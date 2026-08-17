extends Node

## Central color registry for every procedural `_draw()` call, particle
## tint, and script-side `modulate` in the game -- prep work for a full
## visual re-skin (see DESIGN.md's decision log, 2026-08-17): before this,
## ~55 Color constants were scattered across 22 scripts, several
## duplicated verbatim in more than one place. A re-skin now means
## editing this one file's values, not hunting through the whole project.
##
## Same "data lives on one autoload, everything else reads it" pattern
## this project already uses for MetaProgression/LootTypes. Flat const
## fields (GDScript already lets other scripts reference an autoload's
## consts inside their own const initializers -- see shop.gd's
## PLAYER_TREE_STAT_IDS referencing MetaProgression.STAT_* today), grouped
## by role below.
##
## Rarity colors are deliberately NOT here -- loot_registry.gd's
## LootTypeDef already centralizes those (one `_register()` call per
## tier), already a single point of truth. Scope here is colors only:
## animation/technique constants (glow layer counts, pulse speeds) stay
## in their own scripts -- a re-skin changes what color, not how many
## layers.

# --- Currency ---
const ESSENCE: Color = Color(0.9, 0.8, 0.3, 1.0)
const STARDUST: Color = Color(0.3, 0.75, 0.9, 1.0)

# --- HP bar (hud.gd) ---
const HP_HIGH: Color = Color(0.3, 0.85, 0.4)
const HP_MID: Color = Color(0.9, 0.8, 0.2)
const HP_LOW: Color = Color(0.9, 0.25, 0.25)

# --- Attunement gauge (hud.gd) ---
const ATTUNEMENT_LOW: Color = Color(0.3, 0.75, 0.9, 1.0)
const ATTUNEMENT_HIGH: Color = Color(0.95, 0.45, 0.2, 1.0)

# --- Phase announcements (hud.gd) ---
const PHASE_2_LABEL: Color = Color(0.9, 0.55, 0.25)
const PHASE_3_LABEL: Color = Color(0.85, 0.3, 0.85)
const PHASE_4_LABEL: Color = Color(0.9, 0.25, 0.2)
const PHASE_BOSS_LABEL: Color = Color(0.95, 0.2, 0.25)

# --- Shared danger/status language -- explicitly reused today
# (arena.gd's Phase 4 edge comments "reuses BackpackGrid's own red
# danger-color language"), so these two are one constant each, not
# duplicated per file. ---
const DANGER_LOW: Color = Color(0.3, 0.65, 0.9, 0.0)
const DANGER_HIGH: Color = Color(0.9, 0.25, 0.2, 0.35)

# --- Combat feedback (player.gd/enemy.gd) ---
const PLAYER_HIT_FLASH: Color = Color(1.0, 0.35, 0.35)
const PLAYER_DAMAGE_TEXT: Color = Color(1.0, 0.35, 0.35)
const ENEMY_HIT_FLASH: Color = Color(4.0, 4.0, 4.0)
const ENEMY_DAMAGE_TEXT: Color = Color(1.0, 0.9, 0.3)
const ENEMY_SPARK: Color = Color.CRIMSON
const PLAYER_SPARK: Color = Color.CYAN
const ENEMY_PROJECTILE_BOLT: Color = Color(0.85, 0.25, 0.55)
const ENEMY_PROJECTILE_CORE: Color = Color(1.0, 0.85, 0.95)
const ENEMY_FROST_TINT: Color = Color(0.6, 0.9, 1.3, 1.0)

# --- Loot (loot.gd) ---
const LOOT_AFFIX: Color = Color(1.0, 0.85, 0.3)
const LOOT_LEADEN: Color = Color(0.35, 0.32, 0.3)
const LOOT_RECOVERED: Color = Color(0.4, 0.85, 0.6)
const LOOT_BEACON_GLOW: Color = Color(0.95, 0.15, 0.15, 1.0)

# --- Painted Hoard shared "ink"/glow language (loot_gem.gd,
# spell_projectile.gd) -- kept as separate entries since the two
# currently use different alpha, not a true duplicate. ---
const PAINTED_INK_GEM: Color = Color(0.22, 0.14, 0.08, 0.85)
const PAINTED_INK_PROJECTILE: Color = Color(0.22, 0.14, 0.08, 0.7)

# --- Spell tints (spell_caster.gd, and each spell's own fx script) ---
const SPELL_ARCANE: Color = Color(0.55, 0.35, 0.95)
const SPELL_ARCANE_CORE: Color = Color(0.92, 0.85, 1.0)
const SPELL_INFERNO: Color = Color(0.95, 0.4, 0.15)
const SPELL_INFERNO_CORE: Color = Color(1.0, 0.85, 0.55)
const SPELL_FROST: Color = Color(0.5, 0.85, 1.0)
const SPELL_FROST_BURST: Color = Color(0.55, 0.85, 1.0)
const SPELL_FROST_CORE: Color = Color(0.9, 0.98, 1.0)
const SPELL_METEOR: Color = Color(1.0, 0.55, 0.1)
const SPELL_METEOR_CORE: Color = Color(1.0, 0.95, 0.8)
const SPELL_METEOR_FLASH_RING: Color = Color(1.0, 0.9, 0.6)
const SPELL_LIGHTNING: Color = Color(0.6, 0.85, 1.0)
const SPELL_LIGHTNING_CORE: Color = Color(1.0, 0.97, 0.9)
const SPELL_TIME_WARP: Color = Color(0.65, 0.45, 0.95)
const SPELL_TIME_WARP_CORE: Color = Color(0.92, 0.85, 1.0)
const SPELL_TELEPORT: Color = Color(0.6, 0.85, 1.0)
const COMBO_FULL_SET_LABEL: Color = Color(1.0, 0.55, 0.1)

# --- Altar (structures/altar.gd) ---
const ALTAR_ACCENT: Color = Color(0.85, 0.7, 0.35, 1.0)
const ALTAR_DENIED: Color = Color(0.9, 0.3, 0.3, 1.0)

# --- Backpack grid (ui/backpack_grid.gd) ---
const BACKPACK_EMPTY: Color = Color(1.0, 1.0, 1.0, 0.1)
const BACKPACK_EMPTY_BORDER: Color = Color(1.0, 1.0, 1.0, 0.22)
const BACKPACK_GHOST: Color = Color(1.0, 1.0, 1.0, 0.04)
const BACKPACK_GHOST_BORDER: Color = Color(1.0, 1.0, 1.0, 0.16)
const BACKPACK_BALLAST: Color = Color(0.3, 0.28, 0.26)
const BACKPACK_BALLAST_BORDER: Color = Color(0.5, 0.46, 0.42)

# --- Skill tree (ui/skill_tree_view.gd) ---
const SKILL_TREE_LOCKED_BORDER: Color = Color(0.32, 0.32, 0.34, 1.0)
const SKILL_TREE_LOCKED_FILL: Color = Color(0.14, 0.14, 0.16, 1.0)
const SKILL_TREE_NO_CURRENCY_TINT: Color = Color(0.9, 0.35, 0.3, 1.0)
const SKILL_TREE_ICON_DIM: Color = Color(0.5, 0.5, 0.52, 1.0)
const SKILL_TREE_TOOLTIP_GOLD: Color = Color(0.92, 0.82, 0.4, 1.0)
const SKILL_TREE_TOOLTIP_CYAN: Color = Color(0.3, 0.75, 0.9, 1.0)
const SKILL_TREE_SEALED_RING: Color = Color(1.0, 1.0, 1.0, 0.9)
const STATUS_GREEN: Color = Color(0.3, 0.72, 0.32, 1.0)
const STATUS_RED: Color = Color(0.85, 0.3, 0.28, 1.0)
const STATUS_MUTED: Color = Color(0.6, 0.6, 0.62, 1.0)

# --- Buttons (ui/menu_link_button.gd, ui/tab_button.gd) ---
const BUTTON_NORMAL: Color = Color(0.82, 0.82, 0.85, 1.0)
const BUTTON_HOVER: Color = Color(0.95, 0.85, 0.35, 1.0)
const BUTTON_HOVER_LINE: Color = Color(0.95, 0.85, 0.35, 0.9)
const TAB_INACTIVE: Color = Color(0.6, 0.6, 0.63, 1.0)

# --- Sanctum tree accents (ui/shop.gd, shared with each tab's skill-tree
# glow via skill_tree_view.gd's accent_color param) ---
const SANCTUM_PLAYER_ACCENT: Color = Color(0.85, 0.7, 0.35, 1.0)
const SANCTUM_SPELL_ACCENT: Color = Color(0.65, 0.45, 0.85, 1.0)
const SANCTUM_BACKPACK_ACCENT: Color = Color(0.35, 0.75, 0.85, 1.0)

# --- Background decor (fx/night_sky_background.gd,
# fx/arena_space_backdrop.gd, fx/vignette.gd, fx/magic_circle_decor.gd)
# -- VOID_BASE is shared: both backdrops used the identical value for
# their darkest tone already, one constant instead of two. ---
const VOID_BASE: Color = Color(0.04, 0.03, 0.09)
const NIGHT_SKY_MID: Color = Color(0.22, 0.09, 0.24)
const NIGHT_SKY_HORIZON: Color = Color(0.55, 0.24, 0.32)
const NIGHT_SKY_MOUNTAIN: Color = Color(0.03, 0.035, 0.05)
const STAR_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const NEBULA_TINTS: Array[Color] = [
	Color(0.45, 0.25, 0.55, 0.12),
	Color(0.25, 0.35, 0.6, 0.1),
	Color(0.55, 0.3, 0.45, 0.11),
]
const VIGNETTE: Color = Color(0.05, 0.02, 0.1)
const MAGIC_CIRCLE_RING: Color = Color(0.75, 0.65, 0.9, 0.35)

# --- Scene transition (scene_transition.gd) ---
const SCENE_FADE: Color = Color(0.02, 0.02, 0.02, 0.0)

# --- Save slot selector (ui/save_slot_selector.gd) -- built at runtime, so
# these read straight from Palette rather than a game_theme.tres type
# variation (that pattern is for .tscn-declared Labels only). ---
const SAVE_SLOT_EMPTY_TEXT: Color = Color(0.6, 0.6, 0.58, 1.0)
const SAVE_SLOT_FILLED_TEXT: Color = Color(0.88, 0.88, 0.85, 1.0)
