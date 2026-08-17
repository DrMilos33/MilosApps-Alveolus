class_name CampusScene
extends Control

## Runtime host for the editor-authored campus layout.
##
## The map itself lives in scenes/ui/campus_layout.tscn. Building positions are
## read from its visible BuildingSlots, which keeps the existing GameHUD API
## stable while making the layout editable without changing code.

const LAYOUT_SCENE := preload("res://scenes/ui/campus_layout.tscn")
const BUILDING_IDS: Array[StringName] = [
	&"practice",
	&"research",
	&"levels",
	&"lexicon",
	&"settings",
]

static var _building_anchor_cache: Dictionary = {}


static func building_anchor(id: StringName) -> Vector2:
	if _building_anchor_cache.is_empty():
		_cache_building_anchors()
	return _building_anchor_cache.get(id, Vector2(640.0, 360.0))


static func _cache_building_anchors() -> void:
	var layout := LAYOUT_SCENE.instantiate() as Control
	if layout == null:
		return
	var slots := layout.get_node_or_null("BuildingSlots") as Control
	for id in BUILDING_IDS:
		var slot := layout.get_node_or_null("BuildingSlots/%s" % id) as Control
		if slot != null:
			var slots_offset := slots.position if slots != null else Vector2.ZERO
			_building_anchor_cache[id] = slots_offset + slot.position + Vector2(slot.size.x * 0.5, slot.size.y)
	layout.free()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout := LAYOUT_SCENE.instantiate() as Control
	if layout == null:
		push_error("Campus layout scene could not be instantiated.")
		return
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
