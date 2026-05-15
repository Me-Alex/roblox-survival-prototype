local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local VitalsService = {}

local vitalsByPlayer = {}
local context
local random = Random.new(Config.World.Seed + 211)

-- How often (in ticks) we remind the player they are freezing / overheating.
local TEMP_WARN_INTERVAL_TICKS = 4
local tempWarnCounters = {}

local function markDirty(player)
	if context and context.PersistenceService then
		context.PersistenceService.markPlayerDirty(player)
	end
end

local function cloneMap(source)
	local copy = {}

	if type(source) ~= "table" then
		return copy
	end

	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = cloneMap(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function clampVital(value)
	return math.clamp(value, 0, Config.Vitals.Max)
end

local function getHumanoid(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getHealthPercent(player)
	local humanoid = getHumanoid(player)
	if humanoid and humanoid.MaxHealth > 0 then
		return (humanoid.Health / humanoid.MaxHealth) * 100
	end

	local vitals = vitalsByPlayer[player]
	return vitals and (vitals.Health or 100) or 100
end

local function sendVitals(player)
	local vitals = vitalsByPlayer[player]
	if vitals then
		local healthPercent = getHealthPercent(player)
		vitals.Health = healthPercent

		Remotes.get("VitalsUpdated"):FireClient(player, {
			Hunger = math.floor(vitals.Hunger + 0.5),
			Thirst = math.floor(vitals.Thirst + 0.5),
			Temperature = math.floor(vitals.Temperature + 0.5),
			Health = math.floor(healthPercent + 0.5),
			Statuses = vitals.Statuses or {},
		})
	end
end

local function ensureVitals(player)
	if not vitalsByPlayer[player] then
		vitalsByPlayer[player] = {
			Hunger = Config.Vitals.Max,
			Thirst = Config.Vitals.Max,
			Temperature = 72,
			Health = 100,
			Statuses = {},
		}
	end

	return vitalsByPlayer[player]
end

local function damage(player, amount)
	local humanoid = getHumanoid(player)
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(amount)
	end
end

function VitalsService.applyStatus(player, statusId, durationSeconds)
	local statusConfig = Config.StatusEffects[statusId]
	if not statusConfig then
		return
	end

	local vitals = ensureVitals(player)
	local existing = vitals.Statuses[statusId]

	if existing then
		existing.Remaining = math.max(existing.Remaining or 0, durationSeconds or statusConfig.DurationSeconds)
		sendVitals(player)
		return
	end

	vitals.Statuses[statusId] = {
		DisplayName = statusConfig.DisplayName,
		Remaining = durationSeconds or statusConfig.DurationSeconds,
	}

	Remotes.get("Notification"):FireClient(player, string.format("Status: %s", statusConfig.DisplayName))
	sendVitals(player)
	markDirty(player)
end

function VitalsService.removeStatus(player, statusId)
	local vitals = ensureVitals(player)
	vitals.Statuses[statusId] = nil
	sendVitals(player)
	markDirty(player)
end

function VitalsService.applyConsumable(player, consumable)
	local vitals = ensureVitals(player)

	if consumable.Hunger then
		vitals.Hunger = clampVital(vitals.Hunger + consumable.Hunger)
	end

	if consumable.Thirst then
		vitals.Thirst = clampVital(vitals.Thirst + consumable.Thirst)
	end

	if consumable.Temperature then
		vitals.Temperature = math.clamp(vitals.Temperature + consumable.Temperature, 0, 120)
	end

	if consumable.Health then
		local humanoid = getHumanoid(player)
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + consumable.Health)
		end
	end

	if consumable.RemoveStatuses then
		local removed = false

		for statusId in pairs(consumable.RemoveStatuses) do
			if vitals.Statuses[statusId] then
				vitals.Statuses[statusId] = nil
				removed = true
			end
		end

		if removed and context and context.ProgressionService then
			context.ProgressionService.addXP(player, Config.Progression.XP.StatusCured, "status cured")
		end
	end

	if consumable.ApplyStatuses then
		for statusId, durationSeconds in pairs(consumable.ApplyStatuses) do
			VitalsService.applyStatus(player, statusId, durationSeconds)
		end
	end

	if consumable.StatusChance then
		for statusId, chance in pairs(consumable.StatusChance) do
			if random:NextNumber() <= chance then
				VitalsService.applyStatus(player, statusId)
			end
		end
	end

	sendVitals(player)
	markDirty(player)
end

function VitalsService.getSnapshot(player)
	local vitals = ensureVitals(player)
	vitals.Health = getHealthPercent(player)

	return {
		Hunger = vitals.Hunger,
		Thirst = vitals.Thirst,
		Temperature = vitals.Temperature,
		Health = vitals.Health,
		Statuses = cloneMap(vitals.Statuses),
	}
end

function VitalsService.applySnapshot(player, snapshot)
	snapshot = type(snapshot) == "table" and snapshot or {}

	local vitals = ensureVitals(player)
	vitals.Hunger = clampVital(tonumber(snapshot.Hunger) or vitals.Hunger or Config.Vitals.Max)
	vitals.Thirst = clampVital(tonumber(snapshot.Thirst) or vitals.Thirst or Config.Vitals.Max)
	vitals.Temperature = math.clamp(tonumber(snapshot.Temperature) or vitals.Temperature or 72, 0, 120)
	vitals.Health = math.clamp(tonumber(snapshot.Health) or vitals.Health or 100, 1, 100)
	vitals.Statuses = cloneMap(snapshot.Statuses)
	vitals.LoadedSnapshot = true

	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.Health = math.clamp(humanoid.MaxHealth * (vitals.Health / 100), 1, humanoid.MaxHealth)
	end

	sendVitals(player)
end

local function updateStatuses(player, vitals)
	-- Build a list of statuses to expire so we never mutate the table mid-loop.
	local toRemove = {}

	for statusId, statusState in pairs(vitals.Statuses) do
		local statusConfig = Config.StatusEffects[statusId]
		if statusConfig then
			statusState.Remaining -= Config.Vitals.TickSeconds

			if statusConfig.DamagePerTick then
				damage(player, statusConfig.DamagePerTick)
			end

			if statusConfig.HealthPerTick then
				local humanoid = getHumanoid(player)
				if humanoid then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + statusConfig.HealthPerTick)
				end
			end

			if statusConfig.HungerLossPerTick then
				vitals.Hunger = clampVital(vitals.Hunger - statusConfig.HungerLossPerTick)
			end

			if statusConfig.ThirstLossPerTick then
				vitals.Thirst = clampVital(vitals.Thirst - statusConfig.ThirstLossPerTick)
			end

			if statusConfig.ThirstGainPerTick then
				vitals.Thirst = clampVital(vitals.Thirst + statusConfig.ThirstGainPerTick)
			end

			if statusConfig.TemperatureLossPerTick then
				vitals.Temperature = math.clamp(vitals.Temperature - statusConfig.TemperatureLossPerTick, 0, 120)
			end

			if statusConfig.TemperatureGainPerTick then
				vitals.Temperature = math.clamp(vitals.Temperature + statusConfig.TemperatureGainPerTick, 0, 120)
			end

			if statusState.Remaining <= 0 then
				table.insert(toRemove, statusId)
			end
		else
			table.insert(toRemove, statusId)
		end
	end

	for _, statusId in ipairs(toRemove) do
		vitals.Statuses[statusId] = nil
	end
end

-- Check if a player's character stamina is below the Exhausted threshold.
-- This reads the "Stamina" attribute that the client movement system writes,
-- or falls back gracefully if it hasn't been set yet.
local function checkExhaustion(player, vitals)
	local character = player.Character
	if not character then
		return
	end

	local stamina = character:GetAttribute("Stamina")
	if type(stamina) ~= "number" then
		return
	end

	local exhaustedThreshold = Config.Movement and Config.Movement.ExhaustedThreshold or 10

	if stamina <= exhaustedThreshold then
		-- Apply Exhausted status only if not already active.
		if not vitals.Statuses["Exhausted"] then
			VitalsService.applyStatus(player, "Exhausted", Config.StatusEffects.Exhausted and Config.StatusEffects.Exhausted.DurationSeconds or 12)
		end
	else
		-- Remove the Exhausted status once stamina recovers.
		if vitals.Statuses["Exhausted"] then
			vitals.Statuses["Exhausted"] = nil
		end
	end
end

local function updatePlayer(player)
	local vitals = ensureVitals(player)
	local world = context and context.WorldService
	local targetTemperature = world and world.getAmbientTemperature(player) or 72
	local weather = world and world.getCurrentWeatherConfig() or nil
	local hungerMultiplier = weather and weather.HungerMultiplier or 1
	local thirstMultiplier = weather and weather.ThirstMultiplier or 1
	local protectedFromWeather = world and world.isProtectedFromWeather and world.isProtectedFromWeather(player)

	vitals.Hunger = clampVital(vitals.Hunger - (Config.Vitals.HungerLoss * hungerMultiplier))
	vitals.Thirst = clampVital(vitals.Thirst - (Config.Vitals.ThirstLoss * thirstMultiplier))
	vitals.Temperature += (targetTemperature - vitals.Temperature) * Config.Vitals.TemperatureDrift
	vitals.Temperature = math.clamp(vitals.Temperature, 0, 120)

	if weather and weather.ExposureStatus then
		if protectedFromWeather then
			vitals.Statuses[weather.ExposureStatus] = nil
		elseif random:NextNumber() <= (weather.ExposureChance or 0) then
			VitalsService.applyStatus(player, weather.ExposureStatus)
		end
	end

	if vitals.Hunger <= 0 then
		damage(player, Config.Vitals.StarvingDamage)
	end

	if vitals.Thirst <= 0 then
		damage(player, Config.Vitals.DehydratedDamage)
	end

	-- Temperature danger with periodic reminders so the player knows what is killing them.
	local counter = tempWarnCounters[player] or 0
	tempWarnCounters[player] = counter + 1

	if vitals.Temperature <= Config.Vitals.ColdThreshold then
		damage(player, Config.Vitals.ColdDamage)
		if tempWarnCounters[player] >= TEMP_WARN_INTERVAL_TICKS then
			tempWarnCounters[player] = 0
			Remotes.get("Notification"):FireClient(player, "You are freezing! Find warmth.")
		end
	elseif vitals.Temperature >= Config.Vitals.HotThreshold then
		damage(player, Config.Vitals.HeatDamage)
		if tempWarnCounters[player] >= TEMP_WARN_INTERVAL_TICKS then
			tempWarnCounters[player] = 0
			Remotes.get("Notification"):FireClient(player, "You are overheating! Find shade or water.")
		end
	else
		-- Reset counter when temperature is safe so warnings restart promptly.
		tempWarnCounters[player] = 0
	end

	-- Exhaustion check: applies the Exhausted status when stamina is depleted.
	checkExhaustion(player, vitals)

	updateStatuses(player, vitals)
	vitals.Health = getHealthPercent(player)

	sendVitals(player)
end

function VitalsService.init(newContext)
	context = newContext

	task.spawn(function()
		while true do
			-- Snapshot players list to avoid issues if a player leaves mid-loop.
			local players = Players:GetPlayers()
			for _, player in ipairs(players) do
				if player.Parent then
					updatePlayer(player)
				end
			end

			task.wait(Config.Vitals.TickSeconds)
		end
	end)
end

function VitalsService.playerAdded(player)
	ensureVitals(player)
	sendVitals(player)
	tempWarnCounters[player] = 0

	player.CharacterAdded:Connect(function()
		task.defer(function()
			local vitals = ensureVitals(player)
			local humanoid = getHumanoid(player)

			if vitals.LoadedSnapshot then
				if humanoid then
					humanoid.Health = math.clamp(humanoid.MaxHealth * ((vitals.Health or 100) / 100), 1, humanoid.MaxHealth)
				end
			else
				vitals.Hunger = math.max(vitals.Hunger, 35)
				vitals.Thirst = math.max(vitals.Thirst, 35)
				vitals.Temperature = 72
			end

			sendVitals(player)
		end)
	end)
end

function VitalsService.playerRemoving(player)
	vitalsByPlayer[player] = nil
	tempWarnCounters[player] = nil
end

return VitalsService
