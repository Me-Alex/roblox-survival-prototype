-- WorldService.lua  (Milestone 6a)
-- Changes from Milestone 2:
--   • spawnBedroll(position) builds a visible bedroll model and attaches
--     a ProximityPrompt tagged IsBedroll=true so SleepService can detect it.
--   • isRaining() stub added (returns false until weather system is wired up).

local Lighting   = game:GetService("Lighting")
local Workspace  = game:GetService("Workspace")

local WorldService = {}
local ctx
local dayTimer = 0
local day      = 1

-- ── Public init ───────────────────────────────────────────────────────────

function WorldService:init(context)
    ctx = context
    self:setupLighting()
    self:generateTerrain()
    self:spawnResourceNodes()
    self:spawnCampfire(Vector3.new(0, 2, 20))
    print("[WorldService] World generated")
end

-- ── Lighting ─────────────────────────────────────────────────────────────

function WorldService:setupLighting()
    Lighting.ClockTime         = 9
    Lighting.Brightness        = 1.8
    Lighting.GlobalShadows     = true
    Lighting.Ambient           = Color3.fromRGB(58, 44, 34)
    Lighting.OutdoorAmbient    = Color3.fromRGB(94, 72, 52)
    Lighting.ColorShift_Top    = Color3.fromRGB(255, 178, 88)
    Lighting.ColorShift_Bottom = Color3.fromRGB(64, 44, 36)
    Lighting.FogEnd            = 1400
    Lighting.FogStart          = 600
    Lighting.FogColor          = Color3.fromRGB(140, 100, 60)

    local atmo = Lighting:FindFirstChild("Atmosphere") or Instance.new("Atmosphere")
    atmo.Name="Atmosphere" atmo.Density=0.55
    atmo.Color=Color3.fromRGB(172,122,72) atmo.Decay=Color3.fromRGB(68,44,32)
    atmo.Glare=0.3 atmo.Haze=3.2 atmo.Parent=Lighting

    local bloom = Lighting:FindFirstChild("Bloom") or Instance.new("BloomEffect")
    bloom.Name="Bloom" bloom.Intensity=0.35 bloom.Size=26 bloom.Threshold=1.0 bloom.Parent=Lighting

    local cc = Lighting:FindFirstChild("ColorCorrection") or Instance.new("ColorCorrectionEffect")
    cc.Name="ColorCorrection" cc.Brightness=-0.05 cc.Contrast=0.25
    cc.Saturation=0.10 cc.TintColor=Color3.fromRGB(255,215,168) cc.Parent=Lighting
end

-- ── Terrain generation ────────────────────────────────────────────────────

function WorldService:generateTerrain()
    if Workspace:FindFirstChild("_TerrainGenDone") then return end
    local marker = Instance.new("BoolValue")
    marker.Name = "_TerrainGenDone" marker.Parent = Workspace

    local terrain = Workspace.Terrain
    terrain:Clear()

    local cfg   = ctx.Config.World
    local half  = cfg.HalfSize
    local step  = 24
    local rng   = Random.new(cfg.Seed)

    terrain:FillBlock(
        CFrame.new(0, -80, 0),
        Vector3.new(half * 4, 60, half * 4),
        Enum.Material.Water
    )

    local islandRadius = half - 60

    for x = -half, half, step do
        for z = -half, half, step do
            local dist2 = x*x + z*z
            if dist2 <= islandRadius * islandRadius then
                local normalised = math.sqrt(dist2) / islandRadius
                local baseH = math.lerp(40, 2, normalised)
                local noise = rng:NextNumber(-4, 6)
                local height = math.max(2, baseH + noise)

                local mat
                if normalised < 0.2 then
                    mat = Enum.Material.Basalt
                elseif normalised < 0.6 then
                    mat = Enum.Material.Slate
                elseif normalised < 0.85 then
                    mat = Enum.Material.Rock
                else
                    mat = Enum.Material.Sand
                end

                terrain:FillBlock(
                    CFrame.new(x, -height/2, z),
                    Vector3.new(step, height, step),
                    mat
                )
            end
        end
    end

    local caldRadius = 90
    for x = -caldRadius, caldRadius, step do
        for z = -caldRadius, caldRadius, step do
            local r = math.sqrt(x*x + z*z)
            if r >= 50 and r <= caldRadius then
                terrain:FillBlock(
                    CFrame.new(x, 20, z),
                    Vector3.new(step, 44, step),
                    Enum.Material.Basalt
                )
            elseif r < 50 then
                terrain:FillBlock(
                    CFrame.new(x, 2, z),
                    Vector3.new(step, 4, step),
                    Enum.Material.Neon
                )
            end
        end
    end

    local beachOuter = islandRadius + 20
    local beachInner = islandRadius - 10
    for x = -beachOuter, beachOuter, step do
        for z = -beachOuter, beachOuter, step do
            local r = math.sqrt(x*x + z*z)
            if r >= beachInner and r <= beachOuter then
                terrain:FillBlock(
                    CFrame.new(x, -0.5, z),
                    Vector3.new(step, 1, step),
                    Enum.Material.Sand
                )
            end
        end
    end

    terrain:FillBlock(
        CFrame.new(0, 0, 0),
        Vector3.new(80, 4, 80),
        Enum.Material.Slate
    )

    if not Workspace:FindFirstChild("SurvivalSpawn") then
        local spawn = Instance.new("SpawnLocation")
        spawn.Name="SurvivalSpawn" spawn.Anchored=true
        spawn.Size=Vector3.new(10,1,10) spawn.CFrame=CFrame.new(0,2,0)
        spawn.Color=Color3.fromRGB(88,72,52) spawn.Material=Enum.Material.Cobblestone
        spawn.Parent=Workspace
    end
end

-- ── Resource node spawning ────────────────────────────────────────────────

local spawnedPositions = {}

local function tooClose(pos, minDist)
    for _, p in ipairs(spawnedPositions) do
        if (pos - p).Magnitude < minDist then return true end
    end
    return false
end

local function safePosition(rng, halfRange, minDist, clearRadius)
    clearRadius = clearRadius or 50
    for _ = 1, 40 do
        local x = rng:NextNumber(-halfRange, halfRange)
        local z = rng:NextNumber(-halfRange, halfRange)
        local pos = Vector3.new(x, 4, z)
        if math.sqrt(x*x + z*z) < clearRadius then continue end
        if math.sqrt(x*x + z*z) < 120 then continue end
        if not tooClose(pos, minDist) then
            table.insert(spawnedPositions, pos)
            return pos
        end
    end
    return nil
end

local function makeNodePart(pos, size, color, material, nodeType)
    local p = Instance.new("Part")
    p.Anchored       = true
    p.Size           = size
    p.CFrame         = CFrame.new(pos)
    p.Color          = color
    p.Material       = material
    p.CastShadow     = true
    p.Name           = nodeType .. "Node"

    local nt = Instance.new("StringValue")
    nt.Name  = "NodeType"
    nt.Value = nodeType
    nt.Parent = p

    local harvested = Instance.new("BoolValue")
    harvested.Name  = "Harvested"
    harvested.Value = false
    harvested.Parent = p

    local hitsLeft = Instance.new("IntValue")
    hitsLeft.Name  = "HitsLeft"
    hitsLeft.Value = ctx.Config.Resources.Hits[nodeType] or 1
    hitsLeft.Parent = p

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText    = "Harvest"
    prompt.ObjectText    = nodeType
    prompt.HoldDuration  = 0
    prompt.MaxActivationDistance = 8
    prompt.Parent = p

    p.Parent = Workspace
    return p
end

function WorldService:spawnResourceNodes()
    if Workspace:FindFirstChild("_ResourcesDone") then return end
    local marker = Instance.new("BoolValue")
    marker.Name = "_ResourcesDone" marker.Parent = Workspace

    local cfg  = ctx.Config
    local rng  = Random.new(cfg.World.Seed + 1)
    local half = cfg.World.HalfSize - 80
    local minD = cfg.Resources.MinSpacing

    for _ = 1, cfg.Resources.TreeCount do
        local pos = safePosition(rng, half, minD)
        if pos then
            makeNodePart(pos + Vector3.new(0, 4, 0),
                Vector3.new(2.5, 8, 2.5),
                Color3.fromRGB(40, 32, 28), Enum.Material.Wood, "Tree")
            local crown = Instance.new("Part")
            crown.Anchored=true crown.Shape=Enum.PartType.Ball
            crown.Size=Vector3.new(7,6,7)
            crown.CFrame=CFrame.new(pos + Vector3.new(0, 10, 0))
            crown.Color=Color3.fromRGB(52, 48, 44)
            crown.Material=Enum.Material.Grass
            crown.CastShadow=false crown.CanCollide=false
            crown.Name="TreeCrown" crown.Parent=Workspace
        end
    end

    for _ = 1, cfg.Resources.RockCount do
        local pos = safePosition(rng, half, minD)
        if pos then
            local sz = rng:NextNumber(2, 4)
            makeNodePart(pos + Vector3.new(0, sz/2, 0),
                Vector3.new(sz*1.4, sz, sz*1.2),
                Color3.fromRGB(56, 48, 44), Enum.Material.Basalt, "Rock")
        end
    end

    for _ = 1, cfg.Resources.BushCount do
        local pos = safePosition(rng, half, minD)
        if pos then
            makeNodePart(pos + Vector3.new(0, 1.2, 0),
                Vector3.new(3, 2.4, 3),
                Color3.fromRGB(160, 60, 30), Enum.Material.Grass, "Bush")
        end
    end

    for _ = 1, cfg.Resources.FiberCount do
        local pos = safePosition(rng, half, minD)
        if pos then
            makeNodePart(pos + Vector3.new(0, 0.6, 0),
                Vector3.new(3.5, 1.2, 3.5),
                Color3.fromRGB(130, 120, 90), Enum.Material.LeafyGrass, "Fiber")
        end
    end

    print("[WorldService] Resource nodes spawned")
end

-- ── Campfire ──────────────────────────────────────────────────────────────

function WorldService:spawnCampfire(position)
    local cf = Instance.new("Part")
    cf.Name="Campfire" cf.Anchored=true
    cf.Size=Vector3.new(3,1,3) cf.CFrame=CFrame.new(position)
    cf.Color=Color3.fromRGB(180,90,20) cf.Material=Enum.Material.Neon

    local light = Instance.new("PointLight")
    light.Brightness=4 light.Range=ctx.Config.Vitals.CampfireWarmRadius*1.5
    light.Color=Color3.fromRGB(255,160,60) light.Parent=cf

    Instance.new("BoolValue", cf).Name="IsCampfire"
    local fuel=Instance.new("IntValue",cf) fuel.Name="Fuel" fuel.Value=100

    cf.Parent=Workspace
    return cf
end

-- ── Bedroll ───────────────────────────────────────────────────────────────
-- Builds a small visible bedroll from Parts, places it at `position`, and
-- attaches a ProximityPrompt that SleepService (Milestone 6b) will watch.
--
-- MODEL LAYOUT (all Parts anchored, no physics):
--
--   [Frame base]  – a flat dark-wood rectangle  (6 × 0.4 × 3)
--   [Mattress]    – a slightly raised padded slab (5.4 × 0.5 × 2.6)  dark-green
--   [Pillow]      – a small raised block at one end (1.6 × 0.4 × 1.2)  cream
--   [ProximityPrompt] on the Frame, ActionText="Sleep"  HoldDuration=1.5
--   [IsBedroll BoolValue]  – tag so SleepService can find it
--   [Owner StringValue]    – stores player.UserId so only the owner can sleep
--   [Cooldown BoolValue]   – set to true after sleeping, cleared at dawn

function WorldService:spawnBedroll(position, ownerUserId)
    local folder = Instance.new("Model")
    folder.Name = "Bedroll"

    -- Frame base
    local frame = Instance.new("Part")
    frame.Name     = "BedrollFrame"
    frame.Anchored = true
    frame.Size     = Vector3.new(6, 0.4, 3)
    frame.CFrame   = CFrame.new(position + Vector3.new(0, 0.2, 0))
    frame.Color    = Color3.fromRGB(80, 55, 35)
    frame.Material = Enum.Material.Wood
    frame.Parent   = folder

    -- Mattress
    local mattress = Instance.new("Part")
    mattress.Name     = "Mattress"
    mattress.Anchored = true
    mattress.Size     = Vector3.new(5.4, 0.5, 2.6)
    mattress.CFrame   = CFrame.new(position + Vector3.new(0, 0.65, 0))
    mattress.Color    = Color3.fromRGB(55, 80, 55)
    mattress.Material = Enum.Material.Fabric
    mattress.Parent   = folder

    -- Pillow (at the +Z end)
    local pillow = Instance.new("Part")
    pillow.Name     = "Pillow"
    pillow.Anchored = true
    pillow.Size     = Vector3.new(1.6, 0.4, 1.2)
    pillow.CFrame   = CFrame.new(position + Vector3.new(0, 1.05, 1.1))
    pillow.Color    = Color3.fromRGB(220, 200, 160)
    pillow.Material = Enum.Material.Fabric
    pillow.Parent   = folder

    -- Tags
    local isBedroll = Instance.new("BoolValue", frame)
    isBedroll.Name  = "IsBedroll"
    isBedroll.Value = true

    local ownerVal = Instance.new("StringValue", frame)
    ownerVal.Name  = "Owner"
    ownerVal.Value = tostring(ownerUserId or "")

    local cooldown = Instance.new("BoolValue", frame)
    cooldown.Name  = "Cooldown"
    cooldown.Value = false

    -- ProximityPrompt on the frame so players standing near it get the prompt
    local prompt = Instance.new("ProximityPrompt", frame)
    prompt.ActionText            = "Sleep"
    prompt.ObjectText            = "Bedroll"
    prompt.HoldDuration          = 1.5   -- hold for 1.5s to confirm sleep
    prompt.MaxActivationDistance = 6
    prompt.RequiresLineOfSight   = false
    -- SleepService wires up .Triggered in Milestone 6b

    folder.PrimaryPart = frame
    folder.Parent      = Workspace
    return folder
end

-- ── Day / night tick ──────────────────────────────────────────────────────

function WorldService:tick(dt)
    local cfg      = ctx.Config.World
    local Players  = game:GetService("Players")
    dayTimer       = dayTimer + dt

    if dayTimer >= cfg.DayLengthSecs then
        dayTimer = dayTimer - cfg.DayLengthSecs
        day      = day + 1
        -- Clear bedroll cooldowns at dawn so players can sleep again next night
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Cooldown" and obj:IsA("BoolValue") then
                obj.Value = false
            end
        end
    end

    local fraction  = dayTimer / cfg.DayLengthSecs
    local clockTime = fraction * 24
    Lighting.ClockTime = clockTime

    local isNight = clockTime >= cfg.NightStartClock or clockTime < cfg.NightEndClock
    local targetBrightness = isNight and 0.4 or 1.8
    Lighting.Brightness = Lighting.Brightness + (targetBrightness - Lighting.Brightness) * dt * 0.5

    if math.floor(dayTimer) % 2 == 0 then
        for _, player in ipairs(Players:GetPlayers()) do
            ctx.Remotes.DayNightUpdate:FireClient(player, { day=day, isNight=isNight })
        end
    end

    -- Campfire warming
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:FindFirstChild("IsCampfire") then
            local cfPos = obj.CFrame.Position
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (root.Position - cfPos).Magnitude
                    if dist <= ctx.Config.Vitals.CampfireWarmRadius then
                        ctx.VitalsService:adjustTemperature(player, ctx.Config.Vitals.CampfireWarmRate * dt)
                    end
                end
            end
        end
    end
end

function WorldService:getDay()   return day end
function WorldService:getDayTimer() return dayTimer end
function WorldService:isNight()
    local t = Lighting.ClockTime
    return t >= ctx.Config.World.NightStartClock or t < ctx.Config.World.NightEndClock
end
function WorldService:isRaining() return false end  -- stub; extend in weather milestone
function WorldService:skipToMorning()
    -- Jump dayTimer to just past dawn (NightEndClock / 24 * DayLengthSecs)
    local cfg   = ctx.Config.World
    local dawn  = (cfg.NightEndClock / 24) * cfg.DayLengthSecs
    dayTimer    = dawn + 1
    Lighting.ClockTime = cfg.NightEndClock + 0.1
end

return WorldService
