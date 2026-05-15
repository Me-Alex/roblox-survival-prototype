local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = {}
local ctx

local SLOT_COUNT = 20

local inventories = {}
local equipped = {}
local fallbackConfig

local function emptyInv()
    local inv = {}
    for i = 1, SLOT_COUNT do
        inv[i] = nil
    end
    return inv
end

local function cloneSlots(inv)
    local copy = {}
    for i = 1, SLOT_COUNT do
        local slot = inv[i]
        if slot then
            copy[i] = { id = slot.id, qty = slot.qty }
        else
            copy[i] = nil
        end
    end
    return copy
end

local function asItemCounts(inv)
    local items = {}
    for i = 1, SLOT_COUNT do
        local slot = inv[i]
        if slot and slot.id and slot.qty and slot.qty > 0 then
            items[slot.id] = (items[slot.id] or 0) + slot.qty
        end
    end
    return items
end

local function getItemConfig(itemId)
    if ctx and ctx.Config and ctx.Config.Items and ctx.Config.Items[itemId] then
        return ctx.Config.Items[itemId]
    end
    if fallbackConfig and fallbackConfig.Items and fallbackConfig.Items[itemId] then
        return fallbackConfig.Items[itemId]
    end
    return nil
end

local function isStackable(itemId)
    local itemCfg = getItemConfig(itemId)
    if itemCfg == nil then
        return true
    end
    if itemCfg.stackable ~= nil then
        return itemCfg.stackable == true
    end
    if itemCfg.Stackable ~= nil then
        return itemCfg.Stackable == true
    end
    return true
end

local function isPlaceable(itemId)
    local itemCfg = getItemConfig(itemId)
    if itemCfg == nil then
        return false
    end
    if itemCfg.placeable ~= nil then
        return itemCfg.placeable == true
    end
    if itemCfg.Placeable ~= nil then
        return itemCfg.Placeable == true
    end
    return false
end

local function normalizeQty(qty)
    local n = math.floor(tonumber(qty) or 0)
    if n < 0 then
        n = 0
    end
    return n
end

local function ensurePlayer(player)
    if not inventories[player] then
        inventories[player] = emptyInv()
    end
    if not equipped[player] then
        equipped[player] = {}
    end
    return inventories[player]
end

local function broadcast(player)
    if not (ctx and ctx.Remotes and ctx.Remotes.InventoryUpdate) then
        return
    end
    local inv = inventories[player]
    if not inv then
        return
    end
    ctx.Remotes.InventoryUpdate:FireClient(player, cloneSlots(inv))
end

local function markDirty(player)
    if ctx and ctx.PersistenceService and ctx.PersistenceService.markPlayerDirty then
        ctx.PersistenceService.markPlayerDirty(player)
    end
end

function InventoryService:init(context)
    ctx = context

    if not fallbackConfig then
        local ok, configOrErr = pcall(function()
            return require(ReplicatedStorage.Shared.SurvivalConfig)
        end)
        if ok then
            fallbackConfig = configOrErr
        end
    end

    Players.PlayerAdded:Connect(function(player)
        ensurePlayer(player)
        broadcast(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        inventories[player] = nil
        equipped[player] = nil
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        ensurePlayer(player)
    end

    ctx.Remotes.UseItem.OnServerEvent:Connect(function(player, slotIndex)
        local inv = ensurePlayer(player)
        local slot = inv[tonumber(slotIndex)]
        if not slot then
            return
        end

        if not isPlaceable(slot.id) then
            return
        end

        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end

        local pos = root.Position + root.CFrame.LookVector * 4

        if slot.id == "Bedroll" and ctx.WorldService and ctx.WorldService.spawnBedroll then
            ctx.WorldService:spawnBedroll(pos, player.UserId)
            self:removeFromSlot(player, slotIndex, 1)
            if ctx.Remotes.Notify then
                ctx.Remotes.Notify:FireClient(player, { text = "Bedroll placed", color = "green" })
            end
        elseif slot.id == "Campfire" and ctx.WorldService and ctx.WorldService.spawnCampfire then
            ctx.WorldService:spawnCampfire(pos)
            self:removeFromSlot(player, slotIndex, 1)
            if ctx.Remotes.Notify then
                ctx.Remotes.Notify:FireClient(player, { text = "Campfire placed", color = "yellow" })
            end
        end
    end)

    ctx.Remotes.DropItem.OnServerEvent:Connect(function(player, slotIndex)
        local slot = self:getSlot(player, slotIndex)
        if not slot then
            return
        end
        self:removeFromSlot(player, slotIndex, 1)
        if ctx.Remotes.Notify then
            ctx.Remotes.Notify:FireClient(player, { text = "Dropped " .. tostring(slot.id), color = "yellow" })
        end
    end)

    print("[InventoryService] Initialised")
end

function InventoryService:addItem(player, itemId, qty)
    local inv = ensurePlayer(player)
    local amount = normalizeQty(qty == nil and 1 or qty)
    if amount <= 0 then
        return false
    end
    if type(itemId) ~= "string" or itemId == "" then
        return false
    end

    if isStackable(itemId) then
        for i = 1, SLOT_COUNT do
            if inv[i] and inv[i].id == itemId then
                inv[i].qty = inv[i].qty + amount
                markDirty(player)
                broadcast(player)
                return true
            end
        end
    end

    for i = 1, SLOT_COUNT do
        if not inv[i] then
            inv[i] = { id = itemId, qty = amount }
            markDirty(player)
            broadcast(player)
            return true
        end
    end

    if ctx and ctx.Remotes and ctx.Remotes.Notify then
        ctx.Remotes.Notify:FireClient(player, { text = "Inventory full!", color = "red" })
    end
    return false
end

function InventoryService:hasItem(player, itemId, qty)
    local needed = normalizeQty(qty == nil and 1 or qty)
    if needed <= 0 then
        return true
    end
    local inv = ensurePlayer(player)
    local total = 0
    for i = 1, SLOT_COUNT do
        local slot = inv[i]
        if slot and slot.id == itemId then
            total = total + slot.qty
            if total >= needed then
                return true
            end
        end
    end
    return false
end

function InventoryService:removeFromSlot(player, slotIndex, qty)
    local inv = ensurePlayer(player)
    local index = tonumber(slotIndex)
    if not index then
        return false
    end
    local slot = inv[index]
    if not slot then
        return false
    end

    local amount = normalizeQty(qty == nil and 1 or qty)
    if amount <= 0 then
        return false
    end

    slot.qty = slot.qty - amount
    if slot.qty <= 0 then
        inv[index] = nil
    end

    markDirty(player)
    broadcast(player)
    return true
end

function InventoryService:removeItem(player, itemId, qty)
    local needed = normalizeQty(qty == nil and 1 or qty)
    if needed <= 0 then
        return true
    end
    if not self:hasItem(player, itemId, needed) then
        return false
    end

    local inv = ensurePlayer(player)
    for i = 1, SLOT_COUNT do
        local slot = inv[i]
        if slot and slot.id == itemId then
            local take = math.min(needed, slot.qty)
            slot.qty = slot.qty - take
            needed = needed - take
            if slot.qty <= 0 then
                inv[i] = nil
            end
            if needed <= 0 then
                break
            end
        end
    end

    markDirty(player)
    broadcast(player)
    return true
end

function InventoryService:hasItems(player, costMap)
    if type(costMap) ~= "table" then
        return true
    end
    for itemId, amount in pairs(costMap) do
        if not self:hasItem(player, itemId, amount) then
            return false, itemId
        end
    end
    return true
end

function InventoryService:removeItems(player, costMap)
    if type(costMap) ~= "table" then
        return true
    end
    local ok, missing = self:hasItems(player, costMap)
    if not ok then
        return false, missing
    end
    for itemId, amount in pairs(costMap) do
        self:removeItem(player, itemId, amount)
    end
    return true
end

function InventoryService:getSlot(player, slotIndex)
    local inv = ensurePlayer(player)
    local slot = inv[tonumber(slotIndex)]
    if not slot then
        return nil
    end
    return { id = slot.id, qty = slot.qty, itemId = slot.id, amount = slot.qty }
end

function InventoryService:getAll(player)
    return ensurePlayer(player)
end

function InventoryService:getInventory(player)
    local inv = ensurePlayer(player)
    return {
        Slots = cloneSlots(inv),
        Items = asItemCounts(inv),
        Equipped = equipped[player] or {},
    }
end

function InventoryService:getSnapshot(player)
    return self:getInventory(player)
end

function InventoryService:applySnapshot(player, snapshot)
    local inv = emptyInv()
    local slotCount = SLOT_COUNT
    local source = (type(snapshot) == "table" and snapshot.Slots) or snapshot

    if type(source) == "table" then
        for i = 1, slotCount do
            local slot = source[i]
            if type(slot) == "table" then
                local id = slot.id or slot.itemId
                local qty = normalizeQty(slot.qty or slot.amount or 0)
                if type(id) == "string" and id ~= "" and qty > 0 then
                    inv[i] = { id = id, qty = qty }
                end
            end
        end
    end

    if next(inv) == nil and type(snapshot) == "table" and type(snapshot.Items) == "table" then
        for itemId, amount in pairs(snapshot.Items) do
            local remaining = normalizeQty(amount)
            for i = 1, SLOT_COUNT do
                if remaining <= 0 then
                    break
                end
                if not inv[i] then
                    inv[i] = { id = itemId, qty = remaining }
                    remaining = 0
                end
            end
        end
    end

    inventories[player] = inv
    equipped[player] = (type(snapshot) == "table" and type(snapshot.Equipped) == "table") and snapshot.Equipped or {}
    broadcast(player)
end

function InventoryService:equipItem(player, itemId)
    if type(itemId) ~= "string" or itemId == "" then
        return false, "Invalid item."
    end
    if not self:hasItem(player, itemId, 1) then
        return false, "Item not found."
    end
    local eq = equipped[player] or {}
    eq.Hand = itemId
    equipped[player] = eq
    markDirty(player)
    return true, "Equipped " .. itemId
end

function InventoryService:getEquippedItem(player, slotName)
    local eq = equipped[player]
    if not eq then
        return nil
    end
    return eq[slotName]
end

function InventoryService:consume(player, itemId)
    if not self:hasItem(player, itemId, 1) then
        return false, "Item not found."
    end
    self:removeItem(player, itemId, 1)
    return true, "Consumed " .. itemId
end

return InventoryService
