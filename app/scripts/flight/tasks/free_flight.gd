# SPDX-License-Identifier: GPL-3.0-or-later
# Free flight: no task and no pass, just the field. The pilot picks the wind and the time of day; gold
# balls to collect are there for fun. Pause leads out. In the survey course the camera buttons are
# there too, to practise: any steady picture counts.
extends PhotoTask

const BALLS := 10
## Wind by choice: [steady m/s, gusts m/s].
const WINDS := {"none": [0.0, 0.0], "light": [2.0, 0.4], "gusty": [4.0, 1.5]}

var _balls: Array[Vector3] = []
var _taken: Array[int] = []


func configure() -> void:
	kit = key == "FREE_SURVEY"
	if kit:
		view_hint = "drone"
		if mode == "kids":
			tilt = "angled"
	if mode != "kids":
		var w: Array = WINDS.get(Prefs.free["wind"], WINDS["none"])
		wind = w[0]
		gust = w[1]
		if mode == "pro":
			flight_mode = Prefs.free["fpv"]
	else:
		wind = 0.0


func setup_world() -> void:
	if not Prefs.free["balls"]:
		return
	counter_shown = true
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	var ground := key == "FREE_UGV"
	# A plane cannot hover: its balls are higher, further out and bigger to catch.
	var plane := key == "FREE_WING"
	var tries := 0
	while _balls.size() < BALLS and tries < 200:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(40.0, 130.0) if plane else rng.randf_range(8.0, 34.0)
		var x := sin(a) * d
		var z := -cos(a) * d
		# Not inside a house or a tree: the drone must be able to reach every ball.
		if _blocked(x, z):
			continue
		var up := 0.7 if ground else (rng.randf_range(15.0, 40.0) if plane else rng.randf_range(2.0, 6.0))
		_balls.append(Vector3(x, world.height(x, z) + up, z))
		world.add_balloon(_balls[-1], Pal.c("accent"))


## The plane starts in the air over the runway; the rest start on the pad.
func start_position() -> Vector3:
	if key == "FREE_WING":
		return Vector3(WorldLand.RUNWAY_X, 30.0, -12.0)
	return super()


func _blocked(x: float, z: float) -> bool:
	for h in world.houses:
		if flat_distance(Vector3(x, 0, z), h["pos"]) < 5.0:
			return true
	for o in world.obstacles:
		if o.has("cyl") and Vector2(x, z).distance_to(o["cyl"]) < float(o["r"]) + 2.0:
			return true
	return false


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	counter_max = _balls.size()
	var reach: float = {"FREE_UGV": 1.4, "FREE_WING": 3.0}.get(key, 1.1)
	for i in _balls.size():
		if i not in _taken and sim.pos.distance_to(_balls[i]) < reach:
			_taken.append(i)
			world.pop_balloon(i)
	counter = _taken.size()
	if _balls.is_empty():
		say("HINT_FREE")
	elif _taken.size() == _balls.size():
		say("HINT_FREE_ALL")
	else:
		say("HINT_FREE_BALLS", [_balls.size() - _taken.size()])


## In free flight anything steady in front of the camera makes a picture.
func subjects(sim: DroneSim) -> Array:
	if not kit:
		return []
	var ahead := Photo.camera_basis(sim.yaw, tilt) * Vector3(0, 0, -15)
	return [{"id": "view", "pos": Photo.camera_position(sim.pos, sim.yaw) + ahead, "radius": 6.0, "need": {}}]

