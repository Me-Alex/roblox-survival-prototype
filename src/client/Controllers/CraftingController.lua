-- CraftingController.lua  (Milestone 3)
-- Opens/closes a crafting menu when the player presses C.
-- Displays recipes grouped by category. Shows which ingredients are met
-- in green (have enough) or red (missing). Craft button fires CraftRequest.
--
-- UI LAYOUT:
--   Screen centre modal:
--     [Title bar]  "Crafting"  [X close]
--     [Category tabs: Tools | Weapons | Survival | Food]
--     [Recipe list — scrolling frame]
--       Each recipe card:
--         Recipe name (bold)
--         Ingredients row  (green = have it, red = missing)
--         [Craft] button

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local CraftingController = {}
local ctx

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- colours
local C = {
    bg      = Color3.fromRGB(18, 14, 10),
    surface = Color3.fromRGB(30, 24, 18),
    card    = Color3.fromRGB(40, 32, 24),
    border  = Color3.fromRGB(60, 50, 38),
    text    = Color3.fromRGB(230, 220, 200),
    muted   = Color3.fromRGB(150, 136, 116),
    green   = Color3.fromRGB(80, 200, 100),
    red     = Color3.fromRGB(220, 80,  70),
    accent  = Color3.fromRGB(200, 140, 50),
    tabSel  = Color3.fromRGB(200, 140, 50),
    tabDef  = Color3.fromRGB(50, 40, 30),
    btn     = Color3.fromRGB(180, 120, 40),
    btnHov  = Color3.fromRGB(210, 150, 60),
}

local gui, modal, listFrame
local isOpen         = false
local activeCategory = "Tools"
local inventory      = {}   -- mirror of server inventory, updated via InventoryUpdate
local categories     = { "Tools", "Weapons", "Survival", "Food" }

local function computeCategories()
    local map = {}
    for _, recipe in pairs(ctx.Config.Recipes or {}) do
        if type(recipe) == "table" and type(recipe.category) == "string" and recipe.category ~= "" then
            map[recipe.category] = true
        end
    end

    local order = { "Tools", "Weapons", "Survival", "Food", "Building", "Armor" }
    local result = {}
    local seen = {}
    for _, name in ipairs(order) do
        if map[name] then
            table.insert(result, name)
            seen[name] = true
        end
    end

    for name in pairs(map) do
        if not seen[name] then
            table.insert(result, name)
        end
    end

    if #result == 0 then
        result = { "Tools" }
    end
    return result
end

-- ── helpers ───────────────────────────────────────────────────────────────

local function countItem(itemId)
    local total = 0
    for _, slot in ipairs(inventory) do
        local slotItemId = slot and (slot.itemId or slot.id)
        if slotItemId == itemId then
            total = total + (slot.amount or slot.qty or 0)
        end
    end
    return total
end

local function canCraft(recipe)
    for itemId, needed in pairs(recipe.ingredients or {}) do
        if countItem(itemId) < needed then return false end
    end
    return true
end

local function getRecipesForCategory(category)
    local list = {}
    for recipeId, recipe in pairs(ctx.Config.Recipes or {}) do
        if recipe.category == category then
            table.insert(list, { id = recipeId, recipe = recipe })
        end
    end

    table.sort(list, function(a, b)
        local aItem = ctx.Config.Items[a.recipe.result]
        local bItem = ctx.Config.Items[b.recipe.result]
        local aName = (aItem and aItem.displayName) or a.recipe.result or a.id
        local bName = (bItem and bItem.displayName) or b.recipe.result or b.id
        return aName < bName
    end)

    return list
end

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
end

local function label(parent, text, size, color, bold, xAlign)
    local l = Instance.new("TextLabel")
    l.Size                   = UDim2.new(1, 0, 0, size + 4)
    l.BackgroundTransparency = 1
    l.Text                   = text
    l.TextColor3             = color or C.text
    l.TextSize               = size or 14
    l.Font                   = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextXAlignment         = xAlign or Enum.TextXAlignment.Left
    l.Parent                 = parent
    return l
end

-- ── Build static chrome ───────────────────────────────────────────────────

local function buildGui()
    local old = playerGui:FindFirstChild("CraftingGui")
    if old then old:Destroy() end

    gui           = Instance.new("ScreenGui")
    gui.Name      = "CraftingGui"
    gui.ResetOnSpawn = false
    gui.Enabled   = false
    gui.Parent    = playerGui

    -- Dark backdrop
    local backdrop = Instance.new("Frame")
    backdrop.Size              = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.55
    backdrop.BorderSizePixel   = 0
    backdrop.Parent            = gui

    -- Modal panel
    modal                      = Instance.new("Frame")
    modal.Name                 = "Modal"
    modal.Size                 = UDim2.new(0, 480, 0, 520)
    modal.Position             = UDim2.new(0.5, -240, 0.5, -260)
    modal.BackgroundColor3     = C.bg
    modal.BorderSizePixel      = 0
    modal.Parent               = gui
    makeCorner(modal, 12)

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size              = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundColor3  = C.surface
    titleBar.BorderSizePixel   = 0
    titleBar.Parent            = modal
    makeCorner(titleBar, 12)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size              = UDim2.new(1, -50, 1, 0)
    titleLbl.Position          = UDim2.new(0, 16, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text              = "⚒  Crafting"
    titleLbl.TextColor3        = C.accent
    titleLbl.TextSize          = 18
    titleLbl.Font              = Enum.Font.GothamBold
    titleLbl.TextXAlignment    = Enum.TextXAlignment.Left
    titleLbl.Parent            = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size              = UDim2.new(0, 32, 0, 32)
    closeBtn.Position          = UDim2.new(1, -40, 0, 6)
    closeBtn.BackgroundColor3  = Color3.fromRGB(160, 60, 50)
    closeBtn.BorderSizePixel   = 0
    closeBtn.Text              = "✕"
    closeBtn.TextColor3        = C.text
    closeBtn.TextSize          = 14
    closeBtn.Font              = Enum.Font.GothamBold
    closeBtn.Parent            = titleBar
    makeCorner(closeBtn, 6)
    closeBtn.MouseButton1Click:Connect(function() CraftingController:close() end)

    -- Category tab bar
    local tabBar = Instance.new("Frame")
    tabBar.Name                = "TabBar"
    tabBar.Size                = UDim2.new(1, 0, 0, 38)
    tabBar.Position            = UDim2.new(0, 0, 0, 44)
    tabBar.BackgroundColor3    = C.surface
    tabBar.BorderSizePixel     = 0
    tabBar.Parent              = modal

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection    = Enum.FillDirection.Horizontal
    tabLayout.SortOrder        = Enum.SortOrder.LayoutOrder
    tabLayout.Padding          = UDim.new(0, 4)
    tabLayout.Parent           = tabBar

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingLeft  = UDim.new(0, 8)
    tabPad.PaddingTop   = UDim.new(0, 6)
    tabPad.Parent       = tabBar

    for i, cat in ipairs(categories) do
        local tab = Instance.new("TextButton")
        tab.Name               = "Tab_" .. cat
        tab.Size               = UDim2.new(0, 100, 0, 28)
        tab.BackgroundColor3   = cat == activeCategory and C.tabSel or C.tabDef
        tab.BorderSizePixel    = 0
        tab.Text               = cat
        tab.TextColor3         = C.text
        tab.TextSize           = 13
        tab.Font               = Enum.Font.GothamBold
        tab.LayoutOrder        = i
        tab.Parent             = tabBar
        makeCorner(tab, 6)

        tab.MouseButton1Click:Connect(function()
            activeCategory = cat
            CraftingController:refresh()
        end)
    end

    -- Scrolling recipe list
    local scrollContainer = Instance.new("Frame")
    scrollContainer.Size           = UDim2.new(1, -16, 1, -100)
    scrollContainer.Position       = UDim2.new(0, 8, 0, 90)
    scrollContainer.BackgroundTransparency = 1
    scrollContainer.BorderSizePixel = 0
    scrollContainer.Parent         = modal

    listFrame = Instance.new("ScrollingFrame")
    listFrame.Name                 = "RecipeList"
    listFrame.Size                 = UDim2.new(1, 0, 1, 0)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel      = 0
    listFrame.ScrollBarThickness   = 4
    listFrame.ScrollBarImageColor3 = C.border
    listFrame.CanvasSize           = UDim2.new(0, 0, 0, 0)
    listFrame.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    listFrame.Parent               = scrollContainer

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder           = Enum.SortOrder.LayoutOrder
    listLayout.Padding             = UDim.new(0, 8)
    listLayout.Parent              = listFrame

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop    = UDim.new(0, 4)
    listPad.PaddingBottom = UDim.new(0, 8)
    listPad.Parent        = listFrame
end

-- ── Populate recipe cards for current category ────────────────────────────

function CraftingController:refresh()
    if not listFrame then return end

    -- Update tab colours
    local tabBar = modal and modal:FindFirstChild("TabBar")
    if tabBar then
        for _, cat in ipairs(categories) do
            local tab = tabBar:FindFirstChild("Tab_" .. cat)
            if tab then
                tab.BackgroundColor3 = cat == activeCategory and C.tabSel or C.tabDef
            end
        end
    end

    -- Clear old cards
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Build new cards
    local order = 0
    local recipes = getRecipesForCategory(activeCategory)
    for _, entry in ipairs(recipes) do
        local recipeId = entry.id
        local recipe = entry.recipe
        order = order + 1

        local craftable = canCraft(recipe)

        -- Card
        local card = Instance.new("Frame")
        card.Size              = UDim2.new(1, -8, 0, 80)
        card.BackgroundColor3  = C.card
        card.BorderSizePixel   = 0
        card.LayoutOrder       = order
        card.Parent            = listFrame
        makeCorner(card, 8)

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft   = UDim.new(0, 10)
        pad.PaddingRight  = UDim.new(0, 10)
        pad.PaddingTop    = UDim.new(0, 8)
        pad.Parent        = card

        -- Recipe name
        local itemCfg = ctx.Config.Items[recipe.result]
        local nameLbl = label(card,
            (itemCfg and itemCfg.displayName or recipe.result or recipeId)
            .. ((recipe.amount or 1) > 1 and "  x" .. tostring(recipe.amount) or ""),
            15, C.text, true)
        nameLbl.Position = UDim2.new(0, 0, 0, 0)
        nameLbl.Size     = UDim2.new(1, -90, 0, 20)

        -- Near fire warning
        local stationText
        if recipe.nearFire and recipe.nearOven then
            stationText = "🔥 Near campfire or stone oven"
        elseif recipe.nearFire then
            stationText = "🔥 Near campfire only"
        elseif recipe.nearOven then
            stationText = "🔥 Near stone oven only"
        end
        if stationText then
            local fireNote = label(card, stationText, 11, Color3.fromRGB(210,130,40), false)
            fireNote.Position = UDim2.new(0, 0, 0, 20)
            fireNote.Size     = UDim2.new(0.7, 0, 0, 16)
        end

        -- Ingredients row
        local ingRow = Instance.new("Frame")
        ingRow.Size              = UDim2.new(1, -90, 0, 18)
        ingRow.Position          = UDim2.new(0, 0, 0, stationText and 38 or 24)
        ingRow.BackgroundTransparency = 1
        ingRow.Parent            = card

        local ingLayout = Instance.new("UIListLayout")
        ingLayout.FillDirection  = Enum.FillDirection.Horizontal
        ingLayout.Padding        = UDim.new(0, 6)
        ingLayout.Parent         = ingRow

        for itemId, needed in pairs(recipe.ingredients or {}) do
            local have    = countItem(itemId)
            local enough  = have >= needed
            local itemDef = ctx.Config.Items[itemId]
            local ingLbl  = Instance.new("TextLabel")
            ingLbl.Size                   = UDim2.new(0, 0, 1, 0)
            ingLbl.AutomaticSize          = Enum.AutomaticSize.X
            ingLbl.BackgroundTransparency = 1
            ingLbl.Text                   = (itemDef and itemDef.displayName or itemId) .. " " .. have .. "/" .. needed
            ingLbl.TextColor3             = enough and C.green or C.red
            ingLbl.TextSize               = 11
            ingLbl.Font                   = Enum.Font.Gotham
            ingLbl.Parent                 = ingRow
        end

        -- Craft button
        local craftBtn = Instance.new("TextButton")
        craftBtn.Size              = UDim2.new(0, 78, 0, 32)
        craftBtn.Position          = UDim2.new(1, -80, 0.5, -16)
        craftBtn.BackgroundColor3  = craftable and C.btn or Color3.fromRGB(60,50,40)
        craftBtn.BorderSizePixel   = 0
        craftBtn.Text              = "Craft"
        craftBtn.TextColor3        = craftable and C.text or C.muted
        craftBtn.TextSize          = 14
        craftBtn.Font              = Enum.Font.GothamBold
        craftBtn.Parent            = card
        makeCorner(craftBtn, 6)

        if craftable then
            craftBtn.MouseButton1Click:Connect(function()
                ctx.Remotes.CraftRequest:FireServer(recipeId)
                task.wait(0.2)
                CraftingController:refresh()
            end)
        end
    end
end

-- ── Open / close ──────────────────────────────────────────────────────────

function CraftingController:open()
    if not gui then buildGui() end
    isOpen       = true
    gui.Enabled  = true
    self:refresh()
end

function CraftingController:close()
    isOpen = false
    if gui then gui.Enabled = false end
end

function CraftingController:toggle()
    if isOpen then self:close() else self:open() end
end

-- ── Init ──────────────────────────────────────────────────────────────────

function CraftingController:init(context)
    ctx = context
    categories = computeCategories()
    if not table.find(categories, activeCategory) then
        activeCategory = categories[1]
    end
    buildGui()

    -- Keep a local mirror of inventory so ingredient counts are always fresh
    ctx.Remotes.InventoryUpdate.OnClientEvent:Connect(function(slots)
        inventory = slots
        if isOpen then self:refresh() end
    end)

    -- Keyboard toggle
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.C then
            self:toggle()
        end
    end)
end

return CraftingController
