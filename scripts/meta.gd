extends Node
## Match configuration chosen on the start screen.

var mode := "br"          # "br" or "range"
var difficulty := 1       # 0 easy, 1 normal, 2 hard


func bot_reaction_scale() -> float:
	return [1.5, 1.0, 0.6][difficulty]


func bot_damage_scale() -> float:
	return [0.7, 1.0, 1.3][difficulty]


func bot_spread_scale() -> float:
	return [1.6, 1.0, 0.7][difficulty]


func bot_interval_scale() -> float:
	return [1.4, 1.0, 0.8][difficulty]
