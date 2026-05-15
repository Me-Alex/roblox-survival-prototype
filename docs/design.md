# Survival Game Design

## Fantasy

The player wakes up at Hearthmarket Crossing, a rough survival trade hub in the center of a dangerous island, then has to survive the first night by gathering basic materials, bartering for useful supplies, crafting simple gear, managing hunger and thirst, and building warmth or shelter.

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
- Store resources
- Open doors
- Attack
- Hunt
- Equip
- Repair pressure through durability management
- Seek warmth
- Find water
- Build crafting stations
- Smelt ore
- Trade at shops
- Survive nightfall

## Current Prototype Systems

- `WorldService`: regional map, Hearthmarket Crossing hub, spawn, landmarks, cinematic lighting, ambient clutter, day/night, discovery tracking, and structure proximity checks.
- `ResourceService`: biome-weighted resource spawning, more natural primitive resource models, and prompt-driven harvesting.
- `InventoryService`: server inventory state, item usage, and remote sync.
- `ItemToolService`: mirrors weapons, armor, and build kits into tangible Roblox Backpack tools, builds detailed primitive weapon silhouettes, and routes tool actions back through server validation.
- `CraftingService`: recipe validation, crafting, structure placement, door toggles, and storage chest transfer prompts.
- `ShopService`: barter stand spawning, prompts, and server-validated shop purchases.
- `VitalsService`: hunger, thirst, temperature, and survival damage.
- `ProgressionService`: XP, levels, and level-up notifications.
- `EnemyService`: night stalker spawning, pursuit, attacks, damage scaling, drops, and cleanup.
- `CombatService`: server-validated player attacks and weapon selection.
- `ObjectiveService`: per-player progression goals and reward grants.
- `SurvivalClient`: HUD, notifications, inventory actions, and crafting controls.

## Added Gameplay Depth

- Weather changes every few minutes and affects temperature, hunger drain, thirst drain, and enemy pressure.
- Rain and storms can apply `Soaked` to exposed players, adding a short cold-pressure status unless they reach a shelter, watchtower, or lit campfire.
- The island is divided into named regions with visible landmarks, connected muddy trails, waystones, and a matching schematic map in the HUD, now spread over a larger playable footprint.
- Resources are clustered by region, so travel planning matters: Frostpine Rise and Moonwillow Grove favor wood and forage, Glasswater Fen favors herbs and water, Rustjaw Quarry and Ashfall Foundry favor stone and ore, Wreckers' Cove favors caches, and Starfall Observatory favors relic salvage.
- Shop stands give each route a destination: traders, builders, provisioners, herbalists, smiths, and relic brokers turn gathered resources into specific survival plans.
- Region discovery grants XP and feeds an exploration objective.
- Water springs and rain collectors make thirst management more active than eating berries.
- Sprinting helps exploration and combat escapes, but stamina creates a short-term movement tradeoff.
- Shelters now provide an active rest interaction that restores health and warmth, costs a little hunger and thirst, grants a short `Rested` recovery status, and has a cooldown.
- Night stalkers create a reason to prepare before dark with weapons, armor, fire, and food.
- Threat builds through dangerous nights and signal beacon upgrades, then turns into raids.
- Defeated enemies drop raw meat and hide, feeding the cooking and armor loops.
- Gear must be equipped to count in combat, and equipment durability creates long-run resource pressure.
- Weapons, armor, and build kits are represented by real Tool objects, while raw materials stay in the inventory menu so gathered resources do not clutter the Roblox hotbar; usable food and medicine can still appear in the custom action bar.
- Trees can award secondary leaves, and the client shows stacked resource gain cards like the gathering mockup.
- Base building now includes wooden walls, openable doors, stairs, storage chests, and craftable watchtowers.
- Storage chests hold resource stacks using a single prompt: if the player has resources, it stores a stack; otherwise it withdraws stored resources.
- Campfires now have fuel, visible flame intensity, a refuel prompt, and faster burn during storms, turning warmth into an ongoing resource decision instead of a one-time placement.
- Bleeding and poison make medical crafting matter beyond simple health restoration.
- Workbench and forge structures create a midgame station loop.
- Mushroom clusters add a low-risk food find in damp and forested regions, while torch stands give players a permanent way to mark roads, camp entrances, and defensive areas.
- Iron ore and ingots introduce a second gear tier with level requirements.
- Herb patches and abandoned caches make scouting more valuable between base-building pushes.
- Spike traps give base placement a defensive purpose.
- The signal beacon creates a longer rescue objective with staged costs and escalating danger.
- Objectives teach the survival loop and reward useful items without requiring a separate tutorial screen.
- The HUD follows the survival reference style: bottom-left vitals bars, top-center day/objective text, a right-side survivor day board, a larger player-centered circular minimap, teammate name/health plates, and a bottom action bar; inventory, guided crafting categories, objectives, and the world map live in the menu.
- Weapon tools animate the player torso, arms, wrists, and grip with smoothed procedural keyframes, giving axe swings, spear thrusts, mining strikes, and resource gathering feedback without requiring external animation assets.
- Harvest prompts now tell the client to play a local chop, mine, gather, search, or drink gesture while the server plays shared world impact effects.
- Trees, rocks, fiber plants, berry bushes, springs, iron deposits, and the surrounding terrain now use layered primitive details so they read less like single placeholder blocks.

## Next Production Steps

- Add DataStore-backed saves for inventory, unlocked recipes, and survival days.
- Replace runtime primitive models with polished Roblox assets.
- Add biome-specific temperature rules and stronger storm events after the first weather balance pass.
- Add wildlife, ranged weapons, and enemy patrol zones after the first combat playtest.
- Add dedicated cooking stations and spoilage timers.
- Add anti-exploit validation for placement distance, harvest cooldowns, and impossible inventory changes.
- Tune depletion rates around a target first session length of 10 to 15 minutes.
