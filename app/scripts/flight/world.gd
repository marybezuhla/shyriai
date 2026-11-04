# SPDX-License-Identifier: GPL-3.0-or-later
# The low-poly world: a field with rows, hills, poplars, white houses, a landing pad.
# Built in code from flat colours, so it is small and runs on cheap phones. No textures.
class_name FlightWorld
extends Node3D

const FLAT := 48.0  # the field around the pad is flat up to this radius
const PALETTES := {
	"day": {
		"sky_top": Color("#A9CDE6"), "sky_horizon": Color("#E4EFF4"),
		"hill_a": Color("#8DB57A"), "hill_b": Color("#9FC28C"),
		"field": Color("#B6D293"), "row": Color("#A2C27E"),
		"poplar": Color("#5F8A52"), "wall": Color("#FFFFFF"), "roof": Color("#6E5A8A"),
		"pad": Color("#FFF0D5"), "pad_ring": Color("#FFC321"), "pad_mark": Color("#463161"),
		"sun": Color("#FFFFFF"), "sun_energy": 0.55, "ambient": Color("#DDE6EC"), "ambient_energy": 0.5,
		"drone": Color("#463161"), "drone_front": Color("#FFC321"),
	},
	"dusk": {
		"sky_top": Color("#35244D"), "sky_horizon": Color("#7A5A8E"),
		"hill_a": Color("#3D2E57"), "hill_b": Color("#46355F"),
		"field": Color("#3E3358"), "row": Color("#4A3D66"),
		"poplar": Color("#2E2345"), "wall": Color("#E9DCC3"), "roof": Color("#7A6596"),
		"pad": Color("#FFF0D5"), "pad_ring": Color("#FFC321"), "pad_mark": Color("#463161"),
		"sun": Color("#FFC98A"), "sun_energy": 0.7, "ambient": Color("#B9A6D6"), "ambient_energy": 0.7,
		"drone": Color("#FFF0D5"), "drone_front": Color("#FFC321"),
	},
}

var pal: Dictionary
var pad := Vector3.ZERO
var hold_mark := Vector3(0, 0, -8)
var pilot := Vector3(0, 1.7, 11)
var kitten := Vector3.INF
var sunflowers: Array[Vector3] = []
var obstacles: Array[Dictionary] = []

var _noise := FastNoiseLite.new()
var _sunflower_nodes: Array[Node3D] = []
var _kitten_node: Node3D
var _t := 0.0


func build(look: String, with_mission: bool, seed_ := 7) -> void:
	pal = PALETTES.get(look, PALETTES["day"])
	_noise.seed = seed_
	_noise.frequency = 0.012
	_environment()
	_terrain()
	_field()
	_pad()
	_poplars()
	var houses := [Vector3(-24, 0, -30), Vector3(16, 0, -36), Vector3(32, 0, -14), Vector3(-34, 0, -6)]
	for h in houses:
		_house(h, atan2(h.x, h.z) + PI)  # front door towards the pad
	_decor_sunflowers(Vector3(-12, 0, -18))
	if with_mission:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_
		var home: Vector3 = houses[rng.randi_range(0, houses.size() - 1)]
		kitten = home + Vector3(0, 6.15, 0)
		_kitten(kitten)
		_van(Vector3(4, 0, 2.5))
		for i in 5:
			var t := (i + 1) / 6.0
			var p := pad.lerp(kitten, t)
			p.y = 2.5 + 1.5 * sin(t * PI)
			p.x += 3.0 * sin(i * 1.7)
			sunflowers.append(p)
			_sunflower_nodes.append(_sunflower(p))


## Ground height at (x, z): flat around the pad, rolling hills further out.
func height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	if r <= FLAT:
		return 0.0
	var ramp := smoothstep(FLAT, FLAT + 45.0, r)
	return ramp * (6.0 + 9.0 * (_noise.get_noise_2d(x, z) + 0.6))


func take_sunflower(i: int) -> void:
	var n := _sunflower_nodes[i]
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 1.6, 0.12)
	tw.tween_property(n, "scale", Vector3.ZERO, 0.2)


func kitten_found() -> void:
	if _kitten_node:
		var tw := create_tween()
		tw.tween_property(_kitten_node, "position:y", _kitten_node.position.y + 0.6, 0.18)
		tw.tween_property(_kitten_node, "position:y", _kitten_node.position.y, 0.25)


func _process(delta: float) -> void:
	_t += delta
	for n in _sunflower_nodes:
		n.rotation.y = _t * 1.5


# --- Building blocks --------------------------------------------------------

func _mat(c: Color, vertex := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if vertex:
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.albedo_color = Color.WHITE
	return m


func _mesh(mesh: Mesh, c: Color, at: Vector3, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = at
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = pal["sky_top"]
	sky_mat.sky_horizon_color = pal["sky_horizon"]
	sky_mat.ground_horizon_color = pal["sky_horizon"]
	sky_mat.ground_bottom_color = pal["hill_a"]
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = pal["ambient"]
	env.ambient_light_energy = pal["ambient_energy"]
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = pal["sky_horizon"]
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = pal["sun"]
	sun.light_energy = pal["sun_energy"]
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.shadow_enabled = false
	add_child(sun)


func _terrain() -> void:
	# A grid of 10 m cells; every triangle gets its own colour, so the hills look faceted.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := 50
	var cell := 10.0
	var half := n * cell / 2.0
	for i in n:
		for j in n:
			var x0 := -half + i * cell
			var z0 := -half + j * cell
			var a := Vector3(x0, 0, z0)
			var b := Vector3(x0 + cell, 0, z0)
			var c := Vector3(x0, 0, z0 + cell)
			var d := Vector3(x0 + cell, 0, z0 + cell)
			a.y = height(a.x, a.z)
			b.y = height(b.x, b.z)
			c.y = height(c.x, c.z)
			d.y = height(d.x, d.z)
			_tri(st, a, b, c, i * 7 + j * 3)
			_tri(st, b, d, c, i * 5 + j * 11 + 1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(Color.WHITE, true)
	mi.position.y = -0.02
	add_child(mi)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, k: int) -> void:
	var col: Color = pal["hill_a"] if k % 3 else pal["hill_b"]
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _field() -> void:
	# Rows of the field as long strips, alternating two greens.
	var size := FLAT * 1.6
	var rows := 24
	var w := size / rows
	for i in rows:
		var c: Color = pal["field"] if i % 2 else pal["row"]
		var strip := PlaneMesh.new()
		strip.size = Vector2(w, size)
		_mesh(strip, c, Vector3(-size / 2.0 + w * (i + 0.5), 0.0, 0.0))


func _pad() -> void:
	var ring := CylinderMesh.new()
	ring.top_radius = 1.6
	ring.bottom_radius = 1.6
	ring.height = 0.04
	ring.radial_segments = 32
	_mesh(ring, pal["pad_ring"], pad + Vector3(0, 0.02, 0))
	var disc := CylinderMesh.new()
	disc.top_radius = 1.35
	disc.bottom_radius = 1.35
	disc.height = 0.05
	disc.radial_segments = 32
	_mesh(disc, pal["pad"], pad + Vector3(0, 0.03, 0))
	var dot := CylinderMesh.new()
	dot.top_radius = 0.25
	dot.bottom_radius = 0.25
	dot.height = 0.06
	dot.radial_segments = 16
	_mesh(dot, pal["pad_mark"], pad + Vector3(0, 0.035, 0))


func _poplars() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.3
	cone.height = 11.0
	cone.radial_segments = 6
	cone.rings = 1
	var spots: Array[Vector3] = []
	for i in 9:
		spots.append(Vector3(-40 + i * 4.5, 0, -46))
	for i in 6:
		spots.append(Vector3(44, 0, -30 + i * 6.0))
	for i in 5:
		spots.append(Vector3(-46, 0, 8 + i * 5.0))
	for s in spots:
		_mesh(cone, pal["poplar"], s + Vector3(0, 5.5, 0))
		obstacles.append({"cyl": Vector2(s.x, s.z), "r": 1.2, "h": 11.0, "y": 0.0})


func _house(at: Vector3, rot: float) -> void:
	var walls := _box(Vector3(6, 3.5, 5))
	_mesh(walls, pal["wall"], at + Vector3(0, 1.75, 0), rot)
	var roof := PrismMesh.new()
	roof.size = Vector3(5.6, 2.5, 6.8)
	var r := _mesh(roof, pal["roof"], at + Vector3(0, 3.5 + 1.25, 0), rot)
	r.rotation.y = rot + PI / 2.0
	# A door and a window, quietly.
	var front := Vector3(sin(rot), 0, cos(rot))
	_mesh(_box(Vector3(1.0, 1.9, 0.08)), pal["roof"].darkened(0.2), at + front * 2.52 + Vector3(0, 0.95, 0) + front.cross(Vector3.UP) * 1.4, rot)
	_mesh(_box(Vector3(1.2, 1.0, 0.08)), pal["sky_top"], at + front * 2.52 + Vector3(0, 2.0, 0) - front.cross(Vector3.UP) * 1.2, rot)
	# Collision: the walls, and a narrower box for the roof.
	var reach := 3.4
	obstacles.append({"box": AABB(at + Vector3(-reach, 0, -reach), Vector3(reach * 2, 3.5, reach * 2))})
	obstacles.append({"box": AABB(at + Vector3(-1.6, 3.5, -1.6), Vector3(3.2, 2.5, 3.2))})


func _decor_sunflowers(at: Vector3) -> void:
	var stem := _box(Vector3(0.06, 1.4, 0.06))
	var head := CylinderMesh.new()
	head.top_radius = 0.28
	head.bottom_radius = 0.28
	head.height = 0.06
	head.radial_segments = 8
	for i in 24:
		var p := at + Vector3((i % 6) * 1.1, 0, (i / 6) * 1.1)
		_mesh(stem, pal["poplar"], p + Vector3(0, 0.7, 0))
		var h := _mesh(head, Color("#FFC321"), p + Vector3(0, 1.45, 0.05))
		h.rotation.x = PI / 2.0 - 0.3


func _sunflower(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	var petals := CylinderMesh.new()
	petals.top_radius = 0.5
	petals.bottom_radius = 0.5
	petals.height = 0.05
	petals.radial_segments = 12
	var core := CylinderMesh.new()
	core.top_radius = 0.22
	core.bottom_radius = 0.22
	core.height = 0.08
	core.radial_segments = 12
	for part in [[petals, Color("#FFC321")], [core, Color("#6B4A2E")]]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		var m := _mat(part[1])
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.rotation.x = PI / 2.0
		n.add_child(mi)
	return n


func _kitten(at: Vector3) -> void:
	_kitten_node = Node3D.new()
	_kitten_node.position = at
	add_child(_kitten_node)
	var ginger := _mat(Color("#E39B4A"))
	var parts := [
		[SphereMesh.new(), Vector3(0, 0.22, 0), Vector3(0.6, 0.4, 0.4)],
		[SphereMesh.new(), Vector3(0.32, 0.45, 0), Vector3(0.32, 0.3, 0.3)],
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.mesh.radial_segments = 8
		mi.mesh.rings = 4
		mi.material_override = ginger
		mi.position = part[1]
		mi.scale = part[2]
		_kitten_node.add_child(mi)
	for z in [-0.08, 0.08]:
		var ear := PrismMesh.new()
		ear.size = Vector3(0.1, 0.14, 0.06)
		var e := MeshInstance3D.new()
		e.mesh = ear
		e.material_override = ginger
		e.position = Vector3(0.34, 0.64, z)
		_kitten_node.add_child(e)
	var tail := _box(Vector3(0.06, 0.4, 0.06))
	var t := MeshInstance3D.new()
	t.mesh = tail
	t.material_override = ginger
	t.position = Vector3(-0.35, 0.42, 0)
	t.rotation.z = 0.5
	_kitten_node.add_child(t)


func _van(at: Vector3) -> void:
	_mesh(_box(Vector3(2.0, 1.6, 4.2)), Color("#FFFFFF"), at + Vector3(0, 0.95, 0))
	_mesh(_box(Vector3(2.02, 0.3, 4.22)), Color("#FFC321"), at + Vector3(0, 0.9, 0))
	for x in [-0.9, 0.9]:
		for z in [-1.3, 1.3]:
			var w := CylinderMesh.new()
			w.top_radius = 0.35
			w.bottom_radius = 0.35
			w.height = 0.2
			w.radial_segments = 10
			var wi := _mesh(w, Color("#39254F"), at + Vector3(x, 0.35, z))
			wi.rotation.z = PI / 2.0
	obstacles.append({"box": AABB(at + Vector3(-1.0, 0, -2.1), Vector3(2.0, 1.8, 4.2))})
