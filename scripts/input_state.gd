extends Node
## Shared input state.
## Touch UI writes into touch_* fields, keyboard/mouse is read here,
## and the player/bots consume the resulting values.

var move := Vector2.ZERO        # x: strafe right, y: forward
var look := Vector2.ZERO        # accumulated look delta, in pixels
var fire := false
var aim := false
var sprint := false
var jump_queued := false
var reload_queued := false
var locked := false             # true while menus / end screens are up

var touch_move := Vector2.ZERO
var touch_fire := false
var touch_aim := false
var touch_sprint := false
var aim_toggle := false

var medkit_queued := false
var scan_queued := false
var switch_queued := false
var grenade_queued := false
var attach_toggle_queued := false
var first_person := false
var touch_layout: Dictionary = {}
var joy_home := Vector2(-1.0, -1.0)

# mirrored from the player for UI display
var medkit_count := 0
var grenade_count := 0
var scan_cd := 0.0

var sensitivity := 1.0
var master_volume := 0.8
var gyro := false
var aim_toggle_mode := true

const SETTINGS_PATH := "user://settings.cfg"

var _prev_space := false
var _prev_reload := false
var _prev_medkit := false
var _prev_scan := false
var _prev_view := false
var _prev_switch := false
var _prev_grenade := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_volume()


func _process(delta: float) -> void:
	if locked:
		move = Vector2.ZERO
		touch_move = Vector2.ZERO
		look = Vector2.ZERO
		fire = false
		aim = false
		sprint = false
		return

	var kb := Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb.x -= 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		kb.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		kb.y -= 1.0
	kb = kb.limit_length(1.0)

	move = touch_move if touch_move.length() > 0.1 else kb

	var space := Input.is_key_pressed(KEY_SPACE)
	if space and not _prev_space:
		jump_queued = true
	_prev_space = space

	var rl := Input.is_key_pressed(KEY_R)
	if rl and not _prev_reload:
		reload_queued = true
	_prev_reload = rl

	var mk := Input.is_key_pressed(KEY_H)
	if mk and not _prev_medkit:
		medkit_queued = true
	_prev_medkit = mk

	var sc := Input.is_key_pressed(KEY_F)
	if sc and not _prev_scan:
		scan_queued = true
	_prev_scan = sc

	var vw := Input.is_key_pressed(KEY_V)
	if vw and not _prev_view:
		first_person = not first_person
	_prev_view = vw

	var sw := Input.is_key_pressed(KEY_Q)
	if sw and not _prev_switch:
		switch_queued = true
	_prev_switch = sw

	var gr := Input.is_key_pressed(KEY_G)
	if gr and not _prev_grenade:
		grenade_queued = true
	_prev_grenade = gr

	if gyro and OS.has_feature("mobile"):
		var g := Input.get_gyroscope()
		look.x += g.y * 300.0 * sensitivity * delta
		look.y += -g.x * 300.0 * sensitivity * delta

	var use_mouse := not OS.has_feature("mobile")
	sprint = touch_sprint or Input.is_key_pressed(KEY_SHIFT)
	aim = aim_toggle or touch_aim or (use_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	fire = touch_fire or (use_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look += event.relative


func consume_look() -> Vector2:
	var v := look
	look = Vector2.ZERO
	return v


func consume_jump() -> bool:
	var v := jump_queued
	jump_queued = false
	return v


func consume_reload() -> bool:
	var v := reload_queued
	reload_queued = false
	return v


func consume_medkit() -> bool:
	var v := medkit_queued
	medkit_queued = false
	return v


func consume_scan() -> bool:
	var v := scan_queued
	scan_queued = false
	return v


func consume_grenade() -> bool:
	var v := grenade_queued
	grenade_queued = false
	return v


func consume_switch() -> bool:
	var v := switch_queued
	switch_queued = false
	return v


func consume_attach() -> bool:
	var v := attach_toggle_queued
	attach_toggle_queued = false
	return v


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		sensitivity = float(cf.get_value("input", "sensitivity", sensitivity))
		gyro = bool(cf.get_value("input", "gyro", gyro))
		aim_toggle_mode = bool(cf.get_value("input", "aim_toggle", aim_toggle_mode))
		master_volume = float(cf.get_value("audio", "master", master_volume))
		var layout = cf.get_value("layout", "buttons", {})
		if layout is Dictionary:
			for key in layout:
				var v = layout[key]
				if v is Vector2:
					touch_layout[String(key)] = Vector2(
						clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0))
		var j = cf.get_value("layout", "joystick", null)
		if j is Vector2:
			joy_home = Vector2(clampf(j.x, 0.0, 1.0), clampf(j.y, 0.0, 1.0))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("input", "sensitivity", sensitivity)
	cf.set_value("input", "gyro", gyro)
	cf.set_value("input", "aim_toggle", aim_toggle_mode)
	cf.set_value("audio", "master", master_volume)
	cf.set_value("layout", "buttons", touch_layout)
	cf.set_value("layout", "joystick", joy_home)
	cf.save(SETTINGS_PATH)


func set_touch_layout(name: String, rel: Vector2) -> void:
	touch_layout[name] = Vector2(clampf(rel.x, 0.0, 1.0), clampf(rel.y, 0.0, 1.0))
	save_settings()


func set_joy_home(rel: Vector2) -> void:
	joy_home = Vector2(clampf(rel.x, 0.0, 1.0), clampf(rel.y, 0.0, 1.0))
	save_settings()


func reset_touch_layout() -> void:
	touch_layout.clear()
	joy_home = Vector2(-1.0, -1.0)
	save_settings()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))


func set_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	save_settings()


func set_sensitivity(v: float) -> void:
	sensitivity = clampf(v, 0.3, 2.0)
	save_settings()


func set_gyro(v: bool) -> void:
	gyro = v
	save_settings()


func set_aim_mode(toggle_mode: bool) -> void:
	aim_toggle_mode = toggle_mode
	aim_toggle = false
	touch_aim = false
	save_settings()


func clear() -> void:
	move = Vector2.ZERO
	touch_move = Vector2.ZERO
	look = Vector2.ZERO
	fire = false
	aim = false
	aim_toggle = false
	sprint = false
	jump_queued = false
	reload_queued = false
	medkit_queued = false
	scan_queued = false
	switch_queued = false
	grenade_queued = false
	attach_toggle_queued = false
