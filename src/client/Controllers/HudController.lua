-- HudController.lua  (Milestone 2)
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local HudController = {}
local ctx

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = {
    health = Color3.fromRGB(210,60,60),   hunger = Color3.fromRGB(210,140,40),
    thirst = Color3.fromRGB(60,140,210),  temp   = Color3.fromRGB(60,200,160),
    barBg  = Color3.fromRGB(30,25,20),    panel  = Color3.fromRGB(22,18,14),
    text   = Color3.fromRGB(230,220,200), night  = Color3.fromRGB(60,80,160),
    day    = Color3.fromRGB(220,160,60),  green  = Color3.fromRGB(60,200,80),
    red    = Color3.fromRGB(220,70,60),   yellow = Color3.fromRGB(220,190,60),
    white  = Color3.fromRGB(230,220,200),
}

local screenGui, barFrames, dayLabel
local toastQueue  = {}
local toastActive = false

local function makeBar(parent, yPos, color, labelText)
    local container = Instance.new("Frame")
    container.Size             = UDim2.new(0,200,0,18)
    container.Position         = UDim2.new(0,12,0,yPos)
    container.BackgroundColor3 = C.barBg
    container.BorderSizePixel  = 0
    container.Parent           = parent
    Instance.new("UICorner",container).CornerRadius = UDim.new(0,4)

    local fill = Instance.new("Frame")
    fill.Name              = "Fill"
    fill.Size              = UDim2.new(1,0,1,0)
    fill.BackgroundColor3  = color
    fill.BorderSizePixel   = 0
    fill.Parent            = container
    Instance.new("UICorner",fill).CornerRadius = UDim.new(0,4)

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(1,-6,1,0)
    label.Position               = UDim2.new(0,6,0,0)
    label.BackgroundTransparency = 1
    label.Text                   = labelText
    label.TextColor3             = C.text
    label.TextSize               = 11
    label.Font                   = Enum.Font.GothamBold
    label.TextXAlignment         = Enum.TextXAlignment.Left
    label.ZIndex                 = 3
    label.Parent                 = container
    return fill
end

local function buildHud()
    local old = playerGui:FindFirstChild("SurvivalHUD")
    if old then old:Destroy() end

    screenGui                  = Instance.new("ScreenGui")
    screenGui.Name             = "SurvivalHUD"
    screenGui.ResetOnSpawn     = false
    screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
    screenGui.Parent           = playerGui

    local panel = Instance.new("Frame")
    panel.Size                 = UDim2.new(0,224,0,110)
    panel.Position             = UDim2.new(0,8,1,-118)
    panel.BackgroundColor3     = C.panel
    panel.BackgroundTransparency = 0.35
    panel.BorderSizePixel      = 0
    panel.Parent               = screenGui
    Instance.new("UICorner",panel).CornerRadius = UDim.new(0,8)

    barFrames = {
        health = makeBar(panel, 8,  C.health, "❤ Health"),
        hunger = makeBar(panel, 30, C.hunger, "🍖 Hunger"),
        thirst = makeBar(panel, 52, C.thirst, "💧 Thirst"),
        temp   = makeBar(panel, 74, C.temp,   "🌡 Warmth"),
    }

    local dayPanel = Instance.new("Frame")
    dayPanel.Size                 = UDim2.new(0,160,0,32)
    dayPanel.Position             = UDim2.new(0,8,0,8)
    dayPanel.BackgroundColor3     = C.panel
    dayPanel.BackgroundTransparency = 0.35
    dayPanel.BorderSizePixel      = 0
    dayPanel.Parent               = screenGui
    Instance.new("UICorner",dayPanel).CornerRadius = UDim.new(0,8)

    dayLabel = Instance.new("TextLabel")
    dayLabel.Size                   = UDim2.new(1,0,1,0)
    dayLabel.BackgroundTransparency = 1
    dayLabel.Text                   = "☀  Day 1"
    dayLabel.TextColor3             = C.day
    dayLabel.TextSize               = 14
    dayLabel.Font                   = Enum.Font.GothamBold
    dayLabel.Parent                 = dayPanel
end

local function tweenBar(fill, ratio)
    TweenService:Create(fill,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(math.clamp(ratio,0,1),0,1,0) }
    ):Play()
end

local function popToast()
    if #toastQueue == 0 then toastActive=false return end
    toastActive = true
    local data  = table.remove(toastQueue, 1)
    local color = C[data.color] or C.white

    local toast = Instance.new("TextLabel")
    toast.Size                   = UDim2.new(0,300,0,36)
    toast.Position               = UDim2.new(0.5,-150,1,-160)
    toast.BackgroundColor3       = C.panel
    toast.BackgroundTransparency = 0.25
    toast.BorderSizePixel        = 0
    toast.Text                   = data.text
    toast.TextColor3             = color
    toast.TextSize               = 15
    toast.Font                   = Enum.Font.GothamBold
    toast.ZIndex                 = 10
    toast.Parent                 = screenGui
    Instance.new("UICorner",toast).CornerRadius = UDim.new(0,8)

    TweenService:Create(toast,
        TweenInfo.new(0.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5,-150,1,-180) }
    ):Play()

    task.delay(1.8, function()
        TweenService:Create(toast,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad),
            { TextTransparency=1, BackgroundTransparency=1 }
        ):Play()
        task.delay(0.42, function() toast:Destroy() popToast() end)
    end)
end

function HudController:init(context)
    ctx = context
    buildHud()

    ctx.Remotes.VitalsUpdate.OnClientEvent:Connect(function(data)
        local V = ctx.Config.Vitals
        tweenBar(barFrames.health, data.health / V.MaxHealth)
        tweenBar(barFrames.hunger, data.hunger / V.MaxHunger)
        tweenBar(barFrames.thirst, data.thirst / V.MaxThirst)
        tweenBar(barFrames.temp,   data.temp   / V.MaxTemperature)
    end)

    ctx.Remotes.DayNightUpdate.OnClientEvent:Connect(function(data)
        if dayLabel then
            dayLabel.Text       = (data.isNight and "🌙  Night " or "☀  Day ") .. data.day
            dayLabel.TextColor3 = data.isNight and C.night or C.day
        end
    end)

    ctx.Remotes.Notify.OnClientEvent:Connect(function(data)
        table.insert(toastQueue, data)
        if not toastActive then popToast() end
    end)
end

return HudController
