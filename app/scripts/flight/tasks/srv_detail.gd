# SPDX-License-Identifier: GPL-3.0-or-later
# Survey lesson "Height and detail": a number on a roof can be read only from close above. Higher up
# the picture holds more ground but less detail; the pilot finds the height that is just enough.
extends PhotoTask

const HOUSE := 0

var _n := 0


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	_n = rng.randi_range(12, 98)
	world.add_roof_number(HOUSE, _n)


func _board() -> Vector3:
	return world.houses[HOUSE]["pos"] + Vector3(0, 6.15, 0)


func subjects(_sim: DroneSim) -> Array:
	if not photos.is_empty():
		return []
	return [{"id": "number", "pos": _board(), "radius": 1.2,
		"need": {"tilts": ["down"], "min_size": 0.45, "max_size": 2.0}}]


func on_photo(_id: String, _sim: DroneSim) -> bool:
	# Three numbers to choose from: the real one, its digits swapped (what a blurry glance gives),
	# and another; in a random order.
	var swapped := int(str(_n).reverse())
	var wrong_a := swapped if swapped != _n and _n % 10 != 0 else (_n + 11) % 89 + 10
	var wrong_b := (_n + 37) % 89 + 10
	if wrong_b == wrong_a or wrong_b == _n:
		wrong_b = (_n + 53) % 89 + 10
	var opts: Array = [str(_n), str(wrong_a), str(wrong_b)]
	opts.shuffle()
	report = [{"photo": 0, "prompt": "Q_NUMBER", "options": opts.map(func(o): return [o, o]), "answer": str(_n)}]
	report_open = true
	return true


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	if not photos.is_empty():
		return
	marker = _board() + Vector3(0, 2.0, 0)
	if sim.on_ground:
		say("HINT_PH_UP")
	elif tilt != "down":
		say("HINT_SRV_TILT_DOWN")
	else:
		say("HINT_SRV_DETAIL")
