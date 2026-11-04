# SPDX-License-Identifier: GPL-3.0-or-later
# Lesson 6: three precise landings, each time coming in from a different side.
extends FlightTask

const SIDES: Array[Vector3] = [Vector3(-8, 3, 0), Vector3(0, 3, -9), Vector3(8, 3, 0)]

var _round := 0
var _approach := true
var _miss := 0.0


func _tolerance() -> float:
	return {"kids": 1.0, "simple": 0.5, "pro": 0.5}.get(mode, 0.5)


func _max_speed() -> float:
	return 1.0 if mode == "pro" else 0.6


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	progress = (_round + (0.5 if not _approach else 0.0)) / 3.0
	if _approach:
		var t := SIDES[_round]
		marker = t
		beacon = 2.0
		ring = 0.0
		if sim.on_ground:
			say("HINT_LAND_TAKEOFF" if _round > 0 or _miss > 0.0 else "HINT_LAND_UP")
		else:
			say("HINT_LAND_GO", [_round + 1])
		if flat_distance(sim.pos, t) <= 2.0 and absf(sim.pos.y - t.y) <= 1.5:
			_approach = false
	else:
		marker = world.pad
		beacon = 0.0
		ring = _tolerance()
		say("HINT_LAND_DOWN")
	for e in sim.events:
		if e["type"] != "landed" or _approach:
			continue
		var miss := flat_distance(sim.pos, world.pad)
		if miss > _tolerance():
			_miss = miss
			say_for("HINT_LAND_MISS", [int(round(miss * 100.0))])
			_approach = true
		elif e["speed"] > _max_speed():
			say_for("HINT_LAND_HARD", ["%.1f" % e["speed"]])
			_approach = true
		else:
			_round += 1
			_approach = true
			say_for("HINT_LAND_GOOD", [_round, int(round(miss * 100.0))], 2.5)
			if _round >= 3:
				pass_with("SUM_LANDING", [int(round(miss * 100.0))])
