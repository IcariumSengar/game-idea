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
7. Loot converts to currency, spent in a shop between runs on permanent
   upgrades to the player and the backpack.
8. Next run starts fresh (arena/enemies reset), but with the upgrades
   carried over — this is the meta-progression hook that makes each run
   start slightly further than the last.

Inspiration: iteration/roguelite games with quick runs + a meta-upgrade
loop between them (the genre Vampire Survivors popularized).

## Current implementation

What's actually built and playable today (see `scripts/`, as of v4):

- Top-down movement + dash in a single arena; one enemy type that chases
  and damages the player on contact, spawning faster/more over run
  duration.
- One weapon, auto-firing at the nearest enemy; Damage is upgradeable.
- Six rarity tiers (`loot_registry.gd`/`loot_type.gd`), numbers matching
  the Rarity tiers table below. One item drops per kill, tier rolled by
  drop weight, picked up via a proximity-based magnet radius (Magnet
  Range upgradeable).
- A real slot-grid backpack (`backpack_grid.gd`) — one slot per loot
  type held, colored by rarity, growing with Capacity; fill % shrinks
  max HP.
- Two currencies (`meta_progression.gd`): player currency (loot value)
  funds Damage/Move Speed/Magnet Range; backpack currency (survival
  time) funds Capacity. Upgrades are leveled with a geometric cost curve
  and a hard level cap — matches this doc's numbers for Damage, Move
  Speed, and Magnet Range. **Capacity is the one exception**: it's still
  flat-cost and effectively uncapped (level cap 999) in code, not yet
  updated to the ×1.20/lvl-growth, 12-level-cap curve this doc specifies.
- Death → run summary → shop (flat list of upgrade buttons, not yet the
  skill-tree layout below) → restart with upgrades carried over.
- Persistence: 4 save slots available; player selects a slot at game start to
  load/overwrite progress. Save data cloud-syncs for cross-device access.

Not yet built: Compacting (per-tier), Purge, and the skill-tree shop
layout — see [TODO.md](TODO.md) for the remaining build order.

## Loot, backpack & shop economy

Numbers throughout are illustrative placeholders for tuning later, not
final balance — the shapes and relationships (what scales with what) are
the actual decisions being locked in.

### Two currencies: player track vs. backpack track

Shop upgrades split across two independent currencies with two different
income sources, so player-power progression and backpack progression run
at different cadences instead of competing for the same pool:

- **Player currency** — earned from loot value collected during the run
  (the same value scale as the rarity table below). Funds player stats:
  damage, movement speed, and magnet/pickup range.
- **Backpack currency** — earned from time survived in the run,
  independent of what got picked up. Funds backpack-only upgrades: slot
  capacity, per-tier Compacting, and Purge.

Placeholder rate: `backpack_currency = round(1 × seconds_survived)` — 1
currency per second alive, banked at run end. Picked only so there's
something to build against; needs playtesting to find a pace that
actually feels rewarding.

The two tracks aren't directly linked, but both still answer to the same
core risk mechanic: a greedy loot run fills the bag (shrinking max HP)
and likely ends the run sooner, trading backpack-currency income for
player-currency income. A cautious, loot-light run does the opposite. So
"which track am I feeding this run" becomes part of the moment-to-moment
risk decision, not just a shop-screen choice.

Currency names are placeholders for now ("player currency" / "backpack
currency") — real names TBD once the theme is more settled.

### Shop structure: skill tree

The shop is two skill trees, one per currency, shown side by side —
reinforcing the two-currency split visually as well as economically.

- **Backpack Tree** is a real chain: Capacity sits at the root (always
  purchasable). Compactor nodes unlock in rarity order — Common →
  Uncommon → Rare → Epic → Mythic — each locked until the previous tier's
  compactor has at least one level bought. Purge unlocks the same way, as
  a capstone gated behind the Rare Compactor's first level — reusing the
  same "previous node bought once" gate as everything else rather than a
  separate threshold rule. This resolves the earlier open question about
  Compacting's purchase order: it's a hard gate now, enforced by the
  tree, not just a cost-driven nudge.
- **Player Tree** is flatter: Damage, Move Speed, and Magnet Range branch
  independently off a shared root with no cross-gating between them,
  since nothing in the design requires one before another.
- Each node keeps its existing leveled/capped cost curve (see tables
  above and below) — a node isn't one-shot, it has an internal level
  track up to its cap, bought incrementally at the geometric cost per
  level. The tree adds gating and visual structure on top of the
  existing economy, not a new cost model.

Left open for later: mutually exclusive branches / specializations (e.g.
a fork trading Damage for AoE, or another build-defining choice) would be
a real scope addition — new stat types, and some tension with "everything
is eventually maxable" since an exclusive pick means a run commits to a
build rather than a straight completion path. Not doing this now; the
current tree has no exclusive choices, just gating and layout — the door
is intentionally left open to add them later.

### Player-stat upgrade curve

Goal: the game should feel like *very slow* growth in power, run over run —
cheap early gains that quickly become expensive, with a visible ceiling per
stat rather than infinite grinding.

- **Cost grows geometrically per level**: `cost(level) = round(base_cost ×
  growth_rate ^ level)`. This is the actual source of the "slow" feel —
  the first level or two is cheap and comes fast, but cost snowballs so
  each later level takes meaningfully longer to afford.
- **Effect stays flat/additive per level** (a constant amount added per
  level, not a compounding %). Flat power growth against exponential cost
  growth is what produces a decelerating curve instead of a snowball.
- **Each stat is capped** at a fixed level count — a real ceiling, so
  maxing a stat is a visible, earned milestone rather than an open-ended
  number. (Decided over the uncapped/endless alternative.)

First-pass numbers (illustrative — grounded in current code values, not
final balance):

| Stat | Base | Per-level gain | Base cost | Cost growth | Level cap | Value at cap |
|---|---:|---:|---:|---:|---:|---:|
| Damage | 20 | +2 (10% of base) | 15 | ×1.15/lvl | 20 | 60 (3×) |
| Move Speed | 250 | +10 (4% of base) | 15 | ×1.18/lvl | 10 | 350 (1.4×) |
| Magnet Range | 60 | +8 (13% of base) | 12 | ×1.15/lvl | 15 | 180 (3×) |

Move Speed gets the smallest relative gain and the steepest cost growth on
purpose — it's the stat most likely to trivialize difficulty or feel bad
if overtuned, and it also feeds the knockback-decay math in
`scripts/player.gd`, so pumping it has knock-on effects beyond raw
mobility. Damage and Magnet Range get more room to grow since
overinvesting in them is safer. As a rough pacing check: fully maxing
Damage alone (20 levels, geometric sum) comes out to roughly 1,500
currency total — meant to take many runs, not a handful.

Built: `StatDef`/`MetaProgression` now support geometric cost curves and a
hard level cap, and Damage/Move Speed/Magnet Range are wired up with the
exact numbers above.

### Backpack-track upgrade curve

Same framework as the player track — geometric cost growth, flat/additive
effect per level, capped levels — applied to backpack currency instead.
Backpack Capacity gets its own table here; Compacting and Purge (already
tier/threshold-shaped) get their leveled cost curves in their own
sections below.

| Stat | Base | Per-level gain | Base cost | Cost growth | Level cap | Value at cap |
|---|---:|---:|---:|---:|---:|---:|
| Backpack Capacity | 8 slots | +1 slot | 20 | ×1.20/lvl | 12 | 20 slots (2.5×) |

Capacity gets the steepest cost growth of any single stat in the game —
it's the most directly impactful number for survival (more slots means
more headroom before the fullness/HP-shrink curve bites), so it's
deliberately the slowest one to fully grind out.

The slot-grid backpack itself is built (`backpack_grid.gd`), but the
Capacity stat's numbers in `scripts/meta_progression.gd` haven't caught
up to this table yet — it currently registers as `base_value: 1.0`,
`per_level_gain: 1.0`, flat cost (`cost_growth: 1.0`), and an effectively
uncapped `level_cap: 999`. Bringing it in line with the 8/+1/×1.20/cap-12
numbers above is outstanding work, not a design question.

**Fill %** = slots used ÷ total slots — a slot counts as "used" the
moment it holds one or more of an item, regardless of how full its stack
is. So one Common and a maxed-out 192-stack of Commons both count as
exactly one used slot; only the *number of occupied slots* drives
fullness, not how densely packed they are. This is what feeds the
existing HP-shrink formula (`max_hp = base_max_hp × lerp(1.0,
MIN_HP_FRACTION, fill%)` in `scripts/player.gd`) — the formula itself
doesn't change, only what `fill%` is computed from.

### Rarity tiers

Loot comes in six rarity tiers. Three things scale per tier, and they're
the whole point of the system: drop weight goes *down*, while base value
and per-slot value go *up* — so rarer loot is rare, worth more, and a
real space gamble, all at once.

| Tier      | Drop weight | Base stack size | Base value/item | Full-slot value | Color  |
|-----------|------------:|-----------------:|-----------------:|------------------:|--------|
| Common    | 50%         | 64                | 1                 | 64                 | White  |
| Uncommon  | 27%         | 32                | 3                 | 96                 | Green  |
| Rare      | 14%         | 16                | 10                | 160                | Blue   |
| Epic      | 6%          | 8                 | 40                | 320                | Purple |
| Mythic    | 2.5%        | 4                 | 150               | 600                | Orange |
| Legendary | 0.5%        | 1                 | 800               | 800                | Red    |

Every enemy kill drops exactly one loot item; its tier is rolled
independently each time using the Drop weight column above. Weights are
flat for now — not adjusted by difficulty, time survived, or enemy type
— that's a lever to pull later if the drop curve needs shaping.

"Full-slot value" is what one fully-stacked slot of that tier is worth
(`base value/item × base stack size`). It climbs every tier despite stack
size shrinking — that's the "value must outpace space cost" rule made
concrete, and the sanity check for balancing: if a lower tier's full-slot
value ever beats a higher tier's, that tier isn't worth picking up over
the cheaper one.

Drop weight, stack size, and value are three independent tuning knobs and
don't have to move in lockstep — this table is a first-pass shape, not a
locked formula.

### Loot → currency conversion

At run end, player currency earned is the sum of each collected item's
**base value/item** (from the table above), for whatever is still in the
backpack when the run ends:

`player_currency = Σ (count_in_backpack[tier] × base_value/item[tier])`
across all six tiers.

This uses base value/item, not "full-slot value" — full-slot value in the
rarity table is only a balancing sanity-check (what one maxed-out slot is
worth), not the conversion formula itself.

Only loot still in the backpack at the moment of death counts. Anything
discarded mid-run by the Purge upgrade is gone — its value is never
banked. That makes Purge a genuine trade, not a free safety net: it buys
more survival time (and so more backpack currency) at the cost of the
player currency those discarded items would have been worth. Backpack
currency itself (from survival time) is entirely separate and unaffected
by any of this — see Two Currencies above.

Worked example (illustrative): a run ends with 40 Commons, 10 Uncommons,
3 Rares, and 1 Epic still in the bag →
`40×1 + 10×3 + 3×10 + 1×40 = 140` player currency. Against the Damage
curve (base cost 15, ×1.15/lvl), that covers the first several levels of
one stat — a reasonable early pace, a few runs to a first couple of
upgrades.

### Compacting upgrades

A **separate upgrade per rarity tier, Common through Mythic**, each
raising that tier's max stack size (e.g. Common Compactor lvl 1: 64 → 96,
lvl 2: 96 → 128 — several levels per tier for a granular shop ladder).
Compacting never touches item value, only how many of that tier fit in
one slot.

**Legendary is permanently uncompactable** — no compactor exists for it,
stack size stays 1 forever. It's the one item that always eats a whole
slot on its own, by design: that's the top-tier risk/reward tension the
whole rarity system is built around, and it shouldn't be tunable away.

Purchase order follows the rarity ladder — common compactor first,
mythic compactor last — because relevance follows the drop curve:
commons flood the bag from the first run, so a common compactor pays off
immediately and keeps paying off for a long stretch, while a mythic
compactor is nearly irrelevant until mythics are dropping often enough
for stack depth to matter at all. In the skill-tree shop (see above)
this is a **hard gate**: each Compactor node is locked until the
previous tier's node has at least one level bought, not just nudged by
price.

Per-tier cost curve (illustrative):

| Compactor | Base stack | Per-level gain | Base cost | Cost growth | Level cap | Stack at cap |
|---|---:|---:|---:|---:|---:|---:|
| Common | 64 | +16 | 8 | ×1.10/lvl | 8 | 192 (3×) |
| Uncommon | 32 | +8 | 15 | ×1.12/lvl | 6 | 80 (2.5×) |
| Rare | 16 | +4 | 25 | ×1.14/lvl | 5 | 36 (2.25×) |
| Epic | 8 | +2 | 40 | ×1.16/lvl | 4 | 16 (2×) |
| Mythic | 4 | +1 | 70 | ×1.18/lvl | 3 | 7 (1.75×) |
| Legendary | 1 | — | — | — | — | 1 (never stacks) |

Base cost and growth rate also climb with rarity on top of the gate
itself, so even a player who's unlocked a later node still feels the
common-first pull through price.

### Purge upgrade

A single, late-game upgrade: once bag fill crosses a threshold (e.g.
90%), automatically discards the lowest-rarity item(s) to free space
instead of blocking further pickups. Only becomes relevant once slot
count and stack depth (via Compacting) are both near their ceiling and
fullness is still the thing killing runs — a last safety valve after the
other two upgrade paths are mostly exhausted, not a substitute for them.

Leveled via its trigger threshold rather than a flat on/off:

| Purge level | Trigger threshold | Cost |
|---|---:|---:|
| 1 | 90% fill | 100 |
| 2 | 85% fill | 130 |
| 3 | 80% fill | 169 |
| 4 | 70% fill | 220 |

(cost growth ×1.30/lvl off a base of 100 — few levels, steep growth,
matching its role as a rare late-game purchase rather than a routine
one). Always discards the single lowest-rarity item over the threshold;
which tiers it's willing to sacrifice isn't a separate axis for now, just
the threshold.

### Backpack UI

The backpack should be visible on-screen as a real slot grid
(Minecraft-style), not an abstract fill bar. This makes upgrades
self-explanatory in play: Compacting is *seen* as a stack climbing
higher in the same slot, Capacity is *seen* as the grid growing, and
rarity is *seen* via the color-coded item border from the table above.
Fill% and HP shrink should feel visually linked (e.g. slots trending red
as the bag nears full, in sync with the HP bar draining) so the core risk
mechanic reads at a glance without any tutorial text. Longer-term idea:
show locked/ghost slots for not-yet-purchased capacity, so the next shop
upgrade is previewable right in the HUD.

## Decisions log

Short dated entries when a design decision is made and worth remembering
*why*, not just what:

- 2026-08-14 — Project scaffolded, no gameplay decisions yet.
- 2026-08-14 — Core concept locked: top-down auto-attack roguelike,
  backpack-fill-reduces-max-HP as the core risk/reward mechanic,
  loot-funds-backpack-upgrades as the meta-progression loop.
- 2026-08-14 — Initial build scoped to one enemy type, one loot type, one
  weapon, one meta-upgrade (capacity) — full loop before any variety.
- 2026-08-14 — Loot pickup is proximity-based (a magnet-range Area2D on
  the player), not exact-overlap — and that pickup range is itself an
  upgradeable stat, so the shop now covers capacity + pickup range rather
  than capacity alone.
- 2026-08-14 — Sketched a loot-rarity + slot-based-backpack direction:
  six rarity tiers, stack-size limits that shrink with rarity so rarer
  loot costs more space, and two new upgrade types (per-tier Compacting,
  late-game Purge). Not built yet — the flat-count backpack ships first.
- 2026-08-14 — Fleshed out the rarity table with illustrative numbers
  (drop weight, stack size, value/item per tier) and detailed how
  Compacting (per-tier stack-size upgrade) and Purge (late-game
  auto-discard) are meant to work. Open question on whether tier unlock
  order for Compacting is a hard gate or just cost-driven.
- 2026-08-14 — Split the shop into two currencies: player currency (from
  loot value → funds damage/speed/magnet) and backpack currency (from
  time survived → funds capacity/Compacting/Purge). Magnet/pickup range
  moves from the backpack track to the player track. Backpack-currency
  rate left open, needs playtesting.
- 2026-08-14 — Defined the player-stat upgrade curve: geometric cost
  growth per level, flat/additive effect per level, capped level ladder
  per stat (chosen over uncapped/endless) so growth feels slow and each
  stat has a visible max. First-pass numbers for Damage, Move Speed, and
  Magnet Range logged above. Noted `StatDef`/`MetaProgression` currently
  only support flat, uncapped costs — a small code change needed later to
  support this curve.
- 2026-08-14 — Extended the same geometric-cost/capped-level curve to the
  backpack track: Capacity gets the steepest cost growth of any stat
  (it's the single most survival-critical number), each rarity's
  Compactor gets its own per-tier curve (cost/growth climb with rarity,
  reinforcing the intended common-first purchase order), and Purge is
  leveled via a shrinking trigger threshold (90% → 70%) rather than a
  flat on/off.
- 2026-08-14 — Resolved the open Legendary question: Legendary is
  permanently uncompactable/unstackable, stack size 1 forever, no
  compactor tier for it. Keeps the top-tier risk/reward tension (a
  legendary always eats a whole slot) from ever being tuned away.
- 2026-08-14 — Dropped the "MVP / post-MVP" scope framing. Scope is still
  being actively worked out rather than locked, so the doc now just
  separates "Current implementation" (what's built) from the evolving
  design direction, without a fixed in-scope/out-of-scope commitment
  list.
- 2026-08-14 — Shop reframed as two skill trees (one per currency), same
  numbers/stats as before, no new mechanics yet. Backpack Tree makes
  Compacting's rarity-first purchase order a hard gate (resolves the
  earlier open question); Player Tree stays flat/ungated since Damage,
  Move Speed, and Magnet Range have no real dependency on each other.
  Deliberately not adding mutually exclusive branches/specializations
  yet — noted as a door left open for later, since it would be a real
  scope addition and cuts against "everything is eventually maxable."
- 2026-08-14 — Made the loot→currency conversion explicit: player
  currency = sum of base value/item across whatever's still in the
  backpack at death (not full-slot value, which is only a balancing
  check). Confirmed "loot types" means the six rarity tiers already
  defined, not separate named items. Decided items discarded by Purge
  are lost, not banked — makes Purge a real trade between survival time
  (backpack currency) and the player currency those items would've been
  worth, rather than a free safety net.
- 2026-08-14 — Filled remaining gaps found in a scope audit: gave
  backpack currency a placeholder rate (1/sec, needs playtesting),
  restated the slot-grid fill% formula (slots used ÷ total slots,
  binary per slot regardless of stack fullness) which had dropped out
  during an earlier tightening pass, confirmed drop is one item per
  kill with tier rolled from the flat drop-weight table, and gave Purge
  a concrete unlock gate (behind the Rare Compactor's first level)
  instead of a vague "some threshold."
- 2026-08-14 — Reconciled DESIGN.md with reality: parallel worktree
  sessions had already shipped v4 while this design conversation was
  running, implementing rarity tiers, the slot-grid backpack, the
  two-currency split, and Damage/Move Speed/Magnet Range as upgradeable
  stats — matching this doc almost exactly. Updated "Current
  implementation" and the stale "not yet built" notes accordingly.
  One real gap found: Backpack Capacity's cost curve in
  `meta_progression.gd` (flat cost, uncapped) hasn't caught up to this
  doc's ×1.20/lvl, 12-level-cap numbers — noted as outstanding work, not
  a design question. Remaining undone: Compacting, Purge, and the
  skill-tree shop layout.
- 2026-08-14 — Save/load persistence redesigned: 4 save slots (player
  selects at start), cloud-sync for cross-device access. Enables
  meaningful progression testing and supports casual play patterns where
  a player might have multiple simultaneous run series.
