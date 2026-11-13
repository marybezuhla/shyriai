# SPDX-License-Identifier: GPL-3.0-or-later
# Physics tests: hovering, wind, landing help, crashes, battery, FPV and the ground robot.
extends "res://tests/sim_base.gd"


# --- Physics ----------------------------------------------------------------

func test_hover_holds_with_gps() -> void:
	var sim := DroneSim.new("simple")
	sim.place(Vector3.ZERO)
	run(sim, 1.5, 1.0, 0, 0, 0)
	var start := sim.pos
	run(sim, 10.0, 0, 0, 0, 0)
	check(absf(sim.vel.y) < 0.05, "hover: climb stops when the stick is let go")
	check(Vector2(sim.pos.x - start.x, sim.pos.z - start.z).length() < 0.3, "hover: GPS holds the spot in wind")


func test_atti_drifts_with_wind() -> void:
	var sim := DroneSim.new("simple")
	sim.gps = false
	sim.set_wind(1.5, 0.0)
	sim.place(Vector3.ZERO)
	run(sim, 1.5, 1.0, 0, 0, 0)
	var start := sim.pos
	run(sim, 5.0, 0, 0, 0, 0)
	check(Vector2(sim.pos.x - start.x, sim.pos.z - start.z).length() > 3.0, "ATTI: the wind carries the drone")


func test_landing_assist() -> void:
	for mode in ["kids", "simple"]:
		var sim := DroneSim.new(mode)
		sim.place(Vector3.ZERO)
		run(sim, 3.0, 1.0, 0, 0, 0)
		var speed := -1.0
		for i in 900:
			sim.step(DT, -1.0, 0, 0, 0)
			for e in sim.events:
				if e["type"] == "landed":
					speed = e["speed"]
		check(speed >= 0.0 and speed <= 0.45, "%s: full stick down still lands softly (%.2f m/s)" % [mode, speed])


func test_kids_never_crash() -> void:
	var sim := DroneSim.new("kids")
	sim.obstacles = [{"box": AABB(Vector3(-3, 0, -12), Vector3(6, 6, 2))}]
	sim.place(Vector3.ZERO)
	run(sim, 1.5, 1.0, 0, 0, 0)
	run(sim, 8.0, 0, 0, 1.0, 0)
	check(not sim.crashed, "kids: flying into a wall bounces, never crashes")
	check(sim.pos.z > -9.7, "kids: the wall stops the drone")


func test_adult_crashes_into_a_house() -> void:
	var sim := DroneSim.new("pro")
	sim.obstacles = [{"box": AABB(Vector3(-3, 0, -30), Vector3(6, 6, 2))}]
	sim.place(Vector3.ZERO)
	run(sim, 1.0, 1.0, 0, 0, 0)
	run(sim, 8.0, 0, 0, 1.0, 0)
	check(sim.crashed, "adult: full speed into a wall crashes")


func test_battery_lands_by_itself() -> void:
	var sim := DroneSim.new("pro")
	sim.p["battery_s"] = 5.0
	sim.place(Vector3.ZERO)
	run(sim, 2.0, 1.0, 0, 0, 0)
	run(sim, 20.0, 0.5, 0, 0, 0)
	check(sim.battery <= 0.0 and sim.on_ground, "adult: an empty battery brings the drone down")


func test_fpv_physics() -> void:
	# Hover throttle holds the height; nothing else does.
	var sim := FpvSim.new("simple")
	sim.set_wind(0.0, 0.0)
	sim.place(Vector3.ZERO)
	run(sim, 1.0, 0.6, 0, 0, 0)
	var h := sim.hover_throttle() * 2.0 - 1.0
	run(sim, 4.0, h, 0, 0, 0)
	check(absf(sim.vel.y) < 0.2 and not sim.on_ground, "FPV: hover throttle keeps it in the air")
	run(sim, 2.0, -1.0, 0, 0, 0)
	check(sim.vel.y < -1.0 or sim.on_ground, "FPV: no throttle and it falls")
	# Angle: the stick tilts it, letting go levels it.
	sim.place(Vector3.ZERO)
	run(sim, 1.0, 0.6, 0, 0, 0)
	run(sim, 1.0, h, 0, 1.0, 0)
	var leaned := sim.tilt_angles().x
	run(sim, 1.0, h, 0, 0, 0)
	check(leaned > deg_to_rad(25.0) and absf(sim.tilt_angles().x) < deg_to_rad(3.0), "FPV angle: tilts to the stick and levels when let go")
	# Acro: it keeps the turn it was given.
	var pro := FpvSim.new("pro")
	pro.set_wind(0.0, 0.0)
	pro.flight_mode = "acro"
	pro.place(Vector3.ZERO)
	run(pro, 0.8, 0.6, 0, 0, 0)
	run(pro, 0.15, pro.hover_throttle() * 2.0 - 1.0, 0, 0.5, 0)
	var before := pro.tilt_angles().x
	run(pro, 0.5, pro.hover_throttle() * 2.0 - 1.0, 0, 0, 0)
	# It turns on a little after the stick (the turn has momentum), then holds: it never levels.
	check(before > deg_to_rad(10.0) and pro.tilt_angles().x > before - deg_to_rad(1.0) and pro.tilt_angles().x < before + deg_to_rad(10.0),
		"FPV acro: the tilt stays after letting go")
	# Adult: a hard hit on the ground crashes.
	var c := FpvSim.new("pro")
	c.place(Vector3(0, 12, 0))
	c.on_ground = false
	run(c, 3.0, -1.0, 0, 0, 0)
	check(c.crashed, "FPV adult: falling from 12 m crashes")
	# The test pilot can fly each mode to a point.
	for fm in [["simple", "angle"], ["pro", "angle"], ["pro", "horizon"], ["pro", "acro"]]:
		var s2 := FpvSim.new(fm[0])
		s2.flight_mode = fm[1]
		s2.place(Vector3.ZERO)
		var ap := FpvAutopilot.new()
		ap.target = Vector3(-10, 0, -20)
		ap.height = 4.0
		for i in int(20.0 / DT):
			var st: Dictionary = ap.sticks(s2)
			s2.step(DT, st["throttle"], st["yaw"], st["pitch"], st["roll"])
		var off := Vector2(s2.pos.x + 10, s2.pos.z + 20).length()
		check(off < 2.0 and absf(s2.altitude() - 4.0) < 1.0 and not s2.crashed,
			"FPV %s %s: the test pilot reaches a point (%.1f m off)" % [fm[0], fm[1], off])


# --- Ground robot ------------------------------------------------------------------

func test_ugv_physics() -> void:
	var sim := UgvSim.new("simple")
	sim.place(Vector3.ZERO)
	run(sim, 3.0, 1.0, 0, 1.0, 0)
	check(sim.pos.z < -6.0 and absf(sim.pos.x) < 0.1, "UGV: both tracks forward drives straight")
	var heading := sim.yaw
	run(sim, 1.0, 1.0, 0, -1.0, 0)
	var turned := rad_to_deg(absf(wrapf(sim.yaw - heading, -PI, PI)))
	check(turned > 35.0 and turned < 75.0, "UGV: tracks in opposite directions turn on the spot, at a real robot's pace (%.0f° in 1 s)" % turned)
	run(sim, 2.0, 0, 0, 0, 0)
	check(sim.vel.length() < 0.05, "UGV: let go and it stops")
	var mud := UgvSim.new("simple")
	mud.grip = func(_x, _z): return 0.45
	mud.place(Vector3.ZERO)
	run(mud, 3.0, 1.0, 0, 1.0, 0)
	check(mud.pos.z > -4.0, "UGV: mud slows it down")
	var car := UgvSim.new("kids")
	car.place(Vector3.ZERO)
	run(car, 2.0, 1.0, 0, 0, 0)
	check(car.pos.z < -2.0, "UGV kids: left stick forward drives (car steering)")
