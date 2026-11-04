# SPDX-License-Identifier: GPL-3.0-or-later
# Physics of the FPV drone. Unlike the camera drone, nothing holds the height: the left stick is
# the throttle and stays where the thumb leaves it. Three flight modes:
#   angle    the right stick sets the tilt; let go and the drone levels itself
#   horizon  like angle near the centre, free rotation at the stick's ends
#   acro     the right stick sets how fast it rotates; it never levels itself
class_name FpvSim
extends DroneSim

const G := 9.8
const FPV := {
	# thrust: maximum thrust in g (hover throttle = 1/thrust). drag: air drag per second.
	"simple": {"tilt": 30.0, "rate": 220.0, "yaw": 150.0, "thrust": 1.9, "drag": 0.75, "wind": 0.6,
		"gust": 0.2, "ceiling": 40.0, "crash": false, "bounce": 0.0, "battery_s": 0.0},
	"pro": {"tilt": 45.0, "rate": 520.0, "yaw": 260.0, "thrust": 2.6, "drag": 0.45, "wind": 1.5,
		"gust": 0.5, "ceiling": 60.0, "crash": true, "bounce": 0.0, "battery_s": 300.0,
		"crash_speed": 4.0, "crash_fall": 4.5},
}
const LEVEL_GAIN := 7.0  # how fast angle mode levels the drone, 1/s
const RATE_TAU := 0.04

var flight_mode := "angle"
## The drone's turn in space. -Z is the nose, +Y the top.
var att := Basis.IDENTITY
## Body rotation rates, rad/s: x pitch (nose up), y yaw (left), z roll (right wing up).
var omega := Vector3.ZERO
var throttle01 := 0.0


func _init(mode := "simple", seed_ := 1) -> void:
	super(mode, seed_)
	p = FPV.get(mode, FPV["simple"]).duplicate()
	p["vmax"] = 12.0
	p["landing_assist"] = false


func hover_throttle() -> float:
	return 1.0 / float(p["thrust"])


func orientation() -> Basis:
	return att


func place(at: Vector3, heading := 0.0) -> void:
	super(at, heading)
	att = Basis(Vector3.UP, heading)
	omega = Vector3.ZERO


## Tilt now: nose down and right wing down are positive, in radians.
func tilt_angles() -> Vector2:
	var f := -att.z
	var r := att.x
	return Vector2(-asin(clampf(f.y, -1.0, 1.0)), -asin(clampf(r.y, -1.0, 1.0)))


func step(dt: float, throttle: float, yaw_in: float, pitch: float, roll: float) -> void:
	events.clear()
	time += dt
	if crashed:
		_fall(dt)
		return
	throttle01 = clampf((throttle + 1.0) * 0.5, 0.0, 1.0)
	if p["battery_s"] > 0.0:
		battery = maxf(0.0, battery - dt * (0.4 + throttle01) / float(p["battery_s"]))
		if battery <= 0.0:
			throttle01 = minf(throttle01, hover_throttle() * 0.8)

	var g := ground.call(pos.x, pos.z) as float
	if on_ground:
		vel = Vector3.ZERO
		omega = Vector3.ZERO
		att = Basis(Vector3.UP, yaw)
		if throttle01 > hover_throttle() + 0.04:
			on_ground = false
			events.append({"type": "took_off", "speed": 0.0})
		else:
			pos.y = g
			return

	# Rotation
	var max_rate := deg_to_rad(p["rate"])
	var stick := Vector3(-_expo(pitch), 0.0, -_expo(roll)) * max_rate
	var want := Vector3.ZERO
	match flight_mode:
		"acro":
			want = stick
		"horizon":
			# Self-levelling fades out towards the ends of the stick.
			var h := clampf(maxf(absf(pitch), absf(roll)) * 1.4 - 0.4, 0.0, 1.0)
			want = _level_rates(pitch, roll).lerp(stick, h)
		_:
			want = _level_rates(pitch, roll)
	want.y = -deg_to_rad(p["yaw"]) * yaw_in
	omega = omega.lerp(want, 1.0 - exp(-dt / RATE_TAU))
	att = (att * Basis.from_euler(omega * dt)).orthonormalized()

	# Forces: thrust along the drone's top, gravity, air drag relative to the wind.
	var thrust := att.y * float(p["thrust"]) * G * throttle01
	var air := vel - wind()
	var acc := thrust + Vector3(0, -G, 0) - air * float(p["drag"])
	if pos.y - g > float(p["ceiling"]) and acc.y > 0.0:
		acc.y = minf(acc.y, -vel.y * 2.0)
	vel += acc * dt
	pos += vel * dt

	# Heading and tilt for the rest of the app.
	var f := -att.z
	if Vector2(f.x, f.z).length() > 0.2:
		yaw = atan2(-f.x, -f.z)
	tilt = tilt_angles()
	tilt.x = -tilt.x  # base tilt uses nose-up positive

	_collide()
	_touch_ground_fpv()


func _level_rates(pitch: float, roll: float) -> Vector3:
	var max_tilt := deg_to_rad(p["tilt"])
	var now := tilt_angles()
	# Positive x rate lifts the nose; positive z rate lifts the right wing.
	return Vector3(
		-(pitch * max_tilt - now.x) * LEVEL_GAIN,
		0.0,
		-(roll * max_tilt - now.y) * LEVEL_GAIN)


func _expo(s: float) -> float:
	return 0.6 * s * absf(s) + 0.4 * s


func _touch_ground_fpv() -> void:
	var g := ground.call(pos.x, pos.z) as float
	if pos.y > g:
		return
	var down := -vel.y
	var side := Vector2(vel.x, vel.z).length()
	pos.y = g
	if p["crash"] and (down > float(p["crash_fall"]) or side > 7.0):
		crash_speed = maxf(down, side)
		crashed = true
		events.append({"type": "crash", "speed": crash_speed})
		return
	vel.y = 0.0
	vel.x *= 0.5
	vel.z *= 0.5
	if throttle01 <= hover_throttle() + 0.04:
		on_ground = true
		vel = Vector3.ZERO
		omega = Vector3.ZERO
		att = Basis(Vector3.UP, yaw)
		events.append({"type": "landed", "speed": down})


func _fall(dt: float) -> void:
	var g := ground.call(pos.x, pos.z) as float
	if pos.y > g:
		vel.y -= G * dt
		pos += vel * dt
		att = (att * Basis.from_euler(Vector3(2.0, 0.5, 3.0) * dt)).orthonormalized()
	if pos.y <= g:
		pos.y = g
		vel = Vector3.ZERO
