-- InventoryController.lua
-- Inventory panel UI. Press TAB to open/close.

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local InventoryController = {}
local ctx
local panel
local slotFrames   = {}
local currentSlots = {}
local panelOpen    = false

local function buildPanel(player)
    local existing = player.PlayerGui:FindFirstChild("InventoryGUI")
    if existing then existing:Destroy() end
    local sg = Instance.new("ScreenGui")
    sg.Name="InventoryGUI" sg.ResetOnSpawn=false sg.Parent=player.PlayerGui
    local bg = Instance.new("Frame")
    bg.Name="InvPanel" bg.Size=UDim2.new(0,480,0,360)
    bg.Position=UDim2.new(0.5,-240,0.5,-180)
    bg.BackgroundColor3=Color3.fromRGB(18,14,10) bg.BackgroundTransparency=0.15
    bg.BorderSizePixel=0 bg.Visible=false
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,12) c.Parent=bg
    bg.Parent=sg
    local title=Instance.new("TextLabel")
    title.Text="INVENTORY  (TAB to close)" title.Font=Enum.Font.GothamBold title.TextSize=14
    title.TextColor3=Color3.fromRGB(210,190,160) title.BackgroundTransparency=1
    title.Size=UDim2.new(1,-16,0,28) title.Position=UDim2.new(0,8,0,4)
    title.TextXAlignment=Enum.TextXAlignment.Left title.Parent=bg
    local grid=Instance.new("Frame")
    grid.BackgroundTransparency=1 grid.Size=UDim2.new(1,-16,1,-44)
    grid.Position=UDim2.new(0,8,0,36) grid.Parent=bg
    local maxSlots=ctx.Config.Inventory.MaxSlots
    local cols=5 local sz=72 local gap=8
    slotFrames={}
    for i=1,maxSlots do
        local col=(i-1)%cols local row=math.floor((i-1)/cols)
        local slot=Instance.new("Frame")
        slot.Name="Slot"..i slot.Size=UDim2.new(0,sz,0,sz)
        slot.Position=UDim2.new(0,col*(sz+gap),0,row*(sz+gap))
        slot.BackgroundColor3=Color3.fromRGB(34,26,20) slot.BackgroundTransparency=0.3
        slot.BorderSizePixel=0
        local sc=Instance.new("UICorner") sc.CornerRadius=UDim.new(0,8) sc.Parent=slot
        local nl=Instance.new("TextLabel")
        nl.Name="Name" nl.Text="" nl.Font=Enum.Font.Gotham nl.TextSize=11
        nl.TextColor3=Color3.fromRGB(220,210,190) nl.BackgroundTransparency=1
        nl.Size=UDim2.new(1,-4,0.55,0) nl.Position=UDim2.new(0,2,0.05,0)
        nl.TextWrapped=true nl.TextXAlignment=Enum.TextXAlignment.Center nl.Parent=slot
        local al=Instance.new("TextLabel")
        al.Name="Amount" al.Text="" al.Font=Enum.Font.GothamBold al.TextSize=13
        al.TextColor3=Color3.fromRGB(255,220,130) al.BackgroundTransparency=1
        al.Size=UDim2.new(1,-4,0.4,0) al.Position=UDim2.new(0,2,0.58,0)
        al.TextXAlignment=Enum.TextXAlignment.Right al.Parent=slot
        local ub=Instance.new("TextButton")
        ub.Name="UseBtn" ub.Text="Use" ub.Font=Enum.Font.Gotham ub.TextSize=11
        ub.TextColor3=Color3.fromRGB(255,255,255) ub.BackgroundColor3=Color3.fromRGB(60,140,80)
        ub.BackgroundTransparency=0.2 ub.Size=UDim2.new(0.48,0,0,18)
        ub.Position=UDim2.new(0,2,1,-22) ub.Visible=false ub.BorderSizePixel=0
        local uc=Instance.new("UICorner") uc.CornerRadius=UDim.new(0,4) uc.Parent=ub
        ub.Parent=slot
        local db=Instance.new("TextButton")
        db.Name="DropBtn" db.Text="Drop" db.Font=Enum.Font.Gotham db.TextSize=11
        db.TextColor3=Color3.fromRGB(255,255,255) db.BackgroundColor3=Color3.fromRGB(160,60,60)
        db.BackgroundTransparency=0.2 db.Size=UDim2.new(0.48,0,0,18)
        db.Position=UDim2.new(0.52,-2,1,-22) db.Visible=false db.BorderSizePixel=0
        local dc=Instance.new("UICorner") dc.CornerRadius=UDim.new(0,4) dc.Parent=db
        db.Parent=slot
        local si=i
        ub.MouseButton1Click:Connect(function() ctx.Remotes.UseItem:FireServer(si)  end)
        db.MouseButton1Click:Connect(function() ctx.Remotes.DropItem:FireServer(si) end)
        slot.Parent=grid slotFrames[i]=slot
    end
    panel=bg
    return panel
end

local function refreshSlots(slots)
    for i,frame in ipairs(slotFrames) do
        local slot=slots[i]
        local nl=frame:FindFirstChild("Name")
        local al=frame:FindFirstChild("Amount")
        local ub=frame:FindFirstChild("UseBtn")
        local db=frame:FindFirstChild("DropBtn")
        if slot and slot.itemId then
            local ic=ctx.Config.Items[slot.itemId]
            nl.Text=(ic and ic.displayName) or slot.itemId
            al.Text="x"..tostring(slot.amount)
            frame.BackgroundColor3=Color3.fromRGB(50,40,28)
            local isUsable=ic and (ic.type=="food" or ic.healAmount~=nil)
            if ub then ub.Visible=isUsable or false end
            if db then db.Visible=true end
        else
            nl.Text="" al.Text=""
            frame.BackgroundColor3=Color3.fromRGB(34,26,20)
            if ub then ub.Visible=false end
            if db then db.Visible=false end
        end
    end
end

function InventoryController:init(context)
    ctx=context
    local player=ctx.Player
    buildPanel(player)
    UserInputService.InputBegan:Connect(function(input,processed)
        if processed then return end
        if input.KeyCode==Enum.KeyCode.Tab then
            panelOpen=not panelOpen
            panel.Visible=panelOpen
            if panelOpen then refreshSlots(currentSlots) end
        end
    end)
    ctx.Remotes.UpdateInventory:Connect(function(slots)
        currentSlots=slots or {}
        if panelOpen then refreshSlots(currentSlots) end
    end)
    player.CharacterAdded:Connect(function() buildPanel(player) panelOpen=false end)
end

return InventoryController
