# SPDX-License-Identifier: GPL-3.0-or-later
# What is taught, in what order. Titles and goals are translation keys (i18n/strings.csv).
class_name Curriculum
extends RefCounted

const VEHICLES := ["camera", "fpv", "ugv"]

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
}

## Missions per vehicle and mode family: kids get their own stories.
const MISSIONS := {
	"camera": {"kids": ["MIS_CAM_KITTEN"], "adult": ["MIS_CAM_SEARCH", "MIS_CAM_SURVEY"]},
	"fpv": {"kids": ["MIS_FPV_HOOPS", "MIS_FPV_BALLOONS"], "adult": ["MIS_FPV_RACE", "MIS_FPV_TREES"]},
	"ugv": {"kids": ["MIS_UGV_VET", "MIS_UGV_PARCEL"], "adult": ["MIS_UGV_CARGO", "MIS_UGV_EVAC"]},
}

const THEORY := ["TH_CHECKLIST", "TH_BATTERY", "TH_SIGNAL", "TH_RULES"]

## Flying without self-levelling is for Adult mode only.
const PRO_ONLY := ["FPV_HORIZON", "FPV_ACRO"]


## The lessons of a vehicle in a mode. Without a mode: every lesson there is.
static func lessons(vehicle: String, mode := "") -> Array:
	var all: Array = LESSONS.get(vehicle, [])
	if mode == "" or mode == "pro":
		return all
	return all.filter(func(k): return k not in PRO_ONLY)


## Kids mode has its own wording for many texts: KEY_KIDS, when it exists.
static func text_key(key: String, mode: String) -> String:
	if mode == "kids":
		var kids := key + "_KIDS"
		if String(TranslationServer.translate(kids)) != kids:
			return kids
	return key


static func missions(vehicle: String, mode: String) -> Array:
	return MISSIONS.get(vehicle, {}).get("kids" if mode == "kids" else "adult", [])
