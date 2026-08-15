# Changelog

All notable fixed versions of this project are documented here.

## v7 - 2026-08-15

Two new enemy tiers join the Minion, with tactical roles instead of
just more HP: a charger that punishes standing still and a kiter that
punishes standing at range.

- **Bruiser** (Phase 2, 20+ sec): pauses 2-3s to telegraph, then
  charges in a straight line. Only deals contact damage while
  charging, so the pause is a real dodge window.
- **Elite** (Phase 3, 40+ sec): kites to hold ~300px of distance and
  fires a projectile instead of melee-attacking, so closing the
  distance is the counter-play against it.
- Each tier now drops loot from its own weighted table (per DESIGN.md's
  "Enemy Types & Loot Tiers") instead of the single flat global table
  every enemy shared before — Bruisers lean Uncommon, Elites lean
  Rare/Epic.
- `Enemy` is now a base class with an overridable behavior hook, so
  both new tiers reuse the Minion's HP/hit-flash/death-spark plumbing
  rather than duplicating it.
- Visuals are still the shared Minion sprite, tinted red (Bruiser) and
  blue (Elite) and rescaled — distinct sprite art is follow-up work.

## v6 - 2026-08-15

Balance rebalance plus the HUD/UI system promised for v5's follow-up:
harder early game, a live in-run stats readout, a real death summary,
and richer skill tree tooltips.

- Backpack economy slowed down per the "many runs, hard early game"
  philosophy: Stardust income cut to 0.05/sec (was 0.33/sec), Bearing
  (backpack slot) cost raised to 100 base ×1.25/lvl (was 20 ×1.20/lvl),
  Compacting tier costs raised across the board. Player-power upgrades
  stay cheap and early, so the ladder now reads: player stats (early
  wins) → Compacting (mid wins) → Bearing (late-game prestige).
- Fixed ambient magic particles clumping into a single fixed sparkle at
  the arena's center instead of drifting across it (wrong
  `emission_shape` enum value).
- In-run HUD gains a live Time/Essence/Stardust readout above the HP
  bar, updated every frame.
- Death screen is now a full run summary: time survived, difficulty
  phase reached, rewards earned this run, loot collected broken down
  by rarity, run stats (max backpack fill, enemies killed), and a
  previous-best comparison once one exists.
- Skill tree tooltips get a currency-colored border (gold/cyan),
  before/after stat values ("20 → 22"), and affordable/shortfall/
  maxed/locked status text instead of a plain description box.
- Adopted TEXT_FLAVOR.md's stat-naming pass: Damage → Spellpower, Move
  Speed → Swiftness, Magnet Range → Gleam, Backpack Capacity →
  Bearing, Purge → Discard, and the five Compacting tiers → Commons
  Hoard / Uncommon Stash / Rare Vault / Epic Trove / Mythic Hoard.

## v5 - 2026-08-15

The game has a name and a look: **Hoard Survivors**, restyled top to
bottom with a cosmic/magic aesthetic in place of the placeholder
dungeon look and generic UI text.

- Full menu system redesign: procedural night-sky backdrop (gradient,
  twinkling stars, mountain silhouette) and a rotating magic-circle
  motif replace the flat dark panels on the main menu, Run Prep, Load
  Game, and Shop screens. Buttons switched from box-styled to
  text-link style (gold on hover, with flourish lines), matching a
  reference screenshot.
- Skill tree redesigned from square medieval-framed nodes to circular
  chained nodes with per-tree accent colors, glow states for
  purchased/maxed tiers, vector icons per stat, and a hover tooltip
  showing each upgrade's name, description, level, and cost.
- Scene changes fade through black instead of hard-cutting; combat
  got floating damage numbers, hit-stop + weightier screen shake on
  player hit/death, an animated HP/loot bar, and a purchase-pulse
  effect on skill tree nodes.
- Procedural SFX for hits, deaths, pickups, dashes, purchases, and UI
  clicks — the project had no audio at all before this.
- Arena reskinned: the dungeon floor tileset is replaced by a
  procedural space backdrop (nebula washes, stars, no grid), with
  drifting ambient magic particles and a radial vignette. Player
  sprite swapped from a knight to a wizard; loot swapped from a
  spinning coin to a procedurally-drawn faceted gem tinted by rarity.
- Renamed the placeholder currency/stat text DESIGN.md flagged: Player
  Currency → Essence, Backpack Currency → Stardust, Compactor tiers →
  "<Tier> Binding", Shop → Sanctum, and the death screen restyled to
  match (border/text color, magic-circle decor, "Lost to the Void").
- Added a back button to the skill tree/shop screen and fixed a
  scene-change crash in the auto-load path on the main menu.

## v4 - 2026-08-14

Second round of parallel mechanics + visuals workstreams merged into
`main`:

- Loot reworked into six rarity tiers (common → legendary) matching
  DESIGN.md's table exactly: per-tier drop weight, stack size, and
  value. Backpack is a real slot grid (one slot per item type held),
  colored by rarity, replacing the old flat-count/abstract-bar model.
- Meta-progression split into two currencies: player currency (from
  loot value) funds Damage/Move Speed/Magnet Range; backpack currency
  (from time survived) funds Backpack Capacity. Upgrades are now
  leveled with a geometric cost curve and a hard level cap, replacing
  the old flat/uncapped cost.
- Damage and Move Speed are upgradeable stats for the first time
  (previously hardcoded constants).
- Player dash (spacebar), fixed a bug where loot the player couldn't
  actually hold still got magnet-pulled toward them.
- Real sprite art throughout (0x72 DungeonTilesetII), replacing all
  placeholder procedural shapes; Player extracted into its own scene.
- `/play`, `/close`, `/editor` slash commands for the run loop.

## v3 - 2026-08-14

First result of two parallel workstreams (core mechanics + visuals/UI,
each in its own git worktree) merged into `main`:

- Player stats reworked into a generic, data-driven system (`StatDef`
  + `MetaProgression`): upgrades are registered once and read
  generically by the shop and HUD, rather than hardcoded per stat.
- In-run stats readout (speed, pickup range, backpack capacity)
  confirming shop purchases carried into the next run.
- HUD rebuilt with styled panels, color-graded HP/backpack bars
  (`StatBar`), and a proper game-over panel with a styled continue
  button.
- Shared `.tres` style resources for panels/buttons instead of
  duplicated inline styles.
- Visual polish: drop shadows/outlines on player/enemy/loot, particle
  effects on hits/deaths/pickups, loot now pulls toward the player
  (magnet-style) instead of an instant pickup.

## v2 - 2026-08-14

Full MVP core loop from DESIGN.md, playable end to end:

- Top-down player movement in a bounded arena.
- Auto-attack combat against a chasing enemy type; contact damage.
- Player HP with a run-ending death state.
- Loot drops on kill, proximity-based pickup (upgradeable pickup range).
- Capacity-limited backpack; fill % shrinks max HP (the core
  risk/reward tension).
- Difficulty ramp: enemy spawn rate/HP/speed scale over the run.
- Run summary screen showing loot collected.
- Meta-currency (1:1 from loot), a shop to spend it on backpack
  capacity and pickup-range upgrades, and a run-restart flow that
  carries those upgrades into the next run.

## v1 - 2026-08-14

- Initial Godot 4.4 project scaffold
- Minimal main scene with version label
- Established tag + VERSION/CHANGELOG release model
