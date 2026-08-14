# TODO

Lightweight backlog. Not every idea needs to live here — just things worth
not forgetting between sessions. Check items off or delete them once done;
this file should stay short enough to skim.

## Now

- [ ] Implement save/load system with 4 save slots and cloud-sync
  - [ ] Save slot data structure: track per-slot meta-progression, last-played timestamp, playtime
  - [ ] Load Game screen UI: show all 4 slots with metadata (last played, playtime, max upgrades), load/overwrite/delete actions
  - [ ] Save on run end (shop screen) and graceful quit; local file storage with cloud-sync ready
  - [ ] Cloud-sync backend: optional email-based device linking, last-write-wins conflict resolution, sync on run-end + quit
  - [ ] Offline support: saves work fully offline, sync is best-effort when connection returns

## Later

Most of the economy redesign in DESIGN.md shipped already (v4, via
parallel worktree sessions) — rarity tiers, the slot-grid backpack, the
two-currency split, and Damage/Move Speed/Magnet Range as upgradeable
stats. What's actually left:

1. ~~**Fix Backpack Capacity's upgrade curve**~~ — Done. Now uses
   ×1.20/lvl geometric growth with 12-level cap per DESIGN.md.
2. **Skill-tree shop UI** — reorganize the shop (`shop.gd`, currently a
   flat button list) into the two-tree layout: Backpack Tree hard-gated
   in rarity order, Player Tree flat/ungated. See DESIGN.md: "Shop
   structure: skill tree."
3. **Compacting (per-tier) + Purge** — not started. Six per-tier
   Compactor upgrades (Common through Mythic; Legendary is permanently
   uncompactable) plus the Purge capstone, gated behind the Rare
   Compactor per the skill tree. See DESIGN.md: "Compacting upgrades",
   "Purge upgrade".

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
