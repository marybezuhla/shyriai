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
		"road": Color("#E2D3AE"), "mud": Color("#8A6B4E"), "barrier": Color("#D8CBB6"),
	},
	"dusk": {
		"sky_top": Color("#35244D"), "sky_horizon": Color("#7A5A8E"),
		"hill_a": Color("#3D2E57"), "hill_b": Color("#46355F"),
		"field": Color("#3E3358"), "row": Color("#4A3D66"),
		"poplar": Color("#2E2345"), "wall": Color("#E9DCC3"), "roof": Color("#7A6596"),
		"pad": Color("#FFF0D5"), "pad_ring": Color("#FFC321"), "pad_mark": Color("#463161"),
		"sun": Color("#FFC98A"), "sun_energy": 0.7, "ambient": Color("#B9A6D6"), "ambient_energy": 0.7,
		"drone": Color("#FFF0D5"), "drone_front": Color("#FFC321"),
		"road": Color("#6A5884"), "mud": Color("#3B2B3E"), "barrier": Color("#8E7BA8"),
	},
}

var pal: Dictionary
var pad := Vector3.ZERO
var hold_mark := Vector3(0, 0, -8)
var pilot := Vector3(0, 1.7, 11)
var kitten := Vector3.INF
var sunflowers: Array[Vector3] = []
var obstacles: Array[Dictionary] = []
## Every house: {"pos": Vector3, "rot": float}. The roof ridge is 6 m above the ground.
var houses: Array[Dictionary] = []
const HOUSE_SPOTS := [
	Vector3(-24, 0, -30), Vector3(16, 0, -36), Vector3(32, 0, -14),
	Vector3(-34, 0, -6), Vector3(26, 0, 24), Vector3(-20, 0, 30),
]

var _noise := FastNoiseLite.new()
var _sunflower_nodes: Array[Node3D] = []
var _kitten_node: Node3D
var _beacon: MeshInstance3D
var _beacon_pole: MeshInstance3D
var _t := 0.0


func build(look: String, seed_ := 7) -> void:
	pal = PALETTES.get(look, PALETTES["day"])
	_noise.seed = seed_
	_noise.frequency = 0.012
	_environment()
	_terrain()
	_field()
	_pad()
	_poplars()
	for h in HOUSE_SPOTS:
		_house(h, atan2(h.x, h.z) + PI)  # front door towards the pad
	_decor_sunflowers(Vector3(-12, 0, -18))
	_make_beacon()


# --- Things a lesson or mission adds ------------------------------------------

func add_kitten(house: int) -> void:
	kitten = houses[house]["pos"] + Vector3(0, 6.15, 0)
	_kitten(kitten)


## A kitten sitting on the ground (for the ground robot to fetch).
func add_kitten_at(at: Vector3) -> Node3D:
	_kitten(Vector3(at.x, height(at.x, at.z), at.z))
	return _kitten_node


func add_van(at: Vector3) -> void:
	_van(at)


func add_sunflowers(points: Array[Vector3]) -> void:
	for p in points:
		sunflowers.append(p)
		_sunflower_nodes.append(_sunflower(p))


## A storm-damaged roof: a dark hole in one slope and fallen tiles on the ground.
func damage_roof(house: int) -> void:
	var h: Dictionary = houses[house]
	var at: Vector3 = h["pos"]
	var rot: float = h["rot"]
	var front := Vector3(sin(rot), 0, cos(rot))
	var side := front.cross(Vector3.UP)
	var hole := _mesh(_box(Vector3(2.2, 0.12, 1.6)), Color("#2A1D3B"), at + front * 1.3 + Vector3(0, 4.95, 0) + side * 0.8, rot)
	hole.rotation = Vector3(0, rot, 0)
	hole.rotate_object_local(Vector3.RIGHT, 0.73)  # lies on the front slope
	var tile := _box(Vector3(0.5, 0.08, 0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = house * 31 + 5
	for i in 7:
		var off := front * rng.randf_range(3.2, 5.0) + side * rng.randf_range(-2.5, 2.5)
		var t := _mesh(tile, pal["roof"], at + off + Vector3(0, 0.04, 0), rng.randf() * TAU)
		t.rotation.z = rng.randf_range(-0.3, 0.3)


## A person sitting in the field, in a red jacket, for the search mission.
func add_person(at: Vector3) -> void:
	var n := Node3D.new()
	n.position = Vector3(at.x, height(at.x, at.z), at.z)
	add_child(n)
	var jacket := _mat(Color("#D9473B"))
	var skin := _mat(Color("#E7B992"))
	var dark := _mat(Color("#39254F"))
	var parts := [
		[_box(Vector3(0.45, 0.6, 0.3)), jacket, Vector3(0, 0.55, 0)],
		[_box(Vector3(0.4, 0.2, 0.75)), dark, Vector3(0, 0.15, 0.25)],
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[1]
		mi.position = part[2]
		n.add_child(mi)
	var head := SphereMesh.new()
	head.radius = 0.14
	head.height = 0.28
	head.radial_segments = 8
	head.rings = 4
	var hm := MeshInstance3D.new()
	hm.mesh = head
	hm.material_override = skin
	hm.position = Vector3(0, 1.0, 0)
	n.add_child(hm)


## A racing gate: a square frame the drone flies through. Returns its index in `gates`.
## The opening is `w` wide and `h` tall around `center`; `normal` is the way to fly through.
var gates: Array[Dictionary] = []
var _gate_mats: Array[StandardMaterial3D] = []


func add_gate(center: Vector3, normal: Vector3, w := 3.2, h := 2.6) -> int:
	var n := Vector3(normal.x, 0, normal.z).normalized()
	var side := n.cross(Vector3.UP).normalized()
	var g := height(center.x, center.z)
	var c := Vector3(center.x, g + center.y, center.z)
	var m := _mat(pal["pad"])
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var t := 0.18
	var rot := atan2(n.x, n.z)
	var top := c.y + h / 2.0 + t / 2.0
	var bottom := c.y - h / 2.0 - t / 2.0
	var parts := [
		[Vector3(t, top - g + t / 2.0, t), Vector3(c.x, g + (top - g + t / 2.0) / 2.0, c.z) + side * (w / 2.0 + t / 2.0)],
		[Vector3(t, top - g + t / 2.0, t), Vector3(c.x, g + (top - g + t / 2.0) / 2.0, c.z) - side * (w / 2.0 + t / 2.0)],
		[Vector3(w + 2.0 * t, t, t), Vector3(c.x, top, c.z)],
		[Vector3(w + 2.0 * t, t, t), Vector3(c.x, bottom, c.z)],
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = _box(part[0])
		mi.material_override = m
		mi.position = part[1]
		mi.rotation.y = rot
		add_child(mi)
	# Collisions: the two posts and the two bars.
	for sgn in [1.0, -1.0]:
		var post: Vector3 = c + side * sgn * (w / 2.0 + t / 2.0)
		obstacles.append({"cyl": Vector2(post.x, post.z), "r": t, "h": top + t / 2.0 - g, "y": g})
	# The bars are true bars at any angle (a box aligned to the world would stick out of a turned gate).
	for y in [top, bottom]:
		var a := Vector3(c.x, y, c.z) - side * (w / 2.0 + t)
		var b := Vector3(c.x, y, c.z) + side * (w / 2.0 + t)
		obstacles.append({"seg": [a, b], "r": t / 2.0})
	gates.append({"c": c, "n": n, "side": side, "w": w, "h": h})
	_gate_mats.append(m)
	return gates.size() - 1


## The gate to fly through next is gold; the others are cream.
func highlight_gate(i: int) -> void:
	for k in _gate_mats.size():
		_gate_mats[k].albedo_color = pal["pad_ring"] if k == i else pal["pad"]


## A hoop for the kids: a ring in the air, no collisions.
func add_hoop(center: Vector3, normal: Vector3, color: Color, radius := 1.6) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.22
	torus.rings = 32
	torus.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	var m := _mat(color)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	var n := Vector3(normal.x, 0, normal.z).normalized()
	mi.position = Vector3(center.x, height(center.x, center.z) + center.y, center.z)
	# A torus lies flat; stand it up facing the way to fly.
	mi.basis = Basis(Vector3.UP, atan2(n.x, n.z)) * Basis(Vector3.RIGHT, PI / 2.0)
	add_child(mi)
	_hoops.append(mi)


var _hoops: Array[MeshInstance3D] = []


func hoop_done(i: int) -> void:
	if i < _hoops.size():
		var tw := create_tween()
		tw.tween_property(_hoops[i], "scale", Vector3.ONE * 1.25, 0.12)
		tw.tween_property(_hoops[i], "scale", Vector3.ONE * 0.001, 0.25)
		tw.tween_callback(_hoops[i].hide)


## A thin pole for slalom and figure eights.
func add_pole(at: Vector3, h := 8.0) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.25
	cyl.height = h
	cyl.radial_segments = 10
	var g := height(at.x, at.z)
	_mesh(cyl, pal["pad_ring"], Vector3(at.x, g + h / 2.0, at.z))
	obstacles.append({"cyl": Vector2(at.x, at.z), "r": 0.25, "h": h, "y": g})


var _balloons: Array[MeshInstance3D] = []


func add_balloon(at: Vector3, color: Color) -> void:
	var sph := SphereMesh.new()
	sph.radius = 0.55
	sph.height = 1.3
	sph.radial_segments = 16
	sph.rings = 8
	var mi := _mesh(sph, color, Vector3(at.x, height(at.x, at.z) + at.y, at.z))
	_balloons.append(mi)


func pop_balloon(i: int) -> void:
	if i < _balloons.size():
		var tw := create_tween()
		tw.tween_property(_balloons[i], "scale", Vector3.ONE * 1.5, 0.08)
		tw.tween_property(_balloons[i], "scale", Vector3.ZERO, 0.1)


## A round target board with three rings, standing upright and facing `normal`.
func add_target(center: Vector3, normal: Vector3) -> void:
	var n := Vector3(normal.x, 0, normal.z).normalized()
	var c := Vector3(center.x, height(center.x, center.z) + center.y, center.z)
	var colors := [pal["pad"], pal["roof"], pal["pad_ring"]]
	var radii := [2.0, 1.25, 0.5]
	for k in 3:
		var disc := CylinderMesh.new()
		disc.top_radius = radii[k]
		disc.bottom_radius = radii[k]
		disc.height = 0.1 + k * 0.02
		disc.radial_segments = 32
		var mi := MeshInstance3D.new()
		mi.mesh = disc
		var m := _mat(colors[k])
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.position = c
		mi.basis = Basis(Vector3.UP, atan2(n.x, n.z)) * Basis(Vector3.RIGHT, PI / 2.0)
		add_child(mi)
	var stand := _box(Vector3(0.15, c.y - height(c.x, c.z), 0.15))
	_mesh(stand, pal["roof"], Vector3(c.x, (c.y + height(c.x, c.z)) / 2.0, c.z) - n * 0.15)
	var side := n.cross(Vector3.UP)
	var a := c - side * 2.0 - Vector3(0, 2.0, 0) - n * 0.08
	var b := c + side * 2.0 + Vector3(0, 2.0, 0) + n * 0.08
	var lo := Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), b.y, maxf(a.z, b.z))
	obstacles.append({"box": AABB(lo, hi - lo)})


## A round landing target lying on the ground, with three rings.
func add_ground_target(center: Vector3) -> void:
	var colors := [pal["pad"], pal["roof"], pal["pad_ring"]]
	var radii := [2.4, 1.4, 0.6]
	for k in 3:
		var disc := CylinderMesh.new()
		disc.top_radius = radii[k]
		disc.bottom_radius = radii[k]
		disc.height = 0.03 + k * 0.01
		disc.radial_segments = 32
		_mesh(disc, colors[k], Vector3(center.x, height(center.x, center.z) + 0.02 + k * 0.01, center.z))


## A strip of trees: rows across the way. Trunks stand 6 m apart (±0.8 m), so a gap is always at least
## about 2.4 m wide.
## Returns the list of trees, each {"at": Vector3, "r": float, "h": float}.
func add_tree_belt(z_from: float, z_to: float, half_width: float, seed_: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var out := []
	var z := z_from
	var row := 0
	while z > z_to:
		var x := -half_width + (3.0 if row % 2 else 0.0)
		while x <= half_width:
			var r := rng.randf_range(0.9, 1.25)
			var h := rng.randf_range(6.0, 9.0)
			var at := Vector3(x + rng.randf_range(-0.8, 0.8), 0, z + rng.randf_range(-0.8, 0.8))
			var cone := CylinderMesh.new()
			cone.top_radius = 0.05
			cone.bottom_radius = r
			cone.height = h
			cone.radial_segments = 6
			cone.rings = 1
			_mesh(cone, pal["poplar"], at + Vector3(0, h / 2.0, 0))
			obstacles.append({"cyl": Vector2(at.x, at.z), "r": r * 0.8, "h": h, "y": 0.0})
			out.append({"at": at, "r": r, "h": h})
			x += 6.0
		z -= 5.0
		row += 1
	return out


# --- For the ground robot ---------------------------------------------------------

var _hills: Array[Dictionary] = []
## Potholes: x, z = centre, y = radius.
var _dips: Array[Vector3] = []
var _muds: Array[Vector3] = []


## A ramp along Z: up over `up` metres to `top` m high, flat for `flat` m, then down again. Width `w`.
func add_ramp(start_z: float, x: float, w: float, top: float, up: float, flat: float) -> void:
	var h := {"x": x, "z0": start_z, "w": w, "top": top, "up": up, "flat": flat}
	_hills.append(h)
	# Its own mesh, built from the height function, a little above the field.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total := up * 2.0 + flat
	var nx := 6
	var nz := int(total / 0.5)
	for i in nx:
		for j in nz:
			var x0 := x - w / 2.0 + w * i / nx
			var x1 := x - w / 2.0 + w * (i + 1) / nx
			var z0 := start_z - total * j / nz
			var z1 := start_z - total * (j + 1) / nz
			var a := Vector3(x0, height(x0, z0) + 0.02, z0)
			var b := Vector3(x1, height(x1, z0) + 0.02, z0)
			var c := Vector3(x0, height(x0, z1) + 0.02, z1)
			var d := Vector3(x1, height(x1, z1) + 0.02, z1)
			for v in [a, c, b, b, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(pal["hill_b"])
	add_child(mi)


func _hill_height(h: Dictionary, x: float, z: float) -> float:
	if absf(x - h["x"]) > h["w"] / 2.0:
		return 0.0
	var d: float = h["z0"] - z  # distance along the ramp
	var up: float = h["up"]
	var flat: float = h["flat"]
	if d <= 0.0 or d >= up * 2.0 + flat:
		return 0.0
	if d < up:
		return h["top"] * d / up
	if d < up + flat:
		return h["top"]
	return h["top"] * (up * 2.0 + flat - d) / up


func add_mud(center: Vector3, r: float) -> void:
	_muds.append(Vector3(center.x, r, center.z))
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.04
	disc.radial_segments = 20
	_mesh(disc, pal["mud"], Vector3(center.x, height(center.x, center.z) + 0.03, center.z))


## Speed factor of the ground: mud halves it.
func grip(x: float, z: float) -> float:
	for m in _muds:
		if Vector2(x - m.x, z - m.z).length() < m.y:
			return 0.45
	return 1.0


func add_pothole(at: Vector3, r := 0.45) -> void:
	_dips.append(Vector3(at.x, r, at.z))
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.02
	disc.radial_segments = 12
	_mesh(disc, pal["mud"].darkened(0.2), Vector3(at.x, 0.015, at.z))


## A dirt road along points, `w` wide, drawn just above the field.
func add_road(points: Array[Vector3], w: float) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var d := Vector3(b.x - a.x, 0, b.z - a.z)
		var strip := _box(Vector3(w, 0.02, d.length() + w * 0.6))
		var mid := (a + b) / 2.0
		_mesh(strip, pal["road"], Vector3(mid.x, height(mid.x, mid.z) + 0.02, mid.z), atan2(d.x, d.z))


## An axis-aligned wall from `a` to `b` on the ground (one of x or z the same).
func add_wall(a: Vector3, b: Vector3, h := 1.2, t := 0.3) -> void:
	var lo := Vector3(minf(a.x, b.x) - t / 2.0, 0, minf(a.z, b.z) - t / 2.0)
	var hi := Vector3(maxf(a.x, b.x) + t / 2.0, h, maxf(a.z, b.z) + t / 2.0)
	_mesh(_box(hi - lo), pal["barrier"], (lo + hi) / 2.0)
	obstacles.append({"box": AABB(lo, hi - lo)})


func add_barrel(at: Vector3) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 0.9
	cyl.radial_segments = 12
	_mesh(cyl, pal["roof"], Vector3(at.x, height(at.x, at.z) + 0.45, at.z))
	obstacles.append({"cyl": Vector2(at.x, at.z), "r": 0.35, "h": 0.9, "y": height(at.x, at.z)})


## A small round sign on a post, e.g. a paw for the vet.
func add_sign(at: Vector3, color: Color) -> void:
	_mesh(_box(Vector3(0.1, 2.0, 0.1)), pal["barrier"], at + Vector3(0, 1.0, 0))
	var disc := CylinderMesh.new()
	disc.top_radius = 0.45
	disc.bottom_radius = 0.45
	disc.height = 0.06
	disc.radial_segments = 20
	var mi := _mesh(disc, color, at + Vector3(0, 2.2, 0))
	mi.rotation.x = PI / 2.0


## A small low-poly person lying on a stretcher, for the evacuation tasks.
func add_casualty(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(at.x, height(at.x, at.z), at.z)
	add_child(n)
	var parts := [
		[_box(Vector3(0.7, 0.08, 1.9)), pal["barrier"], Vector3(0, 0.2, 0)],
		[_box(Vector3(0.42, 0.22, 0.9)), Color("#5B7D4E"), Vector3(0, 0.35, 0.25)],
		[_box(Vector3(0.38, 0.2, 0.7)), Color("#39254F"), Vector3(0, 0.34, -0.5)],
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = _mat(part[1])
		mi.position = part[2]
		n.add_child(mi)
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	head.radial_segments = 8
	head.rings = 4
	var hm := MeshInstance3D.new()
	hm.mesh = head
	hm.material_override = _mat(Color("#E7B992"))
	hm.position = Vector3(0, 0.4, 0.82)
	n.add_child(hm)
	return n


## A see-through gold sphere at the next target, on a thin pole, so its height and place are clear.
func show_beacon(at: Vector3, radius: float) -> void:
	var on := radius > 0.0 and at != Vector3.INF
	_beacon.visible = on
	_beacon_pole.visible = on
	if not on:
		return
	_beacon.position = at
	_beacon.scale = Vector3.ONE * radius
	var g := height(at.x, at.z)
	var h := maxf(at.y - g - radius, 0.0)
	_beacon_pole.position = Vector3(at.x, g + h / 2.0, at.z)
	_beacon_pole.scale = Vector3(1, maxf(h, 0.01), 1)


func _make_beacon() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.765, 0.13, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon = MeshInstance3D.new()
	_beacon.mesh = sphere
	_beacon.material_override = m
	_beacon.visible = false
	add_child(_beacon)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.03
	pole.height = 1.0
	pole.radial_segments = 6
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(1.0, 0.765, 0.13, 0.7)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon_pole = MeshInstance3D.new()
	_beacon_pole.mesh = pole
	_beacon_pole.material_override = pm
	_beacon_pole.visible = false
	add_child(_beacon_pole)


## Ground height at (x, z): flat around the pad, rolling hills further out, plus what a lesson adds
## (a ramp, potholes).
func height(x: float, z: float) -> float:
	var extra := 0.0
	for h in _hills:
		extra += _hill_height(h, x, z)
	for d in _dips:
		var dd := Vector2(x - d.x, z - d.z).length()
		if dd < d.y:
			extra -= 0.16 * (0.5 + 0.5 * cos(PI * dd / d.y))
	return extra + _base_height(x, z)


func _base_height(x: float, z: float) -> float:
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


## One material per colour, shared by every plain object of that colour (fewer draw states on cheap
## phones). Materials that change later (a highlighted gate) are made separately with _mat().
var _shared := {}


func _shared_mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _shared.has(k):
		_shared[k] = _mat(c)
	return _shared[k]


func _mesh(mesh: Mesh, c: Color, at: Vector3, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _shared_mat(c)
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
	houses.append({"pos": at, "rot": rot})
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
