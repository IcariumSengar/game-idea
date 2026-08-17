# TODO

Now/Next/Later backlog — consolidated from the old TODO.md + IDEAS.md
into one doc, 2026-08-17, since both had grown large and the split
between "short-term backlog" and "free-form ideas" had stopped paying
for itself. Lower rigor than DESIGN.md on purpose: **Now**/**Next**
items get an explicit In scope/Out of scope line once they're real work
items about to be picked up; **Later** stays free-form, no spec
required, until something graduates up into Next.

Completed work isn't tracked here — git history and DESIGN.md's decision
log are the permanent record of what shipped and why (same reasoning
CLAUDE.md already gives for archiving DESIGN.md's own old entries: "Git
already preserves full history; the file doesn't need to").

## Now

Nothing is actively blocking implementation right now — everything
spec'd and ready shipped in one continuous pass on 2026-08-17 (Depth Pass
Groups A-E, Spell Choice, the Shop skill-tree rework, Sanctum UX, the
Text overhaul). What's actually pending:

- **Human verification pass.** Everything shipped 2026-08-17 is
  functionally verified (unit tests + the headless playtest harness) but
  none of it has been seen in a real window — per CLAUDE.md's testing
  tiers, visual/feel work can't be checked headless. Priority order:
  - **Sanctum UX first** — the spec itself flags real risk of the
    stacked node encodings (currency ring, level arc, sealed state,
    border tint, per-tab count) reading as "busy" rather than legible,
    not asserted as fine just because each piece made sense on paper.
  - **Pacts' run-prep selection UI** — never seen in a window; also the
    "2-option toggle vs. a longer list" question was resolved as a row
    of `TabButton`s, worth confirming that reads well with 4 options
    (None + 3 Pacts).
  - **Spell Choice's buy-then-choose panel** — a new interaction pattern
    for this shop, first time seeing it live.
  - **General feel** — Manual Triage's queued-gem visuals in motion,
    Cast Off's throw arc, Magpie's tint/silhouette, Attunement's spell
    VFX at each end of the spectrum.

## Next

Understood and mostly spec'd, but each needs a real decision before
code — not guessed at, per this project's own established discipline.

- **Burden.** Depth Pass Group E's follow-up — a single running number
  summing active Pacts' drawbacks (Hades' Heat precedent), scaling the
  run's payout. Two open decisions, not implementation gaps:
  - Multi-pact selection (`active_pact` → `active_pacts`) or does Burden
    apply against the current single-pact model as-is?
  - The actual payout formula. Unlike everything shipped 2026-08-17,
    there's no existing number to anchor this to (Spell Choice's math,
    Narrow Queue's cap, etc. all had a derivable correct answer) — this
    one is a real design call.
- **HUD + death-summary rework.** Needs its own design pass — the in-run
  overlay and death screen predate Gem Combos, phase callouts, the
  size/hitbox risk signal, Active Pickup's queue, Attunement, and Pacts.
  Absorbs a few loose threads once scoped: the "pips brighten as a combo
  nears completion" cue, new-run scoring (personal bests for
  Richest/Leanest/Most Refused), Burden's own readout, whether the
  meta-stats line (`Swiftness: X  Gleam: Y  Bearing: Z`) still makes
  sense given how much Bearing/Gleam's roles have shifted.

## Later

Blue-sky, no limits, anything that fits the game's essence/fun even if
it's a long way off or half-formed — carried over from IDEAS.md's own
Later bucket verbatim. No in-scope/out-of-scope required here; that gets
written once something's ready to move up into Next.

- **Spend the hoard mid-run** *(working name: "the Altar")*. Loot is
  inert until death — the only way it leaves the bag is being
  auto-discarded. An altar that appears periodically in the arena and
  takes an offering (N of a tier) for a run-scoped boon would give the
  hoard an active outlet, add the in-run choice point the game has none
  of, and cost positioning to reach. Deckbuilder-shaped: your bag
  becomes a hand you can play, not a score you accumulate.

- **The hoard should be losable.** Death is currently the cash-out
  button — everything banks in full on death, quitting early banks
  nothing, so there is no way to lose a hoard and no reason not to die
  holding it. A voluntary exit that pays a bonus, a partial loss on
  death, or a small always-safe pocket (The Cycle's safe pockets, RoR2's
  Obliterate) would make "hoard vs. survive" actually bite instead of
  resolving to "hoard, then die." Big economy change and a genuine
  philosophy call — but this is the softest spot in the whole design.
  Sharpest lesson from genre precedent (Dredge's cargo-damage attrition,
  Incan Gold's per-round wipe, vs. DRG/Tarkov's clean binary loss):
  partial, repeated loss can be more agonizing than a single all-or-
  nothing moment — it keeps you gambling instead of letting you accept
  a stop/start point. Worth weighing against a single voluntary-exit
  mechanic before picking a shape.

- **A Legendary is a set piece, not a drop** *(no proper noun needed —
  it's a behavior on the existing Legendary tier, not new content)*. At
  0.5% base weight the top tier is effectively Boss-only, and when it
  finally appears it magnetizes in like everything else. Let it *not*
  magnetize: it lands, it glows, it pulls every enemy on screen toward
  it. The prize is bait. Turns the rarest thing in the game into an
  event you fight for rather than a free keypress, using nothing but
  positioning.

- **Phase 4: the arena becomes the antagonist** *(name already fits —
  continues the existing Phase 1/2/3 convention, no new term needed)*.
  Nothing new happens after the Boss at 55s — past that it's the same
  featureless 1280x720 box with bigger numbers. The arena is completely
  inert, which is a lot to leave on the table in a game where
  positioning is half the pitch. A late phase where the space itself
  turns hostile (closing in, going dark, drops landing only where you
  don't want to go) would give long runs a reason to exist beyond stat
  scaling.

- **A hoard you can actually see** *(working name: "the Trophy Hall,"
  keeping "Sanctum" itself free for the shop screen it already names)*.
  The game is called Hoard Survivors and nothing is ever hoarded — loot
  converts to currency and vanishes. A room in the Sanctum that
  accumulates your best finds across every run, in the Grimoire's
  progressive-discovery spirit, would give the title something to point
  at and add a long-term pull that isn't another number going up.

- **Pacts are the endgame the caps already imply.** Every stat has a
  hard level cap by design, which means the trees genuinely *finish* —
  and there is currently nothing on the other side of that. Slay the
  Spire's answer is Ascension: once the collection stops growing, the
  difficulty ladder becomes the progression. If Burden (see Next above)
  is a real number, it can carry that weight — best-run records tracked
  *per Burden level*, heavier Pacts only offered once lighter ones have
  been cleared. Reframes Pacts from "a third category of thing to buy"
  into the layer that outlives the trees, which is a far better answer
  to "what is the Sanctum for at 100%" than more nodes would be.

- **Buy the right to carry more Pacts** *(working name: "Resolve")*.
  Hades 2's Grasp is a budget capping how many Arcana you can run at
  once, raised with a separate permanent currency — a permanent
  purchase whose entire payoff is per-run freedom. A Stardust node whose
  only job is raising how many Pacts stack would tie the two halves of
  the shop together so Pacts don't sit isolated on another screen. It
  also supplies the one thing a fully-maxable tree structurally can't:
  with hard caps and no exclusive branches, spending is only ever a
  tempo question, never an exclusivity one — a budget on simultaneous
  *use* is where the real decision lives (Hollow Knight's notches,
  Arcana's Grasp). Steal overcharm as the risk valve while you're there:
  let players exceed the budget for a flat penalty rather than
  hard-blocking them.

- **Buy odds, not numbers** *(working name: "the Forge," after Dead
  Cells' Legendary Forge)*. Every node in the shop raises a number. Dead
  Cells sells *probability* instead — you invest cells into the drop
  rate of each gear quality, gated so you can't invest in a rank until
  the previous is full, which is the same chain-gate this shop already
  uses everywhere. A node that shifts the rarity table toward the top
  tiers is the most on-theme upgrade a game called Hoard Survivors could
  possibly sell, and it's qualitatively a different *kind* of node from
  +2 Spellpower — which is what the tree is actually short of. Flagged
  honestly: this is real balance work on the rarity table (DESIGN.md
  already calls drop weights "a lever to pull later"), not a
  presentation change.

- **Every stat gets a second facet** *(working name: "Facets")*.
  DESIGN.md deliberately leaves the door open to mutually-exclusive
  branches and correctly notes they'd be a scope addition — new stat
  types, and real tension with "everything is eventually maxable."
  Hades' Mirror is the cheap version that dodges both: each upgrade has
  two faces, one that purely adds and one that trades something away,
  switched freely at any time for no cost. No new nodes, no new
  currency, no new cost curve, caps untouched — the same purchased
  levels just point at a different effect. The smallest possible thing
  that lets a maxed-out tree still express a build, and it reuses the
  game's own gem/facet language.

## Reference

- Headless unit-test runner: `Godot.exe --headless --path . -- --unit-test`
- Headless playtest harness: `Godot.exe --headless --path . -- --playtest
  [--playtest-runs=N] [--playtest-seed=stat_id:level,...]`
- See CLAUDE.md's Testing section for the full three-tier verification
  model this project uses (pure-logic unit tests, playtest-harness
  balance signal, windowed visual/feel checks).
