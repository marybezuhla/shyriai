# SPDX-License-Identifier: GPL-3.0-or-later
# FPV lesson 6 (Adult mode): Acro. The drone never levels itself: hold the height and fly a simple course.
extends FlightTask

var _flying := false


func configure() -> void:
	flight_mode = "acro"
	wind = 0.5
	gust = 0.2


func setup_world() -> void:
	var pts: Array[Vector3] = [Vector3(0, 5, -14), Vector3(-10, 5, -26), Vector3(4, 5, -36), Vector3(12, 5, -20)]
	course(pts, 3.0, "")
	cp_height_tol = 2.5


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	if not sim.on_ground:
		_flying = true
	elif _flying and cp > 0:
		_flying = false
		cp = 0
		say_for("HINT_FPV_GROUND")
	var r := course_step(sim)
	progress = float(cp) / cps.size()
	if r == "done":
		pass_with("SUM_ACRO")
	elif sim.on_ground:
		say("HINT_ACRO_UP")
	else:
		say("HINT_ACRO_GO", [cps.size() - cp])
