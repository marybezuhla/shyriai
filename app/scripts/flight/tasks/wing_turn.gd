# SPDX-License-Identifier: GPL-3.0-or-later
# Plane lesson 2: circle the water tower twice (Kids: once) without wandering off or losing height.
# A plane turns by banking: the turns count only while it stays near the tower and at height.
extends WingTask

const TOWER := Vector3(6, 0, -100)
const NEAR := 15.0
const FAR := 55.0

var _turned := 0.0


func setup_world() -> void:
	world.add_tower(TOWER)


func _laps() -> float:
	return 1.0 if mode == "kids" else 2.0


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var top := Vector3(TOWER.x, world.height(TOWER.x, TOWER.z) + 10.0, TOWER.z)
	marker = top
	var d := flat_distance(sim.pos, TOWER)
	var alt := sim.altitude()
	var turn := turned(sim)
	var in_place := d >= NEAR and d <= FAR and alt >= 15.0 and alt <= 50.0
	if in_place:
		_turned += turn
	var need := TAU * _laps()
	var done_turn := absf(_turned)
	progress = clampf(done_turn / need, 0.0, 1.0)
	if done_turn >= need:
		pass_with("SUM_WING_TURN", [] if mode == "kids" else [roundi(sim.time)])
		return
	if air_warnings(sim):
		return
	if d > FAR:
		say("HINT_WING_TOWER")
	elif d < NEAR:
		say("HINT_WING_TOWER_WIDE")
	elif alt < 15.0:
		say("HINT_WING_HIGHER")
	elif alt > 50.0:
		say("HINT_WING_LOWER")
	else:
		say("HINT_WING_TURN_GO", [ceili((need - done_turn) / TAU)])
