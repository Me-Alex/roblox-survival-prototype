-- Remotes.lua
-- Creates or finds all RemoteEvents and RemoteFunctions.
-- Both server and client require this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getOrCreate(className, name, parent)
    local existing = parent:FindFirstChild(name)
    if existing then return existing end
    local obj = Instance.new(className)
    obj.Name = name
    obj.Parent = parent
    return obj
end

local remotesFolder = getOrCreate("Folder", "Remotes", ReplicatedStorage)

local Remotes = {}

-- Vitals
Remotes.UpdateVitals     = getOrCreate("RemoteEvent", "UpdateVitals",     remotesFolder)
-- Inventory
Remotes.UpdateInventory  = getOrCreate("RemoteEvent", "UpdateInventory",  remotesFolder)
Remotes.UseItem          = getOrCreate("RemoteEvent", "UseItem",          remotesFolder)
Remotes.DropItem         = getOrCreate("RemoteEvent", "DropItem",         remotesFolder)
-- Crafting
Remotes.CraftItem        = getOrCreate("RemoteEvent", "CraftItem",        remotesFolder)
Remotes.CraftResult      = getOrCreate("RemoteEvent", "CraftResult",      remotesFolder)
-- Interaction
Remotes.Interact         = getOrCreate("RemoteEvent", "Interact",         remotesFolder)
Remotes.ShowPrompt       = getOrCreate("RemoteEvent", "ShowPrompt",       remotesFolder)
-- World
Remotes.UpdateWorld      = getOrCreate("RemoteEvent", "UpdateWorld",      remotesFolder)
Remotes.ResourceChanged  = getOrCreate("RemoteEvent", "ResourceChanged",  remotesFolder)
-- Notifications
Remotes.Notify           = getOrCreate("RemoteEvent", "Notify",           remotesFolder)
-- Structures
Remotes.PlaceStructure   = getOrCreate("RemoteEvent", "PlaceStructure",   remotesFolder)

return Remotes
