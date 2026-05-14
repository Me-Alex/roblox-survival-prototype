local SurvivalConfig = {}

SurvivalConfig.World = {
	Seed = 1349,
	SpawnAreaHalfSize = 145,
	RespawnHeight = 8,
	DayLengthSeconds = 480,
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
	Berries = { DisplayName = "Berries", Category = "Food" },
	CookedBerries = { DisplayName = "Cooked Berries", Category = "Food" },
	Bandage = { DisplayName = "Bandage", Category = "Medical" },
	StoneAxe = { DisplayName = "Stone Axe", Category = "Tool" },
	CampfireKit = { DisplayName = "Campfire Kit", Category = "Buildable" },
	ShelterKit = { DisplayName = "Shelter Kit", Category = "Buildable" },
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
}

SurvivalConfig.Crafting = {
	StoneAxe = {
		DisplayName = "Stone Axe",
		Cost = { Wood = 2, Stone = 3, Fiber = 1 },
		Result = "StoneAxe",
		Amount = 1,
		Description = "Improves wood and fiber harvesting.",
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
	CookedBerries = {
		DisplayName = "Cooked Berries",
		Cost = { Berries = 3 },
		Result = "CookedBerries",
		Amount = 1,
		RequiresNearby = "Campfire",
		Description = "Restores more hunger and thirst than raw berries.",
	},
	Bandage = {
		DisplayName = "Bandage",
		Cost = { Fiber = 4, Berries = 1 },
		Result = "Bandage",
		Amount = 1,
		Description = "Restores health over time.",
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
	Bandage = {
		Health = 35,
		Notify = "You patched yourself up.",
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
}

return SurvivalConfig
