-- EnemyService.lua  (Milestone 4)
-- Spawns NightStalker enemies at night. Each stalker:
--   1. Spawns at a random point on the island edge when night begins.
--   2. Every tick scans for the nearest player within AggroRadius.
--   3. If a player is found, moves toward them using a simple step (no pathfinding
--      library needed — we just set the NPC HumanoidRootPart CFrame directly).
--   4. Deals damage when close enough (MeleeRange).
--   5. Dies when health reaches 0 — drops RawMeat into the killer's inventory.
--   6. All stalkers are destroyed at sunrise.
--
-- WHY NO PathfindingService here:
--   PathfindingService is great but requires async calls and is hard to debug
--   for beginners. Instead we use direct vector movement: each tick we move the
--   NPC a small step toward the target. It works well on the flat volcanic terrain.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Random    = Random.new()

local EnemyService = {}
local ctx

-- Active stalker table: each entry = { model, humanoid, root, health, target, damageCooldown }
local stalkers     = {}
local spawnTimer   = 0
local SPAWN_INTERVAL = 8   -- try to spawn a new stalker every 8 seconds at night
local MeleeRange   = 5     -- studs — how close before dealing damage
local MeleeCooldown = 1.2  -- seconds between hits

-- ── Build a NightStalker model ────────────────────────────────────────────
-- We build the NPC entirely from Parts so there is no dependency on any
-- particular Roblox character model being in the game.

local function buildStalker(position)
    local model = Instance.new("Model")
    model.Name  = "NightStalker"

    -- Body
    local body = Instance.new("Part")
    body.Name     = "HumanoidRootPart"
    body.Size     = Vector3.new(2.5, 4, 2.5)
    body.CFrame   = CFrame.new(position)
    body.Color    = Color3.fromRGB(20, 14, 10)
    body.Material = Enum.Material.Neon
    body.Parent   = model

    -- Glowing eyes (two small neon parts)
    local function eye(offset)
        local e = Instance.new("Part")
        e.Name     = "Eye"
        e.Size     = Vector3.new(0.4, 0.4, 0.4)
        e.CFrame   = CFrame.new(position) * CFrame.new(offset)
        e.Color    = Color3.fromRGB(200, 50, 50)
        e.Material = Enum.Material.Neon
        e.CanCollide = false
        e.Anchored   = true
        e.Parent     = model
        return e
    end
    eye(Vector3.new(-0.5, 0.8, -1.1))
    eye(Vector3.new( 0.5, 0.8, -1.1))

    -- Humanoid (gives NPC health and lets us use :TakeDamage)
    local hum = Instance.new("Humanoid")
    hum.Name        = "Humanoid"
    hum.MaxHealth   = ctx.Config.Combat.NightStalker.Health
    hum.Health      = ctx.Config.Combat.NightStalker.Health
    hum.WalkSpeed   = ctx.Config.Combat.NightStalker.Speed
    hum.Parent      = model

    -- Health bar above head (BillboardGui)
    local billboard = Instance.new("BillboardGui")
    billboard.Size       = UDim2.new(0, 60, 0, 8)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent     = body

    local hpBar = Instance.new("Frame")
    hpBar.Name             = "HpBar"
    hpBar.Size             = UDim2.new(1, 0, 1, 0)
    hpBar.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    hpBar.BorderSizePixel  = 0
    hpBar.Parent           = billboard

    model.PrimaryPart = body
    model.Parent      = Workspace
    return model, hum, body
end

-- ── Spawn one stalker at the island edge ──────────────────────────────────

local function spawnStalker()
    local cfg    = ctx.Config.Combat.NightStalker
    if #stalkers >= cfg.MaxCount then return end

    local angle  = Random:NextNumber(0, math.pi * 2)
    local r      = cfg.SpawnRadius
    local x      = math.cos(angle) * r
    local z      = math.sin(angle) * r
    local pos    = Vector3.new(x, 6, z)

    local model, hum, root = buildStalker(pos)

    local entry = {
        model          = model,
        humanoid       = hum,
        root           = root,
        damageCooldown = 0,
        killer         = nil,   -- set when a player lands the kill
    }
    table.insert(stalkers, entry)

    -- Track last attacker for kill credit
    hum.HealthChanged:Connect(function(newHealth)
        -- Update health bar width
        local bar = root:FindFirstChild("BillboardGui") and
                    root.BillboardGui:FindFirstChild("HpBar")
        if bar then
            bar.Size = UDim2.new(newHealth / cfg.Health, 0, 1, 0)
        end
    end)

    -- On death: give drops, award XP, remove from table
    hum.Died:Connect(function()
        -- Drop loot to killer if we know who hit it last
        local killer = entry.killer
        if killer and killer.Parent then
            for _, drop in ipairs(cfg.Drops) do
                local amount = Random:NextInteger(drop.min, drop.max)
                ctx.InventoryService:addItem(killer, drop.item, amount)
                local itemCfg = ctx.Config.Items[drop.item]
                ctx.Remotes.Notify:FireClient(killer, {
                    text  = "+" .. amount .. " " .. (itemCfg and itemCfg.displayName or drop.item),
                    color = "green",
                })
            end
            if ctx.ProgressionService and ctx.ProgressionService.addXp then
                ctx.ProgressionService:addXp(killer, ctx.Config.Progression.KillXp)
            end
        end

        -- Remove from active list and destroy
        for i, s in ipairs(stalkers) do
            if s == entry then table.remove(stalkers, i) break end
        end
        task.delay(0.5, function()
            if model and model.Parent then model:Destroy() end
        end)
    end)
end

-- ── Movement helpers ──────────────────────────────────────────────────────

local function nearestPlayer(position)
    local best, bestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local d = (root.Position - position).Magnitude
            if d < bestDist then
                bestDist = d
                best     = player
            end
        end
    end
    return best, bestDist
end

local function stepToward(stalkerEntry, targetPos, dt)
    local root = stalkerEntry.root
    if not root or not root.Parent then return end

    local currentPos = root.Position
    local direction  = (targetPos - currentPos)
    local dist       = direction.Magnitude
    if dist < 0.5 then return end

    local speed = ctx.Config.Combat.NightStalker.Speed
    local step  = math.min(speed * dt, dist)
    local newPos = currentPos + direction.Unit * step

    -- Keep Y at 6 (float above terrain)
    newPos = Vector3.new(newPos.X, 6, newPos.Z)
    root.CFrame = CFrame.new(newPos, Vector3.new(targetPos.X, newPos.Y, targetPos.Z))

    -- Sync eye positions
    for _, child in ipairs(stalkerEntry.model:GetChildren()) do
        if child.Name == "Eye" then
            -- We keep eyes anchored; update them each tick relative to root
        end
    end
end

-- ── Init ──────────────────────────────────────────────────────────────────

function EnemyService:init(context)
    ctx = context

    -- CombatService registers hit on stalkers; it sets entry.killer
    -- via EnemyService:registerHit(model, attacker, damage)
    print("[EnemyService] Initialised")
end

-- Called by CombatService when a player hits a stalker
function EnemyService:registerHit(model, attacker, damage)
    for _, entry in ipairs(stalkers) do
        if entry.model == model then
            entry.killer = attacker
            local hum = entry.humanoid
            if hum and hum.Health > 0 then
                hum:TakeDamage(damage)
            end
            return
        end
    end
end

-- ── Tick ──────────────────────────────────────────────────────────────────

function EnemyService:tick(dt)
    local isNight = ctx.WorldService and ctx.WorldService:isNight() or false

    -- Spawn logic
    if isNight then
        spawnTimer = spawnTimer + dt
        if spawnTimer >= SPAWN_INTERVAL then
            spawnTimer = 0
            spawnStalker()
        end
    else
        -- Daytime: destroy all stalkers
        if #stalkers > 0 then
            for _, entry in ipairs(stalkers) do
                if entry.model and entry.model.Parent then
                    entry.model:Destroy()
                end
            end
            stalkers   = {}
            spawnTimer = 0
        end
    end

    -- Movement + melee tick
    local aggroRadius = ctx.Config.Combat.NightStalker.AggroRadius
    local i = 1
    while i <= #stalkers do
        local entry = stalkers[i]
        local root  = entry.root

        -- Guard: stalker might have been destroyed this frame
        if not root or not root.Parent or
           not entry.humanoid or entry.humanoid.Health <= 0 then
            table.remove(stalkers, i)
        else
            local pos    = root.Position
            local target, dist = nearestPlayer(pos)

            if target and dist <= aggroRadius then
                local char       = target.Character
                local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    stepToward(entry, targetRoot.Position, dt)

                    -- Melee damage
                    entry.damageCooldown = entry.damageCooldown - dt
                    if dist <= MeleeRange and entry.damageCooldown <= 0 then
                        entry.damageCooldown = MeleeCooldown
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            hum:TakeDamage(ctx.Config.Combat.NightStalker.Damage)
                            ctx.Remotes.Notify:FireClient(target, {
                                text  = "Night Stalker hit you! -" .. ctx.Config.Combat.NightStalker.Damage,
                                color = "red",
                            })
                        end
                    end
                end
            end
            i = i + 1
        end
    end
end

return EnemyService
