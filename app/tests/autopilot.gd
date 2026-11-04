# SPDX-License-Identifier: GPL-3.0-or-later
# A simple pilot for tests: flies to a point and height using only the four sticks, like a person.
# Not shipped in the APK.
extends RefCounted

var target := Vector3.ZERO
var height := 2.0
var land := false
var descend := -0.35  # throttle while landing
var _int := Vector3.ZERO


func sticks(sim: DroneSim, dt := 1.0 / 60.0) -> Dictionary:
	var e := target - sim.pos
	e.y = 0.0
	var vh := Vector3(sim.vel.x, 0, sim.vel.z)
	var vmax: float = sim.p["vmax"]
	# Speed we want over the ground, then a correction with memory, so wind is beaten too.
	var want := e * 0.6
	if want.length() > vmax * 0.7:
		want = want.normalized() * vmax * 0.7
	var err := want - vh
	_int += err * dt
	_int = _int.limit_length(4.0)
	var cmd := (want + err * 0.8 + _int * 0.9) / vmax
	var pitch := clampf(cmd.dot(sim.forward()), -1.0, 1.0)
	var roll := clampf(cmd.dot(sim.right()), -1.0, 1.0)
	var throttle: float
	if land:
		throttle = descend
	else:
		var vz: float = sim.p["vz"]
		throttle = clampf(((height - sim.altitude()) * 1.2 - sim.vel.y * 0.6) / vz, -1.0, 1.0)
		if sim.on_ground and height > 0.3:
			throttle = 1.0
	return {"throttle": throttle, "yaw": 0.0, "pitch": pitch, "roll": roll}
