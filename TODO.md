# TODO

Lightweight backlog. Not every idea needs to live here — just things worth
not forgetting between sessions. Check items off or delete them once done;
this file should stay short enough to skim.

## Now

- [x] All DESIGN.md features implemented and tested
  - [x] Core gameplay: movement, combat, loot, backpack, death/run cycle
  - [x] Rarity tiers (6 tiers with correct drop weights, stack sizes, values)
  - [x] Two currencies with correct income streams
  - [x] Upgrade curves (geometric cost, hard caps) for all stats
  - [x] Compacting per-tier (stack size multipliers)
  - [x] Purge (auto-discard at thresholds)
  - [x] Skill tree shop (two-tree layout with gating)
  - [x] 4-slot save system with metadata tracking and persistence
  - [x] Startup menu system (Main Menu → New Game / Load Game)
  - [x] Backpack currency rate aligned with DESIGN.md (0.05/sec, v6 balance)

## In Progress / Lower Priority

- [ ] Cloud-sync backend: infrastructure exists (cloud_sync.gd) but server integration not implemented (placeholder only)
- [ ] Settings menu: UI skeleton exists, no settings stored yet

## Future Content (Locked Design, Post-v6)

### Enemy Types (v7 or v8)

- [ ] Enemy types: Bruiser (charge) and Elite (projectile ranged)
  - [ ] Bruiser spawns Phase 2 (20+ sec), 30% spawn mix, 50% Uncommon drops
  - [ ] Elite spawns Phase 3 (40+ sec), 25% spawn mix, 70% Rare+ drops
  - [ ] Loot weighting: implement dynamic drop rates based on enemy tier
  - [ ] Attack behaviors: charge attack (Bruiser), projectile system (Elite)
  - [ ] Visuals/audio: distinct sprites and effects per tier (placeholder OK initially)
  - [ ] Verify progression: early runs (Phase 1 only) feel accessible, reaching Phase 3 feels like milestone

### Magic Spells (v7)

- [ ] Single-spell system: player chooses 1 active spell (switch in shop)
  - [ ] Arcane Bolt: ranged projectile spell, base game
  - [ ] Inferno Blade: melee swing with burn DOT, unlock via Spell Unlock L1
  - [ ] Frost Nova: crowd control freeze zones, unlock via Spell Unlock L2
  - [ ] Spell Unlock node: gated progression (L1 → Inferno, L2 → Frost Nova, L3+ reserved)
  - [ ] Spell upgrades: Haste/Arc/Radius per spell, Spellpower shared stat
  - [ ] Spell visuals: magic-themed (blue, orange/red, cyan effects)
  - [ ] Verify feel: each spell plays differently, swapping spells changes strategy

### Multiple Active Spells (v8+, expansion)

- [ ] Multi-spell system: player equips 2–3 spells simultaneously
  - [ ] Spell slots: "Spell Slot 1", "Spell Slot 2", "Spell Slot 3" (unlock via progression)
  - [ ] Casting behavior: rotate between slots or all cast on shared cooldown (TBD)
  - [ ] MetaProgression redesign: track multiple active spells per save
  - [ ] Goal: unlock new spell → major power spike, keeps "getting stronger" feeling fresh

## v6 Balance (Implemented, Pending Playtest)

See [DESIGN.md — v6 Balance](DESIGN.md#v6-balance-locked-ready-for-implementation) for all numbers and rationale.

- [x] Implement all v6 balance values (1 slot start, 0.05/sec, Capacity cost 100, etc.)
- [ ] Playtest & verify: player upgrades feel rewarding early, Compacting accessible run 5–10, Capacity feels like prestige late-game

## Later (Completed this session)

- [x] Fix Backpack Capacity's upgrade curve — now uses ×1.20/lvl, 12-level cap
- [x] Skill-tree shop UI — two-tree layout with gating and visual improvements
- [x] Compacting (per-tier) + Purge — full gameplay mechanics implemented
- [x] Compacting gameplay: stack sizes increase per tier based on Compactor level
- [x] Purge gameplay: auto-discard lowest-rarity items at threshold 90/85/80/70%

## Done

- [x] Godot 4 project scaffold, versioning workflow, engineering practices (v1)
- [x] Dev environment: Godot Tools VS Code extension, gdformat/gdlint
- [x] Core concept + initial scope decided (see DESIGN.md)
- [x] Core loop built end-to-end: movement, one enemy, auto-attack combat,
      HP/death, proximity loot pickup, backpack fill/HP-shrink, difficulty
      ramp, run summary, currency + shop (capacity/pickup range), run
      restart with carried-over upgrades (v2)
- [x] Data-driven `StatDef`/`MetaProgression`, styled HUD with stat
      readouts and color-graded bars, shared button/panel style
      resources, magnet-style loot pickup (v3)
- [x] Rarity tiers + slot-grid backpack, two-currency split with
      geometric-cost/capped upgrades, Damage + Move Speed upgradeable,
      player dash, real sprite art, `/play` `/close` `/editor` slash
      commands (v4)
