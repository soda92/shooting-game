extends Node3D
## Procedural island: heightmap terrain, water, trees and rocks.

const BASE_WORLD_SIZE := 900.0
const MAP_SIZE_MULT := 1.55   # 1395m map; change this to expand further
const CHUNK_SIZE := 180.0
const CHUNK_RES := 30         # 6m grid, 49 chunks in view
const VIEW_CHUNKS := 3        # 7x7 chunks around the player
const WATER_LEVEL := 0.0

const POI_COUNT := 5
const CITY_INDEX := 3
const CITY_FX := 0.064
const CITY_FZ := 0.058
const CITY_FLAT := 46.0
const CITY_BLEND := 72.0
const POND_FX := 0.05
const POND_FZ := -0.167
const POND_RADIUS := 46.0

var world_size := BASE_WORLD_SIZE * MAP_SIZE_MULT
var map_scale := MAP_SIZE_MULT
var city_center := Vector2(world_size * CITY_FX, world_size * CITY_FZ)
var pond_center := Vector2(world_size * POND_FX, world_size * POND_FZ)
var city_plateau := 9.0
var pond_depth := 9.0

var _noise := FastNoiseLite.new()
var _tint := FastNoiseLite.new()
var _terrain_mat: StandardMaterial3D
var _terrain_root: Node3D
var _chunks: Dictionary = {}
var _focus := Vector2i(999999, 999999)

var poi_centers: Array[Vector3] = []
var loot_spots: Array[Vector3] = []
var bridge_points: Array[Vector3] = []


func _ready() -> void:
	seed(20261107)
	_noise.seed = 20261107
	_noise.frequency = 0.0048
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.5

	_tint.seed = 4242
	_tint.frequency = 0.05

	# Landmarks follow the map scale. The plateau/depth are derived from the
	# natural height so the city stays flat and the lake still reaches water.
	city_plateau = base_height_at(city_center.x, city_center.y)
	pond_depth = maxf(9.0, base_height_at(pond_center.x, pond_center.y) + 8.0)

	_terrain_mat = _make_terrain_mat()
	_terrain_root = Node3D.new()
	_terrain_root.name = "TerrainChunks"
	add_child(_terrain_root)

	_build_water()
	_build_pois()
	_build_bridge()
	_scatter_trees()
	_scatter_rocks()
	set_process(true)


# --------------------------------------------------------------------------
# Height field
# --------------------------------------------------------------------------

func base_height_at(x: float, z: float) -> float:
	var d := Vector2(x, z).length() / (world_size * 0.5)
	var land := clampf(1.0 - pow(d, 3.0), 0.0, 1.0)
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	return n * n * 55.0 * land - 5.0 - 12.0 * (1.0 - land)


func height_at(x: float, z: float) -> float:
	var h := base_height_at(x, z)
	# Flatten a plateau for the city so streets and plaza sit flush.
	var cd := Vector2(x - city_center.x, z - city_center.y).length()
	if cd < CITY_BLEND:
		var t := 1.0 - smoothstep(CITY_FLAT, CITY_BLEND, cd)
		h = lerpf(h, city_plateau, t)
	# Inland lake: a shallow bowl that reaches below the water plane.
	var pd := Vector2(x - pond_center.x, z - pond_center.y).length()
	var pond := clampf(1.0 - pd / POND_RADIUS, 0.0, 1.0)
	h -= pond_depth * pond * pond
	return h


func is_land(x: float, z: float, margin := 0.6) -> bool:
	return height_at(x, z) > WATER_LEVEL + margin


func random_land_point(max_radius := 175.0) -> Vector3:
	for i in range(64):
		var a := randf() * TAU
		var r := sqrt(randf()) * max_radius
		var x := cos(a) * r
		var z := sin(a) * r
		if is_land(x, z, 1.5):
			return Vector3(x, height_at(x, z), z)
	return Vector3(0.0, height_at(0.0, 0.0), 0.0)


func random_open_point(max_radius: float, poi_clear: float) -> Vector3:
	for i in range(40):
		var p := random_land_point(max_radius)
		if not _near_poi(p, poi_clear):
			return p
	return random_land_point(max_radius)


func slope_at(x: float, z: float) -> float:
	var e := 2.0
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector2(dx, dz).length() / (2.0 * e)


# --------------------------------------------------------------------------
# Terrain mesh
# --------------------------------------------------------------------------

func _color_for(x: float, z: float, h: float) -> Color:
	var v := _tint.get_noise_2d(x, z) * 0.5 + 0.5
	var s := slope_at(x, z)
	if s > 0.95:
		return Color(0.36, 0.35, 0.33).lerp(Color(0.50, 0.48, 0.44), v)
	if h < 1.2:
		return Color(0.80, 0.74, 0.54).lerp(Color(0.88, 0.82, 0.64), v)
	if h < 14.0:
		var grass := Color(0.34, 0.55, 0.26).lerp(Color(0.46, 0.64, 0.30), v)
		return Color(0.74, 0.72, 0.57).lerp(grass, clampf((h - 1.2) / 3.0, 0.0, 1.0))
	if h < 24.0:
		return Color(0.44, 0.43, 0.39).lerp(Color(0.55, 0.53, 0.47), v)
	return Color(0.82, 0.82, 0.84)


func _normal_at(x: float, z: float) -> Vector3:
	var e := 1.5
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func _make_terrain_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if p.has_method("is_airborne") and p.is_airborne():
		return
	var c := Vector2i(
		floori(p.global_position.x / CHUNK_SIZE),
		floori(p.global_position.z / CHUNK_SIZE)
	)
	if c == _focus:
		return
	_focus = c
	_refresh_chunks(c)


func _refresh_chunks(center: Vector2i) -> void:
	var keep := {}
	for dx in range(-VIEW_CHUNKS, VIEW_CHUNKS + 1):
		for dz in range(-VIEW_CHUNKS, VIEW_CHUNKS + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			keep[key] = true
			if not _chunks.has(key):
				_make_chunk(key)
	for key in _chunks.keys():
		if not keep.has(key):
			_chunks[key].queue_free()
			_chunks.erase(key)


func _make_chunk(key: Vector2i) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ox := float(key.x) * CHUNK_SIZE
	var oz := float(key.y) * CHUNK_SIZE
	var step := CHUNK_SIZE / float(CHUNK_RES)
	var row := CHUNK_RES + 1

	for iz in range(row):
		for ix in range(row):
			var x := ox + ix * step
			var z := oz + iz * step
			var y := height_at(x, z)
			st.set_color(_color_for(x, z, y))
			st.set_normal(_normal_at(x, z))
			st.add_vertex(Vector3(x, y, z))

	for iz in range(CHUNK_RES):
		for ix in range(CHUNK_RES):
			var i0 := iz * row + ix
			var i1 := i0 + 1
			var i2 := i0 + row
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i3)
			st.add_index(i2)

	var mesh := st.commit()

	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [key.x, key.y]

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	col.shape = shape
	body.add_child(col)
	root.add_child(body)

	_terrain_root.add_child(root)
	_chunks[key] = root


# --------------------------------------------------------------------------
# Water
# --------------------------------------------------------------------------

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(maxf(4000.0, world_size * 3.0), maxf(4000.0, world_size * 3.0))

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.30, 0.42, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.12
	mat.metallic = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.material_override = mat
	mi.position.y = WATER_LEVEL
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --------------------------------------------------------------------------
# Vegetation
# --------------------------------------------------------------------------

func _scatter_trees() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.7
	cone.height = 5.5
	cone.radial_segments = 6
	cone.rings = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.36, 0.20)
	mat.roughness = 0.9
	cone.material = mat

	var transforms: Array[Transform3D] = []
	for i in range(int(round(900.0 * map_scale * map_scale))):
		var p := random_land_point(330.0 * map_scale)
		if p.y < 2.5 or p.y > 30.0:
			continue
		if slope_at(p.x, p.z) > 0.55:
			continue
		if _near_poi(p, 30.0) or in_settlement(p.x, p.z):
			continue
		if Vector2(p.x - pond_center.x, p.z - pond_center.y).length() < POND_RADIUS + 6.0:
			continue
		var s := randf_range(0.7, 1.6)
		var basis := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s * randf_range(0.85, 1.25), s))
		transforms.append(Transform3D(basis, Vector3(p.x, p.y + 2.2 * s, p.z)))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)


func _scatter_rocks() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.4
	rock_mesh.height = 2.2
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.44, 0.43, 0.41)
	mat.roughness = 0.95
	rock_mesh.material = mat

	var root := Node3D.new()
	root.name = "Rocks"
	add_child(root)

	for i in range(int(round(70.0 * map_scale))):
		var p := random_land_point(320.0 * map_scale)
		if p.y < 1.0:
			continue
		if _near_poi(p, 26.0) or in_settlement(p.x, p.z):
			continue
		var s := randf_range(0.8, 2.4)
		var body := StaticBody3D.new()
		body.position = Vector3(p.x, p.y + 1.0 * s, p.z)
		body.rotation.y = randf() * TAU

		var mi := MeshInstance3D.new()
		mi.mesh = rock_mesh
		mi.scale = Vector3(s, s * randf_range(0.7, 1.2), s)
		body.add_child(mi)

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 1.35
		col.shape = shape
		col.scale = Vector3(s, s, s)
		body.add_child(col)

		root.add_child(body)


# --------------------------------------------------------------------------
# Points of interest
# --------------------------------------------------------------------------

func in_settlement(x: float, z: float) -> bool:
	for i in range(poi_centers.size()):
		var c := poi_centers[i]
		var r := 44.0 if i == CITY_INDEX else 12.0
		if Vector2(c.x - x, c.z - z).length() < r:
			return true
	return false


func _near_poi(p: Vector3, radius: float) -> bool:
	for c in poi_centers:
		if Vector2(c.x - p.x, c.z - p.z).length() < radius:
			return true
	return false


func _is_flat(center: Vector3, radius: float, max_var: float) -> bool:
	var lo := center.y
	var hi := center.y
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var h := height_at(center.x + cos(a) * radius, center.z + sin(a) * radius)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return (hi - lo) <= max_var and lo > 1.5


func _build_pois() -> void:
	var count := int(round(POI_COUNT * map_scale))
	var tries := 0
	while poi_centers.size() < count and tries < 4000:
		tries += 1
		var is_city := poi_centers.size() == CITY_INDEX
		var p: Vector3
		if is_city:
			p = Vector3(city_center.x, height_at(city_center.x, city_center.y), city_center.y)
		else:
			p = random_land_point(300.0 * map_scale)
			if not _is_flat(p, 9.0, 2.2):
				continue
			if Vector2(p.x - city_center.x, p.z - city_center.y).length() < 150.0 * map_scale:
				continue
			if Vector2(p.x - pond_center.x, p.z - pond_center.y).length() < 70.0 * map_scale:
				continue
		var ok := true
		for c in poi_centers:
			if Vector2(c.x - p.x, c.z - p.z).length() < 140.0 * map_scale:
				ok = false
				break
		if not ok:
			continue
		_build_compound(p, poi_centers.size())
		poi_centers.append(p)

	var city := poi_centers[CITY_INDEX] if poi_centers.size() > CITY_INDEX else Vector3.ZERO
	print("[world] pond h=%.1f city=%s" % [
		height_at(pond_center.x, pond_center.y), city
	])
	print("[world] POIs=%d loot spots=%d" % [poi_centers.size(), loot_spots.size()])


func _glass_mat(c: Color) -> StandardMaterial3D:
	var m := _poi_mat(c)
	m.metallic = 0.25
	m.roughness = 0.18
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.12
	return m


func _lamp_mat(c: Color) -> StandardMaterial3D:
	var m := _poi_mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.5
	return m


func _poi_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _surface_mat(c: Color) -> StandardMaterial3D:
	var m := _poi_mat(c)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _max_height_near(center: Vector3, radius: float) -> float:
	var hi := height_at(center.x, center.z)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		hi = maxf(hi, height_at(center.x + cos(a) * radius, center.z + sin(a) * radius))
	return hi


func _build_compound(p: Vector3, index: int) -> void:
	var is_city := index == CITY_INDEX
	var root := Node3D.new()
	if is_city:
		root.position = Vector3(p.x, p.y + 0.02, p.z)
		root.rotation.y = 0.0
	else:
		root.position = Vector3(p.x, _max_height_near(p, 8.0) + 0.05, p.z)
		root.rotation.y = float(index) * (PI * 0.5) + randf_range(-0.35, 0.35)
	add_child(root)

	var mats := {
		"wall": _poi_mat(Color(0.68, 0.64, 0.56)),
		"roof": _poi_mat(Color(0.22, 0.23, 0.26)),
		"metal": _poi_mat(Color(0.42, 0.24, 0.18)),
		"trim": _poi_mat(Color(0.34, 0.35, 0.38)),
		"concrete": _poi_mat(Color(0.55, 0.55, 0.52)),
		"window": _glass_mat(Color(0.22, 0.42, 0.58)),
		"wood": _poi_mat(Color(0.24, 0.15, 0.09)),
		"fabric": _poi_mat(Color(0.78, 0.76, 0.70)),
		"rug": _poi_mat(Color(0.34, 0.18, 0.16)),
		"lamp": _lamp_mat(Color(1.0, 0.79, 0.48)),
		"plaza": _surface_mat(Color(0.56, 0.56, 0.53)),
		"road": _surface_mat(Color(0.20, 0.21, 0.24)),
		"line": _surface_mat(Color(0.80, 0.68, 0.30)),
	}

	var boxes: Array = []
	var spots: Array = []

	if is_city:
		_city_surface(root, mats, root.position)
		_city_boxes(boxes, spots)
	else:
		match index % 3:
			0:
				_house_boxes(boxes, spots)
			1:
				_warehouse_boxes(boxes, spots)
			_:
				_yard_boxes(boxes, spots)

		boxes.append({"size": Vector3(1.2, 1.2, 1.2), "pos": Vector3(7.0, 0.6, -2.0), "mat": "trim"})
		boxes.append({"size": Vector3(1.2, 1.2, 1.2), "pos": Vector3(-7.0, 0.6, 3.0), "mat": "trim"})
		spots.append(Vector3(7.0, 0.0, -3.5))
		spots.append(Vector3(-7.0, 0.0, 4.5))

	_commit_poi(root, mats, boxes)

	for s in spots:
		loot_spots.append(root.to_global(Vector3(s.x, 0.0, s.z)))


func _commit_poi(root: Node3D, mats: Dictionary, boxes: Array) -> void:
	var body := StaticBody3D.new()
	root.add_child(body)

	var groups := {}
	for b in boxes:
		var key: String = b["mat"]
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = st

		var xf := Transform3D(Basis(), b["pos"])
		if b.has("rot"):
			xf.basis = Basis.from_euler(b["rot"])

		if not b.get("no_mesh", false):
			var bm := BoxMesh.new()
			bm.size = b["size"]
			groups[key].append_from(bm, 0, xf)

		if b.get("solid", true):
			var shape := BoxShape3D.new()
			shape.size = b["size"]
			var col := CollisionShape3D.new()
			col.shape = shape
			col.transform = xf
			body.add_child(col)

		if b.get("light", false):
			var light := OmniLight3D.new()
			light.position = b["pos"]
			light.light_color = Color(1.0, 0.86, 0.62)
			light.light_energy = float(b.get("light_energy", 0.9))
			light.omni_range = float(b.get("light_range", 9.0))
			light.shadow_enabled = false
			root.add_child(light)

	for key in groups:
		var mi := MeshInstance3D.new()
		mi.mesh = groups[key].commit()
		mi.material_override = mats[key]
		root.add_child(mi)


# --------------------------------------------------------------------------
# City and bridge
# --------------------------------------------------------------------------

func _city_surface(root: Node3D, mats: Dictionary, root_pos: Vector3) -> void:
	var plaza := _draped_grid(root_pos, 42.0, 3.0, 0.015)
	var pm := MeshInstance3D.new()
	pm.mesh = plaza
	pm.material_override = mats["plaza"]
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pm)

	# Sidewalk ribbons under the asphalt.
	for road in [
		[Vector2(-44, 0), Vector2(44, 0)],
		[Vector2(0, -44), Vector2(0, 44)],
	]:
		var sw := MeshInstance3D.new()
		sw.mesh = _draped_strip(root_pos, road[0], road[1], 14.0, 0.03)
		sw.material_override = mats["plaza"]
		sw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sw)

		var road_mi := MeshInstance3D.new()
		road_mi.mesh = _draped_strip(root_pos, road[0], road[1], 9.5, 0.05)
		road_mi.material_override = mats["road"]
		road_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(road_mi)

		var line := MeshInstance3D.new()
		line.mesh = _draped_strip(root_pos, road[0], road[1], 0.28, 0.062)
		line.material_override = mats["line"]
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(line)


func _draped_grid(root_pos: Vector3, half: float, step: float, y_off: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(half / step)
	for iz in range(-n, n + 1):
		for ix in range(-n, n + 1):
			var lx := ix * step
			var lz := iz * step
			var y := height_at(root_pos.x + lx, root_pos.z + lz) - root_pos.y + y_off
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(lx, y, lz))
	for iz in range(2 * n):
		for ix in range(2 * n):
			var i0 := iz * (2 * n + 1) + ix
			var i1 := i0 + 1
			var i2 := i0 + (2 * n + 1)
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i3)
			st.add_index(i2)
	return st.commit()


func _draped_strip(root_pos: Vector3, from: Vector2, to: Vector2,
		width: float, y_off: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x) * width * 0.5
	var length := (to - from).length()
	var steps := maxi(2, int(length / 2.0))
	for i in range(steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		for s in [-1.0, 1.0]:
			var q: Vector2 = p + side * s
			var y := height_at(root_pos.x + q.x, root_pos.z + q.y) - root_pos.y + y_off
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(q.x, y, q.y))
	for i in range(steps):
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	return st.commit()


func _city_boxes(boxes: Array, spots: Array) -> void:
	# Four blocks around a crossroads, doors facing the main street.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * 25.0, 0.0, sz * 25.0)
			_city_building(boxes, spots, c, 16.0, 12.0, 2 if sx * sz > 0.0 else 3, -sz)

	# Street lamps.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var lc := Vector3(sx * 8.0, 0.0, sz * 8.0)
			boxes.append({"size": Vector3(0.16, 4.4, 0.16), "pos": lc + Vector3(0, 2.2, 0), "mat": "trim"})
			boxes.append({"size": Vector3(0.5, 0.28, 0.5), "pos": lc + Vector3(0, 4.55, 0), "mat": "window"})

	# Street props and cover.
	boxes.append({"size": Vector3(2.4, 2.4, 5.0), "pos": Vector3(-13.0, 1.2, 36.0), "mat": "metal"})
	boxes.append({"size": Vector3(2.4, 2.4, 5.0), "pos": Vector3(13.0, 1.2, -36.0), "mat": "metal"})
	boxes.append({"size": Vector3(3.0, 0.8, 3.0), "pos": Vector3(0.0, 0.4, 0.0), "mat": "concrete"})
	boxes.append({"size": Vector3(1.2, 1.2, 1.2), "pos": Vector3(8.0, 0.6, 8.0), "mat": "trim"})

	spots.append(Vector3(0.0, 0.0, 5.0))
	spots.append(Vector3(5.0, 0.0, -3.0))
	spots.append(Vector3(-4.0, 0.0, -8.0))
	spots.append(Vector3(9.0, 0.0, -9.0))


func _city_building(boxes: Array, spots: Array, c: Vector3,
		w: float, d: float, floors: int, door_sign: float) -> void:
	var floor_h := 3.0
	var h := float(floors) * floor_h
	var ext := 3.0
	var total := h + ext
	var cy := (h - ext) * 0.5
	var t := 0.3

	# Side walls and the wall opposite the door.
	boxes.append({"size": Vector3(t, total, d), "pos": c + Vector3(-w * 0.5, cy, 0), "mat": "wall"})
	boxes.append({"size": Vector3(t, total, d), "pos": c + Vector3(w * 0.5, cy, 0), "mat": "wall"})
	boxes.append({"size": Vector3(w, total, t), "pos": c + Vector3(0, cy, -door_sign * d * 0.5), "mat": "wall"})

	# Door wall on the street side: two segments plus a header.
	var seg := (w - 2.4) * 0.5
	var dz := door_sign * d * 0.5
	boxes.append({"size": Vector3(seg, total, t), "pos": c + Vector3(-(w * 0.5 - seg * 0.5), cy, dz), "mat": "wall"})
	boxes.append({"size": Vector3(seg, total, t), "pos": c + Vector3(w * 0.5 - seg * 0.5, cy, dz), "mat": "wall"})
	boxes.append({
		"size": Vector3(2.4, h - 2.3, t),
		"pos": c + Vector3(0, (h + 2.3) * 0.5, dz),
		"mat": "wall",
	})

	# Flat roof and a low parapet.
	boxes.append({"size": Vector3(w + 0.6, 0.3, d + 0.6), "pos": c + Vector3(0, h + 0.15, 0), "mat": "roof"})
	for sx in [-1.0, 1.0]:
		boxes.append({"size": Vector3(t, 0.8, d + 0.2), "pos": c + Vector3(sx * w * 0.5, h + 0.55, 0), "mat": "roof"})
	for sz in [-1.0, 1.0]:
		boxes.append({"size": Vector3(w + 0.2, 0.8, t), "pos": c + Vector3(0, h + 0.55, sz * d * 0.5), "mat": "roof"})

	# Windows and sills on every floor.
	for f in range(floors):
		var wy := float(f) * floor_h + 1.7
		for wx in [-w * 0.25, w * 0.25]:
			for sz in [-1.0, 1.0]:
				var wz: float = float(sz) * (d * 0.5 + 0.12)
				boxes.append({"size": Vector3(1.4, 1.1, 0.1), "pos": c + Vector3(wx, wy, wz), "mat": "window", "solid": false})
				boxes.append({"size": Vector3(1.7, 0.12, 0.3), "pos": c + Vector3(wx, wy - 0.64, wz), "mat": "trim", "solid": false})
				boxes.append({"size": Vector3(1.7, 0.10, 0.16), "pos": c + Vector3(wx, wy + 0.60, wz), "mat": "trim", "solid": false})
				boxes.append({"size": Vector3(0.10, 1.3, 0.16), "pos": c + Vector3(wx - 0.75, wy, wz), "mat": "trim", "solid": false})
				boxes.append({"size": Vector3(0.10, 1.3, 0.16), "pos": c + Vector3(wx + 0.75, wy, wz), "mat": "trim", "solid": false})
		for wz in [-d * 0.25, d * 0.25]:
			for sx in [-1.0, 1.0]:
				var wx: float = float(sx) * (w * 0.5 + 0.12)
				boxes.append({"size": Vector3(0.1, 1.1, 1.4), "pos": c + Vector3(wx, wy, wz), "mat": "window", "solid": false})
				boxes.append({"size": Vector3(0.3, 0.12, 1.7), "pos": c + Vector3(wx, wy - 0.64, wz), "mat": "trim", "solid": false})
				boxes.append({"size": Vector3(0.16, 0.10, 1.7), "pos": c + Vector3(wx, wy + 0.60, wz), "mat": "trim", "solid": false})
				boxes.append({"size": Vector3(0.16, 1.3, 0.10), "pos": c + Vector3(wx, wy, wz - 0.75), "mat": "trim", "solid": false})
				boxes.append({"size": Vector3(0.16, 1.3, 0.10), "pos": c + Vector3(wx, wy, wz + 0.75), "mat": "trim", "solid": false})

	# Door frame.
	for sx in [-1.0, 1.0]:
		boxes.append({
			"size": Vector3(0.22, 2.45, 0.22),
			"pos": c + Vector3(sx * 1.32, 1.22, dz + door_sign * 0.2),
			"mat": "trim",
			"solid": false,
		})
	boxes.append({
		"size": Vector3(2.9, 0.22, 0.22),
		"pos": c + Vector3(0, 2.42, dz + door_sign * 0.2),
		"mat": "trim",
		"solid": false,
	})

	# Two side stair strips keep the upper flight out from over the lower one.
	var stair_w := 1.5
	var left_x0 := -w * 0.5 + 0.2
	var left_x1 := left_x0 + stair_w
	var right_x0 := w * 0.5 - 1.7
	var right_x1 := right_x0 + stair_w
	var left_x := (left_x0 + left_x1) * 0.5
	var right_x := (right_x0 + right_x1) * 0.5
	var slab_r := right_x0 - 0.1
	var slab_l := (-w * 0.5 + 0.15) if floors == 2 else (left_x1 + 0.1)
	var z_front := door_sign * (d * 0.5 - 0.8)
	var z_back := -door_sign * (d * 0.5 - 0.8)

	for f in range(1, floors):
		var fy := float(f) * floor_h - 0.11
		boxes.append({
			"size": Vector3(slab_r - slab_l, 0.22, d - 0.3),
			"pos": c + Vector3((slab_l + slab_r) * 0.5, fy, 0),
			"mat": "concrete",
		})

	for f in range(floors):
		var by := float(f) * floor_h
		# Room partition with a 1.4m doorway.
		var px0 := slab_l + 0.2
		var px1 := slab_r - 0.2
		var dx := -1.0
		var left_w := (dx - 0.7) - px0
		var right_w := px1 - (dx + 0.7)
		if left_w > 0.2:
			boxes.append({"size": Vector3(left_w, floor_h - 0.05, 0.18), "pos": c + Vector3(px0 + left_w * 0.5, by + floor_h * 0.5, 0), "mat": "wall"})
		if right_w > 0.2:
			boxes.append({"size": Vector3(right_w, floor_h - 0.05, 0.18), "pos": c + Vector3(dx + 0.7 + right_w * 0.5, by + floor_h * 0.5, 0), "mat": "wall"})
		boxes.append({"size": Vector3(1.4, 0.8, 0.18), "pos": c + Vector3(dx, by + 2.6, 0), "mat": "wall"})

		# Beds, bedside tables, rugs, tables and wardrobes.
		for side in [-1.0, 1.0]:
			var side_z: float = float(side) * d * 0.30
			_add_bed(boxes, c + Vector3(-w * 0.26, by, side_z))
			boxes.append({"size": Vector3(3.0, 0.02, 2.4), "pos": c + Vector3(-w * 0.26, by + 0.015, side_z), "mat": "rug", "solid": false})
			_add_table(boxes, c + Vector3(2.4, by, side_z))
			_add_wardrobe(boxes, c + Vector3(w * 0.30, by, side_z + 1.5))
		boxes.append({
			"size": Vector3(0.7, 0.07, 0.7),
			"pos": c + Vector3(-w * 0.16, by + 2.82, -d * 0.18),
			"mat": "lamp",
			"solid": false,
		})

	# One soft interior light per building keeps mobile draw cost low.
	boxes.append({
		"size": Vector3(0.1, 0.1, 0.1),
		"pos": c + Vector3(-w * 0.10, h * 0.5, 0.0),
		"mat": "trim",
		"solid": false,
		"no_mesh": true,
		"light": true,
		"light_energy": 1.2,
		"light_range": 16.0,
	})

	# Run 1 climbs on the right; run 2 climbs on the left.
	for f in range(floors - 1):
		var next_y := float(f + 1) * floor_h
		if f % 2 == 0:
			_add_stairs(boxes, c + Vector3(right_x, 0, 0), z_front, z_back,
				float(f) * floor_h, next_y, stair_w)
			# A top landing so the player can step off the ramp onto the floor.
			var wall_z := -door_sign * d * 0.5
			boxes.append({
				"size": Vector3(stair_w, 0.22, absf(wall_z - z_back)),
				"pos": c + Vector3(right_x, next_y - 0.11, (z_back + wall_z) * 0.5),
				"mat": "concrete",
			})
		else:
			_add_stairs(boxes, c + Vector3(left_x, 0, 0), z_back, z_front,
				float(f) * floor_h, next_y, stair_w)
			var wall_z := door_sign * d * 0.5
			boxes.append({
				"size": Vector3(stair_w, 0.22, absf(wall_z - z_front)),
				"pos": c + Vector3(left_x, next_y - 0.11, (z_front + wall_z) * 0.5),
				"mat": "concrete",
			})

	spots.append(c + Vector3(0.0, 0.0, 0.0))
	spots.append(c + Vector3(-w * 0.25, 0.0, d * 0.2))
	spots.append(c + Vector3(w * 0.25, 0.0, -d * 0.2))


func _add_stairs(boxes: Array, base: Vector3, z0: float, z1: float,
		y0: float, y1: float, width: float) -> void:
	var run := absf(z1 - z0)
	var rise := y1 - y0
	var length := sqrt(run * run + rise * rise)
	var steps := maxi(10, int(ceil(rise / 0.19)))
	var tread := run / float(steps)
	for i in range(steps):
		var t := (float(i) + 0.5) / float(steps)
		var z := lerpf(z0, z1, t)
		var top := lerpf(y0, y1, t)
		boxes.append({
			"size": Vector3(width, rise / float(steps), tread * 1.04),
			"pos": base + Vector3(0, top - rise / float(steps) * 0.5, z),
			"mat": "wood",
			"solid": false,
		})

	var angle := atan2(rise, z0 - z1)
	boxes.append({
		"size": Vector3(width, 0.16, length),
		"pos": base + Vector3(0, (y0 + y1) * 0.5, (z0 + z1) * 0.5),
		"rot": Vector3(angle, 0.0, 0.0),
		"mat": "concrete",
		"no_mesh": true,
	})


func _add_bed(boxes: Array, base: Vector3) -> void:
	boxes.append({"size": Vector3(2.0, 0.18, 1.2), "pos": base + Vector3(0, 0.09, 0), "mat": "wood", "solid": false})
	boxes.append({"size": Vector3(1.85, 0.28, 1.05), "pos": base + Vector3(0, 0.32, 0), "mat": "fabric", "solid": false})
	boxes.append({"size": Vector3(0.55, 0.18, 0.9), "pos": base + Vector3(-0.62, 0.51, 0), "mat": "fabric", "solid": false})
	boxes.append({"size": Vector3(1.05, 0.07, 1.05), "pos": base + Vector3(0.38, 0.48, 0), "mat": "rug", "solid": false})
	boxes.append({"size": Vector3(0.12, 1.0, 1.2), "pos": base + Vector3(-1.02, 0.55, 0), "mat": "wood", "solid": false})
	boxes.append({"size": Vector3(0.6, 0.6, 0.6), "pos": base + Vector3(1.28, 0.30, 0.9), "mat": "wood", "solid": false})


func _add_table(boxes: Array, base: Vector3) -> void:
	boxes.append({"size": Vector3(1.4, 0.10, 0.9), "pos": base + Vector3(0, 0.75, 0), "mat": "wood", "solid": false})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			boxes.append({"size": Vector3(0.10, 0.72, 0.10), "pos": base + Vector3(sx * 0.58, 0.36, sz * 0.34), "mat": "wood", "solid": false})
	boxes.append({"size": Vector3(0.55, 0.08, 0.55), "pos": base + Vector3(0, 0.45, 0.85), "mat": "wood", "solid": false})
	boxes.append({"size": Vector3(0.08, 0.45, 0.08), "pos": base + Vector3(-0.18, 0.22, 0.85), "mat": "wood", "solid": false})
	boxes.append({"size": Vector3(0.08, 0.45, 0.08), "pos": base + Vector3(0.18, 0.22, 0.85), "mat": "wood", "solid": false})


func _add_wardrobe(boxes: Array, base: Vector3) -> void:
	boxes.append({"size": Vector3(1.25, 2.0, 0.55), "pos": base + Vector3(0, 1.0, 0), "mat": "wood", "solid": false})
	boxes.append({"size": Vector3(1.0, 0.06, 0.05), "pos": base + Vector3(0, 1.05, -0.29), "mat": "trim", "solid": false})
	boxes.append({"size": Vector3(0.05, 0.20, 0.05), "pos": base + Vector3(-0.15, 1.05, -0.31), "mat": "trim", "solid": false})
	boxes.append({"size": Vector3(0.05, 0.20, 0.05), "pos": base + Vector3(0.15, 1.05, -0.31), "mat": "trim", "solid": false})


func _build_bridge() -> void:
	var z := pond_center.y
	var deck_y := maxf(
		maxf(height_at(pond_center.x - 60.0, z), height_at(pond_center.x + 60.0, z)) + 0.6,
		2.0
	)
	var root := Node3D.new()
	root.name = "Bridge"
	root.position = Vector3(pond_center.x, 0.0, z)
	add_child(root)

	var mats := {
		"roof": _poi_mat(Color(0.25, 0.26, 0.28)),
		"trim": _poi_mat(Color(0.70, 0.70, 0.68)),
	}

	var boxes: Array = []
	boxes.append({"size": Vector3(120.0, 0.6, 9.0), "pos": Vector3(0, deck_y, 0), "mat": "roof"})
	boxes.append({"size": Vector3(120.0, 1.1, 0.28), "pos": Vector3(0, deck_y + 0.85, 4.3), "mat": "trim"})
	boxes.append({"size": Vector3(120.0, 1.1, 0.28), "pos": Vector3(0, deck_y + 0.85, -4.3), "mat": "trim"})

	var hl := height_at(pond_center.x - 96.0, z)
	var hr := height_at(pond_center.x + 96.0, z)
	var ang_r := asin(clampf((hr - deck_y) / 36.0, -0.8, 0.8))
	var ang_l := asin(clampf((deck_y - hl) / 36.0, -0.8, 0.8))
	boxes.append({
		"size": Vector3(36.0, 0.5, 9.0),
		"pos": Vector3(78.0, (deck_y + hr) * 0.5, 0),
		"rot": Vector3(0.0, 0.0, ang_r),
		"mat": "roof",
	})
	boxes.append({
		"size": Vector3(36.0, 0.5, 9.0),
		"pos": Vector3(-78.0, (deck_y + hl) * 0.5, 0),
		"rot": Vector3(0.0, 0.0, ang_l),
		"mat": "roof",
	})

	_commit_poi(root, mats, boxes)
	bridge_points = [
		Vector3(pond_center.x - 60.0, 0.0, z),
		Vector3(pond_center.x + 60.0, 0.0, z),
	]
	print("[world] bridge deck y=%.1f" % deck_y)


func _house_boxes(boxes: Array, spots: Array) -> void:
	var ext := 2.2
	var total_h := 3.0 + ext
	var cy := (3.0 - ext) * 0.5

	boxes.append({"size": Vector3(6.0, total_h, 0.25), "pos": Vector3(0, cy, 3.0), "mat": "wall"})
	boxes.append({"size": Vector3(0.25, total_h, 6.0), "pos": Vector3(-3.0, cy, 0), "mat": "wall"})
	boxes.append({"size": Vector3(0.25, total_h, 6.0), "pos": Vector3(3.0, cy, 0), "mat": "wall"})
	boxes.append({"size": Vector3(2.4, total_h, 0.25), "pos": Vector3(-1.8, cy, -3.0), "mat": "wall"})
	boxes.append({"size": Vector3(2.4, total_h, 0.25), "pos": Vector3(1.8, cy, -3.0), "mat": "wall"})
	boxes.append({"size": Vector3(1.2, 0.9, 0.25), "pos": Vector3(0, 2.55, -3.0), "mat": "wall"})
	boxes.append({"size": Vector3(6.4, 0.2, 6.4), "pos": Vector3(0, 3.1, 0), "mat": "roof"})
	boxes.append({"size": Vector3(1.2, 1.2, 1.2), "pos": Vector3(1.5, 0.6, 1.2), "mat": "trim"})
	boxes.append({"size": Vector3(1.2, 1.2, 1.2), "pos": Vector3(-1.6, 0.6, 1.8), "mat": "trim"})

	spots.append(Vector3(0.0, 0.0, 0.0))
	spots.append(Vector3(-2.0, 0.0, 2.2))
	spots.append(Vector3(2.2, 0.0, -2.0))


func _warehouse_boxes(boxes: Array, spots: Array) -> void:
	var ext := 2.2
	var total_h := 4.2 + ext
	var cy := (4.2 - ext) * 0.5

	boxes.append({"size": Vector3(10.0, total_h, 0.3), "pos": Vector3(0, cy, 3.5), "mat": "wall"})
	boxes.append({"size": Vector3(0.3, total_h, 7.0), "pos": Vector3(-5.0, cy, 0), "mat": "wall"})
	boxes.append({"size": Vector3(0.3, total_h, 7.0), "pos": Vector3(5.0, cy, 0), "mat": "wall"})
	boxes.append({"size": Vector3(3.4, total_h, 0.3), "pos": Vector3(-3.3, cy, -3.5), "mat": "wall"})
	boxes.append({"size": Vector3(3.4, total_h, 0.3), "pos": Vector3(3.3, cy, -3.5), "mat": "wall"})
	boxes.append({"size": Vector3(3.2, 1.4, 0.3), "pos": Vector3(0, 3.5, -3.5), "mat": "wall"})
	boxes.append({"size": Vector3(10.4, 0.2, 7.4), "pos": Vector3(0, 4.3, 0), "mat": "roof"})
	boxes.append({"size": Vector3(2.4, 2.4, 5.0), "pos": Vector3(-2.6, 1.2, 0.5), "mat": "metal"})
	boxes.append({"size": Vector3(2.4, 2.4, 5.0), "pos": Vector3(2.6, 1.2, 0.5), "mat": "metal"})

	spots.append(Vector3(0.0, 0.0, -2.2))
	spots.append(Vector3(0.0, 0.0, 2.6))
	spots.append(Vector3(-3.5, 0.0, 3.0))
	spots.append(Vector3(3.5, 0.0, -2.0))


func _yard_boxes(boxes: Array, spots: Array) -> void:
	boxes.append({"size": Vector3(2.4, 3.6, 5.5), "pos": Vector3(-3.5, 1.0, -2.0), "mat": "metal"})
	boxes.append({"size": Vector3(2.4, 3.6, 5.5), "pos": Vector3(0.0, 1.0, 2.5), "mat": "metal"})
	boxes.append({"size": Vector3(2.4, 3.6, 5.5), "pos": Vector3(3.5, 1.0, -2.0), "mat": "metal"})
	boxes.append({"size": Vector3(9.0, 2.4, 0.3), "pos": Vector3(0, 0.6, -5.5), "mat": "wall"})
	boxes.append({"size": Vector3(0.3, 2.4, 9.0), "pos": Vector3(-5.5, 0.6, 0), "mat": "wall"})

	spots.append(Vector3(-3.5, 0.0, 1.5))
	spots.append(Vector3(0.0, 0.0, -1.0))
	spots.append(Vector3(3.5, 0.0, 1.5))
	spots.append(Vector3(0.0, 0.0, 5.0))
