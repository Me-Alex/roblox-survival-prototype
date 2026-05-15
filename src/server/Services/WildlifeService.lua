-- WildlifeService.lua  (Milestone 7)
--
-- PURPOSE:
--   Populate the island with passive animals (Rabbit, Deer) that make
--   the world feel alive. Animals have two states:
--
--     IDLE  — wander slowly in a random direction, change direction every
--              few seconds. They never attack players.
--
--     FLEE  — when a player steps within FleeRadius, sprint away from
--              the nearest player until they are far enough away, then
--              return to IDLE.
--
-- HOW MODELS ARE BUILT:
--   Like NightStalkers, animals are built entirely from Parts so no
--   external Roblox models are needed. A Rabbit is a small white box
--   with two ear spikes. A Deer is a taller brown box with two antler
--   sticks and a white tail dot.
--
-- HOW HUNTING WORKS:
--   Animals are registered in a lookup table indexed by their root Part.
--   CombatService already fires AttackRequest from the client. We extend
--   CombatService to also check wildlife models. When an animal's health
--   hits 0, it drops items into the attacker's inventory and schedules
--   a respawn after RespawnTime seconds.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WildlifeService = {}
local ctx

-- Active animal entries indexed numerically for tick iteration
-- entry = { kind, model, root, health, maxHealth, state, fleeTimer,
--           wanderTimer, wanderDir, damageCooldown, killer, dead }
local animals = {}

-- Quick lookup: root Part -> entry  (used by CombatService)
local rootToEntry = {}

local RNG = Random.new()

-- ── Model builders ─────────────────────────────────────────────────────────

local function anchoredPart(parent, name, size, cf, color, material)
    local p = Instance.new("Part")
    p.Name       = name
    p.Anchored   = true
    p.CanCollide = false
    p.Size       = size
    p.CFrame     = cf
    p.Color      = color
    p.Material   = material or Enum.Material.SmoothPlastic
    p.CastShadow = false
    p.Parent     = parent
    return p
end

local function buildRabbit(pos)
    local model = Instance.new("Model")
    model.Name  = "Rabbit"

    local cf    = CFrame.new(pos)
    local white = Color3.fromRGB(230, 225, 215)
    local pink  = Color3.fromRGB(220, 160, 160)

    -- Body (root part)
    local body = anchoredPart(model, "Root", Vector3.new(1.2, 0.9, 1.6),
        cf * CFrame.new(0, 0.45, 0), white)
    body.CanCollide = false

    -- Head
    anchoredPart(model, "Head", Vector3.new(0.9, 0.8, 0.9),
        cf * CFrame.new(0, 1.05, -0.5), white)

    -- Ears (two thin upright boxes)
    anchoredPart(model, "EarL", Vector3.new(0.15, 0.7, 0.15),
        cf * CFrame.new(-0.22, 1.75, -0.5), pink)
    anchoredPart(model, "EarR", Vector3.new(0.15, 0.7, 0.15),
        cf * CFrame.new( 0.22, 1.75, -0.5), pink)

    -- Tail dot
    anchoredPart(model, "Tail", Vector3.new(0.3, 0.3, 0.3),
        cf * CFrame.new(0, 0.5, 0.8), white)

    -- HP billboard
    local bb = Instance.new("BillboardGui", body)
    bb.Size = UDim2.new(0, 40, 0, 6)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = false
    local bar = Instance.new("Frame", bb)
    bar.Name = "HpBar"
    bar.Size = UDim2.new(1,0,1,0)
    bar.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
    bar.BorderSizePixel = 0

    model.PrimaryPart = body
    model.Parent      = Workspace
    return model, body
end

local function buildDeer(pos)
    local model  = Instance.new("Model")
    model.Name   = "Deer"

    local cf     = CFrame.new(pos)
    local brown  = Color3.fromRGB(140, 90, 45)
    local dkBrown= Color3.fromRGB(90, 55, 25)
    local white  = Color3.fromRGB(230, 220, 200)

    -- Body (root)
    local body = anchoredPart(model, "Root", Vector3.new(2, 1.6, 3.2),
        cf * CFrame.new(0, 0.8, 0), brown)
    body.CanCollide = false

    -- Neck
    anchoredPart(model, "Neck", Vector3.new(0.8, 1.2, 0.8),
        cf * CFrame.new(0, 1.8, -1.0), brown)

    -- Head
    anchoredPart(model, "Head", Vector3.new(1.0, 0.9, 1.2),
        cf * CFrame.new(0, 2.65, -1.2), brown)

    -- Antlers (two angled sticks)
    anchoredPart(model, "AntlerL", Vector3.new(0.15, 1.0, 0.15),
        cf * CFrame.new(-0.4, 3.4, -1.2) * CFrame.Angles(0,0, math.rad(15)), dkBrown)
    anchoredPart(model, "AntlerR", Vector3.new(0.15, 1.0, 0.15),
        cf * CFrame.new( 0.4, 3.4, -1.2) * CFrame.Angles(0,0,-math.rad(15)), dkBrown)

    -- Legs (4 thin boxes)
    local legPositions = {
        Vector3.new(-0.6, -0.4, -1.0),
        Vector3.new( 0.6, -0.4, -1.0),
        Vector3.new(-0.6, -0.4,  1.0),
        Vector3.new( 0.6, -0.4,  1.0),
    }
    for _, lp in ipairs(legPositions) do
        anchoredPart(model, "Leg", Vector3.new(0.35, 1.0, 0.35),
            cf * CFrame.new(lp), dkBrown)
    end

    -- White tail
    anchoredPart(model, "Tail", Vector3.new(0.5, 0.5, 0.3),
        cf * CFrame.new(0, 0.9, 1.6), white)

    -- HP billboard
    local bb = Instance.new("BillboardGui", body)
    bb.Size = UDim2.new(0, 50, 0, 6)
    bb.StudsOffset = Vector3.new(0, 4.5, 0)
    bb.AlwaysOnTop = false
    local bar = Instance.new("Frame", bb)
    bar.Name = "HpBar"
    bar.Size = UDim2.new(1,0,1,0)
    bar.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
    bar.BorderSizePixel = 0

    model.PrimaryPart = body
    model.Parent      = Workspace
    return model, body
end

-- ── Spawn helpers ──────────────────────────────────────────────────────────

local function randomIslandPos()
    -- Keep animals away from the volcano centre (radius < 120)
    -- and away from the ocean edge (radius > 380)
    for _ = 1, 30 do
        local angle = RNG:NextNumber(0, math.pi * 2)
        local r     = RNG:NextNumber(130, 360)
        local x     = math.cos(angle) * r
        local z     = math.sin(angle) * r
        return Vector3.new(x, 5, z)
    end
    return Vector3.new(150, 5, 150)
end

local function spawnAnimal(kind)
    local cfg  = ctx.Config.Wildlife[kind]
    local pos  = randomIslandPos()
    local model, root

    if kind == "Rabbit" then
        model, root = buildRabbit(pos)
    else
        model, root = buildDeer(pos)
    end

    local entry = {
        kind          = kind,
        model         = model,
        root          = root,
        health        = cfg.Health,
        maxHealth     = cfg.Health,
        state         = "IDLE",
        wanderTimer   = RNG:NextNumber(2, 5),
        wanderDir     = Vector3.new(RNG:NextNumber(-1,1), 0, RNG:NextNumber(-1,1)).Unit,
        fleeTimer     = 0,
        damageCooldown= 0,
        killer        = nil,
        dead          = false,
    }

    rootToEntry[root] = entry
    table.insert(animals, entry)
    return entry
end

-- ── Move all parts of a model together ────────────────────────────────────────
-- Because all parts are Anchored we move each one by the same delta.

local function moveModel(entry, delta)
    local root = entry.root
    if not root or not root.Parent then return end

    -- Clamp to island radius
    local pos  = root.Position + delta
    local r2d  = math.sqrt(pos.X*pos.X + pos.Z*pos.Z)
    if r2d > 370 then
        -- Bounce back toward centre
        entry.wanderDir = (Vector3.new(0,0,0) - pos).Unit
        entry.wanderDir = Vector3.new(entry.wanderDir.X, 0, entry.wanderDir.Z)
        return
    end

    local model = entry.model
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CFrame = part.CFrame + delta
        end
    end
end

-- ── Death & loot ──────────────────────────────────────────────────────────────

local function killAnimal(entry)
    if entry.dead then return end
    entry.dead = true

    local cfg    = ctx.Config.Wildlife[entry.kind]
    local killer = entry.killer

    -- Give drops to killer
    if killer and killer.Parent then
        for _, drop in ipairs(cfg.Drops) do
            local amount = RNG:NextInteger(drop.min, drop.max)
            ctx.InventoryService:addItem(killer, drop.item, amount)
            local iCfg = ctx.Config.Items[drop.item]
            ctx.Remotes.Notify:FireClient(killer, {
                text  = "+" .. amount .. " " .. (iCfg and iCfg.displayName or drop.item),
                color = "green",
            })
        end
        if ctx.ProgressionService then
            if ctx.ProgressionService.addXp then
                ctx.ProgressionService:addXp(killer, cfg.KillXp, "hunting")
            elseif ctx.ProgressionService.addXP then
                ctx.ProgressionService:addXP(killer, cfg.KillXp, "hunting")
            end
        end
    end

    -- Remove from lookup and list
    rootToEntry[entry.root] = nil
    for i, a in ipairs(animals) do
        if a == entry then table.remove(animals, i) break end
    end

    -- Destroy model
    if entry.model and entry.model.Parent then
        entry.model:Destroy()
    end

    -- Schedule respawn
    task.delay(cfg.RespawnTime, function()
        spawnAnimal(entry.kind)
    end)
end

-- ── Public: called by CombatService ───────────────────────────────────────────

function WildlifeService:registerHit(rootPart, attacker, damage)
    local entry = rootToEntry[rootPart]
    if not entry or entry.dead then return false end

    entry.killer = attacker
    entry.health = math.max(0, entry.health - damage)

    -- Update HP bar
    local bb = entry.root:FindFirstChildOfClass("BillboardGui")
    if bb then
        local bar = bb:FindFirstChild("HpBar")
        if bar then
            bar.Size = UDim2.new(entry.health / entry.maxHealth, 0, 1, 0)
        end
    end

    -- Trigger flee on hit regardless of distance
    entry.state     = "FLEE"
    entry.fleeTimer = 6  -- flee for 6 seconds after being hit

    if entry.health <= 0 then
        killAnimal(entry)
    end

    return true
end

function WildlifeService:getEntryByRoot(rootPart)
    return rootToEntry[rootPart]
end

-- ── Init ──────────────────────────────────────────────────────────────────

function WildlifeService:init(context)
    ctx = context
    local cfg = ctx.Config.Wildlife

    for _ = 1, cfg.Rabbit.Count do spawnAnimal("Rabbit") end
    for _ = 1, cfg.Deer.Count   do spawnAnimal("Deer")   end

    print("[WildlifeService] Spawned " .. #animals .. " animals")
end

-- ── Tick ───────────────────────────────────────────────────────────────────

function WildlifeService:tick(dt)
    local i = 1
    while i <= #animals do
        local entry = animals[i]

        if entry.dead or not entry.root or not entry.root.Parent then
            table.remove(animals, i)
        else
            local cfg     = ctx.Config.Wildlife[entry.kind]
            local rootPos = entry.root.Position

            -- ── Check for nearby players ────────────────────────────────────
            local nearestPlayer, nearestDist = nil, math.huge
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local pr   = char and char:FindFirstChild("HumanoidRootPart")
                if pr then
                    local d = (pr.Position - rootPos).Magnitude
                    if d < nearestDist then
                        nearestDist  = d
                        nearestPlayer = pr
                    end
                end
            end

            if nearestPlayer and nearestDist < cfg.FleeRadius then
                entry.state     = "FLEE"
                entry.fleeTimer = 4
            end

            -- ── State machine ──────────────────────────────────────────────
            if entry.state == "IDLE" then
                -- Wander: drift slowly in wanderDir, change direction periodically
                entry.wanderTimer = entry.wanderTimer - dt
                if entry.wanderTimer <= 0 then
                    local angle       = RNG:NextNumber(0, math.pi * 2)
                    entry.wanderDir   = Vector3.new(math.cos(angle), 0, math.sin(angle))
                    entry.wanderTimer = RNG:NextNumber(2, 6)
                end
                local delta = entry.wanderDir * cfg.WanderSpeed * dt
                moveModel(entry, delta)

            elseif entry.state == "FLEE" then
                entry.fleeTimer = entry.fleeTimer - dt
                if entry.fleeTimer <= 0 then
                    entry.state = "IDLE"
                else
                    -- Sprint directly away from the nearest player
                    local fleeDir
                    if nearestPlayer then
                        fleeDir = (rootPos - nearestPlayer.Position)
                        fleeDir = Vector3.new(fleeDir.X, 0, fleeDir.Z)
                        if fleeDir.Magnitude > 0.1 then
                            fleeDir = fleeDir.Unit
                        else
                            fleeDir = entry.wanderDir
                        end
                    else
                        fleeDir = entry.wanderDir
                    end
                    local delta = fleeDir * cfg.FleeSpeed * dt
                    moveModel(entry, delta)
                end
            end

            i = i + 1
        end
    end
end

return WildlifeService
