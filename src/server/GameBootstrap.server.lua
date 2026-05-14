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
context.EnemyService = require(servicesFolder.EnemyService)
context.CombatService = require(servicesFolder.CombatService)

local startupOrder = {
	context.WorldService,
	context.InventoryService,
	context.VitalsService,
	context.ProgressionService,
	context.ObjectiveService,
	context.ResourceService,
	context.CraftingService,
	context.EnemyService,
	context.CombatService,
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
	for _, service in ipairs(startupOrder) do
		if service.playerRemoving then
			service.playerRemoving(player)
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
