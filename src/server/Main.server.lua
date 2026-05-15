-- Main.server.lua  (Milestone 6b)
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared  = ReplicatedStorage:WaitForChild("Shared")
local Config  = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

Remotes:init(ReplicatedStorage)

local Services = ServerScriptService:WaitForChild("Services")
local VitalsService      = require(Services:WaitForChild("VitalsService"))
local InventoryService   = require(Services:WaitForChild("InventoryService"))
local CraftingService    = require(Services:WaitForChild("CraftingService"))
local WorldService       = require(Services:WaitForChild("WorldService"))
local ResourceService    = require(Services:WaitForChild("ResourceService"))
local EnemyService       = require(Services:WaitForChild("EnemyService"))
local CombatService      = require(Services:WaitForChild("CombatService"))
local ProgressionService = require(Services:WaitForChild("ProgressionService"))
local ObjectiveService   = require(Services:WaitForChild("ObjectiveService"))
local PersistenceService = require(Services:WaitForChild("PersistenceService"))
local ShopService        = require(Services:WaitForChild("ShopService"))
local SleepService       = require(Services:WaitForChild("SleepService"))  -- NEW

local ctx = {
    Config            = Config,
    Remotes           = Remotes,
    VitalsService     = VitalsService,
    InventoryService  = InventoryService,
    CraftingService   = CraftingService,
    WorldService      = WorldService,
    ResourceService   = ResourceService,
    EnemyService      = EnemyService,
    CombatService     = CombatService,
    ProgressionService= ProgressionService,
    ObjectiveService  = ObjectiveService,
    PersistenceService= PersistenceService,
    ShopService       = ShopService,
    SleepService      = SleepService,   -- NEW
}

WorldService:init(ctx)
ResourceService:init(ctx)
VitalsService:init(ctx)
InventoryService:init(ctx)
CraftingService:init(ctx)
EnemyService:init(ctx)
CombatService:init(ctx)
ProgressionService:init(ctx)
ObjectiveService:init(ctx)
PersistenceService:init(ctx)
ShopService:init(ctx)
SleepService:init(ctx)   -- NEW (after WorldService so Workspace is ready)

print("[Server] All services initialised.")

-- Respawn handler
Remotes.RespawnRequest.OnServerEvent:Connect(function(player)
    player:LoadCharacter()
end)

local tickables = {
    WorldService, ResourceService,
    VitalsService, EnemyService, CombatService,
}

RunService.Heartbeat:Connect(function(dt)
    for _, svc in ipairs(tickables) do
        if svc.tick then
            local ok, err = pcall(svc.tick, svc, dt)
            if not ok then warn("[Server tick]", err) end
        end
    end
end)
