extends Node3D
## Shrinking safe zone. Damage per second rises with each phase.

signal phase_changed(index: int)

const PHASES := [
	{"wait": 35.0, "to": 130.0, "time": 35.0, "dps": 2.0},
	{"wait": 25.0, "to": 82.0, "time": 30.0, "dps": 4.0},
	{"wait": 20.0, "to": 44.0, "time": 25.0, "dps": 7.0},
	{"wait": 15.0, "to": 18.0, "time": 20.0, "dps": 11.0},
	{"wait": 10.0, "to": 0.0, "time": 25.0, "dps": 16.0},
]

var center := Vector3.ZERO
var radius := 215.0
var dps := 2.0
var shrinking := false

var _phase := 0
var _timer := 35.0
var _shrink_t := 0.0
var _from_r := 215.0
var _to_r := 215.0
var _shrink_dur := 1.0
var _from_center := Vector3.ZERO
var _to_center := Vector3.ZERO

@onready var wall: MeshInstance3D = $Wall


func reset(start_radius: float) -> void:
	center = Vector3(0.0, 0.0, 0.0)
	radius = start_radius
	_phase = 0
	shrinking = false
	_timer = float(PHASES[0]["wait"])
	dps = 0.0
	_from_center = center
	_to_center = center
	_prepare_next()
	_update_wall()


func _prepare_next() -> void:
	if _phase >= PHASES.size():
		return
	var ph: Dictionary = PHASES[_phase]
	_to_r = float(ph["to"])
	var max_off := maxf(0.0, radius - _to_r)
	var ang := randf() * TAU
	var off := randf() * max_off * 0.9
	_to_center = center + Vector3(cos(ang) * off, 0.0, sin(ang) * off)


func _process(delta: float) -> void:
	if _phase >= PHASES.size():
		return

	var ph: Dictionary = PHASES[_phase]

	if not shrinking:
		_timer -= delta
		if _timer <= 0.0:
			shrinking = true
			_shrink_t = 0.0
			_from_r = radius
			_from_center = center
			_shrink_dur = float(ph["time"])
			dps = float(ph["dps"])
			phase_changed.emit(_phase)
	else:
		_shrink_t += delta
		var t := clampf(_shrink_t / _shrink_dur, 0.0, 1.0)
		radius = lerpf(_from_r, _to_r, t)
		center = _from_center.lerp(_to_center, t)
		if t >= 1.0:
			shrinking = false
			center = _to_center
			radius = _to_r
			_phase += 1
			if _phase < PHASES.size():
				_timer = float(PHASES[_phase]["wait"])
				_prepare_next()
	_update_wall()


func _update_wall() -> void:
	wall.scale = Vector3(maxf(radius, 0.5), 140.0, maxf(radius, 0.5))
	wall.position = Vector3(center.x, 70.0, center.z)


func time_left() -> float:
	if shrinking:
		return maxf(0.0, _shrink_dur - _shrink_t)
	return maxf(0.0, _timer)


func status_text() -> String:
	if _phase >= PHASES.size():
		return "安全区已消失"
	var t := int(ceil(time_left()))
	var mm := t / 60
	var ss := t % 60
	if shrinking:
		return "安全区收缩中  %d:%02d  ·  半径 %dm" % [mm, ss, int(radius)]
	return "下次缩圈  %d:%02d  ·  半径 %dm" % [mm, ss, int(radius)]


func is_inside(pos: Vector3) -> bool:
	var flat := Vector2(pos.x - center.x, pos.z - center.z)
	return flat.length() <= radius


func target_radius() -> float:
	if _phase >= PHASES.size():
		return 0.0
	return _to_r


func target_center() -> Vector3:
	return _to_center
