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
  - [x] Backpack currency rate aligned with DESIGN.md (1.0/sec)

## In Progress / Lower Priority

- [ ] Cloud-sync backend: infrastructure exists (cloud_sync.gd) but server integration not implemented (placeholder only)
- [ ] Settings menu: UI skeleton exists, no settings stored yet
- [ ] Balance tuning: game balance based on placeholder numbers, needs playtesting

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
