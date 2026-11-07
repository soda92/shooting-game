extends Node
## Tiny sound manager: pooled 2D players for UI/player sounds,
## pooled 3D players for world sounds (bot gunfire, deaths).
##
## Drop your own samples into res://assets/audio/<name>.wav (or .ogg)
## and update NAMES if you add new ones.

const NAMES := [
	"shot_rifle", "shot_smg", "shot_shotgun", "shot_sniper",
	"hit", "kill", "hurt", "death", "reload", "empty",
	"pickup", "heal", "scan", "zone_warn", "footstep",
]

const POOL_2D := 12
const POOL_3D := 16

var _streams: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _i2d := 0
var _i3d := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)

	for i in range(POOL_2D):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool2d.append(p)

	for i in range(POOL_3D):
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 90.0
		p.unit_size = 14.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool3d.append(p)

	print("[sfx] loaded %d sounds" % _streams.size())


func has_sound(name: String) -> bool:
	return _streams.has(name)


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool2d[_i2d]
	_i2d = (_i2d + 1) % _pool2d.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_at(name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool3d[_i3d]
	_i3d = (_i3d + 1) % _pool3d.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.global_position = pos
	p.play()
