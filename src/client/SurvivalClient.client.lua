local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local inventory = {}
local vitals = {
	Hunger = 100,
	Thirst = 100,
	Temperature = 72,
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
vitalsPanel.Size = UDim2.fromOffset(270, 112)
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

local function showNotification(message)
	notification.Text = message
	notification.Visible = true

	task.delay(2.4, function()
		if notification.Text == message then
			notification.Visible = false
		end
	end)
end

local function updateVitals()
	for name, bar in pairs(vitalBars) do
		local value = vitals[name] or 0
		local percent = name == "Temperature" and math.clamp(value / 100, 0, 1) or math.clamp(value / 100, 0, 1)

		bar.Label.Text = string.format("%s  %d", name, value)
		bar.Fill.Size = UDim2.fromScale(percent, 1)
	end
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
			label.Text = string.format("%s  x%d", itemConfig.DisplayName, count)
			label.TextColor3 = Color3.fromRGB(235, 238, 229)
			label.TextSize = 13
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Position = UDim2.fromOffset(10, 0)
			label.Size = UDim2.new(1, -150, 1, 0)
			label.Parent = row

			if Config.Consumables[itemId] then
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
		cost.Text = formatCost(recipe.Cost)
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

local function renderAll()
	updateVitals()
	renderInventory()
	renderCrafting()
end

Remotes.get("VitalsUpdated").OnClientEvent:Connect(function(newVitals)
	vitals = newVitals
	updateVitals()
end)

Remotes.get("InventoryUpdated").OnClientEvent:Connect(function(newInventory)
	inventory = newInventory
	renderAll()
end)

Remotes.get("Notification").OnClientEvent:Connect(showNotification)

task.spawn(function()
	local ok, result = pcall(function()
		return Remotes.get("GetInventory"):InvokeServer()
	end)

	if ok and type(result) == "table" then
		inventory = result
	end

	renderAll()
end)

pcall(function()
	StarterGui:SetCore("ResetButtonCallback", true)
end)
