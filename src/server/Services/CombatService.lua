-- CombatService.lua  (Milestone 4)
-- Handles player attack requests.
-- Client fires AttackRequest { targetId } when the player clicks/swings.
-- Server validates distance, cooldown, equipped weapon, then applies damage
-- to the target (NightStalker model or another player).

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CombatService = {}
local ctx

-- Per-player attack cooldown tracker
local cooldowns = {}   -- cooldowns[player] = time remaining

-- ── Helpers ───────────────────────────────────────────────────────────────

local function getEquippedWeapon(player)
    -- Check if player has a weapon tool in their character
    local char = player.Character
    if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            -- Check if it's one of our weapon/tool items
            local itemId = tool:GetAttribute("ItemId")
            if itemId then
                local cfg = ctx.Config.Items[itemId]
                if cfg then return itemId, cfg end
            end
        end
    end
    return nil
end

local function getWeaponDamage(itemId)
    local cfg = ctx.Config.Combat
    if itemId == "StoneAxe"   then return cfg.AxeDamage   end
    if itemId == "StoneSpear" then return cfg.SpearDamage end
    return cfg.FistDamage
end

-- Find which stalker model a given Part belongs to
local function findStalkerModel(part)
    local obj = part
    while obj and obj.Parent do
        if obj:IsA("Model") and obj.Name == "NightStalker" then
            return obj
        end
        obj = obj.Parent
    end
    return nil
end

-- ── Init ──────────────────────────────────────────────────────────────────

function CombatService:init(context)
    ctx = context

    ctx.Remotes.AttackRequest.OnServerEvent:Connect(function(player, targetId)
        self:handleAttack(player, targetId)
    end)

    -- Tick cooldowns down
    -- (done inside CombatService:tick, called from Main.server)

    -- Player touching a NightStalker is handled in EnemyService tick (melee range check)
    -- This service handles PLAYER-INITIATED attacks (swing with tool)

    print("[CombatService] Initialised")
end

function CombatService:handleAttack(player, targetId)
    -- Cooldown check
    local cd = cooldowns[player] or 0
    if cd > 0 then return end
    cooldowns[player] = ctx.Config.Combat.AttackCooldown

    -- Find target part in workspace
    local targetPart = Workspace:FindFirstChild(targetId, true)
    if not targetPart then return end

    -- Distance check (must be within 10 studs)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if (targetPart.Position - root.Position).Magnitude > 10 then return end

    -- Determine damage
    local itemId   = getEquippedWeapon(player)
    local damage   = getWeaponDamage(itemId)

    -- Is it a NightStalker?
    local stalkerModel = findStalkerModel(targetPart)
    if stalkerModel then
        ctx.EnemyService:registerHit(stalkerModel, player, damage)
        ctx.Remotes.Notify:FireClient(player, {
            text  = "Hit! -" .. damage,
            color = "yellow",
        })
        return
    end

    -- Could be another player (PvP) — skip for now (PvP not in scope yet)
end

function CombatService:tick(dt)
    for player, cd in pairs(cooldowns) do
        if cd > 0 then
            cooldowns[player] = cd - dt
        end
    end
    -- Clean up disconnected players
    for player in pairs(cooldowns) do
        if not player.Parent then
            cooldowns[player] = nil
        end
    end
end

return CombatService
