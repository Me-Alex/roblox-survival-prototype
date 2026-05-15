-- CraftingService.lua  (Milestone 8)
-- Changes from Milestone 3:
--   • Recipes now use a plain table with id, requires{}, gives{}, optional
--     nearFire or nearOven flag (both true means EITHER fire OR oven works).
--   • isNearFire() unchanged.
--   • isNearOven() delegates to StoneOvenService.
--   • CookedMeat now accepts nearFire OR nearOven.
--   • New oven-only recipes: MeatStew, MushroomSoup, DriedMeat.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CraftingService = {}
local ctx

-- ── Proximity checks ─────────────────────────────────────────────────────

local function isNearFire(player)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local pos = root.Position
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:FindFirstChild("IsCampfire") then
            local d = (obj.CFrame.Position - pos).Magnitude
            if d <= ctx.Config.Vitals.CampfireWarmRadius then return true end
        end
    end
    return false
end

local function isNearOven(player)
    if ctx.StoneOvenService then
        return ctx.StoneOvenService:isNearOven(player)
    end
    return false
end

-- ── Recipe lookup ─────────────────────────────────────────────────────────

local function findRecipe(recipeId)
    return ctx.Config.Recipes[recipeId]
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
        ctx.Remotes.Notify:FireClient(player, { text="Unknown recipe: "..tostring(recipeId), color="red" })
        return
    end

    -- ── Proximity gate ───────────────────────────────────────────────────
    if recipe.nearFire and recipe.nearOven then
        -- Accepts EITHER campfire OR stone oven
        if not isNearFire(player) and not isNearOven(player) then
            ctx.Remotes.Notify:FireClient(player, {
                text  = "Must be near a Campfire or Stone Oven!",
                color = "red",
            })
            return
        end
    elseif recipe.nearFire then
        if not isNearFire(player) then
            ctx.Remotes.Notify:FireClient(player, { text="Must be near a Campfire!", color="red" })
            return
        end
    elseif recipe.nearOven then
        if not isNearOven(player) then
            ctx.Remotes.Notify:FireClient(player, {
                text  = "Must be near a Stone Oven!",
                color = "red",
            })
            return
        end
    end

    -- ── Ingredient check ───────────────────────────────────────────────────
    for itemId, needed in pairs(recipe.ingredients) do
        if not ctx.InventoryService:hasItem(player, itemId, needed) then
            local iCfg = ctx.Config.Items[itemId]
            ctx.Remotes.Notify:FireClient(player, {
                text  = "Need " .. needed .. "x " .. (iCfg and iCfg.displayName or itemId),
                color = "red",
            })
            return
        end
    end

    -- ── Consume & give ───────────────────────────────────────────────────
    for itemId, needed in pairs(recipe.ingredients) do
        ctx.InventoryService:removeItem(player, itemId, needed)
    end

    ctx.InventoryService:addItem(player, recipe.result, recipe.amount)

    if ctx.ObjectiveService and ctx.ObjectiveService.recordCrafted then
        ctx.ObjectiveService:recordCrafted(player, recipe.result, recipe.amount or 1)
    end

    local iCfg = ctx.Config.Items[recipe.result]
    ctx.Remotes.Notify:FireClient(player, {
        text  = "Crafted: " .. (iCfg and iCfg.displayName or recipe.result)
                .. (recipe.amount > 1 and " x" .. recipe.amount or ""),
        color = "green",
    })

    if ctx.ProgressionService then
        if ctx.ProgressionService.addXp then
            ctx.ProgressionService:addXp(player, ctx.Config.Progression.CraftXp, "crafting")
        elseif ctx.ProgressionService.addXP then
            ctx.ProgressionService:addXP(player, ctx.Config.Progression.CraftXp, "crafting")
        end
    end
end

return CraftingService
