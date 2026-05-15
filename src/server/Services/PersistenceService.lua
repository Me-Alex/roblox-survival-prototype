local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PersistenceService = {}

local DATASTORE_NAME = "SurvivalPrototypeSaves"
local PLAYER_VERSION = 1
local WORLD_VERSION = 1
local WORLD_KEY = "world/main/v1"
local AUTOSAVE_SECONDS = 60
local STARTER_LOADOUT = {
	StoneAxe = 1,
}

local context
local store
local dataStoreUnavailable = false
local worldLoaded = false
local worldDirty = false
local worldSaveBlocked = false
local worldSaveInFlight = false
local lastGoodWorldSnapshot
local loadedPlayersByUserId = {}
local loadingPlayersByUserId = {}
local playerDirtyByUserId = {}
local playerSaveBlockedByUserId = {}
local playerSaveInFlightByUserId = {}
local lastGoodPlayerSnapshotsByUserId = {}
local loadWarningSentByUserId = {}
local saveWarningSentByUserId = {}
local studioMemoryDataByKey = {}
local usingStudioMemoryStore = false

local function cloneTable(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}

	for key, value in pairs(source) do
		copy[key] = cloneTable(value)
	end

	return copy
end

local function useStudioMemoryStore(reason)
	if usingStudioMemoryStore then
		return
	end

	usingStudioMemoryStore = true
	dataStoreUnavailable = false

	store = {
		GetAsync = function(_, key)
			return cloneTable(studioMemoryDataByKey[key])
		end,
		SetAsync = function(_, key, value)
			studioMemoryDataByKey[key] = cloneTable(value)
		end,
	}

	if reason then
		warn("[PersistenceService]", reason)
	end
end

local function isPublishGateError(errorMessage)
	if type(errorMessage) ~= "string" then
		return false
	end

	local lower = string.lower(errorMessage)
	return string.find(lower, "publish", 1, true) ~= nil
end

local function sanitizeForDataStore(value)
	local valueType = type(value)

	if valueType == "string" or valueType == "number" or valueType == "boolean" then
		return value
	end

	if valueType ~= "table" then
		return nil
	end

	local copy = {}

	for key, childValue in pairs(value) do
		local keyType = type(key)
		if keyType == "string" or keyType == "number" then
			local sanitized = sanitizeForDataStore(childValue)
			if sanitized ~= nil then
				copy[key] = sanitized
			end
		end
	end

	return copy
end

local function callServiceMethod(service, methodName, ...)
	if not service then
		return false, nil
	end

	local method = service[methodName]
	if type(method) ~= "function" then
		return false, nil
	end

	local okInfo, arity = pcall(function()
		return select(1, debug.info(method, "a"))
	end)

	if okInfo and type(arity) == "number" then
		local passedCount = select("#", ...)
		if arity >= passedCount + 1 then
			return pcall(method, service, ...)
		end
		return pcall(method, ...)
	end

	local ok, result = pcall(method, service, ...)
	if ok then
		return true, result
	end
	return pcall(method, ...)
end

local function playerKey(player)
	return string.format("player/%d/v%d", player.UserId, PLAYER_VERSION)
end

local function notify(player, message)
	if player and player.Parent then
		Remotes.get("Notification"):FireClient(player, message)
	end
end

local function sendSaveStatus(player, text, kind)
	if player and player.Parent then
		Remotes.get("SaveStatusUpdated"):FireClient(player, {
			Text = text,
			Kind = kind or "info",
			Timestamp = os.time(),
		})
	end
end

local function readKey(key)
	if dataStoreUnavailable or not store then
		return false, "DataStore is unavailable"
	end

	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)

	if not ok and RunService:IsStudio() and isPublishGateError(result) then
		useStudioMemoryStore("Using temporary in-memory saves in Studio because DataStore requires a published place.")
		return pcall(function()
			return store:GetAsync(key)
		end)
	end

	return ok, result
end

local function writeKey(key, value)
	if dataStoreUnavailable or not store then
		return false, "DataStore is unavailable"
	end

	local sanitized = sanitizeForDataStore(value)

	local ok, result = pcall(function()
		store:SetAsync(key, sanitized)
	end)

	if not ok and RunService:IsStudio() and isPublishGateError(result) then
		useStudioMemoryStore("Using temporary in-memory saves in Studio because DataStore requires a published place.")
		return pcall(function()
			store:SetAsync(key, sanitized)
		end)
	end

	return ok, result
end

local function buildPlayerSnapshot(player)
	local snapshot = {
		Version = PLAYER_VERSION,
		SavedAt = os.time(),
	}

	if context.InventoryService and context.InventoryService.getSnapshot then
		local ok, value = callServiceMethod(context.InventoryService, "getSnapshot", player)
		if ok then
			snapshot.Inventory = value
		end
	end

	if context.VitalsService and context.VitalsService.getSnapshot then
		local ok, value = callServiceMethod(context.VitalsService, "getSnapshot", player)
		if ok then
			snapshot.Vitals = value
		end
	end

	if context.ProgressionService and context.ProgressionService.getSnapshot then
		local ok, value = callServiceMethod(context.ProgressionService, "getSnapshot", player)
		if ok then
			snapshot.Progression = value
		end
	end

	if context.ObjectiveService and context.ObjectiveService.getSnapshot then
		local ok, value = callServiceMethod(context.ObjectiveService, "getSnapshot", player)
		if ok then
			snapshot.Objectives = value
		end
	end

	if context.WorldService and context.WorldService.getSnapshot then
		local ok, value = callServiceMethod(context.WorldService, "getSnapshot", player)
		if ok then
			snapshot.World = value
		end
	end

	return snapshot
end

local function applyStarterLoadout(player)
	if not context or not context.InventoryService then
		return
	end

	local inventory = context.InventoryService

	for itemId, amount in pairs(STARTER_LOADOUT) do
		if amount > 0 and not inventory:hasItem(player, itemId, 1) then
			inventory:addItem(player, itemId, amount)
		end
	end
end

local function applyPlayerSnapshot(player, snapshot)
	if type(snapshot) ~= "table" then
		return
	end

	if context.InventoryService and context.InventoryService.applySnapshot then
		callServiceMethod(context.InventoryService, "applySnapshot", player, snapshot.Inventory or {})
	end

	if context.VitalsService and context.VitalsService.applySnapshot then
		callServiceMethod(context.VitalsService, "applySnapshot", player, snapshot.Vitals or {})
	end

	if context.ProgressionService and context.ProgressionService.applySnapshot then
		callServiceMethod(context.ProgressionService, "applySnapshot", player, snapshot.Progression or {})
	end

	if context.ObjectiveService and context.ObjectiveService.applySnapshot then
		callServiceMethod(context.ObjectiveService, "applySnapshot", player, snapshot.Objectives or {})
	end

	if context.WorldService and context.WorldService.applySnapshot then
		callServiceMethod(context.WorldService, "applySnapshot", player, snapshot.World or {})
	end

	if context.ItemToolService then
		task.defer(function()
			callServiceMethod(context.ItemToolService, "syncPlayerTools", player)
		end)
	end
end

function PersistenceService.markPlayerDirty(player)
	if player then
		playerDirtyByUserId[player.UserId] = true
	end
end

function PersistenceService.markWorldDirty()
	worldDirty = true
end

function PersistenceService.loadWorld()
	if worldLoaded then
		return true
	end

	worldLoaded = true

	local ok, result = readKey(WORLD_KEY)
	if not ok then
		worldSaveBlocked = true
		warn("[PersistenceService] World load failed; shared world saves are blocked for this server:", result)
		return false
	end

	if type(result) ~= "table" then
		worldDirty = false
		worldSaveBlocked = false
		return true
	end

	if result.Version ~= WORLD_VERSION then
		warn("[PersistenceService] Ignoring unsupported world snapshot version:", result.Version)
		worldDirty = false
		worldSaveBlocked = false
		return false
	end

	lastGoodWorldSnapshot = cloneTable(result)

	if context.CraftingService and context.CraftingService.applyWorldSnapshot then
		callServiceMethod(context.CraftingService, "applyWorldSnapshot", result)
	end

	worldDirty = false
	worldSaveBlocked = false
	return true
end

function PersistenceService.saveWorld()
	if worldSaveBlocked or worldSaveInFlight then
		return false
	end

	if not worldDirty then
		return true
	end

	if not context.CraftingService or not context.CraftingService.getWorldSnapshot then
		return false
	end

	worldSaveInFlight = true

	local okSnapshot, snapshot = callServiceMethod(context.CraftingService, "getWorldSnapshot")
	if not okSnapshot or type(snapshot) ~= "table" then
		worldSaveInFlight = false
		return false
	end
	snapshot.Version = WORLD_VERSION
	snapshot.SavedAt = os.time()

	local ok, err = writeKey(WORLD_KEY, snapshot)
	worldSaveInFlight = false

	if ok then
		lastGoodWorldSnapshot = cloneTable(snapshot)
		worldDirty = false
		return true
	end

	warn("[PersistenceService] World save failed; keeping last successful snapshot in memory:", err)
	worldDirty = true
	return false
end

function PersistenceService.loadPlayer(player)
	if loadedPlayersByUserId[player.UserId] or loadingPlayersByUserId[player.UserId] then
		return true
	end

	loadingPlayersByUserId[player.UserId] = true
	local ok, result = readKey(playerKey(player))
	loadingPlayersByUserId[player.UserId] = nil

	if not ok then
		playerSaveBlockedByUserId[player.UserId] = true
		if not loadWarningSentByUserId[player.UserId] then
			loadWarningSentByUserId[player.UserId] = true
			notify(player, "Save load unavailable; this session will use safe defaults.")
		end
		sendSaveStatus(player, "Save load unavailable.", "warning")
		applyStarterLoadout(player)
		warn("[PersistenceService] Player load failed for", player.UserId, result)
		return false
	end

	if not player.Parent then
		return false
	end

	loadedPlayersByUserId[player.UserId] = true
	playerSaveBlockedByUserId[player.UserId] = false

	if type(result) ~= "table" then
		applyStarterLoadout(player)
		playerDirtyByUserId[player.UserId] = true
		sendSaveStatus(player, "New save profile created.", "info")
		return true
	end

	if result.Version ~= PLAYER_VERSION then
		notify(player, "Old save version ignored; starting from safe defaults.")
		applyStarterLoadout(player)
		playerDirtyByUserId[player.UserId] = true
		sendSaveStatus(player, "Old save ignored, new profile will be written.", "warning")
		return false
	end

	lastGoodPlayerSnapshotsByUserId[player.UserId] = cloneTable(result)
	applyPlayerSnapshot(player, result)
	playerDirtyByUserId[player.UserId] = false
	sendSaveStatus(player, "Save loaded.", "ok")
	return true
end

function PersistenceService.savePlayer(player, force)
	if not player then
		return false
	end

	local userId = player.UserId
	if loadingPlayersByUserId[userId] or playerSaveBlockedByUserId[userId] or playerSaveInFlightByUserId[userId] then
		return false
	end

	if not force and not playerDirtyByUserId[userId] then
		return true
	end

	playerSaveInFlightByUserId[userId] = true
	sendSaveStatus(player, "Saving...", "pending")
	local snapshot = buildPlayerSnapshot(player)
	local ok, err = writeKey(playerKey(player), snapshot)
	playerSaveInFlightByUserId[userId] = false

	if ok then
		lastGoodPlayerSnapshotsByUserId[userId] = cloneTable(snapshot)
		playerDirtyByUserId[userId] = false
		saveWarningSentByUserId[userId] = nil
		sendSaveStatus(player, "Saved.", "ok")
		return true
	end

	playerDirtyByUserId[userId] = true
	if not saveWarningSentByUserId[userId] then
		saveWarningSentByUserId[userId] = true
		notify(player, "Save retry pending; your session state is still in memory.")
	end
	sendSaveStatus(player, "Save failed, retrying...", "warning")
	warn("[PersistenceService] Player save failed for", userId, err)
	return false
end

function PersistenceService.init(newContext)
	context = newContext

	if RunService:IsStudio() and game.GameId == 0 then
		useStudioMemoryStore("Using temporary in-memory saves in Studio (place is unpublished).")
	else
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(DATASTORE_NAME)
		end)

		if ok then
			store = result
		elseif RunService:IsStudio() and isPublishGateError(result) then
			useStudioMemoryStore("Using temporary in-memory saves in Studio because DataStore requires a published place.")
		else
			dataStoreUnavailable = true
			warn("[PersistenceService] DataStore unavailable:", result)
		end
	end

	PersistenceService.loadWorld()

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)

			if worldSaveBlocked then
				PersistenceService.loadWorld()
			end

			for _, player in ipairs(Players:GetPlayers()) do
				if playerSaveBlockedByUserId[player.UserId] then
					PersistenceService.loadPlayer(player)
				else
					PersistenceService.savePlayer(player)
				end
			end

			PersistenceService.saveWorld()
		end
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			PersistenceService.savePlayer(player, true)
		end

		PersistenceService.saveWorld()
		task.wait(1)
	end)
end

function PersistenceService.playerAdded(player)
	sendSaveStatus(player, "Loading save...", "pending")
	task.spawn(function()
		PersistenceService.loadPlayer(player)
	end)
end

function PersistenceService.playerRemoving(player)
	PersistenceService.savePlayer(player, true)

	local userId = player.UserId
	loadedPlayersByUserId[userId] = nil
	loadingPlayersByUserId[userId] = nil
	playerDirtyByUserId[userId] = nil
	playerSaveBlockedByUserId[userId] = nil
	playerSaveInFlightByUserId[userId] = nil
	loadWarningSentByUserId[userId] = nil
	saveWarningSentByUserId[userId] = nil
end

return PersistenceService
