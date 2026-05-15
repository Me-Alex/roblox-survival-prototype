-- Remotes.lua  (Milestone 6a — added SleepRequest + SleepResponse)
-- All RemoteEvents live here so every script has one place to look.
-- Server creates them; clients WaitForChild each one.

local Remotes = {}

local REMOTE_NAMES = {
    -- Vitals
    "VitalsUpdate",
    -- Inventory
    "InventoryUpdate",
    "UseItem",
    -- Crafting
    "CraftRequest",
    -- Day / night
    "DayNightUpdate",
    -- Notifications (toasts)
    "Notify",
    -- Combat
    "AttackRequest",
    -- Progression
    "ProgressionUpdate",
    -- Objectives
    "ObjectiveUpdate",
    -- Death / respawn
    "RespawnRequest",
    -- Sleep (NEW in Milestone 6a)
    "SleepRequest",    -- client → server: player wants to sleep at a bedroll
    "SleepResponse",   -- server → client: { success, message }
}

function Remotes:init(parent)
    -- Called once on the server to create all RemoteEvents under ReplicatedStorage.
    for _, name in ipairs(REMOTE_NAMES) do
        if not parent:FindFirstChild(name) then
            local re = Instance.new("RemoteEvent")
            re.Name   = name
            re.Parent = parent
        end
    end
end

function Remotes:get(parent, name)
    -- Clients call this to get a remote by name.
    return parent:WaitForChild(name, 10)
end

return Remotes
