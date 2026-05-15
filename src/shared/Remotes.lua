-- Remotes.lua  (Milestone 8 — added PlaceOvenRequest)
-- Central registry for all RemoteEvents and RemoteFunctions.
-- Keeps names in one place so client and server always match.

local Remotes = {}

local REMOTE_NAMES = {
    -- Vitals
    "VitalsUpdate",
    "StatusUpdate",

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

    -- Structures
    "PlaceCampfireRequest",
    "PlaceBedrollRequest",
    "PlaceOvenRequest",      -- NEW

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
}

function Remotes:init(replicatedStorage)
    local folder = replicatedStorage:FindFirstChild("Remotes")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Remotes"
        folder.Parent = replicatedStorage
    end

    for _, name in ipairs(REMOTE_NAMES) do
        if not folder:FindFirstChild(name) then
            local remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = folder
        end
        self[name] = folder:FindFirstChild(name)
    end
end

return Remotes
