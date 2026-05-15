local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ItemToolService = {}

local ITEM_ID_ATTRIBUTE = "SurvivalItemId"
local ITEM_TOOL_ATTRIBUTE = "SurvivalItemTool"
local ACTION_COOLDOWN_SECONDS = 0.35

local context
local lastActionByPlayer = {}
local activeAnimations = {}

local ITEM_VISUALS = {
	Wood = { Shape = "Cylinder", Size = Vector3.new(3.2, 0.65, 0.65), Color = Color3.fromRGB(101, 67, 42), Material = Enum.Material.Wood },
	Stone = { Shape = "Ball", Size = Vector3.new(1.5, 1.15, 1.35), Color = Color3.fromRGB(112, 116, 118), Material = Enum.Material.Slate },
	Fiber = { Shape = "Block", Size = Vector3.new(0.5, 2.5, 0.35), Color = Color3.fromRGB(92, 142, 76), Material = Enum.Material.Grass },
	Hide = { Shape = "Block", Size = Vector3.new(2.2, 0.2, 1.6), Color = Color3.fromRGB(126, 85, 54), Material = Enum.Material.Fabric },
	IronOre = { Shape = "Ball", Size = Vector3.new(1.6, 1.2, 1.4), Color = Color3.fromRGB(114, 87, 75), Material = Enum.Material.Metal },
	IronIngot = { Shape = "Block", Size = Vector3.new(2.2, 0.55, 0.9), Color = Color3.fromRGB(154, 157, 153), Material = Enum.Material.Metal },
	AncientScrap = { Shape = "Block", Size = Vector3.new(1.9, 0.35, 1.2), Color = Color3.fromRGB(82, 103, 103), Material = Enum.Material.CorrodedMetal },
	Leaves = { Shape = "Block", Size = Vector3.new(1.3, 0.2, 0.9), Color = Color3.fromRGB(70, 139, 59), Material = Enum.Material.Grass },
	MedicinalHerb = { Shape = "Block", Size = Vector3.new(0.55, 2.1, 0.35), Color = Color3.fromRGB(78, 149, 83), Material = Enum.Material.Grass },
	RawMeat = { Shape = "Ball", Size = Vector3.new(1.4, 0.9, 1.1), Color = Color3.fromRGB(153, 62, 64), Material = Enum.Material.SmoothPlastic },
	Berries = { Shape = "Ball", Size = Vector3.new(1.15, 1.15, 1.15), Color = Color3.fromRGB(166, 43, 70), Material = Enum.Material.SmoothPlastic },
	CookedBerries = { Shape = "Ball", Size = Vector3.new(1.15, 1.15, 1.15), Color = Color3.fromRGB(119, 47, 72), Material = Enum.Material.SmoothPlastic },
	CookedMeat = { Shape = "Ball", Size = Vector3.new(1.4, 0.9, 1.1), Color = Color3.fromRGB(118, 70, 41), Material = Enum.Material.SmoothPlastic },
	Mushrooms = { Shape = "Ball", Size = Vector3.new(1, 0.8, 1), Color = Color3.fromRGB(157, 128, 86), Material = Enum.Material.SmoothPlastic },
	MushroomStew = { Shape = "Ball", Size = Vector3.new(1.25, 0.9, 1.25), Color = Color3.fromRGB(127, 91, 55), Material = Enum.Material.SmoothPlastic },
	Bandage = { Shape = "Block", Size = Vector3.new(1.7, 0.45, 0.85), Color = Color3.fromRGB(226, 221, 196), Material = Enum.Material.Fabric },
	Antidote = { Shape = "Ball", Size = Vector3.new(0.95, 0.95, 0.95), Color = Color3.fromRGB(91, 194, 122), Material = Enum.Material.Glass },
	SurvivalTonic = { Shape = "Ball", Size = Vector3.new(1.05, 1.05, 1.05), Color = Color3.fromRGB(85, 176, 204), Material = Enum.Material.Glass },
	StoneAxe = { Shape = "Cylinder", Size = Vector3.new(5.2, 0.36, 0.36), Color = Color3.fromRGB(101, 64, 38), Material = Enum.Material.Wood, Kind = "Axe" },
	Pickaxe = { Shape = "Cylinder", Size = Vector3.new(5.6, 0.34, 0.34), Color = Color3.fromRGB(96, 65, 41), Material = Enum.Material.Wood, Kind = "Pickaxe" },
	Spear = { Shape = "Cylinder", Size = Vector3.new(6.8, 0.3, 0.3), Color = Color3.fromRGB(112, 76, 45), Material = Enum.Material.Wood, Kind = "Spear" },
	IronSpear = { Shape = "Cylinder", Size = Vector3.new(7.1, 0.32, 0.32), Color = Color3.fromRGB(126, 91, 58), Material = Enum.Material.Wood, Kind = "IronSpear" },
	HideArmor = { Shape = "Block", Size = Vector3.new(2.5, 0.3, 2.2), Color = Color3.fromRGB(108, 70, 46), Material = Enum.Material.Fabric },
	IronArmor = { Shape = "Block", Size = Vector3.new(2.5, 0.35, 2.2), Color = Color3.fromRGB(137, 141, 142), Material = Enum.Material.Metal },
	CampfireKit = { Shape = "Block", Size = Vector3.new(1.8, 0.7, 1.8), Color = Color3.fromRGB(115, 79, 47), Material = Enum.Material.WoodPlanks, Kind = "Kit" },
	TorchStandKit = { Shape = "Block", Size = Vector3.new(1.5, 0.55, 1.5), Color = Color3.fromRGB(94, 64, 39), Material = Enum.Material.WoodPlanks, Kind = "TorchKit" },
	ShelterKit = { Shape = "Block", Size = Vector3.new(2.2, 0.5, 1.5), Color = Color3.fromRGB(120, 82, 52), Material = Enum.Material.WoodPlanks, Kind = "Kit" },
	WoodenWallKit = { Shape = "Block", Size = Vector3.new(2.4, 0.45, 1.2), Color = Color3.fromRGB(112, 74, 43), Material = Enum.Material.WoodPlanks, Kind = "WallKit" },
	WoodenDoorKit = { Shape = "Block", Size = Vector3.new(1.7, 0.5, 1.2), Color = Color3.fromRGB(103, 68, 40), Material = Enum.Material.WoodPlanks, Kind = "Kit" },
	WoodenStairsKit = { Shape = "Block", Size = Vector3.new(2, 0.5, 1.4), Color = Color3.fromRGB(111, 72, 42), Material = Enum.Material.WoodPlanks, Kind = "StairKit" },
	StorageChestKit = { Shape = "Block", Size = Vector3.new(1.8, 0.75, 1.1), Color = Color3.fromRGB(92, 58, 34), Material = Enum.Material.WoodPlanks, Kind = "ChestKit" },
	WatchtowerKit = { Shape = "Block", Size = Vector3.new(2.3, 0.65, 1.5), Color = Color3.fromRGB(92, 62, 38), Material = Enum.Material.WoodPlanks, Kind = "TowerKit" },
	RainCollectorKit = { Shape = "Block", Size = Vector3.new(1.8, 0.55, 1.8), Color = Color3.fromRGB(73, 137, 157), Material = Enum.Material.Glass, Kind = "Kit" },
	WorkbenchKit = { Shape = "Block", Size = Vector3.new(2.1, 0.55, 1.35), Color = Color3.fromRGB(101, 65, 39), Material = Enum.Material.WoodPlanks, Kind = "Kit" },
	ForgeKit = { Shape = "Block", Size = Vector3.new(1.9, 0.9, 1.5), Color = Color3.fromRGB(88, 87, 83), Material = Enum.Material.Slate, Kind = "Kit" },
	SpikeTrapKit = { Shape = "Block", Size = Vector3.new(2, 0.45, 2), Color = Color3.fromRGB(92, 68, 44), Material = Enum.Material.WoodPlanks, Kind = "TrapKit" },
	SignalBeaconKit = { Shape = "Block", Size = Vector3.new(1.7, 0.8, 1.7), Color = Color3.fromRGB(103, 116, 119), Material = Enum.Material.Metal, Kind = "BeaconKit" },
}

local DEFAULT_GRIPS = {
	StoneAxe = CFrame.new(-1.95, -0.2, -0.22) * CFrame.Angles(math.rad(-8), math.rad(94), math.rad(8)),
	Pickaxe = CFrame.new(-2.05, -0.2, -0.18) * CFrame.Angles(math.rad(-10), math.rad(96), math.rad(6)),
	Spear = CFrame.new(0, -0.1, -0.55) * CFrame.Angles(0, math.rad(90), math.rad(86)),
	IronSpear = CFrame.new(0, -0.1, -0.55) * CFrame.Angles(0, math.rad(90), math.rad(86)),
}

local ATTACK_GRIPS = {
	StoneAxe = {
		{ Grip = CFrame.new(-2.2, -0.02, -0.14) * CFrame.Angles(math.rad(-36), math.rad(110), math.rad(28)), Time = 0.07 },
		{ Grip = CFrame.new(-2.5, 0.18, -0.2) * CFrame.Angles(math.rad(-72), math.rad(122), math.rad(48)), Time = 0.095 },
		{ Grip = CFrame.new(-1.45, -0.42, -0.76) * CFrame.Angles(math.rad(56), math.rad(64), math.rad(-18)), Time = 0.06 },
		{ Grip = CFrame.new(-1.2, -0.28, -0.58) * CFrame.Angles(math.rad(34), math.rad(78), math.rad(-30)), Time = 0.085 },
		{ Grip = CFrame.new(-1.95, -0.2, -0.22) * CFrame.Angles(math.rad(-8), math.rad(94), math.rad(8)), Time = 0.085 },
	},
	Pickaxe = {
		{ Grip = CFrame.new(-2.18, -0.02, -0.14) * CFrame.Angles(math.rad(-42), math.rad(112), math.rad(26)), Time = 0.07 },
		{ Grip = CFrame.new(-2.45, 0.2, -0.22) * CFrame.Angles(math.rad(-80), math.rad(120), math.rad(42)), Time = 0.1 },
		{ Grip = CFrame.new(-1.58, -0.38, -0.82) * CFrame.Angles(math.rad(62), math.rad(68), math.rad(-26)), Time = 0.065 },
		{ Grip = CFrame.new(-2.05, -0.2, -0.18) * CFrame.Angles(math.rad(-10), math.rad(96), math.rad(6)), Time = 0.09 },
	},
	Spear = {
		{ Grip = CFrame.new(0.08, -0.05, -0.28) * CFrame.Angles(math.rad(-10), math.rad(94), math.rad(100)), Time = 0.06 },
		{ Grip = CFrame.new(0.04, -0.07, -1.28) * CFrame.Angles(math.rad(5), math.rad(86), math.rad(82)), Time = 0.07 },
		{ Grip = CFrame.new(0, -0.08, -0.92) * CFrame.Angles(math.rad(2), math.rad(89), math.rad(88)), Time = 0.05 },
		{ Grip = CFrame.new(0, -0.1, -0.55) * CFrame.Angles(0, math.rad(90), math.rad(86)), Time = 0.08 },
	},
	IronSpear = {
		{ Grip = CFrame.new(0.08, -0.05, -0.24) * CFrame.Angles(math.rad(-13), math.rad(96), math.rad(104)), Time = 0.06 },
		{ Grip = CFrame.new(0.05, -0.08, -1.35) * CFrame.Angles(math.rad(6), math.rad(85), math.rad(80)), Time = 0.065 },
		{ Grip = CFrame.new(0, -0.08, -0.98) * CFrame.Angles(math.rad(2), math.rad(89), math.rad(88)), Time = 0.055 },
		{ Grip = CFrame.new(0, -0.1, -0.55) * CFrame.Angles(0, math.rad(90), math.rad(86)), Time = 0.085 },
	},
}

local function notify(player, message)
	Remotes.get("Notification"):FireClient(player, message)
end

local function getDisplayName(itemId)
	local itemConfig = Config.Items[itemId]
	return itemConfig and itemConfig.DisplayName or itemId
end

local function getToolName(itemId, count)
	local displayName = getDisplayName(itemId)
	return count > 1 and string.format("%s x%d", displayName, count) or displayName
end

local function shouldMirrorAsTool(itemId)
	return Config.Equipment[itemId] ~= nil or Config.Buildables[itemId] ~= nil
end

local function getDefaultGrip(itemId)
	return DEFAULT_GRIPS[itemId] or CFrame.new()
end

local function easeOutCubic(alpha)
	local inverse = 1 - math.clamp(alpha, 0, 1)
	return 1 - inverse * inverse * inverse
end

local function getSequenceGrip(entry)
	return typeof(entry) == "CFrame" and entry or entry.Grip
end

local function getSequenceTime(entry)
	return typeof(entry) == "CFrame" and 0.08 or (entry.Time or 0.08)
end

local function tweenToolGrip(tool, targetGrip, duration)
	local startGrip = tool.Grip
	local startedAt = os.clock()

	while tool.Parent and os.clock() - startedAt < duration do
		local alpha = easeOutCubic((os.clock() - startedAt) / duration)
		tool.Grip = startGrip:Lerp(targetGrip, alpha)
		task.wait()
	end

	if tool.Parent then
		tool.Grip = targetGrip
	end
end

local function getPlayerContainers(player)
	local containers = {}
	local backpack = player:FindFirstChildOfClass("Backpack")

	if backpack then
		table.insert(containers, backpack)
	end

	if player.Character then
		table.insert(containers, player.Character)
	end

	return containers
end

local function findItemTools(player, itemId)
	local found = {}

	for _, container in ipairs(getPlayerContainers(player)) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool")
				and child:GetAttribute(ITEM_TOOL_ATTRIBUTE) == true
				and child:GetAttribute(ITEM_ID_ATTRIBUTE) == itemId
			then
				table.insert(found, child)
			end
		end
	end

	return found
end

local function setupPart(part, shape, size, color, material)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Size = size
	part.Color = color
	part.Material = material

	if not part:IsA("Part") then
		return
	end

	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
end

local function weldToHandle(handle, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
end

local function addPart(tool, handle, name, shape, size, cframeOffset, color, material)
	local part = Instance.new("Part")
	part.Name = name
	setupPart(part, shape, size, color, material)
	part.CFrame = handle.CFrame * cframeOffset
	part.Parent = tool
	weldToHandle(handle, part)
	return part
end

local function addWedgePart(tool, handle, name, size, cframeOffset, color, material)
	local part = Instance.new("WedgePart")
	part.Name = name
	setupPart(part, nil, size, color, material)
	part.CFrame = handle.CFrame * cframeOffset
	part.Parent = tool
	weldToHandle(handle, part)
	return part
end

local function addGripWrap(tool, handle, offsetX, width)
	addPart(
		tool,
		handle,
		"LeatherWrap",
		"Block",
		Vector3.new(width or 0.18, 0.52, 0.52),
		CFrame.new(offsetX, 0, 0),
		Color3.fromRGB(61, 39, 27),
		Enum.Material.Fabric
	)
end

local function addAxeDetails(tool, handle)
	addPart(
		tool,
		handle,
		"HandleCap",
		"Block",
		Vector3.new(0.18, 0.58, 0.58),
		CFrame.new(-2.62, 0, 0),
		Color3.fromRGB(62, 39, 25),
		Enum.Material.Wood
	)
	addGripWrap(tool, handle, -1.78, 0.24)
	addGripWrap(tool, handle, -1.5, 0.18)
	addPart(
		tool,
		handle,
		"StoneHeadCore",
		"Block",
		Vector3.new(0.45, 1.22, 1.04),
		CFrame.new(1.8, 0.02, 0),
		Color3.fromRGB(105, 109, 110),
		Enum.Material.Slate
	)
	addWedgePart(
		tool,
		handle,
		"UpperStoneBlade",
		Vector3.new(0.48, 1.08, 0.72),
		CFrame.new(1.88, 0.48, 0) * CFrame.Angles(0, 0, math.rad(180)),
		Color3.fromRGB(132, 136, 136),
		Enum.Material.Slate
	)
	addWedgePart(
		tool,
		handle,
		"LowerStoneBlade",
		Vector3.new(0.48, 1.08, 0.72),
		CFrame.new(1.88, -0.48, 0),
		Color3.fromRGB(132, 136, 136),
		Enum.Material.Slate
	)
	addPart(
		tool,
		handle,
		"StoneEdge",
		"Block",
		Vector3.new(0.12, 1.86, 0.88),
		CFrame.new(2.14, 0, 0),
		Color3.fromRGB(172, 176, 174),
		Enum.Material.Slate
	)
	addGripWrap(tool, handle, 1.42, 0.18)
	addGripWrap(tool, handle, 2.16, 0.14)
end

local function addPickaxeDetails(tool, handle)
	addPart(
		tool,
		handle,
		"HandleCap",
		"Block",
		Vector3.new(0.18, 0.56, 0.56),
		CFrame.new(-2.82, 0, 0),
		Color3.fromRGB(58, 38, 25),
		Enum.Material.Wood
	)
	addGripWrap(tool, handle, -1.9, 0.24)
	addGripWrap(tool, handle, -1.58, 0.18)
	addPart(
		tool,
		handle,
		"PickHeadCore",
		"Block",
		Vector3.new(0.58, 0.52, 1.18),
		CFrame.new(2.14, 0, 0),
		Color3.fromRGB(132, 136, 138),
		Enum.Material.Metal
	)
	addWedgePart(
		tool,
		handle,
		"PickSpikeFront",
		Vector3.new(0.95, 0.42, 0.42),
		CFrame.new(2.78, 0, 0) * CFrame.Angles(0, 0, math.rad(-90)),
		Color3.fromRGB(175, 179, 181),
		Enum.Material.Metal
	)
	addWedgePart(
		tool,
		handle,
		"PickSpikeRear",
		Vector3.new(0.95, 0.42, 0.42),
		CFrame.new(1.52, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(175, 179, 181),
		Enum.Material.Metal
	)
	addGripWrap(tool, handle, 1.62, 0.16)
	addGripWrap(tool, handle, 2.36, 0.14)
end

local function addSpearDetails(tool, handle, iron)
	local tipColor = iron and Color3.fromRGB(170, 174, 172) or Color3.fromRGB(124, 122, 113)
	local socketMaterial = iron and Enum.Material.Metal or Enum.Material.Slate

	addGripWrap(tool, handle, -1.2, 0.16)
	addGripWrap(tool, handle, 2.35, 0.16)
	addPart(
		tool,
		handle,
		"SpearSocket",
		"Block",
		Vector3.new(0.42, 0.46, 0.46),
		CFrame.new(3.05, 0, 0),
		tipColor,
		socketMaterial
	)
	addWedgePart(
		tool,
		handle,
		"SpearTip",
		Vector3.new(1, 0.72, 0.72),
		CFrame.new(3.62, 0, 0) * CFrame.Angles(0, 0, math.rad(-90)),
		tipColor,
		socketMaterial
	)

	if iron then
		for side = -1, 1, 2 do
			addWedgePart(
				tool,
				handle,
				"SpearBarb",
				Vector3.new(0.42, 0.48, 0.22),
				CFrame.new(3.18, side * 0.36, 0) * CFrame.Angles(0, 0, side * math.rad(34)),
				Color3.fromRGB(192, 196, 194),
				Enum.Material.Metal
			)
		end
	end
end

local function addKitDetails(tool, handle, visual)
	if visual.Kind == "TrapKit" then
		for x = -1, 1, 2 do
			addPart(
				tool,
				handle,
				"PackedSpike",
				"Block",
				Vector3.new(0.25, 1.2, 0.25),
				CFrame.new(x * 0.45, 0.55, 0) * CFrame.Angles(math.rad(28), 0, x * math.rad(18)),
				Color3.fromRGB(120, 83, 49),
				Enum.Material.Wood
			)
		end
	elseif visual.Kind == "BeaconKit" then
		addPart(
			tool,
			handle,
			"SignalCore",
			"Ball",
			Vector3.new(0.65, 0.65, 0.65),
			CFrame.new(0, 0.6, 0),
			Color3.fromRGB(93, 216, 243),
			Enum.Material.Neon
		)
	elseif visual.Kind == "TorchKit" then
		addPart(
			tool,
			handle,
			"PackedTorch",
			"Block",
			Vector3.new(0.35, 1.4, 0.35),
			CFrame.new(0, 0.85, 0),
			Color3.fromRGB(66, 44, 29),
			Enum.Material.Wood
		)
		addPart(
			tool,
			handle,
			"PackedFlame",
			"Ball",
			Vector3.new(0.55, 0.55, 0.55),
			CFrame.new(0, 1.6, 0),
			Color3.fromRGB(255, 127, 44),
			Enum.Material.Neon
		)
	elseif visual.Kind == "WallKit" then
		for index = -1, 1 do
			addPart(
				tool,
				handle,
				"PackedPlank",
				"Block",
				Vector3.new(2.6, 0.16, 0.22),
				CFrame.new(0, 0.42 + index * 0.28, 0),
				Color3.fromRGB(75, 49, 30),
				Enum.Material.Wood
			)
		end
	elseif visual.Kind == "StairKit" then
		for step = 1, 3 do
			addPart(
				tool,
				handle,
				"PackedStep",
				"Block",
				Vector3.new(1.65, 0.18, 0.35),
				CFrame.new(0, 0.32 + step * 0.22, -0.42 + step * 0.28),
				Color3.fromRGB(74, 49, 30),
				Enum.Material.Wood
			)
		end
	elseif visual.Kind == "ChestKit" then
		addPart(
			tool,
			handle,
			"ChestBand",
			"Block",
			Vector3.new(1.95, 0.18, 0.18),
			CFrame.new(0, 0.45, -0.58),
			Color3.fromRGB(70, 72, 68),
			Enum.Material.Metal
		)
	elseif visual.Kind == "TowerKit" then
		for x = -1, 1, 2 do
			addPart(
				tool,
				handle,
				"PackedPost",
				"Block",
				Vector3.new(0.18, 1.3, 0.18),
				CFrame.new(x * 0.65, 0.8, 0),
				Color3.fromRGB(70, 45, 29),
				Enum.Material.Wood
			)
		end
	elseif visual.Kind == "Kit" then
		addPart(
			tool,
			handle,
			"Strap",
			"Block",
			Vector3.new(2.2, 0.18, 0.22),
			CFrame.new(0, 0.4, 0),
			Color3.fromRGB(58, 47, 36),
			Enum.Material.Fabric
		)
	end
end

local function createToolVisual(tool, itemId)
	local visual = ITEM_VISUALS[itemId] or {
		Shape = "Block",
		Size = Vector3.new(1.5, 0.7, 1),
		Color = Color3.fromRGB(130, 130, 120),
		Material = Enum.Material.SmoothPlastic,
	}

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	setupPart(handle, visual.Shape, visual.Size, visual.Color, visual.Material)
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	if visual.Kind == "Axe" then
		addAxeDetails(tool, handle)
	elseif visual.Kind == "Pickaxe" then
		addPickaxeDetails(tool, handle)
	elseif visual.Kind == "Spear" or visual.Kind == "IronSpear" then
		addSpearDetails(tool, handle, visual.Kind == "IronSpear")
	elseif visual.Kind then
		addKitDetails(tool, handle, visual)
	end
end

local function playAttackAnimation(tool, itemId)
	local sequence = ATTACK_GRIPS[itemId]
	if not tool or not sequence or activeAnimations[tool] then
		return
	end

	activeAnimations[tool] = true

	task.spawn(function()
		for _, entry in ipairs(sequence) do
			if not tool.Parent then
				break
			end

			local grip = getSequenceGrip(entry)
			if grip then
				tweenToolGrip(tool, grip, getSequenceTime(entry))
			end
		end

		if tool.Parent then
			tweenToolGrip(tool, getDefaultGrip(itemId), 0.07)
		end

		activeAnimations[tool] = nil
	end)
end

local function runAction(player, itemId, tool)
	if not context or not context.InventoryService then
		return
	end

	local playerActions = lastActionByPlayer[player]
	if not playerActions then
		playerActions = {}
		lastActionByPlayer[player] = playerActions
	end

	local now = os.clock()
	if now - (playerActions[itemId] or 0) < ACTION_COOLDOWN_SECONDS then
		return
	end
	playerActions[itemId] = now

	if not context.InventoryService:hasItem(player, itemId, 1) then
		notify(player, string.format("No %s.", getDisplayName(itemId)))
		ItemToolService.syncPlayerTools(player)
		return
	end

	local isHarvestTool = itemId == "StoneAxe" or itemId == "Pickaxe"

	if isHarvestTool and context.ResourceService and context.ResourceService.toolHarvest then
		local handledHarvest = context.ResourceService.toolHarvest(player, itemId)
		if handledHarvest then
			playAttackAnimation(tool, itemId)
			return
		end
	end

	if isHarvestTool then
		playAttackAnimation(tool, itemId)
		return
	end

	if Config.Combat.Weapons[itemId] and context.CombatService then
		playAttackAnimation(tool, itemId)
		if context.CombatService.attack then
			local ok, message = context.CombatService:attack(player)
			if not ok and message then
				notify(player, message)
			end
		end
	elseif Config.Equipment[itemId] then
		local _, message = context.InventoryService:equipItem(player, itemId)
		if message then
			notify(player, message)
		end
	elseif Config.Consumables[itemId] then
		local ok, message = context.InventoryService:consume(player, itemId)
		if not ok and message then
			notify(player, message)
		end
	elseif Config.Buildables[itemId] and context.CraftingService then
		if context.CraftingService.build then
			local ok, message = context.CraftingService:build(player, itemId)
			if not ok and message then
				notify(player, message)
			end
		else
			notify(player, string.format("%s cannot be placed from quick-use yet.", getDisplayName(itemId)))
		end
	else
		notify(player, string.format("%s is a crafting material.", getDisplayName(itemId)))
	end
end

local function equipIfNeeded(player, itemId)
	if Config.Equipment[itemId] and context and context.InventoryService then
		local slot = Config.Equipment[itemId].Slot
		if context.InventoryService.getEquippedItem and context.InventoryService:getEquippedItem(player, slot) == itemId then
			return
		end

		local _, message = context.InventoryService:equipItem(player, itemId)
		if message then
			notify(player, message)
		end
	end
end

local function createTool(player, itemId, count)
	local tool = Instance.new("Tool")
	tool.Name = getToolName(itemId, count)
	tool.ToolTip = "Survival item"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = getDefaultGrip(itemId)
	tool:SetAttribute(ITEM_TOOL_ATTRIBUTE, true)
	tool:SetAttribute(ITEM_ID_ATTRIBUTE, itemId)
	tool:SetAttribute("Count", count)

	createToolVisual(tool, itemId)

	tool.Equipped:Connect(function()
		equipIfNeeded(player, itemId)
	end)

	tool.Activated:Connect(function()
		runAction(player, itemId, tool)
	end)

	return tool
end

local function updateTool(tool, itemId, count)
	tool.Name = getToolName(itemId, count)
	tool:SetAttribute("Count", count)

	if not activeAnimations[tool] then
		tool.Grip = getDefaultGrip(itemId)
	end

	if Config.Combat.Weapons[itemId] then
		tool.ToolTip = "Attack"
	elseif Config.Equipment[itemId] then
		tool.ToolTip = "Equip"
	elseif Config.Buildables[itemId] then
		tool.ToolTip = "Place"
	else
		tool.ToolTip = "Inventory item"
	end
end

function ItemToolService.syncPlayerTools(player)
	if not context or not context.InventoryService then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local snapshot = context.InventoryService:getInventory(player)
	local activeItemIds = {}

	for itemId, count in pairs(snapshot.Items or {}) do
		if count > 0 and shouldMirrorAsTool(itemId) then
			activeItemIds[itemId] = true

			local tools = findItemTools(player, itemId)
			local tool = tools[1]

			if not tool then
				tool = createTool(player, itemId, count)
				tool.Parent = backpack
			else
				updateTool(tool, itemId, count)
			end

			for index = 2, #tools do
				tools[index]:Destroy()
			end
		end
	end

	for _, container in ipairs(getPlayerContainers(player)) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute(ITEM_TOOL_ATTRIBUTE) == true then
				local itemId = child:GetAttribute(ITEM_ID_ATTRIBUTE)
				if not activeItemIds[itemId] then
					child:Destroy()
				end
			end
		end
	end
end

function ItemToolService.syncAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		ItemToolService.syncPlayerTools(player)
	end
end

function ItemToolService.equipPlayerTool(player, itemId)
	if type(itemId) ~= "string" or not shouldMirrorAsTool(itemId) then
		return false
	end

	ItemToolService.syncPlayerTools(player)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	for _, tool in ipairs(findItemTools(player, itemId)) do
		if tool.Parent == character then
			return true
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false
	end

	for _, tool in ipairs(findItemTools(player, itemId)) do
		if tool.Parent == backpack then
			humanoid:EquipTool(tool)
			return true
		end
	end

	return false
end

function ItemToolService.init(newContext)
	context = newContext
end

function ItemToolService.playerAdded(player)
	task.defer(function()
		ItemToolService.syncPlayerTools(player)
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		ItemToolService.syncPlayerTools(player)
	end)
end

function ItemToolService.playerRemoving(player)
	lastActionByPlayer[player] = nil
end

return ItemToolService
