class_name CampusScene
extends Control

const BACKGROUND_PATH := "res://assets/art/campus_evening_v2.png"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = load(BACKGROUND_PATH) as Texture2D
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# The illustration intentionally keeps the upper corners quiet for the
	# persistent logo and status. This soft veil guarantees their legibility.
	var header_veil := ColorRect.new()
	header_veil.position = Vector2.ZERO
	header_veil.size = Vector2(1280.0, 105.0)
	header_veil.color = Color(0.015, 0.035, 0.065, 0.30)
	header_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_veil)
