class_name IconTextButton
extends Button

## Button whose icon and caption are one centered layout unit. Callers never
## position either element manually, which prevents the recurrent offset where
## the label was centered independently of its icon.

var content_inset: MarginContainer
var content_center: CenterContainer
var content_row: HBoxContainer
var icon_view: SimpleIcon
var caption: Label
var accent := AlveolusVisualTheme.TEAL
var content_on_light_surface := false

func configure(caption_text: String, icon_kind: StringName, color: Color, icon_size: float = 22.0, gap: int = 8) -> void:
	if content_inset != null:
		content_inset.queue_free()
	text = ""
	accent = color
	custom_minimum_size.y = maxf(custom_minimum_size.y, AlveolusVisualTheme.BUTTON_HEIGHT_SECONDARY)
	var caption_width := AlveolusVisualTheme.heading_font().get_string_size(
		caption_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		AlveolusVisualTheme.TEXT_ACTION
	).x
	custom_minimum_size.x = maxf(custom_minimum_size.x, ceilf(caption_width + icon_size + float(gap) + 36.0))
	content_inset = MarginContainer.new()
	content_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_inset.add_theme_constant_override("margin_left", 18)
	content_inset.add_theme_constant_override("margin_top", 6)
	content_inset.add_theme_constant_override("margin_right", 18)
	content_inset.add_theme_constant_override("margin_bottom", 6)
	content_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_inset)
	content_center = CenterContainer.new()
	content_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_inset.add_child(content_center)
	content_row = HBoxContainer.new()
	content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_row.add_theme_constant_override("separation", gap)
	content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_center.add_child(content_row)
	icon_view = SimpleIcon.new()
	icon_view.custom_minimum_size = Vector2.ONE * icon_size
	icon_view.configure(icon_kind, color)
	content_row.add_child(icon_view)
	caption = Label.new()
	caption.text = caption_text
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	caption.add_theme_font_size_override("font_size", AlveolusVisualTheme.TEXT_ACTION)
	caption.add_theme_color_override("font_color", AlveolusVisualTheme.IVORY)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(caption)
	set_process(true)

func set_caption(value: String) -> void:
	if caption != null:
		caption.text = value

func set_content_on_light(enabled: bool) -> void:
	content_on_light_surface = enabled
	if icon_view != null:
		icon_view.configure(icon_view.kind, AlveolusVisualTheme.PETROL if enabled else accent, icon_view.framed)

func content_center_error() -> Vector2:
	if content_row == null:
		return Vector2.INF
	return content_row.get_global_rect().get_center() - get_global_rect().get_center()

func _process(_delta: float) -> void:
	if caption == null:
		return
	var enabled_color := AlveolusVisualTheme.PETROL if content_on_light_surface else AlveolusVisualTheme.IVORY
	var target := Color(AlveolusVisualTheme.SKY_DEEP, 0.50) if disabled else enabled_color
	caption.modulate = target
	icon_view.modulate = Color(1.0, 1.0, 1.0, 0.45) if disabled else Color.WHITE
