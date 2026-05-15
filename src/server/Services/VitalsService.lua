-- VitalsService.lua
-- Manages health, hunger, thirst and temperature for every player.

local VitalsService = {}
local vitals = {}
local ctx
local SYNC_INTERVAL = 0.2
local syncTimers = {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function defaultVitals(cfg)
    return {
        health      = cfg.Vitals.MaxHealth,
        hunger      = cfg.Vitals.MaxHunger,
        thirst      = cfg.Vitals.MaxThirst,
        temperature = cfg.Vitals.TemperatureNeutral,
    }
end

function VitalsService:init(context)
    ctx = context
end

function VitalsService:onPlayerAdded(player)
    vitals[player]     = defaultVitals(ctx.Config)
    syncTimers[player] = 0
    ctx.Remotes.UpdateVitals:FireClient(player, vitals[player])
end

function VitalsService:onPlayerRemoving(player)
    vitals[player]     = nil
    syncTimers[player] = nil
end

function VitalsService:getVitals(player)   return vitals[player] end

function VitalsService:heal(player, amount)
    local v = vitals[player]
    if not v then return end
    v.health = clamp(v.health + amount, 0, ctx.Config.Vitals.MaxHealth)
end

function VitalsService:addHunger(player, amount)
    local v = vitals[player]
    if not v then return end
    v.hunger = clamp(v.hunger + amount, 0, ctx.Config.Vitals.MaxHunger)
end

function VitalsService:addThirst(player, amount)
    local v = vitals[player]
    if not v then return end
    v.thirst = clamp(v.thirst + amount, 0, ctx.Config.Vitals.MaxThirst)
end

function VitalsService:adjustTemperature(player, amount)
    local v = vitals[player]
    if not v then return end
    local cfg = ctx.Config.Vitals
    v.temperature = clamp(v.temperature + amount, 0, cfg.MaxTemperature)
end

function VitalsService:tick(dt)
    local cfg = ctx.Config.Vitals
    for player, v in pairs(vitals) do
        v.hunger = clamp(v.hunger - cfg.HungerDrainRate * dt, 0, cfg.MaxHunger)
        v.thirst = clamp(v.thirst - cfg.ThirstDrainRate * dt, 0, cfg.MaxThirst)
        local tempDiff = cfg.TemperatureNeutral - v.temperature
        v.temperature = v.temperature + tempDiff * cfg.TemperatureRate * dt
        local char = player.Character
        local hum  = char and char:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 then
            if v.hunger      <= cfg.HungerDamageThreshold    then hum:TakeDamage(cfg.StarveDamagePerSec   * dt) end
            if v.thirst      <= cfg.ThirstDamageThreshold    then hum:TakeDamage(cfg.DehydrateDamagePerSec* dt) end
            if v.temperature <= cfg.TempFreezeDamageThreshold then hum:TakeDamage(cfg.FreezeDamagePerSec  * dt) end
            if v.temperature >= cfg.TempHeatDamageThreshold  then hum:TakeDamage(cfg.HeatDamagePerSec    * dt) end
            v.health = hum.Health
        end
        syncTimers[player] = (syncTimers[player] or 0) + dt
        if syncTimers[player] >= SYNC_INTERVAL then
            syncTimers[player] = 0
            ctx.Remotes.UpdateVitals:FireClient(player, { health=v.health, hunger=v.hunger, thirst=v.thirst, temperature=v.temperature })
        end
    end
end

return VitalsService
