local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SurvivalHud"
screenGui.ResetOnSpawn = false
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
vitalsPanel.Position = UDim2.fromOffset(18, 18)
vitalsPanel.Size = UDim2.fromOffset(270, 186)
vitalsPanel.Parent = root

local vitalsCorner = Instance.new("UICorner")
vitalsCorner.CornerRadius = UDim.new(0, 8)
vitalsCorner.Parent = vitalsPanel

local inventoryPanel = Instance.new("Frame")
inventoryPanel.Name = "Inventory"
inventoryPanel.AnchorPoint = Vector2.new(1, 1)
inventoryPanel.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
inventoryPanel.BackgroundTransparency = 0.12
inventoryPanel.BorderSizePixel = 0
inventoryPanel.Position = UDim2.new(1, -18, 1, -18)
inventoryPanel.Size = UDim2.fromOffset(390, 360)
inventoryPanel.Parent = root

local inventoryCorner = Instance.new("UICorner")
inventoryCorner.CornerRadius = UDim.new(0, 8)
inventoryCorner.Parent = inventoryPanel

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
title.Parent = vitalsPanel

local inventoryTitle = title:Clone()
inventoryTitle.Name = "InventoryTitle"
inventoryTitle.Text = "GEAR"
inventoryTitle.Parent = inventoryPanel

local worldPanel = Instance.new("Frame")
worldPanel.Name = "World"
worldPanel.AnchorPoint = Vector2.new(1, 0)
worldPanel.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
worldPanel.BackgroundTransparency = 0.12
worldPanel.BorderSizePixel = 0
worldPanel.Position = UDim2.new(1, -18, 0, 18)
worldPanel.Size = UDim2.fromOffset(250, 154)
worldPanel.Parent = root

local worldCorner = Instance.new("UICorner")
worldCorner.CornerRadius = UDim.new(0, 8)
worldCorner.Parent = worldPanel

local worldTitle = title:Clone()
worldTitle.Name = "WorldTitle"
worldTitle.Text = "WORLD"
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
worldDetails.Position = UDim2.fromOffset(14, 36)
worldDetails.Size = UDim2.new(1, -28, 1, -46)
worldDetails.Parent = worldPanel

local objectivePanel = Instance.new("Frame")
objectivePanel.Name = "Objectives"
objectivePanel.BackgroundColor3 = Color3.fromRGB(24, 28, 30)
objectivePanel.BackgroundTransparency = 0.12
objectivePanel.BorderSizePixel = 0
objectivePanel.Position = UDim2.fromOffset(18, 218)
objectivePanel.Size = UDim2.fromOffset(330, 230)
objectivePanel.Parent = root

local objectiveCorner = Instance.new("UICorner")
objectiveCorner.CornerRadius = UDim.new(0, 8)
objectiveCorner.Parent = objectivePanel

local objectiveTitle = title:Clone()
objectiveTitle.Name = "ObjectiveTitle"
objectiveTitle.Text = "OBJECTIVES"
objectiveTitle.Parent = objectivePanel

local objectiveList = Instance.new("ScrollingFrame")
objectiveList.Name = "ObjectiveList"
objectiveList.Active = true
objectiveList.BackgroundTransparency = 1
objectiveList.BorderSizePixel = 0
objectiveList.Position = UDim2.fromOffset(12, 38)
objectiveList.ScrollBarThickness = 6
objectiveList.Size = UDim2.new(1, -24, 1, -50)
objectiveList.CanvasSize = UDim2.fromOffset(0, 0)
objectiveList.AutomaticCanvasSize = Enum.AutomaticSize.Y
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
	label.Parent = vitalsPanel

	local track = Instance.new("Frame")
	track.Name = name .. "Track"
	track.BackgroundColor3 = Color3.fromRGB(50, 55, 56)
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(124, y + 3)
	track.Size = UDim2.fromOffset(128, 12)
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
statusText.Parent = vitalsPanel

local inventoryList = Instance.new("ScrollingFrame")
inventoryList.Name = "InventoryList"
inventoryList.Active = true
inventoryList.BackgroundTransparency = 1
inventoryList.BorderSizePixel = 0
inventoryList.Position = UDim2.fromOffset(12, 36)
inventoryList.ScrollBarThickness = 6
inventoryList.Size = UDim2.new(1, -24, 0, 144)
inventoryList.CanvasSize = UDim2.fromOffset(0, 0)
inventoryList.AutomaticCanvasSize = Enum.AutomaticSize.Y
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
craftTitle.Position = UDim2.fromOffset(14, 188)
craftTitle.Size = UDim2.new(1, -28, 0, 20)
craftTitle.Parent = inventoryPanel

local craftList = Instance.new("ScrollingFrame")
craftList.Name = "CraftList"
craftList.Active = true
craftList.BackgroundTransparency = 1
craftList.BorderSizePixel = 0
craftList.Position = UDim2.fromOffset(12, 214)
craftList.ScrollBarThickness = 6
craftList.Size = UDim2.new(1, -24, 1, -226)
craftList.CanvasSize = UDim2.fromOffset(0, 0)
craftList.AutomaticCanvasSize = Enum.AutomaticSize.Y
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
attackButton.AnchorPoint = Vector2.new(0.5, 1)
attackButton.BackgroundColor3 = Color3.fromRGB(126, 64, 58)
attackButton.Position = UDim2.new(0.5, 0, 1, -28)
attackButton.Size = UDim2.fromOffset(110, 36)
attackButton.TextSize = 14
attackButton.Parent = root

local sprintButton = makeButton("Sprint", 110)
sprintButton.Name = "SprintButton"
sprintButton.AnchorPoint = Vector2.new(0.5, 1)
sprintButton.BackgroundColor3 = Color3.fromRGB(70, 92, 72)
sprintButton.Position = UDim2.new(0.5, -124, 1, -28)
sprintButton.Size = UDim2.fromOffset(110, 36)
sprintButton.TextSize = 14
sprintButton.Parent = root

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

local function requestAttack()
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

local function renderInventory()
	clearChildren(inventoryList)

	local ordered = {}
	for itemId in pairs(Config.Items) do
		table.insert(ordered, itemId)
	end
	table.sort(ordered)

	for _, itemId in ipairs(ordered) do
		local count = inventory[itemId] or 0
		if count > 0 then
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

local function renderWorldState()
	local phase = worldState.IsNight and "Night" or "Daylight"
	local threatLine = worldState.Threat and string.format("\nThreat %d/100", worldState.Threat) or ""
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F then
		requestAttack()
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
