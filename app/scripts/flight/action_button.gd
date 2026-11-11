# SPDX-License-Identifier: GPL-3.0-or-later
# A round button beside the right stick for a task's own action, e.g. "Drop" for the aid kit. The task
# names the action (a translation key, "" hides the button) and does it in act().
class_name ActionButton
extends VBoxContainer

var task: FlightTask
var sim: DroneSim
var _label: Label
var _tap: Control
var _shown := ""


func build(task_: FlightTask, sim_: DroneSim) -> void:
	task = task_
	sim = sim_
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(76, 76)
	_label = UI.label("", 13, 800, "on_accent", false, false)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(_label)
	_tap = UI.tappable(c, Pal.c("accent"), func(): task.act(sim), "", 38, 0)
	add_child(_tap)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if task.action == _shown:
		return
	_shown = task.action
	visible = _shown != ""
	_label.text = tr(_shown) if _shown != "" else ""
	# TalkBack and switch access read the same words the button shows.
	_tap.get_child(1).set("accessibility_name", _label.text)
