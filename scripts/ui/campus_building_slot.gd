@tool
class_name CampusBuildingSlot
extends Control

## Editor-visible placeholder for one interactive campus building.
##
## The full building texture is composed from the documented Kenney layers in
## VisualAssetCatalog. At runtime the interactive CampusBuildingCard is drawn
## at this slot's bottom-centre anchor, so moving this node in the 2D editor is
## enough to move both the visible building and its hit target.

const VisualCatalog = preload("res://scripts/ui/visual_asset_catalog.gd")

@export_enum("practice", "research", "levels", "lexicon", "settings")
var building_id: String = "practice":
	set(value):
		building_id = value
		queue_redraw()

@export var editor_preview_opacity: float = 0.88:
	set(value):
		editor_preview_opacity = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	if not Engine.is_editor_hint():
		# In the game the interactive card renders the same texture. Keep this
		# preview visible only when this layout scene is run directly with F6.
		visible = get_tree().current_scene == owner


func anchor_position() -> Vector2:
	return position + Vector2(size.x * 0.5, size.y)


func _draw() -> void:
	var texture := VisualCatalog.campus_building(StringName(building_id))
	if texture == null:
		return
	var rect := _aspect_fit_rect(texture, Rect2(Vector2.ZERO, size))
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, editor_preview_opacity))
	if Engine.is_editor_hint():
		var anchor := Vector2(size.x * 0.5, size.y)
		draw_circle(anchor, 4.0, Color("eab553"))
		draw_line(anchor + Vector2(-8.0, 0.0), anchor + Vector2(8.0, 0.0), Color("123d46"), 1.0)
		draw_line(anchor + Vector2(0.0, -8.0), anchor + Vector2(0.0, 8.0), Color("123d46"), 1.0)


func _aspect_fit_rect(texture: Texture2D, target: Rect2) -> Rect2:
	if texture.get_width() <= 0 or texture.get_height() <= 0:
		return target
	var texture_aspect := float(texture.get_width()) / float(texture.get_height())
	var target_aspect := target.size.x / maxf(target.size.y, 1.0)
	var fitted_size := target.size
	if texture_aspect > target_aspect:
		fitted_size.y = target.size.x / texture_aspect
	else:
		fitted_size.x = target.size.y * texture_aspect
	return Rect2(target.position + (target.size - fitted_size) * 0.5, fitted_size)
