class_name TouchIcons
extends RefCounted
## Vector icons for the touch HUD, drawn without external art.


static func draw(c: CanvasItem, name: String, center: Vector2, r: float, color: Color) -> void:
	var lw := maxf(2.0, r * 0.085)
	var p := center
	match name:
		"fire", "fire_l":
			c.draw_circle(p, r * 0.16, color)
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(p + d * r * 0.32, p + d * r * 0.62, color, lw)
		"aim":
			c.draw_arc(p, r * 0.54, 0.0, TAU, 32, color, lw)
			c.draw_line(p + Vector2(-r * 0.82, 0), p + Vector2(r * 0.82, 0), color, lw)
			c.draw_line(p + Vector2(0, -r * 0.82), p + Vector2(0, r * 0.82), color, lw)
			c.draw_circle(p, r * 0.13, color)
		"jump":
			for row in [-0.18, 0.22]:
				var pts := PackedVector2Array([
					p + Vector2(-r * 0.38, r * row + r * 0.16),
					p + Vector2(0, r * row - r * 0.24),
					p + Vector2(r * 0.38, r * row + r * 0.16),
				])
				c.draw_polyline(pts, color, lw)
		"reload":
			c.draw_arc(p, r * 0.55, -PI * 0.35, PI * 1.25, 28, color, lw)
			var end := p + Vector2(cos(PI * 1.25), sin(PI * 1.25)) * r * 0.55
			var dir := Vector2(cos(PI * 1.25 + PI * 0.5), sin(PI * 1.25 + PI * 0.5))
			var side := Vector2(-dir.y, dir.x)
			c.draw_colored_polygon(PackedVector2Array([
				end + dir * r * 0.24,
				end - dir * r * 0.16 + side * r * 0.20,
				end - dir * r * 0.16 - side * r * 0.20,
			]), color)
		"medkit":
			c.draw_line(p + Vector2(-r * 0.42, 0), p + Vector2(r * 0.42, 0), color, lw * 2.0)
			c.draw_line(p + Vector2(0, -r * 0.42), p + Vector2(0, r * 0.42), color, lw * 2.0)
		"switch":
			_arrow(c, p + Vector2(-r * 0.52, -r * 0.20), r * 0.52, 0.0, color, lw)
			_arrow(c, p + Vector2(r * 0.52, r * 0.20), r * 0.52, PI, color, lw)
		"scan":
			for rr in [0.28, 0.48, 0.68]:
				c.draw_arc(p, r * rr, -PI * 0.75, PI * 0.25, 24, color, lw)
			c.draw_circle(p, r * 0.09, color)
			c.draw_line(p, p + Vector2(r * 0.55, -r * 0.55), color, lw)
		"grenade":
			c.draw_arc(p + Vector2(0, r * 0.08), r * 0.42, 0.0, TAU, 28, color, lw)
			c.draw_line(p + Vector2(0, -r * 0.42), p + Vector2(0, -r * 0.62), color, lw)
			c.draw_arc(p + Vector2(r * 0.12, -r * 0.68), r * 0.14, 0.0, TAU, 16, color, lw)
			c.draw_line(p + Vector2(-r * 0.28, -r * 0.20), p + Vector2(r * 0.28, r * 0.32), color, lw * 0.8)
			c.draw_line(p + Vector2(r * 0.28, -r * 0.20), p + Vector2(-r * 0.28, r * 0.32), color, lw * 0.8)
		"view":
			var pts := PackedVector2Array([
				p + Vector2(-r * 0.62, 0),
				p + Vector2(-r * 0.30, -r * 0.36),
				p + Vector2(0, -r * 0.44),
				p + Vector2(r * 0.30, -r * 0.36),
				p + Vector2(r * 0.62, 0),
				p + Vector2(r * 0.30, r * 0.36),
				p + Vector2(0, r * 0.44),
				p + Vector2(-r * 0.30, r * 0.36),
				p + Vector2(-r * 0.62, 0),
			])
			c.draw_polyline(pts, color, lw)
			c.draw_circle(p, r * 0.16, color)
		"attach":
			# wrench
			c.draw_line(p + Vector2(-r * 0.48, r * 0.48), p + Vector2(r * 0.26, -r * 0.26), color, lw * 1.7)
			c.draw_line(p + Vector2(r * 0.26, -r * 0.26), p + Vector2(r * 0.50, -r * 0.50), color, lw * 1.7)
			c.draw_line(p + Vector2(r * 0.26, -r * 0.26), p + Vector2(r * 0.50, -r * 0.10), color, lw * 1.7)
			c.draw_circle(p + Vector2(-r * 0.52, r * 0.52), r * 0.13, color)
		_:
			c.draw_circle(p, r * 0.32, color)


static func _arrow(c: CanvasItem, tail: Vector2, length: float, angle: float, color: Color, lw: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var tip := tail + dir * length
	c.draw_line(tail, tip, color, lw)
	var side := Vector2(-dir.y, dir.x)
	c.draw_colored_polygon(PackedVector2Array([
		tip + dir * length * 0.24,
		tip - dir * length * 0.12 + side * length * 0.16,
		tip - dir * length * 0.12 - side * length * 0.16,
	]), color)
