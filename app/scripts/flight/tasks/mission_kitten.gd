# SPDX-License-Identifier: GPL-3.0-or-later
# Kids mission: find the kitten on a roof, then fly back to the rescuers by the pad.
# Sunflowers on the way are a bonus, not a requirement.
extends FlightTask

const SEEN := 5.0  # m from the kitten
const HOME := 3.0  # m from the pad

var _found := false
var _taken: Array[int] = []


func configure() -> void:
	wind = 0.0


func setup_world() -> void:
	counter_shown = true
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	world.add_kitten(rng.randi_range(0, 3))  # one of the houses in front of the pilot
	world.add_van(Vector3(4, 0, 2.5))
	var pts: Array[Vector3] = []
	for i in 5:
		var t := (i + 1) / 6.0
		var p: Vector3 = world.pad.lerp(world.kitten, t)
		p.y = 2.5 + 1.5 * sin(t * PI)
		p.x += 3.0 * sin(i * 1.7)
		pts.append(p)
	world.add_sunflowers(pts)


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	counter_max = world.sunflowers.size()
	for i in world.sunflowers.size():
		if i in _taken:
			continue
		if sim.pos.distance_to(world.sunflowers[i]) < 1.6:
			_taken.append(i)
			world.take_sunflower(i)
	counter = _taken.size()

	if not _found:
		marker = world.kitten
		ring = 0.0
		progress = 0.5 * clampf(1.0 - flat_distance(sim.pos, world.kitten) / 40.0, 0.0, 1.0)
		say("HINT_KITTEN_FIND")
		if sim.pos.distance_to(world.kitten) < SEEN:
			_found = true
			world.kitten_found()
	else:
		marker = world.pad
		ring = HOME
		progress = 0.5 + 0.5 * clampf(1.0 - flat_distance(sim.pos, world.pad) / 40.0, 0.0, 1.0)
		say("HINT_KITTEN_BACK")
		if flat_distance(sim.pos, world.pad) < HOME and sim.altitude() < 3.0:
			pass_with("SUM_KITTEN", [counter, counter_max])
