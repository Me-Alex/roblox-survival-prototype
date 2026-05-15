-- WaterService.lua  (Milestone 9)
--
-- PURPOSE:
--   Adds physical water sources (puddles / shallow pools) to the island.
--   Players approach a puddle and press E to collect DirtyWater.
--   DirtyWater can be drunk raw (gives Poison debuff) or boiled at a
--   campfire / stone oven to make CleanWater (safe to drink, +60 thirst).
--
-- DESIGN INTENT:
--   Thirst is the fastest-draining vital (1.5 per second). Before this
--   milestone the only reliable restoration was food with thirstRestore.
--   Water sources give players a dedicated thirst mechanic:
--
--     Puddle → DirtyWater (inventory item)
--       ├─ Drink raw → +25 thirst, BUT triggers Poisoned (takes damage each tick)
--       └─ Boil (campfire or oven) → CleanWater → +60 thirst, no penalty
--
-- PUDDLE MODEL:
--   A flat blue glowing disc on the ground plus a small ripple ring.
--   Very cheap to render (2 anchored Parts per puddle).
--
-- REFILL:
--   Each puddle has a Cooldown. After being collected it becomes semi-
--   transparent and cannot be used again until RespawnTime seconds pass,
--   then it fully reappears.

local Workspace = game:GetService("Workspace")

local WaterService = {}
local ctx

-- Table of puddle entries
-- { model, disc, prompt, cooldown (seconds left, 0 = ready) }
local puddles = {}
local puddlePositions = {}

local PUDDLE_COUNT   = 20
local REFILL_TIME    = 45   -- seconds before puddle refills
local COLLECT_RADIUS = 8    -- studs; max distance to collect

local RNG = Random.new()

-- ── Build puddle model ────────────────────────────────────────────────────

local function buildPuddle(position)
    local model = Instance.new("Model")
    model.Name  = "WaterPuddle"

    -- Main water disc
    local disc = Instance.new("Part")
    disc.Name        = "Disc"
    disc.Shape       = Enum.PartType.Cylinder
    disc.Anchored    = true
    disc.CanCollide  = false
    disc.Size        = Vector3.new(0.3, 4.5, 4.5)   -- thin cylinder lying flat
    disc.CFrame      = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    disc.Color       = Color3.fromRGB(60, 130, 200)
    disc.Material    = Enum.Material.Neon
    disc.Transparency = 0.35
    disc.CastShadow  = false
    disc.Parent      = model

    -- Outer ripple ring (slightly larger, more transparent)
    local ring = Instance.new("Part")
    ring.Name        = "Ring"
    ring.Shape       = Enum.PartType.Cylinder
    ring.Anchored    = true
    ring.CanCollide  = false
    ring.Size        = Vector3.new(0.15, 6.0, 6.0)
    ring.CFrame      = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    ring.Color       = Color3.fromRGB(100, 170, 230)
    ring.Material    = Enum.Material.Neon
    ring.Transparency = 0.65
    ring.CastShadow  = false
    ring.Parent      = model

    -- ProximityPrompt on the disc
    local prompt = Instance.new("ProximityPrompt", disc)
    prompt.ActionText             = "Collect Water"
    prompt.ObjectText             = "Puddle"
    prompt.HoldDuration           = 0.8
    prompt.MaxActivationDistance  = COLLECT_RADIUS
    prompt.KeyboardKeyCode        = Enum.KeyCode.E

    model.PrimaryPart = disc
    model.Parent      = Workspace
    return model, disc, ring, prompt
end

-- ── Spawn helpers ─────────────────────────────────────────────────────────

local function tooCloseToExisting(position, minDistance)
    for _, existing in ipairs(puddlePositions) do
        if (existing - position).Magnitude < minDistance then
            return true
        end
    end
    return false
end

local function randomPuddlePos()
    if ctx and ctx.WorldService and ctx.WorldService.sampleGroundPosition then
        for _ = 1, 60 do
            local pos = ctx.WorldService:sampleGroundPosition({
                rng = RNG,
                minRadius = 105,
                maxRadius = 360,
                avoidRadius = 90,
                excludeLava = true,
                minHeight = 0.5,
                maxHeight = 14,
                edgePadding = 36,
                attempts = 1,
            })
            if pos and not tooCloseToExisting(pos, 22) then
                table.insert(puddlePositions, pos)
                return pos + Vector3.new(0, 0.1, 0)
            end
        end
    end

    for _ = 1, 30 do
        local angle = RNG:NextNumber(0, math.pi * 2)
        local r = RNG:NextNumber(100, 350)
        local x = math.cos(angle) * r
        local z = math.sin(angle) * r
        local fallback = Vector3.new(x, 2, z)
        if not tooCloseToExisting(fallback, 22) then
            table.insert(puddlePositions, fallback)
            return fallback
        end
    end

    local fallback = Vector3.new(200, 2, 100)
    table.insert(puddlePositions, fallback)
    return fallback
end

local function spawnPuddle()
    local pos = randomPuddlePos()
    local model, disc, ring, prompt = buildPuddle(pos)

    local entry = {
        model    = model,
        disc     = disc,
        ring     = ring,
        prompt   = prompt,
        cooldown = 0,
    }
    table.insert(puddles, entry)

    -- Wire up the ProximityPrompt
    prompt.Triggered:Connect(function(player)
        if entry.cooldown > 0 then
            ctx.Remotes.Notify:FireClient(player, {
                text  = "This puddle is dry. Wait a moment.",
                color = "yellow",
            })
            return
        end

        -- Give player 2x DirtyWater
        ctx.InventoryService:addItem(player, "DirtyWater", 2)
        ctx.Remotes.Notify:FireClient(player, {
            text  = "+2 Dirty Water  (Boil it to make it safe!)",
            color = "blue",
        })

        -- Start cooldown + visual
        entry.cooldown = REFILL_TIME
        disc.Transparency = 0.85
        ring.Transparency = 0.92
        prompt.Enabled    = false
    end)

    return entry
end

-- ── Init ─────────────────────────────────────────────────────────────────

function WaterService:init(context)
    ctx = context
    table.clear(puddlePositions)

    for _ = 1, PUDDLE_COUNT do
        spawnPuddle()
    end

    print("[WaterService] Spawned " .. #puddles .. " water puddles")
end

-- ── Tick ─────────────────────────────────────────────────────────────────
-- Counts down each puddle's cooldown and restores it when ready.

function WaterService:tick(dt)
    for _, entry in ipairs(puddles) do
        if entry.cooldown > 0 then
            entry.cooldown = entry.cooldown - dt
            if entry.cooldown <= 0 then
                entry.cooldown = 0
                -- Restore visual
                if entry.disc and entry.disc.Parent then
                    entry.disc.Transparency = 0.35
                    entry.ring.Transparency = 0.65
                    entry.prompt.Enabled    = true
                end
            end
        end
    end
end

return WaterService
