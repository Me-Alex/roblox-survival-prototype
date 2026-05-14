local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.ensure()

local servicesFolder = script.Parent.Services

local context = {}
context.WorldService = require(servicesFolder.WorldService)
context.InventoryService = require(servicesFolder.InventoryService)
context.VitalsService = require(servicesFolder.VitalsService)
context.ResourceService = require(servicesFolder.ResourceService)
context.CraftingService = require(servicesFolder.CraftingService)

local startupOrder = {
	context.WorldService,
	context.InventoryService,
	context.VitalsService,
	context.ResourceService,
	context.CraftingService,
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
