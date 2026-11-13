# SPDX-License-Identifier: GPL-3.0-or-later
# What the pilot's hands say: the sticks on the screen, a gamepad or a radio in joystick mode, and
# a keyboard. Kept apart from flight.gd so that file stays one topic.
class_name FlightInput
extends RefCounted

const DEADZONE := 0.08

var _joy_throttle := false


## The four sticks, each from -1 to 1.
func read(f: Flight) -> Dictionary:
	if not f._thr.spring_y:
		# Keys move the throttle stick on screen, step by step.
		var k := _keys(KEY_W, KEY_S)
		if k != 0.0:
			f._thr.value.y = clampf(f._thr.value.y + k * Flight.STEP * 0.9, -1.0, 1.0)
			f._thr.queue_redraw()
	var t := f._thr.value.y
	var y := f._left.value.x
	var p := f._fwd.value.y
	var r := f._right.value.x
	# A gamepad or a radio in joystick mode. In Mode 1 its up/down axes swap like the screen sticks.
	var thr_axis := JOY_AXIS_RIGHT_Y if f._mode1 else JOY_AXIS_LEFT_Y
	var fwd_axis := JOY_AXIS_LEFT_Y if f._mode1 else JOY_AXIS_RIGHT_Y
	for dev in Input.get_connected_joypads():
		if f._thr.spring_y:
			t = _bigger(t, -_axis(dev, thr_axis))
		elif not f._thr.touched:
			# A gamepad or radio drives the throttle until the screen stick is touched, but only once
			# its stick has been moved: a self-centring gamepad would otherwise start at half throttle.
			var a := Input.get_joy_axis(dev, thr_axis)
			if absf(a) > 0.2:
				_joy_throttle = true
			if _joy_throttle:
				t = -a
		y = _bigger(y, _axis(dev, JOY_AXIS_LEFT_X))
		p = _bigger(p, -_axis(dev, fwd_axis))
		r = _bigger(r, _axis(dev, JOY_AXIS_RIGHT_X))
	# A keyboard: W/S up and down, A/D turn, arrows move.
	if f._thr.spring_y:
		t = _bigger(t, _keys(KEY_W, KEY_S))
	y = _bigger(y, _keys(KEY_D, KEY_A))
	p = _bigger(p, _keys(KEY_UP, KEY_DOWN))
	r = _bigger(r, _keys(KEY_RIGHT, KEY_LEFT))
	if f.machine != "ugv":
		var e: float = Prefs.STICK_FEELS.get(Prefs.stick_feel, 0.0)
		y = _soft(y, e)
		p = _soft(p, e)
		r = _soft(r, e)
	return {"throttle": t, "yaw": y, "pitch": p, "roll": r}


## Expo: the same full deflection, but gentler near the centre, for fine moves. e = 0 changes nothing.
static func _soft(x: float, e: float) -> float:
	return (1.0 - e) * x + e * x * x * x


func _axis(dev: int, axis: JoyAxis) -> float:
	var v := Input.get_joy_axis(dev, axis)
	return 0.0 if absf(v) < DEADZONE else v


func _keys(plus: Key, minus: Key) -> float:
	return float(Input.is_physical_key_pressed(plus)) - float(Input.is_physical_key_pressed(minus))


func _bigger(a: float, b: float) -> float:
	return a if absf(a) >= absf(b) else b
