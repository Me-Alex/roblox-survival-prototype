local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CombatService = {}

local context
local lastAttackByPlayer = {}
local lastUnarmedHintByPlayer = {}
local UNEQUIPPED_HINT_COOLDOWN_SECONDS = 4

-- 10% base crit chance; Iron Spear gets a bonus 5% on top.
local CRIT_CHANCE = 0.10
local IRON_SPEAR_CRIT_BONUS = 0.05
local CRIT_MULTIPLIER = 2.0

local random = Random.new()

local function getRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getBestWeapon(player)
	local equippedWeapon = context.InventoryService.getEquippedItem(player, "Weapon")
	if equippedWeapon and Config.Combat.Weapons[equippedWeapon] then
		return equippedWeapon, Config.Combat.Weapons[equippedWeapon]
	end

	return "Fists", {
		Damage = Config.Combat.DefaultDamage,
		Range = Config.Combat.DefaultRange,
	}
end

local function hasStowedWeapon(player)
	for _, weaponId in ipairs({ "IronSpear", "Spear", "Pickaxe", "StoneAxe" }) do
		if context.InventoryService.hasItem(player, weaponId, 1) then
			return true
		end
	end

	return false
end

local function getClosestTarget(root, range)
	local closestTarget
	local closestDistance = range
	local isWildlife = false

	-- Check hostile enemies
	for _, enemy in ipairs(context.EnemyService.getEnemies()) do
		if enemy.PrimaryPart then
			local offset = enemy:GetPivot().Position - root.Position
			local distance = offset.Magnitude

			if distance <= closestDistance and distance > 0.1 then
				local facing = root.CFrame.LookVector:Dot(offset.Unit)

				if facing > -0.15 then
					closestDistance = distance
					closestTarget = enemy
					isWildlife = false
				end
			end
		end
	end

	-- Check passive wildlife
	for model in pairs(context.EnemyService.getActiveWildlife()) do
		if model.PrimaryPart then
			local offset = model:GetPivot().Position - root.Position
			local distance = offset.Magnitude

			if distance <= closestDistance and distance > 0.1 then
				local facing = root.CFrame.LookVector:Dot(offset.Unit)

				if facing > -0.15 then
					closestDistance = distance
					closestTarget = model
					isWildlife = true
				end
			end
		end
	end

	return closestTarget, isWildlife
end

-- Returns finalDamage, isCrit
local function calculateDamage(weaponName, baseDamage)
	local critChance = CRIT_CHANCE
	if weaponName == "IronSpear" then
		critChance = critChance + IRON_SPEAR_CRIT_BONUS
	end

	local isCrit = random:NextNumber() < critChance
	local finalDamage = isCrit and math.floor(baseDamage * CRIT_MULTIPLIER) or baseDamage
	return finalDamage, isCrit
end

function CombatService.attack(player)
	local now = os.clock()

	if now - (lastAttackByPlayer[player] or 0) < Config.Combat.CooldownSeconds then
		return false, "Recovering."
	end

	lastAttackByPlayer[player] = now

	local root = getRoot(player)
	if not root then
		return false, "Character is not ready."
	end

	local weaponName, weaponConfig = getBestWeapon(player)
	if weaponName == "Fists" and hasStowedWeapon(player) then
		local lastHintAt = lastUnarmedHintByPlayer[player] or 0
		if now - lastHintAt >= UNEQUIPPED_HINT_COOLDOWN_SECONDS then
			lastUnarmedHintByPlayer[player] = now
			Remotes.get("Notification"):FireClient(player, "Equip a weapon to use its full damage.")
		end
	end

	local target, targetIsWildlife = getClosestTarget(root, weaponConfig.Range)

	if not target then
		return false, "No enemy in range."
	end

	-- Apply crit roll before passing damage to EnemyService.
	local finalDamage, isCrit = calculateDamage(weaponName, weaponConfig.Damage)

	local ok, message
	if targetIsWildlife then
		ok, message = context.EnemyService.damageWildlife(player, target, finalDamage)
	else
		ok, message = context.EnemyService.damageEnemy(player, target, finalDamage)
	end

	if ok then
		if Config.Equipment[weaponName] then
			context.InventoryService.damageEquipment(player, weaponName, 1)
		end

		if context.ProgressionService then
			context.ProgressionService.addXP(player, Config.Progression.XP.EnemyHit, "combat")
		end

		local itemConfig = Config.Items[weaponName]
		local displayName = itemConfig and itemConfig.DisplayName or weaponName

		local hitMsg
		if isCrit then
			hitMsg = string.format("%s: CRITICAL! %s", displayName, message)
		else
			hitMsg = string.format("%s: %s", displayName, message)
		end

		Remotes.get("Notification"):FireClient(player, hitMsg)

		-- Fire EnemyDamaged so the client can show a floating damage number.
		if target.PrimaryPart then
			Remotes.get("EnemyDamaged"):FireClient(player, {
				Position = target:GetPivot().Position,
				Damage = finalDamage,
				IsCrit = isCrit,
			})
		end
	end

	return ok, message
end

function CombatService.init(newContext)
	context = newContext

	Remotes.get("AttackRequest").OnServerInvoke = function(player)
		return CombatService.attack(player)
	end
end

function CombatService.playerRemoving(player)
	lastAttackByPlayer[player] = nil
	lastUnarmedHintByPlayer[player] = nil
end

return CombatService
