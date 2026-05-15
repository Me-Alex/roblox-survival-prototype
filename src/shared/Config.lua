-- Config.lua  (Milestone 2)
local Config = {}

Config.World = {
    HalfSize       = 512,
    Seed           = 42,
    DayLengthSecs  = 480,
    NightStartClock= 20,
    NightEndClock  = 6,
}

Config.Vitals = {
    MaxHealth      = 100,
    MaxHunger      = 100,
    MaxThirst      = 100,
    MaxTemperature = 100,

    HungerDecayRate     = 0.8,
    ThirstDecayRate     = 1.2,
    TempDecayRateDay    = 0.3,
    TempDecayRateNight  = 1.4,

    StarveDamage        = 2,
    DehydrateDamage     = 3,
    HypothermiaDamage   = 2,

    CampfireWarmRadius  = 20,
    CampfireWarmRate    = 8,

    FoodRestore = {
        RawBerries    = { hunger=12, thirst=4  },
        RawMeat       = { hunger=18, thirst=-2 },
        CookedMeat    = { hunger=35, thirst=5  },
        AshBread      = { hunger=28, thirst=2  },
        MushroomStew  = { hunger=40, thirst=10 },
    },
}

Config.Resources = {
    TreeCount   = 60,
    RockCount   = 50,
    BushCount   = 40,
    FiberCount  = 35,
    MinSpacing  = 22,
    RespawnTime = 180,
    Hits = {
        Tree  = 3,
        Rock  = 4,
        Bush  = 1,
        Fiber = 1,
    },
    Drops = {
        Tree  = { item="AshWood",    min=2, max=5 },
        Rock  = { item="Stone",      min=3, max=6 },
        Bush  = { item="RawBerries", min=2, max=4 },
        Fiber = { item="Fiber",      min=3, max=6 },
    },
}

Config.Items = {
    AshWood      = { displayName="Ash Wood",     stackSize=20, category="resource" },
    Stone        = { displayName="Stone",         stackSize=30, category="resource" },
    Fiber        = { displayName="Fiber",         stackSize=30, category="resource" },
    RawBerries   = { displayName="Raw Berries",   stackSize=10, category="food"     },
    RawMeat      = { displayName="Raw Meat",      stackSize=5,  category="food"     },
    IronOre      = { displayName="Iron Ore",      stackSize=15, category="resource" },
    StoneAxe     = { displayName="Stone Axe",     stackSize=1,  category="tool",    durability=40 },
    StoneSpear   = { displayName="Stone Spear",   stackSize=1,  category="weapon",  durability=30 },
    Torch        = { displayName="Torch",          stackSize=3,  category="tool"    },
    CampfireKit  = { displayName="Campfire Kit",  stackSize=2,  category="placeable" },
    ShelterKit   = { displayName="Shelter Kit",   stackSize=1,  category="placeable" },
    CookedMeat   = { displayName="Cooked Meat",   stackSize=5,  category="food"    },
    AshBread     = { displayName="Ash Bread",     stackSize=5,  category="food"    },
    MushroomStew = { displayName="Mushroom Stew", stackSize=3,  category="food"    },
    AshMushroom  = { displayName="Ash Mushroom",  stackSize=10, category="food"    },
}

Config.Recipes = {
    { id="StoneAxe",    requires={AshWood=2,Stone=3},         gives={item="StoneAxe",   amount=1}, category="Tools"   },
    { id="StoneSpear",  requires={AshWood=3,Stone=2,Fiber=2}, gives={item="StoneSpear", amount=1}, category="Weapons" },
    { id="Torch",       requires={AshWood=1,Fiber=1},         gives={item="Torch",      amount=2}, category="Tools"   },
    { id="CampfireKit", requires={AshWood=4,Stone=3},         gives={item="CampfireKit",amount=1}, category="Survival"},
    { id="ShelterKit",  requires={AshWood=8,Fiber=4},         gives={item="ShelterKit", amount=1}, category="Survival"},
    { id="CookedMeat",  requires={RawMeat=1},                 gives={item="CookedMeat", amount=1}, category="Food", nearFire=true },
    { id="AshBread",    requires={AshMushroom=2,Fiber=1},     gives={item="AshBread",   amount=1}, category="Food", nearFire=true },
}

Config.Combat = {
    FistDamage     = 8,
    AxeDamage      = 22,
    SpearDamage    = 18,
    AttackCooldown = 0.6,
    NightStalker = {
        Health=60, Damage=12, Speed=14, AggroRadius=40,
        SpawnRadius=200, MaxCount=6,
        Drops={ { item="RawMeat", min=1, max=2 } },
    },
}

Config.Inventory = { SlotCount = 20 }

Config.Progression = {
    XpPerLevel=200, MaxLevel=30,
    HarvestXp=10, CraftXp=20, KillXp=30, SurviveDayXp=50,
}

return Config
