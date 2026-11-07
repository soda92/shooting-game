extends CharacterBody3D
## First/third person player: drop-in, movement, hitscan shooting, health.

signal died
signal landed
signal damaged(amount: float)
signal hit_confirmed
signal weapon_changed(id: String)
signal healed(amount: float)
signal scan_started

enum State { DROP, PLAY, DEAD }

const WALK := 6.0
const SPRINT := 9.5
const AIM_WALK := 3.6
const JUMP_V := 6.8
const GRAVITY := 20.0
const LOOK_SENS := 0.0032
const FREE_FALL_TIME := 2.6
const MAX_MEDKITS := 3
const MEDKIT_HEAL := 40.0
const SCAN_TIME := 6.0
const SCAN_CD := 18.0

var world
var game

var state := State.DROP
var health := 100.0
var max_health := 100.0
var weapon_id := "rifle"
var mag := 30
var reserve := 150
var medkits := 0
var scan_t := 0.0
var scan_cd := 0.0

var pitch := -0.10
var _fire_cd := 0.0
var _reload_t := 0.0
var _reloading := false
var _drop_t := 0.0
var _fov := 72.0
var _tracer_mat: StandardMaterial3D
var _hurt_cd := 0.0
var _step_t := 0.0

@onready var spring: SpringArm3D = $Pivot/SpringArm
@onready var cam: Camera3D = $Pivot/SpringArm/Camera
@onready var pivot: Node3D = $Pivot
@onready var muzzle: Marker3D = $Muzzle
@onready var visual = $Visual


func _ready() -> void:
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visual.set_skin(Skins.player_skin())
	_apply_weapon(weapon_id)
	spring.rotation.x = pitch


func setup(w: Node3D, g: Node) -> void:
	world = w
	game = g


func is_alive() -> bool:
	return state != State.DEAD and health > 0.0


# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	var look := InputState.consume_look()
	if state == State.PLAY and not InputState.locked:
		var sens := LOOK_SENS * (0.55 if InputState.aim else 1.0)
		rotate_y(-look.x * sens)
		pitch = clampf(pitch - look.y * sens, -0.95, 0.55)
		spring.rotation.x = pitch

	var fp := InputState.first_person and state == State.PLAY
	var ads := InputState.aim and state == State.PLAY

	var target_fov := 72.0
	if ads:
		if fp:
			target_fov = 30.0 if weapon_id == "sniper" else 46.0
		else:
			target_fov = 38.0 if weapon_id == "sniper" else 50.0
	_fov = lerpf(_fov, target_fov, 1.0 - exp(-9.0 * delta))
	cam.fov = _fov

	# First-person (aiming or not) puts the camera at the head and hides the
	# body. Third-person ADS pulls into a tight over-the-shoulder view.
	var follow := 1.0 - exp(-16.0 * delta)
	var arm_target := 0.40 if fp else (3.0 if ads else 4.2)
	var side_target := 0.0 if fp else (0.80 if ads else 0.55)
	spring.spring_length = lerpf(spring.spring_length, arm_target, follow)
	pivot.position.x = lerpf(pivot.position.x, side_target, follow)
	visual.visible = not fp

	scan_t = maxf(0.0, scan_t - delta)
	scan_cd = maxf(0.0, scan_cd - delta)
	_hurt_cd = maxf(0.0, _hurt_cd - delta)
	InputState.medkit_count = medkits
	InputState.scan_cd = scan_cd

	var planar := 0.0
	if state == State.PLAY:
		planar = Vector2(velocity.x, velocity.z).length()
	visual.tick(delta, planar, InputState.aim and state == State.PLAY and not InputState.locked)

	if state != State.PLAY or InputState.locked:
		return

	_fire_cd = maxf(0.0, _fire_cd - delta)

	if InputState.consume_medkit():
		use_medkit()
	if InputState.consume_scan():
		_activate_scan()

	if InputState.consume_reload():
		_start_reload()

	if _reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			_finish_reload()

	if InputState.fire and _fire_cd <= 0.0 and not _reloading:
		_shoot()


func _physics_process(delta: float) -> void:
	match state:
		State.DROP:
			_process_drop(delta)
		State.PLAY:
			_process_play(delta)
		State.DEAD:
			if not is_on_floor():
				velocity.y -= GRAVITY * delta
			move_and_slide()


func _process_drop(delta: float) -> void:
	_drop_t += delta
	velocity.y = -24.0 if _drop_t < FREE_FALL_TIME else -7.0

	var input := InputState.move
	var dir := global_transform.basis.x * input.x + global_transform.basis.z * -input.y
	dir.y = 0.0
	dir = dir.limit_length(1.0)
	velocity.x = dir.x * 9.0
	velocity.z = dir.z * 9.0
	move_and_slide()

	var ground: float = world.height_at(global_position.x, global_position.z) + 1.0
	if global_position.y <= ground or is_on_floor():
		global_position.y = maxf(ground, global_position.y)
		velocity = Vector3.ZERO
		state = State.PLAY
		landed.emit()


func _process_play(delta: float) -> void:
	var input := InputState.move
	var dir := global_transform.basis.x * input.x + global_transform.basis.z * -input.y
	dir.y = 0.0
	dir = dir.limit_length(1.0)

	var speed := WALK
	if InputState.aim:
		speed = AIM_WALK
	elif InputState.sprint and input.y > 0.25:
		speed = SPRINT

	if world != null and world.height_at(global_position.x, global_position.z) < -0.6:
		speed *= 0.45
		if global_position.y < 0.9:
			velocity.y = maxf(velocity.y, 3.5)

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if is_on_floor() and dir.length() > 0.15:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.30 if InputState.sprint else 0.44
			Sfx.footstep(-18.0)

	var want_jump := InputState.consume_jump()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif want_jump:
		velocity.y = JUMP_V

	move_and_slide()


func _shoot() -> void:
	var def := Weapons.get_def(weapon_id)
	if mag <= 0:
		Sfx.play("empty", -8.0)
		_start_reload()
		return

	mag -= 1
	Sfx.play("shot_" + weapon_id, -2.0, randf_range(0.95, 1.06))
	_fire_cd = Weapons.shot_interval(weapon_id)

	var spray := deg_to_rad(float(def["spread_deg"]))
	var origin := cam.global_position
	var basis := cam.global_basis
	var fwd := -basis.z
	var pellets := int(def["pellets"])
	var base_dir := _aim_assist(origin, fwd)

	for i in range(pellets):
		var dir := (base_dir + basis.x * randf_range(-spray, spray) + basis.y * randf_range(-spray, spray)).normalized()
		var to := origin + dir * float(def["range"])
		var params := PhysicsRayQueryParameters3D.create(origin, to, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(params)
		if not hit.is_empty():
			to = hit["position"]
			var c: Object = hit["collider"]
			if c != null and c.has_method("take_damage"):
				c.take_damage(float(def["damage"]), self)
				hit_confirmed.emit()
		if pellets == 1 or i < 4:
			_spawn_tracer(muzzle.global_position, to)

	# small recoil kick
	pitch = clampf(pitch + deg_to_rad(0.35), -0.95, 0.55)
	spring.rotation.x = pitch


func _aim_assist(origin: Vector3, dir: Vector3) -> Vector3:
	var best: Node3D = null
	var best_dot := cos(deg_to_rad(3.5))
	for n in get_tree().get_nodes_in_group("combatants"):
		if n == self:
			continue
		if not n.has_method("is_alive") or not n.is_alive():
			continue
		var aim_point: Vector3 = n.global_position + Vector3(0.0, 1.0, 0.0)
		var to: Vector3 = aim_point - origin
		var dist: float = to.length()
		if dist < 1.0 or dist > 90.0:
			continue
		var dot: float = dir.dot(to / dist)
		if dot <= best_dot:
			continue
		var q := PhysicsRayQueryParameters3D.create(origin, aim_point, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or hit["collider"] == n:
			best_dot = dot
			best = n
	if best == null:
		return dir
	return (best.global_position + Vector3(0.0, 1.0, 0.0) - origin).normalized()


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.5:
		return
	if _tracer_mat == null:
		_tracer_mat = StandardMaterial3D.new()
		_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_mat.albedo_color = Color(1.0, 0.86, 0.45, 0.9)
		_tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var box := BoxMesh.new()
	box.size = Vector3(0.035, 0.035, dist)

	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = _tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)


func _start_reload() -> void:
	if _reloading:
		return
	var def := Weapons.get_def(weapon_id)
	if mag >= int(def["mag"]) or reserve <= 0:
		return
	_reloading = true
	_reload_t = float(def["reload"])
	Sfx.play("reload", -5.0, randf_range(0.95, 1.05))


func _finish_reload() -> void:
	var def := Weapons.get_def(weapon_id)
	var need := int(def["mag"]) - mag
	var take := mini(need, reserve)
	mag += take
	reserve -= take
	_reloading = false


func _apply_weapon(id: String) -> void:
	var def := Weapons.get_def(id)
	weapon_id = id
	mag = int(def["mag"])
	reserve = int(def["reserve"])
	_reloading = false
	_reload_t = 0.0


func give_weapon(id: String) -> void:
	if not Weapons.DEFS.has(id):
		return
	_apply_weapon(id)
	Sfx.play("pickup", -4.0)
	weapon_changed.emit(id)


func add_medkit() -> bool:
	if medkits >= MAX_MEDKITS:
		return false
	medkits += 1
	return true


func use_medkit() -> void:
	if medkits <= 0 or health >= max_health or state != State.PLAY:
		return
	medkits -= 1
	health = minf(max_health, health + MEDKIT_HEAL)
	Sfx.play("heal", -4.0)
	healed.emit(MEDKIT_HEAL)


func _activate_scan() -> void:
	if scan_cd > 0.0 or state != State.PLAY:
		return
	scan_t = SCAN_TIME
	scan_cd = SCAN_CD
	Sfx.play("scan", -4.0)
	scan_started.emit()


func take_damage(amount: float, _attacker: Node = null) -> void:
	if state == State.DEAD:
		return
	health = maxf(0.0, health - amount)
	if _hurt_cd <= 0.0:
		_hurt_cd = 0.14
		Sfx.play("hurt", -7.0, randf_range(0.9, 1.1))
	damaged.emit(amount)
	if health <= 0.0:
		_die()


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	visual.visible = true
	InputState.locked = true
	InputState.clear()
	Sfx.play("death", -2.0)
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", PI * 0.5, 0.45)
	died.emit()
