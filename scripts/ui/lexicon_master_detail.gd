class_name LexiconMasterDetail
extends Control

signal category_changed(category: StringName)
signal entry_selected(entry_id: StringName)
signal context_detail_source_available(source: Control, content_provider: Callable, hover_enabled: bool)

const COMPACT_CONTENT_MIN_HEIGHT := 360.0
const GRID_TILE_MIN_WIDTH := 148.0
const GRID_TILE_HEIGHT := 60.0
const GRID_COLUMNS_WIDE := 7
const MASTER_DETAIL_GRID_COLUMNS := 2
const MASTER_DETAIL_MIN_WIDTH := 340.0
const MASTER_DETAIL_MAX_WIDTH := 420.0
const MASTER_DETAIL_WIDTH_RATIO := 0.36
const SEARCH_FIELD_WIDTH := 280.0

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
var overview_toolbar: PanelContainer
var toolbar_row: HBoxContainer
var content_row: HBoxContainer
var list_panel: PanelContainer
var detail_panel: PanelContainer
var compact_back_button: Button
var compact_detail_visible: bool = false
var entry_scroll: ScrollContainer
var entry_safe_margin: MarginContainer
var entry_list: GridContainer
var entry_filter: LineEdit
var entry_count_label: Label
var entry_empty_label: Label
var detail_scroll: ScrollContainer
var detail_safe_margin: MarginContainer
var detail_content: VBoxContainer
var detail_illustration: MedicalLexiconIllustration
var detail_title: Label
var detail_summary: Label
var detail_gameplay_title: Label
var detail_gameplay_text: Label
var detail_gameplay_panel: PanelContainer
var detail_stats_title: Label
var detail_stats_sections: VBoxContainer
var detail_stats_grid: GridContainer
var detail_type_sections: VBoxContainer
var detail_medical_title: Label
var detail_medical_text: Label
var detail_medical_panel: PanelContainer
var detail_related_title: Label
var detail_related_chips: HFlowContainer
var empty_detail_label: Label
var _context_detail_sources: Dictionary = {}
var _detail_stat_grids: Array[GridContainer] = []
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
	if entry_filter != null and not entry_filter.text.is_empty():
		entry_filter.set_text("")
	_update_category_states()
	_rebuild_entry_list()
	# Category changes only reveal the available entries. Selection remains an
	# explicit player action, so the first row is neither marked nor focused.
	_show_empty_detail()
	compact_detail_visible = false
	_apply_responsive_layout()
	_configure_focus_neighbors()
	category_changed.emit(category)

func select_entry(entry_id: StringName, move_focus: bool = false) -> bool:
	var view_model := entry_view_models.get(entry_id) as LexiconEntryViewModel
	if view_model == null:
		return false
	if view_model.locked:
		var locked_button := entry_buttons.get(entry_id) as Button
		_set_entry_button_selected(locked_button, false)
		return false
	selected_entry_id = entry_id
	for id in entry_buttons:
		var button := entry_buttons[id] as Button
		_set_entry_button_selected(button, id == entry_id)
	_show_detail(view_model)
	compact_detail_visible = true
	_apply_responsive_layout()
	if move_focus and _is_compact():
		compact_back_button.grab_focus.call_deferred()
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
				"id": StringName(registration.get("id", &"")),
				"source": source,
				"provider": content_provider,
				"hover_enabled": bool(registration.get("hover_enabled", false)),
			})
	return result


func context_detail_scope_id() -> StringName:
	return &"lexicon"

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
	margin.add_theme_constant_override("margin_left", AlveolusVisualTheme.SCREEN_MARGIN_COMPACT)
	margin.add_theme_constant_override("margin_top", AlveolusVisualTheme.CONTROL_GAP)
	margin.add_theme_constant_override("margin_right", AlveolusVisualTheme.SCREEN_MARGIN_COMPACT)
	margin.add_theme_constant_override("margin_bottom", AlveolusVisualTheme.CONTENT_GAP)
	page_scroll.add_child(margin)

	var page := VBoxContainer.new()
	page.name = "Page"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	margin.add_child(page)

	category_bar = GridContainer.new()
	category_bar.name = "CategoryBar"
	category_bar.columns = LexiconCatalog.CATEGORY_ORDER.size()
	category_bar.custom_minimum_size.y = 44.0
	category_bar.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	category_bar.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	page.add_child(category_bar)

	overview_toolbar = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_DOCUMENT_INSET)
	overview_toolbar.name = "OverviewToolbar"
	overview_toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(overview_toolbar)

	var toolbar_margin := MarginContainer.new()
	toolbar_margin.add_theme_constant_override("margin_left", 10)
	toolbar_margin.add_theme_constant_override("margin_top", 2)
	toolbar_margin.add_theme_constant_override("margin_right", 10)
	toolbar_margin.add_theme_constant_override("margin_bottom", 2)
	overview_toolbar.add_child(toolbar_margin)

	toolbar_row = HBoxContainer.new()
	toolbar_row.name = "SearchAndProgress"
	toolbar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	toolbar_margin.add_child(toolbar_row)

	entry_filter = LineEdit.new()
	entry_filter.name = "EntryFilter"
	entry_filter.placeholder_text = "Einträge durchsuchen …"
	entry_filter.clear_button_enabled = true
	entry_filter.custom_minimum_size = Vector2(SEARCH_FIELD_WIDTH, 44.0)
	entry_filter.size_flags_horizontal = Control.SIZE_FILL
	entry_filter.set_meta(&"alveolus_accessible_name", "Lexikoneinträge durchsuchen")
	entry_filter.text_changed.connect(_on_entry_filter_changed)
	toolbar_row.add_child(entry_filter)

	var toolbar_spacer := Control.new()
	toolbar_spacer.name = "ToolbarSpacer"
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar_row.add_child(toolbar_spacer)

	entry_count_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	entry_count_label.name = "EntryCount"
	entry_count_label.custom_minimum_size.x = 150.0
	entry_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry_count_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar_row.add_child(entry_count_label)

	content_row = HBoxContainer.new()
	content_row.name = "Content"
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	page.add_child(content_row)

	list_panel = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_DOCUMENT_INSET)
	list_panel.name = "ListPanel"
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(list_panel)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 6)
	list_margin.add_theme_constant_override("margin_top", 6)
	list_margin.add_theme_constant_override("margin_right", 6)
	list_margin.add_theme_constant_override("margin_bottom", 6)
	list_panel.add_child(list_margin)

	entry_scroll = ScrollContainer.new()
	entry_scroll.name = "EntryScroll"
	entry_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entry_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entry_scroll.follow_focus = true
	list_margin.add_child(entry_scroll)

	entry_safe_margin = MarginContainer.new()
	entry_safe_margin.name = "ScrollbarSafeInset"
	entry_safe_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_safe_margin.add_theme_constant_override("margin_right", AlveolusVisualTheme.CARD_PADDING)
	entry_safe_margin.add_theme_constant_override("margin_bottom", AlveolusVisualTheme.GRID_UNIT)
	entry_scroll.add_child(entry_safe_margin)

	entry_list = GridContainer.new()
	entry_list.name = "EntryGrid"
	entry_list.columns = GRID_COLUMNS_WIDE
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_list.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	entry_list.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	entry_safe_margin.add_child(entry_list)

	entry_empty_label = AlveolusUIComponents.label("Keine passenden Einträge.", AlveolusVisualTheme.TYPE_MUTED_LABEL)
	entry_empty_label.name = "NoFilteredEntries"
	entry_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry_empty_label.custom_minimum_size.y = 72.0
	entry_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_empty_label.hide()
	entry_safe_margin.add_child(entry_empty_label)

	detail_panel = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
	detail_panel.name = "DetailPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", AlveolusVisualTheme.CARD_PADDING)
	detail_margin.add_theme_constant_override("margin_top", AlveolusVisualTheme.CONTENT_GAP)
	detail_margin.add_theme_constant_override("margin_right", AlveolusVisualTheme.CARD_PADDING)
	detail_margin.add_theme_constant_override("margin_bottom", AlveolusVisualTheme.CONTENT_GAP)
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
	detail_content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
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
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_category.bind(category, false))
		category_bar.add_child(button)
		category_buttons[category] = button

func _build_detail_content() -> void:
	var heading := HBoxContainer.new()
	heading.name = "Heading"
	heading.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	detail_content.add_child(heading)

	detail_illustration = MedicalLexiconIllustration.new()
	detail_illustration.name = "Illustration"
	detail_illustration.custom_minimum_size = Vector2(96.0, 96.0)
	detail_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(detail_illustration)

	var heading_copy := VBoxContainer.new()
	heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_child(heading_copy)

	detail_title = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_TITLE_LABEL)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_copy.add_child(detail_title)

	compact_back_button = AlveolusUIComponents.action_button(
		"Zur Übersicht",
		AlveolusUIComponents.ACTION_QUIET,
		&"back",
		AlveolusVisualTheme.COBALT
	)
	compact_back_button.custom_minimum_size = Vector2(136.0, 44.0)
	compact_back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	compact_back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	compact_back_button.pressed.connect(_show_compact_list)
	compact_back_button.hide()
	heading.add_child(compact_back_button)

	detail_summary = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_BODY_LABEL)
	detail_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.add_child(detail_summary)

	_add_separator(detail_content)
	detail_stats_title = AlveolusUIComponents.label("Basiswerte", AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	detail_content.add_child(detail_stats_title)
	detail_stats_sections = VBoxContainer.new()
	detail_stats_sections.name = "StatSections"
	detail_stats_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stats_sections.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	detail_content.add_child(detail_stats_sections)
	detail_stats_grid = GridContainer.new()
	detail_stats_grid.name = "StatsGrid"
	detail_stats_grid.columns = 2
	detail_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stats_grid.add_theme_constant_override("h_separation", 12)
	detail_stats_grid.add_theme_constant_override("v_separation", 8)
	detail_stats_sections.add_child(detail_stats_grid)
	_detail_stat_grids.append(detail_stats_grid)

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
	detail_related_chips = HFlowContainer.new()
	detail_related_chips.name = "RelatedTermChips"
	detail_related_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_related_chips.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	detail_related_chips.add_theme_constant_override("v_separation", AlveolusVisualTheme.GRID_UNIT)
	detail_content.add_child(detail_related_chips)

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
	_clear_entry_context_detail_sources()
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
		button.custom_minimum_size = Vector2(GRID_TILE_MIN_WIDTH, GRID_TILE_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_FILL
		button.clip_contents = true
		var exposes_context_detail := view_model.category != LexiconEntryDefinition.CATEGORY_TERMS
		button.tooltip_text = _hover_tooltip_text(view_model) if exposes_context_detail and not view_model.locked else ""
		button.set_meta(&"lexicon_entry_id", definition.id)
		button.pressed.connect(select_entry.bind(definition.id, true))
		entry_list.add_child(button)
		entry_buttons[definition.id] = button

		# The overview is intentionally a dense card grid. Unlocked entries reuse
		# the detail illustration; locked entries are a deliberately anonymous
		# full-card padlock so neither art nor copy leaks through the membrane.
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 4)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(row)
		if not view_model.locked:
			var illustration := MedicalLexiconIllustration.new()
			illustration.custom_minimum_size = Vector2(38.0, 38.0)
			illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
			illustration.configure(view_model.visual_id, accent)
			row.add_child(illustration)
			var row_copy := VBoxContainer.new()
			row_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_copy.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(row_copy)
			var title := AlveolusUIComponents.label(view_model.display_name, AlveolusVisualTheme.TYPE_VALUE_LABEL)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			title.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_copy.add_child(title)
		var state_text := view_model.unlock_reason if view_model.locked else ""
		button.set_meta(&"lexicon_display_name", view_model.display_name)
		button.set_meta(&"lexicon_base_state_text", state_text)
		button.set_meta(&"lexicon_locked", view_model.locked)
		if view_model.locked:
			_build_entry_lock_cover(button)

		if exposes_context_detail:
			var content_provider := context_detail_payload.bind(definition.id)
			var stable_source_id := StringName("lexicon:entry:%s" % String(definition.id))
			button.set_meta(&"context_detail_stable_id", stable_source_id)
			_context_detail_sources[stable_source_id] = {
				"id": stable_source_id,
				"source": button,
				"provider": content_provider,
				"hover_enabled": false,
				"kind": &"entry",
			}
			context_detail_source_available.emit(button, content_provider, false)
		_set_entry_button_selected(button, definition.id == selected_entry_id)
	_update_entry_count()
	entry_empty_label.visible = entry_buttons.is_empty()


func _build_entry_lock_cover(button: Button) -> void:
	var cover := PanelContainer.new()
	cover.name = "EntryLockCover"
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_theme_stylebox_override("panel", AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.MODAL_SHEET,
		AlveolusVisualTheme.GOLD,
		AlveolusVisualTheme.CornerTreatment.CARD_6
	))
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.z_index = 2
	cover.set_meta(&"alveolus_component", &"lexicon_entry_lock")
	button.add_child(cover)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(center)
	var icon := SimpleIcon.new()
	icon.name = "EntryLockIcon"
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.configure(&"locked", AlveolusVisualTheme.GOLD)
	center.add_child(icon)


func _set_entry_button_selected(button: Button, is_selected: bool) -> void:
	if button == null:
		return
	button.set_pressed_no_signal(is_selected)
	button.theme_type_variation = (
		AlveolusVisualTheme.TYPE_SELECTED_CARD
		if is_selected
		else AlveolusVisualTheme.TYPE_SELECTION_CARD
	)
	var display_name := String(button.get_meta(&"lexicon_display_name", "Lexikoneintrag"))
	var state_text := String(button.get_meta(&"lexicon_base_state_text", ""))
	var accessible_name := display_name
	if not state_text.is_empty():
		accessible_name = "Gesperrt. %s. %s" % [display_name, state_text]
	if is_selected:
		accessible_name += ", ausgewählt"
	button.set_meta(&"alveolus_accessible_name", accessible_name)


func _show_empty_detail() -> void:
	selected_entry_id = &""
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for button_value in entry_buttons.values():
		var button := button_value as Button
		_set_entry_button_selected(button, false)
	detail_illustration.hide()
	detail_title.hide()
	detail_summary.hide()
	detail_stats_title.hide()
	detail_stats_sections.hide()
	detail_stats_grid.hide()
	_clear_stat_section_groups()
	_clear_children(detail_type_sections)
	_detail_type_grids.clear()
	detail_type_sections.hide()
	detail_gameplay_title.hide()
	detail_gameplay_text.hide()
	detail_gameplay_panel.hide()
	detail_medical_title.hide()
	detail_medical_text.hide()
	detail_medical_panel.hide()
	_clear_related_term_chips()
	detail_related_title.hide()
	detail_related_chips.hide()
	empty_detail_label.text = "Wähle in der Übersicht einen Eintrag aus."
	empty_detail_label.custom_minimum_size.y = 120.0
	empty_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_detail_label.show()
	detail_scroll.scroll_vertical = 0

func _show_detail(view_model: LexiconEntryViewModel) -> void:
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_detail_label.hide()
	detail_illustration.show()
	detail_title.show()
	detail_summary.show()
	detail_title.text = view_model.display_name
	detail_summary.text = view_model.summary
	detail_illustration.configure(view_model.visual_id, _category_accent(view_model.category))
	detail_illustration.set_locked(view_model.locked)

	var type_presentations := view_model.type_presentations()
	var has_structured_types := not type_presentations.is_empty()
	_clear_stat_section_groups()
	var stat_sections := view_model.stat_section_presentations()
	if stat_sections.is_empty():
		detail_stats_grid.show()
		for row in view_model.stat_rows:
			if has_structured_types and _is_legacy_type_row(row.id):
				continue
			detail_stats_grid.add_child(_build_stat_panel(row))
	else:
		detail_stats_grid.hide()
		for section in stat_sections:
			_build_stat_section(section, has_structured_types)
	var has_stat_rows := not stat_sections.is_empty() or detail_stats_grid.get_child_count() > 0
	detail_stats_title.visible = has_stat_rows and stat_sections.is_empty()
	detail_stats_grid.visible = has_stat_rows and stat_sections.is_empty()
	detail_stats_sections.visible = has_stat_rows
	_rebuild_type_presentations(type_presentations)

	detail_gameplay_text.text = view_model.gameplay_text
	detail_gameplay_title.visible = not view_model.gameplay_text.is_empty() and not view_model.locked
	detail_gameplay_text.visible = detail_gameplay_title.visible
	detail_gameplay_panel.visible = detail_gameplay_title.visible
	detail_medical_text.text = view_model.medical_text
	detail_medical_title.visible = not view_model.medical_text.is_empty() and not view_model.locked
	detail_medical_text.visible = detail_medical_title.visible
	detail_medical_panel.visible = detail_medical_title.visible
	_rebuild_related_term_chips(view_model)
	detail_scroll.scroll_vertical = 0


func _clear_stat_section_groups() -> void:
	if detail_stats_sections == null:
		return
	_clear_children(detail_stats_grid)
	for child in detail_stats_sections.get_children():
		if child != detail_stats_grid:
			detail_stats_sections.remove_child(child)
			child.free()
	_detail_stat_grids.clear()
	_detail_stat_grids.append(detail_stats_grid)


func _build_stat_section(
	section: LexiconEntryViewModel.StatSectionPresentation,
	has_structured_types: bool
) -> void:
	if section == null:
		return
	var group := VBoxContainer.new()
	group.name = "StatSection_%s" % String(section.id)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	group.set_meta(&"lexicon_stat_section", section.id)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var icon := SimpleIcon.new()
	icon.name = "StatSectionIcon"
	icon.custom_minimum_size = Vector2(20.0, 20.0)
	icon.configure(section.icon_id, _category_accent(LexiconEntryDefinition.CATEGORY_CHARACTER))
	heading.add_child(icon)
	heading.add_child(AlveolusUIComponents.label(section.title, AlveolusVisualTheme.TYPE_EYEBROW_LABEL))
	group.add_child(heading)
	var grid := GridContainer.new()
	grid.name = "StatGrid_%s" % String(section.id)
	grid.columns = 1 if _is_compact() else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for row in section.rows():
		if has_structured_types and _is_legacy_type_row(row.id):
			continue
		grid.add_child(_build_stat_panel(row))
	group.add_child(grid)
	detail_stats_sections.add_child(group)
	_detail_stat_grids.append(grid)


func _build_stat_panel(row: StatRowViewModel) -> PanelContainer:
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
	return stat_panel


func _rebuild_related_term_chips(view_model: LexiconEntryViewModel) -> void:
	_clear_related_term_chips()
	if view_model == null or view_model.locked or not view_model.has_method(&"related_term_presentations"):
		detail_related_title.hide()
		detail_related_chips.hide()
		return
	var provided: Variant = view_model.call(&"related_term_presentations")
	if not provided is Array:
		detail_related_title.hide()
		detail_related_chips.hide()
		return
	var presentations := provided as Array
	var chips: Array[Button] = []
	for dto in presentations:
		var snapshot := _related_term_snapshot(dto)
		if snapshot.is_empty():
			continue
		var term_id := StringName(snapshot["id"])
		var display_name := String(snapshot["display_name"])
		var stable_source_id := StringName("lexicon:related:%s:%s" % [String(view_model.id), String(term_id)])
		var chip := AlveolusUIComponents.action_button(
			display_name,
			AlveolusUIComponents.ACTION_QUIET,
			StringName(snapshot.get("icon_id", &"lexicon")),
			AlveolusVisualTheme.COBALT
		)
		chip.name = "Related_%s" % String(term_id).replace("/", "_")
		chip.custom_minimum_size.y = 36.0
		chip.focus_mode = Control.FOCUS_ALL
		chip.tooltip_text = ""
		chip.set_meta(&"lexicon_related_term_id", term_id)
		chip.set_meta(&"context_detail_stable_id", stable_source_id)
		chip.set_meta(&"alveolus_accessible_name", "%s. Erklärung mit I anzeigen." % display_name)
		detail_related_chips.add_child(chip)
		chips.append(chip)

		var content_provider := _related_term_context_payload.bind(snapshot)
		_context_detail_sources[stable_source_id] = {
			"id": stable_source_id,
			"source": chip,
			"provider": content_provider,
			"hover_enabled": true,
			"kind": &"related_term",
		}
		context_detail_source_available.emit(chip, content_provider, true)

	for index in range(chips.size()):
		var chip := chips[index]
		if chips.size() > 1:
			chip.focus_neighbor_left = chip.get_path_to(chips[(index - 1 + chips.size()) % chips.size()])
			chip.focus_neighbor_right = chip.get_path_to(chips[(index + 1) % chips.size()])
	var has_related_terms := not chips.is_empty()
	detail_related_title.visible = has_related_terms
	detail_related_chips.visible = has_related_terms


func _clear_related_term_chips() -> void:
	if detail_related_chips != null:
		_clear_children(detail_related_chips)
	var stale_source_ids: Array[StringName] = []
	for source_id_value in _context_detail_sources:
		var source_id := StringName(source_id_value)
		var registration := _context_detail_sources[source_id] as Dictionary
		if StringName(registration.get("kind", &"")) == &"related_term":
			stale_source_ids.append(source_id)
	for source_id in stale_source_ids:
		_context_detail_sources.erase(source_id)


func _clear_entry_context_detail_sources() -> void:
	var stale_source_ids: Array[StringName] = []
	for source_id_value in _context_detail_sources:
		var source_id := StringName(source_id_value)
		var registration := _context_detail_sources[source_id] as Dictionary
		if StringName(registration.get("kind", &"")) == &"entry":
			stale_source_ids.append(source_id)
	for source_id in stale_source_ids:
		_context_detail_sources.erase(source_id)


func _related_term_snapshot(dto: Variant) -> Dictionary:
	var term_id := StringName(_dto_value(dto, &"id", &""))
	var display_name := String(_dto_value(dto, &"display_name", "")).strip_edges()
	var explanation := String(_dto_value(dto, &"explanation", "")).strip_edges()
	if explanation.is_empty():
		explanation = String(_dto_value(dto, &"meaning", "")).strip_edges()
	var icon_id := StringName(_dto_value(dto, &"icon_id", &"lexicon"))
	if icon_id == &"":
		icon_id = &"lexicon"
	if term_id == &"" or display_name.is_empty() or explanation.is_empty():
		return {}
	return {
		"id": term_id,
		"display_name": display_name,
		"explanation": explanation,
		"icon_id": icon_id,
	}


func _related_term_context_payload(snapshot: Dictionary) -> Dictionary:
	return {
		"entry_id": StringName(snapshot.get("id", &"")),
		"title": String(snapshot.get("display_name", "")),
		"body": String(snapshot.get("explanation", "")),
		"meta": "Lexikon",
		"accent": AlveolusVisualTheme.COBALT,
		"icon_kind": StringName(snapshot.get("icon_id", &"lexicon")),
	}


func _dto_value(dto: Variant, field: StringName, fallback: Variant) -> Variant:
	if dto is Dictionary:
		return (dto as Dictionary).get(field, fallback)
	if typeof(dto) == TYPE_OBJECT and dto != null:
		var value: Variant = (dto as Object).get(field)
		return fallback if value == null else value
	return fallback

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
			"" if presentation.semantic_role == &"resistance_effective" else presentation.meaning,
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
	var split_detail := compact_detail_visible and not _is_compact()
	for index in range(category_count):
		var category := LexiconCatalog.CATEGORY_ORDER[index]
		var button := category_buttons.get(category) as Button
		var previous := category_buttons.get(LexiconCatalog.CATEGORY_ORDER[(index - 1 + category_count) % category_count]) as Button
		var next := category_buttons.get(LexiconCatalog.CATEGORY_ORDER[(index + 1) % category_count]) as Button
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)
		if entry_filter != null:
			button.focus_neighbor_bottom = button.get_path_to(entry_filter)

	if entry_filter != null:
		var selected_category_button := category_buttons.get(selected_category) as Button
		if selected_category_button != null:
			entry_filter.focus_neighbor_top = entry_filter.get_path_to(selected_category_button)
		if not visible.is_empty():
			var first := entry_buttons.get(visible[0].id) as Button
			entry_filter.focus_neighbor_bottom = entry_filter.get_path_to(first)
		elif selected_category_button != null:
			entry_filter.focus_neighbor_bottom = entry_filter.get_path_to(selected_category_button)

	var columns := maxi(entry_list.columns if entry_list != null else 1, 1)
	for index in range(visible.size()):
		var entry_button := entry_buttons.get(visible[index].id) as Button
		var column := index % columns
		var category_button := category_buttons.get(selected_category) as Button
		var top_button: Control = entry_filter
		var bottom_button: Control = entry_filter
		var left_button: Control = category_button
		var right_button: Control = category_button
		if index >= columns:
			top_button = entry_buttons.get(visible[index - columns].id) as Button
		if index + columns < visible.size():
			bottom_button = entry_buttons.get(visible[index + columns].id) as Button
		if column > 0:
			left_button = entry_buttons.get(visible[index - 1].id) as Button
		if column + 1 < columns and index + 1 < visible.size():
			right_button = entry_buttons.get(visible[index + 1].id) as Button
		elif split_detail and compact_back_button != null:
			right_button = compact_back_button
		entry_button.focus_neighbor_top = entry_button.get_path_to(top_button)
		entry_button.focus_neighbor_bottom = entry_button.get_path_to(bottom_button)
		entry_button.focus_neighbor_left = entry_button.get_path_to(left_button)
		entry_button.focus_neighbor_right = entry_button.get_path_to(right_button)
	if compact_back_button != null and split_detail:
		var return_target := entry_buttons.get(selected_entry_id) as Button
		if return_target == null and not visible.is_empty():
			return_target = entry_buttons.get(visible[0].id) as Button
		if return_target != null:
			compact_back_button.focus_neighbor_left = compact_back_button.get_path_to(return_target)

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
	var query := entry_filter.text.strip_edges().to_lower() if entry_filter != null else ""
	for definition in definitions:
		if definition.category != selected_category:
			continue
		if not query.is_empty():
			var view_model := provider.make_view_model(definition, seen_discovery_ids)
			var searchable := "%s %s" % [view_model.display_name, view_model.summary]
			if not searchable.to_lower().contains(query):
				continue
		result.append(definition)
	return result


func _on_entry_filter_changed(_text: String) -> void:
	_rebuild_entry_list()
	_configure_focus_neighbors()


func _update_entry_count() -> void:
	if entry_count_label == null:
		return
	var total := 0
	var unlocked := 0
	for definition in definitions:
		if definition.category != selected_category:
			continue
		total += 1
		if not provider.make_view_model(definition, seen_discovery_ids).locked:
			unlocked += 1
	var shown := entry_buttons.size()
	entry_count_label.text = "%d von %d entdeckt" % [unlocked, total]
	if entry_filter != null and not entry_filter.text.strip_edges().is_empty():
		entry_count_label.text += " · %d Treffer" % shown

func _category_accent(category: StringName) -> Color:
	match category:
		LexiconEntryDefinition.CATEGORY_MONSTERS:
			return AlveolusVisualTheme.CORAL
		LexiconEntryDefinition.CATEGORY_CHARACTER:
			return AlveolusVisualTheme.COBALT
		LexiconEntryDefinition.CATEGORY_GAMEPLAY:
			return AlveolusVisualTheme.TEAL
		LexiconEntryDefinition.CATEGORY_ABILITIES:
			return AlveolusVisualTheme.TURQUOISE
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
		LexiconEntryDefinition.CATEGORY_ABILITIES:
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
	if not compact_detail_visible:
		return false
	_show_compact_list()
	return true

func _show_compact_list() -> void:
	compact_detail_visible = false
	_apply_responsive_layout()
	var selected_button := entry_buttons.get(selected_entry_id) as Button
	if selected_button != null:
		selected_button.grab_focus.call_deferred()
	elif entry_filter != null:
		entry_filter.grab_focus.call_deferred()

func _is_compact() -> bool:
	return size.x < 820.0

func _apply_responsive_layout() -> void:
	if page_scroll == null or category_bar == null or list_panel == null or detail_panel == null or entry_list == null:
		return
	var compact := _is_compact()
	page_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
		if compact
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	if not compact:
		page_scroll.scroll_vertical = 0
	category_bar.columns = _category_column_count()
	var category_rows := ceili(float(LexiconCatalog.CATEGORY_ORDER.size()) / float(category_bar.columns))
	category_bar.custom_minimum_size.y = float(category_rows * 44 + maxi(category_rows - 1, 0) * AlveolusVisualTheme.CONTROL_GAP)
	var split_detail := compact_detail_visible and not compact
	var master_width := _master_detail_width() if split_detail else 0.0
	entry_list.columns = MASTER_DETAIL_GRID_COLUMNS if split_detail else _entry_grid_column_count()
	content_row.custom_minimum_size.y = COMPACT_CONTENT_MIN_HEIGHT if compact else 0.0
	content_row.add_theme_constant_override(
		"separation",
		AlveolusVisualTheme.CONTENT_GAP if split_detail else 0
	)
	list_panel.custom_minimum_size.x = master_width
	list_panel.size_flags_horizontal = Control.SIZE_FILL if split_detail else Control.SIZE_EXPAND_FILL
	list_panel.visible = not compact_detail_visible or split_detail
	detail_panel.visible = compact_detail_visible
	if overview_toolbar != null:
		overview_toolbar.visible = not compact_detail_visible or split_detail
	var estimated_detail_width := size.x - master_width - AlveolusVisualTheme.SCREEN_MARGIN_COMPACT * 2.0
	if split_detail:
		estimated_detail_width -= AlveolusVisualTheme.CONTENT_GAP
	var detail_columns := 1 if compact or estimated_detail_width < 560.0 else 2
	for stat_grid in _detail_stat_grids:
		if stat_grid != null and is_instance_valid(stat_grid):
			stat_grid.columns = detail_columns
	for type_grid in _detail_type_grids:
		if type_grid != null and is_instance_valid(type_grid):
			type_grid.columns = detail_columns
	if compact_back_button != null:
		compact_back_button.visible = compact_detail_visible
	if not category_buttons.is_empty():
		_configure_focus_neighbors()


func _category_column_count() -> int:
	if size.x >= 720.0:
		return LexiconCatalog.CATEGORY_ORDER.size()
	if size.x >= 440.0:
		return 3
	return 2


func _entry_grid_column_count() -> int:
	if size.x >= 1170.0:
		return GRID_COLUMNS_WIDE
	if size.x >= 1030.0:
		return 6
	if size.x >= 860.0:
		return 5
	if size.x >= 690.0:
		return 4
	if size.x >= 520.0:
		return 3
	return 2


func _master_detail_width() -> float:
	return clampf(
		size.x * MASTER_DETAIL_WIDTH_RATIO,
		MASTER_DETAIL_MIN_WIDTH,
		MASTER_DETAIL_MAX_WIDTH
	)

func _add_separator(parent: Container) -> void:
	var separator := HSeparator.new()
	separator.modulate = Color(AlveolusVisualTheme.COBALT, 0.22)
	parent.add_child(separator)

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.free()
