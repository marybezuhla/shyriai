# SPDX-License-Identifier: GPL-3.0-or-later
# Photograph each thing on a list. The survey lessons "camera down" and "a sharp picture", and the
# kids' photographer lessons and album, differ only in what is on the list and how strict it is.
extends PhotoTask

## The ground mark for "camera down", in front of the pad.
const MARK := Vector3(0, 0, -16)
## Round signs on posts for "a sharp picture": stop, aim, shoot, fly on.
const SIGNS: Array[Vector3] = [Vector3(-6, 0, -12), Vector3(6, 0, -20), Vector3(-4, 0, -28)]
const SIGN_COLORS := ["#E5708B", "#5B9BD5", "#7DBE6A"]
## The kids' subjects: the sunflowers by the field, a kitten, a blue van.
const FLOWERS := Vector3(-12, 0, -18)
const KITTEN := Vector3(8, 0, -14)
const VAN := Vector3(-6, 0, -26)

var _list: Array[Dictionary] = []
var _taken: Array[String] = []


func configure() -> void:
	super.configure()
	if mode == "kids":
		tilt = "angled"  # the kids' camera keeps one good angle


func setup_world() -> void:
	match key:
		"SRV_TILT":
			world.add_ground_target(MARK)
			_add("mark", MARK + Vector3(0, 0.05, 0), 2.4,
				{"tilts": ["down"], "min_size": 0.3, "max_size": 1.6, "center": 0.35})
		"SRV_SHARP":
			for i in SIGNS.size():
				world.add_sign(SIGNS[i], Color(SIGN_COLORS[i]))
				_add("sign%d" % i, SIGNS[i] + Vector3(0, 2.2, 0), 0.45, {"min_size": 0.12, "max_size": 1.2})
		"SRV_KIDS_FLOWER":
			_add("flowers", FLOWERS + Vector3(0, 1.3, 0), 1.6, {"min_size": 0.15})
		"SRV_KIDS_KITTEN":
			world.add_kitten_at(KITTEN)
			_add("kitten", KITTEN + Vector3(0, 0.3, 0), 0.6, {"min_size": 0.12})
		"SRV_KIDS_VAN":
			world.add_van(VAN)
			_add("van", VAN + Vector3(0, 1.0, 0), 1.6, {"min_size": 0.15})
		"MIS_SRV_ALBUM":
			world.add_kitten_at(KITTEN)
			world.add_van(VAN)
			_add("flowers", FLOWERS + Vector3(0, 1.3, 0), 1.6, {"min_size": 0.15})
			_add("kitten", KITTEN + Vector3(0, 0.3, 0), 0.6, {"min_size": 0.12})
			_add("van", VAN + Vector3(0, 1.0, 0), 1.6, {"min_size": 0.15})
	counter_shown = _list.size() > 1


func _add(id: String, at: Vector3, radius: float, need: Dictionary) -> void:
	_list.append({"id": id, "pos": Vector3(at.x, world.height(at.x, at.z) + at.y, at.z), "radius": radius, "need": need})


func subjects(_sim: DroneSim) -> Array:
	return _list.filter(func(s): return s["id"] not in _taken)


func on_photo(id: String, _sim: DroneSim) -> bool:
	if id in _taken:
		return false
	_taken.append(id)
	return true


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	counter = _taken.size()
	counter_max = _list.size()
	progress = float(_taken.size()) / _list.size()
	if _taken.size() == _list.size():
		pass_with("SUM_" + key)
		return
	var next: Dictionary = _nearest(sim)
	marker = next["pos"] + Vector3(0, 1.5, 0)
	beacon = 0.0
	if sim.on_ground:
		say("HINT_PH_UP")
	elif key == "SRV_TILT" and tilt != "down":
		say("HINT_SRV_TILT_DOWN")
	else:
		say("HINT_" + key)


func _nearest(sim: DroneSim) -> Dictionary:
	var left := subjects(sim)
	left.sort_custom(func(a, b): return sim.pos.distance_to(a["pos"]) < sim.pos.distance_to(b["pos"]))
	return left[0]
