local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local InventoryService = {}

local inventories = {}
local equippedByPlayer = {}
local durabilityByPlayer = {}
local context

local function cloneMap(items)
	local copy = {}

	for itemId, count in pairs(items) do
		copy[itemId] = count
	end

	return copy
end

local function getOrCreate(player)
	if not inventories[player] then
		inventories[player] = {}

		for itemId in pairs(Config.Items) do
			inventories[player][itemId] = 0
		end
	end

	return inventories[player]
end

local function getEquipped(player)
	if not equippedByPlayer[player] then
		equippedByPlayer[player] = {
			Weapon = nil,
			Armor = nil,
		}
	end

	return equippedByPlayer[player]
end

local function getDurability(player)
	if not durabilityByPlayer[player] then
		durabilityByPlayer[player] = {}
	end

	return durabilityByPlayer[player]
end

local function ensureDurability(player, itemId)
	local equipmentConfig = Config.Equipment[itemId]
	if not equipmentConfig then
		return
	end

	local durability = getDurability(player)
	if not durability[itemId] or durability[itemId] <= 0 then
		durability[itemId] = equipmentConfig.MaxDurability
	end
end

local function clearInvalidEquipment(player)
	local items = getOrCreate(player)
	local equipped = getEquipped(player)

	for slot, itemId in pairs(equipped) do
		if itemId and (items[itemId] or 0) <= 0 then
			equipped[slot] = nil
		end
	end
end

function InventoryService.getInventory(player)
	clearInvalidEquipment(player)

	return {
		Items = cloneMap(getOrCreate(player)),
		Equipped = cloneMap(getEquipped(player)),
		Durability = cloneMap(getDurability(player)),
	}
end

function InventoryService.send(player)
	Remotes.get("InventoryUpdated"):FireClient(player, InventoryService.getInventory(player))
end

function InventoryService.addItem(player, itemId, amount)
	assert(Config.Items[itemId], string.format("Unknown item %s", tostring(itemId)))

	local items = getOrCreate(player)
	items[itemId] = math.max(0, (items[itemId] or 0) + amount)
	if amount > 0 then
		ensureDurability(player, itemId)
	end
	InventoryService.send(player)

	if amount > 0 and context and context.ObjectiveService then
		context.ObjectiveService.recordCollected(player, itemId, amount)
	end
end

function InventoryService.hasItem(player, itemId, amount)
	local items = getOrCreate(player)
	return (items[itemId] or 0) >= (amount or 1)
end

function InventoryService.hasItems(player, cost)
	local items = getOrCreate(player)

	for itemId, amount in pairs(cost) do
		if (items[itemId] or 0) < amount then
			return false, itemId
		end
	end

	return true
end

function InventoryService.removeItems(player, cost)
	local ok = InventoryService.hasItems(player, cost)
	if not ok then
		return false
	end

	local items = getOrCreate(player)

	for itemId, amount in pairs(cost) do
		items[itemId] -= amount
	end

	clearInvalidEquipment(player)
	InventoryService.send(player)
	return true
end

function InventoryService.getEquippedItem(player, slot)
	return getEquipped(player)[slot]
end

function InventoryService.equipItem(player, itemId)
	local equipmentConfig = Config.Equipment[itemId]
	if not equipmentConfig then
		return false, "That item cannot be equipped."
	end

	if not InventoryService.hasItem(player, itemId, 1) then
		return false, "You do not have that item."
	end

	ensureDurability(player, itemId)
	getEquipped(player)[equipmentConfig.Slot] = itemId
	InventoryService.send(player)

	return true, string.format("Equipped %s.", Config.Items[itemId].DisplayName)
end

function InventoryService.getDurability(player, itemId)
	return getDurability(player)[itemId]
end

function InventoryService.damageEquipment(player, itemId, amount)
	if not itemId or not Config.Equipment[itemId] then
		return
	end

	if not InventoryService.hasItem(player, itemId, 1) then
		return
	end

	ensureDurability(player, itemId)

	local durability = getDurability(player)
	durability[itemId] -= amount

	if durability[itemId] <= 0 then
		InventoryService.removeItems(player, { [itemId] = 1 })

		if InventoryService.hasItem(player, itemId, 1) then
			durability[itemId] = Config.Equipment[itemId].MaxDurability
		else
			durability[itemId] = nil
			local equipped = getEquipped(player)
			for slot, equippedItemId in pairs(equipped) do
				if equippedItemId == itemId then
					equipped[slot] = nil
				end
			end
		end

		Remotes.get("Notification"):FireClient(player, string.format("%s broke.", Config.Items[itemId].DisplayName))
		InventoryService.send(player)
	else
		InventoryService.send(player)
	end
end

function InventoryService.damageEquippedArmor(player, amount)
	local armorId = InventoryService.getEquippedItem(player, "Armor")
	if armorId then
		InventoryService.damageEquipment(player, armorId, amount)
	end
end

function InventoryService.consume(player, itemId)
	local consumable = Config.Consumables[itemId]
	if not consumable then
		return false, "That item cannot be used."
	end

	if not InventoryService.hasItem(player, itemId, 1) then
		return false, "You do not have that item."
	end

	InventoryService.removeItems(player, { [itemId] = 1 })

	if context and context.VitalsService then
		context.VitalsService.applyConsumable(player, consumable)
	end

	Remotes.get("Notification"):FireClient(player, consumable.Notify or "Item used.")
	return true, "Used."
end

function InventoryService.init(newContext)
	context = newContext

	Remotes.get("GetInventory").OnServerInvoke = function(player)
		return InventoryService.getInventory(player)
	end

	Remotes.get("ConsumeRequest").OnServerInvoke = function(player, itemId)
		return InventoryService.consume(player, itemId)
	end

	Remotes.get("EquipRequest").OnServerInvoke = function(player, itemId)
		return InventoryService.equipItem(player, itemId)
	end
end

function InventoryService.playerAdded(player)
	getOrCreate(player)
	InventoryService.send(player)
end

function InventoryService.playerRemoving(player)
	inventories[player] = nil
	equippedByPlayer[player] = nil
	durabilityByPlayer[player] = nil
end

return InventoryService
