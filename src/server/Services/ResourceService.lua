local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ResourceService = {}

local context
local random = Random.new(Config.World.Seed)
local resourcesFolder
local lastHarvestAtByPlayer = {}
local lastRangeNoticeAtByPlayer = {}
local lastToolTargetNoticeAtByPlayer = {}

local HARVEST_COOLDOWN_SECONDS = 0.35
local HARVEST_MAX_DISTANCE = 15
local RANGE_NOTICE_COOLDOWN_SECONDS = 1.5
local TOOL_TARGET_NOTICE_COOLDOWN_SECONDS = 1.2
local worldPerformance = (Config.World and Config.World.Performance) or {}
local TONE_DOWN_SMOOTH_SURFACES = worldPerformance.ToneDownSmoothSurfaces ~= false
local RESOURCE_SPAWN_MULTIPLIER = math.clamp(tonumber(worldPerformance.ResourceSpawnMultiplier) or 1, 0.2, 1)
local STARTER_SUPPLY_MULTIPLIER = math.clamp(
	tonumber(worldPerformance.StarterSupplyMultiplier) or RESOURCE_SPAWN_MULTIPLIER,
	0.2,
	1
)

local TOOL_HARVEST_RESOURCES = {
	Tree = true,
	Rock = true,
	IronDeposit = true,
}

local RESOURCE_COLORS = {
	Tree = Color3.fromRGB(74, 52, 36),
	Rock = Color3.fromRGB(96, 94, 89),
	FiberPlant = Color3.fromRGB(63, 104, 65),
	BerryBush = Color3.fromRGB(39, 78, 53),
	WaterSpring = Color3.fromRGB(65, 119, 148),
	IronDeposit = Color3.fromRGB(91, 79, 73),
	HerbPatch = Color3.fromRGB(64, 111, 75),
	MushroomCluster = Color3.fromRGB(139, 104, 72),
	LootCache = Color3.fromRGB(79, 57, 37),
	HouseLoot = Color3.fromRGB(101, 75, 58),
}

local function getScaledSpawnCount(baseCount, multiplier, minCount)
	local base = math.max(0, math.floor(tonumber(baseCount) or 0))
	if base <= 0 then
		return 0
	end

	local minimum = math.max(1, math.floor(tonumber(minCount) or 1))
	local scaled = math.floor(base * multiplier + 0.5)
	return math.max(minimum, scaled)
end

local function getStarterCenter()
	local spawnPoint = Config.World.SpawnPoint or Vector3.new(0, 0, 0)
	return Vector3.new(spawnPoint.X, 0, spawnPoint.Z)
end

local function randomGroundPosition()
	local half = Config.World.SpawnAreaHalfSize
	return Vector3.new(
		random:NextNumber(-half, half),
		0,
		random:NextNumber(-half, half)
	)
end

local function randomPositionNear(center, radius)
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(random:NextNumber()) * radius

	return Vector3.new(
		center.X + math.cos(angle) * distance,
		0,
		center.Z + math.sin(angle) * distance
	)
end

local function resolveGroundPosition(position)
	local x = position.X
	local z = position.Z
	local y = position.Y

	if context and context.WorldService and context.WorldService.getTerrainHeightAt then
		y = context.WorldService.getTerrainHeightAt(x, z)
	end

	return Vector3.new(x, y, z)
end

local function chooseRegionForResource(resourceId)
	local totalWeight = 0

	for _, region in ipairs(Config.Regions) do
		totalWeight += (region.Resources and region.Resources[resourceId]) or 0
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = random:NextNumber(0, totalWeight)
	local running = 0

	for _, region in ipairs(Config.Regions) do
		running += (region.Resources and region.Resources[resourceId]) or 0

		if roll <= running then
			return region
		end
	end

	return Config.Regions[1]
end

local function chooseResourcePosition(resourceId)
	local region = chooseRegionForResource(resourceId)
	if not region then
		return randomGroundPosition()
	end

	return randomPositionNear(region.Center, region.Radius * 0.82)
end

local function setModelVisible(model, visible)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = visible and 0 or 1
			descendant.CanCollide = visible
			descendant.CanTouch = visible
			descendant.CanQuery = visible
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = visible
		elseif descendant:IsA("Light") then
			descendant.Enabled = visible
		end
	end
end

local function setPromptsEnabled(model, enabled)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			descendant.Enabled = enabled
		end
	end
end

local function scheduleResourceRespawn(model, respawnSeconds, hideDelay)
	setPromptsEnabled(model, false)

	task.delay(hideDelay or 0, function()
		if model and model.Parent then
			setModelVisible(model, false)
		end
	end)

	task.delay((hideDelay or 0) + respawnSeconds, function()
		if model and model.Parent then
			model:SetAttribute("HarvestBusy", false)
			model:SetAttribute("HarvestHits", 0)
			model:SetAttribute("HarvestLock", false)
			setModelVisible(model, true)
		end
	end)
end

local function getPlayerRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function canHarvest(player, model)
	local now = os.clock()
	local root = getPlayerRoot(player)

	if not root or not model.PrimaryPart then
		return false, nil
	end

	if model:GetAttribute("HarvestBusy") == true then
		return false, nil
	end

	local lastHarvestAt = lastHarvestAtByPlayer[player] or 0
	if now - lastHarvestAt < HARVEST_COOLDOWN_SECONDS then
		return false, nil
	end

	local distance = (root.Position - model.PrimaryPart.Position).Magnitude
	if distance > HARVEST_MAX_DISTANCE then
		local lastRangeNotice = lastRangeNoticeAtByPlayer[player] or 0
		if now - lastRangeNotice >= RANGE_NOTICE_COOLDOWN_SECONDS then
			lastRangeNoticeAtByPlayer[player] = now
			return false, "Move closer to harvest."
		end

		return false, nil
	end

	lastHarvestAtByPlayer[player] = now
	return true, nil
end

local function getRequiredToolInfo(resourceConfig)
	local requiredToolId = resourceConfig and resourceConfig.RequiredTool
	if type(requiredToolId) ~= "string" or requiredToolId == "" then
		return nil, nil
	end

	local itemConfig = Config.Items[requiredToolId]
	local displayName = itemConfig and itemConfig.DisplayName or requiredToolId
	return requiredToolId, displayName
end

local function isToolHarvestResource(resourceId)
	return TOOL_HARVEST_RESOURCES[resourceId] == true
end

local function getRequiredHits(resourceConfig)
	local hits = tonumber(resourceConfig and resourceConfig.HarvestHits)
	if not hits or hits < 1 then
		return 1
	end
	return math.floor(hits)
end

local function isToolEquippedForRequirement(player, requiredToolId)
	local equipmentConfig = Config.Equipment[requiredToolId]
	if not equipmentConfig then
		return true
	end

	local inventory = context and context.InventoryService
	if not inventory or not inventory.getEquippedItem then
		return false
	end

	return inventory.getEquippedItem(player, equipmentConfig.Slot) == requiredToolId
end

local function getModelParts(model)
	local parts = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function tweenPart(part, tweenInfo, goal)
	if part and part.Parent then
		TweenService:Create(part, tweenInfo, goal):Play()
	end
end

local function emitFragments(origin, count, color, material, scale)
	for _ = 1, count do
		local chip = Instance.new("Part")
		chip.Name = "HarvestFragment"
		chip.Anchored = false
		chip.CanCollide = false
		chip.CanTouch = false
		chip.CanQuery = false
		chip.Massless = true
		chip.Size = Vector3.new(
			random:NextNumber(0.16, 0.34),
			random:NextNumber(0.16, 0.4),
			random:NextNumber(0.16, 0.34)
		) * (scale or 1)
		chip.CFrame = CFrame.new(origin + Vector3.new(random:NextNumber(-1.2, 1.2), random:NextNumber(0.2, 1.7), random:NextNumber(-1.2, 1.2)))
			* CFrame.Angles(random:NextNumber(0, math.pi), random:NextNumber(0, math.pi), random:NextNumber(0, math.pi))
		chip.Color = color
		chip.Material = material
		chip.Parent = Workspace
		chip.AssemblyLinearVelocity = Vector3.new(random:NextNumber(-10, 10), random:NextNumber(10, 22), random:NextNumber(-10, 10))
		chip.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-8, 8), random:NextNumber(-8, 8))
		Debris:AddItem(chip, 1.4)
	end
end

local function createImpactSlash(root, targetPosition, color, delaySeconds)
	task.delay(delaySeconds or 0, function()
		local startPosition = root and root.Position or (targetPosition + Vector3.new(0, 0, 8))
		local direction = (targetPosition - startPosition)
		if direction.Magnitude <= 0.1 then
			direction = Vector3.new(0, 0, -1)
		end

		local slash = Instance.new("Part")
		slash.Name = "HarvestSlash"
		slash.Anchored = true
		slash.CanCollide = false
		slash.CanTouch = false
		slash.CanQuery = false
		slash.Size = Vector3.new(0.22, 0.22, 6)
		slash.CFrame = CFrame.new(targetPosition + Vector3.new(0, 2.5, 0), targetPosition + direction.Unit)
			* CFrame.Angles(0, 0, math.rad(35))
		slash.Color = color
		slash.Material = Enum.Material.Neon
		slash.Transparency = 0.12
		slash.Parent = Workspace

		tweenPart(slash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 8),
		})
		Debris:AddItem(slash, 0.22)
	end)
end

local function createTreeBiteMark(root, trunk, strike)
	local playerPosition = root and root.Position or (trunk.Position + Vector3.new(0, 0, 8))
	local horizontalDirection = Vector3.new(trunk.Position.X - playerPosition.X, 0, trunk.Position.Z - playerPosition.Z)

	if horizontalDirection.Magnitude <= 0.1 then
		horizontalDirection = trunk.CFrame.LookVector
	end

	local direction = horizontalDirection.Unit
	local hitPosition = trunk.Position - direction * 0.82 + Vector3.new(0, 1.7 + strike * 0.28, 0)
	local bite = Instance.new("Part")
	bite.Name = "AxeBiteMark"
	bite.Anchored = true
	bite.CanCollide = false
	bite.CanTouch = false
	bite.CanQuery = false
	bite.Size = Vector3.new(0.09, 0.48, 1.25)
	bite.CFrame = CFrame.new(hitPosition, hitPosition + direction) * CFrame.Angles(0, 0, math.rad(strike % 2 == 0 and -18 or 18))
	bite.Color = Color3.fromRGB(45, 30, 20)
	bite.Material = Enum.Material.WoodPlanks
	bite.Transparency = 0.08
	bite.Parent = Workspace
	Debris:AddItem(bite, 1.45)
end

local function playTreeChopFeedback(player, model, finalHit)
	local trunk = model.PrimaryPart
	if not trunk then
		return finalHit and 0.34 or 0.12
	end

	local root = getPlayerRoot(player)
	local parts = getModelParts(model)
	local originalCFrames = {}

	for _, part in ipairs(parts) do
		originalCFrames[part] = part.CFrame
	end

	task.spawn(function()
		local sign = random:NextNumber() > 0.5 and 1 or -1
		createImpactSlash(root, trunk.Position, Color3.fromRGB(255, 177, 82), 0)
		task.delay(0.03, function()
			if trunk.Parent then
				createTreeBiteMark(root, trunk, finalHit and 3 or 1)
			end
		end)

		for _, part in ipairs(parts) do
			local original = originalCFrames[part]
			if original then
				tweenPart(part, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = original * CFrame.new(sign * 0.18, 0, 0) * CFrame.Angles(0, 0, math.rad(sign * 4)),
				})
			end
		end

		task.wait(0.07)
		emitFragments(
			trunk.Position + Vector3.new(0, 2.1, 0),
			finalHit and 10 or 5,
			RESOURCE_COLORS.Tree,
			Enum.Material.Wood,
			finalHit and 1.15 or 0.75
		)

		for _, part in ipairs(parts) do
			local original = originalCFrames[part]
			if original then
				tweenPart(part, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = original })
			end
		end

		if finalHit then
			for offset = -1, 1, 2 do
				local log = Instance.new("Part")
				log.Name = "FallingLogChunk"
				log.Anchored = false
				log.CanCollide = true
				log.Shape = Enum.PartType.Cylinder
				log.Size = Vector3.new(4.5, 1.15, 1.15)
				log.CFrame = trunk.CFrame * CFrame.new(offset * 1.2, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
				log.Color = RESOURCE_COLORS.Tree
				log.Material = Enum.Material.Wood
				log.Parent = Workspace
				log.AssemblyLinearVelocity = Vector3.new(offset * 8, 9, random:NextNumber(-5, 5))
				log.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-6, 6), random:NextNumber(-8, 8), offset * 7)
				Debris:AddItem(log, 2.4)
			end
		end
	end)

	return finalHit and 0.34 or 0.12
end

local function playRockHitFeedback(player, model, isIron, finalHit)
	local rock = model.PrimaryPart
	if not rock then
		return finalHit and 0.24 or 0.11
	end

	local root = getPlayerRoot(player)
	local originalCFrame = rock.CFrame
	task.spawn(function()
		createImpactSlash(
			root,
			rock.Position,
			isIron and Color3.fromRGB(255, 151, 81) or Color3.fromRGB(205, 215, 213),
			0
		)

		local offset = Vector3.new(random:NextNumber(-0.3, 0.3), 0.08, random:NextNumber(-0.3, 0.3))
		tweenPart(rock, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = originalCFrame + offset })
		task.wait(0.07)
		emitFragments(
			rock.Position + Vector3.new(0, 1.6, 0),
			finalHit and (isIron and 10 or 8) or (isIron and 5 or 4),
			isIron and Color3.fromRGB(190, 112, 73) or RESOURCE_COLORS.Rock,
			isIron and Enum.Material.Metal or Enum.Material.Slate,
			finalHit and (isIron and 0.9 or 1) or 0.7
		)
		tweenPart(rock, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = originalCFrame })
	end)

	return finalHit and 0.24 or 0.11
end

local function playPlantPickFeedback(model, color)
	local parts = getModelParts(model)
	local originals = {}

	for _, part in ipairs(parts) do
		originals[part] = part.CFrame
	end

	task.spawn(function()
		for _, part in ipairs(parts) do
			local original = originals[part]
			if original then
				tweenPart(part, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					CFrame = original * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, math.rad(random:NextNumber(-12, 12)), 0),
				})
			end
		end

		local primary = model.PrimaryPart
		if primary then
			emitFragments(primary.Position + Vector3.new(0, 1, 0), 7, color, Enum.Material.Grass, 0.7)
		end

		task.wait(0.16)
		for _, part in ipairs(parts) do
			local original = originals[part]
			if original then
				tweenPart(part, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = original })
			end
		end
	end)

	return 0.32
end

local function playWaterFeedback(model)
	local water = model.PrimaryPart
	if not water then
		return 0.22
	end

	for index = 1, 3 do
		task.delay(index * 0.06, function()
			local ring = Instance.new("Part")
			ring.Name = "WaterRipple"
			ring.Anchored = true
			ring.CanCollide = false
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(2.5, 0.08, 2.5)
			ring.CFrame = water.CFrame * CFrame.new(0, 0.08 + index * 0.02, 0)
			ring.Color = RESOURCE_COLORS.WaterSpring
			ring.Material = Enum.Material.Glass
			ring.Transparency = 0.35
			ring.Parent = Workspace
			tweenPart(ring, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(8 + index * 2, 0.08, 8 + index * 2),
				Transparency = 1,
			})
			Debris:AddItem(ring, 0.45)
		end)
	end

	return 0.2
end

local function playCacheFeedback(model)
	local crate = model.PrimaryPart
	if not crate then
		return 0.45
	end

	local original = crate.CFrame
	task.spawn(function()
		tweenPart(crate, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = original * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, math.rad(7), 0),
		})
		emitFragments(crate.Position + Vector3.new(0, 1.7, 0), 8, Color3.fromRGB(197, 158, 88), Enum.Material.Metal, 0.75)
		task.wait(0.14)
		tweenPart(crate, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = original })
	end)

	return 0.4
end

local function playHarvestFeedback(player, model, resourceId, finalHit)
	if resourceId == "Tree" then
		return playTreeChopFeedback(player, model, finalHit)
	elseif resourceId == "Rock" then
		return playRockHitFeedback(player, model, false, finalHit)
	elseif resourceId == "IronDeposit" then
		return playRockHitFeedback(player, model, true, finalHit)
	elseif resourceId == "WaterSpring" then
		return playWaterFeedback(model)
	elseif resourceId == "LootCache" or resourceId == "HouseLoot" then
		return playCacheFeedback(model)
	elseif resourceId == "MushroomCluster" then
		return playPlantPickFeedback(model, RESOURCE_COLORS.MushroomCluster)
	elseif resourceId == "FiberPlant" or resourceId == "HerbPatch" then
		return playPlantPickFeedback(model, RESOURCE_COLORS.FiberPlant)
	elseif resourceId == "BerryBush" then
		return playPlantPickFeedback(model, RESOURCE_COLORS.BerryBush)
	end

	return 0.25
end

local function createPrompt(parent, resourceId, resourceConfig)
	if isToolHarvestResource(resourceId) then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HarvestPrompt"
	prompt.ActionText = resourceConfig.HarvestText
	prompt.ObjectText = resourceConfig.DisplayName
	prompt.HoldDuration = 0.65
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent

	prompt.Triggered:Connect(function(player)
		ResourceService.harvest(player, parent.Parent, resourceId)
	end)
end

local function rollLoot(lootTable)
	local totalWeight = 0

	for _, entry in ipairs(lootTable) do
		totalWeight += entry.Weight or 1
	end

	local roll = random:NextNumber(0, totalWeight)
	local running = 0

	for _, entry in ipairs(lootTable) do
		running += entry.Weight or 1

		if roll <= running then
			return entry.Item, random:NextInteger(entry.Min, entry.Max)
		end
	end

	local fallback = lootTable[#lootTable]
	return fallback.Item, random:NextInteger(fallback.Min, fallback.Max)
end

local function sendResourcePopup(player, gains)
	if #gains == 0 then
		return
	end

	Remotes.get("ResourcePopup"):FireClient(player, gains)
end

local function triggerHarvestAnimation(player, resourceId)
	Remotes.get("HarvestAnimation"):FireClient(player, resourceId)
end

local function notify(player, message)
	Remotes.get("Notification"):FireClient(player, message)
end

local function awardResourceHarvest(player, resourceId, resourceConfig, inventory)
	local amount = random:NextInteger(resourceConfig.MinAmount, resourceConfig.MaxAmount)
	local equippedWeaponId = inventory.getEquippedItem(player, "Weapon")

	if equippedWeaponId == "StoneAxe" and (resourceId == "Tree" or resourceId == "FiberPlant") then
		amount += 1
	elseif equippedWeaponId == "Pickaxe" and (resourceId == "Rock" or resourceId == "IronDeposit") then
		amount += 1
	end

	inventory.addItem(player, resourceConfig.Reward, amount)

	local gains = {
		{
			ItemId = resourceConfig.Reward,
			DisplayName = Config.Items[resourceConfig.Reward].DisplayName,
			Amount = amount,
			Color = Color3.fromRGB(88, 205, 96),
		},
	}

	for _, reward in ipairs(resourceConfig.SecondaryRewards or {}) do
		if Config.Items[reward.Item] then
			local rewardAmount = random:NextInteger(reward.Min or 1, reward.Max or 1)
			inventory.addItem(player, reward.Item, rewardAmount)
			table.insert(gains, {
				ItemId = reward.Item,
				DisplayName = Config.Items[reward.Item].DisplayName,
				Amount = rewardAmount,
				Color = Color3.fromRGB(89, 184, 86),
			})
		end
	end

	if context.ProgressionService then
		local xp = resourceId == "IronDeposit" and Config.Progression.XP.RareHarvest or Config.Progression.XP.Harvest
		context.ProgressionService.addXP(player, xp, "harvesting")
	end

	notify(player, string.format("+%d %s", amount, Config.Items[resourceConfig.Reward].DisplayName))
	sendResourcePopup(player, gains)
end

local function findNearestToolHarvestResource(player, toolItemId)
	local root = getPlayerRoot(player)
	if not root or not resourcesFolder then
		return nil, nil, nil
	end

	local nearestModel
	local nearestConfig
	local nearestResourceId
	local nearestDistance = HARVEST_MAX_DISTANCE

	for _, child in ipairs(resourcesFolder:GetChildren()) do
		if child:IsA("Model") and child.PrimaryPart and child:GetAttribute("HarvestBusy") ~= true then
			local resourceId = child.Name
			local resourceConfig = Config.Resources[resourceId]
			local requiredToolId = resourceConfig and resourceConfig.RequiredTool
			local isCorrectResource = resourceConfig
				and isToolHarvestResource(resourceId)
				and type(requiredToolId) == "string"
				and requiredToolId == toolItemId

			if isCorrectResource and child.PrimaryPart.Transparency < 1 then
				local distance = (root.Position - child.PrimaryPart.Position).Magnitude
				if distance <= nearestDistance then
					nearestDistance = distance
					nearestModel = child
					nearestConfig = resourceConfig
					nearestResourceId = resourceId
				end
			end
		end
	end

	return nearestModel, nearestResourceId, nearestConfig
end

local function createCylinderBetween(name, fromPosition, toPosition, radius, color, material, parent)
	local offset = toPosition - fromPosition
	local length = offset.Magnitude

	if length <= 0.05 then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, radius * 2, radius * 2)
	part.CFrame = CFrame.lookAt((fromPosition + toPosition) * 0.5, toPosition) * CFrame.Angles(0, math.rad(90), 0)
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

local function createTree(position)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local groundY = position.Y
	local height = random:NextNumber(14.5, 18.5)
	local trunkRadius = random:NextNumber(2.15, 2.85)

	local trunk = Instance.new("Part")
	trunk.Name = "DarkPineTrunk"
	trunk.Anchored = true
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(height, trunkRadius, trunkRadius)
	trunk.CFrame = CFrame.new(position.X, groundY + height * 0.5, position.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = RESOURCE_COLORS.Tree
	trunk.Material = Enum.Material.Wood
	trunk.Parent = model

	for mark = 1, 5 do
		local angle = (math.pi * 2) * (mark / 5) + random:NextNumber(-0.18, 0.18)
		local bark = Instance.new("Part")
		bark.Name = "BarkRidge"
		bark.Anchored = true
		bark.CanCollide = false
		bark.CanTouch = false
		bark.CanQuery = false
		bark.Size = Vector3.new(height * random:NextNumber(0.52, 0.82), 0.08, 0.16)
		bark.CFrame = trunk.CFrame
			* CFrame.new(
				random:NextNumber(-1.2, 1.1),
				math.cos(angle) * trunkRadius * 0.5,
				math.sin(angle) * trunkRadius * 0.5
			)
			* CFrame.Angles(0, 0, random:NextNumber(-0.08, 0.08))
		bark.Color = Color3.fromRGB(45, 30, 20)
		bark.Material = Enum.Material.Wood
		bark.Parent = model
	end

	for tier = 1, 3 do
		local leaves = Instance.new("Part")
		leaves.Name = "NeedleCrown"
		leaves.Anchored = true
		leaves.Shape = Enum.PartType.Ball
		leaves.Size = Vector3.new(
			(13 - tier * 2) * random:NextNumber(0.92, 1.08),
			7 * random:NextNumber(0.82, 1.1),
			(13 - tier * 2) * random:NextNumber(0.92, 1.08)
		)
		leaves.CFrame = CFrame.new(
			position.X + random:NextNumber(-0.35, 0.35),
			groundY + height * 0.47 + tier * 3.05,
			position.Z + random:NextNumber(-0.35, 0.35)
		)
		leaves.Color = tier == 1 and Color3.fromRGB(29, 78, 42) or Color3.fromRGB(36, 95, 50)
		leaves.Material = Enum.Material.Grass
		leaves.Parent = model
	end

	for branch = 1, 6 do
		local angle = (math.pi * 2) * (branch / 6) + random:NextNumber(-0.22, 0.22)
		local start = Vector3.new(position.X, groundY + height * random:NextNumber(0.42, 0.72), position.Z)
		local finish = start
			+ Vector3.new(math.cos(angle) * random:NextNumber(3.2, 5.4), random:NextNumber(0.7, 1.9), math.sin(angle) * random:NextNumber(3.2, 5.4))
		createCylinderBetween("Branch", start, finish, random:NextNumber(0.18, 0.32), Color3.fromRGB(66, 43, 27), Enum.Material.Wood, model)
	end

	for offset = 1, 4 do
		local angle = (math.pi * 2) * (offset / 4) + random:NextNumber(-0.18, 0.18)
		local root = Instance.new("Part")
		root.Name = "RootFlare"
		root.Anchored = true
		root.CanCollide = false
		root.Size = Vector3.new(random:NextNumber(2.8, 4.1), 0.45, 0.95)
		root.CFrame = CFrame.new(
			position.X + math.cos(angle) * 1.35,
			groundY + 0.25,
			position.Z + math.sin(angle) * 1.35
		) * CFrame.Angles(0, angle, 0)
		root.Color = RESOURCE_COLORS.Tree
		root.Material = Enum.Material.Wood
		root.Parent = model
	end

	model.PrimaryPart = trunk
	createPrompt(trunk, "Tree", Config.Resources.Tree)
	model.Parent = resourcesFolder
end

local function createRock(position)
	local model = Instance.new("Model")
	model.Name = "Rock"

	local rock = Instance.new("Part")
	rock.Name = "Rock"
	rock.Anchored = true
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.new(7, 4, 6)
	rock.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0))
	rock.Color = RESOURCE_COLORS.Rock
	rock.Material = Enum.Material.Slate
	rock.Parent = model

	for index = 1, 4 do
		local chip = Instance.new("Part")
		chip.Name = "RockPlane"
		chip.Anchored = true
		chip.CanCollide = false
		chip.CanTouch = false
		chip.CanQuery = false
		chip.Size = Vector3.new(random:NextNumber(2.4, 4.5), 0.08, random:NextNumber(0.45, 0.85))
		chip.CFrame = rock.CFrame
			* CFrame.new(random:NextNumber(-1.6, 1.6), random:NextNumber(0.2, 1.55), random:NextNumber(-1.5, 1.5))
			* CFrame.Angles(random:NextNumber(-0.45, 0.45), random:NextNumber(0, math.pi), random:NextNumber(-0.45, 0.45))
		chip.Color = index % 2 == 0 and Color3.fromRGB(72, 73, 70) or Color3.fromRGB(128, 130, 124)
		chip.Material = Enum.Material.Slate
		chip.Parent = model
	end

	for index = 1, 3 do
		local pebble = Instance.new("Part")
		pebble.Name = "LooseStone"
		pebble.Anchored = true
		pebble.CanCollide = false
		pebble.Shape = Enum.PartType.Ball
		pebble.Size = Vector3.new(random:NextNumber(1, 1.8), random:NextNumber(0.7, 1.2), random:NextNumber(1, 1.7))
		pebble.CFrame = CFrame.new(
			position.X + random:NextNumber(-3.4, 3.4),
			position.Y + random:NextNumber(0.35, 0.75),
			position.Z + random:NextNumber(-3.4, 3.4)
		) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
		pebble.Color = Color3.fromRGB(87, 88, 84)
		pebble.Material = Enum.Material.Slate
		pebble.Parent = model
	end

	model.PrimaryPart = rock
	createPrompt(rock, "Rock", Config.Resources.Rock)
	model.Parent = resourcesFolder
end

local function createFiberPlant(position)
	local model = Instance.new("Model")
	model.Name = "FiberPlant"

	local plant = Instance.new("Part")
	plant.Name = "PlantCore"
	plant.Anchored = true
	plant.CanCollide = false
	plant.Shape = Enum.PartType.Ball
	plant.Size = Vector3.new(1.4, 1, 1.4)
	plant.CFrame = CFrame.new(position + Vector3.new(0, 0.65, 0))
	plant.Color = Color3.fromRGB(54, 92, 58)
	plant.Material = Enum.Material.Grass
	plant.Parent = model

	for blade = 1, 9 do
		local angle = (math.pi * 2) * (blade / 9) + random:NextNumber(-0.16, 0.16)
		local height = random:NextNumber(3.6, 5.4)
		local leaf = Instance.new("Part")
		leaf.Name = "FiberBlade"
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.CanTouch = false
		leaf.CanQuery = false
		leaf.Size = Vector3.new(0.22, height, 0.42)
		leaf.CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 0.55, height * 0.46, math.sin(angle) * 0.55))
			* CFrame.Angles(random:NextNumber(-0.18, 0.18), angle, random:NextNumber(-0.36, 0.36))
		leaf.Color = blade % 2 == 0 and Color3.fromRGB(73, 128, 70) or RESOURCE_COLORS.FiberPlant
		leaf.Material = Enum.Material.Grass
		leaf.Parent = model
	end

	model.PrimaryPart = plant
	createPrompt(plant, "FiberPlant", Config.Resources.FiberPlant)
	model.Parent = resourcesFolder
end

local function createBerryBush(position)
	local model = Instance.new("Model")
	model.Name = "BerryBush"

	local bush = Instance.new("Part")
	bush.Name = "Bush"
	bush.Anchored = true
	bush.Shape = Enum.PartType.Ball
	bush.Size = Vector3.new(5, 4, 5)
	bush.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
	bush.Color = RESOURCE_COLORS.BerryBush
	bush.Material = Enum.Material.Grass
	bush.Parent = model

	for branch = 1, 5 do
		local angle = (math.pi * 2) * (branch / 5) + random:NextNumber(-0.2, 0.2)
		local start = bush.Position + Vector3.new(0, -1.1, 0)
		local finish = bush.Position + Vector3.new(math.cos(angle) * 2.2, random:NextNumber(-0.2, 1.2), math.sin(angle) * 2.2)
		createCylinderBetween("BushTwig", start, finish, 0.09, Color3.fromRGB(67, 45, 30), Enum.Material.Wood, model)
	end

	for i = 1, 10 do
		local berry = Instance.new("Part")
		berry.Name = "Berry"
		berry.Anchored = true
		berry.CanCollide = false
		berry.Shape = Enum.PartType.Ball
		berry.Size = Vector3.new(0.36, 0.36, 0.36) * random:NextNumber(0.85, 1.25)
		berry.CFrame = bush.CFrame * CFrame.new(
			random:NextNumber(-2.05, 2.05),
			random:NextNumber(-0.65, 1.45),
			random:NextNumber(-2.05, 2.05)
		)
		berry.Color = i % 3 == 0 and Color3.fromRGB(203, 52, 70) or Color3.fromRGB(132, 28, 55)
		berry.Material = TONE_DOWN_SMOOTH_SURFACES and Enum.Material.Plastic or Enum.Material.SmoothPlastic
		berry.Parent = model
	end

	model.PrimaryPart = bush
	createPrompt(bush, "BerryBush", Config.Resources.BerryBush)
	model.Parent = resourcesFolder
end

local function createWaterSpring(position)
	local model = Instance.new("Model")
	model.Name = "WaterSpring"
	local groundY = position.Y

	local water = Instance.new("Part")
	water.Name = "Water"
	water.Anchored = true
	water.Shape = Enum.PartType.Cylinder
	water.Size = Vector3.new(7, 1, 7)
	water.CFrame = CFrame.new(position.X, groundY + 0.35, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	water.Color = RESOURCE_COLORS.WaterSpring
	water.Material = Enum.Material.Glass
	water.Transparency = 0.25
	water.Parent = model

	local rim = Instance.new("Part")
	rim.Name = "StoneRim"
	rim.Anchored = true
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(8, 0.7, 8)
	rim.CFrame = CFrame.new(position.X, groundY + 0.25, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	rim.Color = Color3.fromRGB(93, 96, 94)
	rim.Material = Enum.Material.Slate
	rim.Parent = model

	for index = 1, 9 do
		local angle = (math.pi * 2) * (index / 9) + random:NextNumber(-0.12, 0.12)
		local stone = Instance.new("Part")
		stone.Name = "SpringStone"
		stone.Anchored = true
		stone.CanCollide = false
		stone.Shape = Enum.PartType.Ball
		stone.Size = Vector3.new(random:NextNumber(1, 1.9), random:NextNumber(0.45, 0.9), random:NextNumber(0.9, 1.8))
		stone.CFrame = CFrame.new(
			position.X + math.cos(angle) * random:NextNumber(3.8, 4.8),
			groundY + 0.45,
			position.Z + math.sin(angle) * random:NextNumber(3.8, 4.8)
		) * CFrame.Angles(0, angle, random:NextNumber(-0.18, 0.18))
		stone.Color = Color3.fromRGB(82, 88, 84)
		stone.Material = Enum.Material.Slate
		stone.Parent = model
	end

	local shimmer = Instance.new("Part")
	shimmer.Name = "WaterShimmer"
	shimmer.Anchored = true
	shimmer.CanCollide = false
	shimmer.Shape = Enum.PartType.Cylinder
	shimmer.Size = Vector3.new(5.4, 0.05, 5.4)
	shimmer.CFrame = water.CFrame * CFrame.new(0.04, 0, 0)
	shimmer.Color = Color3.fromRGB(132, 196, 214)
	shimmer.Material = Enum.Material.Neon
	shimmer.Transparency = 0.74
	shimmer.Parent = model

	model.PrimaryPart = water
	createPrompt(water, "WaterSpring", Config.Resources.WaterSpring)
	model.Parent = resourcesFolder
end

local function createIronDeposit(position)
	local model = Instance.new("Model")
	model.Name = "IronDeposit"

	local ore = Instance.new("Part")
	ore.Name = "Ore"
	ore.Anchored = true
	ore.Shape = Enum.PartType.Ball
	ore.Size = Vector3.new(6.5, 4.5, 5.5)
	ore.CFrame = CFrame.new(position + Vector3.new(0, 1.4, 0))
	ore.Color = RESOURCE_COLORS.IronDeposit
	ore.Material = Enum.Material.Metal
	ore.Parent = model

	for veinIndex = 1, 3 do
		local vein = Instance.new("Part")
		vein.Name = "IronVein"
		vein.Anchored = true
		vein.CanCollide = false
		vein.Size = Vector3.new(random:NextNumber(3.2, 5.2), 0.18, 0.46)
		vein.CFrame = ore.CFrame
			* CFrame.new(random:NextNumber(-1.1, 1.1), random:NextNumber(0.2, 1.2), random:NextNumber(-0.9, 0.9))
			* CFrame.Angles(random:NextNumber(-0.45, 0.45), random:NextNumber(0, math.pi), random:NextNumber(-0.5, 0.5))
		vein.Color = Color3.fromRGB(161, 98, 72)
		vein.Material = Enum.Material.CorrodedMetal
		vein.Parent = model
	end

	for chunk = 1, 3 do
		local oreChunk = Instance.new("Part")
		oreChunk.Name = "OreChunk"
		oreChunk.Anchored = true
		oreChunk.CanCollide = false
		oreChunk.Shape = Enum.PartType.Ball
		oreChunk.Size = Vector3.new(random:NextNumber(1.2, 2), random:NextNumber(0.8, 1.4), random:NextNumber(1.1, 1.9))
		oreChunk.CFrame = CFrame.new(
			position.X + random:NextNumber(-3, 3),
			position.Y + random:NextNumber(0.5, 1.1),
			position.Z + random:NextNumber(-3, 3)
		)
		oreChunk.Color = Color3.fromRGB(104, 82, 75)
		oreChunk.Material = Enum.Material.Metal
		oreChunk.Parent = model
	end

	model.PrimaryPart = ore
	createPrompt(ore, "IronDeposit", Config.Resources.IronDeposit)
	model.Parent = resourcesFolder
end

local function createHerbPatch(position)
	local model = Instance.new("Model")
	model.Name = "HerbPatch"

	local base = Instance.new("Part")
	base.Name = "Herbs"
	base.Anchored = true
	base.Shape = Enum.PartType.Ball
	base.Size = Vector3.new(4.5, 1.6, 4.5)
	base.CFrame = CFrame.new(position + Vector3.new(0, 0.9, 0))
	base.Color = RESOURCE_COLORS.HerbPatch
	base.Material = Enum.Material.Grass
	base.Parent = model

	for index = 1, 5 do
		local flower = Instance.new("Part")
		flower.Name = "MedicinalBloom"
		flower.Anchored = true
		flower.CanCollide = false
		flower.Shape = Enum.PartType.Ball
		flower.Size = Vector3.new(0.45, 0.45, 0.45)
		flower.CFrame = base.CFrame * CFrame.new(
			random:NextNumber(-1.6, 1.6),
			0.75,
			random:NextNumber(-1.6, 1.6)
		)
		flower.Color = index % 2 == 0 and Color3.fromRGB(218, 116, 188) or Color3.fromRGB(245, 218, 118)
		flower.Material = Enum.Material.Neon
		flower.Parent = model
	end

	model.PrimaryPart = base
	createPrompt(base, "HerbPatch", Config.Resources.HerbPatch)
	model.Parent = resourcesFolder
end

local function createMushroomCluster(position)
	local model = Instance.new("Model")
	model.Name = "MushroomCluster"

	local base = Instance.new("Part")
	base.Name = "MyceliumPatch"
	base.Anchored = true
	base.Shape = Enum.PartType.Ball
	base.Size = Vector3.new(4.5, 0.8, 4.5)
	base.CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0))
	base.Color = Color3.fromRGB(76, 63, 48)
	base.Material = Enum.Material.Ground
	base.Parent = model

	for index = 1, 7 do
		local cap = Instance.new("Part")
		cap.Name = "MushroomCap"
		cap.Anchored = true
		cap.Shape = Enum.PartType.Ball
		cap.Size = Vector3.new(
			random:NextNumber(0.8, 1.35),
			random:NextNumber(0.45, 0.75),
			random:NextNumber(0.8, 1.35)
		)
		cap.CFrame = base.CFrame * CFrame.new(
			random:NextNumber(-1.6, 1.6),
			random:NextNumber(0.55, 1.1),
			random:NextNumber(-1.6, 1.6)
		)
		cap.Color = index % 3 == 0 and Color3.fromRGB(182, 72, 62) or RESOURCE_COLORS.MushroomCluster
		cap.Material = TONE_DOWN_SMOOTH_SURFACES and Enum.Material.Plastic or Enum.Material.SmoothPlastic
		cap.Parent = model

		local stem = Instance.new("Part")
		stem.Name = "MushroomStem"
		stem.Anchored = true
		stem.Size = Vector3.new(0.28, 0.8, 0.28)
		stem.CFrame = CFrame.new(cap.Position - Vector3.new(0, 0.55, 0))
		stem.Color = Color3.fromRGB(213, 193, 154)
		stem.Material = TONE_DOWN_SMOOTH_SURFACES and Enum.Material.Plastic or Enum.Material.SmoothPlastic
		stem.Parent = model
	end

	model.PrimaryPart = base
	createPrompt(base, "MushroomCluster", Config.Resources.MushroomCluster)
	model.Parent = resourcesFolder
end

local function createLootCache(position)
	local model = Instance.new("Model")
	model.Name = "LootCache"

	local crate = Instance.new("Part")
	crate.Name = "Crate"
	crate.Anchored = true
	crate.Size = Vector3.new(5.5, 3.2, 4)
	crate.CFrame = CFrame.new(position + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
	crate.Color = RESOURCE_COLORS.LootCache
	crate.Material = Enum.Material.WoodPlanks
	crate.Parent = model

	local band = Instance.new("Part")
	band.Name = "MetalBand"
	band.Anchored = true
	band.CanCollide = false
	band.Size = Vector3.new(5.8, 0.35, 4.2)
	band.CFrame = crate.CFrame * CFrame.new(0, 1.72, 0)
	band.Color = Color3.fromRGB(92, 92, 88)
	band.Material = Enum.Material.Metal
	band.Parent = model

	local glow = Instance.new("PointLight")
	glow.Name = "CacheGlint"
	glow.Brightness = 0.8
	glow.Range = 12
	glow.Color = Color3.fromRGB(255, 222, 145)
	glow.Parent = crate

	model.PrimaryPart = crate
	createPrompt(crate, "LootCache", Config.Resources.LootCache)
	model.Parent = resourcesFolder
end

local function createHouseLoot(position)
	local model = Instance.new("Model")
	model.Name = "HouseLoot"

	local yaw = random:NextNumber(0, math.pi)
	local baseCFrame = CFrame.new(position.X, position.Y + 0.2, position.Z) * CFrame.Angles(0, yaw, 0)

	local floor = Instance.new("Part")
	floor.Name = "HouseFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(12, 0.4, 9)
	floor.CFrame = baseCFrame
	floor.Color = Color3.fromRGB(93, 71, 51)
	floor.Material = Enum.Material.WoodPlanks
	floor.Parent = model

	local function addBeam(name, offset, size, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.CFrame = baseCFrame * CFrame.new(offset.X, offset.Y, offset.Z)
		part.Color = color
		part.Material = material
		part.Parent = model
		return part
	end

	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			addBeam(
				"HousePost",
				Vector3.new(x * 5.1, 3.1, z * 3.7),
				Vector3.new(0.9, 6.2, 0.9),
				Color3.fromRGB(74, 52, 37),
				Enum.Material.Wood
			)
		end
	end

	addBeam("BackWall", Vector3.new(0, 2.2, -3.95), Vector3.new(11.2, 4.4, 0.5), Color3.fromRGB(100, 82, 63), Enum.Material.WoodPlanks)
	addBeam("SideWall", Vector3.new(5.75, 2.2, -0.2), Vector3.new(0.5, 4.4, 6.7), Color3.fromRGB(96, 78, 58), Enum.Material.WoodPlanks)
	addBeam("RoofA", Vector3.new(0, 6.05, 0), Vector3.new(12.8, 0.5, 9.8), Color3.fromRGB(78, 60, 46), Enum.Material.WoodPlanks)
	addBeam("RoofB", Vector3.new(0, 6.75, 0), Vector3.new(7.4, 0.35, 7.4), Color3.fromRGB(101, 83, 64), Enum.Material.WoodPlanks)

	local stash = Instance.new("Part")
	stash.Name = "StashCrate"
	stash.Anchored = true
	stash.Size = Vector3.new(3.8, 2.7, 2.8)
	stash.CFrame = baseCFrame * CFrame.new(-1.6, 1.55, 1.9)
	stash.Color = RESOURCE_COLORS.HouseLoot
	stash.Material = Enum.Material.WoodPlanks
	stash.Parent = model

	local lidBand = Instance.new("Part")
	lidBand.Name = "StashBand"
	lidBand.Anchored = true
	lidBand.CanCollide = false
	lidBand.Size = Vector3.new(4, 0.25, 3)
	lidBand.CFrame = stash.CFrame * CFrame.new(0, 1.45, 0)
	lidBand.Color = Color3.fromRGB(92, 92, 88)
	lidBand.Material = Enum.Material.Metal
	lidBand.Parent = model

	local glint = Instance.new("PointLight")
	glint.Name = "HouseLootGlint"
	glint.Brightness = 0.75
	glint.Range = 13
	glint.Color = Color3.fromRGB(255, 224, 163)
	glint.Parent = stash

	model.PrimaryPart = stash
	createPrompt(stash, "HouseLoot", Config.Resources.HouseLoot)
	model.Parent = resourcesFolder
end

local function spawnResource(resourceId, position)
	position = resolveGroundPosition(position or chooseResourcePosition(resourceId))

	if resourceId == "Tree" then
		createTree(position)
	elseif resourceId == "Rock" then
		createRock(position)
	elseif resourceId == "FiberPlant" then
		createFiberPlant(position)
	elseif resourceId == "BerryBush" then
		createBerryBush(position)
	elseif resourceId == "WaterSpring" then
		createWaterSpring(position)
	elseif resourceId == "IronDeposit" then
		createIronDeposit(position)
	elseif resourceId == "HerbPatch" then
		createHerbPatch(position)
	elseif resourceId == "MushroomCluster" then
		createMushroomCluster(position)
	elseif resourceId == "LootCache" then
		createLootCache(position)
	elseif resourceId == "HouseLoot" then
		createHouseLoot(position)
	end
end

local function spawnStarterSupplies()
	local radius = Config.World.StarterSupplyRadius
	local center = getStarterCenter()
	local starterResources = {
		Tree = 10,
		Rock = 8,
		FiberPlant = 9,
		BerryBush = 8,
		WaterSpring = 3,
	}

	for resourceId, count in pairs(starterResources) do
		local scaledCount = getScaledSpawnCount(count, STARTER_SUPPLY_MULTIPLIER, 1)
		for _ = 1, scaledCount do
			spawnResource(resourceId, randomPositionNear(center, radius))
		end
	end
end

function ResourceService.harvest(player, model, resourceId)
	local resourceConfig = Config.Resources[resourceId]
	if not resourceConfig or not model or not model.Parent then
		return
	end

	local okToHarvest, validationMessage = canHarvest(player, model)
	if not okToHarvest then
		if validationMessage then
			notify(player, validationMessage)
		end
		return
	end

	if resourceConfig.Thirst then
		model:SetAttribute("HarvestBusy", true)
		triggerHarvestAnimation(player, resourceId)
		local hideDelay = playHarvestFeedback(player, model, resourceId, true)
		context.VitalsService.applyConsumable(player, {
			Thirst = resourceConfig.Thirst,
		})
		sendResourcePopup(player, {
			{
				DisplayName = "Water",
				Amount = resourceConfig.Thirst,
				Color = Color3.fromRGB(72, 159, 218),
			},
		})
		notify(player, string.format("+%d thirst", resourceConfig.Thirst))
		scheduleResourceRespawn(model, resourceConfig.RespawnSeconds, hideDelay)

		return
	end

	local inventory = context.InventoryService

	if isToolHarvestResource(resourceId) then
		notify(player, "Use the equipped harvesting tool and click to gather.")
		return
	end

	local requiredToolId, requiredToolName = getRequiredToolInfo(resourceConfig)
	if requiredToolId and not inventory.hasItem(player, requiredToolId, 1) then
		notify(player, string.format("Need %s.", requiredToolName))
		return
	end

	if requiredToolId and not isToolEquippedForRequirement(player, requiredToolId) then
		notify(player, string.format("Equip %s first.", requiredToolName))
		return
	end

	model:SetAttribute("HarvestBusy", true)

	if resourceConfig.Loot then
		triggerHarvestAnimation(player, resourceId)
		local hideDelay = playHarvestFeedback(player, model, resourceId, true)
		local itemId, amount = rollLoot(resourceConfig.Loot)
		inventory.addItem(player, itemId, amount)
		sendResourcePopup(player, {
			{
				ItemId = itemId,
				DisplayName = Config.Items[itemId].DisplayName,
				Amount = amount,
				Color = Color3.fromRGB(88, 205, 96),
			},
		})

		if context.ObjectiveService then
			context.ObjectiveService.recordCacheSearched(player)
		end

		if context.ProgressionService then
			context.ProgressionService.addXP(player, Config.Progression.XP.CacheSearch, "cache search")
		end

		notify(player, string.format("Cache found: +%d %s", amount, Config.Items[itemId].DisplayName))

		scheduleResourceRespawn(model, resourceConfig.RespawnSeconds, hideDelay)

		return
	end

	triggerHarvestAnimation(player, resourceId)
	local hideDelay = playHarvestFeedback(player, model, resourceId, true)
	awardResourceHarvest(player, resourceId, resourceConfig, inventory)
	scheduleResourceRespawn(model, resourceConfig.RespawnSeconds, hideDelay)
end

function ResourceService.toolHarvest(player, toolItemId)
	if type(toolItemId) ~= "string" or not Config.Equipment[toolItemId] then
		return false, false
	end

	local model, resourceId, resourceConfig = findNearestToolHarvestResource(player, toolItemId)
	if not model or not resourceConfig then
		local now = os.clock()
		local lastNoticeAt = lastToolTargetNoticeAtByPlayer[player] or 0
		if now - lastNoticeAt >= TOOL_TARGET_NOTICE_COOLDOWN_SECONDS then
			lastToolTargetNoticeAtByPlayer[player] = now
			local itemConfig = Config.Items[toolItemId]
			local displayName = itemConfig and itemConfig.DisplayName or toolItemId
			notify(player, string.format("No harvest target in range for %s.", displayName))
		end
		return false, false
	end

	local okToHarvest, validationMessage = canHarvest(player, model)
	if not okToHarvest then
		if validationMessage then
			notify(player, validationMessage)
		end
		return true, false, validationMessage
	end

	if model:GetAttribute("HarvestBusy") == true then
		return true, false
	end

	local requiredToolId, requiredToolName = getRequiredToolInfo(resourceConfig)
	local inventory = context.InventoryService

	if requiredToolId and not inventory.hasItem(player, requiredToolId, 1) then
		notify(player, string.format("Need %s.", requiredToolName))
		return true, false
	end

	if requiredToolId and not isToolEquippedForRequirement(player, requiredToolId) then
		notify(player, string.format("Equip %s first.", requiredToolName))
		return true, false
	end

	if model:GetAttribute("HarvestLock") == true then
		return true, false
	end

	model:SetAttribute("HarvestLock", true)

	local currentHits = tonumber(model:GetAttribute("HarvestHits")) or 0
	local requiredHits = getRequiredHits(resourceConfig)
	local nextHits = currentHits + 1
	local finalHit = nextHits >= requiredHits

	triggerHarvestAnimation(player, resourceId)
	local hideDelay = playHarvestFeedback(player, model, resourceId, finalHit)

	if Config.Equipment[toolItemId] then
		inventory.damageEquipment(player, toolItemId, 1)
	end

	if finalHit then
		model:SetAttribute("HarvestBusy", true)
		model:SetAttribute("HarvestHits", 0)
		awardResourceHarvest(player, resourceId, resourceConfig, inventory)
		scheduleResourceRespawn(model, resourceConfig.RespawnSeconds, hideDelay)
	else
		model:SetAttribute("HarvestHits", nextHits)
		notify(player, string.format("%s %d/%d", resourceConfig.DisplayName, nextHits, requiredHits))
	end

	model:SetAttribute("HarvestLock", false)
	return true, true
end

function ResourceService.playerRemoving(player)
	lastHarvestAtByPlayer[player] = nil
	lastRangeNoticeAtByPlayer[player] = nil
	lastToolTargetNoticeAtByPlayer[player] = nil
end

function ResourceService.init(newContext)
	context = newContext

	local worldFolder = Workspace:FindFirstChild("SurvivalWorld") or Instance.new("Folder")
	worldFolder.Name = "SurvivalWorld"
	worldFolder.Parent = Workspace

	resourcesFolder = worldFolder:FindFirstChild("Resources") or Instance.new("Folder")
	resourcesFolder.Name = "Resources"
	resourcesFolder.Parent = worldFolder

	if #resourcesFolder:GetChildren() > 0 then
		return
	end

	spawnStarterSupplies()

	for resourceId, resourceConfig in pairs(Config.Resources) do
		local spawnCount = getScaledSpawnCount(resourceConfig.SpawnCount, RESOURCE_SPAWN_MULTIPLIER, 1)
		for _ = 1, spawnCount do
			spawnResource(resourceId)
		end
	end
end

return ResourceService
