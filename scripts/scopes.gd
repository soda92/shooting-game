class_name Scopes
extends RefCounted
## Sight attachments. "iron" is always owned; the rest must be picked up.

const ORDER := ["iron", "red_dot", "4x", "8x"]

const LIST := {
	"iron": {
		"name": "机瞄", "short": "机瞄", "tag": "IR",
		"fov": 46.0, "overlay": "iron",
	},
	"red_dot": {
		"name": "红点镜", "short": "红点", "tag": "RD",
		"fov": 55.0, "overlay": "red_dot",
	},
	"4x": {
		"name": "4 倍镜", "short": "4x", "tag": "4X",
		"fov": 28.0, "overlay": "scope",
	},
	"8x": {
		"name": "8 倍镜", "short": "8x", "tag": "8X",
		"fov": 15.0, "overlay": "scope",
	},
}


static func get_def(id: String) -> Dictionary:
	return LIST.get(id, LIST["iron"])
