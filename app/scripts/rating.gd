# SPDX-License-Identifier: GPL-3.0-or-later
# Sunflowers for a passed lesson or mission: one for passing, a second for not touching anything,
# a third for that and being quicker than the task's par time. Plain rules, no screens: the tests
# check them directly.
class_name Rating
extends RefCounted

## Par time per task, in seconds. Measured from the test autopilots in every mode (the slowest one,
## times 1.8, rounded up to 5 s): a person has room to look around, but must fly with purpose.
const PAR := {
	"CAM_STICKS": 20, "CAM_TAKEOFF": 20, "CAM_HOLD": 25, "CAM_NOSE_IN": 25, "CAM_SQUARE": 50,
	"CAM_LANDING": 80, "CAM_WIND": 40, "CAM_EXAM": 65,
	"MIS_CAM_KITTEN": 60, "MIS_CAM_SEARCH": 90, "MIS_CAM_LINK": 100, "MIS_CAM_JAM": 100,
	"FPV_THROTTLE": 25, "FPV_FORWARD": 30, "FPV_EIGHT": 70, "FPV_GATES": 60, "FPV_HORIZON": 55,
	"FPV_ACRO": 25,
	"MIS_FPV_HOOPS": 60, "MIS_FPV_BALLOONS": 70, "MIS_FPV_RACE": 70, "MIS_FPV_TREES": 90,
	"UGV_DRIVE": 50, "UGV_PIVOT": 35, "UGV_TERRAIN": 60, "UGV_DELIVERY": 45, "UGV_EVACUATION": 160,
	"MIS_UGV_VET": 185, "MIS_UGV_PARCEL": 45, "MIS_UGV_CARGO": 110, "MIS_UGV_EVAC": 160,
	"SRV_TILT": 20, "SRV_SHARP": 40, "SRV_DETAIL": 30, "SRV_ORBIT": 90, "SRV_GRID": 80,
	"SRV_KIDS_FLOWER": 20, "SRV_KIDS_KITTEN": 15, "SRV_KIDS_VAN": 25, "MIS_SRV_ALBUM": 65,
	"MIS_CAM_SURVEY": 245, "MIS_SRV_COUNT": 105,
	# The test autopilot knows where the lost person is; a pilot has to search: three minutes.
	"MIS_SRV_FIND": 180,
	# The test pilot always knows the perfect lead; a person must find the target first, so the
	# interception course gets at least 30 s a target.
	"INT_CHASE": 30, "INT_TURN": 30, "INT_LEAD": 30, "INT_HEADON": 30, "INT_NIGHT": 30,
	"INT_KIDS_BUTTERFLY": 30, "MIS_INT_KIDS": 50,
	"MIS_INT_PATROL": 90, "MIS_INT_FAST": 30, "MIS_INT_FOG": 90,
	"MIS_CAM_MEDS": 35,
	# The test pilot knows where the puppy is; a child looks for it by "warmer, colder".
	"MIS_CAM_DOG": 90,
	"WING_LEVEL": 20, "WING_TURN": 95, "WING_TAKEOFF": 40, "WING_CIRCUIT": 115, "WING_LANDING": 45,
	"WING_KIDS_STORKS": 50, "MIS_WING_CLOUDS": 45, "MIS_WING_KITE": 55, "MIS_WING_FLOOD": 40,
	# The test pilot stalls and recovers at once; a person first reads, then slows down with care.
	"WING_STALL": 30, "WING_INTO_WIND": 120, "WING_PATTERN": 150,
	# The test pilot knows where the lost person is; a pilot has to search the valley: four minutes.
	"MIS_WING_SEARCH": 240,
}
## Kids get half as much time again: the third sunflower should be reachable, not a race.
const KIDS_SLACK := 1.5
## A bump this hard or harder counts as a touch; a landing this hard or harder too.
const TOUCH_SPEED := 0.3
const HARD_LANDING := 2.0
const MAX := 3


static func par(key: String, mode: String) -> float:
	return float(PAR.get(key, 0)) * (KIDS_SLACK if mode == "kids" else 1.0)


static func sunflowers(key: String, mode: String, seconds: float, touches: int) -> int:
	if touches > 0:
		return 1
	var p := par(key, mode)
	return 3 if p > 0.0 and seconds <= p else 2


## Whether one physics event counts as touching something.
static func is_touch(event: Dictionary) -> bool:
	var speed := float(event.get("speed", 0.0))
	match event.get("type", ""):
		"bump":
			return speed >= TOUCH_SPEED
		"landed":
			return speed >= HARD_LANDING
	return false


## What would earn the next sunflower: a translation key and its arguments, or "" at three.
## Kids get a version without numbers.
static func next_tip(key: String, mode: String, got: int) -> Array:
	if got >= MAX:
		return ["", []]
	var kids := mode == "kids"
	if got == 1:
		return ["NEXT_SMOOTH_KIDS" if kids else "NEXT_SMOOTH", []]
	return ["NEXT_FAST_KIDS" if kids else "NEXT_FAST", [] if kids else [FlightTask.clock(par(key, mode))]]
