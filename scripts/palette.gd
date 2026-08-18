extends Node

## Central color registry for every procedural `_draw()` call, particle
## tint, and script-side `modulate` in the game. Built as re-skin prep
## (DESIGN.md's decision log, 2026-08-17) so a full visual pass would mean
## editing this one file's values, not hunting through the whole project --
## this is that pass: Abyssal Dive (DESIGN.md's "Art Direction," 2026-08-17)
## replaces every value below with a dark, high-contrast, glow-driven
## palette. Same names as before wherever the role is unchanged; only two
## constants (the old "Painted Hoard" ink language) got renamed alongside
## their value, since the old name was actively wrong once superseded.
##
## Same "data lives on one autoload, everything else reads it" pattern
## this project already uses for MetaProgression/LootTypes. Flat const
## fields (GDScript already lets other scripts reference an autoload's
## consts inside their own const initializers -- see shop.gd's
## PLAYER_TREE_STAT_IDS referencing MetaProgression.STAT_* today), grouped
## by role below.
##
## Rarity colors are deliberately NOT here -- loot_registry.gd's
## LootTypeDef already centralizes those, and Abyssal Dive explicitly
## locks the six rarity hexes unchanged (only their *treatment* changes,
## see loot_gem.gd). Scope here is colors only: animation/technique
## constants (glow layer counts, pulse speeds) stay in their own scripts.

# --- Currency ---
const ESSENCE: Color = Color(1.0, 0.85, 0.35, 1.0)
const STARDUST: Color = Color(0.25, 0.65, 0.95, 1.0)

# --- HP bar (hud.gd) ---
const HP_HIGH: Color = Color(0.25, 0.85, 0.65)
const HP_MID: Color = Color(0.85, 0.78, 0.25)
const HP_LOW: Color = Color(0.85, 0.15, 0.25)

# --- Attunement gauge (hud.gd) ---
const ATTUNEMENT_LOW: Color = Color(0.25, 0.7, 0.95, 1.0)
const ATTUNEMENT_HIGH: Color = Color(0.95, 0.25, 0.55, 1.0)

# --- Phase announcements (hud.gd) ---
const PHASE_2_LABEL: Color = Color(0.3, 0.85, 0.6)
const PHASE_3_LABEL: Color = Color(0.8, 0.25, 0.9)
const PHASE_4_LABEL: Color = Color(0.95, 0.2, 0.25)
const PHASE_BOSS_LABEL: Color = Color(1.0, 0.15, 0.3)

# --- Shared danger/status language -- explicitly reused today
# (arena.gd's Phase 4 edge comments "reuses BackpackGrid's own red
# danger-color language"), so these two are one constant each, not
# duplicated per file. ---
const DANGER_LOW: Color = Color(0.2, 0.55, 0.85, 0.0)
const DANGER_HIGH: Color = Color(0.9, 0.15, 0.25, 0.35)

# --- Combat feedback (player.gd/enemy.gd) ---
const PLAYER_HIT_FLASH: Color = Color(1.0, 0.3, 0.35)
const PLAYER_DAMAGE_TEXT: Color = Color(1.0, 0.3, 0.35)
const ENEMY_HIT_FLASH: Color = Color(4.0, 4.0, 4.0)
const ENEMY_DAMAGE_TEXT: Color = Color(1.0, 0.85, 0.3)
const ENEMY_SPARK: Color = Color.CRIMSON
const PLAYER_SPARK: Color = Color.CYAN
## Elite's ranged sting, retinted toxic yellow-green to match its new
## jellyfish/siphonophore identity (was a fantasy magenta bolt).
const ENEMY_PROJECTILE_BOLT: Color = Color(0.55, 0.95, 0.35)
const ENEMY_PROJECTILE_CORE: Color = Color(0.85, 1.0, 0.75)
const ENEMY_FROST_TINT: Color = Color(0.6, 0.9, 1.3, 1.0)

# --- Loot (loot.gd) ---
const LOOT_AFFIX: Color = Color(1.0, 0.85, 0.3)
const LOOT_LEADEN: Color = Color(0.28, 0.32, 0.34)
const LOOT_RECOVERED: Color = Color(0.4, 0.85, 0.6)
const LOOT_BEACON_GLOW: Color = Color(0.95, 0.15, 0.15, 1.0)

# --- Abyss shared "ink"/glow language (loot_gem.gd, spell_projectile.gd)
# -- kept as separate entries since the two currently use different
# alpha, not a true duplicate. Cool dark teal-black, replacing Painted
# Hoard's warm dark-brown stroke. ---
const ABYSS_INK_GEM: Color = Color(0.05, 0.14, 0.16, 0.85)
const ABYSS_INK_PROJECTILE: Color = Color(0.05, 0.14, 0.16, 0.7)

# --- Spell tints (spell_caster.gd, and each spell's own fx script) --
# retinted per spell's Abyssal Dive identity (DESIGN.md's spell table,
# 2026-08-17), not a uniform coolify pass -- each spell keeps a distinct
# hue for gameplay readability, shifted to fit what it now represents. ---
# Luminous Dart (was Arcane Bolt): a shard of harvested bioluminescence.
const SPELL_ARCANE: Color = Color(0.35, 0.9, 0.95)
const SPELL_ARCANE_CORE: Color = Color(0.9, 1.0, 1.0)
# The Undertow (was Inferno Blade): crushing pull, not fire -- its burn
# DoT is now "the Bends" (decompression sickness), so a bruised
# violet-red reads as internal damage rather than flame.
const SPELL_INFERNO: Color = Color(0.55, 0.15, 0.35)
const SPELL_INFERNO_CORE: Color = Color(0.85, 0.4, 0.55)
# Deep Chill (was Frost Nova): cold already fit natively -- smallest
# rewrite of the eight, per the spec's own note.
const SPELL_FROST: Color = Color(0.35, 0.75, 1.0)
const SPELL_FROST_BURST: Color = Color(0.4, 0.8, 1.0)
const SPELL_FROST_CORE: Color = Color(0.85, 0.98, 1.0)
# Trench Collapse (was Meteor Strike): the seafloor implodes under
# pressure -- a dark sediment tone instead of fire-orange, with the
# impact flash staying bright (a genuine bright instant, not ambient).
const SPELL_METEOR: Color = Color(0.45, 0.3, 0.15)
const SPELL_METEOR_CORE: Color = Color(0.95, 0.85, 0.6)
const SPELL_METEOR_FLASH_RING: Color = Color(1.0, 0.85, 0.5)
# Eel Current (was Lightning Chain): an electric eel's own bioluminescent
# yellow-green, not generic ice-blue lightning.
const SPELL_LIGHTNING: Color = Color(0.75, 0.95, 0.35)
const SPELL_LIGHTNING_CORE: Color = Color(0.95, 1.0, 0.8)
# Crushing Depths (was Time Warp): a wide pressure field -- kept violet,
# already reads as "deep and mystical" under the new setting too.
const SPELL_TIME_WARP: Color = Color(0.5, 0.3, 0.75)
const SPELL_TIME_WARP_CORE: Color = Color(0.85, 0.75, 1.0)
# Ink Jet (was Teleport Pulse): a dark ink-cloud burst, not a pale blip.
const SPELL_TELEPORT: Color = Color(0.3, 0.55, 0.85)
const COMBO_FULL_SET_LABEL: Color = Color(1.0, 0.92, 0.55)

# --- Altar -- kept warm on purpose, a deliberate exception to the "color
# is scarce" rule: a drowned shrine should read as a warm beacon against
# the cold environment around it, the same "saturated = meaningful"
# logic the spec applies to loot/spell glow. ---
const ALTAR_ACCENT: Color = Color(0.85, 0.65, 0.3, 1.0)
const ALTAR_DENIED: Color = Color(0.9, 0.3, 0.3, 1.0)

# --- Backpack grid (ui/backpack_grid.gd) ---
const BACKPACK_EMPTY: Color = Color(0.6, 0.85, 1.0, 0.1)
const BACKPACK_EMPTY_BORDER: Color = Color(0.6, 0.85, 1.0, 0.22)
const BACKPACK_GHOST: Color = Color(0.6, 0.85, 1.0, 0.04)
const BACKPACK_GHOST_BORDER: Color = Color(0.6, 0.85, 1.0, 0.16)
const BACKPACK_BALLAST: Color = Color(0.22, 0.26, 0.3)
const BACKPACK_BALLAST_BORDER: Color = Color(0.4, 0.46, 0.52)

# --- Skill tree (ui/skill_tree_view.gd) ---
const SKILL_TREE_LOCKED_BORDER: Color = Color(0.18, 0.22, 0.26, 1.0)
const SKILL_TREE_LOCKED_FILL: Color = Color(0.08, 0.1, 0.13, 1.0)
const SKILL_TREE_NO_CURRENCY_TINT: Color = Color(0.9, 0.35, 0.3, 1.0)
const SKILL_TREE_ICON_DIM: Color = Color(0.45, 0.5, 0.55, 1.0)
const SKILL_TREE_TOOLTIP_GOLD: Color = Color(0.92, 0.82, 0.4, 1.0)
const SKILL_TREE_TOOLTIP_CYAN: Color = Color(0.3, 0.75, 0.9, 1.0)
const SKILL_TREE_SEALED_RING: Color = Color(1.0, 1.0, 1.0, 0.9)
const STATUS_GREEN: Color = Color(0.3, 0.72, 0.32, 1.0)
const STATUS_RED: Color = Color(0.85, 0.3, 0.28, 1.0)
const STATUS_MUTED: Color = Color(0.55, 0.6, 0.65, 1.0)

# --- Buttons (ui/menu_link_button.gd, ui/tab_button.gd) -- hover shifts
# from Painted Hoard's warm gold to a bioluminescent teal, the single
# highest-visibility color change since it fires on every menu screen. ---
const BUTTON_NORMAL: Color = Color(0.78, 0.85, 0.88, 1.0)
const BUTTON_HOVER: Color = Color(0.35, 0.95, 0.9, 1.0)
const BUTTON_HOVER_LINE: Color = Color(0.35, 0.95, 0.9, 0.9)
const TAB_INACTIVE: Color = Color(0.55, 0.6, 0.65, 1.0)

# --- Cove tree accents (ui/shop.gd, shared with each tab's skill-tree
# glow via skill_tree_view.gd's accent_color param) -- three distinct
# hues for readability, same logic as before, softened toward the cold
# palette. ---
const COVE_PLAYER_ACCENT: Color = Color(0.85, 0.65, 0.3, 1.0)
const COVE_SPELL_ACCENT: Color = Color(0.65, 0.45, 0.85, 1.0)
const COVE_BACKPACK_ACCENT: Color = Color(0.35, 0.75, 0.85, 1.0)

# --- Background decor (fx/night_sky_background.gd,
# fx/arena_space_backdrop.gd, fx/vignette.gd) -- reworked from a night
# sky/space void into a murky abyss-water gradient with drifting
# particulate instead of stars/nebulae. VOID_BASE is shared: both
# backdrops use the identical darkest tone, one constant instead of
# two. ---
const VOID_BASE: Color = Color(0.02, 0.05, 0.07)
const NIGHT_SKY_MID: Color = Color(0.03, 0.09, 0.11)
const NIGHT_SKY_HORIZON: Color = Color(0.08, 0.18, 0.2)
const NIGHT_SKY_MOUNTAIN: Color = Color(0.015, 0.03, 0.035)
const STAR_TINT: Color = Color(0.7, 0.95, 1.0, 1.0)
const NEBULA_TINTS: Array[Color] = [
	Color(0.1, 0.25, 0.28, 0.1),
	Color(0.08, 0.2, 0.24, 0.08),
	Color(0.12, 0.22, 0.2, 0.09),
]
const VIGNETTE: Color = Color(0.01, 0.03, 0.04)
## Main menu's summoning-circle motif is a deliberate holdover -- see
## DESIGN.md's "What's explicitly NOT in this pass" -- so its color
## stays as-is rather than being retinted toward a mismatched decor
## piece that's slated for its own follow-up.
const MAGIC_CIRCLE_RING: Color = Color(0.75, 0.65, 0.9, 0.35)

# --- Scene transition (scene_transition.gd) ---
const SCENE_FADE: Color = Color(0.01, 0.02, 0.03, 0.0)

# --- Save slot selector (ui/save_slot_selector.gd) -- built at runtime, so
# these read straight from Palette rather than a game_theme.tres type
# variation (that pattern is for .tscn-declared Labels only). ---
const SAVE_SLOT_EMPTY_TEXT: Color = Color(0.55, 0.6, 0.65, 1.0)
const SAVE_SLOT_FILLED_TEXT: Color = Color(0.85, 0.92, 0.95, 1.0)
