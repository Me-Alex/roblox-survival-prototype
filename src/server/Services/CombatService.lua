local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CombatService = {}

local context
local lastAttackByPlayer = {}
local lastUnarmedHintByPlayer = {}
local UNEQUIPPED_HINT_COOLDOWN_SECONDS = 4

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

local function getClosestEnemy(root, range)
	local closestEnemy
	local closestDistance = range

	for _, enemy in ipairs(context.EnemyService.getEnemies()) do
		if enemy.PrimaryPart then
			local offset = enemy:GetPivot().Position - root.Position
			local distance = offset.Magnitude

			if distance <= closestDistance and distance > 0.1 then
				local facing = root.CFrame.LookVector:Dot(offset.Unit)

				if facing > -0.15 then
					closestDistance = distance
					closestEnemy = enemy
				end
			end
		end
	end

	return closestEnemy
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

	local enemy = getClosestEnemy(root, weaponConfig.Range)

	if not enemy then
		return false, "No enemy in range."
	end

	local ok, message = context.EnemyService.damageEnemy(player, enemy, weaponConfig.Damage)
	if ok then
		if Config.Equipment[weaponName] then
			context.InventoryService.damageEquipment(player, weaponName, 1)
		end

		if context.ProgressionService then
			context.ProgressionService.addXP(player, Config.Progression.XP.EnemyHit, "combat")
		end

		local itemConfig = Config.Items[weaponName]
		local displayName = itemConfig and itemConfig.DisplayName or weaponName
		Remotes.get("Notification"):FireClient(player, string.format("%s: %s", displayName, message))
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
