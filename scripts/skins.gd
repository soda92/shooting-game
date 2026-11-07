class_name Skins
extends RefCounted
## Outfit palettes. Add entries here and use them in player.gd / bot.gd.

const PLAYER_INDEX := 0

static var selected_index := 0

const LIST := [
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
]


static func player_skin() -> Dictionary:
	return LIST[selected_index % LIST.size()]


static func cycle() -> Dictionary:
	selected_index = (selected_index + 1) % LIST.size()
	return player_skin()


static func random_bot_skin() -> Dictionary:
	return LIST[randi_range(1, LIST.size() - 1)]
