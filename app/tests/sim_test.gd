# SPDX-License-Identifier: GPL-3.0-or-later
# Tests of the drone physics and of every lesson: each lesson must be passable with the sticks alone,
# in every mode. CI fails if anything here fails. Not shipped in the APK.
extends "res://tests/sim_wing.gd"


func _ready() -> void:
	# A script error stops a test without quitting; never wait for the CI job's own time limit.
	get_tree().create_timer(540.0).timeout.connect(func(): printerr("SIM TIMEOUT"); get_tree().quit(1))
	test_hover_holds_with_gps()
	test_atti_drifts_with_wind()
	test_landing_assist()
	test_kids_never_crash()
	test_adult_crashes_into_a_house()
	test_battery_lands_by_itself()
	test_fpv_physics()
	for mode in Prefs.MODES:
		await test_sticks_lesson(mode)
		await test_takeoff_lesson(mode)
		await test_hold_lesson(mode)
	for mode in Prefs.MODES:
		await test_course_lesson("CAM_NOSE_IN", mode)
		await test_course_lesson("CAM_SQUARE", mode)
		await test_landing_lesson(mode)
		await test_course_lesson("CAM_WIND", mode)
		await test_exam(mode)
	await test_exam_fails_on_a_bump()
	await test_nose_rule("CAM_NOSE_IN")
	await test_nose_rule("CAM_SQUARE")
	await test_kitten_mission()
	for mode in Prefs.MODES:
		for key in Curriculum.lessons("fpv", mode):
			await test_fpv_task(key, mode)
	await test_fpv_task("MIS_FPV_HOOPS", "kids")
	await test_fpv_task("MIS_FPV_BALLOONS", "kids")
	for mode in ["simple", "pro"]:
		await test_fpv_task("MIS_FPV_RACE", mode)
		await test_fpv_task("MIS_FPV_TREES", mode)
	await test_trees_over_fails()
	test_ugv_physics()
	for mode in Prefs.MODES:
		for key in Curriculum.lessons("ugv", mode) + Curriculum.missions("ugv", mode):
			await test_ugv_task(key, mode)
	await test_ugv_rough_driving_fails()
	for mode in ["simple", "pro"]:
		await test_search_mission(mode)
	await test_shortcuts_closed()
	test_photo_rules()
	for mode in Prefs.MODES:
		for key in Curriculum.lessons("survey", mode) + Curriculum.missions("survey", mode):
			await test_survey_task(key, mode)
	await test_survey_mistakes()
	for mode in Prefs.MODES:
		for key in Curriculum.lessons("intercept", mode) + Curriculum.missions("intercept", mode):
			await test_intercept_task(key, mode)
	await test_target_gets_away()
	for mode in ["simple", "pro"]:
		await test_meds(mode)
	await test_meds_rules()
	await test_dog()
	test_wing_physics()
	for mode in Prefs.MODES:
		for key in Curriculum.lessons("wing", mode) + Curriculum.missions("wing", mode):
			await test_wing_task(key, mode)
	await test_wing_landing_rules()
	test_quiz_texts()
	test_rating_rules()
	test_results_are_kept()
	test_saved_results_are_checked()
	test_damaged_save_falls_back()
	await test_free_flight()
	# Missions change with every attempt: fly them with other layouts too.
	for seed_ in [1234, 9001]:
		_seed = seed_
		await test_kitten_mission()
		for mode in ["simple", "pro"]:
			await test_search_mission(mode)
			for key in ["MIS_CAM_SURVEY", "MIS_SRV_FIND", "MIS_SRV_COUNT"]:
				await test_survey_task(key, mode)
				await test_fpv_task("MIS_FPV_TREES", mode)
		for mode in ["simple", "pro"]:
			for key in ["MIS_INT_PATROL", "MIS_INT_FAST"]:
				await test_intercept_task(key, mode)
		for key in ["MIS_UGV_CARGO", "MIS_UGV_EVAC"]:
			await test_ugv_task(key, "simple")
		for key in ["MIS_WING_SEARCH", "MIS_WING_FLOOD"]:
			await test_wing_task(key, "simple")
		await test_wing_task("MIS_WING_KITE", "kids")
	_seed = 7
	# Every lesson and mission the app offers was flown in every mode that offers it.
	for v in Curriculum.VEHICLES:
		for m in Prefs.MODES:
			for k in Curriculum.lessons(v, m) + Curriculum.missions(v, m):
				check(_flown.has(k + "/" + m), "%s %s was flown to a pass in the tests" % [m, k])
	if failures == 0:
		print("SIM OK")
		get_tree().quit(0)
	else:
		print("SIM FAILED: %d" % failures)
		get_tree().quit(1)


# --- Sunflowers, results, licences, free flight ------------------------------

func test_rating_rules() -> void:
	for k in FlightTask.FILES.keys():
		if not k.begins_with("FREE_"):
			check(Rating.PAR.has(k), "%s has a par time" % k)
	check(Rating.sunflowers("CAM_TAKEOFF", "simple", 10.0, 0) == 3, "quick and clean: three sunflowers")
	check(Rating.sunflowers("CAM_TAKEOFF", "simple", 25.0, 0) == 2, "clean but slow: two")
	check(Rating.sunflowers("CAM_TAKEOFF", "simple", 5.0, 1) == 1, "a touch: one, however quick")
	check(Rating.sunflowers("CAM_TAKEOFF", "kids", 25.0, 0) == 3, "kids get more time")
	check(Rating.is_touch({"type": "bump", "speed": 0.5}), "a bump is a touch")
	check(not Rating.is_touch({"type": "landed", "speed": 0.8}), "a soft landing is not")
	check(Rating.is_touch({"type": "landed", "speed": 2.5}), "a hard landing is")
	var tip := Rating.next_tip("CAM_TAKEOFF", "kids", 2)
	check(tip[1].is_empty() and not tr(tip[0]).contains("0"), "kids' tip has no numbers")
	check(Rating.next_tip("CAM_TAKEOFF", "pro", 3)[0] == "", "no tip at three")


func test_results_are_kept() -> void:
	Prefs.set_mode("simple")
	Prefs.record("CAM_HOLD", 2, 30.0)
	var before := Prefs.record("CAM_HOLD", 1, 20.0)
	var now := Prefs.best_of("CAM_HOLD")
	check(int(before["f"]) == 2 and int(now["f"]) == 2 and is_equal_approx(float(now["t"]), 20.0),
		"best sunflowers and best time are kept apart")
	Prefs.reset_progress()
	check(Prefs.best_of("CAM_HOLD").is_empty(), "starting over clears the results")
	Prefs.undo_reset()
	check(int(Prefs.best_of("CAM_HOLD").get("f", 0)) == 2, "undo brings them back")
	for i in Curriculum.lessons("ugv", "simple").size():
		Prefs.mark_passed("ugv", i)
	check(Prefs.licence_date("ugv") == Time.get_date_string_from_system(), "all lessons passed: a licence, dated today")
	check(Prefs.licence_date("fpv") == "", "no licence before the last lesson")
	Prefs.set_pilot_name("  Оля\nПетренко " + "я".repeat(60))
	check(not Prefs.pilot_name.contains("\n") and Prefs.pilot_name.length() <= Prefs.NAME_MAX, "the name is one short line")
	Prefs.erase_all()
	check(Prefs.pilot_name == "" and Prefs.best.is_empty() and Prefs.licences.is_empty(), "erase all clears name, results, licences")
	Prefs.undo_reset()
	check(Prefs.pilot_name != "", "undo after erase brings the name back")
	Prefs.erase_all()


## A broken or hand-edited file must not break the app or slip in odd values.
func test_saved_results_are_checked() -> void:
	Prefs._apply({
		"best": {"pro": {"CAM_TAKEOFF": {"f": 99, "t": 1.0e12}, "NOPE": {"f": 3, "t": 1.0},
			"CAM_HOLD": {"f": "three", "t": 5.0}}, "nobody": {}},
		"licences": {"pro": {"camera": "yesterday", "fpv": "2026-11-06", "plane": "2026-11-06"}},
		"pilot_name": 42, "free": {"wind": "hurricane", "balls": "yes", "time": "dusk"},
	})
	var r: Dictionary = Prefs.best.get("pro", {})
	check(r.size() == 1 and int(r["CAM_TAKEOFF"]["f"]) == 3 and float(r["CAM_TAKEOFF"]["t"]) <= Prefs.MAX_SECONDS,
		"saved results are clamped, unknown tasks dropped")
	check(Prefs.licences["pro"].keys() == ["fpv"], "only real dates for real vehicles")
	check(Prefs.pilot_name == "" and Prefs.free["wind"] == "none" and Prefs.free["balls"] == true
		and Prefs.free["time"] == "dusk", "odd values are ignored, good ones kept")
	Prefs.erase_all()


func test_free_flight() -> void:
	for v in Curriculum.VEHICLES:
		for m in Prefs.MODES:
			var key: String = "FREE_" + v.to_upper()
			var f := _flight(key, m, v)
			var task: FlightTask = f[0]
			var sim: DroneSim = f[1]
			var world: FlightWorld = f[2]
			check(task.is_free and task.counter_shown, "%s %s: free flight with balls" % [m, key])
			# Fly through every ball by placing the vehicle on it: each one counts once, and the
			# flight never ends by itself.
			var balls: Array = task._balls
			for b in balls:
				sim.pos = b
				task.step(DT, sim, {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0})
			check(task.counter == balls.size() and balls.size() == 10 and not task.done,
				"%s %s: all ten balls collected, still flying" % [m, key])
			world.queue_free()
			await get_tree().process_frame
	Prefs.set_free("wind", "gusty")
	check(_flight("FREE_CAMERA", "pro")[0].wind > 3.0, "the chosen wind blows")
	check(_flight("FREE_CAMERA", "kids")[0].wind == 0.0, "kids fly without wind")
	Prefs.erase_all()


func test_damaged_save_falls_back() -> void:
	Prefs.erase_all()
	Prefs.set_mode("simple")
	Prefs.record("CAM_HOLD", 2, 30.0)
	Prefs.set_pilot_name("Оля")  # one more save: the copy now holds CAM_HOLD too
	var f := FileAccess.open(Prefs.path(), FileAccess.WRITE)
	f.store_string('{"mode":"simple","pass')
	f.close()
	Prefs.best = {}
	Prefs._load()
	check(int(Prefs.best_of("CAM_HOLD").get("f", 0)) == 2, "a damaged file falls back to the copy before")
	Prefs.erase_all()
	check(not FileAccess.file_exists(Prefs.path() + ".bak"), "erase all leaves no copy behind")
	check(not Prefs._is_date("1234-56-78") and Prefs._is_date("2026-11-06"), "impossible dates are refused")
	Prefs.set_pilot_name("Оля\u202eПетренко\u200b")
	check(Prefs.pilot_name == "ОляПетренко", "invisible characters are dropped from the name")
	Prefs.erase_all()
