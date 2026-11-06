# SPDX-License-Identifier: GPL-3.0-or-later
# Survey mission "After the storm": picture every roof in the village from above, land, then say from
# the pictures which roofs are damaged, as an operator does for the repair crews. Damaged roofs have a
# dark hole and fallen tiles on the ground.
extends PhotoTask

var _damaged: Array[int] = []
var _shot: Array[int] = []  # houses in the order they were pictured


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	var all := range(world.houses.size())
	for i in all.size():
		var j := rng.randi_range(i, all.size() - 1)
		var tmp = all[i]
		all[i] = all[j]
		all[j] = tmp
	for i in 3:
		_damaged.append(all[i])
		world.damage_roof(all[i])


## For tests only.
func truth(house: int) -> bool:
	return house in _damaged


## Simple mode forgives one misread roof; Adult none.
func allowed_wrong() -> int:
	return 1 if mode == "simple" else 0


func roof(i: int) -> Vector3:
	return world.houses[i]["pos"] + Vector3(0, 5.0, 0)


func subjects(_sim: DroneSim) -> Array:
	var out := []
	for i in world.houses.size():
		if i not in _shot:
			out.append({"id": str(i), "pos": roof(i), "radius": 4.0,
				"need": {"tilts": ["angled", "down"], "min_size": 0.3, "max_size": 1.8}})
	return out


func on_photo(id: String, _sim: DroneSim) -> bool:
	if int(id) in _shot:
		return false
	_shot.append(int(id))
	return true


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var n: int = world.houses.size()
	counter = _shot.size()
	counter_max = n
	progress = 0.9 * _shot.size() / n
	if report_open or done or failed:
		return
	if _shot.size() == n:
		marker = world.pad
		if sim.on_ground:
			_open_report()
		else:
			say("HINT_REPORT_LAND")
		return
	var next := -1
	var best := INF
	for i in n:
		if i not in _shot and flat_distance(sim.pos, world.houses[i]["pos"]) < best:
			best = flat_distance(sim.pos, world.houses[i]["pos"])
			next = i
	marker = roof(next) + Vector3(0, 4.0, 0)
	if sim.on_ground:
		say("HINT_SURVEY_UP")
	elif tilt == "forward":
		say("HINT_SURVEY_TILT")
	else:
		say("HINT_SURVEY_GO", [n - _shot.size()])


func _open_report() -> void:
	report.clear()
	for k in _shot.size():
		var house: int = _shot[k]
		report.append({"photo": k, "prompt": "Q_ROOF", "answer": "damaged" if house in _damaged else "ok",
			"options": [["damaged", "OPT_DAMAGED"], ["ok", "OPT_INTACT"]]})
	report_open = true
