extends Area3D
## Floating medkit. Walk over it to store one (max 3).

var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 1.8
	position.y = _base_y + sin(_t * 2.0) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("add_medkit"):
		return
	if not body.is_alive():
		return
	if body.add_medkit():
		queue_free()
