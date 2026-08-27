class_name ResultOverlay
extends Control

signal retry
signal levels
signal campus

const CANCEL_POLICY := &"consume"
const COMPACT_WIDTH := 700.0
const MODAL_MAXIMUM_WIDTH := 660.0
const MODAL_PADDING := 16
const MINIMUM_BODY_VIEWPORT_HEIGHT := 34.0
const SECTION_CHEVRON_SIZE := 20.0
const ABILITY_SECTION_TITLE := "Fähigkeiten"
const REWARD_PLACEHOLDERS: Array[String] = [
	"+ irgendwas",
	"+ maybe nochwas",
	"+ idk",
]

var _view_model: ResultOverlayViewModel
var _applied_revision := -1
var _applied_content_hash := 0
var _safe_area: MarginContainer
var _scroll: ScrollContainer
var _center: CenterContainer
var _modal_host: VBoxContainer
var _modal: PanelContainer
var _body_content: VBoxContainer
var _action_row: HBoxContainer
var _outcome_emblem_center: CenterContainer
var _outcome_title: Label
var _stats_grid: GridContainer
var _reward_grid: GridContainer
var _action_grid: GridContainer
var _compact_secondary_grid: GridContainer
var _levels_button: Button
var _retry_button: Button
var _campus_button: Button
var _ability_section: PanelContainer
var _ability_section_header: Button
var _ability_section_body: VBoxContainer
var _ability_damage_grid: GridContainer
var _talent_grid: GridContainer
var _ability_section_expanded := false
var _compact_layout := false


func _init() -> void:
	set_process(false)
	set_physics_process(false)
	_build_stage()


func apply(view_model: ResultOverlayViewModel) -> bool:
	if view_model == null:
		return false
	var next_revision := view_model.get_revision()
	var next_hash := view_model.get_content_hash()
	if next_revision < _applied_revision:
		return false
	if next_revision == _applied_revision and _view_model != null:
		return false
	if _view_model != null and next_hash == _applied_content_hash:
		_view_model = view_model.duplicate_immutable()
		_applied_revision = next_revision
		return false
	_view_model = view_model.duplicate_immutable()
	_applied_revision = next_revision
	_applied_content_hash = next_hash
	_rebuild_modal()
	return true


func apply_view_model(view_model: ResultOverlayViewModel) -> bool:
	return apply(view_model)


func get_applied_revision() -> int:
	return _applied_revision


func get_applied_content_hash() -> int:
	return _applied_content_hash


func get_view_model() -> ResultOverlayViewModel:
	return _view_model.duplicate_immutable() if _view_model != null else null


func get_cancel_policy() -> StringName:
	return CANCEL_POLICY


func consumes_cancel() -> bool:
	return true


## The completed result is a terminal layer. ui_cancel is acknowledged while
## visible, but deliberately emits no navigation intent and cannot dismiss it.
func handle_ui_cancel() -> bool:
	return is_inside_tree() and is_visible_in_tree()


func get_default_focus_control() -> Control:
	return _levels_button


func grab_initial_focus() -> void:
	if _levels_button == null:
		return
	# The dominant action lives in the sticky footer. It must not change the
	# internal result-body position while the sheet is opening.
	if _scroll != null:
		_scroll.follow_focus = false
		_scroll.scroll_vertical = 0
	_levels_button.grab_focus()
	_restore_initial_scroll.call_deferred()


func get_scroll_container() -> ScrollContainer:
	return _scroll


func get_modal() -> PanelContainer:
	return _modal


func get_stats_column_count() -> int:
	return _stats_grid.columns if _stats_grid != null else 0


func get_action_column_count() -> int:
	return _action_grid.columns if _action_grid != null else 0


func get_reward_column_count() -> int:
	return _reward_grid.columns if _reward_grid != null else 0


func reward_anchor(reward_id: StringName) -> Control:
	if _reward_grid == null:
		return null
	for child in _reward_grid.get_children():
		if child is Control and StringName(child.get_meta(&"reward_id", &"")) == reward_id:
			var icon := child.find_child("RewardIcon", true, false) as Control
			return icon if icon != null else child as Control
	return null


func get_ability_section_header() -> Button:
	return _ability_section_header


func get_ability_section_body() -> VBoxContainer:
	return _ability_section_body


func is_ability_section_expanded() -> bool:
	return _ability_section_expanded


func is_compact_layout() -> bool:
	return _compact_layout


func _build_stage() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED

	var dimmer := ColorRect.new()
	dimmer.name = "Backdrop"
	dimmer.color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.90)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	_safe_area = MarginContainer.new()
	_safe_area.name = "SafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_area)

	_center = CenterContainer.new()
	_center.name = "ResultCenter"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_safe_area.add_child(_center)

	_modal_host = VBoxContainer.new()
	_modal_host.name = "ModalHost"
	_modal_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_center.add_child(_modal_host)

	resized.connect(_refresh_responsive_layout)


func _rebuild_modal() -> void:
	for child in _modal_host.get_children():
		_modal_host.remove_child(child)
		child.queue_free()
	_ability_section_expanded = false
	_ability_section = null
	_ability_section_header = null
	_ability_section_body = null
	_ability_damage_grid = null
	_talent_grid = null

	var accent := AlveolusVisualTheme.TEAL if _view_model.is_success() else AlveolusVisualTheme.CORAL
	_body_content = VBoxContainer.new()
	_body_content.name = "ResultContent"
	_body_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)

	var heading := VBoxContainer.new()
	heading.name = "OutcomeHeading"
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	_body_content.add_child(heading)
	_outcome_emblem_center = CenterContainer.new()
	_outcome_emblem_center.name = "OutcomeEmblemCenter"
	_outcome_emblem_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(_outcome_emblem_center)
	var emblem := AlveolusUIComponents.surface(AlveolusVisualTheme.SurfaceRole.DETAIL_CARD, accent)
	emblem.name = "OutcomeEmblem"
	emblem.custom_minimum_size = Vector2(52.0, 52.0)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outcome_emblem_center.add_child(emblem)
	var outcome_icon := SimpleIcon.new()
	outcome_icon.name = "OutcomeIcon"
	outcome_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	outcome_icon.configure(&"check" if _view_model.is_success() else &"remove", accent)
	emblem.add_child(outcome_icon)
	_outcome_title = AlveolusUIComponents.label(_view_model.get_title(), AlveolusVisualTheme.TYPE_TITLE_LABEL)
	_outcome_title.name = "OutcomeTitle"
	_outcome_title.add_theme_color_override("font_color", accent.lightened(0.12))
	_outcome_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome_title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	heading.add_child(_outcome_title)

	_build_reward_strip(_body_content)

	var reason_text := _view_model.get_reason().strip_edges()
	if not reason_text.is_empty():
		var reason := AlveolusUIComponents.label(reason_text, AlveolusVisualTheme.TYPE_BODY_LABEL)
		reason.name = "Reason"
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body_content.add_child(reason)
	var detail_text := _view_model.get_detail().strip_edges()
	if not detail_text.is_empty():
		var detail := AlveolusUIComponents.label(detail_text, AlveolusVisualTheme.TYPE_MUTED_LABEL)
		detail.name = "Detail"
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body_content.add_child(detail)

	_stats_grid = GridContainer.new()
	_stats_grid.name = "StatsGrid"
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_stats_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	for stat in _view_model.get_stats():
		var row := _build_result_metric(stat)
		row.name = "Stat_%s" % String(stat.get_id())
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats_grid.add_child(row)
	if _stats_grid.get_child_count() > 0:
		_body_content.add_child(_stats_grid)

	_add_optional_section(_body_content, &"unlock", "Freigeschaltet", _view_model.get_unlock_text(), &"archive", AlveolusVisualTheme.COBALT)
	_add_optional_section(_body_content, &"mastery", "Meisterschaft", _view_model.get_mastery_text(), &"check", AlveolusVisualTheme.TURQUOISE)
	_build_ability_section(_body_content)

	_scroll = ScrollContainer.new()
	_scroll.name = "ResultBodyScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = false
	_scroll.add_child(_body_content)
	_scroll.resized.connect(_refresh_responsive_layout)

	_action_grid = GridContainer.new()
	_action_grid.name = "ResultActions"
	_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_action_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_levels_button = AlveolusUIComponents.action_button(
		_view_model.get_levels_action_text(),
		AlveolusUIComponents.ACTION_PRIMARY,
		&"archive",
		AlveolusVisualTheme.TEAL
	)
	_levels_button.name = "LevelsButton"
	_levels_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels_button.pressed.connect(func() -> void: levels.emit())
	_action_grid.add_child(_levels_button)
	_retry_button = AlveolusUIComponents.action_button(
		_view_model.get_retry_action_text(),
		AlveolusUIComponents.ACTION_SECONDARY,
		&"restart",
		AlveolusVisualTheme.TEAL
	)
	_retry_button.name = "RetryButton"
	_retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_retry_button.pressed.connect(func() -> void: retry.emit())
	_campus_button = AlveolusUIComponents.action_button(
		_view_model.get_campus_action_text(),
		AlveolusUIComponents.ACTION_SECONDARY,
		&"back",
		AlveolusVisualTheme.COBALT
	)
	_campus_button.name = "CampusButton"
	_campus_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campus_button.pressed.connect(func() -> void: campus.emit())
	_compact_secondary_grid = GridContainer.new()
	_compact_secondary_grid.name = "CompactSecondaryActions"
	_compact_secondary_grid.columns = 2
	_compact_secondary_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_secondary_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_compact_secondary_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_compact_secondary_grid.add_child(_retry_button)
	_compact_secondary_grid.add_child(_campus_button)
	_compact_secondary_grid.show()
	_action_grid.add_child(_compact_secondary_grid)

	var modal_actions: Array[Control] = [_action_grid]
	var sheet := AlveolusUIComponents.modal_sheet("", _scroll, modal_actions, MODAL_PADDING, accent)
	_modal = sheet["panel"] as PanelContainer
	_action_row = sheet["actions"] as HBoxContainer
	_modal.name = "ResultModal"
	_modal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_modal.set_meta(&"result_success", _view_model.is_success())
	_modal.set_meta(&"cancel_policy", CANCEL_POLICY)
	_modal_host.add_child(_modal)
	_link_action_focus_cycle()
	if _scroll != null:
		_scroll.follow_focus = false
		_scroll.scroll_vertical = 0
	_refresh_responsive_layout.call_deferred()
	_restore_initial_scroll.call_deferred()


func _link_action_focus_cycle() -> void:
	for action in [_levels_button, _retry_button, _campus_button]:
		action.set_meta(&"alveolus_owns_directional_focus", true)
	_levels_button.focus_neighbor_left = _levels_button.get_path_to(_campus_button)
	_levels_button.focus_neighbor_right = _levels_button.get_path_to(_retry_button)
	_levels_button.focus_neighbor_bottom = _levels_button.get_path_to(_retry_button)
	_levels_button.focus_neighbor_top = (
		_levels_button.get_path_to(_ability_section_header)
		if _ability_section_header != null
		else _levels_button.get_path_to(_campus_button)
	)
	_retry_button.focus_neighbor_left = _retry_button.get_path_to(_levels_button)
	_retry_button.focus_neighbor_right = _retry_button.get_path_to(_campus_button)
	_retry_button.focus_neighbor_top = _retry_button.get_path_to(_levels_button)
	_retry_button.focus_neighbor_bottom = _retry_button.get_path_to(_levels_button)
	_campus_button.focus_neighbor_left = _campus_button.get_path_to(_retry_button)
	_campus_button.focus_neighbor_right = _campus_button.get_path_to(_levels_button)
	_campus_button.focus_neighbor_top = _campus_button.get_path_to(_levels_button)
	_campus_button.focus_neighbor_bottom = _campus_button.get_path_to(_levels_button)
	if _ability_section_header != null:
		_ability_section_header.set_meta(&"alveolus_owns_directional_focus", true)
		_ability_section_header.focus_neighbor_left = _ability_section_header.get_path_to(_campus_button)
		_ability_section_header.focus_neighbor_top = _ability_section_header.get_path_to(_campus_button)
		_ability_section_header.focus_neighbor_right = _ability_section_header.get_path_to(_levels_button)
		_ability_section_header.focus_neighbor_bottom = _ability_section_header.get_path_to(_levels_button)


func _build_ability_section(parent: VBoxContainer) -> void:
	var ability_stats := _view_model.get_ability_damage_stats()
	var talent_stats := _view_model.get_talent_stats()
	var show_talents := _view_model.are_talents_unlocked() or not talent_stats.is_empty()
	if ability_stats.is_empty() and not show_talents:
		_ability_section_expanded = false
		return

	_ability_section = AlveolusUIComponents.surface(
		AlveolusVisualTheme.SurfaceRole.SECTION_GROUP,
		AlveolusVisualTheme.TURQUOISE
	)
	_ability_section.name = "AbilitySection"
	_ability_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_section.set_meta(&"alveolus_component", &"stat_accordion_section")
	_ability_section.set_meta(&"result_detail_section", &"abilities")
	var stack := VBoxContainer.new()
	stack.name = "AbilitySectionStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)

	_ability_section_header = AlveolusUIComponents.action_button(
		"",
		AlveolusUIComponents.ACTION_QUIET
	)
	_ability_section_header.name = "AbilitySectionHeader"
	_ability_section_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ability_section_header.toggle_mode = true
	_ability_section_header.flat = true
	_ability_section_header.focus_mode = Control.FOCUS_ALL
	_ability_section_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_section_header.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	_ability_section_header.set_meta(&"result_detail_section", &"abilities")
	_ability_section_header.toggled.connect(_on_ability_section_toggled)
	_ability_section_header.focus_entered.connect(_ensure_ability_header_visible)
	var header_inset := MarginContainer.new()
	header_inset.name = "AbilitySectionHeaderInset"
	header_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_inset.add_theme_constant_override("margin_left", AlveolusVisualTheme.CONTROL_GAP)
	header_inset.add_theme_constant_override("margin_right", AlveolusVisualTheme.CONTROL_GAP)
	header_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header_row := HBoxContainer.new()
	header_row.name = "AbilitySectionHeaderRow"
	header_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_inset.add_child(header_row)
	var chevron := SimpleIcon.new()
	chevron.name = "AbilitySectionChevron"
	chevron.custom_minimum_size = Vector2.ONE * SECTION_CHEVRON_SIZE
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.configure(&"chevron_right", AlveolusVisualTheme.TURQUOISE)
	chevron.set_meta(&"alveolus_component", &"accordion_chevron")
	header_row.add_child(chevron)
	var title := AlveolusUIComponents.label(
		ABILITY_SECTION_TITLE,
		AlveolusVisualTheme.TYPE_VALUE_LABEL
	)
	title.name = "AbilitySectionTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(title)
	_ability_section_header.add_child(header_inset)
	stack.add_child(_ability_section_header)

	_ability_section_body = VBoxContainer.new()
	_ability_section_body.name = "AbilitySectionBody"
	_ability_section_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_section_body.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	if not ability_stats.is_empty():
		_ability_damage_grid = GridContainer.new()
		_ability_damage_grid.name = "AbilityDamageRows"
		_ability_damage_grid.columns = 1
		_ability_damage_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ability_damage_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.GRID_UNIT)
		for stat in ability_stats:
			var row := AlveolusUIComponents.value_row(stat.get_label(), stat.get_value(), stat.is_highlighted())
			row.name = "AbilityDamage_%s" % String(stat.get_id())
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.set_meta(&"result_detail_kind", &"ability_damage")
			_ability_damage_grid.add_child(row)
		_ability_section_body.add_child(_ability_damage_grid)
	if show_talents:
		var talent_title := AlveolusUIComponents.label("Talente", AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
		talent_title.name = "TalentSectionTitle"
		_ability_section_body.add_child(talent_title)
		if talent_stats.is_empty():
			var empty_talents := AlveolusUIComponents.label(
				"Noch keine Talente aktiv",
				AlveolusVisualTheme.TYPE_MUTED_LABEL
			)
			empty_talents.name = "TalentEmptyState"
			empty_talents.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_ability_section_body.add_child(empty_talents)
		else:
			_talent_grid = GridContainer.new()
			_talent_grid.name = "TalentRows"
			_talent_grid.columns = 1
			_talent_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_talent_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.GRID_UNIT)
			for stat in talent_stats:
				var row := AlveolusUIComponents.value_row(stat.get_label(), stat.get_value(), stat.is_highlighted())
				row.name = "Talent_%s" % String(stat.get_id())
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.set_meta(&"result_detail_kind", &"talent")
				_talent_grid.add_child(row)
			_ability_section_body.add_child(_talent_grid)
	stack.add_child(_ability_section_body)
	_ability_section.add_child(AlveolusUIComponents.margin(stack, AlveolusVisualTheme.GRID_UNIT))
	parent.add_child(_ability_section)
	_apply_ability_section_expansion()


func _on_ability_section_toggled(expanded: bool) -> void:
	_ability_section_expanded = expanded
	_apply_ability_section_expansion()
	_refresh_responsive_layout.call_deferred()


func _apply_ability_section_expansion() -> void:
	if _ability_section_header != null:
		_ability_section_header.set_pressed_no_signal(_ability_section_expanded)
		var state: StringName = &"expanded" if _ability_section_expanded else &"collapsed"
		var chevron := _ability_section_header.find_child("AbilitySectionChevron", true, false) as SimpleIcon
		if chevron != null:
			chevron.configure(
				&"chevron_down" if _ability_section_expanded else &"chevron_right",
				AlveolusVisualTheme.TURQUOISE
			)
			chevron.set_meta(&"accordion_state", state)
		_ability_section_header.set_meta(&"accordion_state", state)
		_ability_section_header.set_meta(
			&"alveolus_accessible_name",
			"%s, %s. %s" % [
				ABILITY_SECTION_TITLE,
				"ausgeklappt" if _ability_section_expanded else "eingeklappt",
				"Einklappen" if _ability_section_expanded else "Ausklappen",
			]
		)
		_ability_section_header.tooltip_text = "%s %s" % [
			ABILITY_SECTION_TITLE,
			"einklappen" if _ability_section_expanded else "ausklappen",
		]
	if _ability_section_body != null:
		_ability_section_body.visible = _ability_section_expanded


func _ensure_ability_header_visible() -> void:
	if _scroll != null and _ability_section_header != null:
		_scroll.ensure_control_visible(_ability_section_header)


func _add_optional_section(
	parent: VBoxContainer,
	section_id: StringName,
	title_text: String,
	body_text: String,
	icon_kind: StringName,
	accent: Color
) -> void:
	if body_text.is_empty():
		return
	var section := AlveolusUIComponents.semantic_copy_section(title_text, body_text, icon_kind, accent)
	var panel := section["panel"] as PanelContainer
	panel.name = "Optional_%s" % String(section_id)
	panel.set_meta(&"result_optional_section", section_id)
	(section["body"] as Label).name = "Optional_%s_Body" % String(section_id)
	parent.add_child(panel)


func _build_result_metric(stat: ResultOverlayViewModel.StatViewModel) -> VBoxContainer:
	var metric := VBoxContainer.new()
	metric.alignment = BoxContainer.ALIGNMENT_CENTER
	metric.add_theme_constant_override("separation", 0)
	metric.set_meta(&"alveolus_component", &"result_metric")
	var value := AlveolusUIComponents.label(stat.get_value(), AlveolusVisualTheme.TYPE_SECTION_LABEL)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_color_override(
		"font_color",
		AlveolusVisualTheme.TURQUOISE if stat.is_highlighted() else AlveolusVisualTheme.IVORY
	)
	metric.add_child(value)
	var caption := AlveolusUIComponents.label(stat.get_label(), AlveolusVisualTheme.TYPE_MUTED_LABEL)
	caption.name = "ValueName"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	metric.add_child(caption)
	return metric


func _build_reward_strip(parent: VBoxContainer) -> void:
	_reward_grid = null
	var rewards := _view_model.get_reward_items()
	if rewards.is_empty():
		return
	_reward_grid = GridContainer.new()
	_reward_grid.name = "RewardStrip"
	_reward_grid.columns = 4
	_reward_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_reward_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_reward_grid.set_meta(&"alveolus_component", &"content_driven_reward_strip")
	_reward_grid.add_child(_build_reward_item(rewards[0]))
	for index in range(REWARD_PLACEHOLDERS.size()):
		_reward_grid.add_child(_build_reward_placeholder(index, REWARD_PLACEHOLDERS[index]))
	parent.add_child(_reward_grid)


func _build_reward_item(reward: ResultOverlayViewModel.RewardViewModel) -> PanelContainer:
	var column := AlveolusUIComponents.surface(
		AlveolusVisualTheme.SurfaceRole.ACTION_CARD,
		_accent_color(reward.get_accent_role())
	)
	column.name = "Reward_%s" % String(reward.get_id())
	column.custom_minimum_size.y = 76.0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.set_meta(&"reward_id", reward.get_id())
	column.set_meta(&"alveolus_accessible_name", reward.get_accessible_name())
	column.set_meta(&"reward_state", &"earned")
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var icon_center := CenterContainer.new()
	icon_center.name = "IconCenter"
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := SimpleIcon.new()
	icon.name = "RewardIcon"
	icon.custom_minimum_size = Vector2(36.0, 36.0)
	icon.configure(reward.get_icon_id(), _accent_color(reward.get_accent_role()))
	icon.set_meta(&"reward_icon_id", reward.get_icon_id())
	icon_center.add_child(icon)
	stack.add_child(icon_center)
	var value := AlveolusUIComponents.label(reward.get_value(), AlveolusVisualTheme.TYPE_VALUE_LABEL)
	# Compatibility target retained for the existing discovery anchor facade.
	value.name = "Optional_reward_Body" if reward.get_id() == &"research" else "RewardValue"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(value)
	column.add_child(AlveolusUIComponents.margin(stack, 8))
	return column


func _build_reward_placeholder(index: int, text_value: String) -> PanelContainer:
	var column := AlveolusUIComponents.surface(
		AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET,
		AlveolusVisualTheme.MUTED
	)
	column.name = "RewardPlaceholder%d" % (index + 1)
	column.custom_minimum_size.y = 76.0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.set_meta(&"reward_placeholder", true)
	column.set_meta(&"reward_state", &"locked")
	column.set_meta(&"alveolus_accessible_name", "Künftige Belohnung gesperrt: %s" % text_value)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var lock_center := CenterContainer.new()
	lock_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lock_icon := SimpleIcon.new()
	lock_icon.name = "PlaceholderLock"
	lock_icon.custom_minimum_size = Vector2(22.0, 22.0)
	lock_icon.configure(&"locked", AlveolusVisualTheme.GOLD)
	lock_center.add_child(lock_icon)
	stack.add_child(lock_center)
	var label := AlveolusUIComponents.label(text_value, AlveolusVisualTheme.TYPE_MUTED_LABEL)
	label.name = "PlaceholderValue"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(label)
	column.add_child(AlveolusUIComponents.margin(stack, 8))
	return column


func _accent_color(role: StringName) -> Color:
	match role:
		&"teal":
			return AlveolusVisualTheme.TEAL
		&"turquoise":
			return AlveolusVisualTheme.TURQUOISE
		&"cobalt":
			return AlveolusVisualTheme.COBALT
		&"coral":
			return AlveolusVisualTheme.CORAL
	return AlveolusVisualTheme.GOLD


func _refresh_responsive_layout() -> void:
	if _safe_area == null:
		return
	var logical_width := size.x
	if logical_width <= 1.0 and get_viewport() != null:
		logical_width = get_viewport().get_visible_rect().size.x
	_compact_layout = logical_width < COMPACT_WIDTH
	var margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if _compact_layout else AlveolusVisualTheme.SCREEN_MARGIN
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_safe_area.add_theme_constant_override(side, margin)
	if _modal != null:
		var available_width := maxf(0.0, logical_width - float(margin * 2))
		_modal.custom_minimum_size.x = minf(MODAL_MAXIMUM_WIDTH, available_width)
		_modal.custom_minimum_size.y = 0.0
	if _stats_grid != null:
		_stats_grid.columns = 1 if _compact_layout else maxi(1, mini(3, _stats_grid.get_child_count()))
	if _outcome_emblem_center != null:
		# On the 480 × 270 logical stage the title is the outcome signal; hiding
		# only the decorative emblem keeps the first earned reward in view.
		_outcome_emblem_center.visible = not _compact_layout
	if _outcome_title != null:
		_outcome_title.add_theme_font_size_override(
			"font_size",
			22 if _compact_layout else AlveolusVisualTheme.TEXT_TITLE
		)
	if _reward_grid != null:
		_reward_grid.columns = 2 if _compact_layout else 4
		for reward_value in _reward_grid.get_children():
			var reward := reward_value as Control
			if reward == null:
				continue
			reward.custom_minimum_size.y = 64.0 if _compact_layout else 76.0
			var reward_icon := reward.find_child("RewardIcon", true, false) as SimpleIcon
			if reward_icon != null:
				reward_icon.custom_minimum_size = Vector2.ONE * (28.0 if _compact_layout else 36.0)
			var lock_icon := reward.find_child("PlaceholderLock", true, false) as SimpleIcon
			if lock_icon != null:
				lock_icon.custom_minimum_size = Vector2.ONE * (18.0 if _compact_layout else 22.0)
			var reward_margin := reward.get_child(0) as MarginContainer if reward.get_child_count() > 0 else null
			if reward_margin != null:
				var reward_inset := 6 if _compact_layout else 8
				for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
					reward_margin.add_theme_constant_override(side, reward_inset)
	if _apply_action_layout():
		_refresh_responsive_layout.call_deferred()
		return
	if _scroll != null and _body_content != null:
		var available_height := maxf(0.0, size.y - float(margin * 2))
		var footer_height := _action_row.get_combined_minimum_size().y if _action_row != null else 0.0
		var modal_chrome_height := float(MODAL_PADDING * 2)
		if _action_row != null:
			modal_chrome_height += float(AlveolusVisualTheme.CONTENT_GAP)
		var available_body_height := maxf(
			MINIMUM_BODY_VIEWPORT_HEIGHT,
			available_height - footer_height - modal_chrome_height
		)
		var content_height := _body_content.get_combined_minimum_size().y
		var visible_body_height := minf(content_height, available_body_height)
		_scroll.custom_minimum_size.y = visible_body_height
		var requires_scroll := content_height > visible_body_height + 1.0
		_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_AUTO if requires_scroll
			else ScrollContainer.SCROLL_MODE_DISABLED
		)
		if not requires_scroll:
			_scroll.scroll_vertical = 0


func _apply_action_layout() -> bool:
	if _action_grid == null or _compact_secondary_grid == null:
		return false
	_action_grid.columns = 1
	_compact_secondary_grid.columns = 2
	_compact_secondary_grid.show()
	return false


func _restore_initial_scroll() -> void:
	if _scroll == null:
		return
	_scroll.scroll_vertical = 0
	_scroll.follow_focus = false
