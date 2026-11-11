# SPDX-License-Identifier: GPL-3.0-or-later
# Courses and missions: survey, interception, aid drop, lost dog, the ground robot.
extends "res://tests/sim_lessons.gd"


# --- Survey course -------------------------------------------------------------

func test_photo_rules() -> void:
	var pos := Vector3(0, 10, 0)
	var basis := Photo.camera_basis(0.0, "down")
	var below := Photo.look(pos, basis, 2.0, Vector3(0, 0, 0), 2.0)
	check(below["in_frame"] and (below["at"] as Vector2).length() < 0.01, "camera down: the point below is in the middle")
	check(not Photo.look(pos, Photo.camera_basis(0.0, "forward"), 2.0, Vector3(0, 0, 0), 2.0)["in_frame"],
		"camera ahead: the point below is not in the frame")
	check(not Photo.look(pos, basis, 2.0, Vector3(0, 20, 0), 2.0)["in_frame"], "nothing behind the camera")
	var far := Photo.look(pos, basis, 2.0, Vector3(0, 0, 0), 0.5)
	check(Photo.verdict(far, 0.0, 0.0, "down", {"min_size": 0.3}) == "PH_TOO_FAR", "a small thing far below: too far")
	check(Photo.verdict(below, 1.5, 0.0, "down", {}) == "PH_BLUR", "moving: smeared")
	check(Photo.verdict(below, 0.0, 1.0, "down", {}) == "PH_BLUR", "turning: smeared")
	check(Photo.verdict(below, 0.0, 0.0, "forward", {"tilts": ["down"]}) == "PH_TILT_DOWN", "wrong tilt says so")
	check(Photo.verdict(below, 0.0, 0.0, "down", {"tilts": ["down"], "min_size": 0.1}) == "", "a good picture")


## Hover still at a point, set the camera, shoot. True if the picture was kept.
func _shoot_at(task: PhotoTask, sim: DroneSim, ap, target: Vector3, height: float, face: Vector3, tilt: String) -> bool:
	ap.target = target
	ap.height = height
	ap.face = face
	ap.land = false
	task.tilt = tilt
	var still := 0.0
	for i in int(60.0 / DT):
		var s: Dictionary = task.controls(ap.sticks(sim))
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if sim.crashed or task.failed:
			return false
		var here := FlightTask.flat_distance(sim.pos, target) < 0.4 and absf(sim.altitude() - height) < 0.4
		still = still + DT if here and sim.vel.length() < 0.2 and absf(task.turn) < 0.05 else 0.0
		if still > 1.0:
			return task.shoot(sim)["ok"]
	return false


## Fly home and land; the report then opens. True once it is open.
func _land_for_report(task: PhotoTask, sim: DroneSim, world: FlightWorld, ap) -> bool:
	ap.target = world.pad
	ap.face = Vector3.INF
	for i in int(60.0 / DT):
		ap.land = FlightTask.flat_distance(sim.pos, world.pad) < 1.0
		var s: Dictionary = task.controls(ap.sticks(sim))
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if task.report_open:
			return true
		if sim.crashed or task.failed:
			return false
	return false


func _answer_all(task: PhotoTask, right := true) -> void:
	for i in task.report.size():
		var item: Dictionary = task.report[i]
		var pick: String = item["answer"]
		if not right:
			for o in item["options"]:
				if o[0] != pick:
					pick = o[0]
					break
		task.answer(i, pick)


func test_survey_task(key: String, mode: String) -> void:
	var f := _flight(key, mode, "survey")
	var task: PhotoTask = f[0]
	var sim: DroneSim = f[1]
	var world: FlightWorld = f[2]
	var ap := Autopilot.new()
	var ok := true
	match key:
		"SRV_TILT":
			ok = _shoot_at(task, sim, ap, task.MARK, 7.0, Vector3.INF, "down")
		"SRV_SHARP":
			for sgn in task.SIGNS:
				ok = ok and _shoot_at(task, sim, ap, sgn + Vector3(0, 0, 3.5), 2.2, sgn, "forward")
		"SRV_DETAIL":
			ok = _shoot_at(task, sim, ap, world.houses[task.HOUSE]["pos"], 9.0, Vector3.INF, "down")
			ok = ok and task.report_open
			_answer_all(task)
		"SRV_ORBIT":
			var tower: Vector3 = task.TOWER
			for k in 80:
				var a := k * TAU / 72.0
				ap.target = tower + Vector3(sin(a), 0, cos(a)) * 12.0
				ap.height = 12.0
				ap.face = task.tank()
				for i in int(0.6 / DT):
					var s: Dictionary = task.controls(ap.sticks(sim))
					sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
					task.step(DT, sim, s)
				if task.done:
					break
		"SRV_GRID":
			task.tilt = "down"
			ap.height = 15.0
			ap.max_speed = 4.0
			for j in task.N:
				for i in task.N:
					var col: int = i if j % 2 == 0 else task.N - 1 - i
					ap.target = task.cell_center(Vector2i(col, j))
					for n in int(12.0 / DT):
						var s: Dictionary = task.controls(ap.sticks(sim))
						sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
						task.step(DT, sim, s)
						if FlightTask.flat_distance(sim.pos, ap.target) < 1.0:
							break
		"SRV_KIDS_FLOWER", "SRV_KIDS_KITTEN", "SRV_KIDS_VAN", "MIS_SRV_ALBUM":
			for subj in task._list.duplicate():
				var at: Vector3 = subj["pos"]
				ok = ok and _shoot_at(task, sim, ap, at + Vector3(0, 0, 6.0), 5.0, at, task.tilt)
		"MIS_CAM_SURVEY":
			for i in world.houses.size():
				ok = ok and _shoot_at(task, sim, ap, world.houses[i]["pos"], 12.0, Vector3.INF, "down")
			ok = ok and _land_for_report(task, sim, world, ap)
			_answer_all(task)
		"MIS_SRV_FIND":
			ok = _shoot_at(task, sim, ap, task.person(), 12.0, Vector3.INF, "down")
			ok = ok and _land_for_report(task, sim, world, ap)
			_answer_all(task)
		"MIS_SRV_COUNT":
			ok = _shoot_at(task, sim, ap, task.camp(), 18.0, Vector3.INF, "down")
			ok = ok and _land_for_report(task, sim, world, ap)
			_answer_all(task)
	# One more step lets a task notice it is done.
	task.step(DT, sim, {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0})
	check(ok and task.done, "%s: %s passes with the camera" % [mode, key])
	if task.done:
		_passed(task, sim)
	world.queue_free()
	await get_tree().process_frame


## A smeared picture is refused, the wrong tilt is named, and a wrong report does not pass in Adult.
func test_survey_mistakes() -> void:
	var f := _flight("SRV_TILT", "pro", "survey")
	var task: PhotoTask = f[0]
	var sim: DroneSim = f[1]
	sim.pos = task.MARK + Vector3(0, 7, 0)
	sim.vel = Vector3(2, 0, 0)
	task.tilt = "down"
	check(not task.shoot(sim)["ok"] and task.hint_base == "PH_BLUR", "moving: the picture is smeared")
	sim.vel = Vector3.ZERO
	task.tilt = "forward"
	check(not task.shoot(sim)["ok"] and task.hint_base == "PH_TILT_DOWN", "camera ahead: told to turn it down")
	f[2].queue_free()
	for m in ["simple", "pro"]:
		f = _flight("MIS_SRV_COUNT", m, "survey")
		task = f[0]
		task.photos.append({"id": "camp", "image": null})
		task.report = [{"photo": 0, "prompt": "Q_COUNT", "answer": "6", "options": [["5", "5"], ["6", "6"], ["7", "7"]]}]
		task.report_open = true
		_answer_all(task, false)
		check(task.failed and task.wrong == [0], "%s: a wrong count does not pass, and is listed" % m)
		f[2].queue_free()
	f = _flight("MIS_CAM_SURVEY", "simple", "survey")
	task = f[0]
	for i in 6:
		task.photos.append({"id": str(i), "image": null})
	task.report = []
	for i in 6:
		task.report.append({"photo": i, "prompt": "Q_ROOF", "answer": "ok", "options": [["damaged", "x"], ["ok", "y"]]})
	task.report_open = true
	for i in 6:
		task.answer(i, "damaged" if i == 0 else "ok")
	check(task.done and task.wrong == [0], "simple: one misread roof still passes, and is listed")
	f[2].queue_free()
	await get_tree().process_frame


# --- Interception course ---------------------------------------------------------

## The test pilot flies to the lead point of the current target at its height, as a person should.
func test_intercept_task(key: String, mode: String) -> void:
	var f := _flight(key, mode, "intercept")
	var task: FlightTask = f[0]
	var sim: DroneSim = f[1]
	var world: FlightWorld = f[2]
	var fpv := sim is FpvSim
	var ap = FpvAutopilot.new() if fpv else Autopilot.new()
	if fpv:
		# Faster than every target, but slow enough to hold height in a hard turn.
		ap.speed = 18.0 if mode == "pro" else 7.0
	for i in int(200.0 / DT):
		var tg: Dictionary = task.current()
		if not tg.is_empty() and tg.has("now"):
			# Fly through the lead point, never brake for it: a point far beyond it, the same way.
			var aim: Vector3 = task.lead_point(sim, tg)
			var way := Vector3(aim.x - sim.pos.x, 0, aim.z - sim.pos.z)
			ap.target = sim.pos + way.normalized() * maxf(way.length(), 60.0) if way.length() > 0.01 else aim
			ap.height = maxf(1.0, aim.y - world.height(sim.pos.x, sim.pos.z))
		var s: Dictionary = task.controls(ap.sticks(sim))
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if task.done or task.failed or sim.crashed:
			break
	check(task.done, "%s: %s catches the target (%s)" % [mode, key, task.summary if task.failed else ("crashed" if sim.crashed else "")])
	if task.done:
		_passed(task, sim)
	world.queue_free()
	await get_tree().process_frame


## Not flying at all: a crossing target gets away, a circling one runs the clock out.
func test_target_gets_away() -> void:
	for key in ["INT_LEAD", "INT_TURN"]:
		var f := _flight(key, "simple", "intercept")
		var task: FlightTask = f[0]
		var sim: DroneSim = f[1]
		for i in int(80.0 / DT):
			sim.step(DT, -1.0, 0, 0, 0)
			task.step(DT, sim, {"throttle": -1.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0})
			if task.failed:
				break
		check(task.failed and task.summary == ("FAIL_INT_GONE" if key == "INT_LEAD" else "FAIL_INT_TIME"),
			"%s: standing still does not pass (%s)" % [key, task.summary])
		f[2].queue_free()
	await get_tree().process_frame


# --- Aid drop, lost dog, theory questions -------------------------------------

## Hover over the circle and drop; if the first kit misses, hover off by the miss the other way.
func test_meds(mode: String) -> void:
	var f := _flight("MIS_CAM_MEDS", mode, "camera")
	var task: FlightTask = f[0]
	var sim: DroneSim = f[1]
	var ap := Autopilot.new()
	var aim: Vector3 = task.spot()
	for attempt in 2:
		ap.target = aim
		ap.height = 5.0
		var still := 0.0
		var dropped := false
		for i in int(60.0 / DT):
			var s: Dictionary = ap.sticks(sim)
			sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
			task.step(DT, sim, s)
			if task.done or task.failed or sim.crashed:
				break
			var here := FlightTask.flat_distance(sim.pos, aim) < 0.3 and sim.vel.length() < 0.15
			still = still + DT if here else 0.0
			if not dropped and still > 1.0:
				task.act(sim)
				dropped = true
			if dropped and task._falling.is_empty() and task.last_landing != Vector3.INF:
				break
		if task.done or task.failed:
			break
		aim += task.spot() - task.last_landing
		aim.y = 0.0
	check(task.done, "%s: the aid kit lands in the circle (%s)" % [mode, task.summary])
	if task.done:
		_passed(task, sim)
	f[2].queue_free()
	await get_tree().process_frame


func test_meds_rules() -> void:
	var f := _flight("MIS_CAM_MEDS", "pro", "camera")
	var task: FlightTask = f[0]
	var sim: DroneSim = f[1]
	sim.pos = task.spot() + Vector3(0, 1.5, 0)
	sim.on_ground = false
	task.act(sim)
	check(task._falling.is_empty() and task.hint_base == "HINT_MEDS_LOW", "no dropping from 1.5 m: people could be hit")
	sim.pos = Vector3(0, 6, -23)
	sim.vel = Vector3.ZERO
	task.act(sim)
	for i in int(3.0 / DT):
		task.step(DT, sim, {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0})
	check(task.hint_base == "HINT_MEDS_WATER" and not task.done, "a kit that falls in the river is lost")
	f[2].queue_free()
	await get_tree().process_frame


## Find the puppy by flying low near it, then lead it home slowly.
func test_dog() -> void:
	var f := _flight("MIS_CAM_DOG", "kids", "camera")
	var task: FlightTask = f[0]
	var sim: DroneSim = f[1]
	var world: FlightWorld = f[2]
	var ap := Autopilot.new()
	ap.target = task.dog()
	ap.height = 3.0
	for i in int(120.0 / DT):
		if task._follows:
			# Home, a little at a time, so the puppy keeps up.
			var to := world.pad - sim.pos
			to.y = 0.0
			ap.target = sim.pos + to.limit_length(2.5)
		var s: Dictionary = ap.sticks(sim)
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if task.done:
			break
	check(task.done, "kids: the puppy is found and led home")
	if task.done:
		_passed(task, sim)
	world.queue_free()
	await get_tree().process_frame


## Every theory card has its questions, in both families, with three different answers and a why.
func test_quiz_texts() -> void:
	for card in Curriculum.THEORY:
		for fam in ["adult", "kids"]:
			for i in range(1, int(Curriculum.QUIZ[fam]) + 1):
				var q := "Q_%s%s_%d" % [card, "_KIDS" if fam == "kids" else "", i]
				var texts := []
				for part in ["", "_A", "_B", "_C", "_WHY"]:
					texts.append(tr(q + part))
				var ok: bool = texts.all(func(t): return not t.begins_with("Q_")) and texts[1] != texts[2] \
					and texts[1] != texts[3] and texts[2] != texts[3]
				if fam == "kids":
					ok = ok and not RegEx.create_from_string("[0-9]").search("".join(texts))
				check(ok, "%s: question, three answers and why%s" % [q, ", no numbers" if fam == "kids" else ""])


func test_ugv_task(key: String, mode: String) -> void:
	var f := _flight(key, mode, "ugv")
	var task: FlightTask = f[0]
	var sim: UgvSim = f[1]
	var world: FlightWorld = f[2]
	var ap := UgvAutopilot.new()
	var gentle := task.meter >= 0.0 or key.contains("EVAC") or key == "MIS_UGV_VET"
	ap.gentle = gentle
	ap.top = 0.35 if gentle else 0.7
	if key == "MIS_UGV_CARGO":
		ap.top = 0.22
	var road: Array[Vector3] = []
	if task.get("road") != null:
		road.assign(task.road)
	var leg := [1]
	var back := [false]
	var plan := func(_t: float) -> Dictionary:
		if key == "UGV_PIVOT":
			match task._stage:
				0:
					ap.target = Vector3(0, 0, -12.8)
				1:
					ap.target = sim.pos + Vector3(0, 0, 6)  # turn round to face out
					ap.stop = false
				2:
					ap.target = Vector3(0, 0, 0)
			return ap.sticks(sim)
		if task.cps.size() > 0:
			var t := task.course_world_target()
			if t != Vector3.INF:
				ap.target = t
			return ap.sticks(sim)
		# Routes: follow the road there, then (when it brings something back) the road home.
		var going_back: bool = task.loaded and task.pickup != Vector3.INF
		var pts := road.duplicate()
		if going_back:
			pts.reverse()
			pts.append(task.dest)
		else:
			pts.append(task.dest if task.pickup == Vector3.INF else task.pickup)
		if going_back and not back[0]:
			leg[0] = 1
			back[0] = true
		var i := mini(leg[0], pts.size() - 1)
		ap.target = pts[i]
		if FlightTask.flat_distance(sim.pos, pts[i]) < 1.0 and i < pts.size() - 1:
			leg[0] += 1
		return ap.sticks(sim)
	var ok := _fly(task, sim, 300.0, plan)
	check(ok, "%s: UGV %s passes%s" % [mode, key, "" if ok else " — %s %s meter=%.0f crashed=%s" % [task.hint_base, task.summary, task.meter, sim.crashed]])
	world.queue_free()
	await get_tree().process_frame


func test_ugv_rough_driving_fails() -> void:
	var f := _flight("UGV_EVACUATION", "simple", "ugv")
	var task: FlightTask = f[0]
	var sim: UgvSim = f[1]
	# Full stick forward and back, again and again, once the casualty is aboard.
	var ap := UgvAutopilot.new()
	ap.top = 0.4
	var plan := func(t: float) -> Dictionary:
		if not task.loaded:
			ap.target = task.road[1] if FlightTask.flat_distance(sim.pos, task.road[1]) > 1.0 and t < 4.0 else task.pickup
			if FlightTask.flat_distance(sim.pos, task.road[1]) < 1.0 or t > 4.0:
				ap.target = task.road[2] if FlightTask.flat_distance(sim.pos, task.road[2]) > 1.0 and t < 12.0 else task.pickup
			return ap.sticks(sim)
		var k := 1.0 if int(t * 2.0) % 2 == 0 else -1.0
		return {"throttle": k, "yaw": 0.0, "pitch": k, "roll": 0.0}
	_fly(task, sim, 120.0, plan)
	check(task.failed and task.summary == "FAIL_JOLT_STRETCHER", "simple: jerky driving with a casualty does not pass (%s)" % task.summary)
	f[2].queue_free()
	await get_tree().process_frame



## Deep enough in the alley for the pivot lesson's "inside" point.
const END_IN := -12.4


## Each way round a lesson that the audit found is now closed.
func test_shortcuts_closed() -> void:
	# Flying round the end of the tree belt instead of through it.
	var f := _flight("MIS_FPV_TREES", "simple", "fpv")
	var ap := FpvAutopilot.new()
	var legs := [Vector3(-17, 0, -4), Vector3(-17, 0, -38), Vector3(0, 0, -38)]
	var leg := [0]
	var plan := func(_t: float) -> Dictionary:
		ap.target = legs[mini(leg[0], legs.size() - 1)]
		ap.height = 3.0
		if FlightTask.flat_distance(f[1].pos, ap.target) < 1.0:
			leg[0] += 1
		return ap.sticks(f[1])
	_fly(f[0], f[1], 80.0, plan)
	check(f[0].failed and f[0].summary == "FAIL_TREES_AROUND", "simple: going round the tree belt does not count")
	f[2].queue_free()
	await get_tree().process_frame

	# Turning on the pad and reversing into the alley: the task must not move on, and must say why.
	var g := _flight("UGV_PIVOT", "simple", "ugv")
	var u: UgvSim = g[1]
	u.place(Vector3.ZERO, PI)  # already turned round, facing the pilot
	check(u.forward().dot(Vector3(0, 0, 1)) > 0.99, "test setup: the robot faces out of the alley")
	var phase := [1]  # 1 reverse in, 2 drive out
	var told := [false]
	var reverse := func(_t: float) -> Dictionary:
		if g[0].hint_base == "HINT_PIVOT_FORWARD":
			told[0] = true
		if phase[0] == 1 and u.pos.z < END_IN:
			phase[0] = 2
		if phase[0] == 1:
			return {"throttle": -0.4, "yaw": 0.0, "pitch": -0.4, "roll": 0.0}
		if u.pos.z > 0.0:
			return {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}  # out: stop
		return {"throttle": 0.4, "yaw": 0.0, "pitch": 0.4, "roll": 0.0}
	var passed := _fly(g[0], u, 60.0, reverse)
	check(phase[0] == 2 and not g[0].failed, "simple: the robot really reversed into the alley and out without a bump (phase %d, %s, %s)" % [phase[0], u.pos, g[0].summary])
	check(not passed and g[0]._stage == 0 and told[0], "simple: reversing into the alley does not count, and the hint says to turn first")
	g[2].queue_free()
	await get_tree().process_frame

	# Driving up the sheer side of the ramp.
	var h := _flight("UGV_TERRAIN", "simple", "ugv")
	var hu: UgvSim = h[1]
	hu.place(Vector3(-4, 0, -14.45), -PI / 2.0)  # beside the ramp, facing it
	var side := func(_t: float) -> Dictionary:
		return {"throttle": 0.8, "yaw": 0.0, "pitch": 0.8, "roll": 0.0}
	_fly(h[0], hu, 5.0, side)
	check(hu.pos.y < 0.3, "simple: the robot cannot climb the sheer side of the ramp (%.2f m)" % hu.pos.y)
	h[2].queue_free()
	await get_tree().process_frame

	# Kids: bumping a barrel on the delivery does not fail it.
	var k := _flight("UGV_DELIVERY", "kids", "ugv")
	k[1].events.append({"type": "bump", "speed": 1.0})
	k[0].step(DT, k[1], {})
	check(not k[0].failed, "kids: a bump on the delivery is not a failure")
	k[2].queue_free()
	await get_tree().process_frame


## A damaged save (full phone, cut write) falls back to the copy before; erase leaves no copy.
