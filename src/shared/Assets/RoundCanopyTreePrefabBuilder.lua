--!strict
-- RoundCanopyTreePrefabBuilder.lua
-- Roblox-ready stylized tree inspired by the uploaded reference:
-- smooth trunk, forked branches, and round clustered leafy canopies.
--
-- Place as:
--   src/shared/Assets/RoundCanopyTreePrefabBuilder.lua
--
-- Test in Studio:
--   local Builder = require(game.ReplicatedStorage.Shared.Assets.RoundCanopyTreePrefabBuilder)
--   local tree = Builder.Create(CFrame.new(0, 4, 0))
--   tree.Parent = workspace

local Builder = {}

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	canCollide: boolean?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = if canCollide == nil then true else canCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeCylinder(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	canCollide: boolean?
): BasePart
	local p = makePart(name, size, cframe, color, material, parent, canCollide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function makeBall(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	canCollide: boolean?
): BasePart
	local p = makePart(name, size, cframe, color, material, parent, canCollide)
	p.Shape = Enum.PartType.Ball
	return p
end

local function addLeafBumps(model: Model, root: CFrame, center: Vector3, radius: number, colorA: Color3, colorB: Color3)
	local bumpPositions = {
		Vector3.new(-0.45, 0.15, -0.25),
		Vector3.new(0.42, 0.18, -0.18),
		Vector3.new(-0.08, 0.42, 0.0),
		Vector3.new(0.05, -0.18, 0.42),
		Vector3.new(-0.35, -0.05, 0.32),
		Vector3.new(0.38, -0.08, 0.35),
		Vector3.new(0.0, 0.02, -0.48),
	}

	for i, offset in ipairs(bumpPositions) do
		local scale = if i % 2 == 0 then 0.42 else 0.34
		local color = if i % 2 == 0 then colorA else colorB
		local pos = center + offset * radius
		makeBall(
			"LeafClusterBump_" .. i,
			Vector3.new(radius * scale, radius * scale, radius * scale),
			root * CFrame.new(pos),
			color,
			Enum.Material.Grass,
			model,
			false
		)
	end
end

function Builder.Create(pivot: CFrame?): Model
	local root = pivot or CFrame.new()
	local model = Instance.new("Model")
	model.Name = "RoundCanopyTree"

	model:SetAttribute("ObjectType", "ResourceNode")
	model:SetAttribute("ResourceType", "Tree")
	model:SetAttribute("HarvestTool", "Axe")
	model:SetAttribute("MaxHealth", 100)
	model:SetAttribute("Health", 100)
	model:SetAttribute("RewardItem", "Wood")
	model:SetAttribute("RewardAmount", 5)
	model:SetAttribute("RespawnSeconds", 45)
	model:SetAttribute("InteractDistance", 10)
	model:SetAttribute("VisualStyle", "StylizedRoundCanopy")

	local trunkColor = Color3.fromRGB(143, 94, 62)
	local trunkDark = Color3.fromRGB(101, 66, 44)
	local leafMain = Color3.fromRGB(69, 154, 76)
	local leafLight = Color3.fromRGB(118, 201, 91)
	local leafDark = Color3.fromRGB(36, 108, 61)

	local rootPart = makePart(
		"Root",
		Vector3.new(0.5, 0.5, 0.5),
		root * CFrame.new(0, 4.2, 0),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		model,
		false
	)
	rootPart.Transparency = 1
	model.PrimaryPart = rootPart

	makeCylinder(
		"SmoothMainTrunk",
		Vector3.new(7.2, 0.75, 0.75),
		root * CFrame.new(0, 3.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
		trunkColor,
		Enum.Material.Wood,
		model,
		true
	)

	for i, y in ipairs({0.6, 1.5, 2.4, 3.3, 4.2, 5.1, 5.8}) do
		makeCylinder(
			"TrunkBarkBand_" .. i,
			Vector3.new(0.055, 0.79, 0.79),
			root * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			trunkDark,
			Enum.Material.Wood,
			model,
			false
		)
	end

	makeCylinder(
		"LeftBranch",
		Vector3.new(3.2, 0.38, 0.38),
		root * CFrame.new(-0.85, 5.65, 0) * CFrame.Angles(0, math.rad(0), math.rad(52)),
		trunkDark,
		Enum.Material.Wood,
		model,
		true
	)

	makeCylinder(
		"RightBranch",
		Vector3.new(3.1, 0.36, 0.36),
		root * CFrame.new(1.0, 5.85, 0.05) * CFrame.Angles(0, math.rad(0), math.rad(128)),
		trunkDark,
		Enum.Material.Wood,
		model,
		true
	)

	makeCylinder(
		"RearBranch",
		Vector3.new(2.4, 0.30, 0.30),
		root * CFrame.new(0.25, 5.8, 0.7) * CFrame.Angles(math.rad(38), 0, math.rad(92)),
		trunkDark,
		Enum.Material.Wood,
		model,
		true
	)

	local canopies = {
		{name = "CanopyLeft", center = Vector3.new(-1.85, 6.7, -0.1), size = Vector3.new(3.2, 2.8, 3.0), color = leafMain},
		{name = "CanopyTop", center = Vector3.new(-0.1, 7.45, 0.0), size = Vector3.new(3.35, 2.85, 3.1), color = leafLight},
		{name = "CanopyRight", center = Vector3.new(1.85, 6.75, 0.05), size = Vector3.new(3.15, 2.7, 2.95), color = leafMain},
		{name = "CanopyRear", center = Vector3.new(0.15, 6.45, 1.25), size = Vector3.new(2.65, 2.35, 2.45), color = leafDark},
	}

	for _, canopy in ipairs(canopies) do
		local b = makeBall(
			canopy.name,
			canopy.size,
			root * CFrame.new(canopy.center),
			canopy.color,
			Enum.Material.Grass,
			model,
			false
		)
		b.CastShadow = true
		addLeafBumps(model, root, canopy.center, math.max(canopy.size.X, canopy.size.Y, canopy.size.Z), leafLight, leafDark)
	end

	local flecks = {
		Vector3.new(-2.8, 7.1, -1.25), Vector3.new(-1.8, 7.75, -1.35), Vector3.new(-0.4, 8.25, -1.25),
		Vector3.new(1.2, 7.85, -1.25), Vector3.new(2.4, 7.15, -1.15), Vector3.new(-2.9, 6.25, -1.05),
		Vector3.new(-0.9, 6.4, -1.45), Vector3.new(0.8, 6.35, -1.4), Vector3.new(2.65, 6.35, -0.9),
	}

	for i, pos in ipairs(flecks) do
		makeBall(
			"LightLeafFleck_" .. i,
			Vector3.new(0.28, 0.18, 0.18),
			root * CFrame.new(pos),
			leafLight,
			Enum.Material.Grass,
			model,
			false
		)
	end

	local hitbox = makePart(
		"InteractionHitbox",
		Vector3.new(2.4, 6.8, 2.4),
		root * CFrame.new(0, 3.4, 0),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		model,
		false
	)
	hitbox.Transparency = 1

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Harvest"
	prompt.ActionText = "Chop"
	prompt.ObjectText = "Tree"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = hitbox

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			child:SetAttribute("TreePart", true)
		end
	end

	model:PivotTo(root)
	return model
end

return Builder
