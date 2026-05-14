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
- Seek warmth
- Survive nightfall

## Current Prototype Systems

- `WorldService`: base map, spawn, lighting, day/night, structure proximity checks.
- `ResourceService`: runtime resource spawning and prompt-driven harvesting.
- `InventoryService`: server inventory state, item usage, and remote sync.
- `CraftingService`: recipe validation, crafting, and structure placement.
- `VitalsService`: hunger, thirst, temperature, and survival damage.
- `SurvivalClient`: HUD, notifications, inventory actions, and crafting controls.

## Next Production Steps

- Add DataStore-backed saves for inventory, unlocked recipes, and survival days.
- Replace runtime primitive models with polished Roblox assets.
- Add hostile weather, storms, and biome-specific temperature rules.
- Add enemy AI or wildlife after the survival loop feels stable.
- Add water sources and cooking stations instead of using berries as the first thirst item.
- Add anti-exploit validation for placement distance, harvest cooldowns, and impossible inventory changes.
- Tune depletion rates around a target first session length of 10 to 15 minutes.
