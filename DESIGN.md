# Design

A short, evolving record of design decisions — what the game actually is,
not just how it's built (that's CLAUDE.md). Update this as decisions get
made; don't try to fill it in all at once upfront.

## Genre

Top-down, Vampire Survivors-like roguelike, built on two simultaneous
input pillars rather than one: **auto-attack combat** (movement/
positioning is the only combat input — weapons fire automatically at
nearby enemies, no aiming or manual casting) and **active inventory
triage** (loot never auto-commits — every pickup is a deliberate
keep-or-discard decision, made in real time while still dodging).
Managing both at once, especially at volume during a heavy fight, is the
core skill the game is built around — not a side mechanic layered on top
of combat.

## Core loop

1. Run starts in an arena. Enemies spawn continuously and get harder /
   more plentiful the longer the run goes on.
2. Player auto-attacks nearby enemies and kills them; kills drop loot.
3. Loot doesn't auto-collect — each drop queues in front of the player,
   who actively **keeps or discards** it under pressure while still
   dodging combat. Kept loot goes into a capacity-limited **backpack**;
   discarded loot is gone for good. This active triage, not the backpack
   number itself, is the core skill the game is built around.
4. As the backpack fills up, the player **grows larger and slower** —
   fill % scales up the player's own size/hitbox (an easier target to
   hit) and shrinks move speed. The fuller the bag, the more exposed the
   player is. This is the core risk/reward tension: keep collecting loot
   vs. survive.
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

### Cloud sync — dropped (2026-08-17)

Was specced as meta-progression-only sync (upgrade levels, currencies,
unlock state; not run history), on run end + graceful quit, last-write-
wins conflict resolution, optional email-based device linking. A stub
autoload (`cloud_sync.gd`) shipped implementing the local-side plumbing,
but the actual server/backend was always a placeholder — see "Current
implementation" and the decision log's 2026-08-15 entry for that history.
Removed entirely on direct instruction rather than left blocked: not
wanted for now. Local-only saves (`SaveManager`, 4 slots) are unaffected
— this only removes the never-implemented cross-device sync layer. See
the decision log for the removal itself.

## Current implementation

What's actually built and playable today:

- Top-down movement + dash in a single arena; four enemy tiers (Minion
  with Fast/Tanky variants, Bruiser pause/charge, Elite kite +
  projectile, and a unique Boss at 55+ sec), phase-gated into the run
  (see "Enemy Types & Loot Tiers" below), spawning faster/more over run
  duration. Per-enemy drop tables were reshaped in a recent tuning pass
  (Minion now has a small Epic chance, Boss's Legendary odds raised) —
  see the decision log for the before/after numbers.
- Casting-based combat (`spell_caster.gd`): every unlocked spell casts
  simultaneously and independently, no switching. Arcane Bolt is always
  available; the other seven join permanently as their Spell Unlock tier
  (L1–L7) gets bought. Spellpower scales all of them proportionally
  (except Summon Familiar's own fixed pet stat).
- Six rarity tiers (`loot_registry.gd`/`loot_type.gd`). One item drops
  per kill, tier rolled by drop weight. **Pickup is no longer
  automatic** — Active Pickup: Manual Triage (see below) queues each
  drop in front of the player, who presses **K** to keep it or **L** to
  discard it (gone for good) while still dodging combat. Gleam now
  governs how far away a gem becomes eligible to queue, not how much
  gets auto-vacuumed in.
- A real slot-grid backpack (`backpack_grid.gd`) — fill % is driven by
  real slot count (one slot per stack instance of a tier, capped by that
  tier's fixed stack size; a tier spans multiple slots once its current
  stack fills), not by how many distinct rarities have ever been touched
  (an earlier bug in the fill-% formula, since fixed — see the decision
  log). Stack sizes are permanent per-tier constants now, not
  upgradeable — Compacting (the shop system that used to raise them) has
  been removed, see the decision log.
- **The backpack-fill risk signal is size/hitbox now, not HP.** A fuller
  bag grows the player's own sprite and actual `CollisionShape2D`
  hitbox — a bigger, easier target — on top of the existing speed-
  shrink. HP-shrink-on-fill was removed outright once this landed.
  Bearing's starting capacity was raised 1 → 5 slots after live-play
  feedback showed the size/speed penalty ramping up too fast otherwise.
- **Gem Combos**, a purely in-run tactical layer (no currency, no
  meta-progression, resets every run): **Full Set** (hold one of each of
  the six rarities at once → one-time AOE clear) and **Streak** (3
  consecutive same-tier pickups → repeatable AOE damage burst scaled to
  tier) are both implemented, with tension-then-release feedback (screen
  shake, a named callout — "FULL SET!"/"STREAK!"). Rampage, Ascension,
  and Ratio (a proportion-based defensive combo) are designed but not
  built — see "Gem Combos" below for the full matrix.
- Gem pickups (`loot_gem.gd`) render as a small faceted-crystal pip,
  color-coded by rarity, with the visual payoff concentrated at the
  pickup/keep moment (spark burst, "+N" text, a punchy pop-and-fade)
  instead of the idle/resting state — went through several live-play
  sizing passes before landing here.
- The Backpack Ability (Condense vs. Clear) system that used to sit here
  has been **removed entirely** — it directly fought the new fill-as-
  risk mechanic (items silently vanishing on their own undermines
  "hoarding is a chosen risk"). No longer part of the game.
- Phase-transition callouts ("BRUISERS!", "ELITES!", "BOSS!") announce
  when a tougher enemy tier — and the rarer loot that comes with it —
  becomes available, closing a gap where that gating was real but
  completely silent.
- An Escape-triggered pause menu (Resume / Quit to Menu / Quit Game) —
  previously the only way to leave a run was dying or killing the
  process.
- Two currencies (`meta_progression.gd`): Essence (loot value) funds
  Player Tree and Spell Tree; Stardust (survival time) funds Backpack
  Tree. Geometric cost curve, hard level caps throughout.
- Shop is currently a two-tree skill-tree layout (Player Tree /
  Backpack Tree); the 8 spells' unlock/upgrade stats still live inside
  Player Tree today, with a separate read-only sidebar just showing
  lock state. A three-tree rework (Player / Spells / Backpack, see
  "Shop structure: skill tree" below) is designed but **deliberately on
  hold** until the current run of mechanics-focused work (backpack /
  pickup / combos) settles — see TODO.md.
- Death → full run summary screen (time/phase, rewards, loot breakdown,
  run stats, previous best) → shop → restart with upgrades carried
  over. Predates everything above this line, though — doesn't yet
  reflect Gem Combo activity, and some of its stat labels have drifted
  from what the game now actually tracks. Flagged as its own rework,
  not yet started — see TODO.md.
- Persistence: 4 save slots with metadata, local-only. Cloud sync was
  specced and stubbed but never had a real backend, and was dropped
  entirely 2026-08-17 rather than finished — see "Cloud sync" above.

Not yet built: real spell/enemy sprite art (spells and Player are still
procedural/placeholder); an in-game reference teaching any of the above
(spells, Gem Combos) to the player — right now it exists only in this
doc — see [TODO.md](TODO.md) for these and other open follow-ups.

## Enemy Types & Loot Tiers

Four enemy tiers, each with distinct attack pattern and loot weighting. Higher-tier enemies drop better loot, creating progression incentive: survive longer → face harder enemies → earn better loot → upgrade → tackle longer runs.

### Tier 1: Minion (baseline, current)

**Attack:** Simple melee chaser. Moves toward player continuously.

**Stats:**
- Base HP: 20
- Base speed: 100
- Attack: On-contact damage
- Scaling: HP and speed scale with run duration (45-sec ramp, ×1.5–3.0 by end)

**Loot:** 55% Common, 30% Uncommon, 14% Rare, 1% Epic

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

**Loot:** 15% Common, 40% Uncommon, 30% Rare, 13% Epic, 2% Mythic

**Role:** Introduces evasion timing; requires dodge-ability

### Tier 3: Elite (late-game)

**Attack:** Projectile ranged attacker. Fires every 1.5–2 sec from ~300 pixels away.

**Stats:**
- Base HP: 40 (+100% vs Minion)
- Base speed: 120 (faster, maintains distance)
- Projectile speed: 150
- Scaling: HP and projectile speed scale with run duration

**Loot:** 3% Common, 12% Uncommon, 30% Rare, 40% Epic, 15% Mythic

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

**Loot:** Guaranteed Mythic+ -- 65% Mythic, 35% Legendary. Skips the
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

**Status quo (implemented, `hud.gd`/`arena.tscn`):** a top area showing
Time (MM:SS), Essence, and Stardust (updated at
`STARDUST_UPDATE_INTERVAL` = 0.1s so the live counter doesn't visibly
stall between real currency awards), plus a StatsPanel lower-left
holding the HP bar, the `BackpackGrid` slot grid + live Essence-from-
loot value, and a single `MetaStatsLabel` text line: `Swiftness: X
Gleam: Y   Bearing: Z`. This line predates Gem Combos and Attunement
and is the specific thing this pass fixes -- not by replacing it, each
of the three is still individually a correct, meaningful number, but
the *set* is stale: it has no slot for Attunement, a constantly-
changing, build-defining number every run now has. (Pacts/Burden would
have needed a slot here too -- moot, Pacts was binned 2026-08-17, see
"Group E: Pacts" above.)

**Decided additions (2026-08-17):**
- **Attunement gauge.** A small horizontal bar reusing `StatBar` (the
  same component the HP bar already uses -- per CLAUDE.md's own
  guidance against a second hand-rolled bar widget when one exists),
  placed directly under the Loot row so cause (bag contents) and effect
  (the gauge) sit together. Reads `Player.get_attunement()` live,
  refreshed on the same `loot_changed` signal the panel already listens
  to (fires on every pickup/discard, exactly when Attunement can move).
  Low/High ends get the same cool/warm color language Group D's spec
  already reserved for the optional spell-VFX tint, so the gauge and
  the spell feel read as one concept, not two unrelated color systems.
- **Combo-nearing pips, on `BackpackGrid`.** Two independent cues, since
  Full Set and Streak already track independently (per
  `spell_caster.gd`'s own comment: picking up a 6th distinct tier can
  complete a Full Set *and* count toward a Streak in the same pickup):
  - **Streak:** the single most-recently-filled slot (tier ==
    `SpellCaster.get_streak_tier()`) lerps toward white as
    `(get_streak_count() - 1) / (STREAK_THRESHOLD - 1)` climbs from 0.0
    (first pickup of the streak) to 1.0 (one more pickup triggers it) --
    only that one slot, so the cue points at *which* tier is hot, not
    just that something's building.
  - **Full Set:** once exactly `LootTypes.get_tier_count() - 1` (5 of 6)
    distinct tiers are held, every currently-filled slot gets a shared,
    slower pulse -- deliberately binary (on at 5/6, off otherwise), not
    a gradient from 0/6, since anything earlier than "one pickup away"
    isn't actually "nearing," it's just normal collection.
  Technical: `BackpackGrid.update()` gains two new optional parameters
  (streak tier + progress, full-set-near bool) computed by `hud.gd` in
  its existing pickup-signal handlers, not inside `BackpackGrid` itself,
  which stays a pure renderer with no combo knowledge of its own
  (matches its current role -- it already has no idea what a "tier" or
  "combo" means beyond colors and counts). `SpellCaster` needs two small
  new getters over state it already tracks (`_streak_count`,
  `_streak_tier`) -- `get_streak_count() -> int` and
  `get_streak_tier() -> StringName` -- no new tracking, just exposure.
  Full Set progress needs no `SpellCaster` getter at all: `hud.gd`
  already receives the live `backpack: Dictionary` on every
  `loot_changed` signal and can count non-zero tiers against
  `LootTypes.get_tier_count()` directly.

### Death Summary Screen

**Status quo (implemented, `hud.gd`'s `_build_summary_bbcode()`):**
title, Time Survived, Difficulty Reached (Phase), Rewards
(Essence/Stardust), Loot Collected breakdown, Max Backpack Fill %,
Enemies Killed, and a single "Highest Previous Run" line comparing only
survival time. Same staleness as the in-run panel: one record tracked
(time).

**Decided additions (2026-08-17):**
- **Three new personal-best categories**, alongside the existing
  survival-time record, each following `update_best_run()`'s existing
  "return the previous value, then overwrite" pattern so `hud.gd` can
  compare and show "New Record!" only for whichever ones a given run
  actually broke, rather than always dumping all four:
  - **Richest** -- `total_value` (Essence earned) at death.
    `MetaProgression.update_best_essence(int) -> int`, new persisted
    `best_run_essence: int`.
  - **Leanest** -- not "died fast at low fill" (a non-achievement, not
    skill), and not a raw fill percentage either (rewards suicide at
    0%). Scored as `seconds_survived * (1.0 - max_fill_ratio)`: credits
    surviving *long* while staying *light*, zero for either extreme (an
    instant death scores ~0 regardless of fill; a long run at 100% fill
    scores 0 regardless of duration). `get_max_fill_ratio()` already
    exists and already feeds the current "Max Backpack Fill %" line, so
    this is arithmetic over an existing number, not new tracking.
    `MetaProgression.update_best_leanness(float) -> float`, new
    persisted `best_run_leanness: float`.
  - **Most Refused** -- total discards (L presses) in the run. No
    existing counter: `Player` gains `_discards_this_run: int`,
    incremented in `_check_triage_input()`'s existing discard branch
    (right where `resolve_discard()` is already called), exposed via
    `get_discards_this_run() -> int`.
    `MetaProgression.update_best_discards(int) -> int`, new persisted
    `best_run_discards: int`.
  All three persist through the same save export/import/reset path
  `best_run_time` already uses -- same category of value, same
  treatment, no separate design needed.

Technical summary for this whole section: `hud.gd`'s `_on_player_died()`
is the single call site touching all of the above -- it already computes
`total_value`/`seconds_survived` and calls `update_best_run()` there, so
the three new `update_best_*()` calls slot into the same function, then
thread through into `_build_summary_bbcode()`'s existing parameter list
rather than a parallel code path.

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

**Status:** Fully implemented -- skill tree tooltips
(`scripts/ui/skill_tree_view.gd`), the in-run overlay and death summary
(`scripts/ui/hud.gd`, `scenes/arena.tscn`) including combo-nearing pips,
the Attunement gauge (`HUD/StatsPanel/.../AttunementRow`, a `StatBar`
reused per the note above), and all three personal-best categories
(`MetaProgression.update_best_essence()`/`update_best_leanness()`/
`update_best_discards()`, `Player._discards_this_run`).

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
  capacity (Bearing) and Discard. (Used to also fund per-tier
  Compacting — removed, see the decision log.)

Rate (v6 balance): `backpack_currency = round(0.05 × seconds_survived)` — 0.05
currency per second alive. Very gradual accumulation; a 60-second run
earns ~3 currency. Designed so player upgrades (from loot) drive early
progression, while backpack upgrades (from survival time) come later as
a long-term goal. Capacity (Bearing) remains a prestige milestone,
20+ runs in for a meaningful investment — now the sole backpack-capacity
lever, see "Backpack-track upgrade curve" below.

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

- **Backpack Tree** is now just two nodes: Bearing at the root (always
  purchasable) and Discard, gated behind Bearing's first level bought —
  reusing the same "previous node bought once" gate as everything else
  in the shop rather than a separate threshold rule. Used to be a longer
  chain (a five-node Compactor ladder plus Alchemy) — both removed, see
  the decision log for why. Much smaller tree now, deliberately: the
  backpack's identity moved to the in-run layer (Active Pickup, Gem
  Combos) rather than a shelf of permanent passive purchases.
- **Player Tree** is flat: just Spellpower, Swiftness, and Gleam, no
  cross-gating between them, since nothing in the design requires one
  before another. (Spell Unlock and all per-spell upgrade stats have
  moved out to the Spell Tree below — Player Tree used to carry all of
  that too, which is what made it feel cluttered.)
- **Spell Tree** (new, split out of Player Tree): Spell Unlock is the
  gated trunk (unchanged ladder — L1 Inferno Blade through L7 Summon
  Familiar). Each level's node branches into that spell's own upgrade
  stats, reusing the same "previous node bought once" gate pattern used
  throughout the shop, just applied to spells instead of a gear ladder.
  Arcane Bolt's two upgrades (Haste, Velocity) branch
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

### Sanctum UX: node language, feedback, and previews

Pressure-tested and fully specced 2026-08-17, from an IDEAS.md research
pass on what makes skill trees fun/legible elsewhere (see the decision
log for the source verdict: the three-tab structure above is *confirmed*
by that research, this section is what got added/fixed on top of it,
not a replacement for it). **Still on hold** with the rest of the shop
rework — this amends that plan, it doesn't lift its hold.

Five presentation fixes, all pure UX — no stat IDs, costs, gates, or
currency behavior change anywhere in this section:

**1. Currency-progress ring.** The locked geometric cost curve (see
"Player-stat upgrade curve" below) means late-game nodes take many runs
to afford — a 60-second run earns ~3 Stardust against Bearing's first
level costing 100 — so most Sanctum visits currently show *no visible
change at all* on an unaffordable node beyond a red-tinted border. Draw
a partial-fill ring around each node showing `current_currency ÷
next_level_cost`, recomputed live every time currency changes (same
signal `_refresh_currency()` already listens to). A node that crosses
into affordable *since the shop was last opened* gets a one-off shimmer
on open (compare current currency against a snapshot taken on shop
*close*, not per-frame — the shimmer is a "welcome back" cue, not a
live effect). **The ring disappears once a node is maxed** — nothing
left to save toward, see point 3 below for what maxed nodes show
instead.

**2. Node shape/size encodes kind, not tree structure.** Real bug, not
just a preference: `_get_node_radius()` currently draws the large
"capstone" circle for any node with zero children, which means a flat
leaf stat with no further upgrades (e.g. Inferno Fury, +damage) renders
*larger* than Spell Unlock, which unlocks an entire spell — visual
weight is inverted from actual importance, an accident of tree
topology rather than a design choice. Fix: add an explicit `is_milestone:
bool` (or similar) to `StatDef` so size/shape is asserted, not inferred
from "happens to have no children" — milestone nodes (Spell Unlock's
trunk, Discard) get the large/distinct treatment regardless of what
branches off them; flat stats stay small regardless of whether anything
branches off them. Separately, `_chain_remaining_roots()` currently
links Player Tree's three unrelated flat stats (Spellpower/Swiftness/
Gleam) with a cosmetic dashed line so the tree "reads as one flowing
branch" — this implies an order/flow the design explicitly does *not*
have (Player Tree is deliberately ungated, see above). Remove the
cosmetic chaining. **Real technical risk flagged, not assumed solved:**
confirm the tree-layout algorithm can still position multiple
disconnected roots sensibly side-by-side without that chaining hack
before removing it — it may currently be load-bearing for layout, not
just visual.

**3. Level/cap moves onto the node itself.** Second real bug found
alongside #2: the level-pip row under each node draws `level_cap` pips
at 7px each, so a 20-level stat like Spellpower draws a 140px-wide row
against ~66px of node spacing — it currently overlaps its neighbors.
Replace the pip row with a partial arc drawn around the node's own edge
showing `level ÷ level_cap` — this is a *different* ring from point 1's
currency-progress ring (that one shows progress toward the *next*
level's cost; this one shows overall progress toward the *cap*) and
they coexist: currency ring outside, level arc as the node's own border
treatment, distinguishable by weight/style not just position, since a
node can be simultaneously "3 of 20 levels bought" (arc) and "60% of
the way to affording level 4" (ring). Once a node hits its cap, the
level arc closes to a full ring and the currency ring (nothing left to
buy) simply stops rendering — replaced by a **sealed** state (see point
4). Freed screen space also fits a small per-tab "N affordable" count
on each tab button, so a player can tell which tab is worth entering
before entering it.

**4. Purchase-moment feedback, including for maxed and denied clicks.**
Every purchase currently fires the same spark burst / `"purchase"`
sample / currency-bounce regardless of level — level 1 and level 20
(the cap) are indistinguishable, and clicking a node you can't afford
does *nothing at all*, not even a refusal. Three fixes, each reusing
something that already exists rather than new systems: step the
purchase tone's pitch with the node's post-purchase level (the
procedural-tone approach `audio_manager.gd` already uses elsewhere,
parameterized by level); give a maxed node a **sealed** visual state —
a distinct border/glow treatment, not just a barely-different alpha
(today's maxed state is 0.9 alpha vs. locked's 0.7 — functionally
invisible at a glance) — plus a one-off resolve cue the moment a node
*becomes* maxed; and make a denied click (can't afford) answer with a
short shake and the shortfall amount. **Technical note:** the shop
scene has its own existing juicy-button feedback pattern (`juicy_button.gd`,
already used for save-slot buttons) — reuse/extend that for the denied
state rather than assuming the Arena's combat screen-shake system
(`trigger_shake`) applies outside the arena scene; they're different
scenes with no shared shake infrastructure today.

**5. Preview the effect where the effect is previewable.** Tooltips
currently describe upgrades in spreadsheet grammar ("5 → 6", "+2").
Where a node's effect is inherently spatial, show it instead of stating
it: hovering Bearing should ghost-preview the slot it would add, reusing
the *exact* ghost-slot concept already built for the in-run HUD
(`backpack_grid.gd`'s existing Bearing-preview ghost slot) — note this
needs its own instance embedded in the Sanctum's Backpack tab, since the
existing one lives in `arena.tscn`'s HUD, a different scene; the concept
carries over, the node doesn't. **Scoped honestly, not oversold:**
Bearing's preview is close to free (the mechanism already exists
elsewhere). Gleam (pull radius) and Discard (Cast Off's throw, now that
Cast Off is implemented) have no equivalent existing preview to reuse —
there's no live arena in the shop scene to visualize range or a throw
arc against, so these need a lightweight *abstract* diagram (a static
reference icon + radius circle, not a gameplay simulation) built from
scratch. Treat Bearing's preview as the first target; Gleam/Discard
previews are real, separable follow-on scope, not bundled into the same
estimate.

**Visual-load caution, worth stating plainly:** points 1-4 each add
their own encoding to a single small node — a currency ring, a level
arc, a sealed/maxed state, an affordability border tint (already
existing) — stacked on a circle that's currently ~66px apart from its
neighbors. Individually each is well-motivated; together they risk
turning "legible" back into "busy," which is the opposite of what this
whole pass is for. This needs an actual windowed look once built, per
CLAUDE.md's own testing tiers (visual/feel work can't be verified
headless) — treat the combination as unverified until someone's
actually looked at it, not as self-evidently fine because each piece
individually made sense on paper.

### Spell Choice

A real mechanic/economy change, not a presentation fix — kept separate
from the UX pass above on purpose, since it touches already-shipped,
already-tested behavior (the Spell Unlock ladder) rather than just how
existing behavior is drawn.

**The problem:** Spell Unlock's L1-L7 ladder maps to a fixed spell order
(L1 Inferno, L2 Frost, ... L7 Familiar) — every save, every player,
unlocks spells in the exact same sequence forever. Cited precedent for
why this matters: Hades 2's Arcana Cards were built specifically to fix
this same complaint about Hades 1's Mirror ("every player was unlocking
every skill in the same order"), and the developers point to Arcana as
generating meaningfully more personal investment as a direct result.

**The fix:** at each Spell Unlock trunk level, offer a choice of 2 of
the remaining not-yet-chosen spells rather than a single fixed one.
Costs nothing in the locked economy — level N still costs what level N
costs, the cap stays 7, Essence is unaffected; only *which spell* a
given level grants changes from fixed to chosen.

**What this preserves on purpose:** the ladder currently doubles as a
difficulty ordering, not just an unlock order — Summon Familiar sits at
L7 deliberately, as a final-tier capstone. A fully free-choice pool
would lose that. Resolution: **Summon Familiar is only ever offered as
one of the two choices at the final trunk level (L7), never earlier** —
keeps the capstone-difficulty intent while still giving real choice at
every other tier.

**Real ambiguities resolved here, not left open:**
- **Choice UI is a new interaction pattern for this shop** — every
  other node today is "click to buy," full stop. Buying a Spell Unlock
  level becomes a two-step flow: buy the level, then pick one of the two
  offered spells. Needs its own modal/panel, not an inline tree
  interaction — flagged as real, non-trivial UI scope, not a small
  addition to the existing tree view.
- **Save compatibility.** Existing saves already have levels bought
  against the old fixed order. Resolution: on first load under the new
  system, treat each already-unlocked spell as having been "chosen" at
  the level it was actually bought at (a one-time migration, not a
  wipe) — no player loses progress or has an unlock silently revoked.
  This needs to actually be implemented as a migration step, not
  assumed to fall out for free.
- **Persistence:** which spell was chosen at which level is new
  per-save state (`MetaProgression` needs a new field — the old system
  only needed to know *how many* levels were bought, since the mapping
  was fixed; the new one needs to know *which* spell each bought level
  actually granted).

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
Bearing gets its own table here; Discard (already threshold-shaped) gets
its own leveled cost curve in its own section below. (Compacting used to
have a table here too — removed, see the decision log.)

| Stat | Base | Per-level gain | Base cost | Cost growth | Level cap | Value at cap |
|---|---:|---:|---:|---:|---:|---:|
| Bearing | 5 slots | +1 slot | 100 | ×1.25/lvl | 10 | 15 slots (3×) |

(Base raised from the original 1 slot to 5 during the size/hitbox
rework's live-play tuning — see the decision log.)

Bearing is deliberately the prestige upgrade — expensive (base cost 100)
and steep cost growth (×1.25/lvl). It's now the *only* backpack-capacity
lever (Compacting's removal means stack sizes per tier are fixed, not
purchasable) — each new slot is a direct, uncomplicated capacity gain,
and, especially at the higher levels, a major milestone/level-up moment
that keeps engagement high through a long progression series.

**Fill %** = slots used ÷ capacity, where **one slot is one stack
instance of a tier** (capped at that tier's fixed stack size) — a tier
can occupy more than one slot once its current stack is
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

### Active Pickup: Manual Triage

**Locked in — a genuine pivot, not an addition.** The backpack has been
sitting at the center of this game's pitch since the first decision log
entry, but pickup itself has always been fully automatic (magnet in,
auto-commit) — there's no actual *management* happening, just RNG
accumulation from whichever enemies happened to die nearby. This replaces
that with a real decision point: gems still magnetize toward the player
within Gleam range, but instead of auto-committing, each one queues in
front of the character awaiting input — one button keeps it (adds to the
backpack), another discards it (**gone for good**, no banking, matching
Discard's existing philosophy — see "Discard upgrade" below). Movement
stays entirely automatic-combat-free per the Genre pillar above; triage
is the second, equally-weighted input pillar layered on top of it.

**Queueing, not throttling — deliberately.** When multiple gems arrive
faster than they can be triaged (a cluster of kills, or Full Set's own
AOE clear dropping several at once), they queue rather than being
auto-resolved or dropped. No auto-timer, no default-to-keep safety net —
direct call: "managing that at scale isn't an issue, it's the fun."
Processing a backlog quickly and correctly *while still dodging* is the
intended skill ceiling, not something to design away. A neglected queue
is its own visible, felt pressure rather than a forced countdown.

**Gleam's role shifts** from "how much gets vacuumed in" to "how far
away a gem starts being eligible to enter the queue" — same stat,
different job, since there's no longer a pure auto-collect volume to
scale.

**Downstream effects, not yet resolved:**
- The already-implemented "pips, not gems" pickup pop (spark burst, "+N"
  text, punchy scale-tween — see "Gem Pickup Visual" below) needs to move
  from "plays on magnet-arrival" to "plays on the keep decision" — the
  visual language stays, just re-anchored to the new trigger point.
  Queued/pending gems need their own held-in-place visual treatment,
  not yet designed.
- Gem Combos (Full Set, Streak, and the considered Ratio pattern below)
  become skill-driven once backpack contents are curated on purpose
  instead of accumulated by luck — likely changes how often they
  realistically fire and may need rebalancing once this lands, since
  their existing numbers were tuned against full-auto pickup.
- Two different "gone for good" mechanics now coexist and need
  distinguishing in eventual UI/flavor text: this manual per-pickup
  discard, and the existing threshold-triggered Discard upgrade. Not a
  blocker, just flagged so they don't read as the same thing.

**Status:** Implemented (`player.gd`'s `enqueue_loot()`/`_advance_queue()`/
`_check_triage_input()`, `loot.gd`'s `enter_queue()`/`resolve_discard()`).
Keep = **K**, Discard = **L** (dedicated keys, chosen over mouse click to
keep both hands on the keyboard through a run). Bots (the playtest
harness) skip the queue entirely and collect exactly as before, so
balance-signal batches stay meaningful without simulating triage
decisions -- see the decision log for the full writeup, including what's
still open (queued-gem visual treatment, combo rebalancing).

### Gem Pickup Visual

Loot drops (`loot_gem.gd`) used to render as a fully-detailed faceted
crystal at rest — same level of visual detail whether one enemy died or
six did, which is why they read as cluttered once they piled up
mid-fight. **Simplified to a small pip at rest** — color-forward, most
of the facet/glow-ring detail dropped — with the visual payoff
concentrated at the pickup/keep moment instead (spark burst, "+N"
floating text, a punchy pop-and-fade). Quiet on the ground, loud on
collect. Presentation only — the one-drop-per-kill mechanic, drop
weights, and values are unchanged; if a real multi-drop-per-kill
mechanic is wanted later, that's a separate balance decision, not this
one.

**Status:** Implemented, after several live-play sizing passes (see the
decision log) — the very first pass over-simplified into a plain dot and
lost the "gem magic" read entirely, so it landed on a small
faceted-crystal silhouette rather than either extreme. Combo-completion
feedback (screen shake, radial flash, a named callout) is also live —
see "Gem Combos" below. Still open: the "tension-building"
pre-completion pip-brightening cue — that's backpack-UI work, not
gem-drop work, tracked separately in TODO.md.

### Loot affixes

Epic+ drops have a chance to roll "Blessed" -- 15% for Epic, 25% for
Mythic, 40% for Legendary; Common/Uncommon/Rare never roll one. A
Blessed item is worth +50% more and reads distinctly in the moment
(brighter gold-shifted color, a bigger pulse, a "+X Blessed!" floating
text) but the bonus is banked immediately as extra currency rather than
living on the item itself.

That's a deliberate scope cut, not the full vision: the backpack tracks
a *count per tier*, not individual item instances (that's what makes
stacking work at all), so there's no slot to durably attach a modifier
to. Reworking to per-instance tracking just to support affixes would be
a real architecture change with knock-on effects on Discard and the
loot grid UI -- out of scope for what this doc actually asked for. A true persistent-modifier version (visible in the backpack
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

### Discard upgrade

A single, late-game upgrade (formerly "Purge"): once bag fill crosses a
threshold (e.g. 90%), automatically discards the lowest-rarity item(s)
to free space instead of blocking further pickups. Only becomes
relevant once Bearing's slot count is near its ceiling and fullness is
still the thing killing runs — a last safety valve after the run's
been fully invested in, not a substitute for it. Gated behind Bearing's
first level bought (reused the standard "previous node bought once"
gate) — previously gated behind Compacting's Rare Vault node, re-pointed
here when Compacting was removed, see the decision log.

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

**Quick-reference matrix** (balancing reference — check against the
decision log / actual code for exact live numbers, which have already
moved more than once during live-play tuning; re-sync this table if they
move again without it being updated here):

| Combo | Trigger | Effect | Repeatable? | Feedback | Status |
|---|---|---|---|---|---|
| **Full Set** | Hold 1 of each of the 6 rarity tiers simultaneously, order-agnostic | AOE clear — kills every enemy currently alive | One-time per run | 2x screen shake + "FULL SET!" callout (Meteor Strike orange) | ✅ Implemented |
| **Streak** | 3 consecutive same-tier pickups, uninterrupted (`SpellCaster.STREAK_THRESHOLD`) | Instant AOE damage burst at the player, radius 200, scales with tier rarity | Repeatable, all run | 0.6x screen shake + "STREAK!" callout (tier's own color) | ✅ Implemented |
| **Rampage** | Volume/speed threshold — illustrative only (~8 pickups within 5s, any tier), not locked | Brief buff rewarding aggressive clear speed — not yet specified | TBD | TBD | ❌ Considered, not built |
| **Ascension** | Strict ascending order, Common → Legendary, no break — exact break condition undecided | Bigger/different payout than Full Set — not yet specified | TBD | TBD | ❌ Considered, not built |
| **Ratio** | Hold two tiers in a specific proportion — illustrative only (2 Uncommon : 1 Common), not locked | Short-radius repel/pushback pulse, ~2 sec — the first defensive/utility combo, the rest are offense or buffs | Repeatable (as long as the ratio holds) | TBD | ❌ Considered, not built |

Also not yet built for either implemented combo: the "tension-building"
half of combo feedback (held tiers' pips reading progressively brighter
as Full Set nears completion) — that's separate backpack-UI work
(`hud.gd`/`backpack_grid.gd`), flagged in the decision log, not done yet.

**Full Set:** holding one of each of the six rarity tiers simultaneously
(order-agnostic, not strict succession) triggers a one-time-per-run AOE
clear of every enemy on screen, reusing Meteor Strike's telegraph-then-
impact visual rather than new art. Order-agnostic was a deliberate
choice over a strict-sequence requirement — combat timing is too chaotic
for a hard order to read as skill rather than bad luck.

Originally designed to need no new pickup mechanic at all: which enemy
tier a player prioritizes killing already determines what drops, via the
existing per-tier loot weighting (Minion → Common-heavy, Bruiser →
Uncommon, Elite → Rare+, Boss → guaranteed Mythic+) — "strategically
chasing the missing gem" was already a real lever through targeting
alone. That premise has since been overtaken in a good way: Active
Pickup: Manual Triage (see below) means completing a set is no longer
just about who you kill, but also whether you actually keep each needed
drop when it queues — two stacked levers, target-priority and
keep/discard curation, instead of one.

Deliberately sequenced after the Fill % fix above: before that fix,
"holding one of each tier" secretly meant "bag is 100% full," so
rewarding that exact state would have read as risk and payoff on the
same ambiguous signal. Fill % now tracks real volume instead of
tier-diversity (see the decision log), so completing a set reads as its
own clean, separate milestone.

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
- **Ratio** — hold two tiers in a specific proportion (e.g. 2 Uncommon to
  1 Common) rather than a fixed count or full diversity, triggering a
  short-radius repel/pushback pulse. The first *defensive/utility* combo
  in the set — Full Set/Streak/Rampage/Ascension all lean offense or
  buffs, this is a "buy yourself space" panic tool instead. Only really
  makes sense once backpack contents are deliberately curated (see
  "Active Pickup: Manual Triage" above) — under full-auto pickup, hitting
  a specific ratio is closer to luck than skill.

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

**Status:** Full Set, Streak, and the shake/flash/callout feedback beats
are implemented and verified (see the decision log below for how).
Rampage and Ascension remain unbuilt, as does the pre-completion
tension-building pip-brightening -- see the matrix above and TODO.md.

### Backpack UI

The backpack should be visible on-screen as a real slot grid
(Minecraft-style), not an abstract fill bar. This makes progress
self-explanatory in play: Bearing is *seen* as the grid growing, and
rarity is *seen* via the color-coded item border from the table above.
(Used to also apply to Compacting — a stack visibly climbing higher in
its slot — moot now that Compacting's gone and stack sizes are fixed.)
Fill% and the player's size/hitbox growth (see "Player size/hitbox as
the fill-risk signal" via the decision log) should feel visually linked
so the core risk mechanic reads at a glance without any tutorial text.
Built: a ghost slot (`backpack_grid.gd`) previews the next Bearing
purchase right in the HUD -- fainter and dashed rather than solid,
appearing one slot past the real grid whenever Bearing isn't maxed, gone
once it is.

## Triage & Hoard Depth Pass

Ten ideas came out of an IDEAS.md ideation pass (2026-08-16/17, see that
file and the decision log below). Rather than spec each in isolation,
they group into six mechanics that reinforce each other -- most touch
the same handful of systems (Active Pickup's queue, the Discard/Gleam
stats orphaned by the pickup pivot, the rarity/loot pipeline) and were
clearly circling the same few problems from different angles. Grouped,
not merged -- each is still independently buildable and gets its own
In scope/Out of scope in TODO.md, per this project's usual discipline.

Scope note: this covers IDEAS.md's **Now-ish** bucket only (candidates
IDEAS.md itself already flags as "worth considering for TODO.md soon").
The **Later** bucket (altar, losable hoard, Legendary set-piece, Phase 4,
visible trophy room) stays blue-sky on purpose -- full technical specs
for admittedly-half-formed ideas would be throwaway work and defeats
the point of keeping a low-rigor bucket at all. They got a light naming
pass in IDEAS.md instead, not a spec.

### Group A: Triage Feel

Deepens Active Pickup itself -- no new systems, just makes the existing
queue and discard actually carry the weight DESIGN.md already claims
they do.

**Queue pressure** (no new name -- a refinement of the existing fill %
formula, not new content). Pending (queued, undecided) gems currently
cost nothing to ignore -- pure decoration floating over the player's
head. Fix: count queued gems toward fill % at a reduced weight (e.g.
`PENDING_SLOT_WEIGHT = 0.5` of a real slot) while they wait, so a
backed-up queue makes the player bigger/slower *right now*, not just
once resolved. No auto-timer, no forced resolution -- matches the
already-locked "managing at scale is the fun" call. Technical: extend
whatever computes real slots-used in `player.gd` to include a weighted
`_pending_queue` contribution; must transition cleanly to full weight
(Keep) or zero (Discard) on resolution, not jump.

**Cast Off** (name locked -- reads well, ties "casting off" unwanted
loot to the spellcaster fantasy). Discard (L) currently deletes a gem
with a fade -- a no-op with a coat of paint. Make it *throw* the gem in
the player's current facing direction: damage/knockback scaled by
tier (reuse Streak's existing tier-scaled damage table rather than
inventing a second one), no value banked, so "gone for good" still
holds exactly as today. Splits K and L into genuinely different systems
-- K feeds the economy, L feeds the fight -- instead of both being
variations on "make the gem go away." Visual: redirect the pip's
existing pop-and-fade tween into a launch-arc-then-impact instead of a
fade-in-place; reuse the existing tier-tinted spark burst
(`spark_burst.tscn`) on impact, same asset pickups already use. Audio:
extend the existing discard descending-sweep cue with a hit-impact
layer. Technical: the discard-resolution path in `player.gd` spawns a
thrown-projectile node (a lightweight new script, or a stripped-down
`Loot` variant) traveling along `_facing`, colliding via the same
`take_damage()` path every other source of damage already uses.

**Rarity cues** (Settings-facing name, e.g. "Rarity Cues" -- Function
register, stays plain per TEXT_FLAVOR.md's established split). Reading
a queued gem's tier currently requires *looking* at it, at exactly the
moment a player can't afford to stop watching enemies. A distinct short
pitched arrival tone per rarity (ascending pitch with rarity, reusing
the existing procedural-tone approach in `audio_manager.gd`) lets a
practiced player triage by ear. Cheap, and it directly raises the skill
ceiling on the thing the game says it's about. Technical: one new
`play_rarity_cue(tier)` call fired wherever a gem enters the queue
(`Loot.enter_queue()`).

### Group B: Re-point Discard and Gleam

Not new mechanics -- two existing stats whose *purpose* the Active
Pickup pivot quietly broke, surfaced by the same ideation pass. Small,
should ship on its own, doesn't need Group A/C/D/E built first.

**Discard** currently auto-removes the lowest-rarity item once fill %
crosses a threshold -- precisely the "items vanish on their own"
behavior Backpack Ability was deleted for ("undermines hoarding as a
chosen risk"), and now the last auto-taking system left standing.
Re-scope: instead of the game discarding *for* the player, Discard's
levels boost the player's *own* manual discards -- e.g. each level adds
flat bonus damage/rebate to Cast Off (Group A) rather than triggering
on its own. Keeps the "late-game assist" spirit without reintroducing
autonomous removal.

**Gleam** now governs pickup-queue-eligibility range instead of
auto-collect volume -- meaning more Gleam means strictly more triage
*workload*, with no compensating benefit, an accidental double-edged
stat nobody decided on purpose. Fix (a call worth flagging, not
obviously the only right one): pair Gleam's range increase with a small
queue-resolve-speed bonus, so more incoming volume stays processable at
roughly the same net pace instead of just piling up faster.

Technical: `meta_progression.gd`'s `StatDef` effects for both stats need
re-wiring -- Discard's effect target moves from the auto-purge branch in
`player.gd` to a multiplier read by Cast Off's damage/rebate calc;
Gleam's `StatDef` gains a second effect field.

### Group C: Loot Has Consequences

Makes loot itself spatial and combat-relevant instead of a pure
inventory abstraction -- three ideas, one theme.

**Scatter** (mechanic term, no proper noun needed). Drops currently
spawn exactly where the enemy died -- rarity costs nothing spatially.
Scale scatter distance with tier (Common lands ~at the kill site,
Legendary skitters 80-150px toward the edge), via a quick
launch-and-settle hop rather than a teleport. Chasing the good stuff
now costs a worse position -- puts the greed decision inside the one
input the combat pillar actually has (movement). Technical: `arena.gd`'s
`_on_enemy_died` gets a rarity-keyed scatter offset feeding a launch
tween already-native to `loot.gd`'s bob/pulse tween pattern.

**Leaden** (name locked -- pairs directly with the existing Blessed
affix). Blessed already exists (Epic+ roll, +50% value, gold-shifted
color/pulse). Leaden is its dark mirror: worth more, but folds extra
"ballast" weight into slots-used even though it's still one item.
Fixes a real hole in the existing rarity philosophy -- a Legendary is
800 value in a single slot today, never actually the "space gamble" the
rarity table's own rationale claims, so Keep is always trivially
correct. A Leaden Legendary makes that a real question. Visual: mirror
Blessed's exact code path (`_is_affixed`, `_pulse_scale_amount`) with
inverted constants -- a leaden-grey color lerp, a slower/heavier pulse
instead of Blessed's brighter one, a "+X, Leaden" floating text in that
tone. Technical: `loot.gd`'s existing `AFFIX_CHANCE_BY_TIER` roll
branches into Blessed vs. Leaden instead of just hit/miss; a new
`_is_leaden` flag parallels `_is_affixed`; its ballast weight folds into
whatever Group A's queue-pressure work ends up computing slots-used
from, so they should land together or at least be aware of each other.

**Magpie** (new enemy name -- plain, animal-descriptive, matches the
existing Minion/Bruiser/Elite/Boss convention rather than a mystical
name; magpies are the real-world animal famous for stealing shiny
objects, so it reads immediately without needing flavor text).
Nothing in the arena has ever reacted to loot -- enemies chase the
player and ignore gems entirely, in a game called Hoard Survivors.
Magpie eats unclaimed ground loot before the player reaches it, or
preferentially targets a fuller bag -- giving size-as-risk a second,
active consequence beyond hitbox area. **Must be built around a
kill-it-back recovery window, not permanent theft** -- this is the
single most consistent finding from the cross-game research behind this
idea (Diablo's Treasure Goblin, DRG's Loot Bug, Dark Souls' Crystal
Lizard are all loved *because* killing them fast enough gets the loot
back, often at a bonus; Minecraft's Creeper and Rogue's original
leprechaun are hated because the loss is final). Telegraphing matters
as much as the mechanic: needs a distinct silhouette/tint and an
audible alert cue so the threat reads before it's already happened.
Visual: sprite pulled from the existing DungeonTilesetII pack if a
fitting scavenger/bird-like frame exists, matching how Bruiser/Elite/
Boss got real sprites rather than tinted reuse. Technical: new `Enemy`
subclass overriding `_update_behavior()` (the established pattern),
consumes nearby `Loot` nodes or overrides aggro-priority toward higher
fill %, drops what it ate on death (at a bonus, per the recovery-window
finding above).

### Group D: Attunement

The single biggest idea from this pass, and deliberately its own group
-- touches all 8 spells, deserves the most careful spec and the most
playtest scrutiny before it ships.

**The problem, stated plainly:** there is currently zero in-run
progression. The whole build (Spellpower, spells unlocked, stat levels)
is locked before the run starts; Gem Combos are the only thing that
happens mid-run, and they're occasional spikes, not a running state.
Separately, greed is priced (bigger, slower, easier to hit) but caution
is free -- the dominant strategy right now is discard everything under
Epic, stay lean and fast, cherry-pick the rest, which makes four of six
rarity tiers close to economically pointless.

**The mechanic:** the backpack's *current composition* continuously
biases spell behavior, recomputed live every time the bag changes (same
`loot_changed`/pickup signals Gem Combos already listen to -- reuse, no
new event needed). A single derived scalar -- **Attunement**, a
weighted average tier-index of everything currently held, normalized
0.0-1.0 -- feeds a lerp on top of existing Spellpower scaling:

- **Low Attunement** (Common/Uncommon-heavy bag): spells cast faster,
  hit weaker. Fast, wide, cheap.
- **High Attunement** (Mythic/Legendary-heavy bag): spells cast slower,
  hit harder. Slow, narrow, heavy.
- **Empty bag is its own worst-case floor, not just the low end of the
  lerp** -- per the idea's own explicit framing ("an empty bag should
  be weak"). Implement as a distinct branch (a flat penalty applied only
  while `backpack.is_empty()`), not an extrapolation of the Low-end
  curve, so the mechanic actually punishes emptiness rather than just
  rewarding fullness.

Naming: **Attunement** -- "the bag tunes your spells" was the idea's own
framing, the word is free (Alchemy was removed with Backpack Ability),
fits the existing mystical stat register (Spellpower, Essence, Gleam)
without colliding with anything.

**Real balance risk, flagged not solved:** this is structurally similar
to Path of Exile's flask system, which became infamous as "flask
piano" -- near-mandatory upkeep with zero cost to skipping it, bad
enough the developers have nerfed it repeatedly. If one Attunement
state ends up strictly, unconditionally better, this collapses the same
way. Needs the low and high ends to each genuinely win in different
circumstances (e.g. low favors clearing trash / early phases, high
favors Boss-scale single-target burst) rather than one dominating --
**this needs real playtest-harness verification once built**, not an
assertion that the shape above already solves it.

Visual: each spell's existing procedural VFX (already `modulate`-tinted
by nothing in particular right now) could trend cooler/thinner at low
Attunement, warmer/thicker at high, reusing the exact tinting mechanism
gems already use for rarity color -- no new art needed. A small HUD
gauge showing current Attunement belongs with the already-queued HUD +
death-summary rework (see TODO.md), not built standalone. Audio: none
needed -- Attunement modulates values (cast rate) that already have
their own cast SFX.

Technical: new `get_attunement() -> float` on `Player` or
`SpellCaster`, recomputed on backpack-change signals. `spell_caster.gd`
wants one shared helper (e.g. `_attunement_multiplier(base, low_end,
high_end)`) called from each of the 8 spells' existing calculations,
not 8 duplicated lerps.

### Group E: Pacts — removed (2026-08-17)

Was designed and implemented as a new shop category selling per-run
rule mutations (Heavy Start / Fragile Bearing / Narrow Queue), with
Burden specced as its payout follow-up. Binned entirely on direct
instruction -- not a balance call, a "don't like it" design-direction
call, same category of decision as Compacting's removal. No replacement
mechanic: the Sanctum stays at its three trees (Player/Spells/Backpack)
plus nothing else, and run-prep/Embark has nothing new to show. Every
piece of the Burden follow-up (the payout-multiplier formula, the
appended HUD line, the death-screen readout) is removed along with it
-- the "HUD & UI Design" section below no longer carries a Burden
mention anywhere. See the decision log for the full history (designed,
implemented, Burden specced, then removed).

### Group F: Score the run you played

Folded into the **HUD + death-summary rework** (see "## HUD & UI
Design" below) rather than standing alone -- personal-best scoring
(Richest/Leanest/Most Refused) is spec'd there alongside the rest of
that pass, decided 2026-08-17.

The death summary currently ranks time survived and loot value; nothing
measures triage quality. Track additional per-run stats -- total value
kept vs. discarded (via Cast Off), a derived efficiency (value kept ÷
slots used) -- and persist personal bests for named *shapes* of run
rather than just one "best time": **Richest** (highest loot value
banked), **Leanest** (best value-per-slot), **Most Refused** (most
value voluntarily discarded via Cast Off). Plain, Function-register
category names -- no extra flavor needed, matches TEXT_FLAVOR.md's
established split. Technical: extends `meta_progression.gd`'s existing
`update_best_run()` pattern with these additional derived, independently
-persisted bests.

## Art Direction

**Decided 2026-08-17: Abyssal Dive -- supersedes Painted Hoard, same
day.** The first art-direction pass (below, preserved in the decision
log) only reconsidered *how* the existing wizard-and-gems premise gets
drawn. On direct feedback that this "was nowhere near the scope
wanted," round two reconsidered the premise itself: three full
setting-and-style packages, each pairing a world with the visual style
that world actually demands, pitched from a live artifact rather than
described in prose. **Abyssal Dive won** -- a descent into a lightless
deep where glowing relics are the only color in the frame. This is a
full replacement of Painted Hoard's soft-painterly/warm-ink language,
not a layer on top of it -- Abyssal Dive's own visual style is dark,
high-contrast, and glow-driven, a different rendering technique
entirely, not just a different subject painted the same way.

**The premise.** The player is **the Diver** -- someone who went too
deep chasing treasure and came back changed, channeling something
found down there rather than "arcane magic." Loot is bioluminescent
salvage and drowned relics, not gems in the fantasy sense (the rarity
*mechanic* is unchanged -- see "What stays locked" below). Darkness is
the default state; anything saturated on screen is meaningful, because
color itself is scarce. Tone: this sharpens "Dark & Desperate" (already
one of TEXT_FLAVOR.md's two confirmed tone pillars) rather than
introducing a new one -- "Mystical & Determined" bends toward something
closer to "eldritch and resolved" under this premise, not abandoned.

### Naming cascade

Full rename, not partial -- every proper noun tied to the old fantasy
framing moves. Two categories were deliberately **not** touched, per
TEXT_FLAVOR.md's own already-locked calls, not revisited without new
reason: enemy tier names (Minion/Bruiser/Elite/Boss) and rarity tier
names (Common through Legendary) -- both already decided as genre-
convention Function text that reskinning would cost clarity for no
payoff, and nothing about a setting change is new reason to reopen
either.

| Old | New | Note |
|---|---|---|
| HOARD SURVIVORS (title) | **ABYSSAL HOARD** | keeps "Hoard" as the brand anchor -- the mechanic's name, not just flavor |
| "Hoard what you can. Survive what you must." | "Hoard what you can. Surface while you still can." | same two-imperative structure, Survive -> Surface |
| Sanctum (shop) | **the Cove** | |
| Grimoire (reference screen) | **the Ship's Log** | |
| EMBARK? (run-prep title) | **DESCEND?** | |
| "Your Hoard" (run-prep panel) | **"Your Haul"** | |
| Essence (loot-value currency) | **Glow** | bioluminescence harvested from what's taken -- keeps Essence's own "power distilled from what you took" logic intact |
| Stardust (survival-time currency) | **Depth** | reward for enduring, parallels the old "sky grants it" logic with "the deep grants it" |
| Bearing (backpack capacity) | **Hold** | ship's cargo hold |
| Gleam (pickup/magnet range) | *unchanged* | bioluminescent gleam in true darkness already fits this setting better than the old one -- no rename needed, not everything has to move |
| Swiftness (move speed) | **Current** | swimming with/against it |
| Spellpower (damage) | **Fathom** | double meaning kept on purpose -- a depth unit, and "to fathom" as grasping something vast and half-understood |
| Discard (backpack stat) | *unchanged* | plain Function text already, no fantasy coding to remove |
| Magpie (loot-stealing enemy) | **the Angler** | an anglerfish's lure is the exact inversion of "creatures drawn to your glow" -- strongest single rename in this table, most other names are direct translations, this one's a real upgrade |
| Altar | *unchanged* | drowned shrines are their own nautical-horror convention, not exclusively fantasy-coded |
| Trophy Hall | **the Reliquary** | |
| The Forge (rarity-shift node) | **the Lure** | forges don't survive underwater at all; "the Lure" reuses the Angler's own logic -- you're attracting better salvage, not smithing it |
| Facets | *unchanged* | cut-gem faceting is not fantasy-exclusive vocabulary |

**Spells** (mechanics -- power, cooldown, range, every number -- stay
byte-for-byte identical; only name/flavor/VFX color change):

| Old | New | What carries the identity |
|---|---|---|
| Arcane Bolt | **Luminous Dart** | a shard of harvested bioluminescence, fired |
| Inferno Blade | **The Undertow** | omnidirectional pull/crush instead of a blade swing; its burn DoT becomes **the Bends** -- decompression sickness as a damage-over-time, the single most on-theme reflavor in this table |
| Frost Nova | **Deep Chill** | cold already fits the abyss natively -- smallest rewrite of the eight |
| Meteor Strike | **Trench Collapse** | the seafloor implodes under crushing pressure at the impact point; the existing telegraph ring becomes a visible pressure-crack spreading before it lands |
| Lightning Chain | **Eel Current** | electric eels are real -- the chain-hop mechanic needs no justification once the source is an eel instead of a lightning bolt |
| Time Warp | **Crushing Depths** | a wide pressure field, low damage/high CC exactly like today -- pressure crushes, it doesn't have to kill |
| Teleport Pulse | **Ink Jet** | jet-propulsion + an ink-cloud burst at both ends, same blink-with-AOE-at-both-ends shape as today |
| Summon Familiar | **Anglerling** | a small tamed anglerfish companion -- deliberate mirrored naming against the Angler enemy above |

### Visual language

Dark, high-contrast, glow-driven -- extends the "Grim Hoard" direction
from round one's pitch (itself anchored to Halls of Torment) rather
than Painted Hoard's soft painterly gradients. Color is scarce by
default; anything saturated on screen (loot, spell VFX, the Angler's
lure) reads as meaningful *because* the environment around it is
desaturated near-black, not despite it. Outlines and shading favor a
cold, wet-look palette over Painted Hoard's warm ink. A scanline/
dither texture pass over environment layers (not UI text) nods to the
underwater-murk feel without needing a real refraction shader.

**What stays locked, unchanged from the previous pass:** the six rarity
hex colors themselves (`loot_registry.gd`'s white/green/blue/purple/
orange/red) are still untouched -- read by the HUD, `BackpackGrid`, the
Ship's Log, and Streak/Attunement's tier-index math, so this remains a
render-technique question, not a balance/legibility one. What changes
is the *treatment* around those six colors (glow + dark ground instead
of gradient-shaded facets on a warm ground), not the hues.

**Loot-gem starting point, concretely:** `loot_gem.gd`'s three flat
`draw_colored_polygon()` facets get a desaturated/darkened base fill (a
dimmer version of the rarity tint, not the flat bright tint used today)
plus 2-3 layered low-alpha glow circles drawn behind the gem at the
rarity color, and a cool-toned stroke (not Painted Hoard's warm brown)
-- the exact technique already prototyped live in the pitch artifact's
canvas renderer, just needs porting from JS canvas calls to Godot
`_draw()` calls (`draw_circle` with alpha for the glow layers,
`draw_colored_polygon` kept for the facets themselves with darker
fill values, `draw_polyline` for the cool stroke).

**Shared background, one asset touching five screens at once:** every
non-arena screen (`main_menu`, `save_slot_selector`, `run_prep`,
`shop`, `settings_menu`) already shares a single `night_sky_background.gd`
backdrop per TEXT_FLAVOR.md's own audit -- replacing that one script
with an abyss-water equivalent (dark gradient + slow-drifting
particulate/bubble layer instead of stars) re-themes five screens'
ambient backdrop in one change, not five separate ones.

### Asset scope

Everything, per direct instruction -- not phased down to "gems only"
like the previous pass. Full surface area: the Diver (player sprite +
animations), enemy visual redesigns for all six tiers/variants (Minion/
Fast/Tanky, Bruiser, Elite, Boss, the Angler), all 8 spells' VFX (color/
particle-shape only -- see the naming table above, no mechanical
changes), the loot gems, and UI chrome across the Cove/Ship's Log/HUD/
Descend screens. **Enemy silhouette direction, illustrative:** Minion ->
small bioluminescent fish-swarm shapes, Bruiser -> armored crustacean/
lobster-like chargers, Elite -> a siphonophore/jellyfish firing stinging
projectiles at range (its existing kite-and-shoot pattern already
matches a jellyfish better than the current sprite), Boss -> a
leviathan-scale hybrid that both closes distance and fires spread
volleys (matches its existing hybrid attack pattern).

### Technical risks, flagged rather than discovered mid-build

- **Save compatibility is fine, but only if this is done correctly.**
  Every `StatDef`/`PactDef`-style identifier (`STAT_BACKPACK_CAPACITY`,
  `STAT_PICKUP_RANGE`, etc.) is an internal `StringName` separate from
  its `display_name` -- renaming Bearing to "Hold" means changing the
  `display_name` string only, not the id. Save files key on ids, not
  display names, so existing saves are unaffected *if* only display
  strings move. Flagged explicitly so it doesn't get done the other way
  by accident.
- **The Magpie -> Angler rename is a real file-rename, not just a
  string change**, and CLAUDE.md already documents the exact trap:
  renaming `enemy_magpie.gd`/`.tscn` (and the `EnemyMagpie` class name,
  `MetaProgression.magpie_encountered` field) leaves Godot's
  `global_script_class_cache.cfg` stale, which produces cascading
  "Could not find type X" errors project-wide even though every actual
  reference is correct -- needs the documented headless-editor-rescan
  fix (`Godot.exe --headless --editor --quit --path .`) before trusting
  a boot check after the rename, not a plain `--quit`.
- **The project title itself changes** -- `project.godot`'s
  `application/config/name` and `main_menu.tscn`'s title label both
  need updating to ABYSSAL HOARD, not just in-fiction text.

### Build order

Sequenced by dependency and risk, same reasoning as the mechanics build
order earlier this project -- not a rigid mandate, a sensible default:

1. **Naming/text pass first.** Every rename in the table above is a
   string change to existing code (`display_name` fields, UI labels,
   the title/tagline) -- zero art dependency, fastest to verify, and
   everything built after this point can be checked against final names
   instead of placeholders.
2. **Loot gems.** Smallest visual surface area, direct technique
   already prototyped in the pitch artifact, validates the core "dark
   ground, glow reads as meaning" premise before it's expanded anywhere
   else.
3. **Shared background + UI chrome.** One asset (the abyss backdrop)
   touching five screens at once, plus the Cove/Ship's Log panel
   treatment -- confirms the mood holds across real UI, not just one
   small canvas.
4. **The Diver + all six enemy tiers.** The single biggest content
   item -- gated behind steps 2-3 actually reading correctly first,
   since a wrong call here is the most expensive to redo.
5. **Spell VFX**, last -- 8 individual reflavors, least blocking to
   validating "does this feel like the new setting," most numerous
   individual line items.

## Later Bucket: First Spec Pass (2026-08-17)

TODO.md's Later bucket held seven blue-sky ideas, deliberately unspecced
per that doc's own philosophy ("no spec required... until something
graduates up into Next"). Spec'd here at the same rigor as the Depth
Pass groups above so they're actually buildable, not just named. Six of
seven are ready to hand to the other process as-is; one (Hoard should be
losable) still needs a shape confirmed first — flagged clearly below,
not silently decided.

**Naming note, added after "Art Direction" was rewritten same day:**
Trophy Hall and The Forge below are renamed to **the Reliquary** and
**the Lure** under Abyssal Dive (see "Art Direction"'s naming cascade)
— left un-renamed in the section headings/bodies below since the
mechanics they describe are unaffected by the rename; use the new
names when actually building either.

### Altar

**Problem:** loot is inert until death -- the only in-run choice about
it is keep/discard, never *spend*. No in-run choice point beyond
triage.

**Mechanic:** a structure spawns in the arena at each existing phase
boundary (20s, 40s -- reusing the pacing beats Phase 2/3 already gate
on, not a new clock) at a point offset from the player's current
position (same margin-from-player logic Scatter already uses for
Legendary drops), and despawns after 15s if unused -- skipping it is a
real, if minor, cost. On approach it offers one boon (not a menu of
several -- the decision is *whether* to take it, not which of many,
keeping this UI-cheap) at a stated cost in items of a tier ("3 Rare or
higher"). Confirming the offer removes that many items from the
backpack (no Cast Off throw, no value banked -- a pure sacrifice, not a
discard) and applies the boon for the rest of the run.

**Boon pool (illustrative, first pass):** flat Spellpower bonus for the
remainder of the run (the game's first in-run temporary power spike,
distinct from permanent shop stats), a full heal, or a guaranteed
tier-up on the next 3 drops. Ship one or two, not the full list, and
see how it plays before adding more -- same "one thing first" discipline
Group A used for Streak before Rampage/Ascension.

**Technical:** new `Altar` scene/script (`Area2D` interaction, structured
like `Loot`/`Enemy`), spawned by `arena.gd` alongside its existing
phase-boundary checks. Consuming items needs a new
`Player.sacrifice_loot(type_id, count)` (subtracts from `backpack`
directly, no value/Cast Off path -- distinct from both `collect_loot()`
and `resolve_discard()`). Boons apply via a new
`Player.apply_altar_boon(boon_id)`.

### Hoard should be losable — needs a shape decision before this ships

**Not silently resolved.** The idea's own text flags this as "the
softest spot in the whole design" and weighs three shapes (voluntary
exit + bonus, partial loss on death, an always-safe pocket) without
picking one -- that's a real open question, not an oversight to paper
over the way Burden's formula or Pact severity were.

**Recommendation, not a decision:** voluntary extraction, not partial
death-loss. Reasoning: death banking loot in full is a pillar this doc
already states plainly (Core loop step 5: "Death is inevitable... just
how much you collect before it happens"; step 7: loot converts to
currency on death, unconditionally) -- reversing that is a bigger,
riskier philosophy change than the idea needs to make its point. A
**voluntary extraction window** (opening periodically, e.g. every 30s
survived starting at 30s -- reusing the same beat-based cadence as the
Altar above) that lets the player end the run early for a small payout
bonus (e.g. +10% Essence/Stardust) creates the same repeated "push or
lock it in" decision the idea is actually after, without touching the
already-shipped death-payout path at all. The source material's own
"sharpest lesson" paragraph leans toward partial/repeated loss as
psychologically sharper -- if that's actually wanted over the safer
option above, say so and this gets re-specced around death-time loss
instead; the technical shape is meaningfully different (a payout
reduction on death vs. an entirely separate early-exit path), so this
isn't a small edit either way.

**Technical (assuming the recommendation):** a new UI prompt (reusing
the pause-menu's existing modal pattern) appearing on a timer, offering
"Extract now" vs. dismiss; confirming calls `award_run_end_currency()`
early with the bonus multiplier applied, same as a death would, then
ends the run without playing the death sequence.

### A Legendary is a set piece, not a drop

**Problem:** at 0.5% base weight the top tier is effectively Boss-only,
and when it appears it magnetizes in exactly like everything else --
the rarest thing in the game gets the same non-event as a Common pip.

**Mechanic:** a dropped Legendary never magnetizes -- the player must
walk to it. While uncollected, it pulls every currently-alive enemy in
the `"enemies"` group toward its position, turning "go get it" into a
real fight rather than a free keypress. Visual: pulse scaled roughly
2x `Loot`'s existing `PULSE_SCALE_AMOUNT`, tinted the existing Legendary
red, plus a glow radius that reads as "danger inbound," not just
"shiny." Audio: a distinct rising cue on spawn (new `AudioManager`
entry), separate from the normal pickup sound.

**Balance flag, honestly scoped:** pulling literally every alive enemy
to one point risks an unwinnable dogpile at low Spellpower -- this needs
a playtest-harness batch specifically measuring survival in the seconds
after a beacon spawns before shipping unguarded. If it reads as a death
sentence, the tuning lever is capping the pull to enemies within some
radius of the beacon rather than the whole arena, not abandoning the
mechanic.

**Technical:** `loot.gd` gains an `_is_beacon: bool` set when
`type_id == &"legendary"`; `start_magnet()` early-returns while it's
true. The enemy-redirect side needs the actual chase/targeting call
site in `enemy.gd` inspected before implementation -- not read this
session, flagged as a real unknown rather than guessed at.

### Phase 4: the arena becomes the antagonist

**Problem:** `Arena.get_phase()` caps at 3 forever -- nothing new
happens after the Boss's 55s climax; the arena itself is completely
inert past that point.

**Mechanic, one shape chosen for a first pass (not all three the idea
lists at once -- same "ship one thing" discipline as Group A's Streak
before Rampage/Ascension):** a closing arena. At a new threshold
(`PHASE_4_TIME = 90.0`, chosen to give Phase 3 room as its own stretch
before escalating again, well clear of the Boss's 55s beat) the
playable bounds shrink from the full 1280x720 toward a smaller safe
zone, marked by a visible encroaching edge (reusing `BackpackGrid`'s
existing red danger-color language rather than inventing new color
vocabulary) that damages the player for lingering outside it.

**Deferred, flagged as real follow-on scope, not forgotten:** "going
dark" (a visibility mechanic) and hostile drop zones (loot avoiding the
shrinking safe area) -- both genuine Phase 4 candidates, out of scope
for this first ship.

**Technical:** `arena.gd` gains `PHASE_4_TIME`, `get_phase()` extended
to return 4 past it; a shrinking bounds value (lerped down over a fixed
duration once Phase 4 starts) read by both `player.gd`'s existing
`position.clamp(...)` movement-bounds line and a new periodic
damage-over-time tick for standing outside it.

### A hoard you can actually see (Trophy Hall)

**Problem:** the game is called Hoard Survivors and nothing is ever
hoarded -- loot converts to currency and vanishes, no persistent
trophy of what's ever been found.

**Mechanic:** a new Sanctum-adjacent screen (pure display, no currency
spent -- same non-economic role the Grimoire already has) showing the
single best item ever found per rarity tier, six fixed slots (Common
through Legendary), each showing that item's value. Deliberately not
"everything ever collected" -- unbounded and illegible at scale -- just
best-of-tier keeps it exactly six entries forever, and gives a concrete,
nameable target ("beat your best Legendary").

**Technical:** new `MetaProgression.best_loot_value: Dictionary` (tier
id -> highest single-item value seen, since loot affixes already make
same-tier items vary in value -- see "Loot affixes"), checked at death
time against that run's loot breakdown rather than a new mid-run signal
hook. New `TrophyHall` scene/script reusing the Grimoire's dark-panel/
section-header visual language. Persisted through the same export/
import/reset path everything else in `MetaProgression` already uses.

### The Forge: buy odds, not numbers

**Mechanic:** a new chain-gated Backpack Tree node (Stardust-funded,
matching "backpack track funds hoard-related things") that shifts the
global rarity table toward higher tiers per level, same chain-gate
pattern (can't invest in the next rank until the previous is maxed)
already used throughout the shop.

**The real technical crux, flagged explicitly so it doesn't get
half-built:** `LootTypes`' registered weights are the source of truth
(`loot_registry.gd`'s own header comment), but most loot doesn't roll
against them directly -- per-enemy drop tables
(`pick_random_weighted(weights)`) are what Minion/Bruiser/Elite/Boss
actually use. A Forge that only adjusts `pick_random_type()`'s internal
fallback table would visibly do nothing, since almost no roll takes
that path. Implementation: `LootTypes.get_forge_adjusted_weights(base:
Dictionary, level: int) -> Dictionary` returns a shifted copy (source
table in `_register()` stays untouched, per its own "update there
first" comment) -- both `pick_random_type()` and
`pick_random_weighted()` route their table through this when Forge
level > 0.

**First-pass numbers**, same geometric-curve `StatDef` shape as every
other node, no new cost system: base_value 0% shift, per-level gain 2%
(moved from Common/Uncommon toward Rare+), base_cost 150 Stardust
(pricier than Bearing/Discard -- a global economy multiplier, not a
personal stat), growth ×1.2/lvl, cap 10 levels (20% max shift).

### Facets

**Scope decision, since "every stat" is too broad for a first pass**
(same "ship one thing" discipline used throughout this pass): two
stats, not all of them -- **Swiftness** (renamed **Current** under
Abyssal Dive; Face A: current, +move speed;
Face B: trades some move speed for +dash cooldown reduction -- a
mobility-*shape* choice, not a strict upgrade) and **Gleam** (Face A:
current, +pickup range; Face B: trades range for +Cast Off damage,
leaning into "I fight with my discards" over "I vacuum wide"). Both
already imply a natural second face from their own post-pivot role
(Group B's Discard/Gleam re-point), not invented from nothing.

**Mechanic:** Hades' Mirror pattern -- already-purchased levels express
either face, switched freely, no cost, any time from the Sanctum. No
new node, currency, cost curve, or cap; the same purchased levels just
point at a different effect depending on which face is active.

**Technical, flagged as the one item in this batch touching
already-shipped behavior rather than adding net-new:** `StatDef` (or a
small paired sub-resource) gains a second effect definition per facet
stat; `MetaProgression` gains a persisted `active_facet: Dictionary`
(stat id -> bool), free to toggle. Every read site for that stat's
effect branches on it (`player.gd`'s speed/dash-cooldown application,
`loot.gd`'s Cast Off damage). Needs unit-test coverage for *both* faces
of each stat before shipping, not just the new one -- a bug here risks
silently regressing an already-tested existing stat, not just failing
to add a new one cleanly.

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
- 2026-08-16 — Player question, confirmed against the actual code: why
  does it feel like only 3 loot types ever show up? Answer: it's not a
  bug, it's enemy-gated by design and was never actually verified end to
  end until now. Minion's own loot table caps at Rare (60/30/10% Common/
  Uncommon/Rare, no Epic+ at all); Bruiser (Phase 2, 20s+) adds a 5%
  Epic chance; Elite (Phase 3, 40s+) is where Epic (30%) and Mythic (5%)
  become real; Boss (55s+, once) is Mythic/Legendary-exclusive (80/20%).
  Phase 1 genuinely only has Minions, so any run that doesn't survive
  past ~20s can only ever see Common/Uncommon/Rare -- exactly the
  reported symptom. The gating itself needed no fix (it already *is* the
  "unlock rarer loot as you go deeper" progression the player wanted),
  but it was completely silent -- nothing on screen ever announces a
  tougher enemy tier (and the rarer loot that comes with it) becoming
  available. Added phase-transition callouts to close that gap: "BRUISERS!"
  at Phase 2, "ELITES!" at Phase 3, "BOSS!" at 55s, reusing the same
  above-the-player floating-text pattern as combo callouts (`hud.gd`'s
  `_check_phase_announcements()`/`_spawn_phase_label()`, mirroring
  `spell_caster.gd`'s combo-label helper). Verified via a normal
  (unmodified-timing) playtest batch reaching Phase 2/3 repeatedly, and
  a separate batch with `Arena.BOSS_SPAWN_TIME` temporarily lowered to
  reliably exercise the boss-announcement path -- both zero errors.
- 2026-08-16 — Pickup itself gets a core rework: Active Pickup / Manual
  Triage. Direct player critique of the whole session's backpack work so
  far: "the premise is a backpack management game" but pickup has always
  been fully automatic (magnet in, auto-commit) -- there's no actual
  management happening, just RNG accumulation. Fixes the thing every
  earlier backpack pass this session (fill %, Gem Combos, the pip
  visual) was quietly built on top of without noticing it was broken.
  Replaces auto-commit with a real decision: each magnetized gem queues
  in front of the player awaiting input -- one button keeps it (adds to
  backpack), one discards it (gone for good, no banking, matching
  Discard's existing philosophy). This is a genuine pillar change, not
  an addition -- the Genre section's "only input is movement/
  positioning" line (referenced repeatedly this session, including as
  Full Set's own design rationale) is rewritten to two co-equal input
  pillars: automatic combat, and active inventory triage. Reconciled as
  "combat stays automatic, triage is a separate deliberate layer,"
  rather than a contradiction. Queueing under pressure (rather than an
  auto-timer or default-to-keep safety net) was a direct, deliberate
  call: "managing that at scale isn't an issue, it's the fun" -- a
  neglected queue is meant to be its own felt pressure while still
  dodging, not something designed away. Gleam's role shifts from "how
  much gets vacuumed in" to "how far away a gem starts being eligible to
  queue." Also developed a fifth Gem Combo alongside this, since it only
  really makes sense once pickup is deliberate: **Ratio** -- hold two
  tiers in a specific proportion (illustrative: 2 Uncommon to 1 Common)
  to trigger a short repel/pushback pulse, the first defensive/utility
  combo (the other four are all offense or buffs). Flagged, not yet
  resolved: Gem Combos' existing tuning (Full Set, Streak) assumed
  full-auto pickup and likely needs rebalancing once curation is real;
  the shipped pip/pop pickup visual needs to move from "plays on
  magnet-arrival" to "plays on the keep decision." See TODO.md; not yet
  built.
- 2026-08-16 — Drop-rate tuning pass, explicitly scoped to arena play
  only (not meta-progression/economy, which the player wants to balance
  separately): rarer tiers still felt too locked-away even once a
  player actually reached the enemy that unlocks them. Per-enemy tables
  reshaped rather than the flat fallback table (which nothing in normal
  play actually reads -- every enemy already has its own non-empty
  `loot_weights`, so `pick_random_type()`'s flat table is dead weight
  for drop purposes, confirmed while making this change). Minion now
  has a small 1% Epic chance (previously hard-capped at Rare) so Phase 1
  isn't a total dead zone. Bruiser's Epic 5->13% plus a new 2% Mythic
  (previously Elite/Boss-exclusive). Elite's Epic 30->40%, Mythic
  5->15%. Boss's Legendary 20->35% -- it's the only guaranteed shot at
  Legendary all run (0.5% base weight otherwise), so tilted further
  toward the payoff landing when a player actually gets there. All
  four tables re-verified to sum to 100. Verified via a heavily-seeded
  playtest batch (12 runs, reaching Phase 2/3): avg loot value rose from
  ~99 to ~147 versus the prior comparable batch, consistent with the
  rarer/higher-value drops landing more often, zero errors.
- 2026-08-16 — Active Pickup: Manual Triage implemented, the doc's own
  "core pivot, not a small item." Input scheme (the one thing the spec
  left open) resolved directly with the player: dedicated keys over
  mouse-click, keeping both hands on the keyboard through a run rather
  than switching to the mouse for a split-second decision made
  mid-dodge. Landed on **K** to keep, **L** to discard (an initial E/Q
  pass was rebound to this immediately after, per direct follow-up).
  Architecture: `Loot._on_body_entered()` now branches on
  `Player.is_bot_controlled()` -- real players hand off to
  `Player.enqueue_loot()` instead of committing immediately; the
  playtest bot collects exactly as before (skips the queue entirely),
  so balance-signal batches stay meaningful without simulating triage
  decisions. The active (front) gem sits pinned just above the player,
  repositioned every physics frame so it follows movement; queued gems
  behind it stack further up and render at 70% scale -- the "queued/
  pending gem visual treatment" the spec flagged as undesigned, resolved
  as reusing the existing pip/pulse look rather than inventing a new
  one, just smaller and offset. Keep reuses the existing `collect()`
  pop/spark/text unchanged, just triggered from the key press instead of
  magnet-arrival, per the spec's own note that the visual language
  should stay and just re-anchor. Discard is new: a shrink-and-fade
  (opposite of Keep's grow-and-fade, so the two read as distinct
  outcomes) plus a new descending-sweep "discard" cue in
  `audio_manager.gd`, no backpack change, no banking.
  Gleam's role changed as specified: `_on_pickup_area_entered()` no
  longer gates magnetizing on backpack capacity for real players (only
  bots still do, to hold their behavior fixed) -- capacity is resolved
  later, at the Keep decision itself, via the same `collect_loot()`
  every other path already uses (which already handled the full-
  backpack case: Keep silently does nothing if it fails, gem stays
  queued -- no new failure-state code needed).
  Explicitly not addressed here, both already flagged as open in the
  spec: rebalancing Full Set/Streak's trigger tuning for curated (vs.
  RNG) backpacks, and the Ratio combo (only makes sense once curation is
  real, tracked separately). Also out of scope per direct instruction:
  any meta-progression/economy rebalancing -- arena play only this pass.
  Verified via the unit-test runner (9 new cases directly exercising
  enqueue/advance/resolve -- headless has no way to simulate real K/L
  key presses, so `_check_triage_input()`'s input-polling itself is
  unverified here, only the queue mechanics it calls into; 204 total
  passing) and playtest batches confirming the bot-bypass path is
  unaffected (fresh-save and heavily-seeded numbers both in line with
  pre-change baselines). Not verified: real keyboard input, or how the
  stacked-gem visual actually reads in motion -- needs a human via
  `playdev`.
- 2026-08-16 — Player gesture on Keep/Discard, requested directly:
  checked the wizzard_m sprite sheet first rather than assuming -- only
  `idle`/`run`/`hit` exist in the DungeonTilesetII pack (`hit` isn't
  even wired into `player_sprite_frames.tres` currently), no "throw" or
  "interact" pose to use, and no way to draw new frames. Approximated
  with the same cheap-juice technique already used everywhere else in
  this game (tween the existing sprite's transform, no new art): Keep
  is a quick hop + backward tilt on `_sprite` (arm reaching up and over
  the shoulder to stow something); Discard is a sharper opposite-
  direction tilt with no hop (a batting-away swipe). Neither touches
  `_sprite.scale` deliberately -- that's already driven by the backpack-
  fill size effect (Tweak 4), and animating it here would fight that
  system the moment a Keep's own `collect_loot()` call recomputes it
  mid-gesture. Pure visual flourish, no gameplay effect -- verified via
  boot check only; per this project's own testing tiers, feel like this
  needs a human via `playdev`, not a headless test.
- 2026-08-16 — Documentation sync, at the player's request: a lot landed
  fast across two parallel processes (this design chat and a code-
  implementing one), and DESIGN.md/TODO.md had drifted from what's
  actually true in a few places -- fixed as part of this pass, not
  worth their own entries: "Current implementation" was still
  describing pre-session behavior (auto-pickup, HP-shrink, the removed
  Backpack Ability) instead of what's live now; Full Set's own
  rationale still said "no new pickup mechanic needed," directly
  contradicted by Active Pickup shipping since; "Gem Pickup Visual"
  still said "Not built" for a feature that had already gone through
  three live-play iterations.
  Worth stating plainly, since it's easy to lose in a log this long: the
  design found real direction this session. It started as a backpack
  that filled up and shrank max HP -- a single static number. Across
  this run of work that's become a live, continuously-relevant risk
  (fill % now tracks real volume, not a one-time flag; the risk signal
  is the player's own visible size, not a bar in the corner) with a
  reward layer bolted directly onto the same act of hoarding (Gem
  Combos) and, as the capstone, a reason to actually think about every
  single pickup instead of vacuuming the arena clean (Active Pickup:
  Manual Triage). Each piece individually was a fix or an addition;
  together they're what turned "collect loot" into the actual game.
  Skill-tree and text-flavor work (both fully speced, see TODO.md) are
  deliberately on hold now, not dropped -- direct instruction, so the
  mechanics side gets to fully settle before spending effort on
  presentation of mechanics that might still move.
- 2026-08-16 — Compacting stack-size re-tune (the one outstanding piece
  of the backpack-rework item): validated via the playtest harness
  rather than changed blind, per the item's own instruction. A/B/C
  comparison at fixed capacity (5) and matched combat stats, 10 runs
  each: no Compacting averaged ~57% fill; Commons Hoard alone (maxed)
  ~44%; the full ladder maxed ~34%. Two things confirmed by that spread:
  Compacting has a real, felt effect now that fill % actually responds
  to it (was zero effect before the fix), and it doesn't trivialize the
  risk mechanic even fully maxed (34% is still a real, live number, not
  near-zero) or after the ladder's first, cheapest purchase (Commons
  Hoard alone only captures about half the total possible reduction --
  Uncommon/Rare/Epic/Mythic Hoards still carry real, non-diminishing
  weight, not just a common-first purchase and then nothing). Conclusion:
  the existing per-tier numbers (see the Compacting upgrades table above)
  hold up under the new mechanic as-is -- re-tuning via the harness
  doesn't always mean changing numbers, sometimes it means confirming
  the ones already there are fine. No values changed.
- 2026-08-16 — Compacting removed entirely, direct instruction, on
  design-direction grounds rather than balance ones -- the re-tune right
  above this entry had just confirmed Compacting was working exactly as
  intended (real, felt, non-trivializing effect on fill %). Removed
  anyway: it's a *fixed* ability -- buy it once with Stardust, it's a
  permanent passive forever -- and the direction this session has been
  moving is away from permanent purchased passives and toward dynamic,
  skill-expressed in-run systems (Gem Combos, Active Pickup). Compacting
  was the last major piece of the backpack still living entirely in the
  old model. `Discard` is unaffected in spirit (still a real upgrade,
  still threshold-leveled) but re-gated: it was gated behind Compacting's
  Rare Vault node, which no longer exists, so it's re-pointed to gate
  behind Bearing's first level instead -- keeps *some* progression
  structure in Backpack Tree (now just two nodes: Bearing, then Discard)
  rather than leaving it fully flat.
  Real consequence, not swept under the rug: stack sizes per tier are
  now **permanently fixed** at their Rarity tiers table values (Common
  10, Uncommon 8, Rare 5, Epic 3, Mythic 2, Legendary 1 -- unchanged
  numbers, just no longer purchasable upward). Bearing becomes the
  *only* backpack-capacity lever left. This will bite sooner than
  Compacting's removal alone suggests -- the just-confirmed A/B/C data
  above showed Compacting cutting fill % roughly in half at the ladder's
  midpoint and further at max, so removing it outright (not just
  freezing it at some in-between level) pushes real fill-%-driven
  pressure earlier and harder than any state that was actually
  playtested. Flagged directly for the implementing process: re-verify
  balance via the playtest harness after removal, specifically whether
  Bearing's cost curve/base value (already raised 1 -> 5 once this
  session for an unrelated reason) still paces correctly as the sole
  capacity lever, and whether the base stack sizes themselves are worth
  revisiting now that they're permanent instead of a starting point.
  Not decided here -- a balance question for the harness, not a design
  call to guess at. See TODO.md for the removal instructions.
- 2026-08-16 — Grimoire implemented: an in-game reference screen for the
  8 spells and 2 shipped Gem Combos (Full Set, Streak), none of which
  were taught anywhere in-game before this -- only DESIGN.md and chat
  history. Progressive discovery, per direct decision: spells show once
  unlocked (`MetaProgression.is_spell_unlocked()`), combos show once
  triggered at least once ever, everything else reads "???" rather than
  spoiling what hasn't happened yet. Combos needed genuinely new
  persistent state for this -- `MetaProgression.discovered_combos`,
  wired into `export_save_data()`/`import_save_data()`/
  `reset_progress()` like everything else that survives a save -- since
  the combos themselves are deliberately ephemeral/in-run-only
  (DESIGN.md's Gem Combos section), but *whether one's ever been seen*
  has to persist across runs regardless. Spells needed no new tracking;
  unlock state already lives on the Spell Unlock stat level.
  Named "Grimoire" (not "Codex") to match the project's existing magic-
  themed renames (Sanctum, Hoard, Essence, Stardust). Reachable from a
  new button on `run_prep.tscn` ("Sanctum"'s pre-run screen), its own
  scene (`scenes/ui/grimoire.tscn`), a scrollable `RichTextLabel` in the
  same visual style as the death-summary/run-prep panels. Verified via
  the unit-test runner (5 new cases covering discovery marking and its
  save round-trip, 209 total passing), boot checks on both new/touched
  scenes directly (`grimoire.tscn`, `run_prep.tscn`), and a playtest
  batch exercising both combos' discovery-marking calls with zero
  errors. Not verified: how the screen actually reads/scrolls in a real
  window -- needs a human via `playdev`.
- 2026-08-16 — Compacting removal implemented, matching this doc's
  already-updated "Discard upgrade" section and decision-log entry.
  Deleted the five Compactor stat defs (`meta_progression.gd`) and every
  reference to them: `loot_registry.gd`'s `get_effective_stack_size()`
  now just returns each tier's fixed registry value (no lookup, no
  special-cased Legendary branch needed anymore either -- it falls out
  of the same generic logic); `shop.gd`/`skill_tree_view.gd`'s gate/
  tree-parent/tooltip tables lost their five Compactor entries, with
  Discard re-pointed to gate behind Bearing's first level as specced;
  `skill_tree_view.gd`'s rarity-tinted gem-icon special case (only ever
  used by Compacting's five nodes) removed along with them -- the gem
  icon just uses its passed-in color now, like every other icon.
  Balance re-verification (flagged, not resolved, per the item's own
  scope -- meta-progression/economy tuning is explicitly not this
  session's focus): playtested at three Bearing progression points
  (fresh save/5 slots, moderate/8 slots, maxed/15 slots). Fill %
  scales inversely with capacity as expected (higher Bearing level ->
  lower fill % for the same loot volume) and nothing crashed or read as
  obviously broken, but whether Bearing's cost curve *paces* correctly
  now that it's the only capacity lever left is a real open question
  this data doesn't answer on its own -- flagged for whoever picks up
  the economy pass, not decided here. Verified via boot checks
  (including `shop.tscn` directly, given how much of the skill tree this
  touched), the unit-test runner (192 passing -- the drop from 209 is
  expected: 20 fewer assertions from 5 removed stat defs in the generic
  per-stat tests, +3 from `_test_loot_effective_stack_size` now covering
  all six tiers instead of two), and three playtest batches with zero
  errors.
- 2026-08-17 — Bugfix: HUD loot readout and the backpack grid were still
  reading the pre-Tweak-3 fill formula (one slot per distinct tier
  touched, `backpack.size()`, hard-capped at 6) instead of the real
  slot-count `player.gd`'s `_slots_used()` had already moved to. The risk
  mechanic itself (size/hitbox growth, speed shrink) was always reading
  the correct value -- only the two things a player actually looks at to
  gauge fill % were wrong. Found while orienting for an unrelated
  ideation pass, flagged in TODO.md before this session picked it up.
  Fixed by moving the slot-accounting math (previously duplicated
  ad hoc in `player.gd` and about to be duplicated a third time in
  `backpack_grid.gd`) onto `LootTypes` as the shared source of truth:
  `count_slots_used()` and `slot_breakdown()`. `player.gd::_slots_used()`
  now delegates to it and gained a public `get_slots_used()` wrapper for
  HUD; `backpack_grid.gd` now draws one rect per real occupied slot
  (splitting a tier across multiple rects once its own stack fills)
  instead of one rect per distinct tier. Verified via 5 new unit-test
  cases (197 passing) covering the multi-slot split directly, plus a
  playtest batch with zero errors and sane fill % readings.
- 2026-08-17 — Synthesized IDEAS.md's ten Now-ish entries into the
  "Triage & Hoard Depth Pass" section above, at the player's request
  ("create a cohesive set of mechanics," not ten isolated specs). Six
  groups, not ten items, since most of the ideas were circling the same
  few problems from different angles: Group A (Queue pressure, Cast
  Off, Rarity cues) all deepen Active Pickup itself with no new
  systems; Group B re-points Discard/Gleam, both quietly broken by the
  pickup pivot rather than genuinely new; Group C (Scatter, Leaden,
  Magpie) all make loot spatially/combatively consequential instead of
  a pure inventory abstraction; Group D (Attunement) stood alone
  deliberately -- the biggest single idea, touching all 8 spells, and
  the only one that gives the run any in-run progression at all right
  now; Group E (Pacts) is a new shop category, not a stat tree, selling
  per-run rule mutations instead of permanent numbers -- the direction
  Compacting's removal already pointed at; Group F folds into the
  already-queued HUD + death-summary rework rather than standing alone.
  Named everything that needed a name (Attunement, Pacts, Magpie) and
  left the rest as plain mechanic terms per the established Frame/
  Function split in TEXT_FLAVOR.md. Deliberately did NOT spec the Later
  bucket at the same depth -- committing full technical requirements to
  admittedly-half-formed blue-sky ideas would be thrown-away work and
  defeats the point of keeping IDEAS.md low-rigor; those five got a
  light naming pass in IDEAS.md instead. Flagged two real open
  questions rather than guessing: whether Attunement's low/high ends
  actually balance against each other needs the playtest harness once
  built, not an assertion; Pacts' selection UI shape (2-option toggle
  vs. a longer list) isn't decided. See TODO.md for the six
  implementation items; none of this is built yet.
- 2026-08-17 — Depth Pass Group A (Triage Feel) implemented: Queue
  pressure (pending gems now weigh `PENDING_SLOT_WEIGHT = 0.5` of a real
  slot toward fill %, recomputed fresh on every queue change so
  resolution transitions cleanly with no separate bookkeeping to desync);
  Cast Off (Discard/L now throws the gem along the player's facing
  direction instead of fading in place -- tier-scaled damage/knockback on
  impact via the same `take_damage()`/`apply_knockback()` path every
  other damage source uses, no value banked, deliberately not
  Spellpower-scaled since this is the gem itself hurting something, not a
  cast); Rarity Cues (a pitched arrival tone per tier, ascending with
  rarity, on `Loot.enter_queue()`). Also fixed a real (if previously
  rare) bug this work made load-bearing: a Keep press against a full
  backpack used to silently orphan the gem node (untracked, unfreed,
  frozen in place forever) since `_check_triage_input()` advanced the
  queue unconditionally regardless of whether `collect()` actually
  succeeded. `Loot.collect()` now returns bool; a denied Keep leaves the
  gem queued instead. Verified via 5 new unit-test cases (203 passing)
  covering the pending-weight formula and the denied-collect contract,
  plus a playtest batch with zero errors -- the bot bypasses the triage
  queue entirely by design, so Cast Off/queue-pressure/rarity-cues still
  need a human `playdev` pass to verify feel, same caveat as the rest of
  Manual Triage.
- 2026-08-17 — Depth Pass Group B (Re-point Discard and Gleam)
  implemented. Discard: no longer auto-purges at a fill threshold
  (`_try_purge()`/`_get_purge_threshold()`/`_find_lowest_rarity_type()`
  deleted from `player.gd` outright, not just disabled); each level now
  adds flat bonus damage to Cast Off instead, expressed through
  `STAT_PURGE`'s own `per_level_gain` (0.0 -> 4.0) so it reads generically
  via `get_stat()` like every other stat's effect rather than a shadow
  constant -- this also means the shop's existing before/after tooltip
  now shows a real number for Discard for the first time. Gleam: paired
  its range increase with a per-level reduction to the pending-slot
  weight itself (Group A's `PENDING_SLOT_WEIGHT`), floored at 0.25 so
  queue pressure never fully disappears -- implementer's call on the
  exact mechanism, since the spec flagged this as "worth flagging, not
  obviously the only right one"; tuned so the floor lands right around
  Gleam's own level cap (15), not sooner. Updated `skill_tree_view.gd`'s
  Discard/Gleam tooltip descriptions, which still described the old
  auto-purge/pure-downside behavior. Verified via 4 new unit-test cases
  (206 passing) plus a playtest batch with Discard/Gleam maxed and
  Bearing at its floor (1 slot) to stress the full-backpack path
  heavily -- zero errors.
- 2026-08-17 — Depth Pass Group C (Loot Has Consequences) implemented:
  Scatter (`arena.gd`'s `_on_enemy_died` now computes a per-tier scatter
  offset -- Common lands in place, Legendary skitters 80-150px --
  radially outward from the arena center so chasing rare loot costs a
  worse position, clamped to stay in-bounds; `loot.gd`'s new
  `launch_scatter()` plays the hop, guarded against fighting the magnet-
  chase tween via a new `_is_scattering` flag); Leaden (Blessed's dark
  mirror -- same `AFFIX_CHANCE_BY_TIER` roll, a second coin-flip decides
  which of the two, more value but folds `LEADEN_BALLAST_SLOTS` extra
  weight into `Player._slots_used()` so a high-value item can finally be
  a real space gamble -- `BackpackGrid` draws ballast as its own plain
  muted slots so the grid's filled count always matches the HUD readout,
  same lesson as the fill-% bugfix earlier today); Magpie (new `Enemy`
  subclass, `imp` sprite frames tinted green since no bird/scavenger
  frame exists in the tileset pack -- chases the nearest unclaimed ground
  gem via a new `"loot"` group and eats it, falls back to a normal chase
  when nothing's stealable so it's never idle, drops everything it ate
  back at a value bonus on death via `loot.gd`'s new `mark_recovered()`,
  drops nothing if killed before it eats anything -- `arena.gd` skips the
  generic per-kill loot roll for it specifically since its own drop *is*
  what it stole). Spawn-weighted into Phase 2 (0.12) and Phase 3 (0.18)
  only, additive on top of the existing per-tier ratios rather than
  carved out of them. Verified via 3 new unit-test cases (210 passing),
  a forced editor rescan + direct scene boot check (new `class_name`
  script, same gotcha as a moved one -- CLAUDE.md), and two playtest
  batches (5 and 8 runs, reaching Phase 3, 55-71 kills/run) with zero
  actual errors -- an intermittent, non-reproducing "2 ObjectDB leaked at
  exit" warning appeared on 2 of 4 batches, consistent with whatever
  happened to be mid-tween at the exact quit moment rather than a real
  leak (didn't recur on an identical immediate re-run).
- 2026-08-17 — Pressure-tested and fully specced the Sanctum UX research
  pass (previous IDEAS.md entries), at direct request: "I dont want any
  ambiguities." Found and resolved four real conflicts/gaps the
  individual ideas didn't surface on their own:
  - Two of the eight ideas each wanted their own ring around the same
    node (currency-progress-to-next-level vs. level-progress-to-cap) --
    resolved as two distinct, coexisting rings (outer ring, inner arc)
    rather than picking one or silently merging them into something
    neither idea actually specified.
  - "Let the player pick which spell comes next" reads as a UX tweak but
    is a real mechanic/economy change touching already-shipped behavior
    -- split into its own "Spell Choice" section rather than bundled
    with the pure-presentation fixes, specifically because it has a save-
    compatibility question (existing saves already have levels bought
    against the fixed order) that a presentation change wouldn't. Chose
    a resolution (one-time migration, treat already-bought levels as
    "chosen" retroactively) rather than leaving it as an open question.
  - "Show the effect, don't state it" bundled three previews (Bearing,
    Gleam, Discard) as if equally cheap. Only Bearing actually reuses an
    existing mechanism (the in-run HUD's ghost-slot preview); Gleam and
    Discard have no equivalent to reuse and need new abstract diagrams
    built from scratch. Split the estimate rather than let the cheap one
    imply the other two are equally cheap.
  - Stacking all five presentation fixes (ring, arc, sealed state,
    border tint, per-tab count) onto one ~66px node risks recreating the
    exact "busy, illegible" problem this whole pass exists to fix.
    Flagged explicitly as needing a real windowed look once built, not
    asserted as fine because each piece individually made sense on
    paper -- per CLAUDE.md's own testing tiers, this is exactly the
    category headless verification can't cover.
  Also confirmed Pacts (Group E) touch neither currency at all --
  resolves why they belong on run-prep, not a fourth Sanctum tab -- and
  added Burden, a single running number summing active Pacts' drawbacks
  (Hades' Heat precedent), paired thematically with Bearing. Everything
  in this entry stays under the shop rework's existing on-hold status
  except Group E/Burden, which was never on hold. See TODO.md; none of
  this is built.
- 2026-08-17 — Depth Pass Group E (Pacts) implemented, against the spec
  as it stood when this pass started: a single `active_pact` (not
  `active_pacts`), no Burden. The Burden/multi-pact extension above
  landed in TODO.md mid-implementation of this same item -- deliberately
  NOT retrofitted here; see "Not yet built" below for why. What shipped:
  new top-level `PactDef` resource (mirrors `StatDef`'s identity shape,
  no cost/level fields -- Pacts are a free per-run choice, not a
  purchase); `MetaProgression` gained a 3-entry Pact registry
  (`get_pact_defs()`/`get_pact_def()`) plus `active_pact` persisted
  through export/import/reset like everything else. Starter roster, each
  with a distinct mechanism rather than a shared numeric knob: **Heavy
  Start** (bag pre-filled with `HEAVY_START_FILL_ITEMS` Common at
  `_ready()`, flat Essence bonus); **Fragile Bearing** (starting capacity
  reduced by a fixed amount, flat Essence bonus); **Narrow Queue**
  (queue capped at zero -- nothing waits behind the active gem, "must
  resolve before the next can even enter" taken literally -- in exchange
  for a Cast Off damage multiplier). Narrow Queue needed real new
  plumbing, not just a stat tweak: gems that arrive while capped now hold
  in a new `_narrow_queue_overflow` list (still magnetized, not yet
  queued) and get promoted once room frees, since an Area2D only re-fires
  `body_entered` on a fresh overlap and a magnetized gem never stops
  overlapping the player -- without this, a denied arrival would've
  softlocked exactly like the pre-Group-A Keep-when-full bug did. Caught
  by a unit test before it shipped: my first `_queue_has_room()` draft
  allowed exactly one gem through before capping (checked "is `_gem_queue`
  empty" rather than "is Narrow Queue active at all"), off by one from
  the spec's own "nothing waits behind it, ever." Selection UI: a row of
  `TabButton`s (the same toggle-with-underline component the shop's
  Player/Backpack tabs already use) on `run_prep.tscn`, built from
  `MetaProgression.get_pact_defs()` in code rather than hand-laid per-row
  markup, plus "None" (always first, always valid -- Pacts are opt-in).
  Verified via 11 new unit-test cases (221 passing, all against the real
  `player.tscn` scene, not a mock, so `_ready()`'s full pact-application
  path is genuinely exercised) and a forced editor rescan + direct boot
  check (new `class_name` script, same gotcha as any other). Not yet
  built: multi-pact selection (`active_pacts`) and Burden (the summed-
  drawback running number scaling payout) from the TODO.md update above
  -- a real scope change mid-item, not a small addition, so left as
  explicit follow-up rather than rushed into this same pass. The
  description text on Narrow Queue also needed a mid-pass fix: it
  originally read "only one gem may wait behind" (matching the same
  off-by-one the code briefly had), corrected to "nothing queues behind"
  once the code was fixed to match the spec's actual wording.
- 2026-08-17 — Depth Pass Group D (Attunement) implemented, last of the
  mechanics work per the design chat's own suggested build order (biggest
  and riskiest, deliberately given the most careful pass). `Player.
  get_attunement()`: count-weighted average tier-index of the backpack,
  normalized 0.0-1.0, recomputed fresh on every call (no cached/stored
  state, same pattern as `_slots_used()`) so it's always live without a
  dedicated change-signal. `SpellCaster` reads it through two shared
  helpers -- `_attunement_damage_multiplier()` folded straight into
  `_scaled_power()` (already the one place all 8 spells + Streak funnel
  damage through, so this was a one-line change, not 8 duplicated lerps)
  and `_attunement_cooldown_multiplier()` wrapped at each spell's own
  cooldown-reset site via a new `_attuned_cooldown()` helper. Empty bag
  implemented as its own branch exactly as specced, not an extrapolation
  of the Low end: weaker damage than even the Low floor (0.6x vs. Low's
  0.85x) AND no cast-rate speed bonus at all (1.0x vs. Low's 0.8x) --
  genuinely worse on both axes, not just numerically identical to an
  all-Common bag. Small cleanup along the way: the tier-index lookup
  Attunement needed was already hand-rolled twice (Streak in
  spell_caster.gd, Cast Off in loot.gd) -- consolidated all three onto a
  new `LootTypes.get_tier_index()`/`get_tier_count()` instead of adding a
  third copy, per CLAUDE.md's duplicated-lookup guidance. `spell_caster.gd`
  gained a `class_name SpellCaster` (had none) so its Attunement constants
  could be referenced with real static typing from the unit tests, same
  convention every other major script already follows.
  **Balance risk -- honestly scoped, not oversold:** verified via 7 new
  unit-test cases (232 passing) that the formula and multipliers compute
  correctly in isolation (weighted-not-naive averaging, Low/High/Empty
  each land on their specced constants), and via a 10-run playtest batch
  with all 8 spells active that nothing crashes or produces NaN/garbage
  damage across a real spread of fill states (36-73%) reaching Phase 3.
  What this does *not* verify: whether Low and High Attunement each
  genuinely win in different circumstances rather than one dominating --
  the "flask piano" risk the spec explicitly flags. The playtest bot
  auto-collects via Manual Triage's bot-bypass and has no notion of
  deliberately staying lean vs. deliberately hoarding, so it can't
  produce the A/B comparison this risk actually needs; that requires
  either extending the bot AI with a lean/hoard strategy toggle or real
  human play across both extremes. Flagged for the next pass, not
  asserted as solved. Also not built (explicitly out of scope): the HUD
  Attunement gauge (belongs with the HUD + death-summary rework) and the
  optional VFX tint (cooler/thinner at Low, warmer/thicker at High) --
  the spec framed both as "could," and effort went into the mechanic the
  balance risk is actually about instead. `spell_caster.gd` is now 603
  lines, past CLAUDE.md's ~400-500 soft ceiling -- flagged, not split;
  splitting 8 spells' casting logic into per-spell files is a real,
  independent refactor with its own risk, not something to rush alongside
  a balance-sensitive mechanic change in the same pass.
- 2026-08-17 — Grimoire extended to cover Magpie, Attunement, and Pacts,
  per the design chat's own suggested build order ("by now Magpie,
  Attunement, and Pacts all exist, so the reference screen documents the
  finished mechanics"). New THREATS section for Magpie, progressive
  discovery like Gem Combos -- new `MetaProgression.magpie_encountered`
  flag, marked in `EnemyMagpie._ready()` the moment one spawns in,
  persisted through export/import/reset like `discovered_combos`.
  ATTUNEMENT and PACTS sections are always shown, deliberately not
  discovery-gated: neither is a run-time surprise the way an undiscovered
  combo is -- Pacts are already visible on the run-prep screen before
  every run, and Attunement is a passive, always-on mechanic from the
  moment a run starts, so hiding either behind "???" would withhold
  information the player already has, not protect a real reveal. Pacts'
  entries are read live from `MetaProgression.get_pact_defs()` rather
  than a second hardcoded list, so a future Pact shows up automatically.
  Verified via 4 new/extended unit-test cases (235 passing, including the
  encounter-flag's save round-trip alongside the existing combo-discovery
  one), a direct scene boot check, and a playtest batch with zero errors.
- 2026-08-17 — Shop skill-tree rework implemented: three tabs (Player /
  Spells / Backpack) instead of two, per DESIGN.md's "Shop structure:
  skill tree" section. Player Tree now holds only Spellpower/Swiftness/
  Gleam (an explicit allowlist in `shop.gd`, not "everything not
  backpack-currency," so a future non-spell Player-currency stat doesn't
  silently land in the wrong tree by default); the new Spell Tree absorbs
  Spell Unlock plus all 13 per-spell upgrade stats. Deleted the old
  read-only spell-lock sidebar (`_spell_status_labels`/
  `_update_spell_status()` and its 8 status-label nodes) entirely -- the
  Spell Tree's own node state (locked/gated/purchased) now carries that
  information, matching the spec's "every spell upgrade is now a real,
  purchasable tree node." Also fixed a real gap this surfaced in
  `skill_tree_view.gd`'s purely-visual parent-chaining: only Inferno/
  Frost's upgrade stats had a real trunk branch under Spell Unlock;
  Arcane's two (ungated) and all five v11 spells' (gated L3-L7) fell
  through to the generic cosmetic root-chain instead, even though
  `shop.gd`'s own `_gate_requirements()` already enforced those gates
  functionally -- the tree just didn't *look* like it. Extended the
  branch map to match, using gate values that already existed, not new
  ones. No stat ID, cost curve, or gate value changed anywhere, per the
  item's own scope. Picked up the ALL-CAPS "START RUN" casing fix from
  TEXT_FLAVOR.md's still-queued text-overhaul item while already
  rewriting that exact button (zero extra cost) -- the text-overhaul pass
  itself will find this one already done. Verified via the full unit-test
  suite (235 passing, unaffected -- no test targets shop.gd directly), a
  direct scene boot check (confirmed via git stash that a pre-existing,
  unrelated ~42-object leak-at-exit warning on this scene predates this
  rework, not a regression), and a playtest batch with zero errors. Not
  verified: how the three-tab layout actually reads/feels in a real
  window -- needs a human via `playdev`, same caveat as every other UI
  change this session.
- 2026-08-17 — Spell Choice implemented: buying a Spell Unlock level no
  longer grants a fixed spell -- it spends currency and grows the trunk
  immediately (unchanged), then leaves that level's spell as a real
  pending choice between 2 offered candidates, resolved via a new shop
  panel. `MetaProgression.chosen_spells` (level -> spell id) replaces
  `SPELL_UNLOCK_REQUIREMENTS` as the live source `is_spell_unlocked()`
  reads; a level can legitimately be bought with its choice still
  pending (no progress lost quitting mid-choice, since the trunk level
  itself is already paid for and saved).
  **A real math problem found and resolved, not just an "ambiguity":**
  the spec's own "offer 2 of the remaining pool, Familiar reserved for
  the final level" doesn't actually work with exactly 7 spells across
  exactly 7 levels -- a pool that shrinks by exactly 1 per level always
  leaves precisely 1 candidate at the last pick, structurally, regardless
  of how the reservation is arranged (verified by hand-tracing the pool
  size level by level before implementing, not discovered by trial and
  error in code). Resolution: L1-L5 are real 2-way choices (pool sizes
  6,5,4,3,2 flowing in, all >= 2); L6 auto-resolves to whichever single
  non-Familiar spell is left (deterministic, not random -- an emergent
  "the spell you always passed on" moment); L7 always resolves to
  Familiar alone. Both single-candidate levels still route through the
  same reveal panel as a real 2-way choice, just showing one option
  instead of two, so every level still feels like a "new spell" moment --
  this is the detail that makes the resolution feel intentional rather
  than a bug, and it's why "5 real choices instead of 7" doesn't
  contradict "the final trunk level is a genuine capstone reveal."
  Save compatibility: `_migrate_fixed_spell_order()` backfills
  `chosen_spells` from the old fixed order for any save with no
  `chosen_spells` key, using only levels actually already bought --
  nothing is silently wiped. The playtest harness's `--playtest-seed`
  (and every `debug_set_level()` call across this session's own unit
  tests) sets stat levels generically with no player to click through a
  real choice panel, so `debug_set_level()` picked up the same
  old-fixed-order backfill specifically for `STAT_SPELL_UNLOCK` --
  without it, every seeded/test spell-unlock level would grow the trunk
  but leave every spell locked, silently breaking every playtest batch
  this entire session has relied on for balance signal. `grimoire.gd`'s
  locked-spell tooltip lost its "(Spell Unlock Lv N)" text since which
  level unlocks which spell is no longer fixed or knowable in advance.
  Known small duplication, flagged not fixed: `shop.gd`'s new
  `SPELL_DISPLAY_NAMES` repeats 7 of `grimoire.gd`'s `SPELLS` names,
  since `grimoire.gd` has no `class_name` and no clean public accessor to
  reuse from a second script -- a future cleanup could unify these, not
  worth the extra surface area in this same pass. Verified via 3 new
  unit-test cases (252 passing) covering the basic buy-then-choose flow,
  the exact L6/L7 single-candidate math derived above, and the migration
  backfill; two pre-existing generic tests that loop `debug_set_level()`
  across every stat needed `chosen_spells` snapshot/restore added to stay
  isolated from this new side effect. Also verified via a direct shop.tscn
  boot check and three playtest batches (full unlock, partial unlock, and
  the existing zero-error baseline) confirming seeded spell unlocks still
  actually cast in a real run. Not verified: the choice panel's actual
  feel/usability in a window -- needs a human via `playdev`.
- 2026-08-17 — Text overhaul implemented, per TEXT_FLAVOR.md's four fixes
  (the fifth, Sanctum's "Start Run" ALL-CAPS casing, was already picked
  up during the Shop tree rework while that exact button was already
  being rewritten). Deleted the death screen's redundant static
  "RUN SUMMARY" `GameOverLabel` -- `hud.gd`'s dynamically-built "Lost to
  the Void" already carries the title role at that size/weight, no script
  referenced the deleted node. Fixed `arena.tscn`'s `MetaStatsLabel`
  scene-default text (still read the pre-v5-naming-pass "Speed/Pickup
  Range/Capacity") to the current Swiftness/Gleam/Bearing names --
  invisible in play (`hud.gd` overwrites it before the player ever sees a
  frame) but misleading to anyone reading the scene file directly.
  Confirmed `scenes/main.tscn`/`scripts/main.gd` were fully dead (not
  `project.godot`'s `run/main_scene` -- that's `main_menu.tscn` -- and not
  referenced by any script or SceneTransition call, only by stale doc
  mentions) and deleted both outright rather than just dropping the
  hardcoded "game-idea v1" string, per TEXT_FLAVOR.md's own stronger
  option once dead-ness is confirmed. Fixed the `CLAUDE.md`/`README.md`
  references that deletion broke (the `main.tscn ↔ main.gd` naming
  example, the "root-flow scenes" list, the project-layout table, and the
  "Getting started" instructions) as a direct consequence of the
  deletion, not a broader doc pass -- README.md's other staleness (Godot
  4.4 vs. the project's actual 4.7, "v1" versioning framing) is
  unrelated and untouched. Verified via a direct `arena.tscn` boot check,
  a forced editor rescan (deleted files, not just added ones -- same
  global-class-cache gotcha applies both directions), the full unit-test
  suite (252 passing, unaffected), and a playtest batch exercising the
  death-screen path (every run ends in death) with zero errors.
- 2026-08-17 — Sanctum UX (node language, feedback, previews) implemented
  -- all 5 points from DESIGN.md's own spec, layered onto the Shop tree
  rework rather than left as a separate follow-up. **Point 1** (currency
  ring): `StatDef`-driven partial ring outside each non-maxed node
  showing `current_currency / next_level_cost`, fed by
  `set_tree_data()`'s new `current_currency` param; a "welcome back"
  shimmer for nodes that crossed into affordable since the shop was last
  closed, via new `MetaProgression.last_shop_close_*_currency` snapshots
  saved on `_on_back_pressed()`/`_on_start_run_button_pressed()` and
  compared once at `_ready()` -- deliberately a one-shot check, not baked
  into every `set_tree_data()` call, so it stays a "welcome back" cue
  rather than re-triggering on ordinary in-session spending. **Point 2**
  (node shape/size): new `StatDef.is_milestone` (set on Spell Unlock and
  Discard only) replaces the old "capstone if no children" inference,
  which had it backwards -- a flat leaf stat with nothing branching off
  it rendered *larger* than Spell Unlock. Removed `_chain_remaining_roots()`
  entirely after tracing `_calculate_positions()`'s root-stacking logic
  by hand first, confirming it already positions multiple disconnected
  roots correctly (each gets its own vertically-stacked band) without
  needing the cosmetic-chain hack -- verified before deleting, per the
  item's own flagged risk, not assumed. **Point 3** (level/cap arc):
  replaces the old level-pip row (drew `level_cap` pips at 7px each, so a
  20-level stat overlapped its neighbors) with a partial arc on the
  node's own border; closes to a full ring at cap. Freed space also fits
  a per-tab "N affordable" count, appended directly to each `TabButton`'s
  text rather than a new badge component. **Point 4** (purchase-moment
  feedback): purchase tone now steps pitch with post-purchase level
  (`AudioManager.play()` gained a `pitch_override` param); maxed nodes
  get a distinct bright sealed ring instead of the old barely-different
  0.9-vs-0.7 alpha; denied clicks (can't afford, or gated) get a shake +
  shortfall/"LOCKED" text via a new `SkillTreeView.flash_denied()`,
  decaying through the same tween-driven technique `juicy_button.gd`
  uses for its own feedback, applied to the node's draw offset since tree
  nodes aren't individual Button instances that script could target
  directly. **A real, previously-invisible bug found and fixed while
  building this, not cosmetic:** `MetaProgression.buy_upgrade()` never
  checked gating at all -- only `is_maxed`/currency -- so a click landing
  on a visually-locked node's position went through anyway if the player
  could afford it, silently bypassing the intended unlock order. Fixed
  by routing every purchase through a new shared `shop.gd::_try_buy()`
  that checks `_is_stat_gated()` first. **Point 5** (previews): Bearing's
  hover now ghost-previews the slot it would add, via a new
  `SkillTreeView.node_hovered` signal and a second `BackpackGrid`
  instance embedded in the Backpack tab -- `BackpackGrid` gained a thin
  `update_preview(capacity)` entry point (`update({}, capacity)`, since
  an empty backpack already renders exactly "capacity outline + ghost
  slot" through the existing path, no new drawing code needed). Gleam/
  Discard previews deliberately not built -- explicitly scoped as
  separable follow-on work in the spec itself, not bundled into this
  estimate. Verified via the full unit-test suite (252 passing,
  unaffected -- this pass is presentation-only, no stat/cost/gate values
  changed) and a direct `shop.tscn` boot check with zero script errors.
  **Explicitly NOT verified, per the spec's own stated caution:** how the
  five stacked encodings (ring, arc, sealed state, border tint, shortfall
  text) actually read together in a real window -- flagged in the spec as
  a real risk of "legible" tipping back into "busy," not asserted as fine
  because each piece made sense individually on paper. Needs a `playdev`
  pass before trusting it. Also noted, not acted on: `skill_tree_view.gd`
  is now 725 lines, well past CLAUDE.md's soft ceiling -- a candidate for
  extracting its icon-drawing functions into a separate file in a future
  pass, not attempted here to avoid restructuring a file mid-feature.
- 2026-08-17 — TODO.md and IDEAS.md consolidated into a single Now/Next/
  Later-format TODO.md, at direct request, once the entire 2026-08-17
  implementation pass (Depth Pass A-E, Grimoire extension, Shop tree
  rework, Spell Choice, Sanctum UX, Text overhaul) left both files
  mostly full of stale checkboxes and an emptied-out IDEAS.md "Now-ish"
  section. IDEAS.md deleted outright; its "Later" bucket carried over
  verbatim into the new TODO.md's own Later section rather than
  re-written, since none of those nine entries changed. The old TODO.md's
  large "Done"/historical-log sections were dropped, not carried over --
  git history and this decision log are already the permanent record,
  same reasoning this doc already applies to archiving its own old
  entries. This doc (DESIGN.md) is explicitly unaffected -- spec content
  and the decision log don't fit a Now/Next backlog shape and stay in
  their own file, per direct confirmation before this consolidation
  started.
- 2026-08-17 — HUD + death-summary rework fully scoped, closing the
  loose threads TODO.md's Next list had flagged (pip-brightening combo
  cue, new-run scoring, whether the meta-stats line still makes sense).
  Rewrote "## HUD & UI Design"'s "In-Run Stats Overlay" and "Death
  Summary Screen" subsections, which had gone stale enough to still
  describe MVP-era 💰/🎒 emoji labeling and a fill-bar alternative
  `BackpackGrid` already replaced -- verdict on the meta-stats line
  specifically: `Swiftness`/`Gleam`/`Bearing` are each still
  individually correct, the *set* is what's stale, missing a slot for
  Attunement (live, every run). Decided: an Attunement gauge reusing the
  existing `StatBar` component; combo-nearing pips on `BackpackGrid`
  (Streak brightens the one active-tier slot as `_streak_count` climbs
  toward `STREAK_THRESHOLD`, Full Set pulses every filled slot once
  exactly 5 of 6 tiers are held); and three new personal-best categories
  alongside the existing survival-time record -- Richest (`total_value`
  at death), Leanest (`seconds_survived × (1.0 - max_fill_ratio)`,
  deliberately rewarding neither instant death nor a full bag), Most
  Refused (a new `Player._discards_this_run` counter, nothing tracked
  this before). Not yet built -- see TODO.md; DESIGN.md's HUD & UI
  Design section above now carries the full spec, this entry is the
  decision record. (This entry originally also specced Burden's HUD/
  death-screen readout -- removed along with the rest of Burden once
  Pacts was binned, see the entry below.)
- 2026-08-17 — Pacts (Depth Pass Group E), and its Burden follow-up,
  removed entirely at direct instruction ("I don't like it") after
  having been fully designed and implemented earlier the same day.
  Design-direction call, not a balance finding -- same category of
  decision as Compacting's removal, not a response to any playtest or
  technical problem with what shipped. Scope of the removal: the whole
  Group E spec (Heavy Start/Fragile Bearing/Narrow Queue, the run-prep
  selection UI, `PactDef`/`active_pact`), Burden's payout-multiplier
  formula (`award_run_end_currency`'s third parameter, `PactDef.burden`,
  the ×1.00-1.45 curve), and Burden's two HUD additions (the appended
  meta-stats line entry, the death-screen REWARDS readout) -- all struck
  from DESIGN.md rather than left as dead spec text pointing at code
  that no longer exists. No replacement mechanic; the Sanctum stays at
  three trees plus nothing else. The two Later-bucket ideas that
  presupposed Pacts existing ("Pacts are the endgame the caps already
  imply," "Resolve") are removed from TODO.md for the same reason --
  their entire premise depended on a mechanic that's now gone. What
  stays as historical record, deliberately not rewritten: the earlier
  2026-08-17 entries describing Pacts being designed, implemented, and
  extended into the Grimoire -- those were true when written, same
  treatment Cloud sync's removal got.
- 2026-08-17 — Pacts removal implemented in code (all the systems named
  in the entry above: `PactDef` deleted, the run-prep selection UI and
  `MetaProgression`'s Pact registry/`active_pact` stripped, the Narrow
  Queue overflow plumbing in `player.gd` simplified back to a plain
  uncapped queue, Cast Off's multiplier removed from `loot.gd`). Combo-
  nearing pips (this same pass's HUD + death-summary rework, "In-Run
  Stats Overlay" above) also implemented: `SpellCaster` gained
  `get_streak_count()`/`get_streak_tier()`, `BackpackGrid.update()` two
  new optional params, `hud.gd` computes both live off state it already
  had (no new tracking). Attunement gauge and the three personal-best
  categories from the same HUD spec remain unbuilt. 241/241 unit tests
  and an 8-run playtest batch pass; verified visually via windowed
  screenshots of Settings/Embark/Sanctum (temporarily pointing
  `main_scene` at each rather than clicking into the live window, per
  this project's screenshot-tooling rules).
- 2026-08-17 — Combo-nearing pips tuned after direct live-play feedback
  ("too subtle to notice"): a flat fill-color lerp alone didn't read
  during real combat. Fix was technique, not the underlying progress
  formula (still `(get_streak_count() - 1) / (STREAK_THRESHOLD - 1)` per
  the spec above) -- added an animated pulsing white ring on top of the
  fill tint for both Streak's hot slot and Full Set's near-complete
  slots (`BackpackGrid`'s `_draw_filled_slot()`), ring pulse speed
  scaling up as Streak nears its threshold. Motion reads far better than
  a static color shift at 20px slot size, same lesson `player.gd`'s
  MAX_SIZE_FRACTION easing already learned from live-play once before.
- 2026-08-17 — Attunement gauge and the three personal-best categories
  (Richest/Leanest/Most Refused) implemented, completing the HUD +
  death-summary rework. Gauge: new `AttunementRow` under the Loot row in
  `arena.tscn`, reusing `StatBar` and a new `HudStatIcon.Kind.FLAME`,
  colored via `ATTUNEMENT_COLOR_LOW`/`HIGH` lerped by
  `Player.get_attunement()`. Personal bests: `MetaProgression` gained
  `best_run_essence`/`best_run_leanness`/`best_run_discards` plus their
  `update_best_*()` functions (same "return previous, then overwrite"
  contract `update_best_run()` already used), `Player` gained
  `_discards_this_run`, and the death screen's old unconditional
  "Highest Previous Run" line was replaced with a "PERSONAL BESTS" block
  showing all four categories, each tagged "NEW RECORD!" only when a
  real previous best (> 0) was actually beaten. Verified: 259/259 unit
  tests (new coverage for the three `update_best_*()` contracts and
  their save round-trip), a 6-run playtest batch, and a windowed
  Attunement-gauge + real-death-screen check (temporarily pointing
  `main_scene` at `arena.tscn` and letting an unattended run play out to
  a real death, rather than clicking into the window).
- 2026-08-17 — TODO.md's seven-item Later bucket given a first full spec
  pass, at direct request ("give these as instructions to other process
  to implement them"), same rigor as the Depth Pass groups rather than
  forwarded as one-liners. New "## Later Bucket: First Spec Pass" section
  above. Six of seven (Altar, Legendary set piece, Phase 4, Trophy Hall,
  the Forge, Facets) are fully specced and moved to TODO.md's Next list.
  The seventh, "hoard should be losable," is explicitly **not** silently
  resolved -- the idea's own text flags it as "the softest spot in the
  whole design," weighing three shapes without picking one, so it gets a
  recommendation (voluntary extraction, not partial death-loss -- keeps
  the already-shipped "death banks in full" pillar intact rather than
  reversing it) instead of a unilateral call, and stays flagged pending
  confirmation rather than shipped as an instruction. Two scope-narrowing
  calls made explicitly rather than left open, same "ship one thing"
  discipline Group A already established for Streak-before-Rampage:
  Phase 4 picks the closing-arena shape only (going-dark and hostile-
  drop-zones deferred); Facets picks Swiftness and Gleam only, not all
  stats. One real technical unknown flagged rather than guessed: the
  Legendary beacon's enemy-redirect needs `enemy.gd`'s actual chase/
  targeting call site inspected before implementation, not read this
  session. One real technical crux caught before it could become a
  half-built bug: the Forge must adjust the weights every per-enemy
  `pick_random_weighted()` call actually uses, not just
  `pick_random_type()`'s rarely-hit fallback table, or it would ship
  doing visibly nothing.
- 2026-08-17 — First real art-direction decision: **Painted Hoard**
  (soft hand-painted illustration), chosen from three pitched options
  each anchored to a real Godot-built game -- Brotato (chunky flat
  pixel art), Halls of Torment (dim glowing dungeon pixel art),
  Backpack Battles/Sovereign Tower (painted illustration) -- rather than
  mood words, since every sprite in the game has been procedural
  placeholder since day one and this was the first time an actual
  direction needed picking. Backpack Battles' own genre (backpack-
  inventory, Godot) made it the closest thematic match of the three.
  New "## Art Direction" section above. Rarity hex colors stay locked --
  this changes render technique, not the six base hues. Production
  method (procedural approximation extending `loot_gem.gd`'s existing
  `_draw()` technique, vs. sourcing real illustrated sprite assets) is
  flagged as a genuine fork, not silently resolved -- recommended the
  procedural path since it costs nothing to try and matches every other
  visual system this game has shipped so far, but explicitly left
  overridable. Scoped as a phased rollout, not a full re-skin in one
  pass, same "ship one thing" discipline used throughout this doc:
  starting point is the loot gems specifically (smallest surface area,
  already validated in the pitch itself), player/enemies/spell-VFX/UI
  chrome come after. Not yet built -- see TODO.md.
- 2026-08-17 — The other six items from this pass's "Later Bucket: First
  Spec Pass" implemented (Art Direction not included -- see the entry
  above, picked up separately). **Altar**: new `scripts/structures/`
  domain folder (`Altar` scene/script), spawns at arena.gd's existing
  20s/40s phase beats offset from the player, offers one of two boons
  (Spellpower or full heal -- the guaranteed-tier-up boon deferred, real
  follow-on scope) at a cost simplified to one concrete tier drawn from
  "Rare or higher" (matching `Player.sacrifice_loot()`'s single-tier
  signature rather than an any-of-several-tiers combo cost), confirmed
  with the Keep key while in range, despawns after 15s unused. **A
  Legendary is a set piece**: `enemy.gd`'s chase call sites (base Minion,
  Boss, Bruiser's charge, Elite's kiting, Magpie's fallback -- attack
  aim/contact damage left player-directed on purpose) now route through
  a new `_chase_position()` that finds an uncollected Legendary via the
  `legendary_beacon` group; `loot.gd` gains `_is_beacon`, a stronger
  pulse, and a layered danger-glow reusing the skill tree's own glow
  technique; `start_magnet()` early-returns for it. Balance-tested with
  an artificially inflated drop rate (no crashes, survival not uniformly
  collapsed) rather than the real 0.5%/35% rates, which are too rare to
  sample cleanly -- flagged as a stress test, not a clean single-beacon
  read; the spec's own radius-cap mitigation wasn't needed on this
  evidence. **Phase 4**: `get_phase()` now returns 4 past a new
  `PHASE_4_TIME = 90.0` (capped at 3 for `PHASE_SPAWN_WEIGHTS`/
  `MAGPIE_PHASE_WEIGHT` lookups, which only have entries through Phase
  3); a shrinking safe-zone `Rect2` (`Arena.get_safe_zone_rect()`) drawn
  as a red encroaching edge and read by a new `Player.set_safe_zone()`
  damage-over-time check -- doesn't clamp/teleport, the hard arena-bounds
  clamp stays fixed at the full size, lingering outside the safe zone
  just costs HP, same as a battle-royale storm circle. Gets the same
  phase-announcement banner treatment as Phase 2/3. **Trophy Hall**: new
  `MetaProgression.best_loot_value` (tier -> highest value seen, checked
  at death against that run's final backpack -- reads each tier's fixed
  base value, not a true per-item value including affix bonuses, since
  those aren't tracked per-item by death time) and a new `TrophyHall`
  screen reusing the Grimoire's visual language, six fixed slots, linked
  from run-prep. **The Forge**: new `STAT_FORGE` (Backpack Tree, gated
  behind Discard L1, now the tree's real capstone -- the `is_milestone`
  flag moved off Discard onto it), `LootTypes.get_forge_adjusted_weights()`
  shifts weight from Common/Uncommon proportionally into every other
  tier; `pick_random_type()` and `pick_random_weighted()` were unified
  into one roll path (the former is now a thin wrapper over the latter)
  so both actually route through the adjustment, closing the spec's own
  flagged crux (adjusting only the rarely-hit fallback would have done
  nothing). **Facets**: `MetaProgression.get_stat()` branches on a new
  `active_facet` map for Swiftness/Gleam's reduced Face B primary gain;
  `get_facet_bonus()` returns Face B's secondary effect (dash-cooldown
  reduction, Cast Off damage) scaled by level; toggle UI lives above the
  Player tree in the Sanctum (moved there after a windowed check showed
  it invisible below the fold when placed after the tree). All six
  verified: 290/290 unit tests (new coverage for both faces of each
  Facet stat, the Forge's weight math and roll routing, Trophy Hall's
  update contract, all specifically called out in each spec as needing
  direct coverage, not just playtest-harness inference), multiple
  playtest batches including a temporarily-lowered `PHASE_4_TIME` and an
  inflated Legendary rate (both reverted after, per this project's
  established "lower the threshold, confirm clean, revert" technique),
  and windowed screenshots of Trophy Hall, the Sanctum's Facets/Forge UI,
  and a real death screen. The Altar's own live visual wasn't caught in
  an unattended screenshot (the test player died 2 seconds before its
  20s spawn) -- accepted on the strength of the headless batches
  spawning/despawning it repeatedly with zero errors rather than
  re-rolling the timing.
- 2026-08-17 — Art Direction's loot-gem starting point implemented, per
  the recommended procedural path (option A). `loot_gem.gd`'s three flat
  `draw_colored_polygon()` facets became `draw_polygon()` calls with a
  color per vertex (Godot interpolates the fill between them -- no
  `GradientTexture2D`/shader needed), each facet lighter near the top
  and darker toward the bottom point for a real light-to-dark form read,
  plus a warm dark-brown `draw_polyline()` stroke around the outer
  silhouette where there was previously no outline at all. Tint source
  untouched -- still neutral grayscale-ish vertex colors multiplied by
  loot.gd's rarity-color `modulate`, exactly as the spec required.
  Verified visually: an unattended arena run couldn't hold a clean shot
  of the (deliberately tiny, ~12px) in-game gems before dying, so a
  temporary scene instancing all six rarity tints at 9x scale was built,
  screenshotted, and deleted -- confirmed the gradient shading and ink
  outline read clearly and rarity tinting is unaffected. 290/290 unit
  tests and a 10-run playtest batch pass (pure `_draw()` change, no
  gameplay logic touched).
- 2026-08-17 — Painted Hoard's rollout continued into spell VFX and UI
  chrome, with one correction to this section's own premise found along
  the way: **player and every enemy variant are not procedural** --
  `player.tscn` and `enemy*.tscn` all use `AnimatedSprite2D` with real
  `SpriteFrames` from the 0x72 DungeonTilesetII pack
  (`assets/dungeon_tileset/`), from a sprite-art pass days before this
  Art Direction decision was written. "Painting" a pre-made pixel-art
  sheet isn't the same kind of change as swapping a `_draw()` call --
  pixel art's whole look is flat/limited-palette, so painterly gradients
  would clash with it, not extend it. Direct instruction: skip player/
  enemies for now (pixel art stays), continue with what's genuinely
  procedural. **Spell VFX** (6 of 8 spells' dedicated FX scripts --
  Teleport Pulse and Summon Familiar have no dedicated procedural visual
  of their own, see below): `spell_projectile.gd` (Arcane Bolt) gained
  the same layered warm-glow technique as the skill tree's node glow and
  the Legendary beacon; `inferno_burst.gd`/`frost_burst.gd`/
  `time_warp_burst.gd`'s single flat-color rings gained a brighter
  warm/cool core arc alongside the outer one, approximating a
  light-to-dark gradient across a stroke (a true fill gradient doesn't
  apply to a ring shape the way it did the gem's solid facets);
  `meteor_strike_fx.gd`'s impact flash (the one genuinely filled shape
  in this set) got a real two-layer radial gradient; `lightning_bolt_fx.gd`
  already had a layered treatment, just warmed its white highlight to
  match this pass's language. Teleport Pulse reuses the shared
  `spark_burst.tscn` particle (no dedicated script to touch); Summon
  Familiar's pet is an `AnimatedSprite2D`, same category as player/
  enemies, skipped for the same reason. **UI chrome**: reconciling every
  hardcoded gray `Color` literal across every UI script (settings,
  shop, run-prep, Grimoire, Trophy Hall, save-slot selector, main menu)
  to warm parchment is real, larger follow-on scope than this pass --
  flagged rather than attempted wholesale. Took the single highest-
  leverage step instead: `resources/panel_dark.tres` (the one shared
  `StyleBoxFlat` nearly every panel in the game already draws from) went
  from flat near-black gray-green to a warm dark umber background with
  a muted-gold border, updating every screen at once from one file.
  Deliberately stayed dark (not literal light parchment) so existing
  light-colored text across dozens of screens didn't need touching too
  -- a full light-parchment/dark-ink flip is the real "illuminated
  manuscript" version of this idea but is its own, much larger pass.
  Verified: 290/290 unit tests, a spell-heavy playtest batch (all 7
  spells unlocked, high damage) with zero errors, and windowed
  screenshots of the Grimoire and Settings confirming the warmer panel
  reads consistently with text still fully legible.
- 2026-08-17 — Art direction reconsidered and replaced, at direct
  instruction that the first pass ("nowhere near the scope wanted") was
  too narrow on two axes: it only changed rendering technique on the
  existing premise, and it phased down to "loot gems only." Round two
  pitched three full setting-and-style packages (a creature-hoarder
  reframe, an abyssal-dive reframe, a sci-fi salvager reframe), each
  from a live artifact, each honest about its own rename-cascade cost.
  **Abyssal Dive won.** New "## Art Direction" section above fully
  replaces the Painted Hoard content from earlier today -- full rename
  cascade (title, both currencies, three stats, the Magpie enemy, three
  of the four newly-specced Later Bucket mechanics), all 8 spells
  renamed/reflavored (mechanics unchanged), a dark/glow visual language
  superseding Painted Hoard's warm-painterly one, and a five-step build
  order (naming pass first, since it's zero-art-dependency and unblocks
  verifying everything after against real names). Two locked decisions
  carried forward unchanged, not revisited: enemy tier names (Minion/
  Bruiser/Elite/Boss) and rarity tier names, both already-closed
  TEXT_FLAVOR.md questions with no new reason to reopen. **Real
  conflict with in-flight work, flagged explicitly:** the entry directly
  above this one already shipped `resources/panel_dark.tres`'s warm-
  umber/gold Painted Hoard treatment -- that now needs redoing under
  Abyssal Dive's cold/dark-water palette, not left as-is or treated as
  a head start. See TODO.md for the concrete follow-up.
- 2026-08-17 — Codebase prepped for a full re-skin, ahead of the Abyssal
  Dive pass above: every hardcoded `Color` in scripts (~55, across 22
  files -- spell VFX, HUD, loot, skill tree, backpack grid, enemy/player
  flash colors, structures, buttons, background decor) now reads from a
  new `Palette` autoload (`scripts/palette.gd`) instead of being
  duplicated at each call site; every `.tscn`-baked Label `font_color`
  (~23 across 8 scenes) now reads from a new `resources/game_theme.tres`
  Theme resource's named type variations instead. Pure refactor -- no
  colors changed, only where they live. Means Abyssal Dive's actual
  palette swap (and the already-flagged `panel_dark.tres` redo) is now a
  matter of editing these two files' values, not hunting through 30
  files by hand. Two names in `Palette` (`PAINTED_INK_GEM`,
  `PAINTED_INK_PROJECTILE`) still carry the superseded Painted Hoard
  name -- harmless (their values just need updating like every other
  const when Abyssal Dive's actual pass lands), left as-is rather than
  renamed speculatively. Verified: 290/290 unit tests, a clean 5-run
  playtest batch, and a windowed screenshot of `grimoire.tscn` (the
  Theme migration's proof-of-concept scene) confirming the refactor is
  visually silent -- the remaining 7 scenes followed the identical,
  already-proven pattern. Windowed screenshots of the other migrated
  scenes were not captured this session: the host hit a repeated Intel
  GPU driver crash (`igc64.dll`, confirmed via Windows Event Log) under
  the default Vulkan renderer, and the GLES3 fallback rendered but
  produced blank captures -- an environment issue, not a code one.
