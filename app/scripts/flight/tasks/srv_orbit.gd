# SPDX-License-Identifier: GPL-3.0-or-later
# Survey lesson "Around it": a full circle round a water tower, keeping it in the middle of the camera
# all the way. Turning and sliding sideways together, as for filming or looking at a thing from all
# sides.
extends PhotoTask

const TOWER := Vector3(0, 0, -20)
const NEAR := 8.0
const FAR := 18.0
const LOW := 6.0
const HIGH := 16.0
## How far the tank may drift from the middle, across the frame (0..1).
const KEEP := 0.4

var _turned := 0.0
var _last := INF


func setup_world() -> void:
	world.add_tower(TOWER)


func tank() -> Vector3:
	return Vector3(TOWER.x, world.height(TOWER.x, TOWER.z) + 10.0, TOWER.z)


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	progress = clampf(absf(_turned) / TAU, 0.0, 1.0)
	if progress >= 1.0:
		pass_with("SUM_SRV_ORBIT")
		return
	var d := flat_distance(sim.pos, TOWER)
	var alt := sim.altitude()
	var seen := Photo.look(Photo.camera_position(sim.pos, sim.yaw), Photo.camera_basis(sim.yaw, tilt), aspect, tank(), 1.4)
	# Across the frame is the pilot's job; up and down depends on the camera's tilt and the height.
	var centred: bool = seen["in_frame"] and absf((seen["at"] as Vector2).x) <= KEEP
	var ok := d >= NEAR and d <= FAR and alt >= LOW and alt <= HIGH and centred
	var a := atan2(sim.pos.x - TOWER.x, sim.pos.z - TOWER.z)
	if ok and _last != INF:
		_turned += wrapf(a - _last, -PI, PI)
	_last = a if ok else INF
	marker = Vector3.INF if ok else tank()
	if sim.on_ground:
		say("HINT_PH_UP")
	elif d < NEAR or d > FAR or alt < LOW or alt > HIGH:
		say("HINT_ORBIT_RING")
	elif not centred:
		say("HINT_ORBIT_CENTRE")
	else:
		say("HINT_ORBIT_GO", [int(round(progress * 100.0))])
