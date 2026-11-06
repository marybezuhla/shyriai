# SPDX-License-Identifier: GPL-3.0-or-later
# Survey mission "Search the field": someone in a red jacket is somewhere out in the fields. Find them,
# take a picture from above, land, and report where they are as seen from the take-off point, so the
# rescuers know which way to go.
extends PhotoTask

## Where a person can be: to the left, straight ahead, or to the right of the pad, far enough apart
## that the answer is never in doubt.
const ZONES := {
	"left": [Vector2(-40, -36), Vector2(-16, -8)],
	"ahead": [Vector2(-5, -48), Vector2(5, -34)],
	"right": [Vector2(16, -36), Vector2(40, -8)],
}

var _side := ""
var _at := Vector3.ZERO


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	var sides := ZONES.keys()
	for tries in 50:
		_side = sides[rng.randi_range(0, sides.size() - 1)]
		var box: Array = ZONES[_side]
		var x := rng.randf_range(box[0].x, box[1].x)
		var z := rng.randf_range(box[0].y, box[1].y)
		_at = Vector3(x, world.height(x, z), z)
		# Not hidden under a house.
		if world.houses.all(func(h): return flat_distance(_at, h["pos"]) > 7.0):
			break
	world.add_person(_at)


## For tests only.
func person() -> Vector3:
	return _at


func side() -> String:
	return _side


func subjects(_sim: DroneSim) -> Array:
	if not photos.is_empty():
		return []
	return [{"id": "person", "pos": _at + Vector3(0, 0.5, 0), "radius": 0.9,
		"need": {"tilts": ["angled", "down"], "min_size": 0.08}}]


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	progress = 0.9 if not photos.is_empty() else 0.0
	if report_open or done or failed:
		return
	if not photos.is_empty():
		marker = world.pad
		if sim.on_ground:
			report = [{"photo": 0, "prompt": "Q_FIND_SIDE", "answer": _side,
				"options": [["left", "OPT_LEFT"], ["ahead", "OPT_AHEAD"], ["right", "OPT_RIGHT"]]}]
			report_open = true
		else:
			say("HINT_REPORT_LAND")
		return
	# No marker: finding them is the task. The hint suggests a search pattern instead.
	marker = Vector3.INF
	if sim.on_ground:
		say("HINT_FIND_UP")
	elif sim.altitude() < 8.0:
		say("HINT_FIND_HIGHER")
	else:
		say("HINT_FIND_PATTERN")
