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
}

local function randomGroundPosition()
	local half = Config.World.SpawnAreaHalfSize
	return Vector3.new(
		random:NextNumber(-half, half),
		1.6,
		random:NextNumber(-half, half)
	)
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

local function spawnResource(resourceId)
	local position = randomGroundPosition()

	if resourceId == "Tree" then
		createTree(position)
	elseif resourceId == "Rock" then
		createRock(position)
	elseif resourceId == "FiberPlant" then
		createFiberPlant(position)
	elseif resourceId == "BerryBush" then
		createBerryBush(position)
	end
end

function ResourceService.harvest(player, model, resourceId)
	local resourceConfig = Config.Resources[resourceId]
	if not resourceConfig or not model or not model.Parent then
		return
	end

	local inventory = context.InventoryService
	local amount = random:NextInteger(resourceConfig.MinAmount, resourceConfig.MaxAmount)

	if inventory.hasItem(player, "StoneAxe", 1) and (resourceId == "Tree" or resourceId == "FiberPlant") then
		amount += 1
	end

	inventory.addItem(player, resourceConfig.Reward, amount)
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

	for resourceId, resourceConfig in pairs(Config.Resources) do
		for _ = 1, resourceConfig.SpawnCount do
			spawnResource(resourceId)
		end
	end
end

return ResourceService
