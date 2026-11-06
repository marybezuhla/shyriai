# SPDX-License-Identifier: GPL-3.0-or-later
# Aerial photography rules: where the drone's camera points, whether a thing is in the frame and big
# enough, and whether the picture is sharp. Plain maths, no screen: the tests check it directly, and
# the flight uses the same numbers to place its camera.
class_name Photo
extends RefCounted

## Camera tilt on its gimbal, in degrees below the horizon. "forward" is the drone's usual view.
const TILTS := {"forward": 25.0, "angled": 55.0, "down": 90.0}
const TILT_ORDER := ["forward", "angled", "down"]
## The drone camera's vertical field of view.
const FOV := 75.0
## Faster than this (m/s, or turning in rad/s) and the picture smears.
const STILL_SPEED := 0.6
const STILL_TURN := 0.35
## Inside this part of the frame (1 = the very edge) a thing counts as "in the frame".
const FRAME := 0.85


## Where the camera is: a little in front of and above the middle of the drone.
static func camera_position(pos: Vector3, yaw: float) -> Vector3:
	return pos + Vector3(-sin(yaw), 0, -cos(yaw)) * 0.45 + Vector3(0, 0.2, 0)


static func camera_basis(yaw: float, tilt: String) -> Basis:
	return Basis.from_euler(Vector3(-deg_to_rad(TILTS.get(tilt, 25.0)), yaw, 0))


## How a round thing of `radius` at `point` looks from the camera:
## "in_frame", "at" (-1..1 across and up the frame), "size" (its height as a share of the frame's).
static func look(cam_pos: Vector3, basis: Basis, aspect: float, point: Vector3, radius: float) -> Dictionary:
	var p := basis.inverse() * (point - cam_pos)
	var depth := -p.z  # the camera looks along -Z
	if depth < 0.2:
		return {"in_frame": false, "at": Vector2.INF, "size": 0.0}
	var half := tan(deg_to_rad(FOV) / 2.0)
	var at := Vector2(p.x / (depth * half * aspect), p.y / (depth * half))
	var inside := absf(at.x) <= FRAME and absf(at.y) <= FRAME
	return {"in_frame": inside, "at": at, "size": radius / (depth * half)}


## Why a picture of a thing would not do, as a hint key, or "" if it is good.
## need: {"min_size": share of the frame, "max_size", "tilts": the tilts it may be taken with,
## "center": how far from the middle it may be (0..1)}.
static func verdict(seen: Dictionary, speed: float, turn: float, tilt: String, need: Dictionary) -> String:
	var tilts: Array = need.get("tilts", [])
	if not tilts.is_empty() and tilt not in tilts:
		return "PH_TILT_" + String(tilts[-1]).to_upper()
	if not seen["in_frame"]:
		return "PH_NOT_IN_FRAME"
	if need.has("center") and (seen["at"] as Vector2).length() > float(need["center"]):
		return "PH_CENTER"
	if float(seen["size"]) < float(need.get("min_size", 0.1)):
		return "PH_TOO_FAR"
	if float(seen["size"]) > float(need.get("max_size", 2.0)):
		return "PH_TOO_CLOSE"
	if speed > STILL_SPEED or absf(turn) > STILL_TURN:
		return "PH_BLUR"
	return ""
