extends Control
## Side map overlay: a right-hand panel that leaves the world visible.
## Drag to pan, pinch / wheel / +− to zoom, click × or outside to close.

signal closed

var game
var _tex: ImageTexture
var _range := 460.0
var _font: SystemFont
var _built := false
var _open_ms := 0

var _panel := Rect2()
var _map_rect := Rect2()
var _close_rect := Rect2()
var _zoom_out_rect := Rect2()
var _zoom_in_rect := Rect2()
var _reset_rect := Rect2()
var _locate_rect := Rect2()

var _clip: Control
var _canvas: Control

var _zoom := 1.0
var _center := Vector2.ZERO
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _mouse_down := false
var _mouse_pos := Vector2.ZERO
var _map_t := 0.0
var _last_press := 0
var _use_mouse := true


class MapCanvas extends Control:
	var ov

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func _draw() -> void:
		if ov == null or ov._tex == null:
			return
		var half: float = ov._range / ov._zoom
		var ts: Vector2 = ov._tex.get_size()
		var u0: float = clampf((ov._center.x - half + ov._range) / (2.0 * ov._range), 0.0, 1.0)
		var v0: float = clampf((ov._center.y - half + ov._range) / (2.0 * ov._range), 0.0, 1.0)
		var u1: float = clampf((ov._center.x + half + ov._range) / (2.0 * ov._range), 0.0, 1.0)
		var v1: float = clampf((ov._center.y + half + ov._range) / (2.0 * ov._range), 0.0, 1.0)
		draw_texture_rect_region(
			ov._tex, Rect2(Vector2.ZERO, size),
			Rect2(u0 * ts.x, v0 * ts.y, (u1 - u0) * ts.x, (v1 - v0) * ts.y)
		)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.35), false, 2.0)
		if ov.game == null or ov.game.world == null:
			return

		if ov.game.world.bridge_points.size() == 2:
			draw_line(m(ov.game.world.bridge_points[0]), m(ov.game.world.bridge_points[1]),
				Color(0.86, 0.80, 0.62, 0.95), 4.0)

		var scale: float = size.x / (2.0 * half)
		draw_arc(m(ov.game.zone.center), ov.game.zone.radius * scale, 0.0, TAU,
			120, Color(0.45, 0.90, 1.0, 0.95), 3.0)
		var tr: float = ov.game.zone.target_radius()
		if tr > 0.0 and tr < ov.game.zone.radius:
			draw_arc(m(ov.game.zone.target_center()), tr * scale, 0.0, TAU,
				120, Color(1, 1, 1, 0.5), 2.0)

		for c in ov.game.world.poi_centers:
			var q := m(c)
			draw_rect(Rect2(q - Vector2(7, 7), Vector2(14, 14)), Color(0.92, 0.92, 0.96, 0.9))
			draw_rect(Rect2(q - Vector2(7, 7), Vector2(14, 14)), Color(0.1, 0.1, 0.12, 0.9), false, 1.5)

		for n in get_tree().get_nodes_in_group("loot"):
			if is_instance_valid(n):
				draw_circle(m(n.global_position), 2.4, Color(1.0, 0.78, 0.25, 0.85))
		for n in get_tree().get_nodes_in_group("medkit"):
			if is_instance_valid(n):
				draw_circle(m(n.global_position), 3.0, Color(0.35, 1.0, 0.55, 0.95))
		for n in get_tree().get_nodes_in_group("scope"):
			if is_instance_valid(n):
				draw_circle(m(n.global_position), 2.6, Color(0.72, 0.45, 1.0, 0.95))
		for n in get_tree().get_nodes_in_group("armor"):
			if is_instance_valid(n):
				draw_circle(m(n.global_position), 2.8, Color(0.40, 0.65, 1.0, 0.95))
		for n in get_tree().get_nodes_in_group("grenade"):
			if is_instance_valid(n):
				draw_circle(m(n.global_position), 2.6, Color(1.0, 0.60, 0.25, 0.95))

		if ov.game.player != null and ov.game.player.scan_t > 0.0:
			for b in ov.game.bots:
				if is_instance_valid(b) and b.is_alive():
					if ov.game.player.global_position.distance_to(b.global_position) <= 110.0:
						draw_circle(m(b.global_position), 4.5, Color(1.0, 0.22, 0.18, 0.98))

		if ov.game.player != null:
			var pp := m(ov.game.player.global_position)
			var yaw: float = ov.game.player.rotation.y
			var dir := Vector2(-sin(yaw), -cos(yaw))
			var side := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([
				pp + dir * 15.0,
				pp - dir * 9.0 + side * 8.0,
				pp - dir * 9.0 - side * 8.0,
			]), Color(1, 1, 1, 1.0))
			draw_arc(pp, 5.0, 0.0, TAU, 20, Color(0.1, 0.1, 0.12, 0.8), 1.5)

	func m(p: Vector3) -> Vector2:
		var half: float = ov._range / ov._zoom
		var u: float = (p.x - ov._center.x) / (2.0 * half) + 0.5
		var v: float = (p.z - ov._center.y) / (2.0 * half) + 0.5
		return Vector2(u * size.x, v * size.y)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_use_mouse = not OS.has_feature("mobile")
	set_process_input(true)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "sans-serif"
	])
	resized.connect(_update_layout)

	_clip = Control.new()
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.clip_contents = true
	add_child(_clip)

	_canvas = MapCanvas.new()
	_canvas.ov = self
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip.add_child(_canvas)

	set_process(false)


func setup(g: Node) -> void:
	game = g
	if game != null and game.world != null:
		_range = game.world.world_size * 0.5 + 20.0
	_build_texture()
	_update_layout()


func open_map() -> void:
	if visible:
		return
	_open_ms = Time.get_ticks_msec()
	_zoom = 1.0
	_center = Vector2.ZERO
	_touches.clear()
	_pinch_dist = 0.0
	visible = true
	set_process(true)
	_update_layout()
	queue_redraw()


func close_map() -> void:
	if not visible:
		return
	visible = false
	set_process(false)
	_touches.clear()
	closed.emit()


func _process(delta: float) -> void:
	# The world keeps rendering behind the panel; the map only needs ~10Hz.
	_map_t -= delta
	if _map_t <= 0.0 and _canvas != null:
		_map_t = 0.1
		_canvas.queue_redraw()


func _build_texture() -> void:
	if _built or game == null or game.world == null:
		return
	_built = true
	var n := 640
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for py in range(n):
		var wz := -_range + (py + 0.5) / float(n) * _range * 2.0
		for px in range(n):
			var wx := -_range + (px + 0.5) / float(n) * _range * 2.0
			var h: float = game.world.height_at(wx, wz)
			var c: Color
			if h < 0.0:
				c = Color(0.10, 0.30, 0.45).lerp(
					Color(0.05, 0.15, 0.26), clampf(-h / 14.0, 0.0, 1.0)
				)
			elif h < 1.4:
				c = Color(0.82, 0.76, 0.56)
			elif h < 14.0:
				c = Color(0.34, 0.54, 0.27).lerp(
					Color(0.47, 0.63, 0.31), clampf(h / 14.0, 0.0, 1.0)
				)
			elif h < 24.0:
				c = Color(0.48, 0.47, 0.43)
			else:
				c = Color(0.74, 0.74, 0.76)
			img.set_pixel(px, py, c)
	_tex = ImageTexture.create_from_image(img)


func _update_layout() -> void:
	var map_size := minf(size.y * 0.72, size.x * 0.42)
	map_size = maxf(map_size, 240.0)
	var panel_w := map_size + 32.0
	var panel_h := map_size + 104.0
	_panel = Rect2(size.x - panel_w - 16.0, (size.y - panel_h) * 0.5, panel_w, panel_h)
	_map_rect = Rect2(_panel.position + Vector2(16, 52), Vector2(map_size, map_size))
	_close_rect = Rect2(_panel.end.x - 44.0, _panel.position.y + 12.0, 28.0, 28.0)

	var by := _panel.end.y - 46.0
	_zoom_out_rect = Rect2(_panel.position.x + 16.0, by, 40.0, 34.0)
	_zoom_in_rect = Rect2(_panel.position.x + 64.0, by, 40.0, 34.0)
	_reset_rect = Rect2(_panel.position.x + 112.0, by, 54.0, 34.0)
	_locate_rect = Rect2(_panel.end.x - 96.0, by, 80.0, 34.0)

	if _clip != null:
		_clip.position = _map_rect.position
		_clip.size = _map_rect.size
	queue_redraw()


func _draw() -> void:
	# Only the side panel is painted; the left side stays fully visible.
	draw_rect(
		Rect2(_panel.position + Vector2(6, 6), _panel.size),
		Color(0, 0, 0, 0.35)
	)
	draw_rect(_panel, Color(0.035, 0.06, 0.085, 0.96))
	draw_rect(_panel, Color(0.30, 0.62, 0.82, 0.65), false, 2.0)

	draw_string(_font, _panel.position + Vector2(16, 30), "地图",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(1, 1, 1, 0.95))
	draw_string(_font, _panel.position + Vector2(70, 30), "%.1fx · 拖动平移 · 双指缩放" % _zoom,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.84, 0.94, 0.7))

	_close(_close_rect, "×")
	_button(_zoom_out_rect, "−")
	_button(_zoom_in_rect, "+")
	_button(_reset_rect, "1×")
	_button(_locate_rect, "定位")



func _button(r: Rect2, txt: String) -> void:
	draw_rect(r, Color(0.10, 0.17, 0.23, 0.95))
	draw_rect(r, Color(0.35, 0.65, 0.85, 0.6), false, 1.0)
	var fs := 16 if txt.length() < 3 else 13
	draw_string(_font, r.position + Vector2(0, r.size.y * 0.5 + fs * 0.36),
		txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(1, 1, 1, 0.9))


func _close(r: Rect2, txt: String) -> void:
	draw_circle(r.get_center(), r.size.x * 0.5, Color(0.12, 0.18, 0.24, 0.95))
	draw_string(_font, r.position + Vector2(0, r.size.y * 0.5 + 8),
		txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(1, 1, 1, 0.9))


# --------------------------------------------------------------------------
# Input: raw events so touch drag/pinch works on Android.
# --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var t := Time.get_ticks_msec() - _open_ms
	if t < 250:
		return

	if event is InputEventScreenTouch:
		_touch(event.position, event.index, event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_drag(event.position, event.index, event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and _use_mouse:
		var p: Vector2 = event.position
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(p, _zoom * 1.25)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(p, _zoom / 1.25)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if _press(p):
					_mouse_down = true
					_mouse_pos = p
		else:
			_mouse_down = false
		if _panel.has_point(p):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _use_mouse and _mouse_down:
		var p: Vector2 = event.position
		_pan(p - _mouse_pos)
		_mouse_pos = p
		get_viewport().set_input_as_handled()


func _press(p: Vector2) -> bool:
	# Touch also arrives as an emulated mouse press; do not double-fire buttons.
	var now := Time.get_ticks_msec()
	if now - _last_press < 180:
		return false
	_last_press = now
	if _close_rect.has_point(p):
		close_map()
		return false
	if _zoom_in_rect.has_point(p):
		_zoom_at(_map_rect.get_center(), _zoom * 1.25)
		return false
	if _zoom_out_rect.has_point(p):
		_zoom_at(_map_rect.get_center(), _zoom / 1.25)
		return false
	if _reset_rect.has_point(p):
		_zoom = 1.0
		_center = Vector2.ZERO
		queue_redraw()
		return false
	if _locate_rect.has_point(p):
		_zoom = maxf(2.0, _zoom)
		if game != null and game.player != null:
			_center = Vector2(game.player.global_position.x, game.player.global_position.z)
		_clamp_center()
		queue_redraw()
		return false
	if _map_rect.has_point(p):
		return true
	# A tap on the visible world outside the panel closes the map.
	close_map()
	return false


func _touch(p: Vector2, idx: int, pressed: bool) -> void:
	if pressed:
		if _panel.has_point(p) and not _map_rect.has_point(p):
			_press(p)
			return
		if not _map_rect.has_point(p):
			close_map()
			return
		_touches[idx] = p
		if _touches.size() == 2:
			var pts := _touches.values()
			_pinch_dist = pts[0].distance_to(pts[1])
	else:
		_touches.erase(idx)
		if _touches.size() < 2:
			_pinch_dist = 0.0


func _drag(p: Vector2, idx: int, rel: Vector2) -> void:
	if not _touches.has(idx):
		return
	_touches[idx] = p
	if _touches.size() == 1:
		_pan(rel)
	elif _touches.size() == 2:
		var pts := _touches.values()
		var d: float = pts[0].distance_to(pts[1])
		if _pinch_dist > 1.0 and d > 1.0:
			var mid: Vector2 = (pts[0] + pts[1]) * 0.5
			_zoom_at(mid, _zoom * d / _pinch_dist)
		_pinch_dist = d


func _pan(rel: Vector2) -> void:
	if _zoom <= 1.001:
		return
	var half := _range / _zoom
	_center.x -= rel.x / _map_rect.size.x * 2.0 * half
	_center.y -= rel.y / _map_rect.size.y * 2.0 * half
	_clamp_center()


func _zoom_at(screen_pos: Vector2, target: float) -> void:
	target = clampf(target, 1.0, 3.5)
	if absf(target - _zoom) < 0.001:
		return
	var old_half := _range / _zoom
	var local := (screen_pos - _map_rect.position) / _map_rect.size - Vector2(0.5, 0.5)
	var world := _center + local * (2.0 * old_half)
	_zoom = target
	var new_half := _range / _zoom
	_center = world - local * (2.0 * new_half)
	_clamp_center()
	queue_redraw()


func _clamp_center() -> void:
	var half := _range / _zoom
	_center.x = clampf(_center.x, -_range + half, _range - half)
	_center.y = clampf(_center.y, -_range + half, _range - half)
