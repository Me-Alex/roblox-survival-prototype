-- InventoryService.lua  (Milestone 6a)
-- Changes: UseItem handling extended so that placing a Bedroll
-- calls WorldService:spawnBedroll() at the player's feet.

local Players = game:GetService("Players")

local InventoryService = {}
local ctx

local inventories = {}   -- inventories[player] = { [slot] = { id, qty } }
local SLOT_COUNT  = 20

-- ── Helpers ───────────────────────────────────────────────────────────────

local function emptyInv()
    local inv = {}
    for i = 1, SLOT_COUNT do inv[i] = nil end
    return inv
end

local function broadcast(player)
    ctx.Remotes.InventoryUpdate:FireClient(player, inventories[player])
end

-- ── Init ─────────────────────────────────────────────────────────────────

function InventoryService:init(context)
    ctx = context

    Players.PlayerAdded:Connect(function(player)
        inventories[player] = emptyInv()
    end)
    Players.PlayerRemoving:Connect(function(player)
        inventories[player] = nil
    end)
    for _, p in ipairs(Players:GetPlayers()) do
        if not inventories[p] then inventories[p] = emptyInv() end
    end

    -- UseItem from client (eat food OR place structure)
    ctx.Remotes.UseItem.OnServerEvent:Connect(function(player, slot)
        local inv  = inventories[player]
        if not inv then return end
        local entry = inv[slot]
        if not entry then return end
        local itemCfg = ctx.Config.Items[entry.id]
        if not itemCfg then return end

        -- ── Food ────────────────────────────────────────────────────────
        if itemCfg.food then
            local v = ctx.VitalsService:get(player)
            if not v then return end
            local V = ctx.Config.Vitals
            v.hunger = math.min(v.hunger + (itemCfg.food.hungerRestore or 0), V.MaxHunger)
            v.thirst = math.min(v.thirst + (itemCfg.food.thirstRestore or 0), V.MaxThirst)
            if itemCfg.food.curesPoison   then v.poisoned  = false end
            if itemCfg.food.curesBleeding then v.bleeding  = false end
            self:removeFromSlot(player, slot, 1)
            broadcast(player)
            ctx.Remotes.Notify:FireClient(player, {
                text  = "Ate " .. (itemCfg.displayName or entry.id),
                color = "green",
            })

        -- ── Bandage ──────────────────────────────────────────────────────
        elseif itemCfg.onUse == "curesBleeding" then
            ctx.VitalsService:setStatus(player, "bleeding", false)
            self:removeFromSlot(player, slot, 1)
            broadcast(player)
            ctx.Remotes.Notify:FireClient(player, { text="Bandage applied", color="green" })

        -- ── Placeable structures ─────────────────────────────────────────
        elseif itemCfg.placeable then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            -- Place 4 studs in front of the player
            local cf   = root.CFrame
            local pos  = cf.Position + cf.LookVector * 4 + Vector3.new(0, 0, 0)

            if entry.id == "Bedroll" then
                ctx.WorldService:spawnBedroll(pos, player.UserId)
                self:removeFromSlot(player, slot, 1)
                broadcast(player)
                ctx.Remotes.Notify:FireClient(player, { text="Bedroll placed", color="green" })
            elseif entry.id == "Campfire" then
                ctx.WorldService:spawnCampfire(pos)
                self:removeFromSlot(player, slot, 1)
                broadcast(player)
                ctx.Remotes.Notify:FireClient(player, { text="Campfire placed", color="yellow" })
            end
        end
    end)

    print("[InventoryService] Initialised")
end

-- ── Public API ────────────────────────────────────────────────────────────

function InventoryService:addItem(player, itemId, qty)
    local inv = inventories[player]
    if not inv then return false end
    qty = qty or 1
    local cfg = ctx.Config.Items[itemId]
    if not cfg then return false end

    -- Try to stack onto existing slot first
    if cfg.stackable then
        for i = 1, SLOT_COUNT do
            if inv[i] and inv[i].id == itemId then
                inv[i].qty = inv[i].qty + qty
                broadcast(player)
                return true
            end
        end
    end

    -- Find first empty slot
    for i = 1, SLOT_COUNT do
        if not inv[i] then
            inv[i] = { id = itemId, qty = qty }
            broadcast(player)
            return true
        end
    end

    -- Inventory full
    ctx.Remotes.Notify:FireClient(player, { text="Inventory full!", color="red" })
    return false
end

function InventoryService:removeFromSlot(player, slot, qty)
    local inv = inventories[player]
    if not inv or not inv[slot] then return end
    inv[slot].qty = inv[slot].qty - qty
    if inv[slot].qty <= 0 then inv[slot] = nil end
    broadcast(player)
end

function InventoryService:getSlot(player, slot)
    local inv = inventories[player]
    return inv and inv[slot]
end

function InventoryService:getAll(player)
    return inventories[player] or {}
end

return InventoryService
