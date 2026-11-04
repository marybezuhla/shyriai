# SPDX-License-Identifier: GPL-3.0-or-later
# What the drone looks like: a small quadcopter with a gold nose, spinning rotors and a soft shadow.
# The gold front matters: it is how the pilot knows where the nose points.
class_name DroneView
extends Node3D

const SCALE := 1.6  # drawn a little larger than life, so it is easy to see from the ground

var _body := Node3D.new()
var _rotors: Array[MeshInstance3D] = []
var _shadow := MeshInstance3D.new()
var _spin := 0.0


func build(body: Color, front: Color) -> void:
	add_child(_body)
	_body.scale = Vector3.ONE * SCALE
	var m_body := _mat(body)
	var m_front := _mat(front)
	_part(_box(Vector3(0.16, 0.06, 0.22)), m_body, Vector3(0, 0.06, 0))
	# The stripe and the camera are at the front (-Z).
	_part(_box(Vector3(0.165, 0.018, 0.08)), m_front, Vector3(0, 0.07, -0.07))
	var cam := SphereMesh.new()
	cam.radius = 0.035
	cam.height = 0.07
	cam.radial_segments = 8
	cam.rings = 4
	_part(cam, _mat(Color("#39254F")), Vector3(0, 0.03, -0.12))
	for i in 4:
		var a := PI / 4.0 + i * PI / 2.0
		var dir := Vector3(sin(a), 0, -cos(a))
		var is_front := dir.z < 0.0
		var arm := _part(_box(Vector3(0.025, 0.02, 0.2)), m_front if is_front else m_body, dir * 0.1 + Vector3(0, 0.06, 0))
		arm.rotation.y = -a
		var motor := CylinderMesh.new()
		motor.top_radius = 0.025
		motor.bottom_radius = 0.025
		motor.height = 0.04
		motor.radial_segments = 8
		_part(motor, m_front if is_front else m_body, dir * 0.19 + Vector3(0, 0.08, 0))
		var disc := CylinderMesh.new()
		disc.top_radius = 0.1
		disc.bottom_radius = 0.1
		disc.height = 0.004
		disc.radial_segments = 16
		var dm := _mat(body)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color.a = 0.35
		_rotors.append(_part(disc, dm, dir * 0.19 + Vector3(0, 0.105, 0)))
	_body.position.y = 0.0

	# The shadow is a soft round blot on the ground, so the pilot can judge height.
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	_shadow.mesh = plane
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.45))
	g.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = tex
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = sm
	_shadow.top_level = true
	add_child(_shadow)


## Hidden when the camera sits on the drone itself.
func body_visible(on: bool) -> void:
	_body.visible = on


func sync(sim: DroneSim, delta: float) -> void:
	position = sim.pos
	basis = sim.orientation()
	var running := not sim.on_ground and not sim.crashed
	_spin += delta * (40.0 if running else 0.0)
	for r in _rotors:
		r.visible = running
		r.rotation.y = _spin
	var g := sim.ground.call(sim.pos.x, sim.pos.z) as float
	var alt := sim.pos.y - g
	_shadow.global_position = Vector3(sim.pos.x, g + 0.05, sim.pos.z)
	var s := 0.9 + alt * 0.08
	_shadow.scale = Vector3(s, 1, s)
	_shadow.transparency = clampf(alt / 25.0, 0.0, 0.85)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _part(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)
	return mi
