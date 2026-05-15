-- CraftingService.lua  (Milestone 3)
-- Listens for CraftRequest from clients.
-- Validates:
--   1. Recipe exists
--   2. Player has all required ingredients
--   3. If nearFire = true, player must be within CampfireWarmRadius of a campfire
-- On success: removes ingredients, adds result, awards XP, notifies player.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CraftingService = {}
local ctx

-- ── Helpers ───────────────────────────────────────────────────────────────

local function findRecipe(recipeId)
    for _, r in ipairs(ctx.Config.Recipes) do
        if r.id == recipeId then return r end
    end
    return nil
end

local function isNearFire(player)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local pos = root.Position
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:FindFirstChild("IsCampfire") then
            local dist = (obj.CFrame.Position - pos).Magnitude
            if dist <= ctx.Config.Vitals.CampfireWarmRadius then
                return true
            end
        end
    end
    return false
end

-- ── Init ──────────────────────────────────────────────────────────────────

function CraftingService:init(context)
    ctx = context

    ctx.Remotes.CraftRequest.OnServerEvent:Connect(function(player, recipeId)
        self:tryCraft(player, recipeId)
    end)

    print("[CraftingService] Initialised")
end

function CraftingService:tryCraft(player, recipeId)
    local recipe = findRecipe(recipeId)
    if not recipe then
        ctx.Remotes.Notify:FireClient(player, { text="Unknown recipe.", color="red" })
        return
    end

    -- Near-fire check
    if recipe.nearFire and not isNearFire(player) then
        ctx.Remotes.Notify:FireClient(player, { text="Must be near a campfire!", color="red" })
        return
    end

    -- Ingredient check
    for itemId, needed in pairs(recipe.requires) do
        if not ctx.InventoryService:hasItem(player, itemId, needed) then
            local itemCfg = ctx.Config.Items[itemId]
            local name = itemCfg and itemCfg.displayName or itemId
            ctx.Remotes.Notify:FireClient(player, {
                text  = "Need " .. needed .. "x " .. name,
                color = "red",
            })
            return
        end
    end

    -- Consume ingredients
    for itemId, needed in pairs(recipe.requires) do
        ctx.InventoryService:removeItem(player, itemId, needed)
    end

    -- Give result
    local gives = recipe.gives
    ctx.InventoryService:addItem(player, gives.item, gives.amount)

    -- Notify
    local itemCfg = ctx.Config.Items[gives.item]
    local name = itemCfg and itemCfg.displayName or gives.item
    ctx.Remotes.Notify:FireClient(player, {
        text  = "Crafted: " .. name .. (gives.amount > 1 and " x" .. gives.amount or ""),
        color = "green",
    })

    -- Award XP
    if ctx.ProgressionService and ctx.ProgressionService.addXp then
        ctx.ProgressionService:addXp(player, ctx.Config.Progression.CraftXp)
    end
end

return CraftingService
