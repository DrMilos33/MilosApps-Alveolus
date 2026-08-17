class_name LexiconMasterDetail
extends Control

signal category_changed(category: StringName)
signal entry_selected(entry_id: StringName)

const OUTER_MARGIN := 24
const CONTENT_GAP := 14
const LIST_WIDTH := 310.0

var provider: LexiconViewModelProvider
var seen_discovery_ids: Variant = []
var definitions: Array[LexiconEntryDefinition] = []
var selected_category: StringName = LexiconEntryDefinition.CATEGORY_MONSTERS
var selected_entry_id: StringName = &""

var category_buttons: Dictionary = {}
var entry_buttons: Dictionary = {}
var entry_view_models: Dictionary = {}

var category_bar: GridContainer
var content_row: HBoxContainer
var list_panel: PanelContainer
var detail_panel: PanelContainer
var compact_back_button: Button
var compact_detail_visible: bool = false
var entry_scroll: ScrollContainer
var entry_list: VBoxContainer
var detail_scroll: ScrollContainer
var detail_content: VBoxContainer
var detail_illustration: MedicalLexiconIllustration
var detail_category_label: Label
var detail_title: Label
var detail_medical_name: Label
var detail_summary: Label
var detail_gameplay_title: Label
var detail_gameplay_text: Label
var detail_gameplay_panel: PanelContainer
var detail_stats_title: Label
var detail_stats_grid: GridContainer
var detail_medical_title: Label
var detail_medical_text: Label
var detail_medical_panel: PanelContainer
var detail_related_title: Label
var detail_related_text: Label
var empty_detail_label: Label

func _ready() -> void:
	if provider == null:
		provider = LexiconViewModelProvider.create_default()
	if definitions.is_empty():
		definitions = LexiconCatalog.entries()
	theme = AlveolusVisualTheme.create_theme()
	_build_layout()
	_build_category_buttons()
	select_category(selected_category, false)
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func configure(
	view_model_provider: LexiconViewModelProvider = null,
	discovered_ids: Variant = [],
	entry_definitions: Array[LexiconEntryDefinition] = []
) -> void:
	provider = LexiconViewModelProvider.create_default() if view_model_provider == null else view_model_provider
	seen_discovery_ids = discovered_ids
	definitions = LexiconCatalog.entries() if entry_definitions.is_empty() else entry_definitions
	if is_node_ready():
		select_category(selected_category, false)

func set_seen_discoveries(discovered_ids: Variant) -> void:
	seen_discovery_ids = discovered_ids
	if is_node_ready():
		select_category(selected_category, false)

func select_category(category: StringName, focus_first_entry: bool = false) -> void:
	if not LexiconCatalog.CATEGORY_ORDER.has(category):
		return
	selected_category = category
	selected_entry_id = &""
	_update_category_states()
	_rebuild_entry_list()
	var visible_definitions := _visible_definitions()
	if visible_definitions.is_empty():
		_show_empty_detail()
	else:
		select_entry(visible_definitions[0].id, false)
	if _is_compact():
		compact_detail_visible = false
		_apply_responsive_layout()
	_configure_focus_neighbors()
	category_changed.emit(category)
	if focus_first_entry and not entry_buttons.is_empty():
		var first_definition := visible_definitions[0]
		var first_button := entry_buttons.get(first_definition.id) as Button
		if first_button != null:
			first_button.grab_focus()

func select_entry(entry_id: StringName, move_focus: bool = false) -> bool:
	var view_model := entry_view_models.get(entry_id) as LexiconEntryViewModel
	if view_model == null:
		return false
	selected_entry_id = entry_id
	for id in entry_buttons:
		var button := entry_buttons[id] as Button
		button.button_pressed = id == entry_id
	_show_detail(view_model)
	if _is_compact() and move_focus:
		compact_detail_visible = true
		_apply_responsive_layout()
		compact_back_button.grab_focus.call_deferred()
	if move_focus:
		var selected_button := entry_buttons.get(entry_id) as Button
		if selected_button != null:
			selected_button.grab_focus()
	entry_selected.emit(entry_id)
	return true

func grab_initial_focus() -> void:
	var button := category_buttons.get(selected_category) as Button
	if button != null:
		button.grab_focus()

func _build_layout() -> void:
	var background := PanelContainer.new()
	background.name = "Surface"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.SECTION_GROUP,
		AlveolusVisualTheme.TEAL,
		AlveolusVisualTheme.CornerTreatment.NONE
	))
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", OUTER_MARGIN)
	margin.add_theme_constant_override("margin_top", OUTER_MARGIN)
	margin.add_theme_constant_override("margin_right", OUTER_MARGIN)
	margin.add_theme_constant_override("margin_bottom", OUTER_MARGIN)
	background.add_child(margin)

	var page := VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", CONTENT_GAP)
	margin.add_child(page)

	category_bar = GridContainer.new()
	category_bar.name = "CategoryBar"
	category_bar.columns = 4
	category_bar.custom_minimum_size.y = 48.0
	category_bar.add_theme_constant_override("separation", 10)
	page.add_child(category_bar)

	content_row = HBoxContainer.new()
	content_row.name = "Content"
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", CONTENT_GAP)
	page.add_child(content_row)

	list_panel = PanelContainer.new()
	list_panel.name = "ListPanel"
	list_panel.custom_minimum_size.x = LIST_WIDTH
	list_panel.add_theme_stylebox_override("panel", AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET,
		AlveolusVisualTheme.TEAL,
		AlveolusVisualTheme.CornerTreatment.CONTROL_4
	))
	content_row.add_child(list_panel)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_top", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	list_margin.add_theme_constant_override("margin_bottom", 12)
	list_panel.add_child(list_margin)

	entry_scroll = ScrollContainer.new()
	entry_scroll.name = "EntryScroll"
	entry_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entry_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entry_scroll.follow_focus = true
	list_margin.add_child(entry_scroll)

	entry_list = VBoxContainer.new()
	entry_list.name = "EntryList"
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_list.add_theme_constant_override("separation", 8)
	entry_scroll.add_child(entry_list)

	detail_panel = PanelContainer.new()
	detail_panel.name = "DetailPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.ACTION_CARD,
		AlveolusVisualTheme.COBALT,
		AlveolusVisualTheme.CornerTreatment.CARD_6
	))
	content_row.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 22)
	detail_margin.add_theme_constant_override("margin_top", 20)
	detail_margin.add_theme_constant_override("margin_right", 22)
	detail_margin.add_theme_constant_override("margin_bottom", 20)
	detail_panel.add_child(detail_margin)

	detail_scroll = ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.follow_focus = true
	detail_margin.add_child(detail_scroll)

	detail_content = VBoxContainer.new()
	detail_content.name = "DetailContent"
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.add_theme_constant_override("separation", 10)
	var detail_safe_margin := MarginContainer.new()
	detail_safe_margin.name = "ScrollbarSafeInset"
	detail_safe_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_safe_margin.add_theme_constant_override("margin_right", 16)
	detail_safe_margin.add_theme_constant_override("margin_bottom", 4)
	detail_scroll.add_child(detail_safe_margin)
	detail_safe_margin.add_child(detail_content)
	_build_detail_content()

func _build_category_buttons() -> void:
	category_buttons.clear()
	for category in LexiconCatalog.CATEGORY_ORDER:
		var button := Button.new()
		button.name = "Category_%s" % category
		button.text = LexiconCatalog.category_name(category)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(160.0, 46.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
		button.add_theme_font_size_override("font_size", 16)
		_apply_button_styles(button, AlveolusVisualTheme.COBALT)
		button.pressed.connect(select_category.bind(category, true))
		category_bar.add_child(button)
		category_buttons[category] = button

func _build_detail_content() -> void:
	compact_back_button = AlveolusUIComponents.action_button(
		"Zur Liste",
		AlveolusUIComponents.ACTION_NAVIGATION,
		&"back",
		AlveolusVisualTheme.COBALT
	)
	compact_back_button.pressed.connect(_show_compact_list)
	compact_back_button.hide()
	detail_content.add_child(compact_back_button)
	var heading := HBoxContainer.new()
	heading.name = "Heading"
	heading.add_theme_constant_override("separation", 18)
	detail_content.add_child(heading)

	detail_illustration = MedicalLexiconIllustration.new()
	detail_illustration.name = "Illustration"
	detail_illustration.custom_minimum_size = Vector2(112.0, 112.0)
	detail_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(detail_illustration)

	var heading_copy := VBoxContainer.new()
	heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	heading_copy.add_theme_constant_override("separation", 3)
	heading.add_child(heading_copy)

	detail_category_label = _label("", 14, AlveolusVisualTheme.COBALT, true)
	heading_copy.add_child(detail_category_label)
	detail_title = _label("", 28, AlveolusVisualTheme.IVORY, true)
	heading_copy.add_child(detail_title)
	detail_medical_name = _label("", 16, AlveolusVisualTheme.SKY_DEEP)
	heading_copy.add_child(detail_medical_name)

	detail_summary = _body_label()
	detail_summary.add_theme_font_size_override("font_size", 18)
	detail_content.add_child(detail_summary)

	_add_separator(detail_content)
	detail_stats_title = _section_title("Basiswerte")
	detail_content.add_child(detail_stats_title)
	detail_stats_grid = GridContainer.new()
	detail_stats_grid.name = "StatsGrid"
	detail_stats_grid.columns = 4
	detail_stats_grid.add_theme_constant_override("h_separation", 12)
	detail_stats_grid.add_theme_constant_override("v_separation", 8)
	detail_content.add_child(detail_stats_grid)

	var gameplay_section := AlveolusUIComponents.semantic_copy_section("IM SPIEL", "", &"ability", AlveolusVisualTheme.TEAL)
	detail_gameplay_panel = gameplay_section["panel"]
	detail_gameplay_title = gameplay_section["title"]
	detail_gameplay_text = gameplay_section["body"]
	detail_content.add_child(detail_gameplay_panel)

	var medical_section := AlveolusUIComponents.semantic_copy_section("MEDIZINISCHER HINTERGRUND", "", &"lexicon", AlveolusVisualTheme.COBALT)
	detail_medical_panel = medical_section["panel"]
	detail_medical_title = medical_section["title"]
	detail_medical_text = medical_section["body"]
	detail_content.add_child(detail_medical_panel)

	detail_related_title = _section_title("Verwandte Begriffe")
	detail_content.add_child(detail_related_title)
	detail_related_text = _body_label()
	detail_related_text.add_theme_color_override("font_color", AlveolusVisualTheme.COBALT)
	detail_content.add_child(detail_related_text)

	empty_detail_label = _label("Wähle links einen Eintrag aus.", 18, AlveolusVisualTheme.SKY_DEEP)
	empty_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_content.add_child(empty_detail_label)

func _rebuild_entry_list() -> void:
	_clear_children(entry_list)
	entry_buttons.clear()
	entry_view_models.clear()
	var accent := _category_accent(selected_category)
	for definition in _visible_definitions():
		var view_model := provider.make_view_model(definition, seen_discovery_ids)
		entry_view_models[definition.id] = view_model
		var button := Button.new()
		button.name = "Entry_%s" % definition.id
		button.text = ""
		button.tooltip_text = ""
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(0.0, 68.0)
		_apply_button_styles(button, accent)
		button.pressed.connect(select_entry.bind(definition.id, true))
		button.mouse_entered.connect(_preview_entry.bind(definition.id))
		button.focus_entered.connect(_preview_entry.bind(definition.id))
		entry_list.add_child(button)
		entry_buttons[definition.id] = button

		# A lexicon row is a compact visual tile, not a text-only menu item. The
		# same illustration ID drives both the list and detail view so unlocked
		# art cannot drift, while undiscovered entries still show a real
		# silhouette instead of an empty card.
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 7)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 7)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(row)
		var illustration := MedicalLexiconIllustration.new()
		illustration.custom_minimum_size = Vector2(48.0, 48.0)
		illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		illustration.configure(view_model.visual_id, accent)
		illustration.set_locked(view_model.locked)
		row.add_child(illustration)
		var title := _label(view_model.display_name, 17, AlveolusVisualTheme.IVORY, true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)

func _preview_entry(entry_id: StringName) -> void:
	# Hover and navigation focus preview the same detail without committing a
	# compact list-to-detail transition. Click/accept remains the explicit action.
	select_entry(entry_id, false)

func _show_empty_detail() -> void:
	detail_illustration.hide()
	detail_category_label.hide()
	detail_title.hide()
	detail_medical_name.hide()
	detail_summary.hide()
	detail_stats_title.hide()
	detail_stats_grid.hide()
	detail_gameplay_title.hide()
	detail_gameplay_text.hide()
	detail_gameplay_panel.hide()
	detail_medical_title.hide()
	detail_medical_text.hide()
	detail_medical_panel.hide()
	detail_related_title.hide()
	detail_related_text.hide()
	empty_detail_label.show()

func _show_detail(view_model: LexiconEntryViewModel) -> void:
	empty_detail_label.hide()
	detail_illustration.show()
	detail_category_label.show()
	detail_title.show()
	detail_summary.show()
	detail_category_label.text = LexiconCatalog.category_name(view_model.category)
	detail_title.text = view_model.display_name
	detail_summary.text = view_model.summary
	detail_illustration.configure(view_model.visual_id, _category_accent(view_model.category))
	detail_illustration.set_locked(view_model.locked)

	detail_medical_name.text = view_model.medical_name
	detail_medical_name.visible = not view_model.medical_name.is_empty() and not view_model.locked

	_clear_children(detail_stats_grid)
	for row in view_model.stat_rows:
		var label := _label(row.label, 16, AlveolusVisualTheme.SKY_DEEP)
		label.tooltip_text = row.description
		label.custom_minimum_size.x = 84.0
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		detail_stats_grid.add_child(label)
		var value := _label(row.formatted_value(), 16, AlveolusVisualTheme.IVORY, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size.x = 64.0
		detail_stats_grid.add_child(value)
	detail_stats_title.visible = not view_model.stat_rows.is_empty()
	detail_stats_grid.visible = not view_model.stat_rows.is_empty()

	detail_gameplay_text.text = view_model.gameplay_text
	detail_gameplay_title.visible = not view_model.gameplay_text.is_empty() and not view_model.locked
	detail_gameplay_text.visible = detail_gameplay_title.visible
	detail_gameplay_panel.visible = detail_gameplay_title.visible
	detail_medical_text.text = view_model.medical_text
	detail_medical_title.visible = not view_model.medical_text.is_empty() and not view_model.locked
	detail_medical_text.visible = detail_medical_title.visible
	detail_medical_panel.visible = detail_medical_title.visible
	detail_related_text.text = "  ·  ".join(view_model.related_names)
	detail_related_title.visible = not view_model.related_names.is_empty() and not view_model.locked
	detail_related_text.visible = detail_related_title.visible
	detail_scroll.scroll_vertical = 0

func _configure_focus_neighbors() -> void:
	var category_count := LexiconCatalog.CATEGORY_ORDER.size()
	var visible := _visible_definitions()
	for index in range(category_count):
		var category := LexiconCatalog.CATEGORY_ORDER[index]
		var button := category_buttons.get(category) as Button
		var previous := category_buttons.get(LexiconCatalog.CATEGORY_ORDER[(index - 1 + category_count) % category_count]) as Button
		var next := category_buttons.get(LexiconCatalog.CATEGORY_ORDER[(index + 1) % category_count]) as Button
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)
		if not visible.is_empty():
			var first := entry_buttons.get(visible[0].id) as Button
			button.focus_neighbor_bottom = button.get_path_to(first)

	for index in range(visible.size()):
		var entry_button := entry_buttons.get(visible[index].id) as Button
		var previous_button := entry_buttons.get(visible[(index - 1 + visible.size()) % visible.size()].id) as Button
		var next_button := entry_buttons.get(visible[(index + 1) % visible.size()].id) as Button
		entry_button.focus_neighbor_top = entry_button.get_path_to(previous_button) if index > 0 else entry_button.get_path_to(category_buttons[selected_category])
		entry_button.focus_neighbor_bottom = entry_button.get_path_to(next_button)
		entry_button.focus_neighbor_left = entry_button.get_path_to(category_buttons[selected_category])

func _update_category_states() -> void:
	for category in category_buttons:
		var button := category_buttons[category] as Button
		button.button_pressed = category == selected_category

func _visible_definitions() -> Array[LexiconEntryDefinition]:
	var result: Array[LexiconEntryDefinition] = []
	for definition in definitions:
		if definition.category == selected_category:
			result.append(definition)
	return result

func _apply_button_styles(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", AlveolusVisualTheme.case_card_style(accent, &"normal"))
	button.add_theme_stylebox_override("hover", AlveolusVisualTheme.case_card_style(accent, &"hover"))
	button.add_theme_stylebox_override("pressed", AlveolusVisualTheme.case_card_style(accent, &"pressed"))
	button.add_theme_stylebox_override("focus", AlveolusVisualTheme.case_card_style(accent, &"focus"))
	button.add_theme_stylebox_override("disabled", AlveolusVisualTheme.case_card_style(accent, &"disabled"))
	button.add_theme_color_override("font_color", AlveolusVisualTheme.IVORY)
	button.add_theme_color_override("font_hover_color", AlveolusVisualTheme.PAPER_LIGHT)
	button.add_theme_color_override("font_pressed_color", AlveolusVisualTheme.IVORY)
	button.add_theme_color_override("font_focus_color", AlveolusVisualTheme.PAPER_LIGHT)

func _category_accent(category: StringName) -> Color:
	match category:
		LexiconEntryDefinition.CATEGORY_MONSTERS:
			return AlveolusVisualTheme.CORAL
		LexiconEntryDefinition.CATEGORY_CHARACTER:
			return AlveolusVisualTheme.COBALT
		LexiconEntryDefinition.CATEGORY_GAMEPLAY:
			return AlveolusVisualTheme.TEAL
		_:
			return AlveolusVisualTheme.GOLD

func _label(text_value: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", AlveolusVisualTheme.heading_font() if heading else AlveolusVisualTheme.body_font())
	label.add_theme_font_size_override("font_size", maxi(16, font_size))
	label.add_theme_color_override("font_color", color)
	return label

func _body_label() -> Label:
	var label := _label("", 16, AlveolusVisualTheme.IVORY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _section_title(title: String) -> Label:
	return _label(title, 16, AlveolusVisualTheme.COBALT.lightened(0.26), true)

func cancel_step() -> bool:
	if not _is_compact() or not compact_detail_visible:
		return false
	_show_compact_list()
	return true

func _show_compact_list() -> void:
	compact_detail_visible = false
	_apply_responsive_layout()
	var selected_button := entry_buttons.get(selected_entry_id) as Button
	if selected_button != null:
		selected_button.grab_focus.call_deferred()

func _is_compact() -> bool:
	return size.x < 820.0

func _apply_responsive_layout() -> void:
	if category_bar == null or list_panel == null or detail_panel == null:
		return
	var compact := _is_compact()
	category_bar.columns = 2 if compact else 4
	category_bar.custom_minimum_size.y = 96.0 if compact else 48.0
	list_panel.custom_minimum_size.x = 0.0 if compact else LIST_WIDTH
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	list_panel.visible = not compact or not compact_detail_visible
	detail_panel.visible = not compact or compact_detail_visible
	detail_stats_grid.columns = 2 if compact else 4
	if compact_back_button != null:
		compact_back_button.visible = compact and compact_detail_visible

func _add_separator(parent: Container) -> void:
	var separator := HSeparator.new()
	separator.modulate = Color(AlveolusVisualTheme.COBALT, 0.22)
	parent.add_child(separator)

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.free()
