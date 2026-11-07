extends Node3D
## Procedural island: heightmap terrain, water, trees and rocks.

const WORLD_SIZE := 900.0
const RES := 200
const WATER_LEVEL := 0.0

const POI_COUNT := 5
const CITY_INDEX := 3
const CITY_CENTER := Vector2(58.0, 52.0)
const CITY_PLATEAU := 9.0
const CITY_FLAT := 46.0
const CITY_BLEND := 72.0
const POND_CENTER := Vector2(45.0, -150.0)
const POND_RADIUS := 46.0
const POND_DEPTH := 9.0

var _noise := FastNoiseLite.new()
var _tint := FastNoiseLite.new()

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

	_build_terrain()
	_build_water()
	_build_pois()
	_build_bridge()
	_scatter_trees()
	_scatter_rocks()


# --------------------------------------------------------------------------
# Height field
# --------------------------------------------------------------------------

func base_height_at(x: float, z: float) -> float:
	var d := Vector2(x, z).length() / (WORLD_SIZE * 0.5)
	var land := clampf(1.0 - pow(d, 3.0), 0.0, 1.0)
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	return n * n * 55.0 * land - 5.0 - 12.0 * (1.0 - land)


func height_at(x: float, z: float) -> float:
	var h := base_height_at(x, z)
	# Flatten a plateau for the city so streets and plaza sit flush.
	var cd := Vector2(x - CITY_CENTER.x, z - CITY_CENTER.y).length()
	if cd < CITY_BLEND:
		var t := 1.0 - smoothstep(CITY_FLAT, CITY_BLEND, cd)
		h = lerpf(h, CITY_PLATEAU, t)
	# Inland lake: a shallow bowl that reaches below the water plane.
	var pd := Vector2(x - POND_CENTER.x, z - POND_CENTER.y).length()
	var pond := clampf(1.0 - pd / POND_RADIUS, 0.0, 1.0)
	h -= POND_DEPTH * pond * pond
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


func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var step := WORLD_SIZE / float(RES)
	var half := WORLD_SIZE * 0.5

	for iz in range(RES + 1):
		for ix in range(RES + 1):
			var x := -half + ix * step
			var z := -half + iz * step
			var y := height_at(x, z)
			st.set_color(_color_for(x, z, y))
			st.set_normal(_normal_at(x, z))
			st.add_vertex(Vector3(x, y, z))

	for iz in range(RES):
		for ix in range(RES):
			var i0 := iz * (RES + 1) + ix
			var i1 := i0 + 1
			var i2 := i0 + (RES + 1)
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i3)
			st.add_index(i2)

	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var col := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	col.shape = shape
	body.add_child(col)
	add_child(body)


# --------------------------------------------------------------------------
# Water
# --------------------------------------------------------------------------

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000.0, 3000.0)

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
	for i in range(900):
		var p := random_land_point(330.0)
		if p.y < 2.5 or p.y > 30.0:
			continue
		if slope_at(p.x, p.z) > 0.55:
			continue
		if _near_poi(p, 30.0) or in_settlement(p.x, p.z):
			continue
		if Vector2(p.x - POND_CENTER.x, p.z - POND_CENTER.y).length() < POND_RADIUS + 6.0:
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

	for i in range(70):
		var p := random_land_point(320.0)
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
	var tries := 0
	while poi_centers.size() < POI_COUNT and tries < 3000:
		tries += 1
		var is_city := poi_centers.size() == CITY_INDEX
		var p: Vector3
		if is_city:
			p = Vector3(CITY_CENTER.x, height_at(CITY_CENTER.x, CITY_CENTER.y), CITY_CENTER.y)
		else:
			p = random_land_point(300.0)
			if not _is_flat(p, 9.0, 2.2):
				continue
			if Vector2(p.x - CITY_CENTER.x, p.z - CITY_CENTER.y).length() < 150.0:
				continue
			if Vector2(p.x - POND_CENTER.x, p.z - POND_CENTER.y).length() < 70.0:
				continue
		var ok := true
		for c in poi_centers:
			if Vector2(c.x - p.x, c.z - p.z).length() < 140.0:
				ok = false
				break
		if not ok:
			continue
		_build_compound(p, poi_centers.size())
		poi_centers.append(p)

	var city := poi_centers[CITY_INDEX] if poi_centers.size() > CITY_INDEX else Vector3.ZERO
	print("[world] pond h=%.1f city=%s" % [
		height_at(POND_CENTER.x, POND_CENTER.y), city
	])
	print("[world] POIs=%d loot spots=%d" % [poi_centers.size(), loot_spots.size()])


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
		"window": _poi_mat(Color(0.16, 0.27, 0.34)),
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
			_city_building(boxes, spots, c, 16.0, 12.0, 5.0, -sz)

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
		w: float, d: float, h: float, door_sign: float) -> void:
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
	boxes.append({"size": Vector3(w + 0.6, 0.3, d + 0.6), "pos": c + Vector3(0, h + 0.15, 0), "mat": "roof"})

	# Windows: two per wall, slightly proud of the facade.
	for wx in [-w * 0.25, w * 0.25]:
		boxes.append({"size": Vector3(1.4, 1.1, 0.1), "pos": c + Vector3(wx, 2.7, -door_sign * d * 0.5 + door_sign * -0.18), "mat": "window", "solid": false})
		boxes.append({"size": Vector3(1.4, 1.1, 0.1), "pos": c + Vector3(wx, 2.7, dz + door_sign * 0.18), "mat": "window", "solid": false})
	for wz in [-d * 0.25, d * 0.25]:
		boxes.append({"size": Vector3(0.1, 1.1, 1.4), "pos": c + Vector3(-w * 0.5 - 0.18, 2.7, wz), "mat": "window", "solid": false})
		boxes.append({"size": Vector3(0.1, 1.1, 1.4), "pos": c + Vector3(w * 0.5 + 0.18, 2.7, wz), "mat": "window", "solid": false})

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

	spots.append(c + Vector3(0.0, 0.0, 0.0))
	spots.append(c + Vector3(-w * 0.25, 0.0, d * 0.2))
	spots.append(c + Vector3(w * 0.25, 0.0, -d * 0.2))


func _build_bridge() -> void:
	var z := POND_CENTER.y
	var deck_y := maxf(
		maxf(height_at(POND_CENTER.x - 60.0, z), height_at(POND_CENTER.x + 60.0, z)) + 0.6,
		2.0
	)
	var root := Node3D.new()
	root.name = "Bridge"
	root.position = Vector3(POND_CENTER.x, 0.0, z)
	add_child(root)

	var mats := {
		"roof": _poi_mat(Color(0.25, 0.26, 0.28)),
		"trim": _poi_mat(Color(0.70, 0.70, 0.68)),
	}

	var boxes: Array = []
	boxes.append({"size": Vector3(120.0, 0.6, 9.0), "pos": Vector3(0, deck_y, 0), "mat": "roof"})
	boxes.append({"size": Vector3(120.0, 1.1, 0.28), "pos": Vector3(0, deck_y + 0.85, 4.3), "mat": "trim"})
	boxes.append({"size": Vector3(120.0, 1.1, 0.28), "pos": Vector3(0, deck_y + 0.85, -4.3), "mat": "trim"})

	var hl := height_at(POND_CENTER.x - 96.0, z)
	var hr := height_at(POND_CENTER.x + 96.0, z)
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
		Vector3(POND_CENTER.x - 60.0, 0.0, z),
		Vector3(POND_CENTER.x + 60.0, 0.0, z),
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
