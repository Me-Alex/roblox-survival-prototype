# Roblox Survival Prototype

A Rojo-compatible Roblox survival game prototype with resource gathering, hunger, thirst, temperature, crafting, placeable structures, and a client HUD.

## What Is Built

- Runtime world setup with a grass island, spawn point, resource nodes, and day/night cycle.
- Harvestable trees, rocks, fiber plants, and berry bushes using `ProximityPrompt`.
- Server-owned inventory with client synchronization.
- Hunger, thirst, and temperature drain over time.
- Damage from starvation, dehydration, and severe temperature exposure.
- Crafting for tools, food, bandages, campfires, and shelter kits.
- Placeable campfires and shelters that affect night-time survival.
- Client HUD for vitals, inventory, consumables, buildables, crafting, and notifications.

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
- Craft a `Stone Axe`, then compare wood/fiber gathering speed.
- Craft and place a `Campfire Kit` before night.
- Stand near the campfire at night and watch temperature stabilize.
- Craft `Cooked Berries` near the campfire and use them from the HUD.
- Build a shelter and verify cold exposure is less punishing nearby.
