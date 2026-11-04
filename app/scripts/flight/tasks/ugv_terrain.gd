# SPDX-License-Identifier: GPL-3.0-or-later
# UGV lesson 3: over a 20° ramp and through mud. Uphill and mud slow the robot; in Adult mode a steep
# lean (driving off the ramp's side) tips it over.
extends FlightTask

const RAMP_Z := -8.0
const TOP := 1.8
const UP := 4.95  # 1.8 m over 4.95 m is 20°
const FLAT := 3.0
const MUD := Vector3(0, 0, -27)


func setup_world() -> void:
	world.add_ramp(RAMP_Z, 0.0, 4.0, TOP, UP, FLAT)
	world.add_mud(MUD, 3.5)
	var top_mid := RAMP_Z - UP - FLAT / 2.0
	var pts: Array[Vector3] = [Vector3(0, 0.8, top_mid), MUD + Vector3(0, 0.8, 0), Vector3(0, 0.8, -35)]
	course(pts, 1.6, "")
	cp_height_tol = 5.0


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var r := course_step(sim)
	beacon = 1.0
	progress = float(cp) / cps.size()
	if r == "done":
		pass_with("SUM_UGV_TERRAIN")
	elif cp == 0:
		say("HINT_TERRAIN_RAMP")
	elif cp == 1:
		say("HINT_TERRAIN_MUD")
	else:
		say("HINT_TERRAIN_FINISH")
