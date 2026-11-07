class_name Weapons
extends RefCounted
## Static weapon definitions shared by player, bots and loot.

const ORDER := ["rifle", "smg", "shotgun", "sniper"]

const DEFS := {
	"rifle": {
		"label": "M4 步枪",
		"short": "M4",
		"damage": 24.0,
		"rpm": 540.0,
		"mag": 30,
		"reserve": 150,
		"spread_deg": 1.3,
		"pellets": 1,
		"auto": true,
		"range": 220.0,
		"reload": 1.7,
	},
	"smg": {
		"label": "UZI 冲锋枪",
		"short": "UZI",
		"damage": 15.0,
		"rpm": 780.0,
		"mag": 32,
		"reserve": 192,
		"spread_deg": 2.4,
		"pellets": 1,
		"auto": true,
		"range": 120.0,
		"reload": 1.4,
	},
	"shotgun": {
		"label": "S12 霰弹枪",
		"short": "S12",
		"damage": 11.0,
		"rpm": 75.0,
		"mag": 6,
		"reserve": 36,
		"spread_deg": 6.0,
		"pellets": 8,
		"auto": false,
		"range": 60.0,
		"reload": 2.2,
	},
	"sniper": {
		"label": "AWM 狙击枪",
		"short": "AWM",
		"damage": 85.0,
		"rpm": 45.0,
		"mag": 5,
		"reserve": 25,
		"spread_deg": 0.3,
		"pellets": 1,
		"auto": false,
		"range": 400.0,
		"reload": 2.6,
	},
}


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["rifle"])


static func shot_interval(id: String) -> float:
	return 60.0 / float(get_def(id)["rpm"])
