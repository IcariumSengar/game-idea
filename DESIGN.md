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

What's actually built and playable today (see `scripts/`, as of v11):

- Top-down movement + dash in a single arena; four enemy tiers (Minion
  melee chaser with Fast/Tanky variants, Bruiser pause/charge, Elite
  kite + projectile, and a unique Boss at 55+ sec), gated into the run
  by phase (see "Enemy Types & Loot Tiers" below) and spawning
  faster/more over run duration. A full bag also slows the
  player's movement (floor 80% of base speed) on top of the max-HP
  shrink, per the backpack-fill penalty below.
- Casting-based combat (`spell_caster.gd`): every unlocked spell casts
  simultaneously and independently, no switching. Arcane Bolt (ranged
  projectile) is always available; the other seven -- Inferno Blade,
  Frost Nova, Meteor Strike, Lightning Chain, Time Warp, Teleport Pulse,
  Summon Familiar -- join in permanently as their Spell Unlock tier (L1-L7)
  gets bought. Spellpower is upgradeable and scales all of them
  proportionally (except Summon Familiar's own attack, which is the
  pet's fixed stat, not the caster's).
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
  (formerly Purge) both built and gated as described below. A pre-run
  Backpack Ability choice (Condense vs. Clear, see below) passively
  processes backpack items during a run on top of that.
- Shop is currently a two-tree skill-tree layout (Player Tree / Backpack
  Tree) with gating and hover tooltips, not a flat button list; the 8
  spells' unlock/upgrade stats live inside Player Tree today, with a
  separate read-only sidebar just showing lock state. A three-tree
  rework (Player / Spells / Backpack, see "Shop structure: skill tree"
  below) is a decided but not-yet-implemented follow-up — see TODO.md.
- Death → full run summary screen (time/phase, rewards, loot breakdown,
  run stats, previous best) → shop → restart with upgrades carried over.
- Persistence: 4 save slots with metadata (last played, playtime,
  upgrade preview); player selects a slot at game start to load/overwrite
  progress. Cloud-sync infrastructure exists but the server side is still
  a placeholder — see [TODO.md](TODO.md).

Not yet built: real spell/enemy sprite art (spells and Player are still
procedural/placeholder; enemies now have real DungeonTilesetII sprites) —
see [TODO.md](TODO.md) for open follow-ups.

## Enemy Types & Loot Tiers

Four enemy tiers, each with distinct attack pattern and loot weighting. Higher-tier enemies drop better loot, creating progression incentive: survive longer → face harder enemies → earn better loot → upgrade → tackle longer runs.

### Tier 1: Minion (baseline, current)

**Attack:** Simple melee chaser. Moves toward player continuously.

**Stats:**
- Base HP: 20
- Base speed: 100
- Attack: On-contact damage
- Scaling: HP and speed scale with run duration (45-sec ramp, ×1.5–3.0 by end)

**Loot:** 60% Common, 30% Uncommon, 10% Rare

**Role:** Bulk enemy; teaches fundamentals

**Variants (same tier, same loot table):** Fast (speed 160, HP 14 -- glass
cannon chaser, hard to outrun but dies quick) and Tanky (speed 65, HP 45 --
easy to outrun but slow to kill if cornered), tinted yellow-green and
purple respectively. Each phase's Minion spawn weight splits 70/15/15
between base/Fast/Tanky, so the tier-level Minion-vs-Bruiser-vs-Elite
ratios below are unchanged -- this only diversifies what "Minion" means.

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

### Tier 4: Boss (unique, one per run)

**Attack:** Hybrid -- relentlessly approaches like a Minion (including
contact damage) while periodically firing a 3-shot projectile spread at
the player, combining pursuit with Elite-style ranged pressure.

**Stats:**
- Base HP: 250 (well past Elite's 40 -- meant to be a real damage sponge)
- Base speed: 90
- Spread attack: 3 projectiles per volley (±20° from center), every 2.2–2.8 sec, 140 px/sec, 10 damage each
- Scaling: HP and projectile speed scale with run duration, same as every other tier

**Loot:** Guaranteed Mythic+ -- 80% Mythic, 20% Legendary. Skips the
normal weighted per-tier table entirely; this is the one enemy where
what drops isn't a gamble across all six tiers.

**Role:** Unique, not part of the repeating phase roll -- spawns once,
the first time the spawn timer fires at or after 55 seconds survived,
alongside (not instead of) that tick's normal roll. A real climax
milestone for a run that's gone the distance.

### Spawn Rules

Timing gates harder enemies so early runs stay accessible:

- **0–20 sec (Phase 1):** Minions only (incl. Fast/Tanky variants)
- **20–40 sec (Phase 2):** Minions 70%, Bruisers 30%
- **40+ sec (Phase 3):** Minions 40%, Bruisers 35%, Elites 25%
- **55+ sec:** Boss spawns once, on top of whichever phase mix is active

Within each phase, spawn *frequency* accelerates; spawn *mix* stays consistent.

### Design Notes

- All enemy types use existing difficulty ramp (no new scaling curves)
- Difficulty is *tactical variety*, not stat bloat
- Loot weighting creates clear progression: reach Phase 3 (40+ sec) → Elites appear → better loot → upgrades → can reach 40+ sec more reliably
- Each tier now has a distinct sprite (goblin/orc_warrior/orc_shaman/
  big_demon from the existing DungeonTilesetII pack); distinct
  per-tier audio is still generic (shared `enemy_hit`/`enemy_death`/
  `enemy_cast` cues) and not yet designed

### Future Expansions (Enemy Types)

- Projectile types (different speeds/colors per enemy)

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

Player is a **magic user**. Weapons are **spells**, casting-based combat with distinct playstyles. v9 launched with a single active spell; v10 replaced that with every unlocked spell casting simultaneously for stronger progression feedback.

### Spell System Structure

**Spell Unlock node** (gated root of the Spell Tree — split out from
Player Tree in the shop's three-tree rework, see "Shop structure: skill
tree" below):
- Base cost: 25, ×1.20/lvl, cap 7 (raised from 5 for v11's five new spells)
- L1: Unlock Inferno Blade
- L2: Unlock Frost Nova
- L3: Unlock Meteor Strike
- L4: Unlock Lightning Chain
- L5: Unlock Time Warp
- L6: Unlock Teleport Pulse
- L7: Unlock Summon Familiar

As of **v10**, every unlocked spell casts automatically and simultaneously
-- no switching, no slots. Arcane Bolt is always active; Inferno Blade and
Frost Nova join in permanently, on their own independent cast-rate
cooldowns, the moment their Spell Unlock tier is bought. Unlocks persist
across runs per save slot, same as any other stat.

### Spell 1: Arcane Bolt (always available)

**Feel:** Ranged magic projectiles; steady, reliable DPS.

**Base stats:**
- Power: 20 (scales with Spellpower)
- Cast rate: 0.33 sec/shot (+50% vs the original 0.5, per balance feedback)
- Projectile speed: 400 pixels/sec

**Upgrades:**
- Spellpower: (shared with Player Tree root stat)
- Haste (cast speed): -0.033 sec/lvl, cap 0.1 sec
- Projectile Speed: +50/lvl, cap 600

### Spell 2: Inferno Blade (unlock at Spell Unlock L1)

**Feel:** Melee flame magic; high risk/reward with burn damage over time.
Omnidirectional (hits everything in range regardless of facing) rather
than a facing-cone -- playtesting found requiring the player to aim a
cone broke the auto-attack feel every other spell/weapon in this game
has had.

**Base stats:**
- Power: 25 (scales with Spellpower)
- Swing rate: 1.0 sec/swing
- Range: 120px, omnidirectional
- Knockback: 200 pixels
- Burn duration: 1.5 sec

**Upgrades:**
- Fury (swing speed): -0.15 sec/lvl, cap 0.3 sec
- Reach (range): base value 90-180 (inherited from the original cone-angle
  curve), value above the 90 baseline adds directly to the 120px base
  range, +15/lvl, cap 180 (so +90px range at max)
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

### Multi-Spell Casting (v10, implemented)

Every unlocked spell casts automatically and simultaneously, each on its
own independent cooldown -- no slots, no rotation, no manual switching.
Resolves the "rotating vs. auto-casting all" question this section
originally left open, in favor of the simpler option. Unlocking a new
spell is a real power milestone: early runs are Arcane-only, and each
Spell Unlock level (now L1-L7, see Spell System Structure above) adds
one more spell permanently to the mix, up to all eight running at once
at L7.

### Spell 4: Meteor Strike (unlock at Spell Unlock L3)

**Feel:** Boss-killer -- high-damage single-target-area impact on a long cooldown.

**Base stats:**
- Power: 90 (scales with Spellpower -- highest of any spell, matching the "boss-killer" role)
- Cast rate: 5.0 sec/strike
- Impact radius: 100px, centered on the nearest enemy at cast time
- Telegraph: 0.5 sec warning ring before the hit actually lands

**Upgrades:**
- Frequency (cast speed): -0.5 sec/lvl, cap 2.5 sec

### Spell 5: Lightning Chain (unlock at Spell Unlock L4)

**Feel:** Arcs from the player to the nearest enemy, then hops to whichever
unhit enemy is nearest the last one struck -- rewards facing clustered
enemies rather than a lone target.

**Base stats:**
- Power: 15/hit (scales with Spellpower), decaying ×0.8 per hop
- Cast rate: 1.5 sec/cast
- Initial range: 200px, chain-hop range: 150px
- Max hits: 4 (initial + 3 chains)

**Upgrades:**
- Frequency (cast speed): -0.15 sec/lvl, cap 0.75 sec

### Spell 6: Time Warp (unlock at Spell Unlock L5)

**Feel:** Massive crowd control -- low damage, but slows everything in a
wide radius hard and long. Distinct from Frost Nova via scale (bigger
radius/duration/slow-strength) rather than raw power.

**Base stats:**
- Power: 10 (scales with Spellpower -- intentionally the lowest of any spell, this is a CC tool not a damage one)
- Cast rate: 4.0 sec/cast
- Radius: 200px
- Slow strength: 80%, duration: 2.0 sec

**Upgrades:**
- Frequency (cast speed): -0.4 sec/lvl, cap 2.0 sec

### Spell 7: Teleport Pulse (unlock at Spell Unlock L6)

**Feel:** Mobility spell -- blinks the player 250px in their current
movement direction (or a random direction if standing still), dealing
AOE damage at both the departure and arrival points. Always fires, even
if nothing's in range to hit -- repositioning is the point, unlike the
damage/CC spells which stay silent on a whiff.

**Base stats:**
- Power: 20/burst (scales with Spellpower), applied at both ends
- Cast rate: 3.5 sec/cast
- Teleport distance: 250px, burst radius: 80px at each end

**Upgrades:**
- Frequency (cast speed): -0.3 sec/lvl, cap 1.5 sec

### Spell 8: Summon Familiar (unlock at Spell Unlock L7, final tier)

**Feel:** A persistent pet that hovers near the player and independently
fires bolts at the nearest enemy in range -- "mana-limited" per the
original concept, stood in for by a fixed resummon cooldown plus an
upgradeable active-duration window rather than introducing a whole new
mana resource for one spell.

**Base stats:**
- Familiar attack power: 8/hit, fixed (doesn't scale with Spellpower --
  it's the pet's own stat, not the caster's)
- Familiar attack rate: 0.8 sec/shot, range 160px
- Resummon cooldown: 8.0 sec, fixed (not upgradeable)
- Active duration: 12.0 sec base

**Upgrades:**
- Familiar Uptime (active duration): +2.0 sec/lvl, cap 20.0 sec

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

The shop is three skill trees across three tabs — **Player**, **Spells**,
**Backpack** — full-width one at a time rather than side by side (the
Spell Tree alone has 18 nodes; showing multiple trees at once doesn't
fit). Player and Spells both spend Essence; Backpack spends Stardust —
tab names are plain/content-based on purpose, not currency-literal, so
two tabs sharing a currency doesn't read as a naming conflict; the
always-visible Essence/Stardust totals on screen carry the currency
identity instead.

- **Backpack Tree** is a real chain: Bearing sits at the root (always
  purchasable). Compactor nodes unlock in rarity order — Commons Hoard →
  Uncommon Stash → Rare Vault → Epic Trove → Mythic Hoard — each locked
  until the previous tier's compactor has at least one level bought.
  Discard unlocks the same way, as a capstone gated behind the Rare
  Vault's first level — reusing the same "previous node bought once"
  gate as everything else rather than a separate threshold rule. Alchemy
  sits ungated alongside Bearing. This resolves the earlier open
  question about Compacting's purchase order: it's a hard gate now,
  enforced by the tree, not just a cost-driven nudge.
- **Player Tree** is flat: just Spellpower, Swiftness, and Gleam, no
  cross-gating between them, since nothing in the design requires one
  before another. (Spell Unlock and all per-spell upgrade stats have
  moved out to the Spell Tree below — Player Tree used to carry all of
  that too, which is what made it feel cluttered.)
- **Spell Tree** (new, split out of Player Tree): Spell Unlock is the
  gated trunk (unchanged ladder — L1 Inferno Blade through L7 Summon
  Familiar). Each level's node branches into that spell's own upgrade
  stats, reusing the exact same "previous node bought once" gate pattern
  as Backpack Tree's Compactor chain, just applied to spells instead of
  rarity tiers. Arcane Bolt's two upgrades (Haste, Velocity) branch
  directly off the trunk's root, ungated, since Arcane itself needs no
  unlock. Replaces the old static sidebar that just showed spell
  lock-state with no interaction — every spell upgrade is now a real,
  purchasable tree node like everything else in the shop.
- Each node keeps its existing leveled/capped cost curve (see tables
  above and below) — this rework is a regrouping and a UI change, not a
  balance change. No stat IDs, costs, or gates move; only which tab a
  node lives in and how it's laid out.

**Why Spells shares Essence with Player rather than getting its own
currency:** it keeps the existing "which track am I feeding this run"
tension (loot-heavy vs. survival-heavy) to two currencies, not three, but
adds a real second-order choice inside Essence itself — level up what you
already have (Player Tree) vs. unlock a new spell (Spell Tree) — without
inventing a new resource to earn or balance. Spell Unlock's full ladder
costs ~323 Essence total vs. Spellpower's ~1,500 to max, so early Essence
naturally leans toward cheap unlocks plus a few Player Tree levels first,
matching "early runs are Arcane-only, spells arrive as milestones"
already established above.

Three trees now read as three distinct fantasies rather than three
buckets of the same kind of node: Player Tree is flexible baseline power
(spend anywhere, no wrong order), Spell Tree is a deliberate milestone
stairway (each trunk level is the single biggest per-run swing in how a
run *feels* — a new spell joining the fight permanently), Backpack Tree
is survival infrastructure (rarity-gated, prestige-capped). That variety
is the actual point of the rework, not just decluttering — it's what
sells "getting stronger" across dozens of short runs instead of one long
flat stat list.

Left open for later: mutually exclusive branches / specializations (e.g.
a fork trading Damage for AoE, or another build-defining choice) would be
a real scope addition — new stat types, and some tension with "everything
is eventually maxable" since an exclusive pick means a run commits to a
build rather than a straight completion path. Not doing this now; none of
the three trees have exclusive choices, just gating and layout — the door
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

**Fill %** = slots used ÷ capacity, where **one slot is one stack
instance of a tier** (capped at that tier's Compacting-modified stack
size) — a tier can occupy more than one slot once its current stack is
full, matching what the six-tier value table already implies. (Currently
shipped: `backpack` is a dictionary keyed only by tier, so "slots used"
is really "distinct tiers touched," hard-capped at 6 regardless of
Bearing level — fill % maxes out within the first few kills of any run
and then stays maxed no matter how much more is collected, and
Compacting/Bearing above level 6 currently have zero effect on survival
risk. This is a real drift from intent, not a documented design choice —
see the decision log and TODO.md's Tweak 3.) The fix keeps the existing
HP-shrink formula (`max_hp = base_max_hp × lerp(1.0, MIN_HP_FRACTION,
fill%)` in `scripts/player.gd`) — only what counts as a slot changes,
restoring fill % as a running measure of how much is actually being
carried instead of a one-time flag for which rarities have been seen.

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

### Gem Pickup Visual

Loot drops (`loot_gem.gd`) currently render as a fully-detailed faceted
crystal at rest — same level of visual detail whether one enemy died or
six did, which is why they read as cluttered once they pile up mid-fight.
**Locked in:** simplify to a small, simple pip at rest — color-forward,
no facets/glow-ring detail to parse in combat — and move the visual
payoff to the pickup moment instead (the existing spark burst + "+N"
floating text, made to actually pop) rather than the idle/resting state.
Quiet on the ground, loud on collect. This is presentation only — the
one-drop-per-kill mechanic, drop weights, and values are unchanged; if a
real multi-drop-per-kill mechanic is wanted later, that's a separate
balance decision, not this one. Not built — see TODO.md.

### Loot affixes

Epic+ drops have a chance to roll "Blessed" -- 15% for Epic, 25% for
Mythic, 40% for Legendary; Common/Uncommon/Rare never roll one. A
Blessed item is worth +50% more and reads distinctly in the moment
(brighter gold-shifted color, a bigger pulse, a "+X Blessed!" floating
text) but the bonus is banked immediately as extra currency rather than
living on the item itself.

That's a deliberate scope cut, not the full vision: the backpack tracks
a *count per tier*, not individual item instances (that's what makes
Compacting/stacking work at all), so there's no slot to durably attach a
modifier to. Reworking to per-instance tracking just to support affixes
would be a real architecture change with knock-on effects on Compacting,
Discard, and the loot grid UI -- out of scope for what this doc actually
asked for. A true persistent-modifier version (visible in the backpack
grid, tradeable value vs. slot space like everything else in the rarity
system) is a real future direction if this scope cut doesn't hold up.

### Loot → currency conversion

At run end, player currency earned is the sum of each collected item's
**base value/item** (from the table above), for whatever is still in the
backpack when the run ends:

`player_currency = Σ (count_in_backpack[tier] × base_value/item[tier])`
across all six tiers, plus any banked Blessed-affix bonus (see Loot
affixes above) on top.

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

### Gem Combos

A purely in-run tactical layer, separate from every other backpack
system: no currency, no meta-progression, no persistence — resets to
nothing at the start of every run, so it's equally available whether
it's a player's 1st run or 500th.

**Full Set:** holding one of each of the six rarity tiers simultaneously
(order-agnostic, not strict succession) triggers a one-time-per-run AOE
clear of every enemy on screen, reusing Meteor Strike's telegraph-then-
impact visual rather than new art. Order-agnostic was a deliberate
choice over a strict-sequence requirement — combat timing is too chaotic
for a hard order to read as skill rather than bad luck.

No new pickup mechanic needed: which enemy tier a player prioritizes
killing already determines what drops, via the existing per-tier loot
weighting (Minion → Common-heavy, Bruiser → Uncommon, Elite → Rare+,
Boss → guaranteed Mythic+) — so "strategically chasing the missing gem"
is already a real, existing lever. Consistent with the core "the
player's only input is movement/positioning" pillar — this is a
positioning/target-priority payoff, not a manual-cast ability.

Deliberately depends on the Fill % fix above landing first: today,
"holding one of each tier" already secretly means "bag is 100% full," so
rewarding that exact state right now would read as risk and payoff on
the same ambiguous signal. Once fill % tracks real volume instead of
tier-diversity, completing a set becomes its own clean, separate
milestone.

Three more patterns were considered, each aimed at a different playstyle
so they don't overlap with Full Set or each other, but deliberately left
out of this pass — ship Full Set first and see how it plays before
adding more combo shapes:

- **Streak** — N consecutive pickups of the *same* tier, uninterrupted,
  triggers a small tier-flavored buff. Rewards leaning into whatever a
  run is naturally giving you.
- **Rampage** — a volume/speed threshold (e.g. 8 pickups within 5
  seconds, any tier) triggers a brief buff. Rewards aggressive
  clearing/looting speed over precision.
- **Ascension** — a *strict ascending* sequence, Common through
  Legendary with no break, no repeats skipped. The hard-mode cousin of
  Full Set: same "collect variety" family, but unforgiving if broken, so
  it should pay out bigger or differently than Full Set rather than
  being strictly better. Resolves the earlier open question of whether
  set-completion should be order-strict or order-agnostic by having
  both exist as different difficulty tiers instead of picking one.

**Combo feedback -- locked in:** completing a combo should read as a
tension-then-release beat, not a flat trigger. Vibe reference: *Hyperslice*
(MrEliptik) -- a fast, aggressive arena roguelite whose core loop is
itself a two-step prime-then-deliver chain (bump an enemy to stun it or
strip its shield, *then* dash-slice to actually destroy it) and whose
players specifically call out the game's juicy VFX/screen effects as a
highlight. Not a source to clone assets or mechanics from -- a reference
for *pacing*: build anticipation, then punch.

Applied here as three concrete beats:
- **Building tension:** as a combo nears completion (e.g. 5 of 6 tiers
  held toward Full Set), the held tiers' pips read progressively
  brighter/faster-pulsing rather than sitting static -- the player should
  feel it coming before it lands.
- **The triggering pickup reads as distinct:** the gem that actually
  completes a combo gets its own brighter flash/trail on the way in,
  separate from an ordinary pickup's pip-pop -- it's the "slice," not
  just another "bump."
- **The payoff is a hard punch, not a fade-in:** a brief hit-stop
  (near-freeze for a few frames), a radial flash, and camera shake --
  all scaled to the combo's size, so Full Set/Ascension hit harder than
  Streak/Rampage. Reuses the same escalation logic already established
  for gems generally (quiet at rest, loud on collect), just at combo
  scale instead of single-pickup scale.

Not built -- see TODO.md.

### Backpack UI

The backpack should be visible on-screen as a real slot grid
(Minecraft-style), not an abstract fill bar. This makes upgrades
self-explanatory in play: Compacting is *seen* as a stack climbing
higher in the same slot, Bearing is *seen* as the grid growing, and
rarity is *seen* via the color-coded item border from the table above.
Fill% and HP shrink should feel visually linked (e.g. slots trending red
as the bag nears full, in sync with the HP bar draining) so the core risk
mechanic reads at a glance without any tutorial text. Built: a ghost slot
(`backpack_grid.gd`) previews the next Bearing purchase right in the
HUD -- fainter and dashed rather than solid, appearing one slot past the
real grid whenever Bearing isn't maxed, gone once it is.

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
- 2026-08-15 — v7 Enemy Types implemented: Bruiser and Elite built
  alongside the existing Minion, matching this doc's stats/roles exactly
  (Bruiser: HP 35, pause/charge state machine, contact damage only while
  charging; Elite: HP 40, kites to ~300px and fires a projectile dealing
  8 damage). `Enemy` was refactored into a base class with an
  overridable `_update_behavior()` so both share Minion's HP/hit-flash/
  death-spark plumbing. Per-tier loot weighting (`Enemy.loot_weights` +
  `LootTypes.pick_random_weighted`) and the Phase 1/2/3 spawn-mix gating
  from the "Spawn Rules" section are both wired into `arena.gd`. One
  deliberate deviation: Minion's own HP/speed were left at their
  already-shipped 30/120 rather than reconciled to this doc's 20/100
  baseline, since that would silently rebalance already-tuned content;
  Bruiser/Elite use this doc's absolute numbers directly rather than
  recomputing off Minion's real baseline. Distinct sprite art and full
  balance playtesting are still open — see TODO.md.
- 2026-08-15 — Post-v7 stock-take: audited every number and behavior in
  this doc against the actual code (loot table, stat curves, enemy
  stats/loot weights, spawn-phase mix, skill-tree gating, HUD/tooltip
  content) and fixed what didn't match. Two real gaps found and fixed:
  the difficulty ramp wasn't scaling Bruiser's charge speed or Elite's
  projectile speed (only the base `speed`/`max_hp` fields), contradicting
  the explicit "Scaling" notes on both tiers above; and the save/load
  system didn't actually support the 4-slot design — "New Game" always
  hardcoded slot 0 (and wiped all 4 slots' metadata doing it), there was
  no way to start fresh in slots 2-4, no "Overwrite" action existed,
  "last played" used engine uptime instead of a real timestamp (so it
  went nonsensical after any restart), and playtime never accumulated.
  All fixed — see TODO.md for the itemized list. Also updated this doc's
  own "Current implementation" summary, which had drifted (still said
  "as of v6" and "one enemy type" after v7 shipped).
- 2026-08-15 — Sketched a secondary backpack-fill penalty: move speed
  loss alongside the existing max-HP shrink, so a full bag also erodes
  mobility, not just survivability. Proposed shape reuses the same
  `lerp(1.0, min_fraction, fill_ratio)` curve `_update_hp_from_backpack()`
  already applies to `max_hp` (`scripts/player.gd`), with speed's
  own floor kept shallower (~0.7, i.e. −30% at a full bag) than HP's
  (0.2, i.e. −80%) — HP shrink stays the dominant, legible risk signal;
  speed loss is a secondary compounding pressure, not a replacement.
  Interesting side effect: since the fraction would apply after Swiftness
  upgrades, a maxed Swiftness investment (250→350 base) nets 245 at 100%
  fill — just under an un-slowed baseline — so Swiftness becomes a real
  counter-pick against greedy looting without fully negating the risk.
  Not built — needs `speed` to be recomputed on backpack change (it's
  currently set once in `_ready()`) before this can be wired in.
- 2026-08-15 — Fixed a real bug reported from live play: Bruiser/Elite
  could go permanently missing mid-run. Only Player was ever clamped to
  the 1280x720 arena (`scripts/player.gd`); `Enemy` had no equivalent,
  so a Bruiser's charge (or an Elite kiting away from the player) could
  carry it past the edge with nothing to bring it back — especially
  likely since real spawns start at arena edges. Once off-arena it's
  unreachable by the player's weapon and never dies, so it silently
  stops threatening the player and never drops its loot, reading as
  "enemy tiers and their gems went missing." Fixed with the same clamp
  Player already uses, applied generically in `Enemy._physics_process()`
  so it covers Minion and any future tier too, not just these two.
- 2026-08-15 — Backpack-fill speed penalty built: `player.gd` now
  recomputes an `_effective_speed` alongside `max_hp` whenever the
  backpack changes, using the same `lerp(1.0, floor, fill_ratio)` shape
  with a 0.7 floor (vs HP's 0.2), matching the shape sketched earlier
  today. Dash stays at its own fixed speed, unaffected — the penalty is
  on sustained movement, not the escape tool.
- 2026-08-15 — v9 Magic Spells implemented: single-active-spell casting
  (`spell_caster.gd`) replaces the old flat auto-fire weapon. Arcane
  Bolt fires a projectile at the nearest enemy; Inferno Blade hits
  everything in a facing-direction arc and applies a burn DOT (ticked
  over 3 intervals); Frost Nova hits everything in a radius around the
  player and applies Enemy's new `apply_slow()` status. All three scale
  with Spellpower proportionally to their own base Power value. Spell
  Unlock is a new gated Player Tree node (base cost 25, ×1.20/lvl, cap
  5) — L1 unlocks Inferno Blade, L2 unlocks Frost Nova, matching this
  doc's Spell System Structure exactly. The 8 per-spell upgrade stats
  (Haste/Velocity, Fury/Arc Width/Burn Damage, Frequency/Radius/Slow
  Strength) got invented cost curves, since this doc only specified
  their effect shape and caps, not costs — same treatment as v7's
  enemy contact-damage constants. One documented gap: Inferno's 200px
  knockback isn't implemented (Enemy has no knockback-velocity system
  yet); damage, burn, and arc-hit detection all work without it. Also
  fixed a skill-tree layout bug this surfaced: a node with more than 4
  children (Spell Unlock has 6) overflowed past the tree column instead
  of wrapping to a new row.
- 2026-08-15 — Live playtesting feedback: Inferno Blade's facing-cone
  requirement felt bad -- an enemy standing right next to the player
  wouldn't get hit if the player happened to be facing the wrong way,
  which breaks the auto-attack feel every other spell/weapon in this
  game has had ("the player's only input is movement/positioning,
  weapons fire automatically"). Changed to omnidirectional: hits
  everything within range regardless of facing. The "Arc Width"
  upgrade (90-180, was a cone angle) no longer has an angle to widen,
  so it's repurposed as "Reach" -- its value above the 90 baseline
  now adds directly to the hit radius instead. Stat ID and cost curve
  are unchanged, just what the number does and its display name.
- 2026-08-15 — Two small player-requested additions: Inferno Blade gets
  a small procedural flame-burst (`inferno_burst.gd`, an expanding ring
  with radiating spikes) on top of the existing generic spark particles,
  since being omnidirectional it has no travelling projectile to carry
  visual weight the way Arcane Bolt's does. The death/run-summary screen
  gained a "Restart Run" button alongside "Return to Sanctum", going
  straight back into `arena.tscn` for players who want to jump into
  another run without a shop stop in between.
- 2026-08-15 — Balance feedback: the backpack-fill speed penalty's −30%
  floor at a full bag felt too punishing stacked on top of the HP
  shrink. Shallowed the floor from 0.7 to 0.8 (`player.gd`'s
  `MIN_SPEED_FRACTION`), i.e. −20% at 100% fill instead of −30% — same
  lerp curve and HP-stays-dominant intent as the original sketch, just
  a gentler number. Also fixed an unrelated live-play bug found in the
  same session: Inferno Blade's cast sound played on every cast tick
  (~1/sec) regardless of whether it hit anything, reading as constant
  background noise — gated it to actual hits only and swapped the tone
  for a sharper whoosh/crackle sweep more fitting for a fire spell.
- 2026-08-15 — Balance feedback: Arcane Bolt's default fire rate felt too
  slow. Scaled its cast-rate curve (base and per-level Haste gain both)
  by 1/1.5 -- 0.5→0.33 sec/shot at level 0, 0.15→0.1 sec/shot at Haste's
  cap -- so it's 50% faster at every level, not just the starting point.
- 2026-08-15 — v10 Multi-Spell Casting: moved to the next roadmap item
  early, on direct player feedback that spells should stay on once
  unlocked rather than being switched one at a time. `spell_caster.gd`
  dropped its single shared `AttackTimer`/`active_spell` dispatch for
  three independent per-spell cooldowns ticked in `_process()`; Arcane
  Bolt's always counts down, Inferno Blade's and Frost Nova's only count
  down once `MetaProgression.is_spell_unlocked()` says so, so all
  unlocked spells fire concurrently and Arcane never pauses for them.
  Removed `MetaProgression.active_spell`/`set_active_spell()`/
  `active_spell_changed` entirely (including from save data) now that
  there's nothing to switch. The shop's spell panel changed from three
  switch buttons to a read-only status list (locked/unlocked, no click
  behavior) since picking one is no longer a choice the player makes.
- 2026-08-15 — Early-game rebalance, driven by data from the new headless
  playtest harness (`scripts/playtest_harness.gd`) rather than guesswork.
  A 20-run fresh-save baseline batch averaged only 10.1s survival / 1.8
  kills, with half the runs collecting zero loot before dying. Two
  changes, measured one at a time:
  - **Bug fix:** Minion's actual stats (`enemy.gd`'s `speed`/`max_hp`
    defaults, since `enemy.tscn` never overrode them) were 120/30 --
    this doc's Enemy Types table has always said 100/20. Restored to
    match the documented spec. Re-running the same baseline batch: kills
    nearly tripled (1.8→4.3 avg) and survival rose modestly (10.1s→11.6s).
  - **Balance call (not a spec value -- `CONTACT_DAMAGE` was an invented
    v7 constant, never documented):** kills roughly tripling while
    survival barely moved showed contact lethality, not weak player
    offense, was now the bottleneck. Eased 10→8 damage per hit (25→20
    effective DPS while in contact). Re-measured again: 11.6s→12.2s
    survival, 4.3→4.7 kills, zero-loot runs down to 3/20 from 10/20.
  Diminishing returns from the second lever suggests this is a reasonable
  stopping point for now -- further easing (e.g. the difficulty ramp's
  1.5×/1.6× floor at t=0, still per this doc's own "×1.5–3.0 by end"
  spec) would be a bigger, more deliberate softening of the documented
  "hard early game" philosophy rather than a bug fix or a small tweak,
  and is left for a follow-up round if the player still finds it too
  punishing after these two changes.
- 2026-08-15 — Correction to the entry above: the Minion HP/speed change
  wasn't actually a bug fix. The v7 entry earlier in this log explicitly
  says Minion was *deliberately* left at 30/120 rather than reconciled to
  this doc's 20/100, specifically to avoid silently rebalancing
  already-tuned content -- a decision I reversed without having
  cross-referenced that entry first. Surfaced to the player once found;
  decision was to keep 20/100 anyway, since the fresh playtest data (this
  entry's numbers) supports it feeling better than the original 30/120
  did. So: this is now a deliberate, informed re-decision superseding the
  v7 one, not an accidental fix that happened to also match the table --
  worth recording accurately since the two read very differently.
- 2026-08-15 — Cleared most of the open backlog in one pass, on direct
  request ("do it all"): Inferno Blade's 200px knockback (`Enemy` gained
  a decaying `_knockback` velocity, same shape as Player's own, applied
  in every behavior branch across Minion/Bruiser/Elite -- also fixed
  Bruiser's PAUSE state, which never called `move_and_slide()` at all
  before, so knockback would've silently done nothing there); Frost
  Nova's own expanding ice-ring visual (`frost_burst.gd`, sized to its
  actual radius stat) replacing the generic spark burst, which also
  caught `frost_cast`'s SFX playing unconditionally regardless of
  whether anything was hit -- the same bug fixed for Inferno Blade
  earlier, just not noticed here until now; Fast/Tanky Minion variants
  (same tier, same loot table, reuse `enemy.gd` directly -- just
  stat/tint overrides, splitting each phase's existing Minion weight
  70/15/15 rather than changing the documented tier ratios); and the
  Tier 4 Boss (unique, 55+ sec, guaranteed Mythic+ drop, hybrid
  pursuit+projectile-spread attack). All four verified via the playtest
  harness with no runtime errors (Boss specifically verified by
  temporarily lowering its spawn time to 5s -- getting a bot to
  naturally survive to 55s took heavy stat seeding and wasn't reliable
  enough on its own to confirm the code path). Also gave Bruiser/Elite/
  Boss their own sprite sheets (orc_warrior/orc_shaman/big_demon --
  already sitting in the DungeonTilesetII pack, imported but unused)
  instead of tinted reuse of the Minion's goblin frames, and built a
  real Settings screen (master volume, fullscreen, persisted to
  `user://settings.json` via a new `Settings` autoload, separate from
  MetaProgression since these are device prefs, not save-slot data).
  Two items from the same backlog pass are deliberately *not* done,
  flagged rather than guessed at: the cloud-sync backend needs an
  actual hosting/service decision no amount of code can substitute for,
  and mutually-exclusive skill-tree branches was already an open
  question this doc left unresolved on purpose (tension with "everything
  is eventually maxable") -- building either unilaterally would be
  guessing at a decision that isn't mine to make.
- 2026-08-16 — v11 Additional Spells implemented: Meteor Strike (boss-
  killer AOE with a telegraph-then-impact delay), Lightning Chain (arcs
  to the nearest unhit enemy up to 4 times, damage decaying per hop),
  Time Warp (Frost Nova's `apply_slow()` reused at a much bigger
  radius/duration for pure crowd control), Teleport Pulse (blinks the
  player in their current movement direction, damage at both ends,
  always fires even on a whiff since repositioning is the point), and
  Summon Familiar (a persistent pet -- `familiar.gd`, imp sprite frames
  from the same DungeonTilesetII pack -- that independently fires its
  own bolts at the nearest enemy). Spell Unlock's cap raised 5->7 to fit
  all five new tiers (L3-L7) alongside Inferno/Frost's existing L1/L2.
  Each new spell got exactly one upgrade stat (frequency, or duration
  for Familiar) instead of the 2-3 the original three got, keeping five
  new spells' worth of shop surface proportional -- shop's spell status
  list extended from 3 to all 8 entries to match. "Mana-limited" for
  Familiar is stood in for by a fixed resummon cooldown + upgradeable
  active-duration window rather than inventing a whole mana resource
  for one spell. Verified via the playtest harness across multiple
  batches (moderate and heavy seeding, plus a minimal-seed run to
  exercise the "no target found" guards) -- zero runtime errors with
  all 8 spells active and casting concurrently.
- 2026-08-16 — Sketched a pre-run Backpack Ability choice: Condense vs.
  Clear, both passively processing backpack items over time at a shared
  per-tier interval (rarer tiers process slower — Common 3s, Uncommon
  6s, Rare 12s, Epic 24s, Mythic 48s, Legendary never). Condense
  consumes 2 items of tier N every 2×interval and produces 1 item of
  tier N+1 (chain stops at Mythic — Mythic never condenses into
  Legendary, same reasoning as Legendary's existing Compacting
  exemption: it stays the one tier you can only get by looting it).
  Value climbs each conversion (Common→Uncommon 2×1→1×3, +50%;
  Uncommon→Rare 2×3→1×10, +67%; Rare→Epic 2×10→1×40, +100%; Epic→Mythic
  2×40→1×150, +87.5%) but since each tier is its own backpack slot
  (`type_id` == rarity in `loot_registry.gd`), producing a new tier
  keeps/opens that slot without freeing the source one — Condense can
  net *increase* occupied slots, so it only pays off with Bearing
  headroom to spare. Clear instead consumes 1 item of tier N every
  interval and banks its base value/item immediately as currency, no
  merge, item just gone — once a tier's count hits 0 its slot frees,
  which is what actually eases fill%. That split creates a natural pick
  that shifts with progression: Clear is the early-game choice (low
  Bearing, need the room), Condense the late-game one (capacity to
  spare, chasing value density) — without needing extra rules to force
  it. A single new Backpack Tree meta stat (name TBD, not "Compacting"/
  "Compactor" — already taken) would cut the interval for whichever
  ability is active that run, geometric cost/capped levels matching the
  existing framework (e.g. base −8%/lvl, cap 6, ~1.6× speed at cap) —
  one shared lever rather than two ladders, since a run only ever uses
  one ability. Not built — numbers are illustrative, not yet decided
  which ability (if either) ships first.
- 2026-08-16 — Backpack Ability implemented: both Condense and Clear
  shipped as a real pre-run choice (not just one of them -- "a choice"
  was the point of the sketch above), picked in `run_prep.tscn` and
  persisted per save slot. `backpack_ability.gd` mirrors
  `spell_caster.gd`'s per-timer pattern (one independent cooldown per
  rarity tier) rather than introducing a new pattern. The "single new
  Backpack Tree meta stat" got a name -- Alchemy -- and its curve
  resolved to a clean +0.1/lvl speed multiplier (1.0 base, cap 6) rather
  than the sketch's −8%/lvl interval reduction, since that lands on the
  exact same "~1.6× speed at cap" target more simply. Condense's produce
  step reuses `Player.collect_loot()` directly (so it inherits stack
  caps and Purge behavior for free, same as any other pickup); a new
  `Player.consume_loot()` handles the removal side for both abilities.
  Verified via the playtest harness with each ability temporarily forced
  active in turn (the harness has no seed hook for a StringName field
  like `active_backpack_ability`, only numeric stat levels) -- zero
  runtime errors either way, and Condense's runs showed visibly higher
  loot values as expected from the value-density mechanic.
- 2026-08-16 — Skill-tree rework decided: spells get their own dedicated
  tree/tab (Spell Tree) instead of living inside Player Tree plus a
  static read-only sidebar. Player Tree drops from 21 nodes to 3
  (Spellpower/Swiftness/Gleam only); the 18 spell nodes (Spell Unlock
  trunk + all per-spell upgrades) move to the new tree, trunk-and-branch
  shaped exactly like the existing gate logic already required (each
  spell's upgrades were already locked behind that spell's Spell Unlock
  level -- this just makes that structure visible and interactive
  instead of hidden inside a flat list). Spell Tree spends Essence, same
  as Player Tree -- deliberately not a new currency, since it preserves
  the two-currency risk tension while adding a real "spend on what I
  have vs. unlock something new" choice inside Essence itself. Tab names
  decided plain (Player / Spells / Backpack) over a more mystical set
  (Vessel/Grimoire/Hoard was considered and rejected), and Spell Unlock
  itself stays unrenamed -- both picked directly by the player this
  session rather than guessed at. No cost curves, stat IDs, or gates
  change -- pure regrouping plus a new tab, not a balance pass. See
  TODO.md for the implementation item; this is a design decision only,
  not yet built.
- 2026-08-16 — Audited every player-facing string in the game against
  TEXT_FLAVOR.md's tone (Mystical + Dark blend) and found the real
  inconsistency wasn't tone choice but an undocumented split between
  "Frame" text (titles/one-time narrative beats, worth flavor) and
  "Function" text (buttons/readouts/settings, read constantly, stays
  plain) -- most existing text already sorted cleanly into one or the
  other, it just was never written down as a rule, which let a few spots
  drift: the death screen shows a plain "RUN SUMMARY" header directly
  above the flavored "Lost to the Void" line (two titles, two registers,
  same panel), and the "Start Run" button is ALL-CAPS on one screen
  (run_prep) but Title Case on another (Sanctum) for the identical
  action. TEXT_FLAVOR.md rewritten as a definitive current-state spec
  (superseding its old options-brainstorm format) with the full audit,
  the specific fixes, and all of its previously-open questions resolved
  (no mandatory flavor text, enemy names stay plain, rarity tier names
  stay plain, a Grimoire/lore screen is a future idea not this pass).
  Also found: Essence (arcane) and Stardust (cosmic) read like mismatched
  registers in isolation, but every non-arena screen already shares the
  same night-sky background, which already reconciles them -- flagged as
  a nice-to-have connective line, not a problem to fix. See TODO.md's
  Tweak 2 for the implementation item; this is a design decision only,
  not yet built.
- 2026-08-16 — Backpack audit: found fill % has silently drifted from its
  intent. `backpack` is a dictionary keyed by rarity tier only, so
  `backpack.size()` (what drives fill %) is really "how many of the six
  tiers have been touched," hard-capped at 6 regardless of Bearing level
  -- Compacting and Bearing above level 6 currently have zero effect on
  survival risk, and fill % maxes out within the first few kills of any
  run (Common alone is 50% drop weight) then stays maxed for the rest of
  the run no matter how much more is collected. Not a documented design
  choice, a real implementation gap between the "Minecraft-style grid
  that visibly fills as you hoard" UI intent and what the number
  actually tracks. Fix decided: a slot becomes one stack instance of a
  tier (capped by that tier's Compacting stack size) instead of one
  dictionary key per tier -- a tier can span multiple slots once a stack
  fills, restoring fill % as a continuous measure of volume carried.
  Same HP/speed-shrink formula, only what counts as a slot changes. This
  also reconnects Compacting/Bearing/Discard/Condense-Clear to the risk
  mechanic they're nominally part of, none of which currently move fill
  % at all above 6 tiers held.
  Alongside the fix, added Gem Combos: a new, purely in-run layer with no
  currency/meta-progression tied to it (resets every run, available from
  run 1) -- holding one of each of the six rarity tiers simultaneously
  (order-agnostic, not strict succession, since combat timing is too
  chaotic for a hard-order requirement to read as skill rather than bad
  luck) triggers a one-time "Full Set" AOE clear, reusing Meteor
  Strike's telegraph/impact visual rather than new art. The strategic
  lever needed no new pickup mechanic: per-tier enemy loot weighting
  (Minion -> Common-heavy, Elite -> Rare+, Boss -> guaranteed Mythic+)
  already means which enemies a player prioritizes killing determines
  which gems they're chasing -- consistent with the core "only input is
  movement/positioning" pillar. Deliberately sequenced after the fill %
  fix: today, "holding one of each tier" already secretly means "bag is
  100% full," so rewarding that exact state right now would read as risk
  and payoff on the same ambiguous signal; once fill % tracks real
  volume instead, completing a set becomes its own clean, separate
  milestone. A second combo idea (3-of-a-tier "Streak," a small tier-
  flavored buff) noted but deliberately left out of this pass -- ship
  the one pattern first. See TODO.md's Tweak 3 for the implementation
  item; this is a design decision only, not yet built.
- 2026-08-16 — Dropped the numbered "Tweak N" staging scheme from
  TODO.md in favor of a flat "General improvements" list -- multiple
  parallel processes are iterating on different themes at once (this
  chat on backpack/gems, another on player-size/hitbox), so forcing new
  ideas into a specific numbered slot added friction without adding
  clarity. Kept everything that scheme was actually protecting (explicit
  In scope/Out of scope per item, real dependencies called out on the
  item that has one, file-overlap flagged as a coordination note); just
  dropped the numbering and the implied ordering. Also locked in the
  Gem Pickup Visual rework (see that section above): loot drops simplify
  to a small pip at rest instead of a fully-detailed crystal, with the
  visual payoff concentrated into the pickup moment instead -- direct
  response to gems reading as cluttered once several are on screen at
  once. And expanded the Gem Combos follow-up list with two more
  patterns (Rampage: volume/speed-based; Ascension: strict-order,
  Full Set's hard-mode cousin) alongside the existing Streak idea, all
  still deliberately deferred past Full Set. See TODO.md for the
  implementation items; these are design decisions only, not yet built.
- 2026-08-16 — Locked in combo-completion feedback, using *Hyperslice*
  (MrEliptik) as a pacing reference, not a source to copy -- a fast
  arena roguelite whose own core loop is a prime-then-deliver chain
  (stun/strip-shield, then dash-slice to finish) and whose players
  specifically praise its juicy VFX. Applied as three beats: held tiers'
  pips read progressively brighter as a combo nears completion (build
  anticipation), the triggering pickup gets its own distinct flash/trail
  instead of an ordinary pip-pop (it's the "slice," not the "bump"), and
  completion itself is a hard punch -- hit-stop, radial flash, camera
  shake scaled to the combo's size -- rather than a flat trigger. Same
  quiet-at-rest/loud-on-collect escalation already locked for individual
  gem pickups, just applied at combo scale. See TODO.md's gem visual
  item; not yet built.
- 2026-08-16 — Sketched a bigger replacement for the backpack-fill risk
  signal, driven by a playability problem rather than a balance one: the
  HUD's top-left backpack panel is hard to track mid-action in a
  fast-paced run, so the risk signal moves onto the player itself where
  it's unmissable. The player's own sprite grows with fill %, and the
  actual `CollisionShape2D` hitbox scales alongside it -- a fuller bag
  means a bigger, easier-to-hit target, not just a visual cue. HP-shrink-
  on-fill (`MIN_HP_FRACTION` in `player.gd`) is removed entirely, since
  the size/hitbox growth takes over as the risk lever it was providing;
  speed-shrink-on-fill (`MIN_SPEED_FRACTION`) is unchanged, so the two
  live risk levers become size/hitbox + speed instead of HP + speed.
  Deliberately sequenced after Tweak 3's fill % fix: fill % is currently
  hard-capped at 6 distinct tiers touched and doesn't respond to
  Compacting/Bearing above that, so building size scaling on the current
  broken formula would inherit the same bug rather than fixing it once.
  Whether the HUD backpack panel gets removed/simplified once the
  on-player signal exists is left open, not decided here. Queued as
  TODO.md's Tweak 4; not built.
- 2026-08-16 — Tweak 4 implemented, along with the fill-%-fix half of
  Tweak 3 it depends on (Gem Combos and the Compacting re-tune are still
  outstanding). `player.gd`'s `backpack.size()` (distinct tiers touched,
  hard-capped at 6) replaced with `_slots_used()` -- one slot per stack
  instance of a tier (`ceili(count / effective_stack_size)`), so a tier
  spans multiple slots once its current stack fills. `can_collect_loot()`/
  `collect_loot()` now gate on whether the next item would cross into a
  new slot (`_needs_new_slot()`), not just "is this a brand-new tier."
  HP-shrink-on-fill removed outright (`max_hp` no longer touches fill
  ratio at all); the freed lerp slot goes to a new `MAX_SIZE_FRACTION`
  (1.5, invented starting value, not yet playtest-tuned) scaling both the
  player's `AnimatedSprite2D` and its actual `CollisionShape2D` radius
  with fill %, on top of the existing unchanged speed-shrink. Local
  sub-resource shapes get `.duplicate()`d in `_ready()` before any
  runtime mutation, since scene-instanced local resources can otherwise
  be shared across `instantiate()` calls (the playtest harness spawns
  many Players per batch) -- this was a latent risk on the pre-existing
  pickup-range shape too, fixed alongside. Verified via the unit-test
  runner (7 new/updated cases covering the slot math and size/speed
  lerps, 198 total passing) and playtest batches at both a fresh-save
  1-slot capacity and a heavily-seeded 9-slot one -- the seeded batch's
  fill % moved gradually (11%/22%/33%) instead of jumping straight to
  100% within the first few kills, confirming the fix. Not yet checked
  visually/by a human -- headless can't confirm the sprite growth reads
  well or that the new hitbox size feels fair rather than cheap.
- 2026-08-16 — Live-play feedback on Tweak 4: the size/speed penalty
  ramped up too fast to let a run breathe. Root cause was mostly
  unrelated to the size/speed formula itself -- starting Bearing capacity
  was still 1 slot (a leftover v6 balance call, from back when the risk
  signal was HP-shrink, not size), so fill % jumped straight to 100% on
  the very first pickup instead of ramping over several. Fixed by raising
  Bearing's base_value from 1 to 5 (`meta_progression.gd`) -- per-level
  growth and cost curve unchanged, so the whole ladder just starts 4
  higher (level 10 cap: 15 instead of 11). `MAX_SIZE_FRACTION` also eased
  1.5 -> 1.3 on the same pass, a smaller adjustment on top of the bigger
  capacity fix. Both changes are numbers-only; the underlying mechanics
  from the prior two entries are unchanged.
- 2026-08-16 — Gem Combos' "Full Set" implemented (the other unbuilt half
  of Tweak 3, alongside the fill-%-fix already landed): holding one of
  each of the six rarity tiers simultaneously triggers a one-time-per-run
  AOE clear of every enemy currently alive, reusing `MeteorStrikeFx` for
  the telegraph/impact visual per the sketch. Lives in `spell_caster.gd`
  (not `player.gd`) -- it listens to `Player.loot_changed`, checks
  whether every tier is present after each backpack change, and on
  trigger spawns the FX and kills unconditionally (not radius-gated) on
  its `impact` signal, so it reliably reads as "clear everyone," not "hit
  whoever happened to be close." Killed enemies go through their normal
  `take_damage()` death flow (loot drop, kill-count, death FX intact) --
  a reward, not a wasted wave. Verified with a genuine end-to-end
  integration test (the suite's first async case: gives a real Player
  instance one of each tier, waits out the FX's real 0.5s telegraph
  timing, confirms a real Enemy instance actually dies), plus a heavily-
  seeded playtest batch reaching Phase 3 with zero errors -- though at
  Legendary's 0.5% drop weight, a Full Set naturally didn't fire in that
  short a batch, expected given how rare the trigger condition is by
  design. Compacting's per-tier re-tune (Tweak 3's third scope item) is
  still outstanding.
- 2026-08-16 — Removed the Backpack Ability (Condense vs. Clear) system
  entirely, on direct live-play feedback: gems were visibly vanishing
  from the backpack shortly after pickup (Clear's default behavior,
  auto-consuming one item per tier every few seconds), which directly
  fights the new fill-as-risk mechanic (Tweak 4) -- if items disappear on
  their own regardless of player choice, hoarding-vs-survival stops being
  a real decision. The two mechanics were sound independently but became
  incompatible once the backpack's role changed from "a number that
  shrinks HP" to "a visible, chosen risk." Deleted `backpack_ability.gd`
  outright (not just disabled) along with its `run_prep.tscn` pre-run
  choice UI, the `Alchemy` upgrade stat, and `active_backpack_ability`'s
  save-data field -- a half-removed feature (dead buttons, a orphaned
  shop-tree stat) would've been worse than a clean cut. `player.gd`'s
  `consume_loot()` stays -- it's a reasonable symmetric API to
  `collect_loot()` independent of what used to call it, and unit-test
  coverage of the backpack-fill-effects-on-removal path is worth keeping.
  This section (previously "Backpack Ability: Condense vs. Clear") is
  removed from the doc rather than left describing a feature that no
  longer exists; git history has the full spec if it's ever revisited.
  Verified via boot checks (`run_prep.tscn`, `shop.tscn`, `player.tscn`),
  the unit-test runner (195 passing -- the 4-assertion drop from 199 is
  expected, from one fewer stat def in the generic per-stat cost/cap
  tests, not a regression), and a playtest batch.
- 2026-08-16 — "Pips, not gems" implemented (per TODO.md's General
  Improvements item): `loot_gem.gd`'s resting-state faceted crystal
  (dual glow rings, three shaded facet triangles, an outline) replaced
  with two plain circles -- a solid pip plus a small offset highlight
  for a hint of shine -- both still tinted by rarity via the existing
  `modulate` pipeline, so no change needed anywhere that sets the color.
  `loot.gd`'s pickup moment absorbed the payoff instead: spark burst
  amount/scale increased, the "+N" floating text's font size bumped, and
  a new quick pop-and-fade tween on the gem sprite (scale up with a
  back-ease, fade to transparent, ~0.18s) plays before the node frees,
  where previously it just vanished instantly on collect. Movement
  (magnet pull/bob/pulse) stops the moment collection succeeds so the
  pop plays in place rather than mid-slide. Presentation only, per the
  item's explicit scope -- drop mechanics/weights/values untouched, and
  gems visually stacking on the player is still the separate, unresolved
  idea noted on the player size/hitbox item. Verified via boot check,
  the unit-test runner (195 passing, unaffected), and a playtest batch
  exercising pickups continuously across 10 runs with zero errors.
- 2026-08-16 — Second live-play pass on the gem visual: the pip still
  read as too big, and losing all facet detail lost the game's magic-gem
  aesthetic entirely -- a plain dot doesn't feel like "gem magic." Kept
  it small but gave it back an actual faceted-crystal silhouette (two
  shaded triangles + a bright cap, no glow ring or outline this time) at
  roughly a third the linear size of the original crystal; `loot.gd`'s
  own `SPRITE_SCALE` also eased 1.8 -> 1.3 on top, since the shape alone
  wasn't enough the first time. Also confirmed the loot-type/combo count
  question raised this session: `LootTypes` registers exactly six rarity
  tiers and Full Set's check reads `LootTypes.get_types()` generically
  (not a hardcoded 6), so nothing was actually out of sync there.
- 2026-08-16 — Combo-completion feedback and Streak implemented (the
  Hyperslice-referenced "Combo feedback" note, and the previously-
  deferred Streak pattern, both from TODO.md's gem visual item), with
  Streak's exact trigger/payout decided live rather than purely per the
  original "small tier-flavored buff" phrasing: 3 consecutive same-tier
  pickups (`SpellCaster.STREAK_THRESHOLD`) triggers an instant AOE damage
  burst at the player, radius 200, "tier-flavored" made concrete as
  damage scaling with tier rarity (Common weakest, Legendary strongest)
  rather than a flat number -- repeatable all run, unlike Full Set's
  one-time clear. Needed a new `Player.loot_collected(type_id)` signal,
  since the existing `loot_changed` only carries the resulting backpack
  state, not which pickup caused it. `Arena` gained a generic
  `trigger_shake(magnitude_scale, stop_duration)`, factored out of the
  player-hit case, so combo punches reuse the same screen-shake/hit-stop
  system rather than a new one -- Full Set's impact now triggers a 2x
  shake (added at the actual impact moment, after the existing telegraph,
  not at cast time -- the telegraph already builds tension, this is the
  punch), Streak a 0.6x one. "The triggering pickup gets its own distinct
  flash/trail" is approximated by Full Set's existing telegraph/impact FX
  landing at the player's position at the moment of completion, rather
  than building separate pre-pickup prediction wiring to flag one
  specific gem in advance -- reads as distinct in practice without the
  added complexity. Not built: the tension-building half of the combo-
  feedback note (held tiers' pips reading progressively brighter/faster-
  pulsing as Full Set nears completion) -- that's backpack-UI work
  (`hud.gd`/`backpack_grid.gd`), not gem-drop work, and deserves its own
  pass rather than a rushed version bolted on here. Rampage/Ascension
  remain unbuilt too. Verified via the unit-test runner (195 passing,
  unaffected) and playtest batches -- a moderate batch exercising
  frequent Streak triggers (10 runs, 5-20 kills each) and a heavily-
  seeded one reaching Phase 3 with fill% high enough to plausibly trigger
  Full Set (15 runs, up to 69 kills), both zero errors.
- 2026-08-16 — Third live-play pass on the gem visual: the previous
  resize went too far the other way -- `loot_gem.gd`'s facets sized back
  up (roughly 2.4x linear) and `loot.gd`'s `SPRITE_SCALE` with them
  (1.3 -> 1.6), aiming for "trackable/followable at a glance without
  cluttering the screen" rather than a specific number. Also added an
  Escape-triggered pause menu mid-run (Resume / Quit to Menu / Quit
  Game) -- there was previously no way to exit a run except dying or
  killing the process. Quitting mid-run abandons it like alt-F4 would
  (no death, no run-end currency award) rather than banking partial
  progress, which wasn't asked for and would be a real economy decision.
  `HUD`'s CanvasLayer is now `process_mode` ALWAYS so the Escape toggle
  keeps working after `get_tree().paused` is set (needed to detect the
  second press that resumes) -- mirrors the existing GameOverPanel's
  per-node ALWAYS pattern, just applied one level up since the whole
  pause flow, not just one panel, needs to survive the pause.
- 2026-08-16 — Direct feedback: the shake/burst/flash combo-completion
  juice told the player *something* happened but not *what*. Added a
  short callout above the player naming the combo -- "FULL SET!" (in
  Meteor Strike's own orange) and "STREAK!" (in the streaked tier's own
  color) -- reusing `floating_text.gd`, same component as damage numbers
  and loot-value pickups, positioned higher (-48px) so it doesn't
  compete with the burst/spark visuals at the same spot. Shared through
  one `_spawn_combo_label()` helper rather than each combo spawning its
  own copy.
