# SPDX-License-Identifier: GPL-3.0-or-later
# The camera drone's way home: return to home on a low battery, on a lost link and on the button,
# and the two missions where the link or the GPS goes away.
extends "res://tests/sim_wing.gd"


func test_return_home() -> void:
	var sim := DroneSim.new("pro", 3)
	sim.ground = func(_x: float, _z: float) -> float: return 0.0
	sim.place(Vector3(40, 12, -40))
	sim.on_ground = false
	var h := FlightHome.new()
	check(h.start(sim), "the Home button starts the way home")
	for i in int(60.0 / DT):
		var s := h.sticks(sim, Vector3.ZERO)
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		if not h.active:
			break
	check(sim.on_ground and not sim.crashed and FlightTask.flat_distance(sim.pos, Vector3.ZERO) < 2.0,
		"it flies home and lands on the pad (%.1f m off)" % FlightTask.flat_distance(sim.pos, Vector3.ZERO))
	var task := FlightTask.new()
	var b := DroneSim.new("pro", 3)
	b.ground = sim.ground
	b.place(Vector3(10, 10, 0))
	b.on_ground = false
	var hb := FlightHome.new()
	b.battery = 0.29
	hb.update(b, task, DT)
	check(hb.alert == "HINT_BATTERY_30" and not hb.active, "30 % battery: a warning")
	b.battery = 0.19
	hb.update(b, task, DT)
	check(hb.active, "20 % battery: home by itself")
	hb.take_back({"throttle": 0.0, "yaw": 0.0, "pitch": 0.6, "roll": 0.0}, true)
	check(not hb.active, "a stick takes control back")
	b.gps = false
	check(not hb.start(b) and hb.alert == "HINT_RTH_NO_GPS", "without GPS the drone cannot fly home")
	b.gps = true
	task.link_ok = false
	var hl := FlightHome.new()
	for i in int(2.5 / DT):
		hl.update(b, task, DT)
	check(hl.active, "a lost link: home by itself after 2 s")
	hl.take_back({"throttle": 0.0, "yaw": 0.0, "pitch": 0.6, "roll": 0.0}, false)
	check(hl.active, "while the link is down the sticks cannot stop it")


## Fly a mission as the flight screen does: the link can cut the sticks, the way home can take over.
func test_link_mission(key: String, mode: String) -> void:
	var f := _flight(key, mode)
	var task: FlightTask = f[0]
	var sim: DroneSim = f[1]
	var world: FlightWorld = f[2]
	var ap := Autopilot.new()
	var land := _lander(task, sim, world, ap, mode)
	var home := FlightHome.new()
	var ok := false
	for i in int(300.0 / DT):
		var want: Dictionary
		if task.phase == "out":
			ap.land = false
			ap.target = task.spot()
			ap.height = 10.0
			want = ap.sticks(sim)
		elif FlightTask.flat_distance(sim.pos, world.pad) > 3.0:
			ap.land = false
			ap.target = world.pad
			ap.height = 14.0
			want = ap.sticks(sim)
		else:
			want = land.call(0.0)
		# The pilot waits while the drone flies home by itself.
		if home.active and task.link_ok:
			want = {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}
		var s := task.controls(want)
		home.update(sim, task, DT)
		home.take_back(want, task.link_ok)
		if home.active:
			s = home.sticks(sim, world.pad)
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if task.done:
			_passed(task, sim)
			ok = true
			break
		if sim.crashed or task.failed:
			break
	check(ok, "%s %s flown to a pass (%s)" % [mode, key, task.hint])
	world.queue_free()
	await get_tree().process_frame


## Adult FPV: the motors start only once armed; rates and the smaller drone change the physics.
func test_fpv_setup() -> void:
	var f := FpvSim.new("pro", 3)
	f.ground = func(_x: float, _z: float) -> float: return 0.0
	f.place(Vector3.ZERO)
	f.armed = false
	run(f, 2.0, 1.0, 0.0, 0.0, 0.0)
	check(f.on_ground and f.throttle01 == 0.0, "FPV: not armed, full throttle does nothing")
	f.armed = true
	run(f, 1.0, 1.0, 0.0, 0.0, 0.0)
	check(not f.on_ground, "FPV: armed, it takes off")
	var soft := FpvSim.new("pro", 3)
	soft.configure("soft", "3in")
	check(float(soft.p["rate"]) < 400.0 and float(soft.p["thrust"]) < 2.5, "FPV: soft rates and the lighter drone apply")
	var easy := FpvSim.new("simple", 3)
	easy.configure("sharp", "3in")
	check(float(easy.p["rate"]) == float(FpvSim.FPV["simple"]["rate"]), "FPV: Simple mode keeps its own gentle rates")


## What an experienced pilot asked for: home at the height the drone has, a stop when GPS goes,
## a LiPo's voltage, and one tilt limit in every direction, and a robot
## that goes over sooner sideways than along a slope.
func test_pilot_findings() -> void:
	var sim := DroneSim.new("pro", 3)
	sim.ground = func(_x: float, _z: float) -> float: return 0.0
	sim.place(Vector3(60, 30, 0))
	sim.on_ground = false
	var h := FlightHome.new()
	h.start(sim)
	var low := 99.0
	for i in int(4.0 / DT):
		var s := h.sticks(sim, Vector3.ZERO)
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		low = minf(low, sim.altitude())
	check(low > 27.0, "home keeps the height it has (lowest %.1f m)" % low)
	sim.gps = false
	h.update(sim, FlightTask.new(), DT)
	check(not h.active and h.alert == "HINT_RTH_GPS_LOST", "GPS lost on the way home: it stops")
	var f := FpvSim.new("pro", 3)
	f.battery = 1.0
	check(absf(FlightBattery.volts(f) - 16.8) < 0.01, "a full 4S pack reads 16.8 V")
	f.battery = 0.0
	check(absf(FlightBattery.volts(f) - 13.2) < 0.01, "an empty one 13.2 V")
	f.battery = 0.25
	var rest := FlightBattery.volts(f)
	f.throttle01 = 1.0
	check(FlightBattery.volts(f) < rest - 1.0, "and it sags under full throttle")
	var a := FpvSim.new("pro", 3)
	a.ground = sim.ground
	a.place(Vector3(0, 20, 0))
	a.on_ground = false
	a.armed = true
	run(a, 1.5, 0.3, 0.0, 1.0, 1.0)
	var tilt := rad_to_deg(acos(clampf(a.att.y.y, -1.0, 1.0)))
	check(tilt < float(a.p["tilt"]) + 5.0, "Angle: a stick corner tilts no more than a side (%.0f°)" % tilt)
	var u := UgvSim.new("pro", 3)
	u.tilt = Vector2(deg_to_rad(38.0), 0.0)
	check(u.tip_share() < 1.0, "the robot does not go over at 38° nose up")
	u.tilt = Vector2(0.0, deg_to_rad(34.0))
	check(u.tip_share() > 1.0, "but does at 34° sideways")


## Radio and gamepad settings are checked like everything else read from the saved file.
func test_pad_prefs() -> void:
	Prefs._apply({"pad_axes": {"throttle": {"a": 2, "inv": true}, "roll": {"a": 99, "inv": false}, "nope": {"a": 1, "inv": false}},
		"pad_buttons": {"pause": {"b": 6}, "arm": {"a": 4}, "view": {"b": -3}}, "pad_dead": "huge"})
	check(Prefs.pad_axes.keys() == ["throttle"] and int(Prefs.pad_axes["throttle"]["a"]) == 2, "only real sticks and axes are kept")
	check(Prefs.pad_buttons.has("pause") and Prefs.pad_buttons.has("arm") and not Prefs.pad_buttons.has("view"), "only real buttons and switches are kept")
	check(Prefs.pad_dead == "medium", "an unknown dead zone is ignored")
	Prefs.set_pad_axis("yaw", 3, false)
	check(int(Prefs.pad_axes["yaw"]["a"]) == 3, "a stick can be learnt")
	Prefs.reset_pad()
	check(Prefs.pad_axes.is_empty() and Prefs.pad_buttons.is_empty(), "back to the usual layout")
	check(int(FlightInput.default_axis("throttle", false)["a"]) == JOY_AXIS_LEFT_Y and int(FlightInput.default_axis("throttle", true)["a"]) == JOY_AXIS_RIGHT_Y,
		"the usual layout follows Mode 2 and Mode 1")
	Prefs.erase_all()
	# A file someone edited by hand: the rest of the settings still load.
	Prefs._apply({"welcomed": true, "theme": 1, "language": "en", "text_size": "larger", "kids_lock": true,
		"kid_pilots": [{"animal": "fox", "color": "gold"}, {"animal": "fox", "color": "gold"}, {"animal": "owl", "color": "blue"}],
		"views": {"simple/camera": "ugv", "simple/wing": "drone", "simple/fpv": "chase"}})
	check(Prefs.language == "en" and Prefs.text_size == "larger" and Prefs.kids_lock, "a theme that is a number does not lose the other settings")
	check(Prefs.kid_pilots.size() == 2, "the same animal twice is one pilot")
	check(Prefs.view_for("simple", "camera") == "pilot" and Prefs.view_for("simple", "wing") == "chase" and Prefs.view_for("simple", "fpv") == "chase",
		"a view saved for another machine is not used")
	Prefs.erase_all()


## Several children on one phone: each keeps their own Kids mode progress; nothing else changes.
func test_kid_pilots() -> void:
	Prefs.erase_all()
	Prefs.set_mode("kids")
	Prefs.mark_passed("camera", 0)
	Prefs.mark_passed("camera", 1)
	check(not KidPilots.ask() and KidPilots.count() == 1, "one child: no one is asked")
	check(KidPilots.add(), "a second pilot can be added")
	check(KidPilots.ask() and Prefs.kid_pilot == 1 and Prefs.passed_count("camera") == 0, "the new pilot starts from the beginning")
	Prefs.mark_passed("camera", 0)
	KidPilots.select(0)
	check(Prefs.passed_count("camera") == 2, "the first pilot keeps their progress")
	KidPilots.select(1)
	check(Prefs.passed_count("camera") == 1, "and so does the second")
	check(KidPilots.flowers(0) >= 1 and KidPilots.animal(1) != KidPilots.animal(0), "own animal, flowers without numbers")
	var saved := Prefs._data()
	Prefs._apply(saved)
	check(Prefs.kid_pilots.size() == 2 and Prefs.kid_pilot == 1 and Prefs.passed_count("camera") == 1, "pilots come back from the file")
	KidPilots.read([{"animal": "dragon", "color": "gold"}, {"animal": "fox", "color": "gold", "slice": {"passed": {"camera": 99}}}], 7)
	check(Prefs.kid_pilots.is_empty(), "odd pilots in the file are dropped")
	Prefs._apply(saved)
	KidPilots.remove(1)
	check(not KidPilots.ask() and Prefs.passed_count("camera") == 2, "removing a pilot leaves the other one flying")
	KidPilots.restore(1, {"animal": "owl", "color": "blue", "slice": {"passed": {"camera": 1}}})
	KidPilots.select(1)
	check(KidPilots.ask() and Prefs.passed_count("camera") == 1, "a removed pilot comes back with their progress")
	KidPilots.select(0)
	KidPilots.remove(1)
	for i in KidPilots.MAX + 2:
		KidPilots.add()
	check(Prefs.kid_pilots.size() == KidPilots.MAX, "no more than six")
	Prefs.erase_all()
	check(Prefs.kid_pilots.is_empty(), "erasing all data removes the pilots too")


## Words a child can meet outside the lesson hints: no numbers, no aiming words.
func test_kids_texts() -> void:
	var rx := RegEx.create_from_string("\\d|мішен|(^|[^а-яіїєґ])ціл(ь|і|ься)([^а-яіїєґ]|$)|target|(^|[^a-z])aim")
	var keys := ["SUM_TARGET_MIDDLE", "SUM_TARGET_EDGE", "HINT_TARGET_MISS", "HINT_READY", "BREAK_TITLE",
		"BREAK_TEXT", "BREAK_REST", "BREAK_MORE", "PILOTS_WHO", "HOME_HELLO_TEXT"]
	for t in Curriculum.THEORY:
		keys.append(t + "_DESC")
	for lang in ["uk", "en"]:
		TranslationServer.set_locale(lang)
		for k in keys:
			var text := String(TranslationServer.translate(Curriculum.text_key(k, "kids")))
			check(rx.search(text) == null, "kids text %s (%s) has no numbers or aiming words: %s" % [k, lang, text])
	TranslationServer.set_locale("en")
