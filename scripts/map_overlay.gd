extends Control
## Full-screen map. Tapping the minimap (or M on desktop) opens it.
## Tap anywhere to close; the world keeps running underneath.

signal closed

var game
var _tex: ImageTexture
var _range := 460.0
var _font: SystemFont
var _rect := Rect2()
var _built := false
var _open_ms := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "sans-serif"
	])
	set_process(false)


func setup(g: Node) -> void:
	game = g
	if game != null and game.world != null:
		_range = game.world.world_size * 0.5 + 20.0
	_build_texture()


func open_map() -> void:
	if visible:
		return
	_open_ms = Time.get_ticks_msec()
	visible = true
	set_process(true)
	queue_redraw()


func close_map() -> void:
	if not visible:
		return
	visible = false
	set_process(false)
	closed.emit()


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() - _open_ms < 300:
		accept_event()
		return
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if pressed:
		close_map()
		accept_event()


func _build_texture() -> void:
	if _built or game == null or game.world == null:
		return
	_built = true
	var n := 448
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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.05, 0.93))

	var ms := maxf(220.0, minf(size.x, size.y) - 80.0)
	_rect = Rect2((size.x - ms) * 0.5, (size.y - ms) * 0.5, ms, ms)

	draw_rect(
		Rect2(_rect.position - Vector2(10, 10), _rect.size + Vector2(20, 20)),
		Color(0.25, 0.58, 0.78, 0.55), false, 3.0
	)
	if _tex != null:
		draw_texture_rect(_tex, _rect, false)
	draw_rect(_rect, Color(1, 1, 1, 0.42), false, 2.0)

	draw_string(
		_font, _rect.position + Vector2(14, 30), "地图 · 点击任意处关闭",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.92)
	)
	draw_string(
		_font, Vector2(_rect.end.x - 26, _rect.position.y + 30), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.75)
	)

	if game == null or game.world == null:
		return

	# bridge
	if game.world.bridge_points.size() == 2:
		draw_line(
			_m(game.world.bridge_points[0]),
			_m(game.world.bridge_points[1]),
			Color(0.86, 0.80, 0.62, 0.95), 4.0
		)

	# zones
	var scale := _rect.size.x / (_range * 2.0)
	draw_arc(_m(game.zone.center), game.zone.radius * scale, 0.0, TAU,
		96, Color(0.45, 0.90, 1.0, 0.95), 3.0)
	var tr: float = game.zone.target_radius()
	if tr > 0.0 and tr < game.zone.radius:
		draw_arc(_m(game.zone.target_center()), tr * scale, 0.0, TAU,
			96, Color(1, 1, 1, 0.5), 2.0)

	# POIs
	for c in game.world.poi_centers:
		var p := _m(c)
		draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Color(0.92, 0.92, 0.96, 0.9))
		draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Color(0.1, 0.1, 0.12, 0.9), false, 1.5)

	# loot
	for n in get_tree().get_nodes_in_group("loot"):
		if is_instance_valid(n):
			draw_circle(_m(n.global_position), 2.4, Color(1.0, 0.78, 0.25, 0.85))
	for n in get_tree().get_nodes_in_group("medkit"):
		if is_instance_valid(n):
			draw_circle(_m(n.global_position), 3.0, Color(0.35, 1.0, 0.55, 0.95))
	for n in get_tree().get_nodes_in_group("scope"):
		if is_instance_valid(n):
			draw_circle(_m(n.global_position), 2.6, Color(0.72, 0.45, 1.0, 0.95))
	for n in get_tree().get_nodes_in_group("armor"):
		if is_instance_valid(n):
			draw_circle(_m(n.global_position), 2.8, Color(0.40, 0.65, 1.0, 0.95))
	for n in get_tree().get_nodes_in_group("grenade"):
		if is_instance_valid(n):
			draw_circle(_m(n.global_position), 2.6, Color(1.0, 0.60, 0.25, 0.95))

	# recon-highlighted enemies
	if game.player != null and game.player.scan_t > 0.0:
		for b in game.bots:
			if is_instance_valid(b) and b.is_alive():
				if game.player.global_position.distance_to(b.global_position) <= 110.0:
					draw_circle(_m(b.global_position), 4.5, Color(1.0, 0.22, 0.18, 0.98))

	# player arrow
	if game.player != null:
		var pp := _m(game.player.global_position)
		var yaw: float = game.player.rotation.y
		var dir := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			pp + dir * 15.0,
			pp - dir * 9.0 + side * 8.0,
			pp - dir * 9.0 - side * 8.0,
		]), Color(1, 1, 1, 1.0))
		draw_arc(pp, 5.0, 0.0, TAU, 20, Color(0.1, 0.1, 0.12, 0.8), 1.5)


func _m(p: Vector3) -> Vector2:
	return Vector2(
		_rect.position.x + (p.x + _range) / (_range * 2.0) * _rect.size.x,
		_rect.position.y + (p.z + _range) / (_range * 2.0) * _rect.size.y
	)
