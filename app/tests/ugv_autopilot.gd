# SPDX-License-Identifier: GPL-3.0-or-later
# A test driver for the ground robot: only the sticks, tank or car steering. It turns towards the
# target first, then drives; `gentle` moves the sticks slowly, as for a casualty.
# Not shipped in the APK.
extends RefCounted

var target := Vector3.ZERO
var height := 0.0  # unused on the ground; here so tests can treat every test pilot alike
var top := 0.8  # stick for full speed
var gentle := false
var stop := false
var _cmd := Vector2.ZERO


func sticks(sim: UgvSim, dt := 1.0 / 60.0) -> Dictionary:
	var d := target - sim.pos
	d.y = 0.0
	var dist := d.length()
	var err := 0.0
	if dist > 0.3:
		err = wrapf(atan2(-d.x, -d.z) - sim.yaw, -PI, PI)
	var v := clampf(dist * 0.35, 0.0, top)
	if absf(err) > 0.5:
		v = 0.0  # turn on the spot first
	else:
		v *= cos(err)
	if stop or dist < 0.35:
		v = 0.0
	var turn := clampf(-err * 1.6, -1.0, 1.0) * (0.35 if gentle else 0.6)
	var want := Vector2(clampf(v + turn, -1.0, 1.0), clampf(v - turn, -1.0, 1.0))
	if gentle:
		_cmd = _cmd.move_toward(want, dt * 0.5)
	else:
		_cmd = want
	if sim.tank:
		return {"throttle": _cmd.x, "yaw": 0.0, "pitch": _cmd.y, "roll": 0.0}
	# Car steering: forward from the left stick, turning from the right.
	var fwd := (_cmd.x + _cmd.y) * 0.5
	var steer := (_cmd.x - _cmd.y) * 0.5 / 0.7
	return {"throttle": fwd, "yaw": 0.0, "pitch": 0.0, "roll": clampf(steer, -1.0, 1.0)}
