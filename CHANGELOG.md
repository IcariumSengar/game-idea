# Changelog

All notable fixed versions of this project are documented here.

## v0.3.0 - 2026-08-18

The biggest single release yet: a full re-theme, six new mechanics, a
skill-tree UX rebuild, and gamepad support. Consolidates everything
built since v0.2.0 across several parallel sessions/worktrees, now
fully merged into `main`.

**Abyssal Dive — full re-theme, replaces the fantasy setting
top to bottom.** The game is now **Abyssal Hoard**: you're the Diver,
descending into a lightless deep where glowing salvage is the only
color in the frame.
- Complete naming cascade: the Cove (was the shop), the Ship's Log
  (reference screen), Glow/Depth (the two currencies), Hold/Current
  (backpack capacity/move speed, Gleam unchanged), the Angler (the
  loot-stealing enemy, was the Magpie), the Reliquary (was Trophy
  Hall), the Lure (was the Forge), and all 8 spells renamed/reflavored
  (Luminous Dart, The Undertow, Deep Chill, Trench Collapse, Eel
  Current, Crushing Depths, Ink Jet, Anglerling) — mechanics unchanged
  throughout, only names and flavor.
- The Diver and all six enemy tiers moved from placeholder pixel art to
  six hand-authored SVG vector sprites, with a procedural swim-bob
  replacing frame animation.
- Every color in the game — UI chrome, backgrounds, loot gem glow,
  spell VFX — recolored from a warm painterly palette to a dark,
  high-contrast, glow-driven one, each spell tinted to its new identity
  rather than a uniform recolor.
- Loot gems reworked: darker, desaturated facets with a layered
  rarity-colored glow behind them — "dark ground, glow reads as
  meaning" — replacing the old bright flat-gradient gems.
- Trench Collapse's telegraph is now spreading pressure cracks instead
  of a plain warning ring.

**The Constellation — skill-tree UX rebuilt from the ground up.**
Direct feedback that the previous pass was "too flat, doesn't tell the
player what's been unlocked, or what they can afford" prompted a full
redesign: one brightness/pulse language (locked/dim/affordable-
pulsing/maxed) replaces three separate per-node rings, purchased
upgrades now trace a lit glowing path back through the tree, and each
of the three trees got a real shape — the Player Tree a hub-and-spoke
around the Diver, the Backpack Tree a tight cluster, the Spell Tree a
radial arc instead of a flat flowchart.

**New mechanics:**
- **Manual Triage deepened** (Depth Pass A-D): queued gems now weigh on
  backpack-fill pressure before you decide on them; discarding a gem
  fires a damaging Cast Off throw; picking up a gem flashes its rarity
  color as a readable cue; Hold/Gleam re-pointed to matter earlier;
  gems scatter on drop and can go Leaden (heavier, harder to carry);
  the Angler chases loot instead of the player and can be killed to
  recover what it stole; Attunement — your bag's composition live-tunes
  spell cast rate vs. power.
- **The Altar** — a structure spawning at each phase boundary, offering
  one boon (a temporary power spike or full heal) in exchange for
  sacrificing a stack of items.
- **Legendary drops are a set piece** — instead of auto-magnetizing,
  they pull every living enemy toward them until collected.
- **Phase 4** — the arena itself closes in as a third escalation beat,
  on top of the existing enemy-tier ramp.
- **The Reliquary** — a pure-display screen showing the single best
  item ever found per rarity tier.
- **The Lure** — a chain-gated skill node that shifts the loot table
  toward higher rarities.
- **Facets** — Current and Gleam each get a free-to-switch second
  effect (Hades' Mirror-style), no new cost or currency.
- **Surfacing** — a voluntary extraction window every 30 seconds
  survived, banking your run early at a 10% bonus instead of pushing
  on. The hoard was always losable to death; now it's a real choice,
  not just an inevitability.

**Also:**
- Full gamepad support: movement, dash, gem triage, and menu/skill-tree
  navigation, alongside the existing mouse/keyboard controls.
- Keybindings are now remappable from the Settings menu.
- A HUD progress indicator toward completing a gem combo.
- Player and every enemy tier's sprite/hitbox size halved for a
  tighter, more legible arena at a glance.
- The Pacts mechanic, added and playtested this cycle, was cut before
  release on direct feedback — see the decision log if picking up
  related work.

## v0.2.0 - 2026-08-17

New mechanics, not just polish: the backpack-fill risk signal, gem
combos, and how loot gets collected in the first place all changed.
Playtested clean via a real windowed pass before tagging.

**Active Pickup: Manual Triage** — gems no longer auto-collect on
contact. They queue in front of the player and wait on a K (keep) / L
(discard) decision, with a distinct sprite gesture for each outcome.
Turns loot collection into a moment-to-moment decision instead of a
passive pickup, and sets up the fill-risk tradeoff below to actually be
felt. Bots bypass the queue entirely so playtest-harness balance signal
is unaffected.

**Backpack-fill risk: size/hitbox replaces HP-shrink** — a fuller
backpack now scales the player's sprite and hitbox up instead of
shrinking max HP. Makes the risk legible at a glance (you can see
yourself getting bigger and easier to hit) rather than buried in a
stat you have to check.

**Gem Combos** — Full Set (hold one of every rarity tier at once, one-time
AOE clear) and Streak (three consecutive same-tier pickups, repeatable
AOE burst scaled by tier). Both land with a shake/hit-stop/callout-label
hit (`"FULL SET!"` / `"STREAK!"`) so completing one actually feels like
something.

**Gem visuals reworked** — smaller, faceted "pips" at rest with a
punchier pop on pickup, replacing the old plain gem sprites; iterated
twice on size after initial passes read as either too flat or too small
to track at a glance.

**Backpack Ability and Compacting removed** — the pre-run Condense/Clear
choice and the Compacting stat line are both gone; they were built for
the old HP-shrink risk model and didn't carry over cleanly to the new
size/hitbox one. A design-direction call, not a balance nerf — see
DESIGN.md's decision log for the reasoning. The Backpack skill tree's
gating was re-pointed at Bearing so it isn't left flat.

**Also:**
- The Grimoire: an in-game spell/combo reference screen, reachable from
  Run Prep, that reveals each entry only once you've actually unlocked
  the spell or triggered the combo — progressive discovery instead of a
  full spoiler list.
- An Escape pause menu mid-run (resume/quit), so a run can be exited
  without alt-tabbing.
- Enemy-tier and loot-tier unlock announcements ("BRUISERS!" /
  "ELITES!" / "BOSS!") called out on screen as a run's difficulty ramps.
- Per-enemy drop rates tuned toward rarer tiers, focused specifically on
  arena-play feel rather than the meta-progression economy.
- A `(DEV)` marker next to the version label when launched via `--dev`.

**Engineering:** a headless pure-logic unit-test runner
(`scripts/unit_tests.gd`, `--unit-test`) joins the playtest harness as a
second, faster verification tier for pure-math changes. Save-slot
persistence split out of `MetaProgression` into a new `SaveManager`
autoload. `scripts/`/`scenes/` reorganized into domain subfolders
(`player/`, `enemy/`, `loot/`, `fx/`, `ui/`) now that the flat layout was
getting hard to navigate.

## v0.1.1 - 2026-08-16

Stabilization pass: no new gameplay content, all polish/tooling/docs.
This is the intended "ultra stable" handoff point before a planned
period of larger system overhauls and new mechanics/graphics — v0.1.0
stays as the first semver tag exactly as released; this patch is
everything that landed cleanly on top of it.

- Shop reorganized into Player/Backpack tabs instead of side-by-side
  trees — with the Player tree now spanning 17 stats across 8 spells
  (v11), showing both at once had gotten too cluttered. No stat/economy
  changes, presentation only.
- New non-focus-stealing visual testing tooling (`tools/screenshot.ps1`,
  `click_foreground.ps1`, `click_at.ps1`) — captures/interacts with the
  running game window without stealing focus from other work, replacing
  the ad-hoc approach that prompted that exact complaint earlier in
  development. Used to verify the shop tab UI end-to-end.
- New [TESTING.md](TESTING.md): full reference for both the headless
  playtest harness and the new screenshot tooling, including gotchas
  found along the way (worth reading before touching either again).
- CLAUDE.md expanded with engineering standards accumulated over the
  v0.1.0 development arc: a three-tier testing framework, an "AI
  session discipline" section on token-budget-conscious habits, and
  several GDScript/architecture conventions.
- Verified via a full stabilization pass: format/lint across every
  script, headless boot checks (including direct runtime instantiation
  checks of non-main scenes), and multiple playtest harness batches
  with every current system active — zero errors.

## v0.1.0 - 2026-08-16

First release under semantic versioning (see VERSIONING.md) — earlier
releases used flat whole-number tags (v1–v8); this isn't a continuation
of that numbering, it's the first tag under the new scheme, and the
biggest single release yet. Consolidates everything built since v8 into
one milestone: the full Magic Spells system (8 spells across three
unlock waves), a fourth enemy tier, real enemy sprite art, several new
backpack/economy systems, a headless playtest harness, and a
data-driven early-game rebalance.

**Magic Spells, complete:**
- Player is a magic user. Casting-based combat replaced the old flat
  weapon — Arcane Bolt (ranged, always available), Inferno Blade (melee
  AOE + burn), Frost Nova (AOE + slow), unlocked via a new Spell Unlock
  skill-tree node.
- Every unlocked spell now casts simultaneously and independently
  rather than switching between one active spell at a time.
- Five more spells joined the roster: Meteor Strike (boss-killer AOE),
  Lightning Chain (arcs between enemies), Time Warp (crowd control),
  Teleport Pulse (mobility + damage), Summon Familiar (persistent pet)
  — Spell Unlock now runs L1–L7.
- Inferno Blade gained its documented 200px knockback; Inferno and
  Frost Nova both got dedicated procedural visuals instead of reusing
  generic spark particles.

**Enemy Types:**
- Tier 4 Boss: unique, spawns once at 55+ seconds, hybrid melee
  pursuit + projectile-spread attack, guaranteed Mythic+ drop.
- Fast/Tanky Minion variants diversify Phase 1 without changing the
  documented tier ratios.
- Bruiser, Elite, and the Boss all got distinct sprites (from the
  existing DungeonTilesetII asset pack) instead of tinted reuse of the
  Minion's frames.

**Backpack & economy:**
- Backpack Ability: a pre-run choice between Condense (merge 2 items of
  a tier into 1 of the next tier up) and Clear (bank an item's value
  immediately, free the slot) — a new Alchemy stat speeds up whichever
  is active.
- Loot affixes: Epic+ drops have a chance to roll "Blessed" for +50%
  value.
- A ghost slot in the backpack grid previews the next Bearing purchase.

**Balance, driven by data:** a new headless auto-playtest harness
(bot-controlled runs, no window, sandboxed save data) found that
Minion's actual stats had drifted from the documented spec (120/30 vs.
the documented 100/20) and that contact damage was the dominant early
lethality driver — both corrected. Arcane Bolt's fire rate and the
backpack-fill speed penalty were also eased on direct feedback.

**Also:** a real Settings menu (volume, fullscreen), and a few bugs
fixed along the way — a physics-flush crash when AOE spells killed
multiple enemies at once, and two spell cast sounds that played
regardless of whether anything was actually hit.

## v8 - 2026-08-15

Correctness pass: a full audit of every DESIGN.md number and behavior
against the actual code, fixing what didn't match rather than adding
new content.

- Difficulty ramp now scales Bruiser's charge speed and Elite's
  projectile speed over the course of a run, not just base
  `speed`/`max_hp` — Bruiser in particular didn't use `speed` at all,
  so its charge previously never got harder no matter how long you
  survived.
- Save/load now actually supports the documented 4-slot design: "New
  Game" no longer hardcodes slot 0 (and no longer wipes every other
  slot's metadata as a side effect); slots 2-4 can start a fresh game;
  an "Overwrite" action exists for occupied slots; "last played" uses a
  real timestamp instead of engine uptime (previously showed nonsense
  like "20680 days ago" after any restart); playtime now accumulates
  instead of resetting to 0 on every save; switching to an empty slot
  no longer leaves the previous slot's currency/levels in memory.
- Skill tree tooltip header bumped to its own spec'd 18px instead of
  matching the body text size.

## v7 - 2026-08-15

Two new enemy tiers join the Minion, with tactical roles instead of
just more HP: a charger that punishes standing still and a kiter that
punishes standing at range.

- **Bruiser** (Phase 2, 20+ sec): pauses 2-3s to telegraph, then
  charges in a straight line. Only deals contact damage while
  charging, so the pause is a real dodge window.
- **Elite** (Phase 3, 40+ sec): kites to hold ~300px of distance and
  fires a projectile instead of melee-attacking, so closing the
  distance is the counter-play against it.
- Each tier now drops loot from its own weighted table (per DESIGN.md's
  "Enemy Types & Loot Tiers") instead of the single flat global table
  every enemy shared before — Bruisers lean Uncommon, Elites lean
  Rare/Epic.
- `Enemy` is now a base class with an overridable behavior hook, so
  both new tiers reuse the Minion's HP/hit-flash/death-spark plumbing
  rather than duplicating it.
- Visuals are still the shared Minion sprite, tinted red (Bruiser) and
  blue (Elite) and rescaled — distinct sprite art is follow-up work.

## v6 - 2026-08-15

Balance rebalance plus the HUD/UI system promised for v5's follow-up:
harder early game, a live in-run stats readout, a real death summary,
and richer skill tree tooltips.

- Backpack economy slowed down per the "many runs, hard early game"
  philosophy: Stardust income cut to 0.05/sec (was 0.33/sec), Bearing
  (backpack slot) cost raised to 100 base ×1.25/lvl (was 20 ×1.20/lvl),
  Compacting tier costs raised across the board. Player-power upgrades
  stay cheap and early, so the ladder now reads: player stats (early
  wins) → Compacting (mid wins) → Bearing (late-game prestige).
- Fixed ambient magic particles clumping into a single fixed sparkle at
  the arena's center instead of drifting across it (wrong
  `emission_shape` enum value).
- In-run HUD gains a live Time/Essence/Stardust readout above the HP
  bar, updated every frame.
- Death screen is now a full run summary: time survived, difficulty
  phase reached, rewards earned this run, loot collected broken down
  by rarity, run stats (max backpack fill, enemies killed), and a
  previous-best comparison once one exists.
- Skill tree tooltips get a currency-colored border (gold/cyan),
  before/after stat values ("20 → 22"), and affordable/shortfall/
  maxed/locked status text instead of a plain description box.
- Adopted TEXT_FLAVOR.md's stat-naming pass: Damage → Spellpower, Move
  Speed → Swiftness, Magnet Range → Gleam, Backpack Capacity →
  Bearing, Purge → Discard, and the five Compacting tiers → Commons
  Hoard / Uncommon Stash / Rare Vault / Epic Trove / Mythic Hoard.

## v5 - 2026-08-15

The game has a name and a look: **Hoard Survivors**, restyled top to
bottom with a cosmic/magic aesthetic in place of the placeholder
dungeon look and generic UI text.

- Full menu system redesign: procedural night-sky backdrop (gradient,
  twinkling stars, mountain silhouette) and a rotating magic-circle
  motif replace the flat dark panels on the main menu, Run Prep, Load
  Game, and Shop screens. Buttons switched from box-styled to
  text-link style (gold on hover, with flourish lines), matching a
  reference screenshot.
- Skill tree redesigned from square medieval-framed nodes to circular
  chained nodes with per-tree accent colors, glow states for
  purchased/maxed tiers, vector icons per stat, and a hover tooltip
  showing each upgrade's name, description, level, and cost.
- Scene changes fade through black instead of hard-cutting; combat
  got floating damage numbers, hit-stop + weightier screen shake on
  player hit/death, an animated HP/loot bar, and a purchase-pulse
  effect on skill tree nodes.
- Procedural SFX for hits, deaths, pickups, dashes, purchases, and UI
  clicks — the project had no audio at all before this.
- Arena reskinned: the dungeon floor tileset is replaced by a
  procedural space backdrop (nebula washes, stars, no grid), with
  drifting ambient magic particles and a radial vignette. Player
  sprite swapped from a knight to a wizard; loot swapped from a
  spinning coin to a procedurally-drawn faceted gem tinted by rarity.
- Renamed the placeholder currency/stat text DESIGN.md flagged: Player
  Currency → Essence, Backpack Currency → Stardust, Compactor tiers →
  "<Tier> Binding", Shop → Sanctum, and the death screen restyled to
  match (border/text color, magic-circle decor, "Lost to the Void").
- Added a back button to the skill tree/shop screen and fixed a
  scene-change crash in the auto-load path on the main menu.

## v4 - 2026-08-14

Second round of parallel mechanics + visuals workstreams merged into
`main`:

- Loot reworked into six rarity tiers (common → legendary) matching
  DESIGN.md's table exactly: per-tier drop weight, stack size, and
  value. Backpack is a real slot grid (one slot per item type held),
  colored by rarity, replacing the old flat-count/abstract-bar model.
- Meta-progression split into two currencies: player currency (from
  loot value) funds Damage/Move Speed/Magnet Range; backpack currency
  (from time survived) funds Backpack Capacity. Upgrades are now
  leveled with a geometric cost curve and a hard level cap, replacing
  the old flat/uncapped cost.
- Damage and Move Speed are upgradeable stats for the first time
  (previously hardcoded constants).
- Player dash (spacebar), fixed a bug where loot the player couldn't
  actually hold still got magnet-pulled toward them.
- Real sprite art throughout (0x72 DungeonTilesetII), replacing all
  placeholder procedural shapes; Player extracted into its own scene.
- `/play`, `/close`, `/editor` slash commands for the run loop.

## v3 - 2026-08-14

First result of two parallel workstreams (core mechanics + visuals/UI,
each in its own git worktree) merged into `main`:

- Player stats reworked into a generic, data-driven system (`StatDef`
  + `MetaProgression`): upgrades are registered once and read
  generically by the shop and HUD, rather than hardcoded per stat.
- In-run stats readout (speed, pickup range, backpack capacity)
  confirming shop purchases carried into the next run.
- HUD rebuilt with styled panels, color-graded HP/backpack bars
  (`StatBar`), and a proper game-over panel with a styled continue
  button.
- Shared `.tres` style resources for panels/buttons instead of
  duplicated inline styles.
- Visual polish: drop shadows/outlines on player/enemy/loot, particle
  effects on hits/deaths/pickups, loot now pulls toward the player
  (magnet-style) instead of an instant pickup.

## v2 - 2026-08-14

Full MVP core loop from DESIGN.md, playable end to end:

- Top-down player movement in a bounded arena.
- Auto-attack combat against a chasing enemy type; contact damage.
- Player HP with a run-ending death state.
- Loot drops on kill, proximity-based pickup (upgradeable pickup range).
- Capacity-limited backpack; fill % shrinks max HP (the core
  risk/reward tension).
- Difficulty ramp: enemy spawn rate/HP/speed scale over the run.
- Run summary screen showing loot collected.
- Meta-currency (1:1 from loot), a shop to spend it on backpack
  capacity and pickup-range upgrades, and a run-restart flow that
  carries those upgrades into the next run.

## v1 - 2026-08-14

- Initial Godot 4.4 project scaffold
- Minimal main scene with version label
- Established tag + VERSION/CHANGELOG release model
