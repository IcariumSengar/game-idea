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
- Meta-currency conversion + a minimal shop: backpack capacity and
  pickup range upgrades.
- Run restart flow with upgraded stats carried over; everything else in
  the arena resets.
- Meta-progression persists between play sessions (currency, purchased
  upgrades saved to disk).

**Explicitly out of scope (for now):**
- Multiple enemy/loot types and rarities.
- Multiple weapon types or weapon upgrades/evolutions.
- Additional meta-upgrades beyond backpack capacity and pickup range.
- Art/animation polish, sound, music.
- Multiple arenas/levels.

Revisit this list as the prototype clarifies what the game actually needs.
The goal is the full loop working end-to-end and *feeling* right before
adding any variety on top of it.

## Post-MVP direction: loot rarity & backpack economy (tentative)

Not yet in scope — MVP ships with one loot type first. Captured here so the
direction isn't lost; details likely to change as the MVP proves out.

- Loot gets six rarity tiers: common, uncommon, rare, epic, mythic,
  legendary. Drop weighting falls off sharply per tier (each tier much
  rarer than the last).
- Backpack becomes a Minecraft-style slot grid rather than an abstract
  capacity number. Fill % = slots used / total slots, so players can see
  the bag filling tile by tile.
- Each rarity tier has its own max stack size per slot, shrinking as
  rarity increases (commons stack deep, legendaries stack little/not at
  all). This means rarer loot inherently takes up more backpack space per
  item — no separate "bulk" rule needed, it falls out of the stack model.
- Loot value (what it converts to in meta-currency at run end) scales up
  with rarity, and that value scaling needs to outpace the space-cost
  scaling — otherwise rarer loot stops feeling like a good gamble and just
  becomes a tax on fullness. Curve shape matters more than exact numbers.
- **Compacting upgrades**: raise the max stack size for one specific
  rarity tier. Unlockable per-tier in the shop, and meant to be unlocked
  in tier order (common first) — since low-tier loot floods the bag
  constantly, a common compactor stays useful for a long stretch, while a
  legendary compactor only starts mattering once legendaries show up
  often enough (i.e. once earlier tiers stop being the bottleneck).
- **Purge upgrade**: auto-discards lowest-rarity loot once the bag nears
  full. Intended as a super-late-game unlock — only relevant once slot
  count and stack depth are both near their ceiling and fullness is still
  the thing killing you.
- **UI**: the backpack should be visible on-screen as a real slot grid
  (Minecraft-style), not an abstract fill bar. This makes upgrades
  self-explanatory in play: Compacting is *seen* as a stack climbing
  higher in the same slot, Capacity is *seen* as the grid growing, and
  rarity is *seen* via a color-coded item border (common → legendary).
  Fill% and HP shrink should feel visually linked (e.g. slots trending
  red as the bag nears full, in sync with the HP bar draining) so the
  core risk mechanic reads at a glance without any tutorial text.
  Longer-term idea: show locked/ghost slots for not-yet-purchased
  capacity, so the next shop upgrade is previewable right in the HUD.

## Decisions log

Short dated entries when a design decision is made and worth remembering
*why*, not just what:

- 2026-08-14 — Project scaffolded, no gameplay decisions yet.
- 2026-08-14 — Core concept locked: top-down auto-attack roguelike,
  backpack-fill-reduces-max-HP as the core risk/reward mechanic,
  loot-funds-backpack-upgrades as the meta-progression loop.
- 2026-08-14 — MVP scoped to one enemy type, one loot type, one weapon,
  one meta-upgrade (capacity) — full loop before any variety.
- 2026-08-14 — Loot pickup is proximity-based (a magnet-range Area2D on
  the player), not exact-overlap — and that pickup range is itself an
  upgradeable stat, so the meta-shop now covers capacity + pickup range
  rather than capacity alone.
- 2026-08-14 — Sketched a tentative post-MVP direction for loot rarity and
  a slot-based backpack (see section above): six rarity tiers, stack-size
  limits that shrink with rarity so rarer loot costs more space, and two
  new upgrade types (per-tier Compacting, late-game Purge). Not committed
  scope yet — MVP still ships with one loot type first.
