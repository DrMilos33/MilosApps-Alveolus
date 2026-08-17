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
const STAT_ROW_WIDTH := 76.0
const STAT_ROW_HEIGHT := 22.0
const STAT_GAP := 6
const ABILITY_HEIGHT := 68.0

var _view_model: RunHUDViewModel
var _applied_revision := -1
var _applied_content_hash := ""

var _stability_panel: Panel
var _stability_icon: SimpleIcon
var _stability_bar: ProgressBar
var _stability_value: Label
var _shield_panel: Panel
var _shield_icon: SimpleIcon
var _shield_bar: ProgressBar
var _shield_value: Label
var _timer_panel: Panel
var _timer_icon: SimpleIcon
var _timer_value: Label
var _boss_panel: Panel
var _boss_icon: SimpleIcon
var _boss_title: Label
var _boss_value: Label
var _boss_phase: Label
var _boss_bar: ProgressBar
var _analysis_panel: Panel
var _analysis_icon: SimpleIcon
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
	_build_timer()
	_build_boss()
	_build_analysis()
	_build_stats()
	_build_abilities()
	_build_pause()
	_configure_focus_paths()


func _build_stability() -> void:
	_stability_panel = _surface_panel("Stability", AlveolusVisualTheme.SurfaceRole.HUD_VITAL, AlveolusVisualTheme.TEAL)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_stability_panel.add_child(_full_inset(row, 8))
	_stability_icon = _hud_icon("StabilityIcon", &"stability_reserve", AlveolusVisualTheme.TURQUOISE, 22.0)
	row.add_child(_stability_icon)
	_stability_bar = AlveolusUIComponents.progress(0.0, 100.0, false)
	_stability_bar.name = "StabilityBar"
	_stability_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_stability_bar)
	_stability_value = _hud_value("100 / 100", 68.0)
	_stability_value.name = "StabilityValue"
	row.add_child(_stability_value)
	_stability_panel.set_meta(&"alveolus_accessible_name", "Zustand")


func _build_shield() -> void:
	_shield_panel = _surface_panel("Shield", AlveolusVisualTheme.SurfaceRole.HUD_VITAL, AlveolusVisualTheme.COBALT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_shield_panel.add_child(_full_inset(row, 5))
	_shield_icon = _hud_icon("ShieldIcon", &"ability_protection_field", AlveolusVisualTheme.COBALT, 20.0)
	row.add_child(_shield_icon)
	_shield_bar = AlveolusUIComponents.progress(0.0, 1.0, false)
	_shield_bar.name = "ShieldBar"
	_shield_bar.custom_minimum_size.y = 8.0
	_shield_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_shield_bar)
	_shield_value = _hud_value("0", 38.0)
	_shield_value.name = "ShieldValue"
	row.add_child(_shield_value)
	_shield_panel.set_meta(&"alveolus_accessible_name", "Schutz")


func _build_timer() -> void:
	_timer_panel = _surface_panel("Timer", AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE, AlveolusVisualTheme.TEAL)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_timer_panel.add_child(_full_inset(row, 6))
	_timer_icon = _hud_icon("TimerIcon", &"clock", AlveolusVisualTheme.TURQUOISE, 20.0)
	row.add_child(_timer_icon)
	_timer_value = AlveolusUIComponents.label("BOSS IN · 00:45", AlveolusVisualTheme.TYPE_HUD_LABEL)
	_timer_value.name = "TimerValue"
	_timer_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_timer_value)


func _build_boss() -> void:
	_boss_panel = _surface_panel("Boss", AlveolusVisualTheme.SurfaceRole.HUD_ALERT, AlveolusVisualTheme.CORAL)
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
	_analysis_panel = _surface_panel("Analysis", AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE, AlveolusVisualTheme.COBALT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_analysis_panel.add_child(_full_inset(row, 5))
	_analysis_icon = _hud_icon("AnalysisIcon", &"sample", AlveolusVisualTheme.COBALT, 20.0)
	row.add_child(_analysis_icon)
	_analysis_value = AlveolusUIComponents.label("Lv 0 · 0/0", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	_analysis_value.name = "AnalysisValue"
	_analysis_value.custom_minimum_size.x = 86.0
	_analysis_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_analysis_value)
	_analysis_bar = AlveolusUIComponents.progress(0.0, 1.0, false)
	_analysis_bar.name = "AnalysisBar"
	_analysis_bar.custom_minimum_size.y = 8.0
	_analysis_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_analysis_bar)


func _build_stats() -> void:
	_stats_strip = HFlowContainer.new()
	_stats_strip.name = "RunStatsStrip"
	_stats_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_strip.focus_mode = Control.FOCUS_NONE
	_stats_strip.alignment = FlowContainer.ALIGNMENT_END
	_stats_strip.add_theme_constant_override("h_separation", STAT_GAP)
	_stats_strip.add_theme_constant_override("v_separation", 4)
	_stats_strip.set_meta(&"alveolus_component", &"transparent_run_stats")
	add_child(_stats_strip)


func _build_abilities() -> void:
	_ability_panel = GridContainer.new()
	_ability_panel.name = "AbilitySlots"
	_ability_panel.columns = 2
	_ability_panel.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_ability_panel.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	add_child(_ability_panel)
	for slot in range(2):
		var card := _surface_panel(
			"AbilityCard%d" % (slot + 1),
			AlveolusVisualTheme.SurfaceRole.HUD_ABILITY,
			AlveolusVisualTheme.TURQUOISE,
			false
		)
		card.custom_minimum_size = Vector2(180.0, ABILITY_HEIGHT)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ability_panel.add_child(card)
		_ability_cards.append(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 2)
		card.add_child(_full_inset(stack, 6))
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 5)
		stack.add_child(heading)
		var icon := _hud_icon("AbilityIcon%d" % (slot + 1), &"ability", AlveolusVisualTheme.TURQUOISE, 22.0)
		heading.add_child(icon)
		_ability_icons.append(icon)
		var title := AlveolusUIComponents.label("Nicht belegt", AlveolusVisualTheme.TYPE_HUD_LABEL)
		title.name = "AbilityTitle%d" % (slot + 1)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.add_child(title)
		_ability_titles.append(title)
		var glyph := AlveolusUIComponents.label("Q" if slot == 0 else "E", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
		glyph.name = "AbilityGlyph%d" % (slot + 1)
		glyph.custom_minimum_size.x = 30.0
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		glyph.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.add_child(glyph)
		_ability_glyphs.append(glyph)
		var footer := HBoxContainer.new()
		footer.add_theme_constant_override("separation", 5)
		stack.add_child(footer)
		var status := AlveolusUIComponents.label("Nicht belegt", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
		status.name = "AbilityStatus%d" % (slot + 1)
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(status)
		_ability_statuses.append(status)
		var cooldown := AlveolusUIComponents.progress(0.0, 1.0, false)
		cooldown.name = "AbilityCooldown%d" % (slot + 1)
		cooldown.custom_minimum_size = Vector2(74.0, 8.0)
		cooldown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(cooldown)
		_ability_bars.append(cooldown)
		var hit := AlveolusUIComponents.action_button(
			"",
			AlveolusUIComponents.ACTION_QUIET,
			&"",
			AlveolusVisualTheme.TURQUOISE
		)
		hit.name = "AbilitySlot%d" % (slot + 1)
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.flat = true
		hit.focus_mode = Control.FOCUS_ALL
		hit.scale = Vector2.ONE
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.set_meta(&"disable_motion_scale", true)
		hit.set_meta(&"ability_slot", slot)
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
	_pause_button.focus_mode = Control.FOCUS_ALL
	_pause_button.scale = Vector2.ONE
	_pause_button.set_meta(&"disable_motion_scale", true)
	_pause_button.set_meta(&"alveolus_accessible_name", "Pause")
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
	var timer_color := AlveolusVisualTheme.IVORY
	match _view_model.timer_tone():
		&"attention":
			timer_color = AlveolusVisualTheme.GOLD
		&"danger":
			timer_color = AlveolusVisualTheme.CORAL
	if _timer_value.modulate != timer_color:
		_timer_value.modulate = timer_color
	_boss_panel.visible = _view_model.boss_visible()
	_set_label_text(_boss_title, _view_model.boss_title())
	if _boss_title.tooltip_text != _view_model.boss_title():
		_boss_title.tooltip_text = _view_model.boss_title()
	_set_label_text(_boss_value, _view_model.boss_percentage_text())
	_set_label_text(_boss_phase, _view_model.boss_phase_text())
	_set_progress(_boss_bar, _view_model.boss_current(), _view_model.boss_maximum())
	AlveolusUIComponents.apply_progress_accent(_boss_bar, AlveolusVisualTheme.CORAL)
	_set_progress(_analysis_bar, float(_view_model.analysis_current()), maxf(1.0, float(_view_model.analysis_target())))
	AlveolusUIComponents.apply_progress_accent(_analysis_bar, AlveolusVisualTheme.COBALT)
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
		if _stat_icons[index].kind != stat.icon_id() or _stat_icons[index].accent != AlveolusVisualTheme.IVORY:
			_stat_icons[index].configure(stat.icon_id(), AlveolusVisualTheme.IVORY)
		_set_label_text(_stat_values[index], stat.formatted_value())
		var accessible_text := "%s: %s" % [stat.accessible_name(), stat.formatted_value()]
		if _stat_rows[index].get_meta(&"alveolus_accessible_name", "") != accessible_text:
			_stat_rows[index].set_meta(&"alveolus_accessible_name", accessible_text)
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
	var icon := _hud_icon("StatIcon", stat.icon_id(), AlveolusVisualTheme.IVORY, 17.0)
	row.add_child(icon)
	_stat_icons.append(icon)
	var value := AlveolusUIComponents.label(stat.formatted_value(), AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	value.name = "StatValue"
	value.custom_minimum_size = Vector2(54.0, STAT_ROW_HEIGHT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value)
	_stat_values.append(value)


func _apply_abilities() -> void:
	_ability_panel.show()
	var focus_paths_changed := false
	for slot in range(2):
		var ability := _view_model.ability_at(slot)
		var accent := AlveolusVisualTheme.MUTED
		if ability.targeting():
			accent = AlveolusVisualTheme.TURQUOISE
		elif ability.ready():
			accent = AlveolusVisualTheme.TEAL
		elif ability.occupied():
			accent = AlveolusVisualTheme.COBALT
		if (
			_ability_cards[slot].get_meta(&"accent", Color.TRANSPARENT) != accent
			or _ability_cards[slot].get_meta(&"targeting", false) != ability.targeting()
		):
			AlveolusUIComponents.apply_surface_role(
				_ability_cards[slot],
				AlveolusVisualTheme.SurfaceRole.HUD_ABILITY,
				accent,
				ability.targeting()
			)
			_ability_cards[slot].set_meta(&"accent", accent)
		if _ability_icons[slot].kind != ability.icon_id() or _ability_icons[slot].accent != accent:
			_ability_icons[slot].configure(ability.icon_id(), accent)
		_set_label_text(_ability_titles[slot], ability.title())
		var title_color := AlveolusVisualTheme.IVORY if ability.occupied() else AlveolusVisualTheme.MUTED
		if _ability_titles[slot].modulate != title_color:
			_ability_titles[slot].modulate = title_color
		_set_label_text(_ability_glyphs[slot], ability.key_glyph_text())
		_set_label_text(_ability_statuses[slot], ability.status_text())
		if _ability_statuses[slot].modulate != accent:
			_ability_statuses[slot].modulate = accent
		_set_progress(_ability_bars[slot], ability.cooldown_progress(), 1.0)
		AlveolusUIComponents.apply_progress_accent(_ability_bars[slot], accent)
		if not _ability_cards[slot].has_meta(&"targeting") or _ability_cards[slot].get_meta(&"targeting") != ability.targeting():
			_ability_cards[slot].set_meta(&"targeting", ability.targeting())
		if not _ability_cards[slot].has_meta(&"ready") or _ability_cards[slot].get_meta(&"ready") != ability.ready():
			_ability_cards[slot].set_meta(&"ready", ability.ready())
		var should_disable := not ability.occupied()
		if _ability_buttons[slot].disabled != should_disable:
			AlveolusUIComponents.set_button_disabled(_ability_buttons[slot], should_disable)
			focus_paths_changed = true
		var tooltip := (
			"Ziel bestätigen" if ability.targeting()
			else ("Fähigkeit einsetzen" if ability.ready() else ability.status_text())
		)
		if _ability_buttons[slot].tooltip_text != tooltip:
			_ability_buttons[slot].tooltip_text = tooltip
		var accessible_text := "%s · %s · %s" % [ability.key_glyph_text(), ability.title(), ability.status_text()]
		if _ability_buttons[slot].get_meta(&"alveolus_accessible_name", "") != accessible_text:
			_ability_buttons[slot].set_meta(&"alveolus_accessible_name", accessible_text)
	if focus_paths_changed:
		_configure_focus_paths()


func _on_ability_pressed(slot: int) -> void:
	ability_requested.emit(slot)


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
	var vital_width := 250.0
	var timer_width := 224.0
	var pause_width := maxf(52.0, _pause_button.get_combined_minimum_size().x)
	var timer_left := floorf((width - timer_width) * 0.5)
	_place(_stability_panel, Rect2(margin, 16.0, vital_width, 44.0))
	_place(_shield_panel, Rect2(margin, 64.0, vital_width, 32.0))
	_place(_timer_panel, Rect2(timer_left, 16.0, timer_width, 40.0))
	_place(_pause_button, Rect2(width - margin - pause_width, 14.0, pause_width, 44.0))
	var stats_left := timer_left + timer_width + 12.0
	var stats_right := _pause_button.position.x - 8.0
	_place(_stats_strip, Rect2(stats_left, 12.0, maxf(0.0, stats_right - stats_left), 48.0))
	_stats_strip.alignment = FlowContainer.ALIGNMENT_END
	var boss_left := maxf(margin + vital_width + 12.0, floorf((width - 520.0) * 0.5))
	var boss_width := minf(520.0, width - margin - boss_left)
	_place(_boss_panel, Rect2(boss_left, 64.0, boss_width, 48.0))
	_place(_analysis_panel, Rect2(margin, height - margin - 32.0, 230.0, 32.0))
	var ability_width := minf(420.0, width * 0.46)
	_place(_ability_panel, Rect2(width - margin - ability_width, height - margin - ABILITY_HEIGHT, ability_width, ABILITY_HEIGHT))
	_ability_panel.columns = 2


func _apply_compact_layout() -> void:
	var width := size.x
	var height := size.y
	var margin := COMPACT_MARGIN
	var gap := 8.0
	var half_width := floorf((width - margin * 2.0 - gap) * 0.5)
	var right_left := margin + half_width + gap
	var maximum_pause_width := maxf(48.0, half_width - 88.0)
	var pause_width := minf(
		maximum_pause_width,
		maxf(48.0, _pause_button.get_combined_minimum_size().x)
	)
	_place(_stability_panel, Rect2(margin, 8.0, half_width, 44.0))
	_place(_timer_panel, Rect2(right_left, 8.0, maxf(80.0, half_width - pause_width - gap), 44.0))
	_place(_pause_button, Rect2(width - margin - pause_width, 8.0, pause_width, 44.0))
	_place(_shield_panel, Rect2(margin, 56.0, half_width, 32.0))
	_place(_boss_panel, Rect2(right_left, 56.0, half_width, 48.0))
	_place(_stats_strip, Rect2(margin, 108.0, width - margin * 2.0, 48.0))
	_stats_strip.alignment = FlowContainer.ALIGNMENT_BEGIN
	_place(_analysis_panel, Rect2(margin, 160.0, minf(220.0, width - margin * 2.0), 32.0))
	_place(_ability_panel, Rect2(margin, height - margin - ABILITY_HEIGHT, width - margin * 2.0, ABILITY_HEIGHT))
	_ability_panel.columns = 2


func _place(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position.floor()
	control.size = rect.size.floor()


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
