local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)

local WorldService = {}

local structuresFolder

local function createPart(name, size, cframe, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function setupBaseWorld()
	local worldFolder = Workspace:FindFirstChild("SurvivalWorld")
	if not worldFolder then
		worldFolder = Instance.new("Folder")
		worldFolder.Name = "SurvivalWorld"
		worldFolder.Parent = Workspace
	end

	structuresFolder = worldFolder:FindFirstChild("Structures")
	if not structuresFolder then
		structuresFolder = Instance.new("Folder")
		structuresFolder.Name = "Structures"
		structuresFolder.Parent = worldFolder
	end

	if not worldFolder:FindFirstChild("Ground") then
		local ground = createPart(
			"Ground",
			Vector3.new(Config.World.SpawnAreaHalfSize * 2.35, 4, Config.World.SpawnAreaHalfSize * 2.35),
			CFrame.new(0, -2, 0),
			Color3.fromRGB(72, 104, 70),
			worldFolder
		)
		ground.Material = Enum.Material.Grass
	end

	if not Workspace:FindFirstChild("SurvivalSpawn") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SurvivalSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.CFrame = CFrame.new(0, Config.World.RespawnHeight, 0)
		spawn.Color = Color3.fromRGB(220, 210, 150)
		spawn.Material = Enum.Material.WoodPlanks
		spawn.Parent = Workspace
	end

	Lighting.ClockTime = 9
	Lighting.Brightness = 2
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.35
end

local function findNearbyStructure(character, modelName, radius)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not structuresFolder then
		return false
	end

	for _, structure in ipairs(structuresFolder:GetChildren()) do
		if structure.Name == modelName then
			local pivot = structure:GetPivot()
			if (pivot.Position - root.Position).Magnitude <= radius then
				return true
			end
		end
	end

	return false
end

function WorldService.getAmbientTemperature(player)
	local clockTime = Lighting.ClockTime
	local isNight = clockTime < 6 or clockTime > 18.5
	local baseTemperature = isNight and 42 or 74
	local character = player.Character

	if findNearbyStructure(character, "Campfire", Config.Buildables.CampfireKit.Radius) then
		baseTemperature = math.max(baseTemperature, 76)
	end

	if findNearbyStructure(character, "Shelter", Config.Buildables.ShelterKit.Radius) then
		baseTemperature = math.max(baseTemperature, 64)
	end

	return baseTemperature
end

function WorldService.isNearStructure(player, modelName, radius)
	return findNearbyStructure(player.Character, modelName, radius)
end

function WorldService.getStructuresFolder()
	return structuresFolder
end

function WorldService.init()
	setupBaseWorld()

	task.spawn(function()
		while true do
			local step = 24 / Config.World.DayLengthSeconds
			Lighting.ClockTime = (Lighting.ClockTime + step) % 24
			task.wait(1)
		end
	end)
end

return WorldService
