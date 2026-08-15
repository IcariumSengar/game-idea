# game-idea — Engineering Practices

A Godot 4 project. This file is the standing reference for how this repo is
worked on — check it before making structural or workflow decisions.

## Versioning & rollback

Full workflow lives in [VERSIONING.md](VERSIONING.md); the short version:

- Regular commits land straight on `main` (see "Workflow" below).
- A git tag (`v1`, `v2`, ...) is only cut at a real milestone — something
  stable you'd want to roll back to — not on every commit or every push.
- `VERSION` and [CHANGELOG.md](CHANGELOG.md) are updated together with each
  tag and mirror what the tag records.

## Workflow

- `main` is the stable trunk — `vN` tags are always cut here. Parallel
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

No automated test framework yet — the project is too early-stage to warrant
one. Before that changes, verify changes by running the game and checking
the specific behavior touched. Revisit this once there's real gameplay
logic worth regression-testing (e.g. via GUT or gdUnit4).
