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

var medkit_queued := false
var scan_queued := false
var switch_queued := false
var attach_toggle_queued := false
var first_person := false

# mirrored from the player for UI display
var medkit_count := 0
var scan_cd := 0.0

var _prev_space := false
var _prev_reload := false
var _prev_medkit := false
var _prev_scan := false
var _prev_view := false
var _prev_switch := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
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

	var use_mouse := not OS.has_feature("mobile")
	sprint = touch_sprint or Input.is_key_pressed(KEY_SHIFT)
	aim = touch_aim or (use_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
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


func consume_switch() -> bool:
	var v := switch_queued
	switch_queued = false
	return v


func consume_attach() -> bool:
	var v := attach_toggle_queued
	attach_toggle_queued = false
	return v


func clear() -> void:
	move = Vector2.ZERO
	touch_move = Vector2.ZERO
	look = Vector2.ZERO
	fire = false
	aim = false
	sprint = false
	jump_queued = false
	reload_queued = false
	medkit_queued = false
	scan_queued = false
	switch_queued = false
	attach_toggle_queued = false
