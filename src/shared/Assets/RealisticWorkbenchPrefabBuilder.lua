--!strict
-- RealisticWorkbenchPrefabBuilder.lua
-- Builds a Roblox-ready workbench inspired by a realistic garage/carpentry bench:
-- long table, back tool wall, upper shelf, hanging tools, side drawer table,
-- stool/box details, and crafting interaction prompt.
--
-- Place as:
--   src/shared/Assets/RealisticWorkbenchPrefabBuilder.lua
--
-- Test in Studio:
--   local Builder = require(game.ReplicatedStorage.Shared.Assets.RealisticWorkbenchPrefabBuilder)
--   local bench = Builder.Create(CFrame.new(0, 4, 0))
--   bench.Parent = workspace

local Builder = {}

local function part(
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
	local p = part(name, size, cframe, color, material, parent, canCollide)
	p.Shape = Enum.PartType.Cylinder
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

local function addPrompt(parentPart: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Craft"
	prompt.ActionText = "Craft"
	prompt.ObjectText = "Workbench"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parentPart
end

function Builder.Create(pivot: CFrame?): Model
	local root = pivot or CFrame.new()
	local model = Instance.new("Model")
	model.Name = "Workbench"

	model:SetAttribute("ObjectType", "CraftingStation")
	model:SetAttribute("StationType", "Workbench")
	model:SetAttribute("InteractDistance", 10)
	model:SetAttribute("VisualStyle", "RealisticCarpentrySurvivalBench")

	local wood = Color3.fromRGB(151, 112, 67)
	local wood2 = Color3.fromRGB(123, 88, 52)
	local darkWood = Color3.fromRGB(82, 58, 38)
	local metal = Color3.fromRGB(112, 111, 105)
	local darkMetal = Color3.fromRGB(61, 63, 64)
	local paper = Color3.fromRGB(226, 218, 195)
	local black = Color3.fromRGB(28, 28, 29)
	local yellow = Color3.fromRGB(233, 184, 47)
	local red = Color3.fromRGB(127, 54, 44)
	local green = Color3.fromRGB(77, 119, 88)

	local rootPart = part("Root", Vector3.new(0.5, 0.5, 0.5), root * CFrame.new(0, 2.4, 0), Color3.new(1,1,1), Enum.Material.SmoothPlastic, model, false)
	rootPart.Transparency = 1
	model.PrimaryPart = rootPart

	part("MainWorkbenchTop", Vector3.new(9.2, 0.35, 2.1), root * CFrame.new(0, 2.45, 0), wood, Enum.Material.WoodPlanks, model)
	part("FrontApron", Vector3.new(9.4, 0.28, 0.22), root * CFrame.new(0, 2.15, -1.13), darkWood, Enum.Material.Wood, model)
	part("BackApron", Vector3.new(9.4, 0.28, 0.22), root * CFrame.new(0, 2.15, 1.13), darkWood, Enum.Material.Wood, model)
	part("LowerBackRail", Vector3.new(8.7, 0.22, 0.18), root * CFrame.new(0, 0.95, 1.05), darkWood, Enum.Material.Wood, model)
	part("LowerFrontRail", Vector3.new(8.7, 0.22, 0.18), root * CFrame.new(0, 0.95, -1.05), darkWood, Enum.Material.Wood, model)

	for i, x in ipairs({-4.25, -1.7, 1.7, 4.25}) do
		part("MainLeg_" .. i, Vector3.new(0.35, 2.25, 0.35), root * CFrame.new(x, 1.25, -0.9), darkWood, Enum.Material.Wood, model)
		part("RearLeg_" .. i, Vector3.new(0.35, 2.25, 0.35), root * CFrame.new(x, 1.25, 0.9), darkWood, Enum.Material.Wood, model)
	end

	part("BackToolWall", Vector3.new(8.6, 3.1, 0.28), root * CFrame.new(0, 4.1, 1.18), wood2, Enum.Material.WoodPlanks, model)
	part("BackWallTopTrim", Vector3.new(8.9, 0.22, 0.36), root * CFrame.new(0, 5.75, 1.02), darkWood, Enum.Material.Wood, model)
	part("BackWallBottomTrim", Vector3.new(8.9, 0.22, 0.36), root * CFrame.new(0, 2.48, 1.02), darkWood, Enum.Material.Wood, model)

	part("UpperShelf", Vector3.new(8.7, 0.24, 0.85), root * CFrame.new(0.1, 5.55, 0.38), wood, Enum.Material.WoodPlanks, model)
	part("ShelfLip", Vector3.new(8.7, 0.18, 0.16), root * CFrame.new(0.1, 5.72, -0.02), darkWood, Enum.Material.Wood, model)
	for i, x in ipairs({-3.8, -1.2, 1.2, 3.8}) do
		part("ShelfBracket_" .. i, Vector3.new(0.22, 0.62, 0.22), root * CFrame.new(x, 5.18, 0.72) * CFrame.Angles(math.rad(25), 0, 0), darkMetal, Enum.Material.Metal, model)
	end

	part("LeftNoticeBoard", Vector3.new(1.5, 1.45, 0.16), root * CFrame.new(-5.45, 4.25, 1.05), Color3.fromRGB(135, 101, 63), Enum.Material.WoodPlanks, model)
	part("NoticePaperLarge", Vector3.new(0.8, 0.95, 0.04), root * CFrame.new(-5.35, 4.18, 0.94), paper, Enum.Material.SmoothPlastic, model, false)
	part("NoticePaperSmallA", Vector3.new(0.42, 0.25, 0.04), root * CFrame.new(-5.82, 4.66, 0.93) * CFrame.Angles(0, 0, math.rad(7)), paper, Enum.Material.SmoothPlastic, model, false)
	part("NoticePaperSmallB", Vector3.new(0.34, 0.24, 0.04), root * CFrame.new(-4.95, 4.72, 0.93) * CFrame.Angles(0, 0, math.rad(-10)), paper, Enum.Material.SmoothPlastic, model, false)

	cylinder("HangingLampCage", Vector3.new(0.55, 0.55, 0.55), root * CFrame.new(-5.2, 5.55, -0.15) * CFrame.Angles(0, 0, math.rad(90)), black, Enum.Material.Metal, model, false)
	local bulb = part("LampGlow", Vector3.new(0.35, 0.35, 0.35), root * CFrame.new(-5.2, 5.55, -0.15), Color3.fromRGB(255, 216, 118), Enum.Material.Neon, model, false)
	local light = Instance.new("PointLight")
	light.Name = "WarmWorkbenchLight"
	light.Color = Color3.fromRGB(255, 204, 120)
	light.Brightness = 1.2
	light.Range = 8
	light.Parent = bulb

	cylinder("ShelfCanLeft", Vector3.new(0.28, 0.45, 0.28), root * CFrame.new(-3.25, 5.9, 0.38), darkMetal, Enum.Material.Metal, model)
	cylinder("ShelfCanRight", Vector3.new(0.24, 0.38, 0.24), root * CFrame.new(3.55, 5.86, 0.38), darkMetal, Enum.Material.Metal, model)
	part("ShelfBoneA", Vector3.new(0.7, 0.12, 0.12), root * CFrame.new(-0.8, 5.86, 0.35) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(220, 214, 198), Enum.Material.SmoothPlastic, model, false)
	cylinder("ShelfBoneKnobA", Vector3.new(0.22, 0.22, 0.22), root * CFrame.new(-1.15, 5.87, 0.35), Color3.fromRGB(220, 214, 198), Enum.Material.SmoothPlastic, model, false)
	cylinder("ShelfBoneKnobB", Vector3.new(0.22, 0.22, 0.22), root * CFrame.new(-0.45, 5.87, 0.35), Color3.fromRGB(220, 214, 198), Enum.Material.SmoothPlastic, model, false)

	part("HangingAxeHandleA", Vector3.new(0.12, 1.05, 0.08), root * CFrame.new(-3.45, 3.86, 0.92), darkWood, Enum.Material.Wood, model, false)
	wedge("HangingAxeHeadA", Vector3.new(0.45, 0.42, 0.12), root * CFrame.new(-3.65, 4.34, 0.92), metal, Enum.Material.Metal, model, false)
	part("HangingAxeHandleB", Vector3.new(0.12, 1.0, 0.08), root * CFrame.new(-2.65, 3.83, 0.92), darkWood, Enum.Material.Wood, model, false)
	wedge("HangingAxeHeadB", Vector3.new(0.38, 0.38, 0.12), root * CFrame.new(-2.82, 4.28, 0.92), Color3.fromRGB(72, 91, 103), Enum.Material.Metal, model, false)

	part("HangingCrowbarMain", Vector3.new(1.25, 0.1, 0.08), root * CFrame.new(-0.8, 4.35, 0.92) * CFrame.Angles(0, 0, math.rad(22)), black, Enum.Material.Metal, model, false)
	part("HangingSawBack", Vector3.new(1.0, 0.08, 0.08), root * CFrame.new(2.1, 4.08, 0.92) * CFrame.Angles(0, 0, math.rad(8)), metal, Enum.Material.Metal, model, false)
	wedge("HangingSawBlade", Vector3.new(1.1, 0.34, 0.1), root * CFrame.new(2.0, 3.9, 0.92), metal, Enum.Material.Metal, model, false)

	for i, x in ipairs({-0.4, -0.05, 0.3, 0.65}) do
		part("HangingToolHandle_" .. i, Vector3.new(0.08, 0.34, 0.08), root * CFrame.new(x, 3.55, 0.92), if i % 2 == 0 then red else green, Enum.Material.SmoothPlastic, model, false)
		part("HangingToolMetal_" .. i, Vector3.new(0.05, 0.5, 0.05), root * CFrame.new(x, 3.15, 0.92), metal, Enum.Material.Metal, model, false)
	end

	for i, x in ipairs({-4.0, -3.2, -2.35, -1.0, -0.2, 0.55, 1.55, 2.5, 3.3}) do
		part("ToolPeg_" .. i, Vector3.new(0.09, 0.09, 0.25), root * CFrame.new(x, 4.55 - (i % 3) * 0.42, 0.85), darkMetal, Enum.Material.Metal, model, false)
	end

	part("YellowLevel", Vector3.new(2.1, 0.12, 0.18), root * CFrame.new(2.55, 2.75, -0.42), yellow, Enum.Material.SmoothPlastic, model, false)
	for _, x in ipairs({1.8, 2.55, 3.3}) do
		part("LevelBubble", Vector3.new(0.18, 0.04, 0.2), root * CFrame.new(x, 2.83, -0.42), Color3.fromRGB(180, 230, 150), Enum.Material.Glass, model, false)
	end

	part("BenchViseBase", Vector3.new(0.65, 0.25, 0.55), root * CFrame.new(-4.0, 2.78, -0.35), darkMetal, Enum.Material.Metal, model)
	part("BenchViseJawA", Vector3.new(0.16, 0.42, 0.55), root * CFrame.new(-4.35, 3.02, -0.35), darkMetal, Enum.Material.Metal, model)
	part("BenchViseJawB", Vector3.new(0.16, 0.42, 0.55), root * CFrame.new(-3.68, 3.02, -0.35), darkMetal, Enum.Material.Metal, model)

	part("SmallWoodBoxA", Vector3.new(0.72, 0.45, 0.52), root * CFrame.new(-2.15, 2.82, -0.35), wood2, Enum.Material.WoodPlanks, model)
	part("SmallWoodBoxB", Vector3.new(0.66, 0.42, 0.5), root * CFrame.new(-1.35, 2.80, -0.4), darkWood, Enum.Material.WoodPlanks, model)
	cylinder("CoffeeMug", Vector3.new(0.28, 0.32, 0.28), root * CFrame.new(3.92, 2.83, -0.22) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(100, 106, 105), Enum.Material.Metal, model, false)
	part("Pencil", Vector3.new(0.75, 0.04, 0.04), root * CFrame.new(-0.4, 2.72, -0.78) * CFrame.Angles(0, math.rad(16), 0), Color3.fromRGB(221, 166, 54), Enum.Material.Wood, model, false)

	part("SmallStoolSeat", Vector3.new(0.95, 0.18, 0.8), root * CFrame.new(-2.7, 1.05, -1.95), wood, Enum.Material.WoodPlanks, model)
	for i, pos in ipairs({Vector3.new(-3.05,0.58,-2.22), Vector3.new(-2.35,0.58,-2.22), Vector3.new(-3.0,0.58,-1.68), Vector3.new(-2.4,0.58,-1.68)}) do
		part("StoolLeg_" .. i, Vector3.new(0.12, 0.85, 0.12), root * CFrame.new(pos), darkWood, Enum.Material.Wood, model)
	end
	part("UnderBenchCrate", Vector3.new(0.92, 0.8, 0.72), root * CFrame.new(1.7, 0.7, -0.05), wood2, Enum.Material.WoodPlanks, model)

	part("SideTableTop", Vector3.new(1.75, 0.28, 1.45), root * CFrame.new(5.4, 2.15, -0.15), wood, Enum.Material.WoodPlanks, model)
	for i, x in ipairs({4.75, 6.05}) do
		for j, z in ipairs({-0.7, 0.35}) do
			part("SideTableLeg_" .. i .. "_" .. j, Vector3.new(0.26, 1.75, 0.26), root * CFrame.new(x, 1.15, z), darkWood, Enum.Material.Wood, model)
		end
	end
	part("SideDrawerFront", Vector3.new(1.25, 0.5, 0.12), root * CFrame.new(5.4, 1.78, -0.9), wood2, Enum.Material.WoodPlanks, model)
	cylinder("SideDrawerKnob", Vector3.new(0.12, 0.12, 0.12), root * CFrame.new(5.4, 1.78, -0.98) * CFrame.Angles(0, 0, math.rad(90)), darkMetal, Enum.Material.Metal, model, false)
	cylinder("SideTableCup", Vector3.new(0.28, 0.35, 0.28), root * CFrame.new(5.85, 2.48, -0.2) * CFrame.Angles(0, 0, math.rad(90)), metal, Enum.Material.Metal, model, false)

	local hitbox = part("InteractionHitbox", Vector3.new(9.6, 3.5, 3.0), root * CFrame.new(0, 2.85, -0.1), Color3.new(1,1,1), Enum.Material.SmoothPlastic, model, false)
	hitbox.Transparency = 1
	addPrompt(hitbox)

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			child:SetAttribute("WorkbenchPart", true)
		end
	end

	model:PivotTo(root)
	return model
end

return Builder
