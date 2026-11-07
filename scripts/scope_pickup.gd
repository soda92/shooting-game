extends Area3D
## Sight pickup. Walking over it unlocks the scope in the attachment panel.

var scope_id := "red_dot"

var _t := 0.0
var _base_y := 0.0

@onready var label: Label3D = $Label


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)


func setup(id: String) -> void:
	scope_id = id
	if label != null:
		label.text = String(Scopes.get_def(id)["tag"])


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 1.4
	position.y = _base_y + sin(_t * 2.0) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("add_scope"):
		return
	if not body.is_alive():
		return
	body.add_scope(scope_id)
	queue_free()
