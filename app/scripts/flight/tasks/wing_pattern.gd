# SPDX-License-Identifier: GPL-3.0-or-later
# The plane round the field, into the wind, as at a real airfield. The wind comes from either end of
# the runway; the plane waits at the downwind end, facing into it, and the windsock shows why.
#   WING_INTO_WIND  take off into the wind, fly round the field, and make a low pass over the runway
#   WING_PATTERN    the full circuit: take off, fly round, come down the glide and land into the wind.
#                   A bad approach can be broken off: throttle and climb, and the circuit goes on
#                   from the crosswind ring, with no try lost.
extends WingTask

const MID_Z := (WorldLand.RUNWAY_Z0 + WorldLand.RUNWAY_Z1) / 2.0
const HALF := (WorldLand.RUNWAY_Z0 - WorldLand.RUNWAY_Z1) / 2.0
## Rings as (x, height over the ground, distance along the runway into the wind from its middle),
## each in the middle of a leg and facing along it: upwind, crosswind, downwind, base, final. The
## base leg stays in the valley (behind the pilot the hills rise), so the final is short and the
## wheels touch a little before the runway's middle.
const ROUND := [
	[Vector3(6, 20, 80), "up"], [Vector3(-30, 25, 130), "cross"], [Vector3(-68, 22, 10), "down"],
	[Vector3(-40, 18, -72), "base"],
]
const PASS := [[Vector3(6, 9, -48), "up"], [Vector3(6, 8, 10), "up"]]
const GLIDE_RINGS := [[Vector3(6, 6.5, -48), "up"], [Vector3(6, 3.5, -30), "up"]]
## Where the wheels should touch, along the runway from its middle, and the glide down to it.
const TOUCH_U := -12.0
const GLIDE := deg_to_rad(8.0)
## Rings round a field are a guide, not a needle's eye: wider than the lessons' rings.
const RING_R := 8.0
const MAX_DOWN := 3.0

## 1: into the wind is towards the far end (-z); -1: towards the pilot (+z).
var into := 1.0
var go_arounds := 0
var _down := -1.0
var _t := 0.0


## A position from (x, height, distance along the runway into the wind) on flat ground.
func _at(x: float, u: float) -> Vector3:
	return Vector3(x, 0, MID_Z - into * u)


func heading() -> float:
	return 0.0 if into > 0.0 else PI


## The way the plane flies along the runway: into the wind.
func along() -> Vector3:
	return Vector3(0, 0, -into)


func touch_point() -> Vector3:
	return _at(WorldLand.RUNWAY_X, TOUCH_U)


func _pick_end() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = task_seed * 31 + 5
	into = 1.0 if r.randf() < 0.5 else -1.0


func start_position() -> Vector3:
	_pick_end()
	return _at(WorldLand.RUNWAY_X, -HALF + 3.0)


func start_heading() -> float:
	return heading()


func setup_world() -> void:
	_pick_end()
	var list: Array = ROUND + (PASS if key == "WING_INTO_WIND" else GLIDE_RINGS)
	for i in list.size():
		var p: Vector3 = list[i][0]
		var q := _at(p.x, p.z)
		var n: Vector3 = {"up": along(), "down": -along(), "cross": Vector3.LEFT, "base": Vector3.RIGHT}[list[i][1]]
		world.add_hoop(Vector3(q.x, p.y, q.z), n, Pal.TOY["gold"], RING_R)
		# Round the field a ring counts from either side; on the final, only along the runway.
		var final := i >= list.size() - 2
		rings.append({"c": over_ground(q.x, p.y, q.z), "n": n, "r": RING_R, "both": not final})


func tune(sim: DroneSim) -> void:
	wind_from_ahead(sim, heading())


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var w := sim as WingSim
	_t += dt
	var before := ring_i
	ring_step(sim)
	if ring_i > before:
		world.hoop_done(before)
	if key == "WING_PATTERN":
		_landing(w)
		if done or failed:
			return
	progress = 0.9 * float(ring_i) / rings.size()
	if ring_i >= rings.size() and key == "WING_INTO_WIND":
		pass_with("SUM_WING_INTO_WIND", [int(ceil(_t))])
		return
	if w.on_ground and _down < 0.0:
		if not world.on_runway(sim.pos.x, sim.pos.z):
			fail_with("FAIL_WING_OFF_RUNWAY")
		elif w.throttle01 < 0.9:
			say("HINT_WING_WINDSOCK")
			stick_hint = {"left": Vector2.UP}
		else:
			say("HINT_WING_ROTATE")
			stick_hint = {"right": Vector2.DOWN} if w.speed > WingSim.V_STALL else {}
		return
	stick_hint = {}
	if air_warnings(sim):
		return
	if ring_i >= rings.size():
		say("HINT_WING_FLARE" if sim.altitude() < 4.0 else "HINT_WING_GLIDE")
	else:
		say("HINT_WING_RINGS", [rings.size() - ring_i])


## The end of the full circuit: the touchdown, the roll to a stop, or a go-around.
func _landing(w: WingSim) -> void:
	for e in w.events:
		if e["type"] == "landed" and ring_i >= rings.size():
			_touched(w, float(e["speed"]), float(e.get("pitch", 0.0)))
			if failed:
				return
	if _down >= 0.0:
		progress = 0.95
		if not world.on_runway(w.pos.x, w.pos.z):
			fail_with("FAIL_WING_OFF_RUNWAY")
		elif w.vel.length() < 1.5:
			pass_with("SUM_WING_PATTERN", [int(ceil(_t))])
		else:
			say("HINT_WING_ROLL")
		return
	if ring_i < rings.size() or w.on_ground:
		return
	# Past the runway's far end still in the air, or climbing away from the glide: a go-around. The
	# circuit goes on from the crosswind ring.
	var u := (w.pos - _at(WorldLand.RUNWAY_X, 0.0)).dot(along())
	if u > HALF + 10.0 or (w.altitude() > 16.0 and w.gamma > 0.05):
		go_arounds += 1
		restart_rings(1)
		for k in range(1, rings.size()):
			world.hoop_reset(k)
		say_for("HINT_WING_GO_AROUND_DONE", [], 4.0)


func _touched(w: WingSim, down: float, pitch: float) -> void:
	if not world.on_runway(w.pos.x, w.pos.z):
		fail_with("FAIL_WING_OFF_RUNWAY")
	elif down > MAX_DOWN:
		fail_with("FAIL_WING_HARD", [FlightTask.num(down)])
	elif pitch < NO_FLARE:
		fail_with("FAIL_WING_NO_FLARE")
	elif _down < 0.0:
		_down = down
