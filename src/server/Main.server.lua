-- Main.server.lua
-- Server entry point. Loads all services in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Shared  = ReplicatedStorage:WaitForChild("Shared")
local Config  = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ServerScript   = script.Parent
local ServicesFolder = ServerScript:WaitForChild("Services")

local WorldService     = require(ServicesFolder:WaitForChild("WorldService"))
local VitalsService    = require(ServicesFolder:WaitForChild("VitalsService"))
local InventoryService = require(ServicesFolder:WaitForChild("InventoryService"))
local CraftingService  = require(ServicesFolder:WaitForChild("CraftingService"))
local EnemyService     = require(ServicesFolder:WaitForChild("EnemyService"))

local ctx = {
    Config           = Config,
    Remotes          = Remotes,
    WorldService     = WorldService,
    VitalsService    = VitalsService,
    InventoryService = InventoryService,
    CraftingService  = CraftingService,
    EnemyService     = EnemyService,
}

WorldService:init(ctx)
VitalsService:init(ctx)
InventoryService:init(ctx)
CraftingService:init(ctx)
EnemyService:init(ctx)

print("[Server] All services initialised")

local services = { WorldService, VitalsService, InventoryService, CraftingService, EnemyService }
RunService.Heartbeat:Connect(function(dt)
    for _, service in ipairs(services) do
        if service.tick then service:tick(dt) end
    end
end)

Players.PlayerAdded:Connect(function(player)
    VitalsService:onPlayerAdded(player)
    InventoryService:onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
    VitalsService:onPlayerRemoving(player)
    InventoryService:onPlayerRemoving(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
    VitalsService:onPlayerAdded(player)
    InventoryService:onPlayerAdded(player)
end
