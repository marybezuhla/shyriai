# SPDX-License-Identifier: GPL-3.0-or-later
# Lesson 1: what each stick does. Try all four moves; nothing can go wrong.
extends FlightTask

var _up := false
var _turned := 0.0
var _fwd := 0.0
var _side := 0.0
var _last_yaw := 0.0
var _last_pos := Vector3.ZERO
var _started := false


func update(_dt: float, sim: DroneSim, sticks: Dictionary) -> void:
	if not _started:
		_last_yaw = sim.yaw
		_last_pos = sim.pos
		_started = true
	if sim.altitude() > 1.0:
		_up = true
	if not sim.on_ground:
		_turned += absf(wrapf(sim.yaw - _last_yaw, -PI, PI))
		var moved := sim.pos - _last_pos
		if absf(sticks["pitch"]) > 0.3:
			_fwd += absf(moved.dot(sim.forward()))
		if absf(sticks["roll"]) > 0.3:
			_side += absf(moved.dot(sim.right()))
	_last_yaw = sim.yaw
	_last_pos = sim.pos

	var yaw_ok := _turned > PI / 2.0
	var fwd_ok := _fwd > 3.0
	var side_ok := _side > 3.0
	var n := int(_up) + int(yaw_ok) + int(fwd_ok) + int(side_ok)
	progress = n / 4.0
	if n == 4:
		pass_with("SUM_STICKS")
	elif not _up:
		say("HINT_STICKS_UP")
	elif not yaw_ok:
		say("HINT_STICKS_YAW")
	elif not fwd_ok:
		say("HINT_STICKS_FWD")
	else:
		say("HINT_STICKS_SIDE")
