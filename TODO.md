# TODO

Lightweight backlog. Not every idea needs to live here — just things worth
not forgetting between sessions. Check items off or delete them once done;
this file should stay short enough to skim.

## Now

- [ ] Persist meta-progression between sessions (save/load)

## Later

Next playable iteration: the full economy in DESIGN.md is a lot bigger
than what's built today, so build it in stages rather than all at once —
each stage should leave the game playable/checkable before the next
starts. Order follows dependencies (later stages read data the earlier
ones define):

1. **Rarity + slot-grid backpack** — six rarity tiers, drop-weight roll on
   kill (one item per kill), stack sizes per tier, fill% = slots used ÷
   total slots feeding the existing HP-shrink formula. Replaces today's
   flat-count backpack. See DESIGN.md: Rarity tiers, Backpack UI.
2. **Two-currency split** — player currency (loot value → Damage/Speed/
   Magnet) and backpack currency (survival time, placeholder 1/sec →
   Capacity/Compacting/Purge). Needs stage 1's rarity values for the
   loot→currency conversion. See DESIGN.md: Two currencies, Loot →
   currency conversion.
3. **Player-stat upgrade curve** — wire Damage and Move Speed into
   `MetaProgression` as upgradeable stats (currently hardcoded consts in
   `weapon.gd`/`player.gd`); geometric cost curve + level caps for
   `StatDef`/`MetaProgression` (currently flat-cost, uncapped). Mostly
   independent of the other stages, could slot in earlier if convenient.
4. **Skill-tree shop UI** — reorganize the shop into the two-tree layout
   (Backpack Tree hard-gated by rarity order, Player Tree flat) instead
   of the current flat button list. A presentation layer on top of
   stages 2-3.
5. **Compacting (per-tier) + Purge** — the deepest, most granular content;
   naturally last since each tier's Compactor only matters once that
   tier is dropping often enough to care about.

## Done

- [x] Godot 4 project scaffold, versioning workflow, engineering practices (v1)
- [x] Dev environment: Godot Tools VS Code extension, gdformat/gdlint
- [x] Core concept + initial scope decided (see DESIGN.md)
- [x] Core loop built end-to-end: movement, one enemy, auto-attack combat,
      HP/death, proximity loot pickup, backpack fill/HP-shrink, difficulty
      ramp, run summary, currency + shop (capacity/pickup range), run
      restart with carried-over upgrades (v2)
