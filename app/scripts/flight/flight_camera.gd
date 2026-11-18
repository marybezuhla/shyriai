# SPDX-License-Identifier: GPL-3.0-or-later
# Where the flight's camera stands and looks, for each view: on the vehicle, behind it, or at the
# pilot's place. Kept apart from flight.gd so that file stays one topic.
class_name FlightCamera
extends RefCounted

## The first lessons are watched from closer: the drone looks bigger and its moves are easy to see.
const CLOSE := ["CAM_STICKS", "CAM_TAKEOFF"]


static func place(f: Flight, delta: float) -> void:
	var target := f.sim.pos + Vector3(0, 0.15, 0)
	if f.view == "fpv":
		# The FPV camera is fixed to the drone, tilted up, so the horizon tilts with it.
		var up_tilt := 10.0 if f.sim is not FpvSim else (20.0 if f.mode == "simple" else 30.0)
		var b := f.sim.orientation()
		var at := Vector3(0, 0.12, -0.45)
		if f.sim is WingSim:
			# The plane's camera looks straight ahead from the top of the nose.
			up_tilt = 0.0
			at = Vector3(0, 0.35, -0.9)
		f.cam.global_basis = b * Basis(Vector3.RIGHT, deg_to_rad(up_tilt))
		f.cam.position = f.sim.pos + b * at
		f.cam.fov = 95.0
	elif f.view == "drone":
		# The drone's own camera on a steady gimbal: tilted down a little, or as far as the survey
		# camera is tilted. The shutter uses the very same pose.
		f.cam.position = Photo.camera_position(f.sim.pos, f.sim.yaw)
		f.cam.global_basis = Photo.camera_basis(f.sim.yaw, f.task.tilt if f.task is PhotoTask else "forward")
		f.cam.fov = Photo.FOV
	elif f.view == "ugv":
		# The robot's own camera on its mast. Some tasks show its video late, as over a slow radio link.
		var pose: Array = [f.sim.pos, f.sim.orientation()]
		var back := int(round(f.task.video_delay / f.STEP))
		if back > 0 and f._cam_history.size() > back:
			pose = f._cam_history[f._cam_history.size() - 1 - back]
		var b: Basis = pose[1]
		f.cam.global_basis = b * Basis(Vector3.RIGHT, deg_to_rad(-8.0))
		f.cam.position = pose[0] + b * Vector3(0, 1.12, -0.76)  # just in front of the lens on the round head
		f.cam.fov = 80.0
	elif f.view == "chase":
		# A plane is fast and wide: the chase camera hangs further back.
		var far := 1.8 if f.sim is WingSim else 1.0
		var back := -f.sim.forward() * 6.0 * far + Vector3(0, 2.6 * far, 0)
		var want := target + back
		var g := f.sim.ground.call(want.x, want.z) as float
		want.y = maxf(want.y, g + 1.0)
		var k := 1.0 - exp(-delta * 4.0)
		f.cam.position = f.cam.position.lerp(want, k) if f.cam.position != Vector3.ZERO else want
		f.cam.fov = 62.0
		f.cam.look_at(target + f.sim.forward() * 2.0, Vector3.UP)
	else:
		# The pilot stands behind the pad and turns the head; far away, the f.view zooms in a little.
		f.cam.position = f.world.pilot
		if f.task_key in CLOSE:
			f.cam.position = f.world.pilot.lerp(f.world.pad + Vector3(0, 1.7, 0), 0.45)
		var d := f.cam.position.distance_to(target)
		f.cam.fov = lerpf(f.cam.fov, clampf(70.0 - d * 0.9, 32.0, 62.0), 1.0 - exp(-delta * 2.0))
		# Straight overhead, looking up would need another "up": just keep the last f.view there.
		if d > 0.5 and Vector2(target.x - f.world.pilot.x, target.z - f.world.pilot.z).length() > 0.3:
			var look_at := target.lerp(f.world.pilot + (target - f.world.pilot) * 0.5, 0.15)
			f.cam.look_at(look_at, Vector3.UP)
