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
	# Sky: light, a pale blue with navy text and a wheat-yellow accent.
	"sky": {
		"bg": Color("#EAF2FB"),
		"surface": Color("#FFFFFF"),
		"surface2": Color("#DCE9F7"),
		"line": Color("#B9CFE6"),
		"text": Color("#12355B"),
		"muted": Color("#3B5878"),
		"faint": Color("#4A6585"),
		"accent": Color("#F5C542"),
		"on_accent": Color("#12355B"),
		"accent_text": Color("#1D5A9E"),
		"focus": Color("#1D5A9E"),
		"seed": Color("#6B4A2E"),
		"ok": Color("#3E8E2F"),
		"warn": Color("#B85F10"),
		"bad": Color("#B8324F"),
	},
	# Starry night: Sky's dark pair, navy with a gold accent.
	"starry": {
		"bg": Color("#0F1D33"),
		"surface": Color("#182A47"),
		"surface2": Color("#22385C"),
		"line": Color("#304A73"),
		"text": Color("#F3F6FF"),
		"muted": Color("#BCC8DE"),
		"faint": Color("#9AABC8"),
		"accent": Color("#FFD23F"),
		"on_accent": Color("#0F1D33"),
		"accent_text": Color("#FFD23F"),
		"focus": Color("#FFD23F"),
		"seed": Color("#6B4A2E"),
		"ok": Color("#7DBE6A"),
		"warn": Color("#F29B50"),
		"bad": Color("#E5708B"),
	},
	# Mallow: light, a blush pink with deep teal text and a pink accent.
	"mallow": {
		"bg": Color("#FCEFF2"),
		"surface": Color("#FFFFFF"),
		"surface2": Color("#F6DDE4"),
		"line": Color("#E6BFCB"),
		"text": Color("#0F4848"),
		"muted": Color("#3C6262"),
		"faint": Color("#426767"),
		"accent": Color("#E5708B"),
		"on_accent": Color("#2B0B18"),
		"accent_text": Color("#9C2D53"),
		"focus": Color("#9C2D53"),
		"seed": Color("#6B4A2E"),
		"ok": Color("#3E8E2F"),
		"warn": Color("#B85F10"),
		"bad": Color("#B8324F"),
	},
	# Sea night: Mallow's dark pair, deep teal with a pink accent.
	"seanight": {
		"bg": Color("#0E2E30"),
		"surface": Color("#15403F"),
		"surface2": Color("#1D5150"),
		"line": Color("#2A6463"),
		"text": Color("#FDF0F3"),
		"muted": Color("#C5DBD8"),
		"faint": Color("#A2C3BF"),
		"accent": Color("#F08CA5"),
		"on_accent": Color("#0E2E30"),
		"accent_text": Color("#F7A8BC"),
		"focus": Color("#F08CA5"),
		"seed": Color("#6B4A2E"),
		"ok": Color("#7DBE6A"),
		"warn": Color("#F29B50"),
		"bad": Color("#E5708B"),
	},
	# Morning: the Kids mode look of Day. Sky-light, the same violet ink and gold.
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
## The bright red of a rescue jacket and of a signal tarp: seen from the air.
const SIGNAL_RED := Color("#D9473B")
## Toy colours for hoops, balloons, butterflies and signs: one set, so they match.
const TOY := {
	"pink": Color("#E5708B"),
	"blue": Color("#5B9BD5"),
	"gold": Color("#FFC321"),
	"green": Color("#7DBE6A"),
	"violet": Color("#B07CD8"),
	"orange": Color("#F29B50"),
}

## The six looks in pairs, light and dark: "Follow the system" picks one of a pair. Kids see the
## light one (Day as Morning).
const PAIRS := {"day": "dusk", "sky": "starry", "mallow": "seanight"}
const KIDS_LOOK := {"day": "morning", "sky": "sky", "mallow": "mallow"}
## Kids read slightly larger text; everything else follows from it.
const KIDS_TEXT := 1.1

var current := "dusk"
var kids := false
var _fonts := {}


func c(token: String) -> Color:
	return THEMES[current][token]


## Text size: the look's own scale (Kids read a little larger) times the reader's choice.
func text_scale() -> float:
	return (KIDS_TEXT if kids else 1.0) * _user_scale


var _user_scale := 1.0


## The light look of a pair, from either of its two.
static func light_of(look: String) -> String:
	for l in PAIRS:
		if look == l or look == PAIRS[l]:
			return l
	return "day"


static func pick(choice: String, follow_system: bool, kids_mode: bool) -> String:
	var chosen := choice if THEMES.has(choice) else "dusk"
	if follow_system and DisplayServer.is_dark_mode_supported():
		var light := light_of(chosen)
		chosen = PAIRS[light] if DisplayServer.is_dark_mode() else light
	if kids_mode:
		chosen = KIDS_LOOK[light_of(chosen)]
	return chosen


static func is_dark(look: String) -> bool:
	return look in PAIRS.values()


## A look by the grown-up's choice: with "follow the system", the pair's light or dark one as the
## phone is now. Kids get the pair's light look.
func apply(choice: String, user_scale := 1.0, follow_system := false, kids_mode := false) -> void:
	_user_scale = user_scale
	kids = kids_mode
	current = pick(choice, follow_system, kids_mode)
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
