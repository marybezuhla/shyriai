# SPDX-License-Identifier: GPL-3.0-or-later
# Physics of the camera drone. Pure maths, no nodes: the same code runs in the app and in tests.
#
# Sticks (Mode 2), each -1..1:
#   throttle  left stick up/down    climb rate
#   yaw       left stick left/right turn
#   pitch     right stick up/down   forward/back
#   roll      right stick left/right sideways
#
# With position hold (GPS) the drone keeps its place over the ground when the sticks are let go.
# Without it (ATTI) it keeps its place in the air, so the wind carries it away.
class_name DroneSim
extends RefCounted

const RADIUS := 0.35  # metres, for collisions
const AREA_RADIUS := 120.0  # the drone is gently kept inside this circle

# How each mode feels. Speeds in m/s, turn in degrees/s, tau = seconds to reach the stick's speed.
const MODES := {
	"kids": {"vmax": 3.0, "vz": 1.5, "yaw": 70.0, "tau": 0.25, "tau_z": 0.25, "wind": 0.0,
		"gust": 0.0, "ceiling": 15.0, "crash": false, "bounce": 0.4, "landing_assist": true, "battery_s": 0.0},
	"simple": {"vmax": 5.0, "vz": 2.0, "yaw": 90.0, "tau": 0.45, "tau_z": 0.3, "wind": 1.0,
		"gust": 0.3, "ceiling": 40.0, "crash": false, "bounce": 0.0, "landing_assist": true, "battery_s": 0.0},
	"pro": {"vmax": 8.0, "vz": 3.0, "yaw": 110.0, "tau": 0.9, "tau_z": 0.45, "wind": 2.5,
		"gust": 0.8, "ceiling": 60.0, "crash": true, "bounce": 0.0, "landing_assist": false, "battery_s": 480.0},
}
const CRASH_SPEED := 2.5  # m/s into an obstacle, Adult mode only
const CRASH_FALL := 3.0  # m/s into the ground, Adult mode only

var p: Dictionary
var gps := true

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0  # radians; 0 = nose towards -Z
var tilt := Vector2.ZERO  # pitch, roll in radians, for drawing only
var on_ground := true
var crashed := false
var crash_speed := 0.0
var battery := 1.0
var time := 0.0
## What happened during the last step: {"type": "landed"|"bump"|"crash"|"took_off", "speed": float}
var events: Array[Dictionary] = []

## Ground height at (x, z). Replaced by the world; flat by default.
var ground: Callable = func(_x: float, _z: float) -> float: return 0.0
## Obstacles: {"box": AABB} or {"cyl": Vector2(x, z), "r": float, "h": float, "y": float}
var obstacles: Array[Dictionary] = []

var _wind_dir := 0.0
var _rng := RandomNumberGenerator.new()


func _init(mode := "simple", seed_ := 1) -> void:
	p = MODES.get(mode, MODES["simple"]).duplicate()
	_rng.seed = seed_
	_wind_dir = _rng.randf() * TAU


func set_wind(speed: float, gust: float) -> void:
	p["wind"] = speed
	p["gust"] = gust


func place(at: Vector3, heading := 0.0) -> void:
	pos = at
	pos.y = maxf(at.y, ground.call(at.x, at.z))
	vel = Vector3.ZERO
	yaw = heading
	on_ground = pos.y <= ground.call(pos.x, pos.z) + 0.01
	crashed = false
	crash_speed = 0.0
	battery = 1.0
	time = 0.0


## How the drone is turned in space, for drawing it and for cameras on it.
func orientation() -> Basis:
	return Basis.from_euler(Vector3(tilt.x, yaw, -tilt.y))


func altitude() -> float:
	return pos.y - ground.call(pos.x, pos.z)


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func wind() -> Vector3:
	var base: float = p["wind"]
	if base <= 0.0:
		return Vector3.ZERO
	# Slow, smooth gusts from a sum of sines; the direction drifts too.
	var g: float = p["gust"] * (0.6 * sin(time * 0.7 + 1.3) + 0.4 * sin(time * 1.9 + 0.2))
	var dir := _wind_dir + 0.35 * sin(time * 0.05)
	return Vector3(cos(dir), 0, sin(dir)) * base * (1.0 + g)


func step(dt: float, throttle: float, yaw_in: float, pitch: float, roll: float) -> void:
	events.clear()
	time += dt
	if crashed:
		_fall(dt)
		return

	if p["battery_s"] > 0.0:
		battery = maxf(0.0, battery - dt / p["battery_s"])
		if battery <= 0.0:
			# Empty battery: the drone lands by itself.
			throttle = -0.6
			pitch = 0.0
			roll = 0.0

	var g := ground.call(pos.x, pos.z) as float

	if on_ground:
		vel = Vector3.ZERO
		tilt = Vector2.ZERO
		if throttle > 0.25:
			on_ground = false
			events.append({"type": "took_off", "speed": 0.0})
		else:
			pos.y = g
			return

	yaw = wrapf(yaw - deg_to_rad(p["yaw"]) * yaw_in * dt, -PI, PI)

	# Horizontal: chase the speed the sticks ask for.
	var want := (forward() * pitch + right() * roll) * float(p["vmax"])
	var air := wind()
	if not gps:
		want += air  # holds in the air, so the wind carries it; with GPS the wind is compensated
	var horiz := Vector3(vel.x, 0, vel.z)
	var k := 1.0 - exp(-dt / float(p["tau"]))
	var new_h := horiz.lerp(want, k)
	var accel := (new_h - horiz) / maxf(dt, 1e-4)

	# Vertical
	var want_z := throttle * float(p["vz"])
	var alt := pos.y - g
	if p["landing_assist"] and want_z < 0.0 and alt < 1.0:
		want_z = maxf(want_z, -0.4)
	if alt > float(p["ceiling"]) and want_z > 0.0:
		want_z = 0.0
	var kz := 1.0 - exp(-dt / float(p["tau_z"]))
	var vz := lerpf(vel.y, want_z, kz)

	vel = Vector3(new_h.x, vz, new_h.z)

	# Keep inside the flying area.
	var flat := Vector2(pos.x, pos.z)
	if flat.length() > AREA_RADIUS:
		var back := -flat.normalized() * (flat.length() - AREA_RADIUS) * 2.0
		vel.x += back.x * dt
		vel.z += back.y * dt

	pos += vel * dt

	# Tilt for drawing: a drone leans into its acceleration.
	var a_fwd := accel.dot(forward())
	var a_right := accel.dot(right())
	tilt = tilt.lerp(Vector2(clampf(-a_fwd * 0.06, -0.45, 0.45), clampf(a_right * 0.06, -0.45, 0.45)), 0.2)

	_collide()
	_touch_ground()


func _touch_ground() -> void:
	var g := ground.call(pos.x, pos.z) as float
	if pos.y > g:
		return
	var speed := -vel.y
	pos.y = g
	if p["crash"] and speed > float(p.get("crash_fall", CRASH_FALL)):
		_crash(speed)
		return
	on_ground = true
	vel = Vector3.ZERO
	events.append({"type": "landed", "speed": speed})


func _collide() -> void:
	for o in obstacles:
		var push := Vector3.ZERO
		if o.has("box"):
			var box: AABB = o["box"]
			var c := pos.clamp(box.position, box.end)
			var d := pos - c
			var dist := d.length()
			if dist >= RADIUS:
				continue
			if dist < 1e-4:
				# Centre inside the box: push out through the nearest face (upwards on a roof).
				d = Vector3.UP
				dist = 0.0
			push = d.normalized() * (RADIUS - dist)
		elif o.has("cyl"):
			var c2: Vector2 = o["cyl"]
			var r: float = o["r"]
			var base_y: float = o.get("y", 0.0)
			if pos.y > base_y + float(o["h"]) + RADIUS or pos.y < base_y - RADIUS:
				continue
			var d2 := Vector2(pos.x, pos.z) - c2
			var dist2 := d2.length()
			if dist2 >= r + RADIUS:
				continue
			var n := d2.normalized() if dist2 > 1e-4 else Vector2(1, 0)
			push = Vector3(n.x, 0, n.y) * (r + RADIUS - dist2)
		else:
			continue
		var normal := push.normalized()
		var into := -vel.dot(normal)
		pos += push
		if into <= 0.0:
			continue
		if p["crash"] and into > float(p.get("crash_speed", CRASH_SPEED)):
			_crash(into)
			return
		# Bounce softly in Kids mode, stop against it otherwise.
		vel += normal * into * (1.0 + float(p["bounce"]))
		events.append({"type": "bump", "speed": into})


func _crash(speed: float) -> void:
	crashed = true
	crash_speed = speed
	events.append({"type": "crash", "speed": speed})


func _fall(dt: float) -> void:
	var g := ground.call(pos.x, pos.z) as float
	if pos.y > g:
		vel.y -= 9.8 * dt
		vel.x *= 0.98
		vel.z *= 0.98
		pos += vel * dt
		tilt += Vector2(1.5, 2.1) * dt
	if pos.y <= g:
		pos.y = g
		vel = Vector3.ZERO
