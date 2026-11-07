extends Control
## On-screen touch controls: left virtual stick, right-side look area,
## fire / aim / jump / reload buttons.

var _joy_origin := Vector2.ZERO
var _joy_r := 90.0
var _joy_active := false
var _joy_index := -1
var _joy_knob := Vector2.ZERO

var _look_index := -1

var _buttons: Dictionary = {}
var _btn_touch: Dictionary = {}

var _font: SystemFont
var _idle := 0.0
var _ui_alpha := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "sans-serif"
	])
	_layout()
	resized.connect(_layout)
	set_process(true)


func _layout() -> void:
	var s := size
	if s.x < 10.0 or s.y < 10.0:
		s = get_viewport_rect().size
	var m := minf(s.x, s.y)

	_joy_origin = Vector2(s.x * 0.13, s.y * 0.74)
	_joy_r = m * 0.135
	_joy_knob = _joy_origin

	_buttons = {
		"fire": {"pos": Vector2(s.x * 0.930, s.y * 0.780), "r": m * 0.090, "label": "开火"},
		"fire_l": {"pos": Vector2(s.x * 0.280, s.y * 0.550), "r": m * 0.062, "label": "开火"},
		"aim": {"pos": Vector2(s.x * 0.820, s.y * 0.630), "r": m * 0.060, "label": "瞄准"},
		"jump": {"pos": Vector2(s.x * 0.735, s.y * 0.720), "r": m * 0.050, "label": "跳"},
		"reload": {"pos": Vector2(s.x * 0.845, s.y * 0.895), "r": m * 0.047, "label": "换弹"},
		"medkit": {"pos": Vector2(s.x * 0.755, s.y * 0.895), "r": m * 0.045, "label": "医疗"},
		"switch": {"pos": Vector2(s.x * 0.665, s.y * 0.895), "r": m * 0.044, "label": "切换"},
		"scan": {"pos": Vector2(s.x * 0.575, s.y * 0.835), "r": m * 0.044, "label": "侦察"},
		"view": {"pos": Vector2(s.x * 0.930, s.y * 0.510), "r": m * 0.044, "label": "视角"},
		"attach": {"pos": Vector2(s.x * 0.760, s.y * 0.470), "r": m * 0.044, "label": "配件"},
	}
	queue_redraw()


# --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if InputState.locked:
		return
	_idle = 0.0
	if event is InputEventScreenTouch:
		_handle_touch(event.position, event.index, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.position, event.index, event.relative)


func _handle_touch(pos: Vector2, idx: int, pressed: bool) -> void:
	if pressed:
		for name in _buttons:
			var b: Dictionary = _buttons[name]
			if pos.distance_to(b["pos"]) <= float(b["r"]) * 1.25:
				_btn_touch[name] = idx
				_apply(name, true)
				return

		if not _joy_active and pos.x < size.x * 0.42 and pos.y > size.y * 0.42:
			_joy_active = true
			_joy_index = idx
			_joy_origin = pos
			_joy_knob = pos
			InputState.touch_move = Vector2.ZERO
			return

		if _look_index == -1:
			_look_index = idx
	else:
		for name in _buttons:
			if int(_btn_touch.get(name, -1)) == idx:
				_btn_touch[name] = -1
				_apply(name, false)
		if _joy_index == idx:
			_joy_index = -1
			_joy_active = false
			InputState.touch_move = Vector2.ZERO
			InputState.touch_sprint = false
		if _look_index == idx:
			_look_index = -1


func _handle_drag(pos: Vector2, idx: int, rel: Vector2) -> void:
	if idx == _joy_index and _joy_active:
		var v := (pos - _joy_origin) / _joy_r
		v = v.limit_length(1.0)
		_joy_knob = _joy_origin + v * _joy_r
		InputState.touch_move = Vector2(v.x, -v.y)
		InputState.touch_sprint = v.length() > 0.82
	elif idx == _look_index:
		InputState.look += rel


func _apply(name: String, on: bool) -> void:
	if name == "fire" or name == "fire_l":
		InputState.touch_fire = _any_fire_down()
	elif name == "aim":
		InputState.touch_aim = on
	elif name == "jump":
		if on:
			InputState.jump_queued = true
	elif name == "reload":
		if on:
			InputState.reload_queued = true
	elif name == "medkit":
		if on:
			InputState.medkit_queued = true
	elif name == "scan":
		if on:
			InputState.scan_queued = true
	elif name == "view":
		if on:
			InputState.first_person = not InputState.first_person
	elif name == "switch":
		if on:
			InputState.switch_queued = true
	elif name == "attach":
		if on:
			InputState.attach_toggle_queued = true
	queue_redraw()


# --------------------------------------------------------------------------

func _any_fire_down() -> bool:
	return int(_btn_touch.get("fire", -1)) != -1 or int(_btn_touch.get("fire_l", -1)) != -1


func _process(delta: float) -> void:
	if InputState.locked and (_joy_active or _look_index != -1):
		reset_touches()
	_idle += delta
	var target := 1.0 if _idle < 2.5 else 0.35
	_ui_alpha = lerpf(_ui_alpha, target, 1.0 - exp(-6.0 * delta))
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset_touches()


func reset_touches() -> void:
	_joy_index = -1
	_joy_active = false
	_joy_knob = _joy_origin
	_look_index = -1
	_btn_touch.clear()
	InputState.touch_move = Vector2.ZERO
	InputState.touch_fire = false
	InputState.touch_aim = false
	InputState.touch_sprint = false


func _draw() -> void:
	var joy_a := maxf(_ui_alpha, 0.55)
	draw_circle(_joy_origin, _joy_r, Color(1, 1, 1, 0.09 * joy_a))
	draw_arc(_joy_origin, _joy_r, 0.0, TAU, 48, Color(1, 1, 1, 0.26 * joy_a), 2.0)
	var knob := _joy_knob if _joy_active else _joy_origin
	draw_circle(knob, _joy_r * 0.36, Color(1, 1, 1, 0.20 * joy_a))
	draw_arc(knob, _joy_r * 0.36, 0.0, TAU, 32, Color(1, 1, 1, 0.34 * joy_a), 2.0)

	# buttons
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		var pressed := int(_btn_touch.get(name, -1)) != -1
		var a := 1.0 if pressed else _ui_alpha

		var dim := false
		var txt: String = b["label"]
		if name == "medkit" and InputState.medkit_count <= 0:
			dim = true
		elif name == "scan" and InputState.scan_cd > 0.0:
			dim = true
			txt = "%d" % int(ceil(InputState.scan_cd))

		var fill := Color(1.0, 0.55, 0.25, 0.38 * a) if pressed else Color(1, 1, 1, 0.10 * a)
		if dim:
			fill = Color(1, 1, 1, 0.05 * a)
		if name == "view" and InputState.first_person and not pressed:
			fill = Color(0.35, 0.70, 1.0, 0.35 * a)
		draw_circle(p, r, fill)
		draw_arc(p, r, 0.0, TAU, 44, Color(1, 1, 1, 0.30 * a), 2.0)

		var fs := int(r * 0.46)
		var fcol := Color(1, 1, 1, 0.92 * a) if not dim else Color(1, 1, 1, 0.40 * a)
		var ts := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(_font, p - Vector2(ts.x * 0.5, -ts.y * 0.30), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fcol)
