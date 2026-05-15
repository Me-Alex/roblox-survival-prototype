-- Config.lua
-- ALL game numbers live here. Change values here, not inside service files.
-- This makes balancing the game easy without digging through code.

local Config = {}

-- ── World ────────────────────────────────────────────────────────────────
Config.World = {
    Seed            = 42,
    HalfSize        = 512,
    SpawnPoint      = Vector3.new(0, 2, 0),
    RespawnHeight   = 2,
    DayLengthSecs   = 480,
    NightStartClock = 19,
    NightEndClock   = 6,
}

-- ── Vitals ───────────────────────────────────────────────────────────────
Config.Vitals = {
    MaxHealth       = 100,
    MaxHunger       = 100,
    MaxThirst       = 100,
    MaxTemperature  = 100,
    HungerDrainRate    = 0.03,
    ThirstDrainRate    = 0.045,
    TemperatureNeutral = 50,
    TemperatureRate    = 0.02,
    HungerDamageThreshold    = 0,
    ThirstDamageThreshold    = 0,
    TempFreezeDamageThreshold = 10,
    TempHeatDamageThreshold  = 90,
    StarveDamagePerSec  = 1,
    DehydrateDamagePerSec = 2,
    FreezeDamagePerSec  = 1.5,
    HeatDamagePerSec    = 1.5,
    CampfireWarmRate       = 8,
    CampfireWarmRadius     = 18,
}

-- ── Resources ────────────────────────────────────────────────────────────
Config.Resources = {
    TreeCount    = 60,
    RockCount    = 40,
    BushCount    = 30,
    FiberCount   = 35,
    MinSpacing   = 12,
    RespawnTime  = 90,
    Drops = {
        Tree    = { item = "Wood",   min = 2, max = 4 },
        Rock    = { item = "Stone",  min = 1, max = 3 },
        Bush    = { item = "Berry",  min = 1, max = 3 },
        Fiber   = { item = "Fiber",  min = 2, max = 4 },
    },
    Hits = {
        Tree    = 3,
        Rock    = 3,
        Bush    = 1,
        Fiber   = 1,
    },
}

-- ── Inventory ────────────────────────────────────────────────────────────
Config.Inventory = {
    MaxSlots  = 20,
    HotbarSlots = 6,
}

-- ── Items ─────────────────────────────────────────────────────────────────
Config.Items = {
    Wood        = { displayName = "Wood",        type = "resource", stackSize = 99 },
    Stone       = { displayName = "Stone",       type = "resource", stackSize = 99 },
    Fiber       = { displayName = "Fiber",       type = "resource", stackSize = 99 },
    Berry       = { displayName = "Berry",       type = "food",     stackSize = 20 },
    Hide        = { displayName = "Hide",        type = "resource", stackSize = 30 },
    Fur         = { displayName = "Fur",         type = "resource", stackSize = 30 },
    Antler      = { displayName = "Antler",      type = "resource", stackSize = 10 },
    IronOre     = { displayName = "Iron Ore",    type = "resource", stackSize = 30 },
    IronIngot   = { displayName = "Iron Ingot",  type = "resource", stackSize = 20 },
    Coal        = { displayName = "Coal",        type = "resource", stackSize = 30 },
    CookedMeat  = { displayName = "Cooked Meat", type = "food",  stackSize = 10, hunger = 35, thirst = -5 },
    CookedBerry = { displayName = "Cooked Berry",type = "food",  stackSize = 10, hunger = 12, thirst = 5 },
    MushroomStew= { displayName = "Mushroom Stew",type="food",  stackSize = 5,  hunger = 40, thirst = 15 },
    StoneAxe    = { displayName = "Stone Axe",   type = "tool",   stackSize = 1, toolType = "axe",     durability = 60 },
    StonePickaxe= { displayName = "Stone Pickaxe",type="tool",   stackSize = 1, toolType = "pickaxe", durability = 60 },
    IronAxe     = { displayName = "Iron Axe",    type = "tool",   stackSize = 1, toolType = "axe",     durability = 120 },
    IronPickaxe = { displayName = "Iron Pickaxe",type = "tool",   stackSize = 1, toolType = "pickaxe", durability = 120 },
    Torch       = { displayName = "Torch",       type = "tool",   stackSize = 5, toolType = "torch" },
    Spear       = { displayName = "Spear",       type = "weapon", stackSize = 1, damage = 22, durability = 80 },
    IronSpear   = { displayName = "Iron Spear",  type = "weapon", stackSize = 1, damage = 38, durability = 150 },
    Knife       = { displayName = "Knife",       type = "weapon", stackSize = 1, damage = 14, durability = 60 },
    HideArmor   = { displayName = "Hide Armor",  type = "armor",  stackSize = 1, defence = 0.70, durability = 100 },
    FurVest     = { displayName = "Fur Vest",    type = "armor",  stackSize = 1, defence = 0.85, durability = 75, warmBonus = 15 },
    CampfireKit = { displayName = "Campfire Kit",    type = "structure", stackSize = 5 },
    ShelterKit  = { displayName = "Shelter Kit",     type = "structure", stackSize = 3 },
    StorageKit  = { displayName = "Storage Chest Kit",type="structure",  stackSize = 3 },
    Bandage     = { displayName = "Bandage",         type = "tool",  stackSize = 10, healAmount = 25 },
}

-- ── Crafting Recipes ──────────────────────────────────────────────────────
Config.Recipes = {
    { id="StoneAxe",     displayName="Stone Axe",     result="StoneAxe",    resultAmount=1, cost={Wood=3,Stone=2},           category="Tools" },
    { id="StonePickaxe", displayName="Stone Pickaxe", result="StonePickaxe",resultAmount=1, cost={Wood=3,Stone=3},           category="Tools" },
    { id="Spear",        displayName="Spear",         result="Spear",       resultAmount=1, cost={Wood=4,Stone=1,Fiber=2},  category="Weapons" },
    { id="Torch",        displayName="Torch",         result="Torch",       resultAmount=2, cost={Wood=1,Fiber=1},          category="Tools" },
    { id="Bandage",      displayName="Bandage",       result="Bandage",     resultAmount=2, cost={Fiber=4},                 category="Medicine" },
    { id="FurVest",      displayName="Fur Vest",      result="FurVest",     resultAmount=1, cost={Fur=6,Fiber=3},           category="Armor" },
    { id="HideArmor",    displayName="Hide Armor",    result="HideArmor",   resultAmount=1, cost={Hide=4,Fiber=4},          category="Armor" },
    { id="CampfireKit",  displayName="Campfire Kit",  result="CampfireKit", resultAmount=1, cost={Wood=4,Stone=2},          category="Survival" },
    { id="ShelterKit",   displayName="Shelter Kit",   result="ShelterKit",  resultAmount=1, cost={Wood=8,Fiber=4},          category="Survival" },
    { id="StorageKit",   displayName="Storage Chest Kit",result="StorageKit",resultAmount=1,cost={Wood=6,Stone=2},          category="Survival" },
    { id="IronAxe",      displayName="Iron Axe",      result="IronAxe",     resultAmount=1, cost={IronIngot=3,Wood=2},      category="Tools",   requiresForge=true },
    { id="IronPickaxe",  displayName="Iron Pickaxe",  result="IronPickaxe", resultAmount=1, cost={IronIngot=3,Wood=2},      category="Tools",   requiresForge=true },
    { id="IronSpear",    displayName="Iron Spear",    result="IronSpear",   resultAmount=1, cost={IronIngot=4,Wood=2,Fiber=2},category="Weapons",requiresForge=true },
}

-- ── Enemies ──────────────────────────────────────────────────────────────
Config.Enemies = {
    NightStalker = {
        displayName="Night Stalker", health=60, damage=10, speed=14,
        detectionRange=40, attackRange=5, attackCooldown=1.8,
        drops={{ item="Hide", min=1, max=2 }},
    },
    AshWolf = {
        displayName="Ash Wolf", health=80, damage=15, speed=18,
        detectionRange=55, attackRange=4, attackCooldown=1.4,
        drops={{ item="Fur", min=1, max=3 },{ item="Hide", min=0, max=1 }},
    },
}

-- ── Regions ───────────────────────────────────────────────────────────────
Config.Regions = {
    { id="CinderHarbour",   displayName="Cinder Harbour",      center=Vector3.new(0,0,0),      radius=140, danger=1, description="A burnt survivor landing beach." },
    { id="AshwoodHollow",   displayName="Ashwood Hollow",      center=Vector3.new(-290,0,-290), radius=120, danger=2, description="Dead ash forest.",          enemyTypes={"AshWolf"} },
    { id="SaltcragShores",  displayName="Saltcrag Shores",     center=Vector3.new(300,0,-280),  radius=120, danger=2, description="Jagged sea cliffs.",        enemyTypes={"NightStalker"} },
    { id="ScorchPitQuarry", displayName="Scorch Pit Quarry",   center=Vector3.new(-340,0,290),  radius=115, danger=3, description="Lava fissure mine.",       enemyTypes={"NightStalker","AshWolf"} },
    { id="BrimstoneMarsh",  displayName="Brimstone Marsh",     center=Vector3.new(340,0,310),   radius=115, danger=3, description="Toxic sulfur swamp.",     enemyTypes={"NightStalker"} },
    { id="DeadMansCaldera", displayName="Dead Man's Caldera",   center=Vector3.new(0,0,-500),    radius=110, danger=5, description="Open volcano crater.",    enemyTypes={"NightStalker","AshWolf"} },
    { id="MoltenSpireHold", displayName="Molten Spire Hold",   center=Vector3.new(0,0,480),     radius=110, danger=4, description="Survivor fortress.",      enemyTypes={"NightStalker"} },
}

return Config
