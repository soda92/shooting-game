class_name Skins
extends RefCounted
## Outfit palettes. Add entries here and use them in player.gd / bot.gd.

const PLAYER_INDEX := 0

static var selected_index := 0

static var LIST := [
	{
		"name": "特战蓝",
		"shirt": Color(0.16, 0.30, 0.58),
		"vest": Color(0.08, 0.10, 0.15),
		"pants": Color(0.12, 0.16, 0.24),
		"helmet": Color(0.14, 0.24, 0.46),
		"skin": Color(0.86, 0.72, 0.57),
	},
	{
		"name": "丛林",
		"shirt": Color(0.27, 0.38, 0.20),
		"vest": Color(0.13, 0.16, 0.10),
		"pants": Color(0.19, 0.24, 0.15),
		"helmet": Color(0.22, 0.30, 0.16),
		"skin": Color(0.82, 0.68, 0.52),
	},
	{
		"name": "沙漠",
		"shirt": Color(0.68, 0.58, 0.38),
		"vest": Color(0.33, 0.28, 0.18),
		"pants": Color(0.52, 0.45, 0.30),
		"helmet": Color(0.60, 0.51, 0.33),
		"skin": Color(0.78, 0.62, 0.45),
	},
	{
		"name": "都市",
		"shirt": Color(0.34, 0.36, 0.40),
		"vest": Color(0.13, 0.14, 0.16),
		"pants": Color(0.24, 0.25, 0.28),
		"helmet": Color(0.28, 0.30, 0.34),
		"skin": Color(0.80, 0.66, 0.50),
	},
	{
		"name": "雪地",
		"shirt": Color(0.84, 0.87, 0.88),
		"vest": Color(0.35, 0.38, 0.42),
		"pants": Color(0.70, 0.74, 0.76),
		"helmet": Color(0.88, 0.90, 0.92),
		"skin": Color(0.88, 0.74, 0.60),
	},
	{
		"name": "赤红",
		"shirt": Color(0.55, 0.22, 0.14),
		"vest": Color(0.18, 0.10, 0.08),
		"pants": Color(0.34, 0.16, 0.12),
		"helmet": Color(0.46, 0.18, 0.12),
		"skin": Color(0.80, 0.64, 0.48),
	},
	{
		"name": "樱粉",
		"style": "anime",
		"hair": Color(1.00, 0.55, 0.72),
		"blouse": Color(0.95, 0.95, 0.97),
		"skirt": Color(0.16, 0.18, 0.32),
		"socks": Color(0.12, 0.12, 0.16),
		"shoe": Color(0.95, 0.95, 0.97),
		"skin": Color(0.98, 0.84, 0.76),
		"eye": Color(0.10, 0.35, 0.55),
	},
	{
		"name": "赛博青",
		"style": "anime",
		"hair": Color(0.25, 0.85, 0.90),
		"blouse": Color(0.12, 0.14, 0.20),
		"skirt": Color(0.08, 0.10, 0.16),
		"socks": Color(0.18, 0.20, 0.26),
		"shoe": Color(0.90, 0.20, 0.55),
		"skin": Color(0.96, 0.82, 0.74),
		"eye": Color(0.90, 0.30, 0.50),
	},
	{
		"name": "二次元·樱",
		"style": "model",
		"model": "res://assets/models/anime_pink.glb",
		"model_yaw": PI,
	},
]


## Models listed here are always included in exported builds.
## Add your own path here after dropping a .glb into assets/models/.
## Example:
##   "res://assets/models/my_anime_skin.glb",
const MODEL_MANIFEST := [
	"res://assets/models/anime_pink.glb",
]


static func player_skin() -> Dictionary:
	return LIST[selected_index % LIST.size()]


static func cycle() -> Dictionary:
	selected_index = (selected_index + 1) % LIST.size()
	return player_skin()


static func random_bot_skin() -> Dictionary:
	var pool: Array = []
	for i in range(1, LIST.size()):
		if String(LIST[i].get("style", "soldier")) == "soldier":
			pool.append(LIST[i])
	return pool[randi() % pool.size()]


## Models from MODEL_MANIFEST are registered first (works in exported builds);
## the directory scan then picks up anything else when running from the editor.
static func refresh_models() -> void:
	for path in MODEL_MANIFEST:
		if ResourceLoader.exists(path):
			_add_model(path)

	var dir := DirAccess.open("res://assets/models")
	if dir != null:
		for f in dir.get_files():
			var lower := f.to_lower()
			if lower.ends_with(".glb") or lower.ends_with(".gltf"):
				_add_model("res://assets/models/" + f)

	print("[skins] %d entries" % LIST.size())


static func _add_model(path: String) -> void:
	for s in LIST:
		if String(s.get("model", "")) == path:
			return
	LIST.append({
		"name": path.get_file().get_basename(),
		"style": "model",
		"model": path,
		"model_yaw": 0.0,
	})
