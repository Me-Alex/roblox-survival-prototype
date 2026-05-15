local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local REMOTE_DEFS = {
    -- Core gameplay
    { name = "VitalsUpdate", className = "RemoteEvent" },
    { name = "StatusUpdate", className = "RemoteEvent" },
    { name = "PlayerDied", className = "RemoteEvent" },
    { name = "InventoryUpdate", className = "RemoteEvent" },
    { name = "CraftRequest", className = "RemoteEvent" },
    { name = "UseItem", className = "RemoteEvent" },
    { name = "DropItem", className = "RemoteEvent" },
    { name = "HarvestRequest", className = "RemoteEvent" },
    { name = "ResourceDepleted", className = "RemoteEvent" },
    { name = "ResourceChanged", className = "RemoteEvent" },
    { name = "AttackRequest", className = "RemoteEvent" },
    { name = "Notify", className = "RemoteEvent" },
    { name = "TimeUpdate", className = "RemoteEvent" },
    { name = "DayNightUpdate", className = "RemoteEvent" },
    { name = "RespawnRequest", className = "RemoteEvent" },
    { name = "SleepRequest", className = "RemoteEvent" },
    { name = "SleepResponse", className = "RemoteEvent" },
    { name = "PlaceStructure", className = "RemoteEvent" },
    { name = "PlaceCampfireRequest", className = "RemoteEvent" },
    { name = "PlaceBedrollRequest", className = "RemoteEvent" },
    { name = "PlaceOvenRequest", className = "RemoteEvent" },

    -- Progression / objectives
    { name = "ProgressionUpdate", className = "RemoteEvent" },
    { name = "ObjectiveUpdate", className = "RemoteEvent" },
    { name = "SaveStatusUpdated", className = "RemoteEvent" },
    { name = "LevelUpReward", className = "RemoteEvent" },

    -- Shops
    { name = "ShopOpened", className = "RemoteEvent" },
    { name = "ShopResponse", className = "RemoteEvent" },
    { name = "ShopRequest", className = "RemoteFunction" },

    -- RPC compatibility
    { name = "GetInventory", className = "RemoteFunction" },
}

local REMOTE_ALIASES = {
    Notification = "Notify",
    ObjectiveUpdated = "ObjectiveUpdate",
    ProgressionUpdated = "ProgressionUpdate",
    InventoryUpdated = "InventoryUpdate",
}

local created = {}

local function ensureRemote(parent, name, className)
    local existing = parent:FindFirstChild(name)
    if existing then
        if existing.ClassName == className then
            return existing
        end
        existing:Destroy()
    end

    local remote = Instance.new(className)
    remote.Name = name
    remote.Parent = parent
    return remote
end

function Remotes:init(replicatedStorage)
    local root = replicatedStorage or ReplicatedStorage
    table.clear(created)

    for _, def in ipairs(REMOTE_DEFS) do
        local remote = ensureRemote(root, def.name, def.className)
        created[def.name] = remote
        self[def.name] = remote
    end

    for alias, canonical in pairs(REMOTE_ALIASES) do
        self[alias] = created[canonical]
    end
end

function Remotes:ensure()
    self:init(ReplicatedStorage)
end

function Remotes.get(name)
    return created[name] or created[REMOTE_ALIASES[name]]
end

return Remotes
