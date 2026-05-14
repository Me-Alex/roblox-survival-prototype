local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CraftingService = {}

local context

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
	end

	if not model then
		return false, "Nothing was built."
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

return CraftingService
