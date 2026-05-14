local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ProgressionService = {}

local progressionByPlayer = {}

local function getLevelForXP(xp)
	local level = 1

	for index, threshold in ipairs(Config.Progression.LevelThresholds) do
		if xp >= threshold then
			level = index
		end
	end

	return level
end

local function getNextThreshold(level)
	return Config.Progression.LevelThresholds[level + 1]
end

local function ensureProgression(player)
	if not progressionByPlayer[player] then
		progressionByPlayer[player] = {
			XP = 0,
			Level = 1,
		}
	end

	return progressionByPlayer[player]
end

function ProgressionService.getLevel(player)
	return ensureProgression(player).Level
end

function ProgressionService.getSnapshot(player)
	local progression = ensureProgression(player)

	return {
		XP = progression.XP,
		Level = progression.Level,
		NextLevelXP = getNextThreshold(progression.Level),
	}
end

function ProgressionService.send(player)
	Remotes.get("ProgressionUpdated"):FireClient(player, ProgressionService.getSnapshot(player))
end

function ProgressionService.addXP(player, amount, reason)
	if not amount or amount <= 0 then
		return
	end

	local progression = ensureProgression(player)
	local oldLevel = progression.Level

	progression.XP += amount
	progression.Level = getLevelForXP(progression.XP)

	if progression.Level > oldLevel then
		Remotes.get("Notification"):FireClient(
			player,
			string.format("Level %d reached: %s", progression.Level, reason or "survival progress")
		)
	end

	ProgressionService.send(player)
end

function ProgressionService.playerAdded(player)
	ensureProgression(player)
	ProgressionService.send(player)
end

function ProgressionService.playerRemoving(player)
	progressionByPlayer[player] = nil
end

return ProgressionService
