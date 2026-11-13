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
	"FPV_THROTTLE": "res://scripts/flight/tasks/fpv_throttle.gd",
	"FPV_FORWARD": "res://scripts/flight/tasks/fpv_forward.gd",
	"FPV_EIGHT": "res://scripts/flight/tasks/fpv_eight.gd",
	"FPV_GATES": "res://scripts/flight/tasks/fpv_gates.gd",
	"FPV_HORIZON": "res://scripts/flight/tasks/fpv_gates.gd",
	"FPV_ACRO": "res://scripts/flight/tasks/fpv_acro.gd",
	"MIS_FPV_HOOPS": "res://scripts/flight/tasks/mission_hoops.gd",
	"MIS_FPV_BALLOONS": "res://scripts/flight/tasks/mission_balloons.gd",
	"MIS_FPV_RACE": "res://scripts/flight/tasks/fpv_gates.gd",
	"MIS_FPV_TREES": "res://scripts/flight/tasks/mission_trees.gd",
	"UGV_DRIVE": "res://scripts/flight/tasks/ugv_drive.gd",
	"UGV_PIVOT": "res://scripts/flight/tasks/ugv_pivot.gd",
	"UGV_TERRAIN": "res://scripts/flight/tasks/ugv_terrain.gd",
	"UGV_DELIVERY": "res://scripts/flight/tasks/ugv_route.gd",
	"UGV_EVACUATION": "res://scripts/flight/tasks/ugv_route.gd",
	"MIS_UGV_VET": "res://scripts/flight/tasks/ugv_route.gd",
	"MIS_UGV_PARCEL": "res://scripts/flight/tasks/ugv_route.gd",
	"MIS_UGV_CARGO": "res://scripts/flight/tasks/ugv_route.gd",
	"MIS_UGV_EVAC": "res://scripts/flight/tasks/ugv_route.gd",
	"FREE_CAMERA": "res://scripts/flight/tasks/free_flight.gd",
	"FREE_FPV": "res://scripts/flight/tasks/free_flight.gd",
	"FREE_UGV": "res://scripts/flight/tasks/free_flight.gd",
	"FREE_SURVEY": "res://scripts/flight/tasks/free_flight.gd",
	"SRV_TILT": "res://scripts/flight/tasks/photo_list.gd",
	"SRV_SHARP": "res://scripts/flight/tasks/photo_list.gd",
	"SRV_DETAIL": "res://scripts/flight/tasks/srv_detail.gd",
	"SRV_ORBIT": "res://scripts/flight/tasks/srv_orbit.gd",
	"SRV_GRID": "res://scripts/flight/tasks/srv_grid.gd",
	"SRV_KIDS_FLOWER": "res://scripts/flight/tasks/photo_list.gd",
	"SRV_KIDS_KITTEN": "res://scripts/flight/tasks/photo_list.gd",
	"SRV_KIDS_VAN": "res://scripts/flight/tasks/photo_list.gd",
	"MIS_SRV_ALBUM": "res://scripts/flight/tasks/photo_list.gd",
	"MIS_SRV_FIND": "res://scripts/flight/tasks/mission_find.gd",
	"MIS_SRV_COUNT": "res://scripts/flight/tasks/mission_count.gd",
	"INT_CHASE": "res://scripts/flight/tasks/intercept.gd",
	"INT_TURN": "res://scripts/flight/tasks/intercept.gd",
	"INT_LEAD": "res://scripts/flight/tasks/intercept.gd",
	"INT_HEADON": "res://scripts/flight/tasks/intercept.gd",
	"INT_NIGHT": "res://scripts/flight/tasks/intercept.gd",
	"INT_KIDS_BUTTERFLY": "res://scripts/flight/tasks/intercept.gd",
	"MIS_INT_PATROL": "res://scripts/flight/tasks/intercept.gd",
	"MIS_INT_FAST": "res://scripts/flight/tasks/intercept.gd",
	"MIS_INT_FOG": "res://scripts/flight/tasks/intercept.gd",
	"MIS_INT_KIDS": "res://scripts/flight/tasks/intercept.gd",
	"FREE_INTERCEPT": "res://scripts/flight/tasks/free_flight.gd",
	"MIS_CAM_MEDS": "res://scripts/flight/tasks/mission_meds.gd",
	"MIS_CAM_DOG": "res://scripts/flight/tasks/mission_dog.gd",
	"WING_LEVEL": "res://scripts/flight/tasks/wing_rings.gd",
	"WING_TURN": "res://scripts/flight/tasks/wing_turn.gd",
	"WING_TAKEOFF": "res://scripts/flight/tasks/wing_takeoff.gd",
	"WING_CIRCUIT": "res://scripts/flight/tasks/wing_rings.gd",
	"WING_STALL": "res://scripts/flight/tasks/wing_stall.gd",
	"WING_LANDING": "res://scripts/flight/tasks/wing_landing.gd",
	"WING_INTO_WIND": "res://scripts/flight/tasks/wing_pattern.gd",
	"WING_PATTERN": "res://scripts/flight/tasks/wing_pattern.gd",
	"WING_KIDS_STORKS": "res://scripts/flight/tasks/wing_rings.gd",
	"MIS_WING_CLOUDS": "res://scripts/flight/tasks/wing_rings.gd",
	"MIS_WING_KITE": "res://scripts/flight/tasks/wing_find.gd",
	"MIS_WING_SEARCH": "res://scripts/flight/tasks/wing_find.gd",
	"MIS_WING_FLOOD": "res://scripts/flight/tasks/wing_flood.gd",
	"FREE_WING": "res://scripts/flight/tasks/free_flight.gd",
}
## The racing gates of the FPV lessons and the race, in order, centre 2.2 m up.
const GATE_COURSE: Array[Vector3] = [
	Vector3(0, 2.2, -10), Vector3(-9, 2.2, -20), Vector3(-4, 2.2, -32),
	Vector3(8, 2.2, -34), Vector3(13, 2.2, -22), Vector3(6, 2.2, -12),
]
## The nose counts as pointing somewhere when it is within this angle of it.
const FACING := deg_to_rad(50.0)

## The underlying key of the hint, e.g. for tests; hint may be its Kids wording.
var hint_base := ""
var key := ""
var mode := "simple"
var vehicle := "camera"
var is_mission := false
## Free flight: no pass, no progress bar, no sunflowers.
var is_free := false
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
## Collected items, e.g. sunflowers or hoops, shown when counter_shown is set.
var counter := 0
var counter_max := 0
var counter_shown := false
## Shown on the "Passed" or "Not this time" card. A translation key and arguments.
var summary := ""
var summary_args: Array = []
## Which way the on-screen sticks should be pushed now, shown as a ghost knob: {"left": Vector2.UP}.
var stick_hint := {}
## A task's own button beside the right stick (a translation key), e.g. "Drop"; "" = none.
var action := ""
## A look the world must have for this task ("dusk", "fog", ...); "" = the usual one.
var look := ""
## For chasing a target: show its distance and how fast the gap closes.
var target_info := false
var target_dist := 0.0
var closing := 0.0
## The camera this task starts with, if it matters (nose-in needs the pilot's view). "" = the saved one.
var view_hint := ""

## Ground robot: what it carries ("", "cargo", "stretcher", "kitten", "parcel"), a meter such as the
## casualty's comfort (0-100; below 0 = none) with its label, whether the radio link is up, and how
## late the robot's video arrives, in seconds.
var load_kind := ""
var meter := -1.0
var meter_label := ""
var link_ok := true
var video_delay := 0.0

## FPV only: "angle", "horizon" or "acro".
var flight_mode := "angle"

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

# Gates or hoops to fly through, in order: {"c": centre, "n": way through, "side": across, "w", "h"} or
# {"c", "n", "r"} for a round hoop.
var rings: Array[Dictionary] = []
var ring_i := 0
var _prev := Vector3.INF


static func implemented(task_key: String) -> bool:
	return FILES.has(task_key)


static func make(task_key: String, mode_: String, seed_ := 7) -> FlightTask:
	var t: FlightTask = load(FILES[task_key]).new()
	t.key = task_key
	t.mode = mode_
	t.task_seed = seed_
	t.is_mission = task_key.begins_with("MIS_")
	t.is_free = task_key.begins_with("FREE_")
	t.configure()
	return t


## The physics for a vehicle in a mode, set up for this task and world. The flight screen and the
## tests both build it here, so the tests always fly what the app flies.
func make_sim(vehicle_: String) -> DroneSim:
	vehicle_ = Curriculum.machine(vehicle_)
	var sim: DroneSim
	if vehicle_ == "ugv":
		var u := UgvSim.new(mode, 11)
		u.grip = world.grip
		sim = u
	elif vehicle_ == "wing":
		sim = WingSim.new(mode, 11)
	elif vehicle_ == "fpv" and mode != "kids":
		var f := FpvSim.new(mode, 11)
		f.flight_mode = flight_mode
		sim = f
	else:
		# Kids fly the FPV drone with the camera drone's help: it holds its height for them.
		sim = DroneSim.new(mode, 11)
		if vehicle_ == "fpv":
			sim.p["vmax"] = 4.0
	sim.gps = gps
	if wind >= 0.0:
		sim.set_wind(wind, gust)
	sim.ground = world.height
	sim.obstacles = world.obstacles
	sim.place(start_position(), start_heading())
	tune(sim)
	return sim


## Override: adjust the physics once it is placed (e.g. the stall lesson turns off stall protection).
func tune(_sim: DroneSim) -> void:
	pass


## What the vehicle gets from the sticks: nothing while the radio link is down.
func controls(sticks: Dictionary) -> Dictionary:
	if link_ok:
		return sticks
	return {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}


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


## Override: the pilot pressed the task's own button.
func act(_sim: DroneSim) -> void:
	pass


## Called by the flight every physics step.
func step(dt: float, sim: DroneSim, sticks: Dictionary) -> void:
	_sticky = maxf(0.0, _sticky - dt)
	update(dt, sim, sticks)


func say(hint_key: String, args: Array = []) -> void:
	if _sticky > 0.0:
		return
	_set_hint(hint_key, args)


## A hint that stays for a few seconds, e.g. why a landing did not count.
func say_for(hint_key: String, args: Array = [], seconds := 3.0) -> void:
	_set_hint(hint_key, args)
	_sticky = seconds


func pass_with(summary_key: String, args: Array = []) -> void:
	done = true
	progress = 1.0
	var w := _wording(summary_key, args)
	summary = w[0]
	summary_args = w[1]


func fail_with(summary_key: String, args: Array = []) -> void:
	failed = true
	var w := _wording(summary_key, args)
	summary = w[0]
	summary_args = w[1]


func _set_hint(hint_key: String, args: Array) -> void:
	hint_base = hint_key
	var w := _wording(hint_key, args)
	hint = w[0]
	hint_args = w[1]


## Kids get their own wording (KEY_KIDS) when there is one; it has no numbers, so no arguments.
func _wording(key_: String, args: Array) -> Array:
	var k := Curriculum.text_key(key_, mode)
	if k != key_ and not String(TranslationServer.translate(k)).contains("%"):
		return [k, []]
	return [k, args]


## A number with one decimal, written the way the reader's language writes it (2,5 in Ukrainian).
static func num(x: float, decimals := 1) -> String:
	var t := ("%." + str(decimals) + "f") % x
	return t.replace(".", ",") if TranslationServer.get_locale().begins_with("uk") else t


## Minutes and seconds, e.g. 2:05.
static func clock(seconds: float) -> String:
	var t := int(ceil(seconds))
	return "%d:%02d" % [floori(t / 60.0), t % 60]


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


# --- Gates and hoops ------------------------------------------------------------

## Each gate faces from the gate before it towards the next one.
static func normals_along(points: Array[Vector3], start: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in points.size():
		var before: Vector3 = start if i == 0 else points[i - 1]
		var after: Vector3 = points[i + 1] if i + 1 < points.size() else points[i] + (points[i] - before)
		var d := after - before
		d.y = 0.0
		out.append(d.normalized())
	return out


## One step through the gates. Returns "", "passed" or "done".
func ring_step(sim: DroneSim) -> String:
	if ring_i >= rings.size():
		return "done"
	var g: Dictionary = rings[ring_i]
	marker = g["c"]
	beacon = 0.0
	ring = 0.0
	var res := ""
	if _prev != Vector3.INF:
		var c: Vector3 = g["c"]
		var n: Vector3 = g["n"]
		var d0 := (_prev - c).dot(n)
		var d1 := (sim.pos - c).dot(n)
		# Kids' rings count from either side: a child who flies through backwards still went through.
		var crossed := (d0 < 0.0 and d1 >= 0.0) or (bool(g.get("both", false)) and d0 > 0.0 and d1 <= 0.0)
		if crossed:
			var hit := _prev.lerp(sim.pos, d0 / (d0 - d1))
			var off: Vector3 = hit - c
			var inside := false
			if g.has("r"):
				inside = (off - n * off.dot(n)).length() < float(g["r"])
			else:
				inside = absf(off.dot(g["side"])) < float(g["w"]) / 2.0 and absf(off.y) < float(g["h"]) / 2.0
			if inside:
				ring_i += 1
				res = "passed"
	_prev = sim.pos
	if ring_i >= rings.size():
		marker = Vector3.INF
		return "done"
	return res


## Back to a ring (the first by default): the rings from there count again.
func restart_rings(from := 0) -> void:
	ring_i = from
	_prev = Vector3.INF
