-- StoneOvenService.lua  (Milestone 8)
--
-- PURPOSE:
--   Handles the Stone Oven placeable structure.
--   A Stone Oven is a crafted item (requires Stone + IronOre + AshWood).
--   When placed it becomes a physical model in the world.
--
--   The oven does two things:
--     1. Acts as a cooking station — players within OvenRadius can craft
--        "nearOven" recipes (Meat Stew, Mushroom Soup, Dried Meat).
--     2. Also counts as a heat source like a campfire (same warm radius).
--
-- DIFFERENCE FROM CAMPFIRE:
--   Campfire = quick to build, basic cooking (Cooked Meat only), burns wood.
--   Stone Oven = mid-game build, unlocks 3 advanced food recipes, no fuel needed.
--
-- HOW PLACEMENT WORKS:
--   Client sends PlaceOvenRequest.
--   Server validates the player has a StoneOven in inventory, removes it,
--   builds the model at the position 5 studs ahead of the player, registers it.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local StoneOvenService = {}
local ctx

-- List of active oven models { model, base, position }
local ovens = {}

local OvenRadius = 14  -- studs within which cooking is allowed

-- ── Build oven model ─────────────────────────────────────────────────────────

local function buildOven(position)
    local model = Instance.new("Model")
    model.Name  = "StoneOven"

    local gray      = Color3.fromRGB(110, 108, 102)
    local darkGray  = Color3.fromRGB(70, 68, 64)
    local orange    = Color3.fromRGB(220, 120, 30)
    local lightOrange = Color3.fromRGB(255, 200, 60)

    local function part(name, size, cf, color, mat)
        local p = Instance.new("Part")
        p.Name       = name
        p.Anchored   = true
        p.CanCollide = true
        p.Size       = size
        p.CFrame     = cf
        p.Color      = color
        p.Material   = mat or Enum.Material.SmoothPlastic
        p.Parent     = model
        return p
    end

    local cf = CFrame.new(position)

    -- Main stone body
    local base = part("Base", Vector3.new(3.5, 2.5, 3.5),
        cf * CFrame.new(0, 1.25, 0), gray, Enum.Material.SmoothPlastic)
    base:SetAttribute("IsStoneOven", true)

    -- Chimney
    part("Chimney", Vector3.new(0.8, 1.8, 0.8),
        cf * CFrame.new(1.0, 3.4, 1.0), darkGray, Enum.Material.SmoothPlastic)

    -- Oven mouth opening (darker inset)
    part("Mouth", Vector3.new(1.2, 1.0, 0.3),
        cf * CFrame.new(0, 0.8, -1.6), darkGray, Enum.Material.SmoothPlastic)

    -- Fire glow inside mouth (neon orange)
    local glow = part("FireGlow", Vector3.new(0.9, 0.7, 0.1),
        cf * CFrame.new(0, 0.8, -1.75), orange, Enum.Material.Neon)
    glow.CanCollide = false

    -- Ember sparks (two tiny neon dots)
    local s1 = part("Spark1", Vector3.new(0.15, 0.15, 0.15),
        cf * CFrame.new(-0.2, 1.3, -1.75), lightOrange, Enum.Material.Neon)
    s1.CanCollide = false
    local s2 = part("Spark2", Vector3.new(0.15, 0.15, 0.15),
        cf * CFrame.new( 0.3, 1.5, -1.75), lightOrange, Enum.Material.Neon)
    s2.CanCollide = false

    -- Top cooking surface (flat stone slab)
    part("Top", Vector3.new(3.5, 0.3, 3.5),
        cf * CFrame.new(0, 2.65, 0), darkGray, Enum.Material.SmoothPlastic)

    -- BillboardGui label
    local bb = Instance.new("BillboardGui", base)
    bb.Size = UDim2.new(0, 100, 0, 24)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = false
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "🪵 Stone Oven"
    lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold

    -- ProximityPrompt so player can open crafting UI at the oven
    local prompt = Instance.new("ProximityPrompt", base)
    prompt.ActionText    = "Cook"
    prompt.ObjectText    = "Stone Oven"
    prompt.HoldDuration  = 0
    prompt.MaxActivationDistance = OvenRadius
    prompt.KeyboardKeyCode = Enum.KeyCode.E

    model.PrimaryPart = base
    model.Parent      = Workspace
    return model, base
end

-- ── Public helpers used by CraftingService ───────────────────────────────────

function StoneOvenService:isNearOven(player)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local pos = root.Position
    for _, entry in ipairs(ovens) do
        if entry.base and entry.base.Parent then
            local d = (entry.base.Position - pos).Magnitude
            if d <= OvenRadius then return true end
        end
    end
    return false
end

-- ── Init ──────────────────────────────────────────────────────────────────

function StoneOvenService:init(context)
    ctx = context

    -- Listen for placement requests from the client
    ctx.Remotes.PlaceOvenRequest.OnServerEvent:Connect(function(player)
        -- Validate inventory
        if not ctx.InventoryService:hasItem(player, "StoneOven", 1) then
            ctx.Remotes.Notify:FireClient(player, {
                text  = "You don't have a Stone Oven to place!",
                color = "red",
            })
            return
        end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        -- Place 5 studs in front of the player
        local forward = root.CFrame.LookVector
        local pos     = root.Position + forward * 5
        pos = Vector3.new(pos.X, 1, pos.Z)  -- snap to ground level

        -- Remove item from inventory
        ctx.InventoryService:removeItem(player, "StoneOven", 1)

        -- Build + register
        local model, base = buildOven(pos)
        table.insert(ovens, { model=model, base=base, position=pos })

        -- Tell client success
        ctx.Remotes.Notify:FireClient(player, {
            text  = "Stone Oven placed! Stand near it to cook advanced recipes.",
            color = "green",
        })

        print("[StoneOvenService] Oven placed by", player.Name)
    end)

    print("[StoneOvenService] Initialised")
end

return StoneOvenService
