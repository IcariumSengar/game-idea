# Design

A short, evolving record of design decisions — what the game actually is,
not just how it's built (that's CLAUDE.md). Update this as decisions get
made; don't try to fill it in all at once upfront.

## Genre

Top-down, Vampire Survivors-like roguelike. Auto-attack combat — the
player's only input is movement/positioning, weapons fire automatically at
nearby enemies.

## Core loop

1. Run starts in an arena. Enemies spawn continuously and get harder /
   more plentiful the longer the run goes on.
2. Player auto-attacks nearby enemies and kills them; kills drop loot.
3. Loot is picked up into a capacity-limited **backpack**.
4. As the backpack fills up, **max HP shrinks** proportionally to fill %
   — the fuller the bag, the more fragile the player is. This is the
   core risk/reward tension: keep collecting loot vs. survive.
5. Death is inevitable — there's no "win" state within a run, just how
   much you collect before it happens.
6. Run ends in a **summary screen**: loot collected this run.
7. Loot converts to a **meta-currency**, spent in a shop between runs on
   permanent **backpack upgrades** (starting with: increased capacity).
8. Next run starts fresh (arena/enemies reset), but with the upgraded
   backpack — more capacity means more time to collect loot before the
   HP-shrink curve kills you. This is the meta-progression hook that
   makes each run start slightly further than the last.

Inspiration: iteration/roguelite games with quick runs + a meta-upgrade
loop between them (the genre Vampire Survivors popularized).

## Scope

**In scope (MVP — a playable version of the core loop):**
- Top-down player movement in a single arena.
- Auto-attack: one weapon type, fires at the nearest enemy automatically.
- One enemy type that chases the player; spawn rate/difficulty ramps
  over run duration.
- Player HP; damage on enemy contact.
- One loot type, dropped on enemy death, auto-picked-up or picked up on
  proximity.
- Backpack: capacity-limited loot storage; fill % shrinks max HP.
- Death when HP <= 0 → run-end state.
- Run summary screen (loot collected).
- Meta-currency conversion + a minimal shop: one upgrade
  (backpack capacity).
- Run restart flow with upgraded stats carried over; everything else in
  the arena resets.
- Meta-progression persists between play sessions (currency, purchased
  upgrades saved to disk).

**Explicitly out of scope (for now):**
- Multiple enemy/loot types and rarities.
- Multiple weapon types or weapon upgrades/evolutions.
- Additional meta-upgrades beyond backpack capacity.
- Art/animation polish, sound, music.
- Multiple arenas/levels.

Revisit this list as the prototype clarifies what the game actually needs.
The goal is the full loop working end-to-end and *feeling* right before
adding any variety on top of it.

## Decisions log

Short dated entries when a design decision is made and worth remembering
*why*, not just what:

- 2026-08-14 — Project scaffolded, no gameplay decisions yet.
- 2026-08-14 — Core concept locked: top-down auto-attack roguelike,
  backpack-fill-reduces-max-HP as the core risk/reward mechanic,
  loot-funds-backpack-upgrades as the meta-progression loop.
- 2026-08-14 — MVP scoped to one enemy type, one loot type, one weapon,
  one meta-upgrade (capacity) — full loop before any variety.
