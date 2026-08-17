class_name PracticeScreen
extends Control

## Bio-Lumen Practice screen.
##
## The screen consumes immutable PracticeScreenViewModel values and emits only
## user intent. GameHUD can therefore retain its current public facade while a
## presenter converts runtime data outside this module.

signal offline_claim_requested
signal clinic_job_start_requested(id: StringName)
signal clinic_job_claim_requested
signal back_requested

const PracticeScreenViewModelType := preload("res://scripts/ui/view_models/practice_screen_view_model.gd")
const ROUTE_ID := &"practice"
const WIDE_LAYOUT_MINIMUM := 920.0

var _page_shell: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _columns: GridContainer
var _research_badge: PanelContainer
var _research_balance: Label

var _back_button: Button
var _offline_card: PanelContainer
var _offline_stored_value: Label
var _offline_capacity_value: Label
var _offline_claim_button: Button

var _clinic_card: PanelContainer
var _clinic_status: Label
var _clinic_progress: ProgressBar
var _clinic_active_details: VBoxContainer
var _clinic_remaining_row: PanelContainer
var _clinic_remaining_value: Label
var _clinic_reward_value: Label
var _clinic_finish_value: Label
var _clinic_offers: VBoxContainer
var _clinic_claim_button: Button
var _job_buttons: Dictionary = {}

var _has_applied_model := false
var _applied_revision := -1
var _applied_content_hash := 0
var _applied_job_offers_hash := 0


func _init() -> void:
	name = "PracticeScreen"
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


## Returns true only when visible content changed. A newer revision with the
## same content hash is acknowledged without rebuilding controls.
func apply_view_model(view_model: PracticeScreenViewModelType) -> bool:
	if view_model == null:
		return false
	var next_revision := view_model.revision()
	if _has_applied_model and next_revision <= _applied_revision:
		return false
	if _has_applied_model and view_model.content_hash() == _applied_content_hash:
		_applied_revision = next_revision
		return false

	_research_balance.text = view_model.research_balance_text()
	var offline := view_model.offline()
	_offline_stored_value.text = offline.stored_text()
	_offline_capacity_value.text = offline.capacity_text()
	_set_button_caption(_offline_claim_button, offline.claim_button_text())
	_offline_claim_button.set_meta(&"claimable_amount", offline.claimable_amount())
	AlveolusUIComponents.set_button_disabled(_offline_claim_button, not offline.claim_enabled())

	var clinic := view_model.clinic()
	var has_active_job := clinic.has_active_job()
	var completed := clinic.completed()
	_clinic_status.text = clinic.status_text()
	_clinic_progress.visible = has_active_job and not completed
	_clinic_progress.max_value = clinic.progress_maximum()
	_clinic_progress.value = clinic.progress_value()
	_clinic_active_details.visible = has_active_job
	_clinic_remaining_row.visible = has_active_job and not completed
	_clinic_remaining_value.text = clinic.remaining_text()
	_clinic_reward_value.text = clinic.reward_text()
	_clinic_finish_value.text = clinic.finish_text()
	_clinic_offers.visible = not has_active_job
	_clinic_claim_button.visible = completed
	if not _has_applied_model or view_model.job_offers_hash() != _applied_job_offers_hash:
		_rebuild_job_offers(view_model.job_offers())

	_has_applied_model = true
	_applied_revision = next_revision
	_applied_content_hash = view_model.content_hash()
	_applied_job_offers_hash = view_model.job_offers_hash()
	return true


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> int:
	return _applied_content_hash


func layout_columns() -> int:
	return _columns.columns


func default_focus_control() -> Control:
	if _offline_claim_button.visible and not _offline_claim_button.disabled:
		return _offline_claim_button
	if _clinic_claim_button.visible and not _clinic_claim_button.disabled:
		return _clinic_claim_button
	for child in _clinic_offers.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Button
	return _back_button


func back_action() -> Button:
	return _back_button


func offline_claim_action() -> Button:
	return _offline_claim_button


func clinic_claim_action() -> Button:
	return _clinic_claim_button


func clinic_job_action(id: StringName) -> Button:
	return _job_buttons.get(id) as Button


func clinic_progress_control() -> ProgressBar:
	return _clinic_progress


func clinic_offers_visible() -> bool:
	return _clinic_offers.visible


func _build() -> void:
	_back_button = AlveolusUIComponents.action_button(
		"Zum Campus",
		AlveolusUIComponents.ACTION_NAVIGATION,
		&"back",
		AlveolusVisualTheme.TEAL
	)
	_back_button.name = "BackAction"
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	var header_parts := AlveolusUIComponents.page_header("Praxis", "", _back_button)

	_scroll = ScrollContainer.new()
	_scroll.name = "PracticeScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_body = VBoxContainer.new()
	_body.name = "PracticeContent"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_scroll.add_child(_body)
	_build_columns()

	var shell_parts := AlveolusUIComponents.page_shell(
		header_parts["panel"] as Control,
		_scroll,
		false
	)
	_page_shell = shell_parts["shell"] as PanelContainer
	_page_shell.name = "PracticePageShell"
	add_child(_page_shell)


func _build_columns() -> void:
	_columns = GridContainer.new()
	_columns.name = "PracticeColumns"
	_columns.columns = 2
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_columns.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_columns.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTENT_GAP)
	_body.add_child(_columns)
	_build_offline_card()
	_build_clinic_card()


func _build_offline_card() -> void:
	_offline_card = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
	_offline_card.name = "OfflineResearchCard"
	_offline_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offline_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_columns.add_child(_offline_card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	var heading_row := HBoxContainer.new()
	heading_row.name = "OfflineResearchHeading"
	heading_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	var heading := AlveolusUIComponents.section_header(
		"",
		"Automatische Forschung",
		"Gespeicherte Forschung kann jederzeit abgeholt werden."
	)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	_research_badge = AlveolusUIComponents.badge("Forschung 0", AlveolusVisualTheme.GOLD)
	_research_badge.name = "ResearchBalance"
	_research_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	_research_badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	heading_row.add_child(_research_badge)
	_research_balance = _last_label(_research_badge)
	content.add_child(heading_row)
	var stored_row := AlveolusUIComponents.value_row("Gespeichert", "–", true)
	content.add_child(stored_row)
	_offline_stored_value = _last_label(stored_row)
	var capacity_row := AlveolusUIComponents.value_row("Kapazität", "8 Stunden")
	content.add_child(capacity_row)
	_offline_capacity_value = _last_label(capacity_row)
	_offline_claim_button = AlveolusUIComponents.action_button(
		"Noch nichts abholbar",
		AlveolusUIComponents.ACTION_PRIMARY,
		&"research",
		AlveolusVisualTheme.TEAL
	)
	_offline_claim_button.name = "OfflineClaimAction"
	_offline_claim_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offline_claim_button.pressed.connect(func() -> void: offline_claim_requested.emit())
	content.add_child(_offline_claim_button)
	_offline_card.add_child(AlveolusUIComponents.margin(content, AlveolusVisualTheme.CARD_PADDING))


func _build_clinic_card() -> void:
	_clinic_card = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
	_clinic_card.name = "ClinicCard"
	_clinic_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clinic_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_columns.add_child(_clinic_card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	content.add_child(AlveolusUIComponents.section_header(
		"",
		"Klinikfall",
		"Ein aktiver Slot"
	))
	_clinic_status = AlveolusUIComponents.label(
		"Wähle einen zeitgesteuerten Fall.",
		AlveolusVisualTheme.TYPE_BODY_LABEL
	)
	_clinic_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_clinic_status)
	_clinic_progress = AlveolusUIComponents.progress(0.0, 1.0, false)
	_clinic_progress.name = "ClinicProgress"
	_clinic_progress.visible = false
	content.add_child(_clinic_progress)

	_clinic_active_details = VBoxContainer.new()
	_clinic_active_details.name = "ClinicActiveDetails"
	_clinic_active_details.visible = false
	_clinic_active_details.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	content.add_child(_clinic_active_details)
	_clinic_remaining_row = AlveolusUIComponents.value_row("Verbleibend", "")
	_clinic_active_details.add_child(_clinic_remaining_row)
	_clinic_remaining_value = _last_label(_clinic_remaining_row)
	var reward_row := AlveolusUIComponents.value_row("Belohnung", "", true)
	_clinic_active_details.add_child(reward_row)
	_clinic_reward_value = _last_label(reward_row)
	var finish_row := AlveolusUIComponents.value_row("Abschluss", "")
	_clinic_active_details.add_child(finish_row)
	_clinic_finish_value = _last_label(finish_row)

	_clinic_offers = VBoxContainer.new()
	_clinic_offers.name = "ClinicOffers"
	_clinic_offers.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	content.add_child(_clinic_offers)
	_clinic_claim_button = AlveolusUIComponents.action_button(
		"Belohnung abholen",
		AlveolusUIComponents.ACTION_PRIMARY,
		&"check",
		AlveolusVisualTheme.TEAL
	)
	_clinic_claim_button.name = "ClinicClaimAction"
	_clinic_claim_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clinic_claim_button.visible = false
	_clinic_claim_button.pressed.connect(func() -> void: clinic_job_claim_requested.emit())
	content.add_child(_clinic_claim_button)
	_clinic_card.add_child(AlveolusUIComponents.margin(content, AlveolusVisualTheme.CARD_PADDING))


func _rebuild_job_offers(offers: Array) -> void:
	for child in _clinic_offers.get_children():
		_clinic_offers.remove_child(child)
		child.free()
	_job_buttons.clear()
	for offer in offers:
		var button := AlveolusUIComponents.choice_row(
			offer.title(),
			offer.duration_text(),
			offer.reward_text(),
			false,
			not offer.enabled()
		)
		button.name = "ClinicOffer_%s" % String(offer.id())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta(&"clinic_job_id", offer.id())
		button.pressed.connect(_emit_clinic_job_start.bind(offer.id()))
		AlveolusUIComponents.set_button_disabled(button, not offer.enabled())
		_clinic_offers.add_child(button)
		_job_buttons[offer.id()] = button


func _emit_clinic_job_start(id: StringName) -> void:
	clinic_job_start_requested.emit(id)


func _update_responsive_layout() -> void:
	if _columns == null:
		return
	var logical_width := size.x
	if logical_width <= 0.0 and get_viewport() != null:
		logical_width = get_viewport_rect().size.x
	_columns.columns = 2 if logical_width >= WIDE_LAYOUT_MINIMUM else 1


func _set_button_caption(button: Button, value: String) -> void:
	if button is IconTextButton:
		(button as IconTextButton).set_caption(value)
	else:
		button.text = value
	button.set_meta(&"alveolus_accessible_name", value)


func _last_label(root: Node) -> Label:
	var result: Label = root as Label
	for child in root.get_children():
		var nested := _last_label(child)
		if nested != null:
			result = nested
	return result
