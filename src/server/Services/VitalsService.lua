-- VitalsService.lua  (Milestone 10)
-- Changes from Milestone 9:
--   • applyDamage now accepts an optional `cause` string.
--   • When health would hit 0, fires PlayerDied remote with the cause
--     string BEFORE setting Humanoid.Health = 0, so the client can
--     display the correct cause-of-death message.
--   • tick() passes a cause string to applyDamage per damage type.

local Players = game:GetService("Players")

local VitalsService = {}
local ctx

local vitals    = {}
local tickTimer = 0
local TICK_RATE = 1

-- ── Defaults ──────────────────────────────────────────────────────────────

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

-- ── Status flags ──────────────────────────────────────────────────────────

local function computeStatuses(v, isNight, isRaining)
    local T = ctx.Config.StatusThresholds
    return {
        bleeding   = v.bleeding == true,
        poisoned   = v.poisoned == true,
        soaked     = v.soaked   == true or (isRaining == true),
        freezing   = v.temp     <  T.FreezingTemp,
        exhausted  = v.stamina  <  T.ExhaustedStamina,
        rested     = v.stamina  >= T.RestedStamina and not isNight,
        starving   = v.hunger   <  T.StarvingHunger,
        dehydrated = v.thirst   <  T.DehydratedThirst,
    }
end

-- ── Broadcast ─────────────────────────────────────────────────────────────

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

-- ── Init ─────────────────────────────────────────────────────────────────

function VitalsService:init(context)
    ctx = context

    Players.PlayerAdded:Connect(function(player)
        vitals[player] = defaultVitals()
        broadcast(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        vitals[player] = nil
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        if not vitals[player] then
            vitals[player] = defaultVitals()
        end
    end

    -- UseItem
    ctx.Remotes.UseItem.OnServerEvent:Connect(function(player, slot)
        local v = vitals[player]
        if not v then return end
        local inv  = ctx.InventoryService
        local item = inv and inv:getSlot(player, slot)
        if not item then return end
        local cfg = ctx.Config.Items[item.id]
        if not cfg then return end

        if cfg.food then
            local f = cfg.food
            v.hunger = math.min(v.hunger + (f.hungerRestore or 0), ctx.Config.Vitals.MaxHunger)
            v.thirst = math.min(v.thirst + (f.thirstRestore or 0), ctx.Config.Vitals.MaxThirst)

            if f.poisonOnDrink then
                v.poisoned = true
                ctx.Remotes.Notify:FireClient(player, {
                    text  = "☠ The dirty water makes you sick! Boil water next time.",
                    color = "red",
                })
            else
                ctx.Remotes.Notify:FireClient(player, {
                    text  = "Ate " .. (cfg.displayName or item.id),
                    color = "green",
                })
            end

            if f.curesPoison   then v.poisoned = false end
            if f.curesBleeding then v.bleeding = false end
            inv:removeFromSlot(player, slot, 1)
            broadcast(player)
            return
        end

        if cfg.onUse == "curesBleeding" then
            if v.bleeding then
                v.bleeding = false
                inv:removeFromSlot(player, slot, 1)
                broadcast(player)
                ctx.Remotes.Notify:FireClient(player, { text="Bleeding stopped.", color="green" })
            else
                ctx.Remotes.Notify:FireClient(player, { text="You are not bleeding.", color="yellow" })
            end
            return
        end
    end)

    print("[VitalsService] Initialised")
end

-- ── Public API ────────────────────────────────────────────────────────────

function VitalsService:get(player)
    return vitals[player]
end

-- cause (optional string): "Starvation", "Dehydration", "Freezing",
--                          "Bleeding", "Poison", "Night Stalker", etc.
function VitalsService:applyDamage(player, amount, cause)
    local v = vitals[player]
    if not v then return end
    local willDie = (v.health - amount) <= 0

    -- Fire PlayerDied BEFORE zeroing health so client receives cause first
    if willDie then
        ctx.Remotes.PlayerDied:FireClient(player, cause or "The island claimed you.")
    end

    v.health = math.max(0, v.health - amount)
    broadcast(player)

    if willDie then
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then hum.Health = 0 end
    end
end

function VitalsService:setStatus(player, statusName, value)
    local v = vitals[player]
    if not v then return end
    v[statusName] = value
    broadcast(player)
end

function VitalsService:adjustTemperature(player, delta)
    local v = vitals[player]
    if not v then
        return
    end

    local maxTemp = (ctx and ctx.Config and ctx.Config.Vitals and ctx.Config.Vitals.MaxTemperature) or 100
    v.temp = math.clamp(v.temp + delta, 0, maxTemp)
    broadcast(player)
end

-- ── Tick ─────────────────────────────────────────────────────────────────

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
            v.hunger = math.max(0, v.hunger - V.HungerDecayRate)
            v.thirst = math.max(0, v.thirst - V.ThirstDecayRate)

            local tempDrain = 0
            if isNight   then tempDrain = tempDrain + (V.NightTempDrain or 1) end
            if isRaining then tempDrain = tempDrain + (V.RainTempDrain  or 2) end
            v.temp = math.max(0, v.temp - tempDrain)

            -- Accumulate damage with per-source causes
            local dmg   = 0
            local cause = nil

            if v.hunger   < T.StarvingHunger   then dmg = dmg + (V.StarveDamage    or 2); cause = "Starvation"  end
            if v.thirst   < T.DehydratedThirst then dmg = dmg + (V.DehydrateDamage or 3); cause = "Dehydration" end
            if v.temp     < T.FreezingTemp      then dmg = dmg + (V.FreezeDamage    or 2); cause = "Freezing"    end
            if v.bleeding                       then dmg = dmg + (V.BleedDamage     or 4); cause = "Bleeding"    end
            if v.poisoned                       then dmg = dmg + (V.PoisonDamage    or 3); cause = "Poison"      end

            -- If multiple sources are active, pick the most lethal label
            -- (simple priority: the last assignment wins, which is Poison)

            if dmg > 0 then
                self:applyDamage(player, dmg, cause)
            else
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
