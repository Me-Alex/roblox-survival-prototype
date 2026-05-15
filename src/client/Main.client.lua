-- Main.client.lua  (Milestone 3)
-- Client entry point. Loads all controllers and wires them with a shared context.

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

local ctx = {
    Config  = Config,
    Remotes = Remotes,
    HudController       = HudController,
    InventoryController = InventoryController,
    CraftingController  = CraftingController,
}

HudController:init(ctx)
InventoryController:init(ctx)
CraftingController:init(ctx)

print("[Client] All controllers initialised.")
