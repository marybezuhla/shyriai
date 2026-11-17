# SPDX-License-Identifier: GPL-3.0-or-later
# The battery of the FPV drone and the plane, as a pilot sees it. The FPV goggles show the voltage
# of a four-cell pack, which sags under throttle as on a real LiPo: a warning at 3.5 V a cell and
# "land now" at 3.3 V. The plane warns at 25 %. (The camera drone has its own: FlightHome.)
class_name FlightBattery
extends RefCounted

const CELLS := 4
const CELL_WARN := 3.5
const CELL_LAND := 3.3
const WING_WARN := 0.25
## Charge left (0..1) and the resting voltage of a cell at it.
const CURVE := [[0.0, 3.3], [0.1, 3.55], [0.2, 3.68], [0.5, 3.8], [0.8, 3.95], [1.0, 4.2]]

var _warned := false
var _land := false


## The pack voltage now: the resting voltage less the sag of the current drawn.
static func volts(sim: FpvSim) -> float:
	var b := clampf(sim.battery, 0.0, 1.0)
	var cell := 4.2
	for i in range(1, CURVE.size()):
		if b <= CURVE[i][0]:
			var a: Array = CURVE[i - 1]
			var t := (b - float(a[0])) / (float(CURVE[i][0]) - float(a[0]))
			cell = lerpf(float(a[1]), float(CURVE[i][1]), t)
			break
	return cell * CELLS - 1.5 * sim.throttle01 * (1.3 - b)


## Once per physics step: the warnings, each said once.
func update(f: Flight) -> void:
	var sim := f.sim
	if sim.p.get("battery_s", 0.0) <= 0.0 or sim.on_ground:
		return
	if sim is FpvSim:
		var v := volts(sim as FpvSim)
		if v < CELL_LAND * CELLS and not _land:
			_land = true
			f.alert("HINT_FPV_LAND_NOW", true, 5.0)
		elif v < CELL_WARN * CELLS and not _warned:
			_warned = true
			f.alert("HINT_FPV_LOW_V", true, 4.0)
	elif sim is WingSim and sim.battery <= WING_WARN and not _warned:
		_warned = true
		f.alert("HINT_WING_BATTERY", true, 4.0)


## What the battery reading says: volts for FPV goggles, per cent elsewhere.
static func text(f: Flight) -> String:
	if f.sim is FpvSim:
		return f.tr("UNIT_V") % FlightTask.num(volts(f.sim as FpvSim), 1)
	return "%d %%" % int(ceil(f.sim.battery * 100.0))


static func fail_key(sim: DroneSim) -> String:
	if sim is UgvSim:
		return "FAIL_BATTERY_UGV"
	if sim is FpvSim:
		return "FAIL_BATTERY_FPV"
	if sim is WingSim:
		return "FAIL_BATTERY_WING"
	return "FAIL_BATTERY"
