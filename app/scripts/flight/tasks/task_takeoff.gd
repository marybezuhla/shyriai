# SPDX-License-Identifier: GPL-3.0-or-later
# Lesson 2: lift to 2 m, hold for 3 s, land softly on the pad.
extends FlightTask

const LOW := 1.5
const HIGH := 2.5
const HOLD := 3.0
const SOFT := 0.5  # m/s at touchdown
const PAD := 3.0  # m from the pad centre

var _phase := 0
var _timer := 0.0


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var alt := sim.altitude()
	match _phase:
		0:
			# A gold sphere 2 m above the pad shows where to go.
			marker = world.pad + Vector3(0, 2, 0)
			beacon = 0.6
			progress = clampf(alt / 2.0, 0.0, 1.0) / 3.0
			say("HINT_TAKEOFF_UP")
			stick_hint = {"left": Vector2.UP} if sim.on_ground else {}
			if alt >= LOW and alt <= HIGH and not sim.on_ground:
				_phase = 1
				_timer = 0.0
		1:
			stick_hint = {}
			if alt >= LOW and alt <= HIGH:
				_timer += dt
				say("HINT_TAKEOFF_HOLD", [ceili(HOLD - _timer)])
			else:
				_timer = 0.0
				say("HINT_TAKEOFF_BACK")
			progress = (1.0 + _timer / HOLD) / 3.0
			if _timer >= HOLD:
				_phase = 2
		2:
			marker = world.pad
			beacon = 0.0
			ring = PAD
			progress = (2.0 + clampf(1.0 - alt / 2.0, 0.0, 0.95)) / 3.0
			say("HINT_TAKEOFF_LAND")
			stick_hint = {"left": Vector2.DOWN} if mode == "kids" else {}
	for e in sim.events:
		if e["type"] != "landed" or _phase != 2:
			continue
		if flat_distance(sim.pos, world.pad) > PAD:
			say_for("HINT_TAKEOFF_MISSED")
			_phase = 0
		elif e["speed"] > SOFT:
			say_for("HINT_TAKEOFF_HARD", [num(e["speed"])])
			_phase = 0
		else:
			pass_with("SUM_TAKEOFF", [num(e["speed"])])
