-- Main.client.lua  (Milestone 6b)
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local Shared    = ReplicatedStorage:WaitForChild("Shared")
local Config    = require(Shared:WaitForChild("Config"))
local RemotesMod= require(Shared:WaitForChild("Remotes"))

local RS = ReplicatedStorage
local Remotes = {
    VitalsUpdate     = RS:WaitForChild("VitalsUpdate"),
    InventoryUpdate  = RS:WaitForChild("InventoryUpdate"),
    UseItem          = RS:WaitForChild("UseItem"),
    DropItem         = RS:WaitForChild("DropItem"),
    CraftRequest     = RS:WaitForChild("CraftRequest"),
    DayNightUpdate   = RS:WaitForChild("DayNightUpdate"),
    Notify           = RS:WaitForChild("Notify"),
    PlayerDied       = RS:WaitForChild("PlayerDied"),
    AttackRequest    = RS:WaitForChild("AttackRequest"),
    ProgressionUpdate= RS:WaitForChild("ProgressionUpdate"),
    ObjectiveUpdate  = RS:WaitForChild("ObjectiveUpdate"),
    RespawnRequest   = RS:WaitForChild("RespawnRequest"),
    SleepRequest     = RS:WaitForChild("SleepRequest"),   -- NEW
    SleepResponse    = RS:WaitForChild("SleepResponse"),  -- NEW
}

local Controllers = script.Parent:WaitForChild("Controllers")
local HudController      = require(Controllers:WaitForChild("HudController"))
local InventoryController= require(Controllers:WaitForChild("InventoryController"))
local CraftingController = require(Controllers:WaitForChild("CraftingController"))
local DeathController    = require(Controllers:WaitForChild("DeathController"))
local SleepController    = require(Controllers:WaitForChild("SleepController"))  -- NEW

local ctx = {
    Config  = Config,
    Remotes = Remotes,
}

HudController:init(ctx)
InventoryController:init(ctx)
CraftingController:init(ctx)
DeathController:init(ctx)
SleepController:init(ctx)   -- NEW

print("[Client] All controllers initialised.")
