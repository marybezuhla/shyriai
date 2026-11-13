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
