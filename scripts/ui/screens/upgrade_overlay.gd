class_name UpgradeOverlay
extends Control

## Bio-Lumen upgrade choice overlay.
##
## Mouse presentation remains neutral: pointer buttons never grab keyboard
## focus and no choice is preselected. Keyboard/gamepad adapters explicitly call
## grab_initial_focus(), which focuses a transparent proxy and reveals a cyan
## in-bounds ring without scaling the card.

signal upgrade_selected(id: StringName)
signal reroll_requested
signal cancel_requested

const SINGLE_WIDTH := 440.0
const SINGLE_EDUCATION_WIDTH := 520.0
const DOUBLE_WIDTH := 680.0
const TRIPLE_WIDTH := 940.0
const MINIMUM_CARD_WIDTH := 240.0
const CARD_HEIGHT := 112.0
const EXTRA_VALUE_ROW_HEIGHT := 20.0
const UPGRADE_ICON_SIZE := 34.0
const MODAL_PADDING := 20
const FOCUS_LINE_WIDTH := 2.0

static var _numeric_fragment_pattern: RegEx

var _view_model: UpgradeOverlayViewModel
var _applied_revision := -1
var _applied_content_hash := ""

var _backdrop: ColorRect
var _safe_area: MarginContainer
var _center: CenterContainer
var _sheet: PanelContainer
var _sheet_stack: VBoxContainer
var _body_scroll: ScrollContainer
var _scrollbar_inset: MarginContainer
var _body_stack: VBoxContainer
var _education_panel: PanelContainer
var _education_body: Label
var _selection_helper: Label
var _cards_grid: GridContainer
var _footer_actions: HBoxContainer
var _reroll_button: Button
var _cancel_button: Button
var _neutral_focus: Control

var _cards: Array[Button] = []
var _focus_targets: Array[Control] = []


func _init() -> void:
	name = "UpgradeOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	_build()
	resized.connect(_queue_responsive_layout)


func apply_view_model(view_model: UpgradeOverlayViewModel) -> bool:
	if view_model == null or not view_model.is_valid():
		return false
	if _applied_revision >= 0 and view_model.revision() < _applied_revision:
		return false
	var content_changed := view_model.content_hash() != _applied_content_hash
	var revision_changed := view_model.revision() != _applied_revision
	if not content_changed and not revision_changed:
		return false

	_view_model = view_model
	_applied_revision = view_model.revision()
	_applied_content_hash = view_model.content_hash()
	if content_changed:
		_rebuild_cards()
		_education_body.text = view_model.education_text()
		_education_panel.visible = view_model.shows_education()
		_selection_helper.visible = view_model.option_count() == 3
		_reroll_button.visible = view_model.can_reroll()
		_cancel_button.visible = view_model.allow_cancel()
		_footer_actions.visible = view_model.can_reroll() or view_model.allow_cancel()
		_update_focus_trap()
		_queue_responsive_layout()
	# Identical visible content with a newer revision is acknowledged without
	# reconstructing cards or focus proxies.
	return content_changed


## request_focus defaults to false so pointer opening never creates a visible
## choice. Keyboard/gamepad callers opt in explicitly.
func present(view_model: UpgradeOverlayViewModel, request_focus: bool = false) -> bool:
	var changed := apply_view_model(view_model)
	show()
	if request_focus:
		grab_initial_focus.call_deferred()
	else:
		park_neutral_focus.call_deferred()
	return changed


func dismiss() -> void:
	hide()


func grab_initial_focus() -> bool:
	if not is_inside_tree() or not is_visible_in_tree() or _focus_targets.is_empty():
		return false
	var target := _focus_targets[0]
	if target == null or not target.is_visible_in_tree():
		return false
	target.grab_focus()
	_ensure_focus_visible.call_deferred(target)
	return true


## Pointer opening must park focus inside the blocking modal without visually
## selecting a choice. This prevents ui_accept/navigation from reaching the
## previously focused background screen.
func park_neutral_focus() -> bool:
	if not is_inside_tree() or not is_visible_in_tree() or _neutral_focus == null:
		return false
	_neutral_focus.grab_focus()
	return true


## Mandatory upgrade modals consume ui_cancel without leaking input. Only a VM
## that explicitly allows cancellation emits the cancel intent.
func handle_ui_cancel() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	if _view_model != null and _view_model.allow_cancel():
		cancel_requested.emit()
	return true


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> String:
	return _applied_content_hash


func modal_sheet() -> PanelContainer:
	return _sheet


func body_scroll() -> ScrollContainer:
	return _body_scroll


func cards_grid() -> GridContainer:
	return _cards_grid


func education_panel() -> PanelContainer:
	return _education_panel


func selection_helper() -> Label:
	return _selection_helper


func cards() -> Array[Button]:
	var result: Array[Button] = []
	result.assign(_cards)
	return result


func focus_targets() -> Array[Control]:
	var result: Array[Control] = []
	result.assign(_focus_targets)
	return result


func reroll_action() -> Button:
	return _reroll_button


func cancel_action() -> Button:
	return _cancel_button


func neutral_focus_target() -> Control:
	return _neutral_focus


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "ModalBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.84)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_meta(&"alveolus_component", &"modal_backdrop")
	add_child(_backdrop)

	_safe_area = MarginContainer.new()
	_safe_area.name = "SafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(_safe_area)

	_center = CenterContainer.new()
	_center.name = "UpgradeCenter"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.resized.connect(_queue_responsive_layout)
	_safe_area.add_child(_center)

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "UpgradeBodyScroll"
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.follow_focus = true
	_body_scroll.resized.connect(_queue_responsive_layout)

	_scrollbar_inset = MarginContainer.new()
	_scrollbar_inset.name = "ScrollbarSafeInset"
	_scrollbar_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.add_child(_scrollbar_inset)

	_body_stack = VBoxContainer.new()
	_body_stack.name = "UpgradeBody"
	_body_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_scrollbar_inset.add_child(_body_stack)

	var education := AlveolusUIComponents.semantic_copy_section(
		"Einführung",
		"",
		&"story",
		AlveolusVisualTheme.TURQUOISE
	)
	_education_panel = education["panel"] as PanelContainer
	_education_panel.name = "ScriptedEducation"
	_education_body = education["body"] as Label
	_education_panel.hide()
	_body_stack.add_child(_education_panel)

	_selection_helper = AlveolusUIComponents.label(
		"Du kannst 1 Upgrade auswählen.",
		AlveolusVisualTheme.TYPE_BODY_LABEL
	)
	_selection_helper.name = "SelectionHelper"
	_selection_helper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_helper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_helper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_helper.set_meta(&"alveolus_component", &"content_driven_helper")
	_selection_helper.hide()
	_body_stack.add_child(_selection_helper)

	_cards_grid = GridContainer.new()
	_cards_grid.name = "UpgradeCards"
	_cards_grid.columns = 3
	_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_cards_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTENT_GAP)
	_body_stack.add_child(_cards_grid)

	_reroll_button = AlveolusUIComponents.action_button(
		"Neu würfeln",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"restart",
		AlveolusVisualTheme.COBALT
	)
	_reroll_button.name = "Reroll"
	_reroll_button.pressed.connect(func() -> void: reroll_requested.emit())

	_cancel_button = AlveolusUIComponents.action_button(
		"Zurück",
		AlveolusUIComponents.ACTION_QUIET,
		&"back",
		AlveolusVisualTheme.MUTED
	)
	_cancel_button.name = "Cancel"
	_cancel_button.pressed.connect(func() -> void: cancel_requested.emit())

	var footer_buttons: Array[Control] = [_reroll_button, _cancel_button]
	var sheet_parts := AlveolusUIComponents.modal_sheet(
		"Level Up!",
		_body_scroll,
		footer_buttons,
		MODAL_PADDING,
		AlveolusVisualTheme.TURQUOISE
	)
	_sheet = sheet_parts["panel"] as PanelContainer
	_sheet_stack = sheet_parts["content"] as VBoxContainer
	_sheet.name = "UpgradeSheet"
	var level_up_title := _sheet_stack.get_child(0) as Label
	if level_up_title != null:
		level_up_title.name = "LevelUpTitle"
		level_up_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level_up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_actions = sheet_parts["actions"] as HBoxContainer
	_footer_actions.hide()
	_neutral_focus = Control.new()
	_neutral_focus.name = "ModalFocusSentinel"
	_neutral_focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_neutral_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_neutral_focus.focus_mode = Control.FOCUS_ALL
	_neutral_focus.set_meta(&"alveolus_component", &"modal_focus_sentinel")
	_neutral_focus.gui_input.connect(_on_neutral_focus_input)
	_sheet.add_child(_neutral_focus)
	_center.add_child(_sheet)


func _rebuild_cards() -> void:
	for child in _cards_grid.get_children():
		_cards_grid.remove_child(child)
		child.queue_free()
	_cards.clear()
	_focus_targets.clear()
	if _view_model == null:
		return
	for option in _view_model.options():
		var card := _build_card(option)
		_cards_grid.add_child(card)
		_cards.append(card)
	_update_focus_trap()


func _build_card(option: UpgradeOverlayViewModel.UpgradeOptionViewModel) -> Button:
	var card := AlveolusUIComponents.choice_card("", "")
	card.name = "Upgrade_%s" % String(option.id())
	# One display-ready value row fits the compact base card. Every additional
	# row grows the card uniformly instead of being clipped below the inset.
	var extra_value_rows := maxi(0, option.value_rows().size() - 1)
	card.custom_minimum_size = Vector2(0.0, CARD_HEIGHT + extra_value_rows * EXTRA_VALUE_ROW_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.scale = Vector2.ONE
	card.clip_contents = true
	card.set_meta(&"upgrade_id", option.id())
	card.set_meta(&"disable_motion_scale", true)
	card.pressed.connect(func() -> void: upgrade_selected.emit(option.id()))

	var content := VBoxContainer.new()
	content.name = "CardCopy"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var inset := AlveolusUIComponents.margin(content, 10)
	inset.name = "CardInset"
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inset)

	var heading := HBoxContainer.new()
	heading.name = "Heading"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	content.add_child(heading)
	var icon := SimpleIcon.new()
	icon.name = "UpgradeIcon"
	icon.custom_minimum_size = Vector2(UPGRADE_ICON_SIZE, UPGRADE_ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(option.icon_id(), _accent_color(option.accent_role()))
	icon.set_meta(&"upgrade_icon_id", option.icon_id())
	heading.add_child(icon)
	var title := AlveolusUIComponents.label(option.title(), AlveolusVisualTheme.TYPE_BODY_LABEL)
	title.name = "UpgradeTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(title)

	var effect := _build_effect_copy(option.effect())
	content.add_child(effect)

	if option.has_value_rows():
		for value_row in option.value_rows():
			content.add_child(_build_value_copy(value_row))
	elif not option.comparison_text().is_empty():
		var comparison := _build_comparison_copy(option.before_value(), option.after_value())
		content.add_child(comparison)

	var focus_ring := _build_focus_ring()
	card.add_child(focus_ring)
	var focus_target := Control.new()
	focus_target.name = "KeyboardFocus"
	focus_target.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_target.focus_mode = Control.FOCUS_ALL
	focus_target.set_meta(&"upgrade_id", option.id())
	focus_target.set_meta(&"alveolus_accessible_name", _card_accessible_name(option))
	focus_target.focus_entered.connect(_on_card_focus_entered.bind(focus_target, focus_ring))
	focus_target.focus_exited.connect(func() -> void: focus_ring.hide())
	focus_target.gui_input.connect(_on_focus_target_input.bind(focus_target, option.id()))
	card.add_child(focus_target)
	_focus_targets.append(focus_target)
	return card


func _card_accessible_name(option: UpgradeOverlayViewModel.UpgradeOptionViewModel) -> String:
	var parts := PackedStringArray([option.title(), option.effect()])
	for row in option.value_rows():
		var row_prefix := "%s " % row.label() if not row.label().is_empty() else ""
		if row.before_value().is_empty():
			parts.append("%s%s" % [row_prefix, row.value()])
		else:
			parts.append("%s%s zu %s" % [row_prefix, row.before_value(), row.value()])
	return ". ".join(parts)


## Value rows arrive fully formatted from the presenter. The overlay only lays
## out label, optional previous value and result value; it never derives units
## or branches on a content ID.
func _build_value_copy(row: UpgradeOverlayViewModel.ValueRowViewModel) -> RichTextLabel:
	var copy := _rich_copy(
		"UpgradeValue_%s" % String(row.id()),
		AlveolusVisualTheme.heading_font(),
		AlveolusVisualTheme.TEXT_BODY
	)
	if not row.label().is_empty():
		_append_colored_text(copy, "%s  " % row.label(), AlveolusVisualTheme.IVORY_DEEP)
	if not row.before_value().is_empty():
		_append_colored_text(copy, row.before_value(), AlveolusVisualTheme.IVORY_DEEP)
		_append_colored_text(copy, "  →  ", AlveolusVisualTheme.MUTED)
	_append_colored_text(copy, row.value(), _accent_color(row.accent_role()))
	copy.set_meta(&"value_row_id", row.id())
	copy.set_meta(&"semantic_label", row.label())
	copy.set_meta(&"semantic_before", row.before_value())
	copy.set_meta(&"semantic_value", row.value())
	copy.set_meta(&"semantic_value_role", row.accent_role())
	return copy


## Highlights one meaningful delta in the upper effect copy by content, never
## by upgrade ID. New upgrades therefore inherit the same visual hierarchy.
func _build_effect_copy(effect_text: String) -> RichTextLabel:
	var copy := _rich_copy("UpgradeEffect", AlveolusVisualTheme.body_font(), AlveolusVisualTheme.TEXT_CAPTION)
	var highlights := PackedStringArray()
	var highlight := _delta_match(effect_text)
	if highlight == null:
		_append_colored_text(copy, effect_text, AlveolusVisualTheme.IVORY_DEEP)
	else:
		var start := highlight.get_start()
		var finish := highlight.get_end()
		_append_colored_text(copy, effect_text.substr(0, start), AlveolusVisualTheme.IVORY_DEEP)
		_append_colored_text(copy, highlight.get_string(), AlveolusVisualTheme.GOLD)
		_append_colored_text(copy, effect_text.substr(finish), AlveolusVisualTheme.IVORY_DEEP)
		highlights.append(highlight.get_string())
	copy.set_meta(&"semantic_highlights", highlights)
	copy.set_meta(&"semantic_highlight_role", &"positive_delta")
	return copy


## Comparisons consistently keep the current value in the normal body colour,
## reduce the arrow to a quiet separator and emphasize only the resulting
## value as one meaningful unit (for example "4 Projektile").
func _build_comparison_copy(before_value: String, after_value: String) -> RichTextLabel:
	var copy := _rich_copy("UpgradeComparison", AlveolusVisualTheme.heading_font(), AlveolusVisualTheme.TEXT_BODY)
	if not before_value.is_empty() and not after_value.is_empty():
		_append_colored_text(copy, before_value, AlveolusVisualTheme.IVORY_DEEP)
		_append_colored_text(copy, "  →  ", AlveolusVisualTheme.MUTED)
		_append_colored_text(copy, after_value, AlveolusVisualTheme.GOLD)
	elif not after_value.is_empty():
		_append_colored_text(copy, after_value, AlveolusVisualTheme.GOLD)
	else:
		_append_colored_text(copy, before_value, AlveolusVisualTheme.IVORY_DEEP)
	copy.set_meta(&"semantic_before", before_value)
	copy.set_meta(&"semantic_after", after_value)
	copy.set_meta(&"semantic_before_role", &"body")
	copy.set_meta(&"semantic_arrow_role", &"muted_separator")
	copy.set_meta(&"semantic_highlight_role", &"result_value")
	copy.set_meta(&"semantic_before_color", AlveolusVisualTheme.IVORY_DEEP)
	copy.set_meta(&"semantic_arrow_color", AlveolusVisualTheme.MUTED)
	copy.set_meta(&"semantic_after_color", AlveolusVisualTheme.GOLD)
	return copy


func _rich_copy(copy_name: String, font: Font, font_size: int) -> RichTextLabel:
	var copy := RichTextLabel.new()
	copy.name = copy_name
	copy.bbcode_enabled = false
	copy.fit_content = true
	copy.scroll_active = false
	copy.selection_enabled = false
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.custom_minimum_size.y = 20.0
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_override("normal_font", font)
	copy.add_theme_font_size_override("normal_font_size", font_size)
	return copy


func _append_colored_text(copy: RichTextLabel, text_value: String, color: Color) -> void:
	if text_value.is_empty():
		return
	copy.push_color(color)
	copy.add_text(text_value)
	copy.pop()


func _numeric_pattern() -> RegEx:
	if _numeric_fragment_pattern == null:
		_numeric_fragment_pattern = RegEx.new()
		_numeric_fragment_pattern.compile("[+\\-−]?\\d+(?:[.,]\\d+)?(?:\\s*%)?")
	return _numeric_fragment_pattern


## The short upper copy gets one highlighted change value. Prefer an explicit
## signed delta and otherwise fall back to the first numeric fact. This keeps
## future upgrade content consistent without coupling presentation to IDs.
func _delta_match(effect_text: String) -> RegExMatch:
	var matches := _numeric_pattern().search_all(effect_text)
	if matches.is_empty():
		return null
	for candidate_value in matches:
		var candidate := candidate_value as RegExMatch
		var fragment := candidate.get_string()
		if fragment.begins_with("+") or fragment.begins_with("-") or fragment.begins_with("−"):
			return candidate
	return matches[0] as RegExMatch


func _build_focus_ring() -> Control:
	var ring := Control.new()
	ring.name = "CyanFocusRing"
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_meta(&"focus_color", AlveolusVisualTheme.TURQUOISE)
	_add_focus_edge(ring, SIDE_TOP)
	_add_focus_edge(ring, SIDE_RIGHT)
	_add_focus_edge(ring, SIDE_BOTTOM)
	_add_focus_edge(ring, SIDE_LEFT)
	ring.hide()
	return ring


func _add_focus_edge(ring: Control, side: int) -> void:
	var edge := ColorRect.new()
	edge.name = "FocusEdge%d" % side
	edge.color = AlveolusVisualTheme.TURQUOISE
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match side:
		SIDE_TOP:
			edge.set_anchor(SIDE_RIGHT, 1.0)
			edge.offset_bottom = FOCUS_LINE_WIDTH
		SIDE_RIGHT:
			edge.set_anchor(SIDE_LEFT, 1.0)
			edge.set_anchor(SIDE_TOP, 0.0)
			edge.set_anchor(SIDE_RIGHT, 1.0)
			edge.set_anchor(SIDE_BOTTOM, 1.0)
			edge.offset_left = -FOCUS_LINE_WIDTH
		SIDE_BOTTOM:
			edge.set_anchor(SIDE_LEFT, 0.0)
			edge.set_anchor(SIDE_TOP, 1.0)
			edge.set_anchor(SIDE_RIGHT, 1.0)
			edge.set_anchor(SIDE_BOTTOM, 1.0)
			edge.offset_top = -FOCUS_LINE_WIDTH
		SIDE_LEFT:
			edge.set_anchor(SIDE_BOTTOM, 1.0)
			edge.offset_right = FOCUS_LINE_WIDTH
	ring.add_child(edge)


func _on_card_focus_entered(target: Control, ring: Control) -> void:
	ring.show()
	_ensure_focus_visible(target)


func _on_focus_target_input(event: InputEvent, target: Control, option_id: StringName) -> void:
	if event.is_action_pressed("ui_accept"):
		upgrade_selected.emit(option_id)
		target.accept_event()


func _on_neutral_focus_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_neutral_focus.accept_event()


func _update_focus_trap() -> void:
	var visible_actions: Array[Control] = []
	for target in _focus_targets:
		if target != null and target.visible:
			visible_actions.append(target)
	if _reroll_button != null and _reroll_button.visible:
		visible_actions.append(_reroll_button)
	if _cancel_button != null and _cancel_button.visible:
		visible_actions.append(_cancel_button)
	for index in range(visible_actions.size()):
		var action := visible_actions[index]
		var previous := visible_actions[posmod(index - 1, visible_actions.size())]
		var following := visible_actions[(index + 1) % visible_actions.size()]
		action.focus_previous = action.get_path_to(previous)
		action.focus_next = action.get_path_to(following)
		action.focus_neighbor_left = action.get_path_to(previous)
		action.focus_neighbor_top = action.get_path_to(previous)
		action.focus_neighbor_right = action.get_path_to(following)
		action.focus_neighbor_bottom = action.get_path_to(following)
	if _neutral_focus != null and not visible_actions.is_empty():
		var first := visible_actions[0]
		var last := visible_actions[visible_actions.size() - 1]
		_neutral_focus.focus_next = _neutral_focus.get_path_to(first)
		_neutral_focus.focus_previous = _neutral_focus.get_path_to(last)
		_neutral_focus.focus_neighbor_left = _neutral_focus.get_path_to(last)
		_neutral_focus.focus_neighbor_top = _neutral_focus.get_path_to(last)
		_neutral_focus.focus_neighbor_right = _neutral_focus.get_path_to(first)
		_neutral_focus.focus_neighbor_bottom = _neutral_focus.get_path_to(first)


func _ensure_focus_visible(control: Control) -> void:
	if _body_scroll != null and control != null and _body_scroll.is_ancestor_of(control):
		_body_scroll.ensure_control_visible(control)


func _queue_responsive_layout() -> void:
	_update_responsive_layout.call_deferred()


func _update_responsive_layout() -> void:
	if _view_model == null or _center == null or _sheet == null:
		return
	var compact := size.x < 640.0 or size.y < 400.0
	var outer_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_safe_area.add_theme_constant_override(side, outer_margin)
	var available := Vector2(
		maxf(0.0, size.x - outer_margin * 2.0),
		maxf(0.0, size.y - outer_margin * 2.0)
	)
	if available.x <= 0.0 or available.y <= 0.0:
		return

	var desired_width := _desired_width()
	var sheet_width := minf(desired_width, available.x)
	_sheet.custom_minimum_size.x = floorf(sheet_width)
	var usable_width := maxf(0.0, sheet_width - float(MODAL_PADDING * 2))
	var column_capacity := maxi(1, floori(
		(usable_width + float(AlveolusVisualTheme.CONTENT_GAP))
		/ (MINIMUM_CARD_WIDTH + float(AlveolusVisualTheme.CONTENT_GAP))
	))
	_cards_grid.columns = maxi(1, mini(_view_model.option_count(), column_capacity))

	_body_scroll.custom_minimum_size.y = 0.0
	var body_height := _body_stack.get_combined_minimum_size().y
	var title_height := 0.0
	if _sheet_stack != null and _sheet_stack.get_child_count() > 0:
		var title_control := _sheet_stack.get_child(0) as Control
		title_height = title_control.get_combined_minimum_size().y if title_control != null else 0.0
	var footer_height := _footer_actions.get_combined_minimum_size().y if _footer_actions.visible else 0.0
	var gap_count := 1 + (1 if _footer_actions.visible else 0)
	var chrome_height := (
		float(MODAL_PADDING * 2)
		+ title_height
		+ footer_height
		+ float(AlveolusVisualTheme.CONTENT_GAP * gap_count)
	)
	var maximum_body_height := maxf(0.0, available.y - chrome_height)
	var visible_body_height := minf(body_height, maximum_body_height)
	_body_scroll.custom_minimum_size.y = ceilf(visible_body_height)
	var requires_scroll := body_height > visible_body_height + 1.0
	_body_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if requires_scroll
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	var scrollbar_inset := ceili(_body_scroll.get_v_scroll_bar().get_combined_minimum_size().x) if requires_scroll else 0
	_scrollbar_inset.add_theme_constant_override("margin_right", scrollbar_inset)
	if not requires_scroll:
		_body_scroll.scroll_vertical = 0


func _desired_width() -> float:
	match _view_model.option_count():
		1:
			return SINGLE_EDUCATION_WIDTH if _view_model.shows_education() else SINGLE_WIDTH
		2:
			return DOUBLE_WIDTH
	return TRIPLE_WIDTH


func _accent_color(role: StringName) -> Color:
	match role:
		&"teal":
			return AlveolusVisualTheme.TEAL
		&"cobalt":
			return AlveolusVisualTheme.COBALT
		&"coral":
			return AlveolusVisualTheme.CORAL
		&"gold":
			return AlveolusVisualTheme.GOLD
	return AlveolusVisualTheme.TURQUOISE
