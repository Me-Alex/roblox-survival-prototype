local SurvivalConfig = {}

SurvivalConfig.World = {
	Seed = 1349,
	SpawnAreaHalfSize = 145,
	RespawnHeight = 8,
	DayLengthSeconds = 480,
	NightStart = 18.5,
	NightEnd = 6,
	WeatherIntervalSeconds = 80,
}

SurvivalConfig.Vitals = {
	Max = 100,
	TickSeconds = 2,
	HungerLoss = 0.55,
	ThirstLoss = 0.8,
	TemperatureDrift = 0.12,
	StarvingDamage = 3,
	DehydratedDamage = 5,
	ColdDamage = 4,
	HeatDamage = 3,
	ColdThreshold = 35,
	HotThreshold = 95,
	ComfortLow = 58,
	ComfortHigh = 82,
}

SurvivalConfig.Items = {
	Wood = { DisplayName = "Wood", Category = "Resource" },
	Stone = { DisplayName = "Stone", Category = "Resource" },
	Fiber = { DisplayName = "Fiber", Category = "Resource" },
	Hide = { DisplayName = "Hide", Category = "Resource" },
	RawMeat = { DisplayName = "Raw Meat", Category = "Food" },
	Berries = { DisplayName = "Berries", Category = "Food" },
	CookedBerries = { DisplayName = "Cooked Berries", Category = "Food" },
	CookedMeat = { DisplayName = "Cooked Meat", Category = "Food" },
	Bandage = { DisplayName = "Bandage", Category = "Medical" },
	SurvivalTonic = { DisplayName = "Survival Tonic", Category = "Medical" },
	StoneAxe = { DisplayName = "Stone Axe", Category = "Tool" },
	Spear = { DisplayName = "Spear", Category = "Weapon" },
	HideArmor = { DisplayName = "Hide Armor", Category = "Armor" },
	CampfireKit = { DisplayName = "Campfire Kit", Category = "Buildable" },
	ShelterKit = { DisplayName = "Shelter Kit", Category = "Buildable" },
	RainCollectorKit = { DisplayName = "Rain Collector Kit", Category = "Buildable" },
}

SurvivalConfig.Resources = {
	Tree = {
		DisplayName = "Tree",
		Reward = "Wood",
		MinAmount = 2,
		MaxAmount = 5,
		SpawnCount = 28,
		RespawnSeconds = 55,
		HarvestText = "Chop",
	},
	Rock = {
		DisplayName = "Rock",
		Reward = "Stone",
		MinAmount = 1,
		MaxAmount = 4,
		SpawnCount = 22,
		RespawnSeconds = 65,
		HarvestText = "Mine",
	},
	FiberPlant = {
		DisplayName = "Fiber Plant",
		Reward = "Fiber",
		MinAmount = 2,
		MaxAmount = 4,
		SpawnCount = 20,
		RespawnSeconds = 45,
		HarvestText = "Gather",
	},
	BerryBush = {
		DisplayName = "Berry Bush",
		Reward = "Berries",
		MinAmount = 2,
		MaxAmount = 5,
		SpawnCount = 18,
		RespawnSeconds = 50,
		HarvestText = "Pick",
	},
	WaterSpring = {
		DisplayName = "Water Spring",
		Thirst = 38,
		MinAmount = 1,
		MaxAmount = 1,
		SpawnCount = 6,
		RespawnSeconds = 14,
		HarvestText = "Drink",
	},
}

SurvivalConfig.Crafting = {
	StoneAxe = {
		DisplayName = "Stone Axe",
		Cost = { Wood = 2, Stone = 3, Fiber = 1 },
		Result = "StoneAxe",
		Amount = 1,
		Description = "Improves wood and fiber harvesting.",
	},
	Spear = {
		DisplayName = "Spear",
		Cost = { Wood = 3, Stone = 2, Fiber = 2 },
		Result = "Spear",
		Amount = 1,
		Description = "A longer reach weapon for night stalkers.",
	},
	HideArmor = {
		DisplayName = "Hide Armor",
		Cost = { Hide = 4, Fiber = 4 },
		Result = "HideArmor",
		Amount = 1,
		Description = "Reduces damage from enemies.",
	},
	CampfireKit = {
		DisplayName = "Campfire Kit",
		Cost = { Wood = 4, Stone = 2 },
		Result = "CampfireKit",
		Amount = 1,
		Description = "Place to warm nearby players at night.",
	},
	ShelterKit = {
		DisplayName = "Shelter Kit",
		Cost = { Wood = 10, Fiber = 6 },
		Result = "ShelterKit",
		Amount = 1,
		Description = "Place to reduce cold exposure nearby.",
	},
	RainCollectorKit = {
		DisplayName = "Rain Collector Kit",
		Cost = { Wood = 5, Fiber = 4, Stone = 1 },
		Result = "RainCollectorKit",
		Amount = 1,
		Description = "Place to collect emergency drinking water.",
	},
	CookedBerries = {
		DisplayName = "Cooked Berries",
		Cost = { Berries = 3 },
		Result = "CookedBerries",
		Amount = 1,
		RequiresNearby = "Campfire",
		Description = "Restores more hunger and thirst than raw berries.",
	},
	CookedMeat = {
		DisplayName = "Cooked Meat",
		Cost = { RawMeat = 2 },
		Result = "CookedMeat",
		Amount = 1,
		RequiresNearby = "Campfire",
		Description = "A strong meal from defeated night stalkers.",
	},
	Bandage = {
		DisplayName = "Bandage",
		Cost = { Fiber = 4, Berries = 1 },
		Result = "Bandage",
		Amount = 1,
		Description = "Restores health over time.",
	},
	SurvivalTonic = {
		DisplayName = "Survival Tonic",
		Cost = { Berries = 2, Fiber = 2 },
		Result = "SurvivalTonic",
		Amount = 1,
		Description = "Restores thirst, hunger, and a little health.",
	},
}

SurvivalConfig.Consumables = {
	Berries = {
		Hunger = 10,
		Thirst = 5,
		Notify = "You ate berries.",
	},
	CookedBerries = {
		Hunger = 28,
		Thirst = 12,
		Notify = "Warm food steadies you.",
	},
	CookedMeat = {
		Hunger = 44,
		Thirst = -4,
		Notify = "Cooked meat gives you strength.",
	},
	Bandage = {
		Health = 35,
		Notify = "You patched yourself up.",
	},
	SurvivalTonic = {
		Hunger = 14,
		Thirst = 30,
		Health = 18,
		Notify = "The tonic steadies your body.",
	},
}

SurvivalConfig.Buildables = {
	CampfireKit = {
		ModelName = "Campfire",
		DisplayName = "Campfire",
		Radius = 24,
		LifetimeSeconds = 360,
	},
	ShelterKit = {
		ModelName = "Shelter",
		DisplayName = "Shelter",
		Radius = 18,
		LifetimeSeconds = 0,
	},
	RainCollectorKit = {
		ModelName = "RainCollector",
		DisplayName = "Rain Collector",
		Radius = 12,
		LifetimeSeconds = 0,
		DrinkThirst = 26,
	},
}

SurvivalConfig.Weather = {
	Clear = {
		DisplayName = "Clear",
		Weight = 42,
		TemperatureModifier = 0,
		HungerMultiplier = 1,
		ThirstMultiplier = 1,
		EnemyMultiplier = 1,
	},
	Rain = {
		DisplayName = "Rain",
		Weight = 24,
		TemperatureModifier = -8,
		HungerMultiplier = 1.05,
		ThirstMultiplier = 0.75,
		EnemyMultiplier = 0.9,
	},
	ColdFront = {
		DisplayName = "Cold Front",
		Weight = 14,
		TemperatureModifier = -22,
		HungerMultiplier = 1.18,
		ThirstMultiplier = 0.95,
		EnemyMultiplier = 1.15,
	},
	HeatWave = {
		DisplayName = "Heat Wave",
		Weight = 10,
		TemperatureModifier = 18,
		HungerMultiplier = 1,
		ThirstMultiplier = 1.65,
		EnemyMultiplier = 0.8,
	},
	Storm = {
		DisplayName = "Storm",
		Weight = 10,
		TemperatureModifier = -14,
		HungerMultiplier = 1.2,
		ThirstMultiplier = 1.1,
		EnemyMultiplier = 1.35,
	},
}

SurvivalConfig.Combat = {
	DefaultDamage = 8,
	DefaultRange = 10,
	CooldownSeconds = 0.75,
	Weapons = {
		StoneAxe = { Damage = 16, Range = 12 },
		Spear = { Damage = 26, Range = 17 },
	},
	Armor = {
		HideArmor = { DamageMultiplier = 0.65 },
	},
}

SurvivalConfig.Enemies = {
	NightStalker = {
		DisplayName = "Night Stalker",
		Health = 72,
		Damage = 13,
		AttackRange = 5.5,
		AggroRange = 95,
		MoveSpeed = 18,
		SpawnEverySeconds = 16,
		MaxAlive = 7,
		Drop = {
			RawMeat = { Min = 1, Max = 2 },
			Hide = { Min = 1, Max = 2 },
		},
	},
}

SurvivalConfig.Objectives = {
	GatherBasics = {
		DisplayName = "First Supplies",
		Description = "Gather wood, stone, fiber, and berries.",
		Kind = "Collect",
		Requirements = { Wood = 4, Stone = 3, Fiber = 3, Berries = 2 },
		Reward = { Bandage = 1 },
	},
	MakeWeapons = {
		DisplayName = "Armed For Night",
		Description = "Craft a stone axe and a spear.",
		Kind = "Craft",
		Requirements = { StoneAxe = 1, Spear = 1 },
		Reward = { CookedBerries = 1 },
	},
	BuildCamp = {
		DisplayName = "Hold The Camp",
		Description = "Place a campfire and shelter.",
		Kind = "Build",
		Requirements = { Campfire = 1, Shelter = 1 },
		Reward = { SurvivalTonic = 1 },
	},
	HuntStalkers = {
		DisplayName = "Night Hunter",
		Description = "Defeat three night stalkers.",
		Kind = "Counter",
		Counter = "EnemiesDefeated",
		Required = 3,
		Reward = { Hide = 2, RawMeat = 2 },
	},
	SurviveNight = {
		DisplayName = "See The Dawn",
		Description = "Survive one full night.",
		Kind = "Counter",
		Counter = "NightsSurvived",
		Required = 1,
		Reward = { Spear = 1 },
	},
}

return SurvivalConfig
