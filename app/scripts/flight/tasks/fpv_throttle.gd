# SPDX-License-Identifier: GPL-3.0-or-later
# FPV lesson 1: find the throttle that holds the drone in the air. Nothing holds the height for you.
extends FlightTask

const HEIGHT := 3.0
const BAND := 1.0
const NEED := 10.0

var _timer := 0.0
var _best := 0.0


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	marker = world.pad + Vector3(0, HEIGHT, 0)
	beacon = BAND
	var inside := absf(sim.altitude() - HEIGHT) <= BAND and flat_distance(sim.pos, world.pad) <= 5.0 and not sim.on_ground
	if not sim.on_ground:
		stick_hint = {}
	if inside:
		_timer += dt
		_best = maxf(_best, _timer)
		say("HINT_FPV_THR_HOLD", [ceili(NEED - _timer)])
	else:
		if _timer > 0.5:
			say_for("HINT_FPV_THR_OUT", [], 2.0)
		elif sim.on_ground:
			say("HINT_FPV_THR_UP")
			stick_hint = {"left": Vector2.UP}
		else:
			say("HINT_FPV_THR_GO")
		_timer = 0.0
	progress = clampf(_best / NEED, 0.0, 1.0)
	if _timer >= NEED:
		pass_with("SUM_FPV_THR")
