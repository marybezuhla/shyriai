# SPDX-License-Identifier: GPL-3.0-or-later
# Adult FPV mission: fly through a belt of trees, below their tops, to the far side and back.
# Touching a tree or flying over the belt ends the run.
extends FlightTask

const BELT_FROM := -14.0
const BELT_TO := -32.0
const HALF := 14.0
const LOW := 5.5  # m: stay below the tree tops (6-9 m)

var trees: Array = []


func setup_world() -> void:
	trees = world.add_tree_belt(BELT_FROM, BELT_TO, HALF, task_seed)
	var pts: Array[Vector3] = [Vector3(0, 3, -38), Vector3(0, 3, -6)]
	course(pts, 2.5, "")
	cp_height_tol = 2.0


func in_belt(p: Vector3) -> bool:
	return p.z < BELT_FROM + 1.5 and p.z > BELT_TO - 1.5 and absf(p.x) < HALF + 1.5


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	for e in sim.events:
		if e["type"] == "bump":
			fail_with("FAIL_TREES")
			return
	if in_belt(sim.pos) and sim.altitude() > LOW:
		fail_with("FAIL_TREES_OVER")
		return
	# Going round the end of the belt does not count either: the way is through it.
	if sim.pos.z < BELT_FROM and sim.pos.z > BELT_TO and absf(sim.pos.x) > HALF + 1.5:
		fail_with("FAIL_TREES_AROUND")
		return
	var r := course_step(sim)
	progress = float(cp) / cps.size()
	if r == "done":
		pass_with("SUM_TREES")
	elif sim.on_ground:
		say("HINT_FPV_THR_UP")
	elif in_belt(sim.pos):
		say("HINT_TREES_LOW")
	elif cp == 0:
		say("HINT_TREES_THERE")
	else:
		say("HINT_TREES_BACK")
