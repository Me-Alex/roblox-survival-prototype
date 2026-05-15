local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EnemyService = {}

local context
local enemiesFolder
local random = Random.new(Config.World.Seed + 91)
local activeEnemies = {} -- [model] = enemyTypeId (string)
local lastAttackByEnemy = {}
local threat = Config.Threat.BaseThreat
local lastRaidAt = 0

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
	model:SetAttribute("EnemyType", "NightStalker")

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
	-- Silence unused variable warning in strict mode.
	_ = head

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
	activeEnemies[model] = "NightStalker"
	lastAttackByEnemy[model] = 0

	return model
end

-- FrostCrawler: a new, faster enemy that spawns during cold-weather nights
-- and has a chance to apply the Soaked (chilling) status on hit.
local function createFrostCrawler(position)
	local enemyConfig = Config.Enemies.FrostCrawler
	local model = Instance.new("Model")
	model.Name = "FrostCrawler"
	model:SetAttribute("Health", enemyConfig.Health)
	model:SetAttribute("MaxHealth", enemyConfig.Health)
	model:SetAttribute("EnemyType", "FrostCrawler")

	-- Low, flat body — pale blue-grey
	local root = createPart(
		"Root",
		Vector3.new(4, 1.8, 4),
		CFrame.new(position),
		Color3.fromRGB(148, 176, 196),
		Enum.Material.Ice,
		model
	)

	-- Small raised head
	local headPart = createPart(
		"Head",
		Vector3.new(2, 1.4, 2),
		CFrame.new(position + Vector3.new(0, 1.6, 0)),
		Color3.fromRGB(110, 140, 160),
		Enum.Material.SmoothPlastic,
		model
	)
	_ = headPart

	-- Icy cyan eyes
	for x = -1, 1, 2 do
		local eye = createPart(
			"Eye",
			Vector3.new(0.3, 0.3, 0.3),
			CFrame.new(position + Vector3.new(x * 0.45, 1.8, -0.9)),
			Color3.fromRGB(100, 220, 255),
			Enum.Material.Neon,
			model
		)
		eye.CanQuery = false
	end

	model.PrimaryPart = root
	model.Parent = enemiesFolder
	activeEnemies[model] = "FrostCrawler"
	lastAttackByEnemy[model] = 0

	return model
end

-- Safe enemy count: prunes dead references while counting.
local function countActiveEnemies()
	local count = 0
	local dead = {}

	for enemy in pairs(activeEnemies) do
		if enemy.Parent then
			count += 1
		else
			table.insert(dead, enemy)
		end
	end

	for _, enemy in ipairs(dead) do
		activeEnemies[enemy] = nil
		lastAttackByEnemy[enemy] = nil
	end

	return count
end

local function getOwnerPlayer(model)
	local ownerUserId = model:GetAttribute("OwnerUserId")
	if not ownerUserId then
		return nil
	end

	return Players:GetPlayerByUserId(ownerUserId)
end

local function getStructuresByName(modelName)
	if context and context.WorldService and context.WorldService.getStructuresByName then
		return context.WorldService.getStructuresByName(modelName)
	end

	local structuresFolder = context and context.WorldService and context.WorldService.getStructuresFolder()
	local matches = {}
	if not structuresFolder then
		return matches
	end

	for _, structure in ipairs(structuresFolder:GetChildren()) do
		if structure.Name == modelName then
			table.insert(matches, structure)
		end
	end

	return matches
end

local function getHighestBeaconStage()
	local highestStage = 0

	for _, structure in ipairs(getStructuresByName("SignalBeacon")) do
		highestStage = math.max(highestStage, structure:GetAttribute("Stage") or 0)
	end

	return highestStage
end

local function getEffectiveThreat()
	local beaconBonus = getHighestBeaconStage() * Config.Threat.BeaconThreatPerStage
	return math.clamp(threat + beaconBonus, Config.Threat.BaseThreat, Config.Threat.MaxThreat)
end

-- Enemies move faster when threat is high (up to +40% at max threat).
local function getScaledSpeed(baseSpeed)
	local threatFraction = getEffectiveThreat() / Config.Threat.MaxThreat
	return baseSpeed * (1 + threatFraction * 0.4)
end

local function getDamageForPlayer(player, baseDamage)
	local dmg = baseDamage
	local armorId = context.InventoryService and context.InventoryService.getEquippedItem(player, "Armor") or nil

	if armorId and Config.Combat.Armor[armorId] then
		dmg *= Config.Combat.Armor[armorId].DamageMultiplier
	end

	return dmg
end

local function triggerSpikeTraps(enemy, position)
	for _, structure in ipairs(getStructuresByName("SpikeTrap")) do
		if not structure.PrimaryPart then
			continue
		end

		local charges = structure:GetAttribute("Charges") or 0
		local lastTriggered = structure:GetAttribute("LastTriggered") or 0
		local distance = (structure:GetPivot().Position - position).Magnitude

		if charges > 0
			and os.clock() - lastTriggered >= 1
			and distance <= Config.Buildables.SpikeTrapKit.Radius
		then
			structure:SetAttribute("LastTriggered", os.clock())
			structure:SetAttribute("Charges", charges - 1)

			if context.PersistenceService then
				context.PersistenceService.markWorldDirty()
			end

			local owner = getOwnerPlayer(structure)
			EnemyService.damageEnemy(owner, enemy, Config.Buildables.SpikeTrapKit.Damage)

			if owner then
				if context.ProgressionService then
					context.ProgressionService.addXP(owner, Config.Progression.XP.TrapTriggered, "trap triggered")
				end

				Remotes.get("Notification"):FireClient(owner, "Spike trap triggered.")
			end

			if charges - 1 <= 0 then
				structure:Destroy()
			end

			return
		end
	end
end

local function moveEnemy(enemy, deltaTime)
	if not enemy.Parent or not enemy.PrimaryPart then
		-- Already destroyed; prune safely.
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

	local typeId = activeEnemies[enemy] or "NightStalker"
	local enemyConfig = Config.Enemies[typeId] or Config.Enemies.NightStalker
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
		local scaledSpeed = getScaledSpeed(enemyConfig.MoveSpeed)
		local step = math.min(scaledSpeed * deltaTime, direction.Magnitude)
		local nextPosition = Vector3.new(position.X, 2, position.Z) + direction.Unit * step
		enemy:PivotTo(CFrame.new(nextPosition, targetPosition))
		triggerSpikeTraps(enemy, nextPosition)
	end

	if not enemy.Parent then
		return
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

				-- NightStalker: chance to apply Bleeding
				if context.VitalsService and typeId == "NightStalker" and random:NextNumber() <= (enemyConfig.BleedChance or 0) then
					context.VitalsService.applyStatus(targetPlayer, "Bleeding")
				end

				-- FrostCrawler: chance to apply Soaked (chilling the player)
				if context.VitalsService and typeId == "FrostCrawler" and random:NextNumber() <= (enemyConfig.ChillChance or 0) then
					context.VitalsService.applyStatus(targetPlayer, "Soaked")
				end
			end
		end
	end
end

local function grantDrops(player, enemyConfig)
	if not player then
		return
	end

	for itemId, drop in pairs(enemyConfig.Drop) do
		local amount = random:NextInteger(drop.Min, drop.Max)
		context.InventoryService.addItem(player, itemId, amount)
		Remotes.get("Notification"):FireClient(
			player,
			string.format("+%d %s", amount, Config.Items[itemId].DisplayName)
		)
	end
end

local function spawnRaid()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end

	for _ = 1, Config.Threat.RaidEnemyCount do
		local target = players[random:NextInteger(1, #players)]
		createNightStalker(randomSpawnPositionAround(target))
	end

	Remotes.get("Notification"):FireAllClients("A raid is closing in on the camp.")
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

function EnemyService.getThreat()
	return math.floor(getEffectiveThreat() + 0.5)
end

function EnemyService.damageEnemy(player, enemy, amount)
	if not activeEnemies[enemy] or not enemy.Parent then
		return false, "No enemy hit."
	end

	local typeId = activeEnemies[enemy] or "NightStalker"
	local health = enemy:GetAttribute("Health") or 0
	health -= amount
	enemy:SetAttribute("Health", health)

	if health <= 0 then
		activeEnemies[enemy] = nil
		lastAttackByEnemy[enemy] = nil
		enemy:Destroy()

		if player then
			local cfg = Config.Enemies[typeId] or Config.Enemies.NightStalker
			grantDrops(player, cfg)

			if context.ObjectiveService then
				context.ObjectiveService.recordEnemyDefeated(player)
			end

			if context.ProgressionService then
				context.ProgressionService.addXP(player, Config.Progression.XP.EnemyDefeat, "enemy defeated")
			end
		end

		return true, string.format("Defeated %s.", typeId)
	end

	return true, string.format("Hit %s for %d.", typeId, amount)
end


-- ─────────────────────────────────────────────────────────────────────────────
-- PASSIVE WILDLIFE (Rabbit / Deer)
-- ─────────────────────────────────────────────────────────────────────────────

local activeWildlife = {}

local function randomPointNear(center, radius)
	local angle = random:NextNumber(0, math.pi * 2)
	local dist = random:NextNumber(radius * 0.3, radius)
	local half = Config.World.SpawnAreaHalfSize
	return Vector3.new(
		math.clamp(center.X + math.cos(angle) * dist, -half, half),
		2,
		math.clamp(center.Z + math.sin(angle) * dist, -half, half)
	)
end

local function createRabbit(position)
	local cfg = Config.Wildlife.Rabbit
	local model = Instance.new("Model")
	model.Name = "Rabbit"
	model:SetAttribute("Health", cfg.Health)
	model:SetAttribute("MaxHealth", cfg.Health)
	model:SetAttribute("WildlifeType", "Rabbit")

	local body = createPart("Root", Vector3.new(1.1, 0.7, 1.6), CFrame.new(position),
		Color3.fromRGB(200, 185, 165), Enum.Material.SmoothPlastic, model)
	local head = createPart("Head", Vector3.new(0.7, 0.65, 0.65),
		CFrame.new(position + Vector3.new(0, 0.55, -0.65)),
		Color3.fromRGB(200, 185, 165), Enum.Material.SmoothPlastic, model)
	_ = head
	for x = -1, 1, 2 do
		local ear = createPart("Ear", Vector3.new(0.18, 0.55, 0.18),
			CFrame.new(position + Vector3.new(x * 0.22, 1.15, -0.65)),
			Color3.fromRGB(230, 200, 190), Enum.Material.SmoothPlastic, model)
		ear.CanQuery = false
	end
	for x = -1, 1, 2 do
		local eye = createPart("Eye", Vector3.new(0.1, 0.1, 0.1),
			CFrame.new(position + Vector3.new(x * 0.22, 0.65, -0.95)),
			Color3.fromRGB(30, 12, 12), Enum.Material.Neon, model)
		eye.CanQuery = false
	end

	model.PrimaryPart = body
	model.Parent = enemiesFolder
	activeWildlife[model] = {
		typeId = "Rabbit",
		state = "Wander",
		fleeTimer = 0,
		homePos = position,
		nextWanderAt = 0,
		targetPos = position,
	}
	return model
end

local function createDeer(position)
	local cfg = Config.Wildlife.Deer
	local model = Instance.new("Model")
	model.Name = "Deer"
	model:SetAttribute("Health", cfg.Health)
	model:SetAttribute("MaxHealth", cfg.Health)
	model:SetAttribute("WildlifeType", "Deer")

	local body = createPart("Root", Vector3.new(2.2, 1.7, 3.6), CFrame.new(position),
		Color3.fromRGB(162, 116, 72), Enum.Material.SmoothPlastic, model)
	local neck = createPart("Neck", Vector3.new(0.65, 1.2, 0.65),
		CFrame.new(position + Vector3.new(0, 1.7, -1.0)),
		Color3.fromRGB(162, 116, 72), Enum.Material.SmoothPlastic, model)
	_ = neck
	local head = createPart("Head", Vector3.new(0.95, 0.85, 1.1),
		CFrame.new(position + Vector3.new(0, 2.4, -1.35)),
		Color3.fromRGB(150, 104, 60), Enum.Material.SmoothPlastic, model)
	_ = head
	for x = -1, 1, 2 do
		local antler = createPart("Antler", Vector3.new(0.18, 0.7, 0.18),
			CFrame.new(position + Vector3.new(x * 0.38, 3.0, -1.35)),
			Color3.fromRGB(120, 85, 45), Enum.Material.Wood, model)
		antler.CanQuery = false
	end
	for x = -1, 1, 2 do
		local eye = createPart("Eye", Vector3.new(0.14, 0.14, 0.14),
			CFrame.new(position + Vector3.new(x * 0.38, 2.45, -1.8)),
			Color3.fromRGB(20, 10, 5), Enum.Material.Neon, model)
		eye.CanQuery = false
	end

	model.PrimaryPart = body
	model.Parent = enemiesFolder
	activeWildlife[model] = {
		typeId = "Deer",
		state = "Wander",
		fleeTimer = 0,
		homePos = position,
		nextWanderAt = 0,
		targetPos = position,
	}
	return model
end

local function countWildlifeOfType(typeId)
	local count = 0
	local dead = {}
	for model, data in pairs(activeWildlife) do
		if model.Parent then
			if data.typeId == typeId then count += 1 end
		else
			table.insert(dead, model)
		end
	end
	for _, m in ipairs(dead) do activeWildlife[m] = nil end
	return count
end

local function regionCenter(regionId)
	for _, region in ipairs(Config.Regions) do
		if region.Id == regionId then
			return region.Center
		end
	end
	return Vector3.new(0, 2, 0)
end

local function spawnWildlifeForType(typeId)
	local cfg = Config.Wildlife[typeId]
	if not cfg then return end
	if countWildlifeOfType(typeId) >= cfg.MaxAlive then return end

	local spawnRegions = cfg.SpawnRegions
	local chosenId = spawnRegions[random:NextInteger(1, #spawnRegions)]
	local center = regionCenter(chosenId)
	local angle = random:NextNumber(0, math.pi * 2)
	local dist = random:NextNumber(20, 80)
	local half = Config.World.SpawnAreaHalfSize
	local pos = Vector3.new(
		math.clamp(center.X + math.cos(angle) * dist, -half, half),
		2,
		math.clamp(center.Z + math.sin(angle) * dist, -half, half)
	)

	if typeId == "Rabbit" then
		createRabbit(pos)
	elseif typeId == "Deer" then
		createDeer(pos)
	end
end

local function grantWildlifeDrops(player, cfg)
	if not player then return end
	for itemId, drop in pairs(cfg.Drop) do
		local amount = random:NextInteger(drop.Min, drop.Max)
		if amount > 0 then
			context.InventoryService.addItem(player, itemId, amount)
			local displayName = Config.Items[itemId] and Config.Items[itemId].DisplayName or itemId
			Remotes.get("Notification"):FireClient(player, string.format("+%d %s", amount, displayName))
		end
	end
end

local function moveWildlife(deltaTime)
	local now = os.clock()
	local snapshot = {}
	for model in pairs(activeWildlife) do
		table.insert(snapshot, model)
	end

	for _, model in ipairs(snapshot) do
		local data = activeWildlife[model]
		if not data or not model.Parent or not model.PrimaryPart then
			activeWildlife[model] = nil
			continue
		end

		local cfg = Config.Wildlife[data.typeId]
		if not cfg then continue end

		local pos = model:GetPivot().Position
		local flatPos = Vector3.new(pos.X, 2, pos.Z)

		local nearestPlayer, nearestDist = getNearestPlayer(flatPos, cfg.FleeRange)

		if nearestPlayer and nearestDist < cfg.FleeRange then
			data.state = "Flee"
			data.fleeTimer = cfg.FleeDurationSeconds

			local playerRoot = getRoot(nearestPlayer)
			if playerRoot then
				local awayDir = (flatPos - Vector3.new(playerRoot.Position.X, 2, playerRoot.Position.Z))
				if awayDir.Magnitude > 0.1 then
					local half = Config.World.SpawnAreaHalfSize
					local fleeTarget = flatPos + awayDir.Unit * cfg.FleeSpeed * 2
					data.targetPos = Vector3.new(
						math.clamp(fleeTarget.X, -half, half),
						2,
						math.clamp(fleeTarget.Z, -half, half)
					)
				end
			end
		else
			if data.state == "Flee" then
				data.fleeTimer -= deltaTime
				if data.fleeTimer <= 0 then
					data.state = "Wander"
				end
			end
		end

		if data.state == "Wander" and now >= data.nextWanderAt then
			data.targetPos = randomPointNear(data.homePos, cfg.WanderRadius)
			data.nextWanderAt = now + cfg.WanderIntervalSeconds + random:NextNumber(-1, 2)
		end

		local speed = data.state == "Flee" and cfg.FleeSpeed or cfg.MoveSpeed
		local direction = data.targetPos - flatPos

		if direction.Magnitude > 0.5 then
			local step = math.min(speed * deltaTime, direction.Magnitude)
			local nextPos = flatPos + direction.Unit * step
			local lookAt = nextPos + direction.Unit
			model:PivotTo(CFrame.new(nextPos, lookAt))
		end
	end
end

local function startWildlifeSpawnLoop(typeId)
	local cfg = Config.Wildlife[typeId]
	task.spawn(function()
		while true do
			task.wait(cfg.SpawnEverySeconds)
			spawnWildlifeForType(typeId)
		end
	end)
end


function EnemyService.damageWildlife(player, model, amount)
	local data = activeWildlife[model]
	if not data or not model.Parent then
		return false, "Not wildlife."
	end

	local health = (model:GetAttribute("Health") or 0) - amount
	model:SetAttribute("Health", health)

	if health <= 0 then
		activeWildlife[model] = nil
		model:Destroy()
		if player then
			local cfg = Config.Wildlife[data.typeId]
			if cfg then grantWildlifeDrops(player, cfg) end
			if context.ProgressionService then
				context.ProgressionService.addXP(player, Config.Progression.XP.EnemyDefeat or 10, "hunted animal")
			end
		end
		return true, "Animal defeated."
	end

	return true, string.format("Hit %s for %d.", data.typeId, amount)
end

function EnemyService.getActiveWildlife()
	return activeWildlife
end

function EnemyService.init(newContext)
	context = newContext

	local worldFolder = Workspace:FindFirstChild("SurvivalWorld") or Instance.new("Folder")
	worldFolder.Name = "SurvivalWorld"
	worldFolder.Parent = Workspace

	enemiesFolder = worldFolder:FindFirstChild("Enemies") or Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = worldFolder

	-- NightStalker regular spawn loop
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

	-- FrostCrawler spawn loop — only during cold weather nights
	task.spawn(function()
		while true do
			local crawlerConfig = Config.Enemies.FrostCrawler
			task.wait(crawlerConfig.SpawnEverySeconds)

			if not context.WorldService.isNight() then
				continue
			end

			local weatherId = context.WorldService.getCurrentWeatherId()
			if weatherId ~= "ColdFront" and weatherId ~= "Storm" then
				continue
			end

			if countActiveEnemies() >= crawlerConfig.MaxAlive + Config.Enemies.NightStalker.MaxAlive then
				continue
			end

			local players = Players:GetPlayers()
			if #players > 0 then
				local target = players[random:NextInteger(1, #players)]
				createFrostCrawler(randomSpawnPositionAround(target))
				Remotes.get("Notification"):FireAllClients("Something cold is crawling through the dark.")
			end
		end
	end)

	-- Threat tick + raid check
	task.spawn(function()
		while true do
			task.wait(10)

			if context.WorldService.isNight() then
				local weatherId = context.WorldService.getCurrentWeatherId()
				threat = math.min(Config.Threat.MaxThreat, threat + Config.Threat.NightThreatPerTick)

				if weatherId == "Storm" then
					threat = math.min(Config.Threat.MaxThreat, threat + Config.Threat.StormThreatBonus)
				elseif weatherId == "HeatWave" then
					threat = math.min(Config.Threat.MaxThreat, threat + Config.Threat.HeatWaveThreatBonus)
				end
			else
				threat = math.max(Config.Threat.BaseThreat, threat - Config.Threat.DayThreatDecay)
			end

			if getEffectiveThreat() >= Config.Threat.RaidThreshold
				and os.clock() - lastRaidAt >= Config.Threat.RaidCooldownSeconds
			then
				lastRaidAt = os.clock()
				spawnRaid()
				threat = math.max(Config.Threat.BaseThreat, threat - (Config.Threat.RaidThreshold * 0.55))
			end

			if context.WorldService then
				context.WorldService.broadcastWorldState()
			end
		end
	end)

	-- Movement loop
	task.spawn(function()
		while true do
			local deltaTime = 0.25
			-- Snapshot keys to avoid modifying the table during iteration.
			local snapshot = {}
			for enemy in pairs(activeEnemies) do
				table.insert(snapshot, enemy)
			end

			for _, enemy in ipairs(snapshot) do
				moveEnemy(enemy, deltaTime)
			end

			task.wait(deltaTime)
		end
	end)

	-- Wildlife spawn loops
	startWildlifeSpawnLoop("Rabbit")
	startWildlifeSpawnLoop("Deer")

	-- Wildlife movement loop
	task.spawn(function()
		while true do
			local deltaTime = 0.25
			moveWildlife(deltaTime)
			task.wait(deltaTime)
		end
	end)

end
return EnemyService
