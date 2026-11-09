extends Node3D
## Opening cargo plane that flies a straight path across the island.

signal finished
signal force_jump

const SPEED := 80.0

var _dir := Vector3.FORWARD
var _distance := 1.0
var _traveled := 0.0
var _force_distance := -1.0
var _forced := false
var _props: Array[MeshInstance3D] = []
var _t := 0.0


func set_force_distance(d: float) -> void:
	_force_distance = d


func setup(start: Vector3, finish: Vector3) -> void:
	global_position = start
	_dir = (finish - start).normalized()
	_distance = start.distance_to(finish)
	rotation.y = atan2(-_dir.x, -_dir.z)


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta
	global_position += _dir * SPEED * delta
	_traveled += SPEED * delta
	if not _forced and _force_distance >= 0.0 and _traveled >= _force_distance:
		_forced = true
		force_jump.emit()
	for p in _props:
		p.rotation.z += delta * 34.0
	rotation.z = sin(_t * 0.7) * 0.025
	if _traveled >= _distance:
		finished.emit()
		queue_free()


func _build() -> void:
	var body := _mat(Color(0.60, 0.64, 0.68))
	var belly := _mat(Color(0.32, 0.35, 0.40))
	var accent := _mat(Color(0.80, 0.20, 0.16))
	var dark := _mat(Color(0.12, 0.14, 0.17))

	# fuselage
	var hull := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.82
	hm.bottom_radius = 0.82
	hm.height = 9.0
	hm.radial_segments = 12
	hull.mesh = hm
	hull.material_override = body
	hull.rotation.x = PI * 0.5
	add_child(hull)

	var nose := MeshInstance3D.new()
	var nm := SphereMesh.new()
	nm.radius = 0.82
	nm.height = 1.64
	nm.radial_segments = 12
	nm.rings = 6
	nose.mesh = nm
	nose.material_override = body
	nose.position = Vector3(0, 0, -4.5)
	add_child(nose)

	var tail := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.38
	tm.bottom_radius = 0.78
	tm.height = 2.2
	tm.radial_segments = 10
	tail.mesh = tm
	tail.material_override = body
	tail.rotation.x = PI * 0.5
	tail.position = Vector3(0, 0.05, 5.2)
	add_child(tail)

	# stripe
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.06, 0.30, 7.4)
	stripe.mesh = sm
	stripe.material_override = accent
	stripe.position = Vector3(0.82, 0.05, 0)
	add_child(stripe)

	# wings
	var wing := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(16.0, 0.24, 2.5)
	wing.mesh = wm
	wing.material_override = body
	wing.position = Vector3(0, 0.05, -0.4)
	add_child(wing)

	var tailplane := MeshInstance3D.new()
	var tpm := BoxMesh.new()
	tpm.size = Vector3(6.4, 0.18, 1.5)
	tailplane.mesh = tpm
	tailplane.material_override = body
	tailplane.position = Vector3(0, 0.25, 4.6)
	add_child(tailplane)

	var fin := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.18, 1.9, 1.5)
	fin.mesh = fm
	fin.material_override = body
	fin.position = Vector3(0, 1.15, 4.6)
	add_child(fin)

	# engine pods and propellers
	for side in [-1.0, 1.0]:
		var pod := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.38
		pm.bottom_radius = 0.44
		pm.height = 2.0
		pm.radial_segments = 9
		pod.mesh = pm
		pod.material_override = belly
		pod.rotation.x = PI * 0.5
		pod.position = Vector3(side * 3.1, -0.18, -0.1)
		add_child(pod)

		var prop := MeshInstance3D.new()
		var prm := BoxMesh.new()
		prm.size = Vector3(0.10, 2.25, 0.08)
		prop.mesh = prm
		prop.material_override = dark
		prop.position = Vector3(side * 3.1, -0.18, -1.15)
		add_child(prop)
		_props.append(prop)

		var light := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.12
		lm.height = 0.24
		lm.radial_segments = 6
		lm.rings = 3
		light.mesh = lm
		var lmat := StandardMaterial3D.new()
		lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lmat.albedo_color = Color(1.0, 0.2, 0.15) if side < 0.0 else Color(0.2, 1.0, 0.35)
		lmat.emission_enabled = true
		lmat.emission = lmat.albedo_color
		lmat.emission_energy_multiplier = 2.5
		light.material_override = lmat
		light.position = Vector3(side * 7.9, 0.05, -0.4)
		add_child(light)

	# cockpit glass
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(1.10, 0.35, 1.3)
	glass.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.12, 0.25, 0.34)
	gmat.metallic = 0.5
	gmat.roughness = 0.15
	glass.material_override = gmat
	glass.position = Vector3(0, 0.72, -3.4)
	add_child(glass)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.65
	m.metallic = 0.15
	return m
