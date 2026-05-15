local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SleepController = {}
local ctx

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FADE_TIME_OUT = 1.8
local FADE_TIME_IN = 2.2

local currentFadeGui
local currentOverlay
local currentLabel

local function showLocalToast(text, color)
    local gui = playerGui:FindFirstChild("SleepToastGui")
    if gui then
        gui:Destroy()
    end

    gui = Instance.new("ScreenGui")
    gui.Name = "SleepToastGui"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 320, 0, 36)
    label.Position = UDim2.new(0.5, -160, 1, -170)
    label.BackgroundColor3 = Color3.fromRGB(22, 18, 14)
    label.BackgroundTransparency = 0.25
    label.BorderSizePixel = 0
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(230, 220, 200)
    label.TextSize = 15
    label.Font = Enum.Font.GothamBold
    label.Parent = gui
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

    task.delay(2, function()
        if gui and gui.Parent then
            gui:Destroy()
        end
    end)
end

local function makeFadeGui()
    local existing = playerGui:FindFirstChild("SleepFade")
    if existing then
        existing:Destroy()
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "SleepFade"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = playerGui

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 50
    overlay.Parent = sg

    local label = Instance.new("TextLabel")
    label.Name = "SleepLabel"
    label.Size = UDim2.new(1, 0, 0, 40)
    label.Position = UDim2.new(0, 0, 0.5, -20)
    label.BackgroundTransparency = 1
    label.Text = "Sleeping..."
    label.TextColor3 = Color3.fromRGB(200, 190, 160)
    label.TextSize = 22
    label.Font = Enum.Font.GothamBold
    label.TextTransparency = 1
    label.ZIndex = 51
    label.Parent = overlay

    return sg, overlay, label
end

local function startFadeOut()
    local sg, overlay, label = makeFadeGui()

    TweenService:Create(
        overlay,
        TweenInfo.new(FADE_TIME_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 0 }
    ):Play()

    task.delay(FADE_TIME_OUT, function()
        TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
        ctx.Remotes.SleepRequest:FireServer()
    end)

    return sg, overlay, label
end

local function startFadeIn()
    if not currentOverlay then
        return
    end

    TweenService:Create(currentLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { TextTransparency = 1 }):Play()

    task.delay(0.35, function()
        TweenService:Create(
            currentOverlay,
            TweenInfo.new(FADE_TIME_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        ):Play()

        task.delay(FADE_TIME_IN + 0.2, function()
            if currentFadeGui then
                currentFadeGui:Destroy()
                currentFadeGui = nil
                currentOverlay = nil
                currentLabel = nil
            end
        end)
    end)

    task.delay(0.5, function()
        showLocalToast("You feel rested", Color3.fromRGB(60, 200, 80))
    end)
end

function SleepController:init(context)
    ctx = context

    ctx.Remotes.SleepResponse.OnClientEvent:Connect(function(data)
        if not (type(data) == "table" and data.success) then
            local message = (type(data) == "table" and data.message) or "Can't sleep right now."
            showLocalToast(message, Color3.fromRGB(220, 190, 60))
            return
        end

        if data.fadeOut then
            currentFadeGui, currentOverlay, currentLabel = startFadeOut()
        end

        if data.wakeUp then
            startFadeIn()
        end
    end)
end

return SleepController
