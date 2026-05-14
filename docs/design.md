# Survival Game Design

## Fantasy

The player wakes up in a small wilderness area and has to survive the first night by gathering basic materials, crafting simple gear, managing hunger and thirst, and building warmth or shelter.

## Core Loop

1. Explore the island.
2. Harvest resources from nearby nodes.
3. Craft tools and survival items.
4. Place campfires and shelters.
5. Manage hunger, thirst, temperature, and health.
6. Survive the night and prepare for longer trips.

## Player Verbs

- Gather
- Craft
- Eat
- Heal
- Build
- Attack
- Hunt
- Equip
- Repair pressure through durability management
- Seek warmth
- Find water
- Build crafting stations
- Smelt ore
- Survive nightfall

## Current Prototype Systems

- `WorldService`: base map, spawn, lighting, day/night, structure proximity checks.
- `ResourceService`: runtime resource spawning and prompt-driven harvesting.
- `InventoryService`: server inventory state, item usage, and remote sync.
- `CraftingService`: recipe validation, crafting, and structure placement.
- `VitalsService`: hunger, thirst, temperature, and survival damage.
- `ProgressionService`: XP, levels, and level-up notifications.
- `EnemyService`: night stalker spawning, pursuit, attacks, damage scaling, drops, and cleanup.
- `CombatService`: server-validated player attacks and weapon selection.
- `ObjectiveService`: per-player progression goals and reward grants.
- `SurvivalClient`: HUD, notifications, inventory actions, and crafting controls.

## Added Gameplay Depth

- Weather changes every few minutes and affects temperature, hunger drain, thirst drain, and enemy pressure.
- Water springs and rain collectors make thirst management more active than eating berries.
- Night stalkers create a reason to prepare before dark with weapons, armor, fire, and food.
- Defeated enemies drop raw meat and hide, feeding the cooking and armor loops.
- Gear must be equipped to count in combat, and equipment durability creates long-run resource pressure.
- Bleeding and poison make medical crafting matter beyond simple health restoration.
- Workbench and forge structures create a midgame station loop.
- Iron ore and ingots introduce a second gear tier with level requirements.
- Objectives teach the survival loop and reward useful items without requiring a separate tutorial screen.

## Next Production Steps

- Add DataStore-backed saves for inventory, unlocked recipes, and survival days.
- Replace runtime primitive models with polished Roblox assets.
- Add hostile weather, storms, and biome-specific temperature rules.
- Add wildlife, ranged weapons, and enemy patrol zones after the first combat playtest.
- Add dedicated cooking stations and spoilage timers.
- Add anti-exploit validation for placement distance, harvest cooldowns, and impossible inventory changes.
- Tune depletion rates around a target first session length of 10 to 15 minutes.
