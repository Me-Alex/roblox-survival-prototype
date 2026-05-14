local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local VitalsService = {}

local vitalsByPlayer = {}
local context
local random = Random.new(Config.World.Seed + 211)

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

local function sendVitals(player)
	local vitals = vitalsByPlayer[player]
	if vitals then
		local humanoid = getHumanoid(player)
		local healthPercent = 100

		if humanoid and humanoid.MaxHealth > 0 then
			healthPercent = (humanoid.Health / humanoid.MaxHealth) * 100
		end

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
	vitals.Statuses[statusId] = {
		DisplayName = statusConfig.DisplayName,
		Remaining = durationSeconds or statusConfig.DurationSeconds,
	}

	Remotes.get("Notification"):FireClient(player, string.format("Status: %s", statusConfig.DisplayName))
	sendVitals(player)
end

function VitalsService.removeStatus(player, statusId)
	local vitals = ensureVitals(player)
	vitals.Statuses[statusId] = nil
	sendVitals(player)
end

function VitalsService.applyConsumable(player, consumable)
	local vitals = ensureVitals(player)

	if consumable.Hunger then
		vitals.Hunger = clampVital(vitals.Hunger + consumable.Hunger)
	end

	if consumable.Thirst then
		vitals.Thirst = clampVital(vitals.Thirst + consumable.Thirst)
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

	if consumable.StatusChance then
		for statusId, chance in pairs(consumable.StatusChance) do
			if random:NextNumber() <= chance then
				VitalsService.applyStatus(player, statusId)
			end
		end
	end

	sendVitals(player)
end

local function updateStatuses(player, vitals)
	for statusId, statusState in pairs(vitals.Statuses) do
		local statusConfig = Config.StatusEffects[statusId]
		if statusConfig then
			statusState.Remaining -= Config.Vitals.TickSeconds

			if statusConfig.DamagePerTick then
				damage(player, statusConfig.DamagePerTick)
			end

			if statusConfig.HungerLossPerTick then
				vitals.Hunger = clampVital(vitals.Hunger - statusConfig.HungerLossPerTick)
			end

			if statusConfig.ThirstLossPerTick then
				vitals.Thirst = clampVital(vitals.Thirst - statusConfig.ThirstLossPerTick)
			end

			if statusState.Remaining <= 0 then
				vitals.Statuses[statusId] = nil
			end
		else
			vitals.Statuses[statusId] = nil
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

	vitals.Hunger = clampVital(vitals.Hunger - (Config.Vitals.HungerLoss * hungerMultiplier))
	vitals.Thirst = clampVital(vitals.Thirst - (Config.Vitals.ThirstLoss * thirstMultiplier))
	vitals.Temperature += (targetTemperature - vitals.Temperature) * Config.Vitals.TemperatureDrift
	vitals.Temperature = math.clamp(vitals.Temperature, 0, 120)

	if vitals.Hunger <= 0 then
		damage(player, Config.Vitals.StarvingDamage)
	end

	if vitals.Thirst <= 0 then
		damage(player, Config.Vitals.DehydratedDamage)
	end

	if vitals.Temperature <= Config.Vitals.ColdThreshold then
		damage(player, Config.Vitals.ColdDamage)
	elseif vitals.Temperature >= Config.Vitals.HotThreshold then
		damage(player, Config.Vitals.HeatDamage)
	end

	updateStatuses(player, vitals)

	sendVitals(player)
end

function VitalsService.init(newContext)
	context = newContext

	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				updatePlayer(player)
			end

			task.wait(Config.Vitals.TickSeconds)
		end
	end)
end

function VitalsService.playerAdded(player)
	ensureVitals(player)
	sendVitals(player)

	player.CharacterAdded:Connect(function()
		local vitals = ensureVitals(player)
		vitals.Hunger = math.max(vitals.Hunger, 35)
		vitals.Thirst = math.max(vitals.Thirst, 35)
		vitals.Temperature = 72
		sendVitals(player)
	end)
end

function VitalsService.playerRemoving(player)
	vitalsByPlayer[player] = nil
end

return VitalsService
