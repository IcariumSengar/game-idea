# Hoard Survivors — Development Roadmap

**One-page version roadmap.** Full details in [DESIGN.md](DESIGN.md).

---

## Current State

- **v4 (released):** Core loop playable end-to-end
- **v5 (released):** Polish & juice (UI/audio/animations)
- **v6 (released):** Balance rebalance + HUD/UI system (stats overlay,
  death summary, skill tree tooltips)
- **v7 (released):** Enemy types — Bruiser (charge) and Elite
  (projectile), phase-gated spawn mix, per-tier loot weighting
- **v8 (released):** Post-v7 audit — difficulty-scale fix, save/load
  slot system fixes (see CHANGELOG.md)

---

## Next Versions

| Version | Focus | Status |
|---------|-------|--------|
| **v9** | Magic spells | Built, pending release tag |
| **v10** | Multi-spell casting (all unlocked spells fire at once) | Built, pending release tag |
| **v11** | Additional spells (Meteor Strike, Lightning Chain, Time Warp, Teleport Pulse, Summon Familiar) | Built, pending release tag |
| — | Tier 4 Boss, Fast/Tanky Minion variants, distinct enemy sprites, Settings menu, loot affixes, backpack ghost-slot preview, headless playtest harness | Built alongside v11, pending release tag |

Cloud-sync backend and mutually-exclusive skill-tree branches are open items, not yet started — see TODO.md/DESIGN.md for why (both need a decision only the player can make).

**For details on each version:** See [DESIGN.md](DESIGN.md)

**For implementation tasks:** See [TODO.md](TODO.md)

---

## Key References

- **[DESIGN.md](DESIGN.md)** — Complete design spec (all decisions, mechanics, numbers, UI system)
- **[TODO.md](TODO.md)** — Implementation checklists per version
- **[CLAUDE.md](CLAUDE.md)** — Engineering practices
- **[VERSIONING.md](VERSIONING.md)** — Git workflow
- **[CHANGELOG.md](CHANGELOG.md)** — Release notes
- **[GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)** — Shipping guide (CI/CD)

---

## Name

**Hoard Survivors** — Collect (hoard) loot while surviving hordes of enemies. Backpack fills, max HP shrinks. Risk/reward every run.
