# SPDX-License-Identifier: GPL-3.0-or-later
# Physics of the ground robot (UGV) on tracks. It always stays on the ground, follows the terrain,
# slows in mud and uphill, and can tip over on a steep slope in Adult mode.
#
# Tank steering: the left stick drives the left track, the right stick the right track.
# Car steering (Kids): the left stick goes forward and back, the right stick turns.
class_name UgvSim
extends DroneSim

const UGV := {
	# vmax m/s, turn deg/s at full opposite tracks, tau s to reach the stick's speed, tip deg.
	"kids": {"vmax": 2.2, "turn": 70.0, "tau": 0.3, "crash": false, "bounce": 0.3, "tip": 90.0,
		"battery_s": 0.0, "wind": 0.0, "gust": 0.0},
	"simple": {"vmax": 3.0, "turn": 80.0, "tau": 0.4, "crash": false, "bounce": 0.0, "tip": 90.0,
		"battery_s": 0.0, "wind": 0.0, "gust": 0.0},
	"pro": {"vmax": 4.0, "turn": 90.0, "tau": 0.6, "crash": true, "bounce": 0.0, "tip": 32.0,
		"battery_s": 600.0, "wind": 0.0, "gust": 0.0, "crash_speed": 2.5},
}
const HALF_LEN := 0.8  # m, for reading the slope under the robot
const HALF_WIDTH := 0.6
const MAX_STEP := 0.25  # m the ground may rise in one step; more is a wall

var tank := true
## Actual track speeds, -1..1.
var tracks := Vector2.ZERO
## Speed factor of the ground at (x, z): 1 on firm ground, lower in mud. Replaced by the world.
var grip: Callable = func(_x: float, _z: float) -> float: return 1.0
## How hard the ride is now, m/s²: speeding up, braking, turning, and bumps under the tracks.
var jolt := 0.0
var att := Basis.IDENTITY

var _vy := 0.0
var _jolt_raw := 0.0


func _init(mode := "simple", seed_ := 1) -> void:
	super(mode, seed_)
	p = UGV.get(mode, UGV["simple"]).duplicate()
	p["ceiling"] = 0.0
	p["landing_assist"] = false
	radius = 0.75
	tank = mode != "kids"


func orientation() -> Basis:
	return att


func altitude() -> float:
	return 0.0


func place(at: Vector3, heading := 0.0) -> void:
	super(at, heading)
	pos.y = ground.call(pos.x, pos.z)
	on_ground = true
	tracks = Vector2.ZERO
	jolt = 0.0
	_vy = 0.0
	att = _terrain_basis()


## Speed along the ground, m/s (negative when reversing).
func speed() -> float:
	return vel.dot(forward())


func step(dt: float, throttle: float, yaw_in: float, pitch: float, roll: float) -> void:
	events.clear()
	time += dt
	if crashed:
		return
	if p["battery_s"] > 0.0:
		battery = maxf(0.0, battery - dt * (0.3 + absf(tracks.x) + absf(tracks.y)) / float(p["battery_s"]))
	var want := Vector2.ZERO
	if tank:
		want = Vector2(throttle, pitch)
	else:
		var turn := roll * 0.7 + yaw_in * 0.7
		want = Vector2(clampf(throttle + turn, -1.0, 1.0), clampf(throttle - turn, -1.0, 1.0))
	if battery <= 0.0:
		want = Vector2.ZERO
	tracks = tracks.lerp(want, 1.0 - exp(-dt / float(p["tau"])))

	var f := float(grip.call(pos.x, pos.z))
	var v := (tracks.x + tracks.y) * 0.5 * float(p["vmax"]) * f
	var w := (tracks.x - tracks.y) * deg_to_rad(p["turn"]) * f  # positive turns right
	# Uphill is slower, downhill a little faster.
	var slope := _slope_along()
	v *= clampf(1.0 - slope * 1.6 * signf(v), 0.25, 1.3)
	var before := vel
	yaw = wrapf(yaw - w * dt, -PI, PI)
	vel = forward() * v
	var old := pos
	pos += vel * dt
	var g := ground.call(pos.x, pos.z) as float
	if g - old.y > MAX_STEP:
		# A wall or a sheer edge, not a slope: the tracks cannot climb it.
		pos = old
		g = old.y
		events.append({"type": "bump", "speed": absf(v)})
		vel = Vector3.ZERO
		tracks = Vector2.ZERO
	var vy := (g - pos.y) / maxf(dt, 1e-4)
	pos.y = g
	att = _terrain_basis()
	tilt = Vector2(asin(clampf(-(-att.z).y, -1.0, 1.0)), asin(clampf(-att.x.y, -1.0, 1.0)))

	# Ride: change of speed, the sideways pull of a turn, and the jump of a bump.
	var a_h := (vel - before).length() / maxf(dt, 1e-4)
	var a_turn := absf(v * w)
	var a_v := absf(vy - _vy) / maxf(dt, 1e-4)
	_vy = vy
	_jolt_raw = a_h + a_turn + a_v * 0.5
	jolt = lerpf(jolt, _jolt_raw, 1.0 - exp(-dt / 0.12))

	# Tipping over on a slope that is too steep (Adult mode).
	var lean := rad_to_deg(acos(clampf(att.y.y, -1.0, 1.0)))
	if p["crash"] and lean > float(p["tip"]):
		crashed = true
		crash_speed = lean
		events.append({"type": "tipped", "speed": lean})
		return

	_collide()
	pos.y = ground.call(pos.x, pos.z)


## Slope under the robot along its heading: + uphill, as a fraction (0.36 ≈ 20°).
func _slope_along() -> float:
	var fw := forward() * HALF_LEN
	var a := ground.call(pos.x + fw.x, pos.z + fw.z) as float
	var b := ground.call(pos.x - fw.x, pos.z - fw.z) as float
	return (a - b) / (2.0 * HALF_LEN)


## Lies on the ground: the top follows the terrain under the tracks.
func _terrain_basis() -> Basis:
	var fw := forward()
	var rt := right()
	var gf := ground.call(pos.x + fw.x * HALF_LEN, pos.z + fw.z * HALF_LEN) as float
	var gb := ground.call(pos.x - fw.x * HALF_LEN, pos.z - fw.z * HALF_LEN) as float
	var gr := ground.call(pos.x + rt.x * HALF_WIDTH, pos.z + rt.z * HALF_WIDTH) as float
	var gl := ground.call(pos.x - rt.x * HALF_WIDTH, pos.z - rt.z * HALF_WIDTH) as float
	var along := (fw * 2.0 * HALF_LEN + Vector3(0, gf - gb, 0)).normalized()
	var across := (rt * 2.0 * HALF_WIDTH + Vector3(0, gr - gl, 0)).normalized()
	var up := across.cross(along).normalized()
	if up.y < 0.0:
		up = -up
	var back := -along
	var x := up.cross(back).normalized()
	return Basis(x, up, back)
