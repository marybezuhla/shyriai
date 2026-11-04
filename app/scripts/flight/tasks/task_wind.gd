# SPDX-License-Identifier: GPL-3.0-or-later
# Lesson 7: no GPS, a strong gusty wind. Reach four points and hold 2 s over each.
extends FlightTask

const HOLD := 2.0

var _held := 0.0


func configure() -> void:
	gps = false
	wind = {"kids": 1.2, "simple": 2.5, "pro": 3.5}.get(mode, 2.5)
	gust = {"kids": 0.3, "simple": 0.6, "pro": 0.7}.get(mode, 0.6)


func setup_world() -> void:
	var pts: Array[Vector3] = [Vector3(-6, 3, -6), Vector3(6, 3, -6), Vector3(6, 3, -14), Vector3(-6, 3, -14)]
	course(pts, 3.0 if mode == "kids" else 2.0, "")


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	if cp >= cps.size():
		return
	var t := course_world_target()
	marker = t
	beacon = cp_radius
	var inside := flat_distance(sim.pos, t) <= cp_radius and absf(sim.pos.y - t.y) <= cp_height_tol
	if inside:
		_held += dt
		say("HINT_WIND_HOLD", [ceili(HOLD - _held)])
		if _held >= HOLD:
			_held = 0.0
			cp += 1
			if cp >= cps.size():
				pass_with("SUM_WIND", ["%.1f" % sim.wind().length()])
				return
	else:
		if _held > 0.3:
			say("HINT_WIND_OUT")
		elif sim.on_ground:
			say("HINT_WIND_UP")
		elif hint != "HINT_WIND_OUT":
			say("HINT_WIND_GO", [cps.size() - cp])
		_held = 0.0
	progress = (cp + _held / HOLD) / cps.size()
