extends Node3D
## Blocky low-poly character with a code-driven run cycle and aim pose.
## Static body parts are merged into a few meshes to keep draw calls low.

var _shirt_mat: StandardMaterial3D
var _vest_mat: StandardMaterial3D
var _pants_mat: StandardMaterial3D
var _skin_mat: StandardMaterial3D
var _skin: Dictionary = {}

var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _phase := 0.0
var _aim := 0.0


func _ready() -> void:
	_build()
	set_skin(Skins.player_skin())


func set_skin(skin: Dictionary) -> void:
	_skin = skin
	if _shirt_mat == null:
		return
	_shirt_mat.albedo_color = skin["shirt"]
	_vest_mat.albedo_color = skin["vest"]
	_pants_mat.albedo_color = skin["pants"]
	_skin_mat.albedo_color = skin["skin"]


func flash() -> void:
	if _shirt_mat == null:
		return
	var base: Color = _skin.get("shirt", Color.WHITE)
	_shirt_mat.albedo_color = base.lerp(Color.WHITE, 0.8)
	var tw := create_tween()
	tw.tween_property(_shirt_mat, "albedo_color", base, 0.12)


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

func _build() -> void:
	_shirt_mat = _mat(Color(0.16, 0.30, 0.58))
	_vest_mat = _mat(Color(0.08, 0.10, 0.15))
	_pants_mat = _mat(Color(0.12, 0.16, 0.24))
	_skin_mat = _mat(Color(0.86, 0.72, 0.57))

	# torso, helmet, shoulder pads, backpack
	_merge([
		{"size": Vector3(0.46, 0.40, 0.28), "pos": Vector3(0, 1.24, 0)},
		{"size": Vector3(0.40, 0.22, 0.26), "pos": Vector3(0, 0.98, 0)},
		{"size": Vector3(0.30, 0.10, 0.30), "pos": Vector3(0, 1.74, 0)},
		{"size": Vector3(0.16, 0.10, 0.21), "pos": Vector3(-0.33, 1.43, 0)},
		{"size": Vector3(0.16, 0.10, 0.21), "pos": Vector3(0.33, 1.43, 0)},
		{"size": Vector3(0.34, 0.36, 0.16), "pos": Vector3(0, 1.18, 0.23)},
	], _shirt_mat)

	# vest, belt, visor
	_merge([
		{"size": Vector3(0.50, 0.30, 0.32), "pos": Vector3(0, 1.26, 0)},
		{"size": Vector3(0.45, 0.07, 0.30), "pos": Vector3(0, 0.88, 0)},
		{"size": Vector3(0.22, 0.05, 0.02), "pos": Vector3(0, 1.62, -0.14)},
	], _vest_mat)

	# head
	_merge([{"size": Vector3(0.26, 0.26, 0.26), "pos": Vector3(0, 1.60, 0)}], _skin_mat)

	# arms: upper arm + glove
	_arm_l = _pivot(Vector3(-0.31, 1.37, 0))
	_merge([{"size": Vector3(0.12, 0.42, 0.12), "pos": Vector3(0, -0.21, 0)}], _shirt_mat, _arm_l)
	_merge([{"size": Vector3(0.13, 0.10, 0.13), "pos": Vector3(0, -0.45, 0)}], _vest_mat, _arm_l)

	_arm_r = _pivot(Vector3(0.31, 1.37, 0))
	_merge([{"size": Vector3(0.12, 0.42, 0.12), "pos": Vector3(0, -0.21, 0)}], _shirt_mat, _arm_r)
	_merge([{"size": Vector3(0.13, 0.10, 0.13), "pos": Vector3(0, -0.45, 0)}], _vest_mat, _arm_r)

	# rifle in the right hand
	_merge([
		{"size": Vector3(0.08, 0.52, 0.10), "pos": Vector3(0, -0.56, 0)},
		{"size": Vector3(0.06, 0.30, 0.06), "pos": Vector3(0, -0.74, 0)},
		{"size": Vector3(0.13, 0.09, 0.26), "pos": Vector3(0, -0.44, -0.13)},
	], _vest_mat, _arm_r)

	# legs: pants + boot
	_leg_l = _pivot(Vector3(-0.13, 0.82, 0))
	_merge([{"size": Vector3(0.16, 0.62, 0.18), "pos": Vector3(0, -0.31, 0)}], _pants_mat, _leg_l)
	_merge([{"size": Vector3(0.17, 0.14, 0.22), "pos": Vector3(0, -0.68, -0.02)}], _vest_mat, _leg_l)

	_leg_r = _pivot(Vector3(0.13, 0.82, 0))
	_merge([{"size": Vector3(0.16, 0.62, 0.18), "pos": Vector3(0, -0.31, 0)}], _pants_mat, _leg_r)
	_merge([{"size": Vector3(0.17, 0.14, 0.22), "pos": Vector3(0, -0.68, -0.02)}], _vest_mat, _leg_r)


# --------------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.82
	return m


func _merge(parts: Array, mat: StandardMaterial3D, parent: Node3D = null) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var bm := BoxMesh.new()
		bm.size = p["size"]
		st.append_from(bm, 0, Transform3D(Basis(), p["pos"]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
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
