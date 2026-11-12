# SPDX-License-Identifier: GPL-3.0-or-later
# The plane: its physics, and every plane lesson and mission flown to a pass with the sticks alone.
extends "res://tests/sim_courses.gd"

const WingAutopilot := preload("res://tests/wing_autopilot.gd")


func test_wing_physics() -> void:
	var w := WingSim.new("simple", 3)
	w.place(Vector3(0, 30, 0), 0.0)
	run(w, 15.0, 0.24, 0.0, 0.0, 0.0)
	check(absf(w.pos.y - 30.0) < 8.0 and w.speed > 11.0, "simple plane flies level hands off (%.1f m, %.1f m/s)" % [w.pos.y, w.speed])
	check(w.pos.z < -150.0, "a plane cannot hover: it has flown on")
	var glide := WingSim.new("simple", 3)
	glide.place(Vector3(0, 30, 0), 0.0)
	run(glide, 6.0, -1.0, 0.0, 0.0, 0.0)
	check(glide.pos.y < 26.0 and glide.speed > 10.0, "throttle off: it glides down, still flying")
	var protected := WingSim.new("simple", 3)
	protected.place(Vector3(0, 60, 0), 0.0)
	run(protected, 12.0, -1.0, 0.0, -1.0, 0.0)
	check(not protected.crashed and protected.pos.y > 20.0, "simple mode keeps a full pull from stalling into the ground")
	var pro := WingSim.new("pro", 3)
	pro.place(Vector3(0, 60, 0), 0.0)
	var stalls := 0
	for i in 600:
		pro.step(DT, -1.0, 0.0, -1.0, 0.0)
		for e in pro.events:
			stalls += int(e["type"] == "stall")
	check(stalls > 0, "adult mode: a full pull with no throttle stalls the wing")
	var kid := WingSim.new("kids", 3)
	kid.place(Vector3(0, 20, 0), 0.0)
	run(kid, 20.0, 0.0, 0.0, -1.0, 0.0)
	check(kid.altitude() > 4.0 and not kid.on_ground, "kids' plane never comes down to the ground")
	var ground := WingSim.new("simple", 3)
	ground.place(Vector3(6, 0, -8), 0.0)
	run(ground, 2.0, -1.0, 0.0, 0.0, 0.0)
	check(ground.on_ground and ground.speed < 0.1, "on the runway with the throttle off it stays put")


func test_wing_task(key: String, mode: String) -> void:
	var f := _flight(key, mode, "wing")
	var task: FlightTask = f[0]
	var sim: WingSim = f[1]
	var world: FlightWorld = f[2]
	var ap := WingAutopilot.new()
	var plan := func(_t: float) -> Dictionary:
		ap.orbit_bank = 0.0
		ap.through = Vector3.ZERO
		match key:
			"WING_TAKEOFF":
				return ap.takeoff(sim)
			"WING_STALL":
				return ap.stall(sim, task._stalled_at >= 0.0)
			"WING_LANDING":
				ap.through = Vector3(0, 0, 1)
				return ap.land(sim, Vector3(WorldLand.RUNWAY_X, 0, task.TOUCH_Z), task.GLIDE)
			"WING_TURN":
				var t: Vector3 = task.TOWER
				ap.target = Vector3(t.x, world.height(t.x, t.z) + 30.0, t.z)
				if FlightTask.flat_distance(sim.pos, t) < 40.0:
					ap.orbit_bank = deg_to_rad(28.0)
			"MIS_WING_SEARCH", "MIS_WING_KITE":
				var s: Vector3 = task._spot
				ap.target = Vector3(s.x, world.height(s.x, s.z) + 30.0, s.z)
				# Found: circle tightly one way, so the turns add up over the spot. Before that, line up
				# on it from the field, so the plane passes right over it instead of circling short.
				if task._found:
					ap.orbit_bank = deg_to_rad(30.0)
				else:
					var line := Vector3(s.x - WorldLand.RUNWAY_X, 0, s.z + 12.0)
					ap.through = line.normalized() if line.length() > 1.0 else Vector3(0, 0, -1)
			"MIS_WING_FLOOD":
				var m := task.marker
				if m != Vector3.INF:
					ap.target = Vector3(m.x, world.height(m.x, m.z) + 15.0, m.z)
			_:
				if task.ring_i < task.rings.size():
					ap.target = task.rings[task.ring_i]["c"]
					ap.through = task.rings[task.ring_i]["n"]
		return ap.sticks(sim)
	var ok := _fly(task, sim, 400.0, plan)
	check(ok, "%s %s flown to a pass by the sticks (%s)" % [mode, key, "crashed" if sim.crashed else ("failed: " + task.summary if task.failed else "time")])
	world.queue_free()
	await get_tree().process_frame


## Into a row of poplars: Kids fly above them; in Simple the plane is slowed and turned, never stuck,
## and nothing raises an error.
func test_wing_obstacles() -> void:
	for mode in ["kids", "simple"]:
		var f := _flight("WING_LEVEL", mode, "wing")
		var sim: WingSim = f[1]
		sim.place(Vector3(20, 8, 4), PI / 2.0)  # at tree height, heading for the poplars at x = 44
		run(sim, 8.0, 0.24, 0.0, 0.0, 0.0)
		check(FlightTask.flat_distance(sim.pos, Vector3(44, 0, 4)) > 8.0 or sim.altitude() > 11.0,
			"%s plane does not stay pinned against the poplars" % mode)
		if mode == "kids":
			check(sim.altitude() > 12.0, "kids plane climbs over the trees")
		f[2].queue_free()
	await get_tree().process_frame


## A jerk of the stick at cruise speed is not the stall the lesson asks for.
func test_wing_stall_needs_slowing() -> void:
	var f := _flight("WING_STALL", "simple", "wing")
	var task: FlightTask = f[0]
	var sim: WingSim = f[1]
	var jerk := func(t: float) -> Dictionary:
		if t < 1.0:
			return {"throttle": 0.24, "yaw": 0.0, "pitch": -1.0, "roll": 0.0}
		return {"throttle": 1.0, "yaw": 0.0, "pitch": 0.3, "roll": 0.0}
	_fly(task, sim, 8.0, jerk)
	check(not task.done, "a quick pull at cruise speed does not pass the stall lesson")
	f[2].queue_free()
	await get_tree().process_frame


## A landing that comes in too hard does not count, and one on the grass ends the try.
func test_wing_landing_rules() -> void:
	var f := _flight("WING_LANDING", "simple", "wing")
	var task: FlightTask = f[0]
	var sim: WingSim = f[1]
	sim.place(Vector3(WorldLand.RUNWAY_X, 1.0, -40.0), PI)
	sim.vel = Vector3(0, -5, 10)
	task._touched(sim, 5.0)
	check(task.failed, "a landing at 5 m/s down is not counted")
	var g := _flight("WING_LANDING", "simple", "wing")
	g[1].place(Vector3(30, 0.5, -40), PI)
	g[0]._touched(g[1], 1.0)
	check(g[0].failed and g[0].summary == "FAIL_WING_OFF_RUNWAY", "touching down on the grass ends the try")
	# Touched down well, but the throttle stays open: it rolls off the end, and that ends the try.
	var h := _flight("WING_LANDING", "simple", "wing")
	var t3: FlightTask = h[0]
	var s3: WingSim = h[1]
	s3.place(Vector3(WorldLand.RUNWAY_X, 0, -40.0), PI)
	s3.speed = 10.0
	t3._down = 1.0
	_fly(t3, s3, 20.0, func(_t): return {"throttle": -0.3, "yaw": 0.0, "pitch": 0.0, "roll": 0.0})
	check(t3.failed and not t3.done, "rolling off the runway end after landing ends the try")
	h[2].queue_free()
	f[2].queue_free()
	g[2].queue_free()
	await get_tree().process_frame
