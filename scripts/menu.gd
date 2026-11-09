extends Control
## Start screen: mode, difficulty, skin preview, settings and start.

var _preview
var _skin_buttons: Array[Button] = []
var _mode_buttons: Array = []
var _diff_buttons: Array = []

var _settings_root: Control
var _sens_slider: HSlider
var _vol_slider: HSlider
var _sens_value: Label
var _vol_value: Label
var _aim_toggle_btn: Button
var _aim_hold_btn: Button
var _gyro_check: CheckButton
var _layout_editor


func _ready() -> void:
	Skins.refresh_models()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_theme()
	_build()
	_build_settings()
	_select_skin(Skins.selected_index)
	_refresh_mode()
	_refresh_diff()
	set_process(true)


func _process(delta: float) -> void:
	if _preview != null:
		_preview.tick(delta, 0.0, false)


# --------------------------------------------------------------------------

func _make_theme() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "sans-serif"
	])
	var t := Theme.new()
	t.default_font = f
	t.default_font_size = 22
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


func _label(txt: String, fsize: int, color := Color(0.92, 0.95, 1.0)) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	return l


func _button(txt: String, fsize := 18) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fsize)
	return b


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.055, 0.085)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 3D preview
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	_place(vpc, 0.56, 0.08, 0.97, 0.94, 0, 0, 0, 0)
	add_child(vpc)

	var vp := SubViewport.new()
	vp.size = Vector2i(620, 800)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.055, 0.085)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.65, 0.78)
	env.ambient_light_energy = 1.4
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-38), deg_to_rad(25), 0)
	light.light_energy = 1.4
	vp.add_child(light)

	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.position = Vector3(0, 1.10, -3.3)
	cam.fov = 30.0
	cam.look_at(Vector3(0, 1.02, 0), Vector3.UP)

	_preview = preload("res://scripts/character_visual.gd").new()
	vp.add_child(_preview)

	# left panel
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	_place(left, 0.05, 0.06, 0.53, 0.95, 0, 0, 0, 0)
	add_child(left)

	left.add_child(_label("ISLAND ROYALE", 46))
	left.add_child(_label("离线单机大逃杀 · Godot 4.7", 17, Color(0.55, 0.65, 0.75)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	left.add_child(gap)

	left.add_child(_label("模式", 18, Color(0.65, 0.75, 0.85)))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	for item in [["br", "大逃杀"], ["range", "训练场"]]:
		var b := _button(item[1], 19)
		b.custom_minimum_size = Vector2(170, 46)
		b.pressed.connect(_set_mode.bind(String(item[0])))
		mode_row.add_child(b)
		_mode_buttons.append({"id": String(item[0]), "btn": b})
	left.add_child(mode_row)

	left.add_child(_label("难度", 18, Color(0.65, 0.75, 0.85)))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 10)
	for item in [[0, "简单"], [1, "普通"], [2, "困难"]]:
		var b := _button(item[1], 18)
		b.custom_minimum_size = Vector2(110, 42)
		b.pressed.connect(_set_diff.bind(int(item[0])))
		diff_row.add_child(b)
		_diff_buttons.append({"id": int(item[0]), "btn": b})
	left.add_child(diff_row)

	left.add_child(_label("皮肤", 18, Color(0.65, 0.75, 0.85)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in range(Skins.LIST.size()):
		var b := _button(String(Skins.LIST[i]["name"]), 15)
		b.custom_minimum_size = Vector2(160, 40)
		b.pressed.connect(_select_skin.bind(i))
		grid.add_child(b)
		_skin_buttons.append(b)
	left.add_child(grid)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	var start := _button("开始", 26)
	start.custom_minimum_size = Vector2(0, 64)
	start.pressed.connect(_start)
	left.add_child(start)

	var settings := _button("设置", 18)
	settings.custom_minimum_size = Vector2(0, 44)
	settings.pressed.connect(_toggle_settings)
	left.add_child(settings)

	var hint := _label("WASD 移动 · 鼠标转视角 · 左键开火 · 右键瞄准", 15, Color(0.45, 0.55, 0.65))
	left.add_child(hint)


# --------------------------------------------------------------------------

func _set_mode(id: String) -> void:
	Meta.mode = id
	_refresh_mode()


func _refresh_mode() -> void:
	for entry in _mode_buttons:
		var active: bool = String(entry["id"]) == Meta.mode
		entry["btn"].add_theme_color_override("font_color",
			Color(1, 1, 1) if active else Color(0.55, 0.62, 0.70))


func _set_diff(d: int) -> void:
	Meta.difficulty = d
	_refresh_diff()


func _refresh_diff() -> void:
	for entry in _diff_buttons:
		var active: bool = int(entry["id"]) == Meta.difficulty
		entry["btn"].add_theme_color_override("font_color",
			Color(1, 1, 1) if active else Color(0.55, 0.62, 0.70))


func _select_skin(i: int) -> void:
	Skins.selected_index = i
	if _preview != null:
		_preview.set_skin(Skins.LIST[i])
	for j in range(_skin_buttons.size()):
		_skin_buttons[j].add_theme_color_override("font_color",
			Color(1, 1, 1) if j == i else Color(0.55, 0.62, 0.70))


func _start() -> void:
	InputState.locked = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --------------------------------------------------------------------------
# settings
# --------------------------------------------------------------------------

func _build_settings() -> void:
	_settings_root = Control.new()
	_settings_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_root.visible = false
	add_child(_settings_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_root.add_child(dim)

	var panel := PanelContainer.new()
	_place(panel, 0.5, 0.5, 0.5, 0.5, -320, -260, 320, 260)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 0.98)
	sb.border_color = Color(0.35, 0.55, 0.75, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	_settings_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	vbox.add_child(_label("设置", 26))

	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 12)
	var l1 := _label("灵敏度", 19)
	l1.custom_minimum_size = Vector2(100, 40)
	_sens_slider = HSlider.new()
	_sens_slider.min_value = 0.3
	_sens_slider.max_value = 2.0
	_sens_slider.step = 0.1
	_sens_slider.custom_minimum_size = Vector2(320, 40)
	_sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sens_value = _label("1.0", 19)
	_sens_value.custom_minimum_size = Vector2(64, 40)
	_sens_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r1.add_child(l1)
	r1.add_child(_sens_slider)
	r1.add_child(_sens_value)
	vbox.add_child(r1)

	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 12)
	var l2 := _label("音量", 19)
	l2.custom_minimum_size = Vector2(100, 40)
	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 1.0
	_vol_slider.step = 0.05
	_vol_slider.custom_minimum_size = Vector2(320, 40)
	_vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vol_value = _label("80%", 19)
	_vol_value.custom_minimum_size = Vector2(64, 40)
	_vol_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r2.add_child(l2)
	r2.add_child(_vol_slider)
	r2.add_child(_vol_value)
	vbox.add_child(r2)

	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 12)
	var l3 := _label("开镜", 19)
	l3.custom_minimum_size = Vector2(100, 40)
	_aim_toggle_btn = _button("点击开镜", 17)
	_aim_toggle_btn.custom_minimum_size = Vector2(180, 42)
	_aim_hold_btn = _button("按住开镜", 17)
	_aim_hold_btn.custom_minimum_size = Vector2(180, 42)
	r3.add_child(l3)
	r3.add_child(_aim_toggle_btn)
	r3.add_child(_aim_hold_btn)
	vbox.add_child(r3)

	var r4 := HBoxContainer.new()
	r4.add_theme_constant_override("separation", 12)
	var l4 := _label("陀螺仪", 19)
	l4.custom_minimum_size = Vector2(100, 40)
	_gyro_check = CheckButton.new()
	_gyro_check.text = "开启"
	_gyro_check.focus_mode = Control.FOCUS_NONE
	r4.add_child(l4)
	r4.add_child(_gyro_check)
	vbox.add_child(r4)

	var credit := _label(
		"音效素材：Vincent Sevedge · congusbongus · Fantozzi · BMacZero(CC BY 3.0 / CC0)",
		12,
		Color(0.72, 0.78, 0.86, 0.75)
	)
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(credit)

	var credit2 := _label(
		"原始脚步录音：swuing · EminYILDIRIM(Freesound)",
		11,
		Color(0.72, 0.78, 0.86, 0.6)
	)
	credit2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(credit2)

	var layout_btn := _button("按键布局", 18)
	layout_btn.custom_minimum_size = Vector2(560, 44)
	layout_btn.pressed.connect(_open_layout_editor)
	vbox.add_child(layout_btn)

	var close := _button("关闭", 20)
	close.custom_minimum_size = Vector2(560, 44)
	close.pressed.connect(_toggle_settings)
	vbox.add_child(close)

	_sens_slider.value_changed.connect(_on_sens)
	_vol_slider.value_changed.connect(_on_vol)
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


func _open_layout_editor() -> void:
	if _layout_editor == null:
		_layout_editor = load("res://scripts/layout_editor.gd").new()
		add_child(_layout_editor)
		_layout_editor.closed.connect(_on_layout_closed)
	_settings_root.visible = false
	_layout_editor.open()


func _on_layout_closed() -> void:
	_settings_root.visible = true
	_refresh_settings()


func _toggle_settings() -> void:
	_settings_root.visible = not _settings_root.visible
	if _settings_root.visible:
		_refresh_settings()


func _refresh_settings() -> void:
	_sens_slider.set_value_no_signal(InputState.sensitivity)
	_vol_slider.set_value_no_signal(InputState.master_volume)
	_sens_value.text = "%.1f" % InputState.sensitivity
	_vol_value.text = "%d%%" % int(round(InputState.master_volume * 100.0))
	_aim_toggle_btn.text = ("● " if InputState.aim_toggle_mode else "○ ") + "点击开镜"
	_aim_hold_btn.text = ("○ " if InputState.aim_toggle_mode else "● ") + "按住开镜"
	_gyro_check.set_pressed_no_signal(InputState.gyro)


func _on_sens(v: float) -> void:
	InputState.set_sensitivity(v)
	_sens_value.text = "%.1f" % v


func _on_vol(v: float) -> void:
	InputState.set_volume(v)
	_vol_value.text = "%d%%" % int(round(v * 100.0))
