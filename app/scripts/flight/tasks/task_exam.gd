# SPDX-License-Identifier: GPL-3.0-or-later
# Lesson 8: the exam. Take off, fly a route nose first, sweep sideways nose in, land precisely.
# Kids get no clock and may bump into things; everyone else must not touch anything and has 3 minutes.
extends FlightTask

const LIMIT := 180.0
const LAND := 0.5

var _stage := 0  # 0 take off, 1 route, 2 nose in, 3 land
var _t := 0.0
var _route: Array[Vector3] = [Vector3(-8, 4, -10), Vector3(0, 4, -20), Vector3(8, 4, -10)]
var _sweep: Array[Vector3] = [Vector3(6, 2.5, -4), Vector3(-6, 2.5, -4), Vector3(0, 2.5, -1.5)]


func setup_world() -> void:
	course(_route, 3.0 if mode == "kids" else 2.0, "" if mode == "kids" else "travel")


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	if not sim.on_ground or _stage > 0:
		_t += dt
	var strict := mode != "kids"
	if strict:
		for e in sim.events:
			if e["type"] == "bump":
				fail_with("FAIL_EXAM_BUMP")
				return
		if _t > LIMIT:
			fail_with("FAIL_EXAM_TIME")
			return
	var steps := float(_route.size() + _sweep.size() + 2)
	match _stage:
		0:
			marker = Vector3.INF
			beacon = 0.0
			say("HINT_EXAM_UP")
			progress = 0.0
			if sim.altitude() >= 2.0:
				_stage = 1
		1:
			var r := course_step(sim)
			progress = (1.0 + cp) / steps
			if r == "done":
				_stage = 2
				course(_sweep, 3.0 if mode == "kids" else 2.0, "" if mode == "kids" else "pilot")
			elif r == "facing" or (cp_facing != "" and not nose_ok(sim) and Vector2(sim.vel.x, sim.vel.z).length() > 1.0):
				say("HINT_SQUARE_NOSE")
			else:
				say("HINT_EXAM_ROUTE", [_route.size() - cp])
		2:
			var r2 := course_step(sim)
			progress = (1.0 + _route.size() + cp) / steps
			if r2 == "done":
				_stage = 3
			elif cp_facing != "" and not nose_ok(sim):
				say("HINT_NOSE_FACE")
			else:
				say("HINT_EXAM_SWEEP", [_sweep.size() - cp])
		3:
			marker = world.pad
			beacon = 0.0
			ring = 1.0 if mode == "kids" else LAND
			progress = (steps - 1.0) / steps
			say("HINT_LAND_DOWN")
			for e in sim.events:
				if e["type"] != "landed":
					continue
				var miss := flat_distance(sim.pos, world.pad)
				if miss > ring:
					say_for("HINT_LAND_MISS", [int(round(miss * 100.0))])
				elif strict and e["speed"] > (1.0 if mode == "pro" else 0.6):
					say_for("HINT_LAND_HARD", [num(e["speed"])])
				else:
					var t := int(ceil(_t))
					pass_with("SUM_EXAM", [floori(t / 60.0), t % 60])
