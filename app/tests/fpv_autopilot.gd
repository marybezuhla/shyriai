# SPDX-License-Identifier: GPL-3.0-or-later
# A test pilot for the FPV drone: only the four sticks, throttle included, in any flight mode.
# Not shipped in the APK.
extends RefCounted

var target := Vector3.ZERO
var height := 3.0  # above the ground
var speed := 5.0  # m/s it aims to fly at
var face_travel := true
var _int := Vector3.ZERO


func sticks(sim: FpvSim, dt := 1.0 / 60.0) -> Dictionary:
	var e := target - sim.pos
	e.y = 0.0
	var vh := Vector3(sim.vel.x, 0, sim.vel.z)
	var want := e * 0.5
	if want.length() > speed:
		want = want.normalized() * speed
	var dv := want - vh
	_int = (_int + dv * dt).limit_length(3.0)
	var acc := dv * 1.6 + _int * 0.6
	# Lean towards the wanted acceleration (drag needs a lean too, to keep the speed).
	acc += vh * float(sim.p["drag"])
	var max_tilt := deg_to_rad(sim.p["tilt"]) * 0.9
	var t_fwd := clampf(atan(acc.dot(sim.forward()) / FpvSim.G), -max_tilt, max_tilt)
	var t_right := clampf(atan(acc.dot(sim.right()) / FpvSim.G), -max_tilt, max_tilt)

	var pitch := 0.0
	var roll := 0.0
	if sim.flight_mode == "acro":
		var now := sim.tilt_angles()
		var max_rate := deg_to_rad(sim.p["rate"])
		pitch = _inv_expo(clampf((t_fwd - now.x) * 6.0 / max_rate, -1.0, 1.0))
		roll = _inv_expo(clampf((t_right - now.y) * 6.0 / max_rate, -1.0, 1.0))
	else:
		var full := deg_to_rad(sim.p["tilt"])
		pitch = clampf(t_fwd / full, -1.0, 1.0)
		roll = clampf(t_right / full, -1.0, 1.0)
		if sim.flight_mode == "horizon":
			# Keep the sticks in the self-levelling part of Horizon.
			pitch = clampf(pitch, -0.28, 0.28)
			roll = clampf(roll, -0.28, 0.28)

	# Throttle: hold the height, and add what the lean takes away.
	var up := sim.att.y.y
	var az := (height - sim.altitude()) * 1.8 - sim.vel.y * 1.4
	var thrust := (FpvSim.G + az) / maxf(up, 0.5)
	var t01 := clampf(thrust / (float(sim.p["thrust"]) * FpvSim.G), 0.0, 1.0)
	if sim.on_ground:
		t01 = sim.hover_throttle() + 0.15

	var yaw_in := 0.0
	if face_travel:
		var d := target - sim.pos
		if Vector2(d.x, d.z).length() > 1.0:
			var heading := atan2(-d.x, -d.z)
			var turn := wrapf(heading - sim.yaw, -PI, PI)
			yaw_in = clampf(-turn * 1.5, -1.0, 1.0)
	return {"throttle": t01 * 2.0 - 1.0, "yaw": yaw_in, "pitch": pitch, "roll": roll}


## The stick that gives this fraction of the full rate, through the drone's expo curve.
func _inv_expo(r: float) -> float:
	var a := absf(r)
	var s := (-0.4 + sqrt(0.16 + 2.4 * a)) / 1.2
	return s if r >= 0.0 else -s
