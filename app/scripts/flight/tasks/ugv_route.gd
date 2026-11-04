# SPDX-License-Identifier: GPL-3.0-or-later
# UGV deliveries and evacuations: drive a road, pick something up (or start loaded), and stop at the
# destination. A meter counts how gently the load travels: hard starts, braking, sharp turns and
# potholes take from it. Some tasks lose the radio link for a moment (the robot stops by itself) or
# show the robot's video late.
extends FlightTask

const STOP_SPEED := 0.2

var cfg := {}
var road: Array[Vector3] = []
var pickup := Vector3.INF
var dest := Vector3.ZERO
var loaded := false
var _stopped := 0.0
var _taken: Array[int] = []
var _casualty: Node3D
var _drops: Array[float] = []  # times when the link drops for 2 s
var _t := 0.0


func configure() -> void:
	var kids := mode == "kids"
	match key:
		"UGV_DELIVERY":
			cfg = {"road": [Vector3(0, 0, 0), Vector3(0, 0, -10), Vector3(-8, 0, -18), Vector3(-8, 0, -30)],
				"load": "cargo", "fragile": not kids, "barrels": true, "meter": "", "dest_r": 2.0 if kids else 1.0}
		"UGV_EVACUATION":
			cfg = {"road": [Vector3(0, 0, 0), Vector3(0, 0, -8), Vector3(10, 0, -16), Vector3(10, 0, -22)],
				"pickup": true, "load": "stretcher", "meter": "METER_PATIENT", "limit": 3.0, "drain": 9.0,
				"back": true, "delay": 0.0 if kids else 0.5, "dest_r": 2.5}
		"MIS_UGV_VET":
			cfg = {"road": [Vector3(0, 0, 0), Vector3(0, 0, -12), Vector3(-14, 0, -20), Vector3(-19, 0, -25)],
				"pickup": true, "load": "kitten", "meter": "METER_KITTEN", "limit": 3.5, "drain": 4.0,
				"vet": true, "dest_r": 2.5}
		"MIS_UGV_PARCEL":
			cfg = {"road": [Vector3(0, 0, 0), Vector3(0, 0, -12), Vector3(9, 0, -22), Vector3(13, 0, -31)],
				"load": "parcel", "sunflowers": true, "meter": "", "dest_r": 2.5}
		"MIS_UGV_CARGO":
			cfg = {"road": [Vector3(0, 0, 0), Vector3(0, 0, -12), Vector3(12, 0, -20), Vector3(13, 0, -31)],
				"load": "cargo", "potholes": true, "barrels": true, "fragile": true, "meter": "METER_CARGO",
				"limit": 4.0, "drain": 7.0, "dest_r": 1.2}
		"MIS_UGV_EVAC":
			cfg = {"road": [Vector3(0, 0, 0), Vector3(0, 0, -10), Vector3(-10, 0, -20), Vector3(-14, 0, -30)],
				"pickup": true, "load": "stretcher", "meter": "METER_PATIENT", "limit": 3.0, "drain": 9.0,
				"back": true, "barrels": true, "potholes": true, "delay": 0.5, "drops": 3, "dest_r": 2.5}
	video_delay = cfg.get("delay", 0.0)


func setup_world() -> void:
	road.assign(cfg["road"])
	world.add_road(road, 3.4)
	var end: Vector3 = road[road.size() - 1]
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	if cfg.get("pickup", false):
		pickup = end
		if cfg["load"] == "stretcher":
			_casualty = world.add_casualty(end + Vector3(1.6, 0, 0))
		else:
			# The kitten waits by a house at the end of the road.
			_casualty = world.add_kitten_at(end + Vector3(1.6, 0, 0))
		dest = Vector3(3.0, 0, -1.0) if cfg.get("back", false) else Vector3(0, 0, -1.0)
		if cfg.get("vet", false):
			world.add_sign(Vector3(-2.2, 0, -1.0), Color("#7DBE6A"))
		if cfg.get("back", false):
			world.add_van(Vector3(6.2, 0, -1.0))
	else:
		loaded = true
		load_kind = cfg["load"]
		dest = end
	if cfg.get("barrels", false):
		for i in road.size() - 1:
			var a := road[i]
			var b := road[i + 1]
			var side := (b - a).normalized().cross(Vector3.UP)
			world.add_barrel(a.lerp(b, 0.5) + side * 2.6)
	if cfg.get("potholes", false):
		for i in range(1, road.size() - 1):
			var a := road[i]
			var b := road[i + 1]
			for k in 3:
				var t := 0.25 + 0.25 * k
				var side := (b - a).normalized().cross(Vector3.UP)
				world.add_pothole(a.lerp(b, t) + side * rng.randf_range(-0.8, 0.8))
	if cfg.get("sunflowers", false):
		counter_shown = true
		var pts: Array[Vector3] = []
		for i in road.size() - 1:
			pts.append(road[i].lerp(road[i + 1], 0.5) + Vector3(0, 0.6, 0))
		world.add_sunflowers(pts)
	if cfg["meter"] != "":
		meter = 100.0
		meter_label = cfg["meter"]
	for i in int(cfg.get("drops", 0)):
		_drops.append(8.0 + i * 14.0 + rng.randf_range(0.0, 5.0))


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	_t += dt
	# The radio link drops for 2 s at a few moments: the robot stops by itself until it is back.
	link_ok = true
	for d in _drops:
		if _t >= d and _t < d + 2.0:
			link_ok = false
	if not link_ok:
		say("HINT_LINK_LOST")
	if cfg.get("fragile", false) and loaded:
		for e in sim.events:
			if e["type"] == "bump":
				fail_with("FAIL_CARGO_BUMP")
				return
	if meter >= 0.0 and loaded and sim is UgvSim:
		var j: float = (sim as UgvSim).jolt
		if j > float(cfg["limit"]):
			meter = maxf(0.0, meter - (j - float(cfg["limit"])) * float(cfg["drain"]) * dt)
			say_for("HINT_JOLT_" + cfg["load"].to_upper(), [], 1.2)
		if meter <= 0.0 and mode != "kids":
			fail_with("FAIL_JOLT_" + cfg["load"].to_upper())
			return
	if cfg.get("sunflowers", false):
		counter_max = world.sunflowers.size()
		for i in world.sunflowers.size():
			if i not in _taken and flat_distance(sim.pos, world.sunflowers[i]) < 1.4:
				_taken.append(i)
				world.take_sunflower(i)
		counter = _taken.size()

	var stopped := sim.vel.length() < STOP_SPEED
	if not loaded:
		marker = pickup + Vector3(0, 0.8, 0)
		beacon = 1.4
		progress = 0.45 * clampf(1.0 - flat_distance(sim.pos, pickup) / 35.0, 0.0, 1.0)
		if flat_distance(sim.pos, pickup) < 2.0 and stopped:
			_stopped += dt
			say("HINT_ROUTE_LOADING")
			if _stopped > 1.0:
				loaded = true
				load_kind = cfg["load"]
				_stopped = 0.0
				if _casualty:
					_casualty.visible = false
				say_for("HINT_ROUTE_LOADED_" + cfg["load"].to_upper(), [], 2.5)
		else:
			_stopped = 0.0
			if link_ok:
				say("HINT_ROUTE_PICKUP_" + cfg["load"].to_upper())
		return
	marker = dest + Vector3(0, 0.8, 0)
	beacon = 0.0
	ring = float(cfg["dest_r"])
	var d := flat_distance(sim.pos, dest)
	progress = 0.5 + 0.45 * clampf(1.0 - d / 40.0, 0.0, 1.0) if cfg.get("pickup", false) else 0.95 * clampf(1.0 - d / 40.0, 0.0, 1.0)
	if d <= float(cfg["dest_r"]) and stopped:
		_stopped += dt
		if _stopped > 0.5:
			_finish()
	else:
		_stopped = 0.0
		if link_ok:
			say("HINT_ROUTE_GO_" + cfg["load"].to_upper())


func _finish() -> void:
	if meter >= 0.0:
		pass_with("SUM_" + key.trim_prefix("MIS_"), [int(round(meter))])
	elif counter_max > 0:
		pass_with("SUM_" + key.trim_prefix("MIS_"), [counter, counter_max])
	else:
		pass_with("SUM_" + key.trim_prefix("MIS_"))
