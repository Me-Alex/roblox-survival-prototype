-- ResourceService.lua
-- Handles ALL resource harvesting interaction.
--
-- HOW IT WORKS:
--   WorldService spawns Parts with a ProximityPrompt and a "NodeType" StringValue.
--   When a player triggers the ProximityPrompt, this service:
--     1. Decrements HitsLeft on the node.
--     2. If HitsLeft > 0: play a hit effect (colour flash).
--     3. If HitsLeft == 0: give the player the drop items, hide the node,
--        schedule a respawn timer, and notify the player.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ResourceService = {}
local ctx

local respawnQueue = {}
local rng = Random.new()
local DEFAULT_RESPAWN_TIME = 120
local MAX_HARVEST_DISTANCE = 14
local HARVEST_COOLDOWN_SECONDS = 0.25
local MAX_STRUCTURE_PLACE_DISTANCE = 20
local MIN_STRUCTURE_PLACE_DISTANCE = 2
local DEFAULT_DROPS = {
    Tree = { item = "AshWood", min = 2, max = 4 },
    Rock = { item = "Stone", min = 2, max = 4 },
    Bush = { item = "RawBerries", min = 1, max = 3 },
    Fiber = { item = "Fiber", min = 2, max = 5 },
}

local lastHarvestByPlayer = {}
local lastStructurePlaceByPlayer = {}

local function randomInt(rng, min, max)
    return rng:NextInteger(min, max)
end

local function setVisualModelActive(model, active)
    if not model or not model:IsA("Model") then
        return
    end

    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("BasePart") then
            if active then
                local originalTransparency = inst:GetAttribute("OriginalTransparency")
                local originalCanCollide = inst:GetAttribute("OriginalCanCollide")
                local originalCanTouch = inst:GetAttribute("OriginalCanTouch")
                local originalCanQuery = inst:GetAttribute("OriginalCanQuery")

                inst.Transparency = typeof(originalTransparency) == "number" and originalTransparency or 0
                inst.CanCollide = originalCanCollide ~= false
                inst.CanTouch = originalCanTouch ~= false
                inst.CanQuery = originalCanQuery ~= false
            else
                if inst:GetAttribute("OriginalTransparency") == nil then
                    inst:SetAttribute("OriginalTransparency", inst.Transparency)
                end
                if inst:GetAttribute("OriginalCanCollide") == nil then
                    inst:SetAttribute("OriginalCanCollide", inst.CanCollide)
                end
                if inst:GetAttribute("OriginalCanTouch") == nil then
                    inst:SetAttribute("OriginalCanTouch", inst.CanTouch)
                end
                if inst:GetAttribute("OriginalCanQuery") == nil then
                    inst:SetAttribute("OriginalCanQuery", inst.CanQuery)
                end

                inst.Transparency = 1
                inst.CanCollide = false
                inst.CanTouch = false
                inst.CanQuery = false
            end
        elseif inst:IsA("ParticleEmitter") then
            inst.Enabled = active
        elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
            inst.Enabled = active
        end
    end
end

local function harvestNode(player, node)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local now = os.clock()
    local userId = player.UserId
    if now - (lastHarvestByPlayer[userId] or 0) < HARVEST_COOLDOWN_SECONDS then
        return
    end
    lastHarvestByPlayer[userId] = now

    if (root.Position - node.Position).Magnitude > MAX_HARVEST_DISTANCE then
        return
    end

    local nodeType = node:FindFirstChild("NodeType")
    local harvested = node:FindFirstChild("Harvested")
    local hitsLeft  = node:FindFirstChild("HitsLeft")

    if not nodeType or not harvested or not hitsLeft then return end
    if harvested.Value then return end

    hitsLeft.Value = hitsLeft.Value - 1

    local showHitFlash = node.Transparency < 0.95
    if showHitFlash then
        local originalColor = node.Color
        node.Color = Color3.fromRGB(255, 220, 120)
        task.delay(0.12, function()
            if node and node.Parent then
                node.Color = originalColor
            end
        end)
    end

    if hitsLeft.Value > 0 then
        ctx.Remotes.Notify:FireClient(player, {
            text  = nodeType.Value .. " — " .. hitsLeft.Value .. " hit(s) left",
            color = "yellow",
        })
        return
    end

    if node:GetAttribute("OriginalTransparency") == nil then
        node:SetAttribute("OriginalTransparency", node.Transparency)
    end
    if node:GetAttribute("OriginalCanCollide") == nil then
        node:SetAttribute("OriginalCanCollide", node.CanCollide)
    end
    if node:GetAttribute("OriginalCanTouch") == nil then
        node:SetAttribute("OriginalCanTouch", node.CanTouch)
    end
    if node:GetAttribute("OriginalCanQuery") == nil then
        node:SetAttribute("OriginalCanQuery", node.CanQuery)
    end

    harvested.Value   = true
    node.Transparency = 1
    node.CanCollide   = false
    node.CanTouch     = false

    local configuredDrops = ctx.Config.Resources and ctx.Config.Resources.Drops
    local dropCfg = (configuredDrops and configuredDrops[nodeType.Value]) or DEFAULT_DROPS[nodeType.Value]
    if dropCfg then
        local amount = randomInt(rng, dropCfg.min, dropCfg.max)
        local added  = ctx.InventoryService:addItem(player, dropCfg.item, amount)
        if added then
            local displayName = ctx.Config.Items[dropCfg.item] and ctx.Config.Items[dropCfg.item].displayName or dropCfg.item
            ctx.Remotes.Notify:FireClient(player, {
                text  = "+" .. amount .. " " .. displayName,
                color = "green",
            })

            if ctx.ObjectiveService and ctx.ObjectiveService.recordCollected then
                ctx.ObjectiveService:recordCollected(player, dropCfg.item, amount)
            end
            if ctx.ProgressionService and ctx.ProgressionService.addXp then
                ctx.ProgressionService:addXp(player, (ctx.Config.Progression and ctx.Config.Progression.HarvestXp) or 0, "harvesting")
            end
        end
    end

    ctx.Remotes.ResourceChanged:FireAllClients({
        nodeId    = tostring(node),
        harvested = true,
    })

    local visualModelRef = node:FindFirstChild("VisualModel")
    if visualModelRef and visualModelRef:IsA("ObjectValue") and visualModelRef.Value then
        setVisualModelActive(visualModelRef.Value, false)
    end

    table.insert(respawnQueue, {
        node  = node,
        timer = (ctx.Config.Resources and ctx.Config.Resources.RespawnTime) or DEFAULT_RESPAWN_TIME,
    })
end

function ResourceService:init(context)
    ctx = context
    self:hookExistingNodes()

    Players.PlayerRemoving:Connect(function(player)
        lastHarvestByPlayer[player.UserId] = nil
        lastStructurePlaceByPlayer[player.UserId] = nil
    end)

    Workspace.ChildAdded:Connect(function(child)
        self:tryHookNode(child)
    end)

    ctx.Remotes.PlaceStructure.OnServerEvent:Connect(function(player, structureId, position)
        self:placeStructure(player, structureId, position)
    end)

    print("[ResourceService] Initialised")
end

function ResourceService:hookExistingNodes()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        self:tryHookNode(obj)
    end
end

function ResourceService:tryHookNode(obj)
    if not obj:IsA("ProximityPrompt") then return end
    local node = obj.Parent
    if not node or not node:FindFirstChild("NodeType") then return end
    if obj:GetAttribute("Hooked") then return end
    obj:SetAttribute("Hooked", true)

    obj.Triggered:Connect(function(player)
        harvestNode(player, node)
    end)
end

function ResourceService:placeStructure(player, structureId, position)
    if typeof(position) ~= "Vector3" then
        ctx.Remotes.Notify:FireClient(player, { text="Invalid placement target.", color="red" })
        return
    end

    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local now = os.clock()
    local userId = player.UserId
    if now - (lastStructurePlaceByPlayer[userId] or 0) < 0.35 then
        return
    end
    lastStructurePlaceByPlayer[userId] = now

    local dist = (root.Position - position).Magnitude
    if dist > MAX_STRUCTURE_PLACE_DISTANCE then
        ctx.Remotes.Notify:FireClient(player, { text="Too far away to place that.", color="red" })
        return
    end
    if dist < MIN_STRUCTURE_PLACE_DISTANCE then
        ctx.Remotes.Notify:FireClient(player, { text="Move back a little before placing.", color="yellow" })
        return
    end

    local safePos
    if ctx.WorldService and ctx.WorldService.snapToGround then
        safePos = ctx.WorldService:snapToGround(position, 0.5, false)
    else
        safePos = Vector3.new(position.X, math.max(1, position.Y), position.Z)
    end

    if structureId == "CampfireKit" then
        if not ctx.InventoryService:hasItem(player, "CampfireKit", 1) then
            ctx.Remotes.Notify:FireClient(player, { text="No Campfire Kit!", color="red" })
            return
        end
        ctx.InventoryService:removeItem(player, "CampfireKit", 1)
        ctx.WorldService:spawnCampfire(safePos)
        ctx.Remotes.Notify:FireClient(player, { text="Campfire placed!", color="green" })

    elseif structureId == "ShelterKit" then
        if not ctx.InventoryService:hasItem(player, "ShelterKit", 1) then
            ctx.Remotes.Notify:FireClient(player, { text="No Shelter Kit!", color="red" })
            return
        end
        ctx.InventoryService:removeItem(player, "ShelterKit", 1)
        self:placeShelter(safePos)
        ctx.Remotes.Notify:FireClient(player, { text="Shelter built!", color="green" })

    elseif structureId == "WorkbenchKit" then
        if not ctx.InventoryService:hasItem(player, "WorkbenchKit", 1) then
            ctx.Remotes.Notify:FireClient(player, { text="No Workbench Kit!", color="red" })
            return
        end
        if not (ctx.WorldService and ctx.WorldService.spawnWorkbench) then
            ctx.Remotes.Notify:FireClient(player, { text="Workbench system unavailable.", color="red" })
            return
        end
        ctx.InventoryService:removeItem(player, "WorkbenchKit", 1)
        ctx.WorldService:spawnWorkbench(safePos)
        ctx.Remotes.Notify:FireClient(player, { text="Workbench placed!", color="green" })
    end
end

function ResourceService:placeShelter(position)
    local function wall(cf, sz, col)
        local p = Instance.new("Part")
        p.Anchored = true
        p.CFrame = cf
        p.Size = sz
        p.Color = col
        p.Material = Enum.Material.Wood
        p.Parent = Workspace
        return p
    end
    local col = Color3.fromRGB(80, 60, 40)
    local x,y,z = position.X, position.Y, position.Z
    wall(CFrame.new(x,    y+3,  z-5), Vector3.new(10,6,0.5), col)
    wall(CFrame.new(x-5,  y+3,  z),   Vector3.new(0.5,6,10), col)
    wall(CFrame.new(x+5,  y+3,  z),   Vector3.new(0.5,6,10), col)
    wall(CFrame.new(x,    y+6.2,z),   Vector3.new(10,0.5,10),col)
end

function ResourceService:tick(dt)
    local i = 1
    while i <= #respawnQueue do
        local entry = respawnQueue[i]
        entry.timer = entry.timer - dt
        if entry.timer <= 0 then
            local node      = entry.node
            if not node or not node.Parent then
                table.remove(respawnQueue, i)
                continue
            end
            local hitsLeft  = node:FindFirstChild("HitsLeft")
            local harvested = node:FindFirstChild("Harvested")
            local nodeType  = node:FindFirstChild("NodeType")
            if hitsLeft then
                hitsLeft.Value = (ctx.Config.Resources and ctx.Config.Resources.Hits[nodeType and nodeType.Value]) or 1
            end
            if harvested then harvested.Value = false end
            node.Transparency = node:GetAttribute("OriginalTransparency") or 0
            node.CanCollide = node:GetAttribute("OriginalCanCollide") ~= false
            node.CanTouch = node:GetAttribute("OriginalCanTouch") ~= false
            node.CanQuery = node:GetAttribute("OriginalCanQuery") ~= false

            local visualModelRef = node:FindFirstChild("VisualModel")
            if visualModelRef and visualModelRef:IsA("ObjectValue") and visualModelRef.Value then
                setVisualModelActive(visualModelRef.Value, true)
            end
            ctx.Remotes.ResourceChanged:FireAllClients({ nodeId=tostring(node), harvested=false })
            table.remove(respawnQueue, i)
        else
            i = i + 1
        end
    end
end

return ResourceService
