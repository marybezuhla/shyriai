# SPDX-License-Identifier: GPL-3.0-or-later
# Plane mission: after a flood, photograph four marked houses from above. The plane's camera looks
# straight down and takes the picture by itself when the plane passes low over a roof with its wings
# nearly level.
extends WingTask

const HOUSES := [0, 1, 2, 3]
const NEAR := 12.0
const LOW := 20.0  # low enough for a clear picture of the roof

var _done: Array[int] = []
var _t := 0.0


func setup_world() -> void:
	world.add_river(-84.0, -74.0)
	for i in HOUSES.size():
		world.add_roof_number(HOUSES[i], i + 1)
	counter_shown = true


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	_t += dt
	var w := sim as WingSim
	var next := -1
	var best := INF
	for i in HOUSES.size():
		if i in _done:
			continue
		var at: Vector3 = world.houses[HOUSES[i]]["pos"]
		var d := flat_distance(sim.pos, at)
		if d < NEAR and sim.altitude() < LOW and absf(w.bank) < deg_to_rad(30.0):
			_done.append(i)
			say_for("HINT_WING_PHOTO")
			continue
		if d < best:
			best = d
			next = i
	counter = _done.size()
	counter_max = HOUSES.size()
	progress = float(_done.size()) / HOUSES.size()
	if _done.size() == HOUSES.size():
		pass_with("SUM_MIS_WING_FLOOD", [int(ceil(_t))])
		return
	if next >= 0:
		marker = world.houses[HOUSES[next]]["pos"] + Vector3(0, 7, 0)
	if not air_warnings(sim):
		say("HINT_WING_FLOOD", [HOUSES.size() - _done.size()])
