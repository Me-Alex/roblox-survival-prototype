-- Main.client.lua
-- Client entry point. Loads all controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Shared  = ReplicatedStorage:WaitForChild("Shared")
local Config  = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientScript = script.Parent
local CtrlFolder   = ClientScript:WaitForChild("Controllers")

local HudController       = require(CtrlFolder:WaitForChild("HudController"))
local InventoryController = require(CtrlFolder:WaitForChild("InventoryController"))

local ctx = {
    Config  = Config,
    Remotes = Remotes,
    Player  = Players.LocalPlayer,
    HudController       = HudController,
    InventoryController = InventoryController,
}

HudController:init(ctx)
InventoryController:init(ctx)

print("[Client] All controllers initialised")

local controllers = { HudController, InventoryController }
RunService.Heartbeat:Connect(function(dt)
    for _, ctrl in ipairs(controllers) do
        if ctrl.tick then ctrl:tick(dt) end
    end
end)
