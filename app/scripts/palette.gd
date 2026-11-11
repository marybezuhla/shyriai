# SPDX-License-Identifier: GPL-3.0-or-later
# Colours and fonts of Shyriai. Every colour of the interface comes from here; the 3D world
# keeps its own per-weather colours in WorldLand.PALETTES.
# "seed" is the brown middle of a sunflower: the same in every look, as a real one.
# "ok", "warn", "bad" fill the comfort and cargo meter: darker on light looks, so the bar
# shows against its track.
extends Node

signal changed

const THEMES := {
	# Dusk: the colours of the app icon. Default.
	"dusk": {
		"bg": Color("#2A1D3B"),
		"surface": Color("#37284C"),
		"surface2": Color("#45335E"),
		"line": Color("#574474"),
		"text": Color("#FFF0D5"),
		"muted": Color("#CBBCA8"),
		"faint": Color("#A897BC"),
		"accent": Color("#FFC321"),
		"on_accent": Color("#2A1D3B"),
		"accent_text": Color("#FFC321"),
		"focus": Color("#FFC321"),
		"seed": Color("#6B4A2E"),
		"ok": Color("#7DBE6A"),
		"warn": Color("#F29B50"),
		"bad": Color("#E5708B"),
	},
	# Day: light, for bright sunlight.
	"day": {
		"bg": Color("#FBF4E9"),
		"surface": Color("#FFFFFF"),
		"surface2": Color("#F0E6F2"),
		"line": Color("#D8CBE0"),
		"text": Color("#2A1D3B"),
		"muted": Color("#5E4F72"),
		"faint": Color("#6E5E84"),
		"accent": Color("#FFC321"),
		"on_accent": Color("#2A1D3B"),
		"accent_text": Color("#5B3E86"),
		"focus": Color("#5B3E86"),
		"seed": Color("#6B4A2E"),
		"ok": Color("#3E8E2F"),
		"warn": Color("#B85F10"),
		"bad": Color("#B8324F"),
	},
	# Morning: the Kids mode look. Sky-light, the same violet ink and gold.
	"morning": {
		"bg": Color("#EAF3F8"),
		"surface": Color("#FFFFFF"),
		"surface2": Color("#D6E8F2"),
		"line": Color("#B5CCDA"),
		"text": Color("#2A1D3B"),
		"muted": Color("#4B4564"),
		"faint": Color("#5C5679"),
		"accent": Color("#FFC321"),
		"on_accent": Color("#2A1D3B"),
		"accent_text": Color("#5B3E86"),
		"focus": Color("#5B3E86"),
		"seed": Color("#6B4A2E"),
		"ok": Color("#3E8E2F"),
		"warn": Color("#B85F10"),
		"bad": Color("#B8324F"),
	},
}

## Fixed colours, the same in every look: the icon's ink, cream and violet, used where the
## interface sits over the 3D world or draws the icon.
const INK := Color("#2A1D3B")
const CREAM := Color("#FFF0D5")
const VIOLET := Color("#463161")
const LOGO_DOT := Color("#39254F")
## Toy colours for hoops, balloons, butterflies and signs: one set, so they match.
const TOY := {
	"pink": Color("#E5708B"),
	"blue": Color("#5B9BD5"),
	"gold": Color("#FFC321"),
	"green": Color("#7DBE6A"),
	"violet": Color("#B07CD8"),
	"orange": Color("#F29B50"),
}

## Kids get slightly larger text; everything else follows from it.
const TEXT_SCALE := {"morning": 1.1}

var current := "dusk"
var _fonts := {}


func c(token: String) -> Color:
	return THEMES[current][token]


## Text size: the look's own scale (Kids read a little larger) times the reader's choice.
func text_scale() -> float:
	return TEXT_SCALE.get(current, 1.0) * _user_scale


var _user_scale := 1.0


func apply(choice: String, user_scale := 1.0) -> void:
	_user_scale = user_scale
	var chosen := choice
	if choice == "system":
		chosen = "dusk" if DisplayServer.is_dark_mode() or not DisplayServer.is_dark_mode_supported() else "day"
	if not THEMES.has(chosen):
		chosen = "dusk"
	current = chosen
	RenderingServer.set_default_clear_color(c("bg"))
	changed.emit()


## Manrope for text, Unbounded for headings. Both are variable fonts; the weight is an axis.
func font(weight: int = 500, display: bool = false, spacing := 0) -> Font:
	var key := "%s%d_%d" % ["d" if display else "t", weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var base: FontFile = load("res://assets/fonts/Unbounded-Variable.ttf" if display else "res://assets/fonts/Manrope-Variable.ttf")
	if not display:
		# Manrope has no modifier letter apostrophe (U+02BC); Unbounded does.
		base.fallbacks = [load("res://assets/fonts/Unbounded-Variable.ttf")]
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	v.spacing_glyph = spacing
	_fonts[key] = v
	return v
