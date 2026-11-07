extends Control
## In-game HUD built entirely in code (no theme assets required).

class Reticle extends Control:
	var hit_t := 0.0
	var head := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flash(is_head := false) -> void:
		hit_t = 0.22
		head = is_head

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
			var a := clampf(hit_t / 0.22, 0.0, 1.0)
			var hc := Color(1.0, 0.68, 0.18, a) if head else Color(1.0, 0.4, 0.3, a)
			var s := 17.0 if head else 13.0
			draw_line(c + Vector2(-s, -s), c + Vector2(-5, -5), hc, 3.0)
			draw_line(c + Vector2(s, -s), c + Vector2(5, -5), hc, 3.0)
			draw_line(c + Vector2(-s, s), c + Vector2(-5, 5), hc, 3.0)
			draw_line(c + Vector2(s, s), c + Vector2(5, 5), hc, 3.0)


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
		if game != null and game.player != null and game.player.is_alive() and InputState.aim and InputState.first_person:
			want = 1.0
		alpha = lerpf(alpha, want, 1.0 - exp(-16.0 * delta))
		queue_redraw()

	func _draw() -> void:
		if alpha <= 0.01 or game == null or game.player == null:
			return

		var sid := String(game.player.current_scope())
		var overlay := String(Scopes.get_def(sid)["overlay"])
		var full := overlay == "scope"
		var c := size * 0.5
		var inner: float
		if full:
			inner = minf(size.x, size.y) * (0.25 if sid == "8x" else 0.31)
		elif overlay == "red_dot":
			inner = minf(size.x, size.y) * 0.42
		else:
			inner = minf(size.x, size.y) * 0.46
		var outer: float = size.length() * 0.5 + 24.0
		var shade := 0.96 if full else (0.16 if overlay == "red_dot" else 0.10)

		# dark ring outside the sight
		draw_arc(c, (inner + outer) * 0.5, 0.0, TAU, 160,
			Color(0, 0, 0, alpha * shade), outer - inner)
		draw_arc(c, inner, 0.0, TAU, 128, Color(0, 0, 0, alpha * 0.75), 3.0)

		if full:
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
		elif overlay == "red_dot":
			draw_arc(c, inner * 0.55, 0.0, TAU, 96, Color(0, 0, 0, alpha * 0.5), 2.0)
			draw_circle(c, 3.0, Color(1.0, 0.15, 0.10, alpha))
		else:
			draw_line(c + Vector2(0, -inner * 0.35), c + Vector2(0, -7),
				Color(0, 0, 0, alpha * 0.8), 3.0)
			draw_circle(c, 2.2, Color(1, 1, 1, alpha * 0.85))


class DamageDir extends Control:
	var game

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if game == null or game.player == null:
			return
		var p = game.player
		if p.hit_from_t <= 0.0:
			return

		var cam: Camera3D = p.get_node("Pivot/SpringArm/Camera")
		var local: Vector3 = cam.global_transform.basis.inverse() * p.hit_from_dir
		var ang := atan2(local.x, -local.z)
		var c := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.33
		var a: float = clampf(p.hit_from_t, 0.0, 1.0)
		var mid := ang - PI * 0.5

		draw_arc(c, radius, mid - 0.16, mid + 0.16, 12, Color(1.0, 0.15, 0.10, a * 0.85), 12.0)
		draw_arc(c, radius + 10.0, mid - 0.12, mid + 0.12, 12, Color(1.0, 0.15, 0.10, a * 0.35), 6.0)


var game

var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _armor_bg: ColorRect
var _armor_fill: ColorRect
var _hp_label: Label
var _med_label: Label
var _ammo_label: Label
var _slots_label: RichTextLabel
var _alive_label: Label
var _zone_label: Label
var _center_label: Label
var _hint_label: Label
var _damage: ColorRect
var _heal: ColorRect
var _kill_label: Label
var _reticle
var _minimap
var _map_layer: CanvasLayer
var _map_overlay
var _map_prev_locked := false
var _map_prev_touch := true
var _markers
var _scope
var _dmg_dir
var _feed_label: RichTextLabel
var _feed: Array = []
var _feed_dirty := false
var _attach_root: Control
var _attach_title: Label
var _attach_buttons: Dictionary = {}
var _settings_root: Control
var _spec_root: Control
var _spec_label: Label
var _spec_btn: Button
var _sens_slider: HSlider
var _vol_slider: HSlider
var _sens_value: Label
var _vol_value: Label
var _aim_toggle_btn: Button
var _aim_hold_btn: Button
var _gyro_check: CheckButton
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
	_minimap.map_requested.connect(_open_map)
	_map_overlay.setup(g)
	_markers.game = g
	_markers.font = theme.default_font
	_scope.game = g
	_dmg_dir.game = g


func _open_map() -> void:
	if _map_overlay == null or _map_overlay.visible:
		return
	_map_prev_locked = InputState.locked
	InputState.locked = true
	if game != null and game.touch != null:
		_map_prev_touch = game.touch.visible
		game.touch.reset_touches()
		game.touch.visible = false
	_map_overlay.open_map()


func _close_map() -> void:
	if _map_overlay == null:
		return
	_map_overlay.close_map()
	InputState.locked = _map_prev_locked
	if game != null and game.touch != null:
		game.touch.visible = _map_prev_touch


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_M:
		if _map_overlay != null and _map_overlay.visible:
			_close_map()
		else:
			_open_map()


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
	_armor_bg = _bottom_rect(Color(0, 0, 0, 0.45), 28, -46, 330, -34)
	_armor_fill = _bottom_rect(Color(0.30, 0.55, 1.0, 1), 31, -43, 327, -37)
	_hp_label = _make_label("100 HP", 22)
	_place(_hp_label, 0.0, 1.0, 0.0, 1.0, 30, -108, 330, -78)

	_med_label = _make_label("医疗包 x0", 20)
	_place(_med_label, 0.0, 1.0, 0.0, 1.0, 30, -140, 330, -112)

	_ammo_label = _make_label("30 / 150\nM4 步枪", 30)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(_ammo_label, 1.0, 1.0, 1.0, 1.0, -460, -120, -200, -28)

	_slots_label = RichTextLabel.new()
	_slots_label.bbcode_enabled = true
	_slots_label.fit_content = true
	_slots_label.scroll_active = false
	_slots_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots_label.add_theme_font_size_override("normal_font_size", 20)
	_place(_slots_label, 1.0, 1.0, 1.0, 1.0, -540, -170, -200, -126)
	add_child(_slots_label)

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

	var settings_btn := Button.new()
	settings_btn.text = "设置"
	settings_btn.focus_mode = Control.FOCUS_NONE
	settings_btn.add_theme_font_size_override("font_size", 18)
	_place(settings_btn, 1.0, 0.0, 1.0, 0.0, -310, 64, -170, 104)
	settings_btn.pressed.connect(_toggle_settings)
	add_child(settings_btn)

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
	_place(_fps_label, 0.0, 0.0, 0.0, 0.0, 18, 282, 160, 306)

	_minimap = preload("res://scripts/minimap.gd").new()
	add_child(_minimap)
	_place(_minimap, 0.0, 0.0, 0.0, 0.0, 18, 18, 228, 228)

	# Transparent hit area over the minimap; a Button is reliable on touch.
	var map_hit := Button.new()
	map_hit.flat = true
	map_hit.focus_mode = Control.FOCUS_NONE
	_place(map_hit, 0.0, 0.0, 0.0, 0.0, 18, 18, 228, 228)
	map_hit.pressed.connect(_open_map)
	add_child(map_hit)

	var map_btn := Button.new()
	map_btn.text = "地图"
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.add_theme_font_size_override("font_size", 16)
	_place(map_btn, 0.0, 0.0, 0.0, 0.0, 18, 234, 128, 274)
	map_btn.pressed.connect(_open_map)
	add_child(map_btn)

	_map_layer = CanvasLayer.new()
	_map_layer.layer = 20
	add_child(_map_layer)
	_map_overlay = preload("res://scripts/map_overlay.gd").new()
	_map_layer.add_child(_map_overlay)
	_map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_overlay.closed.connect(_close_map)

	_markers = Markers.new()
	add_child(_markers)
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_scope = Scope.new()
	add_child(_scope)
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dmg_dir = DamageDir.new()
	add_child(_dmg_dir)
	_dmg_dir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_feed_label = RichTextLabel.new()
	_feed_label.bbcode_enabled = true
	_feed_label.fit_content = true
	_feed_label.scroll_active = false
	_feed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_label.add_theme_font_size_override("normal_font_size", 18)
	_place(_feed_label, 1.0, 0.0, 1.0, 0.0, -640, 112, -30, 300)
	add_child(_feed_label)

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

	_spec_btn = Button.new()
	_spec_btn.text = "观战击杀者"
	_spec_btn.add_theme_font_size_override("font_size", 26)
	_spec_btn.custom_minimum_size = Vector2(280, 76)
	_spec_btn.focus_mode = Control.FOCUS_NONE
	_place(_spec_btn, 0.5, 0.60, 0.5, 0.60, -300, 0, -20, 76)
	_spec_btn.pressed.connect(_on_spectate)
	_end_root.add_child(_spec_btn)

	var btn := Button.new()
	btn.text = "再来一局"
	btn.add_theme_font_size_override("font_size", 26)
	btn.custom_minimum_size = Vector2(280, 76)
	btn.focus_mode = Control.FOCUS_NONE
	_place(btn, 0.5, 0.60, 0.5, 0.60, 20, 0, 300, 76)
	btn.pressed.connect(_on_restart)
	_end_root.add_child(btn)

	# Attachment panel
	_attach_root = Control.new()
	_attach_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attach_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_attach_root.visible = false
	add_child(_attach_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attach_root.add_child(dim)

	var panel := PanelContainer.new()
	_place(panel, 0.5, 0.5, 0.5, 0.5, -300, -230, 300, 230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 0.97)
	sb.border_color = Color(0.35, 0.55, 0.75, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	_attach_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_attach_title = Label.new()
	_attach_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_attach_title)

	for id in Scopes.ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(520, 46)
		b.add_theme_font_size_override("font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_scope_pick.bind(String(id)))
		vbox.add_child(b)
		_attach_buttons[id] = b

	var close := Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(520, 44)
	close.add_theme_font_size_override("font_size", 20)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close_attach)
	vbox.add_child(close)

	# Settings panel
	_settings_root = Control.new()
	_settings_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_root.visible = false
	add_child(_settings_root)

	var sdim := ColorRect.new()
	sdim.color = Color(0, 0, 0, 0.62)
	sdim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_root.add_child(sdim)

	var spanel := PanelContainer.new()
	_place(spanel, 0.5, 0.5, 0.5, 0.5, -330, -250, 330, 250)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.07, 0.09, 0.12, 0.97)
	ssb.border_color = Color(0.35, 0.55, 0.75, 0.85)
	ssb.set_border_width_all(2)
	ssb.set_corner_radius_all(6)
	spanel.add_theme_stylebox_override("panel", ssb)
	_settings_root.add_child(spanel)

	var smargin := MarginContainer.new()
	smargin.add_theme_constant_override("margin_left", 24)
	smargin.add_theme_constant_override("margin_right", 24)
	smargin.add_theme_constant_override("margin_top", 18)
	smargin.add_theme_constant_override("margin_bottom", 18)
	spanel.add_child(smargin)

	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 14)
	smargin.add_child(svbox)

	var stitle := Label.new()
	stitle.text = "设置"
	stitle.add_theme_font_size_override("font_size", 26)
	svbox.add_child(stitle)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	var l1 := Label.new()
	l1.text = "灵敏度"
	l1.custom_minimum_size = Vector2(110, 40)
	l1.add_theme_font_size_override("font_size", 20)
	_sens_slider = HSlider.new()
	_sens_slider.min_value = 0.3
	_sens_slider.max_value = 2.0
	_sens_slider.step = 0.1
	_sens_slider.custom_minimum_size = Vector2(320, 40)
	_sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sens_value = Label.new()
	_sens_value.custom_minimum_size = Vector2(64, 40)
	_sens_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sens_value.add_theme_font_size_override("font_size", 20)
	row1.add_child(l1)
	row1.add_child(_sens_slider)
	row1.add_child(_sens_value)
	svbox.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	var l2 := Label.new()
	l2.text = "音量"
	l2.custom_minimum_size = Vector2(110, 40)
	l2.add_theme_font_size_override("font_size", 20)
	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 1.0
	_vol_slider.step = 0.05
	_vol_slider.custom_minimum_size = Vector2(320, 40)
	_vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vol_value = Label.new()
	_vol_value.custom_minimum_size = Vector2(64, 40)
	_vol_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vol_value.add_theme_font_size_override("font_size", 20)
	row2.add_child(l2)
	row2.add_child(_vol_slider)
	row2.add_child(_vol_value)
	svbox.add_child(row2)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 12)
	var l3 := Label.new()
	l3.text = "开镜模式"
	l3.custom_minimum_size = Vector2(110, 40)
	l3.add_theme_font_size_override("font_size", 20)
	_aim_toggle_btn = Button.new()
	_aim_toggle_btn.custom_minimum_size = Vector2(180, 44)
	_aim_toggle_btn.focus_mode = Control.FOCUS_NONE
	_aim_toggle_btn.add_theme_font_size_override("font_size", 18)
	_aim_hold_btn = Button.new()
	_aim_hold_btn.custom_minimum_size = Vector2(180, 44)
	_aim_hold_btn.focus_mode = Control.FOCUS_NONE
	_aim_hold_btn.add_theme_font_size_override("font_size", 18)
	row3.add_child(l3)
	row3.add_child(_aim_toggle_btn)
	row3.add_child(_aim_hold_btn)
	svbox.add_child(row3)

	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 12)
	var l4 := Label.new()
	l4.text = "陀螺仪"
	l4.custom_minimum_size = Vector2(110, 40)
	l4.add_theme_font_size_override("font_size", 20)
	_gyro_check = CheckButton.new()
	_gyro_check.text = "开启"
	_gyro_check.focus_mode = Control.FOCUS_NONE
	row4.add_child(l4)
	row4.add_child(_gyro_check)
	svbox.add_child(row4)

	var sclose := Button.new()
	sclose.text = "关闭"
	sclose.custom_minimum_size = Vector2(560, 44)
	sclose.add_theme_font_size_override("font_size", 20)
	sclose.focus_mode = Control.FOCUS_NONE
	sclose.pressed.connect(_close_settings)
	svbox.add_child(sclose)

	_sens_slider.value_changed.connect(_on_sens_changed)
	_vol_slider.value_changed.connect(_on_vol_changed)
	_aim_toggle_btn.pressed.connect(func() -> void:
		InputState.set_aim_mode(true)
		_refresh_settings()
	)
	_aim_hold_btn.pressed.connect(func() -> void:
		InputState.set_aim_mode(false)
		_refresh_settings()
	)
	_gyro_check.toggled.connect(func(on: bool) -> void:
		InputState.set_gyro(on)
	)

	# Spectator overlay
	_spec_root = Control.new()
	_spec_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spec_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_spec_root.visible = false
	add_child(_spec_root)

	var spec_panel := PanelContainer.new()
	_place(spec_panel, 0.5, 0.04, 0.5, 0.04, -280, 0, 280, 120)
	var ssb2 := StyleBoxFlat.new()
	ssb2.bg_color = Color(0.05, 0.07, 0.10, 0.92)
	ssb2.border_color = Color(0.35, 0.55, 0.75, 0.7)
	ssb2.set_border_width_all(2)
	ssb2.set_corner_radius_all(6)
	spec_panel.add_theme_stylebox_override("panel", ssb2)
	_spec_root.add_child(spec_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	spec_panel.add_child(sv)

	_spec_label = Label.new()
	_spec_label.text = "观战中"
	_spec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spec_label.add_theme_font_size_override("font_size", 22)
	sv.add_child(_spec_label)

	var sh := HBoxContainer.new()
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation", 16)
	var next_btn := Button.new()
	next_btn.text = "切换目标"
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.add_theme_font_size_override("font_size", 18)
	next_btn.pressed.connect(_on_next_spectate)
	sh.add_child(next_btn)
	var restart_btn := Button.new()
	restart_btn.text = "再来一局"
	restart_btn.focus_mode = Control.FOCUS_NONE
	restart_btn.add_theme_font_size_override("font_size", 18)
	restart_btn.pressed.connect(_on_restart)
	sh.add_child(restart_btn)
	sv.add_child(sh)


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
	_hp_label.text = "%d HP   护甲 %d" % [int(ceil(p.health)), int(ceil(p.armor))]
	_med_label.text = "医疗包 x%d   手雷 x%d" % [p.medkits, p.grenades]
	var ar: float = clampf(p.armor / 100.0, 0.0, 1.0)
	_armor_fill.offset_right = 31.0 + 296.0 * ar
	_ammo_label.text = "%d / %d\n%s · %s" % [
		p.mag(), p.reserve(),
		String(Weapons.get_def(p.weapon_id())["label"]),
		String(Scopes.get_def(p.current_scope())["short"])
	]
	_slots_label.text = _slot_text(p)
	if game.range_mode:
		_alive_label.text = "训练场 · 命中 %d" % game.target_hits
	else:
		_alive_label.text = "存活 %d  ·  击杀 %d" % [game.alive, game.kills]
	_zone_label.text = game.zone.status_text()

	if p.state == 0:
		_hint_label.text = "拖动摇杆下降，落地后开始"
	elif _hint_t <= 0.0:
		_hint_label.text = ""
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _slot_text(p) -> String:
	var parts: Array[String] = []
	for i in range(p.slots.size()):
		var s: Dictionary = p.slots[i]
		if s.is_empty():
			parts.append("[color=#55636e]%d --[/color]" % (i + 1))
		else:
			var nm := String(Weapons.get_def(String(s["id"]))["short"])
			if i == int(p.active):
				parts.append("[color=#ffffff][b]%d %s[/b][/color]" % [i + 1, nm])
			else:
				parts.append("[color=#93a6b6]%d %s[/color]" % [i + 1, nm])
	return "[right]" + "     ".join(parts) + "[/right]"


func flash_hit(headshot := false) -> void:
	if _reticle != null:
		_reticle.flash(headshot)


func add_feed(killer: String, victim: String, by_player: bool) -> void:
	var kc := "#ffb066" if by_player else "#cfd8e3"
	var line := "[color=%s]%s[/color]  淘汰  %s" % [kc, killer, victim]
	_feed.push_front({"text": line, "t": 4.0})
	if _feed.size() > 4:
		_feed.resize(4)
	_feed_dirty = true


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
	_spec_root.visible = false
	_end_root.visible = true
	_spec_btn.disabled = game == null or game.range_mode or game.alive <= 0
	if win:
		_end_title.text = "大吉大利，今晚吃鸡！"
		_end_sub.text = "击杀 %d  ·  第 1 名" % kills
	else:
		_end_title.text = "被淘汰了"
		_end_sub.text = "击杀 %d  ·  第 %d 名" % [kills, place]


func show_spectate(name: String) -> void:
	_end_root.visible = false
	_spec_root.visible = true
	_spec_label.text = "观战中：" + name


func set_spectate_name(name: String) -> void:
	if _spec_root.visible:
		_spec_label.text = "观战中：" + name


# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _reticle != null:
		_reticle.visible = not (InputState.aim and InputState.first_person)

	if InputState.consume_attach():
		_toggle_attach()
	if _attach_root.visible:
		if game == null or game.over or game.player == null or not game.player.is_alive():
			_close_attach()
	if _settings_root.visible:
		if game == null or game.over or game.player == null or not game.player.is_alive():
			_close_settings()

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

	if not _feed.is_empty():
		var removed := false
		for e in _feed:
			e["t"] = float(e["t"]) - delta
		while not _feed.is_empty() and float(_feed[_feed.size() - 1]["t"]) <= 0.0:
			_feed.pop_back()
			removed = true
		if removed:
			_feed_dirty = true
	if _feed_dirty:
		_feed_dirty = false
		var lines: Array[String] = []
		for e in _feed:
			lines.append(String(e["text"]))
		_feed_label.text = "[right]" + "\n".join(lines) + "[/right]"


func _on_spectate() -> void:
	if game != null:
		game.start_spectate()


func _on_next_spectate() -> void:
	if game != null:
		game.next_spectate()


func _on_restart() -> void:
	if game != null:
		game.restart()


func _toggle_settings() -> void:
	if _settings_root.visible:
		_close_settings()
		return
	if game == null or game.player == null or game.over or not game.player.is_alive():
		return
	if _attach_root.visible:
		_close_attach()
	_refresh_settings()
	_settings_root.visible = true
	InputState.locked = true


func _close_settings() -> void:
	_settings_root.visible = false
	if game != null and not game.over:
		InputState.locked = false


func _refresh_settings() -> void:
	_sens_slider.set_value_no_signal(InputState.sensitivity)
	_vol_slider.set_value_no_signal(InputState.master_volume)
	_sens_value.text = "%.1f" % InputState.sensitivity
	_vol_value.text = "%d%%" % int(round(InputState.master_volume * 100.0))
	_aim_toggle_btn.text = ("● " if InputState.aim_toggle_mode else "○ ") + "点击开镜"
	_aim_hold_btn.text = ("○ " if InputState.aim_toggle_mode else "● ") + "按住开镜"
	_gyro_check.set_pressed_no_signal(InputState.gyro)


func _on_sens_changed(v: float) -> void:
	InputState.set_sensitivity(v)
	_sens_value.text = "%.1f" % v


func _on_vol_changed(v: float) -> void:
	InputState.set_volume(v)
	_vol_value.text = "%d%%" % int(round(v * 100.0))


func _toggle_attach() -> void:
	if game == null or game.player == null:
		return
	if _attach_root.visible:
		_close_attach()
		return
	if game.over or not game.player.is_alive():
		return
	if _attach_root.visible:
		_close_attach()
	_refresh_attach()
	_attach_root.visible = true
	InputState.aim_toggle = false
	InputState.locked = true


func _close_attach() -> void:
	_attach_root.visible = false
	if game != null and not game.over:
		InputState.locked = false


func _on_scope_pick(id: String) -> void:
	if game == null or game.player == null:
		return
	if game.player.equip_scope(id):
		_refresh_attach()
		update_hud()


func _refresh_attach() -> void:
	var p = game.player
	var wname := String(Weapons.get_def(p.weapon_id())["label"])
	var sname := String(Scopes.get_def(p.current_scope())["short"])
	_attach_title.text = "配件 · %s · 当前 %s" % [wname, sname]
	for id in Scopes.ORDER:
		var sid := String(id)
		var owned: bool = sid == "iron" or bool(p.scopes_owned.get(sid, false))
		var equipped: bool = String(p.current_scope()) == sid
		var txt := String(Scopes.get_def(sid)["name"])
		if equipped:
			txt += "（已装备）"
		elif not owned:
			txt += "（未拾取）"
		var b: Button = _attach_buttons[sid]
		b.text = txt
		b.disabled = not owned


func _on_skin_pressed() -> void:
	if game != null:
		game.cycle_player_skin()
