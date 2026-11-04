# SPDX-License-Identifier: GPL-3.0-or-later
# Goes through every screen, theme, language and mode; CI fails on any script error.
# Not shipped in the APK (see export_presets.cfg). Optional screenshots: SHYRIAI_SHOTS=<dir>.
extends Node

var shots := OS.get_environment("SHYRIAI_SHOTS")
var main: Node


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(3)
	for lang in ["uk", "en"]:
		Prefs.set_language(lang)
		for theme in ["dusk", "day"]:
			Prefs.set_theme(theme)
			await _visit(lang, theme)
	Prefs.set_language("uk")
	await _flights()
	await _gate()
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
		s.selected = Curriculum.lessons(v).size() - 1
		s.rebuild()
		await _frames(2)
		main.back()
	main.open_tab("missions")
	await _shot("%s-%s-missions" % [lang, theme])
	main.open_tab("theory")
	await _shot("%s-%s-theory" % [lang, theme])
	main.open_soon("Test")
	await _shot("%s-%s-soon" % [lang, theme])
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
	for theme in ["dusk", "day"]:
		Prefs.set_theme(theme)
		for m in Prefs.MODES:
			Prefs.set_mode(m)
			var keys := ["CAM_STICKS", "CAM_TAKEOFF", "CAM_HOLD"]
			if m == "kids":
				keys.append("MIS_CAM_KITTEN")
			for key in keys:
				main.start("camera", key)
				await _frames(2)
				var f = main.flight
				assert(f != null)
				var ap = Autopilot.new()
				ap.height = 3.0
				ap.target = f.world.hold_mark if key != "MIS_CAM_KITTEN" else f.world.kitten.lerp(f.world.pad, 0.6)
				f.autopilot = func(sim, _task): return ap.sticks(sim)
				await _seconds(2.5)
				await _shot("uk-%s-flight-%s-%s" % [theme, m, key])
				if key == "CAM_HOLD":
					f.set_view("chase" if f.view == "pilot" else "pilot")
					await _shot("uk-%s-flight-%s-%s-view" % [theme, m, key])
				f.pause()
				await _shot("uk-%s-flight-%s-%s-pause" % [theme, m, key])
				f.resume()
				f.task.pass_with("SUM_STICKS")
				await _frames(3)
				await _shot("uk-%s-flight-%s-%s-passed" % [theme, m, key])
				main.back()  # Back on the "Passed" card leaves the flight
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
	Prefs.set_kids_lock(false)


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(4)
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
