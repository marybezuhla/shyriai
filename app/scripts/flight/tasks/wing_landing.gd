# SPDX-License-Identifier: GPL-3.0-or-later
# Plane lesson 6: land on the runway. The plane comes in from far down the valley; three rings mark a
# gentle glide (little throttle, nose a touch up). It counts when the wheels touch the runway at no
# more than 3 m/s down and the plane rolls to a stop on it.
extends WingTask

const TOUCH_Z := -50.0
const GLIDE := deg_to_rad(7.0)
const MAX_DOWN := 3.0

var _down := -1.0


func start_position() -> Vector3:
	return Vector3(WorldLand.RUNWAY_X, _glide_height(-230.0), -230.0)


func start_heading() -> float:
	return PI  # towards the pilot, down the valley


func _glide_height(z: float) -> float:
	return (TOUCH_Z - z) * tan(GLIDE)


func setup_world() -> void:
	var pts: Array[Vector3] = []
	for z in [-180.0, -130.0, -95.0]:
		pts.append(Vector3(WorldLand.RUNWAY_X, _glide_height(z), z))
	sky_rings(pts, 6.0, Pal.TOY["gold"])


func tune(sim: DroneSim) -> void:
	# Coming in on the glide already: the motor at a little more than idle.
	(sim as WingSim).throttle01 = 0.35


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var w := sim as WingSim
	var before := ring_i
	ring_step(sim)
	if ring_i > before:
		world.hoop_done(before)
	for e in sim.events:
		if e["type"] == "landed":
			_touched(sim, float(e["speed"]))
			if failed:
				return
	if _down >= 0.0:
		progress = 0.9
		if w.on_ground and w.speed < 1.5:
			pass_with("SUM_WING_LANDING", [FlightTask.num(_down)])
		else:
			say("HINT_WING_ROLL")
		return
	progress = clampf((sim.pos.z + 230.0) / 180.0, 0.0, 0.85)
	if ring_i >= rings.size():
		marker = Vector3(WorldLand.RUNWAY_X, 0, TOUCH_Z)
		ring = 4.0
	if sim.pos.z > WorldLand.RUNWAY_Z0 + 15.0 and not w.on_ground:
		say("HINT_WING_GO_AROUND")
	elif not air_warnings(sim):
		say("HINT_WING_FLARE" if sim.altitude() < 4.0 else "HINT_WING_GLIDE")


func _touched(sim: DroneSim, down: float) -> void:
	if not world.on_runway(sim.pos.x, sim.pos.z):
		fail_with("FAIL_WING_OFF_RUNWAY")
	elif down > MAX_DOWN:
		fail_with("FAIL_WING_HARD", [FlightTask.num(down)])
	elif _down < 0.0:
		_down = down
