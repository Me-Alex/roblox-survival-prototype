-- WorldService.lua
-- World terrain, resource nodes, day/night cycle.
-- Milestone 1: lighting + spawn platform stub.
-- Milestone 2: full terrain and resource spawning.

local Lighting  = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WorldService = {}
local ctx
local dayTimer = 0
local day = 1

function WorldService:init(context)
    ctx = context
    self:setupLighting()
    self:createSpawnPlatform()
    print("[WorldService] Initialised")
end

function WorldService:setupLighting()
    Lighting.ClockTime         = 9
    Lighting.Brightness        = 1.8
    Lighting.GlobalShadows     = true
    Lighting.Ambient           = Color3.fromRGB(58, 44, 34)
    Lighting.OutdoorAmbient    = Color3.fromRGB(94, 72, 52)
    Lighting.ColorShift_Top    = Color3.fromRGB(255, 178, 88)
    Lighting.ColorShift_Bottom = Color3.fromRGB(64, 44, 36)
    local atmo = Lighting:FindFirstChild("Atmosphere") or Instance.new("Atmosphere")
    atmo.Name="Atmosphere" atmo.Density=0.55 atmo.Color=Color3.fromRGB(172,122,72)
    atmo.Decay=Color3.fromRGB(68,44,32) atmo.Glare=0.3 atmo.Haze=3.2 atmo.Parent=Lighting
    local bloom = Lighting:FindFirstChild("Bloom") or Instance.new("BloomEffect")
    bloom.Name="Bloom" bloom.Intensity=0.35 bloom.Size=26 bloom.Threshold=1.0 bloom.Parent=Lighting
    local cc = Lighting:FindFirstChild("ColorCorrection") or Instance.new("ColorCorrectionEffect")
    cc.Name="ColorCorrection" cc.Brightness=-0.05 cc.Contrast=0.25 cc.Saturation=0.10
    cc.TintColor=Color3.fromRGB(255,215,168) cc.Parent=Lighting
end

function WorldService:createSpawnPlatform()
    if Workspace:FindFirstChild("SpawnPlatform") then return end
    local cfg = ctx.Config.World
    local ground = Instance.new("Part")
    ground.Name="SpawnPlatform" ground.Anchored=true
    ground.Size=Vector3.new(cfg.HalfSize*2.2, 4, cfg.HalfSize*2.2)
    ground.CFrame=CFrame.new(0,-2,0) ground.Color=Color3.fromRGB(52,44,36)
    ground.Material=Enum.Material.Slate ground.Parent=Workspace
    local spawn = Instance.new("SpawnLocation")
    spawn.Name="SurvivalSpawn" spawn.Anchored=true spawn.Size=Vector3.new(10,1,10)
    spawn.CFrame=CFrame.new(cfg.SpawnPoint.X,1,cfg.SpawnPoint.Z)
    spawn.Color=Color3.fromRGB(88,72,52) spawn.Material=Enum.Material.Cobblestone
    spawn.Parent=Workspace
end

function WorldService:tick(dt)
    local cfg = ctx.Config.World
    dayTimer = dayTimer + dt
    Lighting.ClockTime = ((dayTimer % cfg.DayLengthSecs) / cfg.DayLengthSecs) * 24
    if dayTimer >= cfg.DayLengthSecs then
        dayTimer = dayTimer - cfg.DayLengthSecs
        day = day + 1
    end
end

function WorldService:getDay()   return day end
function WorldService:isNight()
    local cfg = ctx.Config.World
    local t   = Lighting.ClockTime
    return t >= cfg.NightStartClock or t < cfg.NightEndClock
end

return WorldService
