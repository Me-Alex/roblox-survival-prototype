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
local decorRandom = Random.new(Config.World.Seed + 503)
local currentWeatherId = "Clear"
local day = 1
local wasNight = false
local visitedRegionsByPlayer = {}

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

local function getRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getRegionForPosition(position)
	local nearestRegion
	local nearestDistance = math.huge

	for _, region in ipairs(Config.Regions) do
		local center = region.Center
		local flatOffset = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
		local distance = flatOffset.Magnitude

		if distance <= region.Radius and distance < nearestDistance then
			nearestRegion = region
			nearestDistance = distance
		end
	end

	return nearestRegion
end

local function getPlayerRegion(player)
	local root = getRoot(player)
	if not root then
		return nil
	end

	return getRegionForPosition(root.Position)
end

local function getDiscoverableRegion(player)
	local root = getRoot(player)
	if not root then
		return nil
	end

	for _, region in ipairs(Config.Regions) do
		local center = region.Center
		local flatOffset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
		local radius = region.DiscoveryRadius or Config.World.RegionDiscoveryRadius

		if flatOffset.Magnitude <= radius then
			return region
		end
	end

	return nil
end

local function setupLighting()
	Lighting.ClockTime = 9
	Lighting.Brightness = 2
	Lighting.EnvironmentDiffuseScale = 0.58
	Lighting.EnvironmentSpecularScale = 0.42
	Lighting.ColorShift_Top = Color3.fromRGB(255, 232, 190)
	Lighting.ColorShift_Bottom = Color3.fromRGB(102, 135, 119)

	if not Lighting:FindFirstChild("SurvivalAtmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "SurvivalAtmosphere"
		atmosphere.Density = 0.28
		atmosphere.Offset = 0.16
		atmosphere.Color = Color3.fromRGB(207, 224, 219)
		atmosphere.Decay = Color3.fromRGB(92, 112, 102)
		atmosphere.Glare = 0.12
		atmosphere.Haze = 1.25
		atmosphere.Parent = Lighting
	end

	if not Lighting:FindFirstChild("SurvivalSunRays") then
		local sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "SurvivalSunRays"
		sunRays.Intensity = 0.035
		sunRays.Spread = 0.82
		sunRays.Parent = Lighting
	end
end

local function createRegionSign(region, parent)
	local center = region.Center
	local signPosition = Vector3.new(center.X, 3.1, center.Z)
	local lookAt = Vector3.new(0, 3.1, 0)

	if (signPosition - lookAt).Magnitude < 1 then
		lookAt = signPosition + Vector3.new(0, 0, -1)
	end

	local sign = createPart(
		"RegionSign",
		Vector3.new(11, 5, 0.5),
		CFrame.new(signPosition, lookAt),
		Color3.fromRGB(63, 48, 34),
		parent
	)
	sign.Material = Enum.Material.WoodPlanks
	sign.CanCollide = false

	local surface = Instance.new("SurfaceGui")
	surface.Name = "RegionLabel"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 24
	surface.Parent = sign

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = string.upper(region.DisplayName)
	label.TextColor3 = Color3.fromRGB(245, 238, 205)
	label.TextScaled = true
	label.Parent = surface
end

local function createRegionLandmark(region, parent)
	local model = Instance.new("Model")
	model.Name = "Landmark_" .. region.Id
	model.Parent = parent

	local center = region.Center
	local color = region.Color or Color3.fromRGB(95, 110, 90)
	local base = createPart(
		"RegionGround",
		Vector3.new(region.Radius * 1.45, 0.2, region.Radius * 1.45),
		CFrame.new(center.X, 0.08, center.Z),
		color,
		model
	)
	base.Material = Enum.Material.Grass
	base.Transparency = 0.34
	base.CanCollide = false
	base.CanTouch = false
	base.CanQuery = false

	if region.Id == "PineRidge" then
		local trunk = createPart(
			"OldPine",
			Vector3.new(32, 6, 6),
			CFrame.new(center.X, 16, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(72, 48, 31),
			model
		)
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Material = Enum.Material.Wood

		local crown = createPart("RidgeCrown", Vector3.new(24, 24, 24), CFrame.new(center.X, 34, center.Z), Color3.fromRGB(28, 97, 50), model)
		crown.Shape = Enum.PartType.Ball
		crown.Material = Enum.Material.Grass
	elseif region.Id == "Stonebreak" then
		for offset = -1, 1, 2 do
			local pillar = createPart(
				"CliffPillar",
				Vector3.new(12, 24, 12),
				CFrame.new(center.X + offset * 18, 12, center.Z),
				Color3.fromRGB(87, 90, 88),
				model
			)
			pillar.Shape = Enum.PartType.Ball
			pillar.Material = Enum.Material.Slate
		end

		local cap = createPart("StoneArch", Vector3.new(44, 8, 10), CFrame.new(center.X, 29, center.Z), Color3.fromRGB(93, 96, 92), model)
		cap.Material = Enum.Material.Slate
	elseif region.Id == "Mirefen" then
		local pool = createPart("WetlandPool", Vector3.new(42, 0.5, 34), CFrame.new(center.X, 0.18, center.Z), Color3.fromRGB(56, 135, 148), model)
		pool.Material = Enum.Material.Glass
		pool.Transparency = 0.2
		pool.CanCollide = false

		for index = 1, 10 do
			local angle = (math.pi * 2) * (index / 10)
			local reed = createPart(
				"Reeds",
				Vector3.new(0.5, 7, 0.5),
				CFrame.new(center.X + math.cos(angle) * 24, 3.5, center.Z + math.sin(angle) * 18),
				Color3.fromRGB(88, 128, 72),
				model
			)
			reed.Material = Enum.Material.Grass
		end
	elseif region.Id == "OldCamp" then
		local floor = createPart("RuinedFloor", Vector3.new(24, 0.6, 18), CFrame.new(center.X, 0.4, center.Z), Color3.fromRGB(103, 74, 51), model)
		floor.Material = Enum.Material.WoodPlanks

		for offset = -1, 1, 2 do
			local wall = createPart(
				"BrokenWall",
				Vector3.new(1, 8, 18),
				CFrame.new(center.X + offset * 12, 4.2, center.Z),
				Color3.fromRGB(86, 58, 40),
				model
			)
			wall.Material = Enum.Material.Wood
		end
	elseif region.Id == "IronHighlands" then
		local spire = createPart("IronSpire", Vector3.new(14, 30, 14), CFrame.new(center.X, 15, center.Z), Color3.fromRGB(98, 82, 74), model)
		spire.Shape = Enum.PartType.Ball
		spire.Material = Enum.Material.Metal

		local vein = createPart("IronGlow", Vector3.new(2, 22, 2), CFrame.new(center.X, 16, center.Z - 7), Color3.fromRGB(190, 111, 72), model)
		vein.Material = Enum.Material.Neon
		vein.CanCollide = false
	else
		local marker = createPart("MeadowMarker", Vector3.new(9, 4, 9), CFrame.new(center.X, 2, center.Z), Color3.fromRGB(222, 204, 133), model)
		marker.Shape = Enum.PartType.Ball
		marker.Material = Enum.Material.Slate
	end

	createRegionSign(region, model)
end

local function createTrail(fromPosition, toPosition, parent)
	local start = Vector3.new(fromPosition.X, 0.14, fromPosition.Z)
	local finish = Vector3.new(toPosition.X, 0.14, toPosition.Z)
	local offset = finish - start
	local length = offset.Magnitude

	if length <= 1 then
		return
	end

	local segment = createPart(
		"Trail",
		Vector3.new(8, 0.14, length),
		CFrame.new(start + offset * 0.5, finish),
		Color3.fromRGB(106, 92, 66),
		parent
	)
	segment.Material = Enum.Material.Ground
	segment.Transparency = 0.18
	segment.CanCollide = false
	segment.CanTouch = false
	segment.CanQuery = false
end

local function setupLandmarks(worldFolder)
	if not worldFolder:FindFirstChild("BoundaryWater") then
		local water = createPart(
			"BoundaryWater",
			Vector3.new(Config.World.SpawnAreaHalfSize * 3.35, 1.2, Config.World.SpawnAreaHalfSize * 3.35),
			CFrame.new(0, -2.35, 0),
			Color3.fromRGB(58, 131, 156),
			worldFolder
		)
		water.CanCollide = false
		water.Material = Enum.Material.Glass
		water.Transparency = 0.18
	end

	local landmarks = worldFolder:FindFirstChild("Landmarks")
	if not landmarks then
		landmarks = Instance.new("Folder")
		landmarks.Name = "Landmarks"
		landmarks.Parent = worldFolder
	end

	if landmarks:FindFirstChild("Landmark_BaseMeadow") then
		return
	end

	for _, region in ipairs(Config.Regions) do
		createRegionLandmark(region, landmarks)

		if region.Id ~= "BaseMeadow" then
			createTrail(Vector3.new(0, 0, 0), region.Center, landmarks)
		end
	end

	for index = 1, 12 do
		local angle = (math.pi * 2) * (index / 12)
		local radius = 13
		local stone = createPart(
			"SpawnRingStone",
			Vector3.new(2.8, 1.1, 2.2),
			CFrame.new(math.cos(angle) * radius, 0.35, math.sin(angle) * radius)
				* CFrame.Angles(0, angle, decorRandom:NextNumber(-0.2, 0.2)),
			Color3.fromRGB(112, 116, 105),
			landmarks
		)
		stone.Shape = Enum.PartType.Ball
		stone.Material = Enum.Material.Slate
		stone.CanCollide = false
	end

	for index = 1, 24 do
		local angle = (math.pi * 2) * (index / 24) + decorRandom:NextNumber(-0.08, 0.08)
		local radius = Config.World.SpawnAreaHalfSize * decorRandom:NextNumber(0.92, 1.08)
		local boulder = createPart(
			"PerimeterBoulder",
			Vector3.new(
				decorRandom:NextNumber(5, 11),
				decorRandom:NextNumber(2.5, 6),
				decorRandom:NextNumber(5, 12)
			),
			CFrame.new(math.cos(angle) * radius, 0.8, math.sin(angle) * radius)
				* CFrame.Angles(0, decorRandom:NextNumber(0, math.pi), 0),
			Color3.fromRGB(86, 93, 88),
			landmarks
		)
		boulder.Shape = Enum.PartType.Ball
		boulder.Material = Enum.Material.Slate
	end

	for index = 1, 8 do
		local angle = decorRandom:NextNumber(0, math.pi * 2)
		local radius = decorRandom:NextNumber(35, Config.World.SpawnAreaHalfSize * 0.8)
		local log = createPart(
			"FallenLog",
			Vector3.new(decorRandom:NextNumber(3, 4.5), decorRandom:NextNumber(12, 18), 3),
			CFrame.new(math.cos(angle) * radius, 1.2, math.sin(angle) * radius)
				* CFrame.Angles(math.rad(90), decorRandom:NextNumber(0, math.pi), 0),
			Color3.fromRGB(90, 61, 42),
			landmarks
		)
		log.Shape = Enum.PartType.Cylinder
		log.Material = Enum.Material.Wood
	end
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

	setupLandmarks(worldFolder)

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

	setupLighting()
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

function WorldService.getWorldState(player)
	local weather = getWeatherConfig()
	local threat = nil
	local region = player and getPlayerRegion(player) or nil

	if context and context.EnemyService and context.EnemyService.getThreat then
		threat = context.EnemyService.getThreat()
	end

	return {
		Day = day,
		Clock = getClockLabel(),
		IsNight = WorldService.isNight(),
		WeatherId = currentWeatherId,
		Weather = weather.DisplayName,
		Threat = threat,
		Region = region and region.DisplayName or "Wilderness",
	}
end

function WorldService.sendWorldState(player)
	Remotes.get("WorldStateUpdated"):FireClient(player, WorldService.getWorldState(player))
end

function WorldService.broadcastWorldState()
	for _, player in ipairs(Players:GetPlayers()) do
		WorldService.sendWorldState(player)
	end
end

function WorldService.isNight()
	return isNightAt(Lighting.ClockTime)
end

function WorldService.getCurrentWeatherConfig()
	return getWeatherConfig()
end

function WorldService.getCurrentWeatherId()
	return currentWeatherId
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

function WorldService.getRegionForPosition(position)
	return getRegionForPosition(position)
end

function WorldService.getRegions()
	return Config.Regions
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
						if context.ProgressionService then
							context.ProgressionService.addXP(player, Config.Progression.XP.NightSurvived, "survived the night")
						end
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
			for _, player in ipairs(Players:GetPlayers()) do
				local region = getDiscoverableRegion(player)

				if region then
					local visited = visitedRegionsByPlayer[player]
					if not visited then
						visited = {}
						visitedRegionsByPlayer[player] = visited
					end

					if not visited[region.Id] then
						visited[region.Id] = true
						Remotes.get("Notification"):FireClient(player, string.format("Discovered: %s", region.DisplayName))

						if context.ObjectiveService then
							context.ObjectiveService.recordRegionDiscovered(player)
						end

						if context.ProgressionService then
							context.ProgressionService.addXP(player, Config.Progression.XP.RegionDiscovered, "region discovered")
						end
					end
				end

				WorldService.sendWorldState(player)
			end

			task.wait(2)
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

function WorldService.playerRemoving(player)
	visitedRegionsByPlayer[player] = nil
end

return WorldService
