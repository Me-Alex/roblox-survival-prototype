local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local QUICK_SLOT_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
}

local QUICK_SLOT_PRIORITY = {
	StoneAxe = 1,
	Pickaxe = 2,
	Spear = 3,
	IronSpear = 4,
	Bandage = 5,
	SurvivalTonic = 6,
	Antidote = 7,
	CampfireKit = 8,
	TorchStandKit = 9,
	ShelterKit = 10,
	RainCollectorKit = 11,
	StorageChestKit = 12,
	WoodenWallKit = 13,
	WoodenDoorKit = 14,
	WoodenStairsKit = 15,
	WorkbenchKit = 16,
	WatchtowerKit = 17,
	ForgeKit = 18,
	SpikeTrapKit = 19,
	SignalBeaconKit = 20,
	CookedBerries = 21,
	CookedMeat = 22,
	MushroomStew = 23,
	HideArmor = 24,
	IronArmor = 25,
}

local ITEM_ICON_VISUALS = {
	Wood = { Shape = "Cylinder", Size = Vector3.new(1.9, 0.58, 0.58), Color = Color3.fromRGB(101, 67, 42), Material = Enum.Material.Wood },
	Leaves = { Shape = "Block", Size = Vector3.new(1.25, 0.22, 0.82), Color = Color3.fromRGB(70, 139, 59), Material = Enum.Material.Grass },
	Stone = { Shape = "Ball", Size = Vector3.new(1.2, 1.0, 1.1), Color = Color3.fromRGB(112, 116, 118), Material = Enum.Material.Slate },
	Fiber = { Shape = "Block", Size = Vector3.new(0.4, 1.65, 0.3), Color = Color3.fromRGB(92, 142, 76), Material = Enum.Material.Grass },
	Hide = { Shape = "Block", Size = Vector3.new(1.55, 0.2, 1.12), Color = Color3.fromRGB(126, 85, 54), Material = Enum.Material.Fabric },
	IronOre = { Shape = "Ball", Size = Vector3.new(1.3, 1.05, 1.2), Color = Color3.fromRGB(114, 87, 75), Material = Enum.Material.Metal },
	IronIngot = { Shape = "Block", Size = Vector3.new(1.7, 0.42, 0.74), Color = Color3.fromRGB(154, 157, 153), Material = Enum.Material.Metal },
	AncientScrap = { Shape = "Block", Size = Vector3.new(1.6, 0.3, 0.9), Color = Color3.fromRGB(82, 103, 103), Material = Enum.Material.CorrodedMetal },
	MedicinalHerb = { Shape = "Block", Size = Vector3.new(0.35, 1.5, 0.28), Color = Color3.fromRGB(78, 149, 83), Material = Enum.Material.Grass },
	RawMeat = { Shape = "Ball", Size = Vector3.new(1.1, 0.8, 0.95), Color = Color3.fromRGB(153, 62, 64), Material = Enum.Material.SmoothPlastic },
	Berries = { Shape = "Ball", Size = Vector3.new(0.9, 0.9, 0.9), Color = Color3.fromRGB(166, 43, 70), Material = Enum.Material.SmoothPlastic },
	Mushrooms = { Shape = "Ball", Size = Vector3.new(0.92, 0.75, 0.92), Color = Color3.fromRGB(157, 128, 86), Material = Enum.Material.SmoothPlastic },
	CookedBerries = { Shape = "Ball", Size = Vector3.new(0.9, 0.9, 0.9), Color = Color3.fromRGB(119, 47, 72), Material = Enum.Material.SmoothPlastic },
	CookedMeat = { Shape = "Ball", Size = Vector3.new(1.1, 0.8, 0.95), Color = Color3.fromRGB(118, 70, 41), Material = Enum.Material.SmoothPlastic },
	MushroomStew = { Shape = "Ball", Size = Vector3.new(0.98, 0.72, 0.98), Color = Color3.fromRGB(127, 91, 55), Material = Enum.Material.SmoothPlastic },
	Bandage = { Shape = "Block", Size = Vector3.new(1.3, 0.32, 0.64), Color = Color3.fromRGB(226, 221, 196), Material = Enum.Material.Fabric },
	Antidote = { Shape = "Ball", Size = Vector3.new(0.7, 0.7, 0.7), Color = Color3.fromRGB(91, 194, 122), Material = Enum.Material.Glass },
	SurvivalTonic = { Shape = "Ball", Size = Vector3.new(0.78, 0.78, 0.78), Color = Color3.fromRGB(85, 176, 204), Material = Enum.Material.Glass },
	StoneAxe = { Shape = "Cylinder", Size = Vector3.new(2.1, 0.18, 0.18), Color = Color3.fromRGB(101, 64, 38), Material = Enum.Material.Wood, Kind = "Axe" },
	Pickaxe = { Shape = "Cylinder", Size = Vector3.new(2.2, 0.18, 0.18), Color = Color3.fromRGB(96, 65, 41), Material = Enum.Material.Wood, Kind = "Pickaxe" },
	Spear = { Shape = "Cylinder", Size = Vector3.new(2.6, 0.16, 0.16), Color = Color3.fromRGB(112, 76, 45), Material = Enum.Material.Wood, Kind = "Spear" },
	IronSpear = { Shape = "Cylinder", Size = Vector3.new(2.6, 0.16, 0.16), Color = Color3.fromRGB(126, 91, 58), Material = Enum.Material.Wood, Kind = "IronSpear" },
	HideArmor = { Shape = "Block", Size = Vector3.new(1.45, 0.2, 1.2), Color = Color3.fromRGB(108, 70, 46), Material = Enum.Material.Fabric },
	IronArmor = { Shape = "Block", Size = Vector3.new(1.45, 0.22, 1.2), Color = Color3.fromRGB(137, 141, 142), Material = Enum.Material.Metal },
	CampfireKit = { Shape = "Block", Size = Vector3.new(1.25, 0.46, 1.25), Color = Color3.fromRGB(115, 79, 47), Material = Enum.Material.WoodPlanks },
	TorchStandKit = { Shape = "Block", Size = Vector3.new(1.15, 0.36, 1.15), Color = Color3.fromRGB(94, 64, 39), Material = Enum.Material.WoodPlanks },
	ShelterKit = { Shape = "Block", Size = Vector3.new(1.42, 0.42, 1.08), Color = Color3.fromRGB(120, 82, 52), Material = Enum.Material.WoodPlanks },
	WoodenWallKit = { Shape = "Block", Size = Vector3.new(1.56, 0.35, 0.86), Color = Color3.fromRGB(112, 74, 43), Material = Enum.Material.WoodPlanks },
	WoodenDoorKit = { Shape = "Block", Size = Vector3.new(1.22, 0.4, 0.86), Color = Color3.fromRGB(103, 68, 40), Material = Enum.Material.WoodPlanks },
	WoodenStairsKit = { Shape = "Block", Size = Vector3.new(1.3, 0.42, 1.0), Color = Color3.fromRGB(111, 72, 42), Material = Enum.Material.WoodPlanks },
	StorageChestKit = { Shape = "Block", Size = Vector3.new(1.25, 0.54, 0.84), Color = Color3.fromRGB(92, 58, 34), Material = Enum.Material.WoodPlanks },
	WatchtowerKit = { Shape = "Block", Size = Vector3.new(1.55, 0.52, 1.1), Color = Color3.fromRGB(92, 62, 38), Material = Enum.Material.WoodPlanks },
	RainCollectorKit = { Shape = "Block", Size = Vector3.new(1.2, 0.4, 1.2), Color = Color3.fromRGB(73, 137, 157), Material = Enum.Material.Glass },
	WorkbenchKit = { Shape = "Block", Size = Vector3.new(1.44, 0.4, 0.92), Color = Color3.fromRGB(101, 65, 39), Material = Enum.Material.WoodPlanks },
	ForgeKit = { Shape = "Block", Size = Vector3.new(1.3, 0.6, 1.0), Color = Color3.fromRGB(88, 87, 83), Material = Enum.Material.Slate },
	SpikeTrapKit = { Shape = "Block", Size = Vector3.new(1.3, 0.32, 1.3), Color = Color3.fromRGB(92, 68, 44), Material = Enum.Material.WoodPlanks },
	SignalBeaconKit = { Shape = "Block", Size = Vector3.new(1.15, 0.55, 1.15), Color = Color3.fromRGB(103, 116, 119), Material = Enum.Material.Metal },
}

local ITEM_SHORT_NAMES = {
	StoneAxe = "Axe",
	Pickaxe = "Pick",
	Spear = "Spear",
	IronSpear = "I.Spear",
	Bandage = "Med",
	Antidote = "Anti",
	SurvivalTonic = "Tonic",
	CampfireKit = "Fire",
	TorchStandKit = "Torch",
	ShelterKit = "Shelter",
	WoodenWallKit = "Wall",
	WoodenDoorKit = "Door",
	WoodenStairsKit = "Stairs",
	StorageChestKit = "Chest",
	WatchtowerKit = "Tower",
	RainCollectorKit = "Water",
	WorkbenchKit = "Bench",
	ForgeKit = "Forge",
	SpikeTrapKit = "Trap",
	SignalBeaconKit = "Beacon",
	CookedBerries = "Berry",
	CookedMeat = "Meat",
	MushroomStew = "Stew",
	HideArmor = "Hide",
	IronArmor = "Armor",
}

local SWIM_MOVE_ANIMATION_ID = "rbxassetid://507784897"
local SWIM_IDLE_ANIMATION_ID = "rbxassetid://507785072"
local WATER_SCAN_INTERVAL_SECONDS = 0.12
local WATER_FLOAT_SURFACE_EXIT_OFFSET = 6
local WATER_FLOAT_ROOT_OFFSET = -1.05
local WATER_SWIM_ROOT_TRIGGER_DEPTH = 0.35
local WATER_HEAD_VISIBLE_HEIGHT = 0.18
local SWIM_HEAD_LIFT = 0.34
local SWIM_ORIENTATION_RESPONSIVENESS = 28
local SWIM_ORIENTATION_MAX_TORQUE = 1500000
local SWIM_HORIZONTAL_SNAP_RATE = 12

local THEME = {
	Panel = Color3.fromRGB(17, 19, 18),
	PanelAlt = Color3.fromRGB(29, 33, 31),
	PanelRaised = Color3.fromRGB(40, 45, 42),
	Track = Color3.fromRGB(36, 41, 38),
	Text = Color3.fromRGB(240, 238, 228),
	Muted = Color3.fromRGB(182, 182, 170),
	Accent = Color3.fromRGB(219, 182, 97),
	Good = Color3.fromRGB(92, 170, 88),
	Warn = Color3.fromRGB(212, 146, 66),
	Bad = Color3.fromRGB(198, 75, 70),
	Health = Color3.fromRGB(195, 71, 66),
	Hunger = Color3.fromRGB(219, 149, 67),
	Thirst = Color3.fromRGB(80, 149, 225),
	Stamina = Color3.fromRGB(103, 177, 95),
}

local state = {
	Inventory = {
		Items = {},
		Equipped = {},
		Durability = {},
	},
	Vitals = {
		Hunger = 100,
		Thirst = 100,
		Temperature = 72,
		Health = 100,
		Statuses = {},
	},
	World = {
		Day = 1,
		Clock = "08:00",
		Region = "Wilderness",
		RegionId = nil,
		Weather = "Clear",
		IsNight = false,
		Threat = 0,
		DiscoveredRegions = {},
	},
	Progression = {
		Level = 1,
		XP = 0,
		NextLevelXP = 80,
	},
	Objectives = {
		Objectives = {},
		Counters = {},
	},
	Save = {
		Text = "Loading save...",
		Kind = "pending",
	},
	Stamina = Config.Movement.StaminaMax,
	MenuOpen = false,
	ActiveTab = "Inventory",
	ActiveCraftCategory = (Config.CraftingCategories and Config.CraftingCategories[1] and Config.CraftingCategories[1].Id) or "All",
	SelectedRecipeId = nil,
	ActiveShopId = nil,
	SelectedShopEntryId = nil,
	SprintRequested = false,
	QuickSlots = {},
}

local notificationToken = 0
local resourcePopupToken = 0
local waterScanAccumulator = WATER_SCAN_INTERVAL_SECONDS
local activeSwimHumanoid
local activeSwimTrack
local activeSwimIdleTrack
local activeWaterSurfaceY
local activeSwimAutoRotate
local activeSwimAttachment
local activeSwimOrientation
local activeSwimForward
local swimWaterParts = {}
local swimWaterPartsDirty = true
local lastAppliedWalkSpeed = Config.Movement.WalkSpeed
local lastRenderedStamina = state.Stamina
local STAMINA_UI_EPSILON = 0.2

local swimMoveAnimation = Instance.new("Animation")
swimMoveAnimation.Name = "SurvivalSwimMove"
swimMoveAnimation.AnimationId = SWIM_MOVE_ANIMATION_ID

local swimIdleAnimation = Instance.new("Animation")
swimIdleAnimation.Name = "SurvivalSwimIdle"
swimIdleAnimation.AnimationId = SWIM_IDLE_ANIMATION_ID

local function clamp01(value)
	return math.max(0, math.min(1, value))
end

local function clearChildren(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding") then
			continue
		end
		child:Destroy()
	end
end

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function createStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function createButton(parent, text, size, color)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or THEME.PanelRaised
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Size = size
	button.Text = text
	button.TextColor3 = THEME.Text
	button.TextSize = 12
	button.Parent = parent
	createCorner(button, 6)
	return button
end

local function configureIconPart(part, visual)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = visual.Size or Vector3.new(1, 1, 1)
	part.Color = visual.Color or Color3.fromRGB(130, 130, 120)
	part.Material = visual.Material or Enum.Material.SmoothPlastic

	local shape = visual.Shape
	if part:IsA("Part") then
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		else
			part.Shape = Enum.PartType.Block
		end
	end
end

local function addIconPart(parent, name, visual, cframe)
	local part = Instance.new("Part")
	part.Name = name
	configureIconPart(part, visual)
	part.CFrame = cframe or CFrame.new()
	part.Parent = parent
	return part
end

local function buildItemIconModel(model, itemId)
	local visual = ITEM_ICON_VISUALS[itemId] or {
		Shape = "Block",
		Size = Vector3.new(1.2, 0.7, 1),
		Color = Color3.fromRGB(130, 130, 120),
		Material = Enum.Material.SmoothPlastic,
	}

	local core = addIconPart(model, "Core", visual, CFrame.new())

	if visual.Kind == "Axe" then
		addIconPart(
			model,
			"AxeHead",
			{ Shape = "Block", Size = Vector3.new(0.22, 0.8, 0.62), Color = Color3.fromRGB(170, 176, 174), Material = Enum.Material.Slate },
			CFrame.new(0.95, 0.05, 0) * CFrame.Angles(0, 0, math.rad(14))
		)
	elseif visual.Kind == "Pickaxe" then
		addIconPart(
			model,
			"PickHead",
			{ Shape = "Block", Size = Vector3.new(1.0, 0.18, 0.18), Color = Color3.fromRGB(175, 179, 181), Material = Enum.Material.Metal },
			CFrame.new(0.95, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		)
	elseif visual.Kind == "Spear" or visual.Kind == "IronSpear" then
		addIconPart(
			model,
			"SpearTip",
			{ Shape = "Block", Size = Vector3.new(0.24, 0.24, 0.24), Color = Color3.fromRGB(188, 186, 174), Material = Enum.Material.Metal },
			CFrame.new(1.35, 0, 0)
		)
	end

	return core
end

local function frameModelInViewport(camera, model)
	local cf, size = model:GetBoundingBox()
	local maxDimension = math.max(size.X, size.Y, size.Z)
	local distance = maxDimension * 2.2
	local focus = cf.Position
	camera.CFrame = CFrame.new(
		focus + Vector3.new(distance * 0.62, distance * 0.5, distance),
		focus
	)
	camera.Focus = CFrame.new(focus)
end

local function createItemThumbnail(parent, itemId)
	local thumbnail = Instance.new("Frame")
	thumbnail.BackgroundColor3 = THEME.Panel
	thumbnail.BorderSizePixel = 0
	thumbnail.Size = UDim2.fromOffset(44, 44)
	thumbnail.ZIndex = 23
	thumbnail.Parent = parent
	createCorner(thumbnail, 6)
	createStroke(thumbnail, Color3.fromRGB(67, 73, 69), 0.4, 1)

	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = 24
	viewport.Ambient = Color3.fromRGB(165, 165, 165)
	viewport.LightColor = Color3.fromRGB(255, 248, 230)
	viewport.LightDirection = Vector3.new(-0.7, -1, -0.6)
	viewport.Parent = thumbnail

	local iconModel = Instance.new("Model")
	iconModel.Name = "IconModel"
	iconModel.Parent = viewport

	local core = buildItemIconModel(iconModel, itemId)
	if core then
		iconModel.PrimaryPart = core
	end

	local camera = Instance.new("Camera")
	camera.Name = "IconCamera"
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	frameModelInViewport(camera, iconModel)

	return thumbnail
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SurvivalHud"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = screenGui

local notificationLabel = Instance.new("TextLabel")
notificationLabel.Name = "Notification"
notificationLabel.AnchorPoint = Vector2.new(0.5, 0)
notificationLabel.BackgroundColor3 = THEME.Panel
notificationLabel.BackgroundTransparency = 0.1
notificationLabel.BorderSizePixel = 0
notificationLabel.Font = Enum.Font.GothamBold
notificationLabel.Position = UDim2.new(0.5, 0, 0, 18)
notificationLabel.Size = UDim2.fromOffset(500, 34)
notificationLabel.Text = ""
notificationLabel.TextColor3 = THEME.Text
notificationLabel.TextSize = 14
notificationLabel.Visible = false
notificationLabel.ZIndex = 30
notificationLabel.Parent = root
createCorner(notificationLabel, 8)

local worldStrip = Instance.new("Frame")
worldStrip.Name = "WorldStrip"
worldStrip.AnchorPoint = Vector2.new(0.5, 0)
worldStrip.BackgroundColor3 = THEME.Panel
worldStrip.BackgroundTransparency = 0.08
worldStrip.BorderSizePixel = 0
worldStrip.Position = UDim2.new(0.5, 0, 0, 60)
worldStrip.Size = UDim2.fromOffset(640, 38)
worldStrip.Parent = root
createCorner(worldStrip, 8)

local worldStripText = Instance.new("TextLabel")
worldStripText.BackgroundTransparency = 1
worldStripText.Font = Enum.Font.GothamBold
worldStripText.Position = UDim2.fromOffset(10, 0)
worldStripText.Size = UDim2.new(1, -20, 1, 0)
worldStripText.Text = ""
worldStripText.TextColor3 = THEME.Text
worldStripText.TextSize = 12
worldStripText.TextXAlignment = Enum.TextXAlignment.Left
worldStripText.Parent = worldStrip

local vitalsPanel = Instance.new("Frame")
vitalsPanel.Name = "VitalsPanel"
vitalsPanel.BackgroundColor3 = THEME.Panel
vitalsPanel.BackgroundTransparency = 0.08
vitalsPanel.BorderSizePixel = 0
vitalsPanel.Position = UDim2.fromOffset(14, 110)
vitalsPanel.Size = UDim2.fromOffset(256, 178)
vitalsPanel.Parent = root
createCorner(vitalsPanel, 8)

local vitalsTitle = Instance.new("TextLabel")
vitalsTitle.BackgroundTransparency = 1
vitalsTitle.Font = Enum.Font.GothamBlack
vitalsTitle.Position = UDim2.fromOffset(10, 6)
vitalsTitle.Size = UDim2.new(1, -20, 0, 18)
vitalsTitle.Text = "SURVIVAL"
vitalsTitle.TextColor3 = THEME.Accent
vitalsTitle.TextSize = 12
vitalsTitle.TextXAlignment = Enum.TextXAlignment.Left
vitalsTitle.Parent = vitalsPanel

local vitalsBarsFrame = Instance.new("Frame")
vitalsBarsFrame.BackgroundTransparency = 1
vitalsBarsFrame.Position = UDim2.fromOffset(10, 30)
vitalsBarsFrame.Size = UDim2.new(1, -20, 0, 126)
vitalsBarsFrame.Parent = vitalsPanel

local vitalsLayout = Instance.new("UIListLayout")
vitalsLayout.Padding = UDim.new(0, 6)
vitalsLayout.SortOrder = Enum.SortOrder.LayoutOrder
vitalsLayout.Parent = vitalsBarsFrame

local vitalsStatus = Instance.new("TextLabel")
vitalsStatus.BackgroundTransparency = 1
vitalsStatus.Font = Enum.Font.GothamMedium
vitalsStatus.Position = UDim2.new(0, 10, 1, -20)
vitalsStatus.Size = UDim2.new(1, -20, 0, 14)
vitalsStatus.Text = "Stable"
vitalsStatus.TextColor3 = THEME.Muted
vitalsStatus.TextSize = 11
vitalsStatus.TextXAlignment = Enum.TextXAlignment.Left
vitalsStatus.Parent = vitalsPanel

local barRefs = {}

local function createVitalBar(labelText, color, order)
	local row = Instance.new("Frame")
	row.Name = labelText .. "Row"
	row.LayoutOrder = order
	row.BackgroundColor3 = THEME.Track
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 26)
	row.Parent = vitalsBarsFrame
	createCorner(row, 6)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = row
	createCorner(fill, 6)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.fromOffset(8, 0)
	label.Size = UDim2.new(0, 100, 1, 0)
	label.Text = labelText
	label.TextColor3 = THEME.Text
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.Position = UDim2.new(1, -58, 0, 0)
	value.Size = UDim2.fromOffset(52, 26)
	value.Text = "100"
	value.TextColor3 = THEME.Text
	value.TextSize = 11
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Parent = row

	return {
		Fill = fill,
		Value = value,
	}
end

barRefs.Health = createVitalBar("Health", THEME.Health, 1)
barRefs.Hunger = createVitalBar("Hunger", THEME.Hunger, 2)
barRefs.Thirst = createVitalBar("Thirst", THEME.Thirst, 3)
barRefs.Stamina = createVitalBar("Stamina", THEME.Stamina, 4)

local quickBar = Instance.new("Frame")
quickBar.Name = "QuickBar"
quickBar.AnchorPoint = Vector2.new(0.5, 1)
quickBar.BackgroundColor3 = THEME.Panel
quickBar.BackgroundTransparency = 0.08
quickBar.BorderSizePixel = 0
quickBar.Position = UDim2.new(0.5, 0, 1, -12)
quickBar.Size = UDim2.fromOffset(510, 62)
quickBar.Parent = root
createCorner(quickBar, 8)

local quickLayout = Instance.new("UIListLayout")
quickLayout.FillDirection = Enum.FillDirection.Horizontal
quickLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
quickLayout.VerticalAlignment = Enum.VerticalAlignment.Center
quickLayout.Padding = UDim.new(0, 6)
quickLayout.Parent = quickBar

local quickSlotButtons = {}
for index = 1, 8 do
	local button = createButton(quickBar, tostring(index), UDim2.fromOffset(56, 48), THEME.PanelRaised)
	button.Name = "QuickSlot" .. tostring(index)
	button.TextSize = 11
	button.LayoutOrder = index
	quickSlotButtons[index] = button
end

local actionsPanel = Instance.new("Frame")
actionsPanel.Name = "ActionsPanel"
actionsPanel.AnchorPoint = Vector2.new(1, 1)
actionsPanel.BackgroundTransparency = 1
actionsPanel.Position = UDim2.new(1, -16, 1, -96)
actionsPanel.Size = UDim2.fromOffset(130, 156)
actionsPanel.Parent = root

local actionsLayout = Instance.new("UIListLayout")
actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
actionsLayout.Padding = UDim.new(0, 8)
actionsLayout.Parent = actionsPanel

local attackButton = createButton(actionsPanel, "Attack [F]", UDim2.fromOffset(126, 42), THEME.Bad)
local sprintButton = createButton(actionsPanel, "Sprint", UDim2.fromOffset(126, 42), THEME.Good)
local menuButton = createButton(actionsPanel, "Menu [I]", UDim2.fromOffset(126, 42), THEME.PanelRaised)

local menuFrame = Instance.new("Frame")
menuFrame.Name = "Menu"
menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
menuFrame.BackgroundColor3 = THEME.Panel
menuFrame.BackgroundTransparency = 0.03
menuFrame.BorderSizePixel = 0
menuFrame.Position = UDim2.fromScale(0.5, 0.5)
menuFrame.Size = UDim2.fromScale(0.88, 0.8)
menuFrame.Visible = false
menuFrame.ZIndex = 20
menuFrame.Parent = root
createCorner(menuFrame, 8)
createStroke(menuFrame, Color3.fromRGB(67, 73, 69), 0.35, 1)

local menuSizeConstraint = Instance.new("UISizeConstraint")
menuSizeConstraint.MinSize = Vector2.new(560, 360)
menuSizeConstraint.MaxSize = Vector2.new(1100, 720)
menuSizeConstraint.Parent = menuFrame

local menuTitle = Instance.new("TextLabel")
menuTitle.BackgroundTransparency = 1
menuTitle.Font = Enum.Font.GothamBlack
menuTitle.Position = UDim2.fromOffset(14, 8)
menuTitle.Size = UDim2.new(1, -180, 0, 22)
menuTitle.Text = "SURVIVAL INTERFACE"
menuTitle.TextColor3 = THEME.Accent
menuTitle.TextSize = 14
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.ZIndex = 21
menuTitle.Parent = menuFrame

local closeMenuButton = createButton(menuFrame, "Close", UDim2.fromOffset(90, 30), THEME.PanelRaised)
closeMenuButton.AnchorPoint = Vector2.new(1, 0)
closeMenuButton.Position = UDim2.new(1, -14, 0, 8)
closeMenuButton.ZIndex = 21

local tabsBar = Instance.new("Frame")
tabsBar.BackgroundTransparency = 1
tabsBar.Position = UDim2.fromOffset(14, 38)
tabsBar.Size = UDim2.new(1, -28, 0, 30)
tabsBar.ZIndex = 21
tabsBar.Parent = menuFrame

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding = UDim.new(0, 8)
tabsLayout.Parent = tabsBar

local tabButtons = {
	Inventory = createButton(tabsBar, "Inventory", UDim2.fromOffset(110, 30), THEME.PanelRaised),
	Crafting = createButton(tabsBar, "Crafting", UDim2.fromOffset(110, 30), THEME.PanelRaised),
	Shops = createButton(tabsBar, "Shops", UDim2.fromOffset(110, 30), THEME.PanelRaised),
	Objectives = createButton(tabsBar, "Objectives", UDim2.fromOffset(110, 30), THEME.PanelRaised),
	World = createButton(tabsBar, "World", UDim2.fromOffset(110, 30), THEME.PanelRaised),
}

for _, button in pairs(tabButtons) do
	button.ZIndex = 21
end

local contentFrame = Instance.new("Frame")
contentFrame.BackgroundTransparency = 1
contentFrame.Position = UDim2.fromOffset(14, 78)
contentFrame.Size = UDim2.new(1, -28, 1, -92)
contentFrame.ZIndex = 21
contentFrame.Parent = menuFrame

local inventoryPage = Instance.new("Frame")
inventoryPage.Name = "InventoryPage"
inventoryPage.BackgroundTransparency = 1
inventoryPage.Size = UDim2.fromScale(1, 1)
inventoryPage.ZIndex = 21
inventoryPage.Parent = contentFrame

local inventoryList = Instance.new("ScrollingFrame")
inventoryList.BackgroundTransparency = 1
inventoryList.BorderSizePixel = 0
inventoryList.Size = UDim2.new(0.64, -8, 1, 0)
inventoryList.ScrollBarThickness = 6
inventoryList.CanvasSize = UDim2.fromOffset(0, 0)
inventoryList.AutomaticCanvasSize = Enum.AutomaticSize.Y
inventoryList.ZIndex = 22
inventoryList.Parent = inventoryPage

local inventoryListLayout = Instance.new("UIListLayout")
inventoryListLayout.Padding = UDim.new(0, 6)
inventoryListLayout.Parent = inventoryList

local equipmentPanel = Instance.new("Frame")
equipmentPanel.BackgroundColor3 = THEME.PanelAlt
equipmentPanel.BorderSizePixel = 0
equipmentPanel.Position = UDim2.new(0.64, 8, 0, 0)
equipmentPanel.Size = UDim2.new(0.36, -8, 1, 0)
equipmentPanel.ZIndex = 21
equipmentPanel.Parent = inventoryPage
createCorner(equipmentPanel, 7)

local equipmentTitle = Instance.new("TextLabel")
equipmentTitle.BackgroundTransparency = 1
equipmentTitle.Font = Enum.Font.GothamBlack
equipmentTitle.Position = UDim2.fromOffset(10, 10)
equipmentTitle.Size = UDim2.new(1, -20, 0, 16)
equipmentTitle.Text = "EQUIPMENT"
equipmentTitle.TextColor3 = THEME.Text
equipmentTitle.TextSize = 11
equipmentTitle.TextXAlignment = Enum.TextXAlignment.Left
equipmentTitle.ZIndex = 22
equipmentTitle.Parent = equipmentPanel

local equipmentSummary = Instance.new("TextLabel")
equipmentSummary.BackgroundTransparency = 1
equipmentSummary.Font = Enum.Font.GothamMedium
equipmentSummary.Position = UDim2.fromOffset(10, 34)
equipmentSummary.Size = UDim2.new(1, -20, 1, -44)
equipmentSummary.Text = ""
equipmentSummary.TextColor3 = THEME.Muted
equipmentSummary.TextSize = 12
equipmentSummary.TextWrapped = true
equipmentSummary.TextXAlignment = Enum.TextXAlignment.Left
equipmentSummary.TextYAlignment = Enum.TextYAlignment.Top
equipmentSummary.ZIndex = 22
equipmentSummary.Parent = equipmentPanel

local craftingPage = Instance.new("Frame")
craftingPage.Name = "CraftingPage"
craftingPage.BackgroundTransparency = 1
craftingPage.Size = UDim2.fromScale(1, 1)
craftingPage.Visible = false
craftingPage.ZIndex = 21
craftingPage.Parent = contentFrame

local craftCategoryBar = Instance.new("Frame")
craftCategoryBar.BackgroundTransparency = 1
craftCategoryBar.Size = UDim2.new(1, 0, 0, 30)
craftCategoryBar.ZIndex = 22
craftCategoryBar.Parent = craftingPage

local craftCategoryLayout = Instance.new("UIListLayout")
craftCategoryLayout.FillDirection = Enum.FillDirection.Horizontal
craftCategoryLayout.Padding = UDim.new(0, 8)
craftCategoryLayout.Parent = craftCategoryBar

local craftCategoryButtons = {}
local renderCrafting
local renderShops

local craftList = Instance.new("ScrollingFrame")
craftList.BackgroundTransparency = 1
craftList.BorderSizePixel = 0
craftList.Position = UDim2.fromOffset(0, 36)
craftList.Size = UDim2.new(0.56, -8, 1, -36)
craftList.ScrollBarThickness = 6
craftList.CanvasSize = UDim2.fromOffset(0, 0)
craftList.AutomaticCanvasSize = Enum.AutomaticSize.Y
craftList.ZIndex = 22
craftList.Parent = craftingPage

local craftListLayout = Instance.new("UIListLayout")
craftListLayout.Padding = UDim.new(0, 6)
craftListLayout.Parent = craftList

local craftDetail = Instance.new("Frame")
craftDetail.BackgroundColor3 = THEME.PanelAlt
craftDetail.BorderSizePixel = 0
craftDetail.Position = UDim2.new(0.56, 8, 0, 36)
craftDetail.Size = UDim2.new(0.44, -8, 1, -36)
craftDetail.ZIndex = 21
craftDetail.Parent = craftingPage
createCorner(craftDetail, 7)

local craftDetailTitle = Instance.new("TextLabel")
craftDetailTitle.BackgroundTransparency = 1
craftDetailTitle.Font = Enum.Font.GothamBlack
craftDetailTitle.Position = UDim2.fromOffset(10, 10)
craftDetailTitle.Size = UDim2.new(1, -20, 0, 20)
craftDetailTitle.Text = "SELECT RECIPE"
craftDetailTitle.TextColor3 = THEME.Text
craftDetailTitle.TextSize = 14
craftDetailTitle.TextXAlignment = Enum.TextXAlignment.Left
craftDetailTitle.ZIndex = 22
craftDetailTitle.Parent = craftDetail

local craftDetailDesc = Instance.new("TextLabel")
craftDetailDesc.BackgroundTransparency = 1
craftDetailDesc.Font = Enum.Font.Gotham
craftDetailDesc.Position = UDim2.fromOffset(10, 34)
craftDetailDesc.Size = UDim2.new(1, -20, 0, 66)
craftDetailDesc.Text = ""
craftDetailDesc.TextColor3 = THEME.Muted
craftDetailDesc.TextSize = 12
craftDetailDesc.TextWrapped = true
craftDetailDesc.TextXAlignment = Enum.TextXAlignment.Left
craftDetailDesc.TextYAlignment = Enum.TextYAlignment.Top
craftDetailDesc.ZIndex = 22
craftDetailDesc.Parent = craftDetail

local craftRequirements = Instance.new("Frame")
craftRequirements.BackgroundTransparency = 1
craftRequirements.Position = UDim2.fromOffset(10, 106)
craftRequirements.Size = UDim2.new(1, -20, 1, -158)
craftRequirements.ZIndex = 22
craftRequirements.Parent = craftDetail

local craftRequirementsLayout = Instance.new("UIListLayout")
craftRequirementsLayout.Padding = UDim.new(0, 5)
craftRequirementsLayout.Parent = craftRequirements

local craftButton = createButton(craftDetail, "Craft", UDim2.fromOffset(120, 34), THEME.Good)
craftButton.Position = UDim2.new(0, 10, 1, -44)
craftButton.ZIndex = 22

local shopsPage = Instance.new("Frame")
shopsPage.Name = "ShopsPage"
shopsPage.BackgroundTransparency = 1
shopsPage.Size = UDim2.fromScale(1, 1)
shopsPage.Visible = false
shopsPage.ZIndex = 21
shopsPage.Parent = contentFrame

local shopSelectorBar = Instance.new("ScrollingFrame")
shopSelectorBar.BackgroundTransparency = 1
shopSelectorBar.BorderSizePixel = 0
shopSelectorBar.Size = UDim2.new(1, 0, 0, 32)
shopSelectorBar.ScrollBarThickness = 4
shopSelectorBar.ScrollingDirection = Enum.ScrollingDirection.X
shopSelectorBar.CanvasSize = UDim2.fromOffset(0, 0)
shopSelectorBar.AutomaticCanvasSize = Enum.AutomaticSize.X
shopSelectorBar.ZIndex = 22
shopSelectorBar.Parent = shopsPage

local shopSelectorLayout = Instance.new("UIListLayout")
shopSelectorLayout.FillDirection = Enum.FillDirection.Horizontal
shopSelectorLayout.Padding = UDim.new(0, 8)
shopSelectorLayout.Parent = shopSelectorBar

local shopsList = Instance.new("ScrollingFrame")
shopsList.BackgroundTransparency = 1
shopsList.BorderSizePixel = 0
shopsList.Position = UDim2.fromOffset(0, 40)
shopsList.Size = UDim2.new(0.56, -8, 1, -40)
shopsList.ScrollBarThickness = 6
shopsList.CanvasSize = UDim2.fromOffset(0, 0)
shopsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopsList.ZIndex = 22
shopsList.Parent = shopsPage

local shopsListLayout = Instance.new("UIListLayout")
shopsListLayout.Padding = UDim.new(0, 6)
shopsListLayout.Parent = shopsList

local shopDetail = Instance.new("Frame")
shopDetail.BackgroundColor3 = THEME.PanelAlt
shopDetail.BorderSizePixel = 0
shopDetail.Position = UDim2.new(0.56, 8, 0, 40)
shopDetail.Size = UDim2.new(0.44, -8, 1, -40)
shopDetail.ZIndex = 21
shopDetail.Parent = shopsPage
createCorner(shopDetail, 7)

local shopDetailTitle = Instance.new("TextLabel")
shopDetailTitle.BackgroundTransparency = 1
shopDetailTitle.Font = Enum.Font.GothamBlack
shopDetailTitle.Position = UDim2.fromOffset(10, 10)
shopDetailTitle.Size = UDim2.new(1, -20, 0, 20)
shopDetailTitle.Text = "NO SHOP SELECTED"
shopDetailTitle.TextColor3 = THEME.Text
shopDetailTitle.TextSize = 14
shopDetailTitle.TextXAlignment = Enum.TextXAlignment.Left
shopDetailTitle.ZIndex = 22
shopDetailTitle.Parent = shopDetail

local shopDetailDesc = Instance.new("TextLabel")
shopDetailDesc.BackgroundTransparency = 1
shopDetailDesc.Font = Enum.Font.Gotham
shopDetailDesc.Position = UDim2.fromOffset(10, 34)
shopDetailDesc.Size = UDim2.new(1, -20, 0, 66)
shopDetailDesc.Text = ""
shopDetailDesc.TextColor3 = THEME.Muted
shopDetailDesc.TextSize = 12
shopDetailDesc.TextWrapped = true
shopDetailDesc.TextXAlignment = Enum.TextXAlignment.Left
shopDetailDesc.TextYAlignment = Enum.TextYAlignment.Top
shopDetailDesc.ZIndex = 22
shopDetailDesc.Parent = shopDetail

local shopCostList = Instance.new("Frame")
shopCostList.BackgroundTransparency = 1
shopCostList.Position = UDim2.fromOffset(10, 106)
shopCostList.Size = UDim2.new(1, -20, 1, -158)
shopCostList.ZIndex = 22
shopCostList.Parent = shopDetail

local shopCostListLayout = Instance.new("UIListLayout")
shopCostListLayout.Padding = UDim.new(0, 5)
shopCostListLayout.Parent = shopCostList

local shopBuyButton = createButton(shopDetail, "Buy", UDim2.fromOffset(120, 34), THEME.Good)
shopBuyButton.Position = UDim2.new(0, 10, 1, -44)
shopBuyButton.ZIndex = 22
shopBuyButton.Visible = false

local objectivesPage = Instance.new("Frame")
objectivesPage.Name = "ObjectivesPage"
objectivesPage.BackgroundTransparency = 1
objectivesPage.Size = UDim2.fromScale(1, 1)
objectivesPage.Visible = false
objectivesPage.ZIndex = 21
objectivesPage.Parent = contentFrame

local objectivesList = Instance.new("ScrollingFrame")
objectivesList.BackgroundTransparency = 1
objectivesList.BorderSizePixel = 0
objectivesList.Size = UDim2.new(1, 0, 1, 0)
objectivesList.ScrollBarThickness = 6
objectivesList.CanvasSize = UDim2.fromOffset(0, 0)
objectivesList.AutomaticCanvasSize = Enum.AutomaticSize.Y
objectivesList.ZIndex = 22
objectivesList.Parent = objectivesPage

local objectivesLayout = Instance.new("UIListLayout")
objectivesLayout.Padding = UDim.new(0, 6)
objectivesLayout.Parent = objectivesList

local worldPage = Instance.new("Frame")
worldPage.Name = "WorldPage"
worldPage.BackgroundTransparency = 1
worldPage.Size = UDim2.fromScale(1, 1)
worldPage.Visible = false
worldPage.ZIndex = 21
worldPage.Parent = contentFrame

local worldDetails = Instance.new("TextLabel")
worldDetails.BackgroundColor3 = THEME.PanelAlt
worldDetails.BackgroundTransparency = 0.05
worldDetails.BorderSizePixel = 0
worldDetails.Font = Enum.Font.GothamMedium
worldDetails.Position = UDim2.fromOffset(0, 0)
worldDetails.Size = UDim2.new(1, 0, 0, 130)
worldDetails.Text = ""
worldDetails.TextColor3 = THEME.Text
worldDetails.TextSize = 12
worldDetails.TextWrapped = true
worldDetails.TextXAlignment = Enum.TextXAlignment.Left
worldDetails.TextYAlignment = Enum.TextYAlignment.Top
worldDetails.ZIndex = 22
worldDetails.Parent = worldPage
createCorner(worldDetails, 7)

local worldRegions = Instance.new("TextLabel")
worldRegions.BackgroundColor3 = THEME.PanelAlt
worldRegions.BackgroundTransparency = 0.05
worldRegions.BorderSizePixel = 0
worldRegions.Font = Enum.Font.Gotham
worldRegions.Position = UDim2.fromOffset(0, 138)
worldRegions.Size = UDim2.new(1, 0, 1, -138)
worldRegions.Text = ""
worldRegions.TextColor3 = THEME.Muted
worldRegions.TextSize = 12
worldRegions.TextWrapped = true
worldRegions.TextXAlignment = Enum.TextXAlignment.Left
worldRegions.TextYAlignment = Enum.TextYAlignment.Top
worldRegions.ZIndex = 22
worldRegions.Parent = worldPage
createCorner(worldRegions, 7)

local popupStack = Instance.new("Frame")
popupStack.Name = "PopupStack"
popupStack.AnchorPoint = Vector2.new(1, 0)
popupStack.BackgroundTransparency = 1
popupStack.Position = UDim2.new(1, -156, 0.42, 0)
popupStack.Size = UDim2.fromOffset(160, 220)
popupStack.Parent = root

local popupLayout = Instance.new("UIListLayout")
popupLayout.Padding = UDim.new(0, 6)
popupLayout.Parent = popupStack

local function getInventoryCount(itemId)
	return (state.Inventory.Items and state.Inventory.Items[itemId]) or 0
end

local function getItemDisplayName(itemId)
	local itemConfig = Config.Items[itemId]
	return itemConfig and itemConfig.DisplayName or itemId
end

local function getItemCategory(itemId)
	local itemConfig = Config.Items[itemId]
	return itemConfig and itemConfig.Category or "Other"
end

local function showNotification(message, duration, color)
	if type(message) ~= "string" or message == "" then
		return
	end

	notificationToken += 1
	local token = notificationToken

	notificationLabel.Text = message
	notificationLabel.TextColor3 = color or THEME.Text
	notificationLabel.Visible = true

	task.delay(duration or 2.8, function()
		if notificationToken ~= token then
			return
		end
		notificationLabel.Visible = false
	end)
end

local function showResourcePopup(gains)
	if type(gains) ~= "table" then
		return
	end

	for _, gain in ipairs(gains) do
		local name = gain.DisplayName or (gain.ItemId and getItemDisplayName(gain.ItemId)) or "Resource"
		local amount = tonumber(gain.Amount) or 0
		if amount <= 0 then
			continue
		end

		resourcePopupToken += 1
		local token = resourcePopupToken

		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = THEME.Panel
		label.BackgroundTransparency = 0.14
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.Size = UDim2.fromOffset(160, 24)
		label.Text = string.format("+%d %s", amount, name)
		label.TextColor3 = gain.Color or THEME.Good
		label.TextSize = 12
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = popupStack
		createCorner(label, 6)

		task.delay(1.8, function()
			if resourcePopupToken < token then
				return
			end
			if label.Parent then
				label:Destroy()
			end
		end)
	end
end

local function setBarValue(ref, value)
	local clamped = math.max(0, math.min(100, value))
	ref.Fill.Size = UDim2.fromScale(clamp01(clamped / 100), 1)
	ref.Value.Text = tostring(math.floor(clamped + 0.5))
end

local function updateVitalsStatus()
	local statusNames = {}
	for statusId, statusState in pairs(state.Vitals.Statuses or {}) do
		local displayName = statusState.DisplayName or statusId
		table.insert(statusNames, string.format("%s %ds", displayName, math.max(0, math.floor((statusState.Remaining or 0) + 0.5))))
	end

	table.sort(statusNames)
	if #statusNames == 0 then
		vitalsStatus.Text = string.format("Temp %dF  Stable", math.floor((state.Vitals.Temperature or 72) + 0.5))
		vitalsStatus.TextColor3 = THEME.Muted
	else
		vitalsStatus.Text = table.concat(statusNames, "  |  ")
		vitalsStatus.TextColor3 = THEME.Warn
	end
end

local function updateVitals()
	setBarValue(barRefs.Health, state.Vitals.Health or 100)
	setBarValue(barRefs.Hunger, state.Vitals.Hunger or 100)
	setBarValue(barRefs.Thirst, state.Vitals.Thirst or 100)
	setBarValue(barRefs.Stamina, state.Stamina or 100)
	updateVitalsStatus()
end

local function updateWorldStrip()
	local nextLevel = state.Progression.NextLevelXP and tostring(state.Progression.NextLevelXP) or "max"
	worldStripText.Text = string.format(
		"Day %d  |  %s  |  %s  |  %s  |  Level %d  XP %d/%s",
		state.World.Day or 1,
		state.World.Clock or "00:00",
		state.World.Region or "Wilderness",
		state.World.Weather or "Clear",
		state.Progression.Level or 1,
		state.Progression.XP or 0,
		nextLevel
	)
end

local function getUsableItems()
	local usable = {}
	for itemId, count in pairs(state.Inventory.Items or {}) do
		if count > 0 and (Config.Buildables[itemId] or Config.Consumables[itemId] or Config.Equipment[itemId] or Config.Combat.Weapons[itemId]) then
			table.insert(usable, itemId)
		end
	end

	table.sort(usable, function(left, right)
		local leftPriority = QUICK_SLOT_PRIORITY[left] or 999
		local rightPriority = QUICK_SLOT_PRIORITY[right] or 999
		if leftPriority ~= rightPriority then
			return leftPriority < rightPriority
		end
		return getItemDisplayName(left) < getItemDisplayName(right)
	end)

	return usable
end

local function refreshQuickSlots()
	local usable = getUsableItems()
	state.QuickSlots = {}
	for index = 1, 8 do
		state.QuickSlots[index] = usable[index]
	end
end

local function updateQuickBar()
	refreshQuickSlots()
	for index, button in ipairs(quickSlotButtons) do
		local itemId = state.QuickSlots[index]
		local keyText = tostring(index)
		if itemId then
			local count = getInventoryCount(itemId)
			local short = ITEM_SHORT_NAMES[itemId] or getItemDisplayName(itemId)
			button.Text = string.format("%s\n%s x%d", keyText, short, count)
			button.BackgroundColor3 = THEME.PanelRaised
			if state.Inventory.Equipped.Weapon == itemId or state.Inventory.Equipped.Armor == itemId then
				button.BackgroundColor3 = THEME.Accent
			end
		else
			button.Text = keyText .. "\n-"
			button.BackgroundColor3 = THEME.Track
		end
	end
end

local function request(remoteName, ...)
	local args = table.pack(...)
	local ok, success, message = pcall(function()
		return Remotes.get(remoteName):InvokeServer(table.unpack(args, 1, args.n))
	end)

	if not ok then
		showNotification("Request failed.", 2.4, THEME.Bad)
		return false, "Request failed."
	end

	if success == false then
		if type(message) == "string" and message ~= "" then
			showNotification(message, 2.4, THEME.Bad)
		end
		return false, message
	end

	if type(message) == "string" and message ~= "" and remoteName ~= "AttackRequest" then
		showNotification(message, 1.6, THEME.Good)
	end

	return true, message
end

local function useItem(itemId)
	if not itemId or getInventoryCount(itemId) <= 0 then
		return
	end

	if Config.Buildables[itemId] then
		request("BuildRequest", itemId)
	elseif Config.Consumables[itemId] then
		request("ConsumeRequest", itemId)
	elseif Config.Equipment[itemId] then
		request("EquipRequest", itemId)
	elseif Config.Combat.Weapons[itemId] then
		request("EquipRequest", itemId)
		request("AttackRequest")
	else
		showNotification("Item is not directly usable.", 2, THEME.Muted)
	end
end

local function activateQuickSlot(index)
	local itemId = state.QuickSlots[index]
	if itemId then
		useItem(itemId)
	end
end

local function buildCostText(costMap)
	local parts = {}
	for itemId, amount in pairs(costMap or {}) do
		local owned = getInventoryCount(itemId)
		table.insert(parts, string.format("%s %d/%d", getItemDisplayName(itemId), owned, amount))
	end
	table.sort(parts)
	return table.concat(parts, "  |  ")
end

local function getRecipeListForCategory(categoryId)
	local recipes = {}
	local categoryConfig

	for _, category in ipairs(Config.CraftingCategories or {}) do
		if category.Id == categoryId then
			categoryConfig = category
			break
		end
	end

	if categoryConfig and type(categoryConfig.Recipes) == "table" then
		for _, recipeId in ipairs(categoryConfig.Recipes) do
			if Config.Crafting[recipeId] then
				table.insert(recipes, recipeId)
			end
		end
	else
		for recipeId in pairs(Config.Crafting or {}) do
			table.insert(recipes, recipeId)
		end
	end

	table.sort(recipes, function(left, right)
		return (Config.Crafting[left].DisplayName or left) < (Config.Crafting[right].DisplayName or right)
	end)

	return recipes
end

local function canAffordRecipe(recipe)
	for itemId, amount in pairs((recipe and recipe.Cost) or {}) do
		if getInventoryCount(itemId) < amount then
			return false
		end
	end
	return true
end

local function canAffordCost(costMap)
	for itemId, amount in pairs(costMap or {}) do
		if getInventoryCount(itemId) < amount then
			return false
		end
	end
	return true
end

local function hasRecipeLevel(recipe)
	if not recipe.RequiredLevel then
		return true
	end
	return (state.Progression.Level or 1) >= recipe.RequiredLevel
end

local function getSortedShopIds()
	local shops = {}

	for shopId, shopConfig in pairs(Config.Shops or {}) do
		table.insert(shops, {
			Id = shopId,
			Name = shopConfig.DisplayName or shopId,
		})
	end

	table.sort(shops, function(left, right)
		return left.Name < right.Name
	end)

	local shopIds = {}
	for _, shop in ipairs(shops) do
		table.insert(shopIds, shop.Id)
	end

	return shopIds
end

local function getFirstShopId()
	return getSortedShopIds()[1]
end

local function getShopEntries(shopConfig)
	local entries = {}
	for _, entry in ipairs(shopConfig.Catalog or {}) do
		if type(entry.Id) == "string" and type(entry.ItemId) == "string" and Config.Items[entry.ItemId] then
			table.insert(entries, entry)
		end
	end

	table.sort(entries, function(left, right)
		local leftName = left.DisplayName or getItemDisplayName(left.ItemId)
		local rightName = right.DisplayName or getItemDisplayName(right.ItemId)
		return leftName < rightName
	end)

	return entries
end

local function renderInventory()
	clearChildren(inventoryList)

	local list = {}
	for itemId, count in pairs(state.Inventory.Items or {}) do
		if count > 0 then
			table.insert(list, {
				Id = itemId,
				Count = count,
				Name = getItemDisplayName(itemId),
				Category = getItemCategory(itemId),
			})
		end
	end

	table.sort(list, function(left, right)
		if left.Category ~= right.Category then
			return left.Category < right.Category
		end
		return left.Name < right.Name
	end)

	for index, entry in ipairs(list) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = THEME.PanelAlt
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 58)
		row.ZIndex = 22
		row.Parent = inventoryList
		createCorner(row, 6)

		local icon = createItemThumbnail(row, entry.Id)
		icon.Position = UDim2.fromOffset(8, 7)
		icon.ZIndex = 24

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.Position = UDim2.fromOffset(60, 6)
		title.Size = UDim2.new(1, -210, 0, 16)
		title.Text = string.format("%s x%d", entry.Name, entry.Count)
		title.TextColor3 = THEME.Text
		title.TextSize = 12
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = 23
		title.Parent = row

		local detailParts = { entry.Category }
		local durabilityValue = state.Inventory.Durability[entry.Id]
		local durabilityMax = Config.Equipment[entry.Id] and Config.Equipment[entry.Id].MaxDurability
		if durabilityValue and durabilityMax then
			table.insert(detailParts, string.format("Durability %d/%d", durabilityValue, durabilityMax))
		end

		local details = Instance.new("TextLabel")
		details.BackgroundTransparency = 1
		details.Font = Enum.Font.Gotham
		details.Position = UDim2.fromOffset(60, 24)
		details.Size = UDim2.new(1, -210, 0, 14)
		details.Text = table.concat(detailParts, "  |  ")
		details.TextColor3 = THEME.Muted
		details.TextSize = 11
		details.TextXAlignment = Enum.TextXAlignment.Left
		details.ZIndex = 23
		details.Parent = row

		local rightButtons = Instance.new("Frame")
		rightButtons.BackgroundTransparency = 1
		rightButtons.AnchorPoint = Vector2.new(1, 0.5)
		rightButtons.Position = UDim2.new(1, -8, 0.5, 0)
		rightButtons.Size = UDim2.fromOffset(140, 30)
		rightButtons.ZIndex = 23
		rightButtons.Parent = row

		local rightLayout = Instance.new("UIListLayout")
		rightLayout.FillDirection = Enum.FillDirection.Horizontal
		rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		rightLayout.Padding = UDim.new(0, 6)
		rightLayout.Parent = rightButtons

		if Config.Consumables[entry.Id] then
			local useButton = createButton(rightButtons, "Use", UDim2.fromOffset(56, 26), THEME.Good)
			useButton.ZIndex = 24
			useButton.Activated:Connect(function()
				request("ConsumeRequest", entry.Id)
			end)
		end

		if Config.Buildables[entry.Id] then
			local placeButton = createButton(rightButtons, "Place", UDim2.fromOffset(56, 26), THEME.Accent)
			placeButton.ZIndex = 24
			placeButton.Activated:Connect(function()
				request("BuildRequest", entry.Id)
			end)
		end

		if Config.Equipment[entry.Id] then
			local equipButton = createButton(rightButtons, "Equip", UDim2.fromOffset(56, 26), THEME.PanelRaised)
			equipButton.ZIndex = 24
			equipButton.Activated:Connect(function()
				request("EquipRequest", entry.Id)
			end)
		end
	end

	local weapon = state.Inventory.Equipped.Weapon and getItemDisplayName(state.Inventory.Equipped.Weapon) or "None"
	local armor = state.Inventory.Equipped.Armor and getItemDisplayName(state.Inventory.Equipped.Armor) or "None"
	equipmentSummary.Text = string.format("Weapon: %s\nArmor: %s\n\nTip: trees need an axe, rocks and iron need a pickaxe.", weapon, armor)
end

local function refreshCraftCategoryButtons()
	for categoryId, button in pairs(craftCategoryButtons) do
		button.BackgroundColor3 = categoryId == state.ActiveCraftCategory and THEME.Accent or THEME.PanelRaised
	end
end

local function ensureCraftCategories()
	if next(craftCategoryButtons) then
		refreshCraftCategoryButtons()
		return
	end

	local categories = Config.CraftingCategories or {}
	for index, category in ipairs(categories) do
		local button = createButton(craftCategoryBar, category.DisplayName or category.Id, UDim2.fromOffset(112, 28), THEME.PanelRaised)
		button.LayoutOrder = index
		button.ZIndex = 23
		craftCategoryButtons[category.Id] = button
		button.Activated:Connect(function()
			state.ActiveCraftCategory = category.Id
			state.SelectedRecipeId = nil
			refreshCraftCategoryButtons()
			renderCrafting()
		end)
	end

	refreshCraftCategoryButtons()
end

renderCrafting = function()
	ensureCraftCategories()
	clearChildren(craftList)

	local recipeIds = getRecipeListForCategory(state.ActiveCraftCategory)
	for index, recipeId in ipairs(recipeIds) do
		local recipe = Config.Crafting[recipeId]
		local affordable = canAffordRecipe(recipe)
		local levelReady = hasRecipeLevel(recipe)

		local row = createButton(craftList, "", UDim2.new(1, -8, 0, 58), affordable and THEME.PanelAlt or THEME.Track)
		row.LayoutOrder = index
		row.Text = ""
		row.ZIndex = 23

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.Position = UDim2.fromOffset(10, 6)
		title.Size = UDim2.new(1, -20, 0, 16)
		title.Text = recipe.DisplayName or recipeId
		title.TextColor3 = levelReady and THEME.Text or THEME.Warn
		title.TextSize = 12
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = 24
		title.Parent = row

		local cost = Instance.new("TextLabel")
		cost.BackgroundTransparency = 1
		cost.Font = Enum.Font.Gotham
		cost.Position = UDim2.fromOffset(10, 24)
		cost.Size = UDim2.new(1, -20, 0, 30)
		cost.Text = buildCostText(recipe.Cost)
		cost.TextColor3 = affordable and THEME.Muted or THEME.Warn
		cost.TextSize = 11
		cost.TextWrapped = true
		cost.TextXAlignment = Enum.TextXAlignment.Left
		cost.TextYAlignment = Enum.TextYAlignment.Top
		cost.ZIndex = 24
		cost.Parent = row

		row.Activated:Connect(function()
			state.SelectedRecipeId = recipeId
			renderCrafting()
		end)
	end

	local recipe = state.SelectedRecipeId and Config.Crafting[state.SelectedRecipeId] or nil
	if not recipe then
		craftDetailTitle.Text = "SELECT RECIPE"
		craftDetailDesc.Text = "Choose a recipe from the left list."
		clearChildren(craftRequirements)
		craftButton.Visible = false
		return
	end

	craftDetailTitle.Text = recipe.DisplayName or state.SelectedRecipeId
	craftDetailDesc.Text = recipe.Description or ""

	clearChildren(craftRequirements)
	for itemId, amount in pairs(recipe.Cost or {}) do
		local owned = getInventoryCount(itemId)
		local requirement = Instance.new("TextLabel")
		requirement.BackgroundTransparency = 1
		requirement.Font = Enum.Font.Gotham
		requirement.Size = UDim2.new(1, 0, 0, 16)
		requirement.Text = string.format("%s %d/%d", getItemDisplayName(itemId), owned, amount)
		requirement.TextColor3 = owned >= amount and THEME.Good or THEME.Warn
		requirement.TextSize = 11
		requirement.TextXAlignment = Enum.TextXAlignment.Left
		requirement.ZIndex = 23
		requirement.Parent = craftRequirements
	end

	if recipe.RequiredLevel then
		local levelLabel = Instance.new("TextLabel")
		levelLabel.BackgroundTransparency = 1
		levelLabel.Font = Enum.Font.Gotham
		levelLabel.Size = UDim2.new(1, 0, 0, 16)
		levelLabel.Text = string.format("Required level: %d", recipe.RequiredLevel)
		levelLabel.TextColor3 = hasRecipeLevel(recipe) and THEME.Good or THEME.Warn
		levelLabel.TextSize = 11
		levelLabel.TextXAlignment = Enum.TextXAlignment.Left
		levelLabel.ZIndex = 23
		levelLabel.Parent = craftRequirements
	end

	if recipe.RequiresNearby then
		local stationLabel = Instance.new("TextLabel")
		stationLabel.BackgroundTransparency = 1
		stationLabel.Font = Enum.Font.Gotham
		stationLabel.Size = UDim2.new(1, 0, 0, 16)
		stationLabel.Text = string.format("Station: %s", tostring(recipe.RequiresNearby))
		stationLabel.TextColor3 = THEME.Muted
		stationLabel.TextSize = 11
		stationLabel.TextXAlignment = Enum.TextXAlignment.Left
		stationLabel.ZIndex = 23
		stationLabel.Parent = craftRequirements
	end

	craftButton.Visible = true
	craftButton.BackgroundColor3 = (canAffordRecipe(recipe) and hasRecipeLevel(recipe)) and THEME.Good or THEME.Track
end

renderShops = function()
	clearChildren(shopSelectorBar)
	clearChildren(shopsList)
	clearChildren(shopCostList)

	if not state.ActiveShopId or not (Config.Shops and Config.Shops[state.ActiveShopId]) then
		state.ActiveShopId = getFirstShopId()
		state.SelectedShopEntryId = nil
	end

	local shopConfig = state.ActiveShopId and Config.Shops and Config.Shops[state.ActiveShopId] or nil
	if not shopConfig then
		shopDetailTitle.Text = "NO SHOPS"
		shopDetailDesc.Text = "No shop is configured."
		shopBuyButton.Visible = false
		return
	end

	for index, shopId in ipairs(getSortedShopIds()) do
		local optionConfig = Config.Shops[shopId]
		local button = createButton(
			shopSelectorBar,
			optionConfig.DisplayName or shopId,
			UDim2.fromOffset(132, 28),
			shopId == state.ActiveShopId and THEME.Accent or THEME.PanelRaised
		)
		button.LayoutOrder = index
		button.ZIndex = 23
		button.TextSize = 11
		button.Activated:Connect(function()
			state.ActiveShopId = shopId
			state.SelectedShopEntryId = nil
			renderShops()
		end)
	end

	local entries = getShopEntries(shopConfig)
	for index, entry in ipairs(entries) do
		local affordable = canAffordCost(entry.Cost)
		local row = createButton(shopsList, "", UDim2.new(1, -8, 0, 58), affordable and THEME.PanelAlt or THEME.Track)
		row.LayoutOrder = index
		row.Text = ""
		row.ZIndex = 23

		local entryTitle = Instance.new("TextLabel")
		entryTitle.BackgroundTransparency = 1
		entryTitle.Font = Enum.Font.GothamBold
		entryTitle.Position = UDim2.fromOffset(10, 6)
		entryTitle.Size = UDim2.new(1, -20, 0, 16)
		entryTitle.Text = string.format("%s x%d", entry.DisplayName or getItemDisplayName(entry.ItemId), math.max(1, tonumber(entry.Amount) or 1))
		entryTitle.TextColor3 = THEME.Text
		entryTitle.TextSize = 12
		entryTitle.TextXAlignment = Enum.TextXAlignment.Left
		entryTitle.ZIndex = 24
		entryTitle.Parent = row

		local costLabel = Instance.new("TextLabel")
		costLabel.BackgroundTransparency = 1
		costLabel.Font = Enum.Font.Gotham
		costLabel.Position = UDim2.fromOffset(10, 24)
		costLabel.Size = UDim2.new(1, -20, 0, 30)
		costLabel.Text = buildCostText(entry.Cost)
		costLabel.TextColor3 = affordable and THEME.Muted or THEME.Warn
		costLabel.TextSize = 11
		costLabel.TextWrapped = true
		costLabel.TextXAlignment = Enum.TextXAlignment.Left
		costLabel.TextYAlignment = Enum.TextYAlignment.Top
		costLabel.ZIndex = 24
		costLabel.Parent = row

		row.Activated:Connect(function()
			state.SelectedShopEntryId = entry.Id
			renderShops()
		end)
	end

	if not state.SelectedShopEntryId and entries[1] then
		state.SelectedShopEntryId = entries[1].Id
	end

	local selectedEntry
	for _, entry in ipairs(entries) do
		if entry.Id == state.SelectedShopEntryId then
			selectedEntry = entry
			break
		end
	end

	shopDetailTitle.Text = string.upper(shopConfig.DisplayName or state.ActiveShopId)
	shopDetailDesc.Text = shopConfig.Description or "Trade resources for items."

	if not selectedEntry then
		shopBuyButton.Visible = false
		return
	end

	local selectedName = selectedEntry.DisplayName or getItemDisplayName(selectedEntry.ItemId)
	local selectedAmount = math.max(1, tonumber(selectedEntry.Amount) or 1)
	shopDetailTitle.Text = string.format("%s x%d", selectedName, selectedAmount)
	shopDetailDesc.Text = shopConfig.Description or "Trade resources for items."

	for itemId, amount in pairs(selectedEntry.Cost or {}) do
		local owned = getInventoryCount(itemId)
		local costRow = Instance.new("TextLabel")
		costRow.BackgroundTransparency = 1
		costRow.Font = Enum.Font.Gotham
		costRow.Size = UDim2.new(1, 0, 0, 16)
		costRow.Text = string.format("%s %d/%d", getItemDisplayName(itemId), owned, amount)
		costRow.TextColor3 = owned >= amount and THEME.Good or THEME.Warn
		costRow.TextSize = 11
		costRow.TextXAlignment = Enum.TextXAlignment.Left
		costRow.ZIndex = 23
		costRow.Parent = shopCostList
	end

	shopBuyButton.Visible = true
	shopBuyButton.BackgroundColor3 = canAffordCost(selectedEntry.Cost) and THEME.Good or THEME.Track
end

local function renderObjectives()
	clearChildren(objectivesList)

	for index, objective in ipairs(state.Objectives.Objectives or {}) do
		local completed = objective.Completed == true
		local row = Instance.new("Frame")
		row.BackgroundColor3 = completed and Color3.fromRGB(36, 61, 40) or THEME.PanelAlt
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 72)
		row.ZIndex = 22
		row.Parent = objectivesList
		createCorner(row, 6)

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.Position = UDim2.fromOffset(10, 6)
		title.Size = UDim2.new(1, -20, 0, 18)
		title.Text = completed and (objective.DisplayName .. "  DONE") or objective.DisplayName
		title.TextColor3 = THEME.Text
		title.TextSize = 12
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = 23
		title.Parent = row

		local description = Instance.new("TextLabel")
		description.BackgroundTransparency = 1
		description.Font = Enum.Font.Gotham
		description.Position = UDim2.fromOffset(10, 26)
		description.Size = UDim2.new(1, -20, 0, 28)
		description.Text = objective.Description or ""
		description.TextColor3 = THEME.Muted
		description.TextSize = 11
		description.TextWrapped = true
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.TextYAlignment = Enum.TextYAlignment.Top
		description.ZIndex = 23
		description.Parent = row

		local progress = Instance.new("TextLabel")
		progress.BackgroundTransparency = 1
		progress.Font = Enum.Font.GothamMedium
		progress.Position = UDim2.fromOffset(10, 54)
		progress.Size = UDim2.new(1, -20, 0, 14)
		progress.Text = objective.Progress or ""
		progress.TextColor3 = completed and THEME.Good or THEME.Accent
		progress.TextSize = 11
		progress.TextXAlignment = Enum.TextXAlignment.Left
		progress.ZIndex = 23
		progress.Parent = row
	end
end

local function renderWorldPage()
	local phase = state.World.IsNight and "Night" or "Day"
	local threat = state.World.Threat and tostring(state.World.Threat) or "-"
	local nextLevel = state.Progression.NextLevelXP and tostring(state.Progression.NextLevelXP) or "max"

	worldDetails.Text = string.format(
		"Day %d\nClock: %s\nRegion: %s\nWeather: %s\nPhase: %s\nThreat: %s\nLevel %d  XP %d/%s\nSave: %s",
		state.World.Day or 1,
		state.World.Clock or "00:00",
		state.World.Region or "Wilderness",
		state.World.Weather or "Clear",
		phase,
		threat,
		state.Progression.Level or 1,
		state.Progression.XP or 0,
		nextLevel,
		state.Save.Text or "Pending"
	)

	local discoveredNames = {}
	for _, region in ipairs(Config.Regions or {}) do
		if state.World.DiscoveredRegions and state.World.DiscoveredRegions[region.Id] then
			table.insert(discoveredNames, region.DisplayName)
		end
	end

	table.sort(discoveredNames)

	if #discoveredNames == 0 then
		worldRegions.Text = "Discovered Regions:\nNone yet."
	else
		worldRegions.Text = "Discovered Regions:\n" .. table.concat(discoveredNames, "\n")
	end
end

local function setTab(tabName)
	state.ActiveTab = tabName
	inventoryPage.Visible = tabName == "Inventory"
	craftingPage.Visible = tabName == "Crafting"
	shopsPage.Visible = tabName == "Shops"
	objectivesPage.Visible = tabName == "Objectives"
	worldPage.Visible = tabName == "World"

	for name, button in pairs(tabButtons) do
		button.BackgroundColor3 = name == tabName and THEME.Accent or THEME.PanelRaised
	end

	if tabName == "Inventory" then
		renderInventory()
	elseif tabName == "Crafting" then
		renderCrafting()
	elseif tabName == "Shops" then
		renderShops()
	elseif tabName == "Objectives" then
		renderObjectives()
	elseif tabName == "World" then
		renderWorldPage()
	end
end

local function setMenuOpen(open)
	state.MenuOpen = open
	menuFrame.Visible = open
	if open then
		setTab(state.ActiveTab)
	end
end

local function refreshHud()
	updateVitals()
	updateWorldStrip()
	updateQuickBar()
	if state.MenuOpen then
		setTab(state.ActiveTab)
	end
end

local itemAnim = {
	EquippedItemId = nil,
	LastItemId = nil,
	EquipTime = 0,
	SwingTime = 0,
	HarvestTime = 0,
	HitFlashTime = 0,
	CritFlashTime = 0,
	EquipPulse = 0,
	SwingPulse = 0,
	HarvestPulse = 0,
	HitPulse = 0,
	CritPulse = 0,
	BobPhase = 0,
	Roll = 0,
	Pitch = 0,
}

local ITEM_ANIM = {
	EquipDuration = 0.18,
	SwingDuration = 0.22,
	HarvestDuration = 0.24,
	HitDuration = 0.14,
	CritDuration = 0.22,
	BobSpeed = 8.5,
	BobAmount = 0.035,
	SwingAmount = 0.11,
	HarvestAmount = 0.095,
	HitAmount = 0.07,
	CritAmount = 0.1,
}

local function getEquippedHeldItemId()
	local inventory = state.Inventory
	if type(inventory) ~= "table" then
		return nil
	end

	local equipped = inventory.Equipped
	if type(equipped) == "table" then
		local held = equipped.Weapon or equipped.Tool or equipped.EquippedItem or equipped.ActiveItem
		if type(held) == "string" and held ~= "" then
			return held
		end
	end

	if type(equipped) == "string" and equipped ~= "" then
		return equipped
	end

	return nil
end

local function getHeldItemKind(itemId)
	if not itemId then
		return "None"
	end

	if itemId == "StoneAxe" or itemId == "Pickaxe" then
		return "Tool"
	elseif itemId == "Spear" or itemId == "IronSpear" then
		return "Weapon"
	elseif itemId == "Bandage" or itemId == "SurvivalTonic" or itemId == "Antidote" or itemId == "CookedBerries" or itemId == "CookedMeat" or itemId == "MushroomStew" then
		return "Consumable"
	end

	return "Item"
end

local function triggerEquipAnimation(itemId)
	if itemAnim.LastItemId == itemId then
		return
	end

	itemAnim.LastItemId = itemId
	itemAnim.EquippedItemId = itemId
	itemAnim.EquipTime = 0
	itemAnim.EquipPulse = 1
	attachItemViewModel(itemId)
end

local function triggerAttackAnimation()
	itemAnim.SwingTime = 0
	itemAnim.SwingPulse = 1
end

local function triggerHarvestAnimation(resourceId)
	itemAnim.HarvestTime = 0
	itemAnim.HarvestPulse = 1
	if resourceId == "Tree" or resourceId == "Wood" then
		itemAnim.EquippedItemId = itemAnim.EquippedItemId or "StoneAxe"
	elseif resourceId == "Rock" or resourceId == "IronDeposit" then
		itemAnim.EquippedItemId = itemAnim.EquippedItemId or "Pickaxe"
	end
end

local function triggerHitPulse(isCrit)
	itemAnim.HitFlashTime = 0
	itemAnim.HitPulse = 1
	if isCrit then
		itemAnim.CritFlashTime = 0
		itemAnim.CritPulse = 1
	end
end

local itemViewModel = {
	model = nil,
	toolId = nil,
	baseCFrame = CFrame.new(0.7, -0.9, -1.35),
	animTime = 0,
}

local function getItemViewModelTemplate(itemId)
	local container = ReplicatedStorage:FindFirstChild("ItemViewModels")
	if not container then
		return nil
	end

	return container:FindFirstChild(itemId) or container:FindFirstChild("Default")
end

local function clearItemViewModel()
	if itemViewModel.model then
		itemViewModel.model:Destroy()
		itemViewModel.model = nil
		itemViewModel.toolId = nil
		itemViewModel.animTime = 0
	end
end

local function attachItemViewModel(itemId)
	local template = getItemViewModelTemplate(itemId)
	if not template or not workspace.CurrentCamera then
		return
	end

	clearItemViewModel()
	local clone = template:Clone()
	clone.Name = "ClientItemViewModel"
	clone.Parent = workspace.CurrentCamera
	itemViewModel.model = clone
	itemViewModel.toolId = itemId
	itemViewModel.animTime = 0
	itemAnim.EquipPulse = 1
	attachItemViewModel(itemId)
end

local function updateItemViewModel(deltaTime)
	if not itemViewModel.model or not workspace.CurrentCamera then
		return
	end

	itemViewModel.animTime += deltaTime
	local cam = workspace.CurrentCamera
	local bob = math.sin(itemViewModel.animTime * 8.5) * 0.02
	local sway = math.cos(itemViewModel.animTime * 6.5) * 0.015
	local attack = itemAnim.SwingPulse * 0.05
	local harvest = itemAnim.HarvestPulse * 0.04
	local hit = itemAnim.HitPulse * 0.03
	itemViewModel.model:PivotTo(cam.CFrame * itemViewModel.baseCFrame * CFrame.new(sway, bob - attack - harvest - hit, 0) * CFrame.Angles(itemAnim.Pitch * 0.35, -itemAnim.Roll * 0.5, 0))
end

local function updateItemAnimation(deltaTime)
	local equipped = getEquippedHeldItemId()
	if equipped ~= itemAnim.EquippedItemId then
		triggerEquipAnimation(equipped)
		if not equipped then
			clearItemViewModel()
		end
	end

	itemAnim.BobPhase += deltaTime * ITEM_ANIM.BobSpeed
	itemAnim.EquipTime = math.min(ITEM_ANIM.EquipDuration, itemAnim.EquipTime + deltaTime)
	itemAnim.SwingTime = math.min(ITEM_ANIM.SwingDuration, itemAnim.SwingTime + deltaTime)
	itemAnim.HarvestTime = math.min(ITEM_ANIM.HarvestDuration, itemAnim.HarvestTime + deltaTime)
	itemAnim.HitFlashTime = math.min(ITEM_ANIM.HitDuration, itemAnim.HitFlashTime + deltaTime)
	itemAnim.CritFlashTime = math.min(ITEM_ANIM.CritDuration, itemAnim.CritFlashTime + deltaTime)

	local equipAlpha = 1 - (itemAnim.EquipTime / ITEM_ANIM.EquipDuration)
	local swingAlpha = 1 - (itemAnim.SwingTime / ITEM_ANIM.SwingDuration)
	local harvestAlpha = 1 - (itemAnim.HarvestTime / ITEM_ANIM.HarvestDuration)
	local hitAlpha = 1 - (itemAnim.HitFlashTime / ITEM_ANIM.HitDuration)
	local critAlpha = 1 - (itemAnim.CritFlashTime / ITEM_ANIM.CritDuration)

	itemAnim.EquipPulse = math.max(0, itemAnim.EquipPulse - deltaTime * 5)
	itemAnim.SwingPulse = math.max(0, itemAnim.SwingPulse - deltaTime * 6)
	itemAnim.HarvestPulse = math.max(0, itemAnim.HarvestPulse - deltaTime * 6)
	itemAnim.HitPulse = math.max(0, itemAnim.HitPulse - deltaTime * 8)
	itemAnim.CritPulse = math.max(0, itemAnim.CritPulse - deltaTime * 8)

	local bob = math.sin(itemAnim.BobPhase) * ITEM_ANIM.BobAmount
	local bob2 = math.cos(itemAnim.BobPhase * 0.5) * ITEM_ANIM.BobAmount * 0.6
	local equipKick = ITEM_ANIM.BobAmount * 1.2 * equipAlpha * itemAnim.EquipPulse
	local swingKick = ITEM_ANIM.SwingAmount * swingAlpha * itemAnim.SwingPulse
	local harvestKick = ITEM_ANIM.HarvestAmount * harvestAlpha * itemAnim.HarvestPulse
	local hitKick = ITEM_ANIM.HitAmount * hitAlpha * itemAnim.HitPulse
	local critKick = ITEM_ANIM.CritAmount * critAlpha * itemAnim.CritPulse

	local kind = getHeldItemKind(equipped)
	local itemWeight = kind == "Weapon" and 1.0 or (kind == "Tool" and 0.85 or 0.6)

	itemAnim.Roll = (bob * 0.8 + swingKick * 0.55 - harvestKick * 0.45) * itemWeight
	itemAnim.Pitch = (bob2 * 0.6 - equipKick * 1.1 - hitKick * 0.9 - critKick * 1.25) * itemWeight

	if playerGui and playerGui:FindFirstChild("Hud") then
		local hud = playerGui.Hud
		local quickBar = hud:FindFirstChild("QuickBar")
		if quickBar and quickBar:IsA("Frame") then
			quickBar.Rotation = itemAnim.Roll * 10
			quickBar.Position = UDim2.new(quickBar.Position.X.Scale, quickBar.Position.X.Offset, quickBar.Position.Y.Scale, quickBar.Position.Y.Offset + math.floor((itemAnim.Pitch + swingKick) * 8))
		end
	end

	if workspace.CurrentCamera then
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CFrame.Angles(itemAnim.Pitch, 0, -itemAnim.Roll)
	end
end

local function requestAttack()
	triggerAttackAnimation()
	request("AttackRequest")
end

local function setSprintRequested(value)
	state.SprintRequested = value
	sprintButton.BackgroundColor3 = value and THEME.Accent or THEME.Good
end

local function getHumanoid()
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHeadPart()
	local character = player.Character
	return character and character:FindFirstChild("Head")
end

local function isSurvivalWaterPart(part)
	if not part or not part:IsA("BasePart") then
		return false
	end

	return part:GetAttribute("SurvivalSwimWater") == true
end

local function rebuildSwimWaterParts()
	local found = {}

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isSurvivalWaterPart(descendant) then
			table.insert(found, descendant)
		end
	end

	swimWaterParts = found
	swimWaterPartsDirty = false
end

local function getTrackedSwimWaterParts()
	if swimWaterPartsDirty then
		rebuildSwimWaterParts()
	end

	return swimWaterParts
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") and descendant:GetAttribute("SurvivalSwimWater") == true then
		swimWaterPartsDirty = true
	end
end)

Workspace.DescendantRemoving:Connect(function(descendant)
	if descendant:IsA("BasePart") and descendant:GetAttribute("SurvivalSwimWater") == true then
		swimWaterPartsDirty = true
	end
end)

local function getWaterContact(root)
	local trackedWaterParts = getTrackedSwimWaterParts()

	for index = #trackedWaterParts, 1, -1 do
		local part = trackedWaterParts[index]

		if not part or not part.Parent then
			table.remove(trackedWaterParts, index)
		else
			local localPosition = part.CFrame:PointToObjectSpace(root.Position)
			local halfSize = part.Size * 0.5
			local insideHorizontal = math.abs(localPosition.X) <= halfSize.X + 1.5
				and math.abs(localPosition.Z) <= halfSize.Z + 1.5
			local nearSurface = localPosition.Y <= halfSize.Y + WATER_FLOAT_SURFACE_EXIT_OFFSET and localPosition.Y >= -12

			if insideHorizontal and nearSurface then
				local surfacePosition = part.CFrame:PointToWorldSpace(Vector3.new(localPosition.X, halfSize.Y, localPosition.Z))
				return {
					Part = part,
					SurfaceY = surfacePosition.Y,
				}
			end
		end
	end

	return nil
end

local function clearSwimOrientation()
	if activeSwimOrientation then
		activeSwimOrientation:Destroy()
	end

	if activeSwimAttachment then
		activeSwimAttachment:Destroy()
	end

	if activeSwimHumanoid and activeSwimAutoRotate ~= nil then
		activeSwimHumanoid.AutoRotate = activeSwimAutoRotate
	end

	activeSwimOrientation = nil
	activeSwimAttachment = nil
	activeSwimAutoRotate = nil
	activeSwimForward = nil
end

local function stopSwimAnimation(clearWaterContact)
	if activeSwimTrack then
		activeSwimTrack:Stop(0.18)
	end

	if activeSwimIdleTrack then
		activeSwimIdleTrack:Stop(0.18)
	end

	clearSwimOrientation()
	activeSwimTrack = nil
	activeSwimIdleTrack = nil
	activeSwimHumanoid = nil

	if clearWaterContact then
		activeWaterSurfaceY = nil
	end
end

local function getSwimTracks(humanoid)
	if activeSwimTrack and activeSwimIdleTrack and activeSwimHumanoid == humanoid then
		return activeSwimTrack, activeSwimIdleTrack
	end

	if activeSwimHumanoid and activeSwimHumanoid ~= humanoid then
		stopSwimAnimation(false)
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local okMove, moveTrack = pcall(function()
		return animator:LoadAnimation(swimMoveAnimation)
	end)

	local okIdle, idleTrack = pcall(function()
		return animator:LoadAnimation(swimIdleAnimation)
	end)

	if not okMove or not moveTrack or not okIdle or not idleTrack then
		return nil
	end

	moveTrack.Priority = Enum.AnimationPriority.Movement
	moveTrack.Looped = true
	idleTrack.Priority = Enum.AnimationPriority.Movement
	idleTrack.Looped = true
	activeSwimHumanoid = humanoid
	activeSwimTrack = moveTrack
	activeSwimIdleTrack = idleTrack
	return moveTrack, idleTrack
end

local function getHorizontalSwimDirection(root, humanoid)
	local moveDirection = humanoid.MoveDirection
	local flatMove = Vector3.new(moveDirection.X, 0, moveDirection.Z)
	if flatMove.Magnitude > 0.05 then
		activeSwimForward = flatMove.Unit
		return activeSwimForward
	end

	if activeSwimForward then
		return activeSwimForward
	end

	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.05 then
		activeSwimForward = flatLook.Unit
	else
		activeSwimForward = Vector3.new(0, 0, -1)
	end

	return activeSwimForward
end

local function updateSwimOrientation(root, humanoid, deltaTime)
	if activeSwimHumanoid and activeSwimHumanoid ~= humanoid then
		stopSwimAnimation(false)
	end

	if not activeSwimAttachment or activeSwimAttachment.Parent ~= root then
		clearSwimOrientation()

		activeSwimAttachment = Instance.new("Attachment")
		activeSwimAttachment.Name = "SurvivalSwimAttachment"
		activeSwimAttachment.Parent = root

		activeSwimOrientation = Instance.new("AlignOrientation")
		activeSwimOrientation.Name = "SurvivalSwimOrientation"
		activeSwimOrientation.Attachment0 = activeSwimAttachment
		activeSwimOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		activeSwimOrientation.RigidityEnabled = false
		activeSwimOrientation.Responsiveness = SWIM_ORIENTATION_RESPONSIVENESS
		activeSwimOrientation.MaxTorque = SWIM_ORIENTATION_MAX_TORQUE
		activeSwimOrientation.Parent = root
	end

	if activeSwimAutoRotate == nil then
		activeSwimAutoRotate = humanoid.AutoRotate
	end

	humanoid.AutoRotate = false
	activeSwimHumanoid = humanoid

	local forward = getHorizontalSwimDirection(root, humanoid)
	local worldUp = Vector3.new(0, 1, 0)
	local bodyAxis = (forward + worldUp * SWIM_HEAD_LIFT).Unit
	local right = bodyAxis:Cross(worldUp)
	if right.Magnitude <= 0.01 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end
	local back = right:Cross(bodyAxis).Unit
	local targetCFrame = CFrame.fromMatrix(root.Position, right, bodyAxis, back)

	activeSwimOrientation.CFrame = targetCFrame - targetCFrame.Position
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = root.CFrame:Lerp(targetCFrame, math.clamp(deltaTime * SWIM_HORIZONTAL_SNAP_RATE, 0, 1))
end

local function getSubmergedSwimRootTarget(root)
	local fallbackRootY = activeWaterSurfaceY + WATER_FLOAT_ROOT_OFFSET
	local head = getHeadPart()
	if not head then
		return fallbackRootY
	end

	local headOffsetY = math.clamp(head.Position.Y - root.Position.Y, 0.45, 1.35)
	local headVisibleRootY = activeWaterSurfaceY + WATER_HEAD_VISIBLE_HEIGHT - headOffsetY
	return math.clamp(headVisibleRootY, activeWaterSurfaceY - 1.45, activeWaterSurfaceY - 0.55)
end

local function updateSwimming(deltaTime)
	local humanoid = getHumanoid()
	local root = getRootPart()
	if not humanoid or humanoid.Health <= 0 or not root then
		stopSwimAnimation(true)
		return
	end

	waterScanAccumulator += deltaTime
	if waterScanAccumulator >= WATER_SCAN_INTERVAL_SECONDS then
		waterScanAccumulator = 0
		local contact = getWaterContact(root)
		activeWaterSurfaceY = contact and contact.SurfaceY or nil
	end

	if not activeWaterSurfaceY then
		stopSwimAnimation(true)
		return
	end

	local targetRootY = getSubmergedSwimRootTarget(root)
	local velocity = root.AssemblyLinearVelocity
	if root.Position.Y < targetRootY then
		local lift = math.clamp((targetRootY - root.Position.Y) * 9, 4, 22)
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, lift), velocity.Z)
	elseif root.Position.Y < targetRootY + 1.2 and velocity.Y < -1.2 then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, -1.2, velocity.Z)
	end

	local deepEnoughToSwim = root.Position.Y <= activeWaterSurfaceY - WATER_SWIM_ROOT_TRIGGER_DEPTH
	if not deepEnoughToSwim then
		stopSwimAnimation(false)
		return
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	updateSwimOrientation(root, humanoid, deltaTime)

	local moveTrack, idleTrack = getSwimTracks(humanoid)
	if not moveTrack or not idleTrack then
		return
	end

	local moving = humanoid.MoveDirection.Magnitude > 0.05
	if moving then
		if idleTrack.IsPlaying then
			idleTrack:Stop(0.18)
		end
		if not moveTrack.IsPlaying then
			moveTrack:Play(0.18)
		end
		moveTrack:AdjustSpeed(1)
	else
		if moveTrack.IsPlaying then
			moveTrack:Stop(0.18)
		end
		if not idleTrack.IsPlaying then
			idleTrack:Play(0.18)
		end
		idleTrack:AdjustSpeed(0.8)
	end
end

local function updateSprint(deltaTime)
	local humanoid = getHumanoid()
	if not humanoid then
		lastAppliedWalkSpeed = Config.Movement.WalkSpeed
		return
	end

	local moving = humanoid.MoveDirection.Magnitude > 0.05
	local canSprint = state.SprintRequested
		and moving
		and state.Stamina > Config.Movement.ExhaustedThreshold
		and humanoid.Health > 0

	if canSprint then
		state.Stamina = math.max(0, state.Stamina - Config.Movement.SprintDrainPerSecond * deltaTime)
		lastAppliedWalkSpeed = Config.Movement.SprintSpeed
	else
		state.Stamina = math.min(Config.Movement.StaminaMax, state.Stamina + Config.Movement.StaminaRegenPerSecond * deltaTime)
		lastAppliedWalkSpeed = Config.Movement.WalkSpeed
	end

	if math.abs(humanoid.WalkSpeed - lastAppliedWalkSpeed) > 0.01 then
		humanoid.WalkSpeed = lastAppliedWalkSpeed
	end

	if math.abs(state.Stamina - lastRenderedStamina) >= STAMINA_UI_EPSILON then
		lastRenderedStamina = state.Stamina
		setBarValue(barRefs.Stamina, state.Stamina)
	end
end

local function handleCraftButton()
	if not state.SelectedRecipeId then
		return
	end

	request("CraftRequest", state.SelectedRecipeId)
end

local function handleShopBuyButton()
	if not state.ActiveShopId or not state.SelectedShopEntryId then
		return
	end

	request("ShopRequest", state.ActiveShopId, state.SelectedShopEntryId)
	if state.MenuOpen and state.ActiveTab == "Shops" then
		renderShops()
	end
end

attackButton.Activated:Connect(requestAttack)
sprintButton.Activated:Connect(function()
	setSprintRequested(not state.SprintRequested)
end)
menuButton.Activated:Connect(function()
	setMenuOpen(not state.MenuOpen)
end)
closeMenuButton.Activated:Connect(function()
	setMenuOpen(false)
end)

for tabName, button in pairs(tabButtons) do
	button.Activated:Connect(function()
		setTab(tabName)
	end)
end

craftButton.Activated:Connect(handleCraftButton)
shopBuyButton.Activated:Connect(handleShopBuyButton)

for index, button in ipairs(quickSlotButtons) do
	button.Activated:Connect(function()
		activateQuickSlot(index)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape and state.MenuOpen then
		setMenuOpen(false)
		return
	end

	if gameProcessed then
		return
	end

	for index, keyCode in ipairs(QUICK_SLOT_KEYS) do
		if input.KeyCode == keyCode then
			activateQuickSlot(index)
			return
		end
	end

	if input.KeyCode == Enum.KeyCode.F then
		requestAttack()
	elseif input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.M then
		setMenuOpen(not state.MenuOpen)
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprintRequested(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprintRequested(false)
	end
end)

Remotes.get("InventoryUpdated").OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	local previous = getEquippedHeldItemId()
	state.Inventory = snapshot
	refreshHud()
	local current = getEquippedHeldItemId()
	if current ~= previous then
		triggerEquipAnimation(current)
	end
end)

Remotes.get("VitalsUpdated").OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	state.Vitals = snapshot
	updateVitals()
end)

Remotes.get("WorldStateUpdated").OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	state.World = snapshot
	updateWorldStrip()
	if state.MenuOpen and state.ActiveTab == "World" then
		renderWorldPage()
	end
end)

Remotes.get("ObjectiveUpdated").OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	state.Objectives = snapshot
	if state.MenuOpen and state.ActiveTab == "Objectives" then
		renderObjectives()
	end
end)

Remotes.get("ProgressionUpdated").OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	state.Progression = snapshot
	updateWorldStrip()
	if state.MenuOpen and state.ActiveTab == "Crafting" then
		renderCrafting()
	elseif state.MenuOpen and state.ActiveTab == "World" then
		renderWorldPage()
	end
end)

Remotes.get("SaveStatusUpdated").OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" then
		state.Save.Text = snapshot.Text or state.Save.Text
		state.Save.Kind = snapshot.Kind or state.Save.Kind
	elseif type(snapshot) == "string" then
		state.Save.Text = snapshot
	end

	if state.MenuOpen and state.ActiveTab == "World" then
		renderWorldPage()
	end
end)

Remotes.get("Notification").OnClientEvent:Connect(function(message)
	showNotification(message, 2.8, THEME.Text)
end)

Remotes.get("ResourcePopup").OnClientEvent:Connect(showResourcePopup)

Remotes.get("ShopOpened").OnClientEvent:Connect(function(shopId)
	if type(shopId) ~= "string" then
		return
	end

	state.ActiveShopId = shopId
	state.SelectedShopEntryId = nil
	setMenuOpen(true)
	setTab("Shops")
end)

Remotes.get("EnemyDamaged").OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		triggerHitPulse(payload.IsCrit == true)
	end
end)

Remotes.get("HarvestAnimation").OnClientEvent:Connect(function(resourceId)
	triggerHarvestAnimation(resourceId)
	if resourceId == "Tree" then
		showNotification("Chop with equipped axe.", 0.9, THEME.Accent)
	elseif resourceId == "Rock" or resourceId == "IronDeposit" then
		showNotification("Mine with equipped pickaxe.", 0.9, THEME.Accent)
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	updateSprint(deltaTime)
	updateSwimming(deltaTime)
	updateItemAnimation(deltaTime)
	updateItemViewModel(deltaTime)
end)

task.spawn(function()
	local ok, result = pcall(function()
		return Remotes.get("GetInventory"):InvokeServer()
	end)

	if ok and type(result) == "table" then
		state.Inventory = result
	end

	refreshHud()
end)

pcall(function()
	StarterGui:SetCore("ResetButtonCallback", true)
end)
