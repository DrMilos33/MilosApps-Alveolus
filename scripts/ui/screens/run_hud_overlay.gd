class_name RunHUDOverlay
extends Control

## Bio-Lumen chrome for an active run.
##
## This module never advances clocks, cooldowns or animations. It only applies
## immutable presenter snapshots and emits player intents.

signal ability_requested(slot: int)
signal pause_requested

const WIDE_THRESHOLD := 900.0
const WIDE_MARGIN := 16.0
const COMPACT_MARGIN := 8.0
const STAT_COLUMN_COUNT := 4
const STAT_ROW_WIDTH := 72.0
const STAT_ROW_HEIGHT := 20.0
const STAT_GAP := 4
const STAT_VALUE_MINIMUM_WIDTH := 42.0
const DEFEAT_REWARD_WIDTH := 62.0
const ABILITY_WIDTH := 146.0
const ABILITY_HEIGHT := 38.0
const ABILITY_GAP := 6.0

var _view_model: RunHUDViewModel
var _applied_revision := -1
var _applied_content_hash := ""

var _stability_panel: Panel
var _stability_bar: ProgressBar
var _stability_value: Label
var _shield_panel: Panel
var _shield_icon: SimpleIcon
var _shield_bar: ProgressBar
var _shield_value: Label
var _timer_panel: Panel
var _timer_value: Label
var _defeat_reward_panel: Panel
var _defeat_reward_icon: SimpleIcon
var _defeat_reward_value: Label
var _boss_panel: Panel
var _boss_icon: SimpleIcon
var _boss_title: Label
var _boss_value: Label
var _boss_phase: Label
var _boss_bar: ProgressBar
var _analysis_panel: Panel
var _analysis_bar: ProgressBar
var _analysis_value: Label
var _stats_strip: HFlowContainer
var _stat_rows: Array[HBoxContainer] = []
var _stat_icons: Array[SimpleIcon] = []
var _stat_values: Array[Label] = []
var _ability_panel: GridContainer
var _ability_cards: Array[Panel] = []
var _ability_buttons: Array[Button] = []
var _ability_icons: Array[SimpleIcon] = []
var _ability_titles: Array[Label] = []
var _ability_glyphs: Array[Label] = []
var _ability_statuses: Array[Label] = []
var _ability_bars: Array[ProgressBar] = []
var _pause_button: Button


func _init() -> void:
	name = "RunHUDOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	_build()
	resized.connect(_queue_responsive_layout)


func apply_view_model(view_model: RunHUDViewModel) -> bool:
	if view_model == null or not view_model.is_valid():
		return false
	if _applied_revision >= 0 and view_model.revision() < _applied_revision:
		return false
	var first_apply := _applied_revision < 0
	var content_changed := view_model.content_hash() != _applied_content_hash
	var revision_changed := view_model.revision() != _applied_revision
	if not content_changed and not revision_changed:
		return false

	_view_model = view_model
	_applied_revision = view_model.revision()
	_applied_content_hash = view_model.content_hash()
	if not content_changed:
		return false

	_apply_vitals()
	_sync_stats()
	_apply_abilities()
	if first_apply:
		_queue_responsive_layout()
	return true


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> String:
	return _applied_content_hash


func stability_panel() -> Panel:
	return _stability_panel


func stability_bar() -> ProgressBar:
	return _stability_bar


func stability_value_label() -> Label:
	return _stability_value


func shield_panel() -> Panel:
	return _shield_panel


func shield_bar() -> ProgressBar:
	return _shield_bar


func shield_value_label() -> Label:
	return _shield_value


func timer_panel() -> Panel:
	return _timer_panel


func timer_value_label() -> Label:
	return _timer_value


func defeat_research_reward_panel() -> Panel:
	return _defeat_reward_panel


func defeat_research_reward_icon() -> SimpleIcon:
	return _defeat_reward_icon


func defeat_research_reward_value_label() -> Label:
	return _defeat_reward_value


func boss_panel() -> Panel:
	return _boss_panel


func boss_bar() -> ProgressBar:
	return _boss_bar


func boss_title_label() -> Label:
	return _boss_title


func boss_value_label() -> Label:
	return _boss_value


func boss_phase_label() -> Label:
	return _boss_phase


func analysis_panel() -> Panel:
	return _analysis_panel


func analysis_bar() -> ProgressBar:
	return _analysis_bar


func analysis_value_label() -> Label:
	return _analysis_value


func run_stats_strip() -> HFlowContainer:
	return _stats_strip


func stat_rows() -> Array[HBoxContainer]:
	var result: Array[HBoxContainer] = []
	result.assign(_stat_rows)
	return result


func ability_panel() -> GridContainer:
	return _ability_panel


func ability_cards() -> Array[Panel]:
	var result: Array[Panel] = []
	result.assign(_ability_cards)
	return result


func ability_buttons() -> Array[Button]:
	var result: Array[Button] = []
	result.assign(_ability_buttons)
	return result


func ability_icons() -> Array[SimpleIcon]:
	var result: Array[SimpleIcon] = []
	result.assign(_ability_icons)
	return result


func ability_title_labels() -> Array[Label]:
	var result: Array[Label] = []
	result.assign(_ability_titles)
	return result


func ability_key_labels() -> Array[Label]:
	var result: Array[Label] = []
	result.assign(_ability_glyphs)
	return result


func ability_cooldown_labels() -> Array[Label]:
	var result: Array[Label] = []
	result.assign(_ability_statuses)
	return result


func ability_cooldown_bars() -> Array[ProgressBar]:
	var result: Array[ProgressBar] = []
	result.assign(_ability_bars)
	return result


## Registration records are stable for the lifetime of the HUD. The provider
## reads the latest immutable snapshot, so cooldown refreshes never reconnect
## hover callbacks or make an already-open tooltip disappear.
func context_detail_registrations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(_ability_buttons.size()):
		result.append({
			"source": _ability_buttons[slot],
			"provider": _ability_info_payload.bind(slot),
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


func pause_action() -> Button:
	return _pause_button


func grab_ability_focus(slot: int = 0) -> bool:
	if slot < 0 or slot >= _ability_buttons.size():
		return false
	var target := _ability_buttons[slot]
	if target.disabled or not target.is_visible_in_tree():
		return false
	target.grab_focus()
	return true


func _build() -> void:
	_build_stability()
	_build_shield()
	_build_defeat_reward()
	_build_timer()
	_build_boss()
	_build_analysis()
	_build_stats()
	_build_abilities()
	_build_pause()
	_configure_focus_paths()


func _build_stability() -> void:
	_stability_panel = _surface_panel("Stability", AlveolusVisualTheme.SurfaceRole.HUD_VITAL, AlveolusVisualTheme.TEAL)
	_make_hud_surface_transparent(_stability_panel, &"transparent_hud_vital")
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 1)
	_stability_panel.add_child(_full_inset(stack, 1))
	_stability_value = _hud_value("100 / 100", 0.0)
	_stability_value.name = "StabilityValue"
	_stability_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stability_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_stability_value)
	_stability_bar = AlveolusUIComponents.progress(0.0, 100.0, false)
	_stability_bar.name = "StabilityBar"
	_stability_bar.custom_minimum_size.y = 7.0
	_stability_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stability_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_child(_stability_bar)
	_stability_panel.set_meta(&"alveolus_accessible_name", "Leben")


func _build_shield() -> void:
	_shield_panel = _surface_panel("Shield", AlveolusVisualTheme.SurfaceRole.HUD_VITAL, AlveolusVisualTheme.COBALT)
	_make_hud_surface_transparent(_shield_panel, &"transparent_hud_shield")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_shield_panel.add_child(_full_inset(row, 2))
	_shield_icon = _hud_icon("ShieldIcon", &"ability_protection_field", AlveolusVisualTheme.COBALT, 16.0)
	row.add_child(_shield_icon)
	_shield_bar = AlveolusUIComponents.progress(0.0, 1.0, false)
	_shield_bar.name = "ShieldBar"
	_shield_bar.custom_minimum_size.y = 6.0
	_shield_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_shield_bar)
	_shield_value = _hud_value("0", 28.0)
	_shield_value.name = "ShieldValue"
	row.add_child(_shield_value)
	_shield_panel.set_meta(&"alveolus_accessible_name", "Schild")


func _build_timer() -> void:
	_timer_panel = _surface_panel("Timer", AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE, AlveolusVisualTheme.MUTED)
	_make_hud_surface_transparent(_timer_panel, &"transparent_hud_timer")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_timer_panel.add_child(_full_inset(row, 0))
	_timer_value = AlveolusUIComponents.label("00:00", AlveolusVisualTheme.TYPE_HUD_VALUE_LABEL)
	_timer_value.name = "TimerValue"
	_timer_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_timer_value)
	_timer_panel.set_meta(&"alveolus_accessible_name", "Rundendauer")


func _build_defeat_reward() -> void:
	_defeat_reward_panel = _surface_panel(
		"DefeatResearchReward",
		AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE,
		AlveolusVisualTheme.GOLD
	)
	_make_hud_surface_transparent(_defeat_reward_panel, &"transparent_defeat_research_reward")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 2)
	_defeat_reward_panel.add_child(_full_inset(row, 0))
	_defeat_reward_icon = _hud_icon("DefeatRewardIcon", &"research", AlveolusVisualTheme.GOLD, 15.0)
	row.add_child(_defeat_reward_icon)
	_defeat_reward_value = AlveolusUIComponents.label("0", AlveolusVisualTheme.TYPE_HUD_LABEL)
	_defeat_reward_value.name = "DefeatRewardValue"
	_defeat_reward_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_defeat_reward_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_defeat_reward_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_defeat_reward_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_defeat_reward_value.modulate = AlveolusVisualTheme.GOLD
	row.add_child(_defeat_reward_value)
	_defeat_reward_panel.set_meta(&"alveolus_accessible_name", "Forschung bei Niederlage")
	_defeat_reward_panel.hide()


func _build_boss() -> void:
	_boss_panel = _surface_panel("Boss", AlveolusVisualTheme.SurfaceRole.HUD_ALERT, AlveolusVisualTheme.CORAL)
	_make_hud_surface_transparent(_boss_panel, &"dormant_boss_compatibility")
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	_boss_panel.add_child(_full_inset(stack, 6))
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 5)
	stack.add_child(heading)
	_boss_icon = _hud_icon("BossIcon", &"boss", AlveolusVisualTheme.CORAL, 18.0)
	heading.add_child(_boss_icon)
	_boss_title = AlveolusUIComponents.label("Infektionsherd", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	_boss_title.name = "BossTitle"
	_boss_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(_boss_title)
	_boss_value = AlveolusUIComponents.label("100 %", AlveolusVisualTheme.TYPE_HUD_LABEL)
	_boss_value.name = "BossValue"
	_boss_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(_boss_value)
	_boss_phase = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	_boss_phase.name = "BossPhase"
	_boss_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_phase.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(_boss_phase)
	_boss_bar = AlveolusUIComponents.progress(100.0, 100.0, false)
	_boss_bar.name = "BossBar"
	_boss_bar.custom_minimum_size.y = 8.0
	stack.add_child(_boss_bar)
	_boss_panel.hide()


func _build_analysis() -> void:
	_analysis_panel = _surface_panel("Analysis", AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE, AlveolusVisualTheme.MUTED)
	_make_hud_surface_transparent(_analysis_panel, &"transparent_hud_analysis")
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 1)
	_analysis_panel.add_child(_full_inset(stack, 1))
	_analysis_value = AlveolusUIComponents.label("Lv 0 · 0/0", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	_analysis_value.name = "AnalysisValue"
	_analysis_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_analysis_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_analysis_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(_analysis_value)
	_analysis_bar = AlveolusUIComponents.progress(0.0, 1.0, false)
	_analysis_bar.name = "AnalysisBar"
	_analysis_bar.custom_minimum_size.y = 5.0
	_analysis_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_analysis_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_child(_analysis_bar)
	_analysis_panel.set_meta(&"alveolus_accessible_name", "Level und Erfahrung")


func _build_stats() -> void:
	_stats_strip = HFlowContainer.new()
	_stats_strip.name = "RunStatsStrip"
	_stats_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_strip.focus_mode = Control.FOCUS_NONE
	_stats_strip.alignment = FlowContainer.ALIGNMENT_END
	_stats_strip.add_theme_constant_override("h_separation", STAT_GAP)
	_stats_strip.add_theme_constant_override("v_separation", 4)
	_stats_strip.set_meta(&"alveolus_component", &"transparent_run_stats")
	_stats_strip.resized.connect(_on_stats_strip_resized)
	add_child(_stats_strip)


func _build_abilities() -> void:
	_ability_panel = GridContainer.new()
	_ability_panel.name = "AbilitySlots"
	_ability_panel.columns = 2
	_ability_panel.add_theme_constant_override("h_separation", int(ABILITY_GAP))
	_ability_panel.add_theme_constant_override("v_separation", int(ABILITY_GAP))
	add_child(_ability_panel)
	for slot in range(2):
		var card := _surface_panel(
			"AbilityCard%d" % (slot + 1),
			AlveolusVisualTheme.SurfaceRole.HUD_ABILITY,
			AlveolusVisualTheme.TURQUOISE,
			false
		)
		card.custom_minimum_size = Vector2(ABILITY_WIDTH, ABILITY_HEIGHT)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ability_panel.add_child(card)
		_ability_cards.append(card)
		_make_hud_surface_transparent(card, &"transparent_hud_ability")
		var cooldown := AlveolusUIComponents.progress(0.0, 1.0, false)
		cooldown.name = "AbilityCooldown%d" % (slot + 1)
		cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cooldown.custom_minimum_size = Vector2(ABILITY_WIDTH, ABILITY_HEIGHT)
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown.set_meta(&"alveolus_component", &"ability_cooldown_track")
		card.add_child(cooldown)
		_ability_bars.append(cooldown)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_meta(&"alveolus_component", &"ability_track_readout")
		card.add_child(_full_inset(row, 6))
		var icon := _hud_icon("AbilityIcon%d" % (slot + 1), &"ability", AlveolusVisualTheme.TURQUOISE, 22.0)
		row.add_child(icon)
		_ability_icons.append(icon)
		var title := AlveolusUIComponents.label("Nicht belegt", AlveolusVisualTheme.TYPE_HUD_LABEL)
		title.name = "AbilityTitle%d" % (slot + 1)
		title.hide()
		row.add_child(title)
		_ability_titles.append(title)
		var glyph := AlveolusUIComponents.label("Q" if slot == 0 else "E", AlveolusVisualTheme.TYPE_HUD_LABEL)
		glyph.name = "AbilityGlyph%d" % (slot + 1)
		glyph.custom_minimum_size.x = 24.0
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(glyph)
		_ability_glyphs.append(glyph)
		var status := AlveolusUIComponents.label("Nicht belegt", AlveolusVisualTheme.TYPE_HUD_LABEL)
		status.name = "AbilityStatus%d" % (slot + 1)
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(status)
		_ability_statuses.append(status)
		var hit := AlveolusUIComponents.action_button(
			"",
			AlveolusUIComponents.ACTION_QUIET,
			&"",
			AlveolusVisualTheme.TURQUOISE
		)
		hit.name = "AbilitySlot%d" % (slot + 1)
		hit.custom_minimum_size = Vector2.ZERO
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.flat = true
		hit.focus_mode = Control.FOCUS_ALL
		hit.scale = Vector2.ONE
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.set_meta(&"disable_motion_scale", true)
		hit.set_meta(&"ability_slot", slot)
		# Ability feedback is owned by the gameplay intent: successful abilities
		# have their world feedback, while cooldown blocks emit exactly one quiet
		# cue. The generic button press sound would otherwise double that response.
		UISoundService.set_sound_role(hit, UISoundService.NONE)
		hit.pressed.connect(_on_ability_pressed.bind(slot))
		card.add_child(hit)
		_ability_buttons.append(hit)


func _build_pause() -> void:
	_pause_button = AlveolusUIComponents.action_button(
		"",
		AlveolusUIComponents.ACTION_QUIET,
		&"pause",
		AlveolusVisualTheme.MUTED
	)
	_pause_button.name = "Pause"
	_pause_button.tooltip_text = "Pause"
	_pause_button.flat = true
	_pause_button.focus_mode = Control.FOCUS_ALL
	_pause_button.scale = Vector2.ONE
	_pause_button.set_meta(&"disable_motion_scale", true)
	_pause_button.set_meta(&"alveolus_accessible_name", "Pause")
	_pause_button.custom_minimum_size = Vector2(44.0, 44.0)
	if _pause_button is IconTextButton:
		var compact_button := _pause_button as IconTextButton
		compact_button.content_inset.add_theme_constant_override("margin_left", 10)
		compact_button.content_inset.add_theme_constant_override("margin_right", 10)
		compact_button.icon_view.custom_minimum_size = Vector2(17.0, 17.0)
		compact_button.set_meta(&"alveolus_component", &"transparent_pause_action")
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	add_child(_pause_button)


func _apply_vitals() -> void:
	_set_progress(_stability_bar, _view_model.stability_current(), _view_model.stability_maximum())
	var stability_fraction := _view_model.stability_current() / maxf(1.0, _view_model.stability_maximum())
	var stability_accent := AlveolusVisualTheme.TEAL
	if stability_fraction < 0.30:
		stability_accent = AlveolusVisualTheme.CORAL
	elif stability_fraction < 0.58:
		stability_accent = AlveolusVisualTheme.GOLD
	AlveolusUIComponents.apply_progress_accent(_stability_bar, stability_accent)
	_set_label_text(_stability_value, _view_model.stability_text())
	_set_progress(_shield_bar, _view_model.shield_current(), maxf(1.0, _view_model.shield_maximum()))
	AlveolusUIComponents.apply_progress_accent(_shield_bar, AlveolusVisualTheme.COBALT)
	_set_label_text(_shield_value, _view_model.shield_text())
	_shield_panel.visible = _view_model.shield_current() > 0.001 and _view_model.shield_maximum() > 0.001
	_set_label_text(_timer_value, _view_model.timer_text())
	var timer_color := AlveolusVisualTheme.SKY_DEEP
	match _view_model.timer_tone():
		&"attention":
			timer_color = AlveolusVisualTheme.GOLD
		&"danger":
			timer_color = AlveolusVisualTheme.CORAL
	if _timer_value.modulate != timer_color:
		_timer_value.modulate = timer_color
	var reward_visible := _view_model.defeat_research_reward_visible()
	_defeat_reward_panel.visible = reward_visible
	if reward_visible:
		var reward_kind := _view_model.defeat_research_reward_icon_id()
		if _defeat_reward_icon.kind != reward_kind or _defeat_reward_icon.accent != AlveolusVisualTheme.GOLD:
			_defeat_reward_icon.configure(reward_kind, AlveolusVisualTheme.GOLD)
		_set_label_text(_defeat_reward_value, _view_model.defeat_research_reward_formatted_value())
		var reward_accessible_name := _view_model.defeat_research_reward_accessible_name()
		if _defeat_reward_panel.get_meta(&"alveolus_accessible_name", "") != reward_accessible_name:
			_defeat_reward_panel.set_meta(&"alveolus_accessible_name", reward_accessible_name)
	# Boss health remains part of the immutable compatibility snapshot, but its
	# former card is deliberately dormant. The world presentation owns boss
	# health; this overlay keeps the top-right lane for elapsed run time only.
	_boss_panel.hide()
	_set_label_text(_boss_title, _view_model.boss_title())
	if _boss_title.tooltip_text != _view_model.boss_title():
		_boss_title.tooltip_text = _view_model.boss_title()
	_set_label_text(_boss_value, _view_model.boss_percentage_text())
	_set_label_text(_boss_phase, _view_model.boss_phase_text())
	_set_progress(_boss_bar, _view_model.boss_current(), _view_model.boss_maximum())
	AlveolusUIComponents.apply_progress_accent(_boss_bar, AlveolusVisualTheme.CORAL)
	_set_progress(_analysis_bar, float(_view_model.analysis_current()), maxf(1.0, float(_view_model.analysis_target())))
	AlveolusUIComponents.apply_progress_accent(_analysis_bar, AlveolusVisualTheme.SKY_DEEP)
	_set_label_text(_analysis_value, _view_model.analysis_text())


func _sync_stats() -> void:
	var structure_changed := _stat_rows.size() != _view_model.stat_count()
	if not structure_changed:
		for index in range(_stat_rows.size()):
			if _stat_rows[index].get_meta(&"stat_id", &"") != _view_model.stat_at(index).id():
				structure_changed = true
				break
	if structure_changed:
		for child in _stats_strip.get_children():
			_stats_strip.remove_child(child)
			child.queue_free()
		_stat_rows.clear()
		_stat_icons.clear()
		_stat_values.clear()
		for stat in _view_model.stats():
			_build_stat_row(stat)
	for index in range(_view_model.stat_count()):
		var stat := _view_model.stat_at(index)
		var accent := _stat_accent(stat)
		if _stat_icons[index].kind != stat.icon_id() or _stat_icons[index].accent != accent:
			_stat_icons[index].configure(stat.icon_id(), accent)
		_set_label_text(_stat_values[index], stat.formatted_value())
		if _stat_values[index].modulate != accent:
			_stat_values[index].modulate = accent
		var accessible_text := "%s: %s" % [stat.accessible_name(), stat.formatted_value()]
		if _stat_rows[index].get_meta(&"alveolus_accessible_name", "") != accessible_text:
			_stat_rows[index].set_meta(&"alveolus_accessible_name", accessible_text)
	if _stats_strip.size.x > 0.0:
		_fit_stat_columns(_stats_strip.size.x)
	_stats_strip.visible = not _stat_rows.is_empty()


func _build_stat_row(stat: RunHUDViewModel.StatValueViewModel) -> void:
	var row := HBoxContainer.new()
	row.name = "RunStat_%s" % String(stat.id())
	row.custom_minimum_size = Vector2(STAT_ROW_WIDTH, STAT_ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	row.set_meta(&"stat_id", stat.id())
	_stats_strip.add_child(row)
	_stat_rows.append(row)
	var accent := _stat_accent(stat)
	var icon := _hud_icon("StatIcon", stat.icon_id(), accent, 15.0)
	row.add_child(icon)
	_stat_icons.append(icon)
	var value := AlveolusUIComponents.label(stat.formatted_value(), AlveolusVisualTheme.TYPE_HUD_LABEL)
	value.name = "StatValue"
	value.custom_minimum_size = Vector2(STAT_VALUE_MINIMUM_WIDTH, STAT_ROW_HEIGHT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.add_theme_font_override("font", AlveolusVisualTheme.heading_font())
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_outline_color", Color(AlveolusVisualTheme.PETROL_DEEP, 0.92))
	value.add_theme_constant_override("outline_size", 2)
	row.add_child(value)
	value.modulate = accent
	_stat_values.append(value)


func _apply_abilities() -> void:
	var focus_paths_changed := false
	var occupied_count := 0
	for slot in range(2):
		var ability := _view_model.ability_at(slot)
		var should_show := ability.occupied()
		if _ability_cards[slot].visible != should_show:
			_ability_cards[slot].visible = should_show
			focus_paths_changed = true
		if should_show:
			occupied_count += 1
		var accent := AlveolusVisualTheme.SKY_DEEP
		if ability.targeting():
			accent = AlveolusVisualTheme.TURQUOISE.lightened(0.18)
		elif ability.ready():
			accent = AlveolusVisualTheme.TEAL.lightened(0.28)
		elif ability.occupied():
			accent = AlveolusVisualTheme.SKY_DEEP
		if _ability_cards[slot].get_meta(&"accent", Color.TRANSPARENT) != accent:
			_ability_cards[slot].set_meta(&"accent", accent)
		if _ability_icons[slot].kind != ability.icon_id() or _ability_icons[slot].accent != accent:
			_ability_icons[slot].configure(ability.icon_id(), accent)
		_set_label_text(_ability_titles[slot], ability.title())
		var title_color := AlveolusVisualTheme.IVORY if ability.occupied() else AlveolusVisualTheme.MUTED
		if _ability_titles[slot].modulate != title_color:
			_ability_titles[slot].modulate = title_color
		_set_label_text(_ability_glyphs[slot], ability.key_glyph_text())
		if _ability_glyphs[slot].modulate != AlveolusVisualTheme.IVORY:
			_ability_glyphs[slot].modulate = AlveolusVisualTheme.IVORY
		_set_label_text(_ability_statuses[slot], ability.status_text())
		var status_color := AlveolusVisualTheme.TURQUOISE.lightened(0.30) if ability.targeting() else (
			AlveolusVisualTheme.IVORY if ability.ready() else AlveolusVisualTheme.GOLD.lightened(0.18)
		)
		if _ability_statuses[slot].modulate != status_color:
			_ability_statuses[slot].modulate = status_color
		_set_progress(_ability_bars[slot], ability.cooldown_progress(), 1.0)
		AlveolusUIComponents.apply_hud_cooldown_track(_ability_bars[slot], accent)
		if not _ability_cards[slot].has_meta(&"targeting") or _ability_cards[slot].get_meta(&"targeting") != ability.targeting():
			_ability_cards[slot].set_meta(&"targeting", ability.targeting())
		if not _ability_cards[slot].has_meta(&"ready") or _ability_cards[slot].get_meta(&"ready") != ability.ready():
			_ability_cards[slot].set_meta(&"ready", ability.ready())
		var should_disable := not ability.occupied()
		if _ability_buttons[slot].disabled != should_disable:
			AlveolusUIComponents.set_button_disabled(_ability_buttons[slot], should_disable)
			focus_paths_changed = true
		# Native tooltips would race the shared ContextDetailController. The
		# registered provider below is the single hover information source.
		if not _ability_buttons[slot].tooltip_text.is_empty():
			_ability_buttons[slot].tooltip_text = ""
		var accessible_text := "%s · %s · %s" % [ability.key_glyph_text(), ability.title(), ability.status_text()]
		if _ability_buttons[slot].get_meta(&"alveolus_accessible_name", "") != accessible_text:
			_ability_buttons[slot].set_meta(&"alveolus_accessible_name", accessible_text)
	_ability_panel.visible = occupied_count > 0
	_ability_panel.columns = maxi(1, occupied_count)
	if focus_paths_changed:
		_configure_focus_paths()
		_queue_responsive_layout()


func _on_ability_pressed(slot: int) -> void:
	if _view_model == null:
		return
	var ability := _view_model.ability_at(slot)
	if ability == null or not ability.occupied():
		return
	ability_requested.emit(slot)


func _info_provider_for(source: Control) -> Callable:
	if source == null:
		return Callable()
	for slot in range(_ability_buttons.size()):
		if _ability_buttons[slot] == source:
			return _ability_info_payload.bind(slot)
	return Callable()


func _ability_info_payload(slot: int) -> Dictionary:
	if _view_model == null:
		return {}
	var ability := _view_model.ability_at(slot)
	if ability == null or not ability.occupied():
		return {}
	var facts := ability.facts_text()
	var effect := ability.effect_text()
	return {
		"title": ability.title(),
		"body": effect if not effect.is_empty() else facts,
		"meta": facts if not facts.is_empty() and facts != effect else "",
		"icon_rows": ability.icon_fact_rows(),
		"icon_kind": &"",
		"accent": AlveolusVisualTheme.TURQUOISE if ability.ready() else AlveolusVisualTheme.COBALT,
		"maximum_width": 244.0,
		"surface_opacity": 0.86,
	}


func _configure_focus_paths() -> void:
	if _ability_buttons.size() != 2 or _pause_button == null:
		return
	var cycle: Array[Control] = []
	for button in _ability_buttons:
		if not button.disabled:
			cycle.append(button)
	cycle.append(_pause_button)
	for index in range(cycle.size()):
		var control := cycle[index]
		var previous := cycle[posmod(index - 1, cycle.size())]
		var following := cycle[(index + 1) % cycle.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(following)
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_right = control.get_path_to(following)
		control.focus_neighbor_top = control.get_path_to(_pause_button)
		control.focus_neighbor_bottom = control.get_path_to(cycle[0])


func _queue_responsive_layout() -> void:
	_update_responsive_layout.call_deferred()


func _update_responsive_layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if size.x >= WIDE_THRESHOLD:
		_apply_wide_layout()
	else:
		_apply_compact_layout()


func _apply_wide_layout() -> void:
	var width := size.x
	var height := size.y
	var margin := WIDE_MARGIN
	var vital_width := 360.0
	var timer_width := 82.0
	var pause_width := 44.0
	var pause_left := width - margin - pause_width
	var timer_left := pause_left - 6.0 - timer_width
	var reward_left := timer_left - 4.0 - DEFEAT_REWARD_WIDTH
	var stability_left := floorf((width - vital_width) * 0.5)
	_place(_stability_panel, Rect2(stability_left, 10.0, vital_width, 30.0))
	_place(_shield_panel, Rect2(margin, 14.0, 230.0, 24.0))
	_place(_defeat_reward_panel, Rect2(reward_left, 12.0, DEFEAT_REWARD_WIDTH, 24.0))
	_place(_timer_panel, Rect2(timer_left, 12.0, timer_width, 24.0))
	_place(_pause_button, Rect2(pause_left, 2.0, pause_width, 44.0))
	var stats_width := 336.0
	_place(_stats_strip, Rect2(width - margin - stats_width, 50.0, stats_width, 44.0))
	_fit_stat_columns(stats_width)
	_stats_strip.alignment = FlowContainer.ALIGNMENT_END
	_place(_analysis_panel, Rect2(margin, height - margin - 30.0, 230.0, 30.0))
	var visible_abilities := _visible_ability_count()
	var ability_width := float(visible_abilities) * ABILITY_WIDTH + float(maxi(0, visible_abilities - 1)) * ABILITY_GAP
	_place(_ability_panel, Rect2(width - margin - ability_width, height - margin - ABILITY_HEIGHT, ability_width, ABILITY_HEIGHT))
	_ability_panel.columns = maxi(1, visible_abilities)


func _apply_compact_layout() -> void:
	var width := size.x
	var height := size.y
	var margin := COMPACT_MARGIN
	var gap := 6.0
	var pause_width := 44.0
	var timer_width := 72.0
	var pause_left := width - margin - pause_width
	var timer_left := pause_left - gap - timer_width
	var reward_left := timer_left - 4.0 - DEFEAT_REWARD_WIDTH
	var vital_width := minf(220.0, maxf(132.0, reward_left - margin - gap))
	_place(_stability_panel, Rect2(margin, 8.0, vital_width, 30.0))
	_place(_shield_panel, Rect2(margin, 40.0, vital_width, 22.0))
	_place(_defeat_reward_panel, Rect2(reward_left, 10.0, DEFEAT_REWARD_WIDTH, 24.0))
	_place(_timer_panel, Rect2(timer_left, 10.0, timer_width, 24.0))
	_place(_pause_button, Rect2(pause_left, 0.0, pause_width, 44.0))
	var stats_width := minf(280.0, width - margin * 2.0)
	_place(_stats_strip, Rect2(width - margin - stats_width, 64.0, stats_width, 44.0))
	_fit_stat_columns(stats_width)
	_stats_strip.alignment = FlowContainer.ALIGNMENT_END
	var visible_abilities := _visible_ability_count()
	var ability_width := float(visible_abilities) * ABILITY_WIDTH + float(maxi(0, visible_abilities - 1)) * ABILITY_GAP
	var analysis_width := maxf(120.0, width - margin * 3.0 - ability_width)
	_place(_analysis_panel, Rect2(margin, height - margin - 30.0, analysis_width, 30.0))
	_place(_ability_panel, Rect2(width - margin - ability_width, height - margin - ABILITY_HEIGHT, ability_width, ABILITY_HEIGHT))
	_ability_panel.columns = maxi(1, visible_abilities)


func _place(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position.floor()
	control.size = rect.size.floor()


func _visible_ability_count() -> int:
	var result := 0
	for card in _ability_cards:
		if card.visible:
			result += 1
	return result


func _surface_panel(
	panel_name: String,
	role: int,
	accent: Color,
	add_to_root: bool = true
) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AlveolusUIComponents.apply_surface_role(panel, role, accent)
	if add_to_root:
		add_child(panel)
	return panel


func _make_hud_surface_transparent(panel: Panel, component_name: StringName) -> void:
	# Preserve semantic roles for tooling, while the HUD information itself
	# floats directly over the world. self_modulate affects the Panel's own draw
	# only; child readouts and interaction targets remain fully opaque.
	panel.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	var membrane := panel.get_node_or_null("BioLumenSurface") as Control
	if membrane != null:
		membrane.hide()
	panel.set_meta(&"alveolus_component", component_name)


func _fit_stat_columns(available_width: float) -> void:
	var gaps := float(STAT_GAP * (STAT_COLUMN_COUNT - 1))
	var row_width := maxf(44.0, floorf((available_width - gaps) / float(STAT_COLUMN_COUNT)))
	for row in _stat_rows:
		row.custom_minimum_size.x = row_width


func _on_stats_strip_resized() -> void:
	if _stats_strip.size.x > 0.0:
		_fit_stat_columns(_stats_strip.size.x)


func _stat_accent(stat: RunHUDViewModel.StatValueViewModel) -> Color:
	if String(stat.id()).begins_with("resistance_"):
		var damage_type_id := StringName(String(stat.id()).trim_prefix("resistance_"))
		return AlveolusVisualTheme.damage_type_accent(damage_type_id).lightened(0.22)
	match stat.icon_id():
		&"movement_training":
			return AlveolusVisualTheme.TURQUOISE.lightened(0.32)
		&"defense_training":
			return AlveolusVisualTheme.GOLD.lightened(0.20)
		&"life_regeneration":
			return AlveolusVisualTheme.TEAL.lightened(0.36)
		&"experience_gain":
			return AlveolusVisualTheme.SKY_DEEP.lightened(0.32)
	return AlveolusVisualTheme.IVORY


func _full_inset(content: Control, amount: int) -> MarginContainer:
	var inset := AlveolusUIComponents.margin(content, amount)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return inset


func _hud_icon(icon_name: String, kind: StringName, accent: Color, extent: float) -> SimpleIcon:
	var icon := SimpleIcon.new()
	icon.name = icon_name
	icon.custom_minimum_size = Vector2.ONE * extent
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.configure(kind, accent)
	return icon


func _hud_value(text_value: String, minimum_width: float) -> Label:
	var value := AlveolusUIComponents.label(text_value, AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	value.custom_minimum_size.x = minimum_width
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return value


func _set_label_text(label_control: Label, text_value: String) -> void:
	if label_control.text != text_value:
		label_control.text = text_value


func _set_progress(progress_control: ProgressBar, value: float, maximum: float) -> void:
	if not is_equal_approx(progress_control.max_value, maximum):
		progress_control.max_value = maximum
	if not is_equal_approx(progress_control.value, value):
		progress_control.value = value
