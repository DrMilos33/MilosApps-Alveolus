extends SceneTree

const OUTPUT_DIR := "res://.codex-temp/visual_restart/screens"
const EXPECTED_CAPTURE_COUNT := 32

var capture_size := Vector2i(1280, 720)
var capture_scale := 1.0
var capture_suffix := "1280x720"
var capture_count := 0
var capture_failed := false

func _init() -> void:
	_parse_capture_arguments()
	call_deferred("_capture_views")

func _parse_capture_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-size="):
			var parts := argument.trim_prefix("--capture-size=").split("x")
			if parts.size() == 2:
				capture_size = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--capture-scale="):
			capture_scale = float(argument.trim_prefix("--capture-scale="))
		elif argument.begins_with("--capture-suffix="):
			capture_suffix = argument.trim_prefix("--capture-suffix=")

func _capture_views() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# Configure the logical canvas before the main scene exists. Resizing a live
	# stretched root above its project viewport produced black false-positive
	# screenshots, especially for 1280×800.
	get_root().content_scale_size = capture_size
	get_root().size = capture_size
	DisplayServer.window_set_size(capture_size)
	await _settle_frames(5)

	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await _settle()
	var settings := UISettingsState.new()
	settings.ui_scale = capture_scale
	game.hud.configure_ui_settings(settings)
	await _settle()
	await _capture_suite(game)

	game.queue_free()
	await _settle()
	if capture_failed or capture_count != EXPECTED_CAPTURE_COUNT:
		push_error("Visuelle Abnahme unvollständig: %d/%d für %s" % [capture_count, EXPECTED_CAPTURE_COUNT, capture_suffix])
		quit(1)
		return
	print("ALVEOLUS_VISUAL_CAPTURE_OK suffix=%s captures=%d" % [capture_suffix, capture_count])
	quit(0)

func _capture_suite(game: Node) -> void:
	game._show_campus()
	await _capture("campus")
	game.hud.show_story()
	await _capture("story")
	game._show_practice()
	await _capture("practice")
	game.meta.research_ranks[&"stability_reserve"] = 3
	# Talent captures must not depend on the developer's persisted campaign
	# progress. Unlock the production tree only inside this disposable fixture.
	game.meta.get_level_record(&"localized_focus").victories = 1
	game._show_research()
	await _settle()
	_verify_document_page(game.hud, game.hud.research_overlay, "research")
	if not _verify_research_capture(game):
		return
	await _capture("research")
	var research_source: Button = game.hud.progression_screen.research_action(&"stability_reserve")
	if research_source == null:
		capture_failed = true
		push_error("Mehr Leben besitzt keine stabile Tooltipquelle")
		return
	research_source.mouse_entered.emit()
	await _settle()
	var research_payload: Dictionary = game.hud.context_detail_controller.current_payload()
	if game.hud.context_detail_controller.active_source() != research_source \
		or not String(research_payload.get("body", "")).contains("Gesamt: +9 Leben"):
		capture_failed = true
		push_error("Forschung zeigt die Rangsumme nicht ausschließlich im stabilen Tooltip")
		return
	await _capture("research_tooltip")
	game.hud.close_all_context_details()
	game.hud._select_research_tab(&"talents")
	await _settle()
	_verify_document_page(game.hud, game.hud.research_overlay, "talents")
	if not _verify_talent_tree(game.hud.progression_screen):
		return
	await _capture("talents")
	game.meta.talent_ranks[&"treatment_damage_training"] = 1
	game.meta.talent_ranks[&"spread_shotgun"] = 1
	game.hud.refresh_talents(game._talent_view_model())
	await _settle()
	var ranked_talent: Button = game.hud.progression_screen.talent_action(&"spread_shotgun")
	var rank_pips := ranked_talent.find_child("TalentRankPips", true, false) as Control if ranked_talent != null else null
	if ranked_talent == null \
		or int(ranked_talent.get_meta(&"talent_rank_current", 0)) != 1 \
		or int(ranked_talent.get_meta(&"talent_rank_maximum", 0)) != 1 \
		or not String(ranked_talent.get_meta(&"alveolus_accessible_name", "")).contains("Rang 1 von 1") \
		or rank_pips == null:
		capture_failed = true
		push_error("Talentbaum aktualisiert Mehrfachrang/Pips/Accessibility nicht in-place")
		return
	ranked_talent.mouse_entered.emit()
	await _settle()
	if game.hud.context_detail_controller.active_source() != ranked_talent:
		capture_failed = true
		push_error("Talentdetails öffnen nicht am tatsächlichen kompakten Knoten")
		return
	await _capture("talents_ranked_tooltip")
	game.hud.close_all_context_details()
	game._show_level_select()
	await _capture("levels")
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game._show_lexicon()
	await _settle()
	if game.hud.lexicon_master_detail.selected_entry_id != &"":
		capture_failed = true
		push_error("Lexikon markiert beim Öffnen unerwartet den ersten Eintrag")
		return
	await _capture("lexicon")
	# `move_focus=true` also opens the compact list-to-detail view used at 200 %.
	if not game.hud.lexicon_master_detail.select_entry(&"pneumococcus", true):
		capture_failed = true
		push_error("Bekannter Gegner konnte für die strukturierte Typwert-Capture nicht ausgewählt werden")
		return
	await _settle()
	if not _verify_lexicon_type_presentation(game.hud.lexicon_master_detail):
		return
	await _capture("lexicon_types")
	var related_chips: Array[Node] = game.hud.lexicon_master_detail.detail_related_chips.get_children()
	var related_chip := related_chips[0] as Button if not related_chips.is_empty() else null
	if related_chip == null \
		or related_chip.focus_mode != Control.FOCUS_ALL \
		or StringName(related_chip.get_meta(&"lexicon_related_term_id", &"")) == &"" \
		or not related_chip.tooltip_text.is_empty():
		capture_failed = true
		push_error("Lexikon-Verweis besitzt keinen stabilen fokussierbaren DTO-Chip")
		return
	game.hud.lexicon_master_detail.detail_scroll.ensure_control_visible(related_chip)
	await _settle()
	related_chip.mouse_entered.emit()
	await _settle()
	var related_payload: Dictionary = game.hud.context_detail_controller.current_payload()
	if game.hud.context_detail_controller.active_source() != related_chip \
		or String(related_payload.get("body", "")).strip_edges().is_empty():
		capture_failed = true
		push_error("Lexikon-Verweis zeigt seine DTO-Erklärung nicht über ContextDetail")
		return
	await _capture("lexicon_related_tooltip")
	game.hud.close_all_context_details()
	game.hud.show_settings(true, true)
	await _capture("settings")
	var test_values_section := game.hud.settings_screen.find_child("TestValuesSection", true, false) as Control
	if test_values_section == null:
		capture_failed = true
		push_error("Debug-Einstellungen besitzen keine sichtbare Testwerte-Sektion")
		return
	game.hud.settings_screen.get_scroll_container().ensure_control_visible(test_values_section)
	await _settle()
	await _capture("settings_test_values")

	game.selected_level = game.levels[0]
	game._show_preparation()
	await _settle()
	if game.hud.preparation_workspace.visible or not game.hud.preparation_lock_panel.is_visible_in_tree():
		capture_failed = true
		push_error("Einführungsplan zeigt keine vollständige Sperrfläche")
		return
	await _capture("preparation_intro_locked")
	# Re-enter through the real level-selection route. Reusing the still-open
	# intro overlay would intentionally preserve its compact lock scroll offset
	# and hide the case dossier in the following capture.
	game._show_level_select()
	await _settle()

	game.meta.research_ranks[&"unlock_spread_treatment"] = 1
	game.meta.research_ranks[&"unlock_piercing_treatment"] = 1
	game.selected_level = game.levels[1]
	game._show_preparation()
	if not _verify_direct_preparation_state(game):
		return
	await _capture("preparation")
	await _capture_preparation_editor_states(game)
	game.start_run(game.pending_run_context)
	await _settle_frames(45)
	game.hud.set_run_stats_visibility(true)
	await _settle()
	if not _verify_run_hud_capture(game.hud.run_hud_screen):
		return
	await _capture("run")
	game.hud.show_run_prompt("Beobachte den ersten Erreger.", PlainRunPrompt.MODE_NORMAL)
	await _capture("run_prompt_normal")
	game.hud.hide_run_prompt()
	game.hud.show_run_prompt(
		"Infektionsherd erkannt",
		PlainRunPrompt.MODE_CORAL,
		true,
		"Linksklick zum Fortfahren"
	)
	await _capture("run_prompt_boss")
	game.hud.hide_run_prompt()
	game.hud.show_pause(false, game.stats, game.state)
	await _capture("pause")
	game.hud._show_pause_test_values()
	await _settle()
	if game.hud.pause_screen.current_mode() != PauseOverlay.Mode.TEST \
		or game.hud.pause_screen.test_control(&"damage_immunity") == null \
		or game.hud.pause_screen.test_control(&"outgoing_damage_bonus_percent") == null \
		or game.hud.pause_screen.test_control(&"movement_speed_percent") == null:
		capture_failed = true
		push_error("Pause-Capture besitzt keinen vollständigen Testwerte-Untermodus")
		return
	await _capture("pause_test_values")
	_populate_character_stats_capture(game)
	game.hud._show_pause_stats()
	await _settle()
	if not _verify_pause_accordion(game.hud.pause_screen):
		return
	await _capture("pause_stats")
	game.hud.pause_screen.set_section_expanded(&"general", false)
	game.hud.pause_screen.set_section_expanded(&"treatment:treatment_precision", true)
	await _settle()
	await _capture("pause_stats_treatment")
	game.hud.hide_pause()
	var upgrade_by_id: Dictionary = {}
	for upgrade in ContentCatalog.upgrade_definitions():
		upgrade_by_id[upgrade.id] = upgrade
	var visual_upgrades: Array[UpgradeDefinition] = [
		upgrade_by_id[&"potency"] as UpgradeDefinition,
		upgrade_by_id[&"rhythm"] as UpgradeDefinition,
		upgrade_by_id[&"neutrophils"] as UpgradeDefinition,
	]
	game.hud.show_upgrade_choices(visual_upgrades, game.stats, true, false)
	await _settle()
	if not _verify_level_up_title(game.hud.upgrade_screen):
		return
	if not _verify_upgrade_capture(game, visual_upgrades):
		return
	await _capture("upgrades")
	await _capture_transient_dialogs(game)
	game.hud.show_end(game.selected_level, true, "Der Herd ist kontrolliert.", 151.0, 5, 74, 22, true)
	game.hud.set_result_reward_presentations(game.result_reward_presentations(22))
	var visual_damage_stats: Array[Dictionary] = [
		{"id": &"treatment_precision", "label": "Impuls", "damage": 812},
		{"id": &"ability_defense_burst", "label": "Stoß", "damage": 164},
	]
	var visual_talent_stats: Array[Dictionary] = [
		{"id": &"treatment_damage_training", "label": "Behandlungsgrundlage", "rank": 2, "max_rank": 3},
	]
	game.hud.set_result_damage_statistics(visual_damage_stats)
	game.hud.set_result_talent_statistics(visual_talent_stats, true, true)
	await _settle()
	if not _verify_result_rewards(game.hud.result_screen):
		return
	if not _verify_result_ability_section(game.hud.result_screen, false):
		return
	await _capture("result")
	game.hud.result_screen.get_ability_section_header().button_pressed = true
	await _settle()
	if not _verify_result_ability_section(game.hud.result_screen, true):
		return
	await _capture("result_abilities")

func _populate_character_stats_capture(game: Node) -> void:
	# Keep the visual contract honest by capturing the densest supported sheet,
	# including all five stable accordion sections. Their disclosure state, not a
	# permanently expanded flat sheet, controls the visible density.
	if game.stats.prepared_treatment == null or game.stats.prepared_treatment.id != &"treatment_precision":
		capture_failed = true
		push_error("Visual-Capture startet Charakterwerte nicht mit dem deterministischen Präzisen Impuls")
		return
	game.stats.therapy_projectiles = 3
	game.stats.therapy_max_hits = 4
	game.stats.immune_level = 3
	game.stats.defense = 6.0
	game.stats.life_regeneration_per_second = 1.5
	game.stats.prepared_abilities.assign([
		AbilityDefinition.catalog()[&"ability_defense_burst"],
		AbilityDefinition.catalog()[&"ability_treatment_line"],
	])


func _verify_lexicon_type_presentation(lexicon: LexiconMasterDetail) -> bool:
	var chips: Array[Control] = []
	for node in _descendants(lexicon.detail_type_sections):
		if node is Control and node.get_meta(&"alveolus_component", &"") == &"damage_type_chip":
			chips.append(node as Control)
	var valid := chips.size() == 8
	for chip in chips:
		var type_id := StringName(String(chip.get_meta(&"damage_type_id", &"")))
		valid = valid \
			and DamageTypeCatalog.ALL_IDS.has(type_id) \
			and chip.find_child("DamageTypeIcon", true, false) is SimpleIcon \
			and chip.find_child("DamageTypeName", true, false) is Label \
			and chip.find_child("DamageTypeValue", true, false) is Label
	for node in _descendants(lexicon.detail_content):
		if not node is Label or not (node as Label).is_visible_in_tree():
			continue
		var copy := (node as Label).text.to_lower()
		if copy.contains(" px") or copy.contains("pixel") or copy.contains("weltpunkt") or copy.contains("weltmaß"):
			valid = false
	if valid:
		return true
	capture_failed = true
	push_error("Lexikon zeigt nicht exakt vier strukturierte Schadenstypen und vier effektive Resistenzen ohne interne Entfernungseinheit")
	return false


func _verify_run_hud_capture(run_hud: RunHUDOverlay) -> bool:
	var rows := run_hud.stat_rows()
	var valid := rows.size() == 8 \
		and _row_populations(rows) == [4, 4] \
		and run_hud.defeat_research_reward_panel().is_visible_in_tree() \
		and run_hud.defeat_research_reward_icon().kind == &"research" \
		and not run_hud.defeat_research_reward_value_label().text.is_empty() \
		and not String(run_hud.defeat_research_reward_panel().get_meta(&"alveolus_accessible_name", "")).is_empty() \
		and run_hud.defeat_research_reward_panel().get_global_rect().end.x <= run_hud.timer_panel().get_global_rect().position.x + 0.5
	for row in rows:
		valid = valid and RunHUDViewModel.BASIC_STAT_IDS.has(row.get_meta(&"stat_id", &""))
	if valid:
		return true
	capture_failed = true
	push_error("Run-Capture zeigt nicht acht Grundwerte in Viererreihen plus zugänglichen Forschungsgewinn links vom Timer")
	return false


func _verify_pause_accordion(pause_screen: PauseOverlay) -> bool:
	var expected_ids := [
		&"general",
		&"treatment:treatment_precision",
		&"ability:0:ability_defense_burst",
		&"ability:1:ability_treatment_line",
		&"ability:run:defense_cells",
	]
	var valid := pause_screen.current_mode() == PauseOverlay.Mode.STATS \
		and pause_screen.stat_sections().size() == expected_ids.size() \
		and pause_screen.is_section_expanded(&"general")
	for section_id in expected_ids:
		var header := pause_screen.section_header(section_id)
		valid = valid \
			and header != null \
			and header.focus_mode == Control.FOCUS_ALL \
			and not String(header.get_meta(&"alveolus_accessible_name", "")).is_empty()
	if valid:
		return true
	capture_failed = true
	var actual_ids: Array[String] = []
	for section in pause_screen.stat_sections():
		actual_ids.append(String(section.get_meta(&"section_id", &"")))
	push_error("Charakterwerte-Capture besitzt nicht die fünf stabilen fokussierbaren Accordion-Sektionen (Modus %d, IDs %s)" % [pause_screen.current_mode(), str(actual_ids)])
	return false


func _verify_level_up_title(upgrade_screen: UpgradeOverlay) -> bool:
	var title := upgrade_screen.find_child("LevelUpTitle", true, false) as Label
	var sheet := upgrade_screen.modal_sheet()
	var valid := title != null \
		and title.text == "Level Up!" \
		and title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER \
		and absf(title.get_global_rect().get_center().x - sheet.get_global_rect().get_center().x) <= 1.0
	if valid:
		return true
	capture_failed = true
	push_error("Level-Up-Capture zentriert die lokale Überschrift nicht im Modal")
	return false


func _verify_research_capture(game: Node) -> bool:
	var screen := game.hud.progression_screen as ProgressionScreen
	var definitions := ContentCatalog.research_definitions()
	var logical_width := screen.size.x
	var expected_columns := 4 if logical_width >= 1100.0 else (3 if logical_width >= 900.0 else (2 if logical_width >= 680.0 else 1))
	var valid := screen.research_columns() == expected_columns and definitions.size() == 10
	for definition in definitions:
		var action := screen.research_action(definition.id)
		valid = valid \
			and action != null \
			and action.theme_type_variation in [
				AlveolusVisualTheme.TYPE_COMPACT_RESEARCH,
				AlveolusVisualTheme.TYPE_SELECTED_COMPACT_RESEARCH,
			]
		if action == null:
			continue
		for node in _descendants(action):
			if node is Label and (node as Label).is_visible_in_tree():
				valid = valid and not (node as Label).text.contains("Gesamt:")
	if valid:
		return true
	capture_failed = true
	push_error("Forschungs-Capture verwendet nicht das responsive Kompaktraster oder verrät Gesamtwerte auf der Karte (Breite %.1f, Spalten %d/%d)" % [logical_width, screen.research_columns(), expected_columns])
	return false


func _verify_talent_tree(screen: ProgressionScreen) -> bool:
	var branch := screen.talent_branch(&"treatment")
	var upgrades := screen.talent_branch(&"upgrades")
	var active := screen.talent_branch(&"active")
	if branch == null or upgrades == null or active == null:
		capture_failed = true
		push_error("Talentansicht besitzt nicht alle drei produktiven Bäume")
		return false
	var ids: Array[StringName] = [
		&"treatment_damage_training",
		&"manual_treatment_aim",
		&"spread_shotgun",
		&"piercing_persistence",
		&"impulse_splash",
	]
	var symbols: Dictionary = {}
	var valid := branch.node_count() == 16 and branch.edge_count() == 15 \
		and upgrades.node_count() == 6 and upgrades.edge_count() == 5 \
		and active.node_count() == 4 and active.edge_count() == 3
	var root := screen.talent_action(ids[0])
	for id in ids:
		var action := screen.talent_action(id)
		valid = valid \
			and action != null \
			and action.custom_minimum_size.is_equal_approx(Vector2(68.0, 68.0)) \
			and action.theme_type_variation in [
				AlveolusVisualTheme.TYPE_TALENT_NODE,
				AlveolusVisualTheme.TYPE_SELECTED_TALENT_NODE,
			]
		if action != null:
			symbols[StringName(action.get_meta(&"talent_symbol_kind", &""))] = true
			if id != ids[0] and root != null:
				valid = valid and root.global_position.y < action.global_position.y
	valid = valid and symbols.size() == 5
	if valid:
		return true
	capture_failed = true
	push_error("Talent-Capture besitzt nicht drei Bäume, vier Behandlungsäste, eindeutige Symbole und alle sichtbaren Voraussetzungen")
	return false


func _verify_upgrade_capture(game: Node, options: Array[UpgradeDefinition]) -> bool:
	var cards: Array[Button] = game.hud.upgrade_screen.cards()
	var valid: bool = cards.size() == options.size()
	var diagnostics: Array[String] = []
	var stats := game.stats as PlayerStats
	for index in range(mini(cards.size(), options.size())):
		var card: Button = cards[index]
		var option: UpgradeDefinition = options[index]
		var preview: UpgradePreview = stats.preview_upgrade(option)
		var expected_icon: StringName = preview.presentation_icon_id
		if expected_icon == &"":
			expected_icon = option.resolved_icon_id(stats.prepared_treatment)
		var icon := card.find_child("UpgradeIcon", true, false) as SimpleIcon
		var heading := card.find_child("UpgradeTitle", true, false) as Label
		valid = valid \
			and icon != null \
			and icon.kind == expected_icon \
			and icon.custom_minimum_size.x >= 32.0 \
			and heading != null \
			and heading.text == option.resolved_component_name(stats.prepared_treatment, game.hud._upgrade_component_titles())
		var visible_copy := ""
		for node in _descendants(card):
			if node is RichTextLabel:
				visible_copy += (node as RichTextLabel).get_parsed_text() + " "
			elif node is Label:
				visible_copy += (node as Label).text + " "
		if option.id == &"rhythm":
			valid = valid \
				and visible_copy.contains("Attack Speed") \
				and visible_copy.contains("%") \
				and not visible_copy.contains("Intervall") \
				and not visible_copy.contains("/s")
		if option.id == &"neutrophils":
			valid = valid and visible_copy.contains("Radius 4")
		valid = valid \
			and not visible_copy.to_lower().contains(" px") \
			and not visible_copy.contains("Stufe")
		diagnostics.append("%s icon=%s/%s size=%.1f title=%s copy=%s" % [
			String(option.id),
			String(icon.kind) if icon != null else "<null>",
			String(expected_icon),
			icon.custom_minimum_size.x if icon != null else -1.0,
			heading.text if heading != null else "<null>",
			visible_copy,
		])
	if valid:
		return true
	capture_failed = true
	push_error("Ausbau-Capture übernimmt Icons, Komponentenname, Attack-Speed-Bonus oder Radius nicht datengetrieben: %s" % str(diagnostics))
	return false


func _verify_result_rewards(result: ResultOverlay) -> bool:
	var strip := result.find_child("RewardStrip", true, false) as GridContainer
	var research := result.find_child("Reward_research", true, false) as Control
	var research_value := research.find_child("Optional_reward_Body", true, false) as Label if research != null else null
	var expected_columns := 2 if result.size.x < ResultOverlay.COMPACT_WIDTH else 4
	var valid := strip != null \
		and strip.columns == expected_columns \
		and strip.get_child_count() == 4 \
		and research != null \
		and research.find_child("RewardIcon", true, false) is SimpleIcon \
		and research_value != null \
		and research_value.text == "+22" \
		and result.find_child("Reward_experience", true, false) == null
	for placeholder in ["+ irgendwas", "+ maybe nochwas", "+ idk"]:
		var found := false
		for label in result.find_children("*", "Label", true, false):
			if (label as Label).text == placeholder:
				found = true
				break
		valid = valid and found
	for label in result.find_children("*", "Label", true, false):
		valid = valid and (label as Label).text != "Belohnung"
	if valid:
		return true
	capture_failed = true
	push_error("Ergebnis-Capture besitzt nicht Forschung plus exakt drei angeforderte Placeholder im responsiven Raster")
	return false


func _verify_result_ability_section(result: ResultOverlay, expanded: bool) -> bool:
	var header := result.get_ability_section_header()
	var body := result.get_ability_section_body()
	var title := header.find_child("AbilitySectionTitle", true, false) as Label if header != null else null
	var damage_row := result.find_child("AbilityDamage_*", true, false)
	var talent_row := result.find_child("Talent_*", true, false)
	var valid := header != null \
		and body != null \
		and title != null \
		and title.text == "Fähigkeiten" \
		and result.is_ability_section_expanded() == expanded \
		and body.visible == expanded
	if expanded:
		valid = valid \
			and damage_row != null \
			and talent_row != null
	if valid:
		return true
	capture_failed = true
	push_error("Ergebnis-Capture besitzt nicht den klickbaren Fähigkeiten-Header mit konsistentem Disclosure-Zustand (erwartet=%s, state=%s, body=%s, titel=%s, damage=%s, talent=%s)" % [expanded, result.is_ability_section_expanded(), body.visible if body != null else false, title.text if title != null else "", damage_row != null, talent_row != null])
	return false


func _capture_preparation_editor_states(game: Node) -> void:
	# The current balance profile deliberately exposes exactly two active
	# abilities and equips both by default. Exercise direct replacement through
	# the treatment slot, where all three alternatives remain available.
	var edited_slot := LoadoutSlotId.TREATMENT
	game.hud._on_preparation_slot_pressed(edited_slot)
	await _capture("preparation_picker")
	var current_id: StringName = game.hud._preparation_component_at(edited_slot)
	var candidate_id: StringName = &""
	for id_value in game.hud.preparation_component_buttons:
		var id := StringName(id_value)
		var button := game.hud.preparation_component_buttons[id] as Button
		if id != current_id and not game.hud.current_preparation_selected_components.has(id) and button != null and button.is_visible_in_tree() and bool(button.get_meta(&"catalog_available", false)):
			candidate_id = id
			break
	if candidate_id == &"":
		capture_failed = true
		push_error("Kein Ersatzkandidat für die visuelle Einsatzplanungsprüfung")
		return
	game.hud._on_preparation_component(candidate_id, false)
	await _settle()
	if game.hud.planning_snapshot.mode != PlanningSnapshot.Mode.COMPONENT_PICK \
		or game.hud._preparation_component_at(edited_slot) != candidate_id \
		or game.hud.preparation_editor_confirm.visible:
		capture_failed = true
		push_error("Einsatzplanung ersetzte den expliziten Planplatz nicht direkt")
		return
	await _capture("preparation_applied")
	# The capture suite reuses one game. Restore the approved deterministic
	# treatment before the run so later Upgrade/Stats captures cannot combine a
	# renamed treatment with stale numeric values from the temporary candidate.
	game.hud._on_preparation_component(&"treatment_precision", false)
	await _settle()
	if game.hud._preparation_component_at(edited_slot) != &"treatment_precision":
		capture_failed = true
		push_error("Einsatzplanungs-Capture stellte den Präzisen Impuls nicht wieder her")
		return
	game.hud._cancel_preparation_editor()
	await _settle()

func _verify_direct_preparation_state(game: Node) -> bool:
	var hud := game.hud as GameHUD
	var treatment_button := hud.preparation_slot_buttons.get(LoadoutSlotId.TREATMENT) as Button
	var valid := hud.planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK \
		and hud.planning_snapshot.selected_slot_id == LoadoutSlotId.TREATMENT \
		and treatment_button != null \
		and bool(treatment_button.get_meta(&"selected_slot", false)) \
		and not hud.preparation_reserve_button.is_visible_in_tree()
	if valid:
		return true
	capture_failed = true
	push_error("Einsatzplanung öffnet nicht direkt mit sichtbar markierter Behandlungsauswahl")
	return false

func _verify_document_page(hud: GameHUD, overlay: Control, screen_id: String) -> bool:
	var page_parts := _document_page_parts(hud, overlay)
	var header := page_parts.get("header") as Control
	var body := page_parts.get("body") as Control
	if page_parts.is_empty() or header == null or body == null:
		capture_failed = true
		push_error("Dokumentseite %s besitzt keine semantische oder kompatibel registrierte PageShell" % screen_id)
		return false
	var header_rect := _canvas_rect(header)
	var body_rect := _canvas_rect(body)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(capture_size))
	var valid := header.is_visible_in_tree() \
		and viewport_rect.encloses(header_rect) \
		and header_rect.end.y <= body_rect.position.y + 0.5
	if valid:
		return true
	capture_failed = true
	push_error("Dokumentseite %s verliert oder überlagert ihren Header: header=%s body=%s viewport=%s" % [screen_id, header_rect, body_rect, viewport_rect])
	return false

func _document_page_parts(hud: GameHUD, overlay: Control) -> Dictionary:
	if hud == null or overlay == null:
		return {}
	var semantic_shell := _find_semantic_component(overlay, &"page_shell")
	if semantic_shell != null:
		var semantic_header := _find_semantic_component(semantic_shell, &"page_header")
		var semantic_body := _document_body_after_header(semantic_header)
		if semantic_header != null and semantic_body != null:
			return {
				"overlay": overlay,
				"shell": semantic_shell,
				"header": semantic_header,
				"body": semantic_body,
				"semantic": true,
			}
	for registered_shell in hud.page_shells:
		if registered_shell.get("overlay") == overlay:
			return registered_shell
	return {}

func _find_semantic_component(scope: Node, component_id: StringName) -> Control:
	if scope == null:
		return null
	var pending: Array[Node] = [scope]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is Control and current.get_meta(&"alveolus_component", &"") == component_id:
			return current as Control
		for child in current.get_children():
			pending.append(child)
	return null

func _document_body_after_header(header: Control) -> Control:
	if header == null or header.get_parent() == null:
		return null
	for sibling in header.get_parent().get_children():
		if sibling is Control and sibling != header:
			return sibling as Control
	return null

func _canvas_rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	return Rect2(
		transform.origin,
		Vector2(control.size.x * transform.x.length(), control.size.y * transform.y.length())
	)

func _capture_transient_dialogs(game: Node) -> void:
	game.hud.show_running_hud()
	var discoveries := ContentCatalog.discovery_definitions()
	game.hud.show_discovery(discoveries[&"pneumococcus"], game.hud.root.size * 0.5)
	await _capture("discovery")
	game.hud.hide_discovery()
	game.hud.show_pause(false, game.stats, game.state)
	game.hud.show_abort_confirmation()
	await _capture("abort_confirm")
	game.hud.show_pause(true, game.stats, game.state)
	game.hud.show_intro_skip_confirmation()
	await _capture("intro_skip_confirm")

func _settle() -> void:
	await _settle_frames(4)

func _settle_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _descendants(root_node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if root_node == null:
		return result
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		result.append(current)
		for child in current.get_children():
			pending.append(child)
	return result


func _row_populations(rows: Array[HBoxContainer]) -> Array[int]:
	var levels: Dictionary = {}
	var order: Array[int] = []
	for row in rows:
		var level := roundi(row.global_position.y)
		if not levels.has(level):
			levels[level] = 0
			order.append(level)
		levels[level] = int(levels[level]) + 1
	var result: Array[int] = []
	for level in order:
		result.append(int(levels[level]))
	return result


func _inside_capture_viewport(control: Control) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= -0.5 \
		and rect.position.y >= -0.5 \
		and rect.end.x <= float(capture_size.x) + 0.5 \
		and rect.end.y <= float(capture_size.y) + 0.5

func _capture(screen_id: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var filename := "%s_%s.png" % [screen_id, capture_suffix]
	if image.is_empty() or image.get_size() != capture_size:
		capture_failed = true
		push_error("Screenshot %s hat %s statt %s" % [filename, image.get_size(), capture_size])
		return
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, filename])
	if error != OK:
		capture_failed = true
		push_error("Screenshot konnte nicht gespeichert werden: %s" % filename)
		return
	capture_count += 1
	await process_frame
