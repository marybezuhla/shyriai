# SPDX-License-Identifier: GPL-3.0-or-later
# A test pilot for the plane: only the four sticks, as a person would use them, in any mode.
# Not shipped in the APK.
extends RefCounted

## Where to fly: a world position. The height of the target is the height to hold.
var target := Vector3.ZERO
var speed := 13.0
var max_bank := deg_to_rad(30.0)
## Fly round the target at this bank instead of towards it (0 = off). The circle is kept centred
## on the target: the heading follows the tangent, corrected towards the wanted radius.
var orbit_bank := 0.0
var orbit_radius := 28.0
## The way through the next ring, if any: the pilot lines up before it.
var through := Vector3.ZERO
var _side_i := 0.0


func sticks(sim: WingSim) -> Dictionary:
	var aim := target
	if through != Vector3.ZERO:
		# Line up: aim at a point before the ring until close and nearly in line.
		var to := target - sim.pos
		var flat := Vector2(to.x, to.z).length()
		var along := -to.normalized().dot(-through)
		if flat > 35.0 and along < 0.9:
			aim = target - through * minf(40.0, flat * 0.6)
		elif along < 0.7:
			aim = target - through * 60.0  # too close and across: go out and line up again
	var d := aim - sim.pos
	var heading := atan2(-d.x, -d.z)
	var err := wrapf(heading - sim.yaw, -PI, PI)
	var want_bank := clampf(-err * 1.6, -max_bank, max_bank)
	if orbit_bank != 0.0:
		# A right turn keeps the centre on the right wing: the heading is a right angle left of the
		# heading to the centre, turned in a little when too far out and out when too close.
		var to_c := target - sim.pos
		var dist := Vector2(to_c.x, to_c.z).length()
		var tangent := atan2(-to_c.x, -to_c.z) + PI / 2.0 - clampf((dist - orbit_radius) * 0.04, -0.6, 0.6)
		var e2 := wrapf(tangent - sim.yaw, -PI, PI)
		want_bank = clampf(orbit_bank - e2 * 1.2, -max_bank, max_bank)
	var g_des := clampf((target.y - sim.pos.y) * 0.04, -0.22, 0.22)
	return _hold(sim, want_bank, g_des, speed)


## Sticks that hold a bank, a climb angle and a speed.
func _hold(sim: WingSim, want_bank: float, g_des: float, v: float) -> Dictionary:
	var roll := 0.0
	if float(sim.p["roll_rate"]) > 0.0:
		var rate := (want_bank - sim.bank) * 3.0 + sim.bank * 0.25
		roll = clampf(rate / deg_to_rad(sim.p["roll_rate"]), -1.0, 1.0)
	else:
		roll = clampf(want_bank / deg_to_rad(sim.p["bank"]), -1.0, 1.0)
	var pitch := 0.0
	if sim.kids:
		pitch = clampf(g_des / deg_to_rad(12.0), -1.0, 1.0)
	else:
		# The angle of attack that carries the weight in this bank, plus a nudge towards the climb.
		var cl := WingSim.G / maxf(cos(sim.bank), 0.5) / (WingSim.K_LIFT * maxf(sim.speed * sim.speed, 25.0))
		var a := cl / WingSim.LIFT_SLOPE + (g_des - sim.gamma) * 0.8
		var e := (a - WingSim.ALPHA_TRIM) / deg_to_rad(sim.p["alpha_up"] if a > WingSim.ALPHA_TRIM else sim.p["alpha_down"])
		pitch = -clampf(e, -1.0, 0.85)  # stick up is nose down
	var t01 := clampf(0.62 + (v - sim.speed) * 0.25 + g_des * 2.0, 0.0, 1.0)
	return {"throttle": t01 * 2.0 - 1.0, "yaw": 0.0, "pitch": pitch, "roll": roll}


## Take-off: full throttle on the runway, lift the nose once fast, then climb straight on.
func takeoff(sim: WingSim) -> Dictionary:
	if sim.on_ground:
		return {"throttle": 1.0, "yaw": 0.0, "pitch": -0.5 if sim.speed > 9.0 else 0.0, "roll": 0.0}
	var s := _hold(sim, 0.0, 0.15, 12.0)
	s["throttle"] = 1.0
	return s


## Landing down a glide line towards a touchdown point, heading along `through`.
func land(sim: WingSim, touch: Vector3, glide: float) -> Dictionary:
	if sim.on_ground:
		return {"throttle": -1.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}
	var dist := (touch - sim.pos).dot(through)
	var line_y := touch.y + maxf(dist, 0.0) * tan(glide)
	var side := (sim.pos - touch).cross(through).y
	_side_i = clampf(_side_i + side / 60.0, -20.0, 20.0)  # the wind pushes steadily: lean into it
	var want_heading := atan2(-through.x, -through.z)
	var err := wrapf(want_heading - sim.yaw, -PI, PI) + clampf(side * 0.08 + _side_i * 0.01, -0.5, 0.5)
	var bank := clampf(-err * 1.5, -max_bank, max_bank)
	var alt := sim.altitude()
	var g_des := clampf(-glide + (line_y - sim.pos.y) * 0.05, -0.25, 0.05)
	if alt < 2.5:
		g_des = -0.03  # flare: level off just above the runway
	var s := _hold(sim, bank, g_des, 11.5)
	if alt < 2.5:
		s["throttle"] = -1.0
	return s


## The stall lesson: pull with the throttle off until the wing stalls, then push and add throttle.
func stall(sim: WingSim, stalled_once: bool) -> Dictionary:
	if not stalled_once:
		# Throttle off, a steady pull to bleed off speed, then all the way back.
		return {"throttle": -1.0, "yaw": 0.0, "pitch": -1.0 if sim.speed < 9.5 else -0.4, "roll": 0.0}
	if sim.stalled or sim.speed < 12.0:
		var s := _hold(sim, 0.0, -0.3, 14.0)
		s["throttle"] = 1.0
		s["pitch"] = maxf(s["pitch"], 0.4)
		return s
	return _hold(sim, 0.0, 0.0, 13.0)
