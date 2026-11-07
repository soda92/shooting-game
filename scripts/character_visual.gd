extends Node3D
## Low-poly character with two body styles:
##   "soldier" - tactical blocky soldier
##   "anime"   - chibi anime outfit (big head, twin tails, skirt, thigh-highs)
## Static parts are merged into a few meshes to keep draw calls low.

var _mats: Dictionary = {}
var _skin: Dictionary = {}
var _style := ""

var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _tail_l: Node3D
var _tail_r: Node3D
var _phase := 0.0
var _aim := 0.0

var _model_root: Node3D
var _model_path := ""
var _anim: AnimationPlayer
var _anim_names: PackedStringArray


func _ready() -> void:
	set_skin(Skins.player_skin())


func set_skin(skin: Dictionary) -> void:
	_skin = skin
	var style: String = String(skin.get("style", "soldier"))

	if style == "model":
		var path := String(skin.get("model", ""))
		if _style != "model" or _model_path != path:
			_rebuild("model")
			_model_path = path
			_build_model(path)
		return

	if style != _style:
		_rebuild(style)
	else:
		_recolor()


func flash() -> void:
	var key := "blouse" if _style == "anime" else "shirt"
	if not _mats.has(key):
		return
	var mat: StandardMaterial3D = _mats[key]
	var base: Color = _skin.get(key, Color.WHITE)
	mat.albedo_color = base.lerp(Color.WHITE, 0.8)
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color", base, 0.12)


func tick(delta: float, speed: float, aiming: bool) -> void:
	if _style == "model":
		_tick_model(delta, speed, aiming)
		return

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

	if _tail_l != null:
		var sway := sin(_phase * 0.55) * 0.14 + move * 0.18
		_tail_l.rotation.z = sway
		_tail_r.rotation.z = -sway
		_tail_l.rotation.x = -move * 0.25
		_tail_r.rotation.x = -move * 0.25

	if move < 0.05:
		position.y = sin(_phase * 0.5) * 0.012
	else:
		position.y = abs(sin(_phase)) * 0.03


# --------------------------------------------------------------------------

func _rebuild(style: String) -> void:
	for c in get_children():
		c.free()
	_mats.clear()
	_arm_l = null
	_arm_r = null
	_leg_l = null
	_leg_r = null
	_tail_l = null
	_tail_r = null
	_model_root = null
	_anim = null
	_anim_names = PackedStringArray()
	_style = style

	if style == "anime":
		_build_anime()
	elif style == "model":
		pass
	else:
		_build_soldier()

	if style != "model":
		_recolor()


func _recolor() -> void:
	for role in _mats:
		if _skin.has(role):
			_mats[role].albedo_color = _skin[role]


func _build_soldier() -> void:
	var shirt := _mat_role("shirt", Color(0.16, 0.30, 0.58))
	var vest := _mat_role("vest", Color(0.08, 0.10, 0.15))
	var pants := _mat_role("pants", Color(0.12, 0.16, 0.24))
	var skin := _mat_role("skin", Color(0.86, 0.72, 0.57))

	_merge([
		{"size": Vector3(0.46, 0.40, 0.28), "pos": Vector3(0, 1.24, 0)},
		{"size": Vector3(0.40, 0.22, 0.26), "pos": Vector3(0, 0.98, 0)},
		{"size": Vector3(0.30, 0.10, 0.30), "pos": Vector3(0, 1.74, 0)},
		{"size": Vector3(0.16, 0.10, 0.21), "pos": Vector3(-0.33, 1.43, 0)},
		{"size": Vector3(0.16, 0.10, 0.21), "pos": Vector3(0.33, 1.43, 0)},
		{"size": Vector3(0.34, 0.36, 0.16), "pos": Vector3(0, 1.18, 0.23)},
	], shirt)

	_merge([
		{"size": Vector3(0.50, 0.30, 0.32), "pos": Vector3(0, 1.26, 0)},
		{"size": Vector3(0.45, 0.07, 0.30), "pos": Vector3(0, 0.88, 0)},
		{"size": Vector3(0.22, 0.05, 0.02), "pos": Vector3(0, 1.62, -0.14)},
	], vest)

	_merge([{"size": Vector3(0.26, 0.26, 0.26), "pos": Vector3(0, 1.60, 0)}], skin)

	_arm_l = _pivot(Vector3(-0.31, 1.37, 0))
	_merge([{"size": Vector3(0.12, 0.42, 0.12), "pos": Vector3(0, -0.21, 0)}], shirt, _arm_l)
	_merge([{"size": Vector3(0.13, 0.10, 0.13), "pos": Vector3(0, -0.45, 0)}], vest, _arm_l)

	_arm_r = _pivot(Vector3(0.31, 1.37, 0))
	_merge([{"size": Vector3(0.12, 0.42, 0.12), "pos": Vector3(0, -0.21, 0)}], shirt, _arm_r)
	_merge([{"size": Vector3(0.13, 0.10, 0.13), "pos": Vector3(0, -0.45, 0)}], vest, _arm_r)
	_merge(_rifle_parts(), vest, _arm_r)

	_leg_l = _pivot(Vector3(-0.13, 0.82, 0))
	_merge([{"size": Vector3(0.16, 0.62, 0.18), "pos": Vector3(0, -0.31, 0)}], pants, _leg_l)
	_merge([{"size": Vector3(0.17, 0.14, 0.22), "pos": Vector3(0, -0.68, -0.02)}], vest, _leg_l)

	_leg_r = _pivot(Vector3(0.13, 0.82, 0))
	_merge([{"size": Vector3(0.16, 0.62, 0.18), "pos": Vector3(0, -0.31, 0)}], pants, _leg_r)
	_merge([{"size": Vector3(0.17, 0.14, 0.22), "pos": Vector3(0, -0.68, -0.02)}], vest, _leg_r)


func _build_anime() -> void:
	var hair := _mat_role("hair", Color(1.0, 0.55, 0.72))
	var blouse := _mat_role("blouse", Color(0.95, 0.95, 0.97))
	var skirt := _mat_role("skirt", Color(0.16, 0.18, 0.32))
	var socks := _mat_role("socks", Color(0.12, 0.12, 0.16))
	var skin := _mat_role("skin", Color(0.98, 0.84, 0.76))
	var shoe := _mat_role("shoe", Color(0.95, 0.95, 0.97))
	var eye := _mat_role("eye", Color(0.10, 0.35, 0.55))

	# big chibi head
	_merge([{"size": Vector3(0.34, 0.32, 0.30), "pos": Vector3(0, 1.56, 0)}], skin)

	# eyes on the front face
	_merge([
		{"size": Vector3(0.07, 0.10, 0.02), "pos": Vector3(-0.085, 1.57, -0.155)},
		{"size": Vector3(0.07, 0.10, 0.02), "pos": Vector3(0.085, 1.57, -0.155)},
	], eye)

	# hair cap + bangs + side locks
	_merge([
		{"size": Vector3(0.38, 0.14, 0.34), "pos": Vector3(0, 1.72, 0)},
		{"size": Vector3(0.36, 0.08, 0.08), "pos": Vector3(0, 1.64, -0.16)},
		{"size": Vector3(0.08, 0.24, 0.30), "pos": Vector3(-0.20, 1.57, 0)},
		{"size": Vector3(0.08, 0.24, 0.30), "pos": Vector3(0.20, 1.57, 0)},
	], hair)

	# slim torso
	_merge([{"size": Vector3(0.34, 0.40, 0.22), "pos": Vector3(0, 1.21, 0)}], blouse)

	# skirt
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.20
	cyl.bottom_radius = 0.35
	cyl.height = 0.24
	cyl.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = skirt
	mi.position = Vector3(0, 0.95, 0)
	add_child(mi)

	# slim arms
	_arm_l = _pivot(Vector3(-0.23, 1.35, 0))
	_merge([{"size": Vector3(0.09, 0.40, 0.09), "pos": Vector3(0, -0.20, 0)}], blouse, _arm_l)
	_arm_r = _pivot(Vector3(0.23, 1.35, 0))
	_merge([{"size": Vector3(0.09, 0.40, 0.09), "pos": Vector3(0, -0.20, 0)}], blouse, _arm_r)
	_merge(_rifle_parts(), shoe, _arm_r)

	# thigh-high socks + shoes
	_leg_l = _pivot(Vector3(-0.10, 0.84, 0))
	_merge([{"size": Vector3(0.12, 0.64, 0.14), "pos": Vector3(0, -0.32, 0)}], socks, _leg_l)
	_merge([{"size": Vector3(0.14, 0.12, 0.20), "pos": Vector3(0, -0.70, -0.02)}], shoe, _leg_l)

	_leg_r = _pivot(Vector3(0.10, 0.84, 0))
	_merge([{"size": Vector3(0.12, 0.64, 0.14), "pos": Vector3(0, -0.32, 0)}], socks, _leg_r)
	_merge([{"size": Vector3(0.14, 0.12, 0.20), "pos": Vector3(0, -0.70, -0.02)}], shoe, _leg_r)

	# twin tails
	_tail_l = _pivot(Vector3(-0.19, 1.70, 0.13))
	_merge([{"size": Vector3(0.10, 0.60, 0.10), "pos": Vector3(0, -0.30, 0)}], hair, _tail_l)
	_tail_r = _pivot(Vector3(0.19, 1.70, 0.13))
	_merge([{"size": Vector3(0.10, 0.60, 0.10), "pos": Vector3(0, -0.30, 0)}], hair, _tail_r)


func _rifle_parts() -> Array:
	return [
		{"size": Vector3(0.08, 0.50, 0.10), "pos": Vector3(0, -0.56, 0)},
		{"size": Vector3(0.06, 0.28, 0.06), "pos": Vector3(0, -0.73, 0)},
		{"size": Vector3(0.12, 0.09, 0.26), "pos": Vector3(0, -0.44, -0.13)},
	]


# --------------------------------------------------------------------------
# Imported model skins (.glb / .gltf)

func _build_model(path: String) -> void:
	if not ResourceLoader.exists(path):
		_style = ""
		_rebuild("soldier")
		return
	var packed: PackedScene = load(path)
	if packed == null:
		_style = ""
		_rebuild("soldier")
		return

	var inst := packed.instantiate()
	_model_root = Node3D.new()
	add_child(_model_root)
	_model_root.add_child(inst)

	var meshes: Array = []
	_collect_meshes(inst, meshes)
	for mi in meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var aabb := _node_aabb(inst)
	if aabb.size.y > 0.01:
		var s := 1.75 / aabb.size.y
		_model_root.scale = Vector3(s, s, s)
		_model_root.position = Vector3(
			-aabb.get_center().x * s,
			-aabb.position.y * s,
			-aabb.get_center().z * s
		)

	_model_root.rotation.y = float(_skin.get("model_yaw", 0.0))

	_anim = _find_anim_player(inst)
	if _anim != null:
		_anim_names = _anim.get_animation_list()
		_play_anim("idle", 0.0)


func _tick_model(delta: float, speed: float, aiming: bool) -> void:
	_aim = lerpf(_aim, 1.0 if aiming else 0.0, 1.0 - exp(-10.0 * delta))
	if _anim == null:
		return
	var want := "idle"
	if _aim > 0.6:
		want = "aim"
	elif speed > 0.4:
		want = "run"
	_play_anim(want, 0.12)
	_anim.speed_scale = clampf(speed / 4.5, 0.7, 1.6) if want == "run" else 1.0


func _play_anim(prefix: String, blend: float) -> void:
	if _anim == null:
		return
	var found := ""
	for n in _anim_names:
		if String(n).to_lower().contains(prefix):
			found = n
			break
	if found == "" and prefix == "aim":
		for n in _anim_names:
			if String(n).to_lower().contains("idle"):
				found = n
				break
	if found == "" and prefix == "run":
		for n in _anim_names:
			if String(n).to_lower().contains("walk"):
				found = n
				break
	if found == "":
		return
	if _anim.current_animation != found:
		_anim.play(found, blend)


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r != null:
			return r
	return null


func _node_aabb(root: Node) -> AABB:
	var meshes: Array = []
	_collect_meshes(root, meshes)
	var out := AABB()
	var first := true
	for mi in meshes:
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		var a: AABB = xf * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


func _collect_meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)


# --------------------------------------------------------------------------

func _mat_role(role: String, c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.82
	_mats[role] = m
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
