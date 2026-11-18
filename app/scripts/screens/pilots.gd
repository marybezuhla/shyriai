# SPDX-License-Identifier: GPL-3.0-or-later
# "Who's flying?": the children on this phone, each an animal and a colour, with a few sunflowers
# for how far they have got. A tap picks who flies.
# Opened from settings (`manage`), it is for grown-ups: they are already past the lock there, so
# adding and removing need no second sum. Removing asks once more on the tile, and can be undone.
# On the child's own start screen there are only the animals.
extends Screen

var manage := false
var _removing := false
## The pilot tapped once in remove mode, waiting for the second tap; -1 = none.
var _confirm := -1
## The last pilot removed, to bring back: {"at": index, "pilot": entry}.
var _removed := {}


func build() -> void:
	if manage:
		add_child(header(tr("PILOTS"), tr("PILOTS_DESC")))
	else:
		var title := UI.label(tr("PILOTS_WHO"), UI.TITLE_L, 600, "text", true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(UI.spacer(12))
		add_child(title)
	if not KidPilots.ask():
		_removing = false  # one pilot left: nothing to remove
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in KidPilots.count():
		grid.add_child(_tile(i))
	if manage and Prefs.kid_pilots.size() < KidPilots.MAX and not _removing:
		grid.add_child(_add_tile())
	add_child(grid)
	if not manage:
		return
	var note := UI.label(tr("PILOTS_NOTE"), UI.SMALL, 500, "muted")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	if not _removed.is_empty():
		add_child(UI.secondary(tr("RESET_UNDO"), _bring_back))
	if KidPilots.ask():
		var key := "PILOTS_REMOVE_DONE" if _removing else "PILOTS_REMOVE"
		add_child(UI.secondary(tr(key), _toggle_remove))


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
		var ask := UI.label(tr("PILOTS_REMOVE_SURE" if _confirm == i else "PILOTS_REMOVE_ONE"), UI.SMALL, 700, "bad")
		ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ask)
	var name_ := tr("ANIMAL_" + KidPilots.animal(i).to_upper())
	var act := (func(): _remove_tap(i)) if _removing else (func(): _fly(i))
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
	var l := UI.label(tr("PILOTS_NEW"), UI.SMALL, 700, "text")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	var tile := UI.tappable(col, Pal.c("surface2"), func(): KidPilots.add(), tr("PILOTS_NEW"), 22, 14)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile


func _fly(i: int) -> void:
	KidPilots.select(i)
	app.back()


## The first tap asks, the second removes; the pilot can still be brought back.
func _remove_tap(i: int) -> void:
	if _confirm != i:
		_confirm = i
		rebuild()
		return
	_confirm = -1
	_removed = {"at": i, "pilot": Prefs.kid_pilots[i].duplicate(true)}
	if i == Prefs.kid_pilot:
		_removed["pilot"]["slice"] = KidPilots.live_slice()
	KidPilots.remove(i)


func _bring_back() -> void:
	KidPilots.restore(_removed["at"], _removed["pilot"])
	_removed = {}


func _toggle_remove() -> void:
	_removing = not _removing
	_confirm = -1
	rebuild()
