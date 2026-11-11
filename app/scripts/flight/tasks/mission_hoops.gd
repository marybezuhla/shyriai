# SPDX-License-Identifier: GPL-3.0-or-later
# Kids FPV mission: fly through every colourful hoop. Hoops never get in the way.
extends FlightTask

const POINTS: Array[Vector3] = [
	Vector3(0, 2.5, -8), Vector3(-5, 3, -15), Vector3(-6, 4, -24), Vector3(0, 3, -30),
	Vector3(7, 2.5, -24), Vector3(8, 3.5, -14), Vector3(3, 2.5, -6),
]
const COLORS := ["gold", "pink", "blue", "green"]


func setup_world() -> void:
	counter_shown = true
	var normals := normals_along(POINTS, world.pad)
	for i in POINTS.size():
		var p := POINTS[i]
		world.add_hoop(p, normals[i], Pal.TOY[COLORS[i % COLORS.size()]])
		rings.append({"c": Vector3(p.x, world.height(p.x, p.z) + p.y, p.z), "n": normals[i], "r": 1.6})


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var before := ring_i
	var r := ring_step(sim)
	if ring_i > before:
		world.hoop_done(before)
	counter = ring_i
	counter_max = rings.size()
	progress = float(ring_i) / rings.size()
	if r == "done":
		pass_with("SUM_HOOPS")
	elif sim.on_ground:
		say("HINT_HOOPS_UP")
	else:
		say("HINT_HOOPS_GO", [rings.size() - ring_i])
