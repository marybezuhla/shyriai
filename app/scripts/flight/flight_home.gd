# SPDX-License-Identifier: GPL-3.0-or-later
# Return to home for the camera drone, as on a real one: it climbs to a safe height, flies back over
# the pad and lands. It starts by itself on a low battery (20 %, after a warning at 30 %) or when the
# radio link has been lost for 2 s, and on the "Home" button. Moving a stick takes control back,
# unless the link is down. Without GPS the drone does not know where home is, so it cannot return.
class_name FlightHome
extends RefCounted

const WARN := 0.3
const AUTO := 0.2
## Above every tree and roof in the valley.
const SAFE_ALT := 15.0
const LINK_WAIT := 2.0

var active := false
## A short message for the screen (a translation key), and how long it stays; "" = none.
var alert := ""
var alert_t := 0.0
## The last alert was a warning, shown in orange.
var alert_warn := false
var _warned := false
var _auto := false
var _no_link := 0.0


## Battery and link checks, once per physics step.
func update(sim: DroneSim, task: FlightTask, dt: float) -> void:
	alert_t = maxf(0.0, alert_t - dt)
	if alert_t <= 0.0:
		alert = ""
	if sim.p.get("battery_s", 0.0) > 0.0 and not sim.on_ground:
		if sim.battery <= WARN and not _warned:
			_warned = true
			_say("HINT_BATTERY_30", true)
		if sim.battery <= AUTO and not _auto:
			_auto = true
			start(sim, "HINT_RTH_BATTERY")
	_no_link = 0.0 if task.link_ok else _no_link + dt
	if _no_link >= LINK_WAIT and not active and not sim.on_ground:
		start(sim, "HINT_RTH_LINK")


## Starts the way home. False, with a message, when it cannot.
func start(sim: DroneSim, why := "HINT_RTH") -> bool:
	if not sim.gps:
		_say("HINT_RTH_NO_GPS", true)
		return false
	if sim.on_ground:
		return false
	active = true
	_say(why, why != "HINT_RTH")
	return true


## The pilot moved a stick: control goes back to them (only with a link).
func take_back(pilot: Dictionary, link_ok: bool) -> void:
	if not active or not link_ok:
		return
	for k in pilot:
		if absf(float(pilot[k])) > 0.3:
			active = false
			_say("HINT_RTH_CANCEL", false)
			return


## The sticks that fly the drone home and land it on the pad.
func sticks(sim: DroneSim, home: Vector3) -> Dictionary:
	var to := Vector3(home.x - sim.pos.x, 0, home.z - sim.pos.z)
	var d := to.length()
	var alt := sim.altitude()
	var vmax := float(sim.p["vmax"])
	var want := Vector3.ZERO
	var throttle := 0.0
	if d > 1.0:
		# Up to a safe height first, then home at that height.
		throttle = clampf((SAFE_ALT - alt) * 0.4, -0.5, 1.0)
		if alt > SAFE_ALT - 3.0 or d < 6.0:
			want = to.normalized() * minf(vmax * 0.8, d * 0.6)
	else:
		# Over the pad: down, slowly near the ground.
		want = to * 0.6
		throttle = -0.6 if alt > 2.5 else -0.25
	if sim.on_ground and d < 3.0:
		active = false
		_say("HINT_RTH_LANDED", false)
	# Hold against drift: the stick asks for a speed over the ground.
	var cmd := (want + (want - Vector3(sim.vel.x, 0, sim.vel.z)) * 0.6) / vmax
	return {
		"throttle": throttle, "yaw": 0.0,
		"pitch": clampf(cmd.dot(sim.forward()), -1.0, 1.0), "roll": clampf(cmd.dot(sim.right()), -1.0, 1.0),
	}


func _say(key: String, warn: bool) -> void:
	alert = key
	alert_t = 4.0
	alert_warn = warn
