# SPDX-License-Identifier: GPL-3.0-or-later
# Shared parts of the simulation tests: checks and flying helpers. The tests are split by topic
# into a chain of scripts (base, physics, lessons, courses, sim_test); sim_test.gd runs them all.
extends Node

const Autopilot := preload("res://tests/autopilot.gd")
const FpvAutopilot := preload("res://tests/fpv_autopilot.gd")
const UgvAutopilot := preload("res://tests/ugv_autopilot.gd")
const DT := 1.0 / 60.0

var failures := 0


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func run(sim: DroneSim, seconds: float, t: float, y: float, p: float, r: float) -> void:
	for i in int(seconds / DT):
		sim.step(DT, t, y, p, r)


## Which layout missions get (tests run several), and which tasks were flown in which mode.
var _seed := 7
var _flown := {}


func _flight(key: String, mode: String, vehicle := "camera") -> Array:
	var task := FlightTask.make(key, mode, _seed)
	var world := FlightWorld.new()
	add_child(world)
	world.build("day", 7)
	task.world = world
	task.setup_world()
	return [task, task.make_sim(vehicle), world]


func _passed(task: FlightTask, sim: DroneSim) -> void:
	_flown[task.key + "/" + task.mode] = true
	# The third sunflower must be in reach: the autopilot is well inside the par time.
	check(sim.time <= Rating.par(task.key, task.mode),
		"%s %s autopilot %.0f s within par %.0f s" % [task.mode, task.key, sim.time, Rating.par(task.key, task.mode)])


func _fly(task: FlightTask, sim: DroneSim, seconds: float, pick: Callable) -> bool:
	for i in int(seconds / DT):
		var s: Dictionary = task.controls(pick.call(i * DT))
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if task.done:
			_passed(task, sim)
			return true
		if sim.crashed or task.failed:
			return false
	return false


