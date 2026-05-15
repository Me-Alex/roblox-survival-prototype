-- RespawnService.lua (Milestone 10)
-- Resets vitals on respawn and applies short invincibility.

local Players = game:GetService("Players")

local RespawnService = {}
local ctx

local INVINCIBLE_DURATION = 4

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
        local hum = character:WaitForChild("Humanoid", 10)
        if not hum then
            return
        end

        local V = ctx.Config.Vitals

        if ctx.VitalsService then
            local v = ctx.VitalsService:get(player)
            if v then
                v.health = V.MaxHealth
                v.hunger = V.MaxHunger
                v.thirst = V.MaxThirst
                v.temp = V.MaxTemperature
                v.stamina = V.MaxStamina or 100
                v.bleeding = false
                v.poisoned = false
                v.soaked = false
            end
        end

        hum.MaxHealth = 999999
        hum.Health = 999999

        task.delay(INVINCIBLE_DURATION, function()
            if hum and hum.Parent then
                hum.MaxHealth = V.MaxHealth
                hum.Health = V.MaxHealth
            end
        end)

        ctx.Remotes.Notify:FireClient(player, {
            text = "Respawned - invincible for " .. INVINCIBLE_DURATION .. "s",
            color = "yellow",
        })
    end)
end

return RespawnService
