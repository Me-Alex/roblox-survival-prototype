local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EnemyService = {}

local context
local enemiesFolder
local random = Random.new(Config.World.Seed + 91)
local activeEnemies = {}
local lastAttackByEnemy = {}

local function getRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getNearestPlayer(position, maxDistance)
	local nearestPlayer
	local nearestDistance = maxDistance

	for _, player in ipairs(Players:GetPlayers()) do
		local root = getRoot(player)
		local humanoid = getHumanoid(player)

		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - position).Magnitude

			if distance < nearestDistance then
				nearestDistance = distance
				nearestPlayer = player
			end
		end
	end

	return nearestPlayer, nearestDistance
end

local function randomSpawnPositionAround(player)
	local root = getRoot(player)
	local half = Config.World.SpawnAreaHalfSize

	if not root then
		return Vector3.new(random:NextNumber(-half, half), 2, random:NextNumber(-half, half))
	end

	local angle = random:NextNumber(0, math.pi * 2)
	local distance = random:NextNumber(45, 75)
	local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	local position = root.Position + offset

	return Vector3.new(
		math.clamp(position.X, -half, half),
		2,
		math.clamp(position.Z, -half, half)
	)
end

local function createPart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

local function createNightStalker(position)
	local enemyConfig = Config.Enemies.NightStalker
	local model = Instance.new("Model")
	model.Name = "NightStalker"
	model:SetAttribute("Health", enemyConfig.Health)
	model:SetAttribute("MaxHealth", enemyConfig.Health)

	local root = createPart(
		"Root",
		Vector3.new(3.5, 3.5, 3.5),
		CFrame.new(position),
		Color3.fromRGB(49, 48, 58),
		Enum.Material.Slate,
		model
	)

	local head = createPart(
		"Head",
		Vector3.new(2.6, 2.2, 2.6),
		CFrame.new(position + Vector3.new(0, 2.8, 0)),
		Color3.fromRGB(35, 36, 43),
		Enum.Material.SmoothPlastic,
		model
	)

	for x = -1, 1, 2 do
		local eye = createPart(
			"Eye",
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(position + Vector3.new(x * 0.55, 2.95, -1.15)),
			Color3.fromRGB(255, 73, 73),
			Enum.Material.Neon,
			model
		)
		eye.CanQuery = false
	end

	model.PrimaryPart = root
	model.Parent = enemiesFolder
	activeEnemies[model] = true
	lastAttackByEnemy[model] = 0

	return model
end

local function countActiveEnemies()
	local count = 0

	for enemy in pairs(activeEnemies) do
		if enemy.Parent then
			count += 1
		else
			activeEnemies[enemy] = nil
			lastAttackByEnemy[enemy] = nil
		end
	end

	return count
end

local function getDamageForPlayer(player, baseDamage)
	local damage = baseDamage
	local armorId = context.InventoryService and context.InventoryService.getEquippedItem(player, "Armor") or nil

	if armorId and Config.Combat.Armor[armorId] then
		damage *= Config.Combat.Armor[armorId].DamageMultiplier
	end

	return damage
end

local function moveEnemy(enemy, deltaTime)
	if not enemy.Parent or not enemy.PrimaryPart then
		activeEnemies[enemy] = nil
		lastAttackByEnemy[enemy] = nil
		return
	end

	if not context.WorldService.isNight() then
		enemy:Destroy()
		activeEnemies[enemy] = nil
		lastAttackByEnemy[enemy] = nil
		return
	end

	local enemyConfig = Config.Enemies.NightStalker
	local position = enemy:GetPivot().Position
	local targetPlayer, distance = getNearestPlayer(position, enemyConfig.AggroRange)

	if not targetPlayer then
		return
	end

	local targetRoot = getRoot(targetPlayer)
	if not targetRoot then
		return
	end

	local targetPosition = Vector3.new(targetRoot.Position.X, 2, targetRoot.Position.Z)
	local direction = targetPosition - Vector3.new(position.X, 2, position.Z)

	if direction.Magnitude > 0.1 then
		local step = math.min(enemyConfig.MoveSpeed * deltaTime, direction.Magnitude)
		local nextPosition = Vector3.new(position.X, 2, position.Z) + direction.Unit * step
		enemy:PivotTo(CFrame.new(nextPosition, targetPosition))
	end

	if distance <= enemyConfig.AttackRange then
		local now = os.clock()

		if now - (lastAttackByEnemy[enemy] or 0) >= 1.25 then
			lastAttackByEnemy[enemy] = now
			local humanoid = getHumanoid(targetPlayer)

			if humanoid then
				humanoid:TakeDamage(getDamageForPlayer(targetPlayer, enemyConfig.Damage))

				if context.InventoryService then
					context.InventoryService.damageEquippedArmor(targetPlayer, 2)
				end

				if context.VitalsService and random:NextNumber() <= (enemyConfig.BleedChance or 0) then
					context.VitalsService.applyStatus(targetPlayer, "Bleeding")
				end
			end
		end
	end
end

local function grantDrops(player, enemyConfig)
	for itemId, drop in pairs(enemyConfig.Drop) do
		local amount = random:NextInteger(drop.Min, drop.Max)
		context.InventoryService.addItem(player, itemId, amount)
		Remotes.get("Notification"):FireClient(
			player,
			string.format("+%d %s", amount, Config.Items[itemId].DisplayName)
		)
	end
end

function EnemyService.getEnemies()
	local enemies = {}

	for enemy in pairs(activeEnemies) do
		if enemy.Parent then
			table.insert(enemies, enemy)
		end
	end

	return enemies
end

function EnemyService.damageEnemy(player, enemy, amount)
	if not activeEnemies[enemy] or not enemy.Parent then
		return false, "No enemy hit."
	end

	local health = enemy:GetAttribute("Health") or 0
	health -= amount
	enemy:SetAttribute("Health", health)

	if health <= 0 then
		activeEnemies[enemy] = nil
		lastAttackByEnemy[enemy] = nil
		enemy:Destroy()
		grantDrops(player, Config.Enemies.NightStalker)

		if context.ObjectiveService then
			context.ObjectiveService.recordEnemyDefeated(player)
		end

		if context.ProgressionService then
			context.ProgressionService.addXP(player, Config.Progression.XP.EnemyDefeat, "enemy defeated")
		end

		return true, "Defeated Night Stalker."
	end

	return true, string.format("Hit Night Stalker for %d.", amount)
end

function EnemyService.init(newContext)
	context = newContext

	local worldFolder = Workspace:FindFirstChild("SurvivalWorld") or Instance.new("Folder")
	worldFolder.Name = "SurvivalWorld"
	worldFolder.Parent = Workspace

	enemiesFolder = worldFolder:FindFirstChild("Enemies") or Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = worldFolder

	task.spawn(function()
		while true do
			local enemyConfig = Config.Enemies.NightStalker
			task.wait(enemyConfig.SpawnEverySeconds)

			if context.WorldService.isNight() and countActiveEnemies() < enemyConfig.MaxAlive then
				local players = Players:GetPlayers()
				if #players > 0 then
					local weather = context.WorldService.getCurrentWeatherConfig()
					local maxAlive = math.floor(enemyConfig.MaxAlive * (weather.EnemyMultiplier or 1))

					if countActiveEnemies() < math.max(1, maxAlive) then
						local target = players[random:NextInteger(1, #players)]
						createNightStalker(randomSpawnPositionAround(target))
						Remotes.get("Notification"):FireAllClients("A night stalker is hunting nearby.")
					end
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			local deltaTime = 0.25

			for enemy in pairs(activeEnemies) do
				moveEnemy(enemy, deltaTime)
			end

			task.wait(deltaTime)
		end
	end)
end

return EnemyService
