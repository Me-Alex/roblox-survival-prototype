-- DeathController.lua  (Milestone 10)
--
-- WHAT'S NEW vs M4:
--   1. Tracks real session start time so we can show "X days, Y hours, Z minutes"
--   2. Listens for PlayerDied remote which carries a cause-of-death string
--   3. Animated death screen has a styled "survival stats" card with 3 lines
--   4. Tip of the day shown at the bottom of the card (rotates per death)
--   5. Respawn button fades in after 2s with a scale animation
--   6. On respawn: screen fades out cleanly, 4s invincibility glow on character
--
-- WHY INVINCIBILITY ON RESPAWN:
--   If a Night Stalker killed you and is still standing on your spawn point,
--   you'd die again instantly. 4 seconds of god-mode gives you time to run.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local DeathController = {}
local ctx

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Session tracking
local sessionStart  = os.clock()  -- seconds since script loaded
local INVINCIBLE_DURATION = 4     -- seconds of god-mode after respawn

-- Color palette
local C = {
    bg        = Color3.fromRGB(8,  4,  4),
    panel     = Color3.fromRGB(22, 14, 14),
    border    = Color3.fromRGB(80, 30, 30),
    red       = Color3.fromRGB(200, 50, 45),
    redDark   = Color3.fromRGB(130, 30, 25),
    text      = Color3.fromRGB(230, 215, 205),
    muted     = Color3.fromRGB(160, 140, 130),
    faint     = Color3.fromRGB(100,  80,  70),
    btnFill   = Color3.fromRGB(155, 45, 38),
    btnHover  = Color3.fromRGB(200, 70, 55),
    glow      = Color3.fromRGB(255, 200, 100),
}

-- Tips shown at the bottom of the death card (cycles each death)
local TIPS = {
    "Boil dirty water before drinking it.",
    "Sleep in a bedroll to skip the night.",
    "Stay near a campfire when it's cold.",
    "Deer drop more hide than rabbits.",
    "Meat Stew restores the most hunger.",
    "Build walls before the first night.",
    "Mushroom Soup is the best for thirst.",
    "Use a Bandage to stop bleeding fast.",
    "Explore the island to find puddles.",
    "Stone Ovens unlock advanced recipes.",
}
local tipIndex = 0

-- ── Survival time helper ───────────────────────────────────────────────────────
-- os.clock() counts real seconds; we convert to in-game feel:
-- 1 real second = 1/60 of an in-game hour (DayLengthSecs = 480 ≈ 8 real mins / day)
-- So 480 real seconds = 1 in-game day.
-- We show both real-time survived AND in-game days survived.

local function survivalSummary()
    local elapsed = os.clock() - sessionStart   -- real seconds
    local gameDays   = math.floor(elapsed / 480)
    local remainder  = elapsed % 480
    local gameHours  = math.floor(remainder / 20)  -- 20 real s = 1 game hour
    local gameMins   = math.floor((remainder % 20) / 20 * 60)

    -- Also compute real time for a second stat line
    local realMins  = math.floor(elapsed / 60)
    local realSecs  = math.floor(elapsed % 60)

    return {
        gameDays   = gameDays,
        gameHours  = gameHours,
        gameMins   = gameMins,
        realMins   = realMins,
        realSecs   = realSecs,
    }
end

-- ── UI helpers ─────────────────────────────────────────────────────────────

local function label(parent, text, size, color, font, posX, posY, sizeX, sizeY, transparency)
    local l = Instance.new("TextLabel")
    l.Size                   = UDim2.new(sizeX or 0, 500, sizeY or 0, size + 6)
    l.Position               = UDim2.new(posX or 0.5, -250, posY, 0)
    l.BackgroundTransparency = 1
    l.Text                   = text
    l.TextColor3             = color
    l.TextSize               = size
    l.Font                   = font or Enum.Font.Gotham
    l.TextXAlignment         = Enum.TextXAlignment.Center
    l.TextTransparency       = transparency or 0
    l.TextWrapped            = true
    l.Parent                 = parent
    return l
end

-- ── Invincibility glow ────────────────────────────────────────────────────────
-- Temporarily makes the character's parts semi-transparent and golden
-- to signal they are invincible. Humanoid.Health is NOT set to infinity here;
-- that's handled on the server by RespawnService.

local function applyInvincibleGlow(character)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Color        = C.glow
            part.Transparency = 0.4
            part.Material     = Enum.Material.Neon
        end
    end

    -- After INVINCIBLE_DURATION seconds, restore normal look
    task.delay(INVINCIBLE_DURATION, function()
        if not character or not character.Parent then return end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                -- Roblox default character resets automatically on next physics tick
                -- but we reset Color and Transparency explicitly to be safe
                part.Transparency = 0
                part.Material     = Enum.Material.SmoothPlastic
            end
        end
    end)
end

-- ── Death screen builder ──────────────────────────────────────────────────────

local function buildDeathScreen(cause)
    local old = playerGui:FindFirstChild("DeathGui")
    if old then old:Destroy() end

    -- Cycle tip
    tipIndex = (tipIndex % #TIPS) + 1
    local tip  = TIPS[tipIndex]
    local stats = survivalSummary()

    -- Screen GUI
    local gui = Instance.new("ScreenGui")
    gui.Name          = "DeathGui"
    gui.ResetOnSpawn  = false
    gui.DisplayOrder  = 60
    gui.Parent        = playerGui

    -- Full-screen dark backdrop
    local backdrop = Instance.new("Frame")
    backdrop.Size                    = UDim2.new(1,0,1,0)
    backdrop.BackgroundColor3        = C.bg
    backdrop.BackgroundTransparency  = 1
    backdrop.BorderSizePixel         = 0
    backdrop.Parent                  = gui

    TweenService:Create(backdrop, TweenInfo.new(1.4, Enum.EasingStyle.Quad),
        { BackgroundTransparency = 0.08 }):Play()

    -- ── "YOU DIED" ──────────────────────────────────────────────────────────
    local title = label(backdrop,
        "YOU DIED", 58, C.red, Enum.Font.GothamBlack, 0.5, 0.22)
    title.TextTransparency = 1
    TweenService:Create(title,
        TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { TextTransparency = 0 }):Play()

    -- ── Stats card ──────────────────────────────────────────────────────────
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(0, 440, 0, 210)
    card.Position         = UDim2.new(0.5, -220, 0.36, 0)
    card.BackgroundColor3 = C.panel
    card.BackgroundTransparency = 1
    card.BorderSizePixel  = 0
    card.Parent           = backdrop
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,10); corner.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color       = C.border
    stroke.Thickness   = 1
    stroke.Transparency = 0.4
    stroke.Parent      = card

    TweenService:Create(card, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.3),
        { BackgroundTransparency = 0 }):Play()

    -- Card layout: 5 rows inside a UIListLayout
    local layout = Instance.new("UIListLayout")
    layout.SortOrder  = Enum.SortOrder.LayoutOrder
    layout.Padding    = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent     = card
    local padding = Instance.new("UIPadding")
    padding.PaddingTop    = UDim.new(0, 18)
    padding.PaddingBottom = UDim.new(0, 14)
    padding.PaddingLeft   = UDim.new(0, 20)
    padding.PaddingRight  = UDim.new(0, 20)
    padding.Parent = card

    -- Row helper for card (overrides parent/position)
    local function row(text, col, sz, fnt, order)
        local l = Instance.new("TextLabel")
        l.LayoutOrder             = order or 0
        l.Size                    = UDim2.new(1, 0, 0, sz + 4)
        l.BackgroundTransparency  = 1
        l.Text                    = text
        l.TextColor3              = col
        l.TextSize                = sz
        l.Font                    = fnt or Enum.Font.Gotham
        l.TextXAlignment          = Enum.TextXAlignment.Center
        l.TextWrapped             = true
        l.Parent                  = card
        return l
    end

    -- Cause of death
    local causeStr = cause or "Unknown"
    row("☠  Cause: " .. causeStr, C.redDark, 15, Enum.Font.GothamBold, 1)

    -- Divider
    local div = Instance.new("Frame")
    div.LayoutOrder          = 2
    div.Size                 = UDim2.new(0.9, 0, 0, 1)
    div.BackgroundColor3     = C.border
    div.BackgroundTransparency = 0.5
    div.BorderSizePixel      = 0
    div.Parent               = card

    -- Survived line
    local survivedText
    if stats.gameDays >= 1 then
        survivedText = string.format(
            "🌅  Survived %d day%s, %dh %02dm",
            stats.gameDays, stats.gameDays == 1 and "" or "s",
            stats.gameHours, stats.gameMins)
    else
        survivedText = string.format(
            "⏱  Survived %dh %02dm in-game",
            stats.gameHours, stats.gameMins)
    end
    row(survivedText, C.text, 16, Enum.Font.Gotham, 3)

    -- Real time line
    row(string.format("⌚  Real time: %dm %02ds", stats.realMins, stats.realSecs),
        C.muted, 13, Enum.Font.Gotham, 4)

    -- Tip
    row("💡  Tip: " .. tip, C.faint, 12, Enum.Font.GothamItalic, 5)

    -- ── Respawn button (appears after 2 s) ─────────────────────────────────
    task.delay(2, function()
        if not gui or not gui.Parent then return end

        local btn = Instance.new("TextButton")
        btn.Size                    = UDim2.new(0, 200, 0, 48)
        btn.Position                = UDim2.new(0.5, -100, 0.71, 0)
        btn.BackgroundColor3        = C.btnFill
        btn.BorderSizePixel         = 0
        btn.Text                    = "Respawn"
        btn.TextColor3              = C.text
        btn.TextSize                = 18
        btn.Font                    = Enum.Font.GothamBold
        btn.BackgroundTransparency  = 1
        btn.AutoButtonColor         = false
        btn.Parent                  = backdrop

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 10)
        bCorner.Parent = btn

        -- Scale-in animation
        local uiScale = Instance.new("UIScale")
        uiScale.Scale  = 0.6
        uiScale.Parent = btn

        TweenService:Create(btn,
            TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0 }):Play()
        TweenService:Create(uiScale,
            TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1 }):Play()

        -- Hover effects
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = C.btnHover }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = C.btnFill }):Play()
        end)

        btn.MouseButton1Click:Connect(function()
            btn.Active = false
            -- Fade out death screen
            TweenService:Create(backdrop,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad),
                { BackgroundTransparency = 1 }):Play()
            task.delay(0.5, function()
                if gui then gui:Destroy() end
            end)
            -- Ask server to respawn
            ctx.Remotes.RespawnRequest:FireServer()
        end)
    end)

    return gui
end

-- ── Hook humanoid ────────────────────────────────────────────────────────────

local pendingCause = nil  -- set by PlayerDied event before Humanoid.Died fires

local function hookCharacter(character)
    local hum = character:WaitForChild("Humanoid", 10)
    if not hum then return end
    hum.Died:Connect(function()
        buildDeathScreen(pendingCause or "The island claimed you.")
        pendingCause = nil
    end)
end

-- ── Init ─────────────────────────────────────────────────────────────────

function DeathController:init(context)
    ctx = context
    sessionStart = os.clock()

    -- Receive cause-of-death from server (fires just before health hits 0)
    ctx.Remotes.PlayerDied.OnClientEvent:Connect(function(cause)
        pendingCause = cause
    end)

    -- Hook current character
    if player.Character then hookCharacter(player.Character) end

    player.CharacterAdded:Connect(function(character)
        -- Remove death screen
        local old = playerGui:FindFirstChild("DeathGui")
        if old then old:Destroy() end
        -- Apply invincibility glow
        applyInvincibleGlow(character)
        -- Re-hook for next death
        hookCharacter(character)
    end)
end

return DeathController
