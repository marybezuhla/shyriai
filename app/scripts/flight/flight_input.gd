# SPDX-License-Identifier: GPL-3.0-or-later
# What the pilot's hands say: the sticks on the screen, a gamepad or a radio in joystick mode, and
# a keyboard. Kept apart from flight.gd so that file stays one topic.
class_name FlightInput
extends RefCounted

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
	# A gamepad or a radio in joystick mode, as set up in settings (or the usual gamepad layout).
	for dev in Input.get_connected_joypads():
		if f._thr.spring_y:
			t = _bigger(t, stick(dev, "throttle", f._mode1))
		elif not f._thr.touched:
			# A gamepad or radio drives the throttle until the screen stick is touched, but only once
			# its stick has been moved: a self-centring gamepad would otherwise start at half throttle.
			var a := stick(dev, "throttle", f._mode1, false)
			if absf(a) > 0.2:
				_joy_throttle = true
			if _joy_throttle:
				t = a
		y = _bigger(y, stick(dev, "yaw", f._mode1))
		p = _bigger(p, stick(dev, "pitch", f._mode1))
		r = _bigger(r, stick(dev, "roll", f._mode1))
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


## The usual gamepad layout: Mode 2 has the throttle on the left stick; up reads negative.
static func default_axis(stick_name: String, mode1: bool) -> Dictionary:
	match stick_name:
		"throttle":
			return {"a": JOY_AXIS_RIGHT_Y if mode1 else JOY_AXIS_LEFT_Y, "inv": true}
		"pitch":
			return {"a": JOY_AXIS_LEFT_Y if mode1 else JOY_AXIS_RIGHT_Y, "inv": true}
		"yaw":
			return {"a": JOY_AXIS_LEFT_X, "inv": false}
	return {"a": JOY_AXIS_RIGHT_X, "inv": false}


## One stick from a radio or gamepad, -1..1 with up and right positive.
static func stick(dev: int, stick_name: String, mode1 := false, dead := true) -> float:
	var m: Dictionary = Prefs.pad_axes.get(stick_name, default_axis(stick_name, mode1))
	var v := Input.get_joy_axis(dev, int(m["a"]) as JoyAxis) * (-1.0 if m["inv"] else 1.0)
	return 0.0 if dead and absf(v) < float(Prefs.PAD_DEAD.get(Prefs.pad_dead, 0.08)) else v


func _keys(plus: Key, minus: Key) -> float:
	return float(Input.is_physical_key_pressed(plus)) - float(Input.is_physical_key_pressed(minus))


func _bigger(a: float, b: float) -> float:
	return a if absf(a) >= absf(b) else b


## The usual buttons: Start pauses, Y changes the view, the right shoulder arms an FPV drone.
const DEFAULT_BUTTONS := {"pause": {"b": JOY_BUTTON_START}, "view": {"b": JOY_BUTTON_Y}, "arm": {"b": JOY_BUTTON_RIGHT_SHOULDER}}

var _arm_axis_was := 0.0


static func binding(action: String) -> Dictionary:
	return Prefs.pad_buttons.get(action, DEFAULT_BUTTONS[action])


## The action a joypad button press stands for, or "".
static func button_action(event: InputEventJoypadButton) -> String:
	if not event.pressed:
		return ""
	for action in Prefs.PAD_BUTTONS:
		var b := binding(action)
		if b.has("b") and int(b["b"]) == event.button_index:
			return action
	return ""


## A radio's arm switch is often an axis: flipped up arms, flipped down disarms. Returns 1, -1 or 0
## on the step it moves.
func arm_switch() -> int:
	var b := binding("arm")
	if not b.has("a"):
		return 0
	var v := 0.0
	for dev in Input.get_connected_joypads():
		v = Input.get_joy_axis(dev, int(b["a"]) as JoyAxis)
	var out := 0
	if v > 0.5 and _arm_axis_was <= 0.5:
		out = 1
	elif v < -0.5 and _arm_axis_was >= -0.5:
		out = -1
	_arm_axis_was = v
	return out
