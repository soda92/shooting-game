extends Node3D
## Match controller: spawns combatants and loot, runs zone damage, win/lose.

const BOT_COUNT := 11
const LOOT_COUNT := 26
const MEDKIT_COUNT := 10
const MEDKIT_SCENE := preload("res://scenes/medkit.tscn")

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


func _ready() -> void:
	randomize()
	Skins.refresh_models()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	InputState.locked = false
	InputState.clear()

	zone.reset(215.0)
	zone.phase_changed.connect(_on_zone_phase)

	_spawn_player()
	_spawn_bots()
	_spawn_loot()
	_spawn_medkits()

	hud.setup(self)
	hud.set_center("从空中选择落点", 2.5)


func _process(delta: float) -> void:
	if over:
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
	var p: Vector3 = world.random_land_point(140.0)
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


func _spawn_bots() -> void:
	var scene: PackedScene = load("res://scenes/bot.tscn")
	for i in range(BOT_COUNT):
		var b = scene.instantiate()
		var p: Vector3 = world.random_land_point(165.0)
		if player != null and Vector2(p.x - player.position.x, p.z - player.position.z).length() < 35.0:
			p = world.random_land_point(165.0)
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
	for i in range(LOOT_COUNT):
		var l = scene.instantiate()
		var p: Vector3 = world.random_land_point(165.0)
		l.position = Vector3(p.x, p.y + 0.9, p.z)
		add_child(l)
		l.setup(Weapons.ORDER[i % Weapons.ORDER.size()])


func _spawn_medkits() -> void:
	for i in range(MEDKIT_COUNT):
		spawn_medkit_at(world.random_land_point(165.0))


func spawn_medkit_at(pos: Vector3) -> void:
	var m = MEDKIT_SCENE.instantiate()
	var y: float = world.height_at(pos.x, pos.z)
	m.position = Vector3(pos.x, y + 0.7, pos.z)
	add_child(m)


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
