# SPDX-License-Identifier: GPL-3.0-or-later
# The cards over a flight: pause, passed (with sunflowers), crashed, not this time. Built here so the
# flight screen keeps to flying; `f` is that flight screen.
class_name FlightCards
extends RefCounted


static func pause(f) -> Control:
	var col := UI.vbox(12)
	col.add_child(UI.label(f.tr("PAUSE"), UI.TITLE, 600, "text", true))
	col.add_child(UI.primary(f.tr("RESUME"), f.resume, "play"))
	col.add_child(secondary(f.tr("RESTART"), f.restart))
	col.add_child(secondary(f.tr("EXIT"), f.leave))
	return col


static func passed(f, got: int, before: Dictionary, next: String) -> Control:
	var col := UI.vbox(12)
	col.add_child(UI.label(f.tr("PASSED_KIDS") if f.mode == "kids" else f.tr("PASSED"), UI.TITLE_L, 600, "text", true))
	col.add_child(rating(f, got, before))
	if f.task.summary != "":
		col.add_child(UI.label(summary(f), UI.BODY, 500, "muted"))
	if f.task is PhotoTask and not f.task.wrong.is_empty():
		col.add_child(Report.mistakes(f, f.task))
	if next != "":
		col.add_child(UI.primary(f.tr("NEXT_LESSON"), func(): f.app.open_flight(f.vehicle, next), "play"))
	else:
		col.add_child(UI.primary(f.tr("DONE"), f.leave, "check"))
	# Side by side, so the card fits a phone held sideways.
	var pair := UI.hbox(10)
	var buttons := [secondary(f.tr("AGAIN"), f.restart)]
	if next != "":
		buttons.append(secondary(f.tr("EXIT"), f.leave))
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pair.add_child(b)
	col.add_child(pair)
	return col


## Sunflowers for this pass, the time against the best one, and what earns the next sunflower.
static func rating(f, got: int, before: Dictionary) -> Control:
	var box := UI.vbox(6)
	var row := UI.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in Rating.MAX:
		var on := i < got
		row.add_child(Glyph.make("sunflower" if on else "sunflower_off", 40, Pal.c("accent" if on else "line")))
	box.add_child(row)
	# Kids see no numbers: the sunflowers and the tip say it all.
	if f.mode != "kids":
		var t := FlightTask.clock(f.sim.time)
		var line := ""
		if before.is_empty():
			line = f.tr("RESULT_FIRST") % t
		elif f.sim.time < float(before["t"]):
			line = f.tr("RESULT_RECORD") % t
		else:
			line = f.tr("RESULT_TIME") % [t, FlightTask.clock(float(Prefs.best_of(f.task_key)["t"]))]
		box.add_child(UI.label(line, UI.BODY, 600, "text", false, false))
	var tip := Rating.next_tip(f.task_key, f.mode, got)
	if tip[0] != "":
		var s: String = f.tr(tip[0])
		if not tip[1].is_empty():
			s = s % tip[1]
		box.add_child(UI.label(s, UI.SMALL, 500, "muted"))
	return box


## Tries in a row that did not pass before a tip and practice are offered.
const STREAK := 3


static func crashed(f, streak := 0) -> Control:
	var col := UI.vbox(12)
	if f.sim is UgvSim:
		col.add_child(UI.label(f.tr("CRASHED_UGV"), UI.TITLE_L, 600, "text", true))
		var tipped := false
		for e in f.sim.events:
			tipped = tipped or e["type"] == "tipped"
		var why: String = f.tr("CRASHED_UGV_TIP") if tipped else f.tr("CRASHED_UGV_HIT")
		var speed: float = f.sim.crash_speed
		col.add_child(UI.label(why % (FlightTask.num(speed, 0) if tipped else FlightTask.num(speed)), UI.BODY, 500, "muted"))
	else:
		col.add_child(UI.label(f.tr("CRASHED_WING" if f.sim is WingSim else "CRASHED"), UI.TITLE_L, 600, "text", true))
		col.add_child(UI.label(f.tr("CRASHED_TEXT") % FlightTask.num(f.sim.crash_speed), UI.BODY, 500, "muted"))
		col.add_child(_tip_box(safe_speed(f)))
	_retry_buttons(f, col, streak, "TIP_CRASH")
	return col


## What the machine can take without harm, as one line with a tip: for the crash card.
static func safe_speed(f) -> String:
	var kind: String = f.sim.crash_kind
	if kind == "wingtip":
		return f.tr("CRASHED_SAFE_WINGTIP")
	if kind == "obstacle":
		return f.tr("CRASHED_SAFE_HIT") % FlightTask.num(float(f.sim.p.get("crash_speed", DroneSim.CRASH_SPEED)))
	var key := "CRASHED_SAFE_GROUND_WING" if f.sim is WingSim else "CRASHED_SAFE_GROUND"
	return f.tr(key) % FlightTask.num(float(f.sim.p.get("crash_fall", DroneSim.CRASH_FALL)))


static func not_this_time(f, streak := 0) -> Control:
	var col := UI.vbox(12)
	col.add_child(UI.label(f.tr("NOT_THIS_TIME"), UI.TITLE_L, 600, "text", true))
	col.add_child(UI.label(summary(f), UI.BODY, 500, "muted"))
	if f.task is PhotoTask and not f.task.wrong.is_empty():
		col.add_child(Report.mistakes(f, f.task))
	_retry_buttons(f, col, streak, "TIP_" + String(f.task.summary))
	return col


## "Again" and "Exit"; from the third try in a row, a tip first and the offer to practise.
static func _retry_buttons(f, col: VBoxContainer, streak: int, tip: String) -> void:
	if streak >= STREAK:
		col.add_child(_tip_box(f.tr("TIP") + " " + f.tr(tip_key(tip, f.task_key, f.mode))))
	col.add_child(UI.primary(f.tr("AGAIN"), f.restart, "play"))
	if streak >= STREAK and f.mode != "kids":
		col.add_child(secondary(f.tr("PRACTICE"), func(): f.app.open_flight(f.vehicle, f.task_key, f.flight_seed, true)))
	col.add_child(secondary(f.tr("EXIT"), f.leave))


## The most fitting tip there is: for this very failure, then for the lesson, then a general one.
static func tip_key(first: String, task_key: String, mode: String) -> String:
	for t in [first, "TIP_" + task_key, "TIP_GENERIC"]:
		var key := Curriculum.text_key(t, mode)
		if String(TranslationServer.translate(key)) != key:
			return key
	return "TIP_GENERIC"


static func _tip_box(text: String) -> Control:
	var l := UI.label(text, UI.SMALL, 600, "text")
	return UI.panel(l, Pal.c("surface2"), 14, 12)


## A practice try that passed: nothing is saved, so the real try is offered next.
static func practice_done(f) -> Control:
	var col := UI.vbox(12)
	col.add_child(UI.label(f.tr("PRACTICE_DONE"), UI.TITLE_L, 600, "text", true))
	col.add_child(UI.label(f.tr("PRACTICE_DONE_TEXT"), UI.BODY, 500, "muted"))
	col.add_child(UI.primary(f.tr("PRACTICE_REAL"), func(): f.app.open_flight(f.vehicle, f.task_key, f.flight_seed), "play"))
	col.add_child(secondary(f.tr("PRACTICE_MORE"), f.restart))
	col.add_child(secondary(f.tr("EXIT"), f.leave))
	return col


static func summary(f) -> String:
	var s: String = f.tr(f.task.summary)
	if not f.task.summary_args.is_empty() and s.contains("%"):
		s = s % f.task.summary_args
	return s


static func secondary(text: String, on_press: Callable) -> Control:
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(0, 48)
	c.add_child(UI.label(text, UI.TEXT, 700, "text", false, false))
	return UI.tappable(c, Pal.c("surface2"), on_press, text, 16, 0)


## The dimmed layer with the card in the middle, scrollable when the card is taller than the screen
## (large text, a low phone).
static func overlay(content: Control, height: float) -> Control:
	var o := ColorRect.new()
	var dim := Pal.c("bg")
	dim.a = 0.55
	o.color = dim
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.add_child(scroll)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size = Vector2(0, height)
	scroll.add_child(column)
	var center := CenterContainer.new()
	column.add_child(center)
	var card := UI.panel(content, Pal.c("surface"), 22, 20)
	card.custom_minimum_size = Vector2(360, 0)
	center.add_child(card)
	return o
