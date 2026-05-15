local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WorldService = { _isWorldService = true }

local ctx
local dayTimer = 0
local day = 1
local spawnedPositions = {}

local terrainState = {
    seed = 42,
    halfSize = 600,
    islandRadius = 540,
    lavaCoreRadius = 48,
    lavaRimRadius = 96,
    beachInnerRadius = 500,
    step = 24,
    oceanFloorY = -160,
    oceanSurfaceY = 0,
}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function getWorldConfig()
    local worldCfg = (ctx and ctx.Config and ctx.Config.World) or {}
    local halfSize = tonumber(worldCfg.HalfSize or worldCfg.SpawnAreaHalfSize) or 600
    halfSize = math.max(200, halfSize)

    local seed = tonumber(worldCfg.Seed) or 42
    local dayLength = tonumber(worldCfg.DayLengthSecs or worldCfg.DayLengthSeconds) or 480
    local nightStart = tonumber(worldCfg.NightStartClock or worldCfg.NightStart) or 19
    local nightEnd = tonumber(worldCfg.NightEndClock or worldCfg.NightEnd) or 6

    local spawnPoint = worldCfg.SpawnPoint
    if typeof(spawnPoint) ~= "Vector3" then
        spawnPoint = Vector3.new(0, 0, 24)
    end

    return {
        seed = seed,
        halfSize = halfSize,
        dayLength = math.max(60, dayLength),
        nightStart = nightStart,
        nightEnd = nightEnd,
        spawnPoint = spawnPoint,
    }
end

local function surfaceProfileAt(x, z)
    local dist = math.sqrt(x * x + z * z)
    if dist > terrainState.islandRadius then
        return nil
    end

    local normalized = dist / terrainState.islandRadius
    local radialHeight = 46 * (1 - normalized ^ 1.35) + 1.2

    local n1 = math.noise((x + terrainState.seed * 0.11) / 150, (z - terrainState.seed * 0.17) / 150, terrainState.seed * 0.001)
    local n2 = math.noise((x - terrainState.seed * 0.29) / 60, (z + terrainState.seed * 0.07) / 60, terrainState.seed * 0.002)
    local height = radialHeight + n1 * 7 + n2 * 3

    if dist < terrainState.lavaCoreRadius then
        height = math.min(height, 2.4)
    elseif dist < terrainState.lavaRimRadius then
        local rimAlpha = (dist - terrainState.lavaCoreRadius) / (terrainState.lavaRimRadius - terrainState.lavaCoreRadius)
        local rimHeight = 23 + rimAlpha * 12
        height = math.max(height, rimHeight + n2 * 1.2)
    end

    if dist > terrainState.beachInnerRadius then
        local beachAlpha = math.clamp(
            (dist - terrainState.beachInnerRadius) / (terrainState.islandRadius - terrainState.beachInnerRadius),
            0,
            1
        )
        local beachHeight = lerp(3.2, 0.7, beachAlpha)
        height = math.min(height, beachHeight + n2 * 0.5)
    end

    height = math.clamp(height, 0.35, 58)

    local material
    if dist < terrainState.lavaCoreRadius + 3 then
        material = Enum.Material.Basalt
    elseif dist < terrainState.lavaRimRadius then
        material = Enum.Material.Basalt
    elseif normalized < 0.55 then
        material = Enum.Material.Slate
    elseif normalized < 0.85 then
        material = Enum.Material.Rock
    else
        material = Enum.Material.Sand
    end

    return {
        height = height,
        material = material,
        dist = dist,
    }
end

local function isLavaZone(x, z)
    local dist = math.sqrt(x * x + z * z)
    return dist < (terrainState.lavaCoreRadius + 6)
end

local function isInsideIsland(x, z, padding)
    padding = padding or 0
    local dist = math.sqrt(x * x + z * z)
    return dist <= (terrainState.islandRadius - padding)
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
    atmo.Density = 0.55
    atmo.Color = Color3.fromRGB(172, 122, 72)
    atmo.Decay = Color3.fromRGB(68, 44, 32)
    atmo.Glare = 0.3
    atmo.Haze = 3.2
    atmo.Parent = Lighting

    local bloom = Lighting:FindFirstChild("Bloom") or Instance.new("BloomEffect")
    bloom.Name = "Bloom"
    bloom.Intensity = 0.35
    bloom.Size = 26
    bloom.Threshold = 1.0
    bloom.Parent = Lighting

    local cc = Lighting:FindFirstChild("ColorCorrection") or Instance.new("ColorCorrectionEffect")
    cc.Name = "ColorCorrection"
    cc.Brightness = -0.05
    cc.Contrast = 0.25
    cc.Saturation = 0.10
    cc.TintColor = Color3.fromRGB(255, 215, 168)
    cc.Parent = Lighting
end

function WorldService:generateTerrain()
    if Workspace:FindFirstChild("_TerrainGenDone") then
        return
    end

    local worldCfg = getWorldConfig()
    terrainState.seed = worldCfg.seed
    terrainState.halfSize = worldCfg.halfSize
    terrainState.islandRadius = math.max(140, worldCfg.halfSize - 62)
    terrainState.lavaCoreRadius = math.clamp(terrainState.islandRadius * 0.088, 40, 68)
    terrainState.lavaRimRadius = math.clamp(terrainState.islandRadius * 0.178, terrainState.lavaCoreRadius + 22, 130)
    terrainState.beachInnerRadius = math.max(terrainState.lavaRimRadius + 80, terrainState.islandRadius - 36)
    terrainState.step = 24
    terrainState.oceanFloorY = -160
    terrainState.oceanSurfaceY = 0

    local marker = Instance.new("BoolValue")
    marker.Name = "_TerrainGenDone"
    marker.Parent = Workspace

    local terrain = Workspace.Terrain
    terrain:Clear()

    local oceanDepth = terrainState.oceanSurfaceY - terrainState.oceanFloorY
    terrain:FillBlock(
        CFrame.new(0, terrainState.oceanFloorY + oceanDepth * 0.5, 0),
        Vector3.new(terrainState.halfSize * 4, oceanDepth, terrainState.halfSize * 4),
        Enum.Material.Water
    )

    for x = -terrainState.halfSize, terrainState.halfSize, terrainState.step do
        for z = -terrainState.halfSize, terrainState.halfSize, terrainState.step do
            local profile = surfaceProfileAt(x, z)
            if profile then
                local thickness = profile.height - terrainState.oceanFloorY
                terrain:FillBlock(
                    CFrame.new(x, terrainState.oceanFloorY + thickness * 0.5, z),
                    Vector3.new(terrainState.step, thickness, terrainState.step),
                    profile.material
                )

                if profile.dist < (terrainState.lavaCoreRadius - 4) then
                    terrain:FillBlock(
                        CFrame.new(x, profile.height + 0.6, z),
                        Vector3.new(terrainState.step, 1.2, terrainState.step),
                        Enum.Material.Neon
                    )
                end
            end
        end
    end

    local spawnY = self:getTerrainHeightAt(worldCfg.spawnPoint.X, worldCfg.spawnPoint.Z)
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
    spawn.CFrame = CFrame.new(worldCfg.spawnPoint.X, spawnY + 1.1, worldCfg.spawnPoint.Z)
end

function WorldService.getTerrainHeightAt(a, b, c)
    local x, z
    if type(a) == "table" and a._isWorldService then
        x, z = b, c
    else
        x, z = a, b
    end

    x = tonumber(x) or 0
    z = tonumber(z) or 0

    local profile = surfaceProfileAt(x, z)
    if profile then
        return profile.height
    end
    return terrainState.oceanSurfaceY
end

function WorldService:isLavaAt(x, z)
    return isLavaZone(tonumber(x) or 0, tonumber(z) or 0)
end

function WorldService:isInsideIsland(x, z, padding)
    return isInsideIsland(tonumber(x) or 0, tonumber(z) or 0, padding)
end

function WorldService:snapToGround(position, heightOffset, allowLava)
    if typeof(position) ~= "Vector3" then
        return Vector3.new(0, 1, 0)
    end

    local y = self:getTerrainHeightAt(position.X, position.Z)
    local snapped = Vector3.new(position.X, y + (tonumber(heightOffset) or 0), position.Z)

    if allowLava or not self:isLavaAt(position.X, position.Z) then
        return snapped
    end

    local fallback = self:sampleGroundPosition({
        minRadius = terrainState.lavaRimRadius + 18,
        maxRadius = terrainState.islandRadius - 24,
        attempts = 24,
        excludeLava = true,
        minHeight = terrainState.oceanSurfaceY + 0.5,
    })

    if fallback then
        return fallback + Vector3.new(0, tonumber(heightOffset) or 0, 0)
    end
    return snapped
end

function WorldService:sampleGroundPosition(options)
    options = options or {}
    local worldRng = options.rng or Random.new(terrainState.seed + 13)

    local minRadius = math.max(0, tonumber(options.minRadius) or 0)
    local maxRadius = tonumber(options.maxRadius) or (terrainState.islandRadius - 20)
    maxRadius = math.min(maxRadius, terrainState.islandRadius - (tonumber(options.edgePadding) or 20))
    if maxRadius <= minRadius then
        return nil
    end

    local avoidRadius = math.max(0, tonumber(options.avoidRadius) or 0)
    local attempts = math.max(1, tonumber(options.attempts) or 48)
    local minHeight = tonumber(options.minHeight) or -math.huge
    local maxHeight = tonumber(options.maxHeight) or math.huge
    local center = options.center
    local centerX = (typeof(center) == "Vector3" and center.X) or 0
    local centerZ = (typeof(center) == "Vector3" and center.Z) or 0

    for _ = 1, attempts do
        local angle = worldRng:NextNumber(0, math.pi * 2)
        local radius = math.sqrt(worldRng:NextNumber(minRadius * minRadius, maxRadius * maxRadius))
        local x = centerX + math.cos(angle) * radius
        local z = centerZ + math.sin(angle) * radius

        if not isInsideIsland(x, z, tonumber(options.edgePadding) or 20) then
            continue
        end

        if avoidRadius > 0 and (x * x + z * z) < (avoidRadius * avoidRadius) then
            continue
        end

        if options.excludeLava and isLavaZone(x, z) then
            continue
        end

        local y = self:getTerrainHeightAt(x, z)
        if y < minHeight or y > maxHeight then
            continue
        end

        if options.requireDry ~= false and y <= terrainState.oceanSurfaceY + 0.05 then
            continue
        end

        return Vector3.new(x, y, z)
    end

    return nil
end

local function tooClose(pos, minDist)
    for _, existing in ipairs(spawnedPositions) do
        if (pos - existing).Magnitude < minDist then
            return true
        end
    end
    return false
end

local function reserveGroundPosition(rng, minDist)
    for _ = 1, 80 do
        local pos = WorldService:sampleGroundPosition({
            rng = rng,
            minRadius = terrainState.lavaRimRadius + 24,
            maxRadius = terrainState.islandRadius - 40,
            avoidRadius = terrainState.lavaRimRadius + 8,
            excludeLava = true,
            minHeight = terrainState.oceanSurfaceY + 0.8,
            attempts = 1,
            edgePadding = 28,
        })
        if pos and not tooClose(pos, minDist) then
            table.insert(spawnedPositions, pos)
            return pos
        end
    end
    return nil
end

local function makeNodePart(pos, size, color, material, nodeType)
    local node = Instance.new("Part")
    node.Anchored = true
    node.Size = size
    node.CFrame = CFrame.new(pos)
    node.Color = color
    node.Material = material
    node.CastShadow = true
    node.Name = nodeType .. "Node"

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
    hitsLeft.Value = (ctx.Config.Resources.Hits and ctx.Config.Resources.Hits[nodeType]) or 1
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

function WorldService:spawnResourceNodes()
    if Workspace:FindFirstChild("_ResourcesDone") then
        return
    end

    local marker = Instance.new("BoolValue")
    marker.Name = "_ResourcesDone"
    marker.Parent = Workspace

    table.clear(spawnedPositions)

    local cfg = ctx.Config
    local rng = Random.new((terrainState.seed or 42) + 1)
    local minSpacing = (cfg.Resources and cfg.Resources.MinSpacing) or 18

    for _ = 1, (cfg.Resources.TreeCount or 0) do
        local pos = reserveGroundPosition(rng, minSpacing)
        if pos then
            makeNodePart(
                pos + Vector3.new(0, 4, 0),
                Vector3.new(2.5, 8, 2.5),
                Color3.fromRGB(40, 32, 28),
                Enum.Material.Wood,
                "Tree"
            )

            local crown = Instance.new("Part")
            crown.Anchored = true
            crown.Shape = Enum.PartType.Ball
            crown.Size = Vector3.new(7, 6, 7)
            crown.CFrame = CFrame.new(pos + Vector3.new(0, 10, 0))
            crown.Color = Color3.fromRGB(52, 48, 44)
            crown.Material = Enum.Material.Grass
            crown.CastShadow = false
            crown.CanCollide = false
            crown.Name = "TreeCrown"
            crown.Parent = Workspace
        end
    end

    for _ = 1, (cfg.Resources.RockCount or 0) do
        local pos = reserveGroundPosition(rng, minSpacing)
        if pos then
            local size = rng:NextNumber(2, 4)
            makeNodePart(
                pos + Vector3.new(0, size * 0.5, 0),
                Vector3.new(size * 1.4, size, size * 1.2),
                Color3.fromRGB(56, 48, 44),
                Enum.Material.Basalt,
                "Rock"
            )
        end
    end

    for _ = 1, (cfg.Resources.BushCount or 0) do
        local pos = reserveGroundPosition(rng, minSpacing)
        if pos then
            makeNodePart(
                pos + Vector3.new(0, 1.2, 0),
                Vector3.new(3, 2.4, 3),
                Color3.fromRGB(160, 60, 30),
                Enum.Material.Grass,
                "Bush"
            )
        end
    end

    for _ = 1, (cfg.Resources.FiberCount or 0) do
        local pos = reserveGroundPosition(rng, minSpacing)
        if pos then
            makeNodePart(
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

    local ownerVal = Instance.new("StringValue", frame)
    ownerVal.Name = "Owner"
    ownerVal.Value = tostring(ownerUserId or "")

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

    local starterCampfirePos = self:sampleGroundPosition({
        minRadius = 20,
        maxRadius = 65,
        excludeLava = true,
        attempts = 30,
    }) or Vector3.new(0, 2, 20)
    self:spawnCampfire(starterCampfirePos)

    print("[WorldService] World generated")
end

function WorldService:tick(dt)
    local worldCfg = getWorldConfig()
    dayTimer = dayTimer + dt

    if dayTimer >= worldCfg.dayLength then
        dayTimer = dayTimer - worldCfg.dayLength
        day = day + 1

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BoolValue") and obj.Name == "Cooldown" then
                obj.Value = false
            end
        end
    end

    local fraction = dayTimer / worldCfg.dayLength
    local clockTime = fraction * 24
    Lighting.ClockTime = clockTime

    local isNightNow = clockTime >= worldCfg.nightStart or clockTime < worldCfg.nightEnd
    local targetBrightness = isNightNow and 0.4 or 1.8
    Lighting.Brightness = Lighting.Brightness + (targetBrightness - Lighting.Brightness) * dt * 0.5

    if math.floor(dayTimer) % 2 == 0 then
        for _, player in ipairs(Players:GetPlayers()) do
            ctx.Remotes.DayNightUpdate:FireClient(player, { day = day, isNight = isNightNow })
        end
    end

    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") and obj:FindFirstChild("IsCampfire") then
            local campfirePos = obj.Position
            for _, player in ipairs(Players:GetPlayers()) do
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (root.Position - campfirePos).Magnitude
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
    local worldCfg = getWorldConfig()
    local clock = Lighting.ClockTime
    return clock >= worldCfg.nightStart or clock < worldCfg.nightEnd
end

function WorldService:isRaining()
    return false
end

function WorldService:skipToMorning()
    local worldCfg = getWorldConfig()
    local dawn = (worldCfg.nightEnd / 24) * worldCfg.dayLength
    dayTimer = dawn + 1
    Lighting.ClockTime = worldCfg.nightEnd + 0.1
end

return WorldService
