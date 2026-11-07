extends Node3D
## Thrown grenade: arcs under gravity, bounces off geometry and explodes
## after 2.6s with distance falloff and a line-of-sight check.

const RADIUS := 6.0
const GRAVITY := 16.0
const FUSE := 2.6

var velocity := Vector3.ZERO
var world
var thrower

var _t := 0.0
var _done := false


func setup(w, from: Node, initial_velocity: Vector3) -> void:
	world = w
	thrower = from
	velocity = initial_velocity


func _physics_process(delta: float) -> void:
	if _done:
		return

	_t += delta
	velocity.y -= GRAVITY * delta

	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var n: Vector3 = hit["normal"]
		global_position = hit["position"] + n * 0.06
		velocity = velocity.bounce(n) * 0.35
		if velocity.length() < 2.0:
			velocity = Vector3.ZERO
	else:
		global_position = to

	if world != null:
		var gy: float = world.height_at(global_position.x, global_position.z) + 0.08
		if global_position.y <= gy:
			global_position.y = gy
			velocity = velocity.bounce(Vector3.UP) * 0.3
			if velocity.length() < 1.5:
				velocity = Vector3.ZERO

	rotation.z += delta * 8.0
	rotation.x += delta * 5.0

	if _t >= FUSE:
		_explode()


func _explode() -> void:
	_done = true
	var pos := global_position

	for n in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(n) or not n.has_method("is_alive") or not n.is_alive():
			continue
		var d: float = pos.distance_to(n.global_position + Vector3(0, 0.9, 0))
		if d > RADIUS:
			continue
		var q := PhysicsRayQueryParameters3D.create(
			pos, n.global_position + Vector3(0, 1.0, 0), 1, []
		)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] != n:
			continue
		var dmg := 15.0 + 95.0 * (1.0 - d / RADIUS)
		n.take_damage(dmg, thrower)

	_spawn_blast(pos)
	Sfx.play_at("explosion", pos, 0.0)
	queue_free()


func _spawn_blast(pos: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.18, 0.75)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.no_depth_test = true

	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 5.0, 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.15)
	light.light_energy = 7.0
	light.omni_range = 12.0
	get_tree().current_scene.add_child(light)
	light.global_position = pos
	var tw2 := create_tween()
	tw2.tween_property(light, "light_energy", 0.0, 0.3)

	get_tree().create_timer(0.35).timeout.connect(
		func() -> void:
			if is_instance_valid(mi):
				mi.queue_free()
			if is_instance_valid(light):
				light.queue_free()
	)
