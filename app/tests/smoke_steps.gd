# SPDX-License-Identifier: GPL-3.0-or-later
# Smoke checks for the first steps: the first-run question, the welcome on the home screen, the
# flight that waits for the first stick move, tips and practice after three failed tries, the
# crash card's safe speed, kids' help, the plane's stick names and the glossary.
# Run from smoke.gd; `s` is that test node. Not shipped in the APK.
extends RefCounted

var s: Node
var main: Node


func _init(smoke: Node) -> void:
	s = smoke
	main = smoke.main


func run() -> void:
	await _first_run()
	await _home_for_a_new_pilot()
	await _flight_waits_for_the_sticks()
	await _three_tries()
	await _crash_card()
	await _kids_help()
	await _plane_sticks()
	await _glossary()
	Prefs.erase_all()
	Prefs.welcome(false)


## A fresh install asks who will play, with no tabs under the question.
func _first_run() -> void:
	Prefs.erase_all()
	Prefs.set_language("uk")
	main._open_welcome()
	await s._frames(2)
	assert(String(main.stack.back().get_script().resource_path).ends_with("welcome.gd"), "a fresh install asks who will play")
	assert(not main._nav.visible, "no tabs under the first question")
	await s._shot("uk-dusk-welcome")
	main.welcome(true)
	await s._frames(2)
	assert(Prefs.mode == "kids" and Prefs.kids_lock and Prefs.welcomed, "a child gets Kids mode with the lock")
	assert(main._nav.visible, "the tabs are back after the answer")
	main.welcome(false)
	assert(Prefs.mode == "simple" and not Prefs.kids_lock, "a grown-up gets Simple mode, no lock")


## Nothing flown yet: a welcome, the first course marked as the start, hints on the others, and the
## yellow card opens the first lesson itself.
func _home_for_a_new_pilot() -> void:
	main.open_tab("learn")
	await s._frames(2)
	await s._shot("uk-dusk-home-new")
	var texts: Array = s._texts(main.stack.back())
	assert(texts.has(s.tr("HOME_HELLO")), "a new pilot is welcomed")
	assert(texts.has(s.tr("HOME_AFTER") % s.tr("VEH_CAMERA")), "later courses say what goes first")
	var lessons := Curriculum.lessons("camera", "simple")
	main.start("camera", lessons[0])
	await s._frames(2)
	assert(main.flight != null and main.flight.task_key == lessons[0])
	main.close_flight()
	Prefs.mark_passed("camera", 0)
	main.open_tab("learn")
	await s._frames(2)
	texts = s._texts(main.stack.back())
	assert(not texts.has(s.tr("HOME_HELLO")), "the welcome goes once something is passed")


## Nothing moves and no time counts until a stick is moved.
func _flight_waits_for_the_sticks() -> void:
	main.start("camera", "CAM_TAKEOFF")
	await s._frames(20)
	var f = main.flight
	assert(f._waiting and f.sim.time == 0.0, "the clock waits for the first stick move")
	assert(f._hint.text != "", "a hint says how to start")
	await s._shot("uk-dusk-flight-waiting")
	f._thr.value.y = 0.8
	await s._frames(10)
	assert(not f._waiting and f.sim.time > 0.0, "the first stick move starts the clock")
	main.close_flight()
	await s._frames(2)


## The third failed try in a row brings a tip and practice; a practice pass saves nothing.
func _three_tries() -> void:
	main.fails.clear()
	for i in 3:
		main.start("camera", "CAM_EXAM")
		await s._frames(2)
		main.flight.task.fail_with("FAIL_EXAM_BUMP")
		await s._frames(3)
		var texts: Array = s._texts(main.flight._overlay)
		assert(texts.has(s.tr("PRACTICE")) == (i == 2), "practice is offered on the third try only")
	await s._shot("uk-dusk-flight-third-try")
	main.open_flight("camera", "CAM_EXAM", 7, true)
	await s._frames(2)
	var f = main.flight
	assert(f.practice and not f._stats.has("TIME"), "practice has no clock")
	var before := Prefs.passed_count("camera")
	f.task.pass_with("SUM_CAM_EXAM", [60])
	await s._frames(3)
	assert(s._texts(f._overlay).has(s.tr("PRACTICE_DONE")), "a practice pass says so")
	assert(Prefs.passed_count("camera") == before and Prefs.best_of("CAM_EXAM").is_empty(), "practice saves nothing")
	await s._shot("uk-dusk-flight-practice-done")
	main.close_flight()
	main.fails.clear()


## Adult crash cards say what speed is safe for that kind of crash.
func _crash_card() -> void:
	Prefs.set_mode("pro")
	for c in [["camera", "CAM_STICKS", "ground", "CRASHED_SAFE_GROUND"], ["wing", "WING_LEVEL", "wingtip", "CRASHED_SAFE_WINGTIP"]]:
		main.start(c[0], c[1])
		await s._frames(2)
		main.flight.sim._crash(4.2, c[2])
		await s._frames(3)
		var want: String = s.tr(c[3])
		if want.contains("%"):
			want = want % FlightTask.num(float(main.flight.sim.p.get("crash_fall", DroneSim.CRASH_FALL)))
		assert(s._texts(main.flight._overlay).has(want), "the crash card says what is safe: " + c[3])
		await s._shot("uk-dusk-flight-crash-" + c[2])
		main.close_flight()
	Prefs.set_mode("simple")


## A child stuck for a while is told to follow the gold mark.
func _kids_help() -> void:
	Prefs.set_mode("kids")
	main.start("camera", "CAM_HOLD")
	await s._frames(3)
	var f = main.flight
	f._waiting = false
	f._stuck = Flight.KIDS_HELP_AFTER + 1.0
	await s._frames(2)
	assert(f.task.marker == Vector3.INF or f._hint.text == s.tr("HINT_KIDS_HELP"), "a stuck child gets help")
	main.close_flight()
	Prefs.set_mode("simple")


## The plane's sticks are named for what they do on a plane, in every mode.
func _plane_sticks() -> void:
	for m in [["simple", "STICK_RIGHT_WING"], ["kids", "STICK_RIGHT_WING_KIDS"]]:
		Prefs.set_mode(m[0])
		main.start("wing", Curriculum.lessons("wing", m[0])[0])
		await s._frames(3)
		assert(s._texts(main.flight).has(s.tr(m[1])), "plane stick label in %s mode" % m[0])
		await s._shot("uk-dusk-flight-wing-sticks-" + m[0])
		main.close_flight()
	Prefs.set_mode("simple")


func _glossary() -> void:
	main.open_tab("theory")
	await s._frames(2)
	assert(s._texts(main.stack.back()).has(s.tr("GLOSSARY")), "the theory tab has the glossary")
	main.open_glossary()
	await s._frames(2)
	assert(s._texts(main.stack.back()).has(s.tr("GL_STALL_T")), "the glossary lists the words")
	await s._shot("uk-dusk-glossary")
	main.back()
	Prefs.set_mode("kids")
	main.open_tab("theory")
	await s._frames(2)
	assert(not s._texts(main.stack.back()).has(s.tr("GLOSSARY")), "kids have no glossary")
	Prefs.set_mode("simple")
	main.open_tab("learn")
