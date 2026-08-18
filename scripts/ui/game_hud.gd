class_name GameHUD
extends CanvasLayer

const IconTextButtonComponent = preload("res://scripts/ui/icon_text_button.gd")

signal navigate_requested(destination: StringName)
signal back_requested
signal quit_requested
signal story_finished
signal level_selected(id: StringName)
signal upgrade_chosen(definition: UpgradeDefinition)
signal reroll_requested
signal resume_requested
signal abort_requested
signal abort_confirmed
signal abort_cancelled
signal retry_requested
signal result_levels_requested
signal result_campus_requested
signal offline_claim_requested
signal clinic_job_start_requested(id: StringName)
signal clinic_job_claim_requested
signal research_purchase_requested(id: StringName)
signal research_reset_requested
signal discovery_dismissed
signal intro_skip_requested
signal intro_skip_confirmed
signal intro_skip_cancelled
signal restart_confirmed
signal restart_cancelled
signal run_stats_visibility_changed(enabled: bool)
signal ui_settings_changed(settings: UISettingsState)
signal settings_reset_bindings_requested
signal preparation_start_requested(loadout_snapshot: Dictionary)
signal preparation_component_requested(id: StringName)
signal preparation_slot_component_requested(slot_id: StringName, id: StringName)
signal preparation_slot_clear_requested(slot_index: int)
signal preparation_slot_requested(slot_id: StringName)
signal preparation_reserve_requested(id: StringName)
signal preparation_replacement_cancelled
signal ability_slot_requested(slot: int)
signal pause_requested
signal research_tab_changed(tab: StringName)
signal talent_toggle_requested(id: StringName)
signal talent_reset_requested
signal finding_reaction_selected(id: StringName)
signal finding_reserve_swap_requested(incoming_id: StringName, outgoing_id: StringName)
signal finding_confirmed(reaction_id: StringName, incoming_id: StringName, outgoing_id: StringName)
signal context_detail_opened(source: Control, explicit: bool)
signal context_detail_closed

const COLOR_BG := AlveolusVisualTheme.PETROL
const COLOR_PANEL := Color("163f47")
const COLOR_TEXT := AlveolusVisualTheme.IVORY
const COLOR_MUTED := Color("abc1c4")
const COLOR_TEAL := AlveolusVisualTheme.TEAL
const COLOR_BLUE := AlveolusVisualTheme.COBALT
const COLOR_RED := AlveolusVisualTheme.CORAL
const COLOR_GOLD := AlveolusVisualTheme.GOLD
const PAUSE_PANEL_SIZE := Vector2(420.0, 244.0)
const PAUSE_INTRO_PANEL_SIZE := Vector2(420.0, 244.0)
const PAUSE_STATS_PANEL_SIZE := Vector2(720.0, 420.0)
const END_PANEL_SIZE := Vector2(660.0, 300.0)
const END_FAILURE_PANEL_SIZE := Vector2(660.0, 258.0)
const END_MASTERY_PANEL_SIZE := Vector2(660.0, 370.0)
const PREPARATION_PANEL_HEIGHT := 412.0
const ABORT_PANEL_SIZE := Vector2(470.0, 182.0)
const INTRO_SKIP_PANEL_SIZE := Vector2(470.0, 194.0)

var root: Control
var page_shells: Array[Dictionary] = []
var gameplay_hud: Control
var run_hud_screen: RunHUDOverlay
var run_hud_view_revision: int = 0
var run_hud_vitals: Dictionary = {
	"stability_current": 100.0,
	"stability_maximum": 100.0,
	"shield_current": 0.0,
	"shield_maximum": 0.0,
	"round_time_text": "00:00",
	"timer_text": "BOSS IN · 00:00",
	"timer_tone": &"neutral",
	"boss_visible": false,
	"boss_title": "Infektionsherd",
	"boss_current": 0.0,
	"boss_maximum": 1.0,
	"boss_phase": "",
	"analysis_current": 0,
	"analysis_target": 0,
	"analysis_level": 0,
	"defeat_research_reward": {
		"visible": false,
		"icon_id": &"research",
		"value": "",
		"accessible_name": "",
	},
}
var run_hud_stat_rows: Array = []
var run_hud_ability_rows: Array = [
	{
		"slot": 0,
		"title": "Nicht belegt",
		"icon_id": &"ability",
		"effect_text": "",
		"occupied": false,
		"ready": false,
		"cooldown_remaining": 0.0,
		"cooldown_total": 0.0,
		"targeting": false,
		"key_glyph_text": "Q",
	},
	{
		"slot": 1,
		"title": "Nicht belegt",
		"icon_id": &"ability",
		"effect_text": "",
		"occupied": false,
		"ready": false,
		"cooldown_remaining": 0.0,
		"cooldown_total": 0.0,
		"targeting": false,
		"key_glyph_text": "E",
	},
]
var stability_panel: Panel
var stability_bar: ProgressBar
var stability_value: Label
var shield_panel: Panel
var shield_bar: ProgressBar
var shield_value: Label
var analysis_bar: ProgressBar
var analysis_sample_panel: Panel
var level_label: Label
var timer_label: Label
var timer_panel: Panel
var alert_panel: Panel
var alert_label: Label
var boss_panel: Panel
var boss_bar: ProgressBar
var boss_value: Label
var boss_phase_label: Label
var boss_announcement_panel: Panel
var boss_announcement: Label
var alert_time: float = 0.0
var boss_announcement_time: float = 0.0
var boss_hud_active: bool = false
var run_stats_panel: Control
var run_stats_label: Label
var run_stats_strip: HFlowContainer
var ability_panel: GridContainer
var ability_cards: Array[Panel] = []
var ability_hit_buttons: Array[Button] = []
var ability_title_labels: Array[Label] = []
var ability_key_containers: Array[Control] = []
var ability_key_labels: Array[Label] = []
var ability_key_icons: Array[TextureRect] = []
var ability_cooldown_labels: Array[Label] = []
var ability_cooldown_bars: Array[ProgressBar] = []
var finding_progress_panel: Control
var finding_progress_bar: ProgressBar
var finding_progress_label: Label
var run_stats_enabled: bool = false
var current_player_stats: PlayerStats
var current_run_state: RunState

var campus_overlay: Control
var campus_buttons: Dictionary = {}
var campus_research_status: Label
var campus_clinic_status: Label
var practice_overlay: Control
var practice_screen: PracticeScreen
var practice_view_revision: int = 0
var practice_research_value: Label
var practice_columns: GridContainer
var passive_info: Label
var passive_claim_button: Button
var clinic_status: Label
var clinic_progress: ProgressBar
var clinic_remaining: Label
var clinic_finish: Label
var clinic_reward: Label
var clinic_offers: Control
var clinic_claim_button: Button
var clinic_offer_buttons: Dictionary = {}
var research_overlay: Control
var progression_screen: ProgressionScreen
var progression_view_revision: int = 0
var progression_research_items: Array = []
var progression_talent_branches: Array = []
var progression_research_balance: String = "Forschung 0"
var progression_talent_balance: String = "0 Talentpunkte"
var progression_talent_reset_enabled: bool = false
var progression_context_sources: Array[Control] = []
var research_points_label: Label
var research_rank_labels: Dictionary = {}
var research_buy_buttons: Dictionary = {}
var research_cost_labels: Dictionary = {}
var research_icons: Dictionary = {}
var research_title_labels: Dictionary = {}
var research_grid: GridContainer
var research_inspector_icon: SimpleIcon
var research_inspector_title: Label
var research_inspector_description: Label
var research_inspector_meta: Label
var research_tab_button: Button
var talent_tab_button: Button
var research_tab_row: GridContainer
var talent_summary_grid: GridContainer
var research_content: Control
var talent_content: Control
var research_inspector_panel: Panel
var talent_inspector_panel: Panel
var research_scroll: ScrollContainer
var talent_scroll: ScrollContainer
var talent_grid: GridContainer
var talent_points_label: Label
var talent_reset_button: Button
var talent_buttons: Dictionary = {}
var talent_tree_branches: Array[TalentTreeBranch] = []
var talent_inspector_icon: SimpleIcon
var talent_inspector_title: Label
var talent_inspector_description: Label
var talent_inspector_meta: Label
var current_research_tab: StringName = &"research"
var level_overlay: Control
var level_screen: CaseArchiveScreen
var level_view_revision: int = 0
var level_buttons: Dictionary = {}
var level_card_labels: Dictionary = {}
var lexicon_overlay: Control
var lexicon_master_detail: LexiconMasterDetail
var lexicon_buttons: Dictionary = {}
var lexicon_labels: Dictionary = {}
var lexicon_illustrations: Dictionary = {}
var lexicon_detail: Label
var story_overlay: Control
var story_screen: StoryScreen
var story_view_model: StoryScreenViewModel
var story_kicker: Label
var story_title: Label
var story_body: Label
var story_skip_button: Button
var story_next_button: Button
var story_panel: PanelContainer
var story_index: int = 0
var settings_overlay: Control
var settings_screen: SettingsScreen
var settings_view_revision: int = 0
var settings_show_quit: bool = true
var settings_status_text: String = "Änderungen werden sofort übernommen."
var settings_quit_button: Button
var settings_run_stats_toggle: CheckButton
var settings_master_slider: HSlider
var settings_ui_slider: HSlider
var settings_effects_slider: HSlider
var settings_music_slider: HSlider
var settings_master_mute: CheckButton
var settings_ui_mute: CheckButton
var settings_effects_mute: CheckButton
var settings_music_mute: CheckButton
var settings_scale_option: OptionButton
var settings_reduce_motion_toggle: CheckButton
var settings_restart_confirmation_toggle: CheckButton
var settings_glyph_option: OptionButton
var settings_fullscreen_toggle: CheckButton
var settings_status_label: Label
var settings_binding_buttons: Dictionary = {}
var settings_initial_focus: Control
var settings_scroll: ScrollContainer
var settings_upper_grid: GridContainer
var settings_bindings_grid: GridContainer
var pending_binding_action: StringName = &""
var pending_binding_slot: int = -1
var pending_binding_event: InputEventKey
var pending_binding_conflicting_action: StringName = &""
var current_ui_settings: UISettingsState = UISettingsState.new()
var input_glyph_service: InputGlyphService
var reduced_motion_enabled: bool = false
var preparation_overlay: Control
var preparation_page_body: VBoxContainer
var preparation_scroll: ScrollContainer
var preparation_header_back_button: Button
var preparation_trait_title: Label
var preparation_trait_effect: Label
var preparation_trait_panel: Panel
var preparation_case_row: GridContainer
var preparation_trait_row: HBoxContainer
var preparation_level_title: Label
var preparation_level_facts: Control
var preparation_boss_fact: Control
var preparation_level_description: Label
var preparation_case_facts: HFlowContainer
var preparation_workspace: GridContainer
var preparation_workspace_host: Control
var preparation_lock_panel: Panel
var preparation_lock_icon: SimpleIcon
var preparation_lock_stack: VBoxContainer
var preparation_lock_title: Label
var preparation_lock_copy: Label
var preparation_plan_panel: Panel
var preparation_catalog_panel: Panel
var preparation_slots: GridContainer
var preparation_slot_buttons: Dictionary = {}
var preparation_slot_icons: Dictionary = {}
var preparation_slot_titles: Dictionary = {}
var preparation_slot_descriptions: Dictionary = {}
var preparation_slot_costs: Dictionary = {}
var preparation_slot_status_dots: Dictionary = {}
var preparation_capacity_bar: ProgressBar
var preparation_capacity_label: Label
var preparation_reserve_button: Button
var preparation_catalog: GridContainer
var preparation_catalog_scroll: ScrollContainer
var preparation_editor_stack: VBoxContainer
var preparation_editor_title: Label
var preparation_editor_count: Label
var preparation_editor_hint: Label
var preparation_editor_back_button: Button
var preparation_editor_browse: Control
var preparation_editor_picker: Control
var preparation_editor_confirm: Control
var preparation_confirm_compare: GridContainer
var preparation_inspector: PanelContainer
var preparation_inspector_footer: GridContainer
var preparation_inspector_title: Label
var preparation_inspector_description: Label
var preparation_inspector_meta: Label
var preparation_inspector_icon: SimpleIcon
var preparation_inspector_source: Control
var preparation_inspector_hover_source: Control
var preparation_confirm_current: Label
var preparation_confirm_candidate: Label
var preparation_confirm_capacity: Label
var preparation_confirm_button: Button
var preparation_remove_button: Button
var preparation_validation: Label
var preparation_synergy_label: Label
var preparation_start_button: Button
var preparation_footer: HBoxContainer
var preparation_cancel_replacement_button: Button
var preparation_component_buttons: Dictionary = {}
var current_preparation_snapshot: Dictionary = {}
var current_preparation_slots: Dictionary = {}
var current_preparation_catalog_entries: Array = []
var current_preparation_catalog_by_id: Dictionary = {}
var current_preparation_unlocked_ids: Variant = {}
var current_preparation_availability_reasons: Dictionary = {}
var current_preparation_selected_components: Array = []
var current_preparation_component_slots: Dictionary = {}
var current_preparation_capacity_used: int = 0
var current_preparation_capacity_limit: int = 8
var planning_snapshot: PlanningSnapshot = PlanningSnapshot.new()
var preparation_selecting_reserve: bool = false
var preparation_replacement_slots: Array[StringName] = []
var preparation_intro_skip_button: Button
var preparation_locked: bool = false
var preparation_slot_keyboard_activation: bool = false
var upgrade_overlay: Control
var upgrade_screen: UpgradeOverlay
var upgrade_view_revision: int = 0
var upgrade_panel: PanelContainer
var upgrade_cards: GridContainer
var upgrade_education: Control
var reroll_button: Button
var current_upgrade_options: Array[UpgradeDefinition] = []
var pause_overlay: Control
var pause_screen: PauseOverlay
var pause_view_revision: int = 0
var pause_panel: PanelContainer
var pause_resume_button: Button
var pause_skip_button: Button
var pause_stats_overlay: Control
var pause_stats_panel: PanelContainer
var pause_stats_label: Label
var pause_stats_label_right: Label
var pause_stats_grid: GridContainer
var pause_stats_scroll: ScrollContainer
var pause_stats_columns: Array[VBoxContainer] = []
var pause_stat_rows: Array[PanelContainer] = []
var pause_stats_back_button: Button
var pause_is_intro: bool = false
var abort_overlay: Control
var abort_confirmation: ConfirmationOverlay
var abort_confirmation_revision: int = 0
var abort_panel: PanelContainer
var intro_skip_overlay: Control
var intro_skip_confirmation: ConfirmationOverlay
var intro_skip_confirmation_revision: int = 0
var intro_skip_panel: PanelContainer
var restart_overlay: Control
var restart_confirmation: ConfirmationOverlay
var restart_confirmation_revision: int = 0
var restart_panel: PanelContainer
var discovery_tooltip: DiscoveryTooltip
var context_detail_controller: ContextDetailController
var upgrade_target_preview: UpgradeTargetPreview
var intro_upgrade_target: Variant
var end_overlay: Control
var result_screen: ResultOverlay
var result_view_revision: int = 0
var result_success: bool = false
var result_title_text: String = ""
var result_reason_text: String = ""
var result_detail_text: String = ""
var result_stats_data: Array[ResultOverlayViewModel.StatViewModel] = []
var result_reward_text: String = ""
var result_unlock_text: String = ""
var result_mastery_text: String = ""
var end_panel: PanelContainer
var end_title: Label
var end_reason: Label
var end_stats: Label
var end_reward: Label
var end_unlock: Label
var end_mastery_panel: Control
var end_mastery_label: Label
var finding_overlay: Control
var finding_screen: FindingOverlay
var finding_view_revision: int = 0
var finding_id: StringName = &""
var finding_title_text: String = ""
var finding_medical_copy: String = ""
var finding_gameplay_copy: String = ""
var finding_reaction_models: Array[FindingOverlayViewModel.ReactionViewModel] = []
var finding_reserve_model: FindingOverlayViewModel.ReserveSwapViewModel
var finding_validation_text: String = ""
var finding_context_sources: Array[Control] = []
var finding_title: Label
var finding_medical_text: Label
var finding_gameplay_text: Label
var finding_copy_grid: GridContainer
var finding_panel: PanelContainer
var finding_reaction_cards: GridContainer
var finding_reserve_row: Control
var finding_confirm_button: Button
var finding_swap_toggle: CheckButton
var finding_outgoing_option: OptionButton
var finding_reserve_label: Label
var finding_validation_label: Label
var finding_reaction_group: ButtonGroup
var current_finding_reaction: StringName = &""
var current_finding_reserve: StringName = &""
var current_finding_outgoing_ids: Array[StringName] = []
var finding_swap_valid: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dynamic TTFs must be rasterized for the effective UI scale instead of
	# scaling an already rasterized glyph atlas. Children inherit this mode.
	root.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	root.theme = AlveolusVisualTheme.create_theme()
	add_child(root)
	context_detail_controller = ContextDetailController.new()
	context_detail_controller.name = "ContextDetails"
	context_detail_controller.detail_opened.connect(func(source: Control, explicit: bool) -> void:
		context_detail_opened.emit(source, explicit)
	)
	context_detail_controller.detail_closed.connect(func() -> void:
		context_detail_closed.emit()
	)
	root.add_child(context_detail_controller)
	get_viewport().size_changed.connect(_apply_ui_scale)
	gameplay_hud = _build_gameplay_hud()
	campus_overlay = _build_campus()
	practice_overlay = _build_practice()
	research_overlay = _build_research()
	level_overlay = _build_level_select()
	lexicon_overlay = _build_lexicon()
	story_overlay = _build_story()
	settings_overlay = _build_settings()
	preparation_overlay = _build_preparation()
	upgrade_overlay = _build_upgrade_overlay()
	pause_overlay = _build_pause_overlay()
	pause_stats_overlay = _build_pause_stats_overlay()
	abort_overlay = _build_abort_overlay()
	intro_skip_overlay = _build_intro_skip_overlay()
	restart_overlay = _build_restart_overlay()
	finding_overlay = _build_finding_overlay()
	end_overlay = _build_end_overlay()
	upgrade_target_preview = UpgradeTargetPreview.new()
	for overlay in _all_overlays():
		root.add_child(overlay)
	root.add_child(upgrade_target_preview)
	discovery_tooltip = DiscoveryTooltip.new()
	discovery_tooltip.dismissed.connect(func() -> void: discovery_dismissed.emit())
	root.add_child(discovery_tooltip)
	_hide_all()
	set_process(false)

func _process(delta: float) -> void:
	if alert_time > 0.0:
		alert_time -= delta
		if alert_time <= 0.0:
			alert_panel.hide()
			_refresh_run_stats()
	if boss_announcement_time > 0.0:
		boss_announcement_time -= delta
		if boss_announcement_time <= 0.0:
			boss_announcement_panel.hide()
	if alert_time <= 0.0 and boss_announcement_time <= 0.0:
		set_process(false)

func _input(event: InputEvent) -> void:
	if settings_overlay != null and settings_overlay.is_visible_in_tree() and settings_screen != null and settings_screen.is_binding_conflict_open():
		var cancel_conflict: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
		if cancel_conflict:
			settings_screen.cancel_binding_conflict()
			get_viewport().set_input_as_handled()
		return
	if pending_binding_action == &"" or not settings_overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_binding_capture()
			get_viewport().set_input_as_handled()
			return
		_apply_binding_event(event)
		get_viewport().set_input_as_handled()

func _build_gameplay_hud() -> Control:
	var layer := Control.new()
	layer.name = "GameplayHUD"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layer)

	# Stable combat chrome is owned exclusively by the immutable RunHUD module.
	# Only genuinely transient alert/finding layers remain in this compatibility
	# facade, so hidden duplicate surfaces cannot consume nodes or materials.
	_install_run_hud_overlay(layer)

	alert_panel = Panel.new()
	alert_panel.name = "RunAlert"
	alert_panel.set_anchor(SIDE_LEFT, 0.5)
	alert_panel.set_anchor(SIDE_RIGHT, 0.5)
	alert_panel.offset_left = -260.0
	alert_panel.offset_right = 260.0
	alert_panel.offset_top = 126.0
	alert_panel.offset_bottom = 160.0
	alert_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AlveolusUIComponents.apply_surface_role(alert_panel, AlveolusVisualTheme.SurfaceRole.HUD_ALERT, COLOR_TEAL)
	layer.add_child(alert_panel)
	var alert_margin := _margin(12, 6, 12, 6)
	alert_panel.add_child(alert_margin)
	alert_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_HUD_VALUE_LABEL)
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alert_margin.add_child(alert_label)
	alert_panel.hide()

	boss_announcement_panel = Panel.new()
	boss_announcement_panel.name = "BossAnnouncement"
	boss_announcement_panel.set_anchor(SIDE_LEFT, 0.5)
	boss_announcement_panel.set_anchor(SIDE_RIGHT, 0.5)
	boss_announcement_panel.set_anchor(SIDE_TOP, 0.5)
	boss_announcement_panel.offset_left = -300.0
	boss_announcement_panel.offset_right = 300.0
	boss_announcement_panel.offset_top = -42.0
	boss_announcement_panel.offset_bottom = 42.0
	boss_announcement_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AlveolusUIComponents.apply_surface_role(boss_announcement_panel, AlveolusVisualTheme.SurfaceRole.HUD_ALERT, COLOR_RED, true)
	layer.add_child(boss_announcement_panel)
	var announcement_margin := _margin(16, 10, 16, 10)
	boss_announcement_panel.add_child(announcement_margin)
	boss_announcement = AlveolusUIComponents.label("INFEKTIONSHERD ERKANNT", AlveolusVisualTheme.TYPE_HUD_VALUE_LABEL)
	boss_announcement.add_theme_color_override("font_color", COLOR_RED)
	boss_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcement_margin.add_child(boss_announcement)
	boss_announcement_panel.hide()

	finding_progress_panel = Control.new()
	finding_progress_panel.name = "FindingProgress"
	finding_progress_panel.set_anchor(SIDE_LEFT, 0.5)
	finding_progress_panel.set_anchor(SIDE_RIGHT, 0.5)
	finding_progress_panel.set_anchor(SIDE_TOP, 1.0)
	finding_progress_panel.set_anchor(SIDE_BOTTOM, 1.0)
	finding_progress_panel.offset_left = -132.0
	finding_progress_panel.offset_right = 132.0
	finding_progress_panel.offset_top = -40.0
	finding_progress_panel.offset_bottom = -10.0
	finding_progress_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(finding_progress_panel)
	var finding_margin := _margin(9, 4, 9, 4)
	finding_progress_panel.add_child(finding_margin)
	var finding_row := HBoxContainer.new()
	finding_row.alignment = BoxContainer.ALIGNMENT_CENTER
	finding_row.add_theme_constant_override("separation", 8)
	finding_margin.add_child(finding_row)
	finding_progress_label = AlveolusUIComponents.label("BEFUND · 0 / 30", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	finding_progress_label.add_theme_color_override("font_color", COLOR_GOLD)
	finding_progress_label.custom_minimum_size.x = 122.0
	finding_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	finding_row.add_child(finding_progress_label)
	finding_progress_bar = AlveolusUIComponents.progress(0.0, 30.0, false)
	finding_progress_bar.custom_minimum_size.y = 5.0
	finding_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finding_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	AlveolusUIComponents.apply_progress_accent(finding_progress_bar, COLOR_GOLD)
	finding_row.add_child(finding_progress_bar)
	finding_progress_panel.hide()

	return layer


func _install_run_hud_overlay(layer: Control) -> void:
	# Stable run chrome is presented exclusively by the immutable RunHUD module
	# while the public GameHUD facade keeps its established compatibility handles.
	run_hud_screen = RunHUDOverlay.new()
	run_hud_screen.name = "RunHUD"
	run_hud_screen.ability_requested.connect(func(slot: int) -> void:
		ability_slot_requested.emit(slot)
	)
	run_hud_screen.pause_requested.connect(func() -> void:
		pause_requested.emit()
	)
	layer.add_child(run_hud_screen)
	layer.move_child(run_hud_screen, 0)
	for registration in run_hud_screen.context_detail_registrations():
		var source := registration.get("source") as Control
		var provider: Callable = registration.get("provider", Callable())
		if source != null and provider.is_valid():
			register_context_detail(
				source,
				provider,
				bool(registration.get("hover_enabled", true)),
				registration.get("anchor") as Control,
				int(registration.get("placement", ContextDetailController.Placement.AUTO))
			)

	# Preserve the established compatibility handles for callers and focused
	# layout tests. They now point at the central module's controls.
	stability_panel = run_hud_screen.stability_panel()
	stability_bar = run_hud_screen.stability_bar()
	stability_value = run_hud_screen.stability_value_label()
	shield_panel = run_hud_screen.shield_panel()
	shield_bar = run_hud_screen.shield_bar()
	shield_value = run_hud_screen.shield_value_label()
	timer_panel = run_hud_screen.timer_panel()
	timer_label = run_hud_screen.timer_value_label()
	boss_panel = run_hud_screen.boss_panel()
	boss_bar = run_hud_screen.boss_bar()
	boss_value = run_hud_screen.boss_value_label()
	boss_phase_label = run_hud_screen.boss_phase_label()
	analysis_sample_panel = run_hud_screen.analysis_panel()
	analysis_bar = run_hud_screen.analysis_bar()
	level_label = run_hud_screen.analysis_value_label()
	run_stats_panel = run_hud_screen.run_stats_strip()
	run_stats_strip = run_hud_screen.run_stats_strip()
	ability_panel = run_hud_screen.ability_panel()
	ability_cards = run_hud_screen.ability_cards()
	ability_hit_buttons = run_hud_screen.ability_buttons()
	ability_title_labels = run_hud_screen.ability_title_labels()
	ability_key_labels = run_hud_screen.ability_key_labels()
	ability_cooldown_labels = run_hud_screen.ability_cooldown_labels()
	ability_cooldown_bars = run_hud_screen.ability_cooldown_bars()
	ability_key_containers.clear()
	ability_key_icons.clear()
	_apply_run_hud_model()

func _apply_run_hud_model() -> void:
	if run_hud_screen == null:
		return
	run_hud_view_revision += 1
	run_hud_screen.apply_view_model(RunHUDViewModel.create(
		run_hud_vitals,
		run_hud_stat_rows,
		run_hud_ability_rows,
		run_hud_view_revision
	))

func _build_campus() -> Control:
	var overlay := _overlay_base(Color.TRANSPARENT)
	var scene := CampusScene.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(scene)
	var cards := [
		[&"practice", "PRAXIS", COLOR_TEAL, Vector2(190, 178), 158.0],
		[&"research", "FORSCHUNG", COLOR_GOLD, Vector2(180, 178), 166.0],
		[&"levels", "FÄLLE", COLOR_BLUE, Vector2(190, 176), 154.0],
		[&"lexicon", "LEXIKON", COLOR_TEAL, Vector2(190, 178), 154.0],
		[&"settings", "EINSTELLUNGEN", COLOR_MUTED, Vector2(146, 140), 156.0]
	]
	for data in cards:
		var id: StringName = data[0]
		var card := CampusBuildingCard.new()
		card.size = data[3]
		var anchor := CampusScene.building_anchor(id)
		card.position = anchor - Vector2(card.size.x * 0.5, card.size.y)
		card.configure(data[1], VisualAssetCatalog.campus_building(id), data[2], data[4], card.size.y - 42.0)
		card.selected.connect(_emit_navigation.bind(id))
		overlay.add_child(card)
		campus_buttons[id] = card

	# Header, labels and status share one topmost clipped layer. Runtime cards can
	# therefore never paint over the safe zone, even after future repositioning.
	var header_layer := Control.new()
	header_layer.name = "CampusHeaderLayer"
	header_layer.set_anchor(SIDE_RIGHT, 1.0)
	header_layer.offset_bottom = 92.0
	header_layer.clip_contents = true
	header_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The layer is last inside the campus, so tree order keeps it above buildings.
	# A positive z-index would escape the dimmed campus and cover document pages.
	header_layer.z_index = 0
	overlay.add_child(header_layer)
	var campus_header := Panel.new()
	campus_header.name = "CampusSafeHeader"
	campus_header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	campus_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var campus_header_style := AlveolusVisualTheme.panel_style(Color(AlveolusVisualTheme.PETROL_DEEP, 0.96), COLOR_TEAL, 1, 0, false)
	campus_header_style.border_width_left = 0
	campus_header_style.border_width_top = 0
	campus_header_style.border_width_right = 0
	campus_header_style.border_width_bottom = 2
	campus_header.add_theme_stylebox_override("panel", campus_header_style)
	header_layer.add_child(campus_header)
	var logo := _label("ALVEOLUS", 28, AlveolusVisualTheme.IVORY)
	logo.position = Vector2(28.0, 22.0)
	logo.size = Vector2(300.0, 38.0)
	header_layer.add_child(logo)
	var subtitle := _label("FORSCHUNGSCAMPUS · TAGDIENST", 14, COLOR_TEAL.darkened(0.24))
	subtitle.position = Vector2(30.0, 61.0)
	subtitle.size = Vector2(330.0, 20.0)
	header_layer.add_child(subtitle)
	var top_status := VBoxContainer.new()
	top_status.set_anchor(SIDE_LEFT, 1.0)
	top_status.set_anchor(SIDE_RIGHT, 1.0)
	top_status.offset_left = -400.0
	top_status.offset_right = -24.0
	top_status.offset_top = 24.0
	top_status.offset_bottom = 79.0
	header_layer.add_child(top_status)
	campus_research_status = _label("FORSCHUNG 0", 14, AlveolusVisualTheme.GOLD)
	campus_research_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_status.add_child(campus_research_status)
	campus_clinic_status = _label("KEIN KLINIKFALL AKTIV", 14, AlveolusVisualTheme.SKY_DEEP)
	campus_clinic_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_status.add_child(campus_clinic_status)
	return overlay

func _build_practice() -> Control:
	practice_screen = PracticeScreen.new()
	practice_screen.offline_claim_requested.connect(func() -> void: offline_claim_requested.emit())
	practice_screen.clinic_job_start_requested.connect(func(id: StringName) -> void: clinic_job_start_requested.emit(id))
	practice_screen.clinic_job_claim_requested.connect(func() -> void: clinic_job_claim_requested.emit())
	practice_screen.back_requested.connect(func() -> void: back_requested.emit())
	practice_columns = practice_screen.find_child("PracticeColumns", true, false) as GridContainer
	clinic_offers = practice_screen.find_child("ClinicOffers", true, false) as Control
	passive_claim_button = practice_screen.offline_claim_action()
	clinic_claim_button = practice_screen.clinic_claim_action()
	clinic_progress = practice_screen.clinic_progress_control()
	return practice_screen

func _build_research() -> Control:
	progression_screen = ProgressionScreen.new()
	progression_screen.tab_changed.connect(_on_progression_tab_changed)
	progression_screen.research_purchase.connect(func(id: StringName) -> void: research_purchase_requested.emit(id))
	progression_screen.research_reset.connect(func() -> void: research_reset_requested.emit())
	progression_screen.talent_toggle.connect(func(id: StringName) -> void: talent_toggle_requested.emit(id))
	progression_screen.talent_reset.connect(func() -> void: talent_reset_requested.emit())
	progression_screen.back.connect(func() -> void: back_requested.emit())
	_map_progression_compatibility_controls()
	return progression_screen

func _build_level_select() -> Control:
	level_screen = CaseArchiveScreen.new()
	level_screen.case_selected.connect(_emit_level_selected)
	level_screen.replay_story.connect(func() -> void: navigate_requested.emit(&"story"))
	level_screen.back.connect(func() -> void: back_requested.emit())
	return level_screen

func _build_lexicon() -> Control:
	var page := _page("Lexikon", "Zum Campus")
	var overlay: Control = page["overlay"]
	var body: VBoxContainer = page["body"]
	lexicon_master_detail = LexiconMasterDetail.new()
	lexicon_master_detail.name = "LexiconMasterDetail"
	lexicon_master_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lexicon_master_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lexicon_master_detail.context_detail_source_available.connect(register_context_detail)
	body.add_child(lexicon_master_detail)
	return overlay

func _build_story() -> Control:
	story_screen = StoryScreen.new()
	story_screen.next_requested.connect(func(_step_index: int) -> void: _advance_story())
	story_screen.skip_requested.connect(func() -> void: story_finished.emit())
	story_screen.back_requested.connect(func(step_index: int) -> void:
		if step_index > 0:
			story_index = step_index - 1
			_refresh_story()
		else:
			back_requested.emit()
	)
	story_panel = story_screen.story_sheet()
	story_kicker = story_screen.progress_label()
	story_title = story_screen.title_label()
	story_body = story_screen.body_label()
	story_skip_button = story_screen.skip_action()
	story_next_button = story_screen.next_action()
	return story_screen

func _build_settings() -> Control:
	settings_screen = SettingsScreen.new()
	settings_screen.name = "SettingsScreen"
	settings_screen.audio_value_changed.connect(func(setting_id: StringName, linear_value: float) -> void:
		_on_settings_volume_changed(linear_value * 100.0, setting_id)
	)
	settings_screen.audio_mute_changed.connect(func(setting_id: StringName, muted: bool) -> void:
		_on_settings_mute_changed(muted, setting_id)
	)
	settings_screen.option_changed.connect(_on_settings_option_changed)
	settings_screen.toggle_changed.connect(_on_settings_toggle_changed)
	settings_screen.binding_slot_change_requested.connect(_begin_binding_capture)
	settings_screen.binding_conflict_decided.connect(_on_binding_conflict_decided)
	settings_screen.bindings_reset_requested.connect(func() -> void: settings_reset_bindings_requested.emit())
	settings_screen.quit_requested.connect(func() -> void: quit_requested.emit())
	settings_screen.back.connect(func() -> void: back_requested.emit())
	_refresh_settings_screen(true)
	return settings_screen

func _on_settings_option_changed(setting_id: StringName, selected_index: int) -> void:
	match setting_id:
		&"ui_scale": _on_settings_scale_selected(selected_index)
		&"glyph_mode": _on_settings_glyph_selected(selected_index)

func _on_settings_toggle_changed(setting_id: StringName, enabled: bool) -> void:
	match setting_id:
		&"reduce_motion": _on_settings_reduce_motion(enabled)
		&"run_stats": _on_run_stats_toggle(enabled)
		&"show_character_name": _on_settings_character_name(enabled)
		&"fullscreen": _on_settings_fullscreen(enabled)
		&"confirm_restart": _on_settings_restart_confirmation(enabled)

func _refresh_settings_screen(show_quit: bool = settings_show_quit) -> void:
	if settings_screen == null or current_ui_settings == null:
		return
	settings_show_quit = show_quit
	settings_view_revision += 1
	var audio_settings: Array[SettingsScreenViewModel.AudioSettingViewModel] = [
		SettingsScreenViewModel.AudioSettingViewModel.new(&"master", "Gesamtlautstärke", current_ui_settings.master_volume, current_ui_settings.master_muted),
		SettingsScreenViewModel.AudioSettingViewModel.new(&"ui", "Menü", current_ui_settings.ui_volume, current_ui_settings.ui_muted),
		SettingsScreenViewModel.AudioSettingViewModel.new(&"effects", "Effekte", current_ui_settings.effects_volume, current_ui_settings.effects_muted),
		SettingsScreenViewModel.AudioSettingViewModel.new(&"music", "Musik", current_ui_settings.music_volume, current_ui_settings.music_muted),
	]
	var scale_labels: Array[String] = []
	for scale in UISettingsState.UI_SCALES:
		scale_labels.append("%d %%" % roundi(scale * 100.0))
	var glyph_labels: Array[String] = ["Automatisch", "Tastatur", "Gamepad"]
	var option_settings: Array[SettingsScreenViewModel.OptionSettingViewModel] = [
		SettingsScreenViewModel.OptionSettingViewModel.new(
			&"ui_scale", "UI-Größe", scale_labels,
			maxi(UISettingsState.UI_SCALES.find(current_ui_settings.ui_scale), 0)
		),
		SettingsScreenViewModel.OptionSettingViewModel.new(
			&"glyph_mode", "Eingabesymbole", glyph_labels,
			maxi([UISettingsState.GLYPH_AUTO, UISettingsState.GLYPH_KEYBOARD, UISettingsState.GLYPH_GAMEPAD].find(current_ui_settings.glyph_mode), 0)
		),
	]
	var toggle_settings: Array[SettingsScreenViewModel.ToggleSettingViewModel] = [
		SettingsScreenViewModel.ToggleSettingViewModel.new(&"reduce_motion", "Animationen reduzieren", current_ui_settings.reduce_motion),
		SettingsScreenViewModel.ToggleSettingViewModel.new(&"run_stats", "Charakterwerte im Run", run_stats_enabled),
		SettingsScreenViewModel.ToggleSettingViewModel.new(&"show_character_name", "Charaktername anzeigen", current_ui_settings.show_character_name),
		SettingsScreenViewModel.ToggleSettingViewModel.new(&"fullscreen", "Vollbild", current_ui_settings.fullscreen, not OS.has_feature("web")),
		SettingsScreenViewModel.ToggleSettingViewModel.new(&"confirm_restart", "Neustart bestätigen", current_ui_settings.confirm_run_restart),
	]
	var binding_settings: Array[SettingsScreenViewModel.BindingSettingViewModel] = []
	for action in UISettingsState.CONFIGURABLE_ACTIONS:
		var keyboard_slots: Array[String] = []
		for slot_index in range(UISettingsState.KEYBOARD_BINDING_SLOT_COUNT):
			keyboard_slots.append(_keyboard_binding_slot_summary(action, slot_index))
		binding_settings.append(SettingsScreenViewModel.BindingSettingViewModel.new(
			action,
			_binding_caption(action),
			keyboard_slots,
			pending_binding_slot if pending_binding_action == action else -1
		))
	var conflict_view_model: SettingsScreenViewModel.BindingConflictViewModel = null
	if pending_binding_event != null and pending_binding_action != &"" and pending_binding_conflicting_action != &"":
		var conflict_labels: PackedStringArray = []
		for conflict_action in current_ui_settings.keyboard_binding_conflicts(pending_binding_action, pending_binding_event):
			conflict_labels.append(_binding_caption(conflict_action))
		conflict_view_model = SettingsScreenViewModel.BindingConflictViewModel.new(
			pending_binding_action,
			pending_binding_slot,
			_binding_caption(pending_binding_action),
			pending_binding_conflicting_action,
			", ".join(conflict_labels) if not conflict_labels.is_empty() else _binding_caption(pending_binding_conflicting_action),
			InputGlyphService.text_for_event(pending_binding_event)
		)
	var model := SettingsScreenViewModel.new(
		settings_view_revision,
		audio_settings,
		option_settings,
		toggle_settings,
		binding_settings,
		settings_status_text,
		settings_show_quit,
		conflict_view_model
	)
	settings_screen.apply(model)
	_map_settings_compatibility_controls()

func _map_settings_compatibility_controls() -> void:
	if settings_screen == null:
		return
	settings_scroll = settings_screen.get_scroll_container()
	settings_upper_grid = settings_screen.find_child("UpperSections", true, false) as GridContainer
	settings_bindings_grid = settings_screen.find_child("BindingsGrid", true, false) as GridContainer
	settings_master_slider = settings_screen.control_for_setting(&"audio.master.value") as HSlider
	settings_ui_slider = settings_screen.control_for_setting(&"audio.ui.value") as HSlider
	settings_effects_slider = settings_screen.control_for_setting(&"audio.effects.value") as HSlider
	settings_music_slider = settings_screen.control_for_setting(&"audio.music.value") as HSlider
	settings_master_mute = settings_screen.control_for_setting(&"audio.master.mute") as CheckButton
	settings_ui_mute = settings_screen.control_for_setting(&"audio.ui.mute") as CheckButton
	settings_effects_mute = settings_screen.control_for_setting(&"audio.effects.mute") as CheckButton
	settings_music_mute = settings_screen.control_for_setting(&"audio.music.mute") as CheckButton
	settings_scale_option = settings_screen.control_for_setting(&"option.ui_scale") as OptionButton
	settings_glyph_option = settings_screen.control_for_setting(&"option.glyph_mode") as OptionButton
	settings_reduce_motion_toggle = settings_screen.control_for_setting(&"toggle.reduce_motion") as CheckButton
	settings_run_stats_toggle = settings_screen.control_for_setting(&"toggle.run_stats") as CheckButton
	settings_fullscreen_toggle = settings_screen.control_for_setting(&"toggle.fullscreen") as CheckButton
	settings_restart_confirmation_toggle = settings_screen.control_for_setting(&"toggle.confirm_restart") as CheckButton
	settings_status_label = settings_screen.find_child("StatusText", true, false) as Label
	settings_quit_button = settings_screen.control_for_setting(&"quit") as Button
	settings_initial_focus = settings_screen.get_default_focus_control()
	settings_binding_buttons.clear()
	for action in UISettingsState.CONFIGURABLE_ACTIONS:
		var button := settings_screen.control_for_setting(StringName("binding.%s.0" % String(action))) as Button
		if button != null:
			settings_binding_buttons[action] = button

func _settings_slider_row(caption: String, key: StringName) -> Dictionary:
	var parts := AlveolusUIComponents.slider_row(caption, 0.0, 100.0, 100.0, 1.0)
	var row := parts["row"] as HBoxContainer
	var slider := parts["control"] as HSlider
	slider.value_changed.connect(_on_settings_volume_changed.bind(key))
	var mute := AlveolusUIComponents.toggle_row("Stumm")
	mute.custom_minimum_size = Vector2(92.0, AlveolusVisualTheme.TOUCH_TARGET_MINIMUM)
	mute.toggled.connect(_on_settings_mute_changed.bind(key))
	row.add_child(mute)
	return {"row": row, "slider": slider, "mute": mute}

func _settings_option_row(parent: VBoxContainer, caption: String, entries: Array[String]) -> OptionButton:
	var parts := AlveolusUIComponents.option_row(caption, entries)
	parent.add_child(parts["row"])
	return parts["control"] as OptionButton

func _settings_toggle_row(parent: VBoxContainer, caption: String, callback: Callable) -> CheckButton:
	var toggle := AlveolusUIComponents.toggle_row("Aus")
	toggle.custom_minimum_size = Vector2(92.0, AlveolusVisualTheme.TOUCH_TARGET_MINIMUM)
	var parts := AlveolusUIComponents.form_control_row(caption, toggle)
	parent.add_child(parts["panel"])
	toggle.toggled.connect(func(enabled: bool) -> void: _update_toggle_caption(toggle, enabled))
	toggle.toggled.connect(callback)
	return toggle

func _update_toggle_caption(toggle: CheckButton, enabled: bool) -> void:
	if toggle != null:
		toggle.text = "Ein" if enabled else "Aus"

func _on_settings_volume_changed(value: float, key: StringName) -> void:
	if current_ui_settings == null:
		return
	var linear := clampf(value / 100.0, 0.0, 1.0)
	match key:
		&"master": current_ui_settings.master_volume = linear
		&"ui": current_ui_settings.ui_volume = linear
		&"effects": current_ui_settings.effects_volume = linear
		&"music": current_ui_settings.music_volume = linear
	_emit_ui_settings_changed()

func _on_settings_mute_changed(enabled: bool, key: StringName) -> void:
	if current_ui_settings == null:
		return
	match key:
		&"master": current_ui_settings.master_muted = enabled
		&"ui": current_ui_settings.ui_muted = enabled
		&"effects": current_ui_settings.effects_muted = enabled
		&"music": current_ui_settings.music_muted = enabled
	_emit_ui_settings_changed()

func _on_settings_scale_selected(index: int) -> void:
	if current_ui_settings == null or index < 0 or index >= UISettingsState.UI_SCALES.size():
		return
	current_ui_settings.ui_scale = UISettingsState.UI_SCALES[index]
	_apply_ui_scale()
	_emit_ui_settings_changed()

func _on_settings_glyph_selected(index: int) -> void:
	if current_ui_settings == null:
		return
	current_ui_settings.glyph_mode = [UISettingsState.GLYPH_AUTO, UISettingsState.GLYPH_KEYBOARD, UISettingsState.GLYPH_GAMEPAD][clampi(index, 0, 2)]
	if input_glyph_service != null:
		input_glyph_service.configure(current_ui_settings.glyph_mode)
	_emit_ui_settings_changed()

func _on_settings_reduce_motion(enabled: bool) -> void:
	if current_ui_settings == null:
		return
	current_ui_settings.reduce_motion = enabled
	reduced_motion_enabled = enabled
	_apply_reduced_motion()
	_emit_ui_settings_changed()

func _on_settings_fullscreen(enabled: bool) -> void:
	if current_ui_settings == null:
		return
	current_ui_settings.fullscreen = enabled
	current_ui_settings.apply_window()
	_emit_ui_settings_changed()

func _on_settings_character_name(enabled: bool) -> void:
	if current_ui_settings == null:
		return
	current_ui_settings.show_character_name = enabled
	_emit_ui_settings_changed()

func _on_settings_restart_confirmation(enabled: bool) -> void:
	if current_ui_settings == null:
		return
	current_ui_settings.confirm_run_restart = enabled
	_emit_ui_settings_changed()

func _emit_ui_settings_changed() -> void:
	current_ui_settings.apply_audio()
	ui_settings_changed.emit(current_ui_settings.duplicate_settings())

func _begin_binding_capture(action: StringName, slot_index: int = 0) -> void:
	if not UISettingsState.CONFIGURABLE_ACTIONS.has(action):
		return
	pending_binding_action = action
	pending_binding_slot = clampi(slot_index, 0, UISettingsState.KEYBOARD_BINDING_SLOT_COUNT - 1)
	pending_binding_event = null
	pending_binding_conflicting_action = &""
	settings_status_text = "Tastaturtaste für „%s“ · Platz %d drücken. Escape bricht ab." % [_binding_caption(action), pending_binding_slot + 1]
	_refresh_settings_screen(settings_show_quit)

func _cancel_binding_capture() -> void:
	pending_binding_action = &""
	pending_binding_slot = -1
	pending_binding_event = null
	pending_binding_conflicting_action = &""
	settings_status_text = "Belegung nicht verändert."
	_play_ui_sound(UISoundService.BACK)
	if settings_overlay != null and settings_overlay.visible:
		_refresh_binding_buttons()

func _apply_binding_event(event: InputEvent) -> void:
	var action := pending_binding_action
	if action == &"" or pending_binding_slot < 0 or not event is InputEventKey:
		return
	if UISettingsState.is_reserved_quick_restart_binding(event):
		settings_status_text = "Strg+R ist für den Rundenneustart reserviert."
		_play_ui_sound(UISoundService.ERROR)
		_refresh_binding_buttons()
		return
	var key_event := event as InputEventKey
	var conflicting_actions := current_ui_settings.keyboard_binding_conflicts(action, key_event)
	if not conflicting_actions.is_empty():
		pending_binding_event = key_event.duplicate() as InputEventKey
		pending_binding_conflicting_action = conflicting_actions[0]
		settings_status_text = "„%s“ ist bereits belegt. Bitte Übernahme bestätigen." % InputGlyphService.text_for_event(key_event)
		_play_ui_sound(UISoundService.OPEN)
		_refresh_binding_buttons()
		return
	if current_ui_settings.set_keyboard_binding_slot(action, pending_binding_slot, key_event):
		pending_binding_action = &""
		pending_binding_slot = -1
		pending_binding_event = null
		pending_binding_conflicting_action = &""
		settings_status_text = "„%s“ wurde neu belegt." % _binding_caption(action)
		_play_ui_sound(UISoundService.CONFIRM)
		_emit_ui_settings_changed()
	else:
		settings_status_text = "Diese Eingabe wird bereits verwendet. Wähle eine andere."
		_play_ui_sound(UISoundService.ERROR)
	_refresh_binding_buttons()

func _on_binding_conflict_decided(
	action: StringName,
	slot_index: int,
	conflicting_action: StringName,
	replace_existing: bool
) -> void:
	if action != pending_binding_action or slot_index != pending_binding_slot or conflicting_action != pending_binding_conflicting_action or pending_binding_event == null:
		return
	var applied := replace_existing and current_ui_settings.set_keyboard_binding_slot(action, slot_index, pending_binding_event, true)
	pending_binding_action = &""
	pending_binding_slot = -1
	pending_binding_event = null
	pending_binding_conflicting_action = &""
	if applied:
		settings_status_text = "„%s“ wurde übernommen." % _binding_caption(action)
		_play_ui_sound(UISoundService.CONFIRM)
		_emit_ui_settings_changed()
	else:
		settings_status_text = "Die bestehende Belegung bleibt erhalten."
		_play_ui_sound(UISoundService.BACK)
	_refresh_binding_buttons()

func _refresh_binding_buttons() -> void:
	_refresh_settings_screen(settings_show_quit)

func is_binding_interaction_active() -> bool:
	if settings_overlay == null or not settings_overlay.is_visible_in_tree():
		return false
	return pending_binding_action != &"" or (settings_screen != null and settings_screen.is_binding_conflict_open())

func _clear_binding_interaction() -> void:
	pending_binding_action = &""
	pending_binding_slot = -1
	pending_binding_event = null
	pending_binding_conflicting_action = &""
	settings_status_text = ""

func _binding_summary(action: StringName) -> String:
	var slots: PackedStringArray = []
	for slot_index in range(UISettingsState.KEYBOARD_BINDING_SLOT_COUNT):
		slots.append(_keyboard_binding_slot_summary(action, slot_index))
	return " / ".join(slots)

func _keyboard_binding_slot_summary(action: StringName, slot_index: int) -> String:
	if current_ui_settings == null:
		return "Nicht belegt"
	var bindings := current_ui_settings.keyboard_bindings_for(action)
	if slot_index < 0 or slot_index >= bindings.size():
		return "Nicht belegt"
	var text := InputGlyphService.text_for_event(bindings[slot_index])
	return text if not text.is_empty() else "Nicht belegt"

func _binding_caption(action: StringName) -> String:
	return InputGlyphService.caption_for_action(action)

func _joy_button_text(index: JoyButton) -> String:
	match index:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "Menu"
		JOY_BUTTON_DPAD_UP: return "Steuerkreuz oben"
		JOY_BUTTON_DPAD_DOWN: return "Steuerkreuz unten"
		JOY_BUTTON_DPAD_LEFT: return "Steuerkreuz links"
		JOY_BUTTON_DPAD_RIGHT: return "Steuerkreuz rechts"
	return "Taste %d" % int(index)

func _apply_ui_scale() -> void:
	if root == null or root.theme == null or current_ui_settings == null:
		return
	var ui_scale := current_ui_settings.ui_scale
	# Document UI uses one scaling authority: the root transform. Applying the
	# same factor again through Theme.default_base_scale doubles theme-driven
	# minima, paddings and controls inside the already reduced logical canvas.
	root.theme.default_base_scale = 1.0
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2.ZERO
	root.scale = Vector2.ONE * ui_scale
	root.size = get_viewport().get_visible_rect().size / ui_scale
	_apply_campus_canvas_scale(ui_scale)
	var logical_width := root.size.x
	_apply_page_shell_layout(logical_width)
	if practice_columns != null:
		practice_columns.columns = 1 if logical_width < 920.0 else 2
	if clinic_offers is GridContainer:
		(clinic_offers as GridContainer).columns = 1
	if run_hud_screen == null and stability_panel != null and timer_panel != null:
		if logical_width < 740.0:
			var compact_top_width := minf(230.0, (logical_width - 48.0) * 0.5)
			stability_panel.position = Vector2(16.0, 16.0)
			stability_panel.size = Vector2(compact_top_width, 44.0)
			timer_panel.set_anchor(SIDE_LEFT, 1.0)
			timer_panel.set_anchor(SIDE_RIGHT, 1.0)
			timer_panel.offset_left = -16.0 - compact_top_width
			timer_panel.offset_right = -16.0
			timer_panel.offset_top = 16.0
			timer_panel.offset_bottom = 52.0
		else:
			stability_panel.position = Vector2(16.0, 16.0)
			stability_panel.size = Vector2(250.0, 44.0)
			timer_panel.set_anchor(SIDE_LEFT, 0.5)
			timer_panel.set_anchor(SIDE_RIGHT, 0.5)
			timer_panel.offset_left = -112.0
			timer_panel.offset_right = 112.0
			timer_panel.offset_top = 16.0
			timer_panel.offset_bottom = 52.0
	if run_hud_screen == null and shield_panel != null:
		shield_panel.size = Vector2(minf(250.0, logical_width * 0.45) if logical_width < 740.0 else 250.0, 28.0)
	if run_hud_screen == null and run_stats_panel != null:
		run_stats_panel.set_anchor(SIDE_LEFT, 0.0 if logical_width < 740.0 else 0.5)
		run_stats_panel.set_anchor(SIDE_RIGHT, 1.0)
		run_stats_panel.offset_left = 16.0 if logical_width < 740.0 else 124.0
		run_stats_panel.offset_right = -16.0
		# Compact HUDs already use y=64..92 for the shield. Keep the optional
		# transparent statistics in their own row instead of painting over it.
		run_stats_panel.offset_top = 104.0 if logical_width < 740.0 else 16.0
		run_stats_panel.offset_bottom = run_stats_panel.offset_top + HudStatStrip.MAXIMUM_SIZE.y
	if run_hud_screen == null and ability_panel != null:
		if logical_width >= 900.0:
			ability_panel.columns = 2
			ability_panel.set_anchor(SIDE_LEFT, 1.0)
			ability_panel.set_anchor(SIDE_RIGHT, 1.0)
			ability_panel.set_anchor(SIDE_TOP, 1.0)
			ability_panel.set_anchor(SIDE_BOTTOM, 1.0)
			ability_panel.offset_left = -400.0
			ability_panel.offset_right = -16.0
			ability_panel.offset_top = -72.0
			ability_panel.offset_bottom = -12.0
		else:
			ability_panel.columns = 2
			ability_panel.set_anchor(SIDE_LEFT, 0.0)
			ability_panel.set_anchor(SIDE_RIGHT, 1.0)
			ability_panel.set_anchor(SIDE_TOP, 1.0)
			ability_panel.set_anchor(SIDE_BOTTOM, 1.0)
			ability_panel.offset_left = 12.0
			ability_panel.offset_right = -12.0
			ability_panel.offset_top = -68.0
			ability_panel.offset_bottom = -8.0
	if run_hud_screen == null and analysis_sample_panel != null:
		analysis_sample_panel.offset_top = -100.0 if logical_width < 900.0 else -32.0
		analysis_sample_panel.offset_bottom = -76.0 if logical_width < 900.0 else -8.0
		level_label.offset_top = -99.0 if logical_width < 900.0 else -31.0
		level_label.offset_bottom = -77.0 if logical_width < 900.0 else -9.0
	if finding_progress_panel != null:
		if logical_width < 600.0:
			# Share one compact row with the left-aligned sample badge. This frees a
			# complete critical-HUD row above it on 960×540 at 200 %.
			finding_progress_panel.offset_left = -logical_width * 0.5 + 202.0
			finding_progress_panel.offset_right = logical_width * 0.5 - 16.0
			finding_progress_panel.offset_top = -100.0
			finding_progress_panel.offset_bottom = -72.0
		elif logical_width < 900.0:
			var finding_half_width := minf(132.0, logical_width * 0.25)
			finding_progress_panel.offset_left = -finding_half_width
			finding_progress_panel.offset_right = finding_half_width
			finding_progress_panel.offset_top = -136.0
			finding_progress_panel.offset_bottom = -104.0
		else:
			finding_progress_panel.offset_left = -178.0
			finding_progress_panel.offset_right = 178.0
			finding_progress_panel.offset_top = -60.0
			finding_progress_panel.offset_bottom = -12.0
	if run_hud_screen == null and boss_panel != null and logical_width < 740.0:
		# Boss information shares the shield row on the right and temporarily
		# replaces optional run stats. Transient alerts receive the following row.
		var shield_right := 16.0 + shield_panel.size.x
		var boss_left := -logical_width * 0.5 + shield_right + 16.0
		var compact_right := logical_width * 0.5 - 16.0
		boss_panel.offset_left = boss_left
		boss_panel.offset_right = compact_right
		boss_panel.offset_top = 64.0
		boss_panel.offset_bottom = 106.0
		boss_phase_label.visible = logical_width >= 600.0
		alert_panel.offset_left = -logical_width * 0.5 + 16.0
		alert_panel.offset_right = compact_right
		alert_panel.offset_top = 110.0
		alert_panel.offset_bottom = 144.0
		boss_announcement_panel.offset_left = -logical_width * 0.5 + 16.0
		boss_announcement_panel.offset_right = compact_right
	elif run_hud_screen == null and boss_panel != null:
		boss_panel.offset_left = -260.0
		boss_panel.offset_right = 260.0
		boss_panel.offset_top = 70.0
		boss_panel.offset_bottom = 112.0
		boss_phase_label.show()
		alert_panel.offset_left = -260.0
		alert_panel.offset_right = 260.0
		alert_panel.offset_top = 126.0
		alert_panel.offset_bottom = 160.0
		boss_announcement_panel.offset_left = -300.0
		boss_announcement_panel.offset_right = 300.0
	elif run_hud_screen != null and logical_width < 740.0:
		var compact_right := logical_width * 0.5 - 16.0
		alert_panel.offset_left = -logical_width * 0.5 + 16.0
		alert_panel.offset_right = compact_right
		alert_panel.offset_top = 110.0
		alert_panel.offset_bottom = 144.0
		boss_announcement_panel.offset_left = -logical_width * 0.5 + 16.0
		boss_announcement_panel.offset_right = compact_right
	else:
		alert_panel.offset_left = -260.0
		alert_panel.offset_right = 260.0
		alert_panel.offset_top = 126.0
		alert_panel.offset_bottom = 160.0
		boss_announcement_panel.offset_left = -300.0
		boss_announcement_panel.offset_right = 300.0
	if preparation_workspace != null:
		_apply_preparation_layout()
	if restart_panel != null:
		restart_panel.custom_minimum_size = _fit_modal_size(Vector2(470.0, 188.0))
func _apply_campus_canvas_scale(ui_scale: float) -> void:
	if campus_overlay == null:
		return
	# The campus is a spatial map rather than a document surface. Magnifying its
	# complete 1280x720 world would crop buildings at 200 % UI scale, so it keeps
	# a full-canvas presentation while document screens and controls still scale.
	campus_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	campus_overlay.position = Vector2.ZERO
	campus_overlay.scale = Vector2.ONE / maxf(ui_scale, 0.01)
	campus_overlay.size = root.size * ui_scale
	# The spatial campus deliberately cancels the root transform so every
	# building remains visible. Give only its UI chrome the requested scale;
	# sprites and authored world geometry remain untouched.
	if campus_overlay.theme == null:
		campus_overlay.theme = root.theme.duplicate(true)
	campus_overlay.theme.default_base_scale = ui_scale

func _apply_page_shell_layout(logical_width: float) -> void:
	var compact := logical_width < 740.0
	var stack_header_actions := compact
	var margin_value := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	var header_height := AlveolusVisualTheme.HEADER_HEIGHT_COMPACT if compact else AlveolusVisualTheme.HEADER_HEIGHT
	var content_gap := AlveolusVisualTheme.HEADER_CONTENT_GAP_COMPACT if compact else AlveolusVisualTheme.HEADER_CONTENT_GAP
	for shell in page_shells:
		var outer := shell.get("outer") as MarginContainer
		var page := shell.get("page") as VBoxContainer
		var header := shell.get("header") as HBoxContainer
		var header_back := shell.get("header_back") as Control
		var actions := shell.get("actions") as HBoxContainer
		var visible_action_count := 0
		var inline_action_width := 0.0
		if actions != null:
			for action_value in actions.get_children():
				var visible_action := action_value as Control
				if visible_action != null and visible_action.visible:
					visible_action_count += 1
					inline_action_width += float(visible_action.get_meta(&"preferred_inline_width", maxf(146.0, visible_action.get_combined_minimum_size().x)))
		if visible_action_count > 1:
			inline_action_width += float(visible_action_count - 1) * 8.0
		var title_label := shell.get("title") as Label
		var title_width := 0.0
		if title_label != null:
			title_width = title_label.get_theme_font("font").get_string_size(
				title_label.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				title_label.get_theme_font_size("font_size")
			).x
		var available_header_width := maxf(0.0, logical_width - margin_value * 2.0)
		var required_inline_width := 44.0 + 32.0 + title_width + inline_action_width
		var stack_this_header := visible_action_count > 0 and (
			required_inline_width > available_header_width or
			(stack_header_actions and visible_action_count > 1)
		)
		if outer != null:
			outer.add_theme_constant_override("margin_left", margin_value)
			outer.add_theme_constant_override("margin_right", margin_value)
		if page != null:
			page.add_theme_constant_override("separation", content_gap)
		if header != null:
			header.custom_minimum_size.y = header_height
		if actions != null and header != null and page != null:
			if stack_this_header and actions.get_parent() != page:
				actions.reparent(page)
				page.move_child(actions, 1)
			elif not stack_this_header and actions.get_parent() != header:
				actions.reparent(header)
			actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stack_this_header else Control.SIZE_SHRINK_END
			actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for action_value in actions.get_children():
				var action := action_value as Control
				if action == null:
					continue
				action.custom_minimum_size.x = 0.0 if stack_this_header else float(action.get_meta(&"preferred_inline_width", 146.0))
				action.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stack_this_header else Control.SIZE_FILL
		if header_back != null:
			header_back.offset_bottom = header_height + content_gap + AlveolusVisualTheme.TOUCH_TARGET_MINIMUM if stack_this_header else header_height

func _fit_modal_size(desired: Vector2) -> Vector2:
	if root == null:
		return desired
	return Vector2(
		minf(desired.x, maxf(280.0, root.size.x - 32.0)),
		minf(desired.y, maxf(220.0, root.size.y - 32.0))
	)

func _fit_pause_stats_size(desired: Vector2) -> Vector2:
	if root == null:
		return desired
	# The read-only table may use almost the complete compact viewport. Keeping
	# the generic 16 px modal moat on every side would force a scrollbar at
	# 200 % even though the current value set fits in two dense columns.
	return Vector2(
		minf(desired.x, maxf(280.0, root.size.x - 4.0)),
		minf(desired.y, maxf(220.0, root.size.y - 4.0))
	)

func _apply_reduced_motion() -> void:
	if root == null:
		return
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button != null and reduced_motion_enabled:
			_stop_button_motion(button)
			button.scale = Vector2.ONE
	if get_tree() != null:
		get_tree().call_group(&"alveolus_reduced_motion", &"set_reduced_motion", reduced_motion_enabled)

func _play_ui_sound(cue: StringName) -> void:
	if get_tree() != null:
		get_tree().call_group(&"alveolus_ui_sound_service", &"play", cue)

func _build_preparation() -> Control:
	var page := _page("Einsatzplanung", "Zur Fallauswahl")
	var overlay: Control = page["overlay"]
	overlay.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	# This trial owns a darker canvas than the shared dossier pages. Keeping the
	# override here prevents the Bio-Lumen pass from recolouring other screens.
	if overlay is ColorRect:
		(overlay as ColorRect).color = Color("061e25")
	preparation_page_body = page["body"]
	var page_body: VBoxContainer = preparation_page_body
	var page_actions: HBoxContainer = page["actions"]
	preparation_header_back_button = page["back"]
	_apply_preparation_navigation_style(preparation_header_back_button)
	if preparation_header_back_button is IconTextButtonComponent:
		var planning_back := preparation_header_back_button as IconTextButtonComponent
		planning_back.configure("Zur Fallauswahl", &"back", Color("51d6cb"), 19.0, 8)
		planning_back.caption.add_theme_font_override("font", AlveolusVisualTheme.body_font())
		planning_back.caption.add_theme_font_size_override("font_size", 14)
		planning_back.custom_minimum_size = Vector2(164.0, AlveolusVisualTheme.TOUCH_TARGET_MINIMUM)
		planning_back.set_meta(&"preferred_inline_width", 164.0)
	preparation_intro_skip_button = _secondary_button("Einführung überspringen", COLOR_MUTED)
	_apply_preparation_navigation_style(preparation_intro_skip_button)
	preparation_intro_skip_button.pressed.connect(func() -> void: intro_skip_requested.emit())
	page_actions.add_child(preparation_intro_skip_button)

	preparation_scroll = ScrollContainer.new()
	preparation_scroll.name = "PreparationViewport"
	preparation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preparation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The page owns deliberate dossier/editor scroll positions. Letting this
	# outer viewport also follow every rebuilt focus target makes the same state
	# open at a different vertical offset after slot changes. The nested catalog
	# keeps follow_focus for controller navigation.
	preparation_scroll.follow_focus = false
	preparation_scroll.set_meta(&"manual_focus_scroll", true)
	page_body.add_child(preparation_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	preparation_scroll.add_child(body)

	# Bio-Lumen case ribbon: orientation on the left, semantic facts on the
	# right. It is intentionally one compact membrane instead of a prose card.
	preparation_trait_panel = Panel.new()
	preparation_trait_panel.name = "CaseDossier"
	preparation_trait_panel.custom_minimum_size = Vector2(0.0, 84.0)
	preparation_trait_panel.clip_contents = true
	preparation_trait_panel.add_theme_stylebox_override("panel", PreparationBioLumenStyle.dossier())
	PreparationBioLumenSurfaceFill.attach_static(preparation_trait_panel)
	body.add_child(preparation_trait_panel)
	var trait_margin := _margin(14, 12, 14, 12)
	preparation_trait_panel.add_child(trait_margin)
	preparation_case_row = GridContainer.new()
	preparation_case_row.columns = 2
	preparation_case_row.add_theme_constant_override("h_separation", 14)
	preparation_case_row.add_theme_constant_override("v_separation", 8)
	trait_margin.add_child(preparation_case_row)
	var case_copy := VBoxContainer.new()
	case_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	case_copy.add_theme_constant_override("separation", 3)
	preparation_case_row.add_child(case_copy)
	preparation_trait_row = HBoxContainer.new()
	case_copy.add_child(preparation_trait_row)
	preparation_level_title = _label("Fall", 16, COLOR_TEXT)
	preparation_level_title.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	preparation_level_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_level_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preparation_trait_row.add_child(preparation_level_title)
	preparation_trait_title = _label("Fallmerkmal", 14, COLOR_RED.lightened(0.18))
	preparation_trait_title.hide()
	preparation_trait_row.add_child(preparation_trait_title)
	preparation_level_description = _label("", 14, COLOR_MUTED)
	preparation_level_description.max_lines_visible = 2
	preparation_level_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preparation_level_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	case_copy.add_child(preparation_level_description)
	preparation_case_facts = HFlowContainer.new()
	preparation_case_facts.custom_minimum_size.x = 320.0
	preparation_case_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_case_facts.alignment = FlowContainer.ALIGNMENT_END
	preparation_case_facts.add_theme_constant_override("h_separation", 8)
	preparation_case_facts.add_theme_constant_override("v_separation", 6)
	preparation_case_row.add_child(preparation_case_facts)
	preparation_trait_effect = _label("Kein besonderer Einfluss", 14, COLOR_MUTED)
	preparation_trait_effect.hide()
	case_copy.add_child(preparation_trait_effect)

	preparation_workspace_host = Control.new()
	preparation_workspace_host.name = "PlanningWorkspaceHost"
	preparation_workspace_host.custom_minimum_size = Vector2(0.0, PREPARATION_PANEL_HEIGHT)
	preparation_workspace_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_workspace_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(preparation_workspace_host)
	preparation_workspace = GridContainer.new()
	preparation_workspace.name = "PlanningWorkspace"
	preparation_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preparation_workspace.columns = 2
	preparation_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preparation_workspace.add_theme_constant_override("h_separation", 14)
	preparation_workspace.add_theme_constant_override("v_separation", 14)
	preparation_workspace.resized.connect(_update_preparation_workspace_ratio)
	preparation_workspace_host.add_child(preparation_workspace)

	preparation_plan_panel = Panel.new()
	preparation_plan_panel.name = "PlanSection"
	preparation_plan_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_plan_panel.size_flags_stretch_ratio = 0.88
	preparation_plan_panel.custom_minimum_size = Vector2(0.0, PREPARATION_PANEL_HEIGHT)
	preparation_plan_panel.clip_contents = true
	preparation_plan_panel.add_theme_stylebox_override("panel", PreparationBioLumenStyle.frame())
	PreparationBioLumenSurfaceFill.attach_static(preparation_plan_panel)
	preparation_workspace.add_child(preparation_plan_panel)
	var plan_margin := _margin(14, 14, 14, 14)
	preparation_plan_panel.add_child(plan_margin)
	var plan_box := VBoxContainer.new()
	plan_box.add_theme_constant_override("separation", 10)
	plan_margin.add_child(plan_box)
	var plan_header := HBoxContainer.new()
	plan_header.add_theme_constant_override("separation", 10)
	plan_box.add_child(plan_header)
	var plan_title := _label("DEIN PLAN", 14, COLOR_TEXT)
	plan_title.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	plan_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_header.add_child(plan_title)
	preparation_capacity_label = _label("0 / 8 KAPAZITÄT", 12, Color("f0bc57"))
	preparation_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	plan_header.add_child(preparation_capacity_label)
	preparation_capacity_bar = ProgressBar.new()
	preparation_capacity_bar.custom_minimum_size = Vector2(0.0, 0.0)
	preparation_capacity_bar.show_percentage = false
	preparation_capacity_bar.add_theme_stylebox_override("background", _bar_style(Color("21363c"), 4))
	preparation_capacity_bar.add_theme_stylebox_override("fill", _bar_style(COLOR_TEAL, 4))
	preparation_capacity_bar.hide()
	plan_box.add_child(preparation_capacity_bar)
	preparation_slots = GridContainer.new()
	preparation_slots.name = "PlanSlots"
	preparation_slots.columns = 1
	preparation_slots.add_theme_constant_override("v_separation", 7)
	preparation_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_box.add_child(preparation_slots)
	for slot_id in LoadoutSlotId.planning():
		var slot := _build_preparation_slot_card(slot_id)
		slot.set_meta(&"slot_id", slot_id)
		slot.set_meta(&"stable_focus_id", slot_id)
		slot.gui_input.connect(_on_preparation_slot_gui_input)
		slot.pressed.connect(_on_preparation_slot_pressed.bind(slot_id))
		slot.mouse_entered.connect(_show_preparation_slot_preview.bind(slot_id, slot, true))
		slot.mouse_exited.connect(_hide_preparation_tooltip.bind(slot, true))
		slot.focus_entered.connect(_ensure_preparation_focus_visible.bind(slot))
		register_context_detail(slot, _preparation_slot_context_payload.bind(slot_id), false)
		preparation_slots.add_child(slot)
		preparation_slot_buttons[slot_id] = slot
	preparation_reserve_button = _secondary_button("Reserve wählen", COLOR_GOLD)
	preparation_reserve_button.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTION_CARD
	_apply_compact_selection_card_style(preparation_reserve_button, COLOR_TEAL)
	preparation_reserve_button.add_theme_font_size_override("font_size", 14)
	preparation_reserve_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_reserve_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	preparation_reserve_button.set_meta(&"stable_focus_id", LoadoutSlotId.RESERVE)
	preparation_reserve_button.pressed.connect(_begin_reserve_selection)
	preparation_reserve_button.hide()
	plan_box.add_child(preparation_reserve_button)
	# Compatibility field for the view model. The finding hint is already stated
	# in the case dossier; repeating it below the slots caused overflow and noise.
	preparation_synergy_label = _label("Der genaue Befund entsteht während der Behandlung.", 14, COLOR_MUTED)
	preparation_synergy_label.hide()
	plan_box.add_child(preparation_synergy_label)

	preparation_catalog_panel = Panel.new()
	preparation_catalog_panel.name = "PlanEditor"
	preparation_catalog_panel.custom_minimum_size = Vector2(380.0, PREPARATION_PANEL_HEIGHT)
	preparation_catalog_panel.clip_contents = true
	preparation_catalog_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_catalog_panel.size_flags_stretch_ratio = 1.12
	preparation_catalog_panel.add_theme_stylebox_override("panel", PreparationBioLumenStyle.frame())
	PreparationBioLumenSurfaceFill.attach_static(preparation_catalog_panel)
	preparation_workspace.add_child(preparation_catalog_panel)
	var editor_margin := _margin(14, 14, 14, 14)
	preparation_catalog_panel.add_child(editor_margin)
	preparation_editor_stack = VBoxContainer.new()
	preparation_editor_stack.add_theme_constant_override("separation", 8)
	editor_margin.add_child(preparation_editor_stack)
	var editor_header := HBoxContainer.new()
	editor_header.add_theme_constant_override("separation", 8)
	preparation_editor_stack.add_child(editor_header)
	preparation_editor_back_button = _nav_button("Plan", &"back", COLOR_MUTED)
	preparation_editor_back_button.custom_minimum_size.x = 96.0
	preparation_editor_back_button.pressed.connect(_cancel_preparation_editor)
	preparation_editor_back_button.hide()
	editor_header.add_child(preparation_editor_back_button)
	preparation_editor_title = _label("PLANPLATZ WÄHLEN", 14, COLOR_TEXT)
	preparation_editor_title.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	preparation_editor_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_editor_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	editor_header.add_child(preparation_editor_title)
	# Reserve the action width permanently so adding or removing a component does
	# not move the editor title. An empty slot intentionally shows no counter.
	var editor_action_host := CenterContainer.new()
	editor_action_host.name = "EditorHeaderAction"
	editor_action_host.custom_minimum_size = Vector2(88.0, 28.0)
	editor_action_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	editor_header.add_child(editor_action_host)
	var inline_remove = IconTextButtonComponent.new()
	inline_remove.configure("Entfernen", &"remove", COLOR_RED, 12.0, 3)
	preparation_remove_button = inline_remove
	preparation_remove_button.name = "RemoveSelectedSlot"
	_apply_preparation_remove_style(preparation_remove_button)
	preparation_remove_button.pressed.connect(_remove_selected_preparation_slot)
	preparation_remove_button.hide()
	editor_action_host.add_child(preparation_remove_button)
	preparation_editor_hint = _label("Wähle einen Planplatz.", 12, Color("88a8aa"))
	preparation_editor_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preparation_editor_hint.max_lines_visible = 2
	preparation_editor_stack.add_child(preparation_editor_hint)

	preparation_editor_browse = Panel.new()
	preparation_editor_browse.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preparation_editor_browse.add_theme_stylebox_override("panel", _document_inset_style(COLOR_BLUE))
	preparation_editor_stack.add_child(preparation_editor_browse)
	var browse_margin := _margin(18, 18, 18, 18)
	preparation_editor_browse.add_child(browse_margin)
	var browse_copy := VBoxContainer.new()
	browse_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	browse_copy.add_theme_constant_override("separation", 8)
	browse_margin.add_child(browse_copy)
	var browse_icon := SimpleIcon.new()
	browse_icon.custom_minimum_size = Vector2(42.0, 42.0)
	browse_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	browse_icon.configure(&"plan", COLOR_BLUE)
	browse_copy.add_child(browse_icon)
	var browse_title := _label("Planplatz zuerst", 18, COLOR_TEXT)
	browse_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	browse_copy.add_child(browse_title)
	var browse_text := _label("Dadurch ist immer eindeutig, welches Feld gefüllt oder ersetzt wird.", 14, COLOR_MUTED)
	browse_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	browse_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	browse_copy.add_child(browse_text)

	preparation_editor_picker = VBoxContainer.new()
	preparation_editor_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(preparation_editor_picker as VBoxContainer).add_theme_constant_override("separation", 8)
	preparation_editor_stack.add_child(preparation_editor_picker)
	preparation_catalog_scroll = ScrollContainer.new()
	preparation_catalog_scroll.name = "ComponentListViewport"
	# Candidate descriptions live in the floating hover/focus popover. The grid
	# can therefore use the complete editor height instead of reserving a fixed
	# comparison card below four oversized rows.
	preparation_catalog_scroll.custom_minimum_size = Vector2.ZERO
	preparation_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preparation_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preparation_catalog_scroll.follow_focus = true
	preparation_editor_picker.add_child(preparation_catalog_scroll)
	preparation_catalog = GridContainer.new()
	preparation_catalog.name = "ComponentRows"
	preparation_catalog.columns = 1
	preparation_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_catalog.add_theme_constant_override("h_separation", 8)
	preparation_catalog.add_theme_constant_override("v_separation", 8)
	preparation_catalog_scroll.add_child(preparation_catalog)
	# Compact mouse-only detail popover. It is positioned next to the hovered
	# card and never changes the grid geometry.
	preparation_inspector = PanelContainer.new()
	preparation_inspector.name = "ComponentTooltip"
	preparation_inspector.custom_minimum_size = Vector2(220.0, 0.0)
	preparation_inspector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparation_inspector.z_index = 200
	preparation_inspector.add_theme_stylebox_override("panel", PreparationBioLumenStyle.tooltip())
	overlay.add_child(preparation_inspector)
	var inspector_margin := _margin(12, 10, 12, 10)
	inspector_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparation_inspector.add_child(inspector_margin)
	var inspector_stack := VBoxContainer.new()
	inspector_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector_stack.add_theme_constant_override("separation", 4)
	inspector_margin.add_child(inspector_stack)
	preparation_inspector_title = _label("Alternative ansehen", 14, COLOR_TEXT)
	preparation_inspector_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparation_inspector_title.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	preparation_inspector_title.add_theme_color_override("font_color", Color("edf5ef"))
	inspector_stack.add_child(preparation_inspector_title)
	preparation_inspector_description = _label("Mauszeiger zeigt hier die Kurzinfo.", 13, COLOR_MUTED)
	preparation_inspector_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparation_inspector_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preparation_inspector_description.max_lines_visible = 2
	preparation_inspector_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inspector_stack.add_child(preparation_inspector_description)
	preparation_inspector_footer = GridContainer.new()
	preparation_inspector_footer.columns = 1
	preparation_inspector_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparation_inspector_footer.add_theme_constant_override("h_separation", 8)
	preparation_inspector_footer.add_theme_constant_override("v_separation", 4)
	inspector_stack.add_child(preparation_inspector_footer)
	preparation_inspector_meta = _label("", 12, COLOR_TEAL.lightened(0.22))
	preparation_inspector_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparation_inspector_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_inspector_meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preparation_inspector_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preparation_inspector_footer.add_child(preparation_inspector_meta)
	preparation_inspector.hide()
	preparation_editor_picker.hide()

	preparation_editor_confirm = VBoxContainer.new()
	preparation_editor_confirm.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	(preparation_editor_confirm as VBoxContainer).add_theme_constant_override("separation", 8)
	preparation_editor_stack.add_child(preparation_editor_confirm)
	preparation_confirm_compare = GridContainer.new()
	preparation_confirm_compare.name = "ReplacementComparison"
	preparation_confirm_compare.columns = 2
	preparation_confirm_compare.add_theme_constant_override("h_separation", 8)
	preparation_confirm_compare.add_theme_constant_override("v_separation", 8)
	preparation_editor_confirm.add_child(preparation_confirm_compare)
	var current_panel := Panel.new()
	current_panel.custom_minimum_size.y = 104.0
	current_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_panel.add_theme_stylebox_override("panel", _document_inset_style(COLOR_MUTED))
	preparation_confirm_compare.add_child(current_panel)
	var current_margin := _margin(10, 8, 10, 8)
	current_panel.add_child(current_margin)
	var current_stack := VBoxContainer.new()
	current_stack.add_theme_constant_override("separation", 3)
	current_margin.add_child(current_stack)
	current_stack.add_child(_label("BISHER", 14, COLOR_MUTED))
	preparation_confirm_current = _label("Nicht belegt", 16, COLOR_TEXT)
	preparation_confirm_current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preparation_confirm_current.max_lines_visible = 3
	current_stack.add_child(preparation_confirm_current)
	var candidate_panel := Panel.new()
	candidate_panel.custom_minimum_size.y = 104.0
	candidate_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_panel.add_theme_stylebox_override("panel", _document_inset_style(COLOR_GOLD))
	preparation_confirm_compare.add_child(candidate_panel)
	var candidate_margin := _margin(10, 8, 10, 8)
	candidate_panel.add_child(candidate_margin)
	var candidate_stack := VBoxContainer.new()
	candidate_stack.add_theme_constant_override("separation", 3)
	candidate_margin.add_child(candidate_stack)
	candidate_stack.add_child(_label("NEU", 14, COLOR_GOLD))
	preparation_confirm_candidate = _label("Komponente", 16, COLOR_TEXT)
	preparation_confirm_candidate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preparation_confirm_candidate.max_lines_visible = 3
	candidate_stack.add_child(preparation_confirm_candidate)
	preparation_confirm_capacity = _label("Kapazität unverändert", 14, COLOR_GOLD)
	preparation_editor_confirm.add_child(preparation_confirm_capacity)
	var confirm_actions := HBoxContainer.new()
	confirm_actions.add_theme_constant_override("separation", 8)
	preparation_editor_confirm.add_child(confirm_actions)
	preparation_cancel_replacement_button = _secondary_button("Abbrechen", COLOR_MUTED)
	preparation_cancel_replacement_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_cancel_replacement_button.pressed.connect(_cancel_preparation_replacement)
	confirm_actions.add_child(preparation_cancel_replacement_button)
	preparation_confirm_button = _primary_button("Ersetzen", COLOR_GOLD)
	preparation_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_confirm_button.pressed.connect(_confirm_preparation_replacement)
	confirm_actions.add_child(preparation_confirm_button)
	preparation_editor_confirm.hide()

	preparation_lock_panel = Panel.new()
	preparation_lock_panel.name = "IntroPlanLock"
	preparation_lock_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# It is the last child of the planning workspace, so tree order already keeps
	# it above the editor. A positive z-index would escape that local scope and
	# paint over later confirmation overlays.
	preparation_lock_panel.z_index = 0
	preparation_lock_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	preparation_lock_panel.add_theme_stylebox_override("panel", AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.MODAL_SHEET,
		COLOR_GOLD,
		AlveolusVisualTheme.CornerTreatment.CARD_6
	))
	preparation_workspace_host.add_child(preparation_lock_panel)
	var lock_center := CenterContainer.new()
	lock_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preparation_lock_panel.add_child(lock_center)
	preparation_lock_stack = VBoxContainer.new()
	preparation_lock_stack.custom_minimum_size.x = 320.0
	preparation_lock_stack.add_theme_constant_override("separation", 8)
	lock_center.add_child(preparation_lock_stack)
	preparation_lock_icon = SimpleIcon.new()
	preparation_lock_icon.custom_minimum_size = Vector2(58.0, 58.0)
	preparation_lock_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preparation_lock_icon.configure(&"locked", COLOR_GOLD)
	preparation_lock_stack.add_child(preparation_lock_icon)
	preparation_lock_title = _label("EINFÜHRUNGSPLAN", 20, COLOR_TEXT)
	preparation_lock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preparation_lock_stack.add_child(preparation_lock_title)
	preparation_lock_copy = _label("Der Plan ist für die Einführung festgelegt. Nach dem ersten Fall stellst du ihn selbst zusammen.", 14, COLOR_MUTED)
	preparation_lock_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preparation_lock_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preparation_lock_stack.add_child(preparation_lock_copy)
	preparation_lock_panel.tooltip_text = preparation_lock_copy.text
	preparation_lock_panel.hide()

	preparation_footer = HBoxContainer.new()
	preparation_footer.name = "PlanningActions"
	preparation_footer.add_theme_constant_override("separation", 10)
	page_body.add_child(preparation_footer)
	preparation_validation = _label("Wähle eine Grundbehandlung.", 14, COLOR_RED.lightened(0.18))
	preparation_validation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preparation_validation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preparation_validation.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preparation_footer.add_child(preparation_validation)
	var planning_start = IconTextButtonComponent.new()
	planning_start.configure("Behandlung starten", &"play", COLOR_TEAL, 20.0, 8)
	planning_start.set_content_on_light(true)
	preparation_start_button = planning_start
	preparation_start_button.custom_minimum_size = Vector2(220.0, AlveolusVisualTheme.BUTTON_HEIGHT_PRIMARY)
	preparation_start_button.clip_contents = true
	_apply_preparation_primary_style(preparation_start_button)
	PreparationBioLumenFill.attach(preparation_start_button, AlveolusVisualTheme.TURQUOISE, COLOR_GOLD)
	UISoundService.set_sound_role(preparation_start_button, UISoundService.RUN_START)
	preparation_start_button.pressed.connect(func() -> void: preparation_start_requested.emit(current_preparation_snapshot.duplicate(true)))
	preparation_footer.add_child(preparation_start_button)
	return overlay

func _build_upgrade_overlay() -> Control:
	upgrade_screen = UpgradeOverlay.new()
	upgrade_screen.name = "UpgradeOverlay"
	upgrade_screen.upgrade_selected.connect(_on_upgrade_id_selected)
	upgrade_screen.reroll_requested.connect(func() -> void: reroll_requested.emit())
	upgrade_screen.cancel_requested.connect(func() -> void: back_requested.emit())
	upgrade_panel = upgrade_screen.modal_sheet()
	upgrade_cards = upgrade_screen.cards_grid()
	upgrade_education = upgrade_screen.education_panel()
	reroll_button = upgrade_screen.reroll_action()
	return upgrade_screen

func _on_upgrade_id_selected(upgrade_id: StringName) -> void:
	for definition in current_upgrade_options:
		if definition != null and definition.id == upgrade_id:
			upgrade_chosen.emit(definition)
			return

func _build_pause_overlay() -> Control:
	pause_screen = PauseOverlay.new()
	pause_screen.resume_requested.connect(func() -> void: resume_requested.emit())
	pause_screen.settings_requested.connect(func() -> void: navigate_requested.emit(&"settings"))
	pause_screen.stats_requested.connect(_show_pause_stats)
	pause_screen.abort_requested.connect(func() -> void: abort_requested.emit())
	pause_screen.intro_skip_requested.connect(func() -> void: intro_skip_requested.emit())
	pause_screen.back_requested.connect(func() -> void:
		if pause_screen.current_mode() == PauseOverlay.Mode.STATS:
			_hide_pause_stats()
		else:
			resume_requested.emit()
	)
	pause_panel = pause_screen.modal_sheet()
	pause_resume_button = pause_screen.resume_action()
	pause_skip_button = pause_screen.intro_skip_action()
	pause_stats_panel = pause_panel
	pause_stats_grid = pause_screen.stats_grid()
	pause_stats_scroll = pause_screen.body_scroll()
	pause_stats_back_button = pause_screen.back_action()
	return pause_screen


func _build_pause_stats_overlay() -> Control:
	var marker := Control.new()
	marker.name = "PauseStatsCompatibilityState"
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.process_mode = Node.PROCESS_MODE_DISABLED
	marker.hide()
	return marker


func _build_abort_overlay() -> Control:
	abort_confirmation = ConfirmationOverlay.new()
	abort_confirmation.name = "AbortConfirmation"
	abort_confirmation.confirm.connect(func() -> void: abort_confirmed.emit())
	abort_confirmation.cancel.connect(func() -> void: abort_cancelled.emit())
	_apply_abort_confirmation()
	return abort_confirmation

func _build_intro_skip_overlay() -> Control:
	intro_skip_confirmation = ConfirmationOverlay.new()
	intro_skip_confirmation.name = "IntroSkipConfirmation"
	intro_skip_confirmation.confirm.connect(func() -> void: intro_skip_confirmed.emit())
	intro_skip_confirmation.cancel.connect(func() -> void: intro_skip_cancelled.emit())
	_apply_intro_skip_confirmation()
	return intro_skip_confirmation

func _build_restart_overlay() -> Control:
	restart_confirmation = ConfirmationOverlay.new()
	restart_confirmation.name = "RestartConfirmation"
	restart_confirmation.confirm.connect(func() -> void: restart_confirmed.emit())
	restart_confirmation.cancel.connect(func() -> void: restart_cancelled.emit())
	_apply_restart_confirmation()
	return restart_confirmation

func _apply_abort_confirmation() -> void:
	if abort_confirmation == null:
		return
	abort_confirmation_revision += 1
	abort_confirmation.apply_view_model(ConfirmationOverlayViewModel.new(
		abort_confirmation_revision,
		"Level abbrechen?",
		"Der Fortschritt dieses Runs und die mögliche Forschungsbelohnung gehen verloren.",
		"Abbrechen",
		"Zurück",
		true
	))
	abort_panel = abort_confirmation.modal_sheet()

func _apply_intro_skip_confirmation() -> void:
	if intro_skip_confirmation == null:
		return
	intro_skip_confirmation_revision += 1
	intro_skip_confirmation.apply_view_model(ConfirmationOverlayViewModel.new(
		intro_skip_confirmation_revision,
		"Einführung überspringen?",
		"Fall 1 wird freigeschaltet. Es gibt keine Forschung, keinen Sieg und keinen Versuchseintrag. Die Einführung bleibt wiederholbar.",
		"Intro überspringen",
		"Zurück",
		false
	))
	intro_skip_panel = intro_skip_confirmation.modal_sheet()

func _apply_restart_confirmation() -> void:
	if restart_confirmation == null:
		return
	restart_confirmation_revision += 1
	restart_confirmation.apply_view_model(ConfirmationOverlayViewModel.new(
		restart_confirmation_revision,
		"Runde neu starten?",
		"Der aktuelle Run beginnt sofort von vorn. Fall, Plan und Seed bleiben gleich.",
		"Neu starten",
		"Zurück",
		false
	))
	restart_panel = restart_confirmation.modal_sheet()

func _build_finding_overlay() -> Control:
	finding_screen = FindingOverlay.new()
	finding_screen.reaction_selected.connect(func(id: StringName) -> void:
		current_finding_reaction = id
		finding_reaction_selected.emit(id)
	)
	finding_screen.swap_toggled.connect(func(_enabled: bool) -> void: _emit_finding_swap_preview_from_screen())
	finding_screen.outgoing_selected.connect(func(_id: StringName) -> void: _emit_finding_swap_preview_from_screen())
	finding_screen.confirm.connect(func(reaction_id: StringName, incoming_id: StringName, outgoing_id: StringName) -> void:
		finding_confirmed.emit(reaction_id, incoming_id, outgoing_id)
	)
	return finding_screen


func _build_end_overlay() -> Control:
	result_screen = ResultOverlay.new()
	result_screen.name = "ResultOverlay"
	result_screen.retry.connect(func() -> void: retry_requested.emit())
	result_screen.levels.connect(func() -> void: result_levels_requested.emit())
	result_screen.campus.connect(func() -> void: result_campus_requested.emit())
	return result_screen

func show_campus(meta: MetaProgressionState, jobs: Dictionary) -> void:
	_hide_all()
	campus_overlay.modulate = Color.WHITE
	refresh_campus(meta, jobs)
	campus_overlay.show()
	_focus_first_button.call_deferred(campus_overlay)

func refresh_campus(meta: MetaProgressionState, jobs: Dictionary) -> void:
	var job_status := "Kein Klinikfall aktiv"
	if meta.active_job_id != &"" and jobs.has(meta.active_job_id):
		job_status = "Belohnung bereit" if meta.is_job_complete() else "Klinikfall läuft"
	var research_amount := "∞" if meta.is_unlimited_test_progression() else str(meta.research_points)
	campus_research_status.text = "FORSCHUNG  %s" % research_amount
	campus_clinic_status.text = job_status.to_upper()
	var practice_button: CampusBuildingCard = campus_buttons[&"practice"]
	var practice_badge := "%d Forschung abholbar" % meta.claimable_research() if meta.claimable_research() > 0 else job_status
	practice_button.set_status(practice_badge, meta.claimable_research() > 0 or meta.is_job_complete())
	var research_button: CampusBuildingCard = campus_buttons[&"research"]
	var active_research := 0
	for rank_value in meta.research_ranks.values():
		if int(rank_value) > 0:
			active_research += 1
	var research_status := "∞ · %d aktiv" % active_research if meta.is_unlimited_test_progression() else "%d Punkte · %d aktiv" % [meta.research_points, active_research]
	research_button.set_status(research_status, meta.is_unlimited_test_progression() or meta.research_points > 0)
	var level_button: CampusBuildingCard = campus_buttons[&"levels"]
	level_button.set_status("%d / 4 Fälle frei" % [meta.highest_unlocked_level + 1], true)
	var lexicon_button: CampusBuildingCard = campus_buttons[&"lexicon"]
	lexicon_button.set_status("%d entdeckt" % meta.seen_discovery_ids.size(), meta.seen_discovery_ids.size() > 0)
	var settings_button: CampusBuildingCard = campus_buttons[&"settings"]
	settings_button.set_status("Anzeige · Audio", false)

func show_practice(meta: MetaProgressionState, jobs: Dictionary) -> void:
	_hide_all()
	_show_campus_context()
	practice_overlay.show()
	refresh_practice(meta, jobs)
	var preferred := practice_screen.default_focus_control()
	_prepare_optional_navigation_focus.call_deferred(practice_overlay, preferred)

func refresh_practice(meta: MetaProgressionState, jobs: Dictionary) -> void:
	practice_view_revision += 1
	var claimable := meta.claimable_research()
	var has_job := meta.active_job_id != &"" and jobs.has(meta.active_job_id)
	var job_complete := has_job and meta.is_job_complete()
	var offline := PracticeScreenViewModel.OfflineResearchViewModel.create(
		"%s gespeichert" % _format_duration(floori(meta.passive_seconds), false),
		"8 Stunden",
		"%d Forschung abholen" % claimable if claimable > 0 else "Noch nichts abholbar",
		claimable,
		claimable > 0
	)
	var clinic := PracticeScreenViewModel.ClinicStatusViewModel.idle()
	if has_job:
		var active: ClinicJobDefinition = jobs[meta.active_job_id]
		var remaining := meta.job_seconds_remaining()
		var elapsed := active.duration_seconds - remaining
		clinic = PracticeScreenViewModel.ClinicStatusViewModel.create(
			true,
			active.id,
			"%s abgeschlossen · Belohnung bereit" % active.title if job_complete else "%s läuft" % active.title,
			job_complete,
			clampi(elapsed, 0, active.duration_seconds),
			active.duration_seconds,
			"%s verbleibend" % _format_duration(remaining, true),
			"+%d Forschung" % active.reward,
			"Abgeschlossen um %s" % _local_time(meta.job_finishes_at) if job_complete else "Voraussichtlich fertig um %s" % _local_time(meta.job_finishes_at)
		)
	var offers: Array[PracticeScreenViewModel.ClinicJobOfferViewModel] = []
	for id in [&"short_review", &"follow_up", &"complex_case"]:
		if not jobs.has(id):
			continue
		var definition: ClinicJobDefinition = jobs[id]
		offers.append(PracticeScreenViewModel.ClinicJobOfferViewModel.create(
			id,
			definition.title,
			definition.duration_text(),
			"+%d Forschung" % definition.reward,
			true
		))
	var model := PracticeScreenViewModel.create(
		practice_view_revision,
		"Forschung ∞" if meta.is_unlimited_test_progression() else "Forschung %d" % meta.research_points,
		offline,
		clinic,
		offers
	)
	practice_screen.apply_view_model(model)
	clinic_offer_buttons.clear()
	for offer in offers:
		clinic_offer_buttons[offer.id()] = practice_screen.clinic_job_action(offer.id())

func show_research(meta: MetaProgressionState, definitions: Array[ResearchDefinition]) -> void:
	_hide_all()
	_show_campus_context()
	current_research_tab = &"research"
	refresh_research(meta, definitions)
	research_overlay.show()
	_prepare_optional_navigation_focus.call_deferred(research_overlay, progression_screen.default_focus_control())


func show_research_tabs(meta: MetaProgressionState, definitions: Array[ResearchDefinition], talent_view: Variant) -> void:
	_hide_all()
	_show_campus_context()
	current_research_tab = &"research"
	_refresh_progression_research_cache(meta, definitions)
	var resolved_talents: Variant = _talent_view_from_meta(meta, talent_view) if talent_view is Array else talent_view
	_refresh_progression_talent_cache(resolved_talents)
	_apply_progression_screen_model()
	research_overlay.show()
	_prepare_optional_navigation_focus.call_deferred(research_overlay, progression_screen.default_focus_control())


func refresh_research(meta: MetaProgressionState, definitions: Array[ResearchDefinition]) -> void:
	_refresh_progression_research_cache(meta, definitions)
	_apply_progression_screen_model()


func refresh_talents(talent_view: Variant) -> void:
	_refresh_progression_talent_cache(talent_view)
	_apply_progression_screen_model()


func _refresh_progression_research_cache(meta: MetaProgressionState, definitions: Array[ResearchDefinition]) -> void:
	progression_research_items.clear()
	progression_research_balance = "Forschung  ∞ · Testmodus" if meta.is_unlimited_test_progression() else "Forschung  %d" % meta.research_points
	var module_definitions := ContentCatalog.loadout_module_definitions()
	for definition in definitions:
		var rank := meta.rank(definition.id)
		var maximum := rank >= definition.max_level
		var cost := 0 if maximum else definition.cost_for_rank(rank)
		var purchase_enabled := LoadoutAvailabilityPolicy.research_purchase_enabled(definition)
		var available := purchase_enabled and not maximum and meta.can_afford_research(cost)
		var state := ProgressionScreenViewModel.ItemState.LOCKED if not purchase_enabled else (ProgressionScreenViewModel.ItemState.ACTIVE if maximum else (ProgressionScreenViewModel.ItemState.AVAILABLE if available else ProgressionScreenViewModel.ItemState.LOCKED))
		var rank_text := "Rang %d/%d" % [rank, definition.max_level]
		var cost_text := "Maximum" if maximum else "%d Forschung" % cost
		var state_text := LoadoutAvailabilityPolicy.research_status(definition, module_definitions) if not purchase_enabled else ("Abgeschlossen" if maximum else ("Verfügbar" if available else "Nicht genug Forschung"))
		var info := ProgressionScreenViewModel.InfoViewModel.create(
			definition.title,
			definition.description,
			"%s · %s" % [rank_text, state_text],
			definition.id,
			COLOR_GOLD
		)
		progression_research_items.append(ProgressionScreenViewModel.ResearchItemViewModel.create(
			definition.id,
			definition.title,
			rank_text,
			cost_text,
			definition.id,
			state,
			available,
			info
		))


func _refresh_progression_talent_cache(talent_view: Variant) -> void:
	progression_talent_branches.clear()
	var total := int(_view_value(talent_view, &"total_points", 0))
	var spent := int(_view_value(talent_view, &"spent_points", 0))
	var unlimited := bool(_view_value(talent_view, &"unlimited", false))
	var available_points := MetaProgressionState.UNLIMITED_TEST_POINT_POOL if unlimited else maxi(0, total - spent)
	var refunded := bool(_view_value(talent_view, &"tree_refunded", false))
	var balance := "Unbegrenzte Talentpunkte · %d verteilt" % spent if unlimited else "%d Talentpunkte · %d frei · %d verteilt" % [total, available_points, spent]
	progression_talent_balance = "Talentbaum erneuert · Punkte zurück · %s" % balance if refunded else balance
	progression_talent_reset_enabled = spent > 0
	var grouped: Dictionary = {}
	for talent in _variant_array(_view_value(talent_view, &"talents", [])):
		var category := _talent_category_text(_view_value(talent, &"category", &""))
		var category_items: Array = grouped.get(category, [])
		category_items.append(talent)
		grouped[category] = category_items
	for category in ["BEHANDLUNG"]:
		var node_models: Array = []
		for talent in grouped.get(category, []):
			var id := StringName(_view_value(talent, &"id", &""))
			var title := String(_view_value(talent, &"title", "Talent"))
			var description := String(_view_value(talent, &"description", _view_value(talent, &"effect", "")))
			var cost := int(_view_value(talent, &"cost", 1))
			var active := bool(_view_value(talent, &"active", false))
			var current_rank := int(_view_value(talent, &"current_rank", 1 if active else 0))
			var max_rank := maxi(1, int(_view_value(talent, &"max_rank", 1)))
			var maximum := bool(_view_value(talent, &"maximum", current_rank >= max_rank))
			var unlocked := bool(_view_value(talent, &"unlocked", true))
			var prerequisite_met := bool(_view_value(talent, &"prerequisite_met", true))
			var interactive := not maximum and unlocked and prerequisite_met and available_points >= cost
			var state := ProgressionScreenViewModel.ItemState.ACTIVE if active else (ProgressionScreenViewModel.ItemState.AVAILABLE if interactive else ProgressionScreenViewModel.ItemState.LOCKED)
			var requirement := String(_view_value(talent, &"requirement_text", "Einstieg des Astes"))
			if maximum:
				requirement = "Maximaler Rang erreicht"
			elif not unlocked:
				requirement = "Noch nicht freigeschaltet"
			elif not prerequisite_met:
				requirement = "Benötigt %s" % requirement
			elif not active and available_points < cost:
				requirement = "%d Talentpunkte fehlen" % (cost - available_points)
			var accent := _talent_branch_accent(category)
			var icon_kind := _talent_icon_kind(category)
			var info := ProgressionScreenViewModel.InfoViewModel.create(
				title,
				description,
				"Rang %d/%d · %s" % [current_rank, max_rank, requirement],
				icon_kind,
				accent
			)
			node_models.append(ProgressionScreenViewModel.TalentNodeViewModel.create(
				id,
				title,
				"%d/%d · %s" % [current_rank, max_rank, "Max" if maximum else "%dP" % cost],
				icon_kind,
				int(_view_value(talent, &"tree_tier", 0)),
				int(_view_value(talent, &"tree_lane", 1)),
				PackedStringArray(_view_value(talent, &"required_ids", PackedStringArray())),
				state,
				interactive,
				info
			))
		if node_models.is_empty():
			continue
		var branch_id := &"treatment"
		progression_talent_branches.append(ProgressionScreenViewModel.TalentBranchViewModel.create(
			branch_id,
			"Behandlungen",
			_talent_icon_kind(category),
			_talent_branch_accent(category),
			node_models
		))


func _apply_progression_screen_model() -> void:
	if progression_screen == null:
		return
	progression_view_revision += 1
	var model := ProgressionScreenViewModel.create(
		progression_view_revision,
		current_research_tab,
		progression_research_balance,
		progression_talent_balance,
		progression_talent_reset_enabled,
		progression_research_items,
		progression_talent_branches
	)
	progression_screen.apply_view_model(model)
	_register_progression_context_sources()
	_map_progression_compatibility_controls()


func _register_progression_context_sources() -> void:
	if context_detail_controller == null or progression_screen == null:
		return
	var registrations := progression_screen.context_detail_registrations()
	context_detail_controller.sync_sources(
		progression_screen.context_detail_scope_id(),
		registrations
	)
	progression_context_sources.clear()
	for registration in registrations:
		var source := registration.get("source") as Control
		if source != null and is_instance_valid(source):
			progression_context_sources.append(source)


func _map_progression_compatibility_controls() -> void:
	if progression_screen == null:
		return
	research_overlay = progression_screen
	research_tab_button = progression_screen.research_tab_action()
	talent_tab_button = progression_screen.talent_tab_action()
	research_tab_row = progression_screen.find_child("ProgressionTabs", true, false) as GridContainer
	research_points_label = progression_screen.find_child("ProgressionBalance", true, false) as Label
	talent_points_label = research_points_label
	research_scroll = progression_screen.research_scroll()
	talent_scroll = progression_screen.talent_scroll()
	research_content = research_scroll
	talent_content = talent_scroll
	research_grid = progression_screen.find_child("ResearchGrid", true, false) as GridContainer
	talent_grid = progression_screen.find_child("TalentBranches", true, false) as GridContainer
	talent_reset_button = progression_screen.talent_reset_action()
	talent_summary_grid = null
	research_inspector_panel = null
	talent_inspector_panel = null
	research_buy_buttons.clear()
	talent_buttons.clear()
	talent_tree_branches.clear()
	for item in progression_research_items:
		var research_id := StringName(item.id())
		var research_button := progression_screen.research_action(research_id)
		if research_button != null:
			research_buy_buttons[research_id] = research_button
	for branch_model in progression_talent_branches:
		var branch := progression_screen.talent_branch(branch_model.id())
		if branch != null:
			talent_tree_branches.append(branch)
		for node_model in branch_model.nodes():
			var talent_button := progression_screen.talent_action(node_model.id())
			if talent_button != null:
				talent_buttons[node_model.id()] = talent_button


func _on_progression_tab_changed(tab: StringName) -> void:
	current_research_tab = &"talents" if tab == &"talents" else &"research"
	research_tab_changed.emit(current_research_tab)


func _add_talent_tree_branch(category: String, talents: Array, available_points: int) -> void:
	var accent := _talent_branch_accent(category)
	var panel := Panel.new()
	panel.name = "TalentBranch_%s" % category.to_lower()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _section_surface_style(accent))
	talent_grid.add_child(panel)
	var margin := _margin(10, 9, 10, 10)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	stack.add_child(_section_header(category, _talent_icon_kind(category), accent))
	var branch := TalentTreeBranch.new()
	branch.name = "Tree"
	branch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branch.configure_accent(accent)
	stack.add_child(branch)
	talent_tree_branches.append(branch)
	for talent in talents:
		var id := StringName(_view_value(talent, &"id", &""))
		var title := String(_view_value(talent, &"title", "Talent"))
		var effect := String(_view_value(talent, &"description", _view_value(talent, &"effect", "")))
		var cost := int(_view_value(talent, &"cost", 1))
		var active := bool(_view_value(talent, &"active", false))
		var unlocked := bool(_view_value(talent, &"unlocked", true))
		var prerequisite_met := bool(_view_value(talent, &"prerequisite_met", true))
		var required_ids := PackedStringArray(_view_value(talent, &"required_ids", PackedStringArray()))
		var requirement_text := String(_view_value(talent, &"requirement_text", "Einstieg des Astes"))
		var active_dependents := PackedStringArray(_view_value(talent, &"active_dependents", PackedStringArray()))
		var can_deactivate := active_dependents.is_empty()
		var selectable := (active and can_deactivate) or (not active and unlocked and prerequisite_met and available_points >= cost)
		var state := &"active" if active else (&"available" if selectable else &"locked")
		var status := ("✓ AKTIV · NACHFOLGER AKTIV" if not can_deactivate else "✓ AKTIV") if active else ("BRAUCHT %s" % requirement_text.to_upper() if not prerequisite_met else ("GESPERRT" if not unlocked else ("%d P FEHLEN" % (cost - available_points) if available_points < cost else "VERFÜGBAR")))
		var inspector_requirement := "Zuerst deaktivieren: %s" % ", ".join(active_dependents) if active and not can_deactivate else requirement_text
		var button := Button.new()
		button.name = "Talent_%s" % String(id)
		button.custom_minimum_size = Vector2(0.0, TalentTreeBranch.NODE_HEIGHT)
		button.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTION_CARD
		button.clip_contents = true
		button.toggle_mode = true
		button.set_pressed_no_signal(active)
		button.focus_mode = Control.FOCUS_ALL
		button.set_meta(&"stable_focus_id", id)
		button.set_meta(&"talent_active", active)
		button.set_meta(&"talent_selectable", selectable)
		button.set_meta(&"talent_status", status)
		UISoundService.set_sound_role(button, UISoundService.CONFIRM if selectable else UISoundService.ERROR)
		# Hover and explicit ui_info share one immutable payload. Focus alone stays quiet.
		button.tooltip_text = ""
		var surface_accent := accent if selectable or active else COLOR_MUTED.darkened(0.18)
		button.add_theme_stylebox_override("normal", AlveolusVisualTheme.case_card_style(surface_accent, &"selected" if active else (&"normal" if selectable else &"disabled")))
		button.add_theme_stylebox_override("hover", AlveolusVisualTheme.case_card_style(surface_accent, &"hover" if selectable or active else &"disabled"))
		button.add_theme_stylebox_override("pressed", AlveolusVisualTheme.case_card_style(surface_accent, &"pressed"))
		button.add_theme_stylebox_override("focus", AlveolusVisualTheme.case_card_style(surface_accent, &"focus"))
		button.pressed.connect(_emit_talent_toggle.bind(id))
		register_context_detail(
			button,
			_talent_context_payload.bind(title, effect, category, cost, status, inspector_requirement)
		)
		talent_buttons[id] = button
		var button_margin := _margin(8, 6, 8, 6)
		button_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(button_margin)
		var content := HBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 6)
		button_margin.add_child(content)
		var icon := SimpleIcon.new()
		icon.custom_minimum_size = Vector2(24.0, 24.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.configure(_talent_icon_kind(category), accent if selectable or active else COLOR_MUTED)
		content.add_child(icon)
		var title_label := _label(title, 14, COLOR_TEXT if selectable or active else COLOR_MUTED)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(title_label)
		var cost_label := _label("%dP" % cost, 14, COLOR_GOLD if selectable or active else COLOR_MUTED)
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(cost_label)
		if active or not selectable:
			var state_icon := SimpleIcon.new()
			state_icon.name = "StateIcon"
			state_icon.custom_minimum_size = Vector2(20.0, 20.0)
			state_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			state_icon.configure(&"check" if active else &"locked", COLOR_TEAL if active else COLOR_MUTED)
			content.add_child(state_icon)
		branch.add_talent_node(
			id,
			button,
			int(_view_value(talent, &"tree_tier", 0)),
			int(_view_value(talent, &"tree_lane", 1)),
			required_ids,
			state
		)
	# A Panel does not derive its minimum size from regular Control children.
	# Report the complete branch height explicitly so one-column/200%-grids
	# stack branches instead of painting all three trees into the same row.
	panel.custom_minimum_size.y = branch.custom_minimum_size.y + 54.0

func _talent_branch_accent(category: String) -> Color:
	match category:
		"BEHANDLUNG": return COLOR_TEAL
		"PLANUNG": return COLOR_GOLD
		"DIAGNOSE": return COLOR_RED
		"EINSATZ": return COLOR_BLUE
	return COLOR_TEAL

func _talent_view_from_meta(meta: MetaProgressionState, definitions: Array) -> Dictionary:
	var cards: Array = []
	var definition_titles: Dictionary = {}
	for definition in definitions:
		definition_titles[StringName(_view_value(definition, &"id", &""))] = String(_view_value(definition, &"title", "Talent"))
	for definition in definitions:
		var required_ids: Variant = _view_value(definition, &"required_ids", [])
		var definition_id := StringName(_view_value(definition, &"id", &""))
		var current_rank := meta.talent_rank(definition_id)
		var max_rank := maxi(1, int(_view_value(definition, &"max_rank", 1)))
		var maximum := current_rank >= max_rank
		var next_cost := 0
		if not maximum and definition is TalentDefinition:
			next_cost = (definition as TalentDefinition).cost_for_rank(current_rank)
		elif not maximum:
			next_cost = int(_view_value(definition, &"cost", 1))
		var prerequisites_met := true
		var requirement_titles := PackedStringArray()
		var active_dependents := PackedStringArray()
		for required_id in required_ids:
			requirement_titles.append(String(definition_titles.get(StringName(required_id), String(required_id))))
			if not meta.has_talent(StringName(required_id)):
				prerequisites_met = false
				break
		for candidate in definitions:
			var candidate_id := StringName(_view_value(candidate, &"id", &""))
			var candidate_requirements := PackedStringArray(_view_value(candidate, &"required_ids", PackedStringArray()))
			if meta.has_talent(candidate_id) and candidate_requirements.has(String(definition_id)):
				active_dependents.append(String(_view_value(candidate, &"title", String(candidate_id))))
		cards.append({
			"id": definition_id,
			"title": _view_value(definition, &"title", "Talent"),
			"description": _view_value(definition, &"description", ""),
			"cost": next_cost,
			"category": &"treatment",
			"active": current_rank > 0,
			"current_rank": current_rank,
			"max_rank": max_rank,
			"maximum": maximum,
			"prerequisite_met": prerequisites_met,
			"required_ids": PackedStringArray(required_ids),
			"active_dependents": active_dependents,
			"requirement_text": " + ".join(requirement_titles) if not requirement_titles.is_empty() else "Einstieg des Astes",
			"tree_tier": _view_value(definition, &"tree_tier", 0),
			"tree_lane": _view_value(definition, &"tree_lane", 1),
		})
	return {
		"total_points": meta.talent_points_earned(),
		"spent_points": meta.talent_points_spent(),
		"unlimited": meta.is_unlimited_test_progression(),
		"tree_refunded": meta.talent_tree_refund_pending,
		"talents": cards,
	}

func show_level_select(meta: MetaProgressionState, levels: Array[LevelDefinition]) -> void:
	_hide_all()
	_show_campus_context()
	level_view_revision += 1
	var entries: Array[CaseArchiveViewModel.CaseEntryViewModel] = []
	for level in levels:
		var unlocked := meta.is_level_unlocked(level.order)
		var record := meta.get_level_record(level.id)
		var status := "GESPERRT" if not unlocked else ("ABGESCHLOSSEN" if record.victories > 0 else "BEREIT")
		var record_summary := "Noch kein Sieg"
		if record.victories > 0:
			record_summary = "%d %s · Lv %d · %d Bakt." % [
				record.victories,
				"Sieg" if record.victories == 1 else "Siege",
				record.highest_analysis,
				record.best_defeats,
			]
		entries.append(CaseArchiveViewModel.CaseEntryViewModel.new(
			level.id,
			level.order,
			_level_card_title(level),
			"%s · %s" % ["INTRO" if level.is_tutorial else "FALL %02d" % level.order, status],
			"",
			"",
			record_summary,
			level.is_tutorial,
			unlocked,
			_level_accent(level)
		))
	level_screen.apply_view_model(CaseArchiveViewModel.new(level_view_revision, entries, &""))
	level_buttons.clear()
	level_card_labels.clear()
	for level in levels:
		var button := level_screen.card_for_case(level.id)
		if button == null:
			continue
		level_buttons[level.id] = button
		level_card_labels[level.id] = {
			"status": button.find_child("Status", true, false),
			"title": button.find_child("Title", true, false),
			"facts": button.find_child("Facts", true, false),
			"best": button.find_child("Best", true, false),
			"record": button.find_child("Record", true, false),
		}
	level_overlay.show()
	level_screen.grab_initial_focus.call_deferred()

func show_lexicon(meta: MetaProgressionState) -> void:
	_hide_all()
	_show_campus_context()
	lexicon_overlay.show()
	if lexicon_master_detail != null:
		var lexicon_stats := PlayerStats.new()
		lexicon_stats.apply_meta_progression(meta.research_ranks)
		lexicon_master_detail.configure(
			LexiconViewModelProvider.new(ContentCatalog.enemy_definitions(), ContentCatalog.discovery_definitions(), lexicon_stats, TreatmentDefinition.catalog()),
			meta.seen_discovery_ids,
			LexiconCatalog.entries()
		)
		_configure_focus_cycle.call_deferred(lexicon_overlay)
		lexicon_master_detail.grab_initial_focus.call_deferred()

func cancel_lexicon_step() -> bool:
	return lexicon_master_detail != null and lexicon_master_detail.cancel_step()

func show_story() -> void:
	_hide_all()
	story_index = 0
	if story_view_model == null:
		story_view_model = StoryScreenViewModel.create([
			{"id": &"welcome", "title": "Willkommen bei ALVEOLUS", "body": "Du leitest ALVEOLUS, einen kleinen Forschungscampus für schwierige Lungenfälle.", "next_label": "Weiter"},
			{"id": &"lung_model", "title": "Das Lungenmodell", "body": "Jeder Fall wird als begehbares Lungenmodell dargestellt. Du koordinierst die Behandlung direkt im Modell.", "next_label": "Weiter"},
			{"id": &"mission", "title": "Deine Aufgabe", "body": "Stoppe Bakterien, stärke die Abwehr und halte Doctor Milos am Leben. Gesammelte Proben helfen dem Campus weiter.", "next_label": "Zum Campus"},
		], 1, &"prologue", true, true, "Überspringen")
	story_screen.present(story_view_model, story_index, false)
	_prepare_optional_navigation_focus.call_deferred(story_overlay, story_next_button)

func configure_input_glyphs(service: InputGlyphService) -> void:
	if input_glyph_service != null and input_glyph_service.input_method_changed.is_connected(_on_input_method_changed):
		input_glyph_service.input_method_changed.disconnect(_on_input_method_changed)
	input_glyph_service = service
	if input_glyph_service != null:
		input_glyph_service.input_method_changed.connect(_on_input_method_changed)
	_refresh_input_glyphs()

func register_context_detail(
	source: Control,
	provider: Callable,
	hover_enabled: bool = true,
	anchor: Control = null,
	placement: int = ContextDetailController.Placement.AUTO
) -> void:
	if context_detail_controller != null:
		context_detail_controller.register_source(source, provider, hover_enabled, anchor, placement)

func toggle_focused_context_detail(focus_owner: Control) -> bool:
	return context_detail_controller != null and context_detail_controller.toggle_focused(focus_owner)

func close_context_detail() -> void:
	if context_detail_controller != null:
		context_detail_controller.close_explicit()

func close_all_context_details() -> void:
	if context_detail_controller != null:
		context_detail_controller.close_all()

func is_context_detail_open() -> bool:
	return context_detail_controller != null and context_detail_controller.is_open()

func is_context_detail_explicit() -> bool:
	return context_detail_controller != null and context_detail_controller.is_explicit()

func configure_ui_settings(settings: UISettingsState) -> void:
	_clear_binding_interaction()
	current_ui_settings = settings.duplicate_settings() if settings != null else UISettingsState.new()
	reduced_motion_enabled = current_ui_settings.reduce_motion
	_refresh_settings_screen(settings_show_quit)
	_apply_ui_scale()
	_apply_reduced_motion()
	_refresh_input_glyphs()

func _on_input_method_changed(_method: StringName) -> void:
	_refresh_input_glyphs()

func _refresh_input_glyphs() -> void:
	if input_glyph_service != null:
		for slot_index in range(ability_key_labels.size()):
			var action := &"active_ability_1" if slot_index == 0 else &"active_ability_2"
			var icon := input_glyph_service.icon_for_action(action)
			var has_icon := icon != null and slot_index < ability_key_icons.size()
			ability_key_labels[slot_index].text = input_glyph_service.glyph_for_action(action)
			ability_key_labels[slot_index].visible = not has_icon
			if slot_index < ability_key_containers.size():
				var fallback_width := clampf(18.0 + float(ability_key_labels[slot_index].text.length()) * 6.0, 28.0, 64.0)
				ability_key_containers[slot_index].custom_minimum_size.x = 28.0 if has_icon else fallback_width
			if slot_index < ability_key_icons.size():
				ability_key_icons[slot_index].texture = icon
				ability_key_icons[slot_index].visible = has_icon
			if slot_index < run_hud_ability_rows.size():
				var ability_row: Dictionary = run_hud_ability_rows[slot_index]
				ability_row["key_glyph_text"] = input_glyph_service.glyph_for_action(action)
				run_hud_ability_rows[slot_index] = ability_row
		if run_hud_screen != null:
			run_hud_screen.pause_action().tooltip_text = "Pause · %s" % input_glyph_service.glyph_for_action(&"pause_game")
			_apply_run_hud_model()
		if pause_resume_button != null:
			# The pause action already owns the screen. Repeating a large ESC/Menu
			# glyph inside the primary button duplicated its caption and broke its
			# height. Keep the binding discoverable as a tooltip instead.
			pause_resume_button.icon = null
			pause_resume_button.text = ""
			if pause_resume_button is IconTextButton:
				(pause_resume_button as IconTextButton).set_caption("Weiter")
			pause_resume_button.tooltip_text = "Weiter · %s" % input_glyph_service.glyph_for_action(&"pause_game")
	if settings_overlay != null and settings_overlay.visible:
		_refresh_binding_buttons()

func show_settings(show_quit: bool = true, campus_context: bool = true) -> void:
	_hide_all()
	if campus_context:
		_show_campus_context()
	else:
		gameplay_hud.show()
	_refresh_settings_screen(show_quit)
	if settings_scroll != null:
		settings_scroll.scroll_horizontal = 0
		settings_scroll.scroll_vertical = 0
	settings_overlay.show()
	_configure_focus_cycle.call_deferred(settings_overlay)
	if settings_initial_focus != null:
		_grab_focus_if_valid.call_deferred(settings_initial_focus)
	# Focus restoration and ScrollContainer.follow_focus are both deferred. Run
	# the opening position last so Settings always begins with Gesamtlautstärke
	# instead of inheriting a construction- or binding-row offset.
	_reset_settings_scroll_to_start.call_deferred()

func _reset_settings_scroll_to_start() -> void:
	if settings_overlay != null and settings_overlay.visible and settings_scroll != null:
		settings_scroll.scroll_horizontal = 0
		settings_scroll.scroll_vertical = 0

# UI view contract for preparation:
# trait{title,effect}, slots[{id,title,kind,cost}], catalog[...] plus
# capacity_used, capacity_max, reserve{id,title}, valid, validation_message and
# loadout_snapshot. Models may be Dictionaries or Resources with equal fields.
func show_preparation(view_model: Variant, catalog: Array = [], loadout: Variant = null) -> void:
	var was_visible := preparation_overlay != null and preparation_overlay.visible
	if not was_visible:
		var initial_slots: Variant = _view_value(view_model, &"slot_snapshot", {})
		var initial_treatment := StringName(str(_view_value(loadout, &"treatment_id", &"")))
		if initial_slots is Dictionary:
			initial_treatment = StringName(str((initial_slots as Dictionary).get(
				LoadoutSlotId.TREATMENT,
				(initial_slots as Dictionary).get(String(LoadoutSlotId.TREATMENT), initial_treatment)
			)))
		planning_snapshot.begin_component_pick(LoadoutSlotId.TREATMENT, initial_treatment)
	_hide_all()
	_show_campus_context()
	refresh_preparation(view_model, catalog, loadout)
	preparation_overlay.show()
	_apply_preparation_layout()
	if not was_visible:
		var tutorial_locked := bool(_view_value(view_model, &"tutorial_locked", false))
		var preferred: Control = preparation_start_button if tutorial_locked else preparation_slot_buttons.get(LoadoutSlotId.TREATMENT, null)
		_prepare_initial_preparation_view.call_deferred(preferred, tutorial_locked)
	else:
		_restore_preparation_focus.call_deferred()

func refresh_preparation(view_model: Variant, catalog: Array = [], loadout: Variant = null) -> void:
	var trait_data: Variant = _view_value(view_model, &"trait", null)
	preparation_level_title.text = String(_view_value(view_model, &"level_title", "Fall"))
	preparation_level_description.text = String(_view_value(view_model, &"level_description", ""))
	preparation_trait_title.text = String(_view_value(trait_data, &"title", _view_value(view_model, &"trait_title", "Kein Fallmerkmal")))
	preparation_trait_effect.text = String(_view_value(trait_data, &"description", _view_value(trait_data, &"effect", _view_value(view_model, &"trait_effect", "Kein besonderer Einfluss."))))
	preparation_trait_panel.tooltip_text = preparation_trait_effect.text
	preparation_trait_title.tooltip_text = preparation_trait_effect.text
	_refresh_preparation_case_facts(view_model, trait_data)
	var source_loadout: Variant = loadout if loadout != null else _view_value(view_model, &"loadout", view_model)
	var snapshot_value: Variant = _view_value(view_model, &"loadout_snapshot", _view_value(source_loadout, &"snapshot", {}))
	if snapshot_value is Dictionary and (snapshot_value as Dictionary).is_empty() and source_loadout is Object and (source_loadout as Object).has_method("to_dict"):
		snapshot_value = (source_loadout as Object).call("to_dict")
	current_preparation_snapshot = snapshot_value.duplicate(true) if snapshot_value is Dictionary else {}
	current_preparation_catalog_entries = catalog if not catalog.is_empty() else _variant_array(_view_value(view_model, &"catalog", []))
	current_preparation_catalog_by_id.clear()
	for entry in current_preparation_catalog_entries:
		current_preparation_catalog_by_id[StringName(_view_value(entry, &"id", &""))] = entry
	var slot_snapshot_value: Variant = _view_value(view_model, &"slot_snapshot", {})
	var slot_snapshot: Dictionary = slot_snapshot_value.duplicate() if slot_snapshot_value is Dictionary else {}
	if slot_snapshot.is_empty() and source_loadout is Object:
		var abilities := _variant_array(_view_value(source_loadout, &"ability_ids", []))
		var passives := _variant_array(_view_value(source_loadout, &"passive_ids", []))
		slot_snapshot = {
			LoadoutSlotId.TREATMENT: _view_value(source_loadout, &"treatment_id", &""),
			LoadoutSlotId.ACTIVE_1: abilities[0] if abilities.size() > 0 else &"",
			LoadoutSlotId.ACTIVE_2: abilities[1] if abilities.size() > 1 else &"",
			LoadoutSlotId.PASSIVE_1: passives[0] if passives.size() > 0 else &"",
			LoadoutSlotId.PASSIVE_2: passives[1] if passives.size() > 1 else &"",
			LoadoutSlotId.RESERVE: _view_value(source_loadout, &"reserve_id", &""),
			}
	current_preparation_slots = slot_snapshot.duplicate(true)
	if planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK and planning_snapshot.selected_slot_id != &"":
		planning_snapshot.current_component_id = _preparation_component_at(planning_snapshot.selected_slot_id)
	var active_component_ids: Array = []
	for slot_id in LoadoutSlotId.planning():
		var slot_button: Button = preparation_slot_buttons[slot_id]
		var component_id := StringName(str(slot_snapshot.get(slot_id, slot_snapshot.get(String(slot_id), ""))))
		slot_button.set_meta(&"component_id", component_id)
		var resolved: Variant = current_preparation_catalog_by_id.get(component_id, null)
		if component_id != &"":
			active_component_ids.append(component_id)
		_refresh_preparation_slot_content(slot_id, component_id, resolved)
		slot_button.tooltip_text = ""
		var selected := planning_snapshot.selected_slot_id == slot_id and planning_snapshot.mode != PlanningSnapshot.Mode.BROWSE
		slot_button.set_meta(&"selected_slot", selected)
		_apply_preparation_slot_style(slot_button, selected)
	var validation_data: Variant = _view_value(view_model, &"validation", null)
	var used_fallback := _catalog_capacity(active_component_ids, current_preparation_catalog_by_id)
	var used := int(_view_value(validation_data, &"capacity_used", _view_value(source_loadout, &"capacity_used", _view_value(view_model, &"capacity_used", used_fallback))))
	var maximum := maxi(1, int(_view_value(validation_data, &"capacity_limit", _view_value(source_loadout, &"capacity_max", _view_value(view_model, &"capacity_max", 8)))))
	current_preparation_capacity_used = used
	current_preparation_capacity_limit = maximum
	preparation_capacity_bar.max_value = maximum
	preparation_capacity_bar.value = used
	preparation_capacity_label.text = "%d / %d KAPAZITÄT" % [used, maximum]
	preparation_capacity_bar.add_theme_stylebox_override("fill", _bar_style(COLOR_RED if used > maximum else COLOR_TEAL, 4))
	var selected_components := active_component_ids.duplicate()
	var component_slots: Dictionary = {}
	for slot_id in LoadoutSlotId.planning():
		var assigned_id := StringName(str(slot_snapshot.get(slot_id, slot_snapshot.get(String(slot_id), ""))))
		if assigned_id != &"":
			component_slots[assigned_id] = _loadout_slot_caption(slot_id)
	current_preparation_unlocked_ids = _view_value(view_model, &"available_ids", _view_value(view_model, &"unlocked_ids", {}))
	var raw_availability_reasons: Variant = _view_value(view_model, &"availability_reasons", {})
	current_preparation_availability_reasons = raw_availability_reasons.duplicate() if raw_availability_reasons is Dictionary else {}
	current_preparation_selected_components = selected_components
	current_preparation_component_slots = component_slots
	_rebuild_preparation_catalog(current_preparation_catalog_entries, current_preparation_unlocked_ids, selected_components, component_slots)
	preparation_locked = bool(_view_value(view_model, &"tutorial_locked", false))
	var can_skip_intro := bool(_view_value(view_model, &"can_skip_intro", preparation_locked))
	preparation_intro_skip_button.visible = can_skip_intro
	preparation_workspace.visible = not preparation_locked
	preparation_lock_panel.visible = preparation_locked
	if root != null:
		_apply_page_shell_layout(root.size.x)
	var finding_hint := String(_view_value(view_model, &"finding_hint", "Der genaue Befund entsteht in der Runde."))
	var default_plan_note := "%s Vorbereitete Komponenten erscheinen häufiger bei Ausbauten." % finding_hint
	preparation_synergy_label.text = String(_view_value(view_model, &"synergy_summary", default_plan_note))
	var valid := bool(_view_value(validation_data, &"valid", _view_value(source_loadout, &"valid", _view_value(view_model, &"valid", false))))
	var default_validation := "" if valid else "Plan ist noch nicht gültig."
	if validation_data is Object and (validation_data as Object).has_method("first_error") and not valid:
		default_validation = str((validation_data as Object).call("first_error"))
	var validation := default_validation if valid else String(_view_value(source_loadout, &"validation_message", _view_value(view_model, &"validation_message", default_validation)))
	_set_preparation_validation(validation, COLOR_TEAL.lightened(0.22) if valid else COLOR_RED.lightened(0.14))
	preparation_start_button.disabled = not valid or planning_snapshot.mode == PlanningSnapshot.Mode.REPLACE_CONFIRM
	AlveolusUIComponents.refresh_button_state(preparation_start_button)
	_apply_preparation_editor_state(preparation_locked)
	_apply_preparation_layout()

func _refresh_preparation_case_facts(view_model: Variant, trait_data: Variant) -> void:
	if preparation_case_facts == null:
		return
	for child in preparation_case_facts.get_children():
		preparation_case_facts.remove_child(child)
		child.queue_free()
	preparation_level_facts = _case_fact_chip(
		&"clock",
		"Dauer %s" % String(_view_value(view_model, &"duration_text", "–")),
		Color("7eb5ff")
	)
	preparation_case_facts.add_child(preparation_level_facts)
	preparation_boss_fact = _case_fact_chip(
		&"diamond",
		"Boss %s" % String(_view_value(view_model, &"boss_time_text", "–")),
		Color("f0bc57")
	)
	preparation_case_facts.add_child(preparation_boss_fact)
	for modifier_value in _variant_array(_view_value(trait_data, &"modifiers", [])):
		var fact := _case_modifier_fact(modifier_value)
		if fact.is_empty():
			continue
		preparation_case_facts.add_child(_case_fact_chip(&"circle", String(fact["text"]), fact["color"]))

func _case_fact_chip(icon_kind: StringName, text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size.y = 28.0
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", PreparationBioLumenStyle.chip(color))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	var icon := SimpleIcon.new()
	icon.custom_minimum_size = Vector2(16.0, 16.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(icon_kind, color)
	row.add_child(icon)
	var label := _label(text, 13, color)
	label.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return chip

func _case_modifier_fact(modifier: Variant) -> Dictionary:
	var stat_id := StringName(_view_value(modifier, &"stat_id", &""))
	var operation := StringName(_view_value(modifier, &"operation", &""))
	var value := float(_view_value(modifier, &"value", 0.0))
	var caption := ""
	var amount := 0.0
	var beneficial := false
	match stat_id:
		&"initial_stability":
			caption = "Startleben"
			amount = value
			beneficial = amount >= 0.0
		&"support_effect":
			caption = "Regeneration"
			amount = (value - 1.0) * 100.0 if operation == &"multiply" else value
			beneficial = amount >= 0.0
		&"spawn_interval":
			caption = "Aufkommen"
			amount = (1.0 - value) * 100.0 if operation == &"multiply" else -value
			beneficial = amount <= 0.0
		&"enemy_health":
			caption = "Gegnerleben"
			amount = (value - 1.0) * 100.0 if operation == &"multiply" else value
			beneficial = amount <= 0.0
		&"enemy_speed":
			caption = "Gegnertempo"
			amount = (value - 1.0) * 100.0 if operation == &"multiply" else value
			beneficial = amount <= 0.0
		&"enemy_damage", &"contact_damage":
			caption = "Gegnerschaden"
			amount = (value - 1.0) * 100.0 if operation == &"multiply" else value
			beneficial = amount <= 0.0
		_:
			return {}
	var suffix := "" if stat_id == &"initial_stability" else " %"
	var sign_text := "+" if amount > 0.01 else ("−" if amount < -0.01 else "±")
	return {
		"text": "%s %s%d%s" % [caption, sign_text, roundi(absf(amount)), suffix],
		"color": Color("51d6cb") if beneficial else Color("ff806f"),
	}

func show_running_hud() -> void:
	_hide_all()
	upgrade_target_preview.clear()
	gameplay_hud.show()
	alert_time = 0.0
	boss_announcement_time = 0.0
	alert_panel.hide()
	boss_announcement_panel.hide()
	finding_progress_panel.hide()
	set_process(false)
	boss_hud_active = false
	run_hud_vitals["boss_visible"] = false
	_apply_run_hud_model()
	_refresh_run_stats()

func set_run_stats_visibility(enabled: bool) -> void:
	run_stats_enabled = enabled
	if settings_run_stats_toggle != null:
		settings_run_stats_toggle.set_pressed_no_signal(enabled)
		_update_toggle_caption(settings_run_stats_toggle, enabled)
	_refresh_run_stats()

func update_run_stats(player_stats: PlayerStats, run_state: RunState = null) -> void:
	current_player_stats = player_stats
	current_run_state = run_state
	_refresh_run_stats()
	_refresh_pause_stats()

func _refresh_run_stats() -> void:
	if run_stats_panel == null:
		return
	var available := current_player_stats != null
	# The compact four-column strip has a dedicated top-right lane. Critical
	# alerts no longer need to erase player-selected combat values.
	var should_show := run_stats_enabled and available
	if not available:
		run_hud_stat_rows.clear()
		_apply_run_hud_model()
		return
	var current := current_run_state.stability if current_run_state != null else -1.0
	var maximum := current_run_state.max_stability if current_run_state != null else -1.0
	if run_stats_label != null:
		run_stats_label.text = current_player_stats.compact_stat_text(current, maximum)
	run_hud_stat_rows.clear()
	if should_show:
		var descriptors := _run_stat_descriptors(current, maximum)
		for index in range(descriptors.size()):
			var descriptor := descriptors[index] as HudStatDescriptor
			run_hud_stat_rows.append({
				"id": descriptor.id,
				"icon_id": descriptor.icon_id,
				"value": descriptor.formatted_value,
				"accessible_name": descriptor.accessible_name,
				"priority": descriptor.priority,
			})
	_apply_run_hud_model()

func _run_stat_descriptors(current_stability: float, maximum_stability: float) -> Array:
	var descriptors: Array = []
	var wanted := {
		&"defense": [&"defense_training", 100, "Verteidigung"],
		&"movement_speed": [&"movement_training", 90, "Bewegung"],
		&"life_regeneration": [&"life_regeneration", 80, "Regeneration"],
		&"experience_gain": [&"experience_gain", 70, "Erfahrung"],
		&"resistance_fire": [&"damage_fire", 60, "Feuerresistenz"],
		&"resistance_water": [&"damage_water", 50, "Wasserresistenz"],
		&"resistance_earth": [&"damage_earth", 40, "Erdresistenz"],
		&"resistance_wind": [&"damage_wind", 30, "Windresistenz"],
	}
	var shield_current := float(run_hud_vitals.get("shield_current", 0.0))
	var shield_maximum := float(run_hud_vitals.get("shield_maximum", 0.0))
	for section in current_player_stats.stat_sections(current_stability, maximum_stability, shield_current, shield_maximum):
		if section == null or section.id() != &"general":
			continue
		for row in section.rows():
			var stat_id := StringName(row.get("id", &""))
			if not wanted.has(stat_id):
				continue
			var mapping: Array = wanted[stat_id]
			var value := String(row.get("value", "–"))
			descriptors.append(HudStatDescriptor.create(
				mapping[0],
				value,
				"%s: %s" % [String(mapping[2]), value],
				int(mapping[1]),
				stat_id
			))
		break
	return descriptors

func update_defeat_research_reward(value: int) -> void:
	var normalized := maxi(0, value)
	var next_reward := {
		"visible": normalized > 0,
		"icon_id": &"research",
		"value": "+%d" % normalized if normalized > 0 else "",
		"accessible_name": "Forschungsgewinn bei Niederlage: %d" % normalized if normalized > 0 else "",
	}
	if run_hud_vitals.get("defeat_research_reward", {}) == next_reward:
		return
	run_hud_vitals["defeat_research_reward"] = next_reward
	_apply_run_hud_model()

func _refresh_pause_stats() -> void:
	if pause_stats_grid == null or pause_stats_label == null or pause_stats_label_right == null:
		return
	for child in pause_stats_grid.get_children():
		pause_stats_grid.remove_child(child)
		child.queue_free()
	pause_stats_columns.clear()
	pause_stat_rows.clear()
	if current_player_stats == null:
		pause_stats_label.text = "Noch keine Rundenwerte verfügbar."
		pause_stats_label_right.text = ""
		var empty := _label("Noch keine Rundenwerte verfügbar.", 16, COLOR_MUTED)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pause_stats_grid.add_child(empty)
		return
	var current := current_run_state.stability if current_run_state != null else -1.0
	var maximum := current_run_state.max_stability if current_run_state != null else -1.0
	var grouped: Dictionary = {}
	for row in current_player_stats.stat_rows(current, maximum, TherapyAvatar.MOVE_SPEED):
		var group := String(row.get("group", ""))
		var group_rows: Array = grouped.get(group, [])
		group_rows.append(row)
		grouped[group] = group_rows
	# The reference layout is one quiet sheet with two real value columns. The
	# group color and a small icon travel with every row, so repeated captions
	# such as "Schaden" remain unambiguous without six bulky group cards.
	var column_groups := [
		["ALLGEMEIN", "BEHANDLUNG"],
		["AKTIV", "ABWEHR", "REGENERATION", "PROBEN"],
	]
	for group_order in column_groups:
		var column := VBoxContainer.new()
		column.name = "StatColumn%d" % (pause_stats_columns.size() + 1)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 3)
		pause_stats_grid.add_child(column)
		pause_stats_columns.append(column)
		var row_index := 0
		for group_value in group_order:
			var group := String(group_value)
			if not grouped.has(group):
				continue
			for row_value in grouped[group]:
				_add_pause_stat_row(column, row_value, row_index)
				row_index += 1
	_apply_pause_stats_density()
	# Compatibility text remains available to screen readers and focused tests.
	var text_grouped: Dictionary = {}
	for group in grouped:
		var group_lines := PackedStringArray()
		for row in grouped[group]:
			group_lines.append("%s:  %s" % [String(row.get("label", "")), String(row.get("value", ""))])
		text_grouped[group] = group_lines
	pause_stats_label.text = _stat_group_text(text_grouped, ["ALLGEMEIN", "BEHANDLUNG"])
	pause_stats_label_right.text = _stat_group_text(text_grouped, ["AKTIV", "ABWEHR", "REGENERATION", "PROBEN"])
	if pause_stats_scroll != null:
		pause_stats_scroll.scroll_vertical = 0
		_update_pause_stats_scroll_mode.call_deferred()

func _add_pause_stat_row(column: VBoxContainer, row_value: Variant, row_index: int) -> void:
	var row: Dictionary = row_value
	var group := String(row.get("group", ""))
	var accent := _pause_stat_group_accent(group)
	var row_panel := PanelContainer.new()
	row_panel.name = "StatRow"
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.custom_minimum_size.y = 28.0
	row_panel.set_meta(&"stat_group", group)
	var background_alpha := 0.30 if row_index % 2 == 0 else 0.16
	var row_style := _panel_style(Color(AlveolusVisualTheme.PETROL_SOFT, background_alpha), Color(accent, 0.16), 1, 2)
	AlveolusVisualTheme.with_content_insets(row_style, 8.0, 3.0)
	row_panel.add_theme_stylebox_override("panel", row_style)
	column.add_child(row_panel)
	pause_stat_rows.append(row_panel)
	var line := HBoxContainer.new()
	line.name = "StatLine"
	line.add_theme_constant_override("separation", 6)
	row_panel.add_child(line)
	var marker := SimpleIcon.new()
	marker.name = "StatMarker"
	marker.custom_minimum_size = Vector2(14.0, 14.0)
	marker.configure(_pause_stat_group_icon(group), accent)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(marker)
	var caption := _label(String(row.get("label", "")), 14, COLOR_MUTED)
	caption.name = "StatCaption"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(caption)
	var value := _label(String(row.get("value", "")), 14, accent.lightened(0.22))
	value.name = "StatValue"
	value.custom_minimum_size.x = 64.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(value)
	row_panel.tooltip_text = "%s · %s: %s" % [group.capitalize(), caption.text, value.text]

func _apply_pause_stats_density() -> void:
	if pause_stats_grid == null or root == null:
		return
	var compact_height := root.size.y < 360.0
	pause_stats_grid.add_theme_constant_override("h_separation", 8 if compact_height else 14)
	pause_stats_grid.add_theme_constant_override("v_separation", 2 if compact_height else 4)
	for column in pause_stats_columns:
		column.add_theme_constant_override("separation", 0 if compact_height else 3)
	for row_panel in pause_stat_rows:
		row_panel.custom_minimum_size.y = 18.0 if compact_height else 28.0
		var style := row_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			AlveolusVisualTheme.with_content_insets(style, 6.0 if compact_height else 8.0, 0.0 if compact_height else 3.0)
	_update_pause_stats_scroll_mode.call_deferred()

func _update_pause_stats_scroll_mode() -> void:
	if pause_stats_scroll == null or pause_stats_grid == null:
		return
	var content_height := pause_stats_grid.get_combined_minimum_size().y
	pause_stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO \
		if content_height > pause_stats_scroll.size.y + 1.0 else ScrollContainer.SCROLL_MODE_DISABLED

func _pause_stat_group_accent(group: String) -> Color:
	match group:
		"ALLGEMEIN": return COLOR_GOLD
		"BEHANDLUNG": return COLOR_TEAL
		"AKTIV": return COLOR_BLUE
		"ABWEHR": return COLOR_RED
		"REGENERATION": return COLOR_TEAL.lightened(0.10)
		"PROBEN": return COLOR_BLUE.lightened(0.10)
	return COLOR_MUTED

func _pause_stat_group_icon(group: String) -> StringName:
	match group:
		"ALLGEMEIN": return &"information"
		"BEHANDLUNG": return &"treatment"
		"AKTIV": return &"ability"
		"ABWEHR": return &"immune"
		"REGENERATION": return &"support"
		"PROBEN": return &"sample"
	return &"information"

func _stat_group_text(grouped: Dictionary, order: Array[String]) -> String:
	var blocks := PackedStringArray()
	for group in order:
		if not grouped.has(group):
			continue
		var lines := PackedStringArray([group])
		lines.append_array(grouped[group] as PackedStringArray)
		blocks.append("\n".join(lines))
	return "\n\n".join(blocks)

func _on_run_stats_toggle(enabled: bool) -> void:
	set_run_stats_visibility(enabled)
	run_stats_visibility_changed.emit(enabled)

func update_stability(current: float, maximum: float) -> void:
	run_hud_vitals["stability_current"] = current
	run_hud_vitals["stability_maximum"] = maximum
	_apply_run_hud_model()
	_refresh_run_stats()

func update_shield(current: float, maximum: float) -> void:
	run_hud_vitals["shield_current"] = current
	run_hud_vitals["shield_maximum"] = maximum
	_apply_run_hud_model()

func show_patient_hit() -> void:
	# Kept for API compatibility. Patient damage feedback now lives solely on
	# the avatar as a short, subtle red tint.
	pass

func update_analysis(current: int, target: int, level: int) -> void:
	run_hud_vitals["analysis_current"] = current
	run_hud_vitals["analysis_target"] = target
	run_hud_vitals["analysis_level"] = level
	_apply_run_hud_model()

func configure_active_abilities(abilities: Array) -> void:
	for slot_index in range(2):
		if slot_index >= abilities.size() or abilities[slot_index] == null:
			run_hud_ability_rows[slot_index] = _empty_run_hud_ability(slot_index)
			continue
		var ability: Variant = abilities[slot_index]
		var ability_id := StringName(String(_view_value(ability, &"id", "ability")))
		if ability_id == &"" or not SimpleIcon.supports(ability_id):
			ability_id = &"ability"
		run_hud_ability_rows[slot_index] = {
			"slot": slot_index,
			"title": String(_view_value(ability, &"title", _view_value(ability, &"display_name", "Aktive Fähigkeit"))),
			"icon_id": ability_id,
			"effect_text": String(_view_value(ability, &"description", _view_value(ability, &"effect_text", ""))),
			"fact_rows": _view_value(ability, &"fact_rows", []),
			"occupied": true,
			"ready": bool(_view_value(ability, &"ready", true)),
			"cooldown_remaining": float(_view_value(ability, &"cooldown_remaining", 0.0)),
			"cooldown_total": float(_view_value(ability, &"cooldown_total", _view_value(ability, &"cooldown_seconds", 1.0))),
			"targeting": false,
			"key_glyph_text": _ability_glyph(slot_index),
		}
	_apply_run_hud_model()

func clear_active_abilities() -> void:
	for slot_index in range(2):
		run_hud_ability_rows[slot_index] = _empty_run_hud_ability(slot_index)
	_apply_run_hud_model()

func update_active_ability(slot_index: int, title: String, remaining: float, total: float, ready: bool) -> void:
	if slot_index < 0 or slot_index >= 2:
		return
	var occupied := not title.is_empty()
	if not occupied:
		run_hud_ability_rows[slot_index] = _empty_run_hud_ability(slot_index)
		_apply_run_hud_model()
		return
	var previous: Dictionary = run_hud_ability_rows[slot_index]
	previous["title"] = title
	previous["occupied"] = true
	previous["ready"] = ready
	previous["cooldown_remaining"] = remaining
	previous["cooldown_total"] = total
	previous["key_glyph_text"] = _ability_glyph(slot_index)
	run_hud_ability_rows[slot_index] = previous
	_apply_run_hud_model()

func set_ability_targeting(slot_index: int, targeting: bool) -> void:
	if slot_index < 0 or slot_index >= 2:
		return
	var ability: Dictionary = run_hud_ability_rows[slot_index]
	ability["targeting"] = targeting
	run_hud_ability_rows[slot_index] = ability
	_apply_run_hud_model()

func _empty_run_hud_ability(slot_index: int) -> Dictionary:
	return {
		"slot": slot_index,
		"title": "Nicht belegt",
		"icon_id": &"ability",
		"effect_text": "",
		"fact_rows": [],
		"occupied": false,
		"ready": false,
		"cooldown_remaining": 0.0,
		"cooldown_total": 0.0,
		"targeting": false,
		"key_glyph_text": _ability_glyph(slot_index),
	}

func _ability_glyph(slot_index: int) -> String:
	if input_glyph_service != null:
		return input_glyph_service.glyph_for_action(&"active_ability_1" if slot_index == 0 else &"active_ability_2")
	return "Q" if slot_index == 0 else "E"

func _on_ability_slot_pressed(slot_index: int) -> void:
	ability_slot_requested.emit(slot_index)

func update_finding_progress(current: int, target: int, revealed: bool = false) -> void:
	finding_progress_panel.show()
	finding_progress_bar.max_value = maxi(target, 1)
	finding_progress_bar.value = target if revealed else clampi(current, 0, target)
	finding_progress_label.text = "BEFUND · AUFGEDECKT" if revealed else "BEFUND · %d / %d" % [current, target]
	finding_progress_label.modulate = COLOR_TEAL if revealed else COLOR_GOLD
	AlveolusUIComponents.apply_progress_accent(finding_progress_bar, COLOR_TEAL if revealed else COLOR_GOLD)

func hide_finding_progress() -> void:
	finding_progress_panel.hide()

func update_timer(elapsed: float, boss_spawn_seconds: float, deadline_seconds: float, boss_active: bool) -> void:
	# The permanent top-right readout is elapsed round time. Boss state keeps
	# its own dedicated bar and must not repurpose the clock into a countdown.
	if boss_spawn_seconds < 0.0 or deadline_seconds < 0.0 or boss_active:
		# Retain the established facade arguments without allocating per frame;
		# the elapsed readout deliberately ignores the former countdown context.
		pass
	update_round_time(elapsed)

func update_round_time(elapsed: float) -> void:
	var round_time_text := _clock_text(maxf(elapsed, 0.0))
	var timer_tone := &"neutral"
	if run_hud_vitals.get("round_time_text", "") == round_time_text and run_hud_vitals.get("timer_tone", &"") == timer_tone:
		return
	run_hud_vitals["round_time_text"] = round_time_text
	run_hud_vitals["timer_text"] = round_time_text
	run_hud_vitals["timer_tone"] = timer_tone
	_apply_run_hud_model()

func update_intro_timer(lesson: int, phase: StringName, boss_active: bool) -> void:
	var timer_text := "EINFÜHRUNG · MINI-BOSS" if boss_active else "EINFÜHRUNG · LEKTION %d/3" % clampi(lesson, 1, 3)
	var timer_tone := &"danger" if boss_active else (&"attention" if phase != &"" else &"neutral")
	if run_hud_vitals.get("timer_text", "") == timer_text and run_hud_vitals.get("timer_tone", &"") == timer_tone:
		return
	run_hud_vitals["timer_text"] = timer_text
	run_hud_vitals["timer_tone"] = timer_tone
	if boss_active:
		_apply_run_hud_model()
		return
	_apply_run_hud_model()

func show_boss(maximum: float, phase_count: int) -> void:
	run_hud_vitals["boss_visible"] = true
	run_hud_vitals["boss_current"] = maximum
	run_hud_vitals["boss_maximum"] = maximum
	run_hud_vitals["boss_phase"] = "Phasen 70 % · 40 %" if phase_count > 0 else "Einführungsboss"
	boss_hud_active = true
	_apply_run_hud_model()
	_refresh_run_stats()
	boss_announcement_panel.show()
	boss_announcement_time = 1.2
	set_process(true)

func update_boss_health(current: float, maximum: float) -> void:
	run_hud_vitals["boss_current"] = current
	run_hud_vitals["boss_maximum"] = maximum
	_apply_run_hud_model()

func show_boss_phase(phase: int) -> void:
	run_hud_vitals["boss_phase"] = "Phase %d aktiv" % (phase + 1)
	_apply_run_hud_model()

func show_alert(text: String, color: Color = COLOR_TEAL, duration: float = 2.8) -> void:
	alert_label.text = text
	alert_label.modulate = Color.WHITE
	alert_label.add_theme_color_override("font_color", color.lightened(0.16))
	AlveolusUIComponents.apply_surface_role(alert_panel, AlveolusVisualTheme.SurfaceRole.HUD_ALERT, color)
	alert_panel.show()
	alert_time = duration
	set_process(true)
	_refresh_run_stats()

func show_upgrade_choices(options: Array[UpgradeDefinition], stats: PlayerStats, can_reroll: bool, show_education: bool = false, scripted_intro: bool = false) -> void:
	current_upgrade_options = options.duplicate()
	upgrade_view_revision += 1
	var rows: Array = []
	var component_titles := {
		&"ability_defense_burst": "Abwehrstoß",
		&"ability_treatment_line": "Behandlungslinie",
	}
	for definition in options:
		if definition == null:
			continue
		var preview := stats.preview_upgrade(definition)
		var comparison := _split_upgrade_comparison(preview.before_after_text)
		rows.append({
			"id": definition.id,
			"title": definition.resolved_component_name(stats.prepared_treatment, component_titles),
			"effect": _intro_upgrade_copy(definition.id) if scripted_intro else preview.effect_text,
			"before": "" if scripted_intro else comparison[0],
			"after": "" if scripted_intro else comparison[1],
			"icon_id": _upgrade_icon_kind(definition),
			"accent_role": _upgrade_accent_role(definition),
		})
	var education_copy := ""
	if scripted_intro:
		education_copy = "Diese Auswahl erklärt den nächsten Behandlungsschritt."
	elif show_education:
		# Legacy callers may still request the former legend. Keeping the branch
		# explicit documents that this no longer creates a second text block.
		education_copy = ""
	# show_education is retained in the public facade for compatibility. The
	# central overlay deliberately renders education only for an explicit
	# scripted intro; option count or a generic hint never changes the mode.
	var model := UpgradeOverlayViewModel.create(
		rows,
		upgrade_view_revision,
		scripted_intro,
		education_copy,
		can_reroll,
		false
	)
	var request_focus := input_glyph_service != null and input_glyph_service.current_method == InputGlyphService.GAMEPAD
	upgrade_screen.present(model, request_focus)
	upgrade_panel = upgrade_screen.modal_sheet()
	upgrade_cards = upgrade_screen.cards_grid()
	upgrade_education = upgrade_screen.education_panel()
	reroll_button = upgrade_screen.reroll_action()
	if upgrade_target_preview != null:
		upgrade_target_preview.clear()

func _split_upgrade_comparison(copy: String) -> Array[String]:
	var separator_index := copy.find(">")
	if separator_index < 0:
		return ["", copy.strip_edges()]
	return [
		copy.substr(0, separator_index).strip_edges(),
		copy.substr(separator_index + 1).strip_edges(),
	]

func _upgrade_accent_role(definition: UpgradeDefinition) -> StringName:
	match definition.path:
		UpgradeDefinition.Path.IMMUNE:
			return &"coral"
		UpgradeDefinition.Path.SUPPORT:
			return &"turquoise"
		_:
			return &"teal"

func _intro_upgrade_copy(id: StringName) -> String:
	match id:
		&"potency":
			return "Deine Behandlung verursacht jetzt mehr Schaden."
		&"neutrophils":
			return "Abwehrzellen schützen den Nahbereich automatisch."
		&"oxygenation":
			return "Regeneration stellt regelmäßig Leben wieder her."
		_:
			return "Diese Verbesserung verstärkt deine Behandlung."

func activate_upgrade(index: int) -> void:
	if not upgrade_overlay.visible or index < 0 or index >= current_upgrade_options.size():
		return
	upgrade_chosen.emit(current_upgrade_options[index])

func show_pause(is_intro: bool = false, player_stats: PlayerStats = null, run_state: RunState = null) -> void:
	if player_stats != null:
		update_run_stats(player_stats, run_state)
	pause_is_intro = is_intro
	pause_stats_overlay.hide()
	pause_view_revision += 1
	pause_screen.present(_pause_view_model(), PauseOverlay.Mode.MENU, true)

func hide_pause() -> void:
	pause_screen.dismiss()
	pause_stats_overlay.hide()

func is_pause_stats_open() -> bool:
	return pause_screen != null and pause_screen.visible and pause_screen.current_mode() == PauseOverlay.Mode.STATS

func return_to_pause_menu() -> void:
	_hide_pause_stats()

func _show_pause_stats() -> void:
	pause_view_revision += 1
	pause_screen.apply_view_model(_pause_view_model(), PauseOverlay.Mode.STATS)
	pause_screen.show()
	pause_stats_overlay.show()
	pause_screen.grab_initial_focus.call_deferred()

func _hide_pause_stats() -> void:
	pause_stats_overlay.hide()
	pause_screen.set_mode(PauseOverlay.Mode.MENU, true)
	pause_screen.show()


func _pause_view_model() -> PauseOverlayViewModel:
	var sections: Array = []
	if current_player_stats != null:
		var current_life := current_run_state.stability if current_run_state != null else -1.0
		var maximum_life := current_run_state.max_stability if current_run_state != null else -1.0
		sections = current_player_stats.stat_sections(
			current_life,
			maximum_life,
			float(run_hud_vitals.get("shield_current", 0.0)),
			float(run_hud_vitals.get("shield_maximum", 0.0))
		)
	return PauseOverlayViewModel.create(sections, pause_view_revision, pause_is_intro)


func _pause_stat_group_role(group: String) -> StringName:
	match group:
		"BEHANDLUNG": return &"teal"
		"AKTIV", "PROBEN": return &"cobalt"
		"ABWEHR": return &"coral"
		"REGENERATION": return &"turquoise"
	return &"gold"

func show_abort_confirmation() -> void:
	pause_overlay.hide()
	_apply_abort_confirmation()
	abort_confirmation.present(abort_confirmation.view_model(), true)

func show_intro_skip_confirmation() -> void:
	pause_overlay.hide()
	_apply_intro_skip_confirmation()
	intro_skip_confirmation.present(intro_skip_confirmation.view_model(), true)

func show_restart_confirmation() -> void:
	pause_overlay.hide()
	pause_stats_overlay.hide()
	_apply_restart_confirmation()
	restart_confirmation.present(restart_confirmation.view_model(), true)

func hide_restart_confirmation() -> void:
	restart_confirmation.dismiss()

func hide_intro_skip_confirmation() -> void:
	intro_skip_confirmation.dismiss()

# `definition` and reactions are intentionally duck-typed so data resources
# can evolve without turning this view into a second source of game rules.
func show_finding(definition: Variant, reactions: Array, reserve: Variant = null, swappable_passives: Array = []) -> void:
	_hide_all()
	gameplay_hud.show()
	current_finding_reaction = &""
	current_finding_reserve = StringName(reserve) if reserve is String or reserve is StringName else StringName(_view_value(reserve, &"id", &""))
	finding_id = StringName(_view_value(definition, &"id", &"finding"))
	finding_title_text = String(_view_value(definition, &"title", "Neuer Befund"))
	finding_medical_copy = String(_view_value(definition, &"medical_text", _view_value(definition, &"description", "")))
	finding_gameplay_copy = String(_view_value(definition, &"gameplay_text", _view_value(definition, &"effect", "")))
	finding_reaction_models.clear()
	for index in range(reactions.size()):
		var reaction: Variant = reactions[index]
		var reaction_id := StringName(_view_value(reaction, &"id", &""))
		var title := String(_view_value(reaction, &"title", "Reaktion"))
		var effect := String(_view_value(reaction, &"description", _view_value(reaction, &"effect", "")))
		var accent := COLOR_TEAL if index % 2 == 0 else COLOR_GOLD
		var info := FindingOverlayViewModel.InfoViewModel.new("", effect, "", &"ability", accent)
		finding_reaction_models.append(FindingOverlayViewModel.ReactionViewModel.new(
			reaction_id,
			title,
			effect,
			&"ability",
			accent,
			true,
			info
		))
	current_finding_outgoing_ids.clear()
	var outgoing_models: Array[FindingOverlayViewModel.OutgoingOptionViewModel] = []
	for passive in swappable_passives:
		var passive_id := StringName(passive) if passive is String or passive is StringName else StringName(_view_value(passive, &"id", &""))
		var passive_title := String(_view_value(passive, &"title", String(passive_id)))
		current_finding_outgoing_ids.append(passive_id)
		outgoing_models.append(FindingOverlayViewModel.OutgoingOptionViewModel.new(passive_id, passive_title))
	var reserve_title := String(_view_value(reserve, &"title", String(current_finding_reserve)))
	# Reserve remains save-compatible but dormant in the current product UI.
	finding_reserve_model = FindingOverlayViewModel.ReserveSwapViewModel.new(
		false,
		current_finding_reserve,
		reserve_title,
		false,
		false,
		outgoing_models,
		current_finding_outgoing_ids[0] if not current_finding_outgoing_ids.is_empty() else &""
	)
	finding_swap_valid = true
	finding_validation_text = ""
	_apply_finding_screen_model(true)


func hide_finding() -> void:
	if finding_screen != null:
		finding_screen.dismiss()


func set_finding_swap_validation(valid: bool, message: String = "") -> void:
	finding_swap_valid = valid
	finding_validation_text = message
	if finding_screen != null:
		current_finding_reaction = finding_screen.selected_reaction_id()
	_apply_finding_screen_model(false)


func _apply_finding_screen_model(request_focus: bool) -> void:
	if finding_screen == null:
		return
	finding_view_revision += 1
	var model := FindingOverlayViewModel.new(
		finding_view_revision,
		finding_id,
		finding_title_text,
		finding_medical_copy,
		finding_gameplay_copy,
		finding_reaction_models,
		current_finding_reaction,
		finding_reserve_model,
		finding_swap_valid,
		finding_validation_text
	)
	finding_screen.present(model, request_focus)
	_register_finding_context_sources()
	_map_finding_compatibility_controls()


func _register_finding_context_sources() -> void:
	if context_detail_controller == null or finding_screen == null:
		return
	for source in finding_context_sources:
		if is_instance_valid(source):
			context_detail_controller.unregister_source(source)
	finding_context_sources.clear()
	for registration in finding_screen.context_detail_registrations():
		var source := registration.get("source") as Control
		var provider: Callable = registration.get("provider", Callable())
		if source == null or not provider.is_valid():
			continue
		register_context_detail(
			source,
			provider,
			bool(registration.get("hover_enabled", true)),
			registration.get("anchor") as Control,
			int(registration.get("placement", ContextDetailController.Placement.AUTO))
		)
		finding_context_sources.append(source)


func _map_finding_compatibility_controls() -> void:
	if finding_screen == null:
		return
	finding_overlay = finding_screen
	finding_panel = finding_screen.modal_sheet()
	finding_title = finding_screen.find_child("FindingTitle", true, false) as Label
	finding_copy_grid = finding_screen.copy_grid()
	finding_reaction_cards = finding_screen.reaction_grid()
	finding_confirm_button = finding_screen.confirm_action()
	finding_swap_toggle = finding_screen.swap_action()
	finding_outgoing_option = finding_screen.outgoing_action()
	finding_validation_label = finding_screen.validation_label()
	finding_reserve_row = finding_screen.reserve_panel()


func _emit_finding_swap_preview_from_screen() -> void:
	if finding_screen == null:
		return
	var enabled := finding_screen.is_swap_enabled()
	var incoming := current_finding_reserve if enabled else &""
	var outgoing := finding_screen.selected_outgoing_id() if enabled else &""
	finding_reserve_swap_requested.emit(incoming, outgoing)


func show_end_mastery(new_objectives: Array, earned_points: int, total_points: int) -> void:
	if new_objectives.is_empty() and earned_points <= 0:
		result_mastery_text = ""
		_refresh_result_screen()
		return
	var names := PackedStringArray()
	for objective in new_objectives:
		names.append(String(_view_value(objective, &"title", objective)))
	var detail := " · ".join(names)
	result_mastery_text = "+%d Talentpunkte · Gesamt %d%s" % [
		earned_points,
		total_points,
		" · %s" % detail if not detail.is_empty() else "",
	]
	_refresh_result_screen()

func show_discovery(definition: DiscoveryDefinition, gameplay_target: Variant, gameplay_override: String = "") -> void:
	var resolved_target: Variant = gameplay_target
	if resolved_target == null:
		match definition.target_type:
			&"stability_bar":
				resolved_target = stability_bar
			&"boss_bar":
				resolved_target = boss_bar
			&"reward":
				resolved_target = end_reward if end_reward != null else end_panel
	discovery_tooltip.present(definition, resolved_target, gameplay_override)

func hide_discovery() -> void:
	discovery_tooltip.conceal()

func set_intro_upgrade_target(target: Variant) -> void:
	intro_upgrade_target = target

func show_end(level: LevelDefinition, success: bool, reason: String, elapsed: float, analysis_level: int, defeats: int, reward: int, unlocked_new: bool) -> void:
	_hide_all()
	gameplay_hud.show()
	ability_panel.hide()
	finding_progress_panel.hide()
	result_success = success
	result_title_text = "Herd kontrolliert" if success else "You suck"
	result_reason_text = reason if success else ""
	result_detail_text = level.victory_text if success else ""
	result_stats_data = [
		ResultOverlayViewModel.StatViewModel.new(&"time", "Zeit", _clock_text(elapsed), false),
		ResultOverlayViewModel.StatViewModel.new(&"analysis", "Analyselevel", str(analysis_level), true),
		ResultOverlayViewModel.StatViewModel.new(&"defeats", "Bakterien", str(defeats), false),
	]
	result_reward_text = "+%d Forschung" % reward if reward > 0 else ""
	result_unlock_text = "Neuer Fall freigeschaltet" if unlocked_new else ""
	result_mastery_text = ""
	_refresh_result_screen()
	end_overlay.show()
	result_screen.grab_initial_focus.call_deferred()

func _refresh_result_screen() -> void:
	if result_screen == null:
		return
	result_view_revision += 1
	result_screen.apply(ResultOverlayViewModel.new(
		result_view_revision,
		result_success,
		result_title_text,
		result_reason_text,
		result_detail_text,
		result_stats_data,
		result_reward_text,
		result_unlock_text,
		result_mastery_text
	))
	_map_result_compatibility_controls()

func _map_result_compatibility_controls() -> void:
	if result_screen == null:
		return
	end_panel = result_screen.get_modal()
	end_title = result_screen.find_child("OutcomeTitle", true, false) as Label
	end_reason = result_screen.find_child("Reason", true, false) as Label
	var time_row := result_screen.find_child("Stat_time", true, false) as Control
	end_stats = time_row.find_child("Value", true, false) as Label if time_row != null else null
	end_reward = result_screen.find_child("Optional_reward_Body", true, false) as Label
	end_unlock = result_screen.find_child("Optional_unlock_Body", true, false) as Label
	end_mastery_panel = result_screen.find_child("Optional_mastery", true, false) as Control
	end_mastery_label = result_screen.find_child("Optional_mastery_Body", true, false) as Label

func _end_base_panel_size() -> Vector2:
	if (end_reward != null and end_reward.visible) or (end_unlock != null and end_unlock.visible):
		return END_PANEL_SIZE
	return END_FAILURE_PANEL_SIZE

func _advance_story() -> void:
	if story_index >= 2:
		story_finished.emit()
		return
	story_index += 1
	_refresh_story()

func _refresh_story() -> void:
	if story_screen != null:
		story_screen.set_step_index(story_index)

func _show_lexicon_entry(definition: DiscoveryDefinition) -> void:
	var medical_title := definition.medical_name if not definition.medical_name.is_empty() else definition.title
	lexicon_detail.text = "%s\n%s\n\nIM SPIEL\n%s" % [medical_title, definition.medical_text, definition.gameplay_text]

func _show_campus_context() -> void:
	campus_overlay.modulate = Color(0.20, 0.20, 0.20, 1.0)
	campus_overlay.show()

func _show_intro_upgrade_preview(target_type: StringName) -> void:
	var target: Variant = intro_upgrade_target
	if target == null and target_type == &"stability_bar":
		target = stability_bar
	elif target == null:
		target = get_viewport().get_visible_rect().size * 0.5
	upgrade_target_preview.present(target_type, target)

func _all_overlays() -> Array[Control]:
	return [campus_overlay, practice_overlay, research_overlay, level_overlay, lexicon_overlay, story_overlay, settings_overlay, preparation_overlay, upgrade_overlay, pause_overlay, pause_stats_overlay, abort_overlay, intro_skip_overlay, restart_overlay, finding_overlay, end_overlay]

func _hide_all() -> void:
	_clear_binding_interaction()
	gameplay_hud.hide()
	close_all_context_details()
	if upgrade_target_preview != null:
		upgrade_target_preview.clear()
	if discovery_tooltip != null:
		discovery_tooltip.hide()
	for overlay in _all_overlays():
		overlay.hide()

func _focus_first_button(scope: Control) -> void:
	var focusable := _configure_focus_cycle(scope)
	if not focusable.is_empty():
		focusable[0].grab_focus()


func _grab_focus_if_valid(control: Control) -> void:
	if control != null and is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


func _prepare_optional_navigation_focus(scope: Control, preferred: Control = null) -> void:
	var focusable := _configure_focus_cycle(scope)
	if focusable.is_empty():
		return
	if input_glyph_service != null and input_glyph_service.method() == InputGlyphService.GAMEPAD:
		if preferred != null and preferred.is_visible_in_tree() and preferred.focus_mode != Control.FOCUS_NONE and not (preferred is BaseButton and (preferred as BaseButton).disabled):
			preferred.grab_focus()
		else:
			focusable[0].grab_focus()
		return
	var focus_owner := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focus_owner != null and scope.is_ancestor_of(focus_owner):
		focus_owner.release_focus()

func _configure_focus_cycle(scope: Control) -> Array[Control]:
	if scope == null or not scope.is_visible_in_tree():
		return []
	var focusable: Array[Control] = []
	for node in scope.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree() or control.focus_mode not in [Control.FOCUS_CLICK, Control.FOCUS_ALL]:
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		if control is LineEdit and not (control as LineEdit).editable:
			continue
		focusable.append(control)
	if focusable.is_empty():
		return focusable
	for index in range(focusable.size()):
		var button := focusable[index]
		var previous := focusable[(index - 1 + focusable.size()) % focusable.size()]
		var next := focusable[(index + 1) % focusable.size()]
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)
		if _is_talent_tree_node(button):
			# TalentTreeBranch owns spatial D-pad navigation. Tab/Shift+Tab may
			# still use the global cycle, but an overlay refresh must never flatten
			# the drawn prerequisite branches into DOM order.
			continue
		# Directional navigation must stay in the visible top layer instead of
		# falling through to the dimmed campus that remains underneath it.
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)
		button.focus_neighbor_bottom = button.get_path_to(next)
	return focusable

func _is_talent_tree_node(control: Control) -> bool:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is TalentTreeBranch:
			return true
		ancestor = ancestor.get_parent()
	return false

func _emit_navigation(id: StringName) -> void:
	navigate_requested.emit(id)

func _emit_level_selected(id: StringName) -> void:
	level_selected.emit(id)

func _emit_job_start(id: StringName) -> void:
	clinic_job_start_requested.emit(id)

func _emit_research_purchase(id: StringName) -> void:
	var button := research_buy_buttons.get(id) as Button
	if button == null or not bool(button.get_meta(&"research_available", false)):
		return
	research_purchase_requested.emit(id)

func _select_research_tab(tab: StringName, emit_change: bool = true) -> void:
	current_research_tab = &"talents" if tab == &"talents" else &"research"
	_apply_progression_screen_model()
	if emit_change:
		research_tab_changed.emit(current_research_tab)

func _restore_talent_focus(id: StringName) -> void:
	if current_research_tab != &"talents":
		return
	var button := talent_buttons.get(id) as Button
	if button != null and button.is_visible_in_tree():
		button.grab_focus()
		if talent_scroll != null:
			talent_scroll.ensure_control_visible(button)

func _focus_first_talent_node() -> void:
	if current_research_tab != &"talents" or talent_tree_branches.is_empty():
		return
	var button := talent_tree_branches[0].root_button() as Button
	if button == null or not button.is_visible_in_tree():
		return
	button.grab_focus()
	if talent_scroll != null:
		talent_scroll.ensure_control_visible(button)

func _configure_talent_tree_exits() -> void:
	if talent_tree_branches.is_empty() or talent_grid == null:
		return
	var columns := maxi(1, talent_grid.columns)
	var neutral_exit: Control = talent_reset_button if talent_reset_button != null and not talent_reset_button.disabled and talent_reset_button.is_visible_in_tree() else talent_tab_button
	for index in range(talent_tree_branches.size()):
		var branch := talent_tree_branches[index]
		if not is_instance_valid(branch):
			continue
		var column := index % columns
		var row := index / columns
		var left_exit: Control = neutral_exit
		var right_exit: Control = neutral_exit
		if column > 0:
			left_exit = talent_tree_branches[index - 1].root_button()
		if column + 1 < columns and index + 1 < talent_tree_branches.size():
			right_exit = talent_tree_branches[index + 1].root_button()
		var top_exit: Control = neutral_exit
		if row > 0:
			var previous_row_start := (row - 1) * columns
			var previous_row_end := mini(previous_row_start + columns - 1, talent_tree_branches.size() - 1)
			var above_index := clampi(previous_row_start + column, previous_row_start, previous_row_end)
			top_exit = talent_tree_branches[above_index].root_button()
		var bottom_exit: Control = neutral_exit
		var next_row_start := (row + 1) * columns
		if next_row_start < talent_tree_branches.size():
			var next_row_end := mini(next_row_start + columns - 1, talent_tree_branches.size() - 1)
			var below_index := clampi(next_row_start + column, next_row_start, next_row_end)
			bottom_exit = talent_tree_branches[below_index].root_button()
		branch.configure_focus_exits(top_exit, left_exit, right_exit, bottom_exit)

func _emit_talent_toggle(id: StringName) -> void:
	var button := talent_buttons.get(id) as Button
	if button == null:
		return
	if not bool(button.get_meta(&"talent_selectable", false)):
		button.set_pressed_no_signal(bool(button.get_meta(&"talent_active", false)))
		return
	talent_toggle_requested.emit(id)

func _on_preparation_slot_clear(slot_index: int) -> void:
	preparation_slot_clear_requested.emit(slot_index)

func _on_preparation_slot_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed(&"ui_accept"):
		preparation_slot_keyboard_activation = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		preparation_slot_keyboard_activation = false

func _on_preparation_slot_pressed(slot_id: StringName) -> void:
	if preparation_locked or not LoadoutSlotId.planning().has(slot_id) or planning_snapshot.mode == PlanningSnapshot.Mode.REPLACE_CONFIRM:
		return
	var navigation_activation := preparation_slot_keyboard_activation \
		or (input_glyph_service != null and input_glyph_service.method() == InputGlyphService.GAMEPAD)
	preparation_slot_keyboard_activation = false
	var current_id := _preparation_component_at(slot_id)
	planning_snapshot.begin_component_pick(slot_id, current_id)
	preparation_selecting_reserve = false
	_refresh_preparation_slot_styles()
	_rebuild_preparation_catalog(
		current_preparation_catalog_entries,
		current_preparation_unlocked_ids,
		current_preparation_selected_components,
		current_preparation_component_slots
	)
	_apply_preparation_editor_state(false)
	_apply_preparation_layout()
	_scroll_preparation_to_editor.call_deferred()
	_prepare_preparation_catalog_focus.bind(navigation_activation).call_deferred()

func _build_preparation_slot_card(slot_id: StringName) -> Button:
	var button := Button.new()
	button.name = "Slot_%s" % String(slot_id)
	button.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTION_CARD
	button.custom_minimum_size = Vector2(0.0, 58.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.text = ""
	_apply_preparation_slot_style(button, false)
	PreparationBioLumenSurfaceFill.attach(button)

	var margin := _margin(11, 7, 10, 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	var icon := SimpleIcon.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(&"plus", Color("51d6cb"))
	row.add_child(icon)
	preparation_slot_icons[slot_id] = icon
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	var title := _label(_loadout_slot_caption(slot_id), 14, Color("edf5ef"))
	title.name = "Title"
	title.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	preparation_slot_titles[slot_id] = title
	var description := _label("Freier Platz", 13, Color("a8c9c6"))
	description.name = "Description"
	description.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(description)
	preparation_slot_descriptions[slot_id] = description
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size.x = 40.0
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 4)
	row.add_child(right)
	var cost := _label("0", 14, Color("f0bc57"))
	cost.name = "Cost"
	cost.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cost)
	preparation_slot_costs[slot_id] = cost
	var dot := Panel.new()
	dot.name = "StatusDot"
	dot.custom_minimum_size = Vector2(5.0, 5.0)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_END
	dot.add_theme_stylebox_override("panel", _panel_style(Color("51d6cb"), Color.TRANSPARENT, 0, 3))
	right.add_child(dot)
	preparation_slot_status_dots[slot_id] = dot
	return button

func _apply_preparation_slot_style(button: Button, selected: bool) -> void:
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, PreparationBioLumenStyle.slot(state, selected))

func _apply_preparation_candidate_style(button: Button, available: bool, assigned: bool) -> void:
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, PreparationBioLumenStyle.candidate(state, available, assigned))

func _apply_preparation_primary_style(button: Button) -> void:
	button.set_meta(&"disable_motion_scale", true)
	button.theme_type_variation = AlveolusVisualTheme.TYPE_PRIMARY_BUTTON
	button.custom_minimum_size.y = AlveolusVisualTheme.BUTTON_HEIGHT_PRIMARY
	button.add_theme_font_size_override("font_size", AlveolusVisualTheme.TEXT_ACTION)
	button.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	for color_name in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(color_name, COLOR_BG)
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, PreparationBioLumenStyle.primary(state))
	UISoundService.set_sound_role(button, UISoundService.CONFIRM)

func _apply_preparation_navigation_style(button: Button) -> void:
	button.set_meta(&"disable_motion_scale", true)
	button.theme_type_variation = AlveolusVisualTheme.TYPE_SECONDARY_BUTTON
	button.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	button.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	button.add_theme_font_size_override("font_size", 14)
	for color_name in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(color_name, Color("edf5ef"))
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, PreparationBioLumenStyle.navigation(state))
	# The fill is inset by one pixel. Matching inner radii prevent the former
	# transparent wedges at the large left corners.
	PreparationBioLumenSurfaceFill.attach(
		button,
		PreparationBioLumenSurfaceFill.NORMAL_LEFT,
		PreparationBioLumenSurfaceFill.NORMAL_RIGHT,
		11.0,
		3.0
	)

func _apply_preparation_remove_style(button: Button) -> void:
	button.set_meta(&"disable_motion_scale", true)
	button.theme_type_variation = AlveolusVisualTheme.TYPE_DANGER_BUTTON
	button.custom_minimum_size = Vector2(86.0, 26.0)
	button.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	button.add_theme_font_size_override("font_size", 12)
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, PreparationBioLumenStyle.inline_remove_action(state))
	if button is IconTextButtonComponent:
		var icon_button := button as IconTextButtonComponent
		icon_button.content_inset.add_theme_constant_override("margin_left", 4)
		icon_button.content_inset.add_theme_constant_override("margin_top", 1)
		icon_button.content_inset.add_theme_constant_override("margin_right", 4)
		icon_button.content_inset.add_theme_constant_override("margin_bottom", 1)
		icon_button.content_row.add_theme_constant_override("separation", 3)
		icon_button.icon_view.custom_minimum_size = Vector2(12.0, 12.0)
		icon_button.caption.add_theme_font_override("font", AlveolusVisualTheme.body_font())
		icon_button.caption.add_theme_font_size_override("font_size", 12)
		icon_button.caption.add_theme_color_override("font_color", Color("ff8b7a"))
	UISoundService.set_sound_role(button, UISoundService.PRESS)

func _refresh_preparation_slot_content(slot_id: StringName, component_id: StringName, entry: Variant) -> void:
	var title_label := preparation_slot_titles.get(slot_id, null) as Label
	var description_label := preparation_slot_descriptions.get(slot_id, null) as Label
	var cost_label := preparation_slot_costs.get(slot_id, null) as Label
	var icon := preparation_slot_icons.get(slot_id, null) as SimpleIcon
	if title_label == null or description_label == null or cost_label == null or icon == null:
		return
	var caption := _loadout_slot_caption(slot_id)
	if component_id == &"":
		title_label.text = "%s · Wählen" % caption
		description_label.text = "Freier Platz"
		cost_label.text = "0"
		icon.configure(&"plus", Color("51d6cb"))
		return
	var component_title := String(_view_value(entry, &"title", String(component_id)))
	var cost := int(_view_value(entry, &"capacity_cost", _view_value(entry, &"cost", 0)))
	var visual_id := StringName(_view_value(entry, &"visual_id", component_id))
	var kind_value: Variant = _view_value(entry, &"kind", LoadoutSlotId.expected_kind(slot_id))
	var icon_kind := visual_id if SimpleIcon.supports(visual_id) else _component_icon_kind(kind_value)
	title_label.text = "%s · %s" % [caption, component_title]
	description_label.text = _preparation_slot_short_description(component_id, entry)
	cost_label.text = "%d" % cost
	icon.configure(icon_kind, Color("51d6cb"))

func _preparation_slot_short_description(component_id: StringName, entry: Variant) -> String:
	match component_id:
		&"precise", &"treatment_precision": return "Präziser Einzelimpuls"
		&"focus", &"ability_focus_field": return "Verstärkt das Zielgebiet"
		&"emergency", &"ability_emergency_support": return "Leben und Schild"
		&"shield", &"ability_defense_burst": return "AoE-Schaden und Rückstoß"
	var description := String(_view_value(entry, &"description", _view_value(entry, &"effect", "Vorbereitete Komponente")))
	var first_sentence := description.get_slice(".", 0).strip_edges()
	return first_sentence if not first_sentence.is_empty() else "Vorbereitete Komponente"

func _refresh_preparation_slot_styles() -> void:
	for slot_id_value in preparation_slot_buttons:
		var slot_id := StringName(slot_id_value)
		var button := preparation_slot_buttons[slot_id] as Button
		var selected := planning_snapshot.mode != PlanningSnapshot.Mode.BROWSE and planning_snapshot.selected_slot_id == slot_id
		button.set_meta(&"selected_slot", selected)
		var membrane := button.get_node_or_null("MembraneFill") as PreparationBioLumenSurfaceFill
		if membrane != null:
			membrane.set_selected(selected)
		# Height is the persistent selected-target cue for every editable plan slot.
		# Hover and focus remain geometry-neutral.
		var expanded_selection := selected \
			and planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK \
			and not preparation_locked
		button.custom_minimum_size.y = 72.0 if expanded_selection else 58.0
		_apply_preparation_slot_style(button, selected)
		var component_id := _preparation_component_at(slot_id)
		_refresh_preparation_slot_content(slot_id, component_id, current_preparation_catalog_by_id.get(component_id, null))

func _show_preparation_slot_preview(slot_id: StringName, source: Control = null, from_hover: bool = false) -> void:
	if not from_hover:
		return
	if preparation_inspector_title == null or planning_snapshot.mode == PlanningSnapshot.Mode.REPLACE_CONFIRM:
		return
	var component_id := _preparation_component_at(slot_id)
	var entry: Variant = current_preparation_catalog_by_id.get(component_id, null)
	var title := String(_view_value(entry, &"title", "Leer")) if component_id != &"" else "Leer"
	var description := String(_view_value(entry, &"description", _view_value(entry, &"effect", "Noch nicht belegt."))) if component_id != &"" else "Noch nicht belegt."
	preparation_inspector_title.text = "%s · %s" % [_loadout_slot_caption(slot_id), title]
	preparation_inspector_description.text = description.get_slice(".", 0).strip_edges()
	preparation_inspector_meta.text = ""
	preparation_inspector_meta.hide()
	_show_preparation_tooltip(source, from_hover)


func _preparation_slot_context_payload(slot_id: StringName) -> Dictionary:
	var component_id := _preparation_component_at(slot_id)
	var entry: Variant = current_preparation_catalog_by_id.get(component_id, null)
	var title := String(_view_value(entry, &"title", "Leer")) if component_id != &"" else "Leer"
	var description := String(_view_value(entry, &"description", _view_value(entry, &"effect", "Noch nicht belegt."))) if component_id != &"" else "Noch nicht belegt."
	var kind_value: Variant = _view_value(entry, &"kind", LoadoutSlotId.expected_kind(slot_id))
	var visual_id := StringName(_view_value(entry, &"visual_id", component_id))
	var icon_kind := visual_id if component_id != &"" and SimpleIcon.supports(visual_id) else (_component_icon_kind(kind_value) if component_id != &"" else &"plus")
	return {
		"title": "%s · %s" % [_loadout_slot_caption(slot_id), title],
		"body": description,
		"meta": "Belegt" if component_id != &"" else "Freier Planplatz",
		"accent": COLOR_GOLD if planning_snapshot.selected_slot_id == slot_id else COLOR_TEAL,
		"icon_kind": icon_kind,
	}

func _loadout_slot_caption(slot_id: StringName) -> String:
	match slot_id:
		LoadoutSlotId.TREATMENT: return "Behandlung"
		LoadoutSlotId.ACTIVE_1: return "Aktiv 1"
		LoadoutSlotId.ACTIVE_2: return "Aktiv 2"
		LoadoutSlotId.PASSIVE_1: return "Passiv 1"
		LoadoutSlotId.PASSIVE_2: return "Passiv 2"
		LoadoutSlotId.RESERVE: return "Reserve"
	return "Planplatz"

func show_preparation_replacement(component_id: StringName, compatible_slots: Array[StringName], capacity_before: int, capacity_after_by_slot: Dictionary = {}) -> void:
	if compatible_slots.is_empty():
		show_preparation_error("Für diese Komponente ist kein passender Planplatz verfügbar.")
		return
	var target_slot := planning_snapshot.selected_slot_id
	if not compatible_slots.has(target_slot):
		target_slot = compatible_slots[0]
	var candidate: Variant = current_preparation_catalog_by_id.get(component_id, null)
	var current_id := _preparation_component_at(target_slot)
	var current: Variant = current_preparation_catalog_by_id.get(current_id, null)
	var after := int(capacity_after_by_slot.get(target_slot, capacity_before))
	planning_snapshot.begin_replace(
		target_slot,
		current_id,
		component_id,
		capacity_before,
		after,
		String(_view_value(current, &"title", String(current_id))),
		String(_view_value(candidate, &"title", String(component_id))),
		String(_view_value(candidate, &"description", _view_value(candidate, &"effect", ""))),
		int(_view_value(candidate, &"capacity_cost", _view_value(candidate, &"cost", 0)))
	)
	preparation_replacement_slots = [target_slot]
	preparation_confirm_current.text = "%s\n%s" % [_loadout_slot_caption(target_slot), planning_snapshot.current_title]
	preparation_confirm_candidate.text = "%s · %d\n%s" % [planning_snapshot.candidate_title, planning_snapshot.candidate_cost, planning_snapshot.candidate_description]
	preparation_confirm_capacity.text = planning_snapshot.capacity_change_text(current_preparation_capacity_limit)
	_set_preparation_validation("Austausch offen.", COLOR_GOLD)
	_apply_preparation_editor_state(false)
	_apply_preparation_layout()
	_scroll_preparation_to_editor.call_deferred()
	_prepare_optional_navigation_focus.call_deferred(preparation_editor_confirm, preparation_cancel_replacement_button)

func focus_preparation_slot(slot_id: StringName) -> void:
	if preparation_slot_buttons.has(slot_id):
		var button: Button = preparation_slot_buttons[slot_id]
		_grab_focus_if_valid.call_deferred(button)

func show_preparation_error(message: String) -> void:
	_set_preparation_validation(message if not message.is_empty() else "Diese Änderung ist nicht möglich.", COLOR_RED)

func _set_preparation_validation(message: String, color: Color) -> void:
	if preparation_validation == null:
		return
	preparation_validation.text = message
	preparation_validation.modulate = Color.WHITE
	preparation_validation.add_theme_color_override("font_color", color.lightened(0.12))

func _begin_reserve_selection() -> void:
	if preparation_locked or planning_snapshot.mode == PlanningSnapshot.Mode.REPLACE_CONFIRM:
		return
	preparation_selecting_reserve = true
	planning_snapshot.begin_reserve_pick(_preparation_component_at(LoadoutSlotId.RESERVE))
	_set_preparation_validation("Reserve wählen · ohne Kapazitätskosten.", COLOR_GOLD)
	_rebuild_preparation_catalog(
		current_preparation_catalog_entries,
		current_preparation_unlocked_ids,
		current_preparation_selected_components,
		current_preparation_component_slots
	)
	_apply_preparation_editor_state(false)
	_apply_preparation_layout()
	_scroll_preparation_to_editor.call_deferred()
	_prepare_preparation_catalog_focus.call_deferred()

func _rebuild_preparation_catalog(entries: Array, unlocked_ids: Variant = {}, selected_components: Array = [], component_slots: Dictionary = {}) -> void:
	preparation_inspector_source = null
	preparation_inspector_hover_source = null
	if preparation_inspector != null:
		preparation_inspector.hide()
	for child in preparation_catalog.get_children():
		preparation_catalog.remove_child(child)
		child.queue_free()
	preparation_component_buttons.clear()
	var selected_ids: Dictionary = {}
	for selected_component in selected_components:
		var selected_id := StringName(selected_component) if selected_component is String or selected_component is StringName else StringName(_view_value(selected_component, &"id", &""))
		selected_ids[selected_id] = true
	var required_kind := ""
	if planning_snapshot.mode in [PlanningSnapshot.Mode.COMPONENT_PICK, PlanningSnapshot.Mode.REPLACE_CONFIRM, PlanningSnapshot.Mode.RESERVE_PICK]:
		required_kind = _component_kind_for_slot(planning_snapshot.selected_slot_id)
	# Preserve the catalog's source order for every slot. Availability, current
	# assignment and locks are visual states only; they must never reshuffle the
	# player's learned spatial map when another plan slot is selected.
	var ordered_rows: Array[Dictionary] = []
	for entry in entries:
		var id := StringName(_view_value(entry, &"id", &""))
		var title := String(_view_value(entry, &"title", "Unbenannte Komponente"))
		var description := String(_view_value(entry, &"description", _view_value(entry, &"effect", "")))
		var kind_value: Variant = _view_value(entry, &"kind", &"")
		var kind := _component_kind_text(kind_value)
		if not required_kind.is_empty() and kind != required_kind:
			continue
		var cost := int(_view_value(entry, &"capacity_cost", _view_value(entry, &"cost", 0)))
		var unlocked_default := true
		if unlocked_ids is Dictionary and not (unlocked_ids as Dictionary).is_empty():
			unlocked_default = bool((unlocked_ids as Dictionary).get(id, (unlocked_ids as Dictionary).get(String(id), false)))
		var unlocked := bool(_view_value(entry, &"unlocked", unlocked_default))
		var selected := bool(_view_value(entry, &"selected", selected_ids.has(id)))
		var selected_slot := String(component_slots.get(id, component_slots.get(String(id), "")))
		var current_for_slot := id == planning_snapshot.current_component_id and planning_snapshot.selected_slot_id != &""
		var row := {
			"id": id,
			"title": title,
			"description": description,
			"kind_value": kind_value,
			"kind": kind,
			"cost": cost,
			"selected_slot": selected_slot,
			"entry": entry,
			"lock_reason": String(current_preparation_availability_reasons.get(id, current_preparation_availability_reasons.get(String(id), "Gesperrt"))),
		}
		if current_for_slot:
			row["state"] = &"current"
		elif not unlocked:
			row["state"] = &"locked"
		elif selected:
			row["state"] = &"assigned"
		else:
			row["state"] = &"available"
		ordered_rows.append(row)
	for row in ordered_rows:
		_add_preparation_catalog_row(row)
	if preparation_component_buttons.is_empty():
		var empty_label := _label("Keine weitere passende Komponente verfügbar.", 14, COLOR_MUTED)
		# An autowrapping Label reports a near-zero minimum width. Inside a
		# GridContainer that made the sentence wrap character by character and
		# inflated the scroll content to almost 900 px despite having one line.
		empty_label.custom_minimum_size = Vector2(220.0, 44.0)
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preparation_catalog.add_child(empty_label)
	_configure_preparation_catalog_focus.call_deferred()

func _add_preparation_catalog_row(row: Dictionary) -> void:
	var id := StringName(row.get("id", &""))
	var title := String(row.get("title", "Komponente"))
	var description := String(row.get("description", ""))
	var kind_value: Variant = row.get("kind_value", &"")
	var kind := String(row.get("kind", ""))
	var cost := int(row.get("cost", 0))
	var selected_slot := String(row.get("selected_slot", ""))
	var state := StringName(row.get("state", &"available"))
	var lock_reason := String(row.get("lock_reason", "Gesperrt"))
	var available := state == &"available"
	var locked := state == &"locked"
	var assigned := state == &"assigned"
	var current := state == &"current"
	var button := Button.new()
	button.name = "Component_%s" % String(id)
	button.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTION_CARD
	button.custom_minimum_size = Vector2(0.0, 56.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	# Locked and already assigned rows remain focusable so keyboard/gamepad users
	# can inspect the same explanation as mouse users. Availability is semantic
	# state, not a reason to remove the card from navigation.
	button.disabled = false
	button.tooltip_text = ""
	button.set_meta(&"component_title", title)
	button.set_meta(&"component_id", id)
	button.set_meta(&"component_description", description)
	button.set_meta(&"component_kind", kind)
	button.set_meta(&"component_cost", cost)
	button.set_meta(&"catalog_state", state)
	button.set_meta(&"catalog_available", available)
	button.set_meta(&"catalog_lock_reason", lock_reason)
	button.set_meta(&"stable_focus_id", id)
	UISoundService.set_sound_role(button, UISoundService.CONFIRM if available else (UISoundService.NONE if current else UISoundService.ERROR))
	_apply_preparation_candidate_style(button, available, assigned or current)
	PreparationBioLumenSurfaceFill.attach(button)
	button.pressed.connect(_on_preparation_component.bind(id, _component_is_passive(kind_value)))
	button.mouse_entered.connect(_show_preparation_component_inspector.bind(id, button, true))
	button.mouse_exited.connect(_hide_preparation_tooltip.bind(button, true))
	button.focus_entered.connect(_ensure_preparation_focus_visible.bind(button))
	register_context_detail(button, _preparation_component_context_payload.bind(id), false)
	preparation_catalog.add_child(button)
	preparation_component_buttons[id] = button
	var margin := _margin(10, 6, 10, 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 7)
	margin.add_child(heading)
	var row_icon := SimpleIcon.new()
	row_icon.name = "StateIcon"
	row_icon.custom_minimum_size = Vector2(26.0, 26.0)
	var visual_id := StringName(_view_value(row.get("entry", null), &"visual_id", id))
	var icon_kind := visual_id if SimpleIcon.supports(visual_id) else _component_icon_kind(kind_value)
	if locked:
		icon_kind = &"locked"
	var muted_content := COLOR_MUTED.darkened(0.24)
	row_icon.configure(icon_kind, muted_content if locked else (COLOR_MUTED if assigned or current else Color("51d6cb")))
	heading.add_child(row_icon)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.add_theme_constant_override("separation", 0)
	heading.add_child(title_stack)
	var title_label := _label(title, 14, muted_content if locked else (COLOR_MUTED if assigned or current else Color("edf5ef")))
	title_label.name = "Title"
	title_label.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_stack.add_child(title_label)
	var state_text := ""
	if locked:
		state_text = lock_reason
	elif assigned:
		state_text = "In %s" % selected_slot
	var state_label := _label(state_text, 12, Color("708a8c") if locked else Color("a8c9c6"))
	state_label.name = "State"
	state_label.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state_label.visible = not state_text.is_empty()
	title_stack.add_child(state_label)
	var cost_text := "0" if planning_snapshot.mode == PlanningSnapshot.Mode.RESERVE_PICK else "%d" % cost
	var cost_label := _label(cost_text, 14, Color("8aa2a1") if current else (muted_content if not available else Color("f0bc57")))
	cost_label.name = "Cost"
	cost_label.custom_minimum_size.x = 40.0
	cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_label.add_theme_font_override("font", AlveolusVisualTheme.body_font())
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(cost_label)
func _on_preparation_component(id: StringName, is_passive: bool) -> void:
	if preparation_locked:
		return
	var button := preparation_component_buttons.get(id, null) as Button
	if button == null or not bool(button.get_meta(&"catalog_available", false)):
		return
	if planning_snapshot.mode == PlanningSnapshot.Mode.RESERVE_PICK or preparation_selecting_reserve:
		if not is_passive:
			return
		preparation_selecting_reserve = false
		preparation_reserve_requested.emit(id)
		return
	if planning_snapshot.mode != PlanningSnapshot.Mode.COMPONENT_PICK or planning_snapshot.selected_slot_id == &"":
		return
	planning_snapshot.candidate_component_id = id
	planning_snapshot.focus_return_id = id
	preparation_slot_component_requested.emit(planning_snapshot.selected_slot_id, id)

func _show_preparation_component_inspector(id: StringName, source: Control = null, from_hover: bool = false) -> void:
	if not from_hover:
		return
	var entry: Variant = current_preparation_catalog_by_id.get(id, null)
	if entry == null or preparation_inspector_title == null:
		return
	var title := String(_view_value(entry, &"title", String(id)))
	var description := String(_view_value(entry, &"description", _view_value(entry, &"effect", "Keine Beschreibung verfügbar.")))
	var current_id := _preparation_component_at(planning_snapshot.selected_slot_id)
	preparation_inspector_title.text = title
	var button := preparation_component_buttons.get(id, null) as Button
	var state := StringName(button.get_meta(&"catalog_state", &"available")) if button != null else &"available"
	if state == &"locked":
		preparation_inspector_description.text = description.get_slice(".", 0).strip_edges()
		preparation_inspector_meta.text = String(button.get_meta(&"catalog_lock_reason", "Gesperrt")) if button != null else "Gesperrt"
	elif state == &"assigned":
		preparation_inspector_description.text = description.get_slice(".", 0).strip_edges()
		preparation_inspector_meta.text = "In anderem Planplatz"
	elif state == &"current":
		preparation_inspector_description.text = description.get_slice(".", 0).strip_edges()
		preparation_inspector_meta.text = ""
	elif planning_snapshot.mode == PlanningSnapshot.Mode.RESERVE_PICK:
		preparation_inspector_description.text = description.get_slice(".", 0).strip_edges()
		preparation_inspector_meta.text = "Ohne Plankapazität"
	else:
		preparation_inspector_description.text = _preparation_comparison_copy(current_id, id, description)
		preparation_inspector_meta.text = ""
	preparation_inspector_meta.visible = not preparation_inspector_meta.text.is_empty()
	_show_preparation_tooltip(source, from_hover)


func _preparation_component_context_payload(id: StringName) -> Dictionary:
	var entry: Variant = current_preparation_catalog_by_id.get(id, null)
	if entry == null:
		return {}
	var title := String(_view_value(entry, &"title", String(id)))
	var description := String(_view_value(entry, &"description", _view_value(entry, &"effect", "Keine Beschreibung verfügbar.")))
	var cost := int(_view_value(entry, &"capacity_cost", _view_value(entry, &"cost", 0)))
	var kind_value: Variant = _view_value(entry, &"kind", &"")
	var visual_id := StringName(_view_value(entry, &"visual_id", id))
	var icon_kind := visual_id if SimpleIcon.supports(visual_id) else _component_icon_kind(kind_value)
	var button := preparation_component_buttons.get(id, null) as Button
	var state := StringName(button.get_meta(&"catalog_state", &"available")) if button != null else &"available"
	var meta := "%d" % cost
	match state:
		&"locked": meta = "%d · %s" % [cost, String(button.get_meta(&"catalog_lock_reason", "Gesperrt")) if button != null else "Gesperrt"]
		&"assigned": meta = "%d · In anderem Planplatz" % cost
		&"current": meta = "%d · Aktueller Inhalt" % cost
		_:
			if planning_snapshot.mode == PlanningSnapshot.Mode.RESERVE_PICK:
				meta = "Ohne Plankapazität"
	return {
		"title": title,
		"body": _preparation_comparison_copy(_preparation_component_at(planning_snapshot.selected_slot_id), id, description),
		"meta": meta,
		"accent": COLOR_MUTED if state in [&"locked", &"assigned", &"current"] else COLOR_TEAL,
		"icon_kind": icon_kind,
	}

func _preparation_comparison_copy(current_id: StringName, candidate_id: StringName, fallback: String) -> String:
	if current_id in [&"precise", &"treatment_precision"]:
		match candidate_id:
			&"spread", &"treatment_spread": return "drei Ziele statt einem"
			&"pierce", &"treatment_pierce": return "mehrere Ziele in einer Linie"
	return fallback.get_slice(".", 0).strip_edges()

func _preparation_comparison_delta(current_id: StringName, candidate_id: StringName, cost: int) -> String:
	if current_id in [&"precise", &"treatment_precision"]:
		match candidate_id:
			&"spread", &"treatment_spread": return "1 Ziel → 3 Ziele"
			&"pierce", &"treatment_pierce": return "Einzelziel → Linie"
	return "%d · direkt einsetzen" % cost

func _component_kind_for_slot(slot_id: StringName) -> String:
	match LoadoutSlotId.expected_kind(slot_id):
		&"treatment": return "BEHANDLUNG"
		&"ability": return "AKTIV"
		&"passive": return "PASSIV"
	return ""

func _component_icon_kind(kind: Variant) -> StringName:
	match _component_kind_text(kind):
		"BEHANDLUNG": return &"treatment"
		"AKTIV": return &"ability"
		_: return &"passive"

func _preparation_component_at(slot_id: StringName) -> StringName:
	return StringName(str(current_preparation_slots.get(slot_id, current_preparation_slots.get(String(slot_id), ""))))

func _apply_preparation_editor_state(tutorial_locked: bool = false) -> void:
	if preparation_editor_browse == null:
		return
	var mode := planning_snapshot.mode
	if mode == PlanningSnapshot.Mode.BROWSE:
		planning_snapshot.begin_component_pick(LoadoutSlotId.TREATMENT, _preparation_component_at(LoadoutSlotId.TREATMENT))
		mode = planning_snapshot.mode
	preparation_editor_browse.hide()
	preparation_editor_picker.visible = mode in [PlanningSnapshot.Mode.COMPONENT_PICK, PlanningSnapshot.Mode.RESERVE_PICK]
	preparation_editor_confirm.visible = mode == PlanningSnapshot.Mode.REPLACE_CONFIRM
	match mode:
		PlanningSnapshot.Mode.BROWSE:
			preparation_editor_title.text = "Planplatz wählen"
			preparation_editor_hint.text = "Ein Platz bestimmt eindeutig, was gefüllt oder ersetzt wird."
		PlanningSnapshot.Mode.COMPONENT_PICK:
			preparation_editor_title.text = "EINFÜHRUNGSPLAN" if tutorial_locked else _loadout_slot_caption(planning_snapshot.selected_slot_id).to_upper()
			var current_id := _preparation_component_at(planning_snapshot.selected_slot_id)
			var current_entry: Variant = current_preparation_catalog_by_id.get(current_id, null)
			var current_title := String(_view_value(current_entry, &"title", "Leer")) if current_id != &"" else "Leer"
			preparation_editor_hint.text = "Für die Einführung festgelegt" if tutorial_locked else "Aktuell: %s · Aktivieren setzt direkt ein" % current_title
		PlanningSnapshot.Mode.RESERVE_PICK:
			preparation_editor_title.text = "RESERVE"
			preparation_editor_hint.text = "Passiv wählen · ohne Plankapazität"
		PlanningSnapshot.Mode.REPLACE_CONFIRM:
			preparation_editor_title.text = "%s ERSETZEN" % _loadout_slot_caption(planning_snapshot.selected_slot_id).to_upper()
			preparation_editor_hint.text = "Bisher und neu direkt vergleichen."
	var modal_edit := mode == PlanningSnapshot.Mode.REPLACE_CONFIRM
	for slot_id in preparation_slot_buttons:
		var slot_button: Button = preparation_slot_buttons[slot_id]
		AlveolusUIComponents.set_button_disabled(slot_button, tutorial_locked or modal_edit)
	preparation_reserve_button.disabled = true
	preparation_intro_skip_button.disabled = modal_edit
	if preparation_header_back_button != null:
		AlveolusUIComponents.set_button_disabled(preparation_header_back_button, modal_edit)
	for component_button in preparation_component_buttons.values():
		var button := component_button as Button
		AlveolusUIComponents.set_button_disabled(button, tutorial_locked or modal_edit)
	var selected_current := _preparation_component_at(planning_snapshot.selected_slot_id)
	var can_remove := mode == PlanningSnapshot.Mode.COMPONENT_PICK and selected_current != &"" and planning_snapshot.selected_slot_id != LoadoutSlotId.TREATMENT and not tutorial_locked
	preparation_remove_button.visible = can_remove
	AlveolusUIComponents.set_button_disabled(preparation_remove_button, modal_edit)
	if tutorial_locked:
		_show_preparation_slot_context()
	preparation_start_button.disabled = preparation_start_button.disabled or modal_edit
	AlveolusUIComponents.refresh_button_state(preparation_start_button)
	preparation_lock_panel.visible = tutorial_locked
	preparation_editor_back_button.hide()
	_refresh_preparation_slot_styles()
	_configure_focus_cycle.call_deferred(preparation_overlay)
	_configure_preparation_catalog_focus.call_deferred()

func _apply_preparation_layout() -> void:
	if root == null or preparation_workspace == null:
		return
	var logical_width := root.size.x
	var compact := logical_width < 920.0
	var fixed_desktop := not compact and root.size.y >= 650.0
	preparation_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if fixed_desktop else Control.SIZE_EXPAND_FILL
	preparation_scroll.custom_minimum_size.y = 508.0 if fixed_desktop else 0.0
	preparation_workspace.columns = 1 if compact else 2
	preparation_slots.columns = (2 if logical_width >= 620.0 else 1) if compact else 1
	preparation_case_row.columns = 2 if logical_width >= 760.0 else 1
	preparation_case_facts.custom_minimum_size.x = 320.0 if preparation_case_row.columns == 2 else 0.0
	preparation_trait_panel.custom_minimum_size.y = 118.0 if preparation_case_row.columns == 1 else 84.0
	preparation_trait_panel.show()
	if preparation_lock_stack != null:
		preparation_lock_stack.custom_minimum_size.x = 220.0 if compact else 320.0
		preparation_lock_stack.add_theme_constant_override("separation", 4 if compact else 8)
	if preparation_lock_icon != null:
		preparation_lock_icon.custom_minimum_size = Vector2(34.0, 34.0) if compact else Vector2(58.0, 58.0)
	if preparation_lock_copy != null:
		preparation_lock_copy.visible = not compact
	if preparation_lock_title != null:
		preparation_lock_title.text = "EINFÜHRUNGSPLAN FESTGELEGT" if compact else "EINFÜHRUNGSPLAN"
	preparation_trait_row.custom_minimum_size.x = 0.0
	var compact_plan_height := 250.0 if logical_width >= 620.0 else 386.0
	var planning_view_width := preparation_scroll.size.x if preparation_scroll != null and preparation_scroll.size.x > logical_width * 0.5 else logical_width - float(AlveolusVisualTheme.SCREEN_MARGIN * 2)
	var desktop_plan_width := maxf(0.0, (planning_view_width - 14.0) * 0.44)
	# Compact planning has one scroll authority: the outer document viewport.
	# Let the dense two-column catalog expose its full content height instead of
	# nesting a second vertical scroll area inside the editor.
	var catalog_columns := 2 if logical_width >= 480.0 else 1
	preparation_catalog.columns = catalog_columns
	var catalog_rows := ceili(float(preparation_catalog.get_child_count()) / float(catalog_columns))
	var catalog_content_height := float(catalog_rows * 56 + maxi(0, catalog_rows - 1) * 8)
	if preparation_catalog_scroll != null:
		preparation_catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if compact else ScrollContainer.SCROLL_MODE_AUTO
		preparation_catalog_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
		preparation_catalog_scroll.custom_minimum_size.y = catalog_content_height if compact else 0.0
	preparation_plan_panel.custom_minimum_size = Vector2(0.0 if compact else desktop_plan_width, compact_plan_height if compact else PREPARATION_PANEL_HEIGHT)
	preparation_plan_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_BEGIN
	preparation_catalog_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var confirm_height := 300.0 if logical_width >= 760.0 else PREPARATION_PANEL_HEIGHT
	var editor_height := confirm_height if planning_snapshot.mode == PlanningSnapshot.Mode.REPLACE_CONFIRM else PREPARATION_PANEL_HEIGHT
	if compact and planning_snapshot.mode != PlanningSnapshot.Mode.REPLACE_CONFIRM:
		editor_height = maxf(editor_height, catalog_content_height + 112.0)
	preparation_catalog_panel.custom_minimum_size = Vector2(0.0, editor_height)
	if preparation_workspace_host != null:
		var workspace_height := PREPARATION_PANEL_HEIGHT
		if compact and not preparation_locked:
			workspace_height = compact_plan_height + editor_height + 14.0
		preparation_workspace_host.custom_minimum_size.y = workspace_height
		preparation_workspace_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if preparation_inspector_footer != null:
		preparation_inspector_footer.columns = 1
	if preparation_validation != null:
		preparation_validation.visible = logical_width >= 620.0
	preparation_plan_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preparation_catalog_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Compact cards remain readable in two columns down to the smallest required
	# 960x540 viewport at 200 %, exposing up to eight options before scrolling.
	preparation_confirm_compare.columns = 2 if logical_width >= 760.0 else 1
	preparation_plan_panel.show()
	preparation_catalog_panel.show()
	preparation_editor_back_button.hide()
	_layout_preparation_tooltip.call_deferred()
	_update_preparation_workspace_ratio.call_deferred()
	_configure_preparation_catalog_focus.call_deferred()

func _update_preparation_workspace_ratio() -> void:
	if preparation_workspace == null or preparation_plan_panel == null or preparation_catalog_panel == null:
		return
	if preparation_workspace.columns != 2 or preparation_workspace.size.x <= 14.0:
		return
	var desired_plan_width := (preparation_workspace.size.x - 14.0) * 0.44
	if absf(preparation_plan_panel.custom_minimum_size.x - desired_plan_width) <= 0.5:
		return
	preparation_plan_panel.custom_minimum_size.x = desired_plan_width

func _scroll_preparation_to_start() -> void:
	if preparation_scroll == null:
		return
	preparation_scroll.scroll_horizontal = 0
	preparation_scroll.scroll_vertical = 0

func _scroll_preparation_to_editor() -> void:
	if preparation_scroll == null or preparation_catalog_panel == null or preparation_workspace == null:
		return
	if preparation_workspace.columns == 1:
		# Align the editor itself, not a rebuilt child. ensure_control_visible on a
		# tall panel or candidate can choose either edge and caused compact captures
		# to jump between the plan, middle rows and the footer.
		var editor_top := preparation_catalog_panel.position.y
		if preparation_workspace_host != null:
			editor_top += preparation_workspace_host.position.y
		preparation_scroll.scroll_vertical = maxi(0, roundi(editor_top))
	else:
		preparation_scroll.scroll_vertical = 0


func _scroll_preparation_to_intro_lock() -> void:
	if preparation_scroll == null or preparation_workspace_host == null:
		return
	preparation_scroll.scroll_horizontal = 0
	if preparation_lock_stack != null:
		# The lock surface deliberately matches the full desktop workspace. On a
		# short 200-percent viewport its centered explanation would otherwise sit
		# below the first scrollful even when the panel top is aligned.
		preparation_scroll.ensure_control_visible(preparation_lock_stack)
	else:
		preparation_scroll.scroll_vertical = maxi(0, roundi(preparation_workspace_host.position.y))

func _prepare_initial_preparation_view(preferred: Control, tutorial_locked: bool) -> void:
	if tutorial_locked and preparation_workspace != null and preparation_workspace.columns == 1:
		# On the 200-percent compact canvas the dossier and the full lock surface
		# cannot fit simultaneously. Open on the lock explanation so the read-only
		# state is immediately clear instead of showing an apparently empty plan.
		_scroll_preparation_to_intro_lock.call_deferred()
		_prepare_optional_navigation_focus(preparation_overlay, preferred)
		return
	var compact_gamepad := preparation_workspace != null \
		and preparation_workspace.columns == 1 \
		and input_glyph_service != null \
		and input_glyph_service.method() == InputGlyphService.GAMEPAD \
		and not tutorial_locked
	if compact_gamepad:
		_scroll_preparation_to_editor()
		# When the stacked page scrolls to the editor, the focused plan slot is no
		# longer visible. Put gamepad focus on the first actionable candidate in
		# that same viewport instead of leaving a gold ring above the fold.
		var first := _first_available_preparation_component()
		_prepare_optional_navigation_focus(preparation_overlay, first)
		_configure_preparation_catalog_focus()
		if first != null:
			preparation_scroll.ensure_control_visible(first)
	else:
		_scroll_preparation_to_start()
		_prepare_optional_navigation_focus(preparation_overlay, preferred)

func _first_available_preparation_component() -> Button:
	var inspectable_fallback: Button = null
	for button_value in preparation_component_buttons.values():
		var button := button_value as Button
		if button != null and button.is_visible_in_tree() and not button.disabled:
			if inspectable_fallback == null:
				inspectable_fallback = button
			if bool(button.get_meta(&"catalog_available", false)):
				return button
	return inspectable_fallback

func _prepare_preparation_catalog_focus(force_navigation_focus: bool = false) -> void:
	var first := _first_available_preparation_component()
	var gamepad_navigation := input_glyph_service != null and input_glyph_service.method() == InputGlyphService.GAMEPAD
	var should_focus_candidate := force_navigation_focus or gamepad_navigation
	if should_focus_candidate:
		_configure_focus_cycle(preparation_overlay)
		if first != null:
			first.grab_focus()
	else:
		_prepare_optional_navigation_focus(preparation_overlay, first)
	_configure_preparation_catalog_focus()
	if first != null and preparation_workspace != null and preparation_workspace.columns == 1 \
		and should_focus_candidate:
		preparation_scroll.ensure_control_visible(first)
	if not should_focus_candidate:
		_show_preparation_slot_context()

func _show_preparation_slot_context() -> void:
	preparation_inspector_source = null
	preparation_inspector_hover_source = null
	if preparation_inspector != null:
		preparation_inspector.hide()

func _show_preparation_tooltip(source: Control = null, from_hover: bool = false) -> void:
	if not from_hover or preparation_inspector == null or preparation_locked or source == null:
		return
	preparation_inspector_hover_source = source
	preparation_inspector_source = source
	preparation_inspector.show()
	_layout_preparation_tooltip.call_deferred()

func _hide_preparation_tooltip(source: Control = null, _from_hover: bool = false) -> void:
	# Ignore stale exits when the pointer has already entered another card.
	if source != null and preparation_inspector_source != null and source != preparation_inspector_source:
		return
	_show_preparation_slot_context()

func _layout_preparation_tooltip() -> void:
	if preparation_inspector == null or root == null or not preparation_inspector.visible:
		return
	var source := preparation_inspector_source
	if source == null or not is_instance_valid(source) or not source.is_inside_tree():
		_show_preparation_slot_context()
		return
	var tooltip_parent := preparation_inspector.get_parent() as Control
	if tooltip_parent == null:
		return
	var tooltip_width := minf(252.0, maxf(220.0, root.size.x * 0.36))
	# Tooltip height follows its actual text. A fixed reserve produced a visible
	# empty band beneath short descriptions.
	preparation_inspector.custom_minimum_size = Vector2(tooltip_width, 0.0)
	preparation_inspector.size = Vector2(tooltip_width, 0.0)
	preparation_inspector.update_minimum_size()
	var tooltip_height := ceilf(preparation_inspector.get_combined_minimum_size().y)
	preparation_inspector.size = Vector2(tooltip_width, tooltip_height)
	var parent_inverse := tooltip_parent.get_global_transform().affine_inverse()
	var source_top_left := parent_inverse * source.get_global_transform().origin
	var source_bottom_right := parent_inverse * (source.get_global_transform() * source.size)
	var source_rect := Rect2(source_top_left, source_bottom_right - source_top_left)
	var outer_margin := 12.0 if root.size.x < 620.0 else 16.0
	var gap := 6.0
	var target := Vector2(source_rect.end.x + gap, source_rect.position.y)
	if target.x + tooltip_width > root.size.x - outer_margin:
		target.x = source_rect.position.x - tooltip_width - gap
	if target.x < outer_margin:
		target.x = clampf(source_rect.position.x, outer_margin, root.size.x - tooltip_width - outer_margin)
		target.y = source_rect.end.y + gap
	if target.y + tooltip_height > root.size.y - outer_margin:
		target.y = source_rect.position.y - tooltip_height - gap
	target.y = clampf(target.y, outer_margin, root.size.y - tooltip_height - outer_margin)
	preparation_inspector.position = target

func _configure_preparation_catalog_focus() -> void:
	if preparation_catalog == null or not preparation_catalog.is_visible_in_tree():
		return
	var cells: Array[Button] = []
	for child in preparation_catalog.get_children():
		if child is Button:
			cells.append(child as Button)
	if cells.is_empty():
		return
	var columns := maxi(1, preparation_catalog.columns)
	for index in range(cells.size()):
		var button := cells[index]
		if button.disabled or not button.is_visible_in_tree():
			continue
		var left := _preparation_catalog_neighbor(cells, index, -1, 0, columns)
		var right := _preparation_catalog_neighbor(cells, index, 1, 0, columns)
		var up := _preparation_catalog_neighbor(cells, index, 0, -1, columns)
		var down := _preparation_catalog_neighbor(cells, index, 0, 1, columns)
		if left != null:
			button.focus_neighbor_left = button.get_path_to(left)
		if right != null:
			button.focus_neighbor_right = button.get_path_to(right)
		if up != null:
			button.focus_neighbor_top = button.get_path_to(up)
		if down != null:
			button.focus_neighbor_bottom = button.get_path_to(down)
	var first := _first_available_preparation_component()
	if first == null:
		return
	var return_control: Control = null
	if preparation_plan_panel.visible and preparation_slot_buttons.has(planning_snapshot.selected_slot_id):
		return_control = preparation_slot_buttons[planning_snapshot.selected_slot_id]
	elif preparation_editor_back_button.visible:
		return_control = preparation_editor_back_button
	if return_control != null:
		return_control.focus_neighbor_right = return_control.get_path_to(first)
		return_control.focus_neighbor_bottom = return_control.get_path_to(first)
		first.focus_neighbor_left = first.get_path_to(return_control)


func _ensure_preparation_focus_visible(control: Control) -> void:
	if preparation_scroll == null or control == null or preparation_workspace == null:
		return
	if preparation_workspace.columns == 1 and preparation_scroll.is_ancestor_of(control):
		preparation_scroll.ensure_control_visible(control)

func _preparation_catalog_neighbor(cells: Array[Button], index: int, delta_x: int, delta_y: int, columns: int) -> Button:
	var column := index % columns
	var row := index / columns
	var max_rows := ceili(float(cells.size()) / float(columns))
	column += delta_x
	row += delta_y
	while column >= 0 and column < columns and row >= 0 and row < max_rows:
		var candidate_index := row * columns + column
		if candidate_index >= cells.size():
			return null
		var candidate := cells[candidate_index]
		if not candidate.disabled and candidate.is_visible_in_tree():
			return candidate
		column += delta_x
		row += delta_y
	return null

func _restore_preparation_focus() -> void:
	var focus_id := planning_snapshot.focus_return_id
	if preparation_component_buttons.has(focus_id):
		var component_button := preparation_component_buttons[focus_id] as Button
		if component_button != null and component_button.is_visible_in_tree() and not component_button.disabled:
			component_button.grab_focus()
			return
	# Direct replacement keeps the chosen component visible but marks it as the
	# current, non-actionable entry. Stay in the editor instead of falling back
	# to the plan slot and pulling the outer page back up.
	if planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK and preparation_catalog_panel.visible:
		_scroll_preparation_to_editor()
		if input_glyph_service != null and input_glyph_service.method() == InputGlyphService.GAMEPAD:
			var first_available := _first_available_preparation_component()
			if first_available != null:
				first_available.grab_focus()
		return
	if focus_id == LoadoutSlotId.RESERVE and preparation_reserve_button.is_visible_in_tree():
		preparation_reserve_button.grab_focus()
		return
	if preparation_slot_buttons.has(focus_id):
		focus_preparation_slot(focus_id)
		return
	if planning_snapshot.selected_slot_id != &"" and preparation_slot_buttons.has(planning_snapshot.selected_slot_id):
		focus_preparation_slot(planning_snapshot.selected_slot_id)
		return
	focus_preparation_slot(LoadoutSlotId.TREATMENT)

func _confirm_preparation_replacement() -> void:
	if planning_snapshot.mode != PlanningSnapshot.Mode.REPLACE_CONFIRM or planning_snapshot.selected_slot_id == &"":
		return
	preparation_slot_requested.emit(planning_snapshot.selected_slot_id)

func _cancel_preparation_replacement() -> void:
	if planning_snapshot.mode != PlanningSnapshot.Mode.REPLACE_CONFIRM:
		return
	var slot_id := planning_snapshot.selected_slot_id
	var candidate_id := planning_snapshot.candidate_component_id
	planning_snapshot.begin_component_pick(slot_id, _preparation_component_at(slot_id))
	planning_snapshot.focus_return_id = candidate_id
	preparation_replacement_slots.clear()
	_rebuild_preparation_catalog(
		current_preparation_catalog_entries,
		current_preparation_unlocked_ids,
		current_preparation_selected_components,
		current_preparation_component_slots
	)
	_apply_preparation_editor_state(false)
	_apply_preparation_layout()
	preparation_replacement_cancelled.emit()

func _remove_selected_preparation_slot() -> void:
	if preparation_locked or planning_snapshot.mode != PlanningSnapshot.Mode.COMPONENT_PICK:
		return
	var slot_id := planning_snapshot.selected_slot_id
	if slot_id == &"" or slot_id == LoadoutSlotId.TREATMENT or _preparation_component_at(slot_id) == &"":
		return
	preparation_slot_requested.emit(slot_id)

func _cancel_preparation_editor() -> void:
	cancel_preparation_step()

func cancel_preparation_step() -> bool:
	match planning_snapshot.mode:
		PlanningSnapshot.Mode.REPLACE_CONFIRM:
			_cancel_preparation_replacement()
			return true
		PlanningSnapshot.Mode.COMPONENT_PICK, PlanningSnapshot.Mode.RESERVE_PICK:
			return false
	return false

func complete_preparation_change(slot_id: StringName) -> void:
	var next_slot := slot_id if LoadoutSlotId.planning().has(slot_id) else LoadoutSlotId.TREATMENT
	planning_snapshot.begin_component_pick(next_slot, _preparation_component_at(next_slot))
	preparation_selecting_reserve = false
	preparation_replacement_slots.clear()

func _on_finding_reaction(id: StringName) -> void:
	current_finding_reaction = id
	AlveolusUIComponents.set_button_disabled(finding_confirm_button, not finding_swap_valid)
	finding_reaction_selected.emit(id)

func _on_finding_swap_toggled(enabled: bool) -> void:
	finding_outgoing_option.disabled = not enabled
	if not enabled:
		set_finding_swap_validation(true)
	_emit_finding_swap_preview()

func _on_finding_outgoing_selected(_index: int) -> void:
	_emit_finding_swap_preview()

func _emit_finding_swap_preview() -> void:
	var outgoing := _selected_finding_outgoing() if finding_swap_toggle.button_pressed else &""
	var incoming := current_finding_reserve if finding_swap_toggle.button_pressed else &""
	finding_reserve_swap_requested.emit(incoming, outgoing)

func _confirm_finding() -> void:
	if current_finding_reaction == &"":
		return
	var incoming := current_finding_reserve if finding_swap_toggle.button_pressed else &""
	var outgoing := _selected_finding_outgoing() if finding_swap_toggle.button_pressed else &""
	finding_confirmed.emit(current_finding_reaction, incoming, outgoing)

func _selected_finding_outgoing() -> StringName:
	var selected := finding_outgoing_option.selected
	if selected < 0 or selected >= current_finding_outgoing_ids.size():
		return &""
	return current_finding_outgoing_ids[selected]

func _component_kind_text(kind: Variant) -> String:
	var text := str(kind).to_upper()
	if text in ["0", "TREATMENT", "BEHANDLUNG"]:
		return "BEHANDLUNG"
	if text in ["1", "ABILITY", "AKTIV"]:
		return "AKTIV"
	return "PASSIV"

func _component_is_passive(kind: Variant) -> bool:
	return _component_kind_text(kind) == "PASSIV"


func _progression_inspector(accent: Color, icon_kind: StringName, title_text: String, description_text: String) -> Dictionary:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(0.0, 70.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _document_inset_style(accent))
	var margin := _margin(10, 7, 10, 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	var icon := SimpleIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(icon_kind, accent)
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	var title := _label(title_text, 15, COLOR_TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	var detail_row := HBoxContainer.new()
	detail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_row.add_theme_constant_override("separation", 10)
	copy.add_child(detail_row)
	var description := _label(description_text, 14, COLOR_MUTED)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	description.max_lines_visible = 2
	detail_row.add_child(description)
	var meta := _label("", 14, accent.lightened(0.18))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_row.add_child(meta)
	return {"panel": panel, "icon": icon, "title": title, "description": description, "meta": meta}


func _show_research_inspector(definition: ResearchDefinition, source: Control = null) -> void:
	if definition == null or research_inspector_title == null:
		return
	research_inspector_icon.configure(definition.id, COLOR_GOLD)
	research_inspector_title.text = definition.title
	research_inspector_description.text = definition.description
	var rank := 0
	var button := research_buy_buttons.get(definition.id) as Button
	if button != null:
		rank = int(button.get_meta(&"research_rank", 0))
	var compact := root != null and (root.size.x < 620.0 or root.size.y < 420.0)
	research_inspector_meta.text = "Rang %d/%d" % [rank, definition.max_level] if compact else "%s · Rang %d/%d" % [_research_category_text(definition.category), rank, definition.max_level]
	_position_progression_inspector(research_inspector_panel, source)


func _research_context_payload(definition: ResearchDefinition) -> Dictionary:
	if definition == null:
		return {}
	var button := research_buy_buttons.get(definition.id) as Button
	var rank := int(button.get_meta(&"research_rank", 0)) if button != null else 0
	var status := "MAXIMUM" if rank >= definition.max_level else "%d FORSCHEN" % definition.cost_for_rank(rank)
	return {
		"title": definition.title,
		"body": definition.description,
		"meta": "%s · Rang %d/%d · %s" % [
			_research_category_text(definition.category),
			rank,
			definition.max_level,
			status,
		],
		"accent": COLOR_GOLD,
		"icon_kind": definition.id,
	}


func _show_talent_inspector(
	title: String,
	effect: String,
	category: String,
	cost: int,
	status: String,
	requirement_text: String = "Einstieg des Astes",
	source: Control = null
) -> void:
	if talent_inspector_title == null:
		return
	talent_inspector_icon.configure(_talent_icon_kind(category), COLOR_TEAL if status.contains("AKTIV") else COLOR_BLUE)
	talent_inspector_title.text = title
	talent_inspector_description.text = effect
	var compact := root != null and (root.size.x < 620.0 or root.size.y < 420.0)
	talent_inspector_meta.text = "%d P · %s" % [cost, status] if compact else "%s · %d P · %s · Voraussetzung: %s" % [category, cost, status, requirement_text]
	_position_progression_inspector(talent_inspector_panel, source)


func _talent_context_payload(
	title: String,
	effect: String,
	category: String,
	cost: int,
	status: String,
	requirement_text: String = "Einstieg des Astes"
) -> Dictionary:
	var accent := COLOR_TEAL if status.contains("AKTIV") else _talent_branch_accent(category)
	return {
		"title": title,
		"body": effect,
		"meta": "%s · %d P · %s\nVoraussetzung: %s" % [
			category,
			cost,
			status,
			requirement_text,
		],
		"accent": accent,
		"icon_kind": _talent_icon_kind(category),
	}

func _position_progression_inspector(panel: Control, source: Control) -> void:
	if panel == null or source == null or not is_instance_valid(source) or panel.get_parent() == null:
		return
	var parent := panel.get_parent() as Control
	var inverse := parent.get_global_transform().affine_inverse()
	var source_rect := source.get_global_rect()
	var source_top_left := inverse * source_rect.position
	var source_bottom_right := inverse * source_rect.end
	var inspector_width := minf(540.0, maxf(260.0, parent.size.x - 32.0))
	var inspector_height := panel.custom_minimum_size.y
	panel.size = Vector2(inspector_width, inspector_height)
	var target := Vector2(source_top_left.x, source_bottom_right.y + 6.0)
	if target.y + inspector_height > parent.size.y - 12.0:
		target.y = source_top_left.y - inspector_height - 6.0
	target.x = clampf(target.x, 12.0, maxf(12.0, parent.size.x - inspector_width - 12.0))
	target.y = clampf(target.y, 12.0, maxf(12.0, parent.size.y - inspector_height - 12.0))
	panel.position = target
	panel.show()

func _hide_progression_inspector(panel: Control, source: Control) -> void:
	if panel == null or source == null or not is_instance_valid(source):
		return
	if source.has_focus() or Rect2(Vector2.ZERO, source.size).has_point(source.get_local_mouse_position()):
		return
	panel.hide()


func _research_category_text(category: StringName) -> String:
	match category:
		&"treatment": return "BEHANDLUNG"
		&"ability": return "AKTIV"
		_: return "PASSIV"


func _talent_icon_kind(category: String) -> StringName:
	match category.to_upper():
		"BEHANDLUNG": return &"treatment"
		"PLANUNG": return &"plan"
		"DIAGNOSE": return &"finding"
		_: return &"ability"


func _talent_category_text(category: Variant) -> String:
	var normalized := str(category).to_upper()
	if normalized in ["TREATMENT", "BEHANDLUNG"]:
		return "BEHANDLUNG"
	if normalized in ["0", "PLANNING", "PLANUNG"]:
		return "PLANUNG"
	if normalized in ["1", "DIAGNOSIS", "DIAGNOSE"]:
		return "DIAGNOSE"
	if normalized in ["2", "DEPLOYMENT", "EINSATZ"]:
		return "BEHANDLUNG"
	return "TALENT"

func _catalog_capacity(component_ids: Array, catalog_by_id: Dictionary) -> int:
	var total := 0
	for component in component_ids:
		var id := StringName(component) if component is String or component is StringName else StringName(_view_value(component, &"id", &""))
		var definition: Variant = catalog_by_id.get(id, component)
		total += int(_view_value(definition, &"capacity_cost", _view_value(definition, &"cost", 0)))
	return total

func _view_value(source: Variant, key: StringName, fallback: Variant = null) -> Variant:
	if source == null:
		return fallback
	if source is Dictionary:
		return (source as Dictionary).get(key, fallback)
	if source is Object:
		for property in (source as Object).get_property_list():
			if StringName(property.get("name", "")) == key:
				return (source as Object).get(key)
	return fallback

func _variant_array(source: Variant) -> Array:
	var result: Array = []
	if source == null:
		return result
	if source is Array:
		result.assign(source)
		return result
	for value in source:
		result.append(value)
	return result

func _on_upgrade_pressed(definition: UpgradeDefinition) -> void:
	upgrade_chosen.emit(definition)

func _page(title: String, back_text: String) -> Dictionary:
	var overlay := _overlay_base(AlveolusVisualTheme.PETROL_DEEP)
	overlay.set_meta(&"surface_role", AlveolusVisualTheme.SurfaceRole.PAGE_CANVAS)
	var bio_backdrop := BioLumenBackdrop.new()
	bio_backdrop.name = "BioLumenBackdrop"
	bio_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bio_backdrop)
	var header_back := AlveolusUIComponents.surface(AlveolusVisualTheme.SurfaceRole.PAGE_HEADER)
	header_back.name = "PageHeaderSurface"
	header_back.set_anchor(SIDE_RIGHT, 1.0)
	header_back.offset_bottom = AlveolusVisualTheme.HEADER_HEIGHT
	header_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(header_back)
	var outer := _margin(AlveolusVisualTheme.SCREEN_MARGIN, 0, AlveolusVisualTheme.SCREEN_MARGIN, 16)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(outer)
	# MarginContainer propagates a direct child's combined minimum size. Large
	# scroll content could therefore force the complete document VBox beyond the
	# viewport and make header/body overlap at 200 %. A neutral host owns the
	# fixed viewport; only the dedicated inner ScrollContainers may grow.
	var page_host := Control.new()
	page_host.name = "PageViewport"
	page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_host.clip_contents = true
	outer.add_child(page_host)
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", AlveolusVisualTheme.HEADER_CONTENT_GAP)
	page_host.add_child(page)
	var header := HBoxContainer.new()
	header.name = "PageHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.custom_minimum_size = Vector2(0.0, AlveolusVisualTheme.HEADER_HEIGHT)
	header.add_theme_constant_override("separation", 16)
	page.add_child(header)
	var medallion := AlveolusUIComponents.surface(AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET, COLOR_TEAL)
	medallion.custom_minimum_size = Vector2(44.0, 44.0)
	medallion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(medallion)
	var page_icon := SimpleIcon.new()
	page_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	page_icon.configure(_page_icon_kind(title), COLOR_TEAL)
	medallion.add_child(page_icon)
	var title_label := _label(title, 24, COLOR_TEXT)
	title_label.name = "PageTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(actions)
	var back := _nav_button(back_text, &"back", COLOR_MUTED)
	back.pressed.connect(func() -> void: back_requested.emit())
	actions.add_child(back)
	var body := VBoxContainer.new()
	body.name = "PageBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)
	page_shells.append({
		"overlay": overlay,
		"outer": outer,
		"viewport": page_host,
		"page": page,
		"header": header,
		"body": body,
		"actions": actions,
		"header_back": header_back,
		"medallion": medallion,
		"title": title_label,
	})
	return {"overlay": overlay, "body": body, "actions": actions, "back": back, "header": header}

func _nav_button(text: String, kind: StringName, accent: Color) -> Button:
	var button := AlveolusUIComponents.action_button(
		text,
		AlveolusUIComponents.ACTION_NAVIGATION,
		kind,
		accent
	)
	button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, 146.0)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, AlveolusVisualTheme.TOUCH_TARGET_MINIMUM)
	button.set_meta(&"preferred_inline_width", button.custom_minimum_size.x)
	UISoundService.set_sound_role(button, UISoundService.BACK if kind in [&"back", &"return"] else UISoundService.OPEN)
	return button

func _page_icon_kind(title: String) -> StringName:
	match title.to_upper():
		"PRAXIS":
			return &"practice"
		"FORSCHUNG":
			return &"research"
		"FALLARCHIV":
			return &"archive"
		"LEXIKON":
			return &"lexicon"
		"EINSATZPLANUNG":
			return &"plan"
		"EINSTELLUNGEN":
			return &"settings"
		_:
			return &"information"

func _section_header(text: String, kind: StringName, accent: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := SimpleIcon.new()
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.configure(kind, accent)
	row.add_child(icon)
	var title := _label(text, AlveolusVisualTheme.TEXT_CAPTION, accent.lightened(0.18))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	return row

func _level_placeholder(accent: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", AlveolusVisualTheme.panel_style(Color(accent, 0.09), Color(accent, 0.34), 1, 14, false))
	var question := _label("?", 27, Color(accent, 0.78))
	question.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(question)
	return panel

func _upgrade_icon_kind(definition: UpgradeDefinition) -> StringName:
	if definition.id == &"mobility" or definition.preview_context_tags.has("movement"):
		return &"movement_training"
	match definition.path:
		UpgradeDefinition.Path.IMMUNE:
			return &"immune"
		UpgradeDefinition.Path.SUPPORT:
			return &"support"
		_:
			return &"antibiotic"

func _overlay_base(color: Color) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	return overlay

func _centered_overlay(panel_size: Vector2, accent: Color, padding: int = 24, scrollable: bool = false) -> Dictionary:
	var overlay := _overlay_base(Color(AlveolusVisualTheme.PETROL, 0.72))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	var body: Control = content
	if scrollable:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(content)
		body = scroll
	var sheet_parts := AlveolusUIComponents.modal_sheet("", body, [], padding, accent)
	var panel := sheet_parts["panel"] as PanelContainer
	panel.custom_minimum_size = panel_size
	panel.clip_contents = true
	center.add_child(panel)
	return {"overlay": overlay, "panel": panel, "content": content}

func _card(accent: Color) -> Dictionary:
	var panel := AlveolusUIComponents.surface(AlveolusVisualTheme.SurfaceRole.ACTION_CARD, accent)
	panel.clip_contents = false
	var margin := _margin(15, 12, 15, 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	return {"panel": panel, "content": content}

func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin

func _label(text: String, font_size: int, color: Color) -> Label:
	var variation: StringName = AlveolusVisualTheme.TYPE_TITLE_LABEL if font_size >= 24 else (AlveolusVisualTheme.TYPE_SECTION_LABEL if font_size >= 18 else AlveolusVisualTheme.TYPE_BODY_LABEL)
	var label := AlveolusUIComponents.label(text, variation)
	label.add_theme_font_override("font", AlveolusVisualTheme.heading_font() if font_size >= 18 else AlveolusVisualTheme.body_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _primary_button(text: String, accent: Color) -> Button:
	return AlveolusUIComponents.action_button(text, AlveolusUIComponents.ACTION_PRIMARY)

func _apply_primary_button_style(button: Button, accent: Color) -> void:
	# Primary is a semantic role, not a caller-selected color. The only warm-gold
	# endpoint in the product remains the dedicated planning start action.
	AlveolusUIComponents.apply_action_role(button, AlveolusUIComponents.ACTION_PRIMARY, COLOR_TEAL)
	_decorate_button_motion(button)

func _secondary_button(text: String, accent: Color) -> Button:
	var role := AlveolusUIComponents.ACTION_DANGER if accent == COLOR_RED else AlveolusUIComponents.ACTION_SECONDARY
	return AlveolusUIComponents.action_button(text, role, &"", accent)

func _icon_action_button(text: String, icon_id: StringName, accent: Color, primary: bool = false) -> Button:
	var role := AlveolusUIComponents.ACTION_PRIMARY if primary else (AlveolusUIComponents.ACTION_DANGER if accent == COLOR_RED else AlveolusUIComponents.ACTION_SECONDARY)
	return AlveolusUIComponents.action_button(text, role, icon_id, accent)

func _apply_secondary_button_style(button: Button, accent: Color) -> void:
	var role := AlveolusUIComponents.ACTION_DANGER if accent == COLOR_RED else AlveolusUIComponents.ACTION_SECONDARY
	AlveolusUIComponents.apply_action_role(button, role, accent)
	_decorate_button_motion(button)

func _panel_style(background: Color, border: Color, border_width: int = 1, radius: int = 10) -> StyleBoxFlat:
	return AlveolusVisualTheme.panel_style(background, border, border_width, radius, true)

func _section_surface_style(accent: Color) -> StyleBoxFlat:
	return AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.SECTION_GROUP,
		accent,
		AlveolusVisualTheme.CornerTreatment.NONE
	)

func _document_inset_style(accent: Color) -> StyleBoxFlat:
	return AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET,
		accent,
		AlveolusVisualTheme.CornerTreatment.CONTROL_4
	)

func _apply_compact_selection_card_style(button: Button, accent: Color, selected: bool = false) -> void:
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var visual_state: StringName = &"selected" if selected and state == &"normal" else state
		var style := AlveolusVisualTheme.case_card_style(accent, visual_state)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		button.add_theme_stylebox_override(state, style)

func _hud_panel_style(accent: Color, opacity: float = 0.84, radius: int = 4) -> StyleBoxFlat:
	var style := AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.HUD_ABILITY,
		accent,
		AlveolusVisualTheme.CornerTreatment.CONTROL_4 if radius <= 4 else AlveolusVisualTheme.CornerTreatment.CARD_6
	)
	style.bg_color = Color(AlveolusVisualTheme.PETROL_DEEP, opacity)
	style.border_color = Color(accent, 0.58)
	style.shadow_size = 0
	return style

func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return AlveolusVisualTheme.bar_style(color, radius, luminance < 0.38)

func _decorate_button_motion(button: Button) -> void:
	# Hover, focus and press are represented entirely by semantic surfaces. Even a
	# short fractional transform softens browser text and can paint outside the
	# container allocation, so controls remain pixel-stable in every state.
	_stop_button_motion(button)
	button.scale = Vector2.ONE
	button.set_meta(&"disable_motion_scale", true)

func _animate_button(button: Button, target_scale: Vector2, duration: float = 0.10) -> void:
	if not is_instance_valid(button):
		return
	_stop_button_motion(button)
	if reduced_motion_enabled:
		button.scale = Vector2.ONE
		return
	var tween := button.create_tween()
	button.set_meta(&"alveolus_motion_tween", tween)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, duration)

func _stop_button_motion(button: BaseButton) -> void:
	if not is_instance_valid(button) or not button.has_meta(&"alveolus_motion_tween"):
		return
	var active_tween: Variant = button.get_meta(&"alveolus_motion_tween")
	if active_tween is Tween and (active_tween as Tween).is_valid():
		(active_tween as Tween).kill()
	button.remove_meta(&"alveolus_motion_tween")

func _clock_text(value: float) -> String:
	var seconds := maxi(0, ceili(value))
	return "%02d:%02d" % [seconds / 60, seconds % 60]

func _format_duration(total_seconds: int, exact: bool) -> String:
	var seconds := maxi(0, total_seconds)
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	var remainder := seconds % 60
	if exact:
		return "%02d:%02d:%02d" % [hours, minutes, remainder] if hours > 0 else "%02d:%02d" % [minutes, remainder]
	if hours > 0:
		return "%d Std. %02d Min." % [hours, minutes]
	return "%d:%02d Min." % [minutes, remainder]

func _level_card_title(level: LevelDefinition) -> String:
	return level.title

func _level_accent(level: LevelDefinition) -> Color:
	if level.is_tutorial:
		return COLOR_GOLD
	match level.order:
		1: return COLOR_BLUE
		2: return COLOR_RED
		3: return COLOR_TEAL
		_: return COLOR_BLUE.lerp(COLOR_TEAL, 0.46)

func _local_time(unix_time: int) -> String:
	var zone := Time.get_time_zone_from_system()
	var local_timestamp := unix_time + int(zone.get("bias", 0)) * 60
	var date := Time.get_datetime_dict_from_unix_time(local_timestamp)
	return "%02d:%02d Uhr" % [int(date.hour), int(date.minute)]
