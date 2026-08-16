# TODO

Lightweight backlog. Not every idea needs to live here — just things worth
not forgetting between sessions. Check items off or delete them once done;
this file should stay short enough to skim.

## Staged major tweaks

A run of several big, structural changes is starting — the skill-tree
rework below is the first. `v0.1.1` was deliberately cut as the stable
rollback point right before this phase (see the Process item below), so
each tweak should build on a known-good baseline, not on top of an
in-flight one. To keep that true and avoid blurry scope between changes:

- **One tweak in flight at a time.** Don't start the next tweak's work
  until the current one is finished, playtest-verified, and landed.
- **Each tweak gets an explicit In scope / Out of scope line** below —
  implementation should stick to it rather than opportunistically
  touching adjacent systems while in there.
- **Milestone-sized tweaks get their own version tag** per
  [VERSIONING.md](VERSIONING.md) rather than landing bundled with the
  next tweak's commits — that's what keeps rollback granular if one of
  these turns out wrong.
- Further tweaks in this set get added here in the same format as
  they're scoped, one at a time — this list isn't meant to be
  pre-filled with placeholders for tweaks that aren't designed yet.

- [ ] **Tweak 1 — Shop skill-tree rework.** Split spells out of Player
      Tree into their own Spell Tree tab (three tabs total: Player /
      Spells / Backpack), replacing the static read-only spell-lock
      sidebar with a real interactive tree. See DESIGN.md's "Shop
      structure: skill tree" section for the full target spec.
      - **In scope:** the new Spell Tree tab and its trunk/branch
        layout, moving the 18 spell stat defs' tree membership,
        removing the old sidebar, the three tab labels (Player /
        Spells / Backpack).
      - **Out of scope:** any stat ID, cost curve, or gate value change;
        renaming Player Tree/Backpack Tree's existing header text
        beyond the tab label itself; anything in Backpack Tree; balance
        numbers anywhere.

## Process (from the 2026-08-16 engineering-practices pass)

- [x] Add a lightweight headless unit-test runner for pure logic (cost
      curves, drop weights, stat formulas) — `scripts/unit_tests.gd`
      (autoload `UnitTests`), same self-contained, no-external-framework
      style as `playtest_harness.gd`. See TESTING.md's "Headless
      pure-logic unit tests" section. Covers `MetaProgression` cost/level
      math (generically, against each `StatDef`'s own fields, not
      hardcoded numbers), `buy_upgrade`/level-cap behavior,
      `LootTypes.pick_random_weighted`/`get_effective_stack_size`, and the
      backpack fill-ratio HP/speed lerp in `player.gd` (driven through the
      real `collect_loot`/`consume_loot` API). `Godot.exe --headless
      --path . -- --unit-test`; 191 assertions, all passing.
- [x] Cut the next version tag once the incoming stable build is
      confirmed clean — done as `v0.1.1` (PATCH, not MINOR: Backpack
      Ability/v11 spells/Boss/Settings were already in `v0.1.0`'s tag;
      the only things added after it were the shop-tab reorg and
      tooling/docs, no new content, so PATCH per VERSIONING.md's own
      definitions). This is the intended stable rollback point before
      the next round of bigger overhauls.

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
  - [x] Backpack Ability: pre-run Condense/Clear choice (`backpack_ability.gd`),
        picked in `run_prep.tscn`, new Alchemy upgrade stat -- see
        DESIGN.md's Backpack Ability section for the full spec

## In Progress / Lower Priority

- [ ] Cloud-sync backend: infrastructure exists (cloud_sync.gd) but server
      integration not implemented (placeholder only) -- **blocked**: needs
      an actual backend/hosting decision (Firebase, Supabase, custom
      server, ...), not something to pick unilaterally
- [x] Settings menu: real screen now (`settings_menu.tscn`/`.gd`) with a
      master volume slider and fullscreen toggle, persisted to
      `user://settings.json` via a new `Settings` autoload (device-level
      prefs, separate from per-save-slot MetaProgression data)

## Future Content (Locked Design, Post-v8)

### Magic Spells (v9/v10/v11) follow-up

- [x] Verify *functional* correctness with all 3 spells firing together:
      10-run playtest batches (moderate and heavy stat seeding) show zero
      runtime errors with Arcane/Inferno/Frost all active and casting on
      independent cooldowns simultaneously -- confirms no signal
      conflicts or performance blowup.
- [ ] Verify *visual/audio* feel (whether 3 simultaneous cast effects
      read as clutter or chaos) -- genuinely can't check this headless,
      no way to see frames or hear audio output from the playtest
      harness. Needs actual human eyes/ears.
- [x] Real spell visuals/SFX -- Inferno Blade (flame-burst) and Frost Nova
      (ice-ring, sized to its radius stat) both have dedicated procedural
      visuals now; Arcane Bolt's projectile already had one from the
      start. All still procedural vector shapes, not sprite art.
- [x] Inferno Blade's 200px knockback -- Enemy now has a decaying
      `_knockback` velocity (mirrors Player's own)


- [x] Loot affixes (`loot.gd`): Epic+ drops can roll "Blessed" (+50%
      value, distinct gold color/pulse/floating text). Scoped as a
      one-time bonus banked to `Player.bonus_loot_value` rather than a
      persistent per-item modifier, since the backpack only tracks a
      count per tier, not item instances -- see DESIGN.md's Loot
      Affixes section for why a true instance-level version is a
      bigger architecture change, left as a future direction.
- [x] v11 Additional Spells: Meteor Strike, Lightning Chain, Time Warp,
      Teleport Pulse, Summon Familiar all implemented and gated behind
      Spell Unlock L3-L7 (cap raised 5->7). See DESIGN.md's Magic Spells
      section for full specs and the decision log for scope notes
      (each got 1 upgrade stat instead of 2-3, Familiar's "mana-limited"
      flavor stood in for by duration+cooldown rather than a new mana
      resource). Functional correctness verified via the playtest
      harness with all 8 spells active; visual/audio feel has the same
      "needs a human" caveat as the original three above.

### Enemy Types follow-up (not blocking v7)

- [x] Visuals: Bruiser/Elite/Boss now use their own distinct sprite sheets
      (orc_warrior/orc_shaman/big_demon from the existing DungeonTilesetII
      pack, already imported but previously unused) instead of a tinted
      reuse of the Minion's goblin frames. Audio (distinct hit/cast
      sounds per tier) still not done.
- [ ] Verify progression: early runs (Phase 1 only) feel accessible,
      reaching Phase 3 feels like milestone -- needs real playtesting.
      Playtest harness data so far: a heavily-seeded bot reaches Phase 3
      consistently (~44-52s avg survival); a moderately-seeded one (all 3
      spells + a handful of stat levels, standing in for "several runs
      in") lands solidly in Phase 2 (~30s avg, max 37.6s across 10 runs)
      without reaching it; a fresh/zero-upgrade one never does --
      consistent with "milestone," not yet confirmed as *feeling* like
      one to an actual player (the bot doesn't reposition/plan the way a
      human would, so this reads real difficulty but isn't the full
      picture).
- [x] Tier 4 Boss -- unique, spawns once at 55+ sec, hybrid pursuit +
      3-shot projectile spread, guaranteed Mythic+ drop
- [x] Enemy variants within tiers -- Fast/Tanky Minion, same loot table,
      70/15/15 split of each phase's existing Minion spawn weight

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
- [x] Backpack-fill speed penalty — a full bag now also slows movement
      (floor 70% of base speed) alongside the existing max-HP shrink
      (floor 20%), reusing the same fill-ratio lerp in `player.gd`
- [x] Magic Spells (v9) — single-active-spell casting system replacing
      the old flat weapon: Arcane Bolt (ranged projectile, always
      available), Inferno Blade (melee arc + burn DOT, unlocks at Spell
      Unlock L1), Frost Nova (AOE damage + slow, unlocks at L2). New
      Spell Unlock skill-tree node plus 8 per-spell upgrade stats (cost
      curves invented -- DESIGN.md only gave effect shape/caps, not
      costs). Spell switching + tier unlocking done in the shop's new
      "Active Spell" panel. Also fixed a skill-tree layout bug this
      surfaced: nodes with more than 4 children (Spell Unlock has 6)
      overflowed past the tree column instead of wrapping to a new row.
- [x] Multi-Spell Casting (v10) — replaced v9's single-active-spell
      switching: every unlocked spell now fires simultaneously and
      independently (own cooldown per spell), no slots or manual
      switching. Shop's spell panel is now a read-only unlock-status list.
- [x] Headless auto-playtest harness — `scripts/playtest_harness.gd` +
      `scripts/playtest_bot_ai.gd`, see CLAUDE.md's Testing section for
      usage. Runs N bot-played runs back to back, sandboxed save slot,
      prints an aggregate report; found and fixed two latent physics-flush
      bugs (`loot.gd`, `arena.gd`'s `_on_enemy_died`) along the way.
- [x] Early-game rebalance from playtest harness data — fixed Minion's
      HP/speed (120/30 code vs 100/20 documented spec) and eased
      `CONTACT_DAMAGE` 10→8; 20-run baseline went 10.1s/1.8 kills avg →
      12.2s/4.7 kills avg, zero-loot runs 10/20 → 3/20. See DESIGN.md's
      decision log for the full before/after numbers.

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
