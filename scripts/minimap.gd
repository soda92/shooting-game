extends Control
## Top-down minimap: island texture, safe zone, loot, scanned enemies, player.

const MAP_RANGE := 230.0

var game

var _tex: ImageTexture
var _font: SystemFont
var _built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "sans-serif"
	])
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func setup(g: Node) -> void:
	game = g
	_build_texture()


func _build_texture() -> void:
	if game == null or game.world == null:
		return
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for py in range(n):
		var wz := -MAP_RANGE + (py + 0.5) / float(n) * MAP_RANGE * 2.0
		for px in range(n):
			var wx := -MAP_RANGE + (px + 0.5) / float(n) * MAP_RANGE * 2.0
			var h: float = game.world.height_at(wx, wz)
			var c: Color
			if h < 0.0:
				c = Color(0.10, 0.30, 0.45).lerp(Color(0.05, 0.15, 0.26), clampf(-h / 14.0, 0.0, 1.0))
			elif h < 1.4:
				c = Color(0.82, 0.76, 0.56)
			elif h < 14.0:
				c = Color(0.34, 0.54, 0.27).lerp(Color(0.47, 0.63, 0.31), clampf(h / 14.0, 0.0, 1.0))
			elif h < 24.0:
				c = Color(0.48, 0.47, 0.43)
			else:
				c = Color(0.74, 0.74, 0.76)
			img.set_pixel(px, py, c)
	_tex = ImageTexture.create_from_image(img)
	_built = true


func _to_map(p: Vector3) -> Vector2:
	return Vector2(
		(p.x + MAP_RANGE) / (MAP_RANGE * 2.0) * size.x,
		(p.z + MAP_RANGE) / (MAP_RANGE * 2.0) * size.y
	)


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, Color(0.01, 0.03, 0.05, 0.55))
	if _built and _tex != null:
		draw_texture_rect(_tex, full, false)
	draw_rect(full, Color(1, 1, 1, 0.28), false, 2.0)

	if not _built or game == null or game.player == null:
		return

	draw_string(_font, Vector2(size.x * 0.5 - 4.0, 15.0), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))

	# safe zone
	var zc := _to_map(game.zone.center)
	var scale := size.x / (MAP_RANGE * 2.0)
	draw_arc(zc, game.zone.radius * scale, 0.0, TAU, 72, Color(0.45, 0.90, 1.0, 0.95), 2.0)
	var tr: float = game.zone.target_radius()
	if tr > 0.0 and tr < game.zone.radius:
		var tc := _to_map(game.zone.target_center())
		draw_arc(tc, tr * scale, 0.0, TAU, 72, Color(1, 1, 1, 0.45), 1.0)

	# POI markers
	for c in game.world.poi_centers:
		var m := _to_map(c)
		draw_rect(Rect2(m - Vector2(4, 4), Vector2(8, 8)), Color(0.92, 0.92, 0.96, 0.85))
		draw_rect(Rect2(m - Vector2(4, 4), Vector2(8, 8)), Color(0.1, 0.1, 0.12, 0.9), false, 1.0)

	# loot
	for n in get_tree().get_nodes_in_group("loot"):
		if is_instance_valid(n):
			draw_circle(_to_map(n.global_position), 2.0, Color(1.0, 0.78, 0.25, 0.9))
	for n in get_tree().get_nodes_in_group("medkit"):
		if is_instance_valid(n):
			draw_circle(_to_map(n.global_position), 2.6, Color(0.35, 1.0, 0.55, 0.95))
	for n in get_tree().get_nodes_in_group("scope"):
		if is_instance_valid(n):
			draw_circle(_to_map(n.global_position), 2.2, Color(0.72, 0.45, 1.0, 0.95))

	# enemies highlighted by the recon lens
	if game.player.scan_t > 0.0:
		for b in game.bots:
			if is_instance_valid(b) and b.is_alive():
				if game.player.global_position.distance_to(b.global_position) <= 110.0:
					draw_circle(_to_map(b.global_position), 3.0, Color(1.0, 0.25, 0.20, 0.95))

	# player arrow
	var pp := _to_map(game.player.global_position)
	var yaw: float = game.player.rotation.y
	var dir := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		pp + dir * 9.0,
		pp - dir * 5.0 + side * 5.0,
		pp - dir * 5.0 - side * 5.0,
	]), Color(1, 1, 1, 1.0))
