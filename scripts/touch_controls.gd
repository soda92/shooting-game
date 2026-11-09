extends Control
## On-screen touch controls: left virtual stick, right-side look area and
## icon-only action buttons. The layout can be dragged and saved.

var _joy_origin := Vector2.ZERO
var _joy_r := 90.0
var _joy_active := false
var _joy_index := -1
var _joy_knob := Vector2.ZERO

var _look_index := -1

const TOUCH_ICONS := preload("res://scripts/touch_icons.gd")
const LABELS := {
	"fire": "开火", "fire_l": "开火", "aim": "瞄准", "jump": "跳",
	"reload": "换弹", "medkit": "医疗", "switch": "切换", "scan": "侦察",
	"grenade": "手雷", "view": "视角", "attach": "配件",
}

var _buttons: Dictionary = {}
var _btn_touch: Dictionary = {}

var _font: SystemFont
var _idle := 0.0
var _ui_alpha := 1.0

var edit_mode := false
var _edit_btn := ""
var _edit_joy := false
var _edit_off := Vector2.ZERO


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
	if InputState.joy_home.x >= 0.0:
		_joy_origin = Vector2(InputState.joy_home.x * s.x, InputState.joy_home.y * s.y)
		_joy_knob = _joy_origin

	_buttons = {
		"fire": {"pos": Vector2(s.x * 0.930, s.y * 0.780), "r": m * 0.090},
		"fire_l": {"pos": Vector2(s.x * 0.280, s.y * 0.550), "r": m * 0.062},
		"aim": {"pos": Vector2(s.x * 0.820, s.y * 0.630), "r": m * 0.060},
		"jump": {"pos": Vector2(s.x * 0.735, s.y * 0.720), "r": m * 0.050},
		"reload": {"pos": Vector2(s.x * 0.845, s.y * 0.895), "r": m * 0.047},
		"medkit": {"pos": Vector2(s.x * 0.755, s.y * 0.895), "r": m * 0.045},
		"switch": {"pos": Vector2(s.x * 0.665, s.y * 0.895), "r": m * 0.044},
		"scan": {"pos": Vector2(s.x * 0.575, s.y * 0.835), "r": m * 0.044},
		"grenade": {"pos": Vector2(s.x * 0.485, s.y * 0.895), "r": m * 0.044},
		"view": {"pos": Vector2(s.x * 0.930, s.y * 0.510), "r": m * 0.044},
		"attach": {"pos": Vector2(s.x * 0.760, s.y * 0.470), "r": m * 0.044},
	}
	for name in _buttons:
		if InputState.touch_layout.has(name):
			var rel: Vector2 = InputState.touch_layout[name]
			_buttons[name]["pos"] = Vector2(rel.x * s.x, rel.y * s.y)
	queue_redraw()


func refresh_layout() -> void:
	_layout()


func set_edit_mode(on: bool) -> void:
	edit_mode = on
	_edit_btn = ""
	_edit_joy = false
	_btn_touch.clear()
	_look_index = -1
	if on:
		_idle = 0.0
		_ui_alpha = 1.0
		reset_touches()
	else:
		InputState.touch_fire = false
		InputState.touch_aim = false
	queue_redraw()


# --------------------------------------------------------------------------
# Normal play input
# --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if edit_mode:
		_edit_input(event)
		return
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

		var fixed_joy := InputState.joy_home.x >= 0.0
		var near_home := pos.distance_to(_joy_origin) <= _joy_r * 1.7
		var left_zone := (not fixed_joy) and pos.x < size.x * 0.42 and pos.y > size.y * 0.42
		if not _joy_active and (near_home or left_zone):
			_joy_active = true
			_joy_index = idx
			if not fixed_joy:
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
		if InputState.aim_toggle_mode:
			if on:
				InputState.aim_toggle = not InputState.aim_toggle
		else:
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
	elif name == "grenade":
		if on:
			InputState.grenade_queued = true
	queue_redraw()


func _any_fire_down() -> bool:
	return int(_btn_touch.get("fire", -1)) != -1 or int(_btn_touch.get("fire_l", -1)) != -1


# --------------------------------------------------------------------------
# Layout editing
# --------------------------------------------------------------------------

func _edit_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_edit_touch(event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_edit_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_edit_touch(event.position, event.pressed)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_edit_move(event.position)


func _edit_touch(pos: Vector2, pressed: bool) -> void:
	if pressed:
		for name in _buttons:
			var b: Dictionary = _buttons[name]
			if pos.distance_to(b["pos"]) <= float(b["r"]) * 1.35:
				_edit_btn = name
				_edit_off = pos - b["pos"]
				_edit_joy = false
				queue_redraw()
				return
		if pos.distance_to(_joy_origin) <= _joy_r * 1.35:
			_edit_joy = true
			_edit_btn = ""
			_edit_off = pos - _joy_origin
			queue_redraw()
		return

	if _edit_btn != "":
		var b: Dictionary = _buttons[_edit_btn]
		var bp: Vector2 = b["pos"]
		InputState.set_touch_layout(_edit_btn, Vector2(bp.x / size.x, bp.y / size.y))
		_edit_btn = ""
	elif _edit_joy:
		InputState.set_joy_home(Vector2(_joy_origin.x / size.x, _joy_origin.y / size.y))
		_edit_joy = false
	queue_redraw()


func _edit_move(pos: Vector2) -> void:
	if _edit_btn != "":
		var b: Dictionary = _buttons[_edit_btn]
		var r: float = b["r"]
		var np: Vector2 = pos - _edit_off
		np.x = clampf(np.x, r + 8.0, size.x - r - 8.0)
		np.y = clampf(np.y, r + 8.0, size.y - r - 8.0)
		b["pos"] = np
		queue_redraw()
	elif _edit_joy:
		_joy_origin = pos - _edit_off
		_joy_origin.x = clampf(_joy_origin.x, _joy_r, size.x - _joy_r)
		_joy_origin.y = clampf(_joy_origin.y, _joy_r, size.y - _joy_r)
		_joy_knob = _joy_origin
		queue_redraw()


# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if InputState.locked and not edit_mode and (_joy_active or _look_index != -1):
		reset_touches()
	_idle += delta
	var target := 1.0
	if not edit_mode:
		target = 1.0 if _idle < 2.5 else 0.35
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
	if edit_mode:
		draw_arc(_joy_origin, _joy_r + 4.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.30, 0.7), 2.0)
		var jfs := maxi(12, int(_joy_r * 0.22))
		var jw := _font.get_string_size("摇杆", HORIZONTAL_ALIGNMENT_LEFT, -1, jfs).x
		draw_string(_font, _joy_origin + Vector2(-jw * 0.5, _joy_r + jfs + 6.0), "摇杆",
			HORIZONTAL_ALIGNMENT_LEFT, -1, jfs, Color(1.0, 0.92, 0.72, 0.9))

	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		var pressed := int(_btn_touch.get(name, -1)) != -1
		var a := 1.0 if pressed else _ui_alpha

		var dim := false
		if name == "medkit" and InputState.medkit_count <= 0:
			dim = true
		elif name == "grenade" and InputState.grenade_count <= 0:
			dim = true
		elif name == "scan" and InputState.scan_cd > 0.0:
			dim = true

		var fill := Color(1.0, 0.55, 0.25, 0.38 * a) if pressed else Color(1, 1, 1, 0.10 * a)
		if dim:
			fill = Color(1, 1, 1, 0.05 * a)
		if name == "view" and InputState.first_person and not pressed:
			fill = Color(0.35, 0.70, 1.0, 0.35 * a)
		if name == "aim" and InputState.aim:
			fill = Color(1.0, 0.55, 0.25, 0.42 * a)
		draw_circle(p, r, fill)
		draw_arc(p, r, 0.0, TAU, 44, Color(1, 1, 1, 0.30 * a), 2.0)

		var icon_col := Color(1, 1, 1, 0.94 * a) if not dim else Color(1, 1, 1, 0.38 * a)
		TOUCH_ICONS.draw(self, name, p, r * 0.62, icon_col)

		var badge := ""
		if name == "medkit" and InputState.medkit_count > 0:
			badge = str(InputState.medkit_count)
		elif name == "grenade" and InputState.grenade_count > 0:
			badge = str(InputState.grenade_count)
		elif name == "scan" and InputState.scan_cd > 0.0:
			badge = "%d" % int(ceil(InputState.scan_cd))
		if badge != "":
			_badge(p + Vector2(r * 0.62, r * 0.60), badge, int(r * 0.52), a)

		if edit_mode:
			draw_arc(p, r + 4.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.30, 0.75), 2.0)
			var label := String(LABELS.get(name, name))
			var fs := maxi(11, int(r * 0.36))
			var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(_font, p + Vector2(-tw * 0.5, r + fs + 6.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.72, 0.9))


func _badge(p: Vector2, txt: String, fs: int, a: float) -> void:
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_circle(p, fs * 0.72, Color(0.02, 0.03, 0.05, 0.75 * a))
	draw_string(_font, p + Vector2(-w * 0.5, fs * 0.34), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95 * a))
