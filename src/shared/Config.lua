-- Config.lua  (Milestone 9 — water items + boiling recipe)
local Config = {}

-- ── Vitals ────────────────────────────────────────────────────────────────
Config.Vitals = {
    MaxHealth        = 100,
    MaxHunger        = 100,
    MaxThirst        = 100,
    MaxTemperature   = 100,
    MaxStamina       = 100,

    HungerDecayRate  = 1,
    ThirstDecayRate  = 1.5,
    NightTempDrain   = 1,
    RainTempDrain    = 2,

    StarveDamage     = 2,
    DehydrateDamage  = 3,
    FreezeDamage     = 2,
    BleedDamage      = 4,
    PoisonDamage     = 3,
    HealthRegen      = 0.5,

    CampfireWarmRadius = 18,
    CampfireWarmRate   = 4,
}

-- ── Status thresholds ────────────────────────────────────────────────────
Config.StatusThresholds = {
    FreezingTemp      = 20,
    ExhaustedStamina  = 15,
    RestedStamina     = 80,
    StarvingHunger    = 15,
    DehydratedThirst  = 15,
}

-- ── World ─────────────────────────────────────────────────────────────────
Config.World = {
    Seed           = 42,
    HalfSize       = 600,
    DayLengthSecs  = 480,
    NightStartClock= 19,
    NightEndClock  = 6,
}

-- ── Resources ────────────────────────────────────────────────────────────
Config.Resources = {
    TreeCount  = 60,
    RockCount  = 40,
    BushCount  = 30,
    FiberCount = 30,
    MinSpacing = 18,
    RespawnTime = 120,
    Hits = { Tree=3, Rock=4, Bush=1, Fiber=1 },
    Drops = {
        Tree = { item="AshWood", min=2, max=4 },
        Rock = { item="Stone", min=2, max=4 },
        Bush = { item="RawBerries", min=1, max=3 },
        Fiber = { item="Fiber", min=2, max=5 },
    },
}

-- ── Combat ────────────────────────────────────────────────────────────────
Config.Combat = {
    FistDamage     = 5,
    AxeDamage      = 18,
    SpearDamage    = 28,
    AttackCooldown = 0.6,

    NightStalker = {
        Health      = 60,
        Damage      = 12,
        Speed       = 10,
        AggroRadius = 60,
        SpawnRadius = 220,
        MaxCount    = 6,
        Drops = {
            { item="RawMeat", min=1, max=3 },
            { item="Hide",    min=1, max=2 },
        },
    },
}

-- ── Wildlife ──────────────────────────────────────────────────────────────
Config.Wildlife = {
    Rabbit = {
        Count=12, Health=15, WanderSpeed=4, FleeSpeed=18,
        FleeRadius=20, RespawnTime=60, KillXp=10,
        Drops = { { item="RawMeat", min=1, max=2 } },
    },
    Deer = {
        Count=6, Health=40, WanderSpeed=5, FleeSpeed=22,
        FleeRadius=30, RespawnTime=120, KillXp=20,
        Drops = {
            { item="RawMeat", min=2, max=4 },
            { item="Hide",    min=1, max=2 },
        },
    },
}

-- ── Progression ───────────────────────────────────────────────────────────
Config.Progression = {
    KillXp    = 25,
    CraftXp   = 10,
    HarvestXp = 5,
    LevelsXp  = { 0, 100, 250, 500, 900, 1400, 2000, 2800, 3800, 5000 },
}

-- ── Items ─────────────────────────────────────────────────────────────────
Config.Items = {
    -- Resources
    AshWood      = { displayName="Ash Wood",       category="resource", stackable=true },
    Stone        = { displayName="Stone",           category="resource", stackable=true },
    Fiber        = { displayName="Fiber",           category="resource", stackable=true },
    Flint        = { displayName="Flint",           category="resource", stackable=true },
    IronOre      = { displayName="Iron Ore",        category="resource", stackable=true },
    RopeFiber    = { displayName="Rope Fiber",      category="resource", stackable=true },
    OldCloth     = { displayName="Old Cloth",       category="resource", stackable=true },
    Hide         = { displayName="Hide",            category="resource", stackable=true },

    -- Water
    DirtyWater   = { displayName="Dirty Water",     category="food",    stackable=true,
                     food={ hungerRestore=0, thirstRestore=25, poisonOnDrink=true } },
    CleanWater   = { displayName="Clean Water",     category="food",    stackable=true,
                     food={ hungerRestore=0, thirstRestore=60 } },

    -- Food (campfire tier)
    RawMeat      = { displayName="Raw Meat",        category="food",    stackable=true,
                     food={ hungerRestore=20, thirstRestore=0 } },
    CookedMeat   = { displayName="Cooked Meat",     category="food",    stackable=true,
                     food={ hungerRestore=45, thirstRestore=5 } },
    RawBerries   = { displayName="Raw Berries",     category="food",    stackable=true,
                     food={ hungerRestore=8,  thirstRestore=4 } },
    Mushroom     = { displayName="Mushroom",        category="food",    stackable=true,
                     food={ hungerRestore=12, thirstRestore=2 } },

    -- Food (oven tier)
    MeatStew     = { displayName="Meat Stew",       category="food",    stackable=true,
                     food={ hungerRestore=70, thirstRestore=20 } },
    MushroomSoup = { displayName="Mushroom Soup",   category="food",    stackable=true,
                     food={ hungerRestore=50, thirstRestore=35 } },
    DriedMeat    = { displayName="Dried Meat",      category="food",    stackable=true,
                     food={ hungerRestore=55, thirstRestore=0 } },

    -- Tools & weapons
    Bandage      = { displayName="Bandage",         category="tool",    stackable=true,  onUse="curesBleeding" },
    StoneAxe     = { displayName="Stone Axe",       category="weapon",  stackable=false },
    StoneSpear   = { displayName="Stone Spear",     category="weapon",  stackable=false },

    -- Structures
    Campfire     = { displayName="Campfire",        category="structure", stackable=false },
    WoodWall     = { displayName="Wood Wall",       category="structure", stackable=false },
    WoodFloor    = { displayName="Wood Floor",      category="structure", stackable=false },
    Bedroll      = { displayName="Bedroll",         category="structure", stackable=false, placeable=true },
    StoneOven    = { displayName="Stone Oven",      category="structure", stackable=false, placeable=true },

    -- Armor
    LeatherArmor = { displayName="Leather Armor",   category="armor",     stackable=false },
}

-- ── Crafting recipes ──────────────────────────────────────────────────────
Config.Recipes = {
    -- Tools & Weapons
    StoneAxe     = { category="Tools",    result="StoneAxe",    amount=1,
                     ingredients={ AshWood=2, Stone=3 } },
    StoneSpear   = { category="Weapons",  result="StoneSpear",  amount=1,
                     ingredients={ AshWood=3, Flint=2 } },

    -- Survival
    Campfire     = { category="Survival", result="Campfire",    amount=1,
                     ingredients={ AshWood=5, Stone=4 } },
    Bandage      = { category="Survival", result="Bandage",     amount=2,
                     ingredients={ Fiber=4, OldCloth=2 } },
    Bedroll      = { category="Survival", result="Bedroll",     amount=1,
                     ingredients={ Fiber=3, Hide=2, OldCloth=1 } },

    -- Building
    WoodWall     = { category="Building", result="WoodWall",    amount=1,
                     ingredients={ AshWood=6, RopeFiber=2 } },
    WoodFloor    = { category="Building", result="WoodFloor",   amount=1,
                     ingredients={ AshWood=4, RopeFiber=1 } },
    StoneOven    = { category="Building", result="StoneOven",   amount=1,
                     ingredients={ Stone=8, IronOre=3, AshWood=4 } },

    -- Armor
    LeatherArmor = { category="Armor",    result="LeatherArmor",amount=1,
                     ingredients={ Hide=6, RopeFiber=3 } },

    -- Food — Campfire tier
    CookedMeat   = { category="Food",     result="CookedMeat",  amount=1,
                     nearFire=true, nearOven=true,
                     ingredients={ RawMeat=1 } },

    -- Water — boil DirtyWater at campfire or oven → CleanWater
    CleanWater   = { category="Food",     result="CleanWater",  amount=1,
                     nearFire=true, nearOven=true,
                     ingredients={ DirtyWater=1 } },

    -- Food — Oven tier
    MeatStew     = { category="Food",     result="MeatStew",    amount=1,
                     nearOven=true,
                     ingredients={ RawMeat=2, Mushroom=1, RawBerries=1 } },
    MushroomSoup = { category="Food",     result="MushroomSoup",amount=2,
                     nearOven=true,
                     ingredients={ Mushroom=3, RawBerries=1 } },
    DriedMeat    = { category="Food",     result="DriedMeat",   amount=2,
                     nearOven=true,
                     ingredients={ RawMeat=3, Stone=1 } },
}

return Config
