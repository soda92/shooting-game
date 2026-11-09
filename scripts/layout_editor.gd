extends Control
## Full-screen touch layout editor. Drag any icon (or the joystick) to move it;
## positions are saved to settings as screen-relative coordinates.

signal closed

var touch
var _title: Label
var _hint: Label
var _reset: Button
var _done: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_theme()

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	touch = load("res://scripts/touch_controls.gd").new()
	touch.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(touch)
	touch.set_edit_mode(true)

	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.96)
	sb.border_color = Color(0.35, 0.65, 0.85, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("panel", sb)
	_place(bar, 0.5, 0.0, 0.5, 0.0, -470, 16, 470, 92)
	add_child(bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_title = _label("按键布局", 24, Color(0.80, 0.95, 1.0))
	col.add_child(_title)
	_hint = _label("拖动图标或摇杆调整位置 · 自动保存", 14, Color(0.68, 0.78, 0.86, 0.9))
	col.add_child(_hint)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_reset = _button("重置", 17)
	_reset.custom_minimum_size = Vector2(110, 44)
	_reset.pressed.connect(_on_reset)
	row.add_child(_reset)

	_done = _button("完成", 18)
	_done.custom_minimum_size = Vector2(120, 44)
	_done.pressed.connect(close)
	row.add_child(_done)


func open() -> void:
	visible = true
	InputState.locked = true
	touch.refresh_layout()
	touch.set_edit_mode(true)
	touch.reset_touches()


func close() -> void:
	if not visible:
		return
	touch.set_edit_mode(false)
	visible = false
	InputState.locked = false
	closed.emit()


func _on_reset() -> void:
	InputState.reset_touch_layout()
	touch.refresh_layout()


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


func _label(txt: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.11, 0.15, 0.95)
	normal.border_color = Color(0.35, 0.65, 0.85, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.10, 0.16, 0.22, 0.98)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	return b


func _theme() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "sans-serif"
	])
	var t := Theme.new()
	t.default_font = f
	t.default_font_size = 18
	theme = t
