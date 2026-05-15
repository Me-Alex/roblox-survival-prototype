-- VitalsService.lua  (Milestone 3)
-- Manages health, hunger, thirst, temperature per player.
-- Tick decays vitals over time, applies damage when they hit zero.
-- UseItem remote handler: eating food restores hunger/thirst.

local Players = game:GetService("Players")

local VitalsService = {}
local ctx

-- Per-player vitals table
-- vitals[player] = { health, hunger, thirst, temp }
local vitals = {}

local SEND_INTERVAL = 0.5   -- seconds between sending vitals to client
local timers = {}           -- timers[player] = seconds since last send

-- ── Helpers ───────────────────────────────────────────────────────────────

local function getVitals(player)
    if not vitals[player] then
        vitals[player] = {
            health = ctx.Config.Vitals.MaxHealth,
            hunger = ctx.Config.Vitals.MaxHunger,
            thirst = ctx.Config.Vitals.MaxThirst,
            temp   = ctx.Config.Vitals.MaxTemperature,
        }
        timers[player] = 0
    end
    return vitals[player]
end

local function clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

local function sendVitals(player)
    local v = vitals[player]
    if not v then return end
    ctx.Remotes.VitalsUpdate:FireClient(player, {
        health = v.health,
        hunger = v.hunger,
        thirst = v.thirst,
        temp   = v.temp,
    })
end

local function applyHumanoidDamage(player, amount)
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = math.max(0, hum.Health - amount)
    end
end

-- ── Food use ──────────────────────────────────────────────────────────────

local function useFood(player, itemId)
    local restore = ctx.Config.Vitals.FoodRestore[itemId]
    if not restore then return false end
    local v   = getVitals(player)
    local V   = ctx.Config.Vitals
    v.hunger  = clamp(v.hunger + (restore.hunger or 0), 0, V.MaxHunger)
    v.thirst  = clamp(v.thirst + (restore.thirst or 0), 0, V.MaxThirst)
    sendVitals(player)
    local itemCfg = ctx.Config.Items[itemId]
    local name = itemCfg and itemCfg.displayName or itemId
    ctx.Remotes.Notify:FireClient(player, {
        text  = "Ate " .. name,
        color = "green",
    })
    return true
end

-- ── Init ──────────────────────────────────────────────────────────────────

function VitalsService:init(context)
    ctx = context

    -- Initialise vitals when player joins
    Players.PlayerAdded:Connect(function(player)
        getVitals(player)
        -- Send initial values shortly after (character needs to load)
        task.delay(2, function()
            sendVitals(player)
        end)
    end)

    -- Clean up when player leaves
    Players.PlayerRemoving:Connect(function(player)
        vitals[player] = nil
        timers[player] = nil
    end)

    -- UseItem remote: eat food or use tool
    ctx.Remotes.UseItem.OnServerEvent:Connect(function(player, slotIndex)
        local slot = ctx.InventoryService:getSlot(player, slotIndex)
        if not slot or not slot.itemId then return end

        local itemCfg = ctx.Config.Items[slot.itemId]
        if not itemCfg then return end

        if itemCfg.category == "food" then
            local ate = useFood(player, slot.itemId)
            if ate then
                ctx.InventoryService:removeItem(player, slot.itemId, 1)
            end
        elseif itemCfg.category == "tool" or itemCfg.category == "weapon" then
            -- Equipping is handled by ItemToolService; just notify for now
            ctx.Remotes.Notify:FireClient(player, {
                text  = "Equipped " .. (itemCfg.displayName or slot.itemId),
                color = "yellow",
            })
        end
    end)

    print("[VitalsService] Initialised")
end

-- ── Public API ────────────────────────────────────────────────────────────

function VitalsService:adjustTemperature(player, delta)
    local v = getVitals(player)
    if not v then return end
    v.temp = clamp(v.temp + delta, 0, ctx.Config.Vitals.MaxTemperature)
end

function VitalsService:damage(player, amount)
    local v = getVitals(player)
    if not v then return end
    v.health = clamp(v.health - amount, 0, ctx.Config.Vitals.MaxHealth)
    applyHumanoidDamage(player, amount)
    sendVitals(player)
end

-- ── Tick ──────────────────────────────────────────────────────────────────

function VitalsService:tick(dt)
    local V       = ctx.Config.Vitals
    local isNight = ctx.WorldService and ctx.WorldService:isNight() or false
    local decayT  = isNight and V.TempDecayRateNight or V.TempDecayRateDay
    -- Convert per-minute rates to per-second
    local dHunger = (V.HungerDecayRate / 60) * dt
    local dThirst = (V.ThirstDecayRate / 60) * dt
    local dTemp   = (decayT / 60) * dt

    for player, v in pairs(vitals) do
        v.hunger = clamp(v.hunger - dHunger, 0, V.MaxHunger)
        v.thirst = clamp(v.thirst - dThirst, 0, V.MaxThirst)
        v.temp   = clamp(v.temp   - dTemp,   0, V.MaxTemperature)

        -- Damage from zero vitals
        if v.hunger == 0 then
            applyHumanoidDamage(player, (V.StarveDamage / 60) * dt)
        end
        if v.thirst == 0 then
            applyHumanoidDamage(player, (V.DehydrateDamage / 60) * dt)
        end
        if v.temp == 0 then
            applyHumanoidDamage(player, (V.HypothermiaDamage / 60) * dt)
        end

        -- Throttled network send
        timers[player] = (timers[player] or 0) + dt
        if timers[player] >= SEND_INTERVAL then
            timers[player] = 0
            sendVitals(player)
        end
    end
end

return VitalsService
