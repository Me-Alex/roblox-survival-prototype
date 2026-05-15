-- Main.client.lua  (Milestone 4)
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
player:WaitForChild("PlayerGui")

local Shared  = ReplicatedStorage:WaitForChild("Shared")
local Config  = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent:WaitForChild("Controllers")
local HudController       = require(Controllers:WaitForChild("HudController"))
local InventoryController = require(Controllers:WaitForChild("InventoryController"))
local CraftingController  = require(Controllers:WaitForChild("CraftingController"))
local DeathController     = require(Controllers:WaitForChild("DeathController"))

local ctx = {
    Config  = Config,
    Remotes = Remotes,
    HudController       = HudController,
    InventoryController = InventoryController,
    CraftingController  = CraftingController,
    DeathController     = DeathController,
    DayNightCache       = { day = 1, isNight = false },
}

HudController:init(ctx)
InventoryController:init(ctx)
CraftingController:init(ctx)
DeathController:init(ctx)

print("[Client] All controllers initialised.")
