extends Node3D
## Match controller: spawns combatants and loot, runs zone damage, win/lose.

const BOT_COUNT := 15
const LOOT_COUNT := 50
const MEDKIT_COUNT := 18
const SCOPE_COUNT := 10
const ARMOR_COUNT := 8
const GRENADE_COUNT := 8
const MEDKIT_SCENE := preload("res://scenes/medkit.tscn")
const SCOPE_SCENE := preload("res://scenes/scope.tscn")
const ARMOR_SCENE := preload("res://scenes/armor.tscn")
const GRENADE_PICKUP_SCENE := preload("res://scenes/grenade_pickup.tscn")
const SCOPE_IDS := ["red_dot", "4x", "8x"]
const TARGET_SCENE := preload("res://scenes/target.tscn")

@onready var world = $World
@onready var zone = $Zone
@onready var hud = $UI/HUD
@onready var touch = $UI/TouchControls
@onready var sun: DirectionalLight3D = $Sun

var player
var bots: Array = []
var alive := 0
var kills := 0
var over := false
var place := 1

var map_scale := 1.0
var bot_count := BOT_COUNT
var loot_count := LOOT_COUNT
var medkit_count := MEDKIT_COUNT
var scope_count := SCOPE_COUNT
var armor_count := ARMOR_COUNT
var grenade_count := GRENADE_COUNT
var spawn_radius := 280.0
var bot_radius := 330.0
var zone_radius := 420.0

var range_mode := false
var target_hits := 0
var spectating := false
var spectate_target: Node3D = null
var spec_cam: Camera3D = null


func _ready() -> void:
	randomize()
	Skins.refresh_models()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	InputState.locked = false
	InputState.clear()

	map_scale = world.map_scale
	bot_count = int(round(BOT_COUNT * map_scale * 0.85))
	loot_count = int(round(LOOT_COUNT * map_scale))
	medkit_count = int(round(MEDKIT_COUNT * map_scale))
	scope_count = int(round(SCOPE_COUNT * map_scale))
	armor_count = int(round(ARMOR_COUNT * map_scale))
	grenade_count = int(round(GRENADE_COUNT * map_scale))
	spawn_radius = world.world_size * 0.31
	bot_radius = world.world_size * 0.37
	zone_radius = world.world_size * 0.466

	range_mode = Meta.mode == "range"
	if range_mode:
		zone.training = range_mode
		zone.reset(999.0)
		zone.get_node("Wall").visible = false
		zone.visible = false
	else:
		zone.reset(zone_radius, map_scale)
	zone.phase_changed.connect(_on_zone_phase)

	_spawn_player()
	if range_mode:
		alive = 1
		_spawn_range_gear()
		_spawn_targets()
	else:
		_spawn_bots()
		_spawn_loot()
		_spawn_medkits()
		_spawn_scopes()
		_spawn_armor()
		_spawn_grenades()

	hud.setup(self)
	hud.set_center("训练场：打靶 / 无限弹药" if range_mode else "从空中选择落点", 2.5)


func _process(delta: float) -> void:
	if spectating:
		_update_spectator(delta)
		hud.update_hud()
		return

	if over:
		return

	if range_mode:
		hud.update_hud()
		return

	if zone.dps > 0.0:
		for n in get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(n) or not n.has_method("is_alive") or not n.is_alive():
				continue
			if not zone.is_inside(n.global_position):
				n.take_damage(zone.dps * delta, null)

	hud.update_hud()


# --------------------------------------------------------------------------

func _spawn_player() -> void:
	var scene: PackedScene = load("res://scenes/player.tscn")
	player = scene.instantiate()
	var p: Vector3 = world.random_open_point(spawn_radius, 40.0 * map_scale)
	player.position = Vector3(p.x, p.y + 120.0, p.z)
	player.rotation.y = randf() * TAU
	add_child(player)
	player.setup(world, self)
	player.died.connect(_on_player_died)
	player.landed.connect(_on_player_landed)
	player.damaged.connect(_on_player_damaged)
	player.hit_confirmed.connect(_on_hit_confirmed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.healed.connect(_on_player_healed)
	player.scan_started.connect(_on_scan_started)
	player.scope_added.connect(_on_scope_added)

	if range_mode:
		player.infinite_ammo = true
		player.spawn_ready(Vector3(p.x, p.y + 1.0, p.z), randf() * TAU)


func _spawn_bots() -> void:
	var scene: PackedScene = load("res://scenes/bot.tscn")
	for i in range(bot_count):
		var b = scene.instantiate()
		var p: Vector3 = world.random_land_point(bot_radius)
		if player != null and Vector2(p.x - player.position.x, p.z - player.position.z).length() < 45.0 * map_scale:
			p = world.random_land_point(bot_radius)
		b.position = Vector3(p.x, p.y + 2.0, p.z)
		b.rotation.y = randf() * TAU
		b.bot_name = "Bot %02d" % (i + 1)
		add_child(b)
		b.setup(world, self)
		b.died.connect(_on_bot_died)
		bots.append(b)
	alive = bots.size() + 1


func _spawn_loot() -> void:
	var scene: PackedScene = load("res://scenes/loot.tscn")
	var spots: Array = world.loot_spots
	for i in range(loot_count):
		var l = scene.instantiate()
		var p: Vector3
		if i < int(loot_count * 0.6) and not spots.is_empty():
			var s: Vector3 = spots[i % spots.size()]
			p = Vector3(s.x + randf_range(-1.2, 1.2), 0.0, s.z + randf_range(-1.2, 1.2))
		else:
			p = world.random_land_point(bot_radius)
		var gy: float = world.height_at(p.x, p.z)
		l.position = Vector3(p.x, gy + 0.9, p.z)
		add_child(l)
		l.setup(Weapons.ORDER[i % Weapons.ORDER.size()])


func _spawn_medkits() -> void:
	var spots: Array = world.loot_spots
	for i in range(medkit_count):
		if i < int(medkit_count * 0.45) and not spots.is_empty():
			var s: Vector3 = spots[(i * 2) % spots.size()]
			spawn_medkit_at(Vector3(s.x + randf_range(-1.0, 1.0), 0.0, s.z + randf_range(-1.0, 1.0)))
		else:
			spawn_medkit_at(world.random_land_point(bot_radius))


func spawn_medkit_at(pos: Vector3) -> void:
	var m = MEDKIT_SCENE.instantiate()
	var y: float = world.height_at(pos.x, pos.z)
	m.position = Vector3(pos.x, y + 0.7, pos.z)
	add_child(m)


func _spawn_scopes() -> void:
	var spots: Array = world.loot_spots
	for i in range(scope_count):
		var p: Vector3
		if not spots.is_empty():
			var s: Vector3 = spots[(i * 3) % spots.size()]
			p = Vector3(s.x + randf_range(-1.5, 1.5), 0.0, s.z + randf_range(-1.5, 1.5))
		else:
			p = world.random_land_point(bot_radius)
		var sc = SCOPE_SCENE.instantiate()
		sc.position = Vector3(p.x, world.height_at(p.x, p.z) + 0.6, p.z)
		add_child(sc)
		sc.setup(SCOPE_IDS[i % SCOPE_IDS.size()])


func _on_scope_added(id: String) -> void:
	hud.set_center("拾取 " + String(Scopes.get_def(id)["name"]), 1.0)


func _pickup_point(spots: Array, i: int) -> Vector3:
	if not spots.is_empty():
		var s: Vector3 = spots[(i * 3) % spots.size()]
		return Vector3(s.x + randf_range(-1.2, 1.2), 0.0, s.z + randf_range(-1.2, 1.2))
	return world.random_land_point(bot_radius)


func _spawn_armor() -> void:
	for i in range(armor_count):
		var p := _pickup_point(world.loot_spots, i)
		var a = ARMOR_SCENE.instantiate()
		a.position = Vector3(p.x, world.height_at(p.x, p.z) + 0.6, p.z)
		add_child(a)


func _spawn_grenades() -> void:
	for i in range(grenade_count):
		var p := _pickup_point(world.loot_spots, i + 2)
		var g = GRENADE_PICKUP_SCENE.instantiate()
		g.position = Vector3(p.x, world.height_at(p.x, p.z) + 0.6, p.z)
		add_child(g)


# --------------------------------------------------------------------------
# Training range
# --------------------------------------------------------------------------

func _spawn_range_gear() -> void:
	var fwd: Vector3 = -player.global_transform.basis.z
	var right: Vector3 = player.global_transform.basis.x
	var base: Vector3 = player.global_position

	var ids := ["rifle", "smg", "shotgun", "sniper"]
	for i in range(4):
		var pos: Vector3 = base + right * 5.0 + fwd * (1.0 + i * 1.7)
		var l = load("res://scenes/loot.tscn").instantiate()
		l.position = Vector3(pos.x, base.y + 0.9, pos.z)
		add_child(l)
		l.setup(ids[i])

	for i in range(3):
		var pos: Vector3 = base - right * 5.0 + fwd * (1.0 + i * 1.7)
		var s = SCOPE_SCENE.instantiate()
		s.position = Vector3(pos.x, base.y + 0.6, pos.z)
		add_child(s)
		s.setup(SCOPE_IDS[i])

	var ap: Vector3 = base + right * 7.5 + fwd * 2.0
	var a = ARMOR_SCENE.instantiate()
	a.position = Vector3(ap.x, base.y + 0.6, ap.z)
	add_child(a)

	for i in range(2):
		var gp: Vector3 = base - right * 7.5 + fwd * (2.0 + i * 1.5)
		var g = GRENADE_PICKUP_SCENE.instantiate()
		g.position = Vector3(gp.x, base.y + 0.6, gp.z)
		add_child(g)

	spawn_medkit_at(base - right * 7.5 + fwd * 5.0)


func _spawn_targets() -> void:
	var fwd: Vector3 = -player.global_transform.basis.z
	var right: Vector3 = player.global_transform.basis.x
	var base: Vector3 = player.global_position

	for i in range(7):
		var pos: Vector3 = base + fwd * (5.0 + (i % 2) * 2.0) + right * ((i - 3) * 2.4 + 0.55)
		var t = TARGET_SCENE.instantiate()
		t.position = Vector3(pos.x, base.y, pos.z)
		add_child(t)
		t.setup(self)
		var to_player: Vector3 = base - pos
		to_player.y = 0.0
		t.rotation.y = atan2(-to_player.x, -to_player.z)


# --------------------------------------------------------------------------
# Spectator
# --------------------------------------------------------------------------

func start_spectate() -> void:
	if not over:
		return
	var cand: Node3D = null
	if is_instance_valid(player) and is_instance_valid(player.last_attacker):
		var k = player.last_attacker
		if k is Node3D and k.has_method("is_alive") and k.is_alive():
			cand = k
	if cand == null:
		cand = _first_alive_bot()
	if cand == null:
		return

	spectate_target = cand
	if spec_cam == null:
		spec_cam = Camera3D.new()
		spec_cam.fov = 70.0
		add_child(spec_cam)
	spec_cam.current = true
	spectating = true
	hud.show_spectate(String(spectate_target.get_display_name()))


func next_spectate() -> void:
	if not spectating:
		return
	var alive_list: Array = []
	for b in bots:
		if is_instance_valid(b) and b.is_alive():
			alive_list.append(b)
	if alive_list.is_empty():
		return
	var idx := alive_list.find(spectate_target)
	spectate_target = alive_list[(idx + 1) % alive_list.size()]
	hud.set_spectate_name(String(spectate_target.get_display_name()))


func _first_alive_bot() -> Node3D:
	for b in bots:
		if is_instance_valid(b) and b.is_alive():
			return b
	return null


func _update_spectator(delta: float) -> void:
	if not is_instance_valid(spectate_target) or not spectate_target.is_alive():
		spectate_target = _first_alive_bot()
		if spectate_target == null:
			spectating = false
			if spec_cam != null:
				spec_cam.current = false
			hud.show_end(false, kills, place)
			return
		hud.set_spectate_name(String(spectate_target.get_display_name()))

	var t: Vector3 = spectate_target.global_position
	var back: Vector3 = -spectate_target.global_transform.basis.z
	var want: Vector3 = t - back * 5.5 + Vector3(0, 2.8, 0)
	if spec_cam.global_position.length() < 0.01:
		spec_cam.global_position = want
	else:
		spec_cam.global_position = spec_cam.global_position.lerp(want, 1.0 - exp(-8.0 * delta))
	spec_cam.look_at(t + Vector3(0, 1.2, 0), Vector3.UP)


func drop_weapon_at(id: String, pos: Vector3) -> void:
	var scene: PackedScene = load("res://scenes/loot.tscn")
	var l = scene.instantiate()
	l.position = Vector3(pos.x, world.height_at(pos.x, pos.z) + 0.9, pos.z)
	add_child(l)
	l.setup(id, 1.0)


# --------------------------------------------------------------------------
# Signals
# --------------------------------------------------------------------------

func _on_player_landed() -> void:
	hud.set_center("", 0.1)
	hud.flash_hint("落地！搜集武器，活到最后")


func _on_player_damaged(amount: float) -> void:
	hud.flash_damage(amount)


func _on_hit_confirmed(headshot: bool) -> void:
	Sfx.play("hit", -6.0, 1.35 if headshot else randf_range(0.95, 1.05))
	hud.flash_hit(headshot)


func _on_weapon_changed(id: String) -> void:
	hud.set_center("拾取 " + String(Weapons.get_def(id)["label"]), 1.1)


func _on_player_healed(_amount: float) -> void:
	hud.flash_heal()


func _on_scan_started() -> void:
	hud.set_center("侦察镜已启动", 1.2)


func _on_zone_phase(_index: int) -> void:
	Sfx.play("zone_warn", -8.0)


func cycle_player_skin() -> void:
	var s: Dictionary = Skins.cycle()
	if player != null and player.visual != null:
		player.visual.set_skin(s)
	hud.set_center("皮肤：" + String(s["name"]), 1.0)


func _on_bot_died(bot: Node) -> void:
	if over:
		return

	var killer := "毒圈"
	var by_player := false
	if is_instance_valid(bot) and is_instance_valid(bot.last_attacker):
		if bot.last_attacker == player:
			killer = "你"
			by_player = true
		elif bot.last_attacker.has_method("get_display_name"):
			killer = bot.last_attacker.get_display_name()

	var victim: String = bot.bot_name if is_instance_valid(bot) else "Bot"
	hud.add_feed(killer, victim, by_player)

	if by_player:
		kills += 1
		Sfx.play("kill", -3.0)
		hud.flash_kill()

	alive = maxi(0, alive - 1)
	if alive <= 1 and player != null and player.is_alive():
		_win()


func _on_player_died() -> void:
	if over:
		return
	over = true
	alive = maxi(0, alive - 1)
	place = alive + 1
	InputState.locked = true
	hud.show_end(false, kills, place)


func _win() -> void:
	if over:
		return
	over = true
	place = 1
	InputState.locked = true
	hud.show_end(true, kills, 1)


func restart() -> void:
	InputState.locked = false
	InputState.clear()
	over = false
	get_tree().reload_current_scene()
