# SPDX-License-Identifier: GPL-3.0-or-later
# Physics of the trainer plane. Unlike a drone it cannot hover: the wing lifts only while the plane
# moves, and it turns by banking. Pure maths, no nodes, so the tests fly exactly what the app flies.
#
# Sticks (Mode 2), each -1..1:
#   throttle  left stick up/down, stays where the thumb leaves it   motor
#   yaw       left stick left/right                                 rudder
#   pitch     right stick up/down: up = nose down, like a real radio elevator
#   roll      right stick left/right                                ailerons
# Kids mode is different: the app holds the speed, and the right stick up means "climb".
#
# The model: the elevator sets the angle of attack (how steeply the wing meets the air); lift grows
# with it and with speed squared, up to the stall. Lift bends the flight path up, and when banked,
# sideways: that is the turn. Thrust, drag and gravity along the path change the speed.
class_name WingSim
extends DroneSim

const G := 9.8
## Lift per unit of lift coefficient and speed squared (m/s² per (m/s)²): with CL_MAX the wing
## carries the plane down to the stall speed V_STALL.
const K_LIFT := 0.1255
const LIFT_SLOPE := 5.0  # lift coefficient per radian of angle of attack
const ALPHA_STALL := deg_to_rad(14.0)
const CL_MAX := LIFT_SLOPE * ALPHA_STALL
const V_STALL := 8.0  # m/s, wings level: sqrt(G / (K_LIFT * CL_MAX))
## The angle of attack with the elevator centred: about level flight at cruise speed.
const ALPHA_TRIM := deg_to_rad(5.0)
const DRAG_0 := 0.05
const DRAG_INDUCED := 0.06
const ROLL_TAU := 0.25
const ALPHA_TAU := 0.2
## Beyond this distance from the field the plane turns back by itself, gently.
const HOME_RADIUS := 170.0
const WING := {
	# thrust: m/s² at full throttle standing still; prop_v: speed where the propeller stops pulling.
	"kids": {"thrust": 4.5, "prop_v": 24.0, "bank": 30.0, "roll_rate": 0.0, "cruise": 12.0,
		"alpha_up": 7.0, "alpha_down": 7.0, "wind": 0.0, "gust": 0.0, "crash": false, "battery_s": 0.0,
		"floor": 6.0},
	"simple": {"thrust": 4.5, "prop_v": 24.0, "bank": 35.0, "roll_rate": 0.0, "cruise": 0.0,
		"alpha_up": 9.0, "alpha_down": 10.0, "wind": 1.0, "gust": 0.3, "crash": false, "battery_s": 0.0,
		"floor": 0.0},
	"pro": {"thrust": 5.0, "prop_v": 26.0, "bank": 0.0, "roll_rate": 110.0, "cruise": 0.0,
		"alpha_up": 11.0, "alpha_down": 10.0, "wind": 2.5, "gust": 0.8, "crash": true, "battery_s": 360.0,
		"floor": 0.0, "crash_fall": 3.0, "crash_speed": 4.0},
}

var throttle01 := 0.0
## Speed through the air along the nose, m/s.
var speed := 0.0
## Flight path angle (climb positive), bank (right wing down positive) and angle of attack, radians.
var gamma := 0.0
var bank := 0.0
var alpha := ALPHA_TRIM
## The wing has stalled: lift collapses until the nose is lowered.
var stalled := false
## Close to the stall: slow, or the nose pulled too high. The screen warns.
var stall_warn := false
## Simple mode keeps the wing from stalling; the stall lesson turns this off.
var stall_protect := true
var kids := false
var _mode := "simple"
var _spin := 0.0


func _init(mode := "simple", seed_ := 1) -> void:
	super(mode, seed_)
	_mode = mode if WING.has(mode) else "simple"
	p = WING[_mode].duplicate()
	p["vmax"] = 20.0
	p["landing_assist"] = false
	kids = _mode == "kids"
	stall_protect = _mode != "pro"
	radius = 0.6


## The pitch of the nose: the path plus the angle of attack.
func pitch_angle() -> float:
	return gamma + alpha


func orientation() -> Basis:
	return Basis.from_euler(Vector3(pitch_angle(), yaw, -bank))


func place(at: Vector3, heading := 0.0) -> void:
	super(at, heading)
	gamma = 0.0
	bank = 0.0
	alpha = ALPHA_TRIM
	stalled = false
	stall_warn = false
	_spin = 0.0
	if on_ground:
		speed = 0.0
		throttle01 = 0.0
	else:
		# Started in the air: already flying at cruise speed, motor at cruise.
		speed = 13.0
		throttle01 = 0.62
		vel = forward() * speed


func lift_coefficient() -> float:
	if alpha <= ALPHA_STALL:
		return LIFT_SLOPE * alpha
	# Past the stall the lift drops off quickly.
	return maxf(0.3, CL_MAX - (alpha - ALPHA_STALL) * 3.0)


func step(dt: float, throttle: float, yaw_in: float, pitch: float, roll: float) -> void:
	events.clear()
	time += dt
	if crashed:
		_fall(dt)
		return
	var g := ground.call(pos.x, pos.z) as float

	# Motor. Kids: the app holds the cruise speed.
	if kids:
		throttle01 = clampf(throttle01 + (float(p["cruise"]) - speed) * 0.3 * dt, 0.2, 1.0)
	else:
		throttle01 = clampf((throttle + 1.0) * 0.5, 0.0, 1.0)
	if p["battery_s"] > 0.0:
		battery = maxf(0.0, battery - dt * (0.3 + throttle01) / float(p["battery_s"]))
		if battery <= 0.0:
			throttle01 = 0.0

	# Elevator -> angle of attack. On a real radio, stick up is nose down; kids' up means climb.
	var elev := pitch if kids else -pitch
	var want_alpha := ALPHA_TRIM + elev * deg_to_rad(p["alpha_up"] if elev > 0.0 else p["alpha_down"])
	stall_warn = speed < V_STALL * 1.2 or want_alpha > ALPHA_STALL - deg_to_rad(2.0)
	if stall_protect:
		# Simple and Kids: the wing never goes past the stall; slow, the nose is lowered for you.
		want_alpha = minf(want_alpha, ALPHA_STALL - deg_to_rad(2.5))
		if speed < V_STALL * 1.15:
			want_alpha = minf(want_alpha, ALPHA_TRIM - deg_to_rad(2.0))
	alpha = lerpf(alpha, want_alpha, 1.0 - exp(-dt / ALPHA_TAU))
	var was_stalled := stalled
	stalled = alpha > ALPHA_STALL or (not on_ground and speed < V_STALL * 0.7)
	if stalled and not was_stalled:
		events.append({"type": "stall", "speed": speed})

	# Ailerons -> bank. Simple and Kids: the stick sets the bank and the plane levels itself.
	if p["roll_rate"] > 0.0:
		var rate := deg_to_rad(p["roll_rate"]) * roll
		rate += deg_to_rad(25.0) * yaw_in  # the rudder rolls a high-wing trainer too
		rate -= bank * 0.25  # dihedral: a little self-levelling
		if stalled:
			# A stalled wing drops: one wing first, turning into a spin if nothing is done.
			_spin = clampf(_spin + dt * 1.5, 0.0, 1.0)
			rate += deg_to_rad(120.0) * _spin * (1.0 if bank >= 0.0 else -1.0)
		else:
			_spin = maxf(0.0, _spin - dt * 2.0)
		bank = wrapf(bank + rate * dt, -PI, PI)
	else:
		var want_bank := deg_to_rad(p["bank"]) * clampf(roll + 0.4 * yaw_in, -1.0, 1.0)
		bank = lerpf(bank, want_bank, 1.0 - exp(-dt / ROLL_TAU))
	if not kids:
		yaw -= deg_to_rad(10.0) * yaw_in * dt  # the rudder alone yaws a little

	# Turn back home, gently, when far out over the hills.
	var flat := Vector2(pos.x, pos.z)
	if flat.length() > HOME_RADIUS and not on_ground:
		var home := atan2(pos.x, pos.z)  # heading that points at the centre
		var off := wrapf(yaw - home, -PI, PI)
		bank = lerpf(bank, clampf(off * 1.2, -0.5, 0.5), 1.0 - exp(-dt * 2.0))

	# Forces along and across the path.
	var cl := lift_coefficient()
	var v2 := speed * speed
	var lift := K_LIFT * cl * v2
	var drag := K_LIFT * (DRAG_0 + DRAG_INDUCED * cl * cl) * v2
	var thrust := float(p["thrust"]) * throttle01 * maxf(0.0, 1.0 - speed / float(p["prop_v"]))
	if on_ground:
		drag += 0.6 + (2.5 if throttle01 < 0.05 else 0.0)  # wheels, and brakes once the motor is off
	speed = maxf(0.0, speed + (thrust - drag - G * sin(gamma)) * dt)

	if on_ground:
		gamma = 0.0
		bank = lerpf(bank, 0.0, 1.0 - exp(-dt * 6.0))
		alpha = minf(alpha, deg_to_rad(10.0))
		vel = forward() * speed
		pos += vel * dt
		pos.y = ground.call(pos.x, pos.z)
		if lift > G * 1.02 and speed > V_STALL:
			on_ground = false
			events.append({"type": "took_off", "speed": 0.0})
		_collide()
		return

	var v := maxf(speed, 1.0)
	if kids:
		# Kids steer the path itself: stick up climbs, centred flies level, and the app never lets
		# the plane come lower than the floor. The wing always carries it through the turn.
		var want_gamma := deg_to_rad(12.0) * elev
		if pos.y - g < float(p["floor"]):
			want_gamma = maxf(want_gamma, deg_to_rad(8.0))
		gamma = lerpf(gamma, want_gamma, 1.0 - exp(-dt * 1.5))
		lift = G * cos(gamma) / maxf(cos(bank), 0.5)
		speed = maxf(speed, 10.0)
	else:
		gamma += (lift * cos(bank) - G * cos(gamma)) / v * dt
		gamma = clampf(gamma, -1.3, 1.3)
	yaw = wrapf(yaw - lift * sin(bank) / (v * maxf(cos(gamma), 0.2)) * dt, -PI, PI)

	vel = forward() * (v * cos(gamma)) + Vector3(0, v * sin(gamma), 0) + wind()
	if speed < 1.0:
		vel.y -= G * dt * 2.0
	pos += vel * dt
	tilt = Vector2(pitch_angle(), bank)
	_collide()
	_touch_down()


## Wheels on the ground: a landing if it came down gently and wings level, a crash in Adult mode if not.
func _touch_down() -> void:
	var g := ground.call(pos.x, pos.z) as float
	if pos.y > g:
		return
	var down := -vel.y
	pos.y = g
	if p["crash"] and (down > float(p["crash_fall"]) or absf(bank) > deg_to_rad(25.0)):
		_crash(down)
		return
	on_ground = true
	gamma = 0.0
	events.append({"type": "landed", "speed": down})


func _fall(dt: float) -> void:
	var g := ground.call(pos.x, pos.z) as float
	if pos.y > g:
		vel.y -= G * dt
		pos += vel * dt
		bank += 3.0 * dt
	if pos.y <= g:
		pos.y = g
		vel = Vector3.ZERO
		speed = 0.0
