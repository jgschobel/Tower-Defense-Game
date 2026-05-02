class_name DesignTokens
extends RefCounted

## Single source of truth for the game's visual language.
## Everything UI-facing reads from here so we have ONE place to evolve
## the look. User directive: "clean, elegant, stylish, minimalistic —
## like a professional game developed by pro developers."

# ---------- Palette ----------
# Warm-dark luxury palette. Gold accent. Limited variations.
# All colors below are sampled from a single 6-stop ramp + 2 accent colors.

# Surfaces (background → foreground)
const COL_BG_DEEPEST    := Color(0.06, 0.05, 0.04, 1.0)   # full-screen backdrop
const COL_BG_PANEL      := Color(0.10, 0.08, 0.07, 0.94)  # panels (tower-info, pause, aminos)
const COL_BG_RAISED     := Color(0.16, 0.13, 0.10, 1.0)   # buttons (default state)
const COL_BG_HOVER      := Color(0.30, 0.22, 0.10, 1.0)   # hover state
const COL_BG_PRESSED    := Color(0.46, 0.32, 0.10, 1.0)   # pressed state

# Borders / strokes
const COL_STROKE_FAINT  := Color(0.30, 0.26, 0.20, 0.55)
const COL_STROKE_NORMAL := Color(0.55, 0.45, 0.20, 0.85)
const COL_STROKE_STRONG := Color(1.0,  0.78, 0.18, 0.95)  # primary gold
const COL_STROKE_HOVER  := Color(1.0,  0.92, 0.45, 1.0)

# Text
const COL_TEXT_PRIMARY    := Color(0.98, 0.94, 0.85, 1.0) # body / labels
const COL_TEXT_HEADING    := Color(1.0,  0.88, 0.30, 1.0) # gold heading
const COL_TEXT_MUTED      := Color(0.72, 0.66, 0.58, 1.0) # secondary
const COL_TEXT_DISABLED   := Color(0.45, 0.42, 0.38, 1.0)
const COL_TEXT_OUTLINE    := Color(0.05, 0.03, 0.02, 0.95)

# Semantic
const COL_OK              := Color(0.45, 0.85, 0.40, 1.0)
const COL_WARN            := Color(1.0,  0.65, 0.20, 1.0)
const COL_BAD             := Color(0.95, 0.30, 0.20, 1.0)
const COL_GOLD            := Color(1.0,  0.85, 0.25, 1.0)

# ---------- Typography ----------
const FONT_TITLE       := 44   # main menu title only
const FONT_HEADING     := 26   # screen headings
const FONT_LABEL_LG    := 20   # primary labels
const FONT_LABEL       := 16   # body
const FONT_LABEL_SM    := 13   # secondary
const FONT_LABEL_XS    := 11

const OUTLINE_TITLE    := 6
const OUTLINE_HEADING  := 4
const OUTLINE_LABEL    := 3
const OUTLINE_NONE     := 0

# ---------- Spacing (8pt grid) ----------
const SP_XS  := 4
const SP_S   := 8
const SP_M   := 12
const SP_L   := 16
const SP_XL  := 24
const SP_XXL := 32

const RADIUS_S := 6
const RADIUS_M := 10
const RADIUS_L := 14

# ---------- Helpers ----------

## Build a panel stylebox with optional accent border.
static func panel_box(accent: Color = COL_STROKE_NORMAL, radius: int = RADIUS_M, padding: int = SP_M) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG_PANEL
	sb.border_color = accent
	sb.border_width_left = 2
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = padding
	sb.content_margin_right = padding
	sb.content_margin_top = padding * 0.75
	sb.content_margin_bottom = padding * 0.75
	return sb


## Apply unified button style to a Button. Pass accent for the gold-rim
## variant (primary CTAs). Pass null for the muted variant (secondary).
static func style_button(btn: Button, primary: bool = false, font_size: int = FONT_LABEL) -> void:
	var accent: Color = COL_STROKE_STRONG if primary else COL_STROKE_NORMAL
	var base := StyleBoxFlat.new()
	base.bg_color = COL_BG_RAISED
	base.border_color = accent
	base.border_width_left = 2
	base.border_width_right = 1
	base.border_width_top = 1
	base.border_width_bottom = 2
	base.corner_radius_top_left = RADIUS_S
	base.corner_radius_top_right = RADIUS_S
	base.corner_radius_bottom_left = RADIUS_S
	base.corner_radius_bottom_right = RADIUS_S
	base.content_margin_left = SP_M
	base.content_margin_right = SP_M
	base.content_margin_top = SP_S
	base.content_margin_bottom = SP_S
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = COL_BG_HOVER
	hover.border_color = COL_STROKE_HOVER
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = COL_BG_PRESSED
	pressed.border_color = Color.WHITE
	var disabled := base.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.10, 0.09, 0.08, 0.7)
	disabled.border_color = COL_STROKE_FAINT
	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COL_TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", COL_TEXT_HEADING)
	btn.add_theme_color_override("font_disabled_color", COL_TEXT_DISABLED)
	btn.add_theme_font_size_override("font_size", font_size)


## Apply heading-style label formatting.
static func style_heading(lbl: Label, size: int = FONT_HEADING) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", COL_TEXT_HEADING)
	lbl.add_theme_color_override("font_outline_color", COL_TEXT_OUTLINE)
	lbl.add_theme_constant_override("outline_size", OUTLINE_HEADING)


## Apply body label formatting.
static func style_label(lbl: Label, size: int = FONT_LABEL, muted: bool = false) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", COL_TEXT_MUTED if muted else COL_TEXT_PRIMARY)
	lbl.add_theme_color_override("font_outline_color", COL_TEXT_OUTLINE)
	lbl.add_theme_constant_override("outline_size", OUTLINE_LABEL if not muted else OUTLINE_NONE)
