extends SceneTree

const OUTPUT_DIR := "res://.codex-temp/visual_restart/screens"
const EXPECTED_CAPTURE_COUNT := 21

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
	await _capture("lexicon")
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

	game.meta.research_ranks[&"unlock_defense_burst"] = 1
	game.selected_level = game.levels[1]
	game._show_preparation()
	if not _verify_direct_preparation_state(game):
		return
	await _capture("preparation")
	await _capture_preparation_editor_states(game)
	game.start_run(game.pending_run_context)
	await _settle_frames(45)
	game.hud.set_run_stats_visibility(true)
	await _capture("run")
	game.hud.show_pause(false, game.stats, game.state)
	await _capture("pause")
	_populate_character_stats_capture(game)
	game.hud._show_pause_stats()
	await _capture("pause_stats")
	game.hud.hide_pause()
	game.hud.show_upgrade_choices(ContentCatalog.upgrade_definitions().slice(0, 3), game.stats, true, false)
	await _capture("upgrades")
	await _capture_transient_dialogs(game)
	game.hud.show_end(game.selected_level, true, "Der Herd ist kontrolliert.", 151.0, 5, 74, 22, true)
	await _capture("result")

func _populate_character_stats_capture(game: Node) -> void:
	# Keep the visual contract honest by capturing the densest supported sheet,
	# including conditional treatment, defense, support and active-ability rows.
	game.stats.configure_prepared_treatment(TreatmentDefinition.catalog()[&"treatment_precision"])
	game.stats.therapy_projectiles = 3
	game.stats.therapy_max_hits = 4
	game.stats.immune_level = 3
	game.stats.support_level = 3
	game.stats.prepared_abilities.assign([
		AbilityDefinition.catalog()[&"ability_focus_field"],
		AbilityDefinition.catalog()[&"ability_emergency_support"],
	])

func _capture_preparation_editor_states(game: Node) -> void:
	game.hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_1)
	if game.hud.preparation_scroll != null:
		game.hud.preparation_scroll.scroll_vertical = 0 if game.hud.root.size.x < 820.0 else 220
	await _capture("preparation_picker")
	var current_id: StringName = game.hud._preparation_component_at(LoadoutSlotId.ACTIVE_1)
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
		or game.hud._preparation_component_at(LoadoutSlotId.ACTIVE_1) != candidate_id \
		or game.hud.preparation_editor_confirm.visible:
		capture_failed = true
		push_error("Einsatzplanung ersetzte den expliziten Planplatz nicht direkt")
		return
	await _capture("preparation_applied")
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
	for shell in hud.page_shells:
		if shell.get("overlay") != overlay:
			continue
		var header := shell.get("header") as HBoxContainer
		var body := shell.get("body") as VBoxContainer
		var header_transform := header.get_global_transform_with_canvas()
		var body_transform := body.get_global_transform_with_canvas()
		var header_rect := Rect2(
			header_transform.origin,
			Vector2(header.size.x * header_transform.x.length(), header.size.y * header_transform.y.length())
		)
		var body_rect := Rect2(
			body_transform.origin,
			Vector2(body.size.x * body_transform.x.length(), body.size.y * body_transform.y.length())
		)
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(capture_size))
		var valid := header.is_visible_in_tree() \
			and viewport_rect.encloses(header_rect) \
			and header_rect.end.y <= body_rect.position.y + 0.5
		if valid:
			return true
		capture_failed = true
		push_error("Dokumentseite %s verliert oder überlagert ihren Header: header=%s body=%s viewport=%s" % [screen_id, header_rect, body_rect, viewport_rect])
		return false
	capture_failed = true
	push_error("Dokumentseite %s besitzt keinen registrierten Page-Shell" % screen_id)
	return false

func _capture_transient_dialogs(game: Node) -> void:
	var findings := ContentCatalog.finding_definitions()
	var reactions := ContentCatalog.reaction_definitions()
	var modules := ContentCatalog.loadout_module_definitions()
	var finding_reactions: Array = [reactions[&"group_area"], reactions[&"group_control"], reactions[&"group_safety"]]
	var swappable_passives: Array = [modules[&"defense_readiness"], modules[&"quick_test"]]
	game.hud.show_finding(findings[&"grouping"], finding_reactions, modules[&"reserve_buffer"], swappable_passives)
	await _capture("finding")
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
