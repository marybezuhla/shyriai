# SPDX-License-Identifier: GPL-3.0-or-later
# UGV lesson 2: drive into a dead-end alley, turn round on the spot (tracks in opposite directions)
# and drive back out. Touching a wall ends the run (outside Kids mode).
extends FlightTask

const HALF := 1.7
const END_Z := -15.0

var _stage := 0  # 0 in, 1 turn, 2 out


func setup_world() -> void:
	world.add_wall(Vector3(-HALF, 0, -3), Vector3(-HALF, 0, END_Z))
	world.add_wall(Vector3(HALF, 0, -3), Vector3(HALF, 0, END_Z))
	world.add_wall(Vector3(-HALF, 0, END_Z), Vector3(HALF, 0, END_Z))


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	if mode != "kids":
		for e in sim.events:
			if e["type"] == "bump":
				fail_with("FAIL_UGV_WALL")
				return
	var inside := Vector3(0, 0, END_Z + 2.2)
	var out := Vector3(0, 0, 0)
	match _stage:
		0:
			marker = inside + Vector3(0, 0.8, 0)
			beacon = 1.0
			progress = 0.0
			say("HINT_PIVOT_IN")
			if flat_distance(sim.pos, inside) < 1.3:
				_stage = 1
		1:
			marker = Vector3.INF
			beacon = 0.0
			# Facing back out, towards the pilot.
			var turned := sim.forward().angle_to(Vector3(0, 0, 1)) < deg_to_rad(25.0)
			progress = 0.33 + 0.33 * clampf(1.0 - sim.forward().angle_to(Vector3(0, 0, 1)) / PI, 0.0, 1.0)
			say("HINT_PIVOT_TURN_TANK" if (sim is UgvSim and sim.tank) else "HINT_PIVOT_TURN_CAR")
			if turned:
				_stage = 2
		2:
			marker = out + Vector3(0, 0.8, 0)
			beacon = 1.5
			progress = 0.7
			say("HINT_PIVOT_OUT")
			if flat_distance(sim.pos, out) < 1.6:
				pass_with("SUM_UGV_PIVOT")
