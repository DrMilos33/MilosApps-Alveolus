class_name HudStatDescriptor
extends RefCounted

## Small, presentation-ready value used by HudStatStrip.
##
## The visible HUD deliberately renders only `icon_id` and `formatted_value`.
## `accessible_name` remains available to assistive tooling and tests without
## reintroducing headings or permanent explanatory copy into the run.

var icon_id: StringName = &"information"
var id: StringName = &""
var formatted_value: String = "–"
var accessible_name: String = "Wert"
var priority: int = 0


static func create(
	icon: StringName,
	value: String,
	accessible_label: String,
	value_priority: int = 0,
	stat_id: StringName = &""
) -> HudStatDescriptor:
	var descriptor := HudStatDescriptor.new()
	descriptor.id = stat_id if stat_id != &"" else icon
	descriptor.icon_id = icon
	descriptor.formatted_value = value
	descriptor.accessible_name = accessible_label
	descriptor.priority = value_priority
	return descriptor
