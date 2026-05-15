-- InventoryController.lua  (Milestone 3 rebuild)
-- TAB key opens/closes the inventory panel.
-- Shows all 20 slots. Each filled slot shows:
--   item display name, stack count, [Use] and [Drop] buttons.
-- [Use]  fires UseItem  remote → server handles eating/equipping
-- [Drop] fires DropItem remote → server removes and drops the item

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local InventoryController = {}
local ctx

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = {
    bg      = Color3.fromRGB(18, 14, 10),
    surface = Color3.fromRGB(30, 24, 18),
    slot    = Color3.fromRGB(38, 30, 22),
    slotFilled = Color3.fromRGB(50, 40, 28),
    border  = Color3.fromRGB(65, 52, 38),
    text    = Color3.fromRGB(230, 220, 200),
    muted   = Color3.fromRGB(140, 126, 106),
    accent  = Color3.fromRGB(200, 140, 50),
    green   = Color3.fromRGB(80, 200, 100),
    red     = Color3.fromRGB(220, 80, 70),
    useBtn  = Color3.fromRGB(50, 160, 90),
    dropBtn = Color3.fromRGB(160, 60, 50),
}

local gui, slotContainer
local isOpen   = false
local slots    = {}   -- current inventory state from server

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
end

-- ── Build static chrome ───────────────────────────────────────────────────

local function buildGui()
    local old = playerGui:FindFirstChild("InventoryGui")
    if old then old:Destroy() end

    gui              = Instance.new("ScreenGui")
    gui.Name         = "InventoryGui"
    gui.ResetOnSpawn = false
    gui.Enabled      = false
    gui.Parent       = playerGui

    local backdrop = Instance.new("Frame")
    backdrop.Size              = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3  = Color3.fromRGB(0,0,0)
    backdrop.BackgroundTransparency = 0.55
    backdrop.BorderSizePixel   = 0
    backdrop.Parent            = gui

    local modal = Instance.new("Frame")
    modal.Size             = UDim2.new(0, 520, 0, 560)
    modal.Position         = UDim2.new(0.5, -260, 0.5, -280)
    modal.BackgroundColor3 = C.bg
    modal.BorderSizePixel  = 0
    modal.Parent           = gui
    makeCorner(modal, 12)

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size              = UDim2.new(1,0,0,44)
    titleBar.BackgroundColor3  = C.surface
    titleBar.BorderSizePixel   = 0
    titleBar.Parent            = modal
    makeCorner(titleBar, 12)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size              = UDim2.new(1,-50,1,0)
    titleLbl.Position          = UDim2.new(0,16,0,0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text              = "🎒  Inventory"
    titleLbl.TextColor3        = C.accent
    titleLbl.TextSize          = 18
    titleLbl.Font              = Enum.Font.GothamBold
    titleLbl.TextXAlignment    = Enum.TextXAlignment.Left
    titleLbl.Parent            = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size              = UDim2.new(0,32,0,32)
    closeBtn.Position          = UDim2.new(1,-40,0,6)
    closeBtn.BackgroundColor3  = Color3.fromRGB(160,60,50)
    closeBtn.BorderSizePixel   = 0
    closeBtn.Text              = "✕"
    closeBtn.TextColor3        = C.text
    closeBtn.TextSize          = 14
    closeBtn.Font              = Enum.Font.GothamBold
    closeBtn.Parent            = titleBar
    makeCorner(closeBtn, 6)
    closeBtn.MouseButton1Click:Connect(function() InventoryController:close() end)

    -- Hint
    local hint = Instance.new("TextLabel")
    hint.Size              = UDim2.new(1,-16,0,20)
    hint.Position          = UDim2.new(0,8,0,48)
    hint.BackgroundTransparency = 1
    hint.Text              = "TAB to close  •  Use = eat/equip  •  Drop = discard"
    hint.TextColor3        = C.muted
    hint.TextSize          = 11
    hint.Font              = Enum.Font.Gotham
    hint.TextXAlignment    = Enum.TextXAlignment.Left
    hint.Parent            = modal

    -- Scrolling slot list
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name                = "SlotScroll"
    scroll.Size                = UDim2.new(1,-16,1,-80)
    scroll.Position            = UDim2.new(0,8,0,72)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel     = 0
    scroll.ScrollBarThickness  = 4
    scroll.ScrollBarImageColor3 = C.border
    scroll.CanvasSize          = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent              = modal

    slotContainer = scroll

    local layout = Instance.new("UIListLayout")
    layout.SortOrder  = Enum.SortOrder.LayoutOrder
    layout.Padding    = UDim.new(0,6)
    layout.Parent     = scroll

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0,4)
    pad.PaddingBottom = UDim.new(0,8)
    pad.Parent        = scroll
end

-- ── Rebuild slot rows from current `slots` table ──────────────────────────

function InventoryController:refresh()
    if not slotContainer then return end

    for _, child in ipairs(slotContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local slotCount = ctx.Config.Inventory.SlotCount
    for i = 1, slotCount do
        local slot    = slots[i]
        local isEmpty = not slot or not slot.itemId

        local row = Instance.new("Frame")
        row.Size              = UDim2.new(1,-4,0,46)
        row.BackgroundColor3  = isEmpty and C.slot or C.slotFilled
        row.BorderSizePixel   = 0
        row.LayoutOrder       = i
        row.Parent            = slotContainer
        makeCorner(row, 6)

        -- Slot number
        local numLbl = Instance.new("TextLabel")
        numLbl.Size                   = UDim2.new(0,24,1,0)
        numLbl.BackgroundTransparency = 1
        numLbl.Text                   = tostring(i)
        numLbl.TextColor3             = C.muted
        numLbl.TextSize               = 11
        numLbl.Font                   = Enum.Font.Gotham
        numLbl.Parent                 = row

        if not isEmpty then
            local itemCfg = ctx.Config.Items[slot.itemId]
            local name    = itemCfg and itemCfg.displayName or slot.itemId

            -- Item name
            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size                   = UDim2.new(1,-170,1,0)
            nameLbl.Position               = UDim2.new(0,28,0,0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text                   = name
            nameLbl.TextColor3             = C.text
            nameLbl.TextSize               = 14
            nameLbl.Font                   = Enum.Font.GothamBold
            nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
            nameLbl.Parent                 = row

            -- Stack count
            local stackLbl = Instance.new("TextLabel")
            stackLbl.Size                   = UDim2.new(0,40,1,0)
            stackLbl.Position               = UDim2.new(1,-168,0,0)
            stackLbl.BackgroundTransparency = 1
            stackLbl.Text                   = "x" .. (slot.amount or 1)
            stackLbl.TextColor3             = C.muted
            stackLbl.TextSize               = 13
            stackLbl.Font                   = Enum.Font.Gotham
            stackLbl.TextXAlignment         = Enum.TextXAlignment.Right
            stackLbl.Parent                 = row

            -- Category badge
            if itemCfg then
                local badgeColor = {
                    food     = Color3.fromRGB(180,120,40),
                    tool     = Color3.fromRGB(80,140,200),
                    weapon   = Color3.fromRGB(200,80,80),
                    resource = Color3.fromRGB(100,160,80),
                    placeable= Color3.fromRGB(160,100,200),
                }
                local badge = Instance.new("TextLabel")
                badge.Size                   = UDim2.new(0,64,0,18)
                badge.Position               = UDim2.new(0,28,1,-22)
                badge.BackgroundColor3       = badgeColor[itemCfg.category] or C.muted
                badge.BackgroundTransparency = 0.5
                badge.BorderSizePixel        = 0
                badge.Text                   = itemCfg.category
                badge.TextColor3             = C.text
                badge.TextSize               = 10
                badge.Font                   = Enum.Font.GothamBold
                badge.Parent                 = row
                makeCorner(badge, 4)
            end

            -- [Use] button
            local useBtn = Instance.new("TextButton")
            useBtn.Size              = UDim2.new(0,52,0,28)
            useBtn.Position          = UDim2.new(1,-118,0.5,-14)
            useBtn.BackgroundColor3  = C.useBtn
            useBtn.BorderSizePixel   = 0
            useBtn.Text              = "Use"
            useBtn.TextColor3        = C.text
            useBtn.TextSize          = 13
            useBtn.Font              = Enum.Font.GothamBold
            useBtn.Parent            = row
            makeCorner(useBtn, 5)
            local slotIndex = i
            useBtn.MouseButton1Click:Connect(function()
                ctx.Remotes.UseItem:FireServer(slotIndex)
            end)

            -- [Drop] button
            local dropBtn = Instance.new("TextButton")
            dropBtn.Size              = UDim2.new(0,52,0,28)
            dropBtn.Position          = UDim2.new(1,-60,0.5,-14)
            dropBtn.BackgroundColor3  = C.dropBtn
            dropBtn.BorderSizePixel   = 0
            dropBtn.Text              = "Drop"
            dropBtn.TextColor3        = C.text
            dropBtn.TextSize          = 13
            dropBtn.Font              = Enum.Font.GothamBold
            dropBtn.Parent            = row
            makeCorner(dropBtn, 5)
            dropBtn.MouseButton1Click:Connect(function()
                ctx.Remotes.DropItem:FireServer(slotIndex)
            end)
        else
            -- Empty slot label
            local emptyLbl = Instance.new("TextLabel")
            emptyLbl.Size                   = UDim2.new(1,-30,1,0)
            emptyLbl.Position               = UDim2.new(0,28,0,0)
            emptyLbl.BackgroundTransparency = 1
            emptyLbl.Text                   = "— empty —"
            emptyLbl.TextColor3             = C.muted
            emptyLbl.TextSize               = 12
            emptyLbl.Font                   = Enum.Font.Gotham
            emptyLbl.TextXAlignment         = Enum.TextXAlignment.Left
            emptyLbl.Parent                 = row
        end
    end
end

-- ── Open / close ──────────────────────────────────────────────────────────

function InventoryController:open()
    if not gui then buildGui() end
    isOpen      = true
    gui.Enabled = true
    self:refresh()
end

function InventoryController:close()
    isOpen = false
    if gui then gui.Enabled = false end
end

function InventoryController:toggle()
    if isOpen then self:close() else self:open() end
end

-- ── Init ──────────────────────────────────────────────────────────────────

function InventoryController:init(context)
    ctx = context
    buildGui()

    ctx.Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
        slots = data
        if isOpen then self:refresh() end
    end)

    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Tab then
            self:toggle()
        end
    end)
end

return InventoryController
