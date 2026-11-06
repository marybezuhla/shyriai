# SPDX-License-Identifier: GPL-3.0-or-later
# Survey mission "Count the tents": a camp has sprung up after a flood. Take one picture that holds
# every tent, land, and count them from the picture, so the right number of kits is sent.
extends PhotoTask

const SPOTS: Array[Vector3] = [Vector3(-26, 0, -30), Vector3(24, 0, -34), Vector3(0, 0, -44)]

var _tents: Array[Vector3] = []
var _camp := Vector3.ZERO


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	_camp = SPOTS[rng.randi_range(0, SPOTS.size() - 1)]
	var n := rng.randi_range(5, 9)
	var tries := 0
	while _tents.size() < n and tries < 300:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 7.0)
		var p := _camp + Vector3(sin(a) * d, 0, cos(a) * d)
		# Tents stand apart, so each can be counted.
		if _tents.all(func(t): return flat_distance(t, p) > 3.4):
			_tents.append(p)
	for t in _tents:
		world.add_tent(t, rng.randf() * TAU)


## For tests only.
func camp() -> Vector3:
	return _camp


func tent_count() -> int:
	return _tents.size()


func subjects(_sim: DroneSim) -> Array:
	if not photos.is_empty():
		return []
	var tops: Array = _tents.map(func(t): return Vector3(t.x, world.height(t.x, t.z) + 0.6, t.z))
	return [{"id": "camp", "pos": Vector3(_camp.x, world.height(_camp.x, _camp.z), _camp.z), "radius": 8.0,
		"need": {"tilts": ["down"], "min_size": 0.35}, "all": tops}]


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	progress = 0.9 if not photos.is_empty() else 0.0
	if report_open or done or failed:
		return
	if not photos.is_empty():
		marker = world.pad
		if sim.on_ground:
			# Two near misses around the true count, in order; the true one is not always the middle.
			var n := _tents.size()
			var near := [-2, -1, 1, 2]
			near.shuffle()
			var opts := [n, n + near[0], n + near[1]]
			opts.sort()
			report = [{"photo": 0, "prompt": "Q_COUNT", "answer": str(n),
				"options": opts.map(func(o): return [str(o), str(o)])}]
			report_open = true
		else:
			say("HINT_REPORT_LAND")
		return
	marker = Vector3(_camp.x, world.height(_camp.x, _camp.z) + 2.0, _camp.z)
	if sim.on_ground:
		say("HINT_COUNT_UP")
	elif tilt != "down":
		say("HINT_SRV_TILT_DOWN")
	else:
		say("HINT_COUNT_GO")
