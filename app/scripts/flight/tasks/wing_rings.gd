# SPDX-License-Identifier: GPL-3.0-or-later
# The plane through rings in the sky, in order:
#   WING_LEVEL        three rings straight ahead at one height: straight and level
#   WING_CIRCUIT      four rings round the field: turns with bank, and holding the height
#   WING_KIDS_STORKS  six rings, with a flock of storks flying ahead to follow (Kids)
#   MIS_WING_CLOUDS   five cloud rings (Kids)
extends WingTask

const ROUTES := {
	"WING_LEVEL": [Vector3(6, 30, -60), Vector3(6, 30, -110), Vector3(6, 30, -160)],
	"WING_CIRCUIT": [Vector3(6, 30, -60), Vector3(-30, 30, -140), Vector3(-65, 30, -80), Vector3(-40, 30, -10)],
	"WING_KIDS_STORKS": [
		Vector3(6, 25, -50), Vector3(-6, 28, -100), Vector3(-35, 30, -140),
		Vector3(-62, 28, -100), Vector3(-55, 25, -50), Vector3(-30, 25, -10),
	],
	"MIS_WING_CLOUDS": [
		Vector3(6, 22, -60), Vector3(10, 28, -120), Vector3(-20, 32, -165),
		Vector3(-60, 28, -140), Vector3(-65, 22, -80),
	],
}

var _t := 0.0
var _storks: Array[Node3D] = []


func setup_world() -> void:
	var pts: Array[Vector3] = []
	pts.assign(ROUTES[key])
	var clouds := key == "MIS_WING_CLOUDS"
	sky_rings(pts, 6.0 if mode == "kids" else 5.0, Pal.TOY["blue"] if clouds else Pal.TOY["gold"])
	if clouds:
		for r in rings:
			AirProps.add_cloud(world, r["c"], 6.0)
	if key == "WING_KIDS_STORKS":
		_storks = AirProps.add_storks(world, 3)
	# No counter: kids follow the storks and rings, with no numbers on their screen.


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	_t += dt
	var before := ring_i
	var r := ring_step(sim)
	if ring_i > before:
		world.hoop_done(before)
	progress = float(ring_i) / rings.size()
	counter = ring_i
	counter_max = rings.size()
	_lead_storks(dt)
	if r == "done":
		# Kids get words, not seconds.
		pass_with("SUM_" + key, [] if mode == "kids" else [int(ceil(_t))])
	elif not air_warnings(sim):
		say("HINT_WING_RINGS", [rings.size() - ring_i])


## The storks fly a little beyond the next ring, so a child can simply follow them.
func _lead_storks(dt: float) -> void:
	if _storks.is_empty() or ring_i >= rings.size():
		return
	var g: Dictionary = rings[ring_i]
	var ahead: Vector3 = g["c"] + g["n"] * 10.0
	var side: Vector3 = Vector3(g["n"].z, 0, -g["n"].x)
	for i in _storks.size():
		var want: Vector3 = ahead + side * (float(i) - 1.0) * 3.0 + Vector3(0, sin(_t * 1.3 + i) * 0.6, 0)
		var s := _storks[i]
		var k := 1.0 - exp(-dt * 0.8)
		var was := s.position
		s.position = s.position.lerp(want, k)
		var d := s.position - was
		if d.length() > 0.001:
			s.look_at(s.position + d, Vector3.UP)
		AirProps.flap(s, _t + i * 0.4)
