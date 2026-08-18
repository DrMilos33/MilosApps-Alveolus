class_name LexiconMasterDetail
extends Control

signal category_changed(category: StringName)
signal entry_selected(entry_id: StringName)
signal context_detail_source_available(source: Control, content_provider: Callable, hover_enabled: bool)

const LIST_WIDTH := 310.0
const COMPACT_CONTENT_MIN_HEIGHT := 360.0

var provider: LexiconViewModelProvider
var seen_discovery_ids: Variant = []
var definitions: Array[LexiconEntryDefinition] = []
var selected_category: StringName = LexiconEntryDefinition.CATEGORY_MONSTERS
var selected_entry_id: StringName = &""

var category_buttons: Dictionary = {}
var entry_buttons: Dictionary = {}
var entry_view_models: Dictionary = {}

var page_scroll: ScrollContainer
var category_bar: GridContainer
var content_row: HBoxContainer
var list_panel: PanelContainer
var detail_panel: PanelContainer
var compact_back_button: Button
var compact_detail_visible: bool = false
var entry_scroll: ScrollContainer
var entry_safe_margin: MarginContainer
var entry_list: VBoxContainer
var detail_scroll: ScrollContainer
var detail_safe_margin: MarginContainer
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
var detail_type_sections: VBoxContainer
var detail_medical_title: Label
var detail_medical_text: Label
var detail_medical_panel: PanelContainer
var detail_related_title: Label
var detail_related_text: Label
var empty_detail_label: Label
var _context_detail_sources: Dictionary = {}
var _detail_type_grids: Array[GridContainer] = []

func _ready() -> void:
	if provider == null:
		provider = LexiconViewModelProvider.create_default()
	if definitions.is_empty():
		definitions = LexiconCatalog.entries()
	_ensure_standalone_theme()
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

func select_category(category: StringName, _focus_first_entry: bool = false) -> void:
	if not LexiconCatalog.CATEGORY_ORDER.has(category):
		return
	selected_category = category
	selected_entry_id = &""
	_update_category_states()
	_rebuild_entry_list()
	# Category changes only reveal the available entries. Selection remains an
	# explicit player action, so the first row is neither marked nor focused.
	_show_empty_detail()
	if _is_compact():
		compact_detail_visible = false
		_apply_responsive_layout()
	_configure_focus_neighbors()
	category_changed.emit(category)

func select_entry(entry_id: StringName, move_focus: bool = false) -> bool:
	var view_model := entry_view_models.get(entry_id) as LexiconEntryViewModel
	if view_model == null:
		return false
	selected_entry_id = entry_id
	for id in entry_buttons:
		var button := entry_buttons[id] as Button
		var is_selected: bool = id == entry_id
		button.set_pressed_no_signal(is_selected)
		button.theme_type_variation = (
			AlveolusVisualTheme.TYPE_SELECTED_CARD
			if is_selected
			else AlveolusVisualTheme.TYPE_SELECTION_CARD
		)
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

## Returns the currently mounted information sources without exposing mutable
## domain state. A parent integration layer can register these providers with
## ContextDetailController both after initial construction and after a category
## rebuild signalled through context_detail_source_available.
func context_detail_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for registration_value in _context_detail_sources.values():
		var registration := registration_value as Dictionary
		var source := registration.get("source") as Control
		var content_provider: Callable = registration.get("provider", Callable())
		if source != null and is_instance_valid(source) and content_provider.is_valid():
			result.append({
				"source": source,
				"provider": content_provider,
				# Eligible entries retain their concise native mouse tooltip. The
				# shared controller therefore supplies explicit ui_info only;
				# glossary terms are intentionally never registered here.
				"hover_enabled": false,
			})
	return result

## Provides a detached data snapshot for the explicit ui_info detail card.
## Glossary terms deliberately return no payload because their row and detail
## already carry the complete explanation.
func context_detail_payload(entry_id: StringName) -> Dictionary:
	var view_model := entry_view_models.get(entry_id) as LexiconEntryViewModel
	if view_model == null or view_model.category == LexiconEntryDefinition.CATEGORY_TERMS:
		return {}
	var stat_rows: Array[Dictionary] = []
	for row in view_model.stat_rows:
		stat_rows.append({
			"id": row.id,
			"label": row.label,
			"value": row.formatted_value(),
			"description": row.description,
		})
	var sections: Array[Dictionary] = []
	if not view_model.gameplay_text.is_empty() and not view_model.locked:
		sections.append({
			"kind": &"gameplay",
			"title": "Im Spiel",
			"body": view_model.gameplay_text,
		})
	if not view_model.medical_text.is_empty() and not view_model.locked:
		sections.append({
			"kind": &"medical",
			"title": "Medizinischer Hintergrund",
			"body": view_model.medical_text,
		})
	return {
		"entry_id": view_model.id,
		"title": view_model.display_name,
		"body": view_model.summary,
		"meta": LexiconCatalog.category_name(view_model.category),
		"accent": _category_accent(view_model.category),
		"icon_kind": _category_icon_kind(view_model.category),
		"locked": view_model.locked,
		"medical_name": view_model.medical_name,
		"stat_rows": stat_rows,
		"sections": sections,
		"related_names": Array(view_model.related_names),
	}

func _build_layout() -> void:
	var background := AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_PAGE_CANVAS)
	background.name = "Surface"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# At high UI scales the two-row category bar can be taller than the
	# remaining viewport below the page header. Keep the complete master/detail
	# stage in one outer vertical scroll area so the content panel never
	# collapses to an empty strip. The dedicated list/detail scrollbars remain
	# responsible for long catalogs and long articles inside that stage.
	page_scroll = ScrollContainer.new()
	page_scroll.name = "PageScroll"
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.follow_focus = true
	background.add_child(page_scroll)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", AlveolusVisualTheme.SCREEN_MARGIN)
	margin.add_theme_constant_override("margin_top", AlveolusVisualTheme.SCREEN_MARGIN)
	margin.add_theme_constant_override("margin_right", AlveolusVisualTheme.SCREEN_MARGIN)
	margin.add_theme_constant_override("margin_bottom", AlveolusVisualTheme.SCREEN_MARGIN)
	page_scroll.add_child(margin)

	var page := VBoxContainer.new()
	page.name = "Page"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
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
	content_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	page.add_child(content_row)

	list_panel = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_DOCUMENT_INSET)
	list_panel.name = "ListPanel"
	list_panel.custom_minimum_size.x = LIST_WIDTH
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

	entry_safe_margin = MarginContainer.new()
	entry_safe_margin.name = "ScrollbarSafeInset"
	entry_safe_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_safe_margin.add_theme_constant_override("margin_right", AlveolusVisualTheme.CARD_PADDING)
	entry_safe_margin.add_theme_constant_override("margin_bottom", AlveolusVisualTheme.GRID_UNIT)
	entry_scroll.add_child(entry_safe_margin)

	entry_list = VBoxContainer.new()
	entry_list.name = "EntryList"
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_list.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	entry_safe_margin.add_child(entry_list)

	detail_panel = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
	detail_panel.name = "DetailPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	detail_safe_margin = MarginContainer.new()
	detail_safe_margin.name = "ScrollbarSafeInset"
	detail_safe_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_safe_margin.add_theme_constant_override("margin_right", AlveolusVisualTheme.CARD_PADDING)
	detail_safe_margin.add_theme_constant_override("margin_bottom", AlveolusVisualTheme.GRID_UNIT)
	detail_scroll.add_child(detail_safe_margin)
	detail_safe_margin.add_child(detail_content)
	_build_detail_content()

func _build_category_buttons() -> void:
	category_buttons.clear()
	for category in LexiconCatalog.CATEGORY_ORDER:
		var button := AlveolusUIComponents.segmented_tab(
			LexiconCatalog.category_name(category),
			category == selected_category
		)
		button.name = "Category_%s" % category
		button.custom_minimum_size = Vector2(160.0, 46.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_category.bind(category, false))
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

	detail_category_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	heading_copy.add_child(detail_category_label)
	detail_title = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_TITLE_LABEL)
	heading_copy.add_child(detail_title)
	detail_medical_name = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_MUTED_LABEL)
	heading_copy.add_child(detail_medical_name)

	detail_summary = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_BODY_LABEL)
	detail_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.add_child(detail_summary)

	_add_separator(detail_content)
	detail_stats_title = AlveolusUIComponents.label("Basiswerte", AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	detail_content.add_child(detail_stats_title)
	detail_stats_grid = GridContainer.new()
	detail_stats_grid.name = "StatsGrid"
	detail_stats_grid.columns = 2
	detail_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stats_grid.add_theme_constant_override("h_separation", 12)
	detail_stats_grid.add_theme_constant_override("v_separation", 8)
	detail_content.add_child(detail_stats_grid)

	detail_type_sections = VBoxContainer.new()
	detail_type_sections.name = "TypePresentations"
	detail_type_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_type_sections.add_theme_constant_override("separation", 10)
	detail_content.add_child(detail_type_sections)

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

	detail_related_title = AlveolusUIComponents.label("Verwandte Begriffe", AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	detail_content.add_child(detail_related_title)
	detail_related_text = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_BODY_LABEL)
	detail_related_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_related_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_related_text.add_theme_color_override("font_color", AlveolusVisualTheme.COBALT)
	detail_content.add_child(detail_related_text)

	empty_detail_label = AlveolusUIComponents.label("Eintrag auswählen.", AlveolusVisualTheme.TYPE_MUTED_LABEL)
	empty_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	empty_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_detail_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	empty_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_content.add_child(empty_detail_label)

func _rebuild_entry_list() -> void:
	_clear_children(entry_list)
	entry_buttons.clear()
	entry_view_models.clear()
	_context_detail_sources.clear()
	var accent := _category_accent(selected_category)
	for definition in _visible_definitions():
		var view_model := provider.make_view_model(definition, seen_discovery_ids)
		entry_view_models[definition.id] = view_model
		var button := AlveolusUIComponents.button(
			"",
			AlveolusVisualTheme.TYPE_SELECTION_CARD
		)
		button.name = "Entry_%s" % definition.id
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, 72.0)
		var exposes_context_detail := view_model.category != LexiconEntryDefinition.CATEGORY_TERMS
		button.tooltip_text = _hover_tooltip_text(view_model) if exposes_context_detail else ""
		button.set_meta(&"lexicon_entry_id", definition.id)
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
		var title := AlveolusUIComponents.label(view_model.display_name, AlveolusVisualTheme.TYPE_VALUE_LABEL)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)

		if exposes_context_detail:
			var content_provider := context_detail_payload.bind(definition.id)
			_context_detail_sources[definition.id] = {
				"source": button,
				"provider": content_provider,
			}
			context_detail_source_available.emit(button, content_provider, false)

func _preview_entry(entry_id: StringName) -> void:
	# Hover and navigation focus preview the same detail without committing a
	# compact list-to-detail transition. Click/accept remains the explicit action.
	select_entry(entry_id, false)

func _show_empty_detail() -> void:
	selected_entry_id = &""
	detail_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for button_value in entry_buttons.values():
		var button := button_value as Button
		if button == null:
			continue
		button.set_pressed_no_signal(false)
		button.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTION_CARD
	detail_illustration.hide()
	detail_category_label.hide()
	detail_title.hide()
	detail_medical_name.hide()
	detail_summary.hide()
	detail_stats_title.hide()
	detail_stats_grid.hide()
	_clear_children(detail_type_sections)
	_detail_type_grids.clear()
	detail_type_sections.hide()
	detail_gameplay_title.hide()
	detail_gameplay_text.hide()
	detail_gameplay_panel.hide()
	detail_medical_title.hide()
	detail_medical_text.hide()
	detail_medical_panel.hide()
	detail_related_title.hide()
	detail_related_text.hide()
	empty_detail_label.show()
	detail_scroll.scroll_vertical = 0

func _show_detail(view_model: LexiconEntryViewModel) -> void:
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_detail_label.hide()
	detail_illustration.show()
	detail_category_label.show()
	detail_title.show()
	detail_summary.show()
	detail_category_label.text = LexiconCatalog.category_name(view_model.category)
	detail_title.text = view_model.display_name
	detail_summary.text = view_model.summary
	detail_category_label.add_theme_color_override("font_color", _category_accent(view_model.category))
	detail_illustration.configure(view_model.visual_id, _category_accent(view_model.category))
	detail_illustration.set_locked(view_model.locked)

	detail_medical_name.text = view_model.medical_name
	detail_medical_name.visible = not view_model.medical_name.is_empty() and not view_model.locked

	var type_presentations := view_model.type_presentations()
	var has_structured_types := not type_presentations.is_empty()
	_clear_children(detail_stats_grid)
	for row in view_model.stat_rows:
		if has_structured_types and _is_legacy_type_row(row.id):
			continue
		var stat_panel := AlveolusUIComponents.value_row(row.label, row.formatted_value())
		stat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_panel.set_meta(&"lexicon_stat_id", row.id)
		stat_panel.tooltip_text = row.description
		var name_label := stat_panel.find_child("ValueName", true, false) as Label
		if name_label != null:
			name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var value_label := stat_panel.find_child("Value", true, false) as Label
		if value_label != null:
			value_label.custom_minimum_size.x = 72.0
			value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		detail_stats_grid.add_child(stat_panel)
	var has_stat_rows := detail_stats_grid.get_child_count() > 0
	detail_stats_title.visible = has_stat_rows
	detail_stats_grid.visible = has_stat_rows
	_rebuild_type_presentations(type_presentations)

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

func _rebuild_type_presentations(
	presentations: Array[LexiconEntryViewModel.TypePresentation]
) -> void:
	_clear_children(detail_type_sections)
	_detail_type_grids.clear()
	if presentations.is_empty():
		detail_type_sections.hide()
		return

	var current_role: StringName = &""
	var current_grid: GridContainer = null
	for presentation in presentations:
		if presentation == null:
			continue
		if presentation.semantic_role != current_role:
			current_role = presentation.semantic_role
			var group := VBoxContainer.new()
			group.name = "TypeGroup_%s" % current_role
			group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			group.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
			group.set_meta(&"lexicon_semantic_role", current_role)
			var title := AlveolusUIComponents.label(
				_type_section_title(current_role),
				AlveolusVisualTheme.TYPE_EYEBROW_LABEL
			)
			group.add_child(title)
			current_grid = GridContainer.new()
			current_grid.name = "TypeGrid_%s" % current_role
			current_grid.columns = 1 if _is_compact() else 2
			current_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_grid.add_theme_constant_override("h_separation", 10)
			current_grid.add_theme_constant_override("v_separation", 8)
			group.add_child(current_grid)
			detail_type_sections.add_child(group)
			_detail_type_grids.append(current_grid)

		var parts := AlveolusUIComponents.damage_type_chip(
			presentation.type_id,
			presentation.display_name,
			presentation.formatted_value,
			presentation.meaning,
			_type_indicator_text(presentation.indicator)
		)
		var chip := parts["panel"] as PanelContainer
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.set_meta(&"lexicon_semantic_role", presentation.semantic_role)
		chip.set_meta(&"lexicon_icon_id", presentation.icon_id)
		chip.set_meta(&"lexicon_indicator", presentation.indicator)
		var icon := parts["icon"] as SimpleIcon
		if icon != null:
			icon.configure(
				presentation.icon_id,
				AlveolusVisualTheme.damage_type_accent(presentation.type_id)
			)
		current_grid.add_child(chip)

	detail_type_sections.visible = detail_type_sections.get_child_count() > 0

func _is_legacy_type_row(row_id: StringName) -> bool:
	return row_id in [
		&"damage_types",
		&"damage_type",
		&"treatment_damage_type",
		&"resistances",
	]

func _type_section_title(semantic_role: StringName) -> String:
	match semantic_role:
		&"damage_share":
			return "Schadenstypen"
		&"resistance_effective":
			return "Effektive Resistenzen"
	return "Typwerte"

func _type_indicator_text(indicator: StringName) -> String:
	match indicator:
		&"share":
			return "•"
		&"mitigation":
			return "↓"
		&"vulnerability":
			return "↑"
		&"neutral":
			return "–"
	return ""

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
		var is_selected: bool = category == selected_category
		button.set_pressed_no_signal(is_selected)
		button.theme_type_variation = (
			AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB
			if is_selected
			else AlveolusVisualTheme.TYPE_SEGMENTED_TAB
		)

func _visible_definitions() -> Array[LexiconEntryDefinition]:
	var result: Array[LexiconEntryDefinition] = []
	for definition in definitions:
		if definition.category == selected_category:
			result.append(definition)
	return result

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

func _category_icon_kind(category: StringName) -> StringName:
	match category:
		LexiconEntryDefinition.CATEGORY_MONSTERS:
			return &"boss"
		LexiconEntryDefinition.CATEGORY_CHARACTER:
			return &"clinic"
		LexiconEntryDefinition.CATEGORY_GAMEPLAY:
			return &"ability"
		_:
			return &"lexicon"

func _hover_tooltip_text(view_model: LexiconEntryViewModel) -> String:
	if view_model == null:
		return ""
	if view_model.summary.is_empty():
		return view_model.display_name
	return "%s\n%s" % [view_model.display_name, view_model.summary]

func _ensure_standalone_theme() -> void:
	if theme != null:
		return
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).theme != null:
			return
		ancestor = ancestor.get_parent()
	theme = AlveolusVisualTheme.create_theme()

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
	if page_scroll == null or category_bar == null or list_panel == null or detail_panel == null:
		return
	var compact := _is_compact()
	page_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
		if compact
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	if not compact:
		page_scroll.scroll_vertical = 0
	category_bar.columns = 2 if compact else 4
	category_bar.custom_minimum_size.y = 96.0 if compact else 48.0
	content_row.custom_minimum_size.y = COMPACT_CONTENT_MIN_HEIGHT if compact else 0.0
	list_panel.custom_minimum_size.x = 0.0 if compact else LIST_WIDTH
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	list_panel.visible = not compact or not compact_detail_visible
	detail_panel.visible = not compact or compact_detail_visible
	detail_stats_grid.columns = 1 if compact else 2
	for type_grid in _detail_type_grids:
		if type_grid != null and is_instance_valid(type_grid):
			type_grid.columns = 1 if compact else 2
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
