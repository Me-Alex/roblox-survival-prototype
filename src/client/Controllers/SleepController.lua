-- SleepController.lua  (Milestone 6b)
--
-- PURPOSE:
--   Handle the client side of the sleep sequence:
--     1. Receive SleepResponse { fadeOut=true }  → fade screen to black over 2s.
--     2. Fire SleepRequest to server ("I am fully blacked out, do the time-skip").
--     3. Receive SleepResponse { wakeUp=true }   → fade screen back in over 2s.
--     4. Show a "You feel rested" toast + activate Rested HUD badge.
--
-- WHY A SEPARATE CONTROLLER?
--   Keeping the sleep fade logic here instead of inside HudController or
--   DeathController means each file has one job. The fade overlay is
--   re-used for both sleep and, if you want, fast-travel in future.
--
-- HOW THE FADE WORKS:
--   We create a black Frame that covers the entire screen (full UDim2.new(1,0,1,0)).
--   TweenService animates its BackgroundTransparency from 1 → 0 (fade to black)
--   then from 0 → 1 (fade back in). The frame is destroyed after the wake tween.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SleepController = {}
local ctx

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Fade overlay ───────────────────────────────────────────────────────────

local FADE_TIME_OUT = 1.8   -- seconds to go black
local FADE_TIME_IN  = 2.2   -- seconds to come back

local function makeFadeGui()
    -- Reuse if already exists (shouldn't normally, but safety first)
    local existing = playerGui:FindFirstChild("SleepFade")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "SleepFade"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = playerGui

    local overlay = Instance.new("Frame", sg)
    overlay.Name                 = "Overlay"
    overlay.Size                 = UDim2.new(1, 0, 1, 0)
    overlay.Position             = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3     = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 1   -- starts transparent
    overlay.BorderSizePixel      = 0
    overlay.ZIndex               = 50    -- above everything

    -- "Sleeping..." label that appears at the centre while blacked out
    local label = Instance.new("TextLabel", overlay)
    label.Name                   = "SleepLabel"
    label.Size                   = UDim2.new(1, 0, 0, 40)
    label.Position               = UDim2.new(0, 0, 0.5, -20)
    label.BackgroundTransparency = 1
    label.Text                   = "💤  Sleeping..."
    label.TextColor3             = Color3.fromRGB(200, 190, 160)
    label.TextSize               = 22
    label.Font                   = Enum.Font.GothamBold
    label.TextTransparency       = 1    -- hidden until blacked out
    label.ZIndex                 = 51

    return sg, overlay, label
end

-- ── Main sequence ───────────────────────────────────────────────────────────

local function startFadeOut()
    local sg, overlay, label = makeFadeGui()

    -- Fade to black
    TweenService:Create(overlay,
        TweenInfo.new(FADE_TIME_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 0 }
    ):Play()

    -- After fully black: show label + tell server we're ready
    task.delay(FADE_TIME_OUT, function()
        TweenService:Create(label,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad),
            { TextTransparency = 0 }
        ):Play()

        -- Signal server to do the time-skip
        ctx.Remotes.SleepRequest:FireServer()
    end)

    return sg, overlay, label
end

local currentFadeGui    = nil
local currentOverlay    = nil
local currentLabel      = nil

local function startFadeIn()
    if not currentOverlay then return end

    -- Hide label first
    TweenService:Create(currentLabel,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        { TextTransparency = 1 }
    ):Play()

    task.delay(0.35, function()
        -- Fade back in from black
        TweenService:Create(currentOverlay,
            TweenInfo.new(FADE_TIME_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        ):Play()

        -- Clean up the gui after fade completes
        task.delay(FADE_TIME_IN + 0.2, function()
            if currentFadeGui then
                currentFadeGui:Destroy()
                currentFadeGui = nil
                currentOverlay = nil
                currentLabel   = nil
            end
        end)
    end)

    -- Show "rested" toast via the Notify remote so HudController handles it
    task.delay(0.5, function()
        -- Trigger the Rested HUD badge by firing a fake vitals notify
        -- (the real badge comes from VitalsService on next tick; this just
        --  shows the toast immediately for instant feedback)
        ctx.Remotes.Notify:FireServer()  -- won't do anything server-side
        -- Show a local toast directly
        ctx.Remotes.Notify.OnClientEvent:Fire({
            text  = "✨  You feel rested",
            color = "green",
        })
    end)
end

-- ── Init ─────────────────────────────────────────────────────────────────

function SleepController:init(context)
    ctx = context

    ctx.Remotes.SleepResponse.OnClientEvent:Connect(function(data)
        if not data.success then
            -- Show failure reason as a toast (e.g. wrong owner, cooldown)
            ctx.Remotes.Notify.OnClientEvent:Fire({
                text  = "😴  " .. (data.message or "Can't sleep right now."),
                color = "yellow",
            })
            return
        end

        if data.fadeOut then
            -- Begin fade-to-black sequence
            currentFadeGui, currentOverlay, currentLabel = startFadeOut()
        end

        if data.wakeUp then
            -- Server finished time-skip; fade back in
            startFadeIn()
        end
    end)
end

return SleepController
