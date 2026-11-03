# SPDX-License-Identifier: GPL-3.0-or-later
# One screen of the app. Screens rebuild themselves from scratch when the theme or language changes.
class_name Screen
extends VBoxContainer

var app: Node  # main.gd


func _init() -> void:
	add_theme_constant_override("separation", 20)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Override: put the screen's content in.
func build() -> void:
	pass


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	build()


## A header with a back button, a title and an optional line under it.
func header(title: String, subtitle := "") -> Control:
	var row := UI.hbox(8)
	row.add_child(UI.icon_button("back", func(): app.back(), tr("BACK"), Color(0, 0, 0, 0)))
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(UI.label(title, 20, 600, "text", true))
	if subtitle != "":
		col.add_child(UI.label(subtitle, 13, 500, "muted"))
	row.add_child(col)
	return row
