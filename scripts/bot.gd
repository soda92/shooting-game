extends CharacterBody3D
## Simple battle-royale bot: wanders, picks the nearest visible enemy,
## closes to a comfortable range, strafes and shoots.

signal died(bot: Node)

const GRAVITY := 20.0
const SPEED := 4.4
const DAMAGE := 8.0
const FIRE_INTERVAL := 0.85
const RANGE := 42.0

var world
var game
var bot_name := "Bot"
var weapon_id := "rifle"
var health := 100.0
var max_health := 100.0
var alive := true
var last_attacker: Node = null
var target: Node3D = null

var _retarget := 0.0
var _fire_cd := 0.0
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _strafe := 1.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO

@onready var visual = $Visual


func _ready() -> void:
	_strafe = 1.0 if randf() > 0.5 else -1.0
	_fire_cd = randf_range(0.2, 1.2)
	weapon_id = Weapons.ORDER[randi() % Weapons.ORDER.size()]
	visual.set_skin(Skins.random_bot_skin())
	_last_pos = global_position


func setup(w: Node3D, g: Node) -> void:
	world = w
	game = g


func is_alive() -> bool:
	return alive and health > 0.0


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = randf_range(0.45, 0.9)
		_pick_target()

	var desired := Vector3.ZERO
	if _has_target():
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.05:
			var dir := to / dist
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
			if dist > 18.0:
				desired = dir
			elif dist < 10.0:
				desired = -dir
			else:
				desired = dir.rotated(Vector3.UP, _strafe * PI * 0.5) * 0.75

		if dist < RANGE and _can_see(target):
			_fire_cd -= delta
			if _fire_cd <= 0.0:
				_shoot(target)
	else:
		_wander_t -= delta
		if _wander_t <= 0.0 or global_position.distance_to(_wander) < 3.0:
			_pick_wander()
		var wdir := _wander - global_position
		wdir.y = 0.0
		if wdir.length() > 0.5:
			desired = wdir.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), 4.0 * delta)

	if world != null and world.height_at(global_position.x, global_position.z) < 0.0:
		var back := -Vector3(global_position.x, 0.0, global_position.z).normalized()
		desired += back * 1.5

	# Rotate toward the safe zone instead of dying outside it.
	if game != null and game.zone != null:
		var zone = game.zone
		var flat := Vector2(global_position.x - zone.center.x, global_position.z - zone.center.z)
		var near_edge: bool = flat.length() > zone.radius - 15.0
		if not zone.is_inside(global_position) or (zone.shrinking and near_edge):
			var to_c := Vector3(zone.center.x - global_position.x, 0.0, zone.center.z - global_position.z)
			if to_c.length() > 0.5:
				desired = to_c.normalized()
				rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), 6.0 * delta)

	velocity.x = desired.x * SPEED
	velocity.z = desired.z * SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	_stuck_t += delta
	if _stuck_t >= 0.7:
		if global_position.distance_to(_last_pos) < 0.4:
			target = null
			_retarget = 1.2
			_strafe = -_strafe
			_pick_wander()
		_last_pos = global_position
		_stuck_t = 0.0

	visual.tick(delta, Vector2(velocity.x, velocity.z).length(), _has_target())


# --------------------------------------------------------------------------

func _has_target() -> bool:
	return is_instance_valid(target) and target.has_method("is_alive") and target.is_alive()


func _pick_target() -> void:
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("combatants"):
		if n == self:
			continue
		if not n.has_method("is_alive") or not n.is_alive():
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d and d < 95.0 and _can_see(n):
			best = n
			best_d = d
	target = best


func _can_see(t: Node3D) -> bool:
	var from := global_position + Vector3(0.0, 1.5, 0.0)
	var to := t.global_position + Vector3(0.0, 1.2, 0.0)
	var params := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	return hit.is_empty() or hit["collider"] == t


func _pick_wander() -> void:
	for i in range(14):
		var p := global_position + Vector3(randf_range(-45.0, 45.0), 0.0, randf_range(-45.0, 45.0))
		if world != null and world.is_land(p.x, p.z, 1.2):
			_wander = Vector3(p.x, world.height_at(p.x, p.z), p.z)
			_wander_t = randf_range(6.0, 14.0)
			return
	_wander = global_position
	_wander_t = 4.0


func _shoot(t: Node3D) -> void:
	var def := Weapons.get_def(weapon_id)
	_fire_cd = clampf(60.0 / float(def["rpm"]) * randf_range(1.8, 3.0), 0.5, 1.6)

	var from := global_position + Vector3(0.0, 1.5, 0.0)
	var aim := t.global_position + Vector3(0.0, 1.0, 0.0)
	var dir := (aim - from).normalized()
	var spread := deg_to_rad(float(def["spread_deg"])) * 1.4 + 0.02
	dir = (dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()

	var max_range := minf(RANGE, float(def["range"]))
	var to := from + dir * max_range
	var params := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if not hit.is_empty():
		to = hit["position"]
		var c: Object = hit["collider"]
		if c != null and c.has_method("take_damage"):
			var dmg := float(def["damage"])
			if weapon_id == "shotgun":
				dmg = 16.0
			elif weapon_id == "sniper":
				dmg = 42.0
			if c.has_method("is_alive") and float(hit["position"].y) >= c.global_position.y + 1.45:
				dmg *= 1.8
			c.take_damage(dmg * randf_range(0.85, 1.15), self)

	Sfx.play_at("shot_" + weapon_id, global_position, -7.0, randf_range(0.9, 1.1))
	_spawn_tracer(from, to)


func give_weapon(id: String) -> void:
	if not Weapons.DEFS.has(id):
		return
	weapon_id = id


func get_display_name() -> String:
	return bot_name


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.5:
		return
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, dist)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.5, 0.3, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)


func take_damage(amount: float, attacker: Node = null) -> void:
	if not alive:
		return
	health -= amount
	if attacker != null:
		last_attacker = attacker
	_flash()
	if health <= 0.0:
		_die()


func _flash() -> void:
	visual.flash()


func _die() -> void:
	alive = false
	health = 0.0
	target = null
	collision_layer = 0
	collision_mask = 0
	if game != null and is_instance_valid(game) and randf() < 0.35:
		game.spawn_medkit_at(global_position)
	Sfx.play_at("death", global_position, -4.0, randf_range(0.9, 1.1))
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", PI * 0.5, 0.35)
	tw.tween_interval(1.5)
	tw.tween_callback(queue_free)
