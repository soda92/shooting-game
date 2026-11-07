extends Node
## Sound manager: pooled 2D players for player/UI sounds, pooled 3D players
## for world sounds, distance occlusion, delayed echoes for distant gunfire,
## surface footsteps, stereo wind/surf and sparse birds.
##
## Drop your own CC0 samples into res://assets/audio/<name>.wav (or .ogg)
## and add the name to NAMES. Real recordings are always more convincing
## than synthesis; the generator in tools/gen_sfx.py provides fallbacks.

const NAMES := [
	"shot_rifle", "shot_rifle_1", "shot_rifle_2", "shot_rifle_3",
	"shot_smg", "shot_smg_1", "shot_smg_2", "shot_smg_3",
	"shot_shotgun", "shot_shotgun_1", "shot_shotgun_2", "shot_shotgun_3",
	"shot_sniper", "shot_sniper_1", "shot_sniper_2", "shot_sniper_3",
	"hit", "hit_flesh", "kill", "hurt", "death", "reload", "empty",
	"pickup", "heal", "scan", "zone_warn", "explosion", "land",
	"footstep_1", "footstep_2", "footstep_3",
	"footstep_grass_1", "footstep_grass_2", "footstep_grass_3",
	"footstep_sand_1", "footstep_sand_2", "footstep_sand_3",
	"footstep_concrete_1", "footstep_concrete_2", "footstep_concrete_3",
	"footstep_water_1", "footstep_water_2", "footstep_water_3",
	"ambient_wind", "ambient_surf", "bird_1", "bird_2",
]

const POOL_2D := 14
const POOL_3D := 24
const POOL_ECHO := 8

var _streams: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool_echo: Array[AudioStreamPlayer3D] = []
var _i2d := 0
var _i3d := 0
var _iecho := 0
var _ambient: AudioStreamPlayer
var _surf: AudioStreamPlayer
var _bird_t := 8.0
var _next_echo := 0
var _peak_checked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()

	for n in NAMES:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)

	for i in range(POOL_2D):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)

	for i in range(POOL_3D):
		_pool3d.append(_make_3d("World", 150.0))

	for i in range(POOL_ECHO):
		_pool_echo.append(_make_3d("Echo", 190.0))

	_start_ambience()
	set_process(true)
	print("[sfx] loaded %d sounds" % _streams.size())


func _make_3d(bus: String, max_dist: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = bus
	p.max_distance = max_dist
	p.unit_size = 14.0
	p.max_db = 3.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.attenuation_filter_cutoff_hz = 5200.0
	p.attenuation_filter_db = -14.0
	add_child(p)
	return p


func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "SFX")
		AudioServer.set_bus_send(i, "Master")
		var eq := AudioEffectEQ6.new()
		eq.set_band_gain_db(0, -9.0)
		eq.set_band_gain_db(5, 1.0)
		AudioServer.add_bus_effect(i, eq)

	var world := AudioServer.get_bus_index("World")
	if world == -1:
		AudioServer.add_bus()
		world = AudioServer.bus_count - 1
		AudioServer.set_bus_name(world, "World")
		AudioServer.set_bus_send(world, "Master")
	if AudioServer.get_bus_effect_count(world) == 0:
		var eq := AudioEffectEQ6.new()
		eq.set_band_gain_db(0, -12.0)
		AudioServer.add_bus_effect(world, eq)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.68
		reverb.damping = 0.62
		reverb.spread = 0.8
		reverb.predelay_msec = 24.0
		reverb.wet = 0.15
		reverb.dry = 1.0
		AudioServer.add_bus_effect(world, reverb)

	var echo := AudioServer.get_bus_index("Echo")
	if echo == -1:
		AudioServer.add_bus()
		echo = AudioServer.bus_count - 1
		AudioServer.set_bus_name(echo, "Echo")
		AudioServer.set_bus_send(echo, "Master")
	if AudioServer.get_bus_effect_count(echo) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.9
		reverb.damping = 0.5
		reverb.wet = 0.55
		reverb.dry = 0.35
		AudioServer.add_bus_effect(echo, reverb)

	var master := AudioServer.get_bus_index("Master")
	if master != -1 and AudioServer.get_bus_effect_count(master) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -16.0
		comp.ratio = 2.4
		comp.gain = 2.0
		comp.attack_us = 4000.0
		comp.release_ms = 120.0
		AudioServer.add_bus_effect(master, comp)
		var limiter := AudioEffectLimiter.new()
		limiter.threshold_db = -2.0
		limiter.ceiling_db = -0.3
		limiter.soft_clip_db = 1.0
		limiter.soft_clip_ratio = 2.0
		AudioServer.add_bus_effect(master, limiter)


func _start_ambience() -> void:
	if _streams.has("ambient_wind"):
		_ambient = AudioStreamPlayer.new()
		_ambient.stream = _streams["ambient_wind"]
		_ambient.volume_db = -25.0
		_ambient.bus = "SFX"
		add_child(_ambient)
		_ambient.finished.connect(_ambient.play)
		_ambient.play()

	if _streams.has("ambient_surf"):
		_surf = AudioStreamPlayer.new()
		_surf.stream = _streams["ambient_surf"]
		_surf.volume_db = -31.0
		_surf.bus = "SFX"
		add_child(_surf)
		_surf.finished.connect(_surf.play)
		_surf.play()


func _process(delta: float) -> void:
	_bird_t -= delta
	if _bird_t > 0.0:
		return
	_bird_t = randf_range(7.0, 19.0)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position + Vector3(
		randf_range(-38.0, 38.0), randf_range(2.0, 12.0), randf_range(-38.0, 38.0)
	)
	play_at("bird_%d" % randi_range(1, 2), p, -18.0, randf_range(0.94, 1.06))


func has_sound(name: String) -> bool:
	return _streams.has(name)


func _pick_stream(name: String) -> String:
	if name.begins_with("shot_"):
		var v := "%s_%d" % [name, randi_range(1, 3)]
		if _streams.has(v):
			return v
	return name


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var key := _pick_stream(name)
	if not _streams.has(key):
		return
	var p := _pool2d[_i2d]
	_i2d = (_i2d + 1) % _pool2d.size()
	p.stream = _streams[key]
	p.volume_db = volume_db + randf_range(-0.8, 0.8)
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()
	if OS.is_debug_build() and not _peak_checked:
		_peak_checked = true
		_check_peak()


func play_at(name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	_play_3d(name, pos, volume_db, pitch, true)


func _play_3d(name: String, pos: Vector3, volume_db: float, pitch: float, allow_echo: bool) -> void:
	var key := _pick_stream(name)
	if not _streams.has(key):
		return
	var p := _pool3d[_i3d]
	_i3d = (_i3d + 1) % _pool3d.size()

	var dist := 0.0
	var occluded := false
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		dist = cam.global_position.distance_to(pos)
		if (name.begins_with("shot_") or name == "explosion") and dist > 4.0:
			var q := PhysicsRayQueryParameters3D.create(
				cam.global_position, pos + Vector3(0.0, 0.2, 0.0), 1
			)
			var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty() and hit["position"].distance_to(pos) > 2.5:
				occluded = true

	p.stream = _streams[key]
	p.global_position = pos
	p.volume_db = volume_db + randf_range(-1.0, 1.0) + (-6.0 if occluded else 0.0)
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.attenuation_filter_cutoff_hz = 1300.0 if occluded else 5200.0
	p.play()

	if allow_echo and dist > 38.0 and (name.begins_with("shot_") or name == "explosion"):
		_schedule_echo(key, pos, dist)


func _schedule_echo(key: String, pos: Vector3, dist: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_echo:
		return
	_next_echo = now + 90
	var delay := clampf(dist / 230.0, 0.10, 0.55)
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	var p := _pool_echo[_iecho]
	_iecho = (_iecho + 1) % _pool_echo.size()
	p.stream = _streams[key]
	p.global_position = pos
	p.volume_db = -13.0
	p.pitch_scale = randf_range(0.90, 0.95)
	p.attenuation_filter_cutoff_hz = 2200.0
	p.play()


func footstep(surface := "grass", volume_db := -18.0) -> void:
	var s := "footstep_%s_%d" % [surface, randi_range(1, 3)]
	if not _streams.has(s):
		s = "footstep_%d" % randi_range(1, 3)
	play(s, volume_db, randf_range(0.9, 1.1))


func footstep_at(pos: Vector3, surface := "grass", volume_db := -14.0) -> void:
	var s := "footstep_%s_%d" % [surface, randi_range(1, 3)]
	if not _streams.has(s):
		s = "footstep_%d" % randi_range(1, 3)
	_play_3d(s, pos, volume_db, randf_range(0.9, 1.1), false)


func _check_peak() -> void:
	await get_tree().create_timer(0.12).timeout
	print("[sfx] master peak L=%.1f dB R=%.1f dB" % [
		AudioServer.get_bus_peak_volume_left_db(0, 0),
		AudioServer.get_bus_peak_volume_right_db(0, 0),
	])
