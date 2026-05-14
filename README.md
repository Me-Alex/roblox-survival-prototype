# Roblox Survival Prototype

A Rojo-compatible Roblox survival game prototype with resource gathering, hunger, thirst, temperature, crafting, placeable structures, and a client HUD.

## What Is Built

- Runtime world setup with a larger island, named regions, landmarks, trail routes, resource nodes, and day/night cycle.
- Open-world regions including Base Meadow, Pine Ridge, Stonebreak Cliffs, Mirefen Wetlands, Old Ranger Camp, and Iron Highlands.
- Harvestable trees, rocks, fiber plants, berry bushes, herb patches, and abandoned caches using `ProximityPrompt`.
- Biome-weighted resource clusters that push players to scout forests, wetlands, cliff zones, camps, and iron-rich highlands.
- Server-owned inventory with client synchronization.
- Inventory items mirrored as real Roblox Backpack tools with visible handles and server-validated actions.
- Hunger, thirst, and temperature drain over time.
- Damage from starvation, dehydration, and severe temperature exposure.
- Dynamic weather that changes survival pressure through rain, storms, cold fronts, and heat waves.
- Sprint stamina for faster exploration with an exhaustion tradeoff.
- Drinkable water springs and placeable rain collectors.
- Night stalkers that spawn after dark, chase players, attack, and drop hide/raw meat.
- Night threat that escalates into raids, especially around upgraded signal beacons.
- Server-validated attack action with fists, stone axe, and spear damage tiers.
- Explicit equipment for weapons and armor, with durability loss and breakage.
- Bleeding and poison status effects with medical cures.
- XP and level progression from harvesting, crafting, building, combat, and surviving nights.
- Objective progression with rewards for exploring, gathering, crafting, building, hunting, and surviving the night.
- Crafting for tools, food, bandages, campfires, and shelter kits.
- Expanded crafting for spear, hide armor, cooked meat, antidote, survival tonic, rain collectors, workbench, forge, spike traps, signal beacons, and iron-tier gear.
- Iron deposits, smelting, and station-gated recipes.
- Placeable campfires and shelters that affect night-time survival.
- Client HUD for vitals, quick consumables, inventory menu, crafting, buildables, and notifications.
- Shelter rest interaction that restores health and warmth with a short cooldown and survival tradeoff.
- World HUD for day/time/region/weather/threat, objective tracker, and attack/sprint buttons.

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
- Use Backpack tools to hold resources, eat food, equip weapons, attack, and place build kits.
- Craft a `Spear` before nightfall.
- Equip crafted weapons and armor from the `GEAR` panel.
- Craft and place a `Campfire Kit` before night.
- Build a `Workbench Kit`, then use it to unlock the forge and iron tier.
- Stand near the campfire at night and watch temperature stabilize.
- Fight night stalkers with `F` or the `Attack` button.
- Cook dropped `Raw Meat` near a campfire.
- Cure bleeding or poison with `Bandage`, `Antidote`, or `Survival Tonic`.
- Craft `Cooked Berries` near the campfire and use them from the HUD.
- Build a shelter and verify cold exposure is less punishing nearby.
- Rest at a shelter when hurt or cold, then watch the cooldown before using it again.
- Place a `Rain Collector Kit` and use it as backup drinking water.
- Search abandoned caches for rare supplies.
- Visit Stonebreak Cliffs or Iron Highlands when you need more ore.
- Place `Spike Trap Kit` defenses before a raid.
- Build and upgrade a `Signal Beacon Kit` toward rescue.
