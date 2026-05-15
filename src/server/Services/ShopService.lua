local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.SurvivalConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ShopService = {}

local context
local shopsFolder
local worldPerformance = (Config.World and Config.World.Performance) or {}
local TONE_DOWN_SMOOTH_SURFACES = worldPerformance.ToneDownSmoothSurfaces ~= false

local function getWorldFolder()
	local worldFolder = Workspace:FindFirstChild("SurvivalWorld")
	if not worldFolder then
		worldFolder = Instance.new("Folder")
		worldFolder.Name = "SurvivalWorld"
		worldFolder.Parent = Workspace
	end
	return worldFolder
end

local function getItemDisplayName(itemId)
	local itemConfig = Config.Items[itemId]
	return itemConfig and itemConfig.DisplayName or itemId
end

local function findCatalogEntry(shopConfig, entryId)
	for _, entry in ipairs(shopConfig.Catalog or {}) do
		if entry.Id == entryId then
			return entry
		end
	end
	return nil
end

local function openShopForPlayer(player, shopId)
	Remotes.get("ShopOpened"):FireClient(player, shopId)
end

local function addBasePart(model, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = (TONE_DOWN_SMOOTH_SURFACES and material == Enum.Material.SmoothPlastic) and Enum.Material.Plastic or material
	part.Reflectance = 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function getConfigColor(shopConfig, key, fallback)
	local value = shopConfig and shopConfig[key]
	if typeof(value) == "Color3" then
		return value
	end
	return fallback
end

local function addCylinder(model, name, radius, length, cframe, color, material)
	local cylinder = addBasePart(model, name, Vector3.new(radius, length, radius), cframe, color, material)
	cylinder.Shape = Enum.PartType.Cylinder
	return cylinder
end

local function addLantern(model, cframe, color)
	local lantern = addBasePart(model, "ShopLantern", Vector3.new(1.1, 1.1, 1.1), cframe, color, Enum.Material.Neon)
	lantern.Shape = Enum.PartType.Ball
	lantern.CanCollide = false
	lantern.CanTouch = false
	lantern.CanQuery = false

	local light = Instance.new("PointLight")
	light.Name = "ShopGlow"
	light.Brightness = 1.2
	light.Range = 16
	light.Color = color
	light.Parent = lantern
end

local function addVendorMarker(model, baseCFrame, accentColor)
	local body = addBasePart(
		model,
		"VendorBody",
		Vector3.new(2.2, 3.4, 1.3),
		baseCFrame * CFrame.new(-3.2, 3.2, -2.15),
		Color3.fromRGB(84, 70, 55),
		Enum.Material.Fabric
	)
	body.CanCollide = false

	local head = addBasePart(
		model,
		"VendorHead",
		Vector3.new(1.65, 1.65, 1.65),
		baseCFrame * CFrame.new(-3.2, 5.65, -2.15),
		Color3.fromRGB(177, 136, 93),
		Enum.Material.SmoothPlastic
	)
	head.Shape = Enum.PartType.Ball
	head.CanCollide = false

	local hat = addBasePart(
		model,
		"VendorHat",
		Vector3.new(2.4, 0.55, 2.4),
		baseCFrame * CFrame.new(-3.2, 6.65, -2.15),
		accentColor,
		Enum.Material.Fabric
	)
	hat.CanCollide = false
end

local function addStockDisplays(model, baseCFrame, shopConfig, accentColor)
	local stockTheme = shopConfig.StockTheme or "General"

	for index = 1, 3 do
		local crate = addBasePart(
			model,
			"ShopSupplyCrate",
			Vector3.new(2.1, 1.8, 2.1),
			baseCFrame * CFrame.new(2.2 + index * 1.9, 1.2, 1.9 + (index % 2) * 0.7),
			Color3.fromRGB(96, 65, 39),
			Enum.Material.WoodPlanks
		)
		crate.CanCollide = false
	end

	if stockTheme == "Forge" then
		local anvil = addBasePart(model, "ShopAnvil", Vector3.new(3.2, 1.1, 1.4), baseCFrame * CFrame.new(2.5, 2.7, -1.9), Color3.fromRGB(69, 71, 73), Enum.Material.Metal)
		anvil.CanCollide = false
		for index = 1, 5 do
			local ingot = addBasePart(
				model,
				"ShopIngot",
				Vector3.new(1.8, 0.45, 0.75),
				baseCFrame * CFrame.new(-2 + index * 0.85, 3.32, -1.85),
				Color3.fromRGB(172, 126, 79),
				Enum.Material.Metal
			)
			ingot.CanCollide = false
		end
	elseif stockTheme == "Medic" then
		for index = 1, 5 do
			local bottle = addCylinder(
				model,
				"ShopBottle",
				0.55,
				1.6,
				baseCFrame * CFrame.new(-1.7 + index * 0.8, 3.3, -1.95),
				index % 2 == 0 and Color3.fromRGB(77, 155, 101) or Color3.fromRGB(107, 184, 178),
				Enum.Material.Glass
			)
			bottle.Transparency = 0.18
			bottle.CanCollide = false
		end
	elseif stockTheme == "Builder" then
		for index = 1, 5 do
			local plank = addBasePart(
				model,
				"ShopPlankStack",
				Vector3.new(5.4, 0.35, 1.05),
				baseCFrame * CFrame.new(1.2, 1 + index * 0.42, 2.9) * CFrame.Angles(0, math.rad(index * 4), 0),
				Color3.fromRGB(124, 82, 45),
				Enum.Material.WoodPlanks
			)
			plank.CanCollide = false
		end
	elseif stockTheme == "Food" then
		for index = 1, 5 do
			local basket = addBasePart(
				model,
				"ShopFoodBasket",
				Vector3.new(1.4, 1.2, 1.4),
				baseCFrame * CFrame.new(-2.2 + index * 0.9, 3.2, -1.9),
				index % 2 == 0 and Color3.fromRGB(131, 45, 59) or Color3.fromRGB(142, 105, 55),
				Enum.Material.WoodPlanks
			)
			basket.Shape = Enum.PartType.Ball
			basket.CanCollide = false
		end
	elseif stockTheme == "Relic" then
		for index = 1, 4 do
			local shard = addBasePart(
				model,
				"ShopRelicShard",
				Vector3.new(0.8, 2.8 + index * 0.5, 0.8),
				baseCFrame * CFrame.new(-1.7 + index * 1.15, 3.8, -1.9) * CFrame.Angles(0, math.rad(index * 24), math.rad(10 - index * 4)),
				accentColor,
				Enum.Material.Neon
			)
			shard.CanCollide = false
		end
	end

	addLantern(model, baseCFrame * CFrame.new(4.9, 6.7, 1.2), accentColor)
end

local function createShopStand(shopId, shopConfig, position)
	local terrainY = position.Y
	if context and context.WorldService and context.WorldService.getTerrainHeightAt then
		terrainY = context.WorldService.getTerrainHeightAt(position.X, position.Z)
	end

	local baseCFrame = CFrame.new(position.X, terrainY + 0.3, position.Z)
	local model = Instance.new("Model")
	model.Name = "Shop_" .. shopId
	model.Parent = shopsFolder
	local accentColor = getConfigColor(shopConfig, "AccentColor", Color3.fromRGB(210, 164, 83))
	local counterColor = getConfigColor(shopConfig, "CounterColor", Color3.fromRGB(98, 66, 41))

	local base = addBasePart(
		model,
		"ShopBase",
		Vector3.new(12, 0.6, 8),
		baseCFrame,
		Color3.fromRGB(92, 88, 80),
		Enum.Material.Cobblestone
	)

	local counter = addBasePart(
		model,
		"ShopCounter",
		Vector3.new(8, 3, 2),
		baseCFrame * CFrame.new(0, 1.8, -2.2),
		counterColor,
		Enum.Material.WoodPlanks
	)

	local backWall = addBasePart(
		model,
		"ShopBackWall",
		Vector3.new(9, 6, 0.8),
		baseCFrame * CFrame.new(0, 3.2, -3.5),
		Color3.fromRGB(73, 54, 40),
		Enum.Material.WoodPlanks
	)
	backWall.CanCollide = false

	local canopy = addBasePart(
		model,
		"ShopCanopy",
		Vector3.new(12.6, 0.4, 8.4),
		baseCFrame * CFrame.new(0, 6.2, 0),
		accentColor,
		Enum.Material.Fabric
	)
	canopy.CanCollide = false

	local sign = addBasePart(
		model,
		"ShopSign",
		Vector3.new(8, 2, 0.25),
		baseCFrame * CFrame.new(0, 7.8, 1.9),
		Color3.fromRGB(66, 49, 33),
		Enum.Material.WoodPlanks
	)
	sign.CanCollide = false
	addVendorMarker(model, baseCFrame, accentColor)
	addStockDisplays(model, baseCFrame, shopConfig, accentColor)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "ShopLabel"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 24
	surface.Parent = sign

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(240, 228, 195)
	title.Text = string.upper(shopConfig.DisplayName or shopId)
	title.Parent = surface

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = shopConfig.PromptText or "Trade"
	prompt.ObjectText = shopConfig.DisplayName or "Shop"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	prompt.Triggered:Connect(function(player)
		openShopForPlayer(player, shopId)
	end)

	model.PrimaryPart = base
end

local function spawnShops()
	local worldFolder = getWorldFolder()
	shopsFolder = worldFolder:FindFirstChild("Shops")
	if not shopsFolder then
		shopsFolder = Instance.new("Folder")
		shopsFolder.Name = "Shops"
		shopsFolder.Parent = worldFolder
	end

	for _, child in ipairs(shopsFolder:GetChildren()) do
		child:Destroy()
	end

	for shopId, shopConfig in pairs(Config.Shops or {}) do
		for _, position in ipairs(shopConfig.WorldPositions or {}) do
			if typeof(position) == "Vector3" then
				createShopStand(shopId, shopConfig, position)
			end
		end
	end
end

function ShopService.purchase(player, shopId, entryId)
	if type(shopId) ~= "string" or type(entryId) ~= "string" then
		return false, "Invalid shop request."
	end

	local inventory = context and context.InventoryService
	if not inventory then
		return false, "Shop is unavailable."
	end

	local shopConfig = Config.Shops and Config.Shops[shopId]
	if not shopConfig then
		return false, "Unknown shop."
	end

	local entry = findCatalogEntry(shopConfig, entryId)
	if not entry then
		return false, "Unknown item."
	end

	local itemId = entry.ItemId
	if type(itemId) ~= "string" or not Config.Items[itemId] then
		return false, "Shop item is misconfigured."
	end

	local amount = math.max(1, math.floor(tonumber(entry.Amount) or 1))
	local cost = type(entry.Cost) == "table" and entry.Cost or {}

	local canAfford, missingItemId = inventory.hasItems(player, cost)
	if not canAfford then
		return false, string.format("Need more %s.", getItemDisplayName(missingItemId))
	end

	if not inventory.removeItems(player, cost) then
		return false, "Not enough resources."
	end
	inventory.addItem(player, itemId, amount)

	local displayName = entry.DisplayName or getItemDisplayName(itemId)
	return true, string.format("Purchased %s x%d.", displayName, amount)
end

function ShopService.init(newContext)
	context = newContext
	spawnShops()

	Remotes.get("ShopRequest").OnServerInvoke = function(player, shopId, entryId)
		return ShopService.purchase(player, shopId, entryId)
	end
end

return ShopService
