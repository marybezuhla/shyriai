# SPDX-License-Identifier: GPL-3.0-or-later
# A lesson or mission in flight: watches the drone, tells the pilot what to do next,
# and decides when the task is passed. Texts are translation keys.
class_name FlightTask
extends RefCounted

const FILES := {
	"CAM_STICKS": "res://scripts/flight/tasks/task_sticks.gd",
	"CAM_TAKEOFF": "res://scripts/flight/tasks/task_takeoff.gd",
	"CAM_HOLD": "res://scripts/flight/tasks/task_hold.gd",
	"MIS_CAM_KITTEN": "res://scripts/flight/tasks/mission_kitten.gd",
}

var key := ""
var mode := "simple"
var vehicle := "camera"
var is_mission := false

var progress := 0.0
var done := false
## What to tell the pilot now: a translation key and its % arguments.
var hint := ""
var hint_args: Array = []
## A point to fly to, shown in the world and by an arrow at the screen edge. INF = none.
var marker := Vector3.INF
## A ring on the ground around the marker, in metres. 0 = no ring.
var ring := 0.0
## Collected items, e.g. sunflowers. counter_max 0 = none.
var counter := 0
var counter_max := 0
## Shown on the "Passed" card, e.g. "Landing at 0.3 m/s". A translation key and arguments.
var summary := ""
var summary_args: Array = []

## Physics for this task. wind < 0 keeps the mode's wind.
var gps := true
var wind := -1.0
var gust := 0.0

var world: Node  # FlightWorld


static func implemented(task_key: String) -> bool:
	return FILES.has(task_key)


static func make(task_key: String, mode_: String) -> FlightTask:
	var t: FlightTask = load(FILES[task_key]).new()
	t.key = task_key
	t.mode = mode_
	t.is_mission = task_key.begins_with("MIS_")
	t.configure()
	return t


## Override: physics settings (gps, wind) before the flight starts.
func configure() -> void:
	pass


## Override: called once the world exists. Return where the drone starts.
func start_position() -> Vector3:
	return world.pad


## Override: called every physics step.
func update(_dt: float, _sim: DroneSim, _sticks: Dictionary) -> void:
	pass


func say(hint_key: String, args: Array = []) -> void:
	hint = hint_key
	hint_args = args


func pass_with(summary_key: String, args: Array = []) -> void:
	done = true
	progress = 1.0
	summary = summary_key
	summary_args = args


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
