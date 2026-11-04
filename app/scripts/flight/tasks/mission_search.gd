# SPDX-License-Identifier: GPL-3.0-or-later
# Adult mission: a person is lost in the fields. Search the marked area with the drone's camera,
# hover over the person for 2 s to mark them for the rescuers, then come back and land.
# The person's place is never shown: finding them is the task.
extends FlightTask

const AREA_R := 18.0
const SPOTS: Array[Vector3] = [Vector3(-30, 0, -58), Vector3(36, 0, -52), Vector3(-58, 0, -18), Vector3(54, 0, 8)]

var _area := Vector3.ZERO
var _person := Vector3.ZERO
var _found := false
var _over := 0.0
var _t := 0.0


func configure() -> void:
	view_hint = "drone"


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	_area = SPOTS[rng.randi_range(0, SPOTS.size() - 1)]
	var a := rng.randf() * TAU
	var d := rng.randf_range(3.0, AREA_R - 4.0)
	_person = _area + Vector3(cos(a) * d, 0, sin(a) * d)
	world.add_person(_person)
	_person.y = world.height(_person.x, _person.z)
	_area.y = world.height(_area.x, _area.z)


## For tests only: where the person is.
func person() -> Vector3:
	return _person


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	_t += dt
	beacon = 0.0
	if not _found:
		marker = _area
		ring = AREA_R
		var near := flat_distance(sim.pos, _person) < 6.0 and sim.pos.y - _person.y < 20.0
		if near:
			_over += dt
			say("HINT_SEARCH_MARK", [ceili(2.0 - _over)])
		else:
			_over = 0.0
			if sim.on_ground:
				say("HINT_SEARCH_UP")
			elif flat_distance(sim.pos, _area) > AREA_R:
				say("HINT_SEARCH_GO")
			else:
				say("HINT_SEARCH_LOOK")
		var to_area := clampf(1.0 - flat_distance(sim.pos, _area) / 70.0, 0.0, 1.0)
		progress = 0.4 * to_area + 0.2 * _over / 2.0
		if _over >= 2.0:
			_found = true
			say_for("HINT_SEARCH_FOUND", [], 3.0)
	else:
		marker = world.pad
		ring = 3.0
		progress = 0.6 + 0.4 * clampf(1.0 - flat_distance(sim.pos, world.pad) / 70.0, 0.0, 1.0)
		say("HINT_SEARCH_BACK")
		for e in sim.events:
			if e["type"] == "landed" and flat_distance(sim.pos, world.pad) <= 3.0:
				var t := int(ceil(_t))
				pass_with("SUM_SEARCH", [t / 60, t % 60])
