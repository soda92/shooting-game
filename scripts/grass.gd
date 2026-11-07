extends Node3D
## Chunked grass. Only chunks around the player exist, rebuilt as they move.

const CHUNK := 24.0
const VIEW := 3
const PER_CHUNK := 420

var world
var _mesh: ArrayMesh
var _mat: ShaderMaterial
var _chunks: Dictionary = {}
var _center := Vector2i(999999, 999999)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	world = get_parent()
	_mesh = _make_blade_mesh()
	_mat = _make_material()
	set_process(true)


func _process(_delta: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var c := Vector2i(
		floori(p.global_position.x / CHUNK),
		floori(p.global_position.z / CHUNK)
	)
	if c == _center:
		return
	_center = c
	_refresh()


func _refresh() -> void:
	var keep := {}
	for dx in range(-VIEW, VIEW + 1):
		for dz in range(-VIEW, VIEW + 1):
			var key := Vector2i(_center.x + dx, _center.y + dz)
			keep[key] = true
			if not _chunks.has(key):
				_make_chunk(key)
	for key in _chunks.keys():
		if not keep.has(key):
			_chunks[key].queue_free()
			_chunks.erase(key)


func _make_chunk(key: Vector2i) -> void:
	_rng.seed = hash(key)
	var transforms: Array[Transform3D] = []

	for i in range(PER_CHUNK):
		var x := (key.x + _rng.randf()) * CHUNK
		var z := (key.y + _rng.randf()) * CHUNK
		var h: float = world.height_at(x, z)
		if h < 1.2 or h > 15.0:
			continue
		if world.slope_at(x, z) > 0.5:
			continue
		if world.in_settlement(x, z):
			continue
		var s := _rng.randf_range(0.7, 1.2)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
		transforms.append(Transform3D(basis, Vector3(x, h + 0.02, z)))

	if transforms.is_empty():
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_chunks[key] = mi


func _make_blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for k in range(5):
		var a := TAU * float(k) / 5.0
		var side := Vector3(-sin(a), 0.0, cos(a))
		var out := Vector3(cos(a), 0.0, sin(a))
		var w := 0.055
		var h := 0.45
		var p0 := -side * w
		var p1 := side * w
		var p2 := out * 0.07 + Vector3(0.0, h, 0.0)

		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p0)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p1)
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(p2)

	return st.commit()


func _make_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.20, 0.36, 0.14, 1.0);
uniform vec4 tip_color : source_color = vec4(0.52, 0.72, 0.30, 1.0);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.8 + wp.x * 0.35 + wp.z * 0.27);
	VERTEX.x += sway * 0.07 * UV.y;
	VERTEX.z += sway * 0.04 * UV.y;
}

void fragment() {
	ALBEDO = mix(base_color.rgb, tip_color.rgb, UV.y);
	ROUGHNESS = 1.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
