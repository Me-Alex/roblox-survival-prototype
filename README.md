# Volcanic Survival - Roblox Prototype

A server-authoritative survival crafting prototype set on a volcanic island.

## Current State

Core systems currently implemented:
- Runtime world generation, day/night cycle, and campfire warmth.
- Harvestable nodes (trees, rocks, bushes, fiber) with respawn timers.
- Inventory, item use, dropping, and structure placement.
- Crafting with recipe validation and station checks (campfire/stone oven).
- Wildlife and night enemy combat loops with drops and XP.
- Vitals (health, hunger, thirst, temperature, stamina) and status effects.
- Sleep flow with bedroll prompts and nighttime skip-to-morning.
- Shop purchasing flow with server-side cost validation.
- Persistence layer with Studio in-memory fallback for unpublished places.

## Controls

- `Tab`: open/close inventory
- `C`: open/close crafting
- `E`: interact with prompts (sleep, harvest, oven, shops)
- Left click / tool activate: use equipped tools and attacks

## Project Structure

```text
src/
  server/
    Main.server.lua
    Services/
      WorldService.lua
      ResourceService.lua
      InventoryService.lua
      CraftingService.lua
      VitalsService.lua
      CombatService.lua
      EnemyService.lua
      WildlifeService.lua
      SleepService.lua
      StoneOvenService.lua
      ShopService.lua
      ProgressionService.lua
      ObjectiveService.lua
      PersistenceService.lua
      ItemToolService.lua
  client/
    Main.client.lua
    Controllers/
      HudController.lua
      InventoryController.lua
      CraftingController.lua
      DeathController.lua
      SleepController.lua
  shared/
    Config.lua
    Remotes.lua
```

## Milestones

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Project skeleton and services | Done |
| 2 | Volcanic runtime terrain and resources | Done |
| 3 | Inventory + crafting loop | Done |
| 4 | Night enemy combat | Done |
| 5 | HUD status effects | Done |
| 6 | Bedroll and sleep sequence | Done |
| 7 | Wildlife and hunting loop | Done |
| 8 | Stone oven station and recipes | Done |
| 9 | Water collection and boiling | Done |
| 10 | Death/respawn polish and invincibility window | Done |
| 11 | Stability and compatibility audit pass | In Progress |
| 12 | Next: tighten anti-exploit coverage and rebalance rates | Next |

## Setup (Rojo)

1. Install the Rojo plugin in Roblox Studio.
2. Run `rojo serve` from this repository.
3. Connect from Studio.
4. Or build directly with:
   - `rojo build default.project.json --output build/SurvivalPrototype.rbxlx`
