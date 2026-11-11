# SPDX-License-Identifier: GPL-3.0-or-later
# Camera drone mission "Medicine across the river": the bridge is out, and an aid point on the far bank
# needs a first-aid kit. Two kits hang under the drone. Hover over the circle, high enough to be safe
# for the people there, low enough that the wind does not carry the kit away, and drop.
extends FlightTask

const RIVER_Z := Vector2(-21.0, -25.0)
const SPOTS: Array[Vector3] = [Vector3(0, 0, -40), Vector3(22, 0, -48), Vector3(-14, 0, -38)]
## Dropping only between these heights above the ground: lower risks hitting someone, higher lets
## the wind carry the kit off.
const LOW := 3.0
const HIGH := 15.0
## A kit counts in the circle within this many metres of its middle; a bullseye within the first.
const RING := 2.4
const BULL := 1.0
const KITS := 2

var _spot := Vector3.ZERO
var _left := KITS
var _hanging: Node3D
var _falling: Array[Dictionary] = []  # {"node", "pos", "vel"}
## Where the last kit came down, so a pilot (or a test) can allow for the wind on the next one.
var last_landing := Vector3.INF


func configure() -> void:
	action = "ACT_DROP"


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	_spot = SPOTS[rng.randi_range(0, SPOTS.size() - 1)]
	world.add_river(RIVER_Z.x, RIVER_Z.y)
	world.add_ground_target(_spot)
	_hanging = world.add_kit()


## For tests only.
func spot() -> Vector3:
	return Vector3(_spot.x, world.height(_spot.x, _spot.z), _spot.z)


func act(sim: DroneSim) -> void:
	if _left <= 0 or done or failed:
		return
	if sim.on_ground or sim.altitude() < LOW:
		say_for("HINT_MEDS_LOW", [], 2.5)
		return
	if sim.altitude() > HIGH:
		say_for("HINT_MEDS_HIGH", [], 2.5)
		return
	_left -= 1
	var kit: Node3D = world.add_kit()
	_falling.append({"node": kit, "pos": sim.pos + Vector3(0, -0.3, 0), "vel": sim.vel})
	if _left == 0:
		_hanging.visible = false
		action = ""


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	counter = KITS - _left
	counter_max = KITS
	if _hanging.visible:
		_hanging.position = sim.pos + Vector3(0, -0.32, 0)
	var air: Vector3 = sim.wind() if sim.has_method("wind") else Vector3.ZERO
	for k in _falling.duplicate():
		# A small box falls almost freely; the air slows it and pushes it with the wind.
		var v: Vector3 = k["vel"]
		v.y -= 9.8 * dt
		var rel := v - air
		v -= rel * 0.35 * dt
		k["vel"] = v
		k["pos"] += v * dt
		(k["node"] as Node3D).position = k["pos"]
		var g: float = world.height(k["pos"].x, k["pos"].z)
		if k["pos"].y <= g + 0.11:
			_falling.erase(k)
			_landed(k)
			if done or failed:
				return
	progress = 0.5 * (KITS - _left) / KITS
	if _left == 0 and _falling.is_empty() and not done:
		fail_with("FAIL_MEDS_MISSED")
		return
	marker = spot() + Vector3(0, 1.0, 0)
	if sim.on_ground:
		say("HINT_MEDS_UP")
	elif flat_distance(sim.pos, _spot) > 3.0:
		say("HINT_MEDS_GO")
	else:
		say("HINT_MEDS_DROP")


func _landed(k: Dictionary) -> void:
	var at: Vector3 = k["pos"]
	last_landing = at
	(k["node"] as Node3D).position = Vector3(at.x, world.height(at.x, at.z) + 0.11, at.z)
	if world.in_river(at):
		(k["node"] as Node3D).visible = false
		say_for("HINT_MEDS_WATER", [], 3.0)
		return
	var off := flat_distance(at, _spot)
	if off <= BULL:
		pass_with("SUM_MEDS_CENTRE")
	elif off <= RING:
		pass_with("SUM_MEDS_RING")
	else:
		say_for("HINT_MEDS_MISS", [FlightTask.num(off)], 3.0)
