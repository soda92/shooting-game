extends Control
## In-game HUD built entirely in code (no theme assets required).

class Reticle extends Control:
	var hit_t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flash() -> void:
		hit_t = 0.2

	func _process(delta: float) -> void:
		if hit_t > 0.0:
			hit_t = maxf(0.0, hit_t - delta)
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1, 1, 1, 0.85)
		draw_line(c + Vector2(0, -8), c + Vector2(0, -16), col, 2.0)
		draw_line(c + Vector2(0, 8), c + Vector2(0, 16), col, 2.0)
		draw_line(c + Vector2(-8, 0), c + Vector2(-16, 0), col, 2.0)
		draw_line(c + Vector2(8, 0), c + Vector2(16, 0), col, 2.0)
		draw_circle(c, 1.8, col)
		if hit_t > 0.0:
			var a := clampf(hit_t / 0.2, 0.0, 1.0)
			var hc := Color(1.0, 0.4, 0.3, a)
			draw_line(c + Vector2(-13, -13), c + Vector2(-5, -5), hc, 3.0)
			draw_line(c + Vector2(13, -13), c + Vector2(5, -5), hc, 3.0)
			draw_line(c + Vector2(-13, 13), c + Vector2(-5, 5), hc, 3.0)
			draw_line(c + Vector2(13, 13), c + Vector2(5, 5), hc, 3.0)


class Markers extends Control:
	var game
	var font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if game == null or game.player == null or font == null:
			return
		var p = game.player
		if p.scan_t <= 0.0:
			return
		var cam: Camera3D = p.get_node("Pivot/SpringArm/Camera")
		for b in get_tree().get_nodes_in_group("combatants"):
			if b == p or not b.has_method("is_alive") or not b.is_alive():
				continue
			var d: float = p.global_position.distance_to(b.global_position)
			if d > 110.0:
				continue
			var wp: Vector3 = b.global_position + Vector3(0.0, 1.9, 0.0)
			if cam.is_position_behind(wp):
				continue
			var sp: Vector2 = cam.unproject_position(wp)
			var col := Color(1.0, 0.30, 0.25, 0.95)
			draw_colored_polygon(PackedVector2Array([
				sp + Vector2(0, -13), sp + Vector2(10, 0),
				sp + Vector2(0, 13), sp + Vector2(-10, 0)
			]), col)
			draw_string(font, sp + Vector2(14, 5), "%dm" % int(d),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


class Scope extends Control:
	var game
	var alpha := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		var want := 0.0
		if game != null and game.player != null and game.player.is_alive() and InputState.aim:
			want = 1.0
		alpha = lerpf(alpha, want, 1.0 - exp(-16.0 * delta))
		queue_redraw()

	func _draw() -> void:
		if alpha <= 0.01 or game == null or game.player == null:
			return

		var sniper: bool = String(game.player.weapon_id) == "sniper"
		var c := size * 0.5
		var inner: float = minf(size.x, size.y) * (0.31 if sniper else 0.40)
		var outer: float = size.length() * 0.5 + 24.0
		var shade := 0.96 if sniper else 0.32

		# dark ring outside the sight
		draw_arc(c, (inner + outer) * 0.5, 0.0, TAU, 160,
			Color(0, 0, 0, alpha * shade), outer - inner)
		draw_arc(c, inner, 0.0, TAU, 128, Color(0, 0, 0, alpha * 0.75), 3.0)

		if sniper:
			var col := Color(0.02, 0.02, 0.02, alpha)
			draw_line(c + Vector2(-inner, 0), c + Vector2(-16, 0), col, 2.0)
			draw_line(c + Vector2(inner, 0), c + Vector2(16, 0), col, 2.0)
			draw_line(c + Vector2(0, -inner), c + Vector2(0, -16), col, 2.0)
			draw_line(c + Vector2(0, inner), c + Vector2(0, 16), col, 2.0)
			for i in range(1, 5):
				var off := inner * 0.18 * i
				draw_circle(c + Vector2(-off, 0), 1.4, col)
				draw_circle(c + Vector2(off, 0), 1.4, col)
				draw_circle(c + Vector2(0, -off), 1.4, col)
				draw_circle(c + Vector2(0, off), 1.4, col)
			draw_circle(c, 2.2, Color(0.90, 0.10, 0.10, alpha))
		else:
			draw_arc(c, inner * 0.72, 0.0, TAU, 96, Color(0, 0, 0, alpha * 0.55), 2.0)
			draw_circle(c, 2.0, Color(1.0, 0.28, 0.22, alpha))


var game

var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label
var _med_label: Label
var _ammo_label: Label
var _alive_label: Label
var _zone_label: Label
var _center_label: Label
var _hint_label: Label
var _damage: ColorRect
var _heal: ColorRect
var _kill_label: Label
var _reticle
var _minimap
var _markers
var _scope
var _end_root: Control
var _end_title: Label
var _end_sub: Label

var _center_t := 0.0
var _damage_a := 0.0
var _heal_a := 0.0
var _kill_t := 0.0
var _hint_t := 0.0
var _fps_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_font()
	_build()
	set_process(true)


func setup(g: Node) -> void:
	game = g
	_minimap.setup(g)
	_markers.game = g
	_markers.font = theme.default_font
	_scope.game = g


# --------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------

func _make_font() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "sans-serif"
	])
	var t := Theme.new()
	t.default_font = f
	t.default_font_size = 24
	theme = t


func _place(c: Control, al: float, at: float, ar: float, ab: float,
		l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _make_label(txt: String, fsize: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.94))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _bottom_rect(color: Color, l: float, t: float, r: float, b: float) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(c, 0.0, 1.0, 0.0, 1.0, l, t, r, b)
	add_child(c)
	return c


func _build() -> void:
	_damage = ColorRect.new()
	_damage.color = Color(0.8, 0.05, 0.02, 0.0)
	_damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_damage)

	_heal = ColorRect.new()
	_heal.color = Color(0.20, 0.90, 0.35, 0.0)
	_heal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_heal)

	_hp_bg = _bottom_rect(Color(0, 0, 0, 0.45), 28, -76, 330, -50)
	_hp_fill = _bottom_rect(Color(0.30, 0.85, 0.42, 1), 31, -73, 327, -53)
	_hp_label = _make_label("100 HP", 22)
	_place(_hp_label, 0.0, 1.0, 0.0, 1.0, 30, -108, 330, -78)

	_med_label = _make_label("医疗包 x0", 20)
	_place(_med_label, 0.0, 1.0, 0.0, 1.0, 30, -140, 330, -112)

	_ammo_label = _make_label("30 / 150\nM4 步枪", 30)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(_ammo_label, 1.0, 1.0, 1.0, 1.0, -380, -120, -30, -28)

	_alive_label = _make_label("存活 12  ·  击杀 0", 24)
	_alive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_alive_label, 1.0, 0.0, 1.0, 0.0, -460, 20, -30, 58)

	var skin_btn := Button.new()
	skin_btn.text = "换肤"
	skin_btn.focus_mode = Control.FOCUS_NONE
	skin_btn.add_theme_font_size_override("font_size", 18)
	_place(skin_btn, 1.0, 0.0, 1.0, 0.0, -150, 64, -30, 104)
	skin_btn.pressed.connect(_on_skin_pressed)
	add_child(skin_btn)

	_zone_label = _make_label("安全区", 22)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_zone_label, 0.5, 0.0, 0.5, 0.0, -360, 18, 360, 54)

	_center_label = _make_label("", 38)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_center_label, 0.0, 0.42, 1.0, 0.58, 0, 0, 0, 0)

	_hint_label = _make_label("", 20)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_hint_label, 0.0, 1.0, 1.0, 1.0, 0, -150, 0, -118)

	_fps_label = _make_label("", 16)
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_place(_fps_label, 0.0, 0.0, 0.0, 0.0, 18, 234, 160, 258)

	_minimap = preload("res://scripts/minimap.gd").new()
	add_child(_minimap)
	_place(_minimap, 0.0, 0.0, 0.0, 0.0, 18, 18, 228, 228)

	_markers = Markers.new()
	add_child(_markers)
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_scope = Scope.new()
	add_child(_scope)
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_kill_label = _make_label("击杀 +1", 34)
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kill_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
	_place(_kill_label, 0.5, 0.5, 0.5, 0.5, -200, -140, 200, -96)
	_kill_label.visible = false

	_reticle = Reticle.new()
	add_child(_reticle)
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_end_root = Control.new()
	_end_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_root.visible = false
	add_child(_end_root)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.80)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_root.add_child(bg)

	_end_title = Label.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 52)
	_end_title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_place(_end_title, 0.0, 0.32, 1.0, 0.44, 0, 0, 0, 0)
	_end_root.add_child(_end_title)

	_end_sub = Label.new()
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_sub.add_theme_font_size_override("font_size", 26)
	_place(_end_sub, 0.0, 0.45, 1.0, 0.53, 0, 0, 0, 0)
	_end_root.add_child(_end_sub)

	var btn := Button.new()
	btn.text = "再来一局"
	btn.add_theme_font_size_override("font_size", 28)
	btn.custom_minimum_size = Vector2(280, 76)
	_place(btn, 0.5, 0.60, 0.5, 0.60, -140, 0, 140, 76)
	btn.pressed.connect(_on_restart)
	_end_root.add_child(btn)


# --------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------

func update_hud() -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	var hpr: float = clampf(p.health / p.max_health, 0.0, 1.0)
	_hp_fill.offset_right = 31.0 + 296.0 * hpr
	_hp_fill.color = Color(0.90, 0.25, 0.20) if hpr < 0.35 else Color(0.30, 0.85, 0.42)
	_hp_label.text = "%d HP" % int(ceil(p.health))
	_med_label.text = "医疗包 x%d" % p.medkits
	_ammo_label.text = "%d / %d\n%s" % [p.mag, p.reserve, String(Weapons.get_def(p.weapon_id)["label"])]
	_alive_label.text = "存活 %d  ·  击杀 %d" % [game.alive, game.kills]
	_zone_label.text = game.zone.status_text()

	if p.state == 0:
		_hint_label.text = "拖动摇杆下降，落地后开始"
	elif _hint_t <= 0.0:
		_hint_label.text = ""
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func flash_hit() -> void:
	if _reticle != null:
		_reticle.flash()


func flash_damage(_amount: float) -> void:
	_damage_a = minf(0.9, _damage_a + 0.38)


func flash_heal() -> void:
	_heal_a = 0.55


func flash_kill() -> void:
	_kill_label.visible = true
	_kill_label.modulate.a = 1.0
	_kill_t = 1.0


func flash_hint(text: String) -> void:
	_hint_label.text = text
	_hint_t = 3.0


func set_center(text: String, duration: float) -> void:
	_center_label.text = text
	_center_t = duration


func show_end(win: bool, kills: int, place: int) -> void:
	_end_root.visible = true
	if win:
		_end_title.text = "大吉大利，今晚吃鸡！"
		_end_sub.text = "击杀 %d  ·  第 1 名" % kills
	else:
		_end_title.text = "被淘汰了"
		_end_sub.text = "击杀 %d  ·  第 %d 名" % [kills, place]


# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _reticle != null:
		_reticle.visible = not InputState.aim

	if _center_t > 0.0:
		_center_t -= delta
		if _center_t <= 0.0:
			_center_label.text = ""

	if _hint_t > 0.0:
		_hint_t -= delta

	if _damage_a > 0.0:
		_damage_a = maxf(0.0, _damage_a - delta * 1.3)
		_damage.color.a = _damage_a * 0.55

	if _heal_a > 0.0:
		_heal_a = maxf(0.0, _heal_a - delta * 1.2)
		_heal.color.a = _heal_a * 0.35

	if _kill_t > 0.0:
		_kill_t -= delta
		_kill_label.modulate.a = clampf(_kill_t / 0.35, 0.0, 1.0)
		if _kill_t <= 0.0:
			_kill_label.visible = false


func _on_restart() -> void:
	if game != null:
		game.restart()


func _on_skin_pressed() -> void:
	if game != null:
		game.cycle_player_skin()
