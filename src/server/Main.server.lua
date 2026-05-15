-- Main.server.lua  (Milestone 10)
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local Shared  = ReplicatedStorage:WaitForChild("Shared")
local Config  = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

Remotes:init(ReplicatedStorage)

local Services = script.Parent:WaitForChild("Services")

local function requireService(name)
    local moduleScript = Services:FindFirstChild(name)
    if not moduleScript then
        warn("[Server missing service module]", name)
        return nil
    end

    local ok, serviceOrErr = pcall(require, moduleScript)
    if not ok then
        warn("[Server require failed]", name, serviceOrErr)
        return nil
    end

    return serviceOrErr
end

local function pushService(list, service)
    if service then
        table.insert(list, service)
    end
end

local function callServiceMethod(service, methodName, ...)
    local method = service and service[methodName]
    if type(method) ~= "function" then
        return true
    end

    local okInfo, arity = pcall(function()
        return select(1, debug.info(method, "a"))
    end)

    local ok, err
    if okInfo and type(arity) == "number" then
        local passedCount = select("#", ...)
        if arity >= passedCount + 1 then
            ok, err = pcall(method, service, ...)
        else
            ok, err = pcall(method, ...)
        end
    else
        ok, err = pcall(method, service, ...)
        if not ok then
            ok, err = pcall(method, ...)
        end
    end

    return ok, err
end

local VitalsService      = requireService("VitalsService")
local InventoryService   = requireService("InventoryService")
local CraftingService    = requireService("CraftingService")
local WorldService       = requireService("WorldService")
local ResourceService    = requireService("ResourceService")
local EnemyService       = requireService("EnemyService")
local WildlifeService    = requireService("WildlifeService")
local StoneOvenService   = requireService("StoneOvenService")
local WaterService       = requireService("WaterService")
local CombatService      = requireService("CombatService")
local ProgressionService = requireService("ProgressionService")
local ObjectiveService   = requireService("ObjectiveService")
local PersistenceService = requireService("PersistenceService")
local ShopService        = requireService("ShopService")
local SleepService       = requireService("SleepService")
local RespawnService     = requireService("RespawnService")  -- NEW

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

local startupOrder = {}
pushService(startupOrder, WorldService)
pushService(startupOrder, ResourceService)
pushService(startupOrder, VitalsService)
pushService(startupOrder, InventoryService)
pushService(startupOrder, StoneOvenService)
pushService(startupOrder, CraftingService)
pushService(startupOrder, WildlifeService)
pushService(startupOrder, WaterService)
pushService(startupOrder, EnemyService)
pushService(startupOrder, CombatService)
pushService(startupOrder, ProgressionService)
pushService(startupOrder, ObjectiveService)
pushService(startupOrder, PersistenceService)
pushService(startupOrder, ShopService)
pushService(startupOrder, SleepService)
pushService(startupOrder, RespawnService)

for _, service in ipairs(startupOrder) do
    if service.init then
        local ok, err = callServiceMethod(service, "init", ctx)
        if not ok then
            warn("[Server init failed]", err)
        end
    end
end

print("[Server] All services initialised.")

local function onPlayerAdded(player)
    for _, service in ipairs(startupOrder) do
        if service.playerAdded then
            local ok, err = callServiceMethod(service, "playerAdded", player)
            if not ok then
                warn("[PlayerAdded service error]", err)
            end
        end
    end
end

local function onPlayerRemoving(player)
    for _, service in ipairs(startupOrder) do
        if service.playerRemoving then
            local ok, err = callServiceMethod(service, "playerRemoving", player)
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

local tickables = {}
pushService(tickables, WorldService)
pushService(tickables, ResourceService)
pushService(tickables, VitalsService)
pushService(tickables, EnemyService)
pushService(tickables, WildlifeService)
pushService(tickables, WaterService)
pushService(tickables, CombatService)

RunService.Heartbeat:Connect(function(dt)
    for _, svc in ipairs(tickables) do
        if svc.tick then
            local ok, err = callServiceMethod(svc, "tick", dt)
            if not ok then warn("[Server tick]", err) end
        end
    end
end)
