local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local InventoryService = {}

local inventories = {}
local context

local function cloneItems(items)
	local copy = {}

	for itemId, count in pairs(items) do
		copy[itemId] = count
	end

	return copy
end

local function getOrCreate(player)
	if not inventories[player] then
		inventories[player] = {
			Wood = 0,
			Stone = 0,
			Fiber = 0,
			Berries = 0,
			CookedBerries = 0,
			Bandage = 0,
			StoneAxe = 0,
			CampfireKit = 0,
			ShelterKit = 0,
		}
	end

	return inventories[player]
end

function InventoryService.getInventory(player)
	return cloneItems(getOrCreate(player))
end

function InventoryService.send(player)
	Remotes.get("InventoryUpdated"):FireClient(player, InventoryService.getInventory(player))
end

function InventoryService.addItem(player, itemId, amount)
	assert(Config.Items[itemId], string.format("Unknown item %s", tostring(itemId)))

	local items = getOrCreate(player)
	items[itemId] = math.max(0, (items[itemId] or 0) + amount)
	InventoryService.send(player)
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

	InventoryService.send(player)
	return true
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
end

function InventoryService.playerAdded(player)
	getOrCreate(player)
	InventoryService.send(player)
end

function InventoryService.playerRemoving(player)
	inventories[player] = nil
end

return InventoryService
