# SPDX-License-Identifier: GPL-3.0-or-later
# A task flown with a camera: the gimbal tilts, the shutter takes a picture of whatever is worth one,
# and some tasks end with a report, made on the ground from the pictures, as real operators do.
class_name PhotoTask
extends FlightTask

## Whether the camera buttons are shown: free flight is a PhotoTask too, but has them only in the
## survey course.
var kit := true
var tilt := "forward"
## A picture is kept only for this flight; past this many, the shutter asks to land first.
const MAX_PHOTOS := 30
## How fast the drone is turning (rad/s): turning while shooting smears the picture too.
var turn := 0.0
## The screen's width over its height, set by the flight; the frame depends on it.
var aspect := 2.0
## Pictures taken: {"id": subject, "image": Image or null}. The flight adds the image.
var photos: Array[Dictionary] = []
## The report: {"photo": index, "prompt": key, "options": [[id, key], ...], "answer": id, "given": id}.
var report: Array[Dictionary] = []
var report_open := false
## Report items answered wrong, shown on the result card.
var wrong: Array[int] = []
var _prev_yaw := INF


func configure() -> void:
	view_hint = "drone"


func step(dt: float, sim: DroneSim, sticks: Dictionary) -> void:
	if _prev_yaw != INF and dt > 0.0:
		turn = wrapf(sim.yaw - _prev_yaw, -PI, PI) / dt
	_prev_yaw = sim.yaw
	super.step(dt, sim, sticks)


## Override: what is worth a picture now: [{"id", "pos", "radius", "need"}] (see Photo.verdict).
func subjects(_sim: DroneSim) -> Array:
	return []


## Override: a good picture of `id` was taken. Return false to refuse it (e.g. taken already).
func on_photo(_id: String, _sim: DroneSim) -> bool:
	return true


## Override: kids' pictures forgive more: farther, closer, a little shake.
func lenient() -> bool:
	return mode == "kids"


## Override: how many report answers may be wrong for a pass.
func allowed_wrong() -> int:
	return 0


func cycle_tilt() -> void:
	var i := Photo.TILT_ORDER.find(tilt)
	tilt = Photo.TILT_ORDER[(i + 1) % Photo.TILT_ORDER.size()]


## The shutter. Says why a picture would not do, or keeps it. Returns {"ok", "id"}.
func shoot(sim: DroneSim) -> Dictionary:
	if photos.size() >= MAX_PHOTOS:
		say_for("PH_FULL", [], 2.5)
		return {"ok": false, "id": ""}
	var cam_pos := Photo.camera_position(sim.pos, sim.yaw)
	var basis := Photo.camera_basis(sim.yaw, tilt)
	var speed := sim.vel.length()
	var best_reason := ""
	var best_off := INF
	for s in subjects(sim):
		var need: Dictionary = s.get("need", {}).duplicate()
		if lenient():
			need["min_size"] = float(need.get("min_size", 0.1)) * 0.6
			need.erase("tilts")
			need.erase("center")
		var seen := Photo.look(cam_pos, basis, aspect, s["pos"], s["radius"])
		var why := Photo.verdict(seen, speed * (0.5 if lenient() else 1.0), turn, tilt, need)
		# Some pictures must hold a whole group, e.g. every tent of a camp.
		if why == "":
			for q in s.get("all", []):
				if not Photo.look(cam_pos, basis, aspect, q, 0.5)["in_frame"]:
					why = "PH_NOT_ALL"
					break
		if why == "" and on_photo(s["id"], sim):
			photos.append({"id": s["id"], "image": null})
			say_for("PH_OK", [], 1.5)
			return {"ok": true, "id": s["id"]}
		# The subject nearest the middle of the frame explains what went wrong.
		var off: float = seen["at"].length() if seen["at"] != Vector2.INF else 99.0
		if off < best_off:
			best_off = off
			best_reason = why if why != "" else "PH_TAKEN"
	say_for(best_reason if best_reason != "" else "PH_NOTHING", [], 2.5)
	return {"ok": false, "id": ""}


func answer(i: int, option: String) -> void:
	report[i]["given"] = option
	for r in report:
		if not r.has("given"):
			return
	report_open = false
	wrong.clear()
	for j in report.size():
		if report[j]["given"] != report[j]["answer"]:
			wrong.append(j)
	var right := report.size() - wrong.size()
	if wrong.size() <= allowed_wrong():
		pass_with("SUM_REPORT", [right, report.size()])
	else:
		fail_with("FAIL_REPORT", [right, report.size()])
