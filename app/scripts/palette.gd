# SPDX-License-Identifier: GPL-3.0-or-later
# Colours and fonts of Shyriai. Every colour on screen comes from here.
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
	},
}

var current := "dusk"
var _fonts := {}


func c(token: String) -> Color:
	return THEMES[current][token]


func apply(choice: String) -> void:
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
