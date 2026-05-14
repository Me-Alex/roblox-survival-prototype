local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CombatService = {}

local context
local lastAttackByPlayer = {}

local function getRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getBestWeapon(player)
	if context.InventoryService.hasItem(player, "Spear", 1) then
		return "Spear", Config.Combat.Weapons.Spear
	end

	if context.InventoryService.hasItem(player, "StoneAxe", 1) then
		return "StoneAxe", Config.Combat.Weapons.StoneAxe
	end

	return "Fists", {
		Damage = Config.Combat.DefaultDamage,
		Range = Config.Combat.DefaultRange,
	}
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
	local enemy = getClosestEnemy(root, weaponConfig.Range)

	if not enemy then
		return false, "No enemy in range."
	end

	local ok, message = context.EnemyService.damageEnemy(player, enemy, weaponConfig.Damage)
	if ok then
		Remotes.get("Notification"):FireClient(player, string.format("%s: %s", weaponName, message))
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
end

return CombatService
