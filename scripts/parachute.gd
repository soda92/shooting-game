extends Node3D
## Arched ram-air style canopy with a curved span, cell ribs and lines.
## Opens with a short scale animation and sways gently while active.

const HALF_SPAN := 3.4
const CENTER_Y := 3.95
const TIP_Y := 3.15
const CENTER_CHORD := 1.70
const TIP_CHORD := 0.95

var _canopy_mat: StandardMaterial3D
var _stripe_mat: StandardMaterial3D
var _rib_mat: StandardMaterial3D
var _line_mat: StandardMaterial3D

var _open_t := 1.0
var _opening := false
var _t := 0.0


func _ready() -> void:
	_build()
	visible = false
	set_process(false)


func set_style(def: Dictionary) -> void:
	if _canopy_mat == null:
		return
	_canopy_mat.albedo_color = def["canopy"]
	_canopy_mat.emission = def["canopy"]
	_stripe_mat.albedo_color = def["stripe"]
	_stripe_mat.emission = def["stripe"]
	_rib_mat.albedo_color = def["stripe"].darkened(0.42)


func open() -> void:
	visible = true
	_opening = true
	_open_t = 0.0
	_t = 0.0
	scale = Vector3.ONE * 0.2
	set_process(true)


func close() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	if _opening:
		_open_t = minf(1.0, _open_t + delta / 0.35)
		scale = Vector3.ONE * (0.2 + 0.8 * _open_t)
		if _open_t >= 1.0:
			_opening = false
	rotation.z = sin(_t * 1.6) * 0.035
	rotation.x = sin(_t * 1.1 + 1.0) * 0.025


func _build() -> void:
	_canopy_mat = _mat(Color(0.20, 0.45, 0.85))
	_stripe_mat = _mat(Color(0.95, 0.95, 0.95))
	_rib_mat = _mat(Color(0.16, 0.20, 0.26))
	_line_mat = _mat(Color(0.92, 0.95, 1.0))
	for m in [_canopy_mat, _stripe_mat, _line_mat]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED if m != _line_mat else BaseMaterial3D.CULL_BACK
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rib_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rib_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Wing: colored centre cell with contrasting tips, like a ram-air canopy.
	_section(-HALF_SPAN, -2.65, _stripe_mat)
	_section(-2.65, 2.65, _canopy_mat)
	_section(2.65, HALF_SPAN, _stripe_mat)

	# Leading edge tube makes the thin surface read as a real wing.
	var steps := 18
	for i in range(steps):
		var x0 := lerpf(-HALF_SPAN, HALF_SPAN, float(i) / steps)
		var x1 := lerpf(-HALF_SPAN, HALF_SPAN, float(i + 1) / steps)
		_line(_point(x0, -1.0), _point(x1, -1.0), _stripe_mat, 0.085)

	# Cell seams: thin ribbons that follow the canopy surface.
	for r in range(-3, 4):
		_seam(float(r) * 0.9, _rib_mat)

	# Suspension lines from the underside to the harness.
	for r in range(-2, 3):
		var x := float(r) * 1.5
		for zc in [-0.72, 0.72]:
			var top := _point(x, zc) - Vector3(0, 0.08, 0)
			var bottom := Vector3(x * 0.16, 1.25, float(zc) * 0.18)
			_line(top, bottom, _line_mat, 0.019)


func _section(x0: float, x1: float, mat: Material) -> void:
	var cols := 15
	var rows := 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(cols):
		var x := lerpf(x0, x1, float(i) / float(cols - 1))
		for j in range(rows):
			var zc := -1.0 + float(j) / float(rows - 1) * 2.0
			st.add_vertex(_point(x, zc))
	for i in range(cols - 1):
		for j in range(rows - 1):
			var a := i * rows + j
			var b := (i + 1) * rows + j
			var c := i * rows + j + 1
			var d := (i + 1) * rows + j + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _seam(x: float, mat: Material) -> void:
	var segs := 12
	var half := 0.015
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segs + 1):
		var zc := -0.9 + float(i) / float(segs) * 1.8
		var p := _point(x, zc)
		st.add_vertex(Vector3(p.x - half, p.y - 0.012, p.z))
		st.add_vertex(Vector3(p.x + half, p.y - 0.012, p.z))
	for i in range(segs):
		var a := i * 2
		var b := a + 1
		var c := a + 2
		var d := a + 3
		st.add_index(a)
		st.add_index(c)
		st.add_index(b)
		st.add_index(b)
		st.add_index(c)
		st.add_index(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _point(x: float, zc: float) -> Vector3:
	var u := clampf(x / HALF_SPAN, -1.0, 1.0)
	var arc := cos(u * PI * 0.5)
	var y := TIP_Y + (CENTER_Y - TIP_Y) * arc
	var chord := TIP_CHORD + (CENTER_CHORD - TIP_CHORD) * arc
	y += 0.10 * (1.0 - zc * zc)
	return Vector3(x, y, zc * chord)


func _line(a: Vector3, b: Vector3, mat: Material, thickness := 0.025) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(thickness, thickness, a.distance_to(b))
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dir := (b - a).normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5)
	add_child(mi)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	return m
