# SPDX-License-Identifier: GPL-3.0-or-later
# The badges: how far the whole training has come, then every badge, earned or still ahead. Kids
# see only pictures and short names, no numbers.
extends Screen


func build() -> void:
	var kids := Prefs.mode == "kids"
	var list := Badges.all()
	add_child(header(tr("BADGES_KIDS" if kids else "BADGES"), tr("MODE_" + Prefs.mode.to_upper())))
	if not kids:
		var col := UI.vbox(10)
		col.add_child(UI.eyebrow(tr("BADGES_TOTALS")))
		col.add_child(_totals())
		add_child(col)
	var col2 := UI.vbox(10)
	if not kids:
		col2.add_child(UI.eyebrow(tr("BADGES_EARNED") % [Badges.earned(list), list.size()]))
	var grid := GridContainer.new()
	# Two in a row: room for a long name and its line underneath at every text size.
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	# The narrowest phone: a long one-word name ("Перехоплення") shrinks a little rather than break.
	var inner := (390.0 - 2 * UI.GUTTER - 10.0 * (grid.columns - 1)) / grid.columns - 24.0
	for b in list:
		grid.add_child(_tile(b, kids, inner))
	col2.add_child(grid)
	add_child(col2)
	if not kids:
		add_child(UI.label(tr("BADGES_LEGEND"), UI.SMALL, 500, "muted"))


func _totals() -> Control:
	var t := Badges.totals()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for part in ["lessons", "missions", "flowers", "chapters"]:
		if not t.has(part):
			continue
		var n: Vector2i = t[part]
		var v := UI.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UI.hbox(6)
		row.add_child(UI.label(str(n.x), UI.TITLE, 700, "text", true, false))
		var of := UI.label(tr("BADGES_OUT_OF") % n.y, UI.BODY, 600, "muted", false, false)
		of.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(of)
		v.add_child(row)
		v.add_child(UI.label(tr("BADGES_PART_" + part.to_upper()), UI.SMALL, 500, "muted"))
		v.add_child(_bar(float(n.x) / maxf(1.0, n.y)))
		var p := UI.panel(v, Pal.c("surface"), 16, 12)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.set("accessibility_name", "%s: %d %s" % [tr("BADGES_PART_" + part.to_upper()), n.x, tr("BADGES_OUT_OF") % n.y])
		grid.add_child(p)
	return grid


static func _bar(share: float) -> Control:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.add_theme_stylebox_override("panel", UI.box(Pal.c("line"), 3, 0))
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", UI.box(Pal.c("accent"), 3, 0))
	bar.add_child(fill)
	bar.resized.connect(func(): fill.size = Vector2(bar.size.x * clampf(share, 0.0, 1.0), 6))
	return bar


func _tile(b: Dictionary, kids: bool, inner: float) -> Control:
	var v := UI.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	var c := CenterContainer.new()
	c.add_child(Emblem.make(b, 58.0 * minf(Pal.text_scale(), 1.25)))
	v.add_child(c)
	var title := UI.label(Curriculum.label(b["title"]), UI.SMALL, 700, "text" if b["level"] > 0 else "muted")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit_words(title, inner)
	v.add_child(title)
	var how := ""
	if not kids:
		how = b["note"] if b["note"] != "" and b["level"] < 2 else tr(b["how"])
		var l := UI.label(how, UI.CAPTION, 500, "muted")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.fit_words(l, inner)
		v.add_child(l)
	var p := UI.panel(v, Pal.c("surface"), 16, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var state := tr("BADGE_STATE_%d" % b["level"])
	var said := [Curriculum.label(b["title"])]
	if not kids:
		said.append(how)
	said.append(state)
	p.set("accessibility_name", ". ".join(said))
	return p


## A badge's round emblem: pale while ahead, half filled on the way, full when earned; a double rim
## for the big steps.
class Emblem extends Control:
	var badge := {}

	static func make(b: Dictionary, px: float) -> Emblem:
		var e := Emblem.new()
		e.badge = b
		e.custom_minimum_size = Vector2(px, px)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var level: int = b["level"]
		var icon := Glyph.make(b["icon"], px * 0.48, Pal.c("on_accent") if level == 2 else Pal.c("text" if level == 1 else "muted"))
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(icon)
		e.add_child(cc)
		if level == 0:
			e.modulate.a = 0.7
		return e

	func _draw() -> void:
		var level: int = badge["level"]
		var big: bool = badge["big"] and level == 2
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - (5.0 if big else 2.0)
		draw_circle(c, r, Pal.c("surface2"))
		if level == 2:
			draw_circle(c, r, Pal.c("accent"))
		elif level == 1:
			draw_arc(c, r / 2.0, -PI / 2.0, PI / 2.0, 24, Pal.c("accent"), r, true)  # the right half
		var ring := Pal.c("text") if level > 0 else Pal.c("line")
		draw_arc(c, r, 0.0, TAU, 48, ring, 2.5 if level > 0 else 1.5, true)
		if big:
			draw_arc(c, r + 4.0, 0.0, TAU, 48, ring, 2.0, true)
