# SPDX-License-Identifier: GPL-3.0-or-later
# "Who's flying?": the children on this phone, each an animal and a colour, with a few sunflowers
# for how far they have got. A tap picks who flies. Adding and removing pilots is for grown-ups,
# behind the lock.
extends Screen

var _removing := false


func build() -> void:
	var title := UI.label(tr("PILOTS_WHO"), UI.TITLE_L, 600, "text", true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(UI.spacer(12))
	add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in KidPilots.count():
		grid.add_child(_tile(i))
	if Prefs.kid_pilots.size() < KidPilots.MAX and not _removing:
		grid.add_child(_add_tile())
	add_child(grid)
	var note := UI.label(tr("PILOTS_NOTE"), UI.SMALL, 500, "muted")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	if KidPilots.ask():
		var key := "PILOTS_REMOVE_DONE" if _removing else "PILOTS_REMOVE"
		add_child(UI.secondary(tr(key), func(): app.guard(_toggle_remove)))


func _tile(i: int) -> Control:
	var col := UI.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", UI.box(KidPilots.color(i).lerp(Pal.c("surface"), 0.55), 40, 12))
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.add_child(Glyph.make(KidPilots.animal(i), 52, Pal.c("text")))
	col.add_child(face)
	var flowers := UI.hbox(2)
	flowers.alignment = BoxContainer.ALIGNMENT_CENTER
	flowers.custom_minimum_size = Vector2(0, 20)
	for k in KidPilots.flowers(i):
		flowers.add_child(Glyph.make("sunflower", 18, Pal.c("accent_text")))
	col.add_child(flowers)
	if _removing:
		col.add_child(UI.label(tr("PILOTS_REMOVE_ONE"), UI.SMALL, 700, "bad", false, false))
	var name_ := tr("ANIMAL_" + KidPilots.animal(i).to_upper())
	var act := (func(): KidPilots.remove(i)) if _removing else (func(): _fly(i))
	var tile := UI.tappable(col, Pal.c("surface"), act, name_, 22, 14,
		false, Pal.c("focus") if i == Prefs.kid_pilot and KidPilots.ask() else Color.TRANSPARENT)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile


func _add_tile() -> Control:
	var col := UI.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var plus := CenterContainer.new()
	plus.custom_minimum_size = Vector2(76, 76)
	plus.add_child(Glyph.make("plus", 34, Pal.c("accent_text")))
	col.add_child(plus)
	var l := UI.label(tr("PILOTS_NEW"), UI.SMALL, 700, "text", false, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	var tile := UI.tappable(col, Pal.c("surface2"), func(): app.guard(KidPilots.add), tr("PILOTS_NEW"), 22, 14)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile


func _fly(i: int) -> void:
	KidPilots.select(i)
	app.back()


func _toggle_remove() -> void:
	_removing = not _removing
	rebuild()
