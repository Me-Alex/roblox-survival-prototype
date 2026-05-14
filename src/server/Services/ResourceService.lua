local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ResourceService = {}

local context
local random = Random.new(Config.World.Seed)
local resourcesFolder

local RESOURCE_COLORS = {
	Tree = Color3.fromRGB(92, 64, 44),
	Rock = Color3.fromRGB(116, 120, 128),
	FiberPlant = Color3.fromRGB(87, 138, 73),
	BerryBush = Color3.fromRGB(55, 116, 72),
	WaterSpring = Color3.fromRGB(74, 167, 205),
	IronDeposit = Color3.fromRGB(112, 91, 82),
	HerbPatch = Color3.fromRGB(84, 142, 91),
	LootCache = Color3.fromRGB(121, 98, 62),
}

local function randomGroundPosition()
	local half = Config.World.SpawnAreaHalfSize
	return Vector3.new(
		random:NextNumber(-half, half),
		1.6,
		random:NextNumber(-half, half)
	)
end

local function randomPositionNear(center, radius)
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(random:NextNumber()) * radius

	return Vector3.new(
		center.X + math.cos(angle) * distance,
		1.6,
		center.Z + math.sin(angle) * distance
	)
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

local function createPrompt(parent, resourceId, resourceConfig)
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

local function createTree(position)
	local model = Instance.new("Model")
	model.Name = "Tree"

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Anchored = true
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(3, 12, 3)
	trunk.CFrame = CFrame.new(position + Vector3.new(0, 5.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = RESOURCE_COLORS.Tree
	trunk.Material = Enum.Material.Wood
	trunk.Parent = model

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Anchored = true
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(11, 11, 11)
	leaves.CFrame = CFrame.new(position + Vector3.new(0, 12, 0))
	leaves.Color = Color3.fromRGB(40, 112, 53)
	leaves.Material = Enum.Material.Grass
	leaves.Parent = model

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

	model.PrimaryPart = rock
	createPrompt(rock, "Rock", Config.Resources.Rock)
	model.Parent = resourcesFolder
end

local function createFiberPlant(position)
	local model = Instance.new("Model")
	model.Name = "FiberPlant"

	local plant = Instance.new("Part")
	plant.Name = "Plant"
	plant.Anchored = true
	plant.Size = Vector3.new(2.5, 5, 2.5)
	plant.CFrame = CFrame.new(position + Vector3.new(0, 1.8, 0))
	plant.Color = RESOURCE_COLORS.FiberPlant
	plant.Material = Enum.Material.Grass
	plant.Parent = model

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

	for i = 1, 5 do
		local berry = Instance.new("Part")
		berry.Name = "Berry"
		berry.Anchored = true
		berry.Shape = Enum.PartType.Ball
		berry.Size = Vector3.new(0.45, 0.45, 0.45)
		berry.CFrame = bush.CFrame * CFrame.new(
			random:NextNumber(-1.8, 1.8),
			random:NextNumber(-1, 1.2),
			random:NextNumber(-1.8, 1.8)
		)
		berry.Color = Color3.fromRGB(160, 42, 62)
		berry.Material = Enum.Material.SmoothPlastic
		berry.Parent = model
	end

	model.PrimaryPart = bush
	createPrompt(bush, "BerryBush", Config.Resources.BerryBush)
	model.Parent = resourcesFolder
end

local function createWaterSpring(position)
	local model = Instance.new("Model")
	model.Name = "WaterSpring"

	local water = Instance.new("Part")
	water.Name = "Water"
	water.Anchored = true
	water.Shape = Enum.PartType.Cylinder
	water.Size = Vector3.new(7, 1, 7)
	water.CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	water.Color = RESOURCE_COLORS.WaterSpring
	water.Material = Enum.Material.Glass
	water.Transparency = 0.25
	water.Parent = model

	local rim = Instance.new("Part")
	rim.Name = "StoneRim"
	rim.Anchored = true
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(8, 0.7, 8)
	rim.CFrame = CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	rim.Color = Color3.fromRGB(93, 96, 94)
	rim.Material = Enum.Material.Slate
	rim.Parent = model

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

	local vein = Instance.new("Part")
	vein.Name = "IronVein"
	vein.Anchored = true
	vein.CanCollide = false
	vein.Size = Vector3.new(5, 0.35, 0.6)
	vein.CFrame = ore.CFrame * CFrame.Angles(0, random:NextNumber(0, math.pi), random:NextNumber(-0.5, 0.5))
	vein.Color = Color3.fromRGB(170, 112, 81)
	vein.Material = Enum.Material.Neon
	vein.Parent = model

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

local function spawnResource(resourceId, position)
	position = position or chooseResourcePosition(resourceId)

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
	elseif resourceId == "LootCache" then
		createLootCache(position)
	end
end

local function spawnStarterSupplies()
	local radius = Config.World.StarterSupplyRadius
	local starterResources = {
		Tree = 8,
		Rock = 6,
		FiberPlant = 7,
		BerryBush = 6,
		WaterSpring = 2,
	}

	for resourceId, count in pairs(starterResources) do
		for _ = 1, count do
			spawnResource(resourceId, randomPositionNear(Vector3.new(0, 0, 0), radius))
		end
	end
end

function ResourceService.harvest(player, model, resourceId)
	local resourceConfig = Config.Resources[resourceId]
	if not resourceConfig or not model or not model.Parent then
		return
	end

	if resourceConfig.Thirst then
		context.VitalsService.applyConsumable(player, {
			Thirst = resourceConfig.Thirst,
		})
		Remotes.get("Notification"):FireClient(player, string.format("+%d thirst", resourceConfig.Thirst))
		setModelVisible(model, false)

		task.delay(resourceConfig.RespawnSeconds, function()
			if model and model.Parent then
				setModelVisible(model, true)
			end
		end)

		return
	end

	local inventory = context.InventoryService

	if resourceConfig.RequiredTool and not inventory.hasItem(player, resourceConfig.RequiredTool, 1) then
		Remotes.get("Notification"):FireClient(
			player,
			string.format("Need %s.", Config.Items[resourceConfig.RequiredTool].DisplayName)
		)
		return
	end

	if resourceConfig.Loot then
		local itemId, amount = rollLoot(resourceConfig.Loot)
		inventory.addItem(player, itemId, amount)

		if context.ObjectiveService then
			context.ObjectiveService.recordCacheSearched(player)
		end

		if context.ProgressionService then
			context.ProgressionService.addXP(player, Config.Progression.XP.CacheSearch, "cache search")
		end

		Remotes.get("Notification"):FireClient(
			player,
			string.format("Cache found: +%d %s", amount, Config.Items[itemId].DisplayName)
		)

		setModelVisible(model, false)

		task.delay(resourceConfig.RespawnSeconds, function()
			if model and model.Parent then
				setModelVisible(model, true)
			end
		end)

		return
	end

	local amount = random:NextInteger(resourceConfig.MinAmount, resourceConfig.MaxAmount)

	if inventory.hasItem(player, "StoneAxe", 1) and (resourceId == "Tree" or resourceId == "FiberPlant") then
		amount += 1
	end

	inventory.addItem(player, resourceConfig.Reward, amount)
	if inventory.hasItem(player, "StoneAxe", 1) and (resourceId == "Tree" or resourceId == "IronDeposit") then
		inventory.damageEquipment(player, "StoneAxe", 1)
	end

	if context.ProgressionService then
		local xp = resourceId == "IronDeposit" and Config.Progression.XP.RareHarvest or Config.Progression.XP.Harvest
		context.ProgressionService.addXP(player, xp, "harvesting")
	end

	Remotes.get("Notification"):FireClient(
		player,
		string.format("+%d %s", amount, Config.Items[resourceConfig.Reward].DisplayName)
	)

	setModelVisible(model, false)

	task.delay(resourceConfig.RespawnSeconds, function()
		if model and model.Parent then
			setModelVisible(model, true)
		end
	end)
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
		for _ = 1, resourceConfig.SpawnCount do
			spawnResource(resourceId)
		end
	end
end

return ResourceService
