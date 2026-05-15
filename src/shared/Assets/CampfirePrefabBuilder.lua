--!strict
-- CampfirePrefabBuilder.lua
-- Roblox-ready campfire prefab inspired by the uploaded reference:
-- circular stone ring, crossed logs, bright fire, glow, smoke, and warm zone attributes.
--
-- Place as:
--   src/shared/Assets/CampfirePrefabBuilder.lua
--
-- Test in Studio:
--   local Builder = require(game.ReplicatedStorage.Shared.Assets.CampfirePrefabBuilder)
--   local campfire = Builder.Create(CFrame.new(0, 1, 0))
--   campfire.Parent = workspace

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

local function cylinder(
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

local function ball(
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

local function wedge(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	canCollide: boolean?
): WedgePart
	local p = Instance.new("WedgePart")
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

local function addFireParticles(parent: BasePart)
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "FireParticles"
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Rate = 90
	fire.Lifetime = NumberRange.new(0.45, 0.9)
	fire.Speed = NumberRange.new(2.5, 5.5)
	fire.SpreadAngle = Vector2.new(25, 25)
	fire.Rotation = NumberRange.new(0, 360)
	fire.RotSpeed = NumberRange.new(-80, 80)
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3),
		NumberSequenceKeypoint.new(0.45, 2.0),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 235, 130)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 118, 24)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 35, 15)),
	})
	fire.LightEmission = 0.8
	fire.Parent = parent

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "SmokeParticles"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 28
	smoke.Lifetime = NumberRange.new(2.2, 4.2)
	smoke.Speed = NumberRange.new(1.2, 3.0)
	smoke.Acceleration = Vector3.new(0, 1.2, 0)
	smoke.SpreadAngle = Vector2.new(35, 35)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-20, 20)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 2.2),
		NumberSequenceKeypoint.new(1, 4.0),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.fromRGB(78, 78, 75))
	smoke.Parent = parent

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Rate = 14
	sparks.Lifetime = NumberRange.new(0.35, 0.8)
	sparks.Speed = NumberRange.new(4, 8)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 64))
	sparks.LightEmission = 1
	sparks.Parent = parent
end

function Builder.Create(pivot: CFrame?): Model
	local rootCFrame = pivot or CFrame.new()
	local model = Instance.new("Model")
	model.Name = "Campfire"

	model:SetAttribute("ObjectType", "CraftingStation")
	model:SetAttribute("StationType", "Campfire")
	model:SetAttribute("ProvidesWarmth", true)
	model:SetAttribute("WarmthRadius", 18)
	model:SetAttribute("WarmthPerSecond", 3)
	model:SetAttribute("FuelSeconds", 300)
	model:SetAttribute("DamageIfTouched", 8)
	model:SetAttribute("InteractDistance", 9)
	model:SetAttribute("RecipeId", "Campfire")
	model:SetAttribute("VisualStyle", "StoneRingCrossedLogsFire")

	local stone = Color3.fromRGB(43, 49, 55)
	local stoneLight = Color3.fromRGB(64, 72, 80)
	local charredWood = Color3.fromRGB(62, 38, 22)
	local wood = Color3.fromRGB(105, 63, 32)
	local ember = Color3.fromRGB(255, 99, 25)
	local flameOrange = Color3.fromRGB(255, 128, 24)
	local flameYellow = Color3.fromRGB(255, 229, 104)
	local flameRed = Color3.fromRGB(185, 45, 21)

	local root = makePart(
		"Root",
		Vector3.new(0.5, 0.5, 0.5),
		rootCFrame * CFrame.new(0, 0.55, 0),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		model,
		false
	)
	root.Transparency = 1
	model.PrimaryPart = root

	cylinder(
		"AshBase",
		Vector3.new(0.18, 5.1, 5.1),
		rootCFrame * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(33, 35, 36),
		Enum.Material.Slate,
		model,
		true
	)

	local stoneCount = 12
	for i = 1, stoneCount do
		local angle = ((i - 1) / stoneCount) * math.pi * 2
		local radius = 2.1
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local yaw = -angle
		local size = Vector3.new(
			0.85 + ((i % 3) * 0.08),
			0.55 + ((i % 2) * 0.12),
			0.72 + ((i % 4) * 0.06)
		)
		makePart(
			"BasaltRingStone_" .. i,
			size,
			rootCFrame * CFrame.new(x, 0.35, z) * CFrame.Angles(0, yaw, math.rad((i % 2 == 0) and 4 or -4)),
			if i % 2 == 0 then stone else stoneLight,
			Enum.Material.Slate,
			model,
			true
		)
	end

	local logAngles = {0, 60, 120}
	for i, deg in ipairs(logAngles) do
		local log = cylinder(
			"CharredLog_" .. i,
			Vector3.new(3.15, 0.38, 0.38),
			rootCFrame * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, math.rad(deg), math.rad(90)),
			if i == 1 then wood else charredWood,
			Enum.Material.Wood,
			model,
			true
		)
		log:SetAttribute("Fuel", true)

		cylinder(
			"LogCutEndA_" .. i,
			Vector3.new(0.05, 0.42, 0.42),
			rootCFrame * CFrame.new(math.cos(math.rad(deg)) * 1.58, 0.65, math.sin(math.rad(deg)) * 1.58) * CFrame.Angles(0, math.rad(deg), math.rad(90)),
			Color3.fromRGB(134, 92, 53),
			Enum.Material.Wood,
			model,
			false
		)
		cylinder(
			"LogCutEndB_" .. i,
			Vector3.new(0.05, 0.42, 0.42),
			rootCFrame * CFrame.new(-math.cos(math.rad(deg)) * 1.58, 0.65, -math.sin(math.rad(deg)) * 1.58) * CFrame.Angles(0, math.rad(deg), math.rad(90)),
			Color3.fromRGB(134, 92, 53),
			Enum.Material.Wood,
			model,
			false
		)
	end

	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local radius = if i % 2 == 0 then 0.55 else 0.9
		ball(
			"GlowingCoal_" .. i,
			Vector3.new(0.22, 0.16, 0.22),
			rootCFrame * CFrame.new(math.cos(angle) * radius, 0.52, math.sin(angle) * radius),
			if i % 2 == 0 then ember else flameRed,
			Enum.Material.Neon,
			model,
			false
		)
	end

	local flameRoot = makePart(
		"FireEmitter",
		Vector3.new(0.5, 0.5, 0.5),
		rootCFrame * CFrame.new(0, 1.0, 0),
		flameOrange,
		Enum.Material.Neon,
		model,
		false
	)
	flameRoot.Transparency = 1

	local flameLayers = {
		{"OuterFlameA", Vector3.new(1.8, 2.9, 0.24), CFrame.Angles(0, math.rad(0), 0), flameOrange},
		{"OuterFlameB", Vector3.new(1.7, 2.7, 0.24), CFrame.Angles(0, math.rad(60), 0), flameOrange},
		{"OuterFlameC", Vector3.new(1.7, 2.7, 0.24), CFrame.Angles(0, math.rad(120), 0), flameRed},
		{"InnerFlameA", Vector3.new(1.0, 2.4, 0.18), CFrame.Angles(0, math.rad(30), 0), flameYellow},
		{"InnerFlameB", Vector3.new(0.9, 2.2, 0.18), CFrame.Angles(0, math.rad(90), 0), flameYellow},
	}

	for _, data in ipairs(flameLayers) do
		local name = data[1] :: string
		local size = data[2] :: Vector3
		local rotation = data[3] :: CFrame
		local color = data[4] :: Color3
		local f = wedge(
			name,
			size,
			rootCFrame * CFrame.new(0, 1.55, 0) * rotation * CFrame.Angles(math.rad(-8), 0, 0),
			color,
			Enum.Material.Neon,
			model,
			false
		)
		f:SetAttribute("VisualFlame", true)
	end

	local pointLight = Instance.new("PointLight")
	pointLight.Name = "FireGlow"
	pointLight.Color = Color3.fromRGB(255, 146, 52)
	pointLight.Brightness = 3
	pointLight.Range = 22
	pointLight.Shadows = true
	pointLight.Parent = flameRoot

	local smokeLight = Instance.new("PointLight")
	smokeLight.Name = "SoftSmokeGlow"
	smokeLight.Color = Color3.fromRGB(255, 100, 40)
	smokeLight.Brightness = 0.8
	smokeLight.Range = 10
	smokeLight.Parent = root

	addFireParticles(flameRoot)

	local warmthZone = makePart(
		"WarmthZone",
		Vector3.new(18, 9, 18),
		rootCFrame * CFrame.new(0, 4.5, 0),
		Color3.new(1, 0.4, 0.1),
		Enum.Material.SmoothPlastic,
		model,
		false
	)
	warmthZone.Transparency = 1
	warmthZone:SetAttribute("ZoneType", "Warmth")
	warmthZone:SetAttribute("Radius", 18)

	local hitbox = makePart(
		"InteractionHitbox",
		Vector3.new(5.5, 3.5, 5.5),
		rootCFrame * CFrame.new(0, 1.5, 0),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		model,
		false
	)
	hitbox.Transparency = 1

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UseCampfire"
	prompt.ActionText = "Use"
	prompt.ObjectText = "Campfire"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = hitbox

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			child:SetAttribute("CampfirePart", true)
		end
	end

	model:PivotTo(rootCFrame)
	return model
end

return Builder
