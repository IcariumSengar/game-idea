# UI Design System & HUD Requirements

**Status:** Design locked, ready for implementation (post-v6)

**Purpose:** Single source of truth for all UI/HUD visual design and stats displays across Hoard Survivors.

---

## Overview

Three key UI elements need consistent visual treatment:

1. **In-Run Stats Overlay** — persistent HUD showing time, currencies, rates
2. **Death Summary Screen** — full-screen recap when player dies
3. **Skill Tree Tooltips** — hover info on skill nodes (extend existing system)

All three must use the same visual language, colors, typography, and component library.

---

## Part 1: In-Run Stats Overlay

### Purpose

Make the time → backpack currency connection *visible*. v6 balance has slow currency earning (0.05/sec); players must see this happening or progression feels invisible.

### Location

**Top-left corner** of screen during gameplay.

### Content

**Exactly three stats, stacked vertically:**

```
⏱️  01:23
💰 145
🎒 4.1  (+0.05/sec)
```

1. **Time** — Current run duration in MM:SS format
   - Icon: ⏱️
   - Text: White, primary stat size (24–28px)
   - Updates every frame

2. **Player Currency** — Total loot value collected this run
   - Icon: 💰
   - Text: Gold color (#FFD700), primary stat size (24–28px)
   - Updates when loot picked up

3. **Backpack Currency** — Total earned from time survived
   - Icon: 🎒
   - Text: Cyan color (#00D9FF), primary stat size (24–28px)
   - Decimal to 1 place (4.1, not 4)
   - Supporting text: "(+0.05/sec)" in small gray (12–14px)
   - Updates every 0.1 sec

### Styling

**Background:**
- Dark semi-transparent panel (#1a1a1a, 80% opacity)
- Small border: 1px, dark gray (#333333)
- Rounded corners: 4px

**Layout:**
- Padding: 12px inside panel
- Spacing: 8px between stat rows
- Each stat: icon (24–32px) + 4px gap + text (left-aligned)

**Typography:**
- Stat values: 24–28px, semi-bold, colored
- Labels: None (icons are self-explanatory)
- Supporting text: 12–14px, gray (#888888)

**Positioning:**
- Top-left: 16px from top, 16px from left
- Should not obstruct core gameplay area
- Z-index: High (always visible, even over game elements)

### Example Implementation

```
Panel (12px padding, semi-transparent)
├── Row 1: [⏱️] 01:23
│   (24px icon, 28px white text)
├── Spacer (8px)
├── Row 2: [💰] 145
│   (24px icon, 28px gold text)
├── Spacer (8px)
└── Row 3: [🎒] 4.1  (+0.05/sec)
    (24px icon, 28px cyan text)
    (12px gray supporting text)
```

### Updates

- **Time:** Every frame (tied to Arena._run_time)
- **Player Currency:** Every pickup (tied to MetaProgression.player_currency signal)
- **Backpack Currency:** Every 0.1 sec (to avoid flicker, even though it trickles)

### Optional: Toggle

- Player can hide overlay via settings (accessibility)
- Default: visible
- Hotkey: Could be K or similar (TBD)

---

## Part 2: Death Summary Screen

### Purpose

Celebrate the run and show clear feedback on currency earned. Make the time/currency relationship explicit: "I survived 87 seconds, earned 4.35 backpack currency" (87 × 0.05).

### Trigger

When `Player.died` signal fires → pause game, show death summary → wait for player to click → proceed to shop.

### Layout

**Full-screen centered panel, dark background.**

```
╔═══════════════════════════════════════════╗
║  RUN SUMMARY                              ║
╠═══════════════════════════════════════════╣
║                                           ║
║  ⏱️  Time Survived:         01:47          ║
║  📊 Difficulty Reached:     Phase 2        ║
║                                           ║
║  ──────────────────────────────────────── ║
║  REWARDS THIS RUN:                        ║
║                                           ║
║  💰 Player Currency:   ↑ 287              ║
║  🎒 Backpack Currency: ↑ 84               ║
║                                           ║
║  ──────────────────────────────────────── ║
║  LOOT COLLECTED:                          ║
║                                           ║
║  • Common      x42                        ║
║  • Uncommon    x18                        ║
║  • Rare        x5                         ║
║  • Epic        x1                         ║
║                                           ║
║  ──────────────────────────────────────── ║
║  RUN STATS:                               ║
║                                           ║
║  Max Backpack Fill:  70%                  ║
║  Enemies Killed:     342                  ║
║                                           ║
║  ──────────────────────────────────────── ║
║                                           ║
║  Highest Previous Run: 01:34 (Backpack)   ║
║                                           ║
║        [ CONTINUE TO SHOP ]               ║
║                                           ║
╚═══════════════════════════════════════════╝
```

### Content Breakdown

#### Header
- **Title:** "RUN SUMMARY" (header size, bold, white)

#### Section 1: Run Duration
```
⏱️  Time Survived:         01:47
📊 Difficulty Reached:     Phase 2
```
- Left-aligned labels (secondary size, white)
- Right-aligned values (primary size, white)
- Spacer row between sections

#### Section 2: Rewards (highlighted)
```
💰 Player Currency:   ↑ 287
🎒 Backpack Currency: ↑ 84
```
- Icons + labels (secondary size, white)
- Values in colored text (gold for player, cyan for backpack)
- Arrow prefix (↑) to emphasize gain
- This section should be visually prominent (slightly larger box or different background)

#### Section 3: Loot Breakdown
```
LOOT COLLECTED:
• Common      x42
• Uncommon    x18
• Rare        x5
• Epic        x1
```
- Rarity names in rarity colors (white for Common, green for Uncommon, blue for Rare, etc.)
- Counts right-aligned
- Only show rarities that were collected (no empty rows)

#### Section 4: Run Stats (optional but nice)
```
Max Backpack Fill: 70%
Enemies Killed:    342
```
- Secondary stats, muted gray text
- Less prominent than rewards

#### Section 5: Previous Best (subtle)
```
Highest Previous Run: 01:34 (Backpack)
```
- Small, gray text (doesn't clutter)
- Shows "best time" or "best backpack currency earned"
- Only show if this is not the first run

#### Action Button
```
[ CONTINUE TO SHOP ]
```
- Centered, gold/cyan border
- Clear label (not "OK" or "Next")
- Only one button (no confusion)

### Styling

**Panel:**
- Background: Dark (#2a2a2a)
- Border: 2px, dark gray (#444444)
- Padding: 20px inside
- Max-width: 500–600px (readable, not too wide)
- Centered on screen

**Header bar:**
- Background: Slightly darker (#1a1a1a)
- Text: White, large (28–32px), bold
- Bottom border: 2px gold (#FFD700)
- Padding: 16px

**Section dividers:**
- Light gray line (1px, #444444)
- Padding: 12px above/below

**Typography:**
- Labels: 16px, white, secondary size
- Values (time/currency): 24px, colored (white for time, gold/cyan for currency)
- Rarity names: 14px, rarity color
- Flavor text: 12px, gray (#888888)

**Animations (optional):**
- Currency numbers can animate up from 0 (satisfying feedback)
- Loot items can fade in with rarity flash
- Keep animations <500ms (snappy, not slow)

### Data Requirements

Panel must pull from:
- `Arena.get_run_time()` → MM:SS format
- `Arena._run_time` (in seconds) × 0.05 → backpack currency earned
- `Player.get_total_loot_value()` → player currency
- `Player.backpack` dict → loot breakdown by rarity
- `Arena.enemy_count` (cumulative killed)
- `Player.max_hp` / base + current HP → max backpack fill %
- `MetaProgression.get_best_run()` → previous best (if exists)

### Button Behavior

- Click "CONTINUE TO SHOP" → fade out death summary → load shop scene
- Must not allow skipping (can't press until animation complete)
- Spacebar or Enter as alternative (optional)

---

## Part 3: Skill Tree Tooltips

### Purpose

Extend existing tooltip system to match the overall visual design. Tooltips show upgrade info, cost, lock status, and flavor text.

### Trigger

Hover over any skill node in the tree.

### Content

**Tooltip panel appears near the mouse cursor.**

```
╔═════════════════════════════════╗
║ DAMAGE                          ║
╠═════════════════════════════════╣
║                                 ║
║ Level: 5 / 20                   ║
║ Cost: 75 💰  (Affordable)       ║
║                                 ║
║ Effect: +2 spell power/level    ║
║ Current: 30 → 32                ║
║                                 ║
║ ───────────────────────────────  ║
║                                 ║
║ Increases spell power across    ║
║ all spells.                     ║
║                                 ║
╚═════════════════════════════════╝
```

### Content Breakdown

#### Header
- **Upgrade name** (18px, bold, white)
- Top border: Gold (#FFD700) if player-tree, Cyan (#00D9FF) if backpack-tree

#### Info Section
```
Level: 5 / 20
Cost: 75 💰  (Affordable)
```
- Left-aligned labels (14px, white)
- Status indicator (color-coded):
  - **Green "✓ Affordable"** if player has enough currency
  - **Gray "Need X more"** if not enough (show shortfall)
  - **Green "MAX"** if upgrade is maxed
  - **Red "LOCKED"** if gated (show requirement)

#### Effect Section
```
Effect: +2 spell power/level
Current: 30 → 32
```
- Description of what the upgrade does (14px, white)
- Before/after notation: "30 → 32" (shows immediate impact)

#### Divider
- 1px gray line (#444444)

#### Flavor Section
```
"Increases spell power across
all spells."
```
- Small (12px), muted gray (#888888)
- Wraps to 2–3 lines
- Explains *why* the upgrade matters (not technical details)

### Styling

**Panel:**
- Background: Dark (#2a2a2a)
- Border: 2px (color-coded: gold for player tree, cyan for backpack tree)
- Border-radius: 4px
- Padding: 12px
- Box-shadow: Subtle (optional, helps it pop)
- Width: Fixed 280–320px

**Positioning:**
- Follow cursor (or follow node, TBD)
- Offset: 8–12px from cursor/node
- Keep on-screen (don't clip at screen edges)
- Z-index: High (always visible)

**Header styling:**
- Padding: 8px bottom
- Border-bottom: 2px (matching border color)
- Font: 18px, bold, white

**Variants:**

**Locked Node:**
```
╔═════════════════════════════════╗
║ INFERNO BLADE                   ║ ← Orange if fire-themed
╠═════════════════════════════════╣
║                                 ║
║ [LOCKED] 🔒                      ║ ← Red, clear lock indicator
║                                 ║
║ Requirement: Spell Unlock L1    ║ ← Show how to unlock
║ (You have: Spell Unlock L0)     ║
║                                 ║
║ ───────────────────────────────  ║
║                                 ║
║ Melee flame magic with burn     ║ ← Flavor still visible
║ damage over time.               ║
║                                 ║
╚═════════════════════════════════╝
```

**Maxed Node:**
```
╔═════════════════════════════════╗
║ DAMAGE                          ║
╠═════════════════════════════════╣
║                                 ║
║ Level: 20 / 20  [✓ MAXED]       ║ ← Green indicator
║ Cost: — (no cost)               ║
║                                 ║
║ Effect: +2 spell power/level    ║
║ Final Power: 60                 ║
║                                 ║
╚═════════════════════════════════╝
```

### Updates

- Tooltip content updates in real-time (if player gains currency, "Affordable" status changes)
- No flicker (tooltip stays stable on hover)
- Disappears when mouse leaves node (fade out over 100ms)

---

## Part 4: Visual System (Shared Across All UI)

### Color Palette

| Element | Color | Hex | Use |
|---------|-------|-----|-----|
| Player Currency | Gold | #FFD700 | Currency amounts, player tree borders |
| Backpack Currency | Cyan | #00D9FF | Currency amounts, backpack tree borders |
| Time | White | #FFFFFF | Time display, neutral stats |
| Common Rarity | White | #EEEEEE | Common items, lowest rarity |
| Uncommon Rarity | Green | #4CAF50 | Uncommon items |
| Rare Rarity | Blue | #2196F3 | Rare items |
| Epic Rarity | Purple | #9C27B0 | Epic items |
| Mythic Rarity | Orange | #FF9800 | Mythic items |
| Legendary Rarity | Red | #F44336 | Legendary items |
| Text Primary | White | #FFFFFF | Main text |
| Text Secondary | Gray | #999999 | Labels, supporting |
| Text Muted | Gray | #666666 | Flavor text, small notes |
| Background Dark | Gray | #1a1a1a | Panel backgrounds |
| Background Lighter | Gray | #2a2a2a | Content areas |
| Border Dark | Gray | #333333 | Subtle borders |
| Border Medium | Gray | #444444 | Section dividers |
| Positive/Gain | Green | #4CAF50 | "Affordable", progress |
| Negative/Locked | Red | #F44336 | Locked, cannot afford |

### Typography

| Category | Size | Weight | Color | Use |
|----------|------|--------|-------|-----|
| Header | 28–32px | Bold | White | Panel titles, section headers |
| Primary Stat | 24–28px | Semi-bold | Colored | Currency, time, key numbers |
| Secondary Stat | 16–20px | Regular | White | Labels, descriptions |
| Tertiary | 12–14px | Regular | Gray | Flavor text, rates, small notes |

### Components (Reusable)

**Stat Row:**
```
[ICON] LABEL
       VALUE (supporting text)
```
- Icon (24–32px) + gap (4px) + label/value
- Padding: 8–12px
- Gap between rows: 8px

**Panel:**
```
Header (gold/cyan bottom border)
─────────────────────────────
Content (12–16px padding)
```

**Divider:**
```
1px gray line (#444444)
Padding: 12px above/below
```

**Button:**
```
[ LABEL ]
- Gold or cyan border (2px)
- White text (16–18px)
- Padding: 12px horizontal, 8px vertical
- Rounded: 2–4px
```

### Spacing Standards

- **Padding inside panels:** 12–16px
- **Gap between rows:** 8px
- **Gap between sections:** 12px
- **Margin from edge:** 16px (for in-run overlay), 20px (for panels)
- **Icon-to-text gap:** 4px

### Formatting Standards

- **Numbers:** Use commas for thousands (1,234 not 1234)
- **Time:** Always MM:SS format (01:23, not 1:23)
- **Decimals:** 1 decimal place for slow rates (0.05/sec, 4.1)
- **Before/After:** Use arrow (30 → 32) or + notation (+2)
- **Currency icons:** Always follow value ($, 💰, 🎒)

### Accessibility

- **Contrast:** All text must meet WCAG AA (4.5:1 contrast ratio)
- **Color blind:** Don't rely on color alone; use icons + labels
- **Size:** No text smaller than 12px
- **Motion:** Optional animations (no flashing, can toggle off)
- **Readability:** Dark backgrounds, light text (no light backgrounds)

---

## Implementation Checklist

### Stats Overlay
- [ ] Panel with semi-transparent background, dark border
- [ ] Three stat rows: Time (white), Player Currency (gold), Backpack Currency (cyan)
- [ ] Icons: ⏱️, 💰, 🎒 (emoji or custom sprites)
- [ ] Time updates every frame (MM:SS)
- [ ] Player currency updates on pickup
- [ ] Backpack currency shows as decimal, updates ~10x/sec
- [ ] Supporting text: "(+0.05/sec)" in small gray
- [ ] Position: Top-left, 16px from edges
- [ ] Z-index: High (always visible)
- [ ] Optional: Toggle via settings/hotkey

### Death Summary
- [ ] Full-screen dark panel, centered
- [ ] Header: "RUN SUMMARY" with gold underline
- [ ] Section 1: Time + Difficulty Phase (MM:SS, Phase X/3)
- [ ] Section 2: Rewards (highlighted, gold + cyan text)
- [ ] Section 3: Loot breakdown (rarity color-coded)
- [ ] Section 4: Run stats (max fill %, enemies killed)
- [ ] Section 5: Previous best (if exists)
- [ ] Button: "CONTINUE TO SHOP" (one button only)
- [ ] Appear on Player.died signal
- [ ] Disappear on button click → proceed to shop
- [ ] Optional: Animate currency numbers up

### Skill Tree Tooltips
- [ ] Extend existing tooltip system (or create if doesn't exist)
- [ ] Content: Name, Level, Cost, Effect, Flavor
- [ ] Color-coded border: Gold (player tree), Cyan (backpack tree)
- [ ] Variants: Normal, Locked (show requirement), Maxed (show MAX label)
- [ ] Status indicators: Affordable (green), Need X more (red), Locked (red), Maxed (green)
- [ ] Position: Near cursor/node, stay on-screen
- [ ] Fade out on mouse leave
- [ ] Update in real-time if currency changes

### Visual System
- [ ] All colors defined in a shared palette (use theme/constants)
- [ ] Font sizes consistent across all UI (header/primary/secondary/tertiary)
- [ ] Padding/spacing standardized (12–16px panels, 8px between rows)
- [ ] Number formatting: commas, MM:SS, 1 decimal for rates
- [ ] Currency icons always shown (💰 for gold, 🎒 for cyan)
- [ ] Before/after notation consistent (30 → 32)
- [ ] All text readable: contrast ratio ≥4.5:1
- [ ] Dark backgrounds, light text (no light backgrounds)
- [ ] Icons/text color-coordinated (gold text + 💰, cyan text + 🎒)

---

## Questions for Implementation

1. Should currency numbers animate up in death summary? (Recommendation: yes, <500ms)
2. Should there be a hotkey to toggle stats overlay? (Recommendation: K for "Kurun stats" or similar)
3. Should death summary auto-advance after X seconds, or require click? (Recommendation: require click, more control)
4. Should previous best show "best time" or "best backpack currency"? (Recommendation: time, it's clearer)
5. Should loot breakdown in death summary be truncated if very long? (Recommendation: show all, but max 8 items visible with scroll)

---

## Future Polish (Post-Implementation)

- Animation: Currency count-up in death summary (satisfying feedback)
- Animation: Loot items fade in with rarity flash
- Settings: "Show rates" toggle (hide +0.05/sec if cluttered)
- Settings: "Screen shake" toggle (death summary emphasis)
- Themes: Light mode, high-contrast mode
- Accessibility: Dyslexia-friendly font option

---

## References

- [STATS_SCREEN_DESIGN.md](stats_screen_design.md) (detailed design rationale)
- [DESIGN.md — v6 Balance](DESIGN.md#v6-balance-locked-ready-for-implementation) (balance philosophy)
- [ROADMAP.md](ROADMAP.md) (when to implement)

