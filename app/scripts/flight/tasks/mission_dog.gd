# SPDX-License-Identifier: GPL-3.0-or-later
# Kids mission "The lost dog": a puppy has run off into the field. No marker shows where: the hint
# says warmer or colder. Fly low near it and it follows the drone; lead it home to the pad.
extends FlightTask

## Where the puppy may be: out in the field, away from the houses and trees.
const SPOTS: Array[Vector3] = [Vector3(-18, 0, -20), Vector3(14, 0, -24), Vector3(-6, 0, -34),
	Vector3(24, 0, -4), Vector3(-30, 0, 12)]
const FOUND := 4.0  # m: close enough over the ground for the puppy to notice the drone
const LOW := 5.0  # m: and low enough
const HOME := 2.5  # m from the middle of the pad
const RUN := 2.2  # m/s: a puppy's trot

var _dog: Node3D
var _at := Vector3.ZERO
var _follows := false
var _last_d := INF
var _t := 0.0


func configure() -> void:
	wind = 0.0


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	_at = SPOTS[rng.randi_range(0, SPOTS.size() - 1)]
	_dog = world.add_dog(_at)


## For tests only.
func dog() -> Vector3:
	return _at


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	_t += dt
	(_dog.get_node("tail") as Node3D).rotation.x = sin(_t * (14.0 if _follows else 5.0)) * 0.5
	var d := flat_distance(sim.pos, _at)
	if not _follows and d <= FOUND and sim.altitude() <= LOW:
		_follows = true
		say_for("HINT_DOG_FOUND", [], 3.0)
	if _follows:
		# The puppy trots after the drone and stops a step behind it.
		var to := Vector3(sim.pos.x - _at.x, 0, sim.pos.z - _at.z)
		if to.length() > 1.2:
			_at += to.normalized() * minf(RUN * dt, to.length() - 1.2)
			_dog.rotation.y = atan2(-to.x, -to.z) + PI / 2.0
		_at.y = world.height(_at.x, _at.z)
		_dog.position = _at
		marker = world.pad
		progress = 0.5 + 0.5 * clampf(1.0 - flat_distance(_at, world.pad) / 40.0, 0.0, 1.0)
		if flat_distance(_at, world.pad) <= HOME:
			pass_with("SUM_DOG")
			return
		say("HINT_DOG_HOME")
		return
	marker = Vector3.INF
	progress = 0.0
	# Warmer or colder: only the change in distance is told, never the way.
	if sim.on_ground:
		say("HINT_DOG_UP")
	elif d <= FOUND * 2.0:
		say("HINT_DOG_LOWER" if sim.altitude() > LOW else "HINT_DOG_NEAR")
	elif _last_d != INF and d < _last_d - 0.02:
		say("HINT_DOG_WARMER")
	elif _last_d != INF and d > _last_d + 0.02:
		say("HINT_DOG_COLDER")
	_last_d = d
