local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.ensure()

local servicesFolder = script.Parent.Services

local context = {}
context.WorldService = require(servicesFolder.WorldService)
context.InventoryService = require(servicesFolder.InventoryService)
context.VitalsService = require(servicesFolder.VitalsService)
context.ProgressionService = require(servicesFolder.ProgressionService)
context.ObjectiveService = require(servicesFolder.ObjectiveService)
context.ResourceService = require(servicesFolder.ResourceService)
context.CraftingService = require(servicesFolder.CraftingService)
context.ShopService = require(servicesFolder.ShopService)
context.ItemToolService = require(servicesFolder.ItemToolService)
context.EnemyService = require(servicesFolder.EnemyService)
context.CombatService = require(servicesFolder.CombatService)
context.PersistenceService = require(servicesFolder.PersistenceService)

local startupOrder = {
	context.WorldService,
	context.InventoryService,
	context.VitalsService,
	context.ProgressionService,
	context.ObjectiveService,
	context.ResourceService,
	context.CraftingService,
	context.ShopService,
	context.ItemToolService,
	context.EnemyService,
	context.CombatService,
	context.PersistenceService,
}

for _, service in ipairs(startupOrder) do
	if service.init then
		service.init(context)
	end
end

local function onPlayerAdded(player)
	for _, service in ipairs(startupOrder) do
		if service.playerAdded then
			service.playerAdded(player)
		end
	end
end

local function onPlayerRemoving(player)
	if context.PersistenceService and context.PersistenceService.playerRemoving then
		context.PersistenceService.playerRemoving(player)
	end

	for _, service in ipairs(startupOrder) do
		if service ~= context.PersistenceService and service.playerRemoving then
			service.playerRemoving(player)
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
