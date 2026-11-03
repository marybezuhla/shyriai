# SPDX-License-Identifier: GPL-3.0-or-later
# The lesson list joined by a dashed "stitch" line, like embroidery on a rushnyk.
# Passed stitches are gold, the rest are quiet.
class_name LessonPath
extends Control

var list := VBoxContainer.new()
var dots: Array[Control] = []
var passed := 0
var current := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	list.add_theme_constant_override("separation", 10)
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(list)
	list.sort_children.connect(queue_redraw)
	list.minimum_size_changed.connect(func(): custom_minimum_size = list.get_combined_minimum_size())
	resized.connect(queue_redraw)


func add_row(row: Control, dot: Control) -> void:
	list.add_child(row)
	dots.append(dot)


func _draw() -> void:
	if dots.size() < 2:
		return
	var centers: Array[Vector2] = []
	for d in dots:
		centers.append(d.get_global_rect().get_center() - get_global_rect().position)
	for i in centers.size() - 1:
		var col := Pal.c("accent") if i < passed else Pal.c("line")
		draw_dashed_line(centers[i], centers[i + 1], col, 3.0, 7.0, true, true)
	# A soft halo around the lesson that is up next.
	if current < centers.size():
		var halo := Pal.c("accent")
		halo.a = 0.18
		draw_circle(centers[current], 28, halo, true, -1.0, true)
