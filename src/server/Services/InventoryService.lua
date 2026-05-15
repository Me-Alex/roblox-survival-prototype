-- InventoryService.lua
-- Server-authoritative inventory management.

local InventoryService = {}
local inventories = {}
local ctx

local function emptyInventory(cfg)
    local slots = {}
    for i = 1, cfg.Inventory.MaxSlots do slots[i] = nil end
    return { slots = slots }
end

local function findStackSlot(inv, itemId, maxStack)
    for i, slot in ipairs(inv.slots) do
        if slot and slot.itemId == itemId and slot.amount < maxStack then return i end
    end
    return nil
end

local function findEmptySlot(inv, maxSlots)
    for i = 1, maxSlots do if not inv.slots[i] then return i end end
    return nil
end

local function syncInventory(player, inv)
    ctx.Remotes.UpdateInventory:FireClient(player, inv.slots)
end

function InventoryService:init(context)
    ctx = context
    ctx.Remotes.UseItem:Connect(function(player, slotIndex)  self:useItem(player, slotIndex)  end)
    ctx.Remotes.DropItem:Connect(function(player, slotIndex) self:dropItem(player, slotIndex) end)
end

function InventoryService:onPlayerAdded(player)
    inventories[player] = emptyInventory(ctx.Config)
    syncInventory(player, inventories[player])
end

function InventoryService:onPlayerRemoving(player)
    inventories[player] = nil
end

function InventoryService:addItem(player, itemId, amount)
    local inv = inventories[player]
    if not inv then return false end
    local cfg     = ctx.Config
    local itemCfg = cfg.Items[itemId]
    if not itemCfg then warn("[Inventory] Unknown item: "..tostring(itemId)) return false end
    local maxStack = itemCfg.stackSize or 1
    local maxSlots = cfg.Inventory.MaxSlots
    local remaining = amount
    while remaining > 0 do
        local stackSlot = findStackSlot(inv, itemId, maxStack)
        if stackSlot then
            local space = maxStack - inv.slots[stackSlot].amount
            local add   = math.min(space, remaining)
            inv.slots[stackSlot].amount = inv.slots[stackSlot].amount + add
            remaining = remaining - add
        else
            local emptySlot = findEmptySlot(inv, maxSlots)
            if not emptySlot then
                ctx.Remotes.Notify:FireClient(player, { text="Inventory is full!", color="red" })
                syncInventory(player, inv)
                return false
            end
            local add = math.min(maxStack, remaining)
            inv.slots[emptySlot] = { itemId = itemId, amount = add }
            remaining = remaining - add
        end
    end
    syncInventory(player, inv)
    return true
end

function InventoryService:removeItem(player, itemId, amount)
    local inv = inventories[player]
    if not inv then return false end
    local total = 0
    for _, slot in ipairs(inv.slots) do
        if slot and slot.itemId == itemId then total = total + slot.amount end
    end
    if total < amount then return false end
    local remaining = amount
    for i, slot in ipairs(inv.slots) do
        if slot and slot.itemId == itemId and remaining > 0 then
            local take = math.min(slot.amount, remaining)
            slot.amount = slot.amount - take
            remaining   = remaining - take
            if slot.amount <= 0 then inv.slots[i] = nil end
        end
    end
    syncInventory(player, inv)
    return true
end

function InventoryService:hasItem(player, itemId, amount)
    local inv = inventories[player]
    if not inv then return false end
    local total = 0
    for _, slot in ipairs(inv.slots) do
        if slot and slot.itemId == itemId then total = total + slot.amount end
    end
    return total >= (amount or 1)
end

function InventoryService:getCount(player, itemId)
    local inv = inventories[player]
    if not inv then return 0 end
    local total = 0
    for _, slot in ipairs(inv.slots) do
        if slot and slot.itemId == itemId then total = total + slot.amount end
    end
    return total
end

function InventoryService:useItem(player, slotIndex)
    local inv = inventories[player]
    if not inv then return end
    local slot = inv.slots[slotIndex]
    if not slot then return end
    local itemCfg = ctx.Config.Items[slot.itemId]
    if not itemCfg then return end
    if itemCfg.type == "food" then
        if itemCfg.hunger then ctx.VitalsService:addHunger(player, itemCfg.hunger) end
        if itemCfg.thirst then ctx.VitalsService:addThirst(player, itemCfg.thirst) end
        slot.amount = slot.amount - 1
        if slot.amount <= 0 then inv.slots[slotIndex] = nil end
        syncInventory(player, inv)
        ctx.Remotes.Notify:FireClient(player, { text="Ate "..itemCfg.displayName, color="green" })
    end
    if itemCfg.healAmount then
        ctx.VitalsService:heal(player, itemCfg.healAmount)
        slot.amount = slot.amount - 1
        if slot.amount <= 0 then inv.slots[slotIndex] = nil end
        syncInventory(player, inv)
        ctx.Remotes.Notify:FireClient(player, { text="Used "..itemCfg.displayName..(" (+"..itemCfg.healAmount.." HP)"), color="green" })
    end
end

function InventoryService:dropItem(player, slotIndex)
    local inv = inventories[player]
    if not inv then return end
    if not inv.slots[slotIndex] then return end
    inv.slots[slotIndex] = nil
    syncInventory(player, inv)
end

return InventoryService
