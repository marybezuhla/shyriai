# SPDX-License-Identifier: GPL-3.0-or-later
# What the ground robot looks like: a low body on two tracks, a camera mast, a gold front edge,
# and a load on top when it carries one.
class_name UgvView
extends Node3D

var _body := Node3D.new()
var _load := Node3D.new()
var _treads: Array[MeshInstance3D] = []
var _roll := 0.0


func build(body: Color, front: Color, load_kind := "") -> void:
	add_child(_body)
	var m_body := _mat(body)
	var m_front := _mat(front)
	var m_track := _mat(Color("#2A1D3B"))
	_part(_box(Vector3(1.0, 0.35, 1.5)), m_body, Vector3(0, 0.42, 0))
	_part(_box(Vector3(1.02, 0.08, 0.2)), m_front, Vector3(0, 0.5, -0.72))
	for sx in [-0.62, 0.62]:
		_treads.append(_part(_box(Vector3(0.28, 0.4, 1.75)), m_track, Vector3(sx, 0.22, 0)))
		for z in [-0.6, 0.0, 0.6]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.17
			wheel.bottom_radius = 0.17
			wheel.height = 0.3
			wheel.radial_segments = 10
			var w := _part(wheel, m_body, Vector3(sx * 1.02, 0.2, z))
			w.rotation.z = PI / 2.0
	# Camera mast at the front.
	_part(_box(Vector3(0.08, 0.5, 0.08)), m_body, Vector3(0, 0.85, -0.5))
	_part(_box(Vector3(0.22, 0.14, 0.18)), _mat(Color("#39254F")), Vector3(0, 1.12, -0.52))
	_body.add_child(_load)
	set_load(load_kind)


## "", "cargo" (boxes of water and medicine), "stretcher", "kitten" or "parcel".
func set_load(kind: String) -> void:
	for c in _load.get_children():
		c.queue_free()
	match kind:
		"cargo":
			_load_part(_box(Vector3(0.45, 0.35, 0.5)), Color("#5B9BD5"), Vector3(-0.22, 0.77, 0.25))
			_load_part(_box(Vector3(0.4, 0.3, 0.45)), Color("#E9DCC3"), Vector3(0.24, 0.75, 0.3))
		"stretcher":
			_load_part(_box(Vector3(0.75, 0.06, 1.6)), Color("#E9DCC3"), Vector3(0, 0.64, 0.05))
			_load_part(_box(Vector3(0.42, 0.2, 0.8)), Color("#5B7D4E"), Vector3(0, 0.77, 0.25))
			_load_part(_box(Vector3(0.38, 0.18, 0.6)), Color("#39254F"), Vector3(0, 0.76, -0.4))
		"kitten":
			_load_part(_box(Vector3(0.55, 0.3, 0.45)), Color("#E9DCC3"), Vector3(0, 0.75, 0.2))
			var head := SphereMesh.new()
			head.radius = 0.12
			head.height = 0.24
			head.radial_segments = 8
			head.rings = 4
			_load_part(head, Color("#E39B4A"), Vector3(0, 0.98, 0.2))
		"parcel":
			_load_part(_box(Vector3(0.6, 0.4, 0.5)), Color("#C9A77E"), Vector3(0, 0.8, 0.2))
			_load_part(_box(Vector3(0.62, 0.06, 0.08)), Color("#FFC321"), Vector3(0, 1.0, 0.2))


func body_visible(on: bool) -> void:
	_body.visible = on


func sync(sim: DroneSim, delta: float) -> void:
	position = sim.pos
	basis = sim.orientation()
	# The treads shimmer a little as they roll.
	_roll += sim.vel.length() * delta
	for t in _treads:
		t.scale.y = 1.0 + 0.03 * sin(_roll * 12.0)


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


func _load_part(mesh: Mesh, c: Color, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = at
	_load.add_child(mi)
