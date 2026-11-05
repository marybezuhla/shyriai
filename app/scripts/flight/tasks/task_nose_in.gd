# SPDX-License-Identifier: GPL-3.0-or-later
# Lesson 4: nose in. The drone faces the pilot the whole lap, so left and right feel reversed.
extends FlightTask

const CENTER := Vector3(0, 0, -4)
const R := 4.0
const LIMIT := 60.0

var _t := 0.0
var _wrong := 0.0


func configure() -> void:
	view_hint = "pilot"


func setup_world() -> void:
	# Eight points round a circle that starts and ends at the pad, 2.5 m up.
	var pts: Array[Vector3] = []
	for i in range(1, 9):
		var a := PI / 2.0 + i * TAU / 8.0
		pts.append(CENTER + Vector3(cos(a) * R, 2.5, sin(a) * R))
	course(pts, 2.5 if mode == "kids" else 1.5, "pilot")


func start_heading() -> float:
	return PI


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	if cp > 0:
		_t += dt
	if mode != "kids" and _t > LIMIT:
		cp = 0
		_t = 0.0
		say_for("HINT_NOSE_SLOW")
		return
	# Outside Kids mode the nose must face the pilot the whole lap, not only at each sphere.
	if mode != "kids" and cp > 0 and not sim.on_ground and not nose_ok(sim):
		_wrong += dt
		if _wrong > 1.5:
			cp = 0
			_t = 0.0
			_wrong = 0.0
			say_for("HINT_NOSE_RESET")
			return
	else:
		_wrong = 0.0
	var r := course_step(sim)
	progress = float(cp) / cps.size()
	if r == "done":
		pass_with("SUM_NOSE_IN", [int(ceil(_t))])
	elif sim.on_ground:
		say("HINT_NOSE_UP")
	elif r == "facing" or not nose_ok(sim):
		say("HINT_NOSE_FACE")
	else:
		say("HINT_NOSE_GO", [cps.size() - cp])
