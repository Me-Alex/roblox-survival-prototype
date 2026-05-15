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
local lastRegionIdByPlayer = {}
local structuresByName = {}
local structureIndexBound = false
local sessionStartedAt = os.clock()
local worldPerformance = (Config.World and Config.World.Performance) or {}
local LANDMARK_DETAIL_MULTIPLIER = math.clamp(tonumber(worldPerformance.LandmarkDetailMultiplier) or 1, 0.3, 1)
local MAX_LANDMARK_POINT_LIGHTS = math.max(4, math.floor(tonumber(worldPerformance.MaxLandmarkPointLights) or 9999))
local ENABLE_WORLD_POST_EFFECTS = worldPerformance.EnableWorldPostEffects ~= false
local USE_FUTURE_LIGHTING = worldPerformance.UseFutureLighting == true
local TONE_DOWN_SMOOTH_SURFACES = worldPerformance.ToneDownSmoothSurfaces ~= false

local EARLY_WEATHER_WINDOW_SECONDS = 10 * 60
local EARLY_WEATHER_WEIGHTS = {
	Clear = 6,
	Rain = 2,
}

local function cloneMap(source)
	local copy = {}

	if type(source) ~= "table" then
		return copy
	end

	for key, value in pairs(source) do
		copy[key] = value
	end

	return copy
end

local function markPlayerDirty(player)
	if context and context.PersistenceService then
		context.PersistenceService.markPlayerDirty(player)
	end
end

local function detailCount(baseCount, minimumCount)
	local base = math.max(0, math.floor(tonumber(baseCount) or 0))
	if base <= 0 then
		return 0
	end

	local minimum = math.max(1, math.floor(tonumber(minimumCount) or 1))
	local scaled = math.floor(base * LANDMARK_DETAIL_MULTIPLIER + 0.5)
	return math.max(minimum, scaled)
end

local function indexStructure(structure)
	if not structure or not structure:IsA("Model") then
		return
	end

	local bucket = structuresByName[structure.Name]
	if not bucket then
		bucket = {}
		structuresByName[structure.Name] = bucket
	end

	bucket[structure] = true
end

local function unindexStructure(structure)
	if not structure then
		return
	end

	local bucket = structuresByName[structure.Name]
	if not bucket then
		return
	end

	bucket[structure] = nil
	if next(bucket) == nil then
		structuresByName[structure.Name] = nil
	end
end

local function rebuildStructureIndex()
	structuresByName = {}

	if not structuresFolder then
		return
	end

	for _, child in ipairs(structuresFolder:GetChildren()) do
		indexStructure(child)
	end
end

local function getStructuresByName(modelName)
	local bucket = structuresByName[modelName]
	local structures = {}

	if not bucket then
		return structures
	end

	for structure in pairs(bucket) do
		if structure.Parent then
			table.insert(structures, structure)
		else
			bucket[structure] = nil
		end
	end

	if next(bucket) == nil then
		structuresByName[modelName] = nil
	end

	return structures
end

-- ═══════════════════════════════════════════════════════
-- VOLCANIC ISLAND — colour palette & theme
-- ═══════════════════════════════════════════════════════
local FORTRESS_THEME = {
	-- stone / rock
	Stone          = Color3.fromRGB(62, 58, 55),
	DarkStone      = Color3.fromRGB(32, 28, 26),
	WeatheredStone = Color3.fromRGB(98, 92, 84),
	TrimStone      = Color3.fromRGB(140, 124, 98),
	Shadow         = Color3.fromRGB(14, 10, 8),
	-- wood / organic
	Path           = Color3.fromRGB(88, 72, 52),
	Roof           = Color3.fromRGB(72, 44, 28),
	Wood           = Color3.fromRGB(64, 38, 22),
	FreshWood      = Color3.fromRGB(96, 60, 30),
	Canvas         = Color3.fromRGB(158, 112, 58),
	CanvasDark     = Color3.fromRGB(68, 46, 32),
	Mud            = Color3.fromRGB(55, 40, 28),
	-- fire & lava
	Smoke          = Color3.fromRGB(42, 38, 36),
	Ember          = Color3.fromRGB(238, 80, 28),
	LavaGlow       = Color3.fromRGB(255, 120, 0),
	Torch          = Color3.fromRGB(255, 148, 40),
	MoltenRock     = Color3.fromRGB(180, 58, 14),
	Obsidian       = Color3.fromRGB(22, 18, 26),
	AshGrey        = Color3.fromRGB(88, 82, 78),
	-- nature
	Grass          = Color3.fromRGB(38, 72, 40),
	DryGrass       = Color3.fromRGB(96, 88, 52),
	TropicalLeaf   = Color3.fromRGB(28, 86, 50),
	-- water
	Water          = Color3.fromRGB(28, 96, 124),
	DeepWater      = Color3.fromRGB(14, 52, 78),
	ToxicWater     = Color3.fromRGB(52, 118, 62),
	-- market
	MarketBlue     = Color3.fromRGB(52, 102, 138),
	MarketRed      = Color3.fromRGB(148, 54, 40),
	MarketGold     = Color3.fromRGB(194, 148, 52),
	-- special
	Reed           = Color3.fromRGB(78, 102, 52),
	Crystal        = Color3.fromRGB(88, 148, 172),
	Relic          = Color3.fromRGB(108, 88, 158),
	BoneWhite      = Color3.fromRGB(208, 196, 178),
	IceBlue        = Color3.fromRGB(148, 186, 210),
	PoisonGreen    = Color3.fromRGB(72, 148, 52),
	SulfurYellow   = Color3.fromRGB(188, 172, 28),
}

-- Routes between the 8 new volcanic island regions
local MAP_ROUTES = {
	{ "CinderHarbour",    "AshwoodHollow"   },
	{ "CinderHarbour",    "SaltcragShores"  },
	{ "CinderHarbour",    "ScorchPitQuarry" },
	{ "CinderHarbour",    "BrimstoneMarsh"  },
	{ "AshwoodHollow",    "GlacierScar"     },
	{ "SaltcragShores",   "GlacierScar"     },
	{ "ScorchPitQuarry",  "DeadMansCaldera" },
	{ "BrimstoneMarsh",   "MoltenSpireHold" },
	{ "GlacierScar",      "DeadMansCaldera" },
	{ "DeadMansCaldera",  "MoltenSpireHold" },
	{ "ScorchPitQuarry",  "BrimstoneMarsh"  },
	{ "MoltenSpireHold",  "SaltcragShores"  },
}

local LANDMARK_THEME_VERSION = "volcanic-isle-v1"
local TERRAIN_THEME_VERSION = "volcanic-isle-terrain-v1"

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function smoothStep(minValue, maxValue, value)
	if value <= minValue then
		return 0
	end
	if value >= maxValue then
		return 1
	end
	local alpha = (value - minValue) / (maxValue - minValue)
	return alpha * alpha * (3 - 2 * alpha)
end

local function createPart(name, size, cframe, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = TONE_DOWN_SMOOTH_SURFACES and Enum.Material.Plastic or Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function sampleTerrainHeight(x, z)
	local terrainConfig = Config.World.Terrain
	if not terrainConfig or terrainConfig.Enabled == false then
		return 0
	end

	local seed = Config.World.Seed
	local primaryScale = terrainConfig.PrimaryNoiseScale or 178
	local secondaryScale = terrainConfig.SecondaryNoiseScale or 68
	local primary = math.noise((x + seed * 13.7) / primaryScale, (z - seed * 7.9) / primaryScale, seed * 0.013)
	local secondary = math.noise((x - seed * 5.4) / secondaryScale, (z + seed * 9.2) / secondaryScale, seed * 0.027)
	local height = primary * (terrainConfig.PrimaryAmplitude or 15) + secondary * (terrainConfig.SecondaryAmplitude or 7)

	local extent = Config.World.SpawnAreaHalfSize * (terrainConfig.MeshExtentScale or 1.22)
	local edgeRatio = clamp(Vector3.new(x, 0, z).Magnitude / math.max(extent, 1), 0, 1)
	height -= (terrainConfig.EdgeFalloff or 10) * edgeRatio * edgeRatio

	local spawnPoint = Config.World.SpawnPoint or Vector3.new(0, 0, 0)
	local spawnDistance = (Vector3.new(x, 0, z) - Vector3.new(spawnPoint.X, 0, spawnPoint.Z)).Magnitude
	local spawnFlattenRadius = terrainConfig.SpawnFlattenRadius or 120
	local flattenWeight = 1 - smoothStep(spawnFlattenRadius * 0.4, spawnFlattenRadius, spawnDistance)
	local flattenTarget = spawnPoint.Y

	local regionFlattenRadius = terrainConfig.RegionFlattenRadius or 58
	for _, region in ipairs(Config.Regions) do
		local center = region.Center
		local regionDistance = (Vector3.new(x, 0, z) - Vector3.new(center.X, 0, center.Z)).Magnitude
		local regionWeight = 1 - smoothStep(regionFlattenRadius * 0.35, regionFlattenRadius, regionDistance)
		if regionWeight > flattenWeight then
			flattenWeight = regionWeight
			flattenTarget = center.Y
		end
	end

	height = height * (1 - flattenWeight) + flattenTarget * flattenWeight

	return clamp(
		height,
		terrainConfig.HeightClampMin or -8,
		terrainConfig.HeightClampMax or 30
	)
end

local function getTerrainColor(height)
	-- volcanic island: scorched peaks, obsidian midlands, ash flats, coastal sand
	if height >= 26 then
		return Color3.fromRGB(38, 32, 28), Enum.Material.Slate       -- dark volcanic summit rock
	end
	if height >= 14 then
		return Color3.fromRGB(58, 48, 42), Enum.Material.Slate       -- obsidian midland
	end
	if height >= 4 then
		return Color3.fromRGB(72, 62, 52), Enum.Material.Ground      -- ash-covered earth
	end
	if height <= -3 then
		return Color3.fromRGB(118, 104, 80), Enum.Material.Sand      -- coastal sand
	end
	if height <= 1 then
		return Color3.fromRGB(52, 68, 48), Enum.Material.Grass       -- low coastal scrub
	end
	return Color3.fromRGB(42, 58, 36), Enum.Material.Grass           -- sparse volcanic grass
end

local function setupTerrain(worldFolder)
	local terrainConfig = Config.World.Terrain
	if not terrainConfig or terrainConfig.Enabled == false then
		return
	end

	local terrainFolder = worldFolder:FindFirstChild("TerrainMesh")
	if not terrainFolder then
		terrainFolder = Instance.new("Folder")
		terrainFolder.Name = "TerrainMesh"
		terrainFolder.Parent = worldFolder
	end

	if terrainFolder:GetAttribute("ThemeVersion") == TERRAIN_THEME_VERSION and terrainFolder:GetAttribute("TerrainMode") == "SmoothTerrain" then
		return
	end

	for _, child in ipairs(terrainFolder:GetChildren()) do
		child:Destroy()
	end

	terrainFolder:SetAttribute("ThemeVersion", TERRAIN_THEME_VERSION)
	terrainFolder:SetAttribute("TerrainMode", "SmoothTerrain")

	local terrain = Workspace.Terrain
	terrain:Clear()
	pcall(function()
		terrain.Decoration = true
		terrain.WaterColor = FORTRESS_THEME.Water
		terrain.WaterTransparency = 0.22
		terrain.WaterReflectance = 0.12
		terrain.WaterWaveSize = 0.18
		terrain.WaterWaveSpeed = 6
	end)

	local resolution = math.max(4, terrainConfig.SmoothResolution or 4)
	local extent = Config.World.SpawnAreaHalfSize * (terrainConfig.MeshExtentScale or 1.22)
	local maxCoord = math.floor(extent / resolution) * resolution
	local minCoord = -maxCoord
	local floorY = math.floor(((terrainConfig.HeightClampMin or -8) - 36) / resolution) * resolution
	local ceilingY = math.ceil(((terrainConfig.HeightClampMax or 30) + 20) / resolution) * resolution
	local xCellCount = math.floor((maxCoord - minCoord) / resolution)
	local yCellCount = math.floor((ceilingY - floorY) / resolution)
	local zCellCount = xCellCount
	local chunkCells = 32

	for xStartCell = 1, xCellCount, chunkCells do
		local xEndCell = math.min(xStartCell + chunkCells - 1, xCellCount)
		local chunkXCells = xEndCell - xStartCell + 1
		local chunkMinX = minCoord + (xStartCell - 1) * resolution
		local chunkMaxX = chunkMinX + chunkXCells * resolution
		local heights = {}
		local terrainMaterials = {}

		for xIndex = 1, chunkXCells do
			local worldX = chunkMinX + (xIndex - 0.5) * resolution
			heights[xIndex] = {}
			terrainMaterials[xIndex] = {}

			for zIndex = 1, zCellCount do
				local worldZ = minCoord + (zIndex - 0.5) * resolution
				local topY = sampleTerrainHeight(worldX, worldZ)
				local _, material = getTerrainColor(topY)
				heights[xIndex][zIndex] = topY
				terrainMaterials[xIndex][zIndex] = material
			end
		end

		local materials = {}
		local occupancies = {}

		for xIndex = 1, chunkXCells do
			materials[xIndex] = {}
			occupancies[xIndex] = {}

			for yIndex = 1, yCellCount do
				local cellBottom = floorY + (yIndex - 1) * resolution
				local cellTop = cellBottom + resolution
				materials[xIndex][yIndex] = {}
				occupancies[xIndex][yIndex] = {}

				for zIndex = 1, zCellCount do
					local topY = heights[xIndex][zIndex]
					local occupancy = 0

					if cellTop <= topY then
						occupancy = 1
					elseif cellBottom < topY then
						occupancy = clamp((topY - cellBottom) / resolution, 0.08, 1)
					end

					occupancies[xIndex][yIndex][zIndex] = occupancy
					materials[xIndex][yIndex][zIndex] = occupancy > 0 and terrainMaterials[xIndex][zIndex] or Enum.Material.Air
				end
			end
		end

		local region = Region3.new(
			Vector3.new(chunkMinX, floorY, minCoord),
			Vector3.new(chunkMaxX, ceilingY, maxCoord)
		):ExpandToGrid(resolution)
		terrain:WriteVoxels(region, resolution, materials, occupancies)
	end
end

local function createGrassClump(position, parent)
	for blade = 1, 5 do
		local angle = (math.pi * 2) * (blade / 5) + decorRandom:NextNumber(-0.2, 0.2)
		local height = decorRandom:NextNumber(1.8, 3.3)
		local grass = createPart(
			"GroundGrassBlade",
			Vector3.new(0.16, height, 0.24),
			CFrame.new(
				position.X + math.cos(angle) * decorRandom:NextNumber(0.1, 0.55),
				position.Y + height * 0.5,
				position.Z + math.sin(angle) * decorRandom:NextNumber(0.1, 0.55)
			) * CFrame.Angles(decorRandom:NextNumber(-0.18, 0.18), angle, decorRandom:NextNumber(-0.3, 0.3)),
			blade % 2 == 0 and Color3.fromRGB(61, 104, 54) or Color3.fromRGB(45, 83, 47),
			parent
		)
		grass.Material = Enum.Material.Grass
		grass.CanCollide = false
		grass.CanTouch = false
		grass.CanQuery = false
	end
end

local function createLeafLitter(position, parent)
	local patch = createPart(
		"LeafLitterPatch",
		Vector3.new(decorRandom:NextNumber(2.5, 5.5), 0.08, decorRandom:NextNumber(1.6, 4.2)),
		CFrame.new(position.X, position.Y + 0.06, position.Z) * CFrame.Angles(0, decorRandom:NextNumber(0, math.pi), 0),
		decorRandom:NextNumber() > 0.5 and Color3.fromRGB(92, 67, 42) or Color3.fromRGB(63, 55, 37),
		parent
	)
	patch.Material = Enum.Material.Ground
	patch.Transparency = 0.14
	patch.CanCollide = false
	patch.CanTouch = false
	patch.CanQuery = false
end

local function getSpawnPoint()
	local spawnPoint = Config.World.SpawnPoint or Vector3.new(0, 0, 0)
	return Vector3.new(spawnPoint.X, spawnPoint.Y, spawnPoint.Z)
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
	-- Volcanic island atmosphere: dark orange-red skies, thick ash haze
	Lighting.ClockTime = 9.2
	Lighting.Brightness = 1.85
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.55
	Lighting.Ambient = Color3.fromRGB(58, 44, 34)
	Lighting.OutdoorAmbient = Color3.fromRGB(94, 72, 52)
	Lighting.EnvironmentDiffuseScale = 0.52
	Lighting.EnvironmentSpecularScale = TONE_DOWN_SMOOTH_SURFACES and 0.14 or 0.32
	Lighting.ColorShift_Top = Color3.fromRGB(255, 178, 88)   -- warm ash-orange sun
	Lighting.ColorShift_Bottom = Color3.fromRGB(64, 44, 36)  -- dark volcanic shadow

	pcall(function()
		Lighting.Technology = USE_FUTURE_LIGHTING and Enum.Technology.Future or Enum.Technology.ShadowMap
	end)

	-- Thick volcanic ash atmosphere
	local atmosphere = Lighting:FindFirstChild("SurvivalAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "SurvivalAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.58
	atmosphere.Offset = 0.22
	atmosphere.Color = Color3.fromRGB(172, 122, 72)     -- ash-orange haze
	atmosphere.Decay = Color3.fromRGB(68, 44, 32)
	atmosphere.Glare = 0.32
	atmosphere.Haze = 3.4

	local sunRays = Lighting:FindFirstChild("SurvivalSunRays")
	if not sunRays then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "SurvivalSunRays"
		sunRays.Parent = Lighting
	end
	sunRays.Intensity = 0.09
	sunRays.Spread = 0.88
	sunRays.Enabled = ENABLE_WORLD_POST_EFFECTS

	local bloom = Lighting:FindFirstChild("SurvivalBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "SurvivalBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.38   -- dramatic lava bloom
	bloom.Size = 28
	bloom.Threshold = 0.95
	bloom.Enabled = ENABLE_WORLD_POST_EFFECTS

	local depthOfField = Lighting:FindFirstChild("SurvivalDepthOfField")
	if not depthOfField then
		depthOfField = Instance.new("DepthOfFieldEffect")
		depthOfField.Name = "SurvivalDepthOfField"
		depthOfField.Parent = Lighting
	end
	depthOfField.FarIntensity = 0.14
	depthOfField.FocusDistance = 70
	depthOfField.InFocusRadius = 55
	depthOfField.NearIntensity = 0
	depthOfField.Enabled = ENABLE_WORLD_POST_EFFECTS

	local colorGrade = Lighting:FindFirstChild("SurvivalColorGrade") or Lighting:FindFirstChild("FortressColorGrade")
	if not colorGrade then
		colorGrade = Instance.new("ColorCorrectionEffect")
		colorGrade.Parent = Lighting
	end
	colorGrade.Name = "SurvivalColorGrade"
	colorGrade.Brightness = -0.06
	colorGrade.Contrast = 0.28
	colorGrade.Saturation = 0.12
	colorGrade.TintColor = Color3.fromRGB(255, 218, 172)   -- warm volcanic tint
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

local function createTorch(cframe, parent)
	local post = createPart("TorchPost", Vector3.new(0.45, 4, 0.45), cframe * CFrame.new(0, 2, 0), FORTRESS_THEME.Wood, parent)
	post.Material = Enum.Material.Wood
	post.CanCollide = false

	local flame = createPart("TorchFlame", Vector3.new(0.9, 1.1, 0.9), cframe * CFrame.new(0, 4.35, 0), FORTRESS_THEME.Torch, parent)
	flame.Shape = Enum.PartType.Ball
	flame.Material = Enum.Material.Neon
	flame.CanCollide = false
	flame.CanQuery = false

	local light = Instance.new("PointLight")
	light.Name = "TorchLight"
	light.Brightness = 1.5
	light.Range = 18
	light.Color = Color3.fromRGB(255, 157, 76)
	light.Parent = flame
end

local function createEmberWindow(cframe, parent, size)
	local window = createPart(
		"EmberWindow",
		size or Vector3.new(0.35, 2.8, 2.2),
		cframe,
		FORTRESS_THEME.Ember,
		parent
	)
	window.Material = Enum.Material.Neon
	window.CanCollide = false

	local light = Instance.new("PointLight")
	light.Name = "HearthGlow"
	light.Brightness = 0.6
	light.Range = 14
	light.Color = Color3.fromRGB(255, 126, 64)
	light.Parent = window
end

local function createBattlementWall(name, cframe, length, height, parent, depth)
	depth = depth or 5

	local wall = createPart(
		name,
		Vector3.new(length, height, depth),
		cframe,
		FORTRESS_THEME.Stone,
		parent
	)
	wall.Material = Enum.Material.Slate

	local merlonCount = math.max(3, math.floor(length / 8))
	for index = 1, merlonCount do
		local alpha = (index - 0.5) / merlonCount - 0.5
		local merlon = createPart(
			"Merlon",
			Vector3.new(3.2, 3.6, depth + 0.6),
			cframe * CFrame.new(alpha * length, height * 0.5 + 1.8, 0),
			FORTRESS_THEME.WeatheredStone,
			parent
		)
		merlon.Material = Enum.Material.Slate
	end

	return wall
end

local function createTowerCrenellations(cframe, width, height, parent)
	local edge = width * 0.5 + 0.25
	local topY = height * 0.5 + 3
	local placements = {
		{ -edge, -edge, 2.8, 2.8 },
		{ edge, -edge, 2.8, 2.8 },
		{ -edge, edge, 2.8, 2.8 },
		{ edge, edge, 2.8, 2.8 },
		{ 0, -edge, 4.2, 2.5 },
		{ 0, edge, 4.2, 2.5 },
		{ -edge, 0, 2.5, 4.2 },
		{ edge, 0, 2.5, 4.2 },
	}

	for _, placement in ipairs(placements) do
		local merlon = createPart(
			"TowerMerlon",
			Vector3.new(placement[3], 3.2, placement[4]),
			cframe * CFrame.new(placement[1], topY, placement[2]),
			FORTRESS_THEME.TrimStone,
			parent
		)
		merlon.Material = Enum.Material.Slate
	end
end

local function createFortressTower(name, cframe, width, height, parent)
	local tower = createPart(name, Vector3.new(width, height, width), cframe, FORTRESS_THEME.DarkStone, parent)
	tower.Material = Enum.Material.Slate

	local plinth = createPart(
		name .. "Plinth",
		Vector3.new(width + 4.5, 2.2, width + 4.5),
		cframe * CFrame.new(0, -height * 0.5 + 1.1, 0),
		FORTRESS_THEME.Stone,
		parent
	)
	plinth.Material = Enum.Material.Cobblestone

	local cap = createPart(
		name .. "Cap",
		Vector3.new(width + 3.5, 3, width + 3.5),
		cframe * CFrame.new(0, height * 0.5 + 1.5, 0),
		FORTRESS_THEME.WeatheredStone,
		parent
	)
	cap.Material = Enum.Material.Slate

	for _, bandY in ipairs({ height * 0.24, height * 0.52, height * 0.78 }) do
		local band = createPart(
			name .. "StoneBand",
			Vector3.new(width + 1.4, 1.2, width + 1.4),
			cframe * CFrame.new(0, -height * 0.5 + bandY, 0),
			FORTRESS_THEME.WeatheredStone,
			parent
		)
		band.Material = Enum.Material.Slate
	end

	for _, windowY in ipairs({ height * 0.4, height * 0.66 }) do
		local localY = -height * 0.5 + windowY

		if windowY < height - 4 then
			for side = -1, 1, 2 do
				createEmberWindow(cframe * CFrame.new(side * (width * 0.5 + 0.03), localY, 0), parent)
				createEmberWindow(
					cframe * CFrame.new(0, localY, side * (width * 0.5 + 0.03)) * CFrame.Angles(0, math.rad(90), 0),
					parent
				)
			end
		end
	end

	createTowerCrenellations(cframe, width, height, parent)
	return tower
end

local function createSteppedRoof(name, cframe, footprint, levels, parent)
	for level = 1, levels do
		local inset = (level - 1) * 2.4
		local roof = createPart(
			name .. "RoofTier",
			Vector3.new(math.max(5, footprint.X - inset), 1.2, math.max(5, footprint.Z - inset)),
			cframe * CFrame.new(0, (level - 1) * 1.1, 0),
			FORTRESS_THEME.Roof,
			parent
		)
		roof.Material = Enum.Material.WoodPlanks
	end
end

local function createFortressBuilding(name, cframe, width, height, depth, parent)
	local body = createPart(
		name,
		Vector3.new(width, height, depth),
		cframe * CFrame.new(0, height * 0.5, 0),
		FORTRESS_THEME.Stone,
		parent
	)
	body.Material = Enum.Material.Slate

	createSteppedRoof(name, cframe * CFrame.new(0, height + 1.2, 0), Vector3.new(width + 3.5, 0, depth + 3.5), 3, parent)

	for side = -1, 1, 2 do
		createEmberWindow(cframe * CFrame.new(side * (width * 0.5 + 0.03), height * 0.55, 0), parent, Vector3.new(0.3, 2.2, 1.8))
	end

	return body
end

local function createGatehouse(cframe, parent)
	createFortressTower("SouthGateTowerWest", cframe * CFrame.new(-15, 14, 0), 12, 28, parent)
	createFortressTower("SouthGateTowerEast", cframe * CFrame.new(15, 14, 0), 12, 28, parent)

	local lintel = createPart(
		"SouthGateLintel",
		Vector3.new(20, 7, 6),
		cframe * CFrame.new(0, 18, 0),
		FORTRESS_THEME.WeatheredStone,
		parent
	)
	lintel.Material = Enum.Material.Slate

	for x = -2, 2 do
		local bar = createPart(
			"OpenPortcullisBar",
			Vector3.new(0.35, 9, 0.35),
			cframe * CFrame.new(x * 2, 8, -2.8),
			Color3.fromRGB(55, 54, 51),
			parent
		)
		bar.Material = Enum.Material.Metal
		bar.CanCollide = false
	end

	createTorch(cframe * CFrame.new(-7.5, 0, -4), parent)
	createTorch(cframe * CFrame.new(7.5, 0, -4), parent)
end

local function createFortressRuin(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)
	local spawnPoint = getSpawnPoint()
	local spawnLocal = Vector3.new(spawnPoint.X - center.X, 0, spawnPoint.Z - center.Z)

	local courtyard = createPart(
		"CitadelCourtyard",
		Vector3.new(94, 0.45, 84),
		baseCFrame * CFrame.new(0, 0.24, 0),
		Color3.fromRGB(89, 86, 80),
		parent
	)
	courtyard.Material = Enum.Material.Cobblestone

	local gateRoad = createPart("GateRoad", Vector3.new(13, 0.34, 68), baseCFrame * CFrame.new(0, 0.45, 9), FORTRESS_THEME.Path, parent)
	gateRoad.Material = Enum.Material.Cobblestone

	local crossRoad = createPart("CrossRoad", Vector3.new(70, 0.32, 10), baseCFrame * CFrame.new(0, 0.47, 13), FORTRESS_THEME.Path, parent)
	crossRoad.Material = Enum.Material.Cobblestone

	local spawnPlaza = createPart(
		"CitadelSpawnPlaza",
		Vector3.new(22, 0.38, 18),
		CFrame.new(spawnPoint.X, 0.55, spawnPoint.Z),
		FORTRESS_THEME.TrimStone,
		parent
	)
	spawnPlaza.Material = Enum.Material.Cobblestone

	createBattlementWall("NorthCurtainWall", baseCFrame * CFrame.new(0, 9, -38), 88, 18, parent)
	createBattlementWall("SouthCurtainWest", baseCFrame * CFrame.new(-31, 6.5, 37), 28, 13, parent)
	createBattlementWall("SouthCurtainEast", baseCFrame * CFrame.new(31, 6.5, 37), 28, 13, parent)
	createBattlementWall("WestCurtainWall", baseCFrame * CFrame.new(-44, 8, 0) * CFrame.Angles(0, math.rad(90), 0), 76, 16, parent)
	createBattlementWall("EastBrokenWallNorth", baseCFrame * CFrame.new(44, 7, -18) * CFrame.Angles(0, math.rad(90), 0), 36, 14, parent)
	createBattlementWall("EastBrokenWallSouth", baseCFrame * CFrame.new(44, 5.5, 21) * CFrame.Angles(0, math.rad(90), 0), 28, 11, parent)
	createGatehouse(baseCFrame * CFrame.new(0, 0, 37), parent)

	for _, towerData in ipairs({
		{ "NorthWestTower", -44, -38, 15, 34 },
		{ "NorthEastTower", 44, -38, 15, 34 },
		{ "WestForwardTower", -44, 37, 13, 26 },
		{ "BrokenEastTower", 44, 37, 13, 20 },
	}) do
		createFortressTower(
			towerData[1],
			baseCFrame * CFrame.new(towerData[2], towerData[5] * 0.5, towerData[3]),
			towerData[4],
			towerData[5],
			parent
		)
	end

	local keep = createFortressTower("CentralKeep", baseCFrame * CFrame.new(0, 29, -12), 24, 58, parent)
	keep.Color = Color3.fromRGB(68, 65, 60)

	createSteppedRoof("KeepStepped", baseCFrame * CFrame.new(0, 60.5, -12), Vector3.new(34, 0, 34), 4, parent)

	for level = 1, 3 do
		local band = createPart(
			"KeepStoneBand",
			Vector3.new(25 + level * 4, 2.2, 25 + level * 4),
			baseCFrame * CFrame.new(0, 16 + level * 12, -12),
			FORTRESS_THEME.WeatheredStone,
			parent
		)
		band.Material = Enum.Material.Slate
	end

	for side = -1, 1, 2 do
		createEmberWindow(baseCFrame * CFrame.new(side * 12.2, 24, -17), parent)
		createEmberWindow(baseCFrame * CFrame.new(side * 12.2, 42, -7), parent)
	end

	local doorway = createPart(
		"KeepDoorShadow",
		Vector3.new(9, 12, 0.45),
		baseCFrame * CFrame.new(0, 6.4, 0.25),
		FORTRESS_THEME.Shadow,
		parent
	)
	doorway.Material = TONE_DOWN_SMOOTH_SURFACES and Enum.Material.Plastic or Enum.Material.SmoothPlastic
	doorway.CanCollide = false

	createFortressBuilding("BarracksWest", baseCFrame * CFrame.new(-25, 0, 13), 18, 13, 17, parent)
	createFortressBuilding("SmithyEast", baseCFrame * CFrame.new(25, 0, 12), 19, 12, 18, parent)
	createFortressBuilding("ChapelRuin", baseCFrame * CFrame.new(-21, 0, -21), 15, 16, 14, parent)

	for _, torchOffset in ipairs({
		Vector3.new(-8, 0, 3),
		Vector3.new(8, 0, 3),
		Vector3.new(-16, 0, 23),
		Vector3.new(16, 0, 23),
		Vector3.new(-34, 0, -28),
		Vector3.new(34, 0, -28),
	}) do
		createTorch(baseCFrame * CFrame.new(torchOffset.X, torchOffset.Y, torchOffset.Z), parent)
	end

	for index = 1, detailCount(34, 14) do
		local rubbleX = decorRandom:NextNumber(-39, 39)
		local rubbleZ = decorRandom:NextNumber(-33, 33)
		local awayFromSpawn = math.abs(rubbleX - spawnLocal.X) > 12 or math.abs(rubbleZ - spawnLocal.Z) > 10

		if awayFromSpawn then
			local rubble = createPart(
				"CastleRubble",
				Vector3.new(
					decorRandom:NextNumber(1.3, 3.6),
					decorRandom:NextNumber(0.8, 2.4),
					decorRandom:NextNumber(1.2, 3.4)
				),
				baseCFrame * CFrame.new(rubbleX, 0.8, rubbleZ)
					* CFrame.Angles(0, decorRandom:NextNumber(0, math.pi), decorRandom:NextNumber(-0.25, 0.25)),
				index % 3 == 0 and FORTRESS_THEME.DarkStone or FORTRESS_THEME.WeatheredStone,
				parent
			)
			rubble.Material = Enum.Material.Slate
			rubble.CanCollide = false
		end
	end
end

local function createTallPine(cframe, parent, scale)
	scale = scale or 1

	local trunk = createPart(
		"PineTrunk",
		Vector3.new(1.6 * scale, 18 * scale, 1.6 * scale),
		cframe * CFrame.new(0, 9 * scale, 0),
		Color3.fromRGB(70, 47, 30),
		parent
	)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Material = Enum.Material.Wood
	trunk.CanCollide = false

	for tier = 1, 4 do
		local width = (22 - tier * 3.2) * scale
		local crown = createPart(
			"PineBoughs",
			Vector3.new(width, 8 * scale, width),
			cframe * CFrame.new(0, (12 + tier * 5) * scale, 0),
			Color3.fromRGB(34, 82, 48),
			parent
		)
		crown.Shape = Enum.PartType.Ball
		crown.Material = Enum.Material.Grass
		crown.CanCollide = false
	end
end

local function createLog(cframe, length, parent)
	local log = createPart(
		"StackedLog",
		Vector3.new(2.4, length, 2.4),
		cframe,
		FORTRESS_THEME.FreshWood,
		parent
	)
	log.Shape = Enum.PartType.Cylinder
	log.Material = Enum.Material.Wood
	log.CanCollide = false
	return log
end

local function createCampfireScene(cframe, parent)
	local base = createPart("CampfireAsh", Vector3.new(11, 0.2, 11), cframe * CFrame.new(0, 0.12, 0), Color3.fromRGB(54, 47, 40), parent)
	base.Material = Enum.Material.Ground
	base.CanCollide = false

	local ringStoneCount = detailCount(12, 8)
	for index = 1, ringStoneCount do
		local angle = (math.pi * 2) * (index / ringStoneCount)
		local stone = createPart(
			"FireRingStone",
			Vector3.new(1.4, 0.8, 1.2),
			cframe * CFrame.new(math.cos(angle) * 4.2, 0.55, math.sin(angle) * 4.2) * CFrame.Angles(0, angle, 0),
			Color3.fromRGB(117, 116, 106),
			parent
		)
		stone.Shape = Enum.PartType.Ball
		stone.Material = Enum.Material.Slate
		stone.CanCollide = false
	end

	for index = 1, 3 do
		createLog(
			cframe * CFrame.new(0, 0.65, 0) * CFrame.Angles(math.rad(90), 0, math.rad(index * 60)),
			7,
			parent
		)
	end

	local flame = createPart("CampfireFlame", Vector3.new(2.4, 3.4, 2.4), cframe * CFrame.new(0, 2, 0), FORTRESS_THEME.Torch, parent)
	flame.Shape = Enum.PartType.Ball
	flame.Material = Enum.Material.Neon
	flame.CanCollide = false
	flame.CanQuery = false

	local light = Instance.new("PointLight")
	light.Name = "CampWarmth"
	light.Brightness = 2.4
	light.Range = 34
	light.Color = Color3.fromRGB(255, 158, 77)
	light.Parent = flame

	for layer = 1, 7 do
		local smoke = createPart(
			"SmokePlume",
			Vector3.new(3 + layer * 0.55, 2.2 + layer * 0.25, 3 + layer * 0.55),
			cframe * CFrame.new(decorRandom:NextNumber(-1.2, 1.2), 4.5 + layer * 3.2, decorRandom:NextNumber(-1.2, 1.2)),
			FORTRESS_THEME.Smoke,
			parent
		)
		smoke.Shape = Enum.PartType.Ball
		smoke.Material = TONE_DOWN_SMOOTH_SURFACES and Enum.Material.Plastic or Enum.Material.SmoothPlastic
		smoke.Transparency = 0.28 + layer * 0.07
		smoke.CanCollide = false
		smoke.CanTouch = false
		smoke.CanQuery = false
	end
end

local function createCanvasTent(name, cframe, parent)
	local floor = createPart(name .. "GroundCloth", Vector3.new(16, 0.16, 20), cframe * CFrame.new(0, 0.16, 0), FORTRESS_THEME.CanvasDark, parent)
	floor.Material = Enum.Material.Fabric
	floor.CanCollide = false

	local leftRoof = createPart(
		name .. "RoofLeft",
		Vector3.new(0.8, 8.5, 20),
		cframe * CFrame.new(-2.7, 4.1, 0) * CFrame.Angles(0, 0, math.rad(-31)),
		FORTRESS_THEME.Canvas,
		parent
	)
	leftRoof.Material = Enum.Material.Fabric

	local rightRoof = createPart(
		name .. "RoofRight",
		Vector3.new(0.8, 8.5, 20),
		cframe * CFrame.new(2.7, 4.1, 0) * CFrame.Angles(0, 0, math.rad(31)),
		FORTRESS_THEME.Canvas,
		parent
	)
	rightRoof.Material = Enum.Material.Fabric

	local ridge = createLog(cframe * CFrame.new(0, 7.4, 0) * CFrame.Angles(math.rad(90), 0, 0), 21, parent)
	ridge.Name = name .. "RidgePole"

	local flap = createPart(name .. "OpenFlap", Vector3.new(6, 5, 0.35), cframe * CFrame.new(0, 2.7, -10.2), FORTRESS_THEME.CanvasDark, parent)
	flap.Material = Enum.Material.Fabric
	flap.CanCollide = false
end

local function createWorkbenchShelter(cframe, parent)
	local deck = createPart("WorkshopDeck", Vector3.new(36, 0.5, 24), cframe * CFrame.new(0, 0.32, 0), Color3.fromRGB(86, 57, 34), parent)
	deck.Material = Enum.Material.WoodPlanks

	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local post = createPart(
				"WorkshopPost",
				Vector3.new(1.2, 8.5, 1.2),
				cframe * CFrame.new(x * 16, 4.5, z * 10),
				FORTRESS_THEME.Wood,
				parent
			)
			post.Material = Enum.Material.Wood
		end
	end

	local roof = createPart(
		"WorkshopRoof",
		Vector3.new(40, 1, 28),
		cframe * CFrame.new(0, 9.3, 0) * CFrame.Angles(math.rad(-7), 0, 0),
		FORTRESS_THEME.Roof,
		parent
	)
	roof.Material = Enum.Material.WoodPlanks

	local bench = createPart("WorkbenchPreview", Vector3.new(15, 1.2, 4), cframe * CFrame.new(-6, 3, 3), FORTRESS_THEME.FreshWood, parent)
	bench.Material = Enum.Material.WoodPlanks

	for x = -1, 1, 2 do
		local leg = createPart("BenchLeg", Vector3.new(0.8, 4, 0.8), cframe * CFrame.new(-6 + x * 6, 1.8, 3), FORTRESS_THEME.Wood, parent)
		leg.Material = Enum.Material.Wood
	end

	for index = 1, 5 do
		local crate = createPart(
			"SupplyCrate",
			Vector3.new(3.8, 3.4, 3.8),
			cframe * CFrame.new(6 + (index % 2) * 4, 1.9, -6 + math.floor(index / 2) * 4),
			Color3.fromRGB(95, 69, 42),
			parent
		)
		crate.Material = Enum.Material.WoodPlanks
	end
end

local function createWatchtower(cframe, parent)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local post = createPart(
				"WatchtowerPost",
				Vector3.new(1.4, 23, 1.4),
				cframe * CFrame.new(x * 8, 11.5, z * 8),
				FORTRESS_THEME.Wood,
				parent
			)
			post.Material = Enum.Material.Wood
		end
	end

	local platform = createPart("WatchtowerPlatform", Vector3.new(22, 1, 22), cframe * CFrame.new(0, 21, 0), FORTRESS_THEME.FreshWood, parent)
	platform.Material = Enum.Material.WoodPlanks

	for z = -1, 1, 2 do
		local rail = createPart("WatchtowerRail", Vector3.new(22, 1, 1), cframe * CFrame.new(0, 25, z * 11), FORTRESS_THEME.Wood, parent)
		rail.Material = Enum.Material.Wood
	end

	for x = -1, 1, 2 do
		local rail = createPart("WatchtowerRail", Vector3.new(1, 1, 22), cframe * CFrame.new(x * 11, 25, 0), FORTRESS_THEME.Wood, parent)
		rail.Material = Enum.Material.Wood
	end

	for step = 1, 12 do
		local stair = createPart(
			"WatchtowerStair",
			Vector3.new(5, 0.6, 1.5),
			cframe * CFrame.new(-16 + step * 1.15, 1.5 + step * 1.45, 12.5),
			FORTRESS_THEME.FreshWood,
			parent
		)
		stair.Material = Enum.Material.WoodPlanks
	end

	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local roofPost = createPart(
				"WatchtowerRoofPost",
				Vector3.new(0.8, 5.5, 0.8),
				cframe * CFrame.new(x * 8.8, 27.5, z * 8.8),
				FORTRESS_THEME.Wood,
				parent
			)
			roofPost.Material = Enum.Material.Wood
		end
	end

	local roof = createPart("WatchtowerRoof", Vector3.new(27, 1.2, 27), cframe * CFrame.new(0, 31, 0), FORTRESS_THEME.Roof, parent)
	roof.Material = Enum.Material.WoodPlanks
end

local function createSurvivalOutpost(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)
	local spawnPoint = getSpawnPoint()

	local clearing = createPart(
		"OutpostClearing",
		Vector3.new(138, 0.24, 116),
		baseCFrame * CFrame.new(8, 0.14, 16),
		Color3.fromRGB(62, 91, 54),
		parent
	)
	clearing.Material = Enum.Material.Grass
	clearing.CanCollide = false

	local mainPath = createPart(
		"MuddyCampPath",
		Vector3.new(18, 0.22, 106),
		baseCFrame * CFrame.new(0, 0.3, 12),
		FORTRESS_THEME.Mud,
		parent
	)
	mainPath.Material = Enum.Material.Ground
	mainPath.CanCollide = false

	local crossPath = createPart(
		"MuddyCampCrossPath",
		Vector3.new(96, 0.2, 14),
		baseCFrame * CFrame.new(8, 0.32, 18),
		FORTRESS_THEME.Mud,
		parent
	)
	crossPath.Material = Enum.Material.Ground
	crossPath.CanCollide = false

	createCampfireScene(baseCFrame * CFrame.new(16, 0, 20), parent)
	createWatchtower(baseCFrame * CFrame.new(48, 0, -32) * CFrame.Angles(0, math.rad(-16), 0), parent)
	createWorkbenchShelter(baseCFrame * CFrame.new(40, 0, 36) * CFrame.Angles(0, math.rad(-16), 0), parent)
	createCanvasTent("NorthTent", baseCFrame * CFrame.new(-31, 0, -8) * CFrame.Angles(0, math.rad(18), 0), parent)
	createCanvasTent("SouthTent", baseCFrame * CFrame.new(-45, 0, 26) * CFrame.Angles(0, math.rad(-24), 0), parent)

	for index = 1, detailCount(9, 6) do
		local log = createLog(
			baseCFrame
				* CFrame.new(-7 + (index % 3) * 3, 1 + math.floor((index - 1) / 3) * 2.2, -38)
				* CFrame.Angles(math.rad(90), math.rad(90), 0),
			18,
			parent
		)
		log.Name = "CampLogPile"
	end

	for index = 1, detailCount(44, 18) do
		local angle = decorRandom:NextNumber(0, math.pi * 2)
		local radius = decorRandom:NextNumber(76, 168)
		local x = center.X + math.cos(angle) * radius
		local z = center.Z + math.sin(angle) * radius

		if (Vector3.new(x, 0, z) - Vector3.new(spawnPoint.X, 0, spawnPoint.Z)).Magnitude > 32 then
			createTallPine(
				CFrame.new(x, 0, z) * CFrame.Angles(0, decorRandom:NextNumber(0, math.pi * 2), 0),
				parent,
				decorRandom:NextNumber(0.82, 1.25)
			)
		end
	end

	for index = 1, detailCount(10, 6) do
		local rock = createPart(
			"CampBoulder",
			Vector3.new(decorRandom:NextNumber(3, 7), decorRandom:NextNumber(1.4, 3.2), decorRandom:NextNumber(3, 7)),
			baseCFrame * CFrame.new(decorRandom:NextNumber(-58, 66), 0.9, decorRandom:NextNumber(-50, 58)),
			Color3.fromRGB(92, 97, 91),
			parent
		)
		rock.Shape = Enum.PartType.Ball
		rock.Material = Enum.Material.Slate
		rock.CanCollide = false
	end

	for index = 1, detailCount(8, 4) do
		local bird = createPart(
			"SkyBird",
			Vector3.new(2.5, 0.12, 0.12),
			baseCFrame * CFrame.new(decorRandom:NextNumber(-95, 95), decorRandom:NextNumber(52, 76), decorRandom:NextNumber(-95, 45))
				* CFrame.Angles(0, decorRandom:NextNumber(0, math.pi * 2), math.rad(18)),
			Color3.fromRGB(50, 53, 50),
			parent
		)
		bird.CanCollide = false
		bird.CanTouch = false
		bird.CanQuery = false
	end
end

local function createWaterPatch(name, cframe, size, parent, color)
	local water = createPart(name, size, cframe, color or FORTRESS_THEME.Water, parent)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.24
	water.CanCollide = false
	water.CanTouch = false
	water.CanQuery = true
	water:SetAttribute("SurvivalSwimWater", true)
	return water
end

local function createMarketCanopy(name, cframe, color, parent, width, depth)
	width = width or 18
	depth = depth or 14

	local deck = createPart(name .. "Deck", Vector3.new(width + 2, 0.35, depth + 2), cframe * CFrame.new(0, 0.22, 0), FORTRESS_THEME.Path, parent)
	deck.Material = Enum.Material.WoodPlanks

	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local post = createPart(
				name .. "Post",
				Vector3.new(0.7, 7, 0.7),
				cframe * CFrame.new(x * width * 0.43, 3.6, z * depth * 0.42),
				FORTRESS_THEME.Wood,
				parent
			)
			post.Material = Enum.Material.Wood
		end
	end

	local awning = createPart(
		name .. "Awning",
		Vector3.new(width, 0.55, depth),
		cframe * CFrame.new(0, 7.2, 0) * CFrame.Angles(math.rad(-4), 0, 0),
		color,
		parent
	)
	awning.Material = Enum.Material.Fabric
	awning.CanCollide = false

	local counter = createPart(
		name .. "Counter",
		Vector3.new(width - 5, 2.4, 2.2),
		cframe * CFrame.new(0, 1.6, -depth * 0.25),
		FORTRESS_THEME.FreshWood,
		parent
	)
	counter.Material = Enum.Material.WoodPlanks

	for index = 1, 4 do
		local crate = createPart(
			name .. "Crate",
			Vector3.new(2.8, 2.4, 2.8),
			cframe * CFrame.new(-width * 0.33 + index * 2.4, 1.4, depth * 0.24 + (index % 2) * 1.8),
			Color3.fromRGB(108, 75, 44),
			parent
		)
		crate.Material = Enum.Material.WoodPlanks
		crate.CanCollide = false
	end
end

local function createMarketCrossing(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)
	local spawnPoint = getSpawnPoint()

	local plaza = createPart(
		"MarketStonePlaza",
		Vector3.new(126, 0.42, 118),
		baseCFrame * CFrame.new(0, 0.26, 2),
		Color3.fromRGB(122, 112, 93),
		parent
	)
	plaza.Material = Enum.Material.Cobblestone

	local northRoad = createPart("NorthSouthMarketRoad", Vector3.new(18, 0.28, 178), baseCFrame * CFrame.new(0, 0.36, -8), FORTRESS_THEME.Path, parent)
	northRoad.Material = Enum.Material.Ground

	local eastRoad = createPart("EastWestMarketRoad", Vector3.new(176, 0.28, 18), baseCFrame * CFrame.new(0, 0.38, 18), FORTRESS_THEME.Path, parent)
	eastRoad.Material = Enum.Material.Ground

	local spawnPad = createPart(
		"MarketSpawnCompass",
		Vector3.new(28, 0.35, 28),
		CFrame.new(spawnPoint.X, 0.64, spawnPoint.Z),
		FORTRESS_THEME.TrimStone,
		parent
	)
	spawnPad.Material = Enum.Material.Cobblestone

	local ringPaverCount = detailCount(16, 10)
	for index = 1, ringPaverCount do
		local angle = (math.pi * 2) * (index / ringPaverCount)
		local paver = createPart(
			"MarketRingPaver",
			Vector3.new(5.5, 0.28, 2.4),
			baseCFrame * CFrame.new(math.cos(angle) * 48, 0.64, 2 + math.sin(angle) * 42) * CFrame.Angles(0, -angle, 0),
			index % 2 == 0 and FORTRESS_THEME.WeatheredStone or FORTRESS_THEME.TrimStone,
			parent
		)
		paver.Material = Enum.Material.Cobblestone
		paver.CanCollide = false
	end

	createCampfireScene(baseCFrame * CFrame.new(0, 0, 18), parent)
	createMarketCanopy("ProvisionCanopy", baseCFrame * CFrame.new(-34, 0, -24) * CFrame.Angles(0, math.rad(146), 0), FORTRESS_THEME.MarketRed, parent, 16, 12)
	createMarketCanopy("MapCanopy", baseCFrame * CFrame.new(38, 0, -22) * CFrame.Angles(0, math.rad(-142), 0), FORTRESS_THEME.MarketBlue, parent, 16, 12)
	createWorkbenchShelter(baseCFrame * CFrame.new(58, 0, 24) * CFrame.Angles(0, math.rad(-90), 0), parent)

	local well = createPart("MarketWellBase", Vector3.new(14, 2.2, 14), baseCFrame * CFrame.new(-2, 1.1, -42), FORTRESS_THEME.WeatheredStone, parent)
	well.Shape = Enum.PartType.Cylinder
	well.Material = Enum.Material.Cobblestone
	createWaterPatch("MarketWellWater", baseCFrame * CFrame.new(-2, 2.36, -42), Vector3.new(10, 0.32, 10), parent)

	for _, offset in ipairs({
		Vector3.new(-54, 0, 52),
		Vector3.new(54, 0, 50),
		Vector3.new(-56, 0, -50),
		Vector3.new(56, 0, -48),
		Vector3.new(-76, 0, 4),
		Vector3.new(76, 0, 4),
	}) do
		createTorch(baseCFrame * CFrame.new(offset.X, offset.Y, offset.Z), parent)
	end

	for index = 1, detailCount(30, 12) do
		local angle = decorRandom:NextNumber(0, math.pi * 2)
		local radius = decorRandom:NextNumber(78, 150)
		local x = center.X + math.cos(angle) * radius
		local z = center.Z + math.sin(angle) * radius
		if (Vector3.new(x, 0, z) - Vector3.new(spawnPoint.X, 0, spawnPoint.Z)).Magnitude > 44 then
			createTallPine(
				CFrame.new(x, 0, z) * CFrame.Angles(0, decorRandom:NextNumber(0, math.pi * 2), 0),
				parent,
				decorRandom:NextNumber(0.68, 1.05)
			)
		end
	end
end

-- ═══════════════════════════════════════════════════════
-- VOLCANIC ISLAND LANDMARK BUILDERS
-- ═══════════════════════════════════════════════════════

-- Helper: lava pool / fissure patch
local function createLavaFissure(name, cframe, size, parent)
	local fissure = createPart(name, size, cframe, FORTRESS_THEME.Ember, parent)
	fissure.Material = Enum.Material.Neon
	fissure.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Name = "LavaGlow"
	glow.Brightness = 1.4
	glow.Range = 22
	glow.Color = FORTRESS_THEME.LavaGlow
	glow.Parent = fissure
	return fissure
end

-- Helper: obsidian spike / volcanic pillar
local function createVolcanicSpire(cframe, height, parent)
	local base = createPart("VolcanicSpireBase", Vector3.new(3.2, height * 0.55, 3.2), cframe * CFrame.new(0, height * 0.28, 0), FORTRESS_THEME.Obsidian, parent)
	base.Material = Enum.Material.Slate
	base.CanCollide = false
	local tip = createPart("VolcanicSpireTip", Vector3.new(1.6, height * 0.55, 1.6), cframe * CFrame.new(0, height * 0.72, 0), FORTRESS_THEME.DarkStone, parent)
	tip.Material = Enum.Material.Slate
	tip.CanCollide = false
end

-- Helper: palm / tropical tree
local function createPalmTree(cframe, parent, scale)
	scale = scale or 1
	local trunk = createPart("PalmTrunk", Vector3.new(1.2 * scale, 16 * scale, 1.2 * scale), cframe * CFrame.new(0, 8 * scale, 0), Color3.fromRGB(96, 62, 32), parent)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Material = Enum.Material.Wood
	trunk.CanCollide = false
	local frond = createPart("PalmFronds", Vector3.new(14 * scale, 3 * scale, 14 * scale), cframe * CFrame.new(0, 16.5 * scale, 0), FORTRESS_THEME.TropicalLeaf, parent)
	frond.Shape = Enum.PartType.Ball
	frond.Material = Enum.Material.Grass
	frond.CanCollide = false
end

-- Helper: ash-covered dead tree
local function createDeadTree(cframe, parent)
	local trunk = createPart("DeadTrunk", Vector3.new(1.4, 12, 1.4), cframe * CFrame.new(0, 6, 0), FORTRESS_THEME.AshGrey, parent)
	trunk.Material = Enum.Material.Wood
	trunk.CanCollide = false
	local branch = createPart("DeadBranch", Vector3.new(0.8, 6, 0.8), cframe * CFrame.new(2, 11, 0) * CFrame.Angles(0, 0, math.rad(42)), FORTRESS_THEME.AshGrey, parent)
	branch.Material = Enum.Material.Wood
	branch.CanCollide = false
end

-- ──────────────────────────────────────────────────────
-- 1. CinderHarbour — crashed survivor camp on the coast
-- ──────────────────────────────────────────────────────
local function createCinderHarbour(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)

	-- Sandy beach floor
	local beach = createPart("HarbourBeach", Vector3.new(148, 0.3, 112), baseCFrame * CFrame.new(0, 0.18, 8), FORTRESS_THEME.BoneWhite, parent)
	beach.Material = Enum.Material.Sand
	beach.CanCollide = false

	-- Shallow cove water
	createWaterPatch("HarbourCove", baseCFrame * CFrame.new(18, 0.1, 52), Vector3.new(158, 0.42, 56), parent, FORTRESS_THEME.Water)

	-- Burnt-out dock
	local dock = createPart("BurntDock", Vector3.new(14, 0.6, 52), baseCFrame * CFrame.new(-24, 0.72, 30), FORTRESS_THEME.Wood, parent)
	dock.Material = Enum.Material.WoodPlanks

	-- Wrecked ship ribs
	for i = 1, 5 do
		local rib = createPart("WreckRib", Vector3.new(2, 14, 24), baseCFrame * CFrame.new(14 + i * 5, 5, 36 - i * 2) * CFrame.Angles(math.rad(20), math.rad(-22), 0), FORTRESS_THEME.Wood, parent)
		rib.Material = Enum.Material.Wood
		rib.CanCollide = false
	end

	-- Camp tents + campfire scene
	createCanvasTent("HarbourTentA", baseCFrame * CFrame.new(-18, 0, -14) * CFrame.Angles(0, math.rad(14), 0), parent)
	createCanvasTent("HarbourTentB", baseCFrame * CFrame.new(-38, 0, 8) * CFrame.Angles(0, math.rad(-22), 0), parent)
	createCampfireScene(baseCFrame * CFrame.new(-26, 0, -2), parent)

	-- Washed-up crates
	for i = 1, 20 do
		local crate = createPart("WashedCrate", Vector3.new(decorRandom:NextNumber(2, 4), decorRandom:NextNumber(1.5, 3.2), decorRandom:NextNumber(2, 4)),
			baseCFrame * CFrame.new(decorRandom:NextNumber(-62, 64), 1.2, decorRandom:NextNumber(-40, 46)) * CFrame.Angles(0, decorRandom:NextNumber(0, math.pi), 0),
			Color3.fromRGB(88, 58, 32), parent)
		crate.Material = Enum.Material.WoodPlanks
		crate.CanCollide = false
	end

	-- Scattered palm trees at edge
	for i = 1, detailCount(14, 6) do
		local angle = decorRandom:NextNumber(0, math.pi * 2)
		local r = decorRandom:NextNumber(48, 130)
		createPalmTree(baseCFrame * CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r) * CFrame.Angles(0, decorRandom:NextNumber(0, math.pi * 2), 0), parent, decorRandom:NextNumber(0.8, 1.2))
	end
end

-- ──────────────────────────────────────────────────────
-- 2. AshwoodHollow — haunted ash forest, dead trees, ember spores
-- ──────────────────────────────────────────────────────
local function createAshwoodHollow(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)

	local floor = createPart("AshFloor", Vector3.new(136, 0.28, 118), baseCFrame * CFrame.new(0, 0.18, 0), Color3.fromRGB(68, 58, 52), parent)
	floor.Material = Enum.Material.Ground
	floor.CanCollide = false

	-- Dead ash trees
	for i = 1, detailCount(42, 18) do
		local angle = decorRandom:NextNumber(0, math.pi * 2)
		local r = decorRandom:NextNumber(22, 148)
		createDeadTree(baseCFrame * CFrame.new(math.cos(angle) * r, sampleTerrainHeight(center.X + math.cos(angle)*r, center.Z + math.sin(angle)*r), math.sin(angle) * r) * CFrame.Angles(0, decorRandom:NextNumber(0, math.pi*2), 0), parent)
	end

	-- Glowing ember spore pods on ground
	for i = 1, detailCount(18, 8) do
		local ox = decorRandom:NextNumber(-52, 54)
		local oz = decorRandom:NextNumber(-48, 50)
		local spore = createPart("EmberSpore", Vector3.new(1.8, 1.8, 1.8), baseCFrame * CFrame.new(ox, 1.2, oz), FORTRESS_THEME.Ember, parent)
		spore.Shape = Enum.PartType.Ball
		spore.Material = Enum.Material.Neon
		spore.CanCollide = false
		local gl = Instance.new("PointLight")
		gl.Brightness = 0.6
		gl.Range = 10
		gl.Color = FORTRESS_THEME.LavaGlow
		gl.Parent = spore
	end

	-- Ancient ritual obelisks
	for i = 1, 5 do
		local angle = (math.pi * 2) * (i / 5)
		createVolcanicSpire(baseCFrame * CFrame.new(math.cos(angle) * 28, 0, math.sin(angle) * 28), decorRandom:NextNumber(10, 18), parent)
	end

	-- Collapsed shrine at centre
	local shrine = createPart("AshShrine", Vector3.new(14, 1, 14), baseCFrame * CFrame.new(0, 0.7, 0), FORTRESS_THEME.WeatheredStone, parent)
	shrine.Material = Enum.Material.Cobblestone
	local shrinePost = createPart("AshShrinePost", Vector3.new(3, 12, 3), baseCFrame * CFrame.new(0, 7, 0), FORTRESS_THEME.Obsidian, parent)
	shrinePost.Material = Enum.Material.Slate
end

-- ──────────────────────────────────────────────────────
-- 3. SaltcragShores — jagged salt-crystal sea cliffs
-- ──────────────────────────────────────────────────────
local function createSaltcragShores(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)

	-- Rock shelf
	local shelf = createPart("SaltShelf", Vector3.new(138, 0.38, 106), baseCFrame * CFrame.new(0, 0.22, 0), Color3.fromRGB(148, 138, 118), parent)
	shelf.Material = Enum.Material.Slate
	shelf.CanCollide = false

	-- Sea-water pool
	createWaterPatch("TidalPool", baseCFrame * CFrame.new(24, 0.16, 32) * CFrame.Angles(0, math.rad(12), 0), Vector3.new(84, 0.38, 44), parent, FORTRESS_THEME.DeepWater)

	-- Salt crystal spires scattered
	for i = 1, detailCount(24, 10) do
		local ox = decorRandom:NextNumber(-58, 60)
		local oz = decorRandom:NextNumber(-52, 54)
		local h = decorRandom:NextNumber(6, 18)
		local crystal = createPart("SaltCrystal", Vector3.new(decorRandom:NextNumber(2.5, 5), h, decorRandom:NextNumber(2.5, 5)),
			baseCFrame * CFrame.new(ox, h * 0.5, oz) * CFrame.Angles(decorRandom:NextNumber(-0.12, 0.12), decorRandom:NextNumber(0, math.pi), decorRandom:NextNumber(-0.1, 0.1)),
			FORTRESS_THEME.IceBlue, parent)
		crystal.Material = Enum.Material.Glass
		crystal.Transparency = 0.18
		crystal.CanCollide = false
	end

	-- Collapsed cliff wall rims
	local rimCount = detailCount(20, 10)
	for i = 1, rimCount do
		local angle = (math.pi * 2) * (i / rimCount)
		local rx = 72 + decorRandom:NextNumber(-6, 8)
		local rz = 54 + decorRandom:NextNumber(-5, 7)
		local rimBlock = createPart("CliffRimBlock", Vector3.new(decorRandom:NextNumber(6, 14), decorRandom:NextNumber(5, 12), decorRandom:NextNumber(6, 14)),
			baseCFrame * CFrame.new(math.cos(angle) * rx, 3, math.sin(angle) * rz), FORTRESS_THEME.WeatheredStone, parent)
		rimBlock.Material = Enum.Material.Slate
	end

	-- Survival outpost at cliff top
	createSurvivalOutpost(baseCFrame * CFrame.new(-22, 0, -18), parent)
end

-- ──────────────────────────────────────────────────────
-- 4. ScorchPitQuarry — abandoned mining pit, burnt scaffolding
-- ──────────────────────────────────────────────────────
local function createScorchPitQuarry(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)

	-- Pit floor
	local pit = createPart("ScorchPitFloor", Vector3.new(124, 0.38, 98), baseCFrame * CFrame.new(0, 0.18, 0), Color3.fromRGB(58, 44, 34), parent)
	pit.Material = Enum.Material.Slate
	pit.CanCollide = false

	-- Lava fissures in the pit floor
	local fissureOffsets = { Vector3.new(-18, 0, -8), Vector3.new(22, 0, 14), Vector3.new(-4, 0, 36) }
	for _, off in ipairs(fissureOffsets) do
		createLavaFissure("PitFissure", baseCFrame * CFrame.new(off.X, 0.28, off.Z), Vector3.new(28, 0.38, 10), parent)
	end

	-- Burnt scaffolding gantry
	local gA = createPart("ScaffoldPoleA", Vector3.new(3, 28, 3), baseCFrame * CFrame.new(-32, 14, -20), FORTRESS_THEME.Wood, parent)
	gA.Material = Enum.Material.Wood
	local gB = createPart("ScaffoldPoleB", Vector3.new(3, 28, 3), baseCFrame * CFrame.new(32, 14, -20), FORTRESS_THEME.Wood, parent)
	gB.Material = Enum.Material.Wood
	local beam = createPart("ScaffoldBeam", Vector3.new(70, 3, 3), baseCFrame * CFrame.new(0, 28, -20), FORTRESS_THEME.FreshWood, parent)
	beam.Material = Enum.Material.WoodPlanks
	local chain = createPart("LiftChain", Vector3.new(0.6, 14, 0.6), baseCFrame * CFrame.new(0, 20, -20), Color3.fromRGB(48, 44, 40), parent)
	chain.Material = Enum.Material.Metal

	-- Boulder rim
	local rimCount = detailCount(28, 14)
	for i = 1, rimCount do
		local angle = (math.pi * 2) * (i / rimCount)
		local boulder = createPart("QuarryBoulder", Vector3.new(decorRandom:NextNumber(5, 11), decorRandom:NextNumber(4, 10), decorRandom:NextNumber(5, 11)),
			baseCFrame * CFrame.new(math.cos(angle) * (66 + decorRandom:NextNumber(-6, 8)), 3, math.sin(angle) * (50 + decorRandom:NextNumber(-4, 6))),
			Color3.fromRGB(62, 52, 44), parent)
		boulder.Shape = Enum.PartType.Ball
		boulder.Material = Enum.Material.Slate
	end

	-- Molten runoff channels
	for i = -1, 1 do
		local channel = createPart("MoltenRunoff", Vector3.new(6, 0.28, 84),
			baseCFrame * CFrame.new(i * 20, 0.72, 0) * CFrame.Angles(0, math.rad(i * 7), 0), FORTRESS_THEME.Ember, parent)
		channel.Material = Enum.Material.Neon
		channel.CanCollide = false
	end
end

-- ──────────────────────────────────────────────────────
-- 5. BrimstoneMarsh — toxic sulfur swamp, glowing pools
-- ──────────────────────────────────────────────────────
local function createBrimstoneMarsh(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)

	-- Muddy ground
	local mud = createPart("MarshMud", Vector3.new(138, 0.3, 118), baseCFrame * CFrame.new(0, 0.18, 0), Color3.fromRGB(48, 44, 32), parent)
	mud.Material = Enum.Material.Mud
	mud.CanCollide = false

	-- Toxic sulfur pools
	local poolOffsets = { Vector3.new(-28, 0, -12), Vector3.new(22, 0, 18), Vector3.new(4, 0, 42), Vector3.new(-8, 0, -38) }
	for i, off in ipairs(poolOffsets) do
		local pool = createPart("SulfurPool", Vector3.new(38 - i * 2, 0.44, 26 + i * 4),
			baseCFrame * CFrame.new(off.X, 0.24, off.Z) * CFrame.Angles(0, i * 0.38, 0), FORTRESS_THEME.SulfurYellow, parent)
		pool.Material = Enum.Material.Neon
		pool.Transparency = 0.28
		pool.CanCollide = false
		local gl = Instance.new("PointLight")
		gl.Brightness = 0.8
		gl.Range = 18
		gl.Color = FORTRESS_THEME.SulfurYellow
		gl.Parent = pool
	end

	-- Rotted boardwalk
	local boardwalk = createPart("MarshBoardwalk", Vector3.new(102, 0.44, 6),
		baseCFrame * CFrame.new(4, 0.58, 10) * CFrame.Angles(0, math.rad(-22), 0), FORTRESS_THEME.Wood, parent)
	boardwalk.Material = Enum.Material.WoodPlanks

	-- Marsh reeds
	for i = 1, detailCount(38, 16) do
		local angle = decorRandom:NextNumber(0, math.pi * 2)
		local r = decorRandom:NextNumber(18, 98)
		local reed = createPart("MarshReed", Vector3.new(0.44, decorRandom:NextNumber(4, 8), 0.44),
			baseCFrame * CFrame.new(math.cos(angle) * r, 3.2, math.sin(angle) * r), FORTRESS_THEME.Reed, parent)
		reed.Material = Enum.Material.Grass
		reed.CanCollide = false
	end

	-- Watchtower for safety
	createWatchtower(baseCFrame * CFrame.new(-44, 0, -28) * CFrame.Angles(0, math.rad(22), 0), parent)
end

-- ──────────────────────────────────────────────────────
-- 6. GlacierScar — frozen anomaly, ice and cold in volcanic land
-- ──────────────────────────────────────────────────────
local function createGlacierScar(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)

	local iceFloor = createPart("GlacierFloor", Vector3.new(128, 0.3, 108), baseCFrame * CFrame.new(0, 0.18, 0), FORTRESS_THEME.IceBlue, parent)
	iceFloor.Material = Enum.Material.Ice
	iceFloor.Transparency = 0.12
	iceFloor.CanCollide = false

	-- Ice spire field
	for i = 1, detailCount(32, 14) do
		local ox = decorRandom:NextNumber(-56, 58)
		local oz = decorRandom:NextNumber(-50, 52)
		local h = decorRandom:NextNumber(8, 26)
		local spire = createPart("IceSpire", Vector3.new(decorRandom:NextNumber(2, 4.5), h, decorRandom:NextNumber(2, 4.5)),
			baseCFrame * CFrame.new(ox, h * 0.5, oz) * CFrame.Angles(decorRandom:NextNumber(-0.08, 0.08), decorRandom:NextNumber(0, math.pi), decorRandom:NextNumber(-0.06, 0.06)),
			FORTRESS_THEME.IceBlue, parent)
		spire.Material = Enum.Material.Glass
		spire.Transparency = 0.14
		spire.CanCollide = false
	end

	-- Frozen underground spring
	createWaterPatch("FrozenSpring", baseCFrame * CFrame.new(-8, 0.16, 4), Vector3.new(48, 0.36, 32), parent, FORTRESS_THEME.IceBlue)

	-- Relic buried in ice
	local relic = createPart("FrozenRelic", Vector3.new(6, 6, 6), baseCFrame * CFrame.new(0, 3.5, 0), FORTRESS_THEME.Relic, parent)
	relic.Shape = Enum.PartType.Ball
	relic.Material = Enum.Material.Glass
	relic.Transparency = 0.35
	relic.CanCollide = false
	local relicGlow = Instance.new("PointLight")
	relicGlow.Brightness = 1.2
	relicGlow.Range = 28
	relicGlow.Color = FORTRESS_THEME.Relic
	relicGlow.Parent = relic

	createSurvivalOutpost(baseCFrame * CFrame.new(28, 0, -22), parent)
end

-- ──────────────────────────────────────────────────────
-- 7. DeadMansCaldera — giant volcanic crater, dangerous centre
-- ──────────────────────────────────────────────────────
local function createDeadMansCaldera(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)

	-- Ash floor of crater
	local calderaFloor = createPart("CalderaFloor", Vector3.new(148, 0.42, 126), baseCFrame * CFrame.new(0, 0.22, 0), Color3.fromRGB(42, 34, 28), parent)
	calderaFloor.Material = Enum.Material.Slate
	calderaFloor.CanCollide = false

	-- Central lava lake
	createLavaFissure("CalderaLavaLake", baseCFrame * CFrame.new(0, 0.46, 0), Vector3.new(72, 0.58, 54), parent)

	-- Lava river tendrils from lake
	local riverAngles = { 0, 60, 130, 220, 310 }
	for _, deg in ipairs(riverAngles) do
		local rad = math.rad(deg)
		local river = createPart("CalderaRiver", Vector3.new(8, 0.32, 58),
			baseCFrame * CFrame.new(math.cos(rad) * 56, 0.34, math.sin(rad) * 42) * CFrame.Angles(0, rad, 0), FORTRESS_THEME.Ember, parent)
		river.Material = Enum.Material.Neon
		river.CanCollide = false
	end

	-- Crater rim boulders
	local rimCount = detailCount(30, 16)
	for i = 1, rimCount do
		local angle = (math.pi * 2) * (i / rimCount)
		local rx = 82 + decorRandom:NextNumber(-8, 10)
		local rz = 68 + decorRandom:NextNumber(-6, 8)
		local boulder = createPart("CraterRimRock", Vector3.new(decorRandom:NextNumber(7, 16), decorRandom:NextNumber(6, 14), decorRandom:NextNumber(7, 16)),
			baseCFrame * CFrame.new(math.cos(angle) * rx, 4, math.sin(angle) * rz), FORTRESS_THEME.DarkStone, parent)
		boulder.Material = Enum.Material.Slate
	end

	-- Tall obsidian obelisk at rim
	local obeliskCount = detailCount(8, 4)
	for i = 1, obeliskCount do
		local angle = (math.pi * 2) * (i / obeliskCount)
		createVolcanicSpire(baseCFrame * CFrame.new(math.cos(angle) * 68, 0, math.sin(angle) * 54), decorRandom:NextNumber(18, 30), parent)
	end

	-- Dangerous atmosphere torches ringing the rim
	local torchCount = detailCount(10, 6)
	for i = 1, torchCount do
		local angle = (math.pi * 2) * (i / torchCount)
		createTorch(baseCFrame * CFrame.new(math.cos(angle) * 78, 0, math.sin(angle) * 60), parent)
	end
end

-- ──────────────────────────────────────────────────────
-- 8. MoltenSpireHold — fortress built on volcanic rock, endgame
-- ──────────────────────────────────────────────────────
local function createMoltenSpireHold(center, parent)
	local baseCFrame = CFrame.new(center.X, 0, center.Z)

	-- Fortress yard of scorched stone
	local yard = createPart("SpireYard", Vector3.new(138, 0.48, 118), baseCFrame * CFrame.new(0, 0.28, 0), Color3.fromRGB(52, 42, 34), parent)
	yard.Material = Enum.Material.Cobblestone

	-- Two massive erupting smelter towers
	for _, off in ipairs({ Vector3.new(-32, 0, -18), Vector3.new(28, 0, 22) }) do
		local tower = createPart("SmelterTower", Vector3.new(20, 26, 20), baseCFrame * CFrame.new(off.X, 13, off.Z), FORTRESS_THEME.DarkStone, parent)
		tower.Material = Enum.Material.Slate
		local mouth = createPart("TowerMouth", Vector3.new(12, 9, 0.5), baseCFrame * CFrame.new(off.X, 7, off.Z - 10.2), FORTRESS_THEME.Ember, parent)
		mouth.Material = Enum.Material.Neon
		mouth.CanCollide = false
		local stack = createPart("TowerStack", Vector3.new(8, 32, 8), baseCFrame * CFrame.new(off.X, 42, off.Z), FORTRESS_THEME.Smoke, parent)
		stack.Shape = Enum.PartType.Cylinder
		stack.Material = Enum.Material.Metal
		-- Lava glow from mouth
		local gl = Instance.new("PointLight")
		gl.Brightness = 2.2
		gl.Range = 38
		gl.Color = FORTRESS_THEME.LavaGlow
		gl.Parent = mouth
		createTorch(baseCFrame * CFrame.new(off.X + 14, 0, off.Z - 14), parent)
	end

	-- Molten runoff channels from towers
	for i = -1, 1 do
		local ch = createPart("SpireRunoff", Vector3.new(7, 0.3, 88),
			baseCFrame * CFrame.new(i * 22, 0.78, 0) * CFrame.Angles(0, math.rad(i * 9), 0), FORTRESS_THEME.Ember, parent)
		ch.Material = Enum.Material.Neon
		ch.CanCollide = false
	end

	-- Battlement walls on all 4 sides
	createBattlementWall("SpireWallN", baseCFrame * CFrame.new(0, 0, -56) * CFrame.Angles(0, 0, 0), 136, 12, parent)
	createBattlementWall("SpireWallS", baseCFrame * CFrame.new(0, 0, 56) * CFrame.Angles(0, math.rad(180), 0), 136, 12, parent)
	createBattlementWall("SpireWallW", baseCFrame * CFrame.new(-68, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 116, 12, parent)
	createBattlementWall("SpireWallE", baseCFrame * CFrame.new(68, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), 116, 12, parent)

	-- Gatehouse entrance
	createGatehouse(baseCFrame * CFrame.new(0, 0, -56) * CFrame.Angles(0, 0, 0), parent)

	-- Obsidian obelisks at corners
	for _, corner in ipairs({ Vector3.new(-58, 0, -46), Vector3.new(58, 0, -46), Vector3.new(-58, 0, 46), Vector3.new(58, 0, 46) }) do
		createVolcanicSpire(baseCFrame * CFrame.new(corner.X, 0, corner.Z), 22, parent)
	end
end

local function createRegionLandmark(region, parent)
	local model = Instance.new("Model")
	model.Name = "Landmark_" .. region.Id
	model.Parent = parent

	createRegionSign(region, model)

	if region.Id == "CinderHarbour" then
		createCinderHarbour(region.Center, model)
	elseif region.Id == "AshwoodHollow" then
		createAshwoodHollow(region.Center, model)
	elseif region.Id == "SaltcragShores" then
		createSaltcragShores(region.Center, model)
	elseif region.Id == "ScorchPitQuarry" then
		createScorchPitQuarry(region.Center, model)
	elseif region.Id == "BrimstoneMarsh" then
		createBrimstoneMarsh(region.Center, model)
	elseif region.Id == "GlacierScar" then
		createGlacierScar(region.Center, model)
	elseif region.Id == "DeadMansCaldera" then
		createDeadMansCaldera(region.Center, model)
	elseif region.Id == "MoltenSpireHold" then
		createMoltenSpireHold(region.Center, model)
	end
end

local function createTrail(fromPosition, toPosition, parent, width)
	local start = Vector3.new(fromPosition.X, 0.14, fromPosition.Z)
	local finish = Vector3.new(toPosition.X, 0.14, toPosition.Z)
	local offset = finish - start
	local length = offset.Magnitude

	if length <= 1 then
		return
	end

	local segmentCount = math.max(1, math.ceil(length / 34))
	local trailWidth = width or 8

	for index = 1, segmentCount do
		local alpha0 = (index - 1) / segmentCount
		local alpha1 = index / segmentCount
		local a = start + offset * alpha0
		local b = start + offset * alpha1
		local midpoint = (a + b) * 0.5
		local segmentLength = (b - a).Magnitude
		local terrainY = sampleTerrainHeight(midpoint.X, midpoint.Z) + 0.2
		local segmentFinish = Vector3.new(b.X, terrainY, b.Z)
		local segment = createPart(
			"ForestTrail",
			Vector3.new(trailWidth, 0.16, segmentLength + 1.2),
			CFrame.new(Vector3.new(midpoint.X, terrainY, midpoint.Z), segmentFinish),
			FORTRESS_THEME.Mud,
			parent
		)
		segment.Material = Enum.Material.Ground
		segment.Transparency = 0.08
		segment.CanCollide = false
		segment.CanTouch = false
		segment.CanQuery = false
	end
end

local function createRoadMarker(position, parent, name)
	local terrainY = sampleTerrainHeight(position.X, position.Z)
	local baseCFrame = CFrame.new(position.X, terrainY, position.Z)
	local plinth = createPart(
		name .. "RoadPlinth",
		Vector3.new(5, 0.8, 5),
		baseCFrame * CFrame.new(0, 0.4, 0),
		FORTRESS_THEME.WeatheredStone,
		parent
	)
	plinth.Material = Enum.Material.Cobblestone
	plinth.CanCollide = false

	local marker = createPart(
		name .. "Waystone",
		Vector3.new(2.4, 7, 2.4),
		baseCFrame * CFrame.new(0, 4.1, 0),
		FORTRESS_THEME.TrimStone,
		parent
	)
	marker.Material = Enum.Material.Slate
	marker.CanCollide = false

	local cap = createPart(
		name .. "WaystoneCap",
		Vector3.new(3.8, 1.2, 3.8),
		baseCFrame * CFrame.new(0, 8.2, 0),
		FORTRESS_THEME.DarkStone,
		parent
	)
	cap.Material = Enum.Material.Slate
	cap.CanCollide = false
end

local function getRegionsById()
	local regionsById = {}

	for _, region in ipairs(Config.Regions) do
		regionsById[region.Id] = region
	end

	return regionsById
end

local function optimizeLandmarkPerformance(landmarks)
	local pointLightCount = 0

	for _, descendant in ipairs(landmarks:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Anchored then
				descendant.CanTouch = false
			end

			if TONE_DOWN_SMOOTH_SURFACES and descendant.Material == Enum.Material.SmoothPlastic then
				descendant.Material = Enum.Material.Plastic
			end

			descendant.Reflectance = math.min(descendant.Reflectance, TONE_DOWN_SMOOTH_SURFACES and 0.02 or 0.08)

			if descendant.Size.Magnitude <= 4 then
				descendant.CastShadow = false
			end
		elseif descendant:IsA("PointLight") then
			pointLightCount += 1

			if pointLightCount > MAX_LANDMARK_POINT_LIGHTS then
				descendant.Enabled = false
			else
				descendant.Brightness = math.min(descendant.Brightness, 1.75)
				descendant.Range = math.min(descendant.Range, 14)
			end
		end
	end
end

local function setupLandmarks(worldFolder)
	if not worldFolder:FindFirstChild("BoundaryWater") then
		local water = createPart(
			"BoundaryWater",
			Vector3.new(Config.World.SpawnAreaHalfSize * 3.35, 1.2, Config.World.SpawnAreaHalfSize * 3.35),
			CFrame.new(0, -2.35, 0),
			FORTRESS_THEME.Water,
			worldFolder
		)
		water.CanCollide = false
		water.Material = Enum.Material.Glass
		water.Transparency = 0.18
		water.CanQuery = true
		water:SetAttribute("SurvivalSwimWater", true)
	end

	local landmarks = worldFolder:FindFirstChild("Landmarks")
	if not landmarks then
		landmarks = Instance.new("Folder")
		landmarks.Name = "Landmarks"
		landmarks.Parent = worldFolder
	end

	if landmarks:GetAttribute("ThemeVersion") == LANDMARK_THEME_VERSION and landmarks:FindFirstChild("Landmark_MarketCrossing") then
		optimizeLandmarkPerformance(landmarks)
		return
	end

	for _, child in ipairs(landmarks:GetChildren()) do
		child:Destroy()
	end

	landmarks:SetAttribute("ThemeVersion", LANDMARK_THEME_VERSION)

	local regionsById = getRegionsById()

	for _, region in ipairs(Config.Regions) do
		createRegionLandmark(region, landmarks)
	end

	for _, route in ipairs(MAP_ROUTES) do
		local fromRegion = regionsById[route[1]]
		local toRegion = regionsById[route[2]]

		if fromRegion and toRegion then
			local width = route[1] == "MarketCrossing" and 11 or 7
			local fromPosition = route[1] == "MarketCrossing" and getSpawnPoint() or fromRegion.Center
			createTrail(fromPosition, toRegion.Center, landmarks, width)
		end
	end

	createTrail(getSpawnPoint(), Vector3.new(0, 0, 16), landmarks, 12)
	-- Volcanic island road markers
	createRoadMarker(Vector3.new(0, 0, -118), landmarks, "NorthHarbourGate")
	createRoadMarker(Vector3.new(-138, 0, -28), landmarks, "WestAshFork")
	createRoadMarker(Vector3.new(138, 0, -24), landmarks, "EastSaltFork")
	createRoadMarker(Vector3.new(-8, 0, 132), landmarks, "SouthScorchFork")
	createRoadMarker(Vector3.new(-278, 0, -82), landmarks, "GlacierPass")
	createRoadMarker(Vector3.new(280, 0, 78), landmarks, "CalderaRoad")

	local spawnPoint = getSpawnPoint()
	local spawnRingCount = detailCount(12, 8)
	for index = 1, spawnRingCount do
		local angle = (math.pi * 2) * (index / spawnRingCount)
		local radius = 13
		local stone = createPart(
			"SpawnRingStone",
			Vector3.new(2.8, 1.1, 2.2),
			CFrame.new(spawnPoint.X + math.cos(angle) * radius, 0.35, spawnPoint.Z + math.sin(angle) * radius)
				* CFrame.Angles(0, angle, decorRandom:NextNumber(-0.2, 0.2)),
			Color3.fromRGB(112, 116, 105),
			landmarks
		)
		stone.Shape = Enum.PartType.Ball
		stone.Material = Enum.Material.Slate
		stone.CanCollide = false
	end

	local perimeterBoulderCount = detailCount(24, 12)
	for index = 1, perimeterBoulderCount do
		local angle = (math.pi * 2) * (index / perimeterBoulderCount) + decorRandom:NextNumber(-0.08, 0.08)
		local radius = Config.World.SpawnAreaHalfSize * decorRandom:NextNumber(0.92, 1.08)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = sampleTerrainHeight(x, z)
		local boulder = createPart(
			"PerimeterBoulder",
			Vector3.new(
				decorRandom:NextNumber(5, 11),
				decorRandom:NextNumber(2.5, 6),
				decorRandom:NextNumber(5, 12)
			),
			CFrame.new(x, y + 0.8, z)
				* CFrame.Angles(0, decorRandom:NextNumber(0, math.pi), 0),
			Color3.fromRGB(86, 93, 88),
			landmarks
		)
		boulder.Shape = Enum.PartType.Ball
		boulder.Material = Enum.Material.Slate
	end

	for index = 1, detailCount(8, 4) do
		local angle = decorRandom:NextNumber(0, math.pi * 2)
		local radius = decorRandom:NextNumber(35, Config.World.SpawnAreaHalfSize * 0.8)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = sampleTerrainHeight(x, z)
		local log = createPart(
			"FallenLog",
			Vector3.new(decorRandom:NextNumber(3, 4.5), decorRandom:NextNumber(12, 18), 3),
			CFrame.new(x, y + 1.2, z)
				* CFrame.Angles(math.rad(90), decorRandom:NextNumber(0, math.pi), 0),
			Color3.fromRGB(90, 61, 42),
			landmarks
		)
		log.Shape = Enum.PartType.Cylinder
		log.Material = Enum.Material.Wood
	end

	for index = 1, detailCount(54, 22) do
		local angle = decorRandom:NextNumber(0, math.pi * 2)
		local radius = decorRandom:NextNumber(18, Config.World.SpawnAreaHalfSize * 0.9)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		createGrassClump(Vector3.new(x, sampleTerrainHeight(x, z), z), landmarks)
	end

	for index = 1, detailCount(30, 12) do
		local angle = decorRandom:NextNumber(0, math.pi * 2)
		local radius = decorRandom:NextNumber(24, Config.World.SpawnAreaHalfSize * 0.85)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		createLeafLitter(Vector3.new(x, sampleTerrainHeight(x, z), z), landmarks)
	end

	optimizeLandmarkPerformance(landmarks)
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

	if not structureIndexBound then
		structureIndexBound = true
		structuresFolder.ChildAdded:Connect(indexStructure)
		structuresFolder.ChildRemoved:Connect(unindexStructure)
	end
	rebuildStructureIndex()

	if not worldFolder:FindFirstChild("Ground") then
		local ground = createPart(
			"Ground",
			Vector3.new(Config.World.SpawnAreaHalfSize * 2.35, 4, Config.World.SpawnAreaHalfSize * 2.35),
			CFrame.new(0, -20, 0),
			FORTRESS_THEME.Grass,
			worldFolder
		)
		ground.Material = Enum.Material.Grass
		ground.Transparency = 1
		ground.CanTouch = false
		ground.CanQuery = false
	end

	setupTerrain(worldFolder)
	setupLandmarks(worldFolder)

	if not Workspace:FindFirstChild("SurvivalSpawn") then
		local spawnPoint = getSpawnPoint()
		local spawnY = sampleTerrainHeight(spawnPoint.X, spawnPoint.Z) + Config.World.RespawnHeight
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SurvivalSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.CFrame = CFrame.new(spawnPoint.X, spawnY, spawnPoint.Z)
		spawn.Color = FORTRESS_THEME.WeatheredStone
		spawn.Material = Enum.Material.Cobblestone
		spawn.Parent = Workspace
	else
		local spawnPoint = getSpawnPoint()
		local spawnY = sampleTerrainHeight(spawnPoint.X, spawnPoint.Z) + Config.World.RespawnHeight
		local spawn = Workspace:FindFirstChild("SurvivalSpawn")
		spawn.CFrame = CFrame.new(spawnPoint.X, spawnY, spawnPoint.Z)
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

	for _, structure in ipairs(getStructuresByName(modelName)) do
		if modelName == "Campfire" and structure:GetAttribute("Lit") == false then
			continue
		end

		if structure.PrimaryPart then
			local distance = (structure.PrimaryPart.Position - root.Position).Magnitude
			if distance <= radius then
				return true
			end
		else
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

local function chooseWeatherFromWeights(weights)
	local totalWeight = 0

	for weatherId, weight in pairs(weights) do
		if Config.Weather[weatherId] and weight > 0 then
			totalWeight += weight
		end
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = random:NextNumber(0, totalWeight)
	local running = 0

	for weatherId, weight in pairs(weights) do
		if Config.Weather[weatherId] and weight > 0 then
			running += weight

			if roll <= running then
				return weatherId
			end
		end
	end

	return nil
end

local function chooseWeather()
	local sessionSeconds = os.clock() - sessionStartedAt
	if sessionSeconds < EARLY_WEATHER_WINDOW_SECONDS then
		local earlyWeatherId = chooseWeatherFromWeights(EARLY_WEATHER_WEIGHTS)
		if earlyWeatherId then
			return earlyWeatherId
		end
	end

	local fullWeights = {}
	for weatherId, weatherConfig in pairs(Config.Weather) do
		fullWeights[weatherId] = weatherConfig.Weight or 1
	end

	return chooseWeatherFromWeights(fullWeights) or "Clear"
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
	local discoveredRegions = player and cloneMap(visitedRegionsByPlayer[player]) or {}

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
		RegionId = region and region.Id or nil,
		DiscoveredRegions = discoveredRegions,
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

function WorldService.isProtectedFromWeather(player)
	local shelterConfig = Config.Buildables.ShelterKit
	local watchtowerConfig = Config.Buildables.WatchtowerKit
	local campfireConfig = Config.Buildables.CampfireKit

	return findNearbyStructure(player.Character, "Shelter", shelterConfig.Radius)
		or findNearbyStructure(player.Character, "Watchtower", watchtowerConfig.ShelterRadius or watchtowerConfig.Radius)
		or findNearbyStructure(player.Character, "Campfire", campfireConfig.Radius)
end

function WorldService.isNearStructure(player, modelName, radius)
	return findNearbyStructure(player.Character, modelName, radius)
end

function WorldService.getStructuresFolder()
	return structuresFolder
end

function WorldService.getStructuresByName(modelName)
	if type(modelName) ~= "string" then
		return {}
	end

	return getStructuresByName(modelName)
end

function WorldService.getRegionForPosition(position)
	return getRegionForPosition(position)
end

function WorldService.getRegions()
	return Config.Regions
end

function WorldService.getTerrainHeightAt(x, z)
	return sampleTerrainHeight(x, z)
end

function WorldService.getSnapshot(player)
	return {
		DiscoveredRegions = cloneMap(visitedRegionsByPlayer[player]),
	}
end

function WorldService.applySnapshot(player, snapshot)
	snapshot = type(snapshot) == "table" and snapshot or {}
	visitedRegionsByPlayer[player] = cloneMap(snapshot.DiscoveredRegions)
	WorldService.sendWorldState(player)
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
				local shouldSendWorldState = false
				local currentRegion = getPlayerRegion(player)
				local currentRegionId = currentRegion and currentRegion.Id or nil
				if lastRegionIdByPlayer[player] ~= currentRegionId then
					lastRegionIdByPlayer[player] = currentRegionId
					shouldSendWorldState = true
				end

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

						markPlayerDirty(player)
						shouldSendWorldState = true
					end
				end

				if shouldSendWorldState then
					WorldService.sendWorldState(player)
				end
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
	local region = getPlayerRegion(player)
	lastRegionIdByPlayer[player] = region and region.Id or nil
	WorldService.sendWorldState(player)
end

function WorldService.playerRemoving(player)
	visitedRegionsByPlayer[player] = nil
	lastRegionIdByPlayer[player] = nil
end

return WorldService
