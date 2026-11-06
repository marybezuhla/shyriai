# SPDX-License-Identifier: GPL-3.0-or-later
# A simple pilot for tests: flies to a point and height using only the four sticks, like a person.
# Not shipped in the APK.
extends RefCounted

var target := Vector3.ZERO
var height := 2.0
var land := false
var descend := -0.35  # throttle while landing
## Where the nose should point: a point to face, or INF to keep it.
var face := Vector3.INF
## Face the way it flies (towards the target).
var face_travel := false
## A speed limit over the ground, e.g. for the survey grid.
var max_speed := INF
var _int := Vector3.ZERO


func sticks(sim: DroneSim, dt := 1.0 / 60.0) -> Dictionary:
	var e := target - sim.pos
	e.y = 0.0
	var vh := Vector3(sim.vel.x, 0, sim.vel.z)
	var vmax: float = sim.p["vmax"]
	# Speed we want over the ground, then a correction with memory, so wind is beaten too.
	var want := e * 0.6
	var top := minf(vmax * 0.7, max_speed)
	if want.length() > top:
		want = want.normalized() * top
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
	var yaw_in := 0.0
	var look := Vector3.INF
	if face_travel:
		look = target
	elif face != Vector3.INF:
		look = face
	if look != Vector3.INF:
		var d := look - sim.pos
		if Vector2(d.x, d.z).length() > 0.5:
			var heading := atan2(-d.x, -d.z)
			var turn := wrapf(heading - sim.yaw, -PI, PI)
			yaw_in = clampf(-turn * 2.5, -1.0, 1.0)
	return {"throttle": throttle, "yaw": yaw_in, "pitch": pitch, "roll": roll}
