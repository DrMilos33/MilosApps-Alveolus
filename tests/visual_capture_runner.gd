extends SceneTree

const OUTPUT_DIR := "res://.codex-temp/visual_restart/screens"
const EXPECTED_CAPTURE_COUNT := 26

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
	game._show_research()
	await _settle()
	_verify_document_page(game.hud, game.hud.research_overlay, "research")
	await _capture("research")
	game.hud._select_research_tab(&"talents")
	await _settle()
	_verify_document_page(game.hud, game.hud.research_overlay, "talents")
	await _capture("talents")
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
	if not game.hud.lexicon_master_detail.select_entry(&"pneumococcus"):
		capture_failed = true
		push_error("Bekannter Gegner konnte für die strukturierte Typwert-Capture nicht ausgewählt werden")
		return
	await _settle()
	if not _verify_lexicon_type_presentation(game.hud.lexicon_master_detail):
		return
	await _capture("lexicon_types")
	game.hud.show_settings(true, true)
	await _capture("settings")

	game.selected_level = game.levels[0]
	game._show_preparation()
	await _settle()
	if game.hud.preparation_workspace.visible or not game.hud.preparation_lock_panel.is_visible_in_tree():
		capture_failed = true
		push_error("Einführungsplan zeigt keine vollständige Sperrfläche")
		return
	await _capture("preparation_intro_locked")

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
	game.hud.show_upgrade_choices(ContentCatalog.upgrade_definitions().slice(0, 3), game.stats, true, false)
	await _settle()
	if not _verify_level_up_title(game.hud.upgrade_screen):
		return
	await _capture("upgrades")
	await _capture_transient_dialogs(game)
	game.hud.show_end(game.selected_level, true, "Der Herd ist kontrolliert.", 151.0, 5, 74, 22, true)
	await _capture("result")

func _populate_character_stats_capture(game: Node) -> void:
	# Keep the visual contract honest by capturing the densest supported sheet,
	# including all four stable accordion sections. Their disclosure state, not a
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
	push_error("Charakterwerte-Capture besitzt nicht die vier stabilen fokussierbaren Accordion-Sektionen")
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
	var findings := ContentCatalog.finding_definitions()
	var reactions := ContentCatalog.reaction_definitions()
	var finding_reactions: Array = [reactions[&"group_area"], reactions[&"group_control"], reactions[&"group_safety"]]
	game.hud.show_finding(findings[&"grouping"], finding_reactions)
	await _capture("finding")
	var registrations: Array[Dictionary] = game.hud.finding_screen.context_detail_registrations()
	if registrations.is_empty():
		capture_failed = true
		push_error("Befund besitzt keine Hover-Tooltipquelle für die visuelle Abnahme")
		return
	var tooltip_source := registrations[0].get("source") as Control
	var tooltip_anchor := registrations[0].get("anchor") as Control
	if tooltip_source == null or tooltip_anchor == null:
		capture_failed = true
		push_error("Befund-Tooltipquelle oder ihr kompakter Anker ist ungültig")
		return
	tooltip_source.mouse_entered.emit()
	await _settle()
	var tooltip_card := game.hud.context_detail_controller.card as Control
	var source_rect := tooltip_anchor.get_global_rect()
	var tooltip_rect := tooltip_card.get_global_rect()
	var above_source := tooltip_rect.end.y <= source_rect.position.y + 0.5
	var right_above := tooltip_rect.position.x >= source_rect.end.x - 0.5 and above_source
	var left_above := tooltip_rect.end.x <= source_rect.position.x + 0.5 and above_source
	var right_aligned_above := absf(tooltip_rect.end.x - source_rect.end.x) <= 1.0 and above_source
	var left_aligned_above := absf(tooltip_rect.position.x - source_rect.position.x) <= 1.0 and above_source
	var scaled_gap := ContextDetailController.SOURCE_GAP * capture_scale
	var scaled_margin := ContextDetailController.VIEWPORT_MARGIN * capture_scale
	var vertical_candidate_fits := source_rect.position.y - tooltip_rect.size.y - scaled_gap >= scaled_margin
	var right_candidate_fits := vertical_candidate_fits \
		and source_rect.end.x + scaled_gap + tooltip_rect.size.x <= float(capture_size.x) - scaled_margin
	var left_candidate_fits := vertical_candidate_fits \
		and source_rect.position.x - scaled_gap - tooltip_rect.size.x >= scaled_margin
	var right_aligned_candidate_fits := vertical_candidate_fits \
		and source_rect.end.x - tooltip_rect.size.x >= scaled_margin \
		and source_rect.end.x <= float(capture_size.x) - scaled_margin
	var left_aligned_candidate_fits := vertical_candidate_fits \
		and source_rect.position.x >= scaled_margin \
		and source_rect.position.x + tooltip_rect.size.x <= float(capture_size.x) - scaled_margin
	var valid_preferred_placement := right_above if right_candidate_fits else (
		left_above if left_candidate_fits else (
			right_aligned_above if right_aligned_candidate_fits else (
				left_aligned_above if left_aligned_candidate_fits else above_source
			)
		)
	)
	var title := game.hud.finding_screen.modal_sheet().find_child("FindingTitle", true, false) as Control
	var effect := game.hud.finding_screen.effect_label() as Control
	var covers_core_copy := (title != null and tooltip_rect.intersects(title.get_global_rect())) \
		or (effect != null and tooltip_rect.intersects(effect.get_global_rect()))
	if not tooltip_card.is_visible_in_tree() or not _inside_capture_viewport(tooltip_card) or not valid_preferred_placement or covers_core_copy:
		capture_failed = true
		push_error("Befund-Tooltip nutzt keine mögliche triggernahe Platzierung ohne Titel-/Effektüberdeckung (Anker %s, Karte %s)" % [source_rect, tooltip_rect])
		return
	await _capture("finding_tooltip")
	game.hud.close_all_context_details()
	game.hud.hide_finding()
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
