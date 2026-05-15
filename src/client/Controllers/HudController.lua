-- HudController.lua
-- Draws vital bars (health, hunger, thirst, temperature) and notifications.
-- All UI built in code. No need to set anything up in Studio.

local TweenService  = game:GetService("TweenService")

local HudController = {}
local ctx
local bars = {}
local notifyQueue  = {}
local notifyActive = false

local function makeFrame(parent, name, bgColor, pos, size)
    local f = Instance.new("Frame")
    f.Name=name f.BackgroundColor3=bgColor f.BorderSizePixel=0
    f.Position=pos f.Size=size f.Parent=parent
    return f
end

local function buildHud(player)
    local existing = player.PlayerGui:FindFirstChild("SurvivalHUD")
    if existing then existing:Destroy() end
    local gui = Instance.new("ScreenGui")
    gui.Name="SurvivalHUD" gui.ResetOnSpawn=false gui.Parent=player.PlayerGui
    local barContainer = makeFrame(gui,"VitalBars",Color3.fromRGB(0,0,0),UDim2.new(0,12,1,-128),UDim2.new(0,160,0,116))
    barContainer.BackgroundTransparency=1
    local barDefs = {
        {id="health",      label="♥ Health",  color=Color3.fromRGB(220,60,60)  },
        {id="hunger",      label="🍗 Hunger",  color=Color3.fromRGB(210,140,50) },
        {id="thirst",      label="💧 Thirst",  color=Color3.fromRGB(80,160,220) },
        {id="temperature", label="🌡 Temp",    color=Color3.fromRGB(200,100,220)},
    }
    bars = {}
    for i, def in ipairs(barDefs) do
        local yo = (i-1)*28
        local track = makeFrame(barContainer,def.id.."Track",Color3.fromRGB(30,30,30),UDim2.new(0,0,0,yo+16),UDim2.new(1,0,0,10))
        track.BackgroundTransparency=0.5
        local c1=Instance.new("UICorner") c1.CornerRadius=UDim.new(1,0) c1.Parent=track
        local fill = makeFrame(track,"Fill",def.color,UDim2.new(0,0,0,0),UDim2.new(1,0,1,0))
        local c2=Instance.new("UICorner") c2.CornerRadius=UDim.new(1,0) c2.Parent=fill
        local lbl=Instance.new("TextLabel")
        lbl.BackgroundTransparency=1 lbl.TextColor3=Color3.fromRGB(210,200,190)
        lbl.Text=def.label lbl.Font=Enum.Font.GothamBold lbl.TextSize=12
        lbl.Position=UDim2.new(0,0,0,yo) lbl.Size=UDim2.new(1,0,0,16)
        lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=barContainer
        bars[def.id]=fill
    end
    -- Notification label
    local nf=makeFrame(gui,"NotifyArea",Color3.fromRGB(0,0,0),UDim2.new(0.5,-160,0,8),UDim2.new(0,320,0,40))
    nf.BackgroundTransparency=1
    local nl=Instance.new("TextLabel")
    nl.Name="NotifyLabel" nl.BackgroundColor3=Color3.fromRGB(20,16,12)
    nl.BackgroundTransparency=0.35 nl.TextColor3=Color3.fromRGB(245,235,210)
    nl.Font=Enum.Font.GothamBold nl.TextSize=15 nl.Size=UDim2.new(1,0,1,0)
    nl.TextXAlignment=Enum.TextXAlignment.Center nl.Text="" nl.Visible=false
    local nc=Instance.new("UICorner") nc.CornerRadius=UDim.new(0,8) nc.Parent=nl
    nl.Parent=nf
    return nl
end

local function updateBar(id, value, maxValue)
    local fill = bars[id]
    if not fill then return end
    local pct = math.clamp(value/maxValue, 0, 1)
    TweenService:Create(fill, TweenInfo.new(0.18), { Size=UDim2.new(pct,0,1,0) }):Play()
end

function HudController:init(context)
    ctx = context
    local player = ctx.Player
    local notifyLabel = buildHud(player)
    ctx.Remotes.UpdateVitals:Connect(function(v)
        local cfg = ctx.Config.Vitals
        updateBar("health",      v.health,      cfg.MaxHealth)
        updateBar("hunger",      v.hunger,       cfg.MaxHunger)
        updateBar("thirst",      v.thirst,       cfg.MaxThirst)
        updateBar("temperature", v.temperature,  cfg.MaxTemperature)
    end)
    ctx.Remotes.Notify:Connect(function(data)
        table.insert(notifyQueue, data)
        if not notifyActive then self:_showNextNotify(notifyLabel) end
    end)
    player.CharacterAdded:Connect(function() notifyLabel = buildHud(player) end)
end

function HudController:_showNextNotify(label)
    if #notifyQueue == 0 then notifyActive=false return end
    notifyActive = true
    local data = table.remove(notifyQueue, 1)
    local colors = { green=Color3.fromRGB(100,220,130), red=Color3.fromRGB(230,80,80), yellow=Color3.fromRGB(240,200,60), white=Color3.fromRGB(245,235,210) }
    label.TextColor3=colors[data.color] or colors.white
    label.Text=data.text label.Visible=true label.TextTransparency=0
    task.delay(2.5, function()
        TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency=1, BackgroundTransparency=1 }):Play()
        task.wait(0.5)
        label.Visible=false label.BackgroundTransparency=0.35
        self:_showNextNotify(label)
    end)
end

return HudController
