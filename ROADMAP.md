# Hoard Survivors — Development Roadmap

**One-page version roadmap.** Full details in [DESIGN.md](DESIGN.md).

---

## Current State

**Versioning switched to semantic versioning (`vMAJOR.MINOR.PATCH`) as of
this release** — see [VERSIONING.md](VERSIONING.md). The old whole-number
tags below (`v1`–`v8`) are kept as history, not renamed; `v0.1.0` is the
first tag under the new scheme, not a continuation of that numbering.

- **v0.1.0 (released):** Full Magic Spells system (8 spells, Spell
  Unlock L1–L7), Tier 4 Boss + Minion variants, distinct enemy sprites,
  Backpack Ability (Condense/Clear), loot affixes, a real Settings
  menu, a headless playtest harness, and a data-driven early-game
  rebalance — see CHANGELOG.md for the full list
- **v1–v8 (released, old numbering):** Core loop through post-v7 audit
  — see CHANGELOG.md

---

## Next Up

Nothing currently queued as "next" — the backlog items below are open
but not started, since both need a decision only the player can make:

- Cloud-sync backend (needs an actual hosting/service decision)
- Mutually-exclusive skill-tree branches (an already-open design
  question, tension with "everything is eventually maxable")

See TODO.md for the full follow-up list (visual/audio polish, playtest
verification items, etc.) and [DESIGN.md](DESIGN.md) for design details.

**For implementation tasks:** See [TODO.md](TODO.md)

---

## Key References

- **[DESIGN.md](DESIGN.md)** — Complete design spec (all decisions, mechanics, numbers, UI system)
- **[TODO.md](TODO.md)** — Implementation checklists per version
- **[CLAUDE.md](CLAUDE.md)** — Engineering practices
- **[TESTING.md](TESTING.md)** — Full testing framework: headless auto-playtest harness and non-intrusive screenshot/UI testing tooling
- **[VERSIONING.md](VERSIONING.md)** — Git workflow
- **[CHANGELOG.md](CHANGELOG.md)** — Release notes
- **[GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)** — Shipping guide (CI/CD)

---

## Name

**Hoard Survivors** — Collect (hoard) loot while surviving hordes of enemies. Backpack fills, max HP shrinks. Risk/reward every run.
