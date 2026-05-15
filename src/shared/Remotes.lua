-- Remotes.lua  (Milestone 4 — added RespawnRequest)
local RS = game:GetService("ReplicatedStorage")

local function getOrCreate(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new("RemoteEvent")
    r.Name   = name
    r.Parent = parent
    return r
end

local container = RS:FindFirstChild("SurvivalRemotes")
if not container then
    container      = Instance.new("Folder")
    container.Name = "SurvivalRemotes"
    container.Parent = RS
end

local Remotes = {}
-- Server → Client
Remotes.VitalsUpdate     = getOrCreate(container, "VitalsUpdate")
Remotes.InventoryUpdate  = getOrCreate(container, "InventoryUpdate")
Remotes.Notify           = getOrCreate(container, "Notify")
Remotes.ResourceChanged  = getOrCreate(container, "ResourceChanged")
Remotes.DayNightUpdate   = getOrCreate(container, "DayNightUpdate")
Remotes.ObjectiveUpdate  = getOrCreate(container, "ObjectiveUpdate")
-- Client → Server
Remotes.CraftRequest     = getOrCreate(container, "CraftRequest")
Remotes.UseItem          = getOrCreate(container, "UseItem")
Remotes.DropItem         = getOrCreate(container, "DropItem")
Remotes.PlaceStructure   = getOrCreate(container, "PlaceStructure")
Remotes.AttackRequest    = getOrCreate(container, "AttackRequest")
Remotes.RespawnRequest   = getOrCreate(container, "RespawnRequest")  -- NEW

return Remotes
