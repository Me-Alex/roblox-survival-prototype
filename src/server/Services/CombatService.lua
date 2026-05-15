-- CombatService.lua  (Milestone 7)
-- Changes from Milestone 4:
--   • AttackRequest now also checks if the target Part belongs to a
--     wildlife model (Rabbit / Deer) and routes damage to WildlifeService.
--   • Target priority: NightStalker first, then Wildlife, then nothing.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CombatService = {}
local ctx

local attackCooldowns = {}  -- attackCooldowns[player] = time remaining

-- Damage by equipped weapon
local function damageForPlayer(player)
    local inv     = ctx.InventoryService:getAll(player)
    local cfg     = ctx.Config.Combat
    -- Check action bar slots 1-5 for a weapon
    for i = 1, 5 do
        local slot = inv[i]
        if slot then
            if slot.id == "StoneSpear" then return cfg.SpearDamage end
            if slot.id == "StoneAxe"   then return cfg.AxeDamage   end
        end
    end
    return cfg.FistDamage
end

function CombatService:init(context)
    ctx = context
    attackCooldowns = {}

    ctx.Remotes.AttackRequest.OnServerEvent:Connect(function(player, targetPartName)
        -- Cooldown check
        if attackCooldowns[player] and attackCooldowns[player] > 0 then return end
        attackCooldowns[player] = ctx.Config.Combat.AttackCooldown

        local damage = damageForPlayer(player)
        local char   = player.Character
        local root   = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        -- Find the target Part in Workspace by name
        local targetPart = nil
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == targetPartName then
                targetPart = obj
                break
            end
        end
        if not targetPart then return end

        -- Distance check (10 studs)
        local dist = (root.Position - targetPart.Position).Magnitude
        if dist > 10 then return end

        -- ── Route: NightStalker ───────────────────────────────────────────────
        local stalkerModel = targetPart:FindFirstAncestorOfClass("Model")
        if stalkerModel and stalkerModel.Name == "NightStalker" then
            ctx.EnemyService:registerHit(stalkerModel, player, damage)
            return
        end

        -- ── Route: Wildlife ──────────────────────────────────────────────────
        if ctx.WildlifeService then
            -- Wildlife root parts are named "Root"
            local wildlifeRoot = targetPart
            if wildlifeRoot.Name ~= "Root" then
                -- If player clicked a non-root part (leg, head etc.) find the root
                local parentModel = targetPart:FindFirstAncestorOfClass("Model")
                if parentModel then
                    wildlifeRoot = parentModel:FindFirstChild("Root")
                end
            end
            if wildlifeRoot then
                local hit = ctx.WildlifeService:registerHit(wildlifeRoot, player, damage)
                if hit then return end
            end
        end
    end)

    print("[CombatService] Initialised")
end

function CombatService:tick(dt)
    for player, cd in pairs(attackCooldowns) do
        if player.Parent then
            attackCooldowns[player] = math.max(0, cd - dt)
        else
            attackCooldowns[player] = nil
        end
    end
end

return CombatService
