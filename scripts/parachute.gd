extends Node3D
## Parachute canopy, rim band and suspension lines. Opens with a short
## scale animation and sways gently while active.

var _canopy_mat: StandardMaterial3D
var _stripe_mat: StandardMaterial3D

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
	_canopy_mat.emission_enabled = true
	_canopy_mat.emission = Color(0.20, 0.45, 0.85)
	_canopy_mat.emission_energy_multiplier = 0.35
	_stripe_mat = _mat(Color(0.95, 0.95, 0.95))

	var sphere := SphereMesh.new()
	sphere.radius = 1.55
	sphere.height = 1.7
	sphere.radial_segments = 14
	sphere.rings = 7
	sphere.is_hemisphere = true

	var canopy := MeshInstance3D.new()
	canopy.mesh = sphere
	canopy.material_override = _canopy_mat
	canopy.position = Vector3(0, 3.25, 0)
	canopy.scale = Vector3(1.15, 0.6, 1.15)
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(canopy)

	var ring := CylinderMesh.new()
	ring.top_radius = 1.80
	ring.bottom_radius = 1.80
	ring.height = 0.12
	ring.radial_segments = 20
	ring.rings = 1
	ring.cap_top = false
	ring.cap_bottom = false

	var rim := MeshInstance3D.new()
	rim.mesh = ring
	rim.material_override = _stripe_mat
	rim.position = Vector3(0, 3.22, 0)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)

	for i in range(6):
		var a := TAU * float(i) / 6.0
		var top := Vector3(cos(a) * 1.72, 3.20, sin(a) * 1.72)
		var bottom := Vector3(cos(a) * 0.18, 1.35, sin(a) * 0.18)
		_line(top, bottom)


func _line(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var box := BoxMesh.new()
	box.size = Vector3(0.025, 0.025, length)

	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = _stripe_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var dir := (b - a).normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	return m
