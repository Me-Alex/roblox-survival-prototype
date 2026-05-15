-- RespawnService.lua  (Milestone 10)
--
-- PURPOSE:
--   When a player respawns (CharacterAdded fires) this service:
--     1. Resets all vitals to full (fresh start).
--     2. Grants 4 seconds of god-mode so the player can get away from
--        whatever killed them.
--
-- GOD-MODE IMPLEMENTATION:
--   We set the Humanoid's MaxHealth to a very large number (999999) and
--   Health to 999999 for INVINCIBLE_DURATION seconds, then restore to
--   the config max. This is simpler than tracking every damage source.
--
-- NOTE:
--   This service does NOT call player:LoadCharacter(). Roblox handles
--   respawning automatically when RespawnRequest is received in Main.server.lua.
--   RespawnService only listens for CharacterAdded to apply the invincibility.

local Players = game:GetService("Players")

local RespawnService = {}
local ctx

local INVINCIBLE_DURATION = 4   -- seconds; must match DeathController

function RespawnService:init(context)
    ctx = context

    Players.PlayerAdded:Connect(function(player)
        self:_hookPlayer(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:_hookPlayer(player)
    end

    print("[RespawnService] Initialised")
end

function RespawnService:_hookPlayer(player)
    player.CharacterAdded:Connect(function(character)
        -- Wait for humanoid to exist
        local hum = character:WaitForChild("Humanoid", 10)
        if not hum then return end

        local V = ctx.Config.Vitals

        -- ── Reset vitals ──────────────────────────────────────────────────
        -- VitalsService keeps its own table; we poke it via setStatus
        -- for the booleans, then broadcast a full reset.
        if ctx.VitalsService then
            local v = ctx.VitalsService:get(player)
            if v then
                v.health   = V.MaxHealth
                v.hunger   = V.MaxHunger
                v.thirst   = V.MaxThirst
                v.temp     = V.MaxTemperature
                v.stamina  = V.MaxStamina or 100
                v.bleeding = false
                v.poisoned = false
                v.soaked   = false
            end
        end

        -- ── God-mode ───────────────────────────────────────────────────────
        hum.MaxHealth = 999999
        hum.Health    = 999999

        task.delay(INVINCIBLE_DURATION, function()
            if hum and hum.Parent then
                hum.MaxHealth = V.MaxHealth
                hum.Health    = V.MaxHealth
            end
        end)

        ctx.Remotes.Notify:FireClient(player, {
            text  = "\u26a1 Respawned — invincible for " .. INVINCIBLE_DURATION .. "s",
            color = "yellow",
        })
    end)
end

return RespawnService
