-- Config.lua  (Milestone 6a — added Bedroll item + recipe)
local Config = {}

-- ── Vitals ───────────────────────────────────────────────────────────────
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

-- ── World ────────────────────────────────────────────────────────────────
Config.World = {
    Seed           = 42,
    HalfSize       = 600,
    DayLengthSecs  = 480,   -- 8 real minutes = 1 in-game day
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
    Hits = { Tree=3, Rock=4, Bush=1, Fiber=1 },
}

-- ── Combat ───────────────────────────────────────────────────────────────
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
            { item = "RawMeat", min = 1, max = 3 },
            { item = "Hide",    min = 1, max = 2 },
        },
    },
}

-- ── Progression ──────────────────────────────────────────────────────────
Config.Progression = {
    KillXp    = 25,
    CraftXp   = 10,
    HarvestXp = 5,
    LevelsXp  = { 0, 100, 250, 500, 900, 1400, 2000, 2800, 3800, 5000 },
}

-- ── Items ────────────────────────────────────────────────────────────────
Config.Items = {
    AshWood     = { displayName="Ash Wood",     category="resource", stackable=true },
    Stone       = { displayName="Stone",         category="resource", stackable=true },
    Fiber       = { displayName="Fiber",         category="resource", stackable=true },
    Flint       = { displayName="Flint",         category="resource", stackable=true },
    IronOre     = { displayName="Iron Ore",      category="resource", stackable=true },
    RopeFiber   = { displayName="Rope Fiber",    category="resource", stackable=true },
    OldCloth    = { displayName="Old Cloth",     category="resource", stackable=true },
    Hide        = { displayName="Hide",          category="resource", stackable=true },
    Bandage     = { displayName="Bandage",        category="tool",     stackable=true,
                    onUse="curesBleeding" },
    RawMeat     = { displayName="Raw Meat",       category="food",     stackable=true,
                    food={ hungerRestore=20, thirstRestore=0 } },
    CookedMeat  = { displayName="Cooked Meat",    category="food",     stackable=true,
                    food={ hungerRestore=45, thirstRestore=5 } },
    RawBerries  = { displayName="Raw Berries",    category="food",     stackable=true,
                    food={ hungerRestore=8,  thirstRestore=4 } },
    Mushroom    = { displayName="Mushroom",       category="food",     stackable=true,
                    food={ hungerRestore=12, thirstRestore=2 } },
    StoneAxe    = { displayName="Stone Axe",      category="weapon",   stackable=false },
    StoneSpear  = { displayName="Stone Spear",    category="weapon",   stackable=false },
    Campfire    = { displayName="Campfire",       category="structure",stackable=false },
    WoodWall    = { displayName="Wood Wall",      category="structure",stackable=false },
    WoodFloor   = { displayName="Wood Floor",     category="structure",stackable=false },
    LeatherArmor= { displayName="Leather Armor",  category="armor",    stackable=false },

    -- NEW: Bedroll
    Bedroll     = {
        displayName = "Bedroll",
        category    = "structure",
        stackable   = false,
        -- Placing this item spawns a bedroll model in the world.
        -- The sleep interaction is handled by SleepService (Milestone 6b).
        placeable   = true,
    },
}

-- ── Crafting recipes ─────────────────────────────────────────────────────
Config.Recipes = {
    StoneAxe    = { category="Tools",    ingredients={ AshWood=2, Stone=3 },            result="StoneAxe",    amount=1 },
    StoneSpear  = { category="Weapons",  ingredients={ AshWood=3, Flint=2 },            result="StoneSpear",  amount=1 },
    Campfire    = { category="Survival", ingredients={ AshWood=5, Stone=4 },            result="Campfire",    amount=1 },
    Bandage     = { category="Survival", ingredients={ Fiber=4,   OldCloth=2 },         result="Bandage",     amount=2 },
    CookedMeat  = { category="Food",     ingredients={ RawMeat=1 },                     result="CookedMeat",  amount=1, nearFire=true },
    WoodWall    = { category="Building", ingredients={ AshWood=6, RopeFiber=2 },        result="WoodWall",    amount=1 },
    WoodFloor   = { category="Building", ingredients={ AshWood=4, RopeFiber=1 },        result="WoodFloor",   amount=1 },
    LeatherArmor= { category="Armor",    ingredients={ Hide=6,    RopeFiber=3 },        result="LeatherArmor",amount=1 },

    -- NEW: Bedroll recipe  (Survival tab, no fire needed)
    Bedroll     = { category="Survival", ingredients={ Fiber=3, Hide=2, OldCloth=1 },   result="Bedroll",     amount=1 },
}

return Config
