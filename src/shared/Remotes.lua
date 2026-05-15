-- Remotes.lua  (Milestone 10 — added PlayerDied)
local Remotes = {}

local REMOTE_NAMES = {
    -- Vitals
    "VitalsUpdate",
    "StatusUpdate",
    "PlayerDied",         -- NEW: server → client, carries cause string

    -- Inventory & crafting
    "InventoryUpdate",
    "CraftRequest",

    -- Resources
    "HarvestRequest",
    "ResourceDepleted",

    -- Combat
    "AttackRequest",

    -- Notifications
    "Notify",

    -- World
    "TimeUpdate",
    "DayNightUpdate",

    -- Structures
    "PlaceCampfireRequest",
    "PlaceBedrollRequest",
    "PlaceOvenRequest",

    -- Sleep
    "SleepRequest",
    "SleepResponse",

    -- Progression
    "ProgressionUpdate",
    "ObjectiveUpdate",

    -- Shop
    "ShopRequest",
    "ShopResponse",

    -- Player
    "RespawnRequest",
    "UseItem",
}

function Remotes:init(replicatedStorage)
    local folder = replicatedStorage:FindFirstChild("Remotes")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name   = "Remotes"
        folder.Parent = replicatedStorage
    end
    for _, name in ipairs(REMOTE_NAMES) do
        if not folder:FindFirstChild(name) then
            local r = Instance.new("RemoteEvent")
            r.Name   = name
            r.Parent = folder
        end
        self[name] = folder:FindFirstChild(name)
    end
end

return Remotes
