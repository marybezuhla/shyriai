# SPDX-License-Identifier: GPL-3.0-or-later
# Lesson 3: no GPS hold, the wind pushes the drone. Keep it over the mark for 10 s.
extends FlightTask

const RADIUS := 2.0
const NEED := 10.0

var _timer := 0.0
var _best := 0.0


func configure() -> void:
	gps = false
	wind = {"kids": 0.6, "simple": 1.5, "pro": 2.5}.get(mode, 1.5)
	gust = {"kids": 0.1, "simple": 0.3, "pro": 0.6}.get(mode, 0.3)


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	marker = world.hold_mark
	ring = RADIUS
	var inside := flat_distance(sim.pos, marker) <= RADIUS and sim.altitude() > 1.0
	if inside:
		_timer += dt
		_best = maxf(_best, _timer)
		say("HINT_HOLD_KEEP", [ceili(NEED - _timer)])
	else:
		if _timer > 0.5:
			say("HINT_HOLD_OUT")
		elif sim.on_ground:
			say("HINT_HOLD_GO")
		elif hint != "HINT_HOLD_OUT":
			say("HINT_HOLD_GO")
		_timer = 0.0
	progress = clampf(_best / NEED, 0.0, 1.0)
	if _timer >= NEED:
		pass_with("SUM_HOLD")
