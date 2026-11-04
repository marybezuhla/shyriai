# SPDX-License-Identifier: GPL-3.0-or-later
# A lesson or mission in flight: watches the drone, tells the pilot what to do next,
# and decides when the task is passed. Texts are translation keys.
class_name FlightTask
extends RefCounted

const FILES := {
	"CAM_STICKS": "res://scripts/flight/tasks/task_sticks.gd",
	"CAM_TAKEOFF": "res://scripts/flight/tasks/task_takeoff.gd",
	"CAM_HOLD": "res://scripts/flight/tasks/task_hold.gd",
	"CAM_NOSE_IN": "res://scripts/flight/tasks/task_nose_in.gd",
	"CAM_SQUARE": "res://scripts/flight/tasks/task_square.gd",
	"CAM_LANDING": "res://scripts/flight/tasks/task_landing.gd",
	"CAM_WIND": "res://scripts/flight/tasks/task_wind.gd",
	"CAM_EXAM": "res://scripts/flight/tasks/task_exam.gd",
	"MIS_CAM_KITTEN": "res://scripts/flight/tasks/mission_kitten.gd",
	"MIS_CAM_SEARCH": "res://scripts/flight/tasks/mission_search.gd",
	"MIS_CAM_SURVEY": "res://scripts/flight/tasks/mission_survey.gd",
}
## The nose counts as pointing somewhere when it is within this angle of it.
const FACING := deg_to_rad(50.0)

var key := ""
var mode := "simple"
var vehicle := "camera"
var is_mission := false
var task_seed := 7

var progress := 0.0
var done := false
var failed := false
## What to tell the pilot now: a translation key and its % arguments.
var hint := ""
var hint_args: Array = []
## A point to fly to, shown in the world and by an arrow at the screen edge. INF = none.
var marker := Vector3.INF
## A ring on the ground around the marker, in metres. 0 = no ring.
var ring := 0.0
## A see-through sphere of this radius at the marker. 0 = none.
var beacon := 0.0
## Collected items, e.g. sunflowers. counter_max 0 = none.
var counter := 0
var counter_max := 0
## Shown on the "Passed" or "Not this time" card. A translation key and arguments.
var summary := ""
var summary_args: Array = []
## A question with buttons during the flight: {"prompt": key, "options": [[id, key], ...]}. Empty = none.
var choice := {}
## The camera this task starts with, if it matters (nose-in needs the pilot's view). "" = the saved one.
var view_hint := ""

## Physics for this task. wind < 0 keeps the mode's wind.
var gps := true
var wind := -1.0
var gust := 0.0

var world: Node  # FlightWorld

# A course of checkpoints, used by many lessons.
var cps: Array[Vector3] = []
var cp := 0
var cp_radius := 2.0
## "": anything goes; "travel": nose towards where it flies; "pilot": nose towards the pilot.
var cp_facing := ""
var cp_height_tol := 1.5

var _sticky := 0.0


static func implemented(task_key: String) -> bool:
	return FILES.has(task_key)


static func make(task_key: String, mode_: String, seed_ := 7) -> FlightTask:
	var t: FlightTask = load(FILES[task_key]).new()
	t.key = task_key
	t.mode = mode_
	t.task_seed = seed_
	t.is_mission = task_key.begins_with("MIS_")
	t.configure()
	return t


## Override: physics settings (gps, wind) before the flight starts.
func configure() -> void:
	pass


## Override: add what this task needs to the world (checkpoints, a kitten, damage).
func setup_world() -> void:
	pass


## Override: where the drone starts.
func start_position() -> Vector3:
	return world.pad


## Override: which way the drone points at the start. 0 = away from the pilot, PI = towards.
func start_heading() -> float:
	return 0.0


## Override: called every physics step.
func update(_dt: float, _sim: DroneSim, _sticks: Dictionary) -> void:
	pass


## Override: the pilot tapped an option of `choice`.
func choose(_id: String) -> void:
	pass


## Called by the flight every physics step.
func step(dt: float, sim: DroneSim, sticks: Dictionary) -> void:
	_sticky = maxf(0.0, _sticky - dt)
	update(dt, sim, sticks)


func say(hint_key: String, args: Array = []) -> void:
	if _sticky > 0.0:
		return
	hint = hint_key
	hint_args = args


## A hint that stays for a few seconds, e.g. why a landing did not count.
func say_for(hint_key: String, args: Array = [], seconds := 3.0) -> void:
	hint = hint_key
	hint_args = args
	_sticky = seconds


func pass_with(summary_key: String, args: Array = []) -> void:
	done = true
	progress = 1.0
	summary = summary_key
	summary_args = args


func fail_with(summary_key: String, args: Array = []) -> void:
	failed = true
	summary = summary_key
	summary_args = args


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Courses ------------------------------------------------------------------

func course(points: Array[Vector3], radius: float, facing: String) -> void:
	cps = points
	cp = 0
	cp_radius = radius
	cp_facing = facing


func course_target() -> Vector3:
	return cps[cp] if cp < cps.size() else Vector3.INF


## The ground-relative checkpoint height becomes a world position (hills are not flat).
func course_world_target() -> Vector3:
	var t := course_target()
	if t == Vector3.INF:
		return t
	return Vector3(t.x, world.height(t.x, t.z) + t.y, t.z)


## Where the nose should point now, as a flat direction. ZERO = no rule.
func wanted_nose(sim: DroneSim) -> Vector3:
	var d := Vector3.ZERO
	match cp_facing:
		"pilot":
			d = world.pilot - sim.pos
		"travel":
			var v := Vector3(sim.vel.x, 0, sim.vel.z)
			if v.length() > 0.8:
				d = v
			else:
				d = course_world_target() - sim.pos
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO


func nose_ok(sim: DroneSim) -> bool:
	var want := wanted_nose(sim)
	if want == Vector3.ZERO:
		return true
	return sim.forward().angle_to(want) <= FACING


## One step of the course. Returns "" (flying), "reached", "facing" (at the point, nose wrong) or "done".
func course_step(sim: DroneSim) -> String:
	if cp >= cps.size():
		return "done"
	var t := course_world_target()
	marker = t
	beacon = cp_radius
	ring = 0.0
	var close := flat_distance(sim.pos, t) <= cp_radius and absf(sim.pos.y - t.y) <= cp_height_tol
	if not close:
		return ""
	if not nose_ok(sim):
		return "facing"
	cp += 1
	if cp >= cps.size():
		marker = Vector3.INF
		beacon = 0.0
		return "done"
	return "reached"
