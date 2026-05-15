-- VitalsService.lua  (Milestone 5)
-- What changed from Milestone 2:
--   • computeStatuses() calculates boolean flags from current vitals.
--   • VitalsUpdate now includes `statuses` table.
--   • Thresholds come from Config.StatusThresholds.

local Players = game:GetService("Players")

local VitalsService = {}
local ctx

local vitals     = {}   -- vitals[player] = { health, hunger, thirst, temp, stamina, bleeding, poisoned, soaked }
local tickTimer  = 0
local TICK_RATE  = 1    -- send update every 1 second

-- ── Defaults ───────────────────────────────────────────────────────────────

local function defaultVitals()
    local V = ctx.Config.Vitals
    return {
        health   = V.MaxHealth,
        hunger   = V.MaxHunger,
        thirst   = V.MaxThirst,
        temp     = V.MaxTemperature,
        stamina  = V.MaxStamina or 100,
        bleeding = false,
        poisoned = false,
        soaked   = false,
    }
end

-- ── Status flag computation ─────────────────────────────────────────────────
-- Returns a flat table of boolean flags for the HUD.

local function computeStatuses(v, isNight, isRaining)
    local T = ctx.Config.StatusThresholds
    return {
        bleeding   = v.bleeding  == true,
        poisoned   = v.poisoned  == true,
        soaked     = v.soaked    == true or (isRaining == true),
        freezing   = v.temp      <  T.FreezingTemp,
        exhausted  = v.stamina   <  T.ExhaustedStamina,
        rested     = v.stamina   >= T.RestedStamina and not isNight,
        starving   = v.hunger    <  T.StarvingHunger,
        dehydrated = v.thirst    <  T.DehydratedThirst,
    }
end

-- ── Broadcast to one player ─────────────────────────────────────────────────

local function broadcast(player)
    local v = vitals[player]
    if not v then return end
    local isNight   = ctx.WorldService and ctx.WorldService:isNight()   or false
    local isRaining = ctx.WorldService and ctx.WorldService:isRaining() or false
    ctx.Remotes.VitalsUpdate:FireClient(player, {
        health   = v.health,
        hunger   = v.hunger,
        thirst   = v.thirst,
        temp     = v.temp,
        stamina  = v.stamina,
        statuses = computeStatuses(v, isNight, isRaining),
    })
end

-- ── Init ───────────────────────────────────────────────────────────────────

function VitalsService:init(context)
    ctx = context

    Players.PlayerAdded:Connect(function(player)
        vitals[player] = defaultVitals()
        broadcast(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        vitals[player] = nil
    end)

    -- Populate any players already in server (Studio play-solo)
    for _, player in ipairs(Players:GetPlayers()) do
        if not vitals[player] then
            vitals[player] = defaultVitals()
        end
    end

    -- UseItem: eating food
    ctx.Remotes.UseItem.OnServerEvent:Connect(function(player, slot)
        local v = vitals[player]
        if not v then return end
        local inv  = ctx.InventoryService
        local item = inv and inv:getSlot(player, slot)
        if not item then return end
        local cfg = ctx.Config.Items[item.id]
        if not cfg or not cfg.food then return end

        v.hunger = math.min(v.hunger + (cfg.food.hungerRestore or 0), ctx.Config.Vitals.MaxHunger)
        v.thirst = math.min(v.thirst + (cfg.food.thirstRestore or 0), ctx.Config.Vitals.MaxThirst)
        if cfg.food.curesPoison then v.poisoned = false end
        if cfg.food.curesBleeding then v.bleeding = false end

        inv:removeFromSlot(player, slot, 1)
        broadcast(player)
        ctx.Remotes.Notify:FireClient(player, {
            text  = "Ate " .. (cfg.displayName or item.id),
            color = "green",
        })
    end)

    print("[VitalsService] Initialised")
end

-- ── Public API (used by other services) ────────────────────────────────────

function VitalsService:get(player)
    return vitals[player]
end

function VitalsService:applyDamage(player, amount)
    local v = vitals[player]
    if not v then return end
    v.health = math.max(0, v.health - amount)
    broadcast(player)
    -- If health hits 0, damage the Humanoid (triggers death + DeathController)
    if v.health <= 0 then
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            hum.Health = 0
        end
    end
end

function VitalsService:setStatus(player, statusName, value)
    local v = vitals[player]
    if not v then return end
    v[statusName] = value
    broadcast(player)
end

-- ── Tick ───────────────────────────────────────────────────────────────────

function VitalsService:tick(dt)
    tickTimer = tickTimer + dt
    if tickTimer < TICK_RATE then return end
    tickTimer = 0

    local V = ctx.Config.Vitals
    local T = ctx.Config.StatusThresholds
    local isNight   = ctx.WorldService and ctx.WorldService:isNight()   or false
    local isRaining = ctx.WorldService and ctx.WorldService:isRaining() or false

    for player, v in pairs(vitals) do
        if player.Parent then
            -- Drain hunger & thirst over time
            v.hunger = math.max(0, v.hunger - V.HungerDecayRate)
            v.thirst = math.max(0, v.thirst - V.ThirstDecayRate)

            -- Temperature: cold at night or in rain
            local tempDrain = 0
            if isNight   then tempDrain = tempDrain + (V.NightTempDrain   or 1) end
            if isRaining then tempDrain = tempDrain + (V.RainTempDrain    or 2) end
            v.temp = math.max(0, v.temp - tempDrain)

            -- Passive damage from critical states
            local dmg = 0
            if v.hunger    < T.StarvingHunger    then dmg = dmg + (V.StarveDamage   or 2) end
            if v.thirst    < T.DehydratedThirst  then dmg = dmg + (V.DehydrateDamage or 3) end
            if v.temp      < T.FreezingTemp       then dmg = dmg + (V.FreezeDamage   or 2) end
            if v.bleeding                         then dmg = dmg + (V.BleedDamage    or 4) end
            if v.poisoned                         then dmg = dmg + (V.PoisonDamage   or 3) end

            if dmg > 0 then
                self:applyDamage(player, dmg)
            else
                -- Natural health regen when well-fed and warm
                if v.hunger > T.RestedStamina and v.thirst > T.RestedStamina
                   and v.temp > T.FreezingTemp * 3 then
                    v.health = math.min(V.MaxHealth, v.health + (V.HealthRegen or 0.5))
                end
                broadcast(player)
            end
        end
    end
end

return VitalsService
