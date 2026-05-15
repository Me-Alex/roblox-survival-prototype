-- Main.server.lua  (Milestone 10)
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local Shared  = ReplicatedStorage:WaitForChild("Shared")
local Config  = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

Remotes:init(ReplicatedStorage)

local Services = script.Parent:WaitForChild("Services")
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

local startupOrder = {
    WorldService,
    ResourceService,
    VitalsService,
    InventoryService,
    StoneOvenService,
    CraftingService,
    WildlifeService,
    WaterService,
    EnemyService,
    CombatService,
    ProgressionService,
    ObjectiveService,
    PersistenceService,
    ShopService,
    SleepService,
    RespawnService,
}

for _, service in ipairs(startupOrder) do
    if service.init then
        local ok, err = pcall(service.init, service, ctx)
        if not ok then
            warn("[Server init failed]", err)
        end
    end
end

print("[Server] All services initialised.")

local function onPlayerAdded(player)
    for _, service in ipairs(startupOrder) do
        if service.playerAdded then
            local ok, err = pcall(service.playerAdded, service, player)
            if not ok then
                warn("[PlayerAdded service error]", err)
            end
        end
    end
end

local function onPlayerRemoving(player)
    for _, service in ipairs(startupOrder) do
        if service.playerRemoving then
            local ok, err = pcall(service.playerRemoving, service, player)
            if not ok then
                warn("[PlayerRemoving service error]", err)
            end
        end
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

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
