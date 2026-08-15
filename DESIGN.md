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

## Save/Load system

### Slot-based saves (4 slots)

Players see a "Load Game" screen on startup showing all 4 available slots. Each slot displays:
- **Slot number** (1–4)
- **Last played date** (e.g., "2 hours ago", "never")
- **Total playtime** (hours accumulated in that save)
- **Current max upgrades** (quick preview: Damage lv X, Capacity lv Y, etc.)
- **Action buttons**: Load, Overwrite (grayed if empty), Delete

Empty slots show "Empty — Start new run" and load defaults. Occupied slots show current progress and let players quickly switch between parallel save series (e.g., "speed-run focused" vs. "greedy loot-stacking" playstyles).

### Cloud sync

**Scope:** Meta-progression only (upgrade levels, currencies, unlock state). Not run history or stats yet — those are nice-to-have later additions.

**Sync point:** On run end (when shop screen appears) and on graceful quit. Saves work fully offline; sync is best-effort when connection returns.

**Conflict resolution:** Last-write-wins. If two devices save simultaneously and conflict, the most recent by server timestamp overwrites the older one. Future: if conflicts become frequent, show a merge dialog letting players pick which device's version to keep.

**Device binding:** Optional — player can link their email (icarium.sengar@gmail.com as default) to enable cloud sync. If unlinked, saves stay local-only.

## Current implementation

What's actually built and playable today (see `scripts/`, as of v6):

- Top-down movement + dash in a single arena; one enemy type that chases
  and damages the player on contact, spawning faster/more over run
  duration.
- One weapon, auto-firing at the nearest enemy; Spellpower is upgradeable.
- Six rarity tiers (`loot_registry.gd`/`loot_type.gd`), numbers matching
  the Rarity tiers table below. One item drops per kill, tier rolled by
  drop weight, picked up via a proximity-based magnet radius (Gleam
  upgradeable).
- A real slot-grid backpack (`backpack_grid.gd`) — one slot per loot
  type held, colored by rarity, growing with Bearing; fill % shrinks
  max HP.
- Two currencies (`meta_progression.gd`): player currency (loot value)
  funds Spellpower/Swiftness/Gleam; backpack currency (survival
  time) funds Bearing. Upgrades are leveled with a geometric cost curve
  and a hard level cap, including Bearing (base cost 100, ×1.25/lvl,
  cap 10 as of the v6 balance pass).
- Per-tier Compacting (Commons Hoard through Mythic Hoard) and Discard
  (formerly Purge) both built and gated as described below.
- Shop is the two-tree skill-tree layout (Player Tree / Backpack Tree)
  with gating and hover tooltips, not a flat button list.
- Death → full run summary screen (time/phase, rewards, loot breakdown,
  run stats, previous best) → shop → restart with upgrades carried over.
- Persistence: 4 save slots with metadata (last played, playtime,
  upgrade preview); player selects a slot at game start to load/overwrite
  progress. Cloud-sync infrastructure exists but the server side is still
  a placeholder — see [TODO.md](TODO.md).

Not yet built: enemy tiers beyond the current single Minion type, magic
spells (single weapon is still hardcoded, not spell-based), and multiple
simultaneous spells — see [TODO.md](TODO.md) for the v7/v8+ build order.

## Enemy Types & Loot Tiers

Three enemy tiers, each with distinct attack pattern and loot weighting. Higher-tier enemies drop better loot, creating progression incentive: survive longer → face harder enemies → earn better loot → upgrade → tackle longer runs.

### Tier 1: Minion (baseline, current)

**Attack:** Simple melee chaser. Moves toward player continuously.

**Stats:**
- Base HP: 20
- Base speed: 100
- Attack: On-contact damage
- Scaling: HP and speed scale with run duration (45-sec ramp, ×1.5–3.0 by end)

**Loot:** 60% Common, 30% Uncommon, 10% Rare

**Role:** Bulk enemy; teaches fundamentals

### Tier 2: Bruiser (mid-game)

**Attack:** Charge. Pauses 2–3 sec, then charges in straight line. Resets after hit/miss.

**Stats:**
- Base HP: 35 (+75% vs Minion)
- Base speed: 70 (slower, but charges at 250)
- Charge distance: ~400 pixels
- Scaling: HP and charge speed scale with run duration

**Loot:** 20% Common, 50% Uncommon, 25% Rare, 5% Epic

**Role:** Introduces evasion timing; requires dodge-ability

### Tier 3: Elite (late-game)

**Attack:** Projectile ranged attacker. Fires every 1.5–2 sec from ~300 pixels away.

**Stats:**
- Base HP: 40 (+100% vs Minion)
- Base speed: 120 (faster, maintains distance)
- Projectile speed: 150
- Scaling: HP and projectile speed scale with run duration

**Loot:** 5% Common, 20% Uncommon, 40% Rare, 30% Epic, 5% Mythic

**Role:** Requires positioning and kiting; tactical combat

### Spawn Rules

Timing gates harder enemies so early runs stay accessible:

- **0–20 sec (Phase 1):** Minions only
- **20–40 sec (Phase 2):** Minions 70%, Bruisers 30%
- **40+ sec (Phase 3):** Minions 40%, Bruisers 35%, Elites 25%

Within each phase, spawn *frequency* accelerates; spawn *mix* stays consistent.

### Design Notes

- All enemy types use existing difficulty ramp (no new scaling curves)
- Difficulty is *tactical variety*, not stat bloat
- Loot weighting creates clear progression: reach Phase 3 (40+ sec) → Elites appear → better loot → upgrades → can reach 40+ sec more reliably
- Each tier has distinct visual/audio (not yet designed)

### Future Expansions (Enemy Types)

- Tier 4: Boss (unique, 55+ sec, guaranteed Mythic+ drop)
- Enemy variants within tiers (fast Minion, tanky Minion)
- Projectile types (different speeds/colors per enemy)
- Loot affixes (higher tiers drop items with +modifiers)

## HUD & UI Design

All UI elements follow a consistent visual system to maintain cohesion across the game.

### In-Run Stats Overlay

**Location:** Top-left corner (16px from edges), semi-transparent dark panel

**Three stats displayed:**
- ⏱️ **TIME** — Run duration (MM:SS format), white text
- 💰 **PLAYER CURRENCY** — Loot value collected (gold color)
- 🎒 **BACKPACK CURRENCY** — Time survived earning (~0.05/sec, cyan color)

**Purpose:** Make the time → backpack currency connection visible. Shows rate (+0.05/sec) so players understand slow progression is intentional.

**Styling:** Dark background (#1a1a1a, 80% opacity), small border, 12px padding, 8px spacing between rows.

### Death Summary Screen

**Trigger:** Player dies, full-screen centered panel appears before shop

**Content sections:**
1. **Run Duration:** Time survived + Phase reached (Phase 1/2/3)
2. **Rewards (highlighted):** Player currency earned (gold) + Backpack currency earned (cyan)
3. **Loot Breakdown:** Items collected, color-coded by rarity
4. **Run Stats:** Max backpack fill %, enemies killed
5. **Previous Best:** Best time from prior runs (if exists)
6. **Button:** "CONTINUE TO SHOP" (single action, no confusion)

**Purpose:** Celebrate the run, make currency earning explicit, encourage replaying to beat personal best.

**Styling:** Dark panel (#2a2a2a), gold header underline, section dividers (1px gray), white text with colored accents (gold/cyan for currency).

### Skill Tree Tooltips

**Trigger:** Hover over any skill node

**Content:**
- Upgrade name (header, 18px bold)
- Current level / max level
- Cost (next level) with currency icon and affordability status
- Effect description (what does this do?)
- Before/after notation (current power → new power)
- Flavor text (why this upgrade matters)

**Variants:**
- **Locked:** Red "LOCKED" indicator + requirement text
- **Maxed:** Green "MAX" indicator, no cost shown
- **Affordable:** Gold/cyan cost text (matches currency)
- **Can't afford:** Grayed cost, "Need X more [currency]"

**Styling:** Dark panel (#2a2a2a), 2px color-coded border (gold for player tree, cyan for backpack tree), white text, 12px padding, 280–320px width.

### Visual System (Shared)

**Colors:**
- Player Currency: Gold (#FFD700)
- Backpack Currency: Cyan (#00D9FF)
- Time: White (#FFFFFF)
- Rarity: Common white, Uncommon green, Rare blue, Epic purple, Mythic orange, Legendary red
- Text primary: White, Text secondary: Gray (#999999), Text muted: Gray (#666666)
- Affordable: Green (#4CAF50), Locked/Unaffordable: Red (#F44336)

**Typography:**
- Header: 28–32px, bold, white
- Primary stat: 24–28px, semi-bold, colored
- Secondary: 16–20px, regular, white
- Tertiary: 12–14px, regular, gray

**Spacing Standards:**
- Padding inside panels: 12–16px
- Gap between rows: 8px
- Gap between sections: 12px
- Icon-to-text gap: 4px

**Formatting:**
- Numbers: Use commas (1,234 not 1234)
- Time: Always MM:SS (01:23, not 1:23)
- Decimals: 1 place for slow rates (0.05/sec, 4.1)
- Before/after: Use arrow (30 → 32) or + notation (+2)
- Currency: Always show icon (💰, 🎒)

**Status:** Implemented — in-run overlay (`scripts/hud.gd`, `scripts/hud_stat_icon.gd`),
death summary (`scripts/hud.gd`, `scenes/arena.tscn`), and skill tree tooltips
(`scripts/skill_tree_view.gd`) all match the sections above.

## Magic Spells & Attack Skills

Player is a **magic user**. Weapons are **spells**, casting-based combat with distinct playstyles. v7 launches with single active spell; v8+ unlocks multiple simultaneous spells for stronger progression feedback.

### Spell System Structure

**Spell Unlock node** (gated root in Player Tree):
- Base cost: 25, ×1.20/lvl, cap 5
- L1: Unlock Inferno Blade
- L2: Unlock Frost Nova
- L3+: Reserved for future spells

Only **1 active spell at a time** (v7). Switched in shop screen, persists across runs per save slot.

### Spell 1: Arcane Bolt (always available)

**Feel:** Ranged magic projectiles; steady, reliable DPS.

**Base stats:**
- Power: 20 (scales with Spellpower)
- Cast rate: 0.5 sec/shot
- Projectile speed: 400 pixels/sec

**Upgrades:**
- Spellpower: (shared with Player Tree root stat)
- Haste (cast speed): -0.05 sec/lvl, cap 0.15 sec
- Projectile Speed: +50/lvl, cap 600

### Spell 2: Inferno Blade (unlock at Spell Unlock L1)

**Feel:** Melee flame magic; high risk/reward with burn damage over time.

**Base stats:**
- Power: 25 (scales with Spellpower)
- Swing rate: 1.0 sec/swing
- Arc range: 90°
- Knockback: 200 pixels
- Burn duration: 1.5 sec

**Upgrades:**
- Fury (swing speed): -0.15 sec/lvl, cap 0.3 sec
- Arc Width: +15°/lvl, cap 180°
- Burn Damage: +5/lvl, cap 60

### Spell 3: Frost Nova (unlock at Spell Unlock L2)

**Feel:** Crowd control; freeze zones that slow/stun enemies.

**Base stats:**
- Power: 15 (utility-focused, lower raw damage)
- Cast rate: 2.0 sec/nova
- Freeze radius: 150 pixels
- Freeze duration: 0.8 sec
- Slowdown: 50% move speed

**Upgrades:**
- Frequency (cast speed): -0.3 sec/lvl, cap 0.8 sec
- Radius: +20/lvl, cap 300 pixels
- Slow Strength: +5%/lvl, cap 100% (full stun at max)

### Spell Design Notes

- Spellpower stat applies to all spells uniformly (shared scaling)
- Each spell's individual upgrades are independent (Arcane Haste doesn't affect Inferno Fury)
- Visuals: Arcane (blue/purple), Inferno (orange/red), Frost (cyan/white)
- Loot remains generic currency (magic flavor is aesthetic + mechanical, not tied to loot types)

### Future: Multiple Active Spells (v8+)

**Goal:** Each new spell doubles the feeling of getting stronger; player can equip 2–3 spells simultaneously, rotating between them or auto-casting all.

**Implementation notes:**
- Requires MetaProgression redesign to track multiple active_spells (currently single)
- Player cycles/alternates between spells, or all cast on shared cooldown
- Unlocking a new spell becomes a real power milestone ("I just got Frost Nova, I can freeze enemies now")
- Keeps progression ladder fresh through many runs (early: Arcane only → mid: Arcane + Inferno → late: all three)

### Future: Additional Spells (v8+)

- **Meteor Strike:** High-damage AOE impact, long cooldown (boss-killer)
- **Teleport Pulse:** Dash + damage on arrival, mobility spell
- **Time Warp:** Slow time in area, massive crowd control
- **Lightning Chain:** Arc between enemies, spreads on contact
- **Summon Familiar:** Passive pet that auto-attacks, mana-limited

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

Rate (v6 balance): `backpack_currency = round(0.05 × seconds_survived)` — 0.05
currency per second alive. Very gradual accumulation; a 60-second run
earns ~3 currency. Designed so player upgrades (from loot) drive early
progression, while backpack upgrades (from survival time) come later as
a long-term goal. A player can afford early Compacting after ~5 good
runs, but Capacity remains a prestige milestone for 20+ runs in.

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

- **Backpack Tree** is a real chain: Bearing sits at the root (always
  purchasable). Compactor nodes unlock in rarity order — Commons Hoard →
  Uncommon Stash → Rare Vault → Epic Trove → Mythic Hoard — each locked
  until the previous tier's compactor has at least one level bought.
  Discard unlocks the same way, as a capstone gated behind the Rare
  Vault's first level — reusing the same "previous node bought once"
  gate as everything else rather than a separate threshold rule. This
  resolves the earlier open question about Compacting's purchase order:
  it's a hard gate now, enforced by the tree, not just a cost-driven
  nudge.
- **Player Tree** is flatter: Spellpower, Swiftness, and Gleam branch
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
| Spellpower | 20 | +2 (10% of base) | 15 | ×1.15/lvl | 20 | 60 (3×) |
| Swiftness | 250 | +10 (4% of base) | 15 | ×1.18/lvl | 10 | 350 (1.4×) |
| Gleam | 60 | +8 (13% of base) | 12 | ×1.15/lvl | 15 | 180 (3×) |

Swiftness gets the smallest relative gain and the steepest cost growth on
purpose — it's the stat most likely to trivialize difficulty or feel bad
if overtuned, and it also feeds the knockback-decay math in
`scripts/player.gd`, so pumping it has knock-on effects beyond raw
mobility. Spellpower and Gleam get more room to grow since
overinvesting in them is safer. As a rough pacing check: fully maxing
Spellpower alone (20 levels, geometric sum) comes out to roughly 1,500
currency total — meant to take many runs, not a handful.

Built: `StatDef`/`MetaProgression` support geometric cost curves and a
hard level cap, and Spellpower/Swiftness/Gleam are wired up with the
exact numbers above.

### Backpack-track upgrade curve

Same framework as the player track — geometric cost growth, flat/additive
effect per level, capped levels — applied to backpack currency instead.
Bearing gets its own table here; Compacting and Discard (already
tier/threshold-shaped) get their leveled cost curves in their own
sections below.

| Stat | Base | Per-level gain | Base cost | Cost growth | Level cap | Value at cap |
|---|---:|---:|---:|---:|---:|---:|
| Bearing | 1 slot | +1 slot | 100 | ×1.25/lvl | 10 | 11 slots (11×) |

Bearing is deliberately the prestige upgrade — expensive (base cost 100)
and steep cost growth (×1.25/lvl). Starting at 1 slot creates an immediate
constraint that forces the use of Compacting early on. Each new slot
(especially the 2nd and 3rd) feels like a major milestone/level-up moment,
keeping engagement high through a long progression series. By design,
players should have access to Compacting upgrades in their first 5 runs,
but won't afford a 2nd Bearing slot until run 15–20+.

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
| Common    | 50%         | 10                | 1                 | 10                 | White  |
| Uncommon  | 27%         | 8                | 3                 | 24                 | Green  |
| Rare      | 14%         | 5                | 10                | 50                | Blue   |
| Epic      | 6%          | 3                 | 40                | 120                | Purple |
| Mythic    | 2.5%        | 2                 | 150               | 300                | Orange |
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
discarded mid-run by the Discard upgrade is gone — its value is never
banked. That makes Discard a genuine trade, not a free safety net: it buys
more survival time (and so more backpack currency) at the cost of the
player currency those discarded items would have been worth. Backpack
currency itself (from survival time) is entirely separate and unaffected
by any of this — see Two Currencies above.

Worked example (illustrative): a run ends with 40 Commons, 10 Uncommons,
3 Rares, and 1 Epic still in the bag →
`40×1 + 10×3 + 3×10 + 1×40 = 140` player currency. Against the Spellpower
curve (base cost 15, ×1.15/lvl), that covers the first several levels of
one stat — a reasonable early pace, a few runs to a first couple of
upgrades.

### Compacting upgrades

A **separate upgrade per rarity tier, Common through Mythic** — Commons
Hoard, Uncommon Stash, Rare Vault, Epic Trove, Mythic Hoard — each
raising that tier's max stack size (e.g. Commons Hoard lvl 1: 64 → 96,
lvl 2: 96 → 128 — several levels per tier for a granular shop ladder).
Compacting never touches item value, only how many of that tier fit in
one slot.

**Legendary is permanently uncompactable** — no Compacting node exists
for it, stack size stays 1 forever. It's the one item that always eats a
whole slot on its own, by design: that's the top-tier risk/reward
tension the whole rarity system is built around, and it shouldn't be
tunable away.

Purchase order follows the rarity ladder — Commons Hoard first, Mythic
Hoard last — because relevance follows the drop curve: commons flood the
bag from the first run, so Commons Hoard pays off immediately and keeps
paying off for a long stretch, while Mythic Hoard is nearly irrelevant
until mythics are dropping often enough for stack depth to matter at
all. In the skill-tree shop (see above) this is a **hard gate**: each
Compacting node is locked until the previous tier's node has at least
one level bought, not just nudged by price.

Per-tier cost curve (illustrative):

| Compacting node | Base stack | Per-level gain | Base cost | Cost growth | Level cap | Stack at cap |
|---|---:|---:|---:|---:|---:|---:|
| Commons Hoard | 10 | +10 | 12 | ×1.12/lvl | 8 | 90 (9×) |
| Uncommon Stash | 8 | +5 | 18 | ×1.14/lvl | 6 | 38 (4.75×) |
| Rare Vault | 5 | +3 | 28 | ×1.16/lvl | 5 | 20 (4×) |
| Epic Trove | 3 | +2 | 42 | ×1.18/lvl | 4 | 11 (3.67×) |
| Mythic Hoard | 2 | +1 | 75 | ×1.20/lvl | 3 | 5 (2.5×) |
| Legendary | 1 | — | — | — | — | 1 (never stacks) |

Base cost and growth rate also climb with rarity on top of the gate
itself, so even a player who's unlocked a later node still feels the
common-first pull through price.

### Discard upgrade

A single, late-game upgrade (formerly "Purge"): once bag fill crosses a
threshold (e.g. 90%), automatically discards the lowest-rarity item(s)
to free space instead of blocking further pickups. Only becomes
relevant once slot count and stack depth (via Compacting) are both near
their ceiling and fullness is still the thing killing runs — a last
safety valve after the other two upgrade paths are mostly exhausted,
not a substitute for them.

Leveled via its trigger threshold rather than a flat on/off:

| Discard level | Trigger threshold | Cost |
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
higher in the same slot, Bearing is *seen* as the grid growing, and
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
- 2026-08-14 — Save/load persistence redesigned: 4 save slots with slot
  screen at startup showing metadata (last played, playtime, current
  upgrades). Cloud-sync for cross-device access, syncs on run end and
  graceful quit, local-first (works offline), last-write-wins conflict
  resolution. Meta-progression only (upgrades/currencies), not run stats
  yet. Optional email-based device linking for cloud features; unlinked
  saves stay local. Enables meaningful progression testing and supports
  multiple parallel playstyles in same session.
- 2026-08-15 — v6 balance locked: progression philosophy is "many runs
  with hard early game, incremental growth." Starting backpack capacity
  reduced to 1 slot (bare minimum), forcing Compacting as first priority.
  Backpack currency rate slowed to 0.05/sec (very gradual, ~3 currency per
  60-second run). Capacity cost increased to base 100, ×1.25/lvl, cap 10
  — prestige upgrade that feels earned after 20+ runs. Compacting made
  mid-tier (base cost 12–15, affordable after ~5 good runs). Player
  upgrades (Damage/Speed/Magnet) remain accessible early, rewarding loot
  collection. This creates a progression ladder: player upgrades (early
  wins) → Compacting (mid wins) → Capacity (prestige milestone), keeping
  engagement high through a long series of runs.
- 2026-08-15 — Enemy types locked in: three tiers with distinct attack
  patterns and loot weights. Minion (melee chaser, 60% Common) appears from
  start. Bruiser (charge attack, 50% Uncommon) appears at 20 sec, Phase 2.
  Elite (projectile ranged, 70% Rare+) appears at 40 sec, Phase 3. Loot
  weighting creates direct incentive to survive longer: reach Phase 3 →
  fight Elites → earn Rare+ loot → buy upgrades → survive better. All tiers
  use existing difficulty ramp (no new scaling). Difficulty is tactical
  variety (evasion, positioning) not stat bloat. Future: add Tier 4 Boss at
  55+ sec, enemy variants within tiers, loot affixes.
- 2026-08-15 — Magic spells locked in: player is a magic user, weapons are
  spells. Three core spells (Arcane Bolt ranged, Inferno Blade melee with
  burn, Frost Nova crowd control) unlock via Spell Unlock node in Player Tree.
  v7 supports single active spell (switch in shop). v8+ planned to support
  multiple simultaneous spells to reinforce "getting stronger" feeling
  (unlock Inferno → equip both Arcane + Inferno → later add Frost Nova).
  Spell upgrades follow existing cost curves. Spellpower stat applies to all
  spells uniformly; each spell has independent upgrade paths (Haste, Arc,
  Radius, etc.). Visuals are magic-themed (blue/purple, orange/red, cyan
  effects) but loot stays generic currency.
- 2026-08-15 — v5 naming pass shipped: Player Currency → Essence, Backpack
  Currency → Stardust, Compactor tiers → "<Tier> Binding" (e.g. "Common
  Binding"), Shop → Sanctum, death screen → "Lost to the Void" / "RUN
  SUMMARY". Core stat names (Damage, Move Speed, Magnet Range, Backpack
  Capacity) were deliberately left as-is in this pass — see
  [TEXT_FLAVOR.md](TEXT_FLAVOR.md) for the still-open Spellpower/
  Swiftness/Gleam/Bearing rename proposal, not yet decided.
- 2026-08-15 — HUD & UI Design section (stats overlay, death summary,
  skill tree tooltips) implemented as specified above and verified live
  in-game: run overlay updates Time/Essence/Stardust each frame; death
  summary shows time/phase, rewards, rarity-colored loot breakdown, run
  stats, and previous-best once one exists; skill tree tooltips get a
  currency-colored border, before/after values, and affordable/shortfall/
  maxed/locked status text.
- 2026-08-15 — Adopted TEXT_FLAVOR.md's core stat rename proposal: Damage
  → Spellpower, Move Speed → Swiftness, Magnet Range → Gleam, Backpack
  Capacity → Bearing, Purge → Discard, and the five Compacting tiers →
  Commons Hoard / Uncommon Stash / Rare Vault / Epic Trove / Mythic
  Hoard. Applied throughout this doc's active sections (decisions log
  entries above this one are left as historical record using the old
  names, since they describe decisions made at the time under those
  names). Underlying stat IDs (`damage`, `move_speed`, etc.) are
  unchanged — this is a display-name-only rename, no save compatibility
  impact.
