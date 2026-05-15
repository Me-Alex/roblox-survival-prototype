-- Config.lua  (Milestone 5 — added StatusThresholds + NightStalker block)
-- Central config for the whole game. All numbers live here so you can
-- tweak difficulty without hunting through service files.

local Config = {}

-- ── Vitals ─────────────────────────────────────────────────────────────────
Config.Vitals = {
    MaxHealth        = 100,
    MaxHunger        = 100,
    MaxThirst        = 100,
    MaxTemperature   = 100,
    MaxStamina       = 100,

    HungerDecayRate  = 1,     -- per second
    ThirstDecayRate  = 1.5,
    NightTempDrain   = 1,
    RainTempDrain    = 2,

    StarveDamage     = 2,     -- hp/s when hunger = 0
    DehydrateDamage  = 3,
    FreezeDamage     = 2,
    BleedDamage      = 4,
    PoisonDamage     = 3,
    HealthRegen      = 0.5,   -- hp/s when comfortable
}

-- ── Status thresholds ──────────────────────────────────────────────────────
-- These drive both the HUD badges and the damage tick logic.
Config.StatusThresholds = {
    FreezingTemp      = 20,   -- below this → Freezing badge + damage
    ExhaustedStamina  = 15,   -- below this → Exhausted badge
    RestedStamina     = 80,   -- above this (daytime) → Rested badge
    StarvingHunger    = 15,   -- below this → Starving badge + damage
    DehydratedThirst  = 15,   -- below this → Dehydrated badge + damage
}

-- ── Combat ─────────────────────────────────────────────────────────────────
Config.Combat = {
    FistDamage     = 5,
    AxeDamage      = 18,
    SpearDamage    = 28,
    AttackCooldown = 0.6,   -- seconds between swings

    NightStalker = {
        Health      = 60,
        Damage      = 12,
        Speed       = 10,
        AggroRadius = 60,
        SpawnRadius = 220,   -- studs from map centre
        MaxCount    = 6,
        Drops = {
            { item = "RawMeat", min = 1, max = 3 },
            { item = "Hide",    min = 1, max = 2 },
        },
    },
}

-- ── Progression ────────────────────────────────────────────────────────────
Config.Progression = {
    KillXp       = 25,
    CraftXp      = 10,
    HarvestXp    = 5,
    LevelsXp     = { 0, 100, 250, 500, 900, 1400, 2000, 2800, 3800, 5000 },
}

-- ── Resources ──────────────────────────────────────────────────────────────
Config.Resources = {
    Tree   = { item="AshWood",  min=2, max=4, respawn=30 },
    Rock   = { item="Stone",    min=3, max=6, respawn=45 },
    Fiber  = { item="Fiber",    min=2, max=5, respawn=20 },
    Berry  = { item="RawBerries",min=2,max=5, respawn=25 },
    Iron   = { item="IronOre",  min=1, max=3, respawn=90 },
    Mushroom={item="Mushroom",  min=1, max=3, respawn=35 },
    Cache  = { lootTable={"RopeFiber","Flint","Bandage","OldCloth"}, respawn=120 },
}

-- ── Items ──────────────────────────────────────────────────────────────────
Config.Items = {
    AshWood    = { displayName="Ash Wood",    category="resource", stackable=true },
    Stone      = { displayName="Stone",        category="resource", stackable=true },
    Fiber      = { displayName="Fiber",        category="resource", stackable=true },
    Flint      = { displayName="Flint",        category="resource", stackable=true },
    IronOre    = { displayName="Iron Ore",     category="resource", stackable=true },
    RopeFiber  = { displayName="Rope Fiber",   category="resource", stackable=true },
    OldCloth   = { displayName="Old Cloth",    category="resource", stackable=true },
    Hide       = { displayName="Hide",         category="resource", stackable=true },
    Bandage    = { displayName="Bandage",       category="tool",     stackable=true,
                   onUse = "curesBleeding" },
    RawMeat    = { displayName="Raw Meat",      category="food",     stackable=true,
                   food = { hungerRestore=20, thirstRestore=0  } },
    CookedMeat = { displayName="Cooked Meat",   category="food",     stackable=true,
                   food = { hungerRestore=45, thirstRestore=5  } },
    RawBerries = { displayName="Raw Berries",   category="food",     stackable=true,
                   food = { hungerRestore=8,  thirstRestore=4  } },
    Mushroom   = { displayName="Mushroom",      category="food",     stackable=true,
                   food = { hungerRestore=12, thirstRestore=2  } },
    StoneAxe   = { displayName="Stone Axe",     category="weapon",   stackable=false },
    StoneSpear = { displayName="Stone Spear",   category="weapon",   stackable=false },
    Campfire   = { displayName="Campfire",      category="structure",stackable=false },
    WoodWall   = { displayName="Wood Wall",     category="structure",stackable=false },
    WoodFloor  = { displayName="Wood Floor",    category="structure",stackable=false },
    LeatherArmor={ displayName="Leather Armor",category="armor",    stackable=false },
}

-- ── Crafting recipes ───────────────────────────────────────────────────────
Config.Recipes = {
    StoneAxe   = { category="Tools",    ingredients={ AshWood=2, Stone=3 },      result="StoneAxe",    amount=1 },
    StoneSpear = { category="Weapons",  ingredients={ AshWood=3, Flint=2 },      result="StoneSpear",  amount=1 },
    Campfire   = { category="Survival", ingredients={ AshWood=5, Stone=4 },      result="Campfire",    amount=1, nearFire=false },
    Bandage    = { category="Survival", ingredients={ Fiber=4,   OldCloth=2 },   result="Bandage",     amount=2 },
    CookedMeat = { category="Food",     ingredients={ RawMeat=1 },               result="CookedMeat",  amount=1, nearFire=true  },
    WoodWall   = { category="Building", ingredients={ AshWood=6, RopeFiber=2 },  result="WoodWall",    amount=1 },
    WoodFloor  = { category="Building", ingredients={ AshWood=4, RopeFiber=1 },  result="WoodFloor",   amount=1 },
    LeatherArmor={ category="Armor",    ingredients={ Hide=6,    RopeFiber=3 },  result="LeatherArmor",amount=1 },
}

return Config
