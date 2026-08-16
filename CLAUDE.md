# game-idea — Engineering Practices

A Godot 4 project. This file is the standing reference for how this repo is
worked on — check it before making structural or workflow decisions.

## Versioning & rollback

Full workflow lives in [VERSIONING.md](VERSIONING.md); the short version:

- Regular commits land straight on `main` (see "Workflow" below).
- Semantic versioning (`vMAJOR.MINOR.PATCH`) as of `v0.1.0` — MAJOR stays
  `0` until the game is a complete, shippable 1.0; MINOR is new
  player-facing content (a spell, enemy tier, mechanic); PATCH is fixes,
  balance tweaks, and polish. The old flat `v1`–`v8` milestone tags
  predate this scheme and are left as-is in history, not renamed.
- A tag is only cut at a real milestone — something stable you'd want to
  roll back to — not on every commit or every push. Cut one at the end of
  each content addition once it's playtested clean, rather than letting
  several land on `main` untagged in a row — that's what keeps rollback
  granular instead of theoretical.
- `VERSION` and [CHANGELOG.md](CHANGELOG.md) are updated together with each
  tag and mirror what the tag records.

## Workflow

- `main` is the stable trunk — version tags are always cut here. Parallel
  workstreams (e.g. separate chats working on different concerns at the
  same time) each get their own git worktree/branch via Claude Code's
  worktree feature, and merge into `main` at deliberate checkpoints, not
  continuously. When there's only one active workstream, committing
  straight to `main` is still fine.
- Keep commits small and working — each one should leave the project in a
  state that opens and runs without errors.
- Commit messages: short, present-tense summary line; explain *why* in the
  body only when it's not obvious from the diff.
- Purely editor-generated diffs (e.g. `project.godot` version/feature bumps
  from opening in a newer Godot build) are fine as their own plain commit —
  don't bundle them with real feature work, don't tag them as a version.
- Iteration loop: make a change, run the game to check it, close it, repeat.
  Prefer this tight loop over batching up many changes before checking any
  of them.
- Track backlog items in [TODO.md](TODO.md) once there's more to remember
  than fits in your head; record *what the game is* (mechanics, scope) in
  [DESIGN.md](DESIGN.md) as those decisions get made, not upfront.

## GDScript style

- **Static typing is required.** Type all variables, parameters, and return
  values (`var speed: float = 300.0`, `func move(delta: float) -> void`).
  Untyped/`var x = ...` is only acceptable for rapid throwaway prototyping
  that will be typed before it's committed.
  - Watch for builtins with a Variant-typed return (`clamp`, `lerp`, `min`,
    `max`, ...) — `var x := clamp(...)` fails to infer a type and errors
    out (warnings are treated as errors in this project). Give these an
    explicit type instead: `var x: float = clamp(...)`.
- Naming: `snake_case` for variables, functions, and signals; `PascalCase`
  for class names and node names; `SCREAMING_SNAKE_CASE` for constants.
- Prefer `@export` over hardcoded magic numbers for anything a designer
  (i.e. future you) might want to tune from the editor.
- One script per scene/node responsibility — avoid god-objects that own
  unrelated systems. Split into child nodes/scripts as behavior grows.
- Favor signals and a small autoload (singleton) for cross-scene state over
  deep node-path references (`$Parent/Other/Node`), which break silently
  when a scene gets restructured.
- Once there's repeated data to model (item types, level configs, enemy
  stats), define it as a custom `Resource` class rather than hardcoding it
  in scripts. Not worth doing before there's actually repeated data.
- Format with `gdformat` and check with `gdlint` (gdtoolkit) before
  committing — both are installed; run `gdformat scripts/*.gd` and
  `gdlint scripts/*.gd` (or point at whatever paths changed).
- Watch for duplicated lookups: if two or more scripts hand-roll the same
  "find this def/entry by id" loop, that logic belongs as a real method on
  the autoload that owns the data, not copy-pasted at each call site.
- Soft size ceiling, not a hard rule: a script pushing past ~400-500 lines,
  or a function past ~60, is a prompt to look for an extractable
  responsibility — check before reflexively adding more to it.
- Autoloads own data and logic (`MetaProgression`, `SaveManager`,
  `LootTypes`); scenes/
  nodes own presentation (`SkillTreeView`, `HUD`). Keep that direction
  one-way — presentation reads from autoloads, autoloads never reach into
  a specific scene's nodes.

## Project structure

```
project.godot       Godot project config
scenes/              .tscn scene files
scripts/             .gd scripts, filename matches the node/scene it drives
icon.svg             project icon
VERSION              current released version
CHANGELOG.md         release history
VERSIONING.md        full release/rollback workflow
TODO.md              short-term backlog
DESIGN.md            what the game is: core loop, scope, design decisions
```

Keep this pairing as the project grows: a scene's primary script lives in
`scripts/` under the same base name as the scene (`main.tscn` ↔ `main.gd`).
Once there are enough scenes to warrant it, introduce subfolders
(`scenes/ui/`, `scripts/player/`, etc.) rather than flattening everything
into the two top-level folders indefinitely.

## UI Screenshots & References

Implementation chats often save UI reference screenshots during work (to coordinate
changes, gather feedback). Keep these organized and temporary:

- **Location:** `screenshots/` folder (not committed to git)
- **Naming:** `YYYYMMDD_description.png` (e.g., `20260815_stats_overlay_v1.png`)
- **Cleanup:** Screenshots older than 7 days are auto-deleted via cleanup scripts
  - Windows: `screenshots/cleanup.bat`
  - macOS/Linux: `./screenshots/cleanup.sh`
- **Before shipping a version:** Run cleanup to clear old UI work

See `screenshots/README.md` for usage details. Screenshots stay out of git history
and don't clutter the repo.

## Dev environment

- VS Code extension: **Godot Tools** (`geequlim.godot-tools`) — GDScript
  syntax/debugging/go-to-definition. `.vscode/settings.json` points it at
  the local Godot install and the default LSP port (6005); the extension
  connects whenever the Godot editor is open in the background.
- **gdformat** / **gdlint** (`gdtoolkit`) — formatter and linter enforcing
  the style rules above. Installed via `pip install gdtoolkit`.

## Testing

The project has real gameplay logic now (8 spells, 4 enemy tiers, a
two-currency upgrade economy) — past the point where "just run it and
check" is enough on its own. Three tiers, matched to what's actually being
verified; don't reach for a bigger one than the change needs:

- **Balance/gameplay behavior** (enemy stats, drop rates, cost curves,
  anything about how a full run plays out) — the headless auto-playtest
  harness (`scripts/playtest_harness.gd` + `scripts/playtest_bot_ai.gd`).
  A reactive bot plays full runs back to back with no window and no
  manual input, sandboxed to its own save slot
  (`MetaProgression.PLAYTEST_SLOT` — never touches real save data), and
  prints a per-run + aggregate survival/economy report.

  ```
  Godot.exe --headless --path . -- --playtest [--playtest-runs=N] \
      [--playtest-seed=stat_id:level,...]
  ```

  `--playtest-seed` pre-sets stat levels for the sandboxed run (e.g.
  `spell_unlock:2` to test with all spells unlocked) so a batch can target
  whatever progression point is under test without grinding a real save.

- **Pure logic** (cost curves, drop-weight math, stat formulas — anything
  that doesn't need the scene tree) — the headless unit-test runner
  (`scripts/unit_tests.gd`), same self-contained style as the playtest
  harness (no GUT/gdUnit4). Fast, direct assertions instead of a full
  playtest run standing in for what a five-line check should catch.

  ```
  Godot.exe --headless --path . -- --unit-test
  ```

  Exits non-zero on any failure. Add a case here whenever a new pure-math
  formula ships (a cost curve, a stat lerp) rather than only trusting the
  playtest harness to catch it indirectly.

- **Visual/UI/feel** — the one tier neither of the above can check. Needs
  an actual windowed launch. Check `tools/` (and `TESTING.md`, if present)
  for existing window-capture/interaction scripts before hand-rolling a
  new one — capturing a GPU-rendered window without stealing focus,
  correctly under this environment's DPI scaling, has already been solved
  here once; re-deriving it from scratch burns real turns for no reason.

## AI session discipline

This project is iterated on almost entirely through AI coding sessions,
often several in parallel (see Workflow above). Token budget is a real,
capped constraint here, not a nicety — these rules exist to keep sessions
cheap and the feedback loop tight.

- **Match verification effort to the change**, using the Testing tiers
  above literally: a pure-logic change gets a headless check, a balance
  change gets a playtest harness batch, and only a visual/UI change earns
  a full windowed launch plus screenshot. Don't launch the game to confirm
  a one-line formula fix.
- **Batch, then verify — not verify-per-edit.** "Make a change, run the
  game, repeat" (Workflow above) means per coherent unit of work, not per
  line touched. Group related edits before checking any of them.
- **Read narrow, not wide.** Grep for the section or symbol you need
  instead of reading a whole file; use offset/limit on large ones.
  DESIGN.md in particular is 1000+ lines and growing — grep for the
  relevant heading rather than re-reading it end to end, unless you're
  doing a genuine full-doc audit.
- **Keep DESIGN.md's decision-log entries factual and short.** That log is
  read by every future session touching related work — a bloated entry is
  a tax paid repeatedly, not once. State what changed, why, and any real
  gotcha; skip the play-by-play.
- **Archive DESIGN.md before it grows unbounded.** Once it's pushing
  1500+ lines, move dated log entries older than the last couple of
  shipped MINOR versions into a `DESIGN_HISTORY.md`, keeping DESIGN.md
  itself focused on current decisions. Git already preserves full history;
  the file doesn't need to.
- **Don't spawn a subagent for a targeted lookup.** A well-scoped Grep or
  a couple of Read calls is cheaper than a fresh agent re-deriving context
  from zero. Reserve subagents/Explore for genuinely broad, multi-file
  investigations.
- **Check for existing tooling before building your own.** Before
  hand-rolling a window-capture script or any other dev tool, check
  `tools/` and this file for one that already exists.
- **On picking up a task, orient from git before re-reading files.**
  `git log --oneline -20` and `git status` first; read files only for the
  specific area you're about to touch, not speculatively.
