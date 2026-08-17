class_name ProgressionScreen
extends Control

## Dense Bio-Lumen screen for research and the three talent branches.
##
## Context information is exposed as one provider per source. A
## ContextDetailController may register that provider for mouse hover and uses
## the identical provider when the global ui_info action is invoked. This
## screen never opens details from focus alone.

signal tab_changed(tab: StringName)
signal research_purchase(id: StringName)
signal talent_toggle(id: StringName)
signal talent_reset
signal back

const ProgressionScreenViewModelType := preload("res://scripts/ui/view_models/progression_screen_view_model.gd")
const TalentTreeBranchType := preload("res://scripts/ui/talent_tree_branch.gd")
const ROUTE_ID := &"research"

var _page_shell: PanelContainer
var _back_button: Button
var _tab_row: GridContainer
var _tab_group: ButtonGroup
var _research_tab_button: Button
var _talent_tab_button: Button
var _balance_label: Label

var _research_scroll: ScrollContainer
var _research_stack: VBoxContainer
var _research_inline_balance: Label
var _research_grid: GridContainer
var _talent_scroll: ScrollContainer
var _talent_stack: VBoxContainer
var _talent_inline_balance: Label
var _talent_reset_row: HBoxContainer
var _talent_reset_button: Button
var _talent_grid: GridContainer

var _research_buttons: Dictionary = {}
var _research_interactive: Dictionary = {}
var _talent_buttons: Dictionary = {}
var _talent_interactive: Dictionary = {}
var _talent_branches: Dictionary = {}
var _branch_order: Array[StringName] = []

var _info_sources: Dictionary = {}
var _research_info_source_ids: Array[int] = []
var _talent_info_source_ids: Array[int] = []

var _selected_tab := &"research"
var _research_balance_text := ""
var _talent_balance_text := ""
var _has_applied_model := false
var _applied_revision := -1
var _applied_content_hash := 0
var _applied_research_hash := 0
var _applied_talent_hash := 0


func _init() -> void:
	name = "ProgressionScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	_build()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()


func route_id() -> StringName:
	return ROUTE_ID


## Returns true only when visible content changed. A newer revision with an
## identical content hash is acknowledged without rebuilding cards or trees.
func apply_view_model(view_model: ProgressionScreenViewModelType) -> bool:
	if view_model == null:
		return false
	var next_revision := view_model.revision()
	if _has_applied_model and next_revision <= _applied_revision:
		return false
	if _has_applied_model and view_model.content_hash() == _applied_content_hash:
		_applied_revision = next_revision
		return false

	var current_focus: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	var reset_was_focused := current_focus == _talent_reset_button
	var return_focus_id := _focused_stable_id()
	_research_balance_text = view_model.research_balance_text()
	_talent_balance_text = view_model.talent_balance_text()
	AlveolusUIComponents.set_button_disabled(_talent_reset_button, not view_model.talent_reset_enabled())
	if not _has_applied_model or view_model.research_hash() != _applied_research_hash:
		_rebuild_research(view_model.research_items())
	if not _has_applied_model or view_model.talent_hash() != _applied_talent_hash:
		_rebuild_talents(view_model.talent_branches())
	_set_selected_tab(view_model.selected_tab())

	_has_applied_model = true
	_applied_revision = next_revision
	_applied_content_hash = view_model.content_hash()
	_applied_research_hash = view_model.research_hash()
	_applied_talent_hash = view_model.talent_hash()
	if reset_was_focused and _talent_reset_button.disabled:
		_focus_first_talent.call_deferred()
	elif return_focus_id != &"":
		_restore_focus.call_deferred(return_focus_id)
	return true


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> int:
	return _applied_content_hash


func selected_tab() -> StringName:
	return _selected_tab


func research_columns() -> int:
	return _research_grid.columns


func talent_columns() -> int:
	return _talent_grid.columns


func research_scroll() -> ScrollContainer:
	return _research_scroll


func talent_scroll() -> ScrollContainer:
	return _talent_scroll


func back_action() -> Button:
	return _back_button


func research_tab_action() -> Button:
	return _research_tab_button


func talent_tab_action() -> Button:
	return _talent_tab_button


func talent_reset_action() -> Button:
	return _talent_reset_button


func research_action(id: StringName) -> Button:
	return _research_buttons.get(id) as Button


func talent_action(id: StringName) -> Button:
	return _talent_buttons.get(id) as Button


func talent_branch(id: StringName) -> TalentTreeBranch:
	return _talent_branches.get(id) as TalentTreeBranch


func default_focus_control() -> Control:
	return _talent_tab_button if _selected_tab == &"talents" else _research_tab_button


## Registration records can be passed directly to
## ContextDetailController.register_source. Hover is the only automatic mode.
func context_detail_registrations() -> Array[Dictionary]:
	_prune_info_sources()
	var result: Array[Dictionary] = []
	for entry_value in _info_sources.values():
		var entry := entry_value as Dictionary
		var source_ref := entry.get("source") as WeakRef
		var source: Control = source_ref.get_ref() as Control if source_ref != null else null
		if source == null or not is_instance_valid(source):
			continue
		result.append({
			"source": source,
			"provider": entry.get("provider", Callable()),
			"hover_enabled": true,
		})
	return result


func tooltip_provider_for(source: Control) -> Callable:
	return _info_provider_for(source)


func ui_info_provider_for(source: Control) -> Callable:
	return _info_provider_for(source)


func info_payload_for(source: Control) -> Dictionary:
	var provider := _info_provider_for(source)
	if not provider.is_valid():
		return {}
	var payload: Variant = provider.call()
	return (payload as Dictionary).duplicate(true) if payload is Dictionary else {}


func registered_info_source_count() -> int:
	_prune_info_sources()
	return _info_sources.size()


func _build() -> void:
	_back_button = AlveolusUIComponents.action_button(
		"Zum Campus",
		AlveolusUIComponents.ACTION_NAVIGATION,
		&"back",
		AlveolusVisualTheme.TEAL
	)
	_back_button.name = "BackAction"
	_back_button.pressed.connect(func() -> void: back.emit())
	var header_parts := AlveolusUIComponents.page_header("Forschung", "", _back_button)

	var page_content := VBoxContainer.new()
	page_content.name = "ProgressionContent"
	page_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_build_tabs(page_content)
	_build_research_view(page_content)
	_build_talent_view(page_content)

	var shell_parts := AlveolusUIComponents.page_shell(
		header_parts["panel"] as Control,
		page_content,
		false
	)
	_page_shell = shell_parts["shell"] as PanelContainer
	_page_shell.name = "ProgressionPageShell"
	add_child(_page_shell)


func _build_tabs(parent: VBoxContainer) -> void:
	_tab_row = GridContainer.new()
	_tab_row.name = "ProgressionTabs"
	_tab_row.columns = 3
	_tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_row.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_tab_row.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	parent.add_child(_tab_row)
	_tab_group = ButtonGroup.new()
	_research_tab_button = AlveolusUIComponents.segmented_tab("Forschung", true, _tab_group)
	_research_tab_button.name = "ResearchTab"
	_research_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_research_tab_button.pressed.connect(_on_tab_pressed.bind(&"research"))
	_tab_row.add_child(_research_tab_button)
	_talent_tab_button = AlveolusUIComponents.segmented_tab("Talente", false, _tab_group)
	_talent_tab_button.name = "TalentTab"
	_talent_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talent_tab_button.pressed.connect(_on_tab_pressed.bind(&"talents"))
	_tab_row.add_child(_talent_tab_button)
	_balance_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_VALUE_LABEL)
	_balance_label.name = "ProgressionBalance"
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_balance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_row.add_child(_balance_label)


func _build_research_view(parent: VBoxContainer) -> void:
	_research_scroll = ScrollContainer.new()
	_research_scroll.name = "ResearchScroll"
	_research_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_research_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_research_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_research_scroll.follow_focus = true
	parent.add_child(_research_scroll)
	_research_stack = VBoxContainer.new()
	_research_stack.name = "ResearchContent"
	_research_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_research_stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_research_stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_research_scroll.add_child(_research_stack)
	_research_inline_balance = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_VALUE_LABEL)
	_research_inline_balance.name = "ResearchInlineBalance"
	_research_inline_balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	_research_inline_balance.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_research_inline_balance.hide()
	_research_stack.add_child(_research_inline_balance)
	_research_grid = GridContainer.new()
	_research_grid.name = "ResearchGrid"
	_research_grid.columns = 3
	_research_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_research_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_research_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_research_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_research_stack.add_child(_research_grid)


func _build_talent_view(parent: VBoxContainer) -> void:
	_talent_scroll = ScrollContainer.new()
	_talent_scroll.name = "TalentScroll"
	_talent_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talent_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_talent_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_talent_scroll.follow_focus = true
	_talent_scroll.visible = false
	parent.add_child(_talent_scroll)
	_talent_stack = VBoxContainer.new()
	_talent_stack.name = "TalentContent"
	_talent_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talent_stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_talent_stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_talent_scroll.add_child(_talent_stack)
	_talent_inline_balance = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_VALUE_LABEL)
	_talent_inline_balance.name = "TalentInlineBalance"
	_talent_inline_balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	_talent_inline_balance.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_talent_inline_balance.hide()
	_talent_stack.add_child(_talent_inline_balance)
	_talent_reset_row = HBoxContainer.new()
	_talent_reset_row.name = "TalentResetRow"
	_talent_reset_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_talent_stack.add_child(_talent_reset_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talent_reset_row.add_child(spacer)
	_talent_reset_button = AlveolusUIComponents.action_button(
		"Neu verteilen · kostenlos",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"restart",
		AlveolusVisualTheme.COBALT
	)
	_talent_reset_button.name = "TalentResetAction"
	_talent_reset_button.pressed.connect(func() -> void: talent_reset.emit())
	_talent_reset_row.add_child(_talent_reset_button)
	_talent_grid = GridContainer.new()
	_talent_grid.name = "TalentBranches"
	_talent_grid.columns = 3
	_talent_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talent_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_talent_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_talent_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTENT_GAP)
	_talent_stack.add_child(_talent_grid)


func _rebuild_research(items: Array) -> void:
	_clear_info_sources(_research_info_source_ids)
	_free_children(_research_grid)
	_research_buttons.clear()
	_research_interactive.clear()
	for item in items:
		var state := int(item.state())
		var active := state == ProgressionScreenViewModelType.ItemState.ACTIVE
		var locked := state == ProgressionScreenViewModelType.ItemState.LOCKED
		var button := AlveolusUIComponents.selection_card("", "", "", active, false)
		button.name = "Research_%s" % String(item.id())
		button.custom_minimum_size.y = 76.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_contents = true
		button.tooltip_text = ""
		button.set_meta(&"stable_focus_id", item.id())
		button.set_meta(&"item_state", _state_name(state))
		button.set_meta(&"item_interactive", item.interactive())
		button.set_meta(&"alveolus_accessible_name", "%s, %s" % [item.title(), _accessible_state_name(state)])
		button.set_meta(&"ui_sound_cue", &"confirm" if item.interactive() else &"error")
		button.pressed.connect(_on_research_pressed.bind(item.id()))
		_research_grid.add_child(button)
		_build_item_content(
			button,
			item.title(),
			item.rank_text(),
			item.cost_text(),
			item.icon_kind(),
			state,
			AlveolusVisualTheme.GOLD
		)
		_research_buttons[item.id()] = button
		_research_interactive[item.id()] = item.interactive()
		_register_info_source(button, item.info(), _research_info_source_ids)


func _rebuild_talents(branches: Array) -> void:
	_clear_info_sources(_talent_info_source_ids)
	_free_children(_talent_grid)
	_talent_buttons.clear()
	_talent_interactive.clear()
	_talent_branches.clear()
	_branch_order.clear()
	for branch_model in branches:
		var panel := AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
		panel.name = "TalentBranch_%s" % String(branch_model.id())
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_talent_grid.add_child(panel)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
		stack.add_child(heading)
		var branch_icon := SimpleIcon.new()
		branch_icon.custom_minimum_size = Vector2(24.0, 24.0)
		branch_icon.configure(branch_model.icon_kind(), branch_model.accent())
		heading.add_child(branch_icon)
		var branch_title := AlveolusUIComponents.label(branch_model.title(), AlveolusVisualTheme.TYPE_SECTION_LABEL)
		branch_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heading.add_child(branch_title)
		var tree := TalentTreeBranchType.new() as TalentTreeBranch
		tree.name = "Tree"
		tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tree.configure_accent(branch_model.accent())
		stack.add_child(tree)
		panel.add_child(AlveolusUIComponents.margin(stack, AlveolusVisualTheme.CARD_PADDING))
		for node_model in branch_model.nodes():
			var state := int(node_model.state())
			var active := state == ProgressionScreenViewModelType.ItemState.ACTIVE
			var button := AlveolusUIComponents.selection_card("", "", "", active, false)
			button.name = "Talent_%s" % String(node_model.id())
			button.custom_minimum_size.y = TalentTreeBranch.NODE_HEIGHT
			button.clip_contents = true
			button.tooltip_text = ""
			button.set_meta(&"stable_focus_id", node_model.id())
			button.set_meta(&"item_state", _state_name(state))
			button.set_meta(&"item_interactive", node_model.interactive())
			button.set_meta(&"alveolus_accessible_name", "%s, %s" % [node_model.title(), _accessible_state_name(state)])
			button.set_meta(&"ui_sound_cue", &"confirm" if node_model.interactive() else &"error")
			button.pressed.connect(_on_talent_pressed.bind(node_model.id()))
			_build_item_content(
				button,
				node_model.title(),
				"",
				node_model.cost_text(),
				node_model.icon_kind(),
				state,
				branch_model.accent(),
				true
			)
			tree.add_talent_node(
				node_model.id(),
				button,
				node_model.tier(),
				node_model.lane(),
				node_model.required_ids(),
				_state_name(state)
			)
			_talent_buttons[node_model.id()] = button
			_talent_interactive[node_model.id()] = node_model.interactive()
			_register_info_source(button, node_model.info(), _talent_info_source_ids)
		panel.custom_minimum_size.y = tree.custom_minimum_size.y + 68.0
		_talent_branches[branch_model.id()] = tree
		_branch_order.append(branch_model.id())
	_configure_branch_exits.call_deferred()


func _build_item_content(
	button: Button,
	title_text: String,
	subtitle_text: String,
	value_text: String,
	icon_kind: StringName,
	state: int,
	accent: Color,
	talent_density: bool = false
) -> void:
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var horizontal_inset := AlveolusVisualTheme.GRID_UNIT if talent_density else AlveolusVisualTheme.CONTENT_GAP
	var row_gap := AlveolusVisualTheme.GRID_UNIT if talent_density else AlveolusVisualTheme.CONTROL_GAP
	inset.add_theme_constant_override("margin_left", horizontal_inset)
	inset.add_theme_constant_override("margin_top", AlveolusVisualTheme.CONTROL_GAP)
	inset.add_theme_constant_override("margin_right", horizontal_inset)
	inset.add_theme_constant_override("margin_bottom", AlveolusVisualTheme.CONTROL_GAP)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inset)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", row_gap)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(row)
	var locked := state == ProgressionScreenViewModelType.ItemState.LOCKED
	var active := state == ProgressionScreenViewModelType.ItemState.ACTIVE
	var content_modulate := Color(AlveolusVisualTheme.SKY_DEEP, 0.48) if locked else Color.WHITE
	var icon := SimpleIcon.new()
	icon.custom_minimum_size = Vector2.ONE * (22.0 if talent_density else 28.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(icon_kind, accent if not locked else AlveolusVisualTheme.MUTED)
	icon.modulate = content_modulate
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var title := AlveolusUIComponents.label(title_text, AlveolusVisualTheme.TYPE_BODY_LABEL)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.modulate = content_modulate
	copy.add_child(title)
	if not subtitle_text.is_empty():
		var subtitle := AlveolusUIComponents.label(subtitle_text, AlveolusVisualTheme.TYPE_MUTED_LABEL)
		subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		subtitle.modulate = content_modulate
		copy.add_child(subtitle)
	var value := AlveolusUIComponents.label(value_text, AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.modulate = content_modulate
	row.add_child(value)
	if active or locked:
		var state_icon := SimpleIcon.new()
		state_icon.name = "StateIcon"
		state_icon.custom_minimum_size = Vector2.ONE * (16.0 if talent_density else 20.0)
		state_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		state_icon.configure(
			&"check" if active else &"locked",
			AlveolusVisualTheme.TEAL if active else AlveolusVisualTheme.MUTED
		)
		row.add_child(state_icon)


func _on_tab_pressed(tab: StringName) -> void:
	_set_selected_tab(tab)
	tab_changed.emit(_selected_tab)


func _on_research_pressed(id: StringName) -> void:
	if bool(_research_interactive.get(id, false)):
		research_purchase.emit(id)


func _on_talent_pressed(id: StringName) -> void:
	if bool(_talent_interactive.get(id, false)):
		talent_toggle.emit(id)


func _set_selected_tab(tab: StringName) -> void:
	_selected_tab = &"talents" if tab == &"talents" else &"research"
	var research_selected := _selected_tab == &"research"
	_research_tab_button.set_pressed_no_signal(research_selected)
	_talent_tab_button.set_pressed_no_signal(not research_selected)
	_research_tab_button.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB if research_selected else AlveolusVisualTheme.TYPE_SEGMENTED_TAB
	_talent_tab_button.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB if not research_selected else AlveolusVisualTheme.TYPE_SEGMENTED_TAB
	_research_scroll.visible = research_selected
	_talent_scroll.visible = not research_selected
	_balance_label.text = _research_balance_text if research_selected else _talent_balance_text
	_research_inline_balance.text = _research_balance_text
	_talent_inline_balance.text = _talent_balance_text
	_update_responsive_layout()


func _register_info_source(source: Control, info: Variant, id_bucket: Array[int]) -> void:
	if source == null or info == null:
		return
	var source_id := source.get_instance_id()
	var provider := _info_payload.bind(info.duplicate_value())
	_info_sources[source_id] = {
		"source": weakref(source),
		"provider": provider,
	}
	id_bucket.append(source_id)


func _info_payload(info: Variant) -> Dictionary:
	var payload := info.payload() as Dictionary
	var accent: Color = payload.get("accent", Color.TRANSPARENT)
	if accent.a <= 0.0:
		payload["accent"] = AlveolusVisualTheme.COBALT
	return payload.duplicate(true)


func _info_provider_for(source: Control) -> Callable:
	if source == null:
		return Callable()
	var entry: Dictionary = _info_sources.get(source.get_instance_id(), {})
	var provider: Callable = entry.get("provider", Callable())
	return provider


func _clear_info_sources(ids: Array[int]) -> void:
	for source_id in ids:
		_info_sources.erase(source_id)
	ids.clear()


func _prune_info_sources() -> void:
	var stale_ids: Array[int] = []
	for source_id_value in _info_sources:
		var source_id := int(source_id_value)
		var entry := _info_sources[source_id] as Dictionary
		var source_ref := entry.get("source") as WeakRef
		var source: Variant = source_ref.get_ref() if source_ref != null else null
		if not source is Control or not is_instance_valid(source):
			stale_ids.append(source_id)
	for source_id in stale_ids:
		_info_sources.erase(source_id)


func _configure_branch_exits() -> void:
	var columns := maxi(1, _talent_grid.columns)
	for index in range(_branch_order.size()):
		var id := _branch_order[index]
		var tree := _talent_branches.get(id) as TalentTreeBranch
		if tree == null:
			continue
		var column := index % columns
		var left: Control = _talent_tab_button
		var right: Control = _talent_reset_button
		var top: Control = _talent_tab_button
		var bottom: Control = _talent_reset_button
		if column > 0:
			var left_tree := _talent_branches.get(_branch_order[index - 1]) as TalentTreeBranch
			if left_tree != null and left_tree.root_button() != null:
				left = left_tree.root_button()
		if column + 1 < columns and index + 1 < _branch_order.size():
			var right_tree := _talent_branches.get(_branch_order[index + 1]) as TalentTreeBranch
			if right_tree != null and right_tree.root_button() != null:
				right = right_tree.root_button()
		var above_index := index - columns
		if above_index >= 0:
			var above_tree := _talent_branches.get(_branch_order[above_index]) as TalentTreeBranch
			if above_tree != null and above_tree.root_button() != null:
				top = above_tree.root_button()
		var below_index := index + columns
		if below_index < _branch_order.size():
			var below_tree := _talent_branches.get(_branch_order[below_index]) as TalentTreeBranch
			if below_tree != null and below_tree.root_button() != null:
				bottom = below_tree.root_button()
		tree.configure_focus_exits(top, left, right, bottom)


func _update_responsive_layout() -> void:
	if _research_grid == null or _talent_grid == null:
		return
	var logical_width := size.x
	if logical_width <= 0.0 and get_viewport() != null:
		logical_width = get_viewport_rect().size.x
	_research_grid.columns = 3 if logical_width >= 1000.0 else (2 if logical_width >= 680.0 else 1)
	_talent_grid.columns = 3 if logical_width >= 1080.0 else (2 if logical_width >= 760.0 else 1)
	var compact := logical_width < 620.0
	_tab_row.columns = 2 if compact else 3
	_balance_label.visible = not compact
	_research_inline_balance.visible = compact
	_talent_inline_balance.visible = compact
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if compact:
		_talent_stack.move_child(_talent_grid, 1)
		_talent_stack.move_child(_talent_reset_row, 2)
	else:
		_talent_stack.move_child(_talent_reset_row, 1)
		_talent_stack.move_child(_talent_grid, 2)
	_configure_branch_exits.call_deferred()


func _focused_stable_id() -> StringName:
	if get_viewport() == null:
		return &""
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not is_ancestor_of(focus_owner):
		return &""
	return StringName(focus_owner.get_meta(&"stable_focus_id", &""))


func _restore_focus(id: StringName) -> void:
	var target := research_action(id)
	if target == null:
		target = talent_action(id)
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


func _focus_first_talent() -> void:
	for branch_id in _branch_order:
		var branch := _talent_branches.get(branch_id) as TalentTreeBranch
		if branch == null:
			continue
		var target := branch.root_button()
		if target != null and target.is_visible_in_tree():
			target.grab_focus()
			_talent_scroll.ensure_control_visible(target)
			return
	_talent_tab_button.grab_focus()


func _state_name(state: int) -> StringName:
	match state:
		ProgressionScreenViewModelType.ItemState.ACTIVE:
			return &"active"
		ProgressionScreenViewModelType.ItemState.AVAILABLE:
			return &"available"
	return &"locked"


func _accessible_state_name(state: int) -> String:
	match state:
		ProgressionScreenViewModelType.ItemState.ACTIVE:
			return "aktiv"
		ProgressionScreenViewModelType.ItemState.AVAILABLE:
			return "verfügbar"
	return "gesperrt"


func _free_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.free()
