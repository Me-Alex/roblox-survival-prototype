local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "SurvivalRemotes"

local DEFINITIONS = {
	InventoryUpdated = "RemoteEvent",
	VitalsUpdated = "RemoteEvent",
	WorldStateUpdated = "RemoteEvent",
	ObjectiveUpdated = "RemoteEvent",
	ProgressionUpdated = "RemoteEvent",
	SaveStatusUpdated = "RemoteEvent",
	Notification = "RemoteEvent",
	ResourcePopup = "RemoteEvent",
	HarvestAnimation = "RemoteEvent",
	ShopOpened = "RemoteEvent",
	-- New: fires when the player levels up, carries item reward table
	LevelUpReward = "RemoteEvent",
	-- New: fires to show a floating damage number on the client
	EnemyDamaged = "RemoteEvent",
	CraftRequest = "RemoteFunction",
	ConsumeRequest = "RemoteFunction",
	BuildRequest = "RemoteFunction",
	EquipRequest = "RemoteFunction",
	AttackRequest = "RemoteFunction",
	ShopRequest = "RemoteFunction",
	GetInventory = "RemoteFunction",
}

local Remotes = {}

local function getFolder()
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)

	if not folder and RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	if not folder then
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end

	return folder
end

function Remotes.ensure()
	assert(RunService:IsServer(), "Remotes.ensure can only run on the server")

	local folder = getFolder()

	for name, className in pairs(DEFINITIONS) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end

	return folder
end

function Remotes.get(name)
	local className = DEFINITIONS[name]
	assert(className, string.format("Unknown survival remote: %s", tostring(name)))

	local folder = getFolder()
	return folder:WaitForChild(name)
end

return Remotes
