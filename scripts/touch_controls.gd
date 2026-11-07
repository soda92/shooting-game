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
		"fire": {"pos": Vector2(s.x * 0.905, s.y * 0.760), "r": m * 0.105, "label": "开火"},
		"aim": {"pos": Vector2(s.x * 0.800, s.y * 0.625), "r": m * 0.070, "label": "瞄准"},
		"jump": {"pos": Vector2(s.x * 0.700, s.y * 0.735), "r": m * 0.060, "label": "跳"},
		"reload": {"pos": Vector2(s.x * 0.805, s.y * 0.880), "r": m * 0.056, "label": "换弹"},
		"medkit": {"pos": Vector2(s.x * 0.720, s.y * 0.885), "r": m * 0.052, "label": "医疗"},
		"scan": {"pos": Vector2(s.x * 0.640, s.y * 0.760), "r": m * 0.050, "label": "侦察"},
	}
	queue_redraw()


# --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if InputState.locked:
		return
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
	if name == "fire":
		InputState.touch_fire = on
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
	queue_redraw()


# --------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if InputState.locked and (_joy_active or _look_index != -1):
		reset_touches()
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
	# joystick
	draw_circle(_joy_origin, _joy_r, Color(1, 1, 1, 0.09))
	draw_arc(_joy_origin, _joy_r, 0.0, TAU, 48, Color(1, 1, 1, 0.26), 2.0)
	var knob := _joy_knob if _joy_active else _joy_origin
	draw_circle(knob, _joy_r * 0.36, Color(1, 1, 1, 0.20))
	draw_arc(knob, _joy_r * 0.36, 0.0, TAU, 32, Color(1, 1, 1, 0.34), 2.0)

	# buttons
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		var pressed := int(_btn_touch.get(name, -1)) != -1
		var dim := false
		var txt: String = b["label"]
		if name == "medkit" and InputState.medkit_count <= 0:
			dim = true
		elif name == "scan" and InputState.scan_cd > 0.0:
			dim = true
			txt = "%d" % int(ceil(InputState.scan_cd))

		var fill := Color(1.0, 0.55, 0.25, 0.38) if pressed else Color(1, 1, 1, 0.10)
		if dim:
			fill = Color(1, 1, 1, 0.05)
		draw_circle(p, r, fill)
		draw_arc(p, r, 0.0, TAU, 44, Color(1, 1, 1, 0.30), 2.0)

		var fs := int(r * 0.46)
		var fcol := Color(1, 1, 1, 0.92) if not dim else Color(1, 1, 1, 0.40)
		var ts := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(_font, p - Vector2(ts.x * 0.5, -ts.y * 0.30), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fcol)
