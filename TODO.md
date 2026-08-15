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

## Future Content (Locked Design, Post-v8)

### Magic Spells (v9)

- [ ] Single-spell system: player chooses 1 active spell (switch in shop)
  - [ ] Arcane Bolt: ranged projectile spell, base game
  - [ ] Inferno Blade: melee swing with burn DOT, unlock via Spell Unlock L1
  - [ ] Frost Nova: crowd control freeze zones, unlock via Spell Unlock L2
  - [ ] Spell Unlock node: gated progression (L1 → Inferno, L2 → Frost Nova, L3+ reserved)
  - [ ] Spell upgrades: Haste/Arc/Radius per spell, Spellpower shared stat
  - [ ] Spell visuals: magic-themed (blue, orange/red, cyan effects)
  - [ ] Verify feel: each spell plays differently, swapping spells changes strategy

### Multiple Active Spells (v10+, expansion)

- [ ] Multi-spell system: player equips 2–3 spells simultaneously
  - [ ] Spell slots: "Spell Slot 1", "Spell Slot 2", "Spell Slot 3" (unlock via progression)
  - [ ] Casting behavior: rotate between slots or all cast on shared cooldown (TBD)
  - [ ] MetaProgression redesign: track multiple active spells per save
  - [ ] Goal: unlock new spell → major power spike, keeps "getting stronger" feeling fresh

### Enemy Types follow-up (not blocking v7)

- [ ] Visuals/audio: Bruiser/Elite still reuse the shared Minion sprite
      frames, tinted red/blue and rescaled -- real distinct sprite art
      not done yet (placeholder OK initially)
- [ ] Verify progression: early runs (Phase 1 only) feel accessible,
      reaching Phase 3 feels like milestone -- needs real playtesting

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
- [x] HUD & UI Design (see DESIGN.md) — live stats overlay (Time/Essence/
      Stardust), full death summary screen (rewards, loot breakdown, run
      stats, previous best), and skill tree tooltips (colored border,
      before/after values, affordability status)
- [x] Enemy Types (v7) — Bruiser (pause/charge) and Elite (kite +
      projectile) added alongside Minion, phase-gated spawn mix, and
      per-tier loot weighting (`Enemy.loot_weights` +
      `LootTypes.pick_random_weighted`)
- [x] Post-v7 audit — verified every DESIGN.md number (loot table, stat
      curves, enemy stats/loot weights, spawn-phase mix, skill-tree
      gating) against the actual code line by line; fixed everything
      found broken:
      - Difficulty ramp only scaled `speed`/`max_hp`, silently missing
        Bruiser's `charge_speed` and Elite's `projectile_speed` even
        though DESIGN.md calls both out explicitly — added an
        overridable `Enemy.apply_difficulty_scale()` hook
      - Save/load: "New Game" hardcoded slot 0 and wiped all 4 slots'
        metadata via a stray `_initialize_slots()` call; there was no
        way to start a fresh game in slots 2-4 (Load was disabled on
        empty slots) and no "Overwrite" action existed despite
        DESIGN.md requiring both
      - `last_played` was stored via engine uptime (`Time.get_ticks_msec`),
        so it read as garbage ("20680 days ago") after any restart;
        switched to a real Unix timestamp
      - `playtime_hours` was hardcoded to reset to 0.0 on every save
        instead of accumulating — now tracks real elapsed session time
      - Switching to an empty slot silently kept whatever was in memory
        from the previously loaded slot instead of resetting to defaults

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
