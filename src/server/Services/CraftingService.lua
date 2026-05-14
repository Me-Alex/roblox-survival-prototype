local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CraftingService = {}

local context
local lastRestByPlayer = {}

local function notify(player, message)
	Remotes.get("Notification"):FireClient(player, message)
end

local function getRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function createCampfire(cframe)
	local model = Instance.new("Model")
	model.Name = "Campfire"

	local base = Instance.new("Part")
	base.Name = "FirePit"
	base.Anchored = true
	base.Size = Vector3.new(5, 0.7, 5)
	base.CFrame = cframe
	base.Color = Color3.fromRGB(92, 88, 80)
	base.Material = Enum.Material.Slate
	base.Parent = model

	local flame = Instance.new("Part")
	flame.Name = "HeatSource"
	flame.Anchored = true
	flame.CanCollide = false
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new(2, 2.5, 2)
	flame.CFrame = cframe * CFrame.new(0, 1.5, 0)
	flame.Color = Color3.fromRGB(255, 134, 54)
	flame.Material = Enum.Material.Neon
	flame.Parent = model

	local light = Instance.new("PointLight")
	light.Name = "WarmLight"
	light.Brightness = 3
	light.Range = 28
	light.Color = Color3.fromRGB(255, 177, 92)
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
	floor.Color = Color3.fromRGB(103, 74, 51)
	floor.Material = Enum.Material.WoodPlanks
	floor.Parent = model

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Anchored = true
	roof.Size = Vector3.new(13, 0.7, 11)
	roof.CFrame = cframe * CFrame.new(0, 5.2, 0) * CFrame.Angles(math.rad(16), 0, 0)
	roof.Color = Color3.fromRGB(83, 72, 55)
	roof.Material = Enum.Material.Wood
	roof.Parent = model

	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local post = Instance.new("Part")
			post.Name = "Post"
			post.Anchored = true
			post.Size = Vector3.new(0.7, 5, 0.7)
			post.CFrame = cframe * CFrame.new(x * 5.2, 2.4, z * 4.2)
			post.Color = Color3.fromRGB(92, 64, 44)
			post.Material = Enum.Material.Wood
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
	stand.Color = Color3.fromRGB(94, 67, 45)
	stand.Material = Enum.Material.Wood
	stand.Parent = model

	local basin = Instance.new("Part")
	basin.Name = "Basin"
	basin.Anchored = true
	basin.Size = Vector3.new(7, 1, 7)
	basin.CFrame = cframe * CFrame.new(0, 3.1, 0)
	basin.Color = Color3.fromRGB(78, 145, 162)
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
	base.Color = Color3.fromRGB(70, 72, 74)
	base.Material = Enum.Material.Metal
	base.Parent = model

	local mast = Instance.new("Part")
	mast.Name = "Mast"
	mast.Anchored = true
	mast.Size = Vector3.new(0.8, 8, 0.8)
	mast.CFrame = cframe * CFrame.new(0, 4.5, 0)
	mast.Color = Color3.fromRGB(108, 110, 112)
	mast.Material = Enum.Material.Metal
	mast.Parent = model

	local dish = Instance.new("Part")
	dish.Name = "Dish"
	dish.Anchored = true
	dish.Shape = Enum.PartType.Ball
	dish.Size = Vector3.new(4.4, 1, 4.4)
	dish.CFrame = cframe * CFrame.new(0, 8.6, 0)
	dish.Color = Color3.fromRGB(130, 138, 139)
	dish.Material = Enum.Material.Metal
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

	if recipe.RequiredLevel and context.ProgressionService then
		local level = context.ProgressionService.getLevel(player)

		if level < recipe.RequiredLevel then
			return false, string.format("Requires level %d.", recipe.RequiredLevel)
		end
	end

	if recipe.RequiresNearby then
		local nearStructure = context.WorldService.isNearStructure(
			player,
			recipe.RequiresNearby,
			getStructureRadius(recipe.RequiresNearby)
		)

		if not nearStructure then
			return false, string.format("Stand near a %s.", recipe.RequiresNearby)
		end
	end

	local ok, missingItemId = context.InventoryService.hasItems(player, recipe.Cost)
	if not ok then
		return false, missingItemMessage(missingItemId)
	end

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
	local cframe = CFrame.new(Vector3.new(position.X, 0.45, position.Z), Vector3.new(root.Position.X, 0.45, root.Position.Z))
	local model

	if itemId == "CampfireKit" then
		model = createCampfire(cframe)
	elseif itemId == "ShelterKit" then
		model = createShelter(cframe)
	elseif itemId == "RainCollectorKit" then
		model = createRainCollector(cframe)
	elseif itemId == "WorkbenchKit" then
		model = createWorkbench(cframe)
	elseif itemId == "ForgeKit" then
		model = createForge(cframe)
	elseif itemId == "SpikeTrapKit" then
		model = createSpikeTrap(cframe)
	elseif itemId == "SignalBeaconKit" then
		model = createSignalBeacon(cframe)
	end

	if not model then
		return false, "Nothing was built."
	end

	if model.Name == "SpikeTrap" or model.Name == "SignalBeacon" then
		model:SetAttribute("OwnerUserId", player.UserId)
	end

	context.InventoryService.removeItems(player, { [itemId] = 1 })
	model.Parent = context.WorldService.getStructuresFolder()
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
end

return CraftingService
