# SPDX-License-Identifier: GPL-3.0-or-later
# Survey lesson "The grid": fly over a whole field in lanes, at one height, camera straight down and
# not too fast, so every part of it is pictured. This is how maps are made from the air.
extends PhotoTask

## The field: 3 × 3 squares of 10 m, ahead of the pad.
const X0 := -15.0
const Z0 := -50.0
const CELL := 10.0
const N := 3
const LOW := 12.0
const HIGH := 20.0
const FAST := 5.0

var _covered: Array[Vector2i] = []


func configure() -> void:
	super.configure()
	counter_shown = true


func setup_world() -> void:
	# Corner poles, so the field can be seen from far.
	for c in [Vector3(X0, 0, Z0), Vector3(X0 + CELL * N, 0, Z0), Vector3(X0, 0, Z0 + CELL * N),
			Vector3(X0 + CELL * N, 0, Z0 + CELL * N)]:
		world.add_pole(c, 3.0)


func cell_center(c: Vector2i) -> Vector3:
	var x := X0 + (c.x + 0.5) * CELL
	var z := Z0 + (c.y + 0.5) * CELL
	return Vector3(x, world.height(x, z), z)


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	counter_max = N * N
	counter = _covered.size()
	progress = float(_covered.size()) / (N * N)
	if _covered.size() == N * N:
		pass_with("SUM_SRV_GRID")
		return
	var alt := sim.altitude()
	var fast := Vector2(sim.vel.x, sim.vel.z).length() > FAST
	var c := Vector2i(floori((sim.pos.x - X0) / CELL), floori((sim.pos.z - Z0) / CELL))
	var inside := c.x >= 0 and c.x < N and c.y >= 0 and c.y < N
	if inside and tilt == "down" and alt >= LOW and alt <= HIGH and not fast and c not in _covered:
		_covered.append(c)
	# The next square: the nearest one not pictured yet.
	var next := Vector2i(-1, -1)
	var best := INF
	for i in N:
		for j in N:
			var k := Vector2i(i, j)
			if k not in _covered and flat_distance(sim.pos, cell_center(k)) < best:
				best = flat_distance(sim.pos, cell_center(k))
				next = k
	marker = cell_center(next) + Vector3(0, 1.0, 0)
	if sim.on_ground:
		say("HINT_PH_UP")
	elif tilt != "down":
		say("HINT_SRV_TILT_DOWN")
	elif alt < LOW or alt > HIGH:
		say("HINT_GRID_HEIGHT")
	elif fast:
		say("HINT_GRID_SLOW")
	else:
		say("HINT_SRV_GRID", [N * N - _covered.size()])
