# Game Text Flavor Spec (Hoard Survivors)

## Status

**Adopted 2026-08-15.** The stat and Compacting-tier renames from the
Summary Recommendations table below are implemented in
`scripts/meta_progression.gd` and `scripts/skill_tree_view.gd`: Damage →
Spellpower, Move Speed → Swiftness, Magnet Range → Gleam, Backpack
Capacity → Bearing, Purge → Discard, and the five Compacting tiers →
Commons Hoard / Uncommon Stash / Rare Vault / Epic Trove / Mythic Hoard.
One deviation from this doc: Backpack Currency shipped as **Stardust**
(v5 naming pass, tied to the game's cosmic aesthetic) rather than the
"Endurance" suggested here. See DESIGN.md's decisions log for both
naming passes.

## Overview

This spec defines the voice, tone, and naming conventions for all in-game text: menus, stats, skills, UI copy, etc. Goal: consistent personality that reinforces the core loop (hoarding loot, surviving, getting stronger).

---

## Core Tone Options

### Option A: Mystical & Determined
- **Voice:** Arcane, but grounded. The magic user is competent and focused.
- **Vibe:** "I know what I'm doing. The magic is mine to command."
- **Examples:** "Gather more power," "Your reserves deepen," "The spell strengthens"
- **Best for:** Fantasy-forward, player feels in control

### Option B: Dark & Desperate
- **Voice:** Gritty survival. Hoarding is a matter of necessity.
- **Vibe:** "Collect or perish. Every moment of survival buys power."
- **Examples:** "Desperation breeds strength," "You've weathered the storm," "Hunger for more"
- **Best for:** Roguelike intensity, player feels tested

### Option C: Minimalist & Clean
- **Voice:** Direct, no-frills. Just the facts.
- **Vibe:** "Here's what you earned. Here's what you can buy."
- **Examples:** "Spell Power +2," "10 common items collected," "Next upgrade cost: 75"
- **Best for:** Clarity-first, player focuses on numbers

### Option D: Playful & Greedy
- **Voice:** Wink-nudge tone. Hoarding is fun, accumulation is the goal.
- **Vibe:** "More is always better. Collect everything."
- **Examples:** "Bag getting plump," "Greed fuels your power," "One more thing..."
- **Best for:** Lighter feel, player enjoys the hoarding loop

---

## Recommendation: Blend A + B

**Primary tone:** Mystical & Determined (Option A)
**Secondary tone:** Dark & Desperate (Option B)

This gives personality without veering into comedy, reinforces both the magic and survival themes, and suits the meta-progression loop (survive → gather → empower → repeat).

---

## Naming Conventions

### Currency Names

**Current:** "Player Currency" / "Backpack Currency" (placeholder)

**Option A (Mystical):**
- Player Currency → **"Essence"** (loot distilled into pure power)
- Backpack Currency → **"Endurance"** (earned through survival)

**Option B (Dark):**
- Player Currency → **"Spoils"** (what you took from enemies)
- Backpack Currency → **"Grit"** (you survived this long)

**Option C (Minimal):**
- Keep as-is or use short codes: "Loot" / "Time"

**Recommendation:** Go with Option A (Essence / Endurance)
- Mystical flavor reinforces magic theme
- Suggests accumulation and earning (not just generic "gold")
- "Essence" feels like condensed power, "Endurance" like earned durability

### Stat Names

**Current:** Damage, Move Speed, Magnet Range, Backpack Capacity

**Mystical Layer:**
- Damage → **"Spellpower"** (already used)
- Move Speed → **"Swiftness"** or **"Mobility"** (more fantasy)
- Magnet Range → **"Gleam"** or **"Radius"** (attraction distance; "gleam" sounds mystical)
- Backpack Capacity → **"Bearing"** or **"Capacity"** (how much you can bear/carry)

**Example upgrade tree:**
```
Spellpower       (primary damage scale)
Swiftness        (dodge speed)
Gleam            (loot attraction range)
Bearing          (slot capacity)
```

**Compacting (per tier):**
- Current: "Compactor: Common"
- Option: **"Commons Hoard"**, **"Uncommon Stash"**, **"Rares Vault"**
  - More evocative than "Compactor"
  - Reinforces hoarding theme
  - "Hoard/Stash/Vault" escalates with rarity

**Purge:**
- Current: "Purge"
- Option: **"Discard"** or **"Jettison"** (clearer) or **"Unbind"** (more mystical)

**Recommendation:**
- Spellpower (keep as-is)
- Swiftness (more fantasy than Speed)
- Gleam (loot attraction; mystical)
- Bearing (capacity; implies carrying weight)
- Per-tier Compacting: Commons Hoard → Uncommon Stash → Rare Vault → Epic Trove → Mythic Hoard (or "Pinnacle Hoard")
- Purge → **"Discard"** (clear and neutral)

### Spell Names

**Current:** Arcane Bolt, Inferno Blade, Frost Nova

**These are good.** Keep as-is. They're clear, evocative, and match the magic user fantasy.

**Optional upgrades within trees:**
- Arcane Bolt
  - Haste → **"Quicken"**
  - Projectile Speed → **"Velocity"** or **"Swiftness"**

- Inferno Blade
  - Fury → **"Ferocity"** or **"Rage"**
  - Arc Width → **"Arc"** or **"Sweep"**
  - Burn Damage → **"Pyre"** or **"Scorch"**

- Frost Nova
  - Frequency → **"Cadence"** or **"Pulse Rate"**
  - Radius → **"Radius"** (keep simple)
  - Slow Strength → **"Glaciate"** or **"Freeze Depth"**

### Enemy Names

**Current:** Minion, Bruiser, Elite

**Mystical alternatives:**
- Minion → **"Thrall"** (summoned/enchanted creature)
- Bruiser → **"Colossus"** or **"Brute"** (keep Bruiser, it works)
- Elite → **"Sorcerer"** or **"Caster"** (reinforces magic theme)

**Recommendation:** Keep current names. They're clear and not placeholder-y.

---

## UI Copy (Menu & Screens)

### Main Menu

**Current placeholder:** "Start Game" / "Load Game" / "Settings"

**Mystical tone:**
```
╔═══════════════════════╗
║  HOARD SURVIVORS      ║
╠═══════════════════════╣
║  [ Begin Ascent ]     ║  (start new run)
║  [ Restore Path ]     ║  (load game)
║  [ Attunement ]       ║  (settings)
║  [ Grimoire ]         ║  (help/guide)
╚═══════════════════════╝
```

**Recommendation:** Use clearer names, but with slight flavor.
```
[ New Game ]
[ Continue ]
[ Settings ]
[ Guide ]
```

Or slight mystical flavor:
```
[ Begin the Hunt ]
[ Resume ]
[ Attune ]
[ Grimoire ]
```

### Shop Screen

**Current:** "Shop" or flat list of upgrades

**Mystical frame:**
```
═══════════════════════════════════
  ARSENAL OF THE ARCANE
═══════════════════════════════════
```

or

```
═══════════════════════════════════
  THE SHOP
═══════════════════════════════════
(simple, direct)
```

### Death Summary

**Current:** "Run Summary"

**Mystical flavor:**
```
═══════════════════════════════════
  YOUR ASCENT
═══════════════════════════════════
You survived 01:47 and reached Phase 2.
[rewards breakdown]

Highest previous attempt: 01:34
```

or stay simple:
```
═══════════════════════════════════
  RUN SUMMARY
═══════════════════════════════════
```

### Run Victory / Continue

**Current:** "Continue to Shop"

**Options:**
- "Continue to Shop" (clear, keep)
- "Proceed to Armory" (flavor)
- "Return to Haven" (flavor)

**Recommendation:** Keep "Continue to Shop" for clarity. No unnecessary flavor here.

---

## Upgrade Purchase UI

**When hovering a skill node:**

Current flavor:
```
DAMAGE
Level: 5 / 20
Cost: 75 Essence
Effect: +2 Spellpower
Current: 30 → 32
"Increases spell power across all spells."
```

Slightly more flavor:
```
SPELLPOWER
Level: 5 / 20
Cost: 75 Essence
Effect: +2 spell potency
Current: 30 → 32
"Your spells strike with greater force."
```

or minimize:
```
SPELLPOWER
Level 5/20 | Cost: 75 Essence
+2 potency (30 → 32)
Increases spell power across all spells.
```

**Recommendation:** Middle ground. Keep flavor light, prioritize clarity.

---

## Flavor Text (Fluff)

**Small text descriptions on upgrades/items:**

**Example: Spellpower upgrade**
- Minimal: "Increases spell damage"
- With flavor: "Your spells crackle with arcane power"
- Dark flavor: "The more you cast, the stronger you become. Desperation breeds might."

**Example: Swiftness upgrade**
- Minimal: "Increases movement speed"
- With flavor: "Swift feet carry you through the storm"
- Dark flavor: "Slow runners perish. Move, or fall."

**Recommendation:** Add one-line flavor text to upgrades, keeping it brief and supporting the tone.

---

## Summary Recommendations

| Element | Recommendation | Tone |
|---------|---|---|
| Essence | Player Currency name | Mystical |
| Endurance | Backpack Currency name | Mystical |
| Spellpower | Damage stat (keep) | Mystical |
| Swiftness | Speed stat | Mystical |
| Gleam | Magnet Range stat | Mystical |
| Bearing | Capacity stat | Mystical |
| Commons Hoard / Uncommon Stash / Rare Vault / Epic Trove / Mythic Hoard | Compacting tier names | Mystical + Thematic |
| Discard | Purge upgrade name | Neutral |
| Keep spell names | Arcane Bolt, Inferno Blade, Frost Nova | Already good |
| Simple UI labels | "New Game", "Continue", "Settings" | Clear |
| Light flavor text | One-liners on upgrades | Mystical + brief |
| Death summary | "Run Summary" (simple) | Direct |

---

## Open Questions

1. Should flavor text be mandatory (every upgrade) or minimal (just key ones)?
2. Should enemy names get mystical names, or keep current (Minion, Bruiser, Elite)?
3. Should menu labels have flavor ("Begin Ascent" vs "New Game"), or stay clear?
4. Should loot rarity names change? (Common → Fragment? Uncommon → Essence?)
5. Should there be a "Lore" or "Grimoire" accessible in-game explaining the world?

---

## Implementation Path

1. Decide overall tone: Mystical (recommended) or something else
2. Rename currencies: "Essence" / "Endurance"
3. Rename stats: "Spellpower" / "Swiftness" / "Gleam" / "Bearing"
4. Rename Compacting tiers: "Commons Hoard" → "Mythic Hoard"
5. Rename Purge: "Discard"
6. Add one-line flavor text to 3–5 key upgrades (test the vibe)
7. Keep menu labels simple and clear (no experimental names here)
