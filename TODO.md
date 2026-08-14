# TODO

Lightweight backlog. Not every idea needs to live here — just things worth
not forgetting between sessions. Check items off or delete them once done;
this file should stay short enough to skim.

## Now

Build order for the MVP loop (see DESIGN.md) — each step should be
playable/checkable on its own before moving to the next:

- [x] Player: top-down movement in an arena
- [x] Enemy: single type that spawns and chases the player
- [x] Combat: auto-attack fires at nearest enemy; enemies damage player on
      contact
- [x] Player HP + death → run-end state
- [x] Loot: drops on enemy death, picked up by player (proximity-based,
      via an upgradeable pickup-range stat)
- [x] Backpack: capacity + fill %, max HP shrinks with fill %
- [x] Enemy spawn rate/difficulty ramps over run duration
- [x] Run summary screen (loot collected this run)
- [x] Meta-currency conversion + minimal shop (capacity + pickup range)
- [x] Run restart flow: new run, upgraded stats carried over
- [ ] Persist meta-progression between sessions (save/load)

## Later

- Multiple enemy/loot types, weapon variety, more meta-upgrades (out of
  scope for MVP — see DESIGN.md)

## Done

- [x] Godot 4 project scaffold, versioning workflow, engineering practices (v1)
- [x] Dev environment: Godot Tools VS Code extension, gdformat/gdlint
- [x] Core concept + MVP scope decided (see DESIGN.md)
