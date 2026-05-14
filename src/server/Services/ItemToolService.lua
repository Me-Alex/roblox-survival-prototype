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

local ITEM_VISUALS = {
	Wood = { Shape = "Cylinder", Size = Vector3.new(3.2, 0.65, 0.65), Color = Color3.fromRGB(101, 67, 42), Material = Enum.Material.Wood },
	Stone = { Shape = "Ball", Size = Vector3.new(1.5, 1.15, 1.35), Color = Color3.fromRGB(112, 116, 118), Material = Enum.Material.Slate },
	Fiber = { Shape = "Block", Size = Vector3.new(0.5, 2.5, 0.35), Color = Color3.fromRGB(92, 142, 76), Material = Enum.Material.Grass },
	Hide = { Shape = "Block", Size = Vector3.new(2.2, 0.2, 1.6), Color = Color3.fromRGB(126, 85, 54), Material = Enum.Material.Fabric },
	IronOre = { Shape = "Ball", Size = Vector3.new(1.6, 1.2, 1.4), Color = Color3.fromRGB(114, 87, 75), Material = Enum.Material.Metal },
	IronIngot = { Shape = "Block", Size = Vector3.new(2.2, 0.55, 0.9), Color = Color3.fromRGB(154, 157, 153), Material = Enum.Material.Metal },
	AncientScrap = { Shape = "Block", Size = Vector3.new(1.9, 0.35, 1.2), Color = Color3.fromRGB(82, 103, 103), Material = Enum.Material.CorrodedMetal },
	MedicinalHerb = { Shape = "Block", Size = Vector3.new(0.55, 2.1, 0.35), Color = Color3.fromRGB(78, 149, 83), Material = Enum.Material.Grass },
	RawMeat = { Shape = "Ball", Size = Vector3.new(1.4, 0.9, 1.1), Color = Color3.fromRGB(153, 62, 64), Material = Enum.Material.SmoothPlastic },
	Berries = { Shape = "Ball", Size = Vector3.new(1.15, 1.15, 1.15), Color = Color3.fromRGB(166, 43, 70), Material = Enum.Material.SmoothPlastic },
	CookedBerries = { Shape = "Ball", Size = Vector3.new(1.15, 1.15, 1.15), Color = Color3.fromRGB(119, 47, 72), Material = Enum.Material.SmoothPlastic },
	CookedMeat = { Shape = "Ball", Size = Vector3.new(1.4, 0.9, 1.1), Color = Color3.fromRGB(118, 70, 41), Material = Enum.Material.SmoothPlastic },
	Bandage = { Shape = "Block", Size = Vector3.new(1.7, 0.45, 0.85), Color = Color3.fromRGB(226, 221, 196), Material = Enum.Material.Fabric },
	Antidote = { Shape = "Ball", Size = Vector3.new(0.95, 0.95, 0.95), Color = Color3.fromRGB(91, 194, 122), Material = Enum.Material.Glass },
	SurvivalTonic = { Shape = "Ball", Size = Vector3.new(1.05, 1.05, 1.05), Color = Color3.fromRGB(85, 176, 204), Material = Enum.Material.Glass },
	StoneAxe = { Shape = "Cylinder", Size = Vector3.new(4.4, 0.42, 0.42), Color = Color3.fromRGB(104, 66, 40), Material = Enum.Material.Wood, Kind = "Axe" },
	Spear = { Shape = "Cylinder", Size = Vector3.new(6.2, 0.32, 0.32), Color = Color3.fromRGB(112, 76, 45), Material = Enum.Material.Wood, Kind = "Spear" },
	IronSpear = { Shape = "Cylinder", Size = Vector3.new(6.5, 0.34, 0.34), Color = Color3.fromRGB(126, 91, 58), Material = Enum.Material.Wood, Kind = "IronSpear" },
	HideArmor = { Shape = "Block", Size = Vector3.new(2.5, 0.3, 2.2), Color = Color3.fromRGB(108, 70, 46), Material = Enum.Material.Fabric },
	IronArmor = { Shape = "Block", Size = Vector3.new(2.5, 0.35, 2.2), Color = Color3.fromRGB(137, 141, 142), Material = Enum.Material.Metal },
	CampfireKit = { Shape = "Block", Size = Vector3.new(1.8, 0.7, 1.8), Color = Color3.fromRGB(115, 79, 47), Material = Enum.Material.WoodPlanks, Kind = "Kit" },
	ShelterKit = { Shape = "Block", Size = Vector3.new(2.2, 0.5, 1.5), Color = Color3.fromRGB(120, 82, 52), Material = Enum.Material.WoodPlanks, Kind = "Kit" },
	RainCollectorKit = { Shape = "Block", Size = Vector3.new(1.8, 0.55, 1.8), Color = Color3.fromRGB(73, 137, 157), Material = Enum.Material.Glass, Kind = "Kit" },
	WorkbenchKit = { Shape = "Block", Size = Vector3.new(2.1, 0.55, 1.35), Color = Color3.fromRGB(101, 65, 39), Material = Enum.Material.WoodPlanks, Kind = "Kit" },
	ForgeKit = { Shape = "Block", Size = Vector3.new(1.9, 0.9, 1.5), Color = Color3.fromRGB(88, 87, 83), Material = Enum.Material.Slate, Kind = "Kit" },
	SpikeTrapKit = { Shape = "Block", Size = Vector3.new(2, 0.45, 2), Color = Color3.fromRGB(92, 68, 44), Material = Enum.Material.WoodPlanks, Kind = "TrapKit" },
	SignalBeaconKit = { Shape = "Block", Size = Vector3.new(1.7, 0.8, 1.7), Color = Color3.fromRGB(103, 116, 119), Material = Enum.Material.Metal, Kind = "BeaconKit" },
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

local function addAxeDetails(tool, handle)
	addPart(
		tool,
		handle,
		"StoneHead",
		"Block",
		Vector3.new(0.35, 1.45, 1),
		CFrame.new(1.45, 0.05, 0),
		Color3.fromRGB(112, 116, 118),
		Enum.Material.Slate
	)
end

local function addSpearDetails(tool, handle, iron)
	local tipColor = iron and Color3.fromRGB(170, 174, 172) or Color3.fromRGB(124, 122, 113)
	addPart(
		tool,
		handle,
		"SpearTip",
		"Block",
		Vector3.new(0.7, 0.65, 0.65),
		CFrame.new(3.2, 0, 0) * CFrame.Angles(0, 0, math.rad(45)),
		tipColor,
		iron and Enum.Material.Metal or Enum.Material.Slate
	)
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
	elseif visual.Kind == "Spear" or visual.Kind == "IronSpear" then
		addSpearDetails(tool, handle, visual.Kind == "IronSpear")
	elseif visual.Kind then
		addKitDetails(tool, handle, visual)
	end
end

local function runAction(player, itemId)
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

	if not context.InventoryService.hasItem(player, itemId, 1) then
		notify(player, string.format("No %s.", getDisplayName(itemId)))
		ItemToolService.syncPlayerTools(player)
		return
	end

	if Config.Combat.Weapons[itemId] and context.CombatService then
		local ok, message = context.CombatService.attack(player)
		if not ok and message then
			notify(player, message)
		end
	elseif Config.Equipment[itemId] then
		local _, message = context.InventoryService.equipItem(player, itemId)
		if message then
			notify(player, message)
		end
	elseif Config.Consumables[itemId] then
		local ok, message = context.InventoryService.consume(player, itemId)
		if not ok and message then
			notify(player, message)
		end
	elseif Config.Buildables[itemId] and context.CraftingService then
		local ok, message = context.CraftingService.build(player, itemId)
		if not ok and message then
			notify(player, message)
		end
	else
		notify(player, string.format("%s is a crafting material.", getDisplayName(itemId)))
	end
end

local function equipIfNeeded(player, itemId)
	if Config.Equipment[itemId] and context and context.InventoryService then
		local _, message = context.InventoryService.equipItem(player, itemId)
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
	tool:SetAttribute(ITEM_TOOL_ATTRIBUTE, true)
	tool:SetAttribute(ITEM_ID_ATTRIBUTE, itemId)
	tool:SetAttribute("Count", count)

	createToolVisual(tool, itemId)

	tool.Equipped:Connect(function()
		equipIfNeeded(player, itemId)
	end)

	tool.Activated:Connect(function()
		runAction(player, itemId)
	end)

	return tool
end

local function updateTool(tool, itemId, count)
	tool.Name = getToolName(itemId, count)
	tool:SetAttribute("Count", count)

	if Config.Combat.Weapons[itemId] then
		tool.ToolTip = "Attack"
	elseif Config.Equipment[itemId] then
		tool.ToolTip = "Equip"
	elseif Config.Consumables[itemId] then
		tool.ToolTip = "Use"
	elseif Config.Buildables[itemId] then
		tool.ToolTip = "Place"
	else
		tool.ToolTip = "Crafting material"
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

	local snapshot = context.InventoryService.getInventory(player)
	local activeItemIds = {}

	for itemId, count in pairs(snapshot.Items or {}) do
		if count > 0 then
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
