-- DeathController.lua  (Milestone 4)
-- Listens for the local player's Humanoid.Died event.
-- When the player dies it shows a full-screen overlay with:
--   - "YOU DIED" title
--   - "You survived X days"
--   - [Respawn] button that fires RespawnRequest to the server
--
-- ROBLOX DEATH NOTES:
--   When a Humanoid's health hits 0 in Roblox it fires the .Died event.
--   The character will be removed and replaced ~5 seconds later.
--   We hook into CharacterAdded to re-hook Died on every respawn.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DeathController = {}
local ctx

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = {
    bg     = Color3.fromRGB(10, 5, 5),
    red    = Color3.fromRGB(180, 40, 40),
    text   = Color3.fromRGB(230, 210, 200),
    muted  = Color3.fromRGB(160, 140, 130),
    btn    = Color3.fromRGB(160, 50, 40),
    btnHov = Color3.fromRGB(200, 70, 55),
}

local deathGui = nil

-- ── Build the death screen ─────────────────────────────────────────────────

local function buildDeathScreen(daysSurvived)
    local old = playerGui:FindFirstChild("DeathGui")
    if old then old:Destroy() end

    local gui           = Instance.new("ScreenGui")
    gui.Name            = "DeathGui"
    gui.ResetOnSpawn    = false
    gui.DisplayOrder    = 50   -- on top of HUD
    gui.Parent          = playerGui
    deathGui            = gui

    -- Full-screen dark overlay
    local backdrop = Instance.new("Frame")
    backdrop.Size              = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3  = C.bg
    backdrop.BackgroundTransparency = 0.0
    backdrop.BorderSizePixel   = 0
    backdrop.Parent            = gui

    -- Fade in
    backdrop.BackgroundTransparency = 1
    TweenService:Create(backdrop,
        TweenInfo.new(1.2, Enum.EasingStyle.Quad),
        { BackgroundTransparency = 0.15 }
    ):Play()

    -- "YOU DIED" title
    local title = Instance.new("TextLabel")
    title.Size                   = UDim2.new(0, 500, 0, 80)
    title.Position               = UDim2.new(0.5, -250, 0.35, -40)
    title.BackgroundTransparency = 1
    title.Text                   = "YOU DIED"
    title.TextColor3             = C.red
    title.TextSize               = 52
    title.Font                   = Enum.Font.GothamBlack
    title.TextXAlignment         = Enum.TextXAlignment.Center
    title.TextTransparency       = 1
    title.Parent                 = backdrop

    TweenService:Create(title,
        TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { TextTransparency = 0 }
    ):Play()

    -- Subtitle
    local sub = Instance.new("TextLabel")
    sub.Size                   = UDim2.new(0, 500, 0, 40)
    sub.Position               = UDim2.new(0.5, -250, 0.35, 50)
    sub.BackgroundTransparency = 1
    sub.Text                   = "You survived " .. daysSurvived .. (daysSurvived == 1 and " day" or " days")
    sub.TextColor3             = C.muted
    sub.TextSize               = 22
    sub.Font                   = Enum.Font.Gotham
    sub.TextXAlignment         = Enum.TextXAlignment.Center
    sub.TextTransparency       = 1
    sub.Parent                 = backdrop

    TweenService:Create(sub,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad),
        { TextTransparency = 0 }
    ):Play()

    -- Cause of death hint (could be extended later)
    local causeLabel = Instance.new("TextLabel")
    causeLabel.Size                   = UDim2.new(0, 500, 0, 24)
    causeLabel.Position               = UDim2.new(0.5, -250, 0.35, 86)
    causeLabel.BackgroundTransparency = 1
    causeLabel.Text                   = "Killed by the darkness."
    causeLabel.TextColor3             = Color3.fromRGB(120, 90, 80)
    causeLabel.TextSize               = 14
    causeLabel.Font                   = Enum.Font.Gotham
    causeLabel.TextXAlignment         = Enum.TextXAlignment.Center
    causeLabel.Parent                 = backdrop

    -- Respawn button (appears after 2 seconds)
    task.delay(2, function()
        if not gui or not gui.Parent then return end

        local btn = Instance.new("TextButton")
        btn.Size              = UDim2.new(0, 200, 0, 48)
        btn.Position          = UDim2.new(0.5, -100, 0.62, 0)
        btn.BackgroundColor3  = C.btn
        btn.BorderSizePixel   = 0
        btn.Text              = "Respawn"
        btn.TextColor3        = C.text
        btn.TextSize          = 18
        btn.Font              = Enum.Font.GothamBold
        btn.BackgroundTransparency = 1
        btn.Parent            = backdrop
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        TweenService:Create(btn,
            TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0 }
        ):Play()

        btn.MouseButton1Click:Connect(function()
            -- Tell server to respawn this player
            ctx.Remotes.RespawnRequest:FireServer()
            -- Destroy the death screen
            if gui then gui:Destroy() end
        end)
    end)
end

-- ── Hook humanoid ──────────────────────────────────────────────────────────

local function hookCharacter(character)
    local hum = character:WaitForChild("Humanoid", 10)
    if not hum then return end
    hum.Died:Connect(function()
        local days = (ctx.DayNightCache and ctx.DayNightCache.day) or 1
        buildDeathScreen(days)
    end)
end

-- ── Init ──────────────────────────────────────────────────────────────────

function DeathController:init(context)
    ctx = context

    -- Hook current character (if already spawned)
    if player.Character then
        hookCharacter(player.Character)
    end

    -- Hook every future character (after respawn)
    player.CharacterAdded:Connect(function(character)
        -- Remove old death screen on respawn
        local old = playerGui:FindFirstChild("DeathGui")
        if old then old:Destroy() end
        hookCharacter(character)
    end)

    -- Cache day count from server broadcasts
    ctx.DayNightCache = { day = 1, isNight = false }
    ctx.Remotes.DayNightUpdate.OnClientEvent:Connect(function(data)
        ctx.DayNightCache.day     = data.day
        ctx.DayNightCache.isNight = data.isNight
    end)
end

return DeathController
