extends Node3D
## Blocky low-poly character built from primitives, with a code-driven
## run cycle and a simple aim pose. No external art assets required.

var _body_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _skin_mat: StandardMaterial3D
var _base_color := Color(0.20, 0.45, 0.85)

var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _phase := 0.0
var _aim := 0.0


func _ready() -> void:
	_build()


func set_primary(c: Color) -> void:
	_base_color = c
	if _body_mat != null:
		_body_mat.albedo_color = c


func flash() -> void:
	if _body_mat == null:
		return
	_body_mat.albedo_color = _base_color.lerp(Color(1, 1, 1), 0.85)
	var tw := create_tween()
	tw.tween_property(_body_mat, "albedo_color", _base_color, 0.12)


func _build() -> void:
	_body_mat = _mat(_base_color)
	_dark_mat = _mat(Color(0.13, 0.15, 0.19))
	_skin_mat = _mat(Color(0.85, 0.70, 0.55))

	# torso + chest rig
	_box(Vector3(0.46, 0.60, 0.28), Vector3(0, 1.15, 0), _body_mat)
	_box(Vector3(0.50, 0.12, 0.33), Vector3(0, 1.31, 0), _dark_mat)

	# head + helmet
	_box(Vector3(0.26, 0.26, 0.26), Vector3(0, 1.60, 0), _skin_mat)
	_box(Vector3(0.30, 0.10, 0.30), Vector3(0, 1.74, 0), _body_mat)

	# arms (pivot at the shoulder)
	_arm_l = _pivot(Vector3(-0.31, 1.37, 0))
	_box(Vector3(0.12, 0.48, 0.12), Vector3(0, -0.24, 0), _body_mat, _arm_l)
	_arm_r = _pivot(Vector3(0.31, 1.37, 0))
	_box(Vector3(0.12, 0.48, 0.12), Vector3(0, -0.24, 0), _body_mat, _arm_r)

	# rifle in the right hand
	_box(Vector3(0.08, 0.52, 0.10), Vector3(0, -0.55, 0), _dark_mat, _arm_r)
	_box(Vector3(0.13, 0.09, 0.26), Vector3(0, -0.44, -0.13), _dark_mat, _arm_r)

	# legs (pivot at the hip)
	_leg_l = _pivot(Vector3(-0.13, 0.82, 0))
	_box(Vector3(0.16, 0.74, 0.18), Vector3(0, -0.37, 0), _dark_mat, _leg_l)
	_leg_r = _pivot(Vector3(0.13, 0.82, 0))
	_box(Vector3(0.16, 0.74, 0.18), Vector3(0, -0.37, 0), _dark_mat, _leg_r)


func tick(delta: float, speed: float, aiming: bool) -> void:
	var move := clampf(speed / 6.0, 0.0, 1.0)
	_phase += delta * (3.0 + speed * 1.3)
	var s := sin(_phase) * 0.75 * move

	_leg_l.rotation.x = s
	_leg_r.rotation.x = -s

	var target_aim := 1.0 if aiming else 0.0
	_aim = lerpf(_aim, target_aim, 1.0 - exp(-12.0 * delta))

	var swing := -s * 0.85
	_arm_r.rotation.x = lerpf(swing, 1.45, _aim)
	_arm_l.rotation.x = lerpf(-swing, 1.33, _aim)
	_arm_l.rotation.z = lerpf(0.0, 0.35, _aim)
	_arm_r.rotation.z = lerpf(0.0, -0.10, _aim)

	if move < 0.05:
		position.y = sin(_phase * 0.5) * 0.012
	else:
		position.y = abs(sin(_phase)) * 0.03


# --------------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.82
	return m


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D, parent: Node3D = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if parent != null:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi


func _pivot(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	return n
