extends SceneTree

const OUTPUT_DIR := "res://.codex-temp/ui-accessibility"
const MIN_TEXT_SIZE := 14
const COMPACT_PLANNING_TEXT_SIZE := 12

var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var meta := MetaProgressionState.new()
	# Structured type values belong to discovered entries. Keep opening and
	# category changes selection-neutral, but unlock the explicit fixture entry.
	meta.mark_discovery_seen(&"pneumococcus")
	var jobs := ContentCatalog.clinic_job_definitions()
	var levels := ContentCatalog.level_definitions()
	var research := ContentCatalog.research_definitions()
	var loadout_modules := ContentCatalog.loadout_module_definitions()
	var findings := ContentCatalog.finding_definitions()
	var reactions := ContentCatalog.reaction_definitions()
	var discoveries := ContentCatalog.discovery_definitions()
	var upgrades := ContentCatalog.upgrade_definitions()
	var finding_reactions: Array = [reactions[&"group_area"], reactions[&"group_control"], reactions[&"group_safety"]]
	var swappable_passives: Array = []
	var prepared := PreparedLoadout.default_loadout()
	var prepared_with_active := PreparedLoadout.create(
		PreparedLoadout.DEFAULT_TREATMENT_ID,
		[&"ability_focus_field"]
	)
	var prep_view := {
		"level_title": "Die Ausbreitung",
		"level_description": "Eine zunehmende Belastung erfordert einen klaren Plan.",
		"duration_text": "Ohne Zeitlimit",
		"boss_time_text": "3:00 Min.",
		"trait": ContentCatalog.case_trait_definitions()[&"monster_spawn_10"],
		"validation": LoadoutValidator.validate(prepared, loadout_modules, {}, 8),
	}

	var hud := GameHUD.new()
	get_root().add_child(hud)
	await _settle()

	for setup in [
		{"size": Vector2i(1280, 720), "scale": 0.75, "suffix": "1280x720_075"},
		{"size": Vector2i(1280, 720), "scale": 0.90, "suffix": "1280x720_090"},
		{"size": Vector2i(1280, 720), "scale": 1.0, "suffix": "1280x720"},
		{"size": Vector2i(1280, 800), "scale": 1.0, "suffix": "1280x800"},
		{"size": Vector2i(1024, 576), "scale": 1.0, "suffix": "1024x576"},
		{"size": Vector2i(960, 540), "scale": 1.0, "suffix": "960x540"},
		{"size": Vector2i(1280, 720), "scale": 2.0, "suffix": "1280x720_200"},
		{"size": Vector2i(1280, 800), "scale": 2.0, "suffix": "1280x800_200"},
		{"size": Vector2i(1024, 576), "scale": 2.0, "suffix": "1024x576_200"},
		{"size": Vector2i(960, 540), "scale": 2.0, "suffix": "960x540_200"},
	]:
		var viewport_size: Vector2i = setup["size"]
		get_root().size = viewport_size
		var settings := UISettingsState.new()
		settings.ui_scale = float(setup["scale"])
		hud.configure_ui_settings(settings)
		await _settle()
		var canvas_size := Vector2i(get_root().get_visible_rect().size)
		var character_stats := _character_stats_fixture()
		var show_discovery_screen := func() -> void:
			hud._hide_all()
			hud.show_running_hud()
			hud.show_discovery(discoveries[&"pneumococcus"], hud.root.size * 0.5)
		var show_run_screen := func() -> void:
			var state := RunState.new()
			hud.update_run_stats(character_stats, state)
			hud.update_defeat_research_reward(18)
			hud.set_run_stats_visibility(true)
			hud.show_running_hud()
		var show_upgrade_screen := func() -> void:
			hud._hide_all()
			hud.show_running_hud()
			hud.show_upgrade_choices(upgrades.slice(0, 3), PlayerStats.new(), true, true)
		var show_pause_stats_screen := func() -> void:
			hud.show_pause(false, character_stats, RunState.new())
			hud._show_pause_stats()
		var show_abort_screen := func() -> void:
			hud.show_pause(false, PlayerStats.new(), RunState.new())
			hud.show_abort_confirmation()
		var show_intro_skip_screen := func() -> void:
			hud.show_pause(true, PlayerStats.new(), RunState.new())
			hud.show_intro_skip_confirmation()
		var show_restart_screen := func() -> void:
			hud.show_pause(false, PlayerStats.new(), RunState.new())
			hud.show_restart_confirmation()
		var show_talent_screen := func() -> void:
			hud.show_research_tabs(meta, research, TalentDefinition.definitions())
			hud._select_research_tab(&"talents")
		var show_preparation_picker := func() -> void:
			hud.show_preparation(prep_view, loadout_modules.values(), prepared_with_active)
			hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_1)
		var show_intro_preparation := func() -> void:
			var tutorial_view := prep_view.duplicate(true)
			tutorial_view["tutorial_locked"] = true
			tutorial_view["can_skip_intro"] = true
			hud.show_preparation(tutorial_view, loadout_modules.values(), prepared)

		var screens: Array[Dictionary] = [
			{"id": "campus", "overlay": hud.campus_overlay, "show": func() -> void: hud.show_campus(meta, jobs)},
			{"id": "story", "overlay": hud.story_overlay, "show": func() -> void: hud.show_story()},
			{"id": "practice", "overlay": hud.practice_overlay, "show": func() -> void: hud.show_practice(meta, jobs)},
			{"id": "research", "overlay": hud.research_overlay, "show": func() -> void: hud.show_research_tabs(meta, research, TalentDefinition.definitions())},
			{"id": "talents", "overlay": hud.research_overlay, "show": show_talent_screen},
			{"id": "levels", "overlay": hud.level_overlay, "show": func() -> void: hud.show_level_select(meta, levels)},
			{"id": "preparation", "overlay": hud.preparation_overlay, "show": func() -> void: hud.show_preparation(prep_view, loadout_modules.values(), prepared)},
			{"id": "preparation_picker", "overlay": hud.preparation_overlay, "show": show_preparation_picker},
			{"id": "preparation_intro_locked", "overlay": hud.preparation_overlay, "show": show_intro_preparation},
			{"id": "lexicon", "overlay": hud.lexicon_overlay, "show": func() -> void: hud.show_lexicon(meta)},
			{"id": "settings", "overlay": hud.settings_overlay, "show": func() -> void: hud.show_settings(false, true)},
			{"id": "finding", "overlay": hud.finding_overlay, "show": func() -> void: hud.show_finding(findings[&"grouping"], finding_reactions, null, swappable_passives)},
			{"id": "discovery", "overlay": hud.discovery_tooltip, "show": show_discovery_screen},
			{"id": "run", "overlay": hud.gameplay_hud, "show": show_run_screen},
			{"id": "upgrade", "overlay": hud.upgrade_overlay, "show": show_upgrade_screen},
			{"id": "pause", "overlay": hud.pause_overlay, "show": func() -> void: hud.show_pause(false, character_stats, RunState.new())},
			{"id": "pause_stats", "overlay": hud.pause_overlay, "show": show_pause_stats_screen},
			{"id": "abort", "overlay": hud.abort_overlay, "show": show_abort_screen},
			{"id": "intro_skip", "overlay": hud.intro_skip_overlay, "show": show_intro_skip_screen},
			{"id": "restart", "overlay": hud.restart_overlay, "show": show_restart_screen},
			{"id": "result", "overlay": hud.end_overlay, "show": func() -> void: hud.show_end(levels[1], true, "Der Herd ist kontrolliert.", 151.0, 5, 74, 22, true)},
		]
		for screen in screens:
			(screen["show"] as Callable).call()
			await _settle()
			var overlay := screen["overlay"] as Control
			var context := "%s bei %s und %d %%" % [screen["id"], viewport_size, roundi(float(setup["scale"]) * 100.0)]
			if screen["id"] == "lexicon":
				var lexicon := hud.lexicon_master_detail
				_check(lexicon.selected_entry_id == &"", "%s markiert beim Öffnen keinen Eintrag automatisch" % context)
				lexicon.select_category(LexiconEntryDefinition.CATEGORY_TERMS)
				await _settle()
				_check(lexicon.selected_entry_id == &"", "%s markiert beim Kategorienwechsel keinen Begriff automatisch" % context)
				_check(lexicon.context_detail_sources().is_empty(), "%s registriert für Begriffe keine redundante Detailkarte" % context)
				for term_button_value in lexicon.entry_buttons.values():
					var term_button := term_button_value as Button
					if term_button != null and term_button.is_visible_in_tree():
						_check(term_button.tooltip_text.is_empty(), "%s zeigt Begriffe ohne Maus-Tooltip" % context)
				lexicon.select_category(LexiconEntryDefinition.CATEGORY_MONSTERS)
				_check(lexicon.select_entry(&"pneumococcus"), "%s kann einen bekannten Gegner ausdrücklich für die Typwerte auswählen" % context)
				await _settle()
			_check(overlay.visible, "%s ist sichtbar" % context)
			_check(_inside_viewport(overlay, canvas_size), "%s füllt den Viewport ohne Überlauf" % context)
			if screen["id"] in ["practice", "research", "talents", "levels", "preparation", "preparation_picker", "preparation_intro_locked", "lexicon", "settings"]:
				var page_parts := _document_page_parts(hud, overlay)
				var document_header := page_parts.get("header") as Control
				_check(not page_parts.is_empty(), "%s besitzt eine semantische oder kompatibel registrierte PageShell" % context)
				_check(document_header != null and document_header.is_visible_in_tree() and _inside_viewport(document_header, canvas_size), "%s hält seinen Dokumentheader sichtbar im Viewport" % context)
			var minimum_text_size := COMPACT_PLANNING_TEXT_SIZE \
				if screen["id"] in ["preparation", "preparation_picker", "preparation_intro_locked"] \
				else MIN_TEXT_SIZE
			_check_minimum_text(overlay, context, minimum_text_size)
			_check_actions_reachable(overlay, canvas_size, context)
			if screen["id"] == "story":
				hud._configure_focus_cycle(overlay)
				hud.story_next_button.grab_focus()
			else:
				hud._focus_first_button(overlay)
			await process_frame
			if screen["id"] != "run":
				_check(_focus_owner_inside(overlay), "%s hält den Anfangsfokus im obersten Layer" % context)
				_check(_focus_cycle_inside(overlay), "%s hält Tab und Richtungsnavigation im obersten Layer" % context)
				var focused := get_root().gui_get_focus_owner() as Control
				_check(focused == null or focused.scale.is_equal_approx(Vector2.ONE), "%s zeichnet Fokus ohne geometrischen Überlauf" % context)
			if screen["id"] == "story":
				_check(get_root().gui_get_focus_owner() == hud.story_next_button, "%s fokussiert beim Gamepad-Smoke die primäre Fortsetzen-Aktion statt Überspringen" % context)
			if screen["id"] in ["research", "talents"]:
				var progression_sources: Array = hud.research_buy_buttons.values() if screen["id"] == "research" else hud.talent_buttons.values()
				var progression_source := _first_focusable_control(progression_sources)
				_check(progression_source != null, "%s besitzt mindestens eine fokussierbare Informationsquelle" % context)
				if progression_source != null:
					hud.close_all_context_details()
					progression_source.grab_focus()
					await _settle()
					var hover_provider := hud.progression_screen.tooltip_provider_for(progression_source)
					var info_provider := hud.progression_screen.ui_info_provider_for(progression_source)
					var info_payload := hud.progression_screen.info_payload_for(progression_source)
					_check(not hud.is_context_detail_open(), "%s öffnet Detailinformationen nicht allein durch Fokus" % context)
					_check(hover_provider.is_valid() and info_provider.is_valid() and hover_provider == info_provider, "%s verwendet für Hover und ui_info dieselbe Informationsquelle" % context)
					_check(not String(info_payload.get("title", "")).is_empty() and not String(info_payload.get("body", "")).is_empty(), "%s liefert eine kompakte, vollständige Detailkarte" % context)
					_check(hud.toggle_focused_context_detail(progression_source), "%s lässt sich ausdrücklich über ui_info öffnen" % context)
					await _settle()
					_check(hud.is_context_detail_open() and hud.is_context_detail_explicit(), "%s kennzeichnet die ui_info-Karte als ausdrückliche Detailansicht" % context)
					hud.close_context_detail()
					await _settle()
			if screen["id"] == "talents" and (hud.root.size.x < 620.0 or hud.root.size.y < 420.0):
				if hud.talent_grid.columns == 1:
					var branch_panels := hud.talent_grid.get_children()
					for branch_index in range(1, branch_panels.size()):
						_check(_rects_separate(branch_panels[branch_index - 1] as Control, branch_panels[branch_index] as Control), "%s stapelt Talentäste ohne Übermalung" % context)
			if screen["id"] in ["preparation", "preparation_picker"]:
				_check(
					_controls_inside(hud.preparation_workspace_host, [hud.preparation_workspace]),
					"%s hält den vollständigen Planungsarbeitsbereich in seinem festen Host" % context
				)
				_check(
					_controls_inside(hud.preparation_workspace, [hud.preparation_plan_panel, hud.preparation_catalog_panel]),
					"%s hält Plan und Editor ohne Übermalung im gemeinsamen Arbeitsbereich" % context
				)
				if hud.preparation_workspace.columns == 2:
					_check(
						hud.preparation_catalog_panel.size.x > hud.preparation_plan_panel.size.x + 0.5,
						"%s gibt dem Komponenten-Editor auf dem Desktop mehr Breite als dem Plan" % context
					)
				_check(
					_controls_inside(hud.preparation_plan_panel, hud.preparation_slot_buttons.values()),
					"%s enthält alle fünf Planplätze vollständig in der Plankarte" % context
				)
				for slot_value in hud.preparation_slot_buttons.values():
					var slot := slot_value as Button
					_check(
						slot != null and slot.get_child_count() > 0 and _visible_descendants_inside(slot),
						"%s hält Icon, Texte, Kosten und Zustandsmarker vollständig im Planplatz %s" % [context, slot.name if slot != null else "<fehlt>"]
					)
				_check(
					_controls_inside(hud.preparation_catalog_panel, [hud.preparation_catalog_scroll]),
					"%s hält den Katalogviewport vollständig in der Editorkarte" % context
				)
				if hud.preparation_inspector.visible:
					_check(
						_controls_inside(hud.preparation_overlay, [hud.preparation_inspector]) \
							and _rects_separate(hud.preparation_inspector, hud.preparation_catalog_scroll),
						"%s hält den sichtbaren ComponentTooltip vollständig im Screen und außerhalb des Kandidatenrasters" % context
					)
				_check(
					_controls_inside(hud.preparation_catalog, hud.preparation_component_buttons.values()),
					"%s ordnet alle Kandidaten vollständig im Katalograster an" % context
				)
				_check(
					_controls_horizontally_inside(hud.preparation_catalog_panel, hud.preparation_component_buttons.values()),
					"%s lässt keine Kandidaten seitlich aus der Editorkarte ragen" % context
				)
				for candidate_value in hud.preparation_component_buttons.values():
					var candidate := candidate_value as Button
					_check(
						candidate != null and candidate.get_child_count() > 0 and _visible_descendants_inside(candidate),
						"%s hält Icon, Texte und Kosten vollständig im Kandidaten %s" % [context, candidate.name if candidate != null else "<fehlt>"]
					)
				if hud.preparation_inspector.visible:
					_check(_visible_descendants_inside(hud.preparation_inspector), "%s hält sämtliche Tooltipinhalte innerhalb der Membranfläche" % context)
				_check(not hud.preparation_reserve_button.is_visible_in_tree(), "%s hält die vorerst entfernte Reserve aus dem sichtbaren Plan" % context)
			if screen["id"] == "preparation":
				_check(
					hud.planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK and hud.planning_snapshot.selected_slot_id == LoadoutSlotId.TREATMENT,
					"%s öffnet direkt die Auswahl für Behandlung ohne Zwischenscreen" % context
				)
				_check(bool((hud.preparation_slot_buttons[LoadoutSlotId.TREATMENT] as Button).get_meta(&"selected_slot", false)), "%s markiert den automatisch gewählten Behandlungsplatz sichtbar" % context)
				var selected_slot_focus := hud.preparation_slot_buttons[LoadoutSlotId.TREATMENT] as Control
				selected_slot_focus.grab_focus()
				await _settle()
				_check(get_root().gui_get_focus_owner() == selected_slot_focus, "%s übernimmt den Fokus auf den ausgewählten Behandlungsplatz" % context)
				_check(
					_control_fully_visible_within_clips(selected_slot_focus, canvas_size),
					"%s hält den Planplatzfokus bei 100/200 %% vollständig im Viewport und in allen Scrollflächen" % context
				)
			if screen["id"] == "preparation_picker":
				_check(hud.planning_snapshot.selected_slot_id == LoadoutSlotId.ACTIVE_1 and bool((hud.preparation_slot_buttons[LoadoutSlotId.ACTIVE_1] as Button).get_meta(&"selected_slot", false)), "%s markiert den explizit gewählten Aktivplatz sichtbar" % context)
				_check(hud.preparation_catalog.columns == 2, "%s bewahrt das dichte Zweispaltenraster bis 960x540 bei 200 %%" % context)
				var visible_remove_actions := _visible_controls_named(hud.preparation_overlay, &"RemoveSelectedSlot")
				_check(visible_remove_actions.size() == 1, "%s zeigt genau eine Entfernen-Aktion" % context)
				if visible_remove_actions.size() == 1:
					var remove_action := visible_remove_actions[0]
					_check(
						remove_action.get_parent() != null \
							and remove_action.get_parent().name == &"EditorHeaderAction" \
							and hud.preparation_catalog_panel.is_ancestor_of(remove_action) \
							and _controls_inside(hud.preparation_catalog_panel, [remove_action]),
						"%s hält die kompakte Entfernen-Aktion im stabilen Editorheader" % context
					)
					_check(
						_control_fully_visible_within_clips(remove_action, canvas_size) or _has_scroll_ancestor(remove_action),
						"%s hält die Entfernen-Aktion sichtbar oder über die gemeinsame Seitenfläche erreichbar" % context
					)
					_check(
						not hud.preparation_inspector.is_ancestor_of(remove_action),
						"%s hält die Entfernen-Aktion außerhalb des schwebenden ComponentTooltips" % context
					)
				var candidate_focus := _first_focusable_control(hud.preparation_component_buttons.values())
				_check(candidate_focus != null, "%s bietet mindestens einen fokussierbaren Kandidaten im Komponenten-Editor" % context)
				if candidate_focus != null:
					# Use parent-local rectangles here: focus-following scroll is expected to
					# change global positions, but opening the floating tooltip must not reflow
					# either the editor or its catalog viewport.
					var editor_rect_before := Rect2(hud.preparation_catalog_panel.position, hud.preparation_catalog_panel.size)
					var catalog_viewport_rect_before := Rect2(hud.preparation_catalog_scroll.position, hud.preparation_catalog_scroll.size)
					var catalog_size_before := hud.preparation_catalog.size
					var candidate_size_before := candidate_focus.size
					candidate_focus.grab_focus()
					await _settle()
					_check(get_root().gui_get_focus_owner() == candidate_focus, "%s übernimmt den Fokus auf den ersten bedienbaren Kandidaten" % context)
					_check(
						_control_fully_visible_within_clips(candidate_focus, canvas_size),
						"%s hält den Kandidatenfokus bei 100/200 %% vollständig im Viewport und in allen Scrollflächen" % context
					)
					_check(
						hud.preparation_inspector.name == &"ComponentTooltip" \
							and not hud.preparation_inspector.is_visible_in_tree(),
						"%s öffnet den Maus-Tooltip nicht allein durch Tastatur- oder Gamepadfokus" % context
					)
					_check(
						_rect_approximately_equal(editor_rect_before, Rect2(hud.preparation_catalog_panel.position, hud.preparation_catalog_panel.size)) \
							and _rect_approximately_equal(catalog_viewport_rect_before, Rect2(hud.preparation_catalog_scroll.position, hud.preparation_catalog_scroll.size)) \
							and catalog_size_before.is_equal_approx(hud.preparation_catalog.size) \
							and candidate_size_before.is_equal_approx(candidate_focus.size),
						"%s verändert den Editor und das Kandidatenraster beim Fokus nicht" % context
					)
					candidate_focus.mouse_entered.emit()
					await _settle()
					var tooltip_rect := hud.preparation_inspector.get_global_rect()
					var candidate_rect := candidate_focus.get_global_rect()
					var tooltip_gap_tolerance := 8.0 * float(setup["scale"])
					var adjacent_horizontally := absf(tooltip_rect.position.x - candidate_rect.end.x) <= tooltip_gap_tolerance \
						or absf(candidate_rect.position.x - tooltip_rect.end.x) <= tooltip_gap_tolerance
					var adjacent_vertically := absf(tooltip_rect.position.y - candidate_rect.end.y) <= tooltip_gap_tolerance \
						or absf(candidate_rect.position.y - tooltip_rect.end.y) <= tooltip_gap_tolerance
					_check(
						hud.preparation_inspector.is_visible_in_tree() \
							and hud.preparation_inspector.mouse_filter == Control.MOUSE_FILTER_IGNORE \
							and _controls_inside(hud.preparation_overlay, [hud.preparation_inspector]) \
							and _rects_separate(hud.preparation_inspector, candidate_focus) \
							and (adjacent_horizontally or adjacent_vertically) \
							and _visible_descendants_inside(hud.preparation_inspector) \
							and _rect_approximately_equal(editor_rect_before, Rect2(hud.preparation_catalog_panel.position, hud.preparation_catalog_panel.size)) \
							and _rect_approximately_equal(catalog_viewport_rect_before, Rect2(hud.preparation_catalog_scroll.position, hud.preparation_catalog_scroll.size)) \
							and catalog_size_before.is_equal_approx(hud.preparation_catalog.size) \
							and candidate_size_before.is_equal_approx(candidate_focus.size),
						"%s zeigt den Hover-Tooltip ohne Layoutverschiebung" % context
					)
					if visible_remove_actions.size() == 1:
						_check(
							_rects_separate(hud.preparation_inspector, visible_remove_actions[0]),
							"%s hält ComponentTooltip und Entfernen-Aktion räumlich getrennt" % context
						)
			if screen["id"] == "preparation_intro_locked":
				_check(not hud.preparation_workspace.visible, "%s verbirgt den scheinbar editierbaren Plan vollständig" % context)
				_check(hud.preparation_lock_panel.is_visible_in_tree() and _controls_inside(hud.preparation_workspace_host, [hud.preparation_lock_panel]), "%s zeigt eine vollständig enthaltene Padlock-Fläche" % context)
				_check(hud.preparation_start_button.is_visible_in_tree() and _inside_viewport(hud.preparation_start_button, canvas_size) and not hud.preparation_start_button.disabled and not hud.preparation_remove_button.visible, "%s lässt nur den sichtbaren vorbereiteten Start statt Planmutationen zu" % context)
			if screen["id"] == "settings":
				_check(
					hud.settings_master_slider.is_visible_in_tree() and hud.settings_master_slider.get_global_rect().intersects(Rect2(Vector2.ZERO, Vector2(canvas_size))),
					"%s zeigt die Audio- und Anzeigeoptionen bereits am oberen Scrollanfang" % context
				)
				for settings_control in [hud.settings_master_slider, hud.settings_restart_confirmation_toggle, hud.settings_status_label]:
					_check(_inside_nearest_panel_container(settings_control, hud.settings_overlay), "%s hält %s vollständig in seiner Einstellungs-Karte" % [context, settings_control.name])
			if screen["id"] == "lexicon":
				var lexicon := hud.lexicon_master_detail
				var expected_stat_columns := 1 if hud.root.size.x < 820.0 else 2
				_check(lexicon.detail_stats_grid.columns == expected_stat_columns, "%s zeigt Basiswerte in %d Gridspalten" % [context, expected_stat_columns])
				_check(lexicon.detail_gameplay_panel != null and lexicon.detail_medical_panel != null, "%s trennt Spielwirkung und medizinischen Hintergrund semantisch" % context)
				var type_chips := _semantic_controls(lexicon.detail_type_sections, &"damage_type_chip")
				_check(type_chips.size() == 8, "%s zeigt vier Schadenstypen und vier effektive Resistenzen als strukturierte Chips" % context)
				for chip in type_chips:
					_check(
						DamageTypeCatalog.ALL_IDS.has(StringName(String(chip.get_meta(&"damage_type_id", &""))))
							and chip.find_child("DamageTypeIcon", true, false) is SimpleIcon
							and chip.find_child("DamageTypeName", true, false) is Label
							and chip.find_child("DamageTypeValue", true, false) is Label,
						"%s bindet jeden Typchip an Icon, Name und fertigen Wert" % context
					)
				_check(not _visible_copy_contains_internal_distance_unit(lexicon.detail_content), "%s zeigt keine Pixel- oder Weltmaße im Lexikon" % context)
				var detail_bar := lexicon.detail_scroll.get_v_scroll_bar()
				if detail_bar.visible:
					for stat_child in lexicon.detail_stats_grid.get_children():
						var stat_panel := stat_child as Control
						_check(stat_panel != null and stat_panel.get_global_rect().end.x <= detail_bar.get_global_rect().position.x - 4.0, "%s hält Statistikwerte vor der Scrollbar" % context)
			if screen["id"] == "finding":
				_check(_inside_viewport(hud.finding_panel, canvas_size), "%s hält das Befundfenster vollständig im Viewport" % context)
			if screen["id"] == "upgrade":
				_check(_inside_viewport(hud.upgrade_panel, canvas_size), "%s hält den Ausbau-Dialog vollständig im Viewport" % context)
				_check(_has_scroll_ancestor(hud.upgrade_cards), "%s hält alle Ausbauoptionen scrollbar erreichbar" % context)
				var level_up_title := hud.upgrade_screen.find_child("LevelUpTitle", true, false) as Label
				_check(
					level_up_title != null
						and level_up_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
						and absf(level_up_title.get_global_rect().get_center().x - hud.upgrade_panel.get_global_rect().get_center().x) <= 1.0,
					"%s zentriert Level Up! lokal und geometrisch im Ausbau-Dialog" % context
				)
			if screen["id"] == "story":
				_check(_inside_viewport(hud.story_panel, canvas_size), "%s hält die Prologkarte vollständig im Viewport (Karte %s, Canvas %s)" % [context, hud.story_panel.get_global_rect(), canvas_size])
				var story_scroll := hud.story_screen.focus_scroll()
				_check(story_scroll != null and story_scroll.follow_focus and story_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s verwendet den responsiven StoryScroll ohne horizontalen Überlauf" % context)
				_check(story_scroll.is_ancestor_of(hud.story_next_button) and _control_fully_visible_within_clips(hud.story_next_button, canvas_size), "%s hält die fokussierte Fortsetzen-Aktion im StoryScroll sichtbar (Aktion %s, Scroll %s)" % [context, hud.story_next_button.get_global_rect(), story_scroll.get_global_rect()])
			if screen["id"] == "run":
				var run_hud := hud.run_hud_screen
				var semantic_stat_strip := run_hud.run_stats_strip()
				_check(semantic_stat_strip == hud.run_stats_strip and semantic_stat_strip.get_meta(&"alveolus_component", &"") == &"transparent_run_stats", "%s ordnet Runwerte als transparentes horizontales Statband des RunHUDOverlay an" % context)
				_check(run_hud.stat_rows().size() == 8 and _hud_row_populations(run_hud.stat_rows()) == [4, 4], "%s zeigt ausschließlich acht Grundwerte in zwei Viererreihen" % context)
				for stat_row in run_hud.stat_rows():
					_check(RunHUDViewModel.BASIC_STAT_IDS.has(stat_row.get_meta(&"stat_id", &"")), "%s enthält keine Behandlungs- oder Fähigkeitswerte im Kampfstreifen" % context)
				var reward_panel := run_hud.defeat_research_reward_panel()
				var reward_rect := reward_panel.get_global_rect()
				var timer_rect := run_hud.timer_panel().get_global_rect()
				_check(
					reward_panel.is_visible_in_tree()
						and run_hud.defeat_research_reward_icon().kind == &"research"
						and run_hud.defeat_research_reward_value_label().text == "+18"
						and not String(reward_panel.get_meta(&"alveolus_accessible_name", "")).is_empty()
						and reward_rect.end.x <= timer_rect.position.x + 0.5,
					"%s zeigt den zugänglich benannten Forschungsgewinn als Symbol und Zahl links vom Timer" % context
				)
			if screen["id"] == "pause":
				_check(not _contains_text(hud.pause_overlay, "RUNMENÜ"), "%s enthält keinen überflüssigen Runmenü-Obertitel" % context)
				_check(hud.pause_screen.current_mode() == PauseOverlay.Mode.MENU and not hud.pause_screen.body_scroll().is_ancestor_of(hud.pause_resume_button), "%s hält Weiter fest außerhalb des responsiven Inhaltsviewports" % context)
			if screen["id"] == "pause_stats":
				var pause_screen := hud.pause_screen
				_check(pause_screen.current_mode() == PauseOverlay.Mode.STATS and not pause_screen.body_scroll().is_ancestor_of(hud.pause_stats_back_button), "%s zeigt Charakterwerte im gemeinsamen PauseOverlay mit festem Rückweg" % context)
				_check(
					pause_screen.stat_sections().size() == 3
						and pause_screen.section_header(&"general") != null
						and pause_screen.section_header(&"treatment:treatment_precision") != null
						and pause_screen.section_header(&"ability:0:ability_focus_field") != null
						and pause_screen.section_header(&"ability:1:ability_treatment_line") == null,
					"%s zeigt nur Grundwerte, Behandlung und den belegten Aktivslot ohne leere Aktivsektion" % context
				)
				for section_id in [&"general", &"treatment:treatment_precision", &"ability:0:ability_focus_field"]:
					var section_header := pause_screen.section_header(section_id)
					_check(
						section_header != null
							and section_header.focus_mode == Control.FOCUS_ALL
							and not String(section_header.get_meta(&"alveolus_accessible_name", "")).is_empty(),
						"%s besitzt für %s einen fokussierbaren und zugänglich benannten Accordion-Kopf" % [context, section_id]
					)
				_check(pause_screen.is_section_expanded(&"general") and pause_screen.section_body(&"general").is_visible_in_tree(), "%s öffnet Grundwerte standardmäßig" % context)
				_check(not pause_screen.is_section_expanded(&"treatment:treatment_precision") and not pause_screen.section_body(&"treatment:treatment_precision").visible, "%s reserviert für die geschlossene Behandlung keinen Body-Leerraum" % context)
			if screen["id"] == "finding" and viewport_size == Vector2i(1280, 720):
				await _check_finding_tooltip_placement(hud, canvas_size, context)
			if screen["id"] == "abort":
				_check(_inside_viewport(hud.abort_panel, canvas_size), "%s hält die Abbruchbestätigung vollständig im Viewport" % context)
			if screen["id"] == "intro_skip":
				_check(_inside_viewport(hud.intro_skip_panel, canvas_size), "%s hält die Introbestätigung vollständig im Viewport" % context)
			if screen["id"] == "restart":
				_check(_inside_viewport(hud.restart_panel, canvas_size), "%s hält die Neustartbestätigung vollständig im Viewport" % context)
			if screen["id"] == "discovery":
				_check(_inside_viewport(hud.discovery_tooltip.panel, canvas_size), "%s hält Tooltip und Pfeilziel im Viewport" % context)
			await _capture("%s_%s.png" % [screen["id"], setup["suffix"]], viewport_size)
		if viewport_size == Vector2i(1280, 720) and is_equal_approx(float(setup["scale"]), 2.0):
			var tutorial_prep_view := prep_view.duplicate(true)
			tutorial_prep_view["tutorial_locked"] = true
			hud.show_preparation(tutorial_prep_view, loadout_modules.values(), prepared)
			await _settle()
			_check(_inside_viewport(hud.preparation_intro_skip_button, canvas_size), "Einsatzplanung hält Einführung überspringen bei 1280×720 und 200 % vollständig im Viewport")
			_check(hud.preparation_intro_skip_button.theme_type_variation == AlveolusVisualTheme.TYPE_SECONDARY_BUTTON, "Einführung überspringen verwendet bei 200 % die semantische Sekundäraktion")
			for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
				var effective_style := hud.preparation_intro_skip_button.get_theme_stylebox(state)
				_check(
					_has_minimum_content_insets(effective_style, 18.0, 10.0),
					"Einführung überspringen bewahrt im effektiven Zustand %s mindestens 18 px horizontalen und 10 px vertikalen Innenrand" % state
				)
			var skip_normal_style := hud.preparation_intro_skip_button.get_theme_stylebox(&"normal")
			var skip_font := hud.preparation_intro_skip_button.get_theme_font(&"font")
			var skip_font_size := hud.preparation_intro_skip_button.get_theme_font_size(&"font_size")
			var skip_text_width := skip_font.get_string_size(
				hud.preparation_intro_skip_button.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				skip_font_size
			).x
			var skip_required_width := skip_text_width \
				+ skip_normal_style.get_content_margin(SIDE_LEFT) \
				+ skip_normal_style.get_content_margin(SIDE_RIGHT)
			_check(hud.preparation_intro_skip_button.size.x + 0.5 >= skip_required_width, "Einführung überspringen reserviert bei 200 % den Text plus beide Content-Inset-Seiten")
			_check(_inside_viewport(hud.preparation_header_back_button, canvas_size), "Einsatzplanung hält Zur Fallauswahl bei 1280×720 und 200 % vollständig im Viewport")
			var preparation_action_host := hud.preparation_intro_skip_button.get_parent().get_parent() as Control
			_check(not (preparation_action_host is HBoxContainer), "Ein überfüllter Einsatzplanungsheader stapelt seine beiden Aktionen bei 1280×720 und 200 %")

	# 960×540 at 200 percent resolves to a 480×270 logical document host.
	# Exercise that host directly as a regression contract for every header that
	# shares the planning page anatomy.
	get_root().size = Vector2i(480, 270)
	var compact_document_settings := UISettingsState.new()
	compact_document_settings.ui_scale = 1.0
	hud.configure_ui_settings(compact_document_settings)
	await _settle()
	for compact_document in [
		{"id": "Praxis", "overlay": hud.practice_overlay, "show": func() -> void: hud.show_practice(meta, jobs)},
		{"id": "Forschung", "overlay": hud.research_overlay, "show": func() -> void: hud.show_research_tabs(meta, research, TalentDefinition.definitions())},
		{"id": "Einstellungen", "overlay": hud.settings_overlay, "show": func() -> void: hud.show_settings(false, true)},
		{"id": "Fallarchiv", "overlay": hud.level_overlay, "show": func() -> void: hud.show_level_select(meta, levels)},
	]:
		(compact_document["show"] as Callable).call()
		await _settle()
		var compact_overlay := compact_document["overlay"] as Control
		var compact_parts := _document_page_parts(hud, compact_overlay)
		_check_compact_page_header(compact_parts, compact_overlay, String(compact_document["id"]))

	get_root().size = Vector2i(1280, 720)
	var baseline_settings := UISettingsState.new()
	baseline_settings.ui_scale = 1.0
	hud.configure_ui_settings(baseline_settings)
	await _settle()
	hud.show_pause(false, PlayerStats.new(), RunState.new())
	await _settle()
	var normal_pause_height := hud.pause_panel.size.y
	_check(_is_content_driven_modal(hud.pause_panel), "Pause folgt ihrer tatsächlichen Inhaltshöhe ohne dekorative Leerraumreserve")
	hud.show_pause(true, PlayerStats.new(), RunState.new())
	await _settle()
	_check(hud.pause_skip_button.is_visible_in_tree() and hud.pause_panel.size.y >= normal_pause_height - 0.5 and _is_content_driven_modal(hud.pause_panel), "Intro-Pause wächst nur mit ihrer sichtbaren Zusatzaktion und bleibt inhaltsgetrieben")
	for document_overlay in [hud.practice_overlay, hud.research_overlay, hud.level_overlay, hud.preparation_overlay, hud.lexicon_overlay, hud.settings_overlay]:
		var page_parts := _document_page_parts(hud, document_overlay as Control)
		var header := page_parts.get("header") as Control
		var title_labels := _document_title_labels(header)
		_check(not page_parts.is_empty() and title_labels.size() == 1 and not _document_header_has_eyebrow(header), "Jeder Dokumentheader besitzt genau einen Titel und keinen Obertitel")
	_check(_has_scroll_ancestor(hud.preparation_catalog), "Komponentenkatalog bleibt bei großer UI scrollbar")
	_check(_has_descendant_type(hud.practice_overlay, "ScrollContainer"), "Praxis bleibt bei großer UI scrollbar")

	# Stable section IDs must retain disclosure state, focus and node identity
	# across a content refresh. An unoccupied second active slot must never leave
	# a dormant accordion panel or a blank-space reserve behind.
	var refreshed_stats := _character_stats_fixture()
	hud.show_pause(false, refreshed_stats, RunState.new())
	hud._show_pause_stats()
	await _settle()
	var treatment_section_id := &"treatment:treatment_precision"
	var treatment_header := hud.pause_screen.section_header(treatment_section_id)
	var treatment_header_instance := treatment_header.get_instance_id() if treatment_header != null else 0
	_check(hud.pause_screen.set_section_expanded(treatment_section_id, true), "Charakterwerte lassen die Behandlung ausdrücklich ausklappen")
	_check(hud.pause_screen.set_section_expanded(&"general", false), "Charakterwerte lassen Grundwerte unabhängig einklappen")
	if treatment_header != null:
		treatment_header.grab_focus()
	refreshed_stats.defense = 7.0
	hud.pause_view_revision += 1
	hud.pause_screen.apply_view_model(hud._pause_view_model(), PauseOverlay.Mode.STATS)
	await _settle()
	_check(
		hud.pause_screen.section_header(treatment_section_id) != null
			and hud.pause_screen.section_header(treatment_section_id).get_instance_id() == treatment_header_instance
			and hud.pause_screen.is_section_expanded(treatment_section_id)
			and not hud.pause_screen.is_section_expanded(&"general"),
		"Accordion-IDs bewahren Control-Instanz und Aufklappzustand beim Werte-Refresh"
	)
	_check(get_root().gui_get_focus_owner() == hud.pause_screen.section_header(treatment_section_id), "Accordion-Refresh bewahrt den Fokus am gleichen Sektionskopf")
	_check(hud.pause_screen.section_header(&"ability:1:ability_treatment_line") == null, "Leerer Aktivslot bleibt auch nach einem Refresh ohne Sektion und Blank Space")

	# The densest combat-HUD combination is validated separately because the
	# optional eight-value strip and transient alerts do not normally coexist in
	# a static screen capture. Critical rows must win without geometry collisions.
	for compact_setup in [
		Vector2i(1280, 720),
		Vector2i(1280, 800),
		Vector2i(1024, 576),
		Vector2i(960, 540),
	]:
		get_root().size = compact_setup
		var compact_settings := UISettingsState.new()
		compact_settings.ui_scale = 2.0
		hud.configure_ui_settings(compact_settings)
		hud.alert_time = 0.0
		hud.alert_label.hide()
		var compact_state := RunState.new()
		hud.update_run_stats(_character_stats_fixture(), compact_state)
		hud.update_defeat_research_reward(18)
		hud.set_run_stats_visibility(true)
		hud.show_running_hud()
		hud.update_shield(24.0, 40.0)
		hud.update_finding_progress(8, 30)
		hud.configure_active_abilities([
			{"title": "Fokusfeld", "cooldown_remaining": 0.0, "cooldown_total": 12.0, "ready": true},
			{"title": "Notfallhilfe", "cooldown_remaining": 4.0, "cooldown_total": 20.0, "ready": false},
		])
		await _settle()
		var compact_context := "%s bei 200 %%" % compact_setup
		var run_hud := hud.run_hud_screen
		_check(run_hud.run_stats_strip().visible and _rects_separate(run_hud.run_stats_strip(), run_hud.shield_panel()), "%s trennt optionale Werte und Schutzleiste im RunHUDOverlay" % compact_context)
		_check(run_hud.stat_rows().size() == 8 and _hud_row_populations(run_hud.stat_rows()) == [4, 4], "%s hält acht Grundwerte in zwei Viererreihen" % compact_context)
		_check(
			run_hud.defeat_research_reward_panel().visible
				and run_hud.defeat_research_reward_panel().get_global_rect().end.x <= run_hud.timer_panel().get_global_rect().position.x + 0.5,
			"%s hält den Forschungsgewinn links vom freistehenden Timer" % compact_context
		)
		_check(_rects_separate(run_hud.analysis_panel(), hud.finding_progress_panel), "%s ordnet Probe und Befund ohne Überlagerung" % compact_context)
		_check(_rects_separate(hud.finding_progress_panel, run_hud.ability_panel()), "%s reserviert getrennte Befund- und Fähigkeitsreihen" % compact_context)
		hud.show_alert("BELASTUNGSSCHUB", AlveolusVisualTheme.CORAL, 2.0)
		await _settle()
		_check(run_hud.run_stats_strip().visible and _rects_separate(run_hud.run_stats_strip(), run_hud.analysis_panel()), "%s hält die zweireihige Grundwertanzeige unter dem Timer trotz Alarm lesbar" % compact_context)
		_check(_rects_separate(run_hud.timer_panel(), run_hud.pause_action()), "%s trennt freistehende Rundendauer und Pauseaktion" % compact_context)
		_check(_rects_separate(hud.alert_label, run_hud.run_stats_strip()), "%s trennt Alarm und Kampfwerte" % compact_context)
		_check(_rects_separate(hud.alert_label, hud.finding_progress_panel), "%s trennt Alarm und untere Befundreihe" % compact_context)

	hud.queue_free()
	await process_frame
	_finish()


func _character_stats_fixture() -> PlayerStats:
	var stats := PlayerStats.new()
	stats.configure_prepared_treatment(TreatmentDefinition.catalog()[&"treatment_precision"])
	stats.prepared_abilities.assign([
		AbilityDefinition.catalog()[&"ability_focus_field"],
	])
	stats.defense = 6.0
	stats.life_regeneration_per_second = 1.5
	return stats


func _check_finding_tooltip_placement(hud: GameHUD, viewport_size: Vector2i, context: String) -> void:
	var registrations := hud.finding_screen.context_detail_registrations()
	_check(not registrations.is_empty(), "%s besitzt mindestens eine stabile Befund-Tooltipquelle" % context)
	if registrations.is_empty():
		return
	var source_registrations: Array = [registrations[0]]
	if registrations.size() > 1:
		source_registrations.append(registrations[registrations.size() - 1])
	for registration_value in source_registrations:
		var registration := registration_value as Dictionary
		var source := registration.get("source") as Control
		_check(source != null and source.is_visible_in_tree(), "%s bindet den Befund-Tooltip an eine sichtbare Quelle" % context)
		if source == null or not source.is_visible_in_tree():
			continue
		source.mouse_entered.emit()
		await _settle()
		var card := hud.context_detail_controller.card
		var source_rect := source.get_global_rect()
		var card_rect := card.get_global_rect()
		var transform := source.get_global_transform_with_canvas()
		var source_scale := maxf(transform.x.length(), transform.y.length())
		var scaled_gap := ContextDetailController.SOURCE_GAP * source_scale
		var scaled_margin := ContextDetailController.VIEWPORT_MARGIN * source_scale
		_check(card.is_visible_in_tree() and _inside_viewport(card, viewport_size), "%s hält den Befund-Tooltip vollständig im Viewport" % context)
		_check(not card_rect.intersects(source_rect), "%s überdeckt seine tatsächliche Befundquelle nicht" % context)
		var bounds := Rect2(
			Vector2(scaled_margin, scaled_margin),
			Vector2(viewport_size) - Vector2(scaled_margin, scaled_margin) * 2.0
		)
		var candidates := [
			Vector2(source_rect.end.x + scaled_gap, source_rect.position.y - card_rect.size.y - scaled_gap),
			Vector2(source_rect.position.x - card_rect.size.x - scaled_gap, source_rect.position.y - card_rect.size.y - scaled_gap),
			Vector2(source_rect.end.x + scaled_gap, source_rect.end.y + scaled_gap),
			Vector2(source_rect.position.x - card_rect.size.x - scaled_gap, source_rect.end.y + scaled_gap),
		]
		for candidate in candidates:
			if bounds.encloses(Rect2(candidate, card_rect.size)):
				_check(card_rect.position.distance_to(candidate) <= 1.5, "%s verwendet die erste vollständig passende globale AUTO-Position" % context)
				break
	hud.close_all_context_details()
	await _settle()


func _semantic_controls(root_node: Node, component_id: StringName) -> Array[Control]:
	var result: Array[Control] = []
	if root_node == null:
		return result
	for node in _descendants(root_node):
		if node is Control and node.get_meta(&"alveolus_component", &"") == component_id:
			result.append(node as Control)
	return result


func _visible_copy_contains_internal_distance_unit(root_node: Node) -> bool:
	if root_node == null:
		return false
	for node in _descendants(root_node):
		if not node is Label or not (node as Label).is_visible_in_tree():
			continue
		var copy := (node as Label).text.to_lower()
		if copy.contains(" px") or copy.contains("pixel") or copy.contains("weltpunkt") or copy.contains("weltmaß"):
			return true
	return false


func _hud_row_populations(rows: Array[HBoxContainer]) -> Array[int]:
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


func _check_minimum_text(root_control: Control, context: String, minimum_size: int = MIN_TEXT_SIZE) -> void:
	for node in _descendants(root_control):
		if not node.is_visible_in_tree():
			continue
		var text_value := ""
		if node is Label:
			text_value = (node as Label).text
		elif node is Button:
			text_value = (node as Button).text
		else:
			continue
		if text_value.strip_edges().is_empty():
			continue
		var control := node as Control
		var size := control.get_theme_font_size("font_size")
		_check(size >= minimum_size, "%s: „%s“ verwendet mindestens %d px" % [context, text_value.left(36), minimum_size])

func _check_actions_reachable(root_control: Control, viewport_size: Vector2i, context: String) -> void:
	for node in _descendants(root_control):
		if not node is Button or not node.is_visible_in_tree():
			continue
		var button := node as Button
		if button.text.strip_edges().is_empty() and button.get_child_count() == 0:
			continue
		_check(
			_inside_viewport(button, viewport_size) or _has_scroll_ancestor(button),
			"%s: Aktion „%s“ (%s, %s) ist sichtbar oder scrollbar erreichbar" % [context, _button_name(button), button.get_path(), button.get_global_rect()]
		)

func _button_name(button: Button) -> String:
	if not button.text.strip_edges().is_empty():
		return button.text.left(32)
	for node in _descendants(button):
		if node is Label and not (node as Label).text.strip_edges().is_empty():
			return (node as Label).text.left(32)
	return "Ohne Beschriftung"


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
	for node in _descendants(scope):
		if node is Control and node.get_meta(&"alveolus_component", &"") == component_id:
			return node as Control
	return null


func _document_body_after_header(header: Control) -> Control:
	if header == null or header.get_parent() == null:
		return null
	for sibling in header.get_parent().get_children():
		if sibling is Control and sibling != header:
			return sibling as Control
	return null


func _document_title_labels(header: Control) -> Array[Label]:
	var result: Array[Label] = []
	if header == null:
		return result
	for node in _descendants(header):
		if not node is Label:
			continue
		var label := node as Label
		if label.name == &"PageTitle" or label.theme_type_variation == AlveolusVisualTheme.TYPE_TITLE_LABEL:
			result.append(label)
	return result


func _document_header_has_eyebrow(header: Control) -> bool:
	if header == null:
		return false
	for node in _descendants(header):
		if not node is Label:
			continue
		var label := node as Label
		if label.text.strip_edges().is_empty():
			continue
		if label.theme_type_variation == AlveolusVisualTheme.TYPE_EYEBROW_LABEL or String(label.name).to_lower().contains("kicker"):
			return true
	return false


func _check_compact_page_header(parts: Dictionary, host: Control, context: String) -> void:
	var shell := parts.get("shell") as Control
	var header := parts.get("header") as Control
	var body := parts.get("body") as Control
	var stack := header.get_parent() as VBoxContainer if header != null else null
	var medallion := header.find_child("PageMedallion", true, false) as PanelContainer if header != null else null
	var icon := header.find_child("PageIcon", true, false) as SimpleIcon if header != null else null
	var heading := header.find_child("PageHeading", true, false) as VBoxContainer if header != null else null
	var titles := _document_title_labels(header)
	_check(
		shell != null and header != null and body != null and stack != null \
			and header.get_parent() == stack and stack.get_child(0) == header \
			and body.get_parent() == stack and stack.get_child(1) == body,
		"%s verwendet im 480×270-Host PageHeader als direktes Topband vor PageBodySafeArea" % context
	)
	_check(
		header != null and shell != null \
			and _rect_encloses_with_tolerance(host.get_global_rect(), header.get_global_rect()) \
			and is_equal_approx(header.get_global_rect().position.x, shell.get_global_rect().position.x) \
			and is_equal_approx(header.get_global_rect().size.x, shell.get_global_rect().size.x) \
			and body.get_global_rect().position.y >= header.get_global_rect().end.y - 0.5,
		"%s hält das vollbreite Topband und den darunterliegenden Body im 480×270-Host" % context
	)
	_check(medallion != null and medallion.custom_minimum_size.is_equal_approx(Vector2(44.0, 44.0)), "%s behält das 44-px-Medaillon" % context)
	_check(icon != null and SimpleIcon.supports(icon.kind) and titles.size() == 1, "%s zeigt semantisches SimpleIcon und genau einen Titel" % context)
	_check(heading != null and not titles.is_empty() and heading.size_flags_vertical == Control.SIZE_SHRINK_CENTER and titles[0].vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "%s zentriert den Seitentitel über den gemeinsamen Headervertrag" % context)
	var visible_actions: Array[Control] = []
	if header != null:
		for node in _descendants(header):
			if node is Button and (node as Button).is_visible_in_tree():
				visible_actions.append(node as Control)
	_check(not visible_actions.is_empty(), "%s besitzt im kompakten Header eine sichtbare Navigation" % context)
	for action in visible_actions:
		_check(
			_rect_encloses_with_tolerance(host.get_global_rect(), action.get_global_rect()) \
				and _rect_encloses_with_tolerance(header.get_global_rect(), action.get_global_rect()),
			"%s hält Headeraktion %s vollständig im 480×270-Host" % [context, action.name]
		)


func _is_content_driven_modal(modal: Control) -> bool:
	return modal != null \
		and modal.custom_minimum_size.y <= 0.5 \
		and modal.size.y <= modal.get_combined_minimum_size().y + 1.0

func _descendants(root_node: Node) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		result.append(current)
		for child in current.get_children():
			pending.append(child)
	return result

func _has_scroll_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current is ScrollContainer:
			return true
		current = current.get_parent()
	return false

func _has_descendant_type(node: Node, class_name_value: String) -> bool:
	for child in _descendants(node):
		if child.get_class() == class_name_value:
			return true
	return false

func _contains_text(node: Node, fragment: String) -> bool:
	if node is Label and (node as Label).text.contains(fragment):
		return true
	if node is Button and (node as Button).text.contains(fragment):
		return true
	for child in node.get_children():
		if _contains_text(child, fragment):
			return true
	return false

func _inside_viewport(control: Control, viewport_size: Vector2i) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= -0.5 \
		and rect.position.y >= -0.5 \
		and rect.end.x <= float(viewport_size.x) + 0.5 \
		and rect.end.y <= float(viewport_size.y) + 0.5

func _focus_owner_inside(scope: Control) -> bool:
	var owner := get_root().gui_get_focus_owner()
	return owner != null and (owner == scope or scope.is_ancestor_of(owner))

func _focus_cycle_inside(scope: Control) -> bool:
	for node in _descendants(scope):
		if not node is Button:
			continue
		var button := node as Button
		if not button.is_visible_in_tree() or button.disabled or button.focus_mode == Control.FOCUS_NONE:
			continue
		for path in [button.focus_previous, button.focus_next, button.focus_neighbor_left, button.focus_neighbor_right, button.focus_neighbor_top, button.focus_neighbor_bottom]:
			if (path as NodePath).is_empty():
				return false
			var target := button.get_node_or_null(path) as Control
			if target == null or (target != scope and not scope.is_ancestor_of(target)):
				return false
	return true

func _controls_inside(container: Control, controls: Array) -> bool:
	if container == null:
		return false
	var bounds := container.get_global_rect()
	for candidate in controls:
		var control := candidate as Control
		if control == null:
			return false
		var rect := control.get_global_rect()
		if rect.position.x < bounds.position.x - 0.5 or rect.position.y < bounds.position.y - 0.5 \
			or rect.end.x > bounds.end.x + 0.5 or rect.end.y > bounds.end.y + 0.5:
			return false
	return true

func _controls_horizontally_inside(container: Control, controls: Array) -> bool:
	if container == null:
		return false
	var bounds := container.get_global_rect()
	for candidate in controls:
		var control := candidate as Control
		if control == null:
			return false
		var rect := control.get_global_rect()
		if rect.position.x < bounds.position.x - 0.5 or rect.end.x > bounds.end.x + 0.5:
			return false
	return true

func _visible_descendants_inside(container: Control) -> bool:
	if container == null:
		return false
	var bounds := container.get_global_rect()
	for node in _descendants(container):
		if node == container or not node is Control:
			continue
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if not _rect_encloses_with_tolerance(bounds, control.get_global_rect()):
			return false
	return true

func _visible_controls_named(root_node: Node, target_name: StringName) -> Array[Control]:
	var result: Array[Control] = []
	for node in _descendants(root_node):
		if not node is Control or node.name != target_name:
			continue
		var control := node as Control
		if control.is_visible_in_tree():
			result.append(control)
	return result

func _first_focusable_control(controls: Array) -> Control:
	for candidate in controls:
		var control := candidate as Control
		if control == null or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		return control
	return null

func _control_fully_visible_within_clips(control: Control, viewport_size: Vector2i) -> bool:
	if control == null or not _inside_viewport(control, viewport_size):
		return false
	var control_rect := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var ancestor_control := ancestor as Control
			if (ancestor_control is ScrollContainer or ancestor_control.clip_contents) \
				and not _rect_encloses_with_tolerance(ancestor_control.get_global_rect(), control_rect):
				return false
		ancestor = ancestor.get_parent()
	return true

func _rect_encloses_with_tolerance(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 \
		and inner.position.y >= outer.position.y - 0.5 \
		and inner.end.x <= outer.end.x + 0.5 \
		and inner.end.y <= outer.end.y + 0.5

func _rect_approximately_equal(first: Rect2, second: Rect2, tolerance: float = 0.5) -> bool:
	return first.position.distance_to(second.position) <= tolerance \
		and first.size.distance_to(second.size) <= tolerance

func _inside_nearest_panel_container(control: Control, scope: Control) -> bool:
	if control == null or scope == null:
		return false
	var current := control.get_parent()
	while current != null and current != scope:
		if current is PanelContainer:
			return (current as Control).get_global_rect().encloses(control.get_global_rect())
		current = current.get_parent()
	return false

func _rects_separate(first: Control, second: Control) -> bool:
	if first == null or second == null:
		return false
	return not first.get_global_rect().intersects(second.get_global_rect())

func _has_minimum_content_insets(style: StyleBox, horizontal: float, vertical: float) -> bool:
	return style != null \
		and style.get_content_margin(SIDE_LEFT) >= horizontal \
		and style.get_content_margin(SIDE_RIGHT) >= horizontal \
		and style.get_content_margin(SIDE_TOP) >= vertical \
		and style.get_content_margin(SIDE_BOTTOM) >= vertical

func _settle() -> void:
	for _frame in range(3):
		await process_frame

func _capture(filename: String, expected_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(not image.is_empty(), "Screenshot %s enthält ein Bild" % filename)
	_check(image.get_size() == expected_size, "Screenshot %s besitzt die erwartete Auflösung" % filename)
	_check(image.save_png("%s/%s" % [OUTPUT_DIR, filename]) == OK, "Screenshot %s wurde gespeichert" % filename)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_UI_ACCESSIBILITY_LAYOUT_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
