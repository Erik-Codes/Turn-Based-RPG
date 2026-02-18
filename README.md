# Godot RPG
*A Turn-Based Creature Battler Built in Godot (name still wip)*

I'm working on a custom-built, turn-based creature battler developed in **Godot using GDScript**.  
The project serves both as a playable game prototype and as a structured deep dive into Godot engine architecture, UI systems, and persistent game state design.

I thought of this project as a great way to learn **Godot and GDScript through real-world system implementation**.

**NOTE: Due to licensing restrictions I am unable to include the sprites I'll be using to this repo**

---

## Last Edit
My most recent changes (2/18)
- replaced party lineup slots w/ MonsterEntryButtons and refactored the code to just use the built-in setup
- changed it so 1 press selects the monster (to view stats), and dragging is used to swap (dragging gives just the image of the monster)
- made sure the 4th (locked) slot is unusable until MAX_PARTY_SIZE is changed down the line
- added outline for quests to GameState (next)
---

## Overview

I'm combining node-based overworld exploration with a timeline-driven battle system and persistent creature management. I'm trying to emphasizes clean architecture, modular UI components, and scalable state management.

The game features:
- Node-based island exploration system
- Turn-order battle system with dynamic priority queue reflow
- Persistent monster instances (HP, level, stats, etc.)
- Party and roster management with swapping and reordering
- Scene transitions with zoom + fade effects
- Modular town hubs and activity zones (fishing, shops, upgrades)

---

## Core Systems Implemented

### Overworld System
- Graph-based island navigation
- Node reveal logic
- Temporary battle clearing with town reset behavior
- Persistent node state via `GameState`
- Animated player movement + camera zoom transitions

### Battle System
- Timeline-based turn order
- Dynamic queue visualization
- Unique battle UID system (separate from persistent monster UID)
- Animated HP fill + chip system
- Enemy wave spawning
- Persistent HP between battles
- KO handling with greyed party slots

### State Architecture
- Autoload `GameState` for:
  - Island state
  - Party composition
  - Persistent monster instances
  - Roster storage
- Clear separation between:
  - Monster species data (static)
  - Monster instance data (persistent)
  - Battle-specific runtime data

### Party Management
- Unified reusable MonsterEntry UI component
- Party slot ↔ roster swap logic
- Automatic party assignment for newly captured monsters
- KO prevention and validation logic

---

## Technical Design Decisions

- **Instance-based monster system**  
  Each monster is stored as a persistent instance (`uid`) separate from species definitions.

- **Separation of battle UID vs. persistent UID**  
  Prevents data corruption and allows multiple battle layers safely.

- **Rebuild UI pattern**  
  Rather than mutating UI in-place, lineup and roster lists are rebuilt from `GameState`, ensuring consistency and reducing edge-case bugs.

- **Tween-based animation architecture**  
  Movement, HP updates, queue reflow, and transitions are all managed via tweens for clarity and modularity.

- **Autoload-driven state persistence**  
  Map progress, HP, and party configuration survive scene changes without duplication or manual transfer.

---

## Current Feature Set

- Persistent monster HP
- Village healing reset
- Temporary battle clearing system
- Dynamic encounter probability reduction (currently disabled for debugging)
- Animated turn-order queue
- Enemy drop-in sequences
- Party reorder and swap system
- Fishing and town scene structure foundations

---

## Planned Features

- Experience and leveling system
- Expanded stat scaling
- Quest log with manual turn-in
- Town-specific shop inventories
- Interactive fishing with reward chance (items vs enemy encounters)
- Monster evolution system
- Expanded multi-island world structure
- Save/load system

---

## Technologies Used

- **Engine:** Godot
- **Language:** GDScript
- Scene-based architecture
- Autoload singletons
- Tween animation systems
- Custom UI components

---

## Development Focus

This project prioritizes:

- Clean architecture
- System scalability
- State integrity across scenes
- Clear separation of data layers
- Learning engine internals through implementation

This is an ongoing project designed to evolve alongside my technical understanding of game architecture and Godot development.
