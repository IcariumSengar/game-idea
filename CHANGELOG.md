# Changelog

All notable fixed versions of this project are documented here.

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
