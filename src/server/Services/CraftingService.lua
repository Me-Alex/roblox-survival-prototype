-- CraftingService.lua
-- Handles crafting on the server.

local CraftingService = {}
local ctx

function CraftingService:init(context)
    ctx = context
    ctx.Remotes.CraftItem:Connect(function(player, recipeId)
        self:tryCraft(player, recipeId)
    end)
end

function CraftingService:tryCraft(player, recipeId)
    local recipe = nil
    for _, r in ipairs(ctx.Config.Recipes) do
        if r.id == recipeId then recipe = r break end
    end
    if not recipe then
        ctx.Remotes.CraftResult:FireClient(player, { success=false, reason="Unknown recipe: "..tostring(recipeId) })
        return
    end
    local inv = ctx.InventoryService
    for itemId, amount in pairs(recipe.cost) do
        if not inv:hasItem(player, itemId, amount) then
            local itemName = (ctx.Config.Items[itemId] and ctx.Config.Items[itemId].displayName) or itemId
            ctx.Remotes.CraftResult:FireClient(player, { success=false, reason="Need "..amount.."x "..itemName })
            return
        end
    end
    for itemId, amount in pairs(recipe.cost) do
        inv:removeItem(player, itemId, amount)
    end
    local amount = recipe.resultAmount or 1
    inv:addItem(player, recipe.result, amount)
    local resultName = (ctx.Config.Items[recipe.result] and ctx.Config.Items[recipe.result].displayName) or recipe.result
    ctx.Remotes.CraftResult:FireClient(player, { success=true, message="Crafted "..amount.."x "..resultName })
    ctx.Remotes.Notify:FireClient(player, { text="Crafted: "..resultName, color="green" })
end

return CraftingService
