extends StaticBody3D
## Training dummy. Takes hits, flashes, falls for 1.5s and respawns.

var max_health := 100.0
var health := 100.0
var game
var _down := false

@onready var body: MeshInstance3D = $Body
@onready var collision: CollisionShape3D = $Collision


func setup(g: Node) -> void:
	game = g


func take_damage(amount: float, _attacker: Node = null) -> void:
	if _down:
		return
	health -= amount
	if game != null:
		game.target_hits += 1
	_flash()
	if health <= 0.0:
		_down = true
		collision_layer = 0
		body.visible = false
		get_tree().create_timer(1.5).timeout.connect(_respawn)


func _respawn() -> void:
	health = max_health
	_down = false
	collision_layer = 1
	body.visible = true


func _flash() -> void:
	if body.material_override == null:
		return
	var mat: StandardMaterial3D = body.material_override
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color", Color(0.85, 0.24, 0.20), 0.14)
