# SPDX-License-Identifier: GPL-3.0-or-later
# Plane lesson 5: the stall, high up where it is safe. Throttle off and keep pulling until the wing
# stalls; then push the stick forward and add throttle until the plane flies again. Simple mode has
# no spin and no crash; in Adult mode a stall left alone turns into a spin.
extends WingTask

const START_ALT := 70.0

var _stalled_at := -1.0
var _stall_time := 0.0
## Seconds flown slowly with the throttle closed: a stall counts only after real slowing down.
var _slow_time := 0.0


func start_position() -> Vector3:
	return Vector3(WorldLand.RUNWAY_X, START_ALT, -12.0)


func tune(sim: DroneSim) -> void:
	var w := sim as WingSim
	w.stall_protect = false
	# In Simple mode a full pull must be able to reach the stall.
	w.p["alpha_up"] = maxf(float(w.p["alpha_up"]), 12.0)


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var w := sim as WingSim
	if w.throttle01 < 0.2 and w.speed < 11.0:
		_slow_time += dt
	if _stalled_at < 0.0:
		progress = clampf((14.0 - w.speed) / 6.0, 0.0, 0.5)
		# A real stall: slow, not a quick jerk of the stick at cruise speed.
		if w.stalled and w.speed < WingSim.V_STALL * 1.25 and _slow_time >= 2.0:
			_stalled_at = sim.altitude()
			_stall_time = sim.time
			say_for("HINT_WING_STALL_NOW")
		else:
			say("HINT_WING_STALL_SLOW")
			stick_hint = {"left": Vector2.DOWN, "right": Vector2.DOWN}
		return
	stick_hint = {"left": Vector2.UP, "right": Vector2.UP}
	progress = 0.5 + 0.5 * clampf((w.speed - WingSim.V_STALL) / 4.0, 0.0, 1.0)
	if not w.stalled and w.speed >= 12.0 and w.gamma >= -0.05 and sim.time - _stall_time > 1.0:
		pass_with("SUM_WING_STALL", [maxi(0, roundi(_stalled_at - sim.altitude()))])
	elif sim.altitude() < 8.0:
		fail_with("FAIL_WING_STALL_LOW")
	else:
		say("HINT_WING_STALL_NOW")
