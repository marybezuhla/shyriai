# SPDX-License-Identifier: GPL-3.0-or-later
# FPV lessons 4-5 and the race: fly through six gates in order. Lesson 5 is the same in Horizon mode;
# the race adds two gates and a clock. Touching a gate starts the run again (outside Kids mode).
extends FlightTask

var _t := 0.0


func configure() -> void:
	if key == "FPV_HORIZON":
		flight_mode = "horizon"


func setup_world() -> void:
	var pts: Array[Vector3] = GATE_COURSE.duplicate()
	if key == "MIS_FPV_RACE":
		pts.append(Vector3(-3, 2.2, -4))
		pts.append(Vector3(-12, 2.2, -10))
	var normals := normals_along(pts, world.pad)
	for i in pts.size():
		world.add_gate(pts[i], normals[i])
		var g: Dictionary = world.gates[i]
		rings.append(g)


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	if ring_i > 0:
		_t += dt
	world.highlight_gate(ring_i)
	if mode != "kids":
		for e in sim.events:
			if e["type"] == "bump" and ring_i > 0:
				restart_rings()
				_t = 0.0
				say_for("HINT_GATE_BUMP")
	var r := ring_step(sim)
	progress = float(ring_i) / rings.size()
	if r == "done":
		world.highlight_gate(-1)
		var t := int(ceil(_t))
		if key == "MIS_FPV_RACE":
			pass_with("SUM_RACE", [floori(t / 60.0), t % 60])
		else:
			pass_with("SUM_GATES", [t])
	elif sim.on_ground:
		say("HINT_FPV_THR_UP")
	else:
		say("HINT_GATE_GO", [rings.size() - ring_i])
