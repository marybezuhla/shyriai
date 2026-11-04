# SPDX-License-Identifier: GPL-3.0-or-later
# Kids FPV mission: pop the balloons, then fly into the target, as close to the middle as you can.
extends FlightTask

const BALLOONS: Array[Vector3] = [
	Vector3(-4, 2.5, -8), Vector3(4, 3, -10), Vector3(-7, 3.5, -16),
	Vector3(6, 2.5, -17), Vector3(-2, 4, -21), Vector3(3, 3, -26),
]
const COLORS := ["#E5708B", "#5B9BD5", "#FFC321", "#7DBE6A", "#B07CD8", "#F29B50"]
const TARGET := Vector3(0, 3, -32)

var _popped: Array[int] = []
var _target := Vector3.ZERO
var _normal := Vector3(0, 0, 1)


func setup_world() -> void:
	counter_shown = true
	for i in BALLOONS.size():
		world.add_balloon(BALLOONS[i], Color(COLORS[i]))
	world.add_target(TARGET, _normal)
	_target = Vector3(TARGET.x, world.height(TARGET.x, TARGET.z) + TARGET.y, TARGET.z)


func balloon_pos(i: int) -> Vector3:
	var b := BALLOONS[i]
	return Vector3(b.x, world.height(b.x, b.z) + b.y, b.z)


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	counter_max = BALLOONS.size()
	for i in BALLOONS.size():
		if i not in _popped and sim.pos.distance_to(balloon_pos(i)) < 1.1:
			_popped.append(i)
			world.pop_balloon(i)
	counter = _popped.size()
	if _popped.size() < BALLOONS.size():
		marker = Vector3.INF
		progress = 0.7 * _popped.size() / BALLOONS.size()
		if sim.on_ground:
			say("HINT_BALLOONS_UP")
		else:
			say("HINT_BALLOONS_GO", [BALLOONS.size() - _popped.size()])
		return
	marker = _target
	progress = 0.8
	say("HINT_TARGET_GO")
	# A hit: the drone touches the board's face.
	var front := (sim.pos - _target).dot(_normal)
	var off := sim.pos - _normal * front - _target
	if front < 0.75 and front > -0.3 and off.length() < 2.0:
		if off.length() < 0.5:
			pass_with("SUM_TARGET_CENTRE")
		elif off.length() < 1.25:
			pass_with("SUM_TARGET_MIDDLE")
		else:
			pass_with("SUM_TARGET_EDGE")
