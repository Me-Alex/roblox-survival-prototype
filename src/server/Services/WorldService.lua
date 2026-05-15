local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WorldService = { _isWorldService = true }

local ctx
local day = 1
local dayTimer = 0
local claimedResourceSpots = {}

local worldState = {
    seed = 42,
    runtimeSeed = 42,
    halfSize = 600,
    islandRadius = 520,
    beachRadius = 485,
    spawnFlatRadius = 110,
    step = 24,
    oceanFloorY = -160,
    oceanSurfaceY = 0,
    centerX = 0,
    centerZ = 0,
    radialPower = 1.45,
    heightScale = 22,
    macroScale = 170,
    microScale = 65,
    detailScale = 32,
    macroStrength = 8,
    microStrength = 4,
    detailStrength = 1.6,
    ridgeAngle = 0,
    ridgeStrength = 0,
    ridgeFrequency = 0.006,
    beachSoftness = 1,
}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function getWorldConfig()
    local cfg = (ctx and ctx.Config and ctx.Config.World) or {}
    local halfSize = tonumber(cfg.HalfSize or cfg.SpawnAreaHalfSize) or 600
    halfSize = math.max(220, halfSize)

    local spawnPoint = cfg.SpawnPoint
    if typeof(spawnPoint) ~= "Vector3" then
        spawnPoint = Vector3.new(0, 0, 24)
    end

    return {
        seed = tonumber(cfg.Seed) or 42,
        halfSize = halfSize,
        dayLength = math.max(60, tonumber(cfg.DayLengthSecs or cfg.DayLengthSeconds) or 480),
        nightStart = tonumber(cfg.NightStartClock or cfg.NightStart) or 19,
        nightEnd = tonumber(cfg.NightEndClock or cfg.NightEnd) or 6,
        spawnPoint = spawnPoint,
    }
end

local function hashString(str)
    if type(str) ~= "string" or str == "" then
        return 0
    end
    local h = 0
    for i = 1, #str do
        h = (h * 33 + string.byte(str, i)) % 2147483647
    end
    return h
end

local function resolveRuntimeSeed(baseSeed)
    local millis = DateTime.now().UnixTimestampMillis % 2147483647
    local jobHash = hashString(game.JobId)
    local mixed = (baseSeed * 1103515245 + millis + jobHash * 97 + 12345) % 2147483647
    if mixed < 1 then
        mixed = mixed + 2147483629
    end
    return mixed
end

local function configureTerrainShape(cfg)
    local runtimeSeed = resolveRuntimeSeed(cfg.seed)
    worldState.runtimeSeed = runtimeSeed
    worldState.seed = runtimeSeed

    local rng = Random.new(runtimeSeed)
    worldState.centerX = rng:NextNumber(-70, 70)
    worldState.centerZ = rng:NextNumber(-70, 70)
    worldState.radialPower = rng:NextNumber(1.2, 1.95)
    worldState.heightScale = rng:NextNumber(18, 29)

    worldState.macroScale = rng:NextNumber(145, 235)
    worldState.microScale = rng:NextNumber(45, 95)
    worldState.detailScale = rng:NextNumber(24, 42)
    worldState.macroStrength = rng:NextNumber(6, 11)
    worldState.microStrength = rng:NextNumber(2.5, 5.8)
    worldState.detailStrength = rng:NextNumber(0.8, 2.2)

    worldState.ridgeAngle = rng:NextNumber(0, math.pi * 2)
    worldState.ridgeStrength = rng:NextNumber(1.5, 6.5)
    worldState.ridgeFrequency = rng:NextNumber(0.0035, 0.0095)
    worldState.beachSoftness = rng:NextNumber(0.65, 1.35)
end

local function isInsideIslandXZ(x, z, padding)
    padding = padding or 0
    local dist = math.sqrt(x * x + z * z)
    return dist <= (worldState.islandRadius - padding)
end

local function terrainProfileAt(x, z)
    local worldX = x - worldState.centerX
    local worldZ = z - worldState.centerZ

    local warpX = math.noise(worldX / (worldState.macroScale * 1.8), worldZ / (worldState.macroScale * 1.8), worldState.seed * 0.004) * 26
    local warpZ = math.noise(worldX / (worldState.macroScale * 1.8), worldZ / (worldState.macroScale * 1.8), worldState.seed * 0.006) * 26
    worldX = worldX + warpX
    worldZ = worldZ + warpZ

    local dist = math.sqrt(worldX * worldX + worldZ * worldZ)
    if dist > worldState.islandRadius then
        return nil
    end

    local radial = dist / worldState.islandRadius
    local base = worldState.heightScale * (1 - radial ^ worldState.radialPower) + 4

    local macro = math.noise((worldX + worldState.seed * 0.17) / worldState.macroScale, (worldZ - worldState.seed * 0.23) / worldState.macroScale, worldState.seed * 0.001)
    local micro = math.noise((worldX - worldState.seed * 0.31) / worldState.microScale, (worldZ + worldState.seed * 0.11) / worldState.microScale, worldState.seed * 0.002)
    local detail = math.noise((worldX + worldState.seed * 0.47) / worldState.detailScale, (worldZ + worldState.seed * 0.19) / worldState.detailScale, worldState.seed * 0.003)
    local ridgeAxis = (worldX * math.cos(worldState.ridgeAngle) + worldZ * math.sin(worldState.ridgeAngle))
    local ridge = math.sin(ridgeAxis * worldState.ridgeFrequency) * worldState.ridgeStrength

    local height = base + macro * worldState.macroStrength + micro * worldState.microStrength + detail * worldState.detailStrength + ridge

    local flatAlpha = 1 - math.clamp(dist / worldState.spawnFlatRadius, 0, 1)
    if flatAlpha > 0 then
        local target = 6 + micro * 0.9
        height = lerp(height, target, flatAlpha * 0.9)
    end

    if dist > worldState.beachRadius then
        local beachAlpha = math.clamp((dist - worldState.beachRadius) / math.max(1, (worldState.islandRadius - worldState.beachRadius)), 0, 1)
        beachAlpha = math.clamp(beachAlpha * worldState.beachSoftness, 0, 1)
        local beachHeight = lerp(3.2, 0.8, beachAlpha)
        height = math.min(height, beachHeight + micro * 0.4)
    end

    height = math.clamp(height, 0.35, 46)

    local material
    if radial > 0.9 then
        material = Enum.Material.Sand
    elseif height < 4.8 then
        material = Enum.Material.Mud
    elseif height > 28 then
        material = Enum.Material.Rock
    elseif height > 16 then
        material = Enum.Material.Slate
    else
        material = Enum.Material.Grass
    end

    return {
        height = height,
        material = material,
        dist = dist,
    }
end

local function clearGeneratedWorld()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name == "SurvivalWorld"
            or obj.Name == "WaterPuddle"
            or obj.Name == "NightStalker"
            or obj.Name == "Rabbit"
            or obj.Name == "Deer"
            or obj.Name == "Bedroll"
            or obj.Name == "TreeCrown"
        then
            obj:Destroy()
        elseif obj:IsA("BasePart") then
            if obj.Name == "Campfire"
                or obj:FindFirstChild("NodeType")
                or obj:FindFirstChild("IsCampfire")
                or obj:GetAttribute("IsStoneOven")
            then
                obj:Destroy()
            end
        elseif obj:IsA("Model") then
            local primary = obj.PrimaryPart
            if primary and primary:GetAttribute("IsStoneOven") then
                obj:Destroy()
            end
        end
    end
end

local function createResourceNode(position, size, color, material, nodeType)
    local node = Instance.new("Part")
    node.Name = nodeType .. "Node"
    node.Anchored = true
    node.Size = size
    node.CFrame = CFrame.new(position)
    node.Color = color
    node.Material = material
    node.CastShadow = true

    local nodeTypeValue = Instance.new("StringValue")
    nodeTypeValue.Name = "NodeType"
    nodeTypeValue.Value = nodeType
    nodeTypeValue.Parent = node

    local harvested = Instance.new("BoolValue")
    harvested.Name = "Harvested"
    harvested.Value = false
    harvested.Parent = node

    local hitsLeft = Instance.new("IntValue")
    hitsLeft.Name = "HitsLeft"
    hitsLeft.Value = ((ctx.Config.Resources and ctx.Config.Resources.Hits) and ctx.Config.Resources.Hits[nodeType]) or 1
    hitsLeft.Parent = node

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Harvest"
    prompt.ObjectText = nodeType
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 8
    prompt.Parent = node

    node.Parent = Workspace
    return node
end

function WorldService:setupLighting()
    Lighting.ClockTime = 9
    Lighting.Brightness = 1.8
    Lighting.GlobalShadows = true
    Lighting.Ambient = Color3.fromRGB(58, 44, 34)
    Lighting.OutdoorAmbient = Color3.fromRGB(94, 72, 52)
    Lighting.ColorShift_Top = Color3.fromRGB(255, 178, 88)
    Lighting.ColorShift_Bottom = Color3.fromRGB(64, 44, 36)
    Lighting.FogEnd = 1400
    Lighting.FogStart = 600
    Lighting.FogColor = Color3.fromRGB(140, 100, 60)

    local atmo = Lighting:FindFirstChild("Atmosphere") or Instance.new("Atmosphere")
    atmo.Name = "Atmosphere"
    atmo.Density = 0.52
    atmo.Color = Color3.fromRGB(172, 122, 72)
    atmo.Decay = Color3.fromRGB(68, 44, 32)
    atmo.Glare = 0.3
    atmo.Haze = 3.1
    atmo.Parent = Lighting

    local bloom = Lighting:FindFirstChild("Bloom") or Instance.new("BloomEffect")
    bloom.Name = "Bloom"
    bloom.Intensity = 0.32
    bloom.Size = 24
    bloom.Threshold = 1.0
    bloom.Parent = Lighting

    local cc = Lighting:FindFirstChild("ColorCorrection") or Instance.new("ColorCorrectionEffect")
    cc.Name = "ColorCorrection"
    cc.Brightness = -0.05
    cc.Contrast = 0.22
    cc.Saturation = 0.08
    cc.TintColor = Color3.fromRGB(255, 215, 168)
    cc.Parent = Lighting
end

function WorldService:generateTerrain()
    local cfg = getWorldConfig()
    configureTerrainShape(cfg)
    worldState.halfSize = cfg.halfSize
    worldState.islandRadius = math.max(160, cfg.halfSize - 70)
    worldState.spawnFlatRadius = math.clamp(worldState.islandRadius * 0.22, 90, 165)
    worldState.beachRadius = math.max(worldState.spawnFlatRadius + 220, worldState.islandRadius - 40)
    worldState.step = 24
    worldState.oceanFloorY = -160
    worldState.oceanSurfaceY = 0

    clearGeneratedWorld()
    table.clear(claimedResourceSpots)

    local terrain = Workspace.Terrain
    terrain:Clear()
    print("[WorldService] Runtime terrain seed:", worldState.runtimeSeed)

    local oceanDepth = worldState.oceanSurfaceY - worldState.oceanFloorY
    terrain:FillBlock(
        CFrame.new(0, worldState.oceanFloorY + oceanDepth * 0.5, 0),
        Vector3.new(worldState.halfSize * 4, oceanDepth, worldState.halfSize * 4),
        Enum.Material.Water
    )

    for x = -worldState.halfSize, worldState.halfSize, worldState.step do
        for z = -worldState.halfSize, worldState.halfSize, worldState.step do
            local profile = terrainProfileAt(x, z)
            if profile then
                local thickness = profile.height - worldState.oceanFloorY
                terrain:FillBlock(
                    CFrame.new(x, worldState.oceanFloorY + thickness * 0.5, z),
                    Vector3.new(worldState.step, thickness, worldState.step),
                    profile.material
                )
            end
        end
    end

    local spawnY = self:getTerrainHeightAt(cfg.spawnPoint.X, cfg.spawnPoint.Z)
    local spawn = Workspace:FindFirstChild("SurvivalSpawn")
    if not spawn then
        spawn = Instance.new("SpawnLocation")
        spawn.Name = "SurvivalSpawn"
        spawn.Anchored = true
        spawn.Size = Vector3.new(10, 1, 10)
        spawn.Color = Color3.fromRGB(88, 72, 52)
        spawn.Material = Enum.Material.Cobblestone
        spawn.Parent = Workspace
    end
    spawn.CFrame = CFrame.new(cfg.spawnPoint.X, spawnY + 1.1, cfg.spawnPoint.Z)
end

function WorldService.getTerrainHeightAt(a, b, c)
    local x
    local z
    if type(a) == "table" and a._isWorldService then
        x = b
        z = c
    else
        x = a
        z = b
    end

    x = tonumber(x) or 0
    z = tonumber(z) or 0

    local profile = terrainProfileAt(x, z)
    if profile then
        return profile.height
    end
    return worldState.oceanSurfaceY
end

function WorldService:isInsideIsland(x, z, padding)
    return isInsideIslandXZ(tonumber(x) or 0, tonumber(z) or 0, padding)
end

function WorldService:isLavaAt(_x, _z)
    return false
end

function WorldService:sampleGroundPosition(options)
    options = options or {}
    local rng = options.rng or Random.new(worldState.seed + 33)

    local minRadius = math.max(0, tonumber(options.minRadius) or 0)
    local maxRadius = tonumber(options.maxRadius) or (worldState.islandRadius - 20)
    maxRadius = math.min(maxRadius, worldState.islandRadius - (tonumber(options.edgePadding) or 20))
    if maxRadius <= minRadius then
        return nil
    end

    local avoidRadius = math.max(0, tonumber(options.avoidRadius) or 0)
    local attempts = math.max(1, tonumber(options.attempts) or 48)
    local minHeight = tonumber(options.minHeight) or -math.huge
    local maxHeight = tonumber(options.maxHeight) or math.huge
    local center = options.center
    local cx = (typeof(center) == "Vector3" and center.X) or 0
    local cz = (typeof(center) == "Vector3" and center.Z) or 0

    for _ = 1, attempts do
        local angle = rng:NextNumber(0, math.pi * 2)
        local radius = math.sqrt(rng:NextNumber(minRadius * minRadius, maxRadius * maxRadius))
        local x = cx + math.cos(angle) * radius
        local z = cz + math.sin(angle) * radius

        if not isInsideIslandXZ(x, z, tonumber(options.edgePadding) or 20) then
            continue
        end
        if avoidRadius > 0 and (x * x + z * z) < (avoidRadius * avoidRadius) then
            continue
        end

        local y = self:getTerrainHeightAt(x, z)
        if y < minHeight or y > maxHeight then
            continue
        end
        if options.requireDry ~= false and y <= worldState.oceanSurfaceY + 0.05 then
            continue
        end

        return Vector3.new(x, y, z)
    end

    return nil
end

function WorldService:snapToGround(position, heightOffset, _allowLava)
    if typeof(position) ~= "Vector3" then
        return Vector3.new(0, 1, 0)
    end

    local y = self:getTerrainHeightAt(position.X, position.Z)
    return Vector3.new(position.X, y + (tonumber(heightOffset) or 0), position.Z)
end

local function isTooCloseToClaimed(pos, minDist)
    for _, existing in ipairs(claimedResourceSpots) do
        if (existing - pos).Magnitude < minDist then
            return true
        end
    end
    return false
end

local function claimResourcePosition(rng, minDist)
    for _ = 1, 90 do
        local pos = WorldService:sampleGroundPosition({
            rng = rng,
            minRadius = worldState.spawnFlatRadius + 18,
            maxRadius = worldState.islandRadius - 44,
            avoidRadius = worldState.spawnFlatRadius - 20,
            minHeight = worldState.oceanSurfaceY + 0.8,
            attempts = 1,
            edgePadding = 28,
        })
        if pos and not isTooCloseToClaimed(pos, minDist) then
            table.insert(claimedResourceSpots, pos)
            return pos
        end
    end
    return nil
end

function WorldService:spawnResourceNodes()
    local resources = (ctx.Config and ctx.Config.Resources) or {}
    local rng = Random.new(worldState.seed + 1)
    local minSpacing = resources.MinSpacing or 18
    table.clear(claimedResourceSpots)

    for _ = 1, (resources.TreeCount or 0) do
        local pos = claimResourcePosition(rng, minSpacing)
        if pos then
            createResourceNode(
                pos + Vector3.new(0, 4, 0),
                Vector3.new(2.5, 8, 2.5),
                Color3.fromRGB(40, 32, 28),
                Enum.Material.Wood,
                "Tree"
            )
            local crown = Instance.new("Part")
            crown.Name = "TreeCrown"
            crown.Anchored = true
            crown.Shape = Enum.PartType.Ball
            crown.Size = Vector3.new(7, 6, 7)
            crown.CFrame = CFrame.new(pos + Vector3.new(0, 10, 0))
            crown.Color = Color3.fromRGB(52, 48, 44)
            crown.Material = Enum.Material.Grass
            crown.CastShadow = false
            crown.CanCollide = false
            crown.Parent = Workspace
        end
    end

    for _ = 1, (resources.RockCount or 0) do
        local pos = claimResourcePosition(rng, minSpacing)
        if pos then
            local size = rng:NextNumber(2, 4)
            createResourceNode(
                pos + Vector3.new(0, size * 0.5, 0),
                Vector3.new(size * 1.4, size, size * 1.2),
                Color3.fromRGB(56, 48, 44),
                Enum.Material.Basalt,
                "Rock"
            )
        end
    end

    for _ = 1, (resources.BushCount or 0) do
        local pos = claimResourcePosition(rng, minSpacing)
        if pos then
            createResourceNode(
                pos + Vector3.new(0, 1.2, 0),
                Vector3.new(3, 2.4, 3),
                Color3.fromRGB(160, 60, 30),
                Enum.Material.Grass,
                "Bush"
            )
        end
    end

    for _ = 1, (resources.FiberCount or 0) do
        local pos = claimResourcePosition(rng, minSpacing)
        if pos then
            createResourceNode(
                pos + Vector3.new(0, 0.6, 0),
                Vector3.new(3.5, 1.2, 3.5),
                Color3.fromRGB(130, 120, 90),
                Enum.Material.LeafyGrass,
                "Fiber"
            )
        end
    end

    print("[WorldService] Resource nodes spawned")
end

function WorldService:spawnCampfire(position)
    local grounded = self:snapToGround(position, 0.5, false)
    local campfire = Instance.new("Part")
    campfire.Name = "Campfire"
    campfire.Anchored = true
    campfire.Size = Vector3.new(3, 1, 3)
    campfire.CFrame = CFrame.new(grounded)
    campfire.Color = Color3.fromRGB(180, 90, 20)
    campfire.Material = Enum.Material.Neon

    local light = Instance.new("PointLight")
    light.Brightness = 4
    light.Range = ((ctx.Config.Vitals and ctx.Config.Vitals.CampfireWarmRadius) or 18) * 1.5
    light.Color = Color3.fromRGB(255, 160, 60)
    light.Parent = campfire

    Instance.new("BoolValue", campfire).Name = "IsCampfire"
    local fuel = Instance.new("IntValue", campfire)
    fuel.Name = "Fuel"
    fuel.Value = 100
    campfire.Parent = Workspace
    return campfire
end

function WorldService:spawnBedroll(position, ownerUserId)
    local grounded = self:snapToGround(position, 0, false)
    local model = Instance.new("Model")
    model.Name = "Bedroll"

    local frame = Instance.new("Part")
    frame.Name = "BedrollFrame"
    frame.Anchored = true
    frame.Size = Vector3.new(6, 0.4, 3)
    frame.CFrame = CFrame.new(grounded + Vector3.new(0, 0.2, 0))
    frame.Color = Color3.fromRGB(80, 55, 35)
    frame.Material = Enum.Material.Wood
    frame.Parent = model

    local mattress = Instance.new("Part")
    mattress.Name = "Mattress"
    mattress.Anchored = true
    mattress.Size = Vector3.new(5.4, 0.5, 2.6)
    mattress.CFrame = CFrame.new(grounded + Vector3.new(0, 0.65, 0))
    mattress.Color = Color3.fromRGB(55, 80, 55)
    mattress.Material = Enum.Material.Fabric
    mattress.Parent = model

    local pillow = Instance.new("Part")
    pillow.Name = "Pillow"
    pillow.Anchored = true
    pillow.Size = Vector3.new(1.6, 0.4, 1.2)
    pillow.CFrame = CFrame.new(grounded + Vector3.new(0, 1.05, 1.1))
    pillow.Color = Color3.fromRGB(220, 200, 160)
    pillow.Material = Enum.Material.Fabric
    pillow.Parent = model

    local isBedroll = Instance.new("BoolValue", frame)
    isBedroll.Name = "IsBedroll"
    isBedroll.Value = true

    local owner = Instance.new("StringValue", frame)
    owner.Name = "Owner"
    owner.Value = tostring(ownerUserId or "")

    local cooldown = Instance.new("BoolValue", frame)
    cooldown.Name = "Cooldown"
    cooldown.Value = false

    local prompt = Instance.new("ProximityPrompt", frame)
    prompt.ActionText = "Sleep"
    prompt.ObjectText = "Bedroll"
    prompt.HoldDuration = 1.5
    prompt.MaxActivationDistance = 6
    prompt.RequiresLineOfSight = false

    model.PrimaryPart = frame
    model.Parent = Workspace
    return model
end

function WorldService:init(context)
    ctx = context
    self:setupLighting()
    self:generateTerrain()
    self:spawnResourceNodes()

    local starterCampfire = self:sampleGroundPosition({
        minRadius = 18,
        maxRadius = 65,
        attempts = 30,
    }) or Vector3.new(0, 2, 20)
    self:spawnCampfire(starterCampfire)

    print("[WorldService] World generated")
end

function WorldService:tick(dt)
    local cfg = getWorldConfig()
    dayTimer = dayTimer + dt

    if dayTimer >= cfg.dayLength then
        dayTimer = dayTimer - cfg.dayLength
        day = day + 1
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BoolValue") and obj.Name == "Cooldown" then
                obj.Value = false
            end
        end
    end

    local fraction = dayTimer / cfg.dayLength
    local clockTime = fraction * 24
    Lighting.ClockTime = clockTime

    local nightNow = clockTime >= cfg.nightStart or clockTime < cfg.nightEnd
    local targetBrightness = nightNow and 0.4 or 1.8
    Lighting.Brightness = Lighting.Brightness + (targetBrightness - Lighting.Brightness) * dt * 0.5

    if math.floor(dayTimer) % 2 == 0 then
        for _, player in ipairs(Players:GetPlayers()) do
            ctx.Remotes.DayNightUpdate:FireClient(player, { day = day, isNight = nightNow })
        end
    end

    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") and obj:FindFirstChild("IsCampfire") then
            local campPos = obj.Position
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (root.Position - campPos).Magnitude
                    if dist <= ((ctx.Config.Vitals and ctx.Config.Vitals.CampfireWarmRadius) or 18) then
                        if ctx.VitalsService and ctx.VitalsService.adjustTemperature then
                            ctx.VitalsService:adjustTemperature(
                                player,
                                ((ctx.Config.Vitals and ctx.Config.Vitals.CampfireWarmRate) or 4) * dt
                            )
                        end
                    end
                end
            end
        end
    end
end

function WorldService:getDay()
    return day
end

function WorldService:getDayTimer()
    return dayTimer
end

function WorldService:isNight()
    local cfg = getWorldConfig()
    local t = Lighting.ClockTime
    return t >= cfg.nightStart or t < cfg.nightEnd
end

function WorldService:isRaining()
    return false
end

function WorldService:skipToMorning()
    local cfg = getWorldConfig()
    local dawn = (cfg.nightEnd / 24) * cfg.dayLength
    dayTimer = dawn + 1
    Lighting.ClockTime = cfg.nightEnd + 0.1
end

return WorldService
