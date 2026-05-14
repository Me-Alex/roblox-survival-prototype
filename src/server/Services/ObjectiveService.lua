local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ObjectiveService = {}

local progressByPlayer = {}
local context

local function cloneMap(source)
	local copy = {}

	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = cloneMap(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function ensureProgress(player)
	if not progressByPlayer[player] then
		progressByPlayer[player] = {
			Collected = {},
			Crafted = {},
			Built = {},
			Counters = {
				BeaconStage = 0,
				CachesSearched = 0,
				EnemiesDefeated = 0,
				NightsSurvived = 0,
				RegionsDiscovered = 0,
			},
			Completed = {},
		}
	end

	return progressByPlayer[player]
end

local function requirementProgress(values, requirements)
	local done = 0
	local total = 0

	for id, required in pairs(requirements) do
		total += required
		done += math.min(values[id] or 0, required)
	end

	return done, total
end

local function isObjectiveComplete(progress, objective)
	if objective.Kind == "Collect" then
		for itemId, required in pairs(objective.Requirements) do
			if (progress.Collected[itemId] or 0) < required then
				return false
			end
		end

		return true
	elseif objective.Kind == "Craft" then
		for itemId, required in pairs(objective.Requirements) do
			if (progress.Crafted[itemId] or 0) < required then
				return false
			end
		end

		return true
	elseif objective.Kind == "Build" then
		for modelName, required in pairs(objective.Requirements) do
			if (progress.Built[modelName] or 0) < required then
				return false
			end
		end

		return true
	elseif objective.Kind == "Counter" then
		return (progress.Counters[objective.Counter] or 0) >= objective.Required
	end

	return false
end

local function getProgressText(progress, objective)
	if objective.Kind == "Collect" then
		local done, total = requirementProgress(progress.Collected, objective.Requirements)
		return string.format("%d/%d supplies", done, total)
	elseif objective.Kind == "Craft" then
		local done, total = requirementProgress(progress.Crafted, objective.Requirements)
		return string.format("%d/%d crafted", done, total)
	elseif objective.Kind == "Build" then
		local done, total = requirementProgress(progress.Built, objective.Requirements)
		return string.format("%d/%d placed", done, total)
	elseif objective.Kind == "Counter" then
		return string.format("%d/%d", progress.Counters[objective.Counter] or 0, objective.Required)
	end

	return ""
end

local function grantReward(player, reward)
	if not reward or not context or not context.InventoryService then
		return
	end

	for itemId, amount in pairs(reward) do
		context.InventoryService.addItem(player, itemId, amount)
	end
end

local function evaluate(player)
	local progress = ensureProgress(player)
	local completedNow = {}

	for objectiveId, objective in pairs(Config.Objectives) do
		if not progress.Completed[objectiveId] and isObjectiveComplete(progress, objective) then
			progress.Completed[objectiveId] = true
			table.insert(completedNow, objective.DisplayName)
			grantReward(player, objective.Reward)
		end
	end

	for _, displayName in ipairs(completedNow) do
		Remotes.get("Notification"):FireClient(player, string.format("Objective complete: %s", displayName))
	end

	ObjectiveService.send(player)
end

function ObjectiveService.getSnapshot(player)
	local progress = ensureProgress(player)
	local objectives = {}

	for objectiveId, objective in pairs(Config.Objectives) do
		table.insert(objectives, {
			Id = objectiveId,
			DisplayName = objective.DisplayName,
			Description = objective.Description,
			Progress = getProgressText(progress, objective),
			Completed = progress.Completed[objectiveId] == true,
		})
	end

	table.sort(objectives, function(left, right)
		if left.Completed ~= right.Completed then
			return not left.Completed
		end

		return left.DisplayName < right.DisplayName
	end)

	return {
		Objectives = objectives,
		Counters = cloneMap(progress.Counters),
	}
end

function ObjectiveService.send(player)
	Remotes.get("ObjectiveUpdated"):FireClient(player, ObjectiveService.getSnapshot(player))
end

function ObjectiveService.recordCollected(player, itemId, amount)
	local progress = ensureProgress(player)
	progress.Collected[itemId] = (progress.Collected[itemId] or 0) + amount
	evaluate(player)
end

function ObjectiveService.recordCrafted(player, itemId, amount)
	local progress = ensureProgress(player)
	progress.Crafted[itemId] = (progress.Crafted[itemId] or 0) + (amount or 1)
	evaluate(player)
end

function ObjectiveService.recordBuilt(player, modelName)
	local progress = ensureProgress(player)
	progress.Built[modelName] = (progress.Built[modelName] or 0) + 1
	evaluate(player)
end

function ObjectiveService.recordEnemyDefeated(player)
	local progress = ensureProgress(player)
	progress.Counters.EnemiesDefeated = (progress.Counters.EnemiesDefeated or 0) + 1
	evaluate(player)
end

function ObjectiveService.recordCacheSearched(player)
	local progress = ensureProgress(player)
	progress.Counters.CachesSearched = (progress.Counters.CachesSearched or 0) + 1
	evaluate(player)
end

function ObjectiveService.recordRegionDiscovered(player)
	local progress = ensureProgress(player)
	progress.Counters.RegionsDiscovered = (progress.Counters.RegionsDiscovered or 0) + 1
	evaluate(player)
end

function ObjectiveService.recordBeaconStage(player, stage)
	local progress = ensureProgress(player)
	progress.Counters.BeaconStage = math.max(progress.Counters.BeaconStage or 0, stage)
	evaluate(player)
end

function ObjectiveService.recordNightSurvived(player)
	local progress = ensureProgress(player)
	progress.Counters.NightsSurvived = (progress.Counters.NightsSurvived or 0) + 1
	evaluate(player)
end

function ObjectiveService.init(newContext)
	context = newContext
end

function ObjectiveService.playerAdded(player)
	ensureProgress(player)
	ObjectiveService.send(player)
end

function ObjectiveService.playerRemoving(player)
	progressByPlayer[player] = nil
end

return ObjectiveService
