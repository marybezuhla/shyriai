# SPDX-License-Identifier: GPL-3.0-or-later
# The interception course: catch a moving training target in the air by touching it. The target is an
# abstract striped ball, on a set path: straight, round, weaving. What is taught is the pursuit: catch
# up, lead the target (aim where it will be), meet it head on. Kids catch butterflies instead.
extends FlightTask

## How close counts as a touch, metres: the ball is 0.55 m round, the drone about 0.3 m.
const CATCH := {"kids": 1.5, "simple": 1.4, "pro": 1.2}
## Target speed per task, m/s, for Simple and Adult. The FPV drone tops out near 7.5 m/s in Simple
## and 22 m/s in Adult, so each target can be caught, but not by flying straight at it every time.
const SPEED := {
	"INT_CHASE": [4.0, 9.0], "INT_TURN": [3.5, 8.0], "INT_LEAD": [5.0, 13.0], "INT_HEADON": [4.0, 10.0],
	"INT_NIGHT": [3.5, 8.0], "MIS_INT_PATROL": [4.5, 11.0], "MIS_INT_FAST": [6.0, 14.0],
	"MIS_INT_FOG": [4.5, 11.0],
}
## Beyond this far from the pad a target has got away. Paths keep above the poplars (11 m) and the
## roofs wherever they cross them.
const ARENA := 110.0
const BUTTERFLY_COLORS := ["#E5708B", "#5B9BD5", "#FFC321", "#7DBE6A", "#B07CD8"]

## Each target: {"node", "pos", "vel", "kind", ... path settings, "caught", "active"}.
var targets: Array[Dictionary] = []
var limit := 60.0
var _time := 0.0
var _speed := 4.0


func configure() -> void:
	target_info = mode != "kids"
	if key == "INT_NIGHT":
		look = "dusk"
	elif key == "MIS_INT_FOG":
		look = "fog"
	var s: Array = SPEED.get(key, [4.0, 9.0])
	_speed = s[1] if mode == "pro" else s[0]


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	var night := key == "INT_NIGHT"
	match key:
		"INT_CHASE":
			_add({"kind": "line", "pos": Vector3(0, 10, -22), "vel": Vector3(0, 0, -1)}, night)
		"INT_TURN", "INT_NIGHT":
			# Over the poplars (11 m), which the circle crosses.
			_add({"kind": "circle", "center": Vector3(0, 13, -40), "radius": 22.0, "phase": rng.randf() * TAU,
				"dir": 1.0 if rng.randf() < 0.5 else -1.0}, night)
		"INT_LEAD":
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			_add({"kind": "line", "pos": Vector3(-70 * side, 9, -24), "vel": Vector3(side, 0, 0)}, night)
		"INT_HEADON":
			# Down the gap east of the poplar row, high enough to clear it anyway.
			_add({"kind": "line", "pos": Vector3(rng.randf_range(0, 10), 13, -120), "vel": Vector3(0, 0, 1)}, night)
		"MIS_INT_PATROL", "MIS_INT_FOG":
			for i in 3:
				var a := rng.randf_range(-1.2, 1.2) + (PI if i == 1 else 0.0)
				var from := Vector3(sin(a) * 90.0, rng.randf_range(12, 15), -40 - cos(a) * 60.0)
				var to := Vector3(rng.randf_range(-20, 20), from.y, rng.randf_range(-60, -20))
				_add({"kind": "line", "pos": from, "vel": (to - from).normalized()}, false)
			for i in range(1, targets.size()):
				targets[i]["active"] = false
				targets[i]["node"].visible = false
		"MIS_INT_FAST":
			# Gentle weaves: about a quarter of its speed sideways, a swing every eight seconds.
			_add({"kind": "weave", "pos": Vector3(-50, 13, -40), "vel": Vector3(1, 0, -0.3).normalized(),
				"amp": _speed * 0.35, "freq": 0.12}, false)
		"INT_KIDS_BUTTERFLY":
			_add_butterfly(Vector3(0, 2.5, -12), 6.0, rng)
		"MIS_INT_KIDS":
			for i in 5:
				var c := Vector3(rng.randf_range(-20, 20), 2.5, rng.randf_range(-35, -8))
				_add_butterfly(c, rng.randf_range(3.0, 6.0), rng)
	limit = 45.0 if key.begins_with("INT_") else 120.0
	if key == "MIS_INT_KIDS" or key == "INT_KIDS_BUTTERFLY":
		limit = INF
	counter_shown = targets.size() > 1
	_place_all(0.0)


func _add(t: Dictionary, light: bool) -> void:
	t["node"] = world.add_target_ball(light)
	t["caught"] = false
	t["active"] = true
	t["t"] = 0.0
	if t["kind"] == "line" or t["kind"] == "weave":
		t["start"] = t["pos"]
		t["vel"] = (t["vel"] as Vector3).normalized() * _speed
	targets.append(t)


func _add_butterfly(center: Vector3, radius: float, rng: RandomNumberGenerator) -> void:
	var c: String = BUTTERFLY_COLORS[targets.size() % BUTTERFLY_COLORS.size()]
	targets.append({"node": world.add_butterfly(Color(c)), "kind": "circle", "center": center, "radius": radius,
		"phase": rng.randf() * TAU, "dir": 1.0, "butterfly": true, "caught": false, "active": true, "t": 0.0})
	_speed = 1.2


## Where each target is at its own time `t`: straight lines, circles, a weave across.
func _where(tg: Dictionary, t: float) -> Vector3:
	var p := Vector3.ZERO
	match tg["kind"]:
		"circle":
			var r: float = tg["radius"]
			var a: float = float(tg["phase"]) + float(tg["dir"]) * t * _speed / r
			var c: Vector3 = tg["center"]
			p = c + Vector3(sin(a), 0, cos(a)) * r
			if tg.has("butterfly"):
				p.y += sin(t * 1.3) * 0.5
		"weave":
			var v: Vector3 = tg["vel"]
			var start: Vector3 = tg["start"]
			var side := v.cross(Vector3.UP).normalized()
			var amp: float = tg["amp"]
			var freq: float = tg["freq"]
			p = start + v * t + side * sin(t * TAU * freq) * amp
		_:
			var v: Vector3 = tg["vel"]
			var start: Vector3 = tg["start"]
			p = start + v * t
	var ground: float = world.height(p.x, p.z)
	# Butterflies keep low over the grass; a target holds its own height and only clears the hills.
	if tg.has("butterfly"):
		return Vector3(p.x, ground + p.y, p.z)
	return Vector3(p.x, maxf(world.pad.y + p.y, ground + 2.0), p.z)


func _place_all(dt: float) -> void:
	for tg in targets:
		if tg["caught"] or not tg["active"]:
			continue
		var before: Vector3 = tg.get("now", Vector3.INF)
		tg["t"] += dt
		tg["now"] = _where(tg, tg["t"])
		tg["speed_vec"] = (tg["now"] - before) / dt if dt > 0.0 and before != Vector3.INF else Vector3.ZERO
		var n: Node3D = tg["node"]
		n.position = tg["now"]
		if tg.has("butterfly"):
			n.rotation.y = atan2(-(tg["speed_vec"] as Vector3).x, -(tg["speed_vec"] as Vector3).z)
			FlightWorld.flap(n, tg["t"])


## The target being chased: the first active one not caught yet.
func current() -> Dictionary:
	for tg in targets:
		if tg["active"] and not tg["caught"]:
			return tg
	return {}


## Where to aim: where the target will be when the drone gets there (a rough guess, as a pilot's).
func lead_point(sim: DroneSim, tg: Dictionary) -> Vector3:
	var d := sim.pos.distance_to(tg["now"])
	var v: Vector3 = tg["speed_vec"]
	var closing := maxf(_closing(sim, tg), 3.0)
	return tg["now"] + v * clampf(d / closing, 0.0, 2.5)


func _closing(sim: DroneSim, tg: Dictionary) -> float:
	var to: Vector3 = (tg["now"] - sim.pos)
	if to.length() < 0.01:
		return 0.0
	return (sim.vel - (tg["speed_vec"] as Vector3)).dot(to.normalized())


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	_time += dt
	_place_all(dt)
	var caught := 0
	for tg in targets:
		caught += int(tg["caught"])
	counter = caught
	counter_max = targets.size()
	progress = float(caught) / targets.size()
	var tg := current()
	if tg.is_empty():
		pass_with("SUM_" + key)
		return
	var d := sim.pos.distance_to(tg["now"])
	target_dist = d
	closing = _closing(sim, tg)
	if d <= float(CATCH.get(mode, 1.2)):
		tg["caught"] = true
		(tg["node"] as Node3D).visible = false
		# The next target of a patrol comes in now.
		for other in targets:
			if not other["active"]:
				other["active"] = true
				other["node"].visible = true
				break
		say_for("HINT_INT_CAUGHT", [], 1.5)
		return
	# Gone: beyond the field and still moving away (a target may come in from far), or past the pad.
	var now: Vector3 = tg["now"]
	var away := Vector2(now.x - world.pad.x, now.z - world.pad.z)
	var v: Vector3 = tg["speed_vec"]
	var leaving := away.dot(Vector2(v.x, v.z)) > 0.0
	if (away.length() > ARENA and leaving) or (key == "INT_HEADON" and now.z > 15.0):
		fail_with("FAIL_INT_GONE")
		return
	if _time > limit:
		fail_with("FAIL_INT_TIME")
		return
	# Where to look: in Simple and for kids, and in the lesson about it, the lead point; otherwise
	# the target itself, so it can be found when it is off the screen.
	var show_lead := mode != "pro" or key == "INT_LEAD"
	marker = lead_point(sim, tg) if show_lead else tg["now"]
	if sim.on_ground:
		say("HINT_INT_UP")
	elif key == "INT_LEAD" or (show_lead and closing < 0.5):
		say("HINT_INT_LEAD")
	elif closing < 0.0:
		say("HINT_INT_BEHIND")
	else:
		say("HINT_" + key)
