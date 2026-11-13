# SPDX-License-Identifier: GPL-3.0-or-later
# What the flight draws over the 3D view: the gold diamond on the next target, or an arrow at the
# edge of the screen pointing to it, a ring on the ground, and a thin circle round a far-away drone.
class_name FlightMarks
extends RefCounted


static func draw(f: Flight) -> void:
	var rect := f._marks.get_rect()
	if f.task.marker != Vector3.INF:
		var behind := f.cam.is_position_behind(f.task.marker)
		var p := f.cam.unproject_position(f.task.marker)
		# Keep the arrow clear of the sticks along the bottom: under a thumb it cannot be seen.
		var inner := rect.grow_individual(-40, -40, -40, -maxf(40.0, f.stick_band()))
		if not behind and inner.has_point(p):
			# Grows and pulses when a child needs help finding it.
			var r := 9.0
			if f.kids_help():
				r = 13.0 + 3.0 * sin(Time.get_ticks_msec() / 160.0)
			_diamond(f, p, r)
		else:
			# An arrow at the edge of the screen, pointing towards the target.
			var c := inner.get_center()
			var dir := (p - c)
			if behind:
				dir = -dir
			if dir.length() < 1.0:
				dir = Vector2.UP
			dir = dir.normalized()
			var t := minf(absf((inner.size.x / 2.0) / dir.x) if dir.x != 0.0 else INF, absf((inner.size.y / 2.0) / dir.y) if dir.y != 0.0 else INF)
			var tip := c + dir * t
			var side := Vector2(-dir.y, dir.x)
			var col := Pal.c("accent")
			var arrow := PackedVector2Array([tip + dir * 12, tip - dir * 6 + side * 11, tip - dir * 6 - side * 11])
			f._marks.draw_colored_polygon(arrow, col)
			# A dark edge keeps the gold arrow visible against a bright sky.
			arrow.append(arrow[0])
			f._marks.draw_polyline(arrow, Pal.INK, 2.0, true)
		if f.task.ring > 0.0:
			_ground_ring(f, f.task.marker, f.task.ring)
	# A thin ring round the drone when it is far and tiny.
	if f.view == "pilot" and not f.cam.is_position_behind(f.sim.pos):
		var d := f.cam.position.distance_to(f.sim.pos)
		if d > 14.0:
			var q := f.cam.unproject_position(f.sim.pos + Vector3(0, 0.1, 0))
			var col2 := Pal.c("text") if f.look == "dusk" else Pal.VIOLET
			col2.a = 0.7
			f._marks.draw_arc(q, 16.0, 0, TAU, 32, col2, 2.0, true)


static func _diamond(f: Flight, p: Vector2, r: float) -> void:
	var col := Pal.c("accent")
	f._marks.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)
	f._marks.draw_polyline(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)]), Pal.INK, 2.0, true)


static func _ground_ring(f: Flight, center: Vector3, radius: float) -> void:
	var pts := PackedVector2Array()
	var g := f.sim.ground.call(center.x, center.z) as float
	for i in 49:
		var a := i * TAU / 48.0
		var w := Vector3(center.x + cos(a) * radius, g + 0.05, center.z + sin(a) * radius)
		if f.cam.is_position_behind(w):
			return
		pts.append(f.cam.unproject_position(w))
	var col := Pal.c("accent")
	f._marks.draw_polyline(pts, Pal.INK, 5.0, true)
	f._marks.draw_polyline(pts, col, 3.0, true)
