-- HudController.lua  (Milestone 5)
-- What changed from Milestone 2:
--   • New buildStatusBar() builds a row of icon badges below the vitals panel.
--   • updateStatuses(flags) shows/hides each badge with a fade tween.
--   • Active badges pulse gently so players notice them at a glance.
--   • VitalsUpdate now carries a `statuses` table from the server.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local HudController = {}
local ctx

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = {
    health  = Color3.fromRGB(210, 60,  60),
    hunger  = Color3.fromRGB(210, 140, 40),
    thirst  = Color3.fromRGB(60,  140, 210),
    temp    = Color3.fromRGB(60,  200, 160),
    barBg   = Color3.fromRGB(30,  25,  20),
    panel   = Color3.fromRGB(22,  18,  14),
    text    = Color3.fromRGB(230, 220, 200),
    night   = Color3.fromRGB(60,  80,  160),
    day     = Color3.fromRGB(220, 160, 60),
    green   = Color3.fromRGB(60,  200, 80),
    red     = Color3.fromRGB(220, 70,  60),
    yellow  = Color3.fromRGB(220, 190, 60),
    white   = Color3.fromRGB(230, 220, 200),
    -- Status badge background colours
    bleed   = Color3.fromRGB(160, 30,  30),
    poison  = Color3.fromRGB(60,  140, 50),
    soaked  = Color3.fromRGB(40,  100, 180),
    freeze  = Color3.fromRGB(120, 180, 230),
    exhaust = Color3.fromRGB(120, 90,  50),
    rested  = Color3.fromRGB(60,  160, 120),
    starve  = Color3.fromRGB(180, 100, 30),
    dehydra = Color3.fromRGB(50,  120, 200),
}

local screenGui, barFrames, dayLabel
local toastQueue  = {}
local toastActive = false

-- Status badge references  { label, bg, pulse connection }
local badges = {}

-- ── Status definitions ─────────────────────────────────────────────────────
-- Order here is the left-to-right display order.
local STATUS_DEFS = {
    { id = "bleeding",    icon = "🩸", label = "Bleeding",    bg = "bleed"   },
    { id = "poisoned",    icon = "💀", label = "Poisoned",    bg = "poison"  },
    { id = "soaked",      icon = "🌧", label = "Soaked",      bg = "soaked"  },
    { id = "freezing",    icon = "🥶", label = "Freezing",    bg = "freeze"  },
    { id = "exhausted",   icon = "😴", label = "Exhausted",   bg = "exhaust" },
    { id = "rested",      icon = "✨", label = "Rested",      bg = "rested"  },
    { id = "starving",    icon = "🍖", label = "Starving",    bg = "starve"  },
    { id = "dehydrated",  icon = "💧", label = "Dehydrated",  bg = "dehydra" },
}

-- ── Bar builder (unchanged) ─────────────────────────────────────────────────

local function makeBar(parent, yPos, color, labelText)
    local container = Instance.new("Frame")
    container.Size             = UDim2.new(0, 200, 0, 18)
    container.Position         = UDim2.new(0, 12, 0, yPos)
    container.BackgroundColor3 = C.barBg
    container.BorderSizePixel  = 0
    container.Parent           = parent
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)

    local fill = Instance.new("Frame")
    fill.Name              = "Fill"
    fill.Size              = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3  = color
    fill.BorderSizePixel   = 0
    fill.Parent            = container
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(1, -6, 1, 0)
    label.Position               = UDim2.new(0, 6, 0, 0)
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

-- ── Status badge builder ────────────────────────────────────────────────────
-- Builds a row of small pill badges anchored below the vitals panel.
-- Each badge is hidden (Transparency = 1) by default.

local statusRow  -- the Frame that holds all badges

local function buildStatusBar(parent)
    statusRow = Instance.new("Frame")
    statusRow.Name                 = "StatusRow"
    -- Position just below the vitals panel (panel is 110px tall, offset 8px from bottom)
    statusRow.Size                 = UDim2.new(0, 224, 0, 28)
    statusRow.Position             = UDim2.new(0, 8, 1, -118 - 34) -- 8px gap above vitals panel
    statusRow.BackgroundTransparency = 1
    statusRow.BorderSizePixel      = 0
    statusRow.Parent               = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection       = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment   = Enum.VerticalAlignment.Center
    layout.Padding             = UDim.new(0, 4)
    layout.Parent              = statusRow

    for _, def in ipairs(STATUS_DEFS) do
        local badge = Instance.new("Frame")
        badge.Name                = def.id
        badge.Size                = UDim2.new(0, 24, 0, 24)
        badge.BackgroundColor3    = C[def.bg]
        badge.BackgroundTransparency = 1   -- hidden by default
        badge.BorderSizePixel     = 0
        badge.Parent              = statusRow
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)

        local icon = Instance.new("TextLabel")
        icon.Size                   = UDim2.new(1, 0, 1, 0)
        icon.BackgroundTransparency = 1
        icon.Text                   = def.icon
        icon.TextSize               = 14
        icon.Font                   = Enum.Font.GothamBold
        icon.TextXAlignment         = Enum.TextXAlignment.Center
        icon.TextYAlignment         = Enum.TextYAlignment.Center
        icon.TextTransparency       = 1   -- hidden by default
        icon.Parent                 = badge

        -- Tooltip label (appears above badge on hover — works in Studio test)
        local tooltip = Instance.new("TextLabel")
        tooltip.Name                  = "Tooltip"
        tooltip.Size                  = UDim2.new(0, 70, 0, 18)
        tooltip.Position              = UDim2.new(0.5, -35, 0, -22)
        tooltip.BackgroundColor3      = C.panel
        tooltip.BackgroundTransparency = 0.2
        tooltip.BorderSizePixel       = 0
        tooltip.Text                  = def.label
        tooltip.TextColor3            = C.text
        tooltip.TextSize              = 10
        tooltip.Font                  = Enum.Font.Gotham
        tooltip.TextTransparency      = 1
        tooltip.ZIndex                = 20
        tooltip.Parent                = badge
        Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 4)

        badges[def.id] = {
            badge   = badge,
            icon    = icon,
            tooltip = tooltip,
            pulseConn = nil,
            active  = false,
        }
    end
end

-- ── Activate / deactivate a badge ──────────────────────────────────────────

local function activateBadge(id)
    local b = badges[id]
    if not b or b.active then return end
    b.active = true

    -- Fade in
    TweenService:Create(b.badge,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        { BackgroundTransparency = 0.15 }
    ):Play()
    TweenService:Create(b.icon,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        { TextTransparency = 0 }
    ):Play()

    -- Gentle pulse: shrink and grow the badge size every 1.2s
    local function pulse()
        if not b.active then return end
        TweenService:Create(b.badge,
            TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Size = UDim2.new(0, 20, 0, 20) }
        ):Play()
        task.delay(0.5, function()
            if not b.active then return end
            TweenService:Create(b.badge,
                TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Size = UDim2.new(0, 24, 0, 24) }
            ):Play()
        end)
    end
    pulse()
    -- Repeat pulse every 1.2s using a looping task
    local function loopPulse()
        if not b.active then return end
        task.delay(1.2, function()
            pulse()
            loopPulse()
        end)
    end
    loopPulse()
end

local function deactivateBadge(id)
    local b = badges[id]
    if not b or not b.active then return end
    b.active = false

    TweenService:Create(b.badge,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        { BackgroundTransparency = 1, Size = UDim2.new(0, 24, 0, 24) }
    ):Play()
    TweenService:Create(b.icon,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        { TextTransparency = 1 }
    ):Play()
end

-- Called every VitalsUpdate with a flags table e.g. { bleeding=true, poisoned=false, ... }
local function updateStatuses(flags)
    if not flags then return end
    for _, def in ipairs(STATUS_DEFS) do
        if flags[def.id] then
            activateBadge(def.id)
        else
            deactivateBadge(def.id)
        end
    end
end

-- ── Main HUD builder ───────────────────────────────────────────────────────

local function buildHud()
    local old = playerGui:FindFirstChild("SurvivalHUD")
    if old then old:Destroy() end

    screenGui                = Instance.new("ScreenGui")
    screenGui.Name           = "SurvivalHUD"
    screenGui.ResetOnSpawn   = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent         = playerGui

    -- Vitals panel (bottom-left)
    local panel = Instance.new("Frame")
    panel.Size                   = UDim2.new(0, 224, 0, 110)
    panel.Position               = UDim2.new(0, 8, 1, -118)
    panel.BackgroundColor3       = C.panel
    panel.BackgroundTransparency = 0.35
    panel.BorderSizePixel        = 0
    panel.Parent                 = screenGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

    barFrames = {
        health = makeBar(panel, 8,  C.health, "❤ Health"),
        hunger = makeBar(panel, 30, C.hunger, "🍖 Hunger"),
        thirst = makeBar(panel, 52, C.thirst, "💧 Thirst"),
        temp   = makeBar(panel, 74, C.temp,   "🌡 Warmth"),
    }

    -- Status effect badge row (sits above the vitals panel)
    buildStatusBar(screenGui)

    -- Day / night indicator (top-left)
    local dayPanel = Instance.new("Frame")
    dayPanel.Size                   = UDim2.new(0, 160, 0, 32)
    dayPanel.Position               = UDim2.new(0, 8, 0, 8)
    dayPanel.BackgroundColor3       = C.panel
    dayPanel.BackgroundTransparency = 0.35
    dayPanel.BorderSizePixel        = 0
    dayPanel.Parent                 = screenGui
    Instance.new("UICorner", dayPanel).CornerRadius = UDim.new(0, 8)

    dayLabel = Instance.new("TextLabel")
    dayLabel.Size                   = UDim2.new(1, 0, 1, 0)
    dayLabel.BackgroundTransparency = 1
    dayLabel.Text                   = "☀  Day 1"
    dayLabel.TextColor3             = C.day
    dayLabel.TextSize               = 14
    dayLabel.Font                   = Enum.Font.GothamBold
    dayLabel.Parent                 = dayPanel
end

-- ── Helpers ────────────────────────────────────────────────────────────────

local function tweenBar(fill, ratio)
    TweenService:Create(fill,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0) }
    ):Play()
end

local function popToast()
    if #toastQueue == 0 then toastActive = false return end
    toastActive = true
    local data  = table.remove(toastQueue, 1)
    local color = C[data.color] or C.white

    local toast = Instance.new("TextLabel")
    toast.Size                   = UDim2.new(0, 300, 0, 36)
    toast.Position               = UDim2.new(0.5, -150, 1, -160)
    toast.BackgroundColor3       = C.panel
    toast.BackgroundTransparency = 0.25
    toast.BorderSizePixel        = 0
    toast.Text                   = data.text
    toast.TextColor3             = color
    toast.TextSize               = 15
    toast.Font                   = Enum.Font.GothamBold
    toast.ZIndex                 = 10
    toast.Parent                 = screenGui
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)

    TweenService:Create(toast,
        TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -150, 1, -180) }
    ):Play()

    task.delay(1.8, function()
        TweenService:Create(toast,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad),
            { TextTransparency = 1, BackgroundTransparency = 1 }
        ):Play()
        task.delay(0.42, function() toast:Destroy() popToast() end)
    end)
end

-- ── Init ───────────────────────────────────────────────────────────────────

function HudController:init(context)
    ctx = context
    buildHud()

    ctx.Remotes.VitalsUpdate.OnClientEvent:Connect(function(data)
        local V = ctx.Config.Vitals
        tweenBar(barFrames.health, data.health / V.MaxHealth)
        tweenBar(barFrames.hunger, data.hunger / V.MaxHunger)
        tweenBar(barFrames.thirst, data.thirst / V.MaxThirst)
        tweenBar(barFrames.temp,   data.temp   / V.MaxTemperature)
        -- NEW: update status badges
        updateStatuses(data.statuses)
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
