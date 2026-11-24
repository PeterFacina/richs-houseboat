extends Node

const GAME_FONT = preload("res://fonts/playfull_rocket.ttf")


func _enter_tree() -> void:
	# The project theme initializes before a fresh checkout can import the TTF.
	ThemeDB.get_default_theme().default_font = GAME_FONT
	ThemeDB.fallback_font = GAME_FONT
