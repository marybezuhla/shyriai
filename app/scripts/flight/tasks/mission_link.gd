# SPDX-License-Identifier: GPL-3.0-or-later
# Missions where help in the air goes away, as it does in Ukraine:
#   MIS_CAM_LINK  fly out to a marked spot and hover there. The radio link drops: the drone hovers,
#                 then flies home by itself, and the link comes back near home. Wait calmly, take
#                 control again if needed, and land on the pad.
#   MIS_CAM_JAM   fly out to a marked spot and hover there. The GPS is jammed: the drone stops
#                 holding its place, the wind carries it, and it cannot fly home by itself. Fly it
#                 back by hand and land on the pad.
extends FlightTask

const SPOTS: Array[Vector3] = [Vector3(-40, 0, -55), Vector3(45, 0, -50), Vector3(-62, 0, -12), Vector3(58, 0, 6)]
const HOVER := 2.0
## The link comes back this close to home.
const LINK_BACK := 30.0
const JAM_WIND := 3.0

var phase := "out"
var _spot := Vector3.ZERO
var _over := 0.0
var _lost_t := 0.0
var _t := 0.0


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	_spot = SPOTS[rng.randi_range(0, SPOTS.size() - 1)]
	_spot.y = world.height(_spot.x, _spot.z)


## For tests only: where to fly out to.
func spot() -> Vector3:
	return _spot


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	_t += dt
	match phase:
		"out":
			_out(dt, sim)
		"lost":
			_lost(dt, sim)
		_:
			_back(sim)


func _out(dt: float, sim: DroneSim) -> void:
	marker = _spot
	ring = 4.0
	var near := flat_distance(sim.pos, _spot) < 5.0 and sim.altitude() > 3.0
	_over = _over + dt if near else 0.0
	progress = 0.4 * clampf(1.0 - flat_distance(sim.pos, _spot) / 70.0, 0.0, 1.0) + 0.1 * _over / HOVER
	if sim.on_ground:
		say("HINT_LINK_UP")
	elif near:
		say("HINT_LINK_HOLD", [ceili(HOVER - _over)])
	else:
		say("HINT_LINK_GO")
	if _over < HOVER:
		return
	if key == "MIS_CAM_LINK":
		link_ok = false
		phase = "lost"
		say_for("HINT_LINK_LOST", [], 4.0)
	else:
		sim.gps = false
		sim.set_wind(JAM_WIND, 0.3)
		phase = "back"
		say_for("HINT_JAM", [], 5.0)


func _lost(dt: float, sim: DroneSim) -> void:
	marker = world.pad
	ring = 3.0
	_lost_t += dt
	progress = 0.5 + 0.3 * clampf(1.0 - flat_distance(sim.pos, world.pad) / 70.0, 0.0, 1.0)
	say("HINT_LINK_WAIT")
	# Near home the radio reaches again (and never later than a minute, whatever happened).
	if flat_distance(sim.pos, world.pad) < LINK_BACK or _lost_t > 60.0:
		link_ok = true
		phase = "back"
		say_for("HINT_LINK_BACK", [], 4.0)


func _back(sim: DroneSim) -> void:
	marker = world.pad
	ring = 3.0
	progress = 0.8 + 0.2 * clampf(1.0 - flat_distance(sim.pos, world.pad) / 70.0, 0.0, 1.0)
	say("HINT_JAM_BACK" if key == "MIS_CAM_JAM" else "HINT_LINK_LAND")
	for e in sim.events:
		if e["type"] == "landed" and flat_distance(sim.pos, world.pad) <= 3.0:
			var t := int(ceil(_t))
			pass_with("SUM_" + key, [floori(t / 60.0), t % 60])
