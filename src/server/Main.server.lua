-- Main.server.lua  (Milestone 10)
local RunService          = game:GetService("RunService")
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
local WildlifeService    = require(Services:WaitForChild("WildlifeService"))
local StoneOvenService   = require(Services:WaitForChild("StoneOvenService"))
local WaterService       = require(Services:WaitForChild("WaterService"))
local CombatService      = require(Services:WaitForChild("CombatService"))
local ProgressionService = require(Services:WaitForChild("ProgressionService"))
local ObjectiveService   = require(Services:WaitForChild("ObjectiveService"))
local PersistenceService = require(Services:WaitForChild("PersistenceService"))
local ShopService        = require(Services:WaitForChild("ShopService"))
local SleepService       = require(Services:WaitForChild("SleepService"))
local RespawnService     = require(Services:WaitForChild("RespawnService"))  -- NEW

local ctx = {
    Config             = Config,
    Remotes            = Remotes,
    VitalsService      = VitalsService,
    InventoryService   = InventoryService,
    CraftingService    = CraftingService,
    WorldService       = WorldService,
    ResourceService    = ResourceService,
    EnemyService       = EnemyService,
    WildlifeService    = WildlifeService,
    StoneOvenService   = StoneOvenService,
    WaterService       = WaterService,
    CombatService      = CombatService,
    ProgressionService = ProgressionService,
    ObjectiveService   = ObjectiveService,
    PersistenceService = PersistenceService,
    ShopService        = ShopService,
    SleepService       = SleepService,
    RespawnService     = RespawnService,    -- NEW
}

WorldService:init(ctx)
ResourceService:init(ctx)
VitalsService:init(ctx)
InventoryService:init(ctx)
StoneOvenService:init(ctx)
CraftingService:init(ctx)
WildlifeService:init(ctx)
WaterService:init(ctx)
EnemyService:init(ctx)
CombatService:init(ctx)
ProgressionService:init(ctx)
ObjectiveService:init(ctx)
PersistenceService:init(ctx)
ShopService:init(ctx)
SleepService:init(ctx)
RespawnService:init(ctx)    -- NEW

print("[Server] All services initialised.")

Remotes.RespawnRequest.OnServerEvent:Connect(function(player)
    player:LoadCharacter()
end)

local tickables = {
    WorldService, ResourceService,
    VitalsService, EnemyService,
    WildlifeService, WaterService,
    CombatService,
}

RunService.Heartbeat:Connect(function(dt)
    for _, svc in ipairs(tickables) do
        if svc.tick then
            local ok, err = pcall(svc.tick, svc, dt)
            if not ok then warn("[Server tick]", err) end
        end
    end
end)
