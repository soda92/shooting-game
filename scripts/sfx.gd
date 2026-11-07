extends Node
## Sound manager: pooled 2D players for player/UI sounds, pooled 3D players
## for world sounds, a reverb bus, distance low-pass, pitch jitter and wind.
##
## Drop your own samples into res://assets/audio/<name>.wav (or .ogg)
## and update NAMES if you add new ones.

const NAMES := [
	"shot_rifle", "shot_smg", "shot_shotgun", "shot_sniper",
	"hit", "kill", "hurt", "death", "reload", "empty",
	"pickup", "heal", "scan", "zone_warn", "explosion",
	"footstep_1", "footstep_2", "footstep_3", "ambient_wind",
]

const POOL_2D := 12
const POOL_3D := 16

var _streams: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _i2d := 0
var _i3d := 0
var _ambient: AudioStreamPlayer
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
		var p := AudioStreamPlayer3D.new()
		p.bus = "World"
		p.max_distance = 90.0
		p.unit_size = 14.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz = 7000.0
		p.attenuation_filter_db = -16.0
		add_child(p)
		_pool3d.append(p)

	_start_ambience()
	print("[sfx] loaded %d sounds" % _streams.size())


func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "SFX")
		AudioServer.set_bus_send(i, "Master")

	if AudioServer.get_bus_index("World") == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "World")
		AudioServer.set_bus_send(i, "Master")
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.5
		reverb.damping = 0.55
		reverb.wet = 0.14
		reverb.dry = 1.0
		AudioServer.add_bus_effect(i, reverb)

	var master := AudioServer.get_bus_index("Master")
	if master != -1 and AudioServer.get_bus_effect_count(master) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.threshold_db = -2.0
		limiter.ceiling_db = -0.3
		limiter.soft_clip_db = 1.0
		limiter.soft_clip_ratio = 2.0
		AudioServer.add_bus_effect(master, limiter)


func _start_ambience() -> void:
	if not _streams.has("ambient_wind"):
		return
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _streams["ambient_wind"]
	_ambient.volume_db = -26.0
	_ambient.bus = "SFX"
	add_child(_ambient)
	_ambient.finished.connect(_ambient.play)
	_ambient.play()


func has_sound(name: String) -> bool:
	return _streams.has(name)


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool2d[_i2d]
	_i2d = (_i2d + 1) % _pool2d.size()
	p.stream = _streams[name]
	p.volume_db = volume_db + randf_range(-0.8, 0.8)
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()
	if OS.is_debug_build() and not _peak_checked:
		_peak_checked = true
		_check_peak()


func play_at(name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool3d[_i3d]
	_i3d = (_i3d + 1) % _pool3d.size()
	p.stream = _streams[name]
	p.volume_db = volume_db + randf_range(-1.0, 1.0)
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.global_position = pos
	p.play()


func footstep(volume_db := -18.0) -> void:
	play("footstep_%d" % randi_range(1, 3), volume_db, randf_range(0.9, 1.1))


func _check_peak() -> void:
	await get_tree().create_timer(0.12).timeout
	print("[sfx] master peak L=%.1f dB R=%.1f dB" % [
		AudioServer.get_bus_peak_volume_left_db(0, 0),
		AudioServer.get_bus_peak_volume_right_db(0, 0),
	])
