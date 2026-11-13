# SPDX-License-Identifier: GPL-3.0-or-later
# Smoke checks for package 3: the plane's air speed, wind and windsock, the camera drone's way home,
# FPV arming and the OSD, the robot's inclinometer, and the radio and gamepad settings.
# Run from smoke.gd; `s` is that test node. Not shipped in the APK.
extends RefCounted

var s: Node
var main: Node


func _init(smoke: Node) -> void:
	s = smoke
	main = smoke.main


func run() -> void:
	# A phone held sideways, wide enough for every number: without a display the window is portrait.
	var was: Vector2i = s.get_window().size
	s.get_window().size = Vector2i(1688, 780)
	Prefs.set_language("uk")
	Prefs.set_mode("pro")
	await _flight("wing", "WING_INTO_WIND", ["AIRSPEED", "WIND"], "uk-dusk-flight-wing-into-wind")
	assert(main.flight != null)
	await _flight("camera", "MIS_CAM_LINK", ["VERT", "HOME"], "uk-dusk-flight-camera-home")
	assert(s._texts(main.flight).has(s.tr("RTH")), "Adult camera drones have a Home button")
	main.flight.sim.on_ground = false
	main.flight.sim.pos.y = 10.0
	main.flight._waiting = false
	main.flight.sim.battery = 0.25
	await s._seconds(0.3)
	assert(s._texts(main.flight).has(s.tr("HINT_BATTERY_30")), "a 30 % battery warning shows")
	await s._shot("uk-dusk-flight-camera-battery")
	main.close_flight()
	Prefs.set_view("pro", "fpv", "fpv")
	await _flight("fpv", "FPV_THROTTLE", [], "uk-dusk-flight-fpv-disarmed")
	assert(s._texts(main.flight).has(s.tr("ARM")), "Adult FPV has an Arm button")
	main.flight._thr.value.y = -1.0
	main.flight._toggle_arm()
	await s._frames(2)
	assert(main.flight.sim.armed, "throttle down and the button arms the FPV drone")
	main.close_flight()
	await _flight("ugv", "UGV_TERRAIN", ["LEAN"], "uk-dusk-flight-ugv-lean")
	main.close_flight()
	main.open_lessons("fpv")
	var screen = main.stack.back()
	screen.tab = "missions"
	screen.rebuild()
	await s._frames(2)
	assert(s._texts(screen).has(s.tr("FPV_MISSION_MODE").to_upper()), "Adult FPV missions offer a flight mode")
	main.back()
	main.open_settings()
	await s._frames(2)
	assert(s._texts(main.stack.back()).has(s.tr("SET_FPV").to_upper()), "settings have the FPV choices")
	await s._shot("uk-dusk-settings-fpv")
	main.open_pad()
	await s._frames(2)
	assert(s._texts(main.stack.back()).has(s.tr("PAD_CHECK")), "the radio settings open")
	await s._shot("uk-dusk-pad")
	main.stack.back()._learn("throttle")
	await s._frames(2)
	assert(s._texts(main.stack.back()).has(s.tr("PAD_MOVE_UP")), "learning a stick asks to move it")
	await s._shot("uk-dusk-pad-learning")
	main.back()
	main.back()
	Prefs.set_mode("simple")
	s.get_window().size = was


func _flight(vehicle: String, key: String, words: Array, shot: String) -> void:
	main.start(vehicle, key)
	await s._seconds(0.2)
	for w in words:
		assert(main.flight._stats.has(w), "%s shows %s" % [key, w])
	await s._shot(shot)
