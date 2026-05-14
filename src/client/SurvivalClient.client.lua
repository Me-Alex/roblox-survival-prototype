local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ITEM_ID_ATTRIBUTE = "SurvivalItemId"

local inventory = {}
local equipment = {}
local durability = {}
local vitals = {
	Hunger = 100,
	Thirst = 100,
	Temperature = 72,
	Health = 100,
	Statuses = {},
}
local stamina = Config.Movement.StaminaMax
local sprintRequested = false
local progression = {
	Level = 1,
	XP = 0,
	NextLevelXP = 80,
}
local worldState = {
	Day = 1,
	Clock = "09:00",
	Region = "Base Meadow",
	Weather = "Clear",
	IsNight = false,
}
local objectiveSnapshot = {
	Objectives = {},
	Counters = {},
}
local menuOpen = false
local activeMenuTab = "Inventory"
local localAttackAnimating = false

local DEFAULT_ATTACK_GRIPS = {
	StoneAxe = CFrame.new(0, -0.15, -0.35) * CFrame.Angles(0, math.rad(90), math.rad(82)),
	Spear = CFrame.new(0, -0.1, -0.55) * CFrame.Angles(0, math.rad(90), math.rad(86)),
	IronSpear = CFrame.new(0, -0.1, -0.55) * CFrame.Angles(0, math.rad(90), math.rad(86)),
}

local ATTACK_GRIPS = {
	StoneAxe = {
		CFrame.new(0.1, -0.1, -0.2) * CFrame.Angles(math.rad(-38), math.rad(104), math.rad(122)),
		CFrame.new(0, -0.22, -0.6) * CFrame.Angles(math.rad(44), math.rad(72), math.rad(54)),
		CFrame.new(0, -0.15, -0.35) * CFrame.Angles(0, math.rad(90), math.rad(82)),
	},
	Spear = {
		CFrame.new(0, -0.08, -0.28) * CFrame.Angles(math.rad(-8), math.rad(92), math.rad(92)),
		CFrame.new(0, -0.08, -1.1) * CFrame.Angles(math.rad(4), math.rad(88), math.rad(88)),
		CFrame.new(0, -0.1, -0.55) * CFrame.Angles(0, math.rad(90), math.rad(86)),
	},
	IronSpear = {
		CFrame.new(0, -0.08, -0.28) * CFrame.Angles(math.rad(-8), math.rad(92), math.rad(92)),
		CFrame.new(0, -0.08, -1.15) * CFrame.Angles(math.rad(4), math.rad(88), math.rad(88)),
		CFrame.new(0, -0.1, -0.55) * CFrame.Angles(0, math.rad(90), math.rad(86)),
	},
}

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

local vitalsPanel = Instance.new("Frame")
vitalsPanel.Name = "Vitals"
vitalsPanel.AnchorPoint = Vector2.new(0, 0)
vitalsPanel.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
vitalsPanel.BackgroundTransparency = 0.12
vitalsPanel.BorderSizePixel = 0
vitalsPanel.Position = UDim2.fromOffset(18, 76)
vitalsPanel.Size = UDim2.fromOffset(560, 42)
vitalsPanel.Parent = root

local vitalsCorner = Instance.new("UICorner")
vitalsCorner.CornerRadius = UDim.new(0, 8)
vitalsCorner.Parent = vitalsPanel

local inventoryPanel = Instance.new("Frame")
inventoryPanel.Name = "Inventory"
inventoryPanel.AnchorPoint = Vector2.new(0.5, 0.5)
inventoryPanel.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
inventoryPanel.BackgroundTransparency = 0.05
inventoryPanel.BorderSizePixel = 0
inventoryPanel.Position = UDim2.fromScale(0.5, 0.5)
inventoryPanel.Size = UDim2.fromScale(0.86, 0.76)
inventoryPanel.Visible = false
inventoryPanel.ZIndex = 4
inventoryPanel.Parent = root

local inventoryCorner = Instance.new("UICorner")
inventoryCorner.CornerRadius = UDim.new(0, 8)
inventoryCorner.Parent = inventoryPanel

local inventorySizeConstraint = Instance.new("UISizeConstraint")
inventorySizeConstraint.MaxSize = Vector2.new(620, 440)
inventorySizeConstraint.MinSize = Vector2.new(430, 300)
inventorySizeConstraint.Parent = inventoryPanel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "SURVIVAL"
title.TextColor3 = Color3.fromRGB(235, 238, 229)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.fromOffset(14, 9)
title.Size = UDim2.new(1, -28, 0, 22)
title.Visible = false
title.Parent = vitalsPanel

local inventoryTitle = title:Clone()
inventoryTitle.Name = "InventoryTitle"
inventoryTitle.Text = "INVENTORY"
inventoryTitle.ZIndex = 5
inventoryTitle.Parent = inventoryPanel

local equipmentSummary = Instance.new("TextLabel")
equipmentSummary.Name = "EquipmentSummary"
equipmentSummary.BackgroundTransparency = 1
equipmentSummary.Font = Enum.Font.GothamMedium
equipmentSummary.Text = ""
equipmentSummary.TextColor3 = Color3.fromRGB(191, 201, 190)
equipmentSummary.TextSize = 12
equipmentSummary.TextXAlignment = Enum.TextXAlignment.Left
equipmentSummary.Position = UDim2.fromOffset(14, 35)
equipmentSummary.Size = UDim2.new(1, -28, 0, 18)
equipmentSummary.ZIndex = 5
equipmentSummary.Parent = inventoryPanel

local worldPanel = Instance.new("Frame")
worldPanel.Name = "World"
worldPanel.AnchorPoint = Vector2.new(0, 0)
worldPanel.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
worldPanel.BackgroundTransparency = 1
worldPanel.BorderSizePixel = 0
worldPanel.Position = UDim2.fromOffset(14, 92)
worldPanel.Size = UDim2.new(1, -28, 1, -108)
worldPanel.Visible = false
worldPanel.ZIndex = 5
worldPanel.Parent = inventoryPanel

local worldCorner = Instance.new("UICorner")
worldCorner.CornerRadius = UDim.new(0, 8)
worldCorner.Parent = worldPanel

local worldTitle = title:Clone()
worldTitle.Name = "WorldTitle"
worldTitle.Text = "WORLD"
worldTitle.Visible = false
worldTitle.Parent = worldPanel

local worldDetails = Instance.new("TextLabel")
worldDetails.Name = "WorldDetails"
worldDetails.BackgroundTransparency = 1
worldDetails.Font = Enum.Font.GothamMedium
worldDetails.TextColor3 = Color3.fromRGB(235, 238, 229)
worldDetails.TextSize = 13
worldDetails.TextWrapped = true
worldDetails.TextXAlignment = Enum.TextXAlignment.Left
worldDetails.TextYAlignment = Enum.TextYAlignment.Top
worldDetails.Position = UDim2.fromOffset(0, 0)
worldDetails.Size = UDim2.new(1, 0, 1, 0)
worldDetails.ZIndex = 5
worldDetails.Parent = worldPanel

local objectivePanel = Instance.new("Frame")
objectivePanel.Name = "Objectives"
objectivePanel.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
objectivePanel.BackgroundTransparency = 1
objectivePanel.BorderSizePixel = 0
objectivePanel.Position = UDim2.fromOffset(14, 92)
objectivePanel.Size = UDim2.new(1, -28, 1, -108)
objectivePanel.Visible = false
objectivePanel.ZIndex = 5
objectivePanel.Parent = inventoryPanel

local objectiveCorner = Instance.new("UICorner")
objectiveCorner.CornerRadius = UDim.new(0, 8)
objectiveCorner.Parent = objectivePanel

local objectiveTitle = title:Clone()
objectiveTitle.Name = "ObjectiveTitle"
objectiveTitle.Text = "OBJECTIVES"
objectiveTitle.Visible = false
objectiveTitle.Parent = objectivePanel

local objectiveList = Instance.new("ScrollingFrame")
objectiveList.Name = "ObjectiveList"
objectiveList.Active = true
objectiveList.BackgroundTransparency = 1
objectiveList.BorderSizePixel = 0
objectiveList.Position = UDim2.fromOffset(0, 0)
objectiveList.ScrollBarThickness = 6
objectiveList.Size = UDim2.new(1, 0, 1, 0)
objectiveList.CanvasSize = UDim2.fromOffset(0, 0)
objectiveList.AutomaticCanvasSize = Enum.AutomaticSize.Y
objectiveList.ZIndex = 5
objectiveList.Parent = objectivePanel

local objectiveLayout = Instance.new("UIListLayout")
objectiveLayout.Padding = UDim.new(0, 6)
objectiveLayout.SortOrder = Enum.SortOrder.LayoutOrder
objectiveLayout.Parent = objectiveList

local notification = Instance.new("TextLabel")
notification.Name = "Notification"
notification.AnchorPoint = Vector2.new(0.5, 0)
notification.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
notification.BackgroundTransparency = 0.2
notification.BorderSizePixel = 0
notification.Font = Enum.Font.GothamMedium
notification.Position = UDim2.new(0.5, 0, 0, 24)
notification.Size = UDim2.fromOffset(420, 38)
notification.Text = ""
notification.TextColor3 = Color3.fromRGB(245, 245, 235)
notification.TextSize = 15
notification.Visible = false
notification.Parent = root

local notificationCorner = Instance.new("UICorner")
notificationCorner.CornerRadius = UDim.new(0, 8)
notificationCorner.Parent = notification

local vitalBars = {}

local function makeVitalBar(name, y, color)
	local label = Instance.new("TextLabel")
	label.Name = name .. "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(235, 238, 229)
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.fromOffset(106, 18)
	label.Visible = false
	label.Parent = vitalsPanel

	local track = Instance.new("Frame")
	track.Name = name .. "Track"
	track.BackgroundColor3 = Color3.fromRGB(50, 55, 56)
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(124, y + 3)
	track.Size = UDim2.fromOffset(128, 12)
	track.Visible = false
	track.Parent = vitalsPanel

	local fill = Instance.new("Frame")
	fill.Name = name .. "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track

	vitalBars[name] = {
		Label = label,
		Fill = fill,
	}
end

makeVitalBar("Hunger", 38, Color3.fromRGB(222, 177, 75))
makeVitalBar("Thirst", 62, Color3.fromRGB(76, 172, 222))
makeVitalBar("Temperature", 86, Color3.fromRGB(226, 104, 72))
makeVitalBar("Health", 110, Color3.fromRGB(207, 74, 91))
makeVitalBar("Stamina", 134, Color3.fromRGB(111, 198, 121))

local statusText = Instance.new("TextLabel")
statusText.Name = "StatusText"
statusText.BackgroundTransparency = 1
statusText.Font = Enum.Font.GothamMedium
statusText.Text = "Status  Stable"
statusText.TextColor3 = Color3.fromRGB(214, 220, 210)
statusText.TextSize = 12
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.Position = UDim2.fromOffset(14, 158)
statusText.Size = UDim2.new(1, -28, 0, 18)
statusText.Visible = false
statusText.Parent = vitalsPanel

local compactStatusText = Instance.new("TextLabel")
compactStatusText.Name = "CompactStatus"
compactStatusText.BackgroundTransparency = 1
compactStatusText.Font = Enum.Font.GothamBold
compactStatusText.Text = "HP 100  H 100  W 100  Temp 72  Sta 100"
compactStatusText.TextColor3 = Color3.fromRGB(235, 238, 229)
compactStatusText.TextSize = 12
compactStatusText.TextXAlignment = Enum.TextXAlignment.Left
compactStatusText.Position = UDim2.fromOffset(12, 4)
compactStatusText.Size = UDim2.new(1, -24, 0, 17)
compactStatusText.Parent = vitalsPanel

local compactWorldText = Instance.new("TextLabel")
compactWorldText.Name = "CompactWorld"
compactWorldText.BackgroundTransparency = 1
compactWorldText.Font = Enum.Font.GothamMedium
compactWorldText.Text = "Day 1  09:00  Base Meadow"
compactWorldText.TextColor3 = Color3.fromRGB(190, 201, 192)
compactWorldText.TextSize = 11
compactWorldText.TextXAlignment = Enum.TextXAlignment.Left
compactWorldText.Position = UDim2.fromOffset(12, 21)
compactWorldText.Size = UDim2.new(1, -24, 0, 16)
compactWorldText.Parent = vitalsPanel

local inventoryList = Instance.new("ScrollingFrame")
inventoryList.Name = "InventoryList"
inventoryList.Active = true
inventoryList.BackgroundTransparency = 1
inventoryList.BorderSizePixel = 0
inventoryList.Position = UDim2.fromOffset(14, 92)
inventoryList.ScrollBarThickness = 6
inventoryList.Size = UDim2.new(1, -28, 1, -108)
inventoryList.CanvasSize = UDim2.fromOffset(0, 0)
inventoryList.AutomaticCanvasSize = Enum.AutomaticSize.Y
inventoryList.ZIndex = 5
inventoryList.Parent = inventoryPanel

local inventoryLayout = Instance.new("UIListLayout")
inventoryLayout.Padding = UDim.new(0, 6)
inventoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
inventoryLayout.Parent = inventoryList

local craftTitle = Instance.new("TextLabel")
craftTitle.Name = "CraftTitle"
craftTitle.BackgroundTransparency = 1
craftTitle.Font = Enum.Font.GothamBold
craftTitle.Text = "CRAFT"
craftTitle.TextColor3 = Color3.fromRGB(235, 238, 229)
craftTitle.TextSize = 14
craftTitle.TextXAlignment = Enum.TextXAlignment.Left
craftTitle.Position = UDim2.fromOffset(14, 68)
craftTitle.Size = UDim2.new(1, -28, 0, 20)
craftTitle.Visible = false
craftTitle.ZIndex = 5
craftTitle.Parent = inventoryPanel

local craftList = Instance.new("ScrollingFrame")
craftList.Name = "CraftList"
craftList.Active = true
craftList.BackgroundTransparency = 1
craftList.BorderSizePixel = 0
craftList.Position = UDim2.fromOffset(14, 92)
craftList.ScrollBarThickness = 6
craftList.Size = UDim2.new(1, -28, 1, -108)
craftList.CanvasSize = UDim2.fromOffset(0, 0)
craftList.AutomaticCanvasSize = Enum.AutomaticSize.Y
craftList.Visible = false
craftList.ZIndex = 5
craftList.Parent = inventoryPanel

local craftLayout = Instance.new("UIListLayout")
craftLayout.Padding = UDim.new(0, 6)
craftLayout.SortOrder = Enum.SortOrder.LayoutOrder
craftLayout.Parent = craftList

local function makeButton(text, width)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(72, 96, 88)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Size = UDim2.fromOffset(width, 28)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(245, 245, 235)
	button.TextSize = 12

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	return button
end

local attackButton = makeButton("Attack", 110)
attackButton.Name = "AttackButton"
attackButton.AnchorPoint = Vector2.new(1, 1)
attackButton.BackgroundColor3 = Color3.fromRGB(126, 64, 58)
attackButton.Position = UDim2.new(1, -20, 1, -140)
attackButton.Size = UDim2.fromOffset(98, 36)
attackButton.TextSize = 14
attackButton.Parent = root

local sprintButton = makeButton("Sprint", 110)
sprintButton.Name = "SprintButton"
sprintButton.AnchorPoint = Vector2.new(1, 1)
sprintButton.BackgroundColor3 = Color3.fromRGB(70, 92, 72)
sprintButton.Position = UDim2.new(1, -20, 1, -184)
sprintButton.Size = UDim2.fromOffset(98, 36)
sprintButton.TextSize = 14
sprintButton.Parent = root

local inventoryToggleButton = makeButton("Menu", 98)
inventoryToggleButton.Name = "InventoryToggleButton"
inventoryToggleButton.AnchorPoint = Vector2.new(1, 1)
inventoryToggleButton.BackgroundColor3 = Color3.fromRGB(68, 82, 96)
inventoryToggleButton.Position = UDim2.new(1, -20, 1, -228)
inventoryToggleButton.Size = UDim2.fromOffset(98, 36)
inventoryToggleButton.TextSize = 14
inventoryToggleButton.Parent = root

local quickBar = Instance.new("Frame")
quickBar.Name = "QuickBar"
quickBar.AnchorPoint = Vector2.new(0.5, 1)
quickBar.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
quickBar.BackgroundTransparency = 0.16
quickBar.BorderSizePixel = 0
quickBar.Position = UDim2.new(0.5, 0, 1, -78)
quickBar.Size = UDim2.fromOffset(408, 46)
quickBar.Visible = false
quickBar.Parent = root

local quickBarCorner = Instance.new("UICorner")
quickBarCorner.CornerRadius = UDim.new(0, 8)
quickBarCorner.Parent = quickBar

local quickBarLayout = Instance.new("UIListLayout")
quickBarLayout.FillDirection = Enum.FillDirection.Horizontal
quickBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
quickBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
quickBarLayout.Padding = UDim.new(0, 6)
quickBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
quickBarLayout.Parent = quickBar

local menuTabBar = Instance.new("Frame")
menuTabBar.Name = "TabBar"
menuTabBar.BackgroundTransparency = 1
menuTabBar.Position = UDim2.fromOffset(14, 58)
menuTabBar.Size = UDim2.new(1, -104, 0, 28)
menuTabBar.ZIndex = 5
menuTabBar.Parent = inventoryPanel

local menuTabLayout = Instance.new("UIListLayout")
menuTabLayout.FillDirection = Enum.FillDirection.Horizontal
menuTabLayout.Padding = UDim.new(0, 8)
menuTabLayout.SortOrder = Enum.SortOrder.LayoutOrder
menuTabLayout.Parent = menuTabBar

local bagTabButton = makeButton("Bag", 68)
bagTabButton.Name = "BagTab"
bagTabButton.ZIndex = 6
bagTabButton.Parent = menuTabBar

local craftTabButton = makeButton("Craft", 68)
craftTabButton.Name = "CraftTab"
craftTabButton.ZIndex = 6
craftTabButton.Parent = menuTabBar

local worldTabButton = makeButton("World", 68)
worldTabButton.Name = "WorldTab"
worldTabButton.ZIndex = 6
worldTabButton.Parent = menuTabBar

local objectivesTabButton = makeButton("Goals", 68)
objectivesTabButton.Name = "ObjectivesTab"
objectivesTabButton.ZIndex = 6
objectivesTabButton.Parent = menuTabBar

local closeMenuButton = makeButton("Close", 76)
closeMenuButton.Name = "CloseMenu"
closeMenuButton.AnchorPoint = Vector2.new(1, 0)
closeMenuButton.Position = UDim2.new(1, -14, 0, 10)
closeMenuButton.ZIndex = 6
closeMenuButton.Parent = inventoryPanel

local function showNotification(message)
	notification.Text = message
	notification.Visible = true

	task.delay(2.4, function()
		if notification.Text == message then
			notification.Visible = false
		end
	end)
end

local function updateVitalBar(name, value)
	local bar = vitalBars[name]
	if not bar then
		return
	end

	local percent = math.clamp(value / 100, 0, 1)
	bar.Label.Text = string.format("%s  %d", name, value)
	bar.Fill.Size = UDim2.fromScale(percent, 1)
end

local function updateVitals()
	for name in pairs(vitalBars) do
		local value = name == "Stamina" and stamina or (vitals[name] or 0)
		updateVitalBar(name, math.floor(value + 0.5))
	end

	local statuses = {}
	for _, statusState in pairs(vitals.Statuses or {}) do
		table.insert(statuses, statusState.DisplayName or "Unknown")
	end
	table.sort(statuses)

	statusText.Text = #statuses > 0 and ("Status  " .. table.concat(statuses, ", ")) or "Status  Stable"
	compactStatusText.Text = string.format(
		"HP %d   H %d   W %d   Temp %d   Sta %d   %s",
		math.floor((vitals.Health or 0) + 0.5),
		math.floor((vitals.Hunger or 0) + 0.5),
		math.floor((vitals.Thirst or 0) + 0.5),
		math.floor((vitals.Temperature or 0) + 0.5),
		math.floor(stamina + 0.5),
		#statuses > 0 and table.concat(statuses, ", ") or "Stable"
	)
end

local function clearChildren(frame)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function formatCost(cost)
	local parts = {}

	for itemId, amount in pairs(cost) do
		local itemConfig = Config.Items[itemId]
		table.insert(parts, string.format("%dx %s", amount, itemConfig and itemConfig.DisplayName or itemId))
	end

	table.sort(parts)
	return table.concat(parts, "  ")
end

local function formatRecipeDetails(recipe)
	local details = { formatCost(recipe.Cost) }

	if recipe.RequiredLevel then
		table.insert(details, string.format("Lvl %d", recipe.RequiredLevel))
	end

	if recipe.RequiresNearby then
		table.insert(details, recipe.RequiresNearby)
	end

	return table.concat(details, "  ")
end

local function canAfford(cost)
	for itemId, amount in pairs(cost) do
		if (inventory[itemId] or 0) < amount then
			return false
		end
	end

	return true
end

local function requestCraft(recipeId)
	local ok, message = Remotes.get("CraftRequest"):InvokeServer(recipeId)
	if not ok and message then
		showNotification(message)
	end
end

local function requestConsume(itemId)
	local ok, message = Remotes.get("ConsumeRequest"):InvokeServer(itemId)
	if not ok and message then
		showNotification(message)
	end
end

local function requestBuild(itemId)
	local ok, message = Remotes.get("BuildRequest"):InvokeServer(itemId)
	if not ok and message then
		showNotification(message)
	end
end

local function requestEquip(itemId)
	local ok, message = Remotes.get("EquipRequest"):InvokeServer(itemId)
	if message then
		showNotification(message)
	elseif not ok then
		showNotification("Could not equip item.")
	end
end

local function getHeldWeaponTool()
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local itemId = child:GetAttribute(ITEM_ID_ATTRIBUTE)
			if itemId and Config.Combat.Weapons[itemId] then
				return child, itemId
			end
		end
	end

	return nil
end

local function playLocalAttackAnimation()
	if localAttackAnimating then
		return
	end

	local tool, itemId = getHeldWeaponTool()
	local sequence = itemId and ATTACK_GRIPS[itemId] or nil
	if not tool or not sequence then
		return
	end

	localAttackAnimating = true

	task.spawn(function()
		for _, grip in ipairs(sequence) do
			if not tool.Parent then
				break
			end

			tool.Grip = grip
			task.wait(0.08)
		end

		if tool.Parent then
			tool.Grip = DEFAULT_ATTACK_GRIPS[itemId] or CFrame.new()
		end

		localAttackAnimating = false
	end)
end

local function requestAttack()
	playLocalAttackAnimation()
	local ok, message = Remotes.get("AttackRequest"):InvokeServer()
	if not ok and message then
		showNotification(message)
	end
end

local function applyInventorySnapshot(snapshot)
	if snapshot.Items then
		inventory = snapshot.Items
		equipment = snapshot.Equipped or {}
		durability = snapshot.Durability or {}
	else
		inventory = snapshot
		equipment = {}
		durability = {}
	end
end

local function getItemDisplayName(itemId)
	local itemConfig = itemId and Config.Items[itemId]
	return itemConfig and itemConfig.DisplayName or "None"
end

local function renderInventory()
	clearChildren(inventoryList)
	equipmentSummary.Text = string.format(
		"Weapon  %s    Armor  %s",
		getItemDisplayName(equipment.Weapon),
		getItemDisplayName(equipment.Armor)
	)

	local ordered = {}
	for itemId in pairs(Config.Items) do
		table.insert(ordered, itemId)
	end
	table.sort(ordered)

	local hasVisibleItems = false

	for _, itemId in ipairs(ordered) do
		local count = inventory[itemId] or 0
		if count > 0 then
			hasVisibleItems = true
			local itemConfig = Config.Items[itemId]
			local equipmentConfig = Config.Equipment[itemId]
			local row = Instance.new("Frame")
			row.BackgroundColor3 = Color3.fromRGB(38, 43, 44)
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, -8, 0, 32)
			row.Parent = inventoryList

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = row

			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamMedium
			local labelText = string.format("%s  x%d", itemConfig.DisplayName, count)
			if equipmentConfig then
				local durabilityValue = durability[itemId] or equipmentConfig.MaxDurability
				labelText = string.format("%s  %d/%d", labelText, durabilityValue, equipmentConfig.MaxDurability)
			end
			label.Text = labelText
			label.TextColor3 = Color3.fromRGB(235, 238, 229)
			label.TextSize = 13
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Position = UDim2.fromOffset(10, 0)
			label.Size = UDim2.new(1, -150, 1, 0)
			label.Parent = row

			if equipmentConfig then
				local equipped = equipment[equipmentConfig.Slot] == itemId
				local equipButton = makeButton(equipped and "Equipped" or "Equip", 76)
				equipButton.AnchorPoint = Vector2.new(1, 0.5)
				equipButton.Position = UDim2.new(1, -8, 0.5, 0)
				equipButton.BackgroundColor3 = equipped and Color3.fromRGB(92, 122, 82) or Color3.fromRGB(72, 96, 88)
				equipButton.Parent = row
				equipButton.Activated:Connect(function()
					requestEquip(itemId)
				end)
			elseif Config.Consumables[itemId] then
				local useButton = makeButton("Use", 58)
				useButton.AnchorPoint = Vector2.new(1, 0.5)
				useButton.Position = UDim2.new(1, -8, 0.5, 0)
				useButton.Parent = row
				useButton.Activated:Connect(function()
					requestConsume(itemId)
				end)
			elseif Config.Buildables[itemId] then
				local buildButton = makeButton("Place", 64)
				buildButton.AnchorPoint = Vector2.new(1, 0.5)
				buildButton.Position = UDim2.new(1, -8, 0.5, 0)
				buildButton.Parent = row
				buildButton.Activated:Connect(function()
					requestBuild(itemId)
				end)
			end
		end
	end

	if not hasVisibleItems then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.GothamMedium
		empty.Text = "Backpack empty"
		empty.TextColor3 = Color3.fromRGB(190, 196, 188)
		empty.TextSize = 13
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Size = UDim2.new(1, -8, 0, 32)
		empty.Parent = inventoryList
	end
end

local function renderCrafting()
	clearChildren(craftList)

	local ordered = {}
	for recipeId in pairs(Config.Crafting) do
		table.insert(ordered, recipeId)
	end
	table.sort(ordered)

	for _, recipeId in ipairs(ordered) do
		local recipe = Config.Crafting[recipeId]
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(38, 43, 44)
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, -8, 0, 58)
		row.Parent = craftList

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = recipe.DisplayName
		label.TextColor3 = Color3.fromRGB(235, 238, 229)
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Position = UDim2.fromOffset(10, 5)
		label.Size = UDim2.new(1, -108, 0, 18)
		label.Parent = row

		local cost = Instance.new("TextLabel")
		cost.BackgroundTransparency = 1
		cost.Font = Enum.Font.Gotham
		cost.Text = formatRecipeDetails(recipe)
		cost.TextColor3 = Color3.fromRGB(187, 194, 185)
		cost.TextSize = 11
		cost.TextXAlignment = Enum.TextXAlignment.Left
		cost.Position = UDim2.fromOffset(10, 28)
		cost.Size = UDim2.new(1, -108, 0, 18)
		cost.Parent = row

		local craftButton = makeButton("Craft", 72)
		craftButton.AnchorPoint = Vector2.new(1, 0.5)
		craftButton.Position = UDim2.new(1, -8, 0.5, 0)
		craftButton.BackgroundColor3 = canAfford(recipe.Cost) and Color3.fromRGB(72, 96, 88) or Color3.fromRGB(74, 74, 74)
		craftButton.Parent = row
		craftButton.Activated:Connect(function()
			requestCraft(recipeId)
		end)
	end
end

local function renderQuickSlots()
	clearChildren(quickBar)
end

local function setMenuTab(tabName)
	activeMenuTab = tabName
	local showingInventory = activeMenuTab == "Inventory"
	local showingCrafting = activeMenuTab == "Crafting"
	local showingWorld = activeMenuTab == "World"
	local showingObjectives = activeMenuTab == "Objectives"

	if showingInventory then
		inventoryTitle.Text = "INVENTORY"
	elseif showingCrafting then
		inventoryTitle.Text = "CRAFTING"
	elseif showingWorld then
		inventoryTitle.Text = "WORLD"
	else
		inventoryTitle.Text = "OBJECTIVES"
	end

	inventoryList.Visible = showingInventory
	equipmentSummary.Visible = showingInventory
	craftTitle.Visible = showingCrafting
	craftList.Visible = showingCrafting
	worldPanel.Visible = showingWorld
	objectivePanel.Visible = showingObjectives
	bagTabButton.BackgroundColor3 = showingInventory and Color3.fromRGB(92, 122, 82) or Color3.fromRGB(72, 96, 88)
	craftTabButton.BackgroundColor3 = showingCrafting and Color3.fromRGB(92, 122, 82) or Color3.fromRGB(72, 96, 88)
	worldTabButton.BackgroundColor3 = showingWorld and Color3.fromRGB(92, 122, 82) or Color3.fromRGB(72, 96, 88)
	objectivesTabButton.BackgroundColor3 = showingObjectives and Color3.fromRGB(92, 122, 82) or Color3.fromRGB(72, 96, 88)
end

local function setMenuOpen(open)
	menuOpen = open
	inventoryPanel.Visible = menuOpen
	inventoryToggleButton.BackgroundColor3 = menuOpen and Color3.fromRGB(92, 122, 82) or Color3.fromRGB(68, 82, 96)

	if menuOpen then
		setMenuTab(activeMenuTab)
	end
end

local function renderWorldState()
	local phase = worldState.IsNight and "Night" or "Daylight"
	local threatLine = worldState.Threat and string.format("\nThreat %d/100", worldState.Threat) or ""
	compactWorldText.Text = string.format(
		"Day %d  %s   %s   %s   Lv %d %d/%s",
		worldState.Day or 1,
		worldState.Clock or "00:00",
		worldState.Region or "Wilderness",
		worldState.Weather or "Clear",
		progression.Level or 1,
		progression.XP or 0,
		progression.NextLevelXP and tostring(progression.NextLevelXP) or "max"
	)
	worldDetails.Text = string.format(
		"Day %d   %s\n%s\n%s\n%s\nLevel %d  XP %d/%s%s",
		worldState.Day or 1,
		worldState.Clock or "00:00",
		worldState.Region or "Wilderness",
		worldState.Weather or "Clear",
		phase,
		progression.Level or 1,
		progression.XP or 0,
		progression.NextLevelXP and tostring(progression.NextLevelXP) or "max",
		threatLine
	)
end

local function renderObjectives()
	clearChildren(objectiveList)

	for index, objective in ipairs(objectiveSnapshot.Objectives or {}) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = objective.Completed and Color3.fromRGB(44, 74, 56) or Color3.fromRGB(38, 43, 44)
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 68)
		row.Parent = objectiveList

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.Text = objective.Completed and (objective.DisplayName .. "  DONE") or objective.DisplayName
		name.TextColor3 = Color3.fromRGB(235, 238, 229)
		name.TextSize = 12
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(10, 5)
		name.Size = UDim2.new(1, -20, 0, 18)
		name.Parent = row

		local description = Instance.new("TextLabel")
		description.BackgroundTransparency = 1
		description.Font = Enum.Font.Gotham
		description.Text = objective.Description
		description.TextColor3 = Color3.fromRGB(190, 196, 188)
		description.TextSize = 11
		description.TextWrapped = true
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.TextYAlignment = Enum.TextYAlignment.Top
		description.Position = UDim2.fromOffset(10, 25)
		description.Size = UDim2.new(1, -20, 0, 26)
		description.Parent = row

		local progress = Instance.new("TextLabel")
		progress.BackgroundTransparency = 1
		progress.Font = Enum.Font.GothamMedium
		progress.Text = objective.Progress
		progress.TextColor3 = Color3.fromRGB(224, 207, 142)
		progress.TextSize = 11
		progress.TextXAlignment = Enum.TextXAlignment.Left
		progress.Position = UDim2.fromOffset(10, 50)
		progress.Size = UDim2.new(1, -20, 0, 15)
		progress.Parent = row
	end
end

local function renderAll()
	updateVitals()
	renderWorldState()
	renderObjectives()
	renderInventory()
	renderCrafting()
	renderQuickSlots()
	setMenuTab(activeMenuTab)
end

local function setSprintRequested(requested)
	sprintRequested = requested
	sprintButton.BackgroundColor3 = requested and Color3.fromRGB(91, 130, 82) or Color3.fromRGB(70, 92, 72)
end

local function getHumanoid()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function updateSprint(deltaTime)
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end

	local moving = humanoid.MoveDirection.Magnitude > 0.05
	local canSprint = sprintRequested
		and moving
		and stamina > Config.Movement.ExhaustedThreshold
		and humanoid.Health > 0

	if canSprint then
		stamina = math.max(0, stamina - Config.Movement.SprintDrainPerSecond * deltaTime)
		humanoid.WalkSpeed = Config.Movement.SprintSpeed
	else
		stamina = math.min(Config.Movement.StaminaMax, stamina + Config.Movement.StaminaRegenPerSecond * deltaTime)
		humanoid.WalkSpeed = Config.Movement.WalkSpeed
	end

	updateVitalBar("Stamina", math.floor(stamina + 0.5))
	updateVitals()
end

Remotes.get("VitalsUpdated").OnClientEvent:Connect(function(newVitals)
	vitals = newVitals
	updateVitals()
end)

Remotes.get("InventoryUpdated").OnClientEvent:Connect(function(newInventory)
	applyInventorySnapshot(newInventory)
	renderAll()
end)

Remotes.get("WorldStateUpdated").OnClientEvent:Connect(function(newWorldState)
	worldState = newWorldState
	renderWorldState()
end)

Remotes.get("ObjectiveUpdated").OnClientEvent:Connect(function(newObjectiveSnapshot)
	objectiveSnapshot = newObjectiveSnapshot
	renderObjectives()
end)

Remotes.get("ProgressionUpdated").OnClientEvent:Connect(function(newProgression)
	progression = newProgression
	renderWorldState()
end)

Remotes.get("Notification").OnClientEvent:Connect(showNotification)

attackButton.Activated:Connect(requestAttack)
inventoryToggleButton.Activated:Connect(function()
	setMenuOpen(not menuOpen)
end)

bagTabButton.Activated:Connect(function()
	setMenuTab("Inventory")
end)

craftTabButton.Activated:Connect(function()
	setMenuTab("Crafting")
end)

worldTabButton.Activated:Connect(function()
	setMenuTab("World")
end)

objectivesTabButton.Activated:Connect(function()
	setMenuTab("Objectives")
end)

closeMenuButton.Activated:Connect(function()
	setMenuOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape and menuOpen then
		setMenuOpen(false)
		return
	end

	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F then
		requestAttack()
	elseif input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.M then
		setMenuOpen(not menuOpen)
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprintRequested(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprintRequested(false)
	end
end)

sprintButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		setSprintRequested(true)
	end
end)

sprintButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		setSprintRequested(false)
	end
end)

RunService.RenderStepped:Connect(updateSprint)

task.spawn(function()
	local ok, result = pcall(function()
		return Remotes.get("GetInventory"):InvokeServer()
	end)

	if ok and type(result) == "table" then
		applyInventorySnapshot(result)
	end

	renderAll()
end)

pcall(function()
	StarterGui:SetCore("ResetButtonCallback", true)
end)
