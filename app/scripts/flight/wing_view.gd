# SPDX-License-Identifier: GPL-3.0-or-later
# What the trainer plane looks like: a slim body, a high wing with gold tips, a tail and a spinning
# propeller disc. Built from boxes in the app's colours, about one and a half times a real foam
# trainer, so it reads from the pilot's place far below.
class_name WingView
extends Node3D

const SCALE := 1.5

var _body := Node3D.new()
var _prop: MeshInstance3D
var _shadow := MeshInstance3D.new()


func build(body: Color, front: Color) -> void:
	add_child(_body)
	_body.scale = Vector3.ONE * SCALE
	var m_body := _mat(body)
	var m_wing := _mat(Pal.CREAM)
	var m_front := _mat(front)
	_part(_box(Vector3(0.16, 0.16, 1.1)), m_body, Vector3.ZERO)
	var nose := SphereMesh.new()
	nose.radius = 0.09
	nose.height = 0.18
	_part(nose, m_body, Vector3(0, 0, -0.56))
	# The high wing, with gold tips so its bank shows from far away.
	_part(_box(Vector3(1.6, 0.04, 0.26)), m_wing, Vector3(0, 0.11, -0.12))
	_part(_box(Vector3(0.12, 0.045, 0.26)), m_front, Vector3(0.86, 0.11, -0.12))
	_part(_box(Vector3(0.12, 0.045, 0.26)), m_front, Vector3(-0.86, 0.11, -0.12))
	_part(_box(Vector3(0.56, 0.03, 0.16)), m_wing, Vector3(0, 0.02, 0.5))
	_part(_box(Vector3(0.03, 0.22, 0.18)), m_front, Vector3(0, 0.13, 0.5))
	var disc := CylinderMesh.new()
	disc.top_radius = 0.17
	disc.bottom_radius = 0.17
	disc.height = 0.01
	var m_prop := _mat(Color(Color.WHITE, 0.35))
	m_prop.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_prop = _part(disc, m_prop, Vector3(0, 0, -0.66))
	_prop.rotation.x = PI / 2.0
	# A soft shadow straight below, so height over the ground can be judged.
	var sh := CylinderMesh.new()
	sh.top_radius = 0.9
	sh.bottom_radius = 0.9
	sh.height = 0.01
	_shadow.mesh = sh
	var m_sh := _mat(Color(0, 0, 0, 0.25))
	m_sh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow.material_override = m_sh
	_shadow.top_level = true
	add_child(_shadow)


func body_visible(on: bool) -> void:
	_body.visible = on


func sync(sim: DroneSim, _delta: float) -> void:
	position = sim.pos + Vector3(0, 0.2 * SCALE, 0) * float(sim.on_ground)
	basis = sim.orientation()
	_prop.visible = not sim.crashed and (sim as WingSim).throttle01 > 0.02
	var g := sim.ground.call(sim.pos.x, sim.pos.z) as float
	var alt := sim.pos.y - g
	_shadow.global_position = Vector3(sim.pos.x, g + 0.05, sim.pos.z)
	_shadow.scale = Vector3.ONE * (1.0 + alt * 0.04)
	_shadow.transparency = clampf(alt / 40.0, 0.0, 0.85)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
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
