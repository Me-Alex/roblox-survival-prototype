local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CraftingService = {}

local context
local lastRestByPlayer = {}
local lastBuildByPlayer = {}
local lastCraftByPlayer = {}

local BUILD_COOLDOWN_SECONDS = 0.35
local BUILD_MAX_DISTANCE = 13
local BUILD_WORLD_MARGIN = 12
local BUILD_OVERLAP_PADDING = 1.2
local CRAFT_COOLDOWN_SECONDS = 0.22
local worldPerformance = (Config.World and Config.World.Performance) or {}
local TONE_DOWN_SMOOTH_SURFACES = worldPerformance.ToneDownSmoothSurfaces ~= false

local PERSISTENT_ATTRIBUTE_NAMES = {
	Charges = true,
	FuelSeconds = true,
	Lit = true,
	MaxFuelSeconds = true,
	Open = true,
	OwnerUserId = true,
	Stage = true,
	StructureId = true,
}

local function markWorldDirty()
	if context and context.PersistenceService then
		context.PersistenceService.markWorldDirty()
	end
end

local function markPlayerDirty(player)
	if context and context.PersistenceService then
		context.PersistenceService.markPlayerDirty(player)
	end
end

local function notify(player, message)
	Remotes.get("Notification"):FireClient(player, message)
end

local function assignStructureId(model)
	if not model:GetAttribute("StructureId") then
		model:SetAttribute("StructureId", HttpService:GenerateGUID(false))
	end
end

local function serializeCFrame(cframe)
	return { cframe:GetComponents() }
end

local function deserializeCFrame(values)
	if type(values) ~= "table" or #values < 12 then
		return CFrame.new()
	end

	return CFrame.new(table.unpack(values, 1, 12))
end

local function getStructurePlacementCFrame(model)
	local placementCFrame = model:GetAttribute("PlacementCFrame")
	if typeof(placementCFrame) == "CFrame" then
		return placementCFrame
	end

	return model:GetPivot()
end

local function shouldPersistAttribute(name, value)
	local valueType = type(value)
	return (PERSISTENT_ATTRIBUTE_NAMES[name] or string.sub(name, 1, 7) == "Stored_")
		and (valueType == "number" or valueType == "string" or valueType == "boolean")
end

local function getPersistentAttributes(model)
	local attributes = {}

	for name, value in pairs(model:GetAttributes()) do
		if shouldPersistAttribute(name, value) then
			attributes[name] = value
		end
	end

	return attributes
end

local function getRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function canBuild(player, root, placementPosition)
	local now = os.clock()
	local lastBuildAt = lastBuildByPlayer[player] or 0
	if now - lastBuildAt < BUILD_COOLDOWN_SECONDS then
		return false, "Slow down before placing another kit."
	end

	local horizontalDelta = Vector3.new(
		placementPosition.X - root.Position.X,
		0,
		placementPosition.Z - root.Position.Z
	)

	if horizontalDelta.Magnitude > BUILD_MAX_DISTANCE then
		return false, "Move closer before placing."
	end

	local half = Config.World.SpawnAreaHalfSize + BUILD_WORLD_MARGIN
	if math.abs(placementPosition.X) > half or math.abs(placementPosition.Z) > half then
		return false, "Cannot build outside the island bounds."
	end

	return true
end

local function getHorizontalFootprintRadius(model)
	local ok, _, size = pcall(function()
		return model:GetBoundingBox()
	end)

	local extents = ok and size or model:GetExtentsSize()
	return math.max(1.6, math.max(extents.X, extents.Z) * 0.5)
end

local function isPlacementOverlapping(model)
	local structuresFolder = context and context.WorldService and context.WorldService.getStructuresFolder()
	if not structuresFolder then
		return false
	end

	local placementPosition = model:GetPivot().Position
	local placementRadius = getHorizontalFootprintRadius(model)

	for _, structure in ipairs(structuresFolder:GetChildren()) do
		if structure:IsA("Model") and structure.PrimaryPart then
			local otherPosition = structure:GetPivot().Position
			local delta = Vector3.new(placementPosition.X - otherPosition.X, 0, placementPosition.Z - otherPosition.Z)
			local minDistance = placementRadius + getHorizontalFootprintRadius(structure) + BUILD_OVERLAP_PADDING

			if delta.Magnitude < minDistance then
				return true
			end
		end
	end

	return false
end

local function createPart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = (TONE_DOWN_SMOOTH_SURFACES and material == Enum.Material.SmoothPlastic) and Enum.Material.Plastic or material
	part.Reflectance = 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function updateCampfireVisual(model)
	local fuel = model:GetAttribute("FuelSeconds") or 0
	local maxFuel = math.max(1, model:GetAttribute("MaxFuelSeconds") or Config.Buildables.CampfireKit.MaxFuelSeconds or 1)
	local lit = fuel > 0
	local fuelRatio = math.clamp(fuel / maxFuel, 0, 1)

	model:SetAttribute("Lit", lit)

	local flame = model:FindFirstChild("HeatSource", true)
	if flame then
		flame.Transparency = lit and math.clamp(0.2 + (1 - fuelRatio) * 0.45, 0.15, 0.7) or 1
		flame.Size = Vector3.new(1.2 + fuelRatio * 1.1, 1.4 + fuelRatio * 1.6, 1.2 + fuelRatio * 1.1)

		local light = flame:FindFirstChild("WarmLight")
		if light then
			light.Enabled = lit
			light.Brightness = 1 + fuelRatio * 2.4
			light.Range = 15 + fuelRatio * 18
		end
	end

	local prompt = model:FindFirstChild("FuelPrompt", true)
	if prompt then
		prompt.ActionText = lit and "Add Fuel" or "Relight"
		prompt.ObjectText = string.format("Campfire - %ds fuel", math.floor(fuel + 0.5))
	end
end

local function getCampfireFuelDrain()
	if not context or not context.WorldService then
		return 1
	end

	local weather = context.WorldService.getCurrentWeatherConfig()
	return weather and (weather.FuelDrainMultiplier or 1) or 1
end

local function refuelCampfire(player, model)
	local campfireConfig = Config.Buildables.CampfireKit
	local itemId = campfireConfig.RefuelItem or "Wood"
	local amount = campfireConfig.RefuelAmount or 1

	if not context or not context.InventoryService then
		return
	end

	if not context.InventoryService.hasItem(player, itemId, amount) then
		notify(player, string.format("Need %d %s for fuel.", amount, Config.Items[itemId].DisplayName))
		return
	end

	context.InventoryService.removeItems(player, { [itemId] = amount })

	local maxFuel = campfireConfig.MaxFuelSeconds or 420
	local fuel = model:GetAttribute("FuelSeconds") or 0
	model:SetAttribute("FuelSeconds", math.min(maxFuel, fuel + (campfireConfig.RefuelSeconds or 90)))
	updateCampfireVisual(model)
	markWorldDirty()
	notify(player, "Campfire fuel added.")
end

local function createCampfire(cframe)
	local model = Instance.new("Model")
	model.Name = "Campfire"
	model:SetAttribute("MaxFuelSeconds", Config.Buildables.CampfireKit.MaxFuelSeconds or 420)
	model:SetAttribute("FuelSeconds", Config.Buildables.CampfireKit.FuelSeconds or 180)
	model:SetAttribute("Lit", true)

	local base = createPart("FirePit", Vector3.new(5, 0.7, 5), cframe, Color3.fromRGB(92, 88, 80), Enum.Material.Slate, model)

	for index = 1, 8 do
		local angle = (math.pi * 2) * (index / 8)
		local stone = createPart(
			"FireRingStone",
			Vector3.new(0.85, 0.55, 0.8),
			cframe * CFrame.new(math.cos(angle) * 2.55, 0.45, math.sin(angle) * 2.55) * CFrame.Angles(0, angle, 0),
			Color3.fromRGB(103, 101, 94),
			Enum.Material.Slate,
			model
		)
		stone.Shape = Enum.PartType.Ball
		stone.CanCollide = false
	end

	for index = 1, 3 do
		local log = createPart(
			"BurnLog",
			Vector3.new(0.7, 4.2, 0.7),
			cframe * CFrame.new(0, 0.75, 0) * CFrame.Angles(math.rad(90), 0, math.rad(index * 60)),
			Color3.fromRGB(91, 58, 34),
			Enum.Material.Wood,
			model
		)
		log.Shape = Enum.PartType.Cylinder
		log.CanCollide = false
	end

	local flame = createPart(
		"HeatSource",
		Vector3.new(2, 2.5, 2),
		cframe * CFrame.new(0, 1.5, 0),
		Color3.fromRGB(255, 134, 54),
		Enum.Material.Neon,
		model
	)
	flame.CanCollide = false
	flame.Shape = Enum.PartType.Ball

	local light = Instance.new("PointLight")
	light.Name = "WarmLight"
	light.Brightness = 3
	light.Range = 28
	light.Color = Color3.fromRGB(255, 177, 92)
	light.Parent = flame

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FuelPrompt"
	prompt.ActionText = "Add Fuel"
	prompt.ObjectText = "Campfire"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	prompt.Triggered:Connect(function(player)
		refuelCampfire(player, model)
	end)

	model.PrimaryPart = base
	updateCampfireVisual(model)

	task.spawn(function()
		while not model.Parent do
			task.wait()
		end

		while model.Parent do
			task.wait(1)
			local fuel = model:GetAttribute("FuelSeconds") or 0
			if fuel > 0 then
				model:SetAttribute("FuelSeconds", math.max(0, fuel - getCampfireFuelDrain()))
				updateCampfireVisual(model)
			end
		end
	end)

	return model
end

local function createTorchStand(cframe)
	local model = Instance.new("Model")
	model.Name = "TorchStand"

	local base = Instance.new("Part")
	base.Name = "StoneBase"
	base.Anchored = true
	base.Size = Vector3.new(3.2, 0.6, 3.2)
	base.CFrame = cframe * CFrame.new(0, 0.25, 0)
	base.Color = Color3.fromRGB(91, 88, 80)
	base.Material = Enum.Material.Cobblestone
	base.Parent = model

	local post = Instance.new("Part")
	post.Name = "TorchPost"
	post.Anchored = true
	post.Size = Vector3.new(0.45, 6, 0.45)
	post.CFrame = cframe * CFrame.new(0, 3.2, 0)
	post.Color = Color3.fromRGB(75, 50, 32)
	post.Material = Enum.Material.Wood
	post.Parent = model

	local bowl = Instance.new("Part")
	bowl.Name = "BrazierBowl"
	bowl.Anchored = true
	bowl.Shape = Enum.PartType.Ball
	bowl.Size = Vector3.new(2.2, 0.8, 2.2)
	bowl.CFrame = cframe * CFrame.new(0, 6.45, 0)
	bowl.Color = Color3.fromRGB(83, 79, 71)
	bowl.Material = Enum.Material.Slate
	bowl.Parent = model

	local flame = Instance.new("Part")
	flame.Name = "TorchFlame"
	flame.Anchored = true
	flame.CanCollide = false
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new(1.2, 1.55, 1.2)
	flame.CFrame = cframe * CFrame.new(0, 7.1, 0)
	flame.Color = Color3.fromRGB(255, 128, 45)
	flame.Material = Enum.Material.Neon
	flame.Parent = model

	local light = Instance.new("PointLight")
	light.Name = "TorchLight"
	light.Brightness = 2.2
	light.Range = 32
	light.Color = Color3.fromRGB(255, 158, 74)
	light.Parent = flame

	model.PrimaryPart = base
	return model
end

local function createShelter(cframe)
	local model = Instance.new("Model")
	model.Name = "Shelter"

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(12, 0.5, 10)
	floor.CFrame = cframe
	floor.Color = Color3.fromRGB(92, 89, 82)
	floor.Material = Enum.Material.Cobblestone
	floor.Parent = model

	local backWall = Instance.new("Part")
	backWall.Name = "BackWall"
	backWall.Anchored = true
	backWall.Size = Vector3.new(12, 4.2, 0.8)
	backWall.CFrame = cframe * CFrame.new(0, 2.2, 4.6)
	backWall.Color = Color3.fromRGB(72, 70, 66)
	backWall.Material = Enum.Material.Slate
	backWall.Parent = model

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Anchored = true
	roof.Size = Vector3.new(13, 0.7, 11)
	roof.CFrame = cframe * CFrame.new(0, 5.2, 0) * CFrame.Angles(math.rad(16), 0, 0)
	roof.Color = Color3.fromRGB(83, 67, 53)
	roof.Material = Enum.Material.WoodPlanks
	roof.Parent = model

	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local post = Instance.new("Part")
			post.Name = "Post"
			post.Anchored = true
			post.Size = Vector3.new(0.9, 5, 0.9)
			post.CFrame = cframe * CFrame.new(x * 5.2, 2.4, z * 4.2)
			post.Color = Color3.fromRGB(68, 65, 60)
			post.Material = Enum.Material.Slate
			post.Parent = model
		end
	end

	local restPrompt = Instance.new("ProximityPrompt")
	restPrompt.Name = "RestPrompt"
	restPrompt.ActionText = "Rest"
	restPrompt.ObjectText = "Shelter"
	restPrompt.HoldDuration = 0.8
	restPrompt.MaxActivationDistance = 10
	restPrompt.RequiresLineOfSight = false
	restPrompt.Parent = floor

	restPrompt.Triggered:Connect(function(player)
		CraftingService.restAtShelter(player)
	end)

	model.PrimaryPart = floor
	return model
end

local function createRainCollector(cframe)
	local model = Instance.new("Model")
	model.Name = "RainCollector"

	local stand = Instance.new("Part")
	stand.Name = "Stand"
	stand.Anchored = true
	stand.Size = Vector3.new(4, 3, 4)
	stand.CFrame = cframe * CFrame.new(0, 1.3, 0)
	stand.Color = Color3.fromRGB(82, 63, 45)
	stand.Material = Enum.Material.WoodPlanks
	stand.Parent = model

	local basin = Instance.new("Part")
	basin.Name = "Basin"
	basin.Anchored = true
	basin.Size = Vector3.new(7, 1, 7)
	basin.CFrame = cframe * CFrame.new(0, 3.1, 0)
	basin.Color = Color3.fromRGB(60, 120, 148)
	basin.Material = Enum.Material.Glass
	basin.Transparency = 0.18
	basin.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrinkPrompt"
	prompt.ActionText = "Drink"
	prompt.ObjectText = "Rain Collector"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = basin

	prompt.Triggered:Connect(function(player)
		if context and context.VitalsService then
			context.VitalsService.applyConsumable(player, {
				Thirst = Config.Buildables.RainCollectorKit.DrinkThirst,
			})
			notify(player, "You drank stored rainwater.")
		end
	end)

	model.PrimaryPart = stand
	return model
end

local function createWorkbench(cframe)
	local model = Instance.new("Model")
	model.Name = "Workbench"

	local top = Instance.new("Part")
	top.Name = "BenchTop"
	top.Anchored = true
	top.Size = Vector3.new(9, 1, 4)
	top.CFrame = cframe * CFrame.new(0, 2.6, 0)
	top.Color = Color3.fromRGB(96, 65, 42)
	top.Material = Enum.Material.WoodPlanks
	top.Parent = model

	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local leg = Instance.new("Part")
			leg.Name = "Leg"
			leg.Anchored = true
			leg.Size = Vector3.new(0.6, 2.5, 0.6)
			leg.CFrame = cframe * CFrame.new(x * 3.8, 1.2, z * 1.5)
			leg.Color = Color3.fromRGB(78, 50, 34)
			leg.Material = Enum.Material.Wood
			leg.Parent = model
		end
	end

	model.PrimaryPart = top
	return model
end

local function createWoodenWall(cframe)
	local model = Instance.new("Model")
	model.Name = "WoodenWall"

	local wall = createPart("WallPlanks", Vector3.new(16, 9, 1.2), cframe * CFrame.new(0, 4.5, 0), Color3.fromRGB(104, 68, 40), Enum.Material.WoodPlanks, model)
	wall.CanCollide = true

	for x = -1, 1, 2 do
		local post = createPart("WallPost", Vector3.new(1.2, 11, 1.2), cframe * CFrame.new(x * 7.4, 5.5, 0), Color3.fromRGB(72, 47, 29), Enum.Material.Wood, model)
		post.CanCollide = true
	end

	for y = 1, 3 do
		local brace = createPart("Brace", Vector3.new(17, 0.45, 1.45), cframe * CFrame.new(0, 2 + y * 2.1, -0.08), Color3.fromRGB(74, 49, 30), Enum.Material.Wood, model)
		brace.CanCollide = false
	end

	model.PrimaryPart = wall
	return model
end

local function applyDoorOpenState(model)
	local door = model.PrimaryPart or model:FindFirstChild("DoorSlab")
	if not door then
		return
	end

	local prompt = model:FindFirstChild("DoorPrompt", true)
	local isOpen = model:GetAttribute("Open") == true
	local closedCFrame = model:GetAttribute("ClosedCFrame")
	local openCFrame = model:GetAttribute("OpenCFrame")

	if typeof(closedCFrame) == "CFrame" and typeof(openCFrame) == "CFrame" then
		door.CFrame = isOpen and openCFrame or closedCFrame
	end

	door.CanCollide = not isOpen

	if prompt then
		prompt.ActionText = isOpen and "Close" or "Open"
	end
end

local function createWoodenDoor(cframe)
	local model = Instance.new("Model")
	model.Name = "WoodenDoor"

	createPart("LeftFrame", Vector3.new(1.1, 10, 1.1), cframe * CFrame.new(-4.2, 5, 0), Color3.fromRGB(72, 47, 29), Enum.Material.Wood, model)
	createPart("RightFrame", Vector3.new(1.1, 10, 1.1), cframe * CFrame.new(4.2, 5, 0), Color3.fromRGB(72, 47, 29), Enum.Material.Wood, model)
	createPart("TopFrame", Vector3.new(9.6, 1.1, 1.1), cframe * CFrame.new(0, 9.6, 0), Color3.fromRGB(72, 47, 29), Enum.Material.Wood, model)

	local door = createPart("DoorSlab", Vector3.new(6.8, 7.5, 0.8), cframe * CFrame.new(0, 3.8, -0.15), Color3.fromRGB(108, 72, 43), Enum.Material.WoodPlanks, model)
	door.CanCollide = true

	local closedCFrame = door.CFrame
	local openCFrame = cframe * CFrame.new(3.4, 3.8, -3.4) * CFrame.Angles(0, math.rad(90), 0)
	model:SetAttribute("Open", false)
	model:SetAttribute("ClosedCFrame", closedCFrame)
	model:SetAttribute("OpenCFrame", openCFrame)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DoorPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Wooden Door"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = door

	prompt.Triggered:Connect(function()
		model:SetAttribute("Open", model:GetAttribute("Open") ~= true)
		applyDoorOpenState(model)
		markWorldDirty()
	end)

	model.PrimaryPart = door
	applyDoorOpenState(model)
	return model
end

local function createWoodenStairs(cframe)
	local model = Instance.new("Model")
	model.Name = "WoodenStairs"

	local base
	for step = 1, 7 do
		local part = createPart(
			"Step",
			Vector3.new(8, 0.8, 2.2),
			cframe * CFrame.new(0, 0.45 + step * 0.72, -5 + step * 1.55),
			Color3.fromRGB(105, 70, 42),
			Enum.Material.WoodPlanks,
			model
		)
		part.CanCollide = true
		base = base or part
	end

	for x = -1, 1, 2 do
		local rail = createPart("StairRail", Vector3.new(0.65, 4.2, 12), cframe * CFrame.new(x * 4.6, 3.7, 0.5) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(74, 49, 30), Enum.Material.Wood, model)
		rail.CanCollide = false
	end

	model.PrimaryPart = base
	return model
end

local function useStorageChest(player, model)
	if not context or not context.InventoryService then
		return
	end

	local storageConfig = Config.Buildables.StorageChestKit
	local transferAmount = storageConfig.TransferAmount or 10
	local snapshot = context.InventoryService.getInventory(player)

	for _, itemId in ipairs(storageConfig.StorageItems or {}) do
		local count = snapshot.Items[itemId] or 0
		if count > 0 then
			local amount = math.min(count, transferAmount)
			context.InventoryService.removeItems(player, { [itemId] = amount })
			model:SetAttribute("Stored_" .. itemId, (model:GetAttribute("Stored_" .. itemId) or 0) + amount)
			markWorldDirty()
			notify(player, string.format("Stored %d %s.", amount, Config.Items[itemId].DisplayName))
			return
		end
	end

	for _, itemId in ipairs(storageConfig.StorageItems or {}) do
		local stored = model:GetAttribute("Stored_" .. itemId) or 0
		if stored > 0 then
			local amount = math.min(stored, transferAmount)
			model:SetAttribute("Stored_" .. itemId, stored - amount)
			context.InventoryService.addItem(player, itemId, amount)
			markWorldDirty()
			notify(player, string.format("Withdrew %d %s.", amount, Config.Items[itemId].DisplayName))
			return
		end
	end

	notify(player, "Storage chest is empty.")
end

local function createStorageChest(cframe)
	local model = Instance.new("Model")
	model.Name = "StorageChest"

	local body = createPart("ChestBody", Vector3.new(6, 3, 3.4), cframe * CFrame.new(0, 1.5, 0), Color3.fromRGB(92, 58, 34), Enum.Material.WoodPlanks, model)
	local lid = createPart("ChestLid", Vector3.new(6.4, 0.6, 3.8), cframe * CFrame.new(0, 3.35, 0), Color3.fromRGB(67, 43, 28), Enum.Material.Wood, model)
	createPart("ChestBand", Vector3.new(6.8, 0.35, 0.25), cframe * CFrame.new(0, 2.6, -1.85), Color3.fromRGB(70, 72, 68), Enum.Material.Metal, model)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StoragePrompt"
	prompt.ActionText = "Use"
	prompt.ObjectText = "Storage Chest"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	prompt.Triggered:Connect(function(player)
		useStorageChest(player, model)
	end)

	model.PrimaryPart = body
	return model
end

local function createWatchtower(cframe)
	local model = Instance.new("Model")
	model.Name = "Watchtower"

	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			createPart("TowerPost", Vector3.new(1.1, 18, 1.1), cframe * CFrame.new(x * 6, 9, z * 6), Color3.fromRGB(72, 47, 29), Enum.Material.Wood, model)
		end
	end

	local platform = createPart("TowerPlatform", Vector3.new(16, 1, 16), cframe * CFrame.new(0, 17.5, 0), Color3.fromRGB(105, 70, 42), Enum.Material.WoodPlanks, model)
	for z = -1, 1, 2 do
		createPart("TowerRail", Vector3.new(16, 1, 0.8), cframe * CFrame.new(0, 20, z * 8), Color3.fromRGB(77, 51, 31), Enum.Material.Wood, model)
	end
	for x = -1, 1, 2 do
		createPart("TowerRail", Vector3.new(0.8, 1, 16), cframe * CFrame.new(x * 8, 20, 0), Color3.fromRGB(77, 51, 31), Enum.Material.Wood, model)
	end

	for step = 1, 10 do
		createPart("TowerStair", Vector3.new(5, 0.55, 1.6), cframe * CFrame.new(-11 + step, 1.2 + step * 1.45, 8.5), Color3.fromRGB(105, 70, 42), Enum.Material.WoodPlanks, model)
	end

	local roof = createPart("TowerRoof", Vector3.new(19, 1.1, 19), cframe * CFrame.new(0, 24.5, 0), Color3.fromRGB(83, 56, 36), Enum.Material.WoodPlanks, model)
	model.PrimaryPart = platform
	return model
end

local function createForge(cframe)
	local model = Instance.new("Model")
	model.Name = "Forge"

	local body = Instance.new("Part")
	body.Name = "StoneBody"
	body.Anchored = true
	body.Size = Vector3.new(7, 4, 6)
	body.CFrame = cframe * CFrame.new(0, 2, 0)
	body.Color = Color3.fromRGB(83, 82, 80)
	body.Material = Enum.Material.Slate
	body.Parent = model

	local heat = Instance.new("Part")
	heat.Name = "Heat"
	heat.Anchored = true
	heat.CanCollide = false
	heat.Size = Vector3.new(4.5, 1, 3.5)
	heat.CFrame = cframe * CFrame.new(0, 2.2, -0.2)
	heat.Color = Color3.fromRGB(255, 104, 42)
	heat.Material = Enum.Material.Neon
	heat.Parent = model

	local light = Instance.new("PointLight")
	light.Name = "ForgeLight"
	light.Brightness = 2.6
	light.Range = 18
	light.Color = Color3.fromRGB(255, 138, 71)
	light.Parent = heat

	model.PrimaryPart = body
	return model
end

local function createSpikeTrap(cframe)
	local model = Instance.new("Model")
	model.Name = "SpikeTrap"
	model:SetAttribute("Charges", Config.Buildables.SpikeTrapKit.Charges)
	model:SetAttribute("LastTriggered", 0)

	local base = Instance.new("Part")
	base.Name = "TrapBase"
	base.Anchored = true
	base.Size = Vector3.new(8, 0.4, 8)
	base.CFrame = cframe * CFrame.new(0, 0.1, 0)
	base.Color = Color3.fromRGB(76, 58, 42)
	base.Material = Enum.Material.WoodPlanks
	base.Parent = model

	for x = -1, 1 do
		for z = -1, 1 do
			local spike = Instance.new("WedgePart")
			spike.Name = "Spike"
			spike.Anchored = true
			spike.CanCollide = false
			spike.Size = Vector3.new(1.1, 2.6, 1.1)
			spike.CFrame = cframe
				* CFrame.new(x * 2, 1.25, z * 2)
				* CFrame.Angles(0, (x + z) * math.rad(18), 0)
			spike.Color = Color3.fromRGB(92, 72, 48)
			spike.Material = Enum.Material.Wood
			spike.Parent = model
		end
	end

	model.PrimaryPart = base
	return model
end

local function setBeaconStage(model, stage)
	model:SetAttribute("Stage", stage)

	local stageName = Config.SignalBeacon.StageNames[stage] or "Unknown"
	local signal = model:FindFirstChild("SignalLight", true)
	local prompt = model:FindFirstChild("UpgradePrompt", true)

	if signal then
		signal.Transparency = stage > 0 and 0 or 0.45
		signal.Color = stage >= Config.SignalBeacon.MaxStage and Color3.fromRGB(92, 223, 255)
			or Color3.fromRGB(255, 202, 96)

		local light = signal:FindFirstChild("BeaconLight")
		if light then
			light.Enabled = stage > 0
			light.Brightness = stage >= Config.SignalBeacon.MaxStage and 3.5 or 1.7
			light.Range = stage >= Config.SignalBeacon.MaxStage and 42 or 24
		end
	end

	if prompt then
		prompt.ActionText = stage >= Config.SignalBeacon.MaxStage and "Online" or "Upgrade"
		prompt.ObjectText = string.format("Signal Beacon - %s", stageName)
		prompt.Enabled = stage < Config.SignalBeacon.MaxStage
	end
end

local function createSignalBeacon(cframe)
	local model = Instance.new("Model")
	model.Name = "SignalBeacon"

	local base = Instance.new("Part")
	base.Name = "BeaconBase"
	base.Anchored = true
	base.Size = Vector3.new(7, 1, 7)
	base.CFrame = cframe * CFrame.new(0, 0.5, 0)
	base.Color = Color3.fromRGB(82, 80, 75)
	base.Material = Enum.Material.Cobblestone
	base.Parent = model

	local mast = Instance.new("Part")
	mast.Name = "Mast"
	mast.Anchored = true
	mast.Size = Vector3.new(0.8, 8, 0.8)
	mast.CFrame = cframe * CFrame.new(0, 4.5, 0)
	mast.Color = Color3.fromRGB(82, 58, 39)
	mast.Material = Enum.Material.Wood
	mast.Parent = model

	local dish = Instance.new("Part")
	dish.Name = "SignalBrazier"
	dish.Anchored = true
	dish.Shape = Enum.PartType.Ball
	dish.Size = Vector3.new(4.4, 1, 4.4)
	dish.CFrame = cframe * CFrame.new(0, 8.6, 0)
	dish.Color = Color3.fromRGB(97, 94, 87)
	dish.Material = Enum.Material.Slate
	dish.Parent = model

	local signal = Instance.new("Part")
	signal.Name = "SignalLight"
	signal.Anchored = true
	signal.CanCollide = false
	signal.Shape = Enum.PartType.Ball
	signal.Size = Vector3.new(1.2, 1.2, 1.2)
	signal.CFrame = cframe * CFrame.new(0, 9.4, 0)
	signal.Material = Enum.Material.Neon
	signal.Parent = model

	local light = Instance.new("PointLight")
	light.Name = "BeaconLight"
	light.Color = Color3.fromRGB(92, 223, 255)
	light.Enabled = false
	light.Parent = signal

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.HoldDuration = 0.7
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	prompt.Triggered:Connect(function(player)
		CraftingService.upgradeBeacon(player, model)
	end)

	model.PrimaryPart = base
	setBeaconStage(model, 0)
	return model
end

local function createBuildableModel(itemId, cframe)
	local model

	if itemId == "CampfireKit" then
		model = createCampfire(cframe)
	elseif itemId == "TorchStandKit" then
		model = createTorchStand(cframe)
	elseif itemId == "ShelterKit" then
		model = createShelter(cframe)
	elseif itemId == "WoodenWallKit" then
		model = createWoodenWall(cframe)
	elseif itemId == "WoodenDoorKit" then
		model = createWoodenDoor(cframe)
	elseif itemId == "WoodenStairsKit" then
		model = createWoodenStairs(cframe)
	elseif itemId == "StorageChestKit" then
		model = createStorageChest(cframe)
	elseif itemId == "RainCollectorKit" then
		model = createRainCollector(cframe)
	elseif itemId == "WorkbenchKit" then
		model = createWorkbench(cframe)
	elseif itemId == "WatchtowerKit" then
		model = createWatchtower(cframe)
	elseif itemId == "ForgeKit" then
		model = createForge(cframe)
	elseif itemId == "SpikeTrapKit" then
		model = createSpikeTrap(cframe)
	elseif itemId == "SignalBeaconKit" then
		model = createSignalBeacon(cframe)
	end

	if model then
		model:SetAttribute("PlacementCFrame", cframe)
	end

	return model
end

local function createStructureModel(modelName, cframe)
	for itemId, buildable in pairs(Config.Buildables) do
		if buildable.ModelName == modelName then
			return createBuildableModel(itemId, cframe)
		end
	end

	return nil
end

function CraftingService.createStructureFromRecord(record)
	if type(record) ~= "table" or type(record.Type) ~= "string" then
		return nil
	end

	local model = createStructureModel(record.Type, deserializeCFrame(record.CFrame))
	if not model then
		return nil
	end

	local attributes = type(record.Attributes) == "table" and record.Attributes or {}

	for name, value in pairs(attributes) do
		if shouldPersistAttribute(name, value) then
			model:SetAttribute(name, value)
		end
	end

	if type(record.Id) == "string" then
		model:SetAttribute("StructureId", record.Id)
	end

	assignStructureId(model)

	if model.Name == "Campfire" then
		updateCampfireVisual(model)
	elseif model.Name == "WoodenDoor" then
		applyDoorOpenState(model)
	elseif model.Name == "SignalBeacon" then
		setBeaconStage(model, tonumber(model:GetAttribute("Stage")) or 0)
	end

	local structuresFolder = context.WorldService.getStructuresFolder()
	model.Parent = structuresFolder
	return model
end

function CraftingService.getWorldSnapshot()
	local structuresFolder = context and context.WorldService and context.WorldService.getStructuresFolder()
	local records = {}

	if not structuresFolder then
		return {
			Version = 1,
			Structures = records,
		}
	end

	for _, structure in ipairs(structuresFolder:GetChildren()) do
		if structure:IsA("Model") and structure.PrimaryPart then
			assignStructureId(structure)
			table.insert(records, {
				Id = structure:GetAttribute("StructureId"),
				Type = structure.Name,
				CFrame = serializeCFrame(getStructurePlacementCFrame(structure)),
				Attributes = getPersistentAttributes(structure),
			})
		end
	end

	return {
		Version = 1,
		Structures = records,
	}
end

function CraftingService.applyWorldSnapshot(snapshot)
	snapshot = type(snapshot) == "table" and snapshot or {}

	local structuresFolder = context and context.WorldService and context.WorldService.getStructuresFolder()
	if not structuresFolder then
		return
	end

	for _, child in ipairs(structuresFolder:GetChildren()) do
		child:Destroy()
	end

	for _, record in ipairs(type(snapshot.Structures) == "table" and snapshot.Structures or {}) do
		CraftingService.createStructureFromRecord(record)
	end
end

local function getStructureRadius(modelName)
	for _, buildable in pairs(Config.Buildables) do
		if buildable.ModelName == modelName then
			return buildable.Radius
		end
	end

	return 16
end

local function missingItemMessage(itemId)
	local itemConfig = Config.Items[itemId]
	local displayName = itemConfig and itemConfig.DisplayName or itemId
	return string.format("Need more %s.", displayName)
end

local function formatStructureName(modelName)
	if type(modelName) ~= "string" then
		return "structure"
	end
	return string.gsub(modelName, "(%l)(%u)", "%1 %2")
end

local function getRequiredStations(recipe)
	if type(recipe.RequiresNearby) == "string" then
		return { recipe.RequiresNearby }
	end

	if type(recipe.RequiresNearby) == "table" then
		return recipe.RequiresNearby
	end

	if type(recipe.Stations) == "table" then
		return recipe.Stations
	end

	if type(recipe.Station) == "string" and recipe.Station ~= "" and recipe.Station ~= "Hand" then
		return { recipe.Station }
	end

	return {}
end

local function ensureNearStations(player, recipe)
	for _, stationName in ipairs(getRequiredStations(recipe)) do
		local nearStructure = context.WorldService.isNearStructure(
			player,
			stationName,
			getStructureRadius(stationName)
		)

		if not nearStructure then
			return false, string.format("Stand near %s.", formatStructureName(stationName))
		end
	end

	return true
end

function CraftingService.upgradeBeacon(player, model)
	if not model or model.Name ~= "SignalBeacon" or not model.Parent then
		return false, "No signal beacon nearby."
	end

	local currentStage = model:GetAttribute("Stage") or 0
	local nextStage = currentStage + 1

	if nextStage > Config.SignalBeacon.MaxStage then
		notify(player, "The signal beacon is already online.")
		return false, "Already online."
	end

	local cost = Config.SignalBeacon.UpgradeCost[nextStage]
	local ok, missingItemId = context.InventoryService.hasItems(player, cost)

	if not ok then
		local message = missingItemMessage(missingItemId)
		notify(player, message)
		return false, message
	end

	context.InventoryService.removeItems(player, cost)
	setBeaconStage(model, nextStage)
	markWorldDirty()
	markPlayerDirty(player)

	if context.ObjectiveService then
		context.ObjectiveService.recordBeaconStage(player, nextStage)
	end

	if context.ProgressionService then
		context.ProgressionService.addXP(player, Config.Progression.XP.BeaconUpgrade, "signal beacon")
	end

	local stageName = Config.SignalBeacon.StageNames[nextStage] or tostring(nextStage)
	local message = string.format("Signal beacon upgraded: %s.", stageName)

	if nextStage >= Config.SignalBeacon.MaxStage then
		Remotes.get("Notification"):FireAllClients("The rescue signal is online. Expect heavy resistance.")
	else
		notify(player, message)
	end

	return true, message
end

function CraftingService.restAtShelter(player)
	local restConfig = Config.CampComfort.ShelterRest
	local now = os.clock()
	local lastRest = lastRestByPlayer[player] or 0
	local remaining = restConfig.CooldownSeconds - (now - lastRest)

	if remaining > 0 then
		notify(player, string.format("Rest again in %ds.", math.ceil(remaining)))
		return false, "Rest is cooling down."
	end

	lastRestByPlayer[player] = now

	if context.VitalsService then
		context.VitalsService.applyConsumable(player, {
			Health = restConfig.Health,
			Hunger = restConfig.Hunger,
			Thirst = restConfig.Thirst,
			Temperature = restConfig.Temperature,
			ApplyStatuses = restConfig.ApplyStatuses,
		})
	end

	if context.ObjectiveService then
		context.ObjectiveService.recordShelterRest(player)
	end

	if context.ProgressionService then
		context.ProgressionService.addXP(player, Config.Progression.XP.ShelterRest, "shelter rest")
	end

	notify(player, "You rested at the shelter.")
	return true, "Rested."
end

function CraftingService.craft(player, recipeId)
	local recipe = Config.Crafting[recipeId]
	if not recipe then
		return false, "Unknown recipe."
	end

	local now = os.clock()
	if now - (lastCraftByPlayer[player] or 0) < CRAFT_COOLDOWN_SECONDS then
		return false, "Crafting too fast."
	end

	if recipe.RequiredLevel and context.ProgressionService then
		local level = context.ProgressionService.getLevel(player)

		if level < recipe.RequiredLevel then
			return false, string.format("Requires level %d.", recipe.RequiredLevel)
		end
	end

	local nearStations, stationMessage = ensureNearStations(player, recipe)
	if not nearStations then
		return false, stationMessage
	end

	local ok, missingItemId = context.InventoryService.hasItems(player, recipe.Cost)
	if not ok then
		return false, missingItemMessage(missingItemId)
	end

	lastCraftByPlayer[player] = now
	context.InventoryService.removeItems(player, recipe.Cost)
	context.InventoryService.addItem(player, recipe.Result, recipe.Amount or 1)
	if context.ObjectiveService then
		context.ObjectiveService.recordCrafted(player, recipe.Result, recipe.Amount or 1)
	end
	if context.ProgressionService then
		context.ProgressionService.addXP(player, Config.Progression.XP.Craft, "crafting")
	end
	notify(player, string.format("Crafted %s.", recipe.DisplayName))

	return true, "Crafted."
end

function CraftingService.build(player, itemId)
	local buildable = Config.Buildables[itemId]
	if not buildable then
		return false, "That item cannot be placed."
	end

	if not context.InventoryService.hasItem(player, itemId, 1) then
		return false, "You do not have that kit."
	end

	local root = getRoot(player)
	if not root then
			return false, "Character is not ready."
	end

	local position = root.Position + root.CFrame.LookVector * 9
	local ok, buildMessage = canBuild(player, root, position)
	if not ok then
		return false, buildMessage
	end

	local terrainHeight = context.WorldService.getTerrainHeightAt(position.X, position.Z)
	local placementY = terrainHeight + 0.45
	local cframe = CFrame.new(
		Vector3.new(position.X, placementY, position.Z),
		Vector3.new(root.Position.X, placementY, root.Position.Z)
	)
	local model = createBuildableModel(itemId, cframe)

	if not model then
		return false, "Nothing was built."
	end

	if isPlacementOverlapping(model) then
		model:Destroy()
		return false, "Need more open space for that structure."
	end

	lastBuildByPlayer[player] = os.clock()

	assignStructureId(model)
	model:SetAttribute("OwnerUserId", player.UserId)

	context.InventoryService.removeItems(player, { [itemId] = 1 })
	model.Parent = context.WorldService.getStructuresFolder()
	markWorldDirty()
	markPlayerDirty(player)

	if context.ObjectiveService then
		context.ObjectiveService.recordBuilt(player, model.Name)
	end
	if context.ProgressionService then
		context.ProgressionService.addXP(player, Config.Progression.XP.Build, "base building")
	end

	if buildable.LifetimeSeconds and buildable.LifetimeSeconds > 0 then
		Debris:AddItem(model, buildable.LifetimeSeconds)
	end

	notify(player, string.format("Placed %s.", buildable.DisplayName))
	return true, "Built."
end

function CraftingService.init(newContext)
	context = newContext

	Remotes.get("CraftRequest").OnServerInvoke = function(player, recipeId)
		return CraftingService.craft(player, recipeId)
	end

	Remotes.get("BuildRequest").OnServerInvoke = function(player, itemId)
		return CraftingService.build(player, itemId)
	end
end

function CraftingService.playerRemoving(player)
	lastRestByPlayer[player] = nil
	lastBuildByPlayer[player] = nil
	lastCraftByPlayer[player] = nil
end

return CraftingService
