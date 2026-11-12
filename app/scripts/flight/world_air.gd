# SPDX-License-Identifier: GPL-3.0-or-later
# What the plane's lessons and missions add to the world: storks to follow, clouds, a red tarp beside
# a lost person, a kite caught in a tree. Kept apart from world.gd, which is the drones' world.
class_name AirProps
extends RefCounted


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


static func _part(parent: Node3D, mesh: Mesh, c: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## White storks with black wing tips, a little larger than life so they show from the plane.
static func add_storks(world: Node3D, n: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in n:
		var s := Node3D.new()
		s.position = Vector3(6 + i * 3.0, 28, -40)
		world.add_child(s)
		_part(s, _box(Vector3(0.35, 0.35, 1.3)), Color.WHITE, Vector3.ZERO)
		_part(s, _box(Vector3(0.1, 0.1, 0.5)), Color("#E5703B"), Vector3(0, 0, -0.85))  # beak
		for side in [-1.0, 1.0]:
			var w := Node3D.new()
			w.name = "wing_l" if side < 0.0 else "wing_r"
			s.add_child(w)
			_part(w, _box(Vector3(1.1, 0.06, 0.5)), Color.WHITE, Vector3(side * 0.7, 0, 0))
			_part(w, _box(Vector3(0.5, 0.07, 0.5)), Pal.INK, Vector3(side * 1.4, 0, 0))
		out.append(s)
	return out


## Wing beats: slow and wide, like a stork's.
static func flap(stork: Node3D, t: float) -> void:
	var a := sin(t * 3.0) * 0.45
	stork.get_node("wing_l").rotation.z = a
	stork.get_node("wing_r").rotation.z = -a


## A few white puffs around a ring, so it reads as a cloud.
static func add_cloud(world: Node3D, center: Vector3, radius: float) -> void:
	var puff := SphereMesh.new()
	puff.radius = 2.2
	puff.height = 3.2
	puff.radial_segments = 10
	puff.rings = 5
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var at := center + Vector3(cos(a) * (radius + 2.0), sin(a) * (radius + 1.5), 0)
		var mi := _part(world, puff, Color("#FBFBFF"), at)
		mi.scale = Vector3.ONE * (0.8 + 0.25 * float(i % 3))


## A bright red tarp on the ground: what a lost person spreads out to be seen from the air.
static func add_tarp(world: FlightWorld, at: Vector3) -> void:
	var y := world.height(at.x, at.z)
	_part(world, _box(Vector3(4.0, 0.05, 4.0)), Color("#D9473B"), Vector3(at.x + 2.5, y + 0.03, at.z))
	world.add_person(at)


## A lone tree with a kite caught in its top. Returns where the kite is.
static func add_kite_tree(world: FlightWorld, at: Vector3) -> Vector3:
	var y := world.height(at.x, at.z)
	var crown := SphereMesh.new()
	crown.radius = 3.5
	crown.height = 6.0
	crown.radial_segments = 10
	crown.rings = 5
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35
	trunk.bottom_radius = 0.45
	trunk.height = 4.0
	_part(world, trunk, Color("#6B4A2E"), Vector3(at.x, y + 2.0, at.z))
	_part(world, crown, world.pal["poplar"], Vector3(at.x, y + 6.5, at.z))
	world.obstacles.append({"cyl": Vector2(at.x, at.z), "r": 3.5, "h": 9.5, "y": y})
	var kite := Node3D.new()
	kite.position = Vector3(at.x + 1.0, y + 10.0, at.z)
	world.add_child(kite)
	var diamond := _part(kite, _box(Vector3(1.4, 1.4, 0.06)), Pal.TOY["pink"], Vector3.ZERO)
	diamond.rotation.z = PI / 4.0
	_part(kite, _box(Vector3(0.05, 2.5, 0.05)), Pal.TOY["gold"], Vector3(0, -1.8, 0))  # tail
	return kite.position
