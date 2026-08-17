class_name HudStatStrip
extends HFlowContainer

## Transparent, pointer-pass-through run statistics.
##
## This component intentionally owns no panel, title or visible captions. The
## expanded explanations live in the paused statistics view.

const MAX_STATS := 5
const MAXIMUM_SIZE := Vector2(432.0, 50.0)
const ROW_HEIGHT := 22.0
const ROW_WIDTH := 78.0
const ICON_SIZE := 18.0
const ROW_GAP := 6

var descriptors: Array[HudStatDescriptor] = []


func _ready() -> void:
	name = "HudStatStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	add_theme_constant_override("h_separation", ROW_GAP)
	add_theme_constant_override("v_separation", 4)


func set_descriptors(values: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	descriptors.clear()
	for value in values:
		if value is HudStatDescriptor:
			descriptors.append(value)
	descriptors.sort_custom(func(a: HudStatDescriptor, b: HudStatDescriptor) -> bool:
		return a.priority > b.priority
	)
	if descriptors.size() > MAX_STATS:
		descriptors.resize(MAX_STATS)
	for descriptor in descriptors:
		add_child(_build_row(descriptor))
	custom_minimum_size.y = ROW_HEIGHT


func _build_row(descriptor: HudStatDescriptor) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta(&"accessible_name", "%s: %s" % [descriptor.accessible_name, descriptor.formatted_value])

	var icon := SimpleIcon.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.configure(descriptor.icon_id, AlveolusVisualTheme.IVORY)
	row.add_child(icon)

	var value := Label.new()
	value.text = descriptor.formatted_value
	value.custom_minimum_size = Vector2(54.0, ROW_HEIGHT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", AlveolusVisualTheme.IVORY)
	value.add_theme_color_override("font_outline_color", Color(AlveolusVisualTheme.PETROL, 0.96))
	value.add_theme_constant_override("outline_size", 3)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)
	return row
