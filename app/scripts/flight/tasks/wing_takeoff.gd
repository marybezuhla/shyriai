# SPDX-License-Identifier: GPL-3.0-or-later
# Plane lesson 3: take off from the runway. Full throttle, run up to speed, lift the nose gently,
# climb to 25 m with the wings level. Leaving the runway on the ground ends the try.
extends WingTask

const CLIMB_TO := 25.0


func start_position() -> Vector3:
	return Vector3(WorldLand.RUNWAY_X, 0, WorldLand.RUNWAY_Z0 - 3.0)


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var w := sim as WingSim
	var alt := sim.altitude()
	progress = clampf(alt / CLIMB_TO, 0.0, 1.0)
	marker = over_ground(WorldLand.RUNWAY_X, CLIMB_TO, -120.0)
	if alt >= CLIMB_TO and absf(w.bank) < deg_to_rad(25.0):
		pass_with("SUM_WING_TAKEOFF", [roundi(sim.time)])
		return
	if w.on_ground:
		if not world.on_runway(sim.pos.x, sim.pos.z):
			fail_with("FAIL_WING_OFF_RUNWAY")
		elif w.throttle01 < 0.9:
			say("HINT_WING_THROTTLE_UP")
			stick_hint = {"left": Vector2.UP}
		else:
			say("HINT_WING_ROTATE")
			stick_hint = {"right": Vector2.DOWN} if w.speed > WingSim.V_STALL else {}
		return
	stick_hint = {}
	if not air_warnings(sim):
		say("HINT_WING_CLIMB", [ceili(CLIMB_TO - alt)])
