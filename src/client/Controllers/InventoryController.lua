local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local InventoryController = {}
local ctx

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = {
    bg = Color3.fromRGB(18, 14, 10),
    surface = Color3.fromRGB(30, 24, 18),
    slot = Color3.fromRGB(38, 30, 22),
    slotFilled = Color3.fromRGB(50, 40, 28),
    border = Color3.fromRGB(65, 52, 38),
    text = Color3.fromRGB(230, 220, 200),
    muted = Color3.fromRGB(140, 126, 106),
    accent = Color3.fromRGB(200, 140, 50),
    useBtn = Color3.fromRGB(50, 160, 90),
    dropBtn = Color3.fromRGB(160, 60, 50),
}

local ITEM_VISUALS = {
    Wood = { Shape = "Block", Size = Vector3.new(1.7, 0.5, 0.8), Color = Color3.fromRGB(101, 67, 42), Material = Enum.Material.Wood },
    Stone = { Shape = "Ball", Size = Vector3.new(1.1, 1.1, 1.1), Color = Color3.fromRGB(112, 116, 118), Material = Enum.Material.Slate },
    Fiber = { Shape = "Block", Size = Vector3.new(0.4, 1.5, 0.3), Color = Color3.fromRGB(92, 142, 76), Material = Enum.Material.Grass },
    RawMeat = { Shape = "Ball", Size = Vector3.new(1.1, 0.9, 1), Color = Color3.fromRGB(153, 62, 64), Material = Enum.Material.SmoothPlastic },
    CookedMeat = { Shape = "Ball", Size = Vector3.new(1.1, 0.9, 1), Color = Color3.fromRGB(118, 70, 41), Material = Enum.Material.SmoothPlastic },
    Berry = { Shape = "Ball", Size = Vector3.new(0.9, 0.9, 0.9), Color = Color3.fromRGB(166, 43, 70), Material = Enum.Material.SmoothPlastic },
    Bandage = { Shape = "Block", Size = Vector3.new(1.2, 0.35, 0.65), Color = Color3.fromRGB(226, 221, 196), Material = Enum.Material.Fabric },
    StoneAxe = { Shape = "Cylinder", Size = Vector3.new(2.1, 0.2, 0.2), Color = Color3.fromRGB(101, 64, 38), Material = Enum.Material.Wood },
    Spear = { Shape = "Cylinder", Size = Vector3.new(2.4, 0.18, 0.18), Color = Color3.fromRGB(112, 76, 45), Material = Enum.Material.Wood },
    Campfire = { Shape = "Block", Size = Vector3.new(1.2, 0.5, 1.2), Color = Color3.fromRGB(180, 90, 20), Material = Enum.Material.Neon },
    Bedroll = { Shape = "Block", Size = Vector3.new(1.3, 0.35, 0.9), Color = Color3.fromRGB(55, 80, 55), Material = Enum.Material.Fabric },
}

local gui
local slotContainer
local isOpen = false
local slots = {}

local function makeCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
end

local function resolveSlot(slot)
    if not slot then
        return nil, 0
    end
    local itemId = slot.itemId or slot.id
    local amount = slot.amount or slot.qty or 1
    return itemId, amount
end

local function makeIconPart(model, itemId)
    local visual = ITEM_VISUALS[itemId] or {
        Shape = "Block",
        Size = Vector3.new(1.2, 0.8, 1),
        Color = Color3.fromRGB(130, 130, 120),
        Material = Enum.Material.SmoothPlastic,
    }

    local part = Instance.new("Part")
    part.Name = "IconPart"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Size = visual.Size
    part.Color = visual.Color
    part.Material = visual.Material
    if visual.Shape == "Ball" then
        part.Shape = Enum.PartType.Ball
    elseif visual.Shape == "Cylinder" then
        part.Shape = Enum.PartType.Cylinder
    else
        part.Shape = Enum.PartType.Block
    end
    part.Parent = model
    return part
end

local function addIcon(parent, itemId)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.fromOffset(34, 34)
    holder.Position = UDim2.new(0, 26, 0.5, -17)
    holder.BackgroundColor3 = Color3.fromRGB(24, 20, 16)
    holder.BorderSizePixel = 0
    holder.Parent = parent
    makeCorner(holder, 6)

    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.fromScale(1, 1)
    viewport.BackgroundTransparency = 1
    viewport.Ambient = Color3.fromRGB(170, 170, 170)
    viewport.LightColor = Color3.fromRGB(255, 245, 220)
    viewport.LightDirection = Vector3.new(-0.7, -1, -0.3)
    viewport.Parent = holder

    local model = Instance.new("Model")
    model.Parent = viewport
    local part = makeIconPart(model, itemId)
    model.PrimaryPart = part

    local camera = Instance.new("Camera")
    camera.Parent = viewport
    viewport.CurrentCamera = camera

    local cf, size = model:GetBoundingBox()
    local maxSize = math.max(size.X, size.Y, size.Z)
    local distance = maxSize * 2.1
    camera.CFrame = CFrame.new(
        cf.Position + Vector3.new(distance * 0.7, distance * 0.45, distance),
        cf.Position
    )
end

local function buildGui()
    local old = playerGui:FindFirstChild("InventoryGui")
    if old then
        old:Destroy()
    end

    gui = Instance.new("ScreenGui")
    gui.Name = "InventoryGui"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.Parent = playerGui

    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.55
    backdrop.BorderSizePixel = 0
    backdrop.Parent = gui

    local modal = Instance.new("Frame")
    modal.Size = UDim2.new(0, 560, 0, 560)
    modal.Position = UDim2.new(0.5, -280, 0.5, -280)
    modal.BackgroundColor3 = C.bg
    modal.BorderSizePixel = 0
    modal.Parent = gui
    makeCorner(modal, 12)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundColor3 = C.surface
    titleBar.BorderSizePixel = 0
    titleBar.Parent = modal
    makeCorner(titleBar, 12)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -50, 1, 0)
    titleLbl.Position = UDim2.new(0, 16, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "Inventory"
    titleLbl.TextColor3 = C.accent
    titleLbl.TextSize = 18
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -40, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = C.text
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    makeCorner(closeBtn, 6)
    closeBtn.MouseButton1Click:Connect(function()
        InventoryController:close()
    end)

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -16, 0, 20)
    hint.Position = UDim2.new(0, 8, 0, 48)
    hint.BackgroundTransparency = 1
    hint.Text = "TAB to close"
    hint.TextColor3 = C.muted
    hint.TextSize = 11
    hint.Font = Enum.Font.Gotham
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = modal

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "SlotScroll"
    scroll.Size = UDim2.new(1, -16, 1, -80)
    scroll.Position = UDim2.new(0, 8, 0, 72)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = C.border
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = modal
    slotContainer = scroll

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = scroll

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = scroll
end

function InventoryController:refresh()
    if not slotContainer then
        return
    end

    for _, child in ipairs(slotContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local slotCount = (ctx.Config.Inventory and ctx.Config.Inventory.SlotCount) or 20

    for i = 1, slotCount do
        local slot = slots[i]
        local itemId, amount = resolveSlot(slot)
        local isEmpty = not itemId

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 52)
        row.BackgroundColor3 = isEmpty and C.slot or C.slotFilled
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = slotContainer
        makeCorner(row, 6)

        local numLbl = Instance.new("TextLabel")
        numLbl.Size = UDim2.new(0, 24, 1, 0)
        numLbl.BackgroundTransparency = 1
        numLbl.Text = tostring(i)
        numLbl.TextColor3 = C.muted
        numLbl.TextSize = 11
        numLbl.Font = Enum.Font.Gotham
        numLbl.Parent = row

        if isEmpty then
            local emptyLbl = Instance.new("TextLabel")
            emptyLbl.Size = UDim2.new(1, -30, 1, 0)
            emptyLbl.Position = UDim2.new(0, 70, 0, 0)
            emptyLbl.BackgroundTransparency = 1
            emptyLbl.Text = "- empty -"
            emptyLbl.TextColor3 = C.muted
            emptyLbl.TextSize = 12
            emptyLbl.Font = Enum.Font.Gotham
            emptyLbl.TextXAlignment = Enum.TextXAlignment.Left
            emptyLbl.Parent = row
        else
            addIcon(row, itemId)

            local itemCfg = ctx.Config.Items[itemId]
            local name = (itemCfg and itemCfg.displayName) or itemId
            local category = (itemCfg and itemCfg.category) or "item"

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -250, 0, 22)
            nameLbl.Position = UDim2.new(0, 68, 0, 6)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = name
            nameLbl.TextColor3 = C.text
            nameLbl.TextSize = 14
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = row

            local categoryLbl = Instance.new("TextLabel")
            categoryLbl.Size = UDim2.new(0, 72, 0, 18)
            categoryLbl.Position = UDim2.new(0, 68, 0, 28)
            categoryLbl.BackgroundColor3 = C.border
            categoryLbl.BackgroundTransparency = 0.25
            categoryLbl.BorderSizePixel = 0
            categoryLbl.Text = category
            categoryLbl.TextColor3 = C.text
            categoryLbl.TextSize = 10
            categoryLbl.Font = Enum.Font.GothamBold
            categoryLbl.Parent = row
            makeCorner(categoryLbl, 4)

            local stackLbl = Instance.new("TextLabel")
            stackLbl.Size = UDim2.new(0, 52, 1, 0)
            stackLbl.Position = UDim2.new(1, -172, 0, 0)
            stackLbl.BackgroundTransparency = 1
            stackLbl.Text = "x" .. tostring(amount)
            stackLbl.TextColor3 = C.muted
            stackLbl.TextSize = 13
            stackLbl.Font = Enum.Font.Gotham
            stackLbl.TextXAlignment = Enum.TextXAlignment.Right
            stackLbl.Parent = row

            local slotIndex = i

            local useBtn = Instance.new("TextButton")
            useBtn.Size = UDim2.new(0, 52, 0, 28)
            useBtn.Position = UDim2.new(1, -118, 0.5, -14)
            useBtn.BackgroundColor3 = C.useBtn
            useBtn.BorderSizePixel = 0
            useBtn.Text = "Use"
            useBtn.TextColor3 = C.text
            useBtn.TextSize = 13
            useBtn.Font = Enum.Font.GothamBold
            useBtn.Parent = row
            makeCorner(useBtn, 5)
            useBtn.MouseButton1Click:Connect(function()
                if ctx.Remotes.UseItem then
                    ctx.Remotes.UseItem:FireServer(slotIndex)
                end
            end)

            local dropBtn = Instance.new("TextButton")
            dropBtn.Size = UDim2.new(0, 52, 0, 28)
            dropBtn.Position = UDim2.new(1, -60, 0.5, -14)
            dropBtn.BackgroundColor3 = C.dropBtn
            dropBtn.BorderSizePixel = 0
            dropBtn.Text = "Drop"
            dropBtn.TextColor3 = C.text
            dropBtn.TextSize = 13
            dropBtn.Font = Enum.Font.GothamBold
            dropBtn.Parent = row
            makeCorner(dropBtn, 5)
            dropBtn.MouseButton1Click:Connect(function()
                if ctx.Remotes.DropItem then
                    ctx.Remotes.DropItem:FireServer(slotIndex)
                end
            end)
        end
    end
end

function InventoryController:open()
    if not gui then
        buildGui()
    end
    isOpen = true
    gui.Enabled = true
    self:refresh()
end

function InventoryController:close()
    isOpen = false
    if gui then
        gui.Enabled = false
    end
end

function InventoryController:toggle()
    if isOpen then
        self:close()
    else
        self:open()
    end
end

function InventoryController:init(context)
    ctx = context
    buildGui()

    ctx.Remotes.InventoryUpdate.OnClientEvent:Connect(function(data)
        slots = data or {}
        if isOpen then
            self:refresh()
        end
    end)

    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.KeyCode == Enum.KeyCode.Tab then
            self:toggle()
        end
    end)
end

return InventoryController
