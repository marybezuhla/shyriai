# SPDX-License-Identifier: GPL-3.0-or-later
# The survey camera's two buttons beside the right stick: the gimbal tilt (forward, angled, down)
# and the shutter. A white flash and a click say a picture was taken.
class_name PhotoKit
extends VBoxContainer

var task: PhotoTask
## Called with nothing when the shutter is pressed.
var on_shutter: Callable
var _tilt_label: Label
var _tilt_icon: Glyph


func build(task_: PhotoTask, kids: bool, shutter: Callable) -> void:
	task = task_
	on_shutter = shutter
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass := Pal.c("bg")
	glass.a = 0.82
	# Kids' camera keeps one angle: one button is plenty.
	if not kids:
		var col := UI.vbox(2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		_tilt_icon = Glyph.make("tilt_" + task.tilt, 22, Pal.c("text"))
		var ic := CenterContainer.new()
		ic.add_child(_tilt_icon)
		col.add_child(ic)
		_tilt_label = UI.label(tr("TILT_" + task.tilt.to_upper()), 11, 700, "text", false, false)
		_tilt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(_tilt_label)
		var tilt := UI.tappable(col, glass, _cycle, tr("TILT"), 14, 6)
		tilt.custom_minimum_size = Vector2(68, 56)
		add_child(tilt)
	var ring := _Shutter.new()
	ring.custom_minimum_size = Vector2(68, 68)
	var shot := UI.tappable(ring, Color(0, 0, 0, 0), func(): on_shutter.call(), tr("SHUTTER"), 34, 0)
	add_child(shot)


func _cycle() -> void:
	task.cycle_tilt()


## The button follows the camera, however its tilt changed.
func _process(_delta: float) -> void:
	if _tilt_icon and _tilt_icon.icon != "tilt_" + task.tilt:
		_tilt_icon.icon = "tilt_" + task.tilt
		_tilt_icon.queue_redraw()
		_tilt_label.text = tr("TILT_" + task.tilt.to_upper())


## A white flash over the whole view, gone in a blink.
static func flash(parent: Control) -> void:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.7)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(f)
	var t := f.create_tween()
	t.tween_property(f, "color:a", 0.0, 0.25)
	t.tween_callback(f.queue_free)


## A camera shutter button: a light ring round a light disc.
class _Shutter extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		draw_arc(c, r - 3.0, 0, TAU, 48, Pal.c("text"), 4.0, true)
		draw_circle(c, r - 10.0, Pal.c("text"), true, -1.0, true)
