# SPDX-License-Identifier: GPL-3.0-or-later
# Lesson 5: a square, then a circle, nose first: turning while moving.
extends FlightTask

var _square := 5


func setup_world() -> void:
	var pts: Array[Vector3] = [
		Vector3(-5, 3, -4), Vector3(-5, 3, -14), Vector3(5, 3, -14), Vector3(5, 3, -4), Vector3(-5, 3, -4),
	]
	# Then a circle of 10 m across, starting on its left side.
	var c := Vector3(0, 0, -9)
	for i in range(1, 9):
		var a := PI + i * TAU / 8.0
		pts.append(c + Vector3(cos(a) * 5.0, 3.0, sin(a) * 5.0))
	_square = 5
	course(pts, 3.0 if mode == "kids" else 2.0, "" if mode == "kids" else "travel")


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var r := course_step(sim)
	progress = float(cp) / cps.size()
	if r == "done":
		pass_with("SUM_SQUARE")
	elif sim.on_ground:
		say("HINT_SQUARE_UP")
	elif r == "facing" or (cp_facing != "" and not nose_ok(sim) and Vector2(sim.vel.x, sim.vel.z).length() > 1.0):
		say("HINT_SQUARE_NOSE")
	elif cp < _square:
		say("HINT_SQUARE_GO", [_square - cp])
	else:
		say("HINT_CIRCLE_GO", [cps.size() - cp])
