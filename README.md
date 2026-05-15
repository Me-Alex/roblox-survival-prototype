# Roblox Survival Prototype

A Rojo-compatible Roblox survival game prototype with resource gathering, hunger, thirst, temperature, crafting, placeable structures, and a client HUD.

## What Is Built

- Runtime world setup with Hearthmarket Crossing, region landmarks, shop stands, roads, waystones, grass clumps, leaf litter, detailed resource nodes, and day/night cycle.
- Redesigned open-world regions including Hearthmarket Crossing, Frostpine Rise, Glasswater Fen, Rustjaw Quarry, Wreckers' Cove, Moonwillow Grove, Ashfall Foundry, and Starfall Observatory.
- Expanded open-world route chains with a central trade hub, outer biome spokes, quarry and foundry routes, wetland crossings, and late-game relic paths.
- Harvestable detailed trees, rocks, fiber plants, berry bushes, water springs, herb patches, iron deposits, and abandoned caches using `ProximityPrompt`.
- Harvest feedback with procedural axe chops, tree shake, bite marks, slash arcs, wood chips, falling log pieces, stone impacts, plant bounce, cache glints, water ripples, and reference-style `+Wood`/`+Leaves` resource cards.
- Biome-weighted resource clusters that push players to scout forests, wetlands, cliff zones, camps, and iron-rich highlands.
- Server-owned inventory with client synchronization.
- Weapons, armor, and build kits mirrored as real Roblox tools with detailed primitive handles and server-validated actions; raw materials stay inside the inventory menu.
- Hunger, thirst, and temperature drain over time.
- Damage from starvation, dehydration, and severe temperature exposure.
- Dynamic weather that changes survival pressure through rain, storms, cold fronts, and heat waves.
- Rain and storms can soak exposed players; shelters, watchtowers, and lit campfires protect against exposure.
- Sprint stamina for faster exploration with an exhaustion tradeoff.
- Drinkable water springs and placeable rain collectors.
- Night stalkers that spawn after dark, chase players, attack, and drop hide/raw meat.
- Night threat that escalates into raids, especially around upgraded signal beacons.
- Server-validated attack action with fists, stone axe, and spear damage tiers.
- Explicit equipment for weapons and armor, with durability loss and breakage.
- Bleeding and poison status effects with medical cures.
- XP and level progression from harvesting, crafting, building, combat, and surviving nights.
- Objective progression with rewards for exploring, gathering, crafting, building, hunting, and surviving the night.
- Category-based crafting for first steps, base building, food, medicine, and forge progression.
- Barter shops for starter supplies, building kits, medicine, provisions, forge gear, and rare relic progression items.
- Expanded crafting for spear, hide armor, cooked meat, antidote, survival tonic, rain collectors, workbench, forge, spike traps, signal beacons, and iron-tier gear.
- Mushroom clusters, mushroom stew, and placeable torch stands add more exploration rewards and base-lighting options.
- Iron deposits, smelting, and station-gated recipes.
- Placeable campfires and shelters that affect night-time survival, with campfires now burning fuel that can be refueled with wood.
- Reference-style survival HUD with bottom-left health/hunger/thirst/stamina bars, a top-center day/objective banner, a right-side survivor day board, and a bottom action bar.
- Larger circular minimap with player-centered zoomed projection, route hints, and teammate nameplates with health bars for co-op play.
- Buildable wooden walls, openable doors, stairs, storage chests, and watchtowers support the shelter-building references.
- Storage chests transfer resource stacks in and out through a proximity prompt.
- Smoothed procedural body and tool animations that move the torso, right arm, left arm, wrist, and grip for axe swings, spear thrusts, mining strikes, gathering, searching, and drinking.
- Stone axe now grips from the handle end (not centered), with animation keyframes tuned around that hold.
- Shelter rest interaction that restores health and warmth, grants a short `Rested` recovery status, and uses a survival tradeoff.
- Menu tabs for inventory, guided crafting, objectives, and a schematic world map with region routes.

## Project Layout

- `default.project.json`: Rojo project map.
- `src/shared`: shared config and remote definitions.
- `src/server`: server bootstrap and gameplay services.
- `src/client`: player HUD and client actions.
- `docs/design.md`: gameplay direction and next production steps.

## Run In Roblox Studio

1. Install Rojo if you do not already have it.
2. Open Roblox Studio and create a new baseplate place.
3. Start the Rojo server from this folder:

```powershell
rojo serve default.project.json
```

4. In Roblox Studio, connect the Rojo plugin to the local server.
5. Press Play. Walk to resource nodes and use the prompts to gather materials.

## Open A Built Place File

You can also generate a Studio-openable place file from the repo:

```powershell
rojo build default.project.json --output build/SurvivalPrototype.rbxlx
```

Then open `build/SurvivalPrototype.rbxlx` in Roblox Studio.

The `build/` folder is ignored by Git because it is generated from the source files.

## GitHub Workflow

This repository is designed to live on GitHub as source code. Clone it on another machine, install Rojo, then either run `rojo serve default.project.json` or build the `.rbxlx` place file with the command above.

## First Playtest Goals

- Gather wood, stone, fiber, and berries.
- Follow trails to discover named regions and complete `Scout The Island`.
- Craft a `Stone Axe`, then compare wood/fiber gathering speed.
- Chop a tree with the axe equipped and verify the two-hit swing, bark marks, chips, and log chunks.
- Use the bottom action bar or number keys to equip weapons, use food/medicine, and place build kits.
- Craft a `Spear` before nightfall.
- Equip crafted weapons and armor from the inventory menu or action bar.
- Craft and place a `Campfire Kit` before night.
- Use the campfire prompt to refuel it with wood before bad weather or long nights.
- Craft `Torch Stand Kit` markers around your gate or road junctions.
- Craft `Wooden Wall Kit`, `Wooden Door Kit`, and `Wooden Stairs Kit` to build a starter shelter.
- Place a `Storage Chest Kit`, use its prompt to store gathered resources, then use it again when carrying no raw resources to withdraw.
- Build a `Watchtower Kit` near a workbench after reaching level 2.
- Build a `Workbench Kit`, then use it to unlock the forge and iron tier.
- Stand near a lit campfire at night and watch temperature stabilize.
- Fight night stalkers with `F` after equipping a weapon from the action bar.
- Test spear and iron spear attacks to compare their longer thrust animations.
- Cook dropped `Raw Meat` near a campfire.
- Visit shop stands at Hearthmarket Crossing and outlying regions to barter for tools, medicine, building kits, forge supplies, provisions, and relic items.
- Pick mushrooms in Frostpine Rise, Hearthmarket Crossing, Glasswater Fen, or Moonwillow Grove and cook `Mushroom Stew` near a campfire.
- Cure bleeding or poison with `Bandage`, `Antidote`, or `Survival Tonic`.
- Craft `Cooked Berries` near the campfire and use them from the HUD.
- Build a shelter or watchtower and verify rain or storm exposure stops applying `Soaked` while nearby.
- Rest at a shelter when hurt or cold, then watch the `Rested` status and cooldown before using it again.
- Place a `Rain Collector Kit` and use it as backup drinking water.
- Search abandoned caches for rare supplies.
- Visit Rustjaw Quarry or Ashfall Foundry when you need more ore.
- Place `Spike Trap Kit` defenses before a raid.
- Build and upgrade a `Signal Beacon Kit` toward rescue.
