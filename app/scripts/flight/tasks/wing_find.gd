# SPDX-License-Identifier: GPL-3.0-or-later
# Plane missions: find something on the ground, then circle over it so the rescuers can see where.
#   MIS_WING_SEARCH  a lost person with a red tarp somewhere in the valley; three circles over them
#   MIS_WING_KITE    a kite caught in a tree (Kids): the arrow shows the way; one circle over it
extends WingTask

var _spot := Vector3.INF
var _found := false
var _turned := 0.0


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed * 31 + 5
	var at := Vector3(rng.randf_range(-55.0, 55.0), 0, rng.randf_range(-170.0, -80.0))
	if key == "MIS_WING_KITE":
		_spot = AirProps.add_kite_tree(world, at)
	else:
		AirProps.add_tarp(world, at)
		_spot = Vector3(at.x, world.height(at.x, at.z), at.z)


func _laps() -> float:
	return 1.0 if mode == "kids" else 3.0


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var d := flat_distance(sim.pos, _spot)
	var turn := turned(sim)
	# Kids are shown the way; grown-ups search until they are close.
	if mode == "kids" or _found:
		marker = _spot
	if not _found:
		progress = 0.0
		if d < 35.0 and sim.altitude() < 70.0:
			_found = true
			say_for("HINT_WING_FOUND")
		elif not air_warnings(sim):
			say("HINT_WING_KITE_GO" if key == "MIS_WING_KITE" else "HINT_WING_SEARCH")
		return
	if d < 60.0:
		_turned += turn
	var need := TAU * _laps()
	progress = 0.3 + 0.7 * clampf(_turned / need, 0.0, 1.0)
	if _turned >= need:
		var t := int(ceil(sim.time))
		pass_with("SUM_" + key, [] if mode == "kids" else [floori(t / 60.0), t % 60])
	elif not air_warnings(sim):
		say("HINT_WING_CIRCLE" if d < 60.0 else "HINT_WING_BACK", [ceili((need - _turned) / TAU)])
