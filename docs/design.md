# Survival Game Design

## Fantasy

The player wakes up in a small wilderness area and has to survive the first night by gathering basic materials, crafting simple gear, managing hunger and thirst, and building warmth or shelter.

## Core Loop

1. Explore the island.
2. Discover named regions and decide where to travel next.
3. Harvest resources from biome-specific clusters.
4. Craft tools and survival items.
5. Place campfires and shelters.
6. Manage hunger, thirst, temperature, and health.
7. Survive the night and prepare for longer trips.

## Player Verbs

- Gather
- Sprint
- Scout landmarks
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

- `WorldService`: regional map, spawn, landmarks, lighting, day/night, discovery tracking, and structure proximity checks.
- `ResourceService`: biome-weighted resource spawning and prompt-driven harvesting.
- `InventoryService`: server inventory state, item usage, and remote sync.
- `ItemToolService`: mirrors server inventory into tangible Roblox Backpack tools and routes tool actions back through server validation.
- `CraftingService`: recipe validation, crafting, and structure placement.
- `VitalsService`: hunger, thirst, temperature, and survival damage.
- `ProgressionService`: XP, levels, and level-up notifications.
- `EnemyService`: night stalker spawning, pursuit, attacks, damage scaling, drops, and cleanup.
- `CombatService`: server-validated player attacks and weapon selection.
- `ObjectiveService`: per-player progression goals and reward grants.
- `SurvivalClient`: HUD, notifications, inventory actions, and crafting controls.

## Added Gameplay Depth

- Weather changes every few minutes and affects temperature, hunger drain, thirst drain, and enemy pressure.
- The island is divided into named regions with visible landmarks and route trails.
- Resources are clustered by region, so travel planning matters: forests favor wood, wetlands favor herbs and water, cliffs and highlands favor stone and ore, and the old camp favors caches.
- Region discovery grants XP and feeds an exploration objective.
- Water springs and rain collectors make thirst management more active than eating berries.
- Sprinting helps exploration and combat escapes, but stamina creates a short-term movement tradeoff.
- Shelters now provide an active rest interaction that restores health and warmth, costs a little hunger and thirst, and has a cooldown.
- Night stalkers create a reason to prepare before dark with weapons, armor, fire, and food.
- Threat builds through dangerous nights and signal beacon upgrades, then turns into raids.
- Defeated enemies drop raw meat and hide, feeding the cooking and armor loops.
- Gear must be equipped to count in combat, and equipment durability creates long-run resource pressure.
- Inventory items are represented by real Tool objects, so players can hold resources, activate consumables, equip weapons and armor, and place build kits from the Roblox Backpack.
- Bleeding and poison make medical crafting matter beyond simple health restoration.
- Workbench and forge structures create a midgame station loop.
- Iron ore and ingots introduce a second gear tier with level requirements.
- Herb patches and abandoned caches make scouting more valuable between base-building pushes.
- Spike traps give base placement a defensive purpose.
- The signal beacon creates a longer rescue objective with staged costs and escalating danger.
- Objectives teach the survival loop and reward useful items without requiring a separate tutorial screen.
- The HUD keeps vitals, world state, objectives, combat, sprint, and quick consumables visible while moving backpack and crafting actions into a focused inventory menu.

## Next Production Steps

- Add DataStore-backed saves for inventory, unlocked recipes, and survival days.
- Replace runtime primitive models with polished Roblox assets.
- Add hostile weather, storms, and biome-specific temperature rules.
- Add wildlife, ranged weapons, and enemy patrol zones after the first combat playtest.
- Add dedicated cooking stations and spoilage timers.
- Add anti-exploit validation for placement distance, harvest cooldowns, and impossible inventory changes.
- Tune depletion rates around a target first session length of 10 to 15 minutes.
