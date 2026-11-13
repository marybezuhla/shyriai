# SPDX-License-Identifier: GPL-3.0-or-later
# Goes through every screen, theme, language and mode; CI fails on any script error.
# Not shipped in the APK (see export_presets.cfg). Optional screenshots: SHYRIAI_SHOTS=<dir>.
# SHYRIAI_STORE=<dir> instead takes only the 8 store screenshots per language, phone-sized.
extends Node

var shots := OS.get_environment("SHYRIAI_SHOTS")
var store := OS.get_environment("SHYRIAI_STORE")
var main: Node


func _ready() -> void:
	get_tree().create_timer(840.0).timeout.connect(func(): printerr("SMOKE TIMEOUT"); get_tree().quit(1))
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(3)
	if store != "":
		# The store pass erases progress: never let it touch a real settings file.
		if OS.get_environment("SHYRIAI_PREFS") == "":
			printerr("SHYRIAI_STORE needs SHYRIAI_PREFS pointing at a scratch file")
			get_tree().quit(1)
			return
		await _store_shots()
		get_tree().quit(0)
		return
	for lang in ["uk", "en"]:
		Prefs.set_language(lang)
		for theme in ["dusk", "day"]:
			Prefs.set_theme(theme)
			await _visit(lang, theme)
	await _big_text_and_tablet()
	Prefs.set_language("uk")
	await _flights()
	await _sticks_and_sound()
	await _sunflowers_and_free()
	await _gate()
	await _fixes_0_11()
	await _kids_0_11()
	await _check_title_fits()
	await _hud_fits()
	await preload("res://tests/smoke_steps.gd").new(self).run()
	await preload("res://tests/smoke_p3.gd").new(self).run()
	Prefs.set_language("system")
	Prefs.set_theme("dusk")
	Prefs.set_mode("simple")
	Prefs.set_kids_lock(false)
	print("SMOKE OK")
	get_tree().quit(0)


func _visit(lang: String, theme: String) -> void:
	for m in Prefs.MODES:
		Prefs.set_mode(m)
		main.open_tab("learn")
		await _shot("%s-%s-home-%s" % [lang, theme, m])
	Prefs.set_mode("simple")
	for v in Curriculum.VEHICLES:
		main.open_lessons(v)
		await _shot("%s-%s-lessons-%s" % [lang, theme, v])
		var s = main.stack.back()
		s.tab = "missions"
		s.rebuild()
		await _shot("%s-%s-lessons-%s-missions" % [lang, theme, v])
		s.tab = "learn"
		s.selected = Curriculum.lessons(v, Prefs.mode).size() - 1
		s.rebuild()
		await _frames(2)
		main.back()
	main.open_tab("missions")
	await _shot("%s-%s-missions" % [lang, theme])
	main.open_tab("theory")
	await _shot("%s-%s-theory" % [lang, theme])
	for card in Curriculum.THEORY:
		main.open_theory(card)
		await _shot("%s-%s-%s" % [lang, theme, card.to_lower()])
		# One right and one wrong answer in "Check yourself".
		var sc = main.stack.back()
		sc.picked = {"Q_%s_1" % card: "A", "Q_%s_2" % card: "B"}
		sc.rebuild()
		await _shot("%s-%s-%s-quiz" % [lang, theme, card.to_lower()])
		main.back()
	main.back()
	main.open_tab("learn")
	main.open_settings()
	await _shot("%s-%s-settings" % [lang, theme])
	main.open_about()
	await _shot("%s-%s-about" % [lang, theme])
	main.open_licenses()
	await _frames(3)
	main.back()
	main.back()
	main.back()
	await _frames(2)
	assert(main.stack.size() == 1)


## Every lesson and mission in flight, in every mode: fly a little, pause, pass, leave.
func _flights() -> void:
	var Autopilot := load("res://tests/autopilot.gd")
	# Simple mode in both looks; Kids (always Morning) and Adult once each.
	var runs := [["dusk", "simple"], ["day", "simple"], ["dusk", "kids"], ["dusk", "pro"]]
	for run in runs:
		var theme: String = run[0]
		var m: String = run[1]
		Prefs.set_theme(theme)
		Prefs.set_mode(m)
		var keys: Array = []
		for veh in Curriculum.VEHICLES:
			for k in Curriculum.lessons(veh, m) + Curriculum.missions(veh, m):
				# Every lesson and mission must have a flight: there is no "coming soon" page any more.
				assert(FlightTask.implemented(k), "a flight for " + k)
				keys.append([veh, k])
		for vk in keys:
			var veh: String = vk[0]
			var key: String = vk[1]
			main.start(veh, key)
			await _frames(2)
			var f = main.flight
			assert(f != null)
			var ap = Autopilot.new()
			if f.sim is FpvSim:
				ap = load("res://tests/fpv_autopilot.gd").new()
			elif f.sim is UgvSim:
				ap = load("res://tests/ugv_autopilot.gd").new()
			if f.sim is WingSim:
				# The plane flies on, level, towards the far end of the valley.
				ap = load("res://tests/wing_autopilot.gd").new()
				ap.target = f.sim.pos + Vector3(0, 0, -200)
			else:
				ap.height = 3.0
				ap.target = f.world.hold_mark
			if key == "MIS_CAM_KITTEN":
				ap.target = f.world.kitten.lerp(f.world.pad, 0.6)
			f.autopilot = func(sim, _task): return ap.sticks(sim)
			await _seconds(1.5)
			await _shot("uk-%s-flight-%s-%s" % [theme, m, key])
			await _flight_extras(f, theme, m, key)
			if key == "MIS_CAM_SURVEY":
				await _survey_report(f, theme, m, key)
				continue
			f.pause()
			await _shot("uk-%s-flight-%s-%s-pause" % [theme, m, key])
			main.back()  # Back on pause leaves; Back in flight only pauses
			await _frames(2)
			assert(main.flight == null)
			main.start(veh, key)
			await _frames(2)
			f = main.flight
			assert(f != null)
			f.task.pass_with("SUM_STICKS")
			await _frames(3)
			await _shot("uk-%s-flight-%s-%s-passed" % [theme, m, key])
			main.back()  # Back on the "Passed" card leaves the flight
			await _frames(2)
			assert(main.flight == null)
	await _failed_and_crashed()


## The other views, the lost link and the camera buttons, where a flight has them.
func _flight_extras(f, theme: String, m: String, key: String) -> void:
	if key == "FPV_GATES":
		for v in ["chase", "pilot", "fpv"]:
			f.set_view(v)
			await _shot("uk-%s-flight-%s-%s-%s" % [theme, m, key, v])
	if key == "UGV_EVACUATION":
		for v in ["chase", "pilot", "ugv"]:
			f.set_view(v)
			await _shot("uk-%s-flight-%s-%s-%s" % [theme, m, key, v])
	if key == "MIS_UGV_EVAC":
		f._paused = true
		f.task.link_ok = false
		f.task.say("HINT_LINK_LOST")
		await _shot("uk-%s-flight-%s-%s-nolink" % [theme, m, key])
		f.task.link_ok = true
		f._paused = false
	if key == "CAM_HOLD":
		for v in ["chase", "drone", "pilot"]:
			f.set_view(v)
			await _shot("uk-%s-flight-%s-%s-%s" % [theme, m, key, v])
	if f.task is PhotoTask and f.task.kit:
		# The camera buttons: each tilt, then a picture (refused or kept, either way no error).
		for t in Photo.TILT_ORDER:
			f.task.tilt = t
			await _shot("uk-%s-flight-%s-%s-tilt-%s" % [theme, m, key, t])
		f.shutter()
		await _frames(3)


## The report after landing, with a real picture taken from the drone's camera.
func _survey_report(f, theme: String, m: String, key: String) -> void:
	f.autopilot = Callable()
	f.sim.pos = f.world.houses[0]["pos"] + Vector3(0, 12, 0)
	f.sim.on_ground = false
	f.task.tilt = "down"
	var shot: Dictionary = {"photo": 0, "prompt": "Q_ROOF", "answer": "ok",
		"options": [["damaged", "OPT_DAMAGED"], ["ok", "OPT_INTACT"]]}
	f.task.photos.append({"id": "0", "image": await f._picture()})
	f.task.report.assign([shot, shot.duplicate()])
	f.task.photos.append({"id": "1", "image": null})
	f.task.report[1]["photo"] = 1
	f.task.report_open = true
	await _frames(3)
	await _shot("uk-%s-flight-%s-%s-report" % [theme, m, key])
	f.report_answer(0, "damaged")
	f.report_answer(1, "ok")
	await _frames(4)
	await _shot("uk-%s-flight-%s-%s-report-result" % [theme, m, key])
	main.close_flight()
	await _frames(2)


## A failed exam in Simple mode and a crash in Adult mode.
func _failed_and_crashed() -> void:
	# A failed exam, in Simple mode.
	Prefs.set_theme("dusk")
	Prefs.set_mode("simple")
	main.start("camera", "CAM_EXAM")
	await _frames(2)
	main.flight.task.fail_with("FAIL_EXAM_BUMP")
	await _frames(3)
	await _shot("uk-dusk-flight-simple-failed")
	main.back()
	await _frames(2)
	assert(main.flight == null)
	# A crash, in Adult mode.
	Prefs.set_mode("pro")
	main.start("camera", "CAM_STICKS")
	await _frames(2)
	main.flight.sim._crash(4.2)
	await _frames(3)
	await _shot("uk-dusk-flight-pro-crashed")
	main.close_flight()
	await _frames(2)


## After the flights every lesson has sunflowers and every vehicle a licence: the lessons, the free
## flight tab, the licences and a free flight, in each mode and both languages.
func _sunflowers_and_free() -> void:
	Prefs.set_theme("day")
	Prefs.set_pilot_name("Оля Петренко")
	for lang in ["uk", "en"]:
		Prefs.set_language(lang)
		for m in Prefs.MODES:
			Prefs.set_mode(m)
			# The flights above pass each lesson by hand: grade a few so all three looks show.
			var lessons := Curriculum.lessons("camera", m)
			for i in lessons.size():
				Prefs.mark_passed("camera", i)
				Prefs.record(lessons[i], 1 + i % 3, 999.0)
			main.open_tab("learn")
			await _shot("%s-day-home-%s-cards" % [lang, m])
			main.open_lessons("camera")
			await _shot("%s-day-lessons-camera-%s-flowers" % [lang, m])
			var s = main.stack.back()
			for v in Curriculum.VEHICLES:
				s.vehicle = v
				s.tab = "free"
				s.rebuild()
				await _shot("%s-day-free-%s-%s" % [lang, m, v])
			main.back()
			main.open_pilot_cards()
			await _shot("%s-day-cards-%s" % [lang, m])
			main.back()
			await _frames(2)
	Prefs.set_language("uk")
	Prefs.set_text_size("larger")
	Prefs.set_mode("pro")
	main.open_pilot_cards()
	await _shot("uk-larger-cards-pro")
	main.back()
	main.open_lessons("fpv")
	main.stack.back().tab = "free"
	main.stack.back().rebuild()
	await _shot("uk-larger-free-pro-fpv")
	main.back()
	Prefs.set_text_size("normal")
	for weather in ["fog", "winter"]:
		Prefs.set_free("time", weather)
		main.start("camera", "FREE_CAMERA")
		await _frames(2)
		await _seconds(1.0)
		await _shot("uk-%s-flight-free-camera" % weather)
		main.close_flight()
		await _frames(2)
	for v in Curriculum.VEHICLES:
		Prefs.set_free("time", "dusk")
		main.start(v, "FREE_" + v.to_upper())
		await _frames(2)
		assert(main.flight.task.is_free)
		await _seconds(1.0)
		await _shot("uk-dusk-flight-free-%s" % v)
		main.close_flight()
		await _frames(2)
	# A pass shows the sunflowers card.
	main.start("camera", "CAM_TAKEOFF")
	await _frames(2)
	main.flight._touches = 1
	main.flight.task.pass_with("SUM_STICKS")
	await _frames(3)
	await _shot("uk-day-flight-pro-passed-one-flower")
	main.close_flight()
	await _frames(2)
	Prefs.set_free("time", "day")
	Prefs.set_mode("simple")


## Mode 1 moves the throttle to the right stick (drones, not kids or the robot); soft sticks keep full
## deflection; every sound can be made; with sound off nothing is played.
func _sticks_and_sound() -> void:
	for n in ["drone", "fpv", "ugv", "chime", "blip", "fail", "beep", "thud"]:
		var w := FlightSound._make(n)
		assert(w.data.size() > 1000, n)
	Prefs.set_mode("pro")
	Prefs.set_stick_mode("1")
	assert(Curriculum.text_key("FPV_THROTTLE_GOAL", "pro") == "FPV_THROTTLE_GOAL_M1")
	assert(Curriculum.text_key("FPV_THROTTLE_GOAL", "kids") != "FPV_THROTTLE_GOAL_M1")
	main.start("fpv", "FPV_THROTTLE")
	await _frames(2)
	var f = main.flight
	assert(f._thr == f._right and f._fwd == f._left)
	assert(not f._right.spring_y and f._left.spring_y)
	f._right.value = Vector2(0.0, 0.4)
	f._left.value = Vector2(0.0, 0.7)
	f._read_sticks()
	assert(is_equal_approx(f._sticks["throttle"], 0.4) and is_equal_approx(f._sticks["pitch"], 0.7))
	assert(f._sound._motor != null)
	await _shot("uk-dusk-flight-pro-mode1")
	main.close_flight()
	await _frames(2)
	main.start("ugv", "UGV_DRIVE")
	await _frames(2)
	assert(not main.flight._mode1)
	main.close_flight()
	await _frames(2)
	Prefs.set_mode("kids")
	main.start("camera", "CAM_STICKS")
	await _frames(2)
	assert(not main.flight._mode1)
	main.close_flight()
	await _frames(2)
	Prefs.set_mode("pro")
	Prefs.set_stick_mode("2")
	Prefs.set_stick_feel("softer")
	main.start("camera", "CAM_STICKS")
	await _frames(2)
	f = main.flight
	f._right.value = Vector2(1.0, 0.5)
	f._read_sticks()
	assert(is_equal_approx(f._sticks["roll"], 1.0) and f._sticks["pitch"] < 0.5)
	main.close_flight()
	await _frames(2)
	Prefs.set_stick_feel("normal")
	Prefs.set_sound(false)
	main.start("camera", "CAM_STICKS")
	await _frames(2)
	assert(main.flight._sound._motor == null)
	main.close_flight()
	await _frames(2)
	Prefs.set_sound(true)
	Prefs.set_mode("simple")


## The grown-ups' lock in Kids mode: a wrong answer, then the right one.
func _gate() -> void:
	Prefs.set_mode("kids")
	Prefs.set_kids_lock(true)
	main.open_tab("learn")
	await _shot("uk-morning-home-kids")
	var opened := [false]
	main.guard(func(): opened[0] = true)
	await _frames(2)
	var g = main._gate
	assert(g != null and not opened[0])
	await _shot("uk-morning-gate")
	g._press("1")
	g._press("OK")
	await _frames(1)
	assert(not opened[0])
	for ch in str(g._a * g._b):
		g._press(ch)
	g._press("OK")
	await _frames(2)
	assert(opened[0])
	main.open_settings()
	await _shot("uk-morning-settings")
	main.back()
	main.open_tab("theory")
	main.open_theory("TH_RULES")
	await _shot("uk-morning-th_rules")
	main.back()
	main.open_tab("learn")
	main.open_settings()
	main.back()
	Prefs.set_kids_lock(false)
	# Start a mode over, then erase everything, through the settings screen; Undo puts it all back.
	Prefs.set_mode("simple")
	Prefs.mark_passed("camera", 0)
	var before: Dictionary = Prefs._data()
	main.open_settings()
	var st = main.stack.back()
	st._confirm = "mode"
	st.rebuild()
	await _shot("uk-dusk-settings-reset-ask")
	st.confirm_erase()
	await _shot("uk-dusk-settings-reset-done")
	assert(Prefs.passed_count("camera") == 0 and Prefs.undo_kind() == "mode")
	Prefs.undo_reset()
	assert(Prefs._data() == before)
	st._confirm = "all"
	st.rebuild()
	await _shot("uk-dusk-settings-erase-ask")
	st.confirm_erase()
	await _shot("uk-dusk-settings-erase-done")
	assert(Prefs.passed_count("camera") == 0 and Prefs.undo_kind() == "all")
	Prefs.undo_reset()
	assert(Prefs._data() == before)
	# Changing any setting after an erase makes its Undo go away instead of reverting the change.
	Prefs.erase_all()
	Prefs.set_text_size("large")
	assert(Prefs.undo_kind() == "")
	Prefs._apply(before)
	Prefs._apply_theme()
	assert(Prefs._data() == before)
	st.rebuild()
	main.back()


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name_: String) -> void:
	await _frames(4)
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	# Menus draw only on change (low-processor mode): make sure this frame is drawn.
	var low := OS.low_processor_usage_mode
	OS.low_processor_usage_mode = false
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(name_ + ".png"))
	OS.low_processor_usage_mode = low


## The 8 screenshots for the app pages (F-Droid, Komora), most important first,
## with made-up progress only.
func _store_shots() -> void:
	get_window().size = Vector2i(1080, 2337)
	for lang in [["uk", "uk"], ["en", "en-US"]]:
		Prefs.erase_all()
		Prefs.set_language(lang[0])
		# A pilot a few days in: sunflowers on the first lessons, a name on the licence.
		var lessons := Curriculum.lessons("camera", "simple")
		for i in 5:
			Prefs.mark_passed("camera", i)
			Prefs.record(lessons[i], [3, 3, 2, 3, 1][i], Rating.par(lessons[i], "simple") * 0.8)
		Prefs.mark_passed("fpv", 0)
		Prefs.record(Curriculum.lessons("fpv", "simple")[0], 2, 30.0)
		var dir: String = store.path_join(lang[1])
		DirAccess.make_dir_recursive_absolute(dir)
		Prefs.set_theme("day")
		Prefs.set_mode("simple")
		main.open_tab("learn")
		await _store(dir, "01_home")
		await _store_flight(dir, "02_camera", "camera", "CAM_SQUARE", "chase", Vector3(-3.0, 4.0, -9.0))
		Prefs.set_mode("kids")
		main.open_tab("learn")
		await _store(dir, "03_kids")
		Prefs.set_mode("simple")
		main.open_lessons("camera")
		await _store(dir, "04_lessons")
		main.back()
		await _store_flight(dir, "05_fpv", "fpv", "FPV_GATES", "fpv", Vector3(0.0, 2.5, -6.0))
		Prefs.set_theme("dusk")
		main.open_tab("learn")
		await _store(dir, "06_home_dusk")
		main.open_settings()
		await _store(dir, "07_settings")
		main.back()
		main.open_about()
		await _store(dir, "08_about")
		main.back()
	Prefs.erase_all()


func _store(dir: String, name_: String) -> void:
	await _frames(6)
	# Menus draw only on change (low-processor mode): make sure this frame is drawn.
	var low := OS.low_processor_usage_mode
	OS.low_processor_usage_mode = false
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name_ + ".png"))
	OS.low_processor_usage_mode = low


func _store_flight(dir: String, name_: String, vehicle: String, key: String, view: String, at: Vector3) -> void:
	Prefs.set_view(Prefs.mode, vehicle, view)
	main.start(vehicle, key)
	await _frames(3)
	var f = main.flight
	f.sim.place(at, 0.0)
	# An FPV drone does not hold height by itself: shoot it before it sinks.
	await _frames(30 if vehicle == "camera" else 4)
	await _store(dir, name_)
	main.back()
	main.back()
	await _frames(2)


## The largest text on a phone, and a tablet: nothing may be cut off.
func _big_text_and_tablet() -> void:
	Prefs.set_language("uk")
	Prefs.set_theme("day")
	Prefs.set_text_size("larger")
	for m in Prefs.MODES:
		Prefs.set_mode(m)
		main.open_tab("learn")
		await _shot("uk-larger-home-%s" % m)
		main.open_lessons("fpv")
		await _shot("uk-larger-lessons-fpv-%s" % m)
		main.back()
	Prefs.set_mode("simple")
	main.open_settings()
	await _shot("uk-larger-settings")
	main.back()
	Prefs.set_text_size("normal")
	if DisplayServer.get_name() != "headless":
		var phone := get_window().size
		get_window().size = Vector2i(1200, 1600)
		main.open_tab("learn")
		await _shot("uk-tablet-home")
		main.open_lessons("camera")
		await _shot("uk-tablet-lessons")
		main.back()
		get_window().size = phone


## Bugs found before 1.0, each with the check that would have caught it.
func _fixes_0_11() -> void:
	Prefs.erase_all()
	Prefs.set_mode("simple")
	# Back while the name field has focus leaves the licence screen at once, no errors.
	main.open_pilot_cards()
	await _frames(2)
	var depth: int = main.stack.size()
	var fields: Array = main.stack.back().find_children("*", "LineEdit", true, false)
	assert(fields.size() == 1)
	(fields[0] as LineEdit).grab_focus()
	await _frames(1)
	main.back()
	await _frames(3)
	assert(main.stack.size() == depth - 1, "one Back leaves the licence screen")
	# After a pass the lesson card moves on to the next lesson.
	main.open_lessons("camera")
	await _frames(1)
	var s = main.stack.back()
	assert(s.selected == 0)
	Prefs.mark_passed("camera", 0)
	s.rebuild()
	assert(s.selected == 1, "the card follows the pilot to the next lesson")
	main.back()
	# A finished course is not offered to continue.
	for i in Curriculum.lessons("camera", "simple").size():
		Prefs.mark_passed("camera", i)
	assert(load("res://scripts/screens/home.gd").continue_vehicle() != "camera", "continue offers an unfinished course")
	# The photo report stops the clock and the battery.
	Prefs.set_mode("pro")
	main.start("survey", "SRV_DETAIL")
	await _frames(2)
	var f = main.flight
	f.task.photos.append({"id": "number", "image": null})
	f.task.on_photo("number", f.sim)
	assert(f.task.report_open)
	await _frames(2)
	var t0: float = f.sim.time
	var b0: float = f.sim.battery
	await _seconds(1.0)
	assert(f.sim.time == t0 and f.sim.battery == b0, "time stands still while the report is open")
	main.close_flight()
	await _frames(2)
	Prefs.erase_all()


## Kids mode before 1.0: no war letter or defence fundraisers, no lesson numbers; the lock waits.
func _kids_0_11() -> void:
	Prefs.erase_all()
	Prefs.set_language("uk")
	Prefs.set_mode("kids")
	main.open_about()
	await _shot("uk-morning-about-kids")
	var texts := _texts(main.stack.back())
	assert(not texts.has(tr("LETTER_4")) and not texts.has(tr("ORG_NBU")), "kids see no war letter or army account")
	assert(texts.has(tr("ORG_REDCROSS")), "kids still see humanitarian help")
	main.back()
	main.open_lessons("ugv")
	await _shot("uk-morning-lessons-ugv-kids")
	texts = _texts(main.stack.back())
	for t in texts:
		assert(not RegEx.create_from_string("\\d").search(t), "no numbers on the kids lessons screen: " + t)
	main.back()
	# Three wrong answers and the lock waits before the next try.
	Prefs.set_kids_lock(true)
	var opened := [false]
	main.guard(func(): opened[0] = true)
	await _frames(2)
	var g = main._gate
	for i in 3:
		g._press("1")
		g._press("OK")
	assert(g._wait_until > 0, "three misses and the lock waits")
	for ch in str(g._a * g._b):
		g._press(ch)
	g._press("OK")
	await _frames(1)
	assert(not opened[0], "no answer counts while it waits")
	await _shot("uk-morning-gate-wait")
	g.close()
	# Closing and reopening does not skip the wait.
	main.guard(func(): opened[0] = true)
	await _frames(2)
	g = main._gate
	for ch in str(g._a * g._b):
		g._press(ch)
	g._press("OK")
	await _frames(1)
	assert(not opened[0], "reopening the lock does not skip the wait")
	g.close()
	Gate._wait_until = 0
	Gate._misses = 0
	Prefs.set_kids_lock(false)
	Prefs.erase_all()


func _texts(n: Node) -> Array:
	var out := []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


## The longest one-word title still fits at the largest text size.
func _check_title_fits() -> void:
	Prefs.set_language("uk")
	Prefs.set_text_size("larger")
	main.open_settings()
	await _frames(2)
	var title: Label = main.stack.back().find_children("*", "Label", true, false)[0]
	assert(title.get_line_count() == 1, "the settings title stays one word on one line")
	main.back()
	Prefs.set_text_size("normal")


## The flight's controls stay on the screen on every phone shape, with the largest text, with the
## camera or drop buttons, and when the screen turns or unfolds in the middle of a flight.
func _hud_fits() -> void:
	var was := get_window().size
	Prefs.set_language("uk")
	Prefs.set_mode("pro")
	var shapes := [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(2400, 1080), Vector2i(1800, 2200), Vector2i(800, 360)]
	for size in ["normal", "larger"]:
		Prefs.set_text_size(size)
		for key in [["camera", "CAM_SQUARE"], ["survey", "SRV_TILT"], ["camera", "MIS_CAM_MEDS"], ["wing", "WING_CIRCUIT"], ["ugv", "UGV_DRIVE"]]:
			get_window().size = shapes[0]
			main.start(key[0], key[1])
			await _frames(3)
			for shape in shapes:
				get_window().size = shape  # turning or unfolding mid-flight
				await _frames(3)
				var screen := get_viewport().get_visible_rect().grow(1.0)
				for c in main.flight._hud.find_children("*", "Control", true, false):
					var ctl := c as Control
					if ctl.is_visible_in_tree() and ctl.size != Vector2.ZERO and ctl != main.flight._marks:
						assert(screen.encloses(ctl.get_global_rect()), "%s %s %s: %s is off the screen at %s" % [size, key[1], shape, ctl.get_class(), ctl.get_global_rect()])
			main.close_flight()
			await _frames(2)
	Prefs.set_text_size("normal")
	get_window().size = was
	await _frames(2)
