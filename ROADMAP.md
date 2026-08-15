# Hoard Survivors — Development Roadmap

## Current State: v4 Released

Core game is playable end-to-end: movement, combat, loot, backpack, death/run cycle, meta-progression through shop upgrades.

---

## v5: Polish & Juice (In Progress)

**Focus:** Visual/audio feedback, animations, UI refinement

**What's included:**
- UI/UX improvements (menus, buttons, clarity)
- Visual effects & animations (combat, loot pickup, death)
- Audio/SFX (attack sounds, loot jingle, music)
- Scene transitions & menu polish
- Procedural SFX improvements

**Owner:** Implementation chat (parallel to v6 design)

**When ready:** Ship after v6 balance is implemented or in parallel

---

## v6: Balance Rebalance (Ready for Implementation)

**Focus:** Hard early game, lots of runs, incremental progression

**What changes from v4:**

| Parameter | v4 | v6 | Impact |
|-----------|----|----|--------|
| Starting capacity | 8 slots | 1 slot | Immediate pressure; forces Compacting early |
| Loot stack (Common) | 64 | 10 | Stacking becomes essential, not optional |
| Backpack currency rate | 0.33/sec | 0.05/sec | Very slow; Capacity is late-game prestige |
| Capacity base cost | 20 | 100 | Each slot feels earned |
| Capacity growth | ×1.20/lvl | ×1.25/lvl | Steeper late-game curve |
| Compacting (Common) base | 8 | 12 | Still accessible early, but costs more |

**Result:** Player upgrades (Damage/Speed/Magnet) feel rewarding early → Compacting accessible mid-game → Capacity becomes prestige milestone (20+ runs to unlock slot 2)

**Design reference:** [DESIGN.md — v6 Balance](DESIGN.md#v6-balance-locked-ready-for-implementation)

**Implementation checklist:** [TODO.md — v6 Balance](TODO.md#v6-balance-locked-ready-for-implementation)

**Scope:** Data-driven; mostly config/constant changes, minimal new systems

**Testing:** Playtesting should verify progression feels right (not grindy, not too fast)

---

## v7: Content Expansion (Ready for Design Review, Next Implementation)

**Focus:** Tactical enemy variety + spell system

### Enemy Types

Three enemy tiers with distinct attack patterns and loot weighting.

**Phase 1 (0–20 sec):** Minions only
**Phase 2 (20–40 sec):** 70% Minions, 30% Bruisers
**Phase 3 (40+ sec):** 40% Minions, 35% Bruisers, 25% Elites

| Enemy | Attack | Loot | HP | Speed | Role |
|-------|--------|------|----|----|------|
| Minion | Melee chaser | 60% Common | 20 | 100 | Bulk; teaches fundamentals |
| Bruiser | Charge attack | 50% Uncommon | 35 (+75%) | 70 | Evasion timing; risk/reward |
| Elite | Projectile (ranged) | 70% Rare+ | 40 (+100%) | 120 | Positioning; tactical |

**Design reference:** [DESIGN.md — Enemy Types & Loot Tiers](DESIGN.md#enemy-types--loot-tiers)

**Implementation checklist:** [TODO.md — Future Content](TODO.md#future-content-locked-design-post-v6)

### Magic Spells (Single Active)

Player is a magic user. Only 1 spell active at a time (switch in shop).

| Spell | Type | Unlock | Upgrades | Feel |
|-------|------|--------|----------|------|
| Arcane Bolt | Ranged projectile | Always available | Haste, Speed | Steady, reliable DPS |
| Inferno Blade | Melee swing + burn | L1 Spell Unlock | Fury, Arc, Burn Dmg | Risk/reward, area control |
| Frost Nova | Crowd control freeze | L2 Spell Unlock | Frequency, Radius, Slow | Utility, kiting support |

**Design reference:** [DESIGN.md — Magic Spells & Attack Skills](DESIGN.md#magic-spells--attack-skills)

**Implementation checklist:** [TODO.md — Magic Spells](TODO.md#magic-spells-v7)

### v7 Implementation Notes

- Enemy types and spells are independent systems; can build in parallel
- Loot weighting needs to be dynamic (enemy tier → drop rate adjustment)
- Spell system can reuse existing upgrade architecture (Damage/Fire Rate curves)
- Visuals: enemy sprites/effects, spell particle effects (placeholder OK initially)

**Testing:** Verify new enemies/spells create tactical variety; runs feel less repetitive

---

## v8+: Multi-Spell Expansion (Future)

**Focus:** Player equips 2–3 spells simultaneously; keeps "getting stronger" feeling alive

**What's added:**
- Spell Slots: unlock additional slots via progression
- Casting behavior: rotate between spells or all cast on shared cooldown (TBD)
- MetaProgression redesign: track multiple active spells per save

**Goal:** Each new spell unlock feels like a major power spike, sustaining engagement through 20+ runs

**Design reference:** [DESIGN.md — Future: Multiple Active Spells](DESIGN.md#future-multiple-active-spells-v8)

---

## Post-v8 Ideas (Backlog)

- Tier 4 Boss enemy (55+ sec, guaranteed Mythic+ drop)
- Enemy variants (fast Minion, tanky Minion)
- Additional spells: Meteor Strike, Teleport Pulse, Time Warp, Lightning Chain, Summon Familiar
- Loot affixes (+ modifiers on rare drops)
- Boss-exclusive weapons

---

## Shared Reference

| Document | Purpose |
|----------|---------|
| [DESIGN.md](DESIGN.md) | Complete design spec; all decisions & rationale |
| [TODO.md](TODO.md) | Implementation checklists per version |
| [CLAUDE.md](CLAUDE.md) | Engineering practices, codebase structure |
| [VERSIONING.md](VERSIONING.md) | Git workflow, tagging, releases |
| [CHANGELOG.md](CHANGELOG.md) | Release notes (updated per version tag) |

---

## Timeline Estimate (Rough)

- **v6 Balance:** 1–2 implementation sessions (config changes, playtesting)
- **v7 Content:** 2–3 implementation sessions (enemy types + spells in parallel)
- **v8+ Multi-Spell:** TBD, depends on v7 feedback

---

## Sync Points

- **After v6 ships:** Gather balance feedback; v7 design is locked, ready to start
- **After v7 ships:** Gather content feedback; v8 multi-spell design is fleshed out, ready to plan implementation
- **Between versions:** Design & implementation chats sync on priorities and blockers

---

## Name

**Hoard Survivors** — You collect (hoard) loot while surviving hordes of enemies. Core mechanic: backpack fills, max HP shrinks. Risk/reward tension every run.
