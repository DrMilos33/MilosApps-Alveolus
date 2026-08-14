class_name GameHUD
extends CanvasLayer

signal navigate_requested(destination: StringName)
signal back_requested
signal quit_requested
signal story_finished
signal level_selected(id: StringName)
signal briefing_start_requested
signal upgrade_chosen(definition: UpgradeDefinition)
signal reroll_requested
signal resume_requested
signal pause_levels_requested
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
signal discovery_dismissed
signal intro_skip_requested
signal intro_skip_confirmed
signal intro_skip_cancelled

const COLOR_BG := Color("101b23")
const COLOR_PANEL := Color(0.055, 0.105, 0.135, 0.97)
const COLOR_TEXT := Color("e7f3f1")
const COLOR_MUTED := Color("91abae")
const COLOR_TEAL := Color("58dacb")
const COLOR_BLUE := Color("76aaff")
const COLOR_RED := Color("ef7188")
const COLOR_GOLD := Color("f2bd68")

var root: Control
var gameplay_hud: Control
var stability_bar: ProgressBar
var stability_value: Label
var analysis_bar: ProgressBar
var level_label: Label
var timer_label: Label
var alert_label: Label
var boss_panel: Panel
var boss_bar: ProgressBar
var boss_value: Label
var boss_phase_label: Label
var boss_announcement: Label
var hit_vignette: ColorRect
var alert_time: float = 0.0
var boss_announcement_time: float = 0.0
var hit_feedback_time: float = 0.0
var stability_pulse_time: float = 0.0

var campus_overlay: Control
var campus_buttons: Dictionary = {}
var campus_research_status: Label
var campus_clinic_status: Label
var practice_overlay: Control
var practice_research_value: Label
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
var research_points_label: Label
var research_rank_labels: Dictionary = {}
var research_buy_buttons: Dictionary = {}
var level_overlay: Control
var level_buttons: Dictionary = {}
var level_card_labels: Dictionary = {}
var level_illustrations: Dictionary = {}
var lexicon_overlay: Control
var lexicon_buttons: Dictionary = {}
var lexicon_labels: Dictionary = {}
var lexicon_illustrations: Dictionary = {}
var lexicon_detail: Label
var story_overlay: Control
var story_kicker: Label
var story_title: Label
var story_body: Label
var story_next_button: Button
var story_index: int = 0
var settings_overlay: Control
var settings_quit_button: Button
var briefing_overlay: Control
var briefing_kicker: Label
var briefing_title: Label
var briefing_body: Label
var briefing_facts: Label
var briefing_skip_button: Button
var upgrade_overlay: Control
var upgrade_cards: HBoxContainer
var upgrade_education: Panel
var reroll_button: Button
var current_upgrade_options: Array[UpgradeDefinition] = []
var pause_overlay: Control
var pause_skip_button: Button
var abort_overlay: Control
var intro_skip_overlay: Control
var discovery_tooltip: DiscoveryTooltip
var upgrade_target_preview: UpgradeTargetPreview
var intro_upgrade_target: Variant
var end_overlay: Control
var end_title: Label
var end_reason: Label
var end_stats: Label
var end_reward: Label
var end_unlock: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	gameplay_hud = _build_gameplay_hud()
	campus_overlay = _build_campus()
	practice_overlay = _build_practice()
	research_overlay = _build_research()
	level_overlay = _build_level_select()
	lexicon_overlay = _build_lexicon()
	story_overlay = _build_story()
	settings_overlay = _build_settings()
	briefing_overlay = _build_briefing()
	upgrade_overlay = _build_upgrade_overlay()
	pause_overlay = _build_pause_overlay()
	abort_overlay = _build_abort_overlay()
	intro_skip_overlay = _build_intro_skip_overlay()
	end_overlay = _build_end_overlay()
	upgrade_target_preview = UpgradeTargetPreview.new()
	for overlay in _all_overlays():
		root.add_child(overlay)
	root.add_child(upgrade_target_preview)
	discovery_tooltip = DiscoveryTooltip.new()
	discovery_tooltip.dismissed.connect(func() -> void: discovery_dismissed.emit())
	root.add_child(discovery_tooltip)
	_hide_all()

func _process(delta: float) -> void:
	if alert_time > 0.0:
		alert_time -= delta
		if alert_time <= 0.0:
			alert_label.hide()
	if boss_announcement_time > 0.0:
		boss_announcement_time -= delta
		if boss_announcement_time <= 0.0:
			boss_announcement.hide()
	if hit_feedback_time > 0.0:
		hit_feedback_time -= delta
		hit_vignette.color.a = 0.16 * clampf(hit_feedback_time / 0.22, 0.0, 1.0)
	else:
		hit_vignette.color.a = 0.0
	if stability_pulse_time > 0.0:
		stability_pulse_time -= delta
		stability_bar.modulate = Color.WHITE.lerp(COLOR_RED, 0.42 * clampf(stability_pulse_time / 0.20, 0.0, 1.0))
	else:
		stability_bar.modulate = Color.WHITE

func _build_gameplay_hud() -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layer)
	var stability_panel := Panel.new()
	stability_panel.position = Vector2(16.0, 16.0)
	stability_panel.size = Vector2(286.0, 48.0)
	stability_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(COLOR_TEAL, 0.35), 1, 11))
	layer.add_child(stability_panel)
	var stability_margin := _margin(12, 8, 12, 7)
	stability_panel.add_child(stability_margin)
	var stability_row := HBoxContainer.new()
	stability_row.add_theme_constant_override("separation", 10)
	stability_margin.add_child(stability_row)
	var stability_stack := VBoxContainer.new()
	stability_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stability_stack.add_theme_constant_override("separation", 4)
	stability_row.add_child(stability_stack)
	stability_stack.add_child(_label("PATIENTENSTABILITÄT", 10, COLOR_MUTED))
	stability_bar = ProgressBar.new()
	stability_bar.custom_minimum_size = Vector2(0.0, 7.0)
	stability_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stability_bar.show_percentage = false
	stability_bar.add_theme_stylebox_override("background", _bar_style(Color("24343d"), 3))
	stability_bar.add_theme_stylebox_override("fill", _bar_style(COLOR_TEAL, 3))
	stability_stack.add_child(stability_bar)
	stability_value = _label("100 / 100", 12, COLOR_TEXT)
	stability_value.custom_minimum_size = Vector2(68.0, 0.0)
	stability_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stability_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stability_row.add_child(stability_value)

	var timer_panel := Panel.new()
	timer_panel.set_anchor(SIDE_LEFT, 0.5)
	timer_panel.set_anchor(SIDE_RIGHT, 0.5)
	timer_panel.offset_left = -135.0
	timer_panel.offset_right = 135.0
	timer_panel.offset_top = 16.0
	timer_panel.offset_bottom = 58.0
	timer_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(0.35, 0.48, 0.52, 0.32), 1, 11))
	layer.add_child(timer_panel)
	timer_label = _label("BOSS IN 00:45", 15, COLOR_TEXT)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_panel.add_child(timer_label)

	boss_panel = Panel.new()
	boss_panel.set_anchor(SIDE_LEFT, 0.5)
	boss_panel.set_anchor(SIDE_RIGHT, 0.5)
	boss_panel.offset_left = -260.0
	boss_panel.offset_right = 260.0
	boss_panel.offset_top = 70.0
	boss_panel.offset_bottom = 112.0
	boss_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.035, 0.05, 0.95), Color(COLOR_RED, 0.62), 1, 10))
	layer.add_child(boss_panel)
	var boss_margin := _margin(12, 6, 12, 6)
	boss_panel.add_child(boss_margin)
	var boss_stack := VBoxContainer.new()
	boss_stack.add_theme_constant_override("separation", 3)
	boss_margin.add_child(boss_stack)
	var boss_row := HBoxContainer.new()
	boss_stack.add_child(boss_row)
	boss_value = _label("INFEKTIONSHERD", 10, COLOR_RED)
	boss_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_row.add_child(boss_value)
	boss_phase_label = _label("PHASEN 70 % · 40 %", 9, COLOR_MUTED)
	boss_row.add_child(boss_phase_label)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(0.0, 8.0)
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("background", _bar_style(Color("301c27"), 3))
	boss_bar.add_theme_stylebox_override("fill", _bar_style(COLOR_RED, 3))
	boss_stack.add_child(boss_bar)
	boss_panel.hide()

	analysis_bar = ProgressBar.new()
	analysis_bar.set_anchor(SIDE_RIGHT, 1.0)
	analysis_bar.set_anchor(SIDE_TOP, 1.0)
	analysis_bar.set_anchor(SIDE_BOTTOM, 1.0)
	analysis_bar.offset_top = -6.0
	analysis_bar.show_percentage = false
	analysis_bar.add_theme_stylebox_override("background", _bar_style(Color(0.07, 0.12, 0.16, 0.92), 0))
	analysis_bar.add_theme_stylebox_override("fill", _bar_style(COLOR_BLUE, 0))
	layer.add_child(analysis_bar)
	level_label = _label("STUFE 0", 11, COLOR_BLUE)
	level_label.set_anchor(SIDE_TOP, 1.0)
	level_label.set_anchor(SIDE_BOTTOM, 1.0)
	level_label.offset_left = 14.0
	level_label.offset_top = -29.0
	level_label.offset_right = 140.0
	level_label.offset_bottom = -9.0
	layer.add_child(level_label)

	alert_label = _label("", 14, COLOR_TEXT)
	alert_label.set_anchor(SIDE_LEFT, 0.5)
	alert_label.set_anchor(SIDE_RIGHT, 0.5)
	alert_label.offset_left = -260.0
	alert_label.offset_right = 260.0
	alert_label.offset_top = 126.0
	alert_label.offset_bottom = 160.0
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alert_label.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.09, 0.12, 0.90), Color(COLOR_TEAL, 0.32), 1, 9))
	alert_label.hide()
	layer.add_child(alert_label)

	boss_announcement = _label("INFEKTIONSHERD ERKANNT", 25, COLOR_RED)
	boss_announcement.set_anchor(SIDE_LEFT, 0.5)
	boss_announcement.set_anchor(SIDE_RIGHT, 0.5)
	boss_announcement.set_anchor(SIDE_TOP, 0.5)
	boss_announcement.offset_left = -300.0
	boss_announcement.offset_right = 300.0
	boss_announcement.offset_top = -42.0
	boss_announcement.offset_bottom = 42.0
	boss_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_announcement.add_theme_stylebox_override("normal", _panel_style(Color(0.09, 0.025, 0.04, 0.94), COLOR_RED, 1, 12))
	boss_announcement.hide()
	layer.add_child(boss_announcement)

	hit_vignette = ColorRect.new()
	hit_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_vignette.color = Color(0.85, 0.08, 0.16, 0.0)
	hit_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hit_vignette)
	return layer

func _build_campus() -> Control:
	var overlay := _overlay_base(Color.TRANSPARENT)
	var scene := CampusScene.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(scene)
	var logo := _label("ALVEOLUS", 28, COLOR_TEXT)
	logo.position = Vector2(28.0, 22.0)
	logo.size = Vector2(300.0, 38.0)
	overlay.add_child(logo)
	var subtitle := _label("PRAXIS-CAMPUS · ABENDDIENST", 10, Color(COLOR_TEAL, 0.82))
	subtitle.position = Vector2(30.0, 61.0)
	subtitle.size = Vector2(330.0, 20.0)
	overlay.add_child(subtitle)
	var top_status := VBoxContainer.new()
	top_status.position = Vector2(880.0, 24.0)
	top_status.size = Vector2(368.0, 55.0)
	overlay.add_child(top_status)
	campus_research_status = _label("FORSCHUNG 0", 12, COLOR_GOLD)
	campus_research_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_status.add_child(campus_research_status)
	campus_clinic_status = _label("KEIN KLINIKFALL AKTIV", 10, COLOR_MUTED)
	campus_clinic_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_status.add_child(campus_clinic_status)
	var cards := [
		[&"practice", "PRAXIS", COLOR_TEAL, Vector2(270, 132), Vector2(270, 238), PackedVector2Array([Vector2(80, 17), Vector2(191, 49), Vector2(238, 76), Vector2(238, 159), Vector2(211, 170), Vector2(211, 190), Vector2(198, 202), Vector2(124, 183), Vector2(51, 153), Vector2(51, 80)]), Vector2(64, -34)],
		[&"research", "FORSCHUNG", COLOR_GOLD, Vector2(685, 128), Vector2(430, 330), PackedVector2Array([Vector2(173, 7), Vector2(288, 37), Vector2(413, 119), Vector2(413, 215), Vector2(370, 243), Vector2(315, 259), Vector2(314, 279), Vector2(301, 290), Vector2(132, 265), Vector2(46, 212), Vector2(46, 88)]), Vector2(135, -34)],
		[&"levels", "FALLARCHIV", COLOR_BLUE, Vector2(218, 386), Vector2(300, 252), PackedVector2Array([Vector2(91, 32), Vector2(211, 61), Vector2(279, 104), Vector2(279, 176), Vector2(250, 193), Vector2(250, 208), Vector2(237, 219), Vector2(85, 196), Vector2(63, 186), Vector2(63, 103)]), Vector2(76, -34)],
		[&"lexicon", "LEXIKON", COLOR_TEAL, Vector2(548, 418), Vector2(272, 235), PackedVector2Array([Vector2(85, 25), Vector2(202, 53), Vector2(251, 98), Vector2(251, 169), Vector2(226, 184), Vector2(226, 203), Vector2(213, 214), Vector2(69, 193), Vector2(42, 180), Vector2(42, 97)]), Vector2(73, -34)],
		[&"settings", "EINSTELLUNGEN", COLOR_MUTED, Vector2(852, 470), Vector2(188, 170), PackedVector2Array([Vector2(55, 39), Vector2(129, 53), Vector2(169, 88), Vector2(169, 126), Vector2(150, 136), Vector2(150, 151), Vector2(139, 160), Vector2(49, 145), Vector2(27, 133), Vector2(27, 86)]), Vector2(22, -34)]
	]
	for data in cards:
		var id: StringName = data[0]
		var card := CampusBuildingCard.new()
		card.position = data[3]
		card.size = data[4]
		card.configure(data[1], data[5], data[2], data[6])
		card.selected.connect(_emit_navigation.bind(id))
		overlay.add_child(card)
		campus_buttons[id] = card
	return overlay

func _build_practice() -> Control:
	var page := _page("PRAXIS", "", "ZUM CAMPUS")
	var overlay: Control = page["overlay"]
	var body: VBoxContainer = page["body"]
	var balance_row := HBoxContainer.new()
	body.add_child(balance_row)
	var intro := _label("Automatische Forschung und Klinikfälle laufen auch bei geschlossenem Spiel weiter.", 11, COLOR_MUTED)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_row.add_child(intro)
	practice_research_value = _label("Forschung 0", 16, COLOR_GOLD)
	balance_row.add_child(practice_research_value)
	var columns := HBoxContainer.new()
	columns.custom_minimum_size = Vector2(0.0, 188.0)
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)
	var offline := _card(COLOR_BLUE)
	offline["panel"].custom_minimum_size = Vector2(320.0, 188.0)
	columns.add_child(offline["panel"])
	var offline_box: VBoxContainer = offline["content"]
	offline_box.add_child(_section_header("AUTOMATISCHE FORSCHUNG", &"offline", COLOR_BLUE))
	passive_info = _label("Noch keine Forschung abholbar", 13, COLOR_TEXT)
	passive_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	offline_box.add_child(passive_info)
	passive_claim_button = _primary_button("ABHOLEN", COLOR_BLUE)
	passive_claim_button.custom_minimum_size = Vector2(0.0, 34.0)
	passive_claim_button.pressed.connect(func() -> void: offline_claim_requested.emit())
	offline_box.add_child(passive_claim_button)

	var clinic := _card(COLOR_TEAL)
	clinic["panel"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clinic["panel"].custom_minimum_size = Vector2(0.0, 188.0)
	columns.add_child(clinic["panel"])
	var clinic_box: VBoxContainer = clinic["content"]
	clinic_box.add_child(_section_header("KLINIKFALL · EIN AKTIVER SLOT", &"clinic", COLOR_TEAL))
	clinic_status = _label("Wähle einen zeitgesteuerten Fall.", 14, COLOR_TEXT)
	clinic_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clinic_box.add_child(clinic_status)
	clinic_progress = ProgressBar.new()
	clinic_progress.custom_minimum_size = Vector2(0.0, 8.0)
	clinic_progress.show_percentage = false
	clinic_progress.add_theme_stylebox_override("background", _bar_style(Color("24343d"), 5))
	clinic_progress.add_theme_stylebox_override("fill", _bar_style(COLOR_TEAL, 5))
	clinic_box.add_child(clinic_progress)
	var clinic_details := HBoxContainer.new()
	clinic_box.add_child(clinic_details)
	clinic_remaining = _label("", 12, COLOR_TEXT)
	clinic_remaining.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clinic_details.add_child(clinic_remaining)
	clinic_reward = _label("", 12, COLOR_GOLD)
	clinic_details.add_child(clinic_reward)
	clinic_finish = _label("", 10, COLOR_MUTED)
	clinic_box.add_child(clinic_finish)
	clinic_offers = HBoxContainer.new()
	clinic_offers.add_theme_constant_override("separation", 8)
	clinic_box.add_child(clinic_offers)
	for id in [&"short_review", &"follow_up", &"complex_case"]:
		var button := _secondary_button("", COLOR_TEAL)
		button.custom_minimum_size = Vector2(132.0, 54.0)
		button.add_theme_font_size_override("font_size", 10)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_emit_job_start.bind(id))
		clinic_offers.add_child(button)
		clinic_offer_buttons[id] = button
	clinic_claim_button = _primary_button("BELOHNUNG ABHOLEN", COLOR_GOLD)
	clinic_claim_button.custom_minimum_size = Vector2(0.0, 34.0)
	clinic_claim_button.pressed.connect(func() -> void: clinic_job_claim_requested.emit())
	clinic_box.add_child(clinic_claim_button)
	return overlay

func _build_research() -> Control:
	var page := _page("FORSCHUNG", "DAUERHAFTE PRAXISENTWICKLUNG", "ZUM CAMPUS")
	var overlay: Control = page["overlay"]
	var body: VBoxContainer = page["body"]
	var row := HBoxContainer.new()
	body.add_child(row)
	var note := _label("Kleine, gedeckelte Verbesserungen unterstützen den nächsten Fall.", 12, COLOR_MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	research_points_label = _label("Forschung 0", 18, COLOR_GOLD)
	row.add_child(research_points_label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for definition in ContentCatalog.research_definitions():
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(330.0, 112.0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(COLOR_GOLD, 0.30), 1, 10))
		grid.add_child(panel)
		var margin := _margin(12, 10, 12, 10)
		panel.add_child(margin)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		margin.add_child(box)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 9)
		box.add_child(header)
		var icon := SimpleIcon.new()
		icon.custom_minimum_size = Vector2(34.0, 34.0)
		icon.configure(definition.id, COLOR_GOLD)
		header.add_child(icon)
		var title_stack := VBoxContainer.new()
		title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title_stack)
		title_stack.add_child(_label(definition.title, 14, COLOR_TEXT))
		var description := _label(definition.description, 10, COLOR_MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_stack.add_child(description)
		var footer := HBoxContainer.new()
		box.add_child(footer)
		var rank_label := _label("RANG 0 / %d" % definition.max_level, 10, COLOR_GOLD)
		rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(rank_label)
		var buy := _secondary_button("", COLOR_GOLD)
		buy.custom_minimum_size = Vector2(132.0, 30.0)
		buy.add_theme_font_size_override("font_size", 9)
		buy.pressed.connect(_emit_research_purchase.bind(definition.id))
		footer.add_child(buy)
		research_rank_labels[definition.id] = rank_label
		research_buy_buttons[definition.id] = buy
	return overlay

func _build_level_select() -> Control:
	var page := _page("FALLARCHIV", "", "ZUM CAMPUS")
	var overlay: Control = page["overlay"]
	var body: VBoxContainer = page["body"]
	var actions: HBoxContainer = page["actions"]
	var replay_story := _nav_button("PROLOG", &"story", COLOR_BLUE)
	replay_story.pressed.connect(func() -> void: navigate_requested.emit(&"story"))
	actions.add_child(replay_story)
	actions.move_child(replay_story, 0)
	actions.custom_minimum_size = Vector2(300.0, 38.0)
	var top := HBoxContainer.new()
	body.add_child(top)
	var hint := _label("Wähle einen dokumentierten Fall. Ein Sieg schaltet den nächsten frei.", 11, COLOR_MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	for level in ContentCatalog.level_definitions():
		var button := Button.new()
		button.custom_minimum_size = Vector2(286.0, 246.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_contents = true
		button.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.08, 0.105, 0.98), Color(COLOR_BLUE, 0.32), 1, 12))
		button.add_theme_stylebox_override("hover", _panel_style(Color("153039"), COLOR_BLUE, 2, 12))
		button.add_theme_stylebox_override("disabled", _panel_style(Color(0.025, 0.045, 0.055, 0.96), Color(COLOR_MUTED, 0.18), 1, 12))
		button.pressed.connect(_emit_level_selected.bind(level.id))
		row.add_child(button)
		var accent_strip := ColorRect.new()
		accent_strip.position = Vector2.ZERO
		accent_strip.size = Vector2(286.0, 4.0)
		accent_strip.color = COLOR_GOLD if level.is_tutorial else COLOR_BLUE
		accent_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(accent_strip)
		var illustration := LevelCaseIllustration.new()
		illustration.position = Vector2(196.0, 16.0)
		illustration.size = Vector2(68.0, 68.0)
		illustration.configure(level.order, level.is_tutorial, COLOR_GOLD if level.is_tutorial else COLOR_BLUE)
		button.add_child(illustration)
		var status_label := _label("", 9, COLOR_BLUE)
		status_label.position = Vector2(16.0, 15.0)
		status_label.size = Vector2(170.0, 18.0)
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(status_label)
		var title_label := _label(_level_card_title(level), 14, COLOR_TEXT)
		title_label.position = Vector2(16.0, 40.0)
		title_label.size = Vector2(172.0, 48.0)
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.max_lines_visible = 2
		title_label.clip_text = true
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(title_label)
		var separator := ColorRect.new()
		separator.position = Vector2(16.0, 102.0)
		separator.size = Vector2(254.0, 1.0)
		separator.color = Color(COLOR_BLUE, 0.20)
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(separator)
		var facts_label := _label("", 10, COLOR_MUTED)
		facts_label.position = Vector2(16.0, 115.0)
		facts_label.size = Vector2(254.0, 18.0)
		facts_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(facts_label)
		var best_label := _label("", 10, COLOR_TEXT)
		best_label.position = Vector2(16.0, 146.0)
		best_label.size = Vector2(254.0, 18.0)
		best_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(best_label)
		var record_label := _label("", 9, COLOR_MUTED)
		record_label.position = Vector2(16.0, 174.0)
		record_label.size = Vector2(254.0, 18.0)
		record_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(record_label)
		var action_label := _label("FALL ÖFFNEN  →", 10, COLOR_BLUE)
		action_label.position = Vector2(16.0, 211.0)
		action_label.size = Vector2(254.0, 18.0)
		action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(action_label)
		level_buttons[level.id] = button
		level_card_labels[level.id] = {
			"status": status_label,
			"title": title_label,
			"facts": facts_label,
			"best": best_label,
			"record": record_label,
			"action": action_label,
		}
		level_illustrations[level.id] = illustration
	return overlay

func _build_lexicon() -> Control:
	var page := _page("MEDIZINISCHES LEXIKON", "DOKUMENTIERTE ENTDECKUNGEN", "ZUM CAMPUS")
	var overlay: Control = page["overlay"]
	var body: VBoxContainer = page["body"]
	var note := _label("Neue Erreger und Mechaniken werden beim ersten Auftreten automatisch dokumentiert.", 12, COLOR_MUTED)
	body.add_child(note)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	body.add_child(grid)
	for discovery in ContentCatalog.discovery_definitions().values():
		var entry_button := Button.new()
		entry_button.custom_minimum_size = Vector2(228.0, 126.0)
		entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry_button.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.08, 0.10, 0.96), Color(COLOR_TEAL, 0.25), 1, 10))
		entry_button.add_theme_stylebox_override("hover", _panel_style(Color(0.07, 0.14, 0.16, 0.98), COLOR_TEAL, 1, 10))
		entry_button.pressed.connect(_show_lexicon_entry.bind(discovery))
		grid.add_child(entry_button)
		var illustration := MedicalLexiconIllustration.new()
		illustration.position = Vector2(74.0, 9.0)
		illustration.size = Vector2(80.0, 72.0)
		illustration.configure(discovery.id, COLOR_TEAL)
		illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry_button.add_child(illustration)
		var entry_label := _label(discovery.title, 11, COLOR_TEXT)
		entry_label.position = Vector2(9.0, 88.0)
		entry_label.size = Vector2(210.0, 28.0)
		entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		entry_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		entry_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry_button.add_child(entry_label)
		lexicon_buttons[discovery.id] = entry_button
		lexicon_labels[discovery.id] = entry_label
		lexicon_illustrations[discovery.id] = illustration
	var detail_panel := Panel.new()
	detail_panel.custom_minimum_size = Vector2(0.0, 112.0)
	detail_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.095, 0.97), Color(COLOR_TEAL, 0.32), 1, 10))
	body.add_child(detail_panel)
	var detail_margin := _margin(16, 13, 16, 13)
	detail_panel.add_child(detail_margin)
	lexicon_detail = _label("Wähle einen entdeckten Eintrag. Medizinische Bedeutung und Spielwirkung werden hier gemeinsam erklärt.", 12, COLOR_MUTED)
	lexicon_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_margin.add_child(lexicon_detail)
	return overlay

func _build_story() -> Control:
	var parts := _centered_overlay(Vector2(620.0, 300.0), COLOR_BLUE, 28)
	var overlay: Control = parts["overlay"]
	var box: VBoxContainer = parts["content"]
	story_kicker = _label("PROLOG · 1 / 3", 11, COLOR_BLUE)
	box.add_child(story_kicker)
	story_title = _label("Willkommen bei ALVEOLUS", 28, COLOR_TEXT)
	box.add_child(story_title)
	story_body = _label("", 16, Color("c8dcdb"))
	story_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(story_body)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	box.add_child(controls)
	var skip := _secondary_button("ÜBERSPRINGEN", COLOR_MUTED)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(func() -> void: story_finished.emit())
	controls.add_child(skip)
	story_next_button = _primary_button("WEITER", COLOR_BLUE)
	story_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_next_button.pressed.connect(_advance_story)
	controls.add_child(story_next_button)
	return overlay

func _build_settings() -> Control:
	var parts := _centered_overlay(Vector2(560.0, 330.0), COLOR_MUTED)
	var overlay: Control = parts["overlay"]
	var box: VBoxContainer = parts["content"]
	box.add_child(_label("EINSTELLUNGEN", 26, COLOR_TEXT))
	var text := _label("Dieses Menü ist als Teil des vollständigen Spielflusses vorbereitet. Funktionale Audio-, Anzeige- und Zugänglichkeitsoptionen folgen in einem späteren Meilenstein.", 14, COLOR_MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var back := _primary_button("ZURÜCK", COLOR_MUTED)
	back.pressed.connect(func() -> void: back_requested.emit())
	box.add_child(back)
	settings_quit_button = _secondary_button("SPIEL BEENDEN", COLOR_RED)
	settings_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(settings_quit_button)
	return overlay

func _build_briefing() -> Control:
	var parts := _centered_overlay(Vector2(620.0, 168.0), COLOR_TEAL, 14)
	var overlay: Control = parts["overlay"]
	var box: VBoxContainer = parts["content"]
	briefing_kicker = _label("FALL", 11, COLOR_TEAL)
	box.add_child(briefing_kicker)
	briefing_title = _label("", 22, COLOR_TEXT)
	briefing_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(briefing_title)
	briefing_body = _label("", 11, Color("c8dcdb"))
	briefing_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_body.hide()
	box.add_child(briefing_body)
	briefing_facts = _label("", 11, COLOR_MUTED)
	box.add_child(briefing_facts)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	var back := _secondary_button("ZURÜCK", COLOR_MUTED)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void: back_requested.emit())
	buttons.add_child(back)
	briefing_skip_button = _secondary_button("INTRO ÜBERSPRINGEN", COLOR_GOLD)
	briefing_skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	briefing_skip_button.pressed.connect(func() -> void: intro_skip_requested.emit())
	buttons.add_child(briefing_skip_button)
	var begin := _primary_button("STARTEN", COLOR_TEAL)
	begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	begin.pressed.connect(func() -> void: briefing_start_requested.emit())
	buttons.add_child(begin)
	return overlay

func _build_upgrade_overlay() -> Control:
	var overlay := _overlay_base(Color(0.015, 0.030, 0.040, 0.82))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := _label("THERAPIE ANPASSEN", 18, COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	upgrade_education = Panel.new()
	upgrade_education.custom_minimum_size = Vector2(882.0, 48.0)
	upgrade_education.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.075, 0.04, 0.97), COLOR_GOLD, 1, 9))
	box.add_child(upgrade_education)
	var education_text := _label("ANTIBIOTISCH: direkter Erregerschaden   ·   IMMUN: Nahbereichsschutz   ·   SUPPORTIV: Patientenstabilität", 11, COLOR_GOLD)
	education_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	education_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	education_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upgrade_education.add_child(education_text)
	upgrade_cards = HBoxContainer.new()
	upgrade_cards.add_theme_constant_override("separation", 12)
	box.add_child(upgrade_cards)
	reroll_button = _secondary_button("R · NEU WÄHLEN (1×)", COLOR_BLUE)
	reroll_button.custom_minimum_size = Vector2(190.0, 36.0)
	reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
	box.add_child(reroll_button)
	return overlay

func _build_pause_overlay() -> Control:
	var parts := _centered_overlay(Vector2(340.0, 314.0), COLOR_BLUE, 18)
	var overlay: Control = parts["overlay"]
	var box: VBoxContainer = parts["content"]
	var title := _label("BEHANDLUNG PAUSIERT", 21, COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := _primary_button("WEITER · ESC", COLOR_BLUE)
	resume.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(resume)
	var settings := _secondary_button("EINSTELLUNGEN", COLOR_MUTED)
	settings.pressed.connect(func() -> void: navigate_requested.emit(&"settings"))
	box.add_child(settings)
	var levels := _secondary_button("ZUR FALLAUSWAHL", COLOR_BLUE)
	levels.pressed.connect(func() -> void: pause_levels_requested.emit())
	box.add_child(levels)
	pause_skip_button = _secondary_button("INTRO ÜBERSPRINGEN", COLOR_GOLD)
	pause_skip_button.pressed.connect(func() -> void: intro_skip_requested.emit())
	box.add_child(pause_skip_button)
	var abort := _secondary_button("LEVEL ABBRECHEN", COLOR_RED)
	abort.pressed.connect(func() -> void: abort_requested.emit())
	box.add_child(abort)
	return overlay

func _build_abort_overlay() -> Control:
	var parts := _centered_overlay(Vector2(450.0, 250.0), COLOR_RED, 24)
	var overlay: Control = parts["overlay"]
	var box: VBoxContainer = parts["content"]
	box.add_child(_label("LEVEL ABBRECHEN?", 22, COLOR_TEXT))
	var text := _label("Der Fortschritt dieses Runs und die mögliche Forschungsbelohnung gehen verloren.", 13, COLOR_MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var cancel := _secondary_button("ZURÜCK", COLOR_MUTED)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: abort_cancelled.emit())
	row.add_child(cancel)
	var confirm := _primary_button("ABBRECHEN", COLOR_RED)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(func() -> void: abort_confirmed.emit())
	row.add_child(confirm)
	return overlay

func _build_intro_skip_overlay() -> Control:
	var parts := _centered_overlay(Vector2(450.0, 235.0), COLOR_GOLD, 22)
	var overlay: Control = parts["overlay"]
	var box: VBoxContainer = parts["content"]
	box.add_child(_label("EINFÜHRUNG ÜBERSPRINGEN?", 20, COLOR_TEXT))
	var text := _label("Fall 1 wird freigeschaltet. Es gibt keine Forschung, keinen Sieg und keinen Versuchseintrag. Die Einführung bleibt wiederholbar.", 12, COLOR_MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var cancel := _secondary_button("ZURÜCK", COLOR_MUTED)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: intro_skip_cancelled.emit())
	row.add_child(cancel)
	var confirm := _primary_button("INTRO ÜBERSPRINGEN", COLOR_GOLD)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(func() -> void: intro_skip_confirmed.emit())
	row.add_child(confirm)
	return overlay

func _build_end_overlay() -> Control:
	var parts := _centered_overlay(Vector2(620.0, 430.0), COLOR_TEAL, 28)
	var overlay: Control = parts["overlay"]
	var box: VBoxContainer = parts["content"]
	end_title = _label("FALL ABGESCHLOSSEN", 26, COLOR_TEXT)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_title)
	end_reason = _label("", 14, Color("c8dcdb"))
	end_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_reason)
	end_stats = _label("", 12, COLOR_MUTED)
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_stats)
	end_reward = _label("", 18, COLOR_GOLD)
	end_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_reward)
	end_unlock = _label("", 12, COLOR_BLUE)
	end_unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_unlock)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	box.add_child(row)
	var retry := _secondary_button("ERNEUT BEHANDELN", COLOR_TEAL)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(func() -> void: retry_requested.emit())
	row.add_child(retry)
	var levels := _primary_button("FALLÜBERSICHT", COLOR_BLUE)
	levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels.pressed.connect(func() -> void: result_levels_requested.emit())
	row.add_child(levels)
	var campus := _secondary_button("ZUM CAMPUS", COLOR_MUTED)
	campus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campus.pressed.connect(func() -> void: result_campus_requested.emit())
	row.add_child(campus)
	return overlay

func show_campus(meta: MetaProgressionState, jobs: Dictionary) -> void:
	_hide_all()
	campus_overlay.modulate = Color.WHITE
	refresh_campus(meta, jobs)
	campus_overlay.show()

func refresh_campus(meta: MetaProgressionState, jobs: Dictionary) -> void:
	var job_status := "Kein Klinikfall aktiv"
	if meta.active_job_id != &"" and jobs.has(meta.active_job_id):
		job_status = "Belohnung bereit" if meta.is_job_complete() else "Klinikfall läuft"
	campus_research_status.text = "FORSCHUNG  %d" % meta.research_points
	campus_clinic_status.text = job_status.to_upper()
	var practice_button: CampusBuildingCard = campus_buttons[&"practice"]
	var practice_badge := job_status
	if meta.claimable_research() > 0:
		practice_badge += " · %d Forschung abholbar" % meta.claimable_research()
	practice_button.set_status(practice_badge, meta.claimable_research() > 0 or meta.is_job_complete())
	var research_button: CampusBuildingCard = campus_buttons[&"research"]
	var active_research := 0
	for rank_value in meta.research_ranks.values():
		if int(rank_value) > 0:
			active_research += 1
	research_button.set_status("%d Punkte · %d Projekte aktiv" % [meta.research_points, active_research], meta.research_points > 0)
	var level_button: CampusBuildingCard = campus_buttons[&"levels"]
	level_button.set_status("%d von 4 Fällen freigeschaltet" % [meta.highest_unlocked_level + 1], true)
	var lexicon_button: CampusBuildingCard = campus_buttons[&"lexicon"]
	lexicon_button.set_status("%d Entdeckungen dokumentiert" % meta.seen_discovery_ids.size(), meta.seen_discovery_ids.size() > 0)
	var settings_button: CampusBuildingCard = campus_buttons[&"settings"]
	settings_button.set_status("Anzeige · Steuerung · Beenden", false)

func show_practice(meta: MetaProgressionState, jobs: Dictionary) -> void:
	_hide_all()
	_show_campus_context()
	practice_overlay.show()
	refresh_practice(meta, jobs)

func refresh_practice(meta: MetaProgressionState, jobs: Dictionary) -> void:
	practice_research_value.text = "Forschung  %d" % meta.research_points
	var claimable := meta.claimable_research()
	passive_info.text = "%s gespeichert\nKapazität: 8 Stunden" % _format_duration(floori(meta.passive_seconds), false)
	passive_claim_button.text = "%d FORSCHUNG ABHOLEN" % claimable if claimable > 0 else "NOCH NICHTS ABHOLBAR"
	passive_claim_button.disabled = claimable <= 0
	var has_job := meta.active_job_id != &"" and jobs.has(meta.active_job_id)
	var job_complete := has_job and meta.is_job_complete()
	clinic_progress.visible = has_job and not job_complete
	clinic_remaining.visible = has_job and not job_complete
	clinic_finish.visible = has_job
	clinic_reward.visible = has_job
	clinic_offers.visible = not has_job
	clinic_claim_button.visible = job_complete
	if not has_job:
		clinic_status.text = "Wähle einen zeitgesteuerten Fall"
		for id in clinic_offer_buttons:
			var button: Button = clinic_offer_buttons[id]
			var definition: ClinicJobDefinition = jobs[id]
			button.text = "%s\n%s · +%d" % [definition.title, definition.duration_text(), definition.reward]
		return
	var active: ClinicJobDefinition = jobs[meta.active_job_id]
	var remaining := meta.job_seconds_remaining()
	var elapsed := active.duration_seconds - remaining
	clinic_status.text = "%s abgeschlossen · Belohnung bereit" % active.title if job_complete else "%s läuft" % active.title
	clinic_progress.max_value = active.duration_seconds
	clinic_progress.value = clampi(elapsed, 0, active.duration_seconds)
	clinic_remaining.text = "%s verbleibend" % _format_duration(remaining, true)
	clinic_reward.text = "+%d Forschung" % active.reward
	clinic_finish.text = "Abgeschlossen um %s" % _local_time(meta.job_finishes_at) if job_complete else "Voraussichtlich fertig um %s" % _local_time(meta.job_finishes_at)

func show_research(meta: MetaProgressionState, definitions: Array[ResearchDefinition]) -> void:
	_hide_all()
	_show_campus_context()
	research_overlay.show()
	refresh_research(meta, definitions)

func refresh_research(meta: MetaProgressionState, definitions: Array[ResearchDefinition]) -> void:
	research_points_label.text = "Forschung  %d" % meta.research_points
	for definition in definitions:
		var rank := meta.rank(definition.id)
		var rank_label: Label = research_rank_labels[definition.id]
		var button: Button = research_buy_buttons[definition.id]
		rank_label.text = "RANG %d / %d" % [rank, definition.max_level]
		if rank >= definition.max_level:
			button.text = "MAXIMUM ERREICHT"
			button.disabled = true
		else:
			var cost := definition.cost_for_rank(rank)
			button.text = "%d FORSCHUNG" % cost
			button.disabled = meta.research_points < cost

func show_level_select(meta: MetaProgressionState, levels: Array[LevelDefinition]) -> void:
	_hide_all()
	_show_campus_context()
	for level in levels:
		var button: Button = level_buttons[level.id]
		var card: Dictionary = level_card_labels[level.id]
		var illustration: LevelCaseIllustration = level_illustrations[level.id]
		var unlocked := meta.is_level_unlocked(level.order)
		var record := meta.get_level_record(level.id)
		var status := "GESPERRT" if not unlocked else ("ABGESCHLOSSEN" if record.victories > 0 else "BEREIT")
		var best := "Noch kein Sieg"
		if record.best_time >= 0.0:
			best = "Beste Zeit %s" % _format_duration(floori(record.best_time), false)
		(card["status"] as Label).text = "%s  ·  %s" % ["INTRO" if level.is_tutorial else "FALL %02d" % level.order, status]
		(card["title"] as Label).text = _level_card_title(level)
		(card["facts"] as Label).text = "%s  ·  BOSS %s" % [level.duration_text().to_upper(), level.boss_time_text().to_upper()]
		(card["best"] as Label).text = best
		(card["record"] as Label).text = "%d Siege  ·  Analyse %d  ·  %d Erreger" % [record.victories, record.highest_analysis, record.best_defeats]
		(card["action"] as Label).text = "GESPERRT" if not unlocked else "FALL ÖFFNEN  →"
		button.disabled = not unlocked
		for label in card.values():
			(label as Label).modulate = Color.WHITE if unlocked else Color(0.55, 0.58, 0.60, 0.72)
		illustration.modulate = Color.WHITE if unlocked else Color(0.42, 0.48, 0.50, 0.55)
	level_overlay.show()

func show_lexicon(meta: MetaProgressionState) -> void:
	_hide_all()
	_show_campus_context()
	for discovery in ContentCatalog.discovery_definitions().values():
		var seen := meta.has_seen_discovery(discovery.id)
		var entry_button: Button = lexicon_buttons[discovery.id]
		var entry_label: Label = lexicon_labels[discovery.id]
		var illustration: MedicalLexiconIllustration = lexicon_illustrations[discovery.id]
		entry_button.disabled = not seen
		entry_label.text = discovery.title if seen else "Noch nicht beobachtet"
		entry_label.modulate = Color.WHITE if seen else Color(0.50, 0.58, 0.60, 0.72)
		illustration.set_locked(not seen)
	lexicon_detail.text = "Wähle einen entdeckten Eintrag. Medizinische Bedeutung und Spielwirkung werden hier gemeinsam erklärt."
	lexicon_overlay.show()

func show_story() -> void:
	_hide_all()
	story_index = 0
	_refresh_story()
	story_overlay.show()

func show_settings(show_quit: bool = true, campus_context: bool = true) -> void:
	_hide_all()
	if campus_context:
		_show_campus_context()
	else:
		gameplay_hud.show()
	settings_quit_button.visible = show_quit
	settings_overlay.show()

func show_briefing(level: LevelDefinition) -> void:
	_hide_all()
	_show_campus_context()
	briefing_kicker.text = "EINFÜHRUNG" if level.is_tutorial else "FALL %02d" % level.order
	briefing_title.text = level.title
	briefing_body.text = level.briefing_text
	briefing_facts.text = "%s     ·     BOSS %s     ·     STARTSTABILITÄT %d" % [level.duration_text().to_upper(), level.boss_time_text().to_upper(), roundi(level.initial_stability)]
	briefing_skip_button.visible = level.is_tutorial
	briefing_overlay.show()

func show_running_hud() -> void:
	_hide_all()
	upgrade_target_preview.clear()
	gameplay_hud.show()
	boss_panel.hide()

func update_stability(current: float, maximum: float) -> void:
	stability_bar.max_value = maximum
	stability_bar.value = current
	stability_value.text = "%d / %d" % [roundi(current), roundi(maximum)]
	var fraction := current / maxf(maximum, 1.0)
	var fill_color := COLOR_TEAL
	if fraction < 0.30:
		fill_color = COLOR_RED
	elif fraction < 0.58:
		fill_color = COLOR_GOLD
	stability_bar.add_theme_stylebox_override("fill", _bar_style(fill_color, 3))

func show_patient_hit() -> void:
	hit_feedback_time = 0.22
	stability_pulse_time = 0.20

func update_analysis(current: int, target: int, level: int) -> void:
	analysis_bar.max_value = maxi(target, 1)
	analysis_bar.value = current
	level_label.text = "STUFE %d · %d/%d" % [level, current, target]

func update_timer(elapsed: float, boss_spawn_seconds: float, deadline_seconds: float, boss_active: bool) -> void:
	var remaining := maxf(0.0, (deadline_seconds if boss_active else boss_spawn_seconds) - elapsed)
	timer_label.text = "%s %s" % ["BOSS AKTIV ·" if boss_active else "BOSS IN", _clock_text(remaining)]
	timer_label.modulate = COLOR_RED if boss_active else COLOR_TEXT

func update_intro_timer(lesson: int, phase: StringName, boss_active: bool) -> void:
	if boss_active:
		timer_label.text = "EINFÜHRUNG · MINI-BOSS"
		timer_label.modulate = COLOR_RED
		return
	timer_label.text = "EINFÜHRUNG · LEKTION %d/3" % clampi(lesson, 1, 3)
	timer_label.modulate = COLOR_GOLD if phase != &"" else COLOR_TEXT

func show_boss(maximum: float, phase_count: int) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = maximum
	boss_phase_label.text = "PHASEN 70 % · 40 %" if phase_count > 0 else "EINFÜHRUNGSBOSS"
	boss_panel.show()
	boss_announcement.show()
	boss_announcement_time = 1.2

func update_boss_health(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
	boss_value.text = "INFEKTIONSHERD · %d %%" % roundi(100.0 * current / maxf(maximum, 1.0))

func show_boss_phase(phase: int) -> void:
	boss_phase_label.text = "PHASE %d AKTIV" % (phase + 1)

func show_alert(text: String, color: Color = COLOR_TEAL, duration: float = 2.8) -> void:
	alert_label.text = text
	alert_label.modulate = color
	alert_label.show()
	alert_time = duration

func show_upgrade_choices(options: Array[UpgradeDefinition], stats: PlayerStats, can_reroll: bool, show_education: bool = false) -> void:
	current_upgrade_options = options.duplicate()
	var scripted_intro := options.size() == 1
	upgrade_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for child in upgrade_cards.get_children():
		child.queue_free()
	for index in range(options.size()):
		var definition: UpgradeDefinition = options[index]
		var preview := stats.preview_upgrade(definition)
		# Dauerhafter Kartenvertrag: Name, exakter Effekt und Vorher/Nachher – keine Beschreibungstexte.
		var card := Button.new()
		card.custom_minimum_size = Vector2(440.0, 150.0) if scripted_intro else Vector2(286.0, 138.0)
		card.clip_contents = true
		card.add_theme_stylebox_override("normal", _panel_style(COLOR_PANEL, definition.accent_color(), 2, 14))
		card.add_theme_stylebox_override("hover", _panel_style(Color("17313a"), definition.accent_color(), 3, 14))
		card.add_theme_stylebox_override("pressed", _panel_style(Color("1d3c45"), definition.accent_color(), 3, 14))
		card.pressed.connect(_on_upgrade_pressed.bind(definition))
		if scripted_intro:
			card.mouse_entered.connect(_show_intro_upgrade_preview.bind(preview.target_type))
			card.mouse_exited.connect(upgrade_target_preview.clear)
			card.focus_entered.connect(_show_intro_upgrade_preview.bind(preview.target_type))
			card.focus_exited.connect(upgrade_target_preview.clear)
		upgrade_cards.add_child(card)
		var margin := _margin(15, 12, 15, 12)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(margin)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 7)
		margin.add_child(content)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 8)
		content.add_child(heading)
		var path_icon := SimpleIcon.new()
		path_icon.custom_minimum_size = Vector2(26.0, 26.0)
		path_icon.configure(_upgrade_icon_kind(definition), definition.accent_color())
		heading.add_child(path_icon)
		var card_title := _label(definition.title, 14, COLOR_TEXT)
		card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.add_child(card_title)
		var effect := _label(preview.effect_text, 17, definition.accent_color())
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.max_lines_visible = 1
		content.add_child(effect)
		var comparison := _label(preview.before_after_text, 11, COLOR_TEXT)
		comparison.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		comparison.max_lines_visible = 2
		content.add_child(comparison)
	upgrade_education.visible = show_education and not scripted_intro
	reroll_button.visible = can_reroll
	upgrade_overlay.show()
	if scripted_intro and upgrade_cards.get_child_count() > 0:
		var first_card := upgrade_cards.get_child(0) as Button
		first_card.grab_focus()
		_show_intro_upgrade_preview(stats.preview_upgrade(options[0]).target_type)

func activate_upgrade(index: int) -> void:
	if not upgrade_overlay.visible or index < 0 or index >= current_upgrade_options.size():
		return
	upgrade_chosen.emit(current_upgrade_options[index])

func show_pause(is_intro: bool = false) -> void:
	pause_skip_button.visible = is_intro
	pause_overlay.show()

func hide_pause() -> void:
	pause_overlay.hide()

func show_abort_confirmation() -> void:
	pause_overlay.hide()
	abort_overlay.show()

func show_intro_skip_confirmation() -> void:
	pause_overlay.hide()
	intro_skip_overlay.show()

func hide_intro_skip_confirmation() -> void:
	intro_skip_overlay.hide()

func show_discovery(definition: DiscoveryDefinition, gameplay_target: Variant, gameplay_override: String = "") -> void:
	var resolved_target: Variant = gameplay_target
	if resolved_target == null:
		match definition.target_type:
			&"stability_bar":
				resolved_target = stability_bar
			&"boss_bar":
				resolved_target = boss_bar
			&"reward":
				resolved_target = end_reward
	discovery_tooltip.present(definition, resolved_target, gameplay_override)

func hide_discovery() -> void:
	discovery_tooltip.conceal()

func set_intro_upgrade_target(target: Variant) -> void:
	intro_upgrade_target = target

func show_end(level: LevelDefinition, success: bool, reason: String, elapsed: float, analysis_level: int, defeats: int, reward: int, unlocked_new: bool) -> void:
	_hide_all()
	gameplay_hud.show()
	end_title.text = "INFEKTIONSKONTROLLE ERREICHT" if success else "PATIENT INSTABIL"
	end_title.modulate = COLOR_TEAL if success else COLOR_RED
	end_reason.text = "%s\n%s" % [reason, level.victory_text if success else level.failure_text]
	end_stats.text = "Behandlungszeit %s · Analysestufe %d · Erreger %d" % [_clock_text(elapsed), analysis_level, defeats]
	end_reward.text = "+%d Forschung" % reward
	end_unlock.text = "NEUER FALL FREIGESCHALTET" if unlocked_new else ""
	end_overlay.show()

func _advance_story() -> void:
	if story_index >= 2:
		story_finished.emit()
		return
	story_index += 1
	_refresh_story()

func _refresh_story() -> void:
	var titles := ["Willkommen bei ALVEOLUS", "Das Lungenmodell", "Deine Aufgabe"]
	var texts := [
		"Du leitest die neue Abteilung ALVEOLUS. Hier werden bakterielle Patientenfälle analysiert und Therapieentscheidungen als spielbare Modelle untersucht.",
		"Das Innere der Lunge wird bewusst stilisiert dargestellt. Der Therapie-Avatar steht für koordinierte Behandlung – nicht für einen Arzt, der sich buchstäblich im Körper befindet.",
		"Kontrolliere Infektionsherde, unterstütze die Immunreaktion und erhalte die Patientenstabilität. Jeder Fall liefert Analyse und Forschung für die Praxis."
	]
	story_kicker.text = "PROLOG · %d / 3" % (story_index + 1)
	story_title.text = titles[story_index]
	story_body.text = texts[story_index]
	story_next_button.text = "ZUM CAMPUS" if story_index == 2 else "WEITER"

func _show_lexicon_entry(definition: DiscoveryDefinition) -> void:
	lexicon_detail.text = "%s\n%s\n%s" % [definition.title.to_upper(), definition.medical_text, definition.gameplay_text]

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
	return [campus_overlay, practice_overlay, research_overlay, level_overlay, lexicon_overlay, story_overlay, settings_overlay, briefing_overlay, upgrade_overlay, pause_overlay, abort_overlay, intro_skip_overlay, end_overlay]

func _hide_all() -> void:
	gameplay_hud.hide()
	if upgrade_target_preview != null:
		upgrade_target_preview.clear()
	if discovery_tooltip != null:
		discovery_tooltip.hide()
	for overlay in _all_overlays():
		overlay.hide()

func _emit_navigation(id: StringName) -> void:
	navigate_requested.emit(id)

func _emit_level_selected(id: StringName) -> void:
	level_selected.emit(id)

func _emit_job_start(id: StringName) -> void:
	clinic_job_start_requested.emit(id)

func _emit_research_purchase(id: StringName) -> void:
	research_purchase_requested.emit(id)

func _on_upgrade_pressed(definition: UpgradeDefinition) -> void:
	upgrade_chosen.emit(definition)

func _page(title: String, kicker: String, back_text: String) -> Dictionary:
	var overlay := _overlay_base(Color(0.018, 0.035, 0.045, 0.90))
	var header_back := ColorRect.new()
	header_back.position = Vector2.ZERO
	header_back.size = Vector2(1280.0, 82.0)
	header_back.color = Color(0.018, 0.035, 0.045, 0.98)
	header_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(header_back)
	var outer := _margin(24, 16, 24, 18)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(outer)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	outer.add_child(page)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 54.0)
	page.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 1)
	header.add_child(title_stack)
	if not kicker.is_empty():
		title_stack.add_child(_label(kicker, 9, COLOR_TEAL))
	title_stack.add_child(_label(title, 24, COLOR_TEXT))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(actions)
	var back := _nav_button(back_text, &"back", COLOR_MUTED)
	back.pressed.connect(func() -> void: back_requested.emit())
	actions.add_child(back)
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)
	return {"overlay": overlay, "body": body, "actions": actions}

func _nav_button(text: String, kind: StringName, accent: Color) -> Button:
	var button := _secondary_button(text, accent)
	button.custom_minimum_size = Vector2(146.0, 38.0)
	var icon := SimpleIcon.new()
	icon.position = Vector2(11.0, 8.0)
	icon.size = Vector2(22.0, 22.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.configure(kind, accent)
	button.add_child(icon)
	return button

func _section_header(text: String, kind: StringName, accent: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := SimpleIcon.new()
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.configure(kind, accent)
	row.add_child(icon)
	var title := _label(text, 10, accent)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	return row

func _upgrade_icon_kind(definition: UpgradeDefinition) -> StringName:
	match definition.path:
		UpgradeDefinition.Path.IMMUNE:
			return &"immune"
		UpgradeDefinition.Path.SUPPORT:
			return &"support"
		_:
			return &"antibiotic"

func _building_button(title: String, kind: StringName, accent: Color) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0.0, 225.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(COLOR_PANEL, Color(accent, 0.38), 1, 15))
	button.add_theme_stylebox_override("hover", _panel_style(Color("17313a"), accent, 2, 15))
	var icon := SimpleIcon.new()
	icon.position = Vector2(24.0, 22.0)
	icon.size = Vector2(58.0, 58.0)
	icon.configure(&"archive" if kind == &"levels" else kind, accent)
	button.add_child(icon)
	return button

func _overlay_base(color: Color) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	return overlay

func _centered_overlay(panel_size: Vector2, accent: Color, padding: int = 24) -> Dictionary:
	var overlay := _overlay_base(Color(0.015, 0.030, 0.040, 0.93))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := Panel.new()
	panel.custom_minimum_size = panel_size
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, accent, 1, 14))
	center.add_child(panel)
	var margin := _margin(padding, padding, padding, padding)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	return {"overlay": overlay, "panel": panel, "content": content}

func _card(accent: Color) -> Dictionary:
	var panel := Panel.new()
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.082, 0.105, 0.94), Color(accent, 0.38), 1, 12))
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
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _primary_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", COLOR_BG)
	button.add_theme_color_override("font_hover_color", COLOR_BG)
	button.add_theme_stylebox_override("normal", _panel_style(accent, accent, 0, 9))
	button.add_theme_stylebox_override("hover", _panel_style(accent.lightened(0.10), accent, 0, 9))
	button.add_theme_stylebox_override("pressed", _panel_style(accent.darkened(0.10), accent, 0, 9))
	return button

func _secondary_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.06, 0.11, 0.14, 0.96), Color(accent, 0.56), 1, 8))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.09, 0.17, 0.20, 0.98), accent, 1, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.10, 0.20, 0.23, 1.0), accent, 1, 8))
	return button

func _panel_style(background: Color, border: Color, border_width: int = 1, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

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
	match level.order:
		1:
			return "Lokalisierter\nPneumokokkenherd"
		2:
			return "Ausbreitende\nbakterielle Pneumonie"
		3:
			return "Schwere bakterielle\nPneumonie"
		_:
			return level.title

func _local_time(unix_time: int) -> String:
	var zone := Time.get_time_zone_from_system()
	var local_timestamp := unix_time + int(zone.get("bias", 0)) * 60
	var date := Time.get_datetime_dict_from_unix_time(local_timestamp)
	return "%02d:%02d Uhr" % [int(date.hour), int(date.minute)]
