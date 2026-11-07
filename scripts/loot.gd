extends Area3D
## Floating weapon crate. Walk over it to swap weapons.

var weapon_id := "rifle"
var _pickup_delay := 0.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var label: Label3D = $Label

var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)


func setup(id: String, delay := 0.0) -> void:
	weapon_id = id
	_pickup_delay = delay
	if label != null:
		label.text = String(Weapons.get_def(id)["short"])


func _process(delta: float) -> void:
	_pickup_delay = maxf(0.0, _pickup_delay - delta)
	_t += delta
	rotation.y += delta * 1.6
	position.y = _base_y + sin(_t * 2.0) * 0.18


func _on_body_entered(body: Node3D) -> void:
	if _pickup_delay > 0.0:
		return
	if not body.has_method("give_weapon"):
		return
	if not body.is_alive():
		return
	body.give_weapon(weapon_id)
	queue_free()
