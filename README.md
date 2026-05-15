# Volcanic Survival — Roblox Prototype

A survival-crafting game set on a dangerous volcanic island.

## Project Structure

```
src/
  server/
    Main.server.lua              ← Server entry point
    Services/
      WorldService.lua           ← World, terrain, day/night
      VitalsService.lua          ← Health, hunger, thirst, temperature
      InventoryService.lua       ← Server-authoritative inventory
      CraftingService.lua        ← Crafting validation
      EnemyService.lua           ← Enemy AI and spawning
  client/
    Main.client.lua              ← Client entry point
    Controllers/
      HudController.lua          ← Vital bars + notifications HUD
      InventoryController.lua    ← Inventory panel (TAB to open)
  shared/
    Config.lua                   ← ALL game numbers & definitions
    Remotes.lua                  ← All RemoteEvents in one place
```

## Controls

| Key | Action |
|-----|--------|
| TAB | Open/close inventory |
| Click | Interact / harvest |

## Build Milestones

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Project skeleton (config, remotes, services, controllers) | ✅ Done |
| 2 | World terrain, resource nodes, campfire placement | 🔜 Next |
| 3 | Gathering (chop trees, mine rocks, pick berries) | ⏳ |
| 4 | Enemy AI (night stalker, ash wolf) | ⏳ |
| 5 | Persistence (save/load vitals + inventory) | ⏳ |

## Setup (Rojo)
1. Install [Rojo](https://rojo.space) plugin in Roblox Studio
2. Run `rojo serve` in this folder
3. Click **Connect** in Studio
