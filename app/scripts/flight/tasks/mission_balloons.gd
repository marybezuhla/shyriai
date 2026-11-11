# SPDX-License-Identifier: GPL-3.0-or-later
# Kids FPV mission: pop the balloons, then land in the middle of a target lying on the ground.
extends FlightTask

const BALLOONS: Array[Vector3] = [
	Vector3(-4, 2.5, -8), Vector3(4, 3, -10), Vector3(-7, 3.5, -16),
	Vector3(6, 2.5, -17), Vector3(-2, 4, -21), Vector3(3, 3, -26),
]
const COLORS := ["pink", "blue", "gold", "green", "violet", "orange"]
const TARGET := Vector3(0, 0, -32)

var _popped: Array[int] = []


func setup_world() -> void:
	counter_shown = true
	for i in BALLOONS.size():
		world.add_balloon(BALLOONS[i], Pal.TOY[COLORS[i]])
	world.add_ground_target(TARGET)


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
	marker = TARGET
	ring = 0.0
	progress = 0.8
	say("HINT_TARGET_GO")
	for e in sim.events:
		if e["type"] != "landed":
			continue
		var off := flat_distance(sim.pos, TARGET)
		if off < 0.6:
			pass_with("SUM_TARGET_CENTRE")
		elif off < 1.4:
			pass_with("SUM_TARGET_MIDDLE")
		elif off < 2.4:
			pass_with("SUM_TARGET_EDGE")
		else:
			say_for("HINT_TARGET_MISS")
