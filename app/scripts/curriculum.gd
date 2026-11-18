# SPDX-License-Identifier: GPL-3.0-or-later
# What is taught, in what order. Titles and goals are translation keys (i18n/strings.csv).
class_name Curriculum
extends RefCounted

## A course of its own may be flown with one of the machines: "survey" (aerial photography and
## reconnaissance) with the camera drone, "intercept" (catching a training target) with the FPV drone.
const VEHICLES := ["camera", "fpv", "ugv", "survey", "intercept", "wing"]
## The picture for each course, on the home screen and the licences.
const ICONS := {"camera": "camera", "fpv": "fpv", "ugv": "ugv", "survey": "photo", "intercept": "intercept", "wing": "wing"}
const MACHINE := {"survey": "camera", "intercept": "fpv"}
## A course that goes better after another one: shown as a hint on the course card, never a lock.
const AFTER := {"fpv": "camera", "survey": "camera", "intercept": "fpv", "wing": "camera"}

const LESSONS := {
	"camera": [
		"CAM_STICKS", "CAM_TAKEOFF", "CAM_HOLD", "CAM_NOSE_IN",
		"CAM_SQUARE", "CAM_LANDING", "CAM_WIND", "CAM_EXAM",
	],
	"fpv": [
		"FPV_THROTTLE", "FPV_FORWARD", "FPV_EIGHT",
		"FPV_GATES", "FPV_HORIZON", "FPV_ACRO",
	],
	"ugv": [
		"UGV_DRIVE", "UGV_PIVOT", "UGV_TERRAIN",
		"UGV_DELIVERY", "UGV_EVACUATION",
	],
	"survey": [
		"SRV_TILT", "SRV_SHARP", "SRV_DETAIL", "SRV_ORBIT", "SRV_GRID",
		"SRV_KIDS_FLOWER", "SRV_KIDS_KITTEN", "SRV_KIDS_VAN",
	],
	"intercept": [
		"INT_CHASE", "INT_TURN", "INT_LEAD", "INT_HEADON", "INT_NIGHT",
		"INT_KIDS_BUTTERFLY",
	],
	"wing": [
		"WING_LEVEL", "WING_TURN", "WING_TAKEOFF", "WING_INTO_WIND", "WING_CIRCUIT", "WING_STALL",
		"WING_LANDING", "WING_PATTERN",
		"WING_KIDS_STORKS",
	],
}

## Missions per vehicle and mode family: kids get their own stories.
const MISSIONS := {
	"camera": {"kids": ["MIS_CAM_KITTEN", "MIS_CAM_DOG"], "adult": ["MIS_CAM_SEARCH", "MIS_CAM_MEDS", "MIS_CAM_LINK", "MIS_CAM_JAM"]},
	"fpv": {"kids": ["MIS_FPV_HOOPS", "MIS_FPV_BALLOONS"], "adult": ["MIS_FPV_RACE", "MIS_FPV_TREES"]},
	"ugv": {"kids": ["MIS_UGV_VET", "MIS_UGV_PARCEL"], "adult": ["MIS_UGV_CARGO", "MIS_UGV_EVAC"]},
	"survey": {"kids": ["MIS_SRV_ALBUM"], "adult": ["MIS_CAM_SURVEY", "MIS_SRV_FIND", "MIS_SRV_COUNT"]},
	"intercept": {"kids": ["MIS_INT_KIDS"], "adult": ["MIS_INT_PATROL", "MIS_INT_FAST", "MIS_INT_FOG"]},
	"wing": {"kids": ["MIS_WING_KITE", "MIS_WING_CLOUDS"], "adult": ["MIS_WING_FLOOD", "MIS_WING_SEARCH"]},
}

const THEORY := ["TH_CHECKLIST", "TH_BATTERY", "TH_SIGNAL", "TH_WING", "TH_RULES"]
## "Check yourself" under each theory card: how many questions it has. A question is Q_<card>_<n>
## (or Q_<card>_KIDS_<n>); its right answer is _A, the others _B and _C, and _WHY says why.
const QUIZ := {"adult": 3, "kids": 2}

## Flying without self-levelling is for Adult mode only.
const PRO_ONLY := ["FPV_HORIZON", "FPV_ACRO"]
## The kids' own photography lessons; the grown-ups' survey lessons are not for kids.
const KIDS_ONLY := ["SRV_KIDS_FLOWER", "SRV_KIDS_KITTEN", "SRV_KIDS_VAN", "INT_KIDS_BUTTERFLY", "WING_KIDS_STORKS"]
## Kids start a course with these: the storks show a child where to fly before the plain rings.
const KIDS_FIRST := ["WING_KIDS_STORKS"]
const NOT_KIDS := [
	"SRV_TILT", "SRV_SHARP", "SRV_DETAIL", "SRV_ORBIT", "SRV_GRID",
	"INT_CHASE", "INT_TURN", "INT_LEAD", "INT_HEADON", "INT_NIGHT",
	# Kids' planes take off and land by themselves, and cannot stall.
	"WING_TAKEOFF", "WING_INTO_WIND", "WING_STALL", "WING_LANDING", "WING_PATTERN",
]


## The lessons of a vehicle in a mode. Without a mode: every lesson there is.
static func lessons(vehicle: String, mode := "") -> Array:
	var all: Array = LESSONS.get(vehicle, [])
	if mode == "":
		return all
	if mode == "kids":
		var kids := all.filter(func(k): return k not in PRO_ONLY and k not in NOT_KIDS)
		var first := kids.filter(func(k): return k in KIDS_FIRST)
		return first + kids.filter(func(k): return k not in KIDS_FIRST)
	return all.filter(func(k): return k not in KIDS_ONLY and (mode == "pro" or k not in PRO_ONLY))


## The machine a course or vehicle is flown with: physics, cameras and sticks follow it; progress
## and licences follow the course.
static func machine(vehicle: String) -> String:
	return MACHINE.get(vehicle, vehicle)


## A name or text as the pilot sees it now: Kids mode gets its own wording where there is one.
static func label(key: String) -> String:
	return String(TranslationServer.translate(text_key(key, Prefs.mode)))


## Kids mode has its own wording for many texts: KEY_KIDS, when it exists. With the throttle on the
## right stick (Mode 1), texts that name a stick have their own wording too: KEY_M1.
static func text_key(key: String, mode: String) -> String:
	if mode == "kids":
		var kids := key + "_KIDS"
		if String(TranslationServer.translate(kids)) != kids:
			return kids
	elif Prefs.stick_mode == "1":
		var m1 := key + "_M1"
		if String(TranslationServer.translate(m1)) != m1:
			return m1
	return key


static func missions(vehicle: String, mode: String) -> Array:
	return MISSIONS.get(vehicle, {}).get("kids" if mode == "kids" else "adult", [])
