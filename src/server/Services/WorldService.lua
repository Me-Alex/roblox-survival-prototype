local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local WorldService = {}

local structuresFolder
local context
local random = Random.new(Config.World.Seed + 17)
local currentWeatherId = "Clear"
local day = 1
local wasNight = false

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

local function isNightAt(clockTime)
	return clockTime < Config.World.NightEnd or clockTime >= Config.World.NightStart
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

local function getWeatherConfig()
	return Config.Weather[currentWeatherId] or Config.Weather.Clear
end

local function chooseWeather()
	local totalWeight = 0

	for _, weatherConfig in pairs(Config.Weather) do
		totalWeight += weatherConfig.Weight or 1
	end

	local roll = random:NextNumber(0, totalWeight)
	local running = 0

	for weatherId, weatherConfig in pairs(Config.Weather) do
		running += weatherConfig.Weight or 1

		if roll <= running then
			return weatherId
		end
	end

	return "Clear"
end

local function getClockLabel()
	local clockTime = Lighting.ClockTime
	local hour = math.floor(clockTime)
	local minute = math.floor((clockTime - hour) * 60)
	return string.format("%02d:%02d", hour, minute)
end

function WorldService.getWorldState()
	local weather = getWeatherConfig()

	return {
		Day = day,
		Clock = getClockLabel(),
		IsNight = WorldService.isNight(),
		WeatherId = currentWeatherId,
		Weather = weather.DisplayName,
	}
end

function WorldService.sendWorldState(player)
	Remotes.get("WorldStateUpdated"):FireClient(player, WorldService.getWorldState())
end

function WorldService.broadcastWorldState()
	local state = WorldService.getWorldState()
	Remotes.get("WorldStateUpdated"):FireAllClients(state)
end

function WorldService.isNight()
	return isNightAt(Lighting.ClockTime)
end

function WorldService.getCurrentWeatherConfig()
	return getWeatherConfig()
end

function WorldService.getAmbientTemperature(player)
	local clockTime = Lighting.ClockTime
	local isNight = isNightAt(clockTime)
	local baseTemperature = isNight and 42 or 74
	local character = player.Character
	local weather = getWeatherConfig()

	baseTemperature += weather.TemperatureModifier or 0

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

function WorldService.init(newContext)
	context = newContext
	setupBaseWorld()
	wasNight = WorldService.isNight()

	task.spawn(function()
		local sendTimer = 0

		while true do
			local step = 24 / Config.World.DayLengthSeconds
			Lighting.ClockTime = (Lighting.ClockTime + step) % 24
			local isNight = WorldService.isNight()

			if wasNight and not isNight then
				day += 1

				if context and context.ObjectiveService then
					for _, player in ipairs(Players:GetPlayers()) do
						context.ObjectiveService.recordNightSurvived(player)
					end
				end
			end

			wasNight = isNight
			sendTimer += 1

			if sendTimer >= 5 then
				sendTimer = 0
				WorldService.broadcastWorldState()
			end

			task.wait(1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.World.WeatherIntervalSeconds)
			currentWeatherId = chooseWeather()
			WorldService.broadcastWorldState()
			Remotes.get("Notification"):FireAllClients(
				string.format("Weather shift: %s", getWeatherConfig().DisplayName)
			)
		end
	end)
end

function WorldService.playerAdded(player)
	WorldService.sendWorldState(player)
end

return WorldService
