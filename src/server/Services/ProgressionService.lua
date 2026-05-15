local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ProgressionService = {}

local progressionByPlayer = {}
local context

-- Items awarded automatically when the player reaches each level.
-- Key = level number reached. Value = { itemId = amount, ... }
local LEVEL_REWARDS = {
	[2] = { CampfireKit = 1, Bandage = 2 },
	[3] = { Spear = 1, CookedBerries = 2 },
	[4] = { HideArmor = 1, SurvivalTonic = 1 },
	[5] = { IronSpear = 1, Antidote = 2 },
	[6] = { IronArmor = 1, SurvivalTonic = 2 },
}

local function markDirty(player)
	if context and context.PersistenceService then
		context.PersistenceService.markPlayerDirty(player)
	end
end

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

-- Grant level-up rewards through InventoryService and notify the client.
local function grantLevelRewards(player, level)
	local rewards = LEVEL_REWARDS[level]
	if not rewards then
		return
	end

	if not (context and context.InventoryService) then
		return
	end

	local rewardLines = {}

	for itemId, amount in pairs(rewards) do
		context.InventoryService.addItem(player, itemId, amount)

		local itemConfig = Config.Items[itemId]
		local displayName = itemConfig and itemConfig.DisplayName or itemId
		table.insert(rewardLines, string.format("+%d %s", amount, displayName))
		Remotes.get("Notification"):FireClient(
			player,
			string.format("+%d %s (level %d reward)", amount, displayName, level)
		)
	end

	-- Also fire the dedicated LevelUpReward event so the client can show a
	-- special popup banner separate from ordinary toast notifications.
	Remotes.get("LevelUpReward"):FireClient(player, {
		Level = level,
		Rewards = rewards,
		Lines = rewardLines,
	})
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

function ProgressionService.applySnapshot(player, snapshot)
	snapshot = type(snapshot) == "table" and snapshot or {}

	local progression = ensureProgression(player)
	progression.XP = math.max(0, math.floor(tonumber(snapshot.XP) or 0))
	progression.Level = getLevelForXP(progression.XP)
	ProgressionService.send(player)
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
		-- Announce the level-up with a clear, prominent message.
		local nextXP = getNextThreshold(progression.Level)
		local nextMsg = nextXP
			and string.format(" (%d XP to next level)", nextXP - progression.XP)
			or " (max level!)"

		Remotes.get("Notification"):FireClient(
			player,
			string.format(">> LEVEL %d REACHED! <<  %s", progression.Level, reason or "survival")
		)
		Remotes.get("Notification"):FireClient(player, string.format("Level %d%s", progression.Level, nextMsg))

		-- Grant the free reward items for this level.
		grantLevelRewards(player, progression.Level)
	end

	ProgressionService.send(player)
	markDirty(player)
end

function ProgressionService.init(newContext)
	context = newContext
end

function ProgressionService.playerAdded(player)
	ensureProgression(player)
	ProgressionService.send(player)
end

function ProgressionService.playerRemoving(player)
	progressionByPlayer[player] = nil
end

return ProgressionService
