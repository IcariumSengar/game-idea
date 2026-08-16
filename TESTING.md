# Testing

No external unit-test framework (see CLAUDE.md's Testing section for why
-- deliberately dependency-free). What this project *does* have, built up
over the course of development, is three complementary tools for
verifying changes without a human sitting at the keyboard for every
check: a headless pure-logic unit-test runner, a headless auto-playtest
harness for gameplay/balance, and a non-intrusive screenshot tool for
UI/visuals. This doc is the full reference for all three.

**Baseline, before any of these:** `gdformat`/`gdlint` on whatever
scripts changed, and a plain headless boot check:

```
gdformat scripts/*.gd
gdlint scripts/*.gd
Godot.exe --headless --path . --quit
```

The boot check catches parse errors and missing-resource errors across
every autoload and the main scene. It does **not** catch errors in a
scene that isn't the current `run/main_scene` — see "Verifying a specific
scene loads correctly" below for that.

---

## 1. Headless pure-logic unit tests

Self-contained assertion runner (no GUT/gdUnit4) for formulas that don't
need the scene tree at all -- cost curves, stat lerps, drop-weight math.
Catches a broken formula in seconds instead of relying on a full playtest
batch to surface it indirectly.

### Running it

```
Godot.exe --headless --path . -- --unit-test
```

Prints PASS/FAIL per case and a final tally, exits non-zero if anything
failed -- scriptable in CI as well as ad hoc.

### What it covers

- `MetaProgression`'s cost curve (`get_cost`) and stat curve (`get_stat`)
  against each registered `StatDef`'s own fields, not hardcoded balance
  numbers -- stays valid across balance passes instead of needing updates
  every time a number gets retuned.
- `is_maxed()` / level-cap behavior, and `buy_upgrade()`'s funding checks,
  currency-pool routing, and refusal once maxed.
- `LootTypes.pick_random_weighted()` (empty-weights fallback, single-tier
  and restricted-tier rolls) and `get_effective_stack_size()` (Compactor
  scaling, Legendary's permanent stack-size-1 exemption).
- `player.gd`'s backpack-fill HP/speed lerp, driven through the real
  `collect_loot()`/`consume_loot()` public API on an isolated `Player`
  instance rather than reaching into the private lerp directly.

### Save isolation

Same sandboxing as the playtest harness: `save_manager.gd`'s
`_playtest_mode` triggers on `--unit-test` too, so `current_slot` becomes
`PLAYTEST_SLOT` and `save()` no-ops. Never reads or writes the player's
real save files. Safe to run anytime without asking.

### Files

- `scripts/unit_tests.gd` (autoload `UnitTests`) -- all test cases live
  here as one script; add a new `_test_*()` function and call it from
  `_ready()` rather than reaching for a framework.

---

## 2. Headless auto-playtest harness

A reactive bot plays full runs back to back with no window and no manual
input, then prints a per-run and aggregate survival/economy report.
Built for gathering balance signal without manual play, and for smoke-
testing gameplay changes (spells, enemies, economy) for runtime errors
across many runs and RNG seeds fast.

### Running it

```
Godot.exe --headless --path . -- --playtest [--playtest-runs=N] \
    [--playtest-seed=stat_id:level,...]
```

- `--playtest-runs=N` — how many runs in the batch (default 15).
- `--playtest-seed=` — comma-separated `stat_id:level` pairs, applied
  once before the batch starts. Use this to test a specific progression
  point without grinding a save — e.g. `spell_unlock:7` to test with
  every spell unlocked, or `damage:10,move_speed:4` to simulate a
  several-runs-in player. Stat IDs match `MetaProgression`'s `STAT_*`
  constants (e.g. `backpack_capacity`, `arcane_haste`).
- Runs at `Engine.time_scale = 8` (see `playtest_harness.gd`) so a batch
  of 10-20 runs typically finishes in under a minute of real time.
  Camera juice (screen shake/hit-stop) is skipped in playtest mode since
  it fights the speedup by repeatedly resetting time_scale to 1.0.

### What it's good for

- **Regression smoke-testing:** after any gameplay change, run a batch
  and confirm zero runtime errors. This has caught real bugs before they
  shipped — e.g. a physics-server "flushing queries" error that only
  showed up when an AOE spell killed multiple enemies in the same
  frame, rare enough in normal single-target play to go unnoticed.
- **Balance signal:** compare aggregate survival/kills/loot-value
  across seed levels or before/after a numeric tweak. This is *relative*
  signal (bot vs. bot), not a substitute for a human's sense of "does
  this feel right" — the bot doesn't reposition/plan the way a real
  player does, so treat its numbers as a floor, not the full picture.
- **Reaching content that's hard to hit manually:** e.g. verifying the
  Tier 4 Boss's code path without playing for 55+ real seconds --
  temporarily lower `Arena.BOSS_SPAWN_TIME` for one test run, confirm
  clean, then revert. (General technique: when a batch can't naturally
  reach the thing you want to test, temporarily lower the threshold
  that gates it rather than trying to force a bot to be more skilled.)

### What it can't tell you

- Visual/audio feel (does the UI look right, do overlapping spell
  effects read as clutter) -- there's no video or audio output from a
  headless run. That's what part 2 of this doc is for.
- Whether the difficulty *feels* fair to a human -- the bot is a
  simplistic, consistent, non-learning player. Useful as a floor and for
  A/B comparison, not as a verdict.

### Save isolation

Sandboxed to `SaveManager.PLAYTEST_SLOT` (99), outside the normal
0-3 slot range the Load Game screen manages. `--playtest-seed` writes
directly into that sandbox's in-memory stat levels
(`MetaProgression.debug_set_level()`, bypassing currency cost -- it's
not a real purchase). Never reads or writes the player's real save
files. Safe to run anytime without asking.

### Files

- `scripts/playtest_harness.gd` (autoload `PlaytestHarness`) --
  orchestrates the run loop, applies seeds, prints the report.
- `scripts/playtest_bot_ai.gd` -- the reactive movement AI (flees
  danger, avoids walls, panic-dashes). Spells auto-cast on their own
  (v10+), so this only ever drives movement/dash.

### A pattern worth reusing: verifying a specific scene loads correctly

The plain headless boot check only instantiates whatever
`run/main_scene` currently points at, so it won't catch a broken
`%unique_name` reference or a bad node path in a scene that isn't the
main one (e.g. `shop.tscn`, `run_prep.tscn`). To check one directly:

```
# temporarily point main_scene at the scene under test
Godot.exe --headless --path . --quit
# revert project.godot's run/main_scene back afterward
```

Edit `project.godot`'s `run/main_scene` line, run the boot check, revert
the line. A few seconds, catches a whole class of "works in the editor,
breaks at runtime" bugs that pure static analysis misses.

---

## 3. Visual/screenshot testing

For anything the playtest harness structurally can't answer: does the
UI actually look right, is text clipped, does a layout change render as
intended. `tools/` has three PowerShell scripts for this.

### The constraint these exist to satisfy

**Never launch, screenshot, or click into the game window without being
asked, and never do it in a way that steals window focus or pops the
window on top of whatever the user is doing.** This was an explicit,
strongly-worded correction earlier in development (repeated focus-
stealing during automated screenshot loops interrupted the user's other
work) and is a hard constraint, not a style preference. Concretely:

- `screenshot.ps1` never brings the window to the foreground -- safe to
  use whenever a passive visual check is warranted.
- `click_foreground.ps1` *does* briefly foreground the window (that's
  the only way found so far to get a click to actually register --
  see below). Only run it when the user has explicitly asked for
  interactive UI testing, never proactively, and say what's about to
  happen first ("clicking through to the shop to check the new tab
  layout") the same way you'd announce launching the game at all.
- Always say what's opening/closing and what you're checking for, even
  for the non-intrusive screenshot-only path -- the user can't see tool
  calls, only your messages.

### screenshot.ps1

Captures the game window's contents via the Win32 `PrintWindow` API
directly, instead of the more common "bring window to front, grab the
screen region under it" approach -- which is exactly the technique that
caused the original complaint, since it requires the window to be
foregrounded.

```
.\tools\screenshot.ps1 [-OutFile <path>] [-ProcessName <name>]
```

Defaults to `screenshots/<timestamp>.png` and the project's Godot
binary name. Read the resulting PNG directly (the Read tool renders
images) to actually look at it.

**Two real bugs found getting this working, worth knowing about if this
ever needs touching again:**

1. `PrintWindow` needs the `PW_CLIENTONLY` flag (`0x1`) to match a
   client-area-sized bitmap. Without it, `PrintWindow` draws the
   *entire* window (title bar included) starting from the bitmap's
   origin -- so a client-sized target only ever captures the title bar
   plus a thin sliver of content, with the rest clipped off. (Combined
   with `PW_RENDERFULLCONTENT`, `0x2`, which is separately required to
   capture GPU-rendered/OpenGL content at all -- without it you get a
   blank bitmap.)
2. A DPI-unaware caller gets `GetClientRect`/`PrintWindow` results
   scaled down by the display's DPI factor. A real 1280x720 window read
   back as 426x240 at 300% Windows display scaling until
   `SetProcessDPIAware()` was called first. If a capture comes back an
   oddly "round" fraction of the expected size, this is almost
   certainly why.

### click_at.ps1 (background click -- unreliable, kept for reference)

Attempts a click via `PostMessage` (`WM_LBUTTONDOWN`/`UP`) sent directly
to the window handle, which -- in theory -- doesn't require the window
to have focus. **In practice this did not reliably register with
Godot's input handling** (Godot's `DisplayServer` appears to only
process mouse input while the window has real OS input focus,
regardless of whether a message was delivered to it). Kept in the repo
in case a future Godot/Windows combination behaves differently, but
verify with a before/after screenshot before trusting it -- don't
assume it worked just because the script didn't error.

### click_foreground.ps1 (proven working)

```
.\tools\click_foreground.ps1 -X <client-x> -Y <client-y>
```

Real OS input: `SetForegroundWindow` + `SetCursorPos` + `mouse_event`.
Coordinates are client-area pixels at the window's actual size (i.e.
the same coordinate space `screenshot.ps1`'s output image uses -- take
a screenshot first, read it, and eyeball the pixel coordinates of
whatever you want to click).

Uses `ClientToScreen` to convert client coordinates to real screen
coordinates, rather than guessing at title-bar/border height -- that
guess (assuming a fixed ~39px title bar) is what cost the most
iteration time when this was first built, since it silently clicked
the wrong element a full button-height off target instead of erroring.

### Typical workflow

```
# 1. Launch (per the /play skill's launch pattern)
Godot.exe --path . --rendering-driver opengl3 &

# 2. Look
.\tools\screenshot.ps1 -OutFile screenshots\20260101_check.png
# (Read the PNG)

# 3. Interact, only if the user asked for interactive testing
.\tools\click_foreground.ps1 -X 639 -Y 595
.\tools\screenshot.ps1 -OutFile screenshots\20260101_after_click.png
# (Read the PNG, compare)

# 4. Close when done
Stop-Process -Name "Godot_v4.7.1-stable_win64" -Force
```

`screenshots/` is gitignored (see its own `.gitignore`) -- it's scratch
space for a session, not permanent reference material. Clean up
temporary captures when done (`rm screenshots/*.png` or
`screenshots/cleanup.bat`/`.sh` for anything older than 7 days).
