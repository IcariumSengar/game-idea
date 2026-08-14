# TODO

Lightweight backlog. Not every idea needs to live here — just things worth
not forgetting between sessions. Check items off or delete them once done;
this file should stay short enough to skim.

## Now

- [ ] Persist meta-progression between sessions (save/load)

## Later

Design direction is fleshed out in DESIGN.md; scope/order for building it
is still being worked out. Rough shape of what's next:

- Loot rarity tiers + slot-grid backpack (Compacting, Purge upgrades) —
  see DESIGN.md
- Split the shop into two currencies (player track vs. backpack track) —
  see DESIGN.md
- Wire Damage and Move Speed into `MetaProgression` as upgradeable stats
  (currently hardcoded consts in `weapon.gd`/`player.gd`) — see DESIGN.md
- Geometric cost curve + level caps for `StatDef`/`MetaProgression`
  (currently flat-cost, uncapped) — see DESIGN.md

## Done

- [x] Godot 4 project scaffold, versioning workflow, engineering practices (v1)
- [x] Dev environment: Godot Tools VS Code extension, gdformat/gdlint
- [x] Core concept + initial scope decided (see DESIGN.md)
- [x] Core loop built end-to-end: movement, one enemy, auto-attack combat,
      HP/death, proximity loot pickup, backpack fill/HP-shrink, difficulty
      ramp, run summary, currency + shop (capacity/pickup range), run
      restart with carried-over upgrades (v2)
