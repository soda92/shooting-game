extends Area3D
## Body armor pickup (vest + helmet). Grants up to 100 armor.

var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 1.2
	position.y = _base_y + sin(_t * 2.0) * 0.10


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("add_armor"):
		return
	if not body.is_alive():
		return
	if body.add_armor(100.0):
		queue_free()
