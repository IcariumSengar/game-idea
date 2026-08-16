# Game Text Flavor Spec (Hoard Survivors)

## Status

**Living spec, audited against shipped text 2026-08-16.** Earlier versions
of this doc were an options brainstorm written before most of the game
existed; several of its own recommendations were superseded by what
actually shipped (it suggested "Endurance" for the backpack currency, the
game shipped "Stardust" -- see DESIGN.md's decision log for that and the
other naming-pass entries). This rewrite replaces the brainstorm with a
definitive spec grounded in a line-by-line audit of every player-facing
string in the game as of `v0.1.1`, and resolves the old draft's "Open
Questions" instead of leaving them open indefinitely.

## Tone

Mystical & Determined + Dark & Desperate -- confirmed by what's shipped,
though Dark & Desperate carries more weight than the original draft gave
it credit for. The title itself is "HOARD SURVIVORS," tagline "Hoard what
you can. Survive what you must." -- squarely desperate-survival, not just
seasoning on a mystical base. Treat the two as equal partners going
forward, not primary/secondary.

## The real problem: two unlabeled registers, applied inconsistently

Auditing every screen turns up two genuinely different kinds of text
living side by side with no rule for which is which:

- **Frame text** -- titles, one-time narrative beats, proper nouns
  (screen titles, the death screen's emotional line, "Sanctum,"
  "Embark"). Read rarely, at a mood-setting moment. Worth the flavor
  investment.
- **Function text** -- buttons, numeric readouts, list rows, settings.
  Read constantly, scanned for information under time pressure (mid-run
  HUD, a save-slot list, a cost tooltip). Flavor here is friction, not
  charm.

Most shipped text already sorts cleanly into one bucket or the other
(Settings is entirely Function, "Lost to the Void" is entirely Frame) --
the inconsistency isn't that the game can't tell them apart, it's that
the split was never written down as a rule, so it drifted in a few
spots: two places put Frame and Function text right next to each other
doing the same job twice, and one same-action button ended up with
different casing on different screens. That's the actual "blurry line" --
not the tone itself, which is fine.

## Screen-by-screen audit

| Screen | Element | Current text | Register | Verdict |
|---|---|---|---|---|
| Main Menu | Title | HOARD SURVIVORS | Frame | Keep |
| Main Menu | Subtitle | "Hoard what you can. Survive what you must." | Frame | Keep |
| Main Menu | Buttons | PLAY / LOAD GAME / SETTINGS / QUIT | Function | Keep |
| Save Slot Selector | Title | LOAD GAME | Function | Keep |
| Save Slot Selector | Row buttons | Start / Load / Overwrite / Delete | Function | Keep |
| Run Prep (outer hub) | Title | EMBARK? | Frame | Keep |
| Run Prep | Progress panel | "Your Hoard" + stat/currency list | Frame label, Function content | Keep |
| Run Prep | Ability section | BACKPACK ABILITY, Condense / Clear | Function | Keep |
| Run Prep | CTAs | START RUN / ENTER SANCTUM / ← BACK | Function (CTA) | Keep casing convention |
| Sanctum (shop) | Title | SANCTUM | Frame | Keep |
| Sanctum | Currency | Essence: N / Stardust: N | Function | Keep |
| Sanctum | Tabs | PLAYER / BACKPACK (+ SPELLS, Tweak 1) | Function | Keep -- matches Tweak 1's plain-naming call |
| Sanctum | CTA | "Start Run" | Function (CTA) | **Fix -- casing mismatch, see below** |
| Arena HUD | Live stats | Time / Essence / Stardust / HP / Loot | Function | Keep |
| Arena HUD | Rate hint | "(+0.05/sec)" | Function | Keep -- deliberate transparency per DESIGN.md |
| Arena HUD | Meta-stats placeholder | "Speed: 250 Pickup Range: 60 Capacity: 20" (scene default, overwritten at runtime) | Function | **Fix -- stale pre-rename names, see below** |
| Death screen | Static header | RUN SUMMARY | Function | **Fix -- redundant with the line below, see below** |
| Death screen | Body opening line | "Lost to the Void" | Frame | Keep |
| Death screen | Body data | Time/Phase/Rewards/Loot/Stats | Function | Keep |
| Death screen | Buttons | Return to Sanctum / Restart Run | Function (CTA) | Keep |
| Settings | Everything | SETTINGS, Master Volume, Fullscreen | Function | Keep -- deliberately unflavored |
| Enemies | Minion/Bruiser/Elite/Boss | -- | Function | Keep -- already decided, not revisiting |
| Rarity tiers | Common...Legendary | -- | Function | Keep -- see "Closed questions" below |

## The fixes

1. **Death screen's double header.** `arena.tscn`'s `GameOverLabel` ("RUN
   SUMMARY," plain) sits directly above `SummaryBody`'s dynamically-built
   first line ("Lost to the Void," flavored) -- two titles, two
   registers, same panel, same moment. Delete the static "RUN SUMMARY"
   label; let "Lost to the Void" carry the panel's title role at that
   size/weight instead (`hud.gd`'s `_build_summary_bbcode()` already
   generates it, no new copy needed). One header, one voice.
2. **START RUN casing mismatch.** `run_prep.tscn`'s Start Run button is
   ALL-CAPS ("START RUN"); `shop.tscn`'s is Title Case ("Start Run") --
   same action, two screens, two casings. ALL-CAPS is the established
   convention for primary CTAs elsewhere (PLAY, ENTER SANCTUM, SANCTUM,
   HOARD SURVIVORS) -- standardize `shop.tscn`'s button to "START RUN".
3. **Stale HUD placeholder.** `arena.tscn`'s `MetaStatsLabel` scene-
   default text still reads "Speed: 250 Pickup Range: 60 Capacity: 20" --
   the pre-v5-naming-pass stat names. `hud.gd`'s `_ready()` overwrites it
   with the correct "Swiftness / Gleam / Bearing" wording before the
   player ever sees a frame, so this is invisible in play, but it's
   misleading to anyone reading the scene file. Update the placeholder to
   match.
4. **Dead scene leaking flavor-free text.** `scenes/main.tscn` (not the
   project's main scene -- that's `main_menu.tscn` per `project.godot`'s
   `run/main_scene`) has a hardcoded `"game-idea v1"` label and is
   unreferenced by any script or scene -- an unused leftover from the
   initial project scaffold. Delete it, or if there's a reason to keep
   it, at minimum drop the hardcoded placeholder. Note: `CLAUDE.md` and
   `README.md` both still describe it as current (the `main.tscn ↔
   main.gd` naming example, and README's scene table calling it the
   "Entry scene") -- worth a follow-up doc correction once the scene
   itself is resolved; outside this doc's scope.

None of these touch cost curves, stat IDs, or gameplay -- pure copy/scene-
default fixes, same spirit as Tweak 1.

## Essence and Stardust aren't actually clashing

Worth calling out since it looks like a mismatch on paper: Essence (loot,
arcane, "power distilled from what you took") and Stardust (survival
time, cosmic) read like two different aesthetic registers sitting next to
each other in a currency list. But every non-arena screen (`main_menu`,
`save_slot_selector`, `run_prep`, `shop`, `settings_menu`) already shares
the same `night_sky_background.gd` backdrop -- the entire meta-game
outside a run plays out under a literal night sky. That's an existing,
pervasive visual throughline that already reconciles the two: Essence is
what you *take*, Stardust is what the *sky grants you* for enduring
under it. Nothing to rename here -- if anything, it's worth reinforcing
with a small connective flavor line somewhere cheap (e.g. a hover
tooltip on the Stardust readout) rather than treated as a problem. Not
required for this tweak; flagged as a nice-to-have.

## Closed questions (resolving the old draft's "Open Questions")

- **Flavor text on every upgrade node?** No -- stays light-touch/
  optional, not mandatory. Writing 30+ node descriptions is a content
  task, not a text-consistency fix; out of scope here.
- **Enemy names mystical?** No -- Minion/Bruiser/Elite/Boss stay.
  Already decided once (see DESIGN.md); not revisiting without new
  reason.
- **Menu labels -- flavor or clear?** Answered by what shipped: titles/
  CTAs get flavor (HOARD SURVIVORS, PLAY, SANCTUM, EMBARK), Settings and
  list rows stay plain. That's the Frame/Function split above, made
  explicit.
- **Rename loot rarities (Common → Fragment, etc.)?** No -- Common/
  Uncommon/Rare/Epic/Mythic/Legendary is a load-bearing genre convention
  players parse instantly; reskinning it trades clarity for cuteness
  with little payoff. Function-register despite being "loot."
- **In-game Lore/Grimoire screen?** Real idea, but it's new content, not
  a text fix -- left for a future tweak if wanted, not part of this one.

## What this doc is not touching

DESIGN.md's own prose still calls this screen "the shop" throughout
(section headings, currency descriptions) even though the shipped screen
is titled "Sanctum" to the player -- that's design-doc terminology drift,
not a player-facing text bug, and fixing it means editing a lot of
existing DESIGN.md prose rather than game text. Flagged to the user
separately rather than folded into this spec.
