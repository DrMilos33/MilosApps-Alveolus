extends SceneTree

var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var hud := GameHUD.new()
	get_root().add_child(hud)
	var sound_service := UISoundService.new()
	sound_service.output_enabled = false
	get_root().add_child(sound_service)
	sound_service.wire_tree(hud.root)
	await process_frame
	await process_frame
	var campus_meta := MetaProgressionState.new(func() -> int: return 1_700_000_000)
	campus_meta.reset_defaults(1_700_000_000)
	hud.show_campus(campus_meta)
	hud.show_campus_research_guidance()
	await process_frame
	await process_frame
	var research_card := hud.campus_buttons[&"research"] as CampusBuildingCard
	var research_target := research_card.building_sprite.get_global_rect()
	var guidance_rect := hud.campus_research_prompt.get_global_rect()
	_check(guidance_rect.end.x < research_target.position.x and guidance_rect.get_center().y < research_target.get_center().y, "Forschungshinweis steht diagonal links oberhalb des tatsächlichen Gebäudes (Hinweis %s, Ziel %s)" % [str(guidance_rect), str(research_target)])
	_check(hud.campus_research_guidance_arrow != null and hud.campus_research_guidance_arrow.text == "↘", "Der Pfeil zeigt vom Hinweis diagonal zum Forschungsgebäude")
	_check(hud.campus_research_prompt.get_meta(&"alveolus_surface_role", -1) == AlveolusVisualTheme.SurfaceRole.HUD_ALERT, "Der Forschungshinweis besitzt eine kontrastreiche semantische Alarmfläche statt ungerahmten Text")
	_check(float(research_card.outline_material.get_shader_parameter("outline_width")) >= 5.0, "Der Forschungshinweis hebt das Zielgebäude gleichzeitig mit einem dicken Rand hervor")
	var lexicon_card := hud.campus_buttons[&"lexicon"] as CampusBuildingCard
	_check(not lexicon_card.available and lexicon_card.status_label.text.contains("Fall 1"), "Das Lexikongebäude ist vor Abschluss von Fall 1 sichtbar gesperrt")
	campus_meta.highest_unlocked_level = 2
	hud.refresh_campus(campus_meta)
	_check(lexicon_card.available, "Der erhaltene Fall-1-Fortschritt schaltet das Lexikongebäude frei")

	var components := [
		{"id": &"precise", "title": "Impuls", "description": "Ein verfolgtes Ziel", "kind": 0, "capacity_cost": 2, "selected": true, "visual_id": &"treatment_precision"},
		{"id": &"focus", "title": "Fokusfeld", "description": "Stärkt einen Bereich", "kind": 1, "capacity_cost": 2, "selected": true, "visual_id": &"ability_focus_field"},
		{"id": &"emergency", "title": "Notfallhilfe", "description": "+14 Leben", "kind": 1, "capacity_cost": 2, "selected": true, "visual_id": &"ability_emergency_support"},
		{"id": &"steady", "title": "Ruhige Hand", "description": "+2 % Schaden", "kind": 2, "capacity_cost": 1},
		{"id": &"rapid_test", "title": "Schnelltest", "description": "+20 % Befund", "kind": 2, "capacity_cost": 1},
		{"id": &"shield", "title": "Schildfeld", "description": "Reduziert Schaden im Zielgebiet", "kind": 1, "capacity_cost": 2, "visual_id": &"ability_protection_field"},
		# Dense fixture for the approved two-by-two picker. These IDs exist only in
		# this UI test and deliberately do not add production loadout content.
		{"id": &"pulse", "title": "Pulswelle", "description": "Mehrere Impulse in kurzer Folge", "kind": 1, "capacity_cost": 3, "visual_id": &"ability_treatment_line"},
		{"id": &"twin", "title": "Zwillingsimpuls", "description": "Zwei Ziele gleichzeitig", "kind": 1, "capacity_cost": 3, "visual_id": &"ability_sample_pull"},
		{"id": &"ability_defense_burst", "title": "Stoß", "description": "Drängt Erreger am Ziel zurück", "kind": 1, "capacity_cost": 2, "visual_id": &"ability_defense_burst"}
	]
	var prep_view := {
		"level_title": "Testfall",
		"level_description": "Kurze Beschreibung für die Einsatzplanung.",
		"duration_text": "3:00 Min.",
		"boss_time_text": "2:15 Min.",
		"traits": [
			{"title": "Hohe Keimlast", "description": "Mehr Bakterien, aber weniger Widerstand.", "semantic_role": &"negative"},
			{"title": "Empfindliche Hülle", "description": "Erreger nehmen mehr Behandlungsschaden.", "semantic_role": &"positive"},
		],
		"trait": {"title": "Hohe Keimlast", "description": "Mehr Bakterien, aber weniger Widerstand."},
		"slot_snapshot": {
			LoadoutSlotId.TREATMENT: &"precise",
			LoadoutSlotId.ACTIVE_1: &"focus",
			LoadoutSlotId.ACTIVE_2: &"emergency",
			LoadoutSlotId.PASSIVE_1: &"",
			LoadoutSlotId.PASSIVE_2: &"",
			LoadoutSlotId.RESERVE: &"",
		},
		"validation": {"valid": true, "capacity_used": 6, "capacity_limit": 8},
		"validation_message": "Plan ist einsatzbereit.",
		"loadout_snapshot": {"treatment_id": &"precise", "ability_ids": [&"focus", &"emergency"], "passive_ids": [], "reserve_id": &""}
	}
	var start_snapshots: Array[Dictionary] = []
	hud.preparation_start_requested.connect(func(snapshot: Dictionary) -> void: start_snapshots.append(snapshot))
	hud.show_preparation(prep_view, components)
	await process_frame
	await process_frame
	_check(hud.preparation_overlay.visible, "Vorbereitung ist sichtbar")
	_check(get_root().gui_get_focus_owner() == null, "Pointer-neutrales Öffnen der Vorbereitung setzt keinen sichtbaren Fokus")
	var pointer_press := InputEventMouseButton.new()
	pointer_press.button_index = MOUSE_BUTTON_LEFT
	pointer_press.pressed = true
	hud._input(pointer_press)
	await process_frame
	await process_frame
	_check(get_root().gui_get_focus_owner() == null, "Ein Pointer-Klick aktiviert keinen automatischen Navigationsfokus")
	var tab_navigation := InputEventAction.new()
	tab_navigation.action = &"ui_focus_next"
	tab_navigation.pressed = true
	hud._input(tab_navigation)
	await process_frame
	await process_frame
	var tab_focus := get_root().gui_get_focus_owner()
	_check(tab_focus != null and hud.preparation_overlay.is_ancestor_of(tab_focus), "Tab aktiviert Fokus innerhalb der sichtbaren Vorbereitung")
	hud._input(pointer_press)
	await process_frame
	await process_frame
	_check(get_root().gui_get_focus_owner() == null, "Ein anschließender Pointer-Klick entfernt den Navigationsfokus wieder")
	var directional_navigation := InputEventAction.new()
	directional_navigation.action = &"ui_right"
	directional_navigation.pressed = true
	hud._input(directional_navigation)
	await process_frame
	await process_frame
	var directional_focus := get_root().gui_get_focus_owner()
	_check(directional_focus != null and hud.preparation_overlay.is_ancestor_of(directional_focus), "Eine Richtungseingabe aktiviert ebenfalls Fokus innerhalb der sichtbaren Vorbereitung")
	hud._input(pointer_press)
	await process_frame
	await process_frame

	# Pointer mode clears a text focus only when the click is outside that text
	# field. Otherwise an intentional click into search would immediately lose
	# its caret again.
	hud.show_lexicon(campus_meta)
	await process_frame
	await process_frame
	var lexicon_filter := hud.lexicon_master_detail.entry_filter
	lexicon_filter.grab_focus()
	var outside_text_press := InputEventMouseButton.new()
	outside_text_press.button_index = MOUSE_BUTTON_LEFT
	outside_text_press.pressed = true
	outside_text_press.position = Vector2(1270.0, 710.0)
	hud._input(outside_text_press)
	await process_frame
	await process_frame
	_check(get_root().gui_get_focus_owner() == null, "Ein Pointer-Klick außerhalb der Lexikonsuche entfernt auch deren Textfokus")
	lexicon_filter.grab_focus()
	var inside_text_press := InputEventMouseButton.new()
	inside_text_press.button_index = MOUSE_BUTTON_LEFT
	inside_text_press.pressed = true
	inside_text_press.position = lexicon_filter.get_global_rect().get_center()
	hud._input(inside_text_press)
	await process_frame
	await process_frame
	_check(get_root().gui_get_focus_owner() == lexicon_filter, "Ein Pointer-Klick in die Lexikonsuche behält den benötigten Texteingabefokus")

	# PauseStatsCompatibilityState is only a visibility marker. Directional
	# navigation must enter the real pause subview instead of that empty marker.
	hud._hide_all()
	hud.show_pause(false)
	hud._show_pause_stats()
	await process_frame
	await process_frame
	_check(hud._active_navigation_scope() == hud.pause_overlay, "Charakterwerte verwenden den echten Pause-Overlay als Navigationsbereich")
	hud._input(outside_text_press)
	await process_frame
	await process_frame
	hud._input(directional_navigation)
	await process_frame
	await process_frame
	var pause_stats_focus := get_root().gui_get_focus_owner()
	_check(pause_stats_focus != null and hud.pause_overlay.is_ancestor_of(pause_stats_focus), "Pfeil- und D-Pad-Eingaben betreten Charakterwerte nach Pointermodus wieder zuverlässig")
	hud.hide_pause()
	hud.show_preparation(prep_view, components)
	await process_frame
	await process_frame
	_check(hud.preparation_trait_title.text.to_lower().contains("hohe keimlast"), "Fallmerkmal wird erklärt")
	_check(hud.preparation_random_traits.get_child_count() == 2, "Die Fallkurzinfo zeigt beide Fallmerkmale als getrennte sichtbare Einträge")
	_check(hud.preparation_random_traits_header.visible and hud.preparation_random_traits_header.text == "ZUFALLSEREIGNISSE", "Das Merkmalspaar besitzt eine gemeinsame sichtbare Überschrift")
	_check(hud.preparation_trait_separator.visible and hud.preparation_facts_group.columns == 3, "Ein sichtbarer Separator trennt Fakten und das zweifache Merkmalspaar")
	for trait_chip in hud.preparation_random_traits.get_children():
		_check(str((trait_chip as Control).get_meta(&"alveolus_accessible_name", "")).contains("15 Prozent mehr Forschung"), "Jedes sichtbare Fallmerkmal erklärt seinen eigenen Forschungsbonus")
		_check((trait_chip as Control).focus_mode == Control.FOCUS_ALL, "Jedes sichtbare Fallmerkmal ist für ui_info fokussierbar")
	var first_trait_chip := hud.preparation_random_traits.get_child(0) as Control
	first_trait_chip.grab_focus()
	_check(hud.toggle_focused_context_detail(first_trait_chip), "ui_info öffnet die vollständige Erklärung des fokussierten Fallmerkmals")
	var trait_detail := hud.context_detail_controller.current_payload()
	_check(String(trait_detail.get("body", "")).contains("Mehr Bakterien") and trait_detail.get("meta", "") == "+15 % Forschung", "Fallmerkmal-Tooltip und ui_info teilen Wirkung und Forschungsbonus")
	hud.close_context_detail()
	var dossier_style := hud.preparation_trait_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(_stylebox_matches(dossier_style, PreparationBioLumenStyle.dossier()), "Fallkurzinfo verwendet die freigegebene Bio-Lumen-Membran")
	var plan_frame_style := hud.preparation_plan_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var editor_frame_style := hud.preparation_catalog_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(_stylebox_matches(plan_frame_style, PreparationBioLumenStyle.frame()), "Plankarte verwendet den Bio-Lumen-Rahmen")
	_check(_stylebox_matches(editor_frame_style, PreparationBioLumenStyle.frame()), "Behandlungskatalog verwendet den Bio-Lumen-Rahmen")
	var planning_back := hud.preparation_header_back_button as IconTextButton
	_check(planning_back != null and planning_back.icon_view != null and planning_back.icon_view.kind == &"back", "Zur Fallauswahl verwendet den lokalen semantischen Zurück-Button")
	_check(planning_back.get_node_or_null("MembraneFill") is PreparationBioLumenSurfaceFill, "Zur Fallauswahl besitzt die lokale Bio-Lumen-Membran")
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		_check(_stylebox_matches(planning_back.get_theme_stylebox(state) as StyleBoxFlat, PreparationBioLumenStyle.navigation(state)), "Zur Fallauswahl verwendet im Zustand %s den lokalen Bio-Lumen-Stil" % state)
	var planning_back_rect := planning_back.get_global_rect()
	planning_back.mouse_entered.emit()
	await process_frame
	planning_back.grab_focus()
	await process_frame
	_check(planning_back.scale.is_equal_approx(Vector2.ONE) and _rect_approx(planning_back_rect, planning_back.get_global_rect()), "Hover und Fokus von Zur Fallauswahl bleiben ohne Skalierung oder Geometriesprung")
	planning_back.button_down.emit()
	await process_frame
	_check(planning_back.scale.is_equal_approx(Vector2.ONE) and _rect_approx(planning_back_rect, planning_back.get_global_rect()), "Auch der gedrückte Zurück-Button bleibt pixelscharf und geometrieneutral")
	planning_back.button_up.emit()
	var plan_rect := hud.preparation_plan_panel.get_global_rect()
	var editor_rect := hud.preparation_catalog_panel.get_global_rect()
	var desktop_columns_width := plan_rect.size.x + editor_rect.size.x
	var plan_share := plan_rect.size.x / desktop_columns_width if desktop_columns_width > 0.0 else 0.0
	_check(absf(plan_share - 0.44) <= 0.025, "Desktop teilt Plan und Behandlung im freigegebenen Verhältnis 44 / 56 (aktuell %.3f; Plan %.1f / Editor %.1f; Minima %.1f / %.1f)" % [plan_share, plan_rect.size.x, editor_rect.size.x, hud.preparation_plan_panel.custom_minimum_size.x, hud.preparation_catalog_panel.custom_minimum_size.x])
	_check(absf(plan_rect.position.y - editor_rect.position.y) <= 0.5 and absf(plan_rect.size.y - editor_rect.size.y) <= 0.5, "Plan und Behandlung bilden eine bündige gemeinsame Arbeitsfläche")
	_check(hud.preparation_slots.get_child_count() == 3, "Plan zeigt nur Behandlung und die beiden aktiven Plätze")
	_check(not hud.preparation_slot_buttons.has(LoadoutSlotId.PASSIVE_1) and not hud.preparation_slot_buttons.has(LoadoutSlotId.PASSIVE_2), "Passivplätze bleiben vollständig aus der sichtbaren Planung entfernt")
	for slot_id_value in hud.preparation_slot_buttons:
		var slot_id := StringName(slot_id_value)
		var slot_button := hud.preparation_slot_buttons[slot_id] as Button
		var slot_selected := slot_id == LoadoutSlotId.TREATMENT
		_check(slot_button.tooltip_text.is_empty(), "Planplätze öffnen keinen redundanten nativen Tooltip über dem Editor")
		var normal_style := slot_button.get_theme_stylebox("normal") as StyleBoxFlat
		_check(_stylebox_matches(normal_style, PreparationBioLumenStyle.slot(&"normal", slot_selected)), "Planplatz %s verwendet seinen Bio-Lumen-Normalzustand" % slot_id)
		_check(_structured_slot_card(slot_button), "Planplatz %s enthält Icon, Titel, Beschreibung und Kosten" % slot_id)
		var slot_cost := slot_button.find_child("Cost", true, false) as Label
		_check(slot_cost != null and not slot_cost.text.contains("K"), "Planplatz %s zeigt Kapazitätskosten als nackte Zahl" % slot_id)
		_check(slot_button.find_child("SelectedRail", true, false) == null, "Planplatz %s verwendet keinen separaten Auswahlbalken" % slot_id)
	_check(not hud.preparation_reserve_button.is_visible_in_tree() and hud.preparation_reserve_button.disabled, "Die Reserve bleibt in der aktuellen Planung vollständig verborgen und inaktiv")
	_check(hud.preparation_capacity_label.text.contains("6 / 8"), "Kapazität ist unabhängig von der Mockup-Wortstellung exakt")
	_check(hud.preparation_capacity_label.get_theme_color("font_color").is_equal_approx(Color("f0bc57")), "Globale Plankapazität ist als goldener Entscheidungswert hervorgehoben")
	_check(not hud.preparation_start_button.disabled, "Gültiger Plan kann gestartet werden")
	var planning_cta_fill := hud.preparation_start_button.get_node_or_null("PreparationBioLumenFill") as PreparationBioLumenFill
	_check(planning_cta_fill != null and planning_cta_fill.host == hud.preparation_start_button, "Startaktion besitzt den planungsspezifischen Bio-Lumen-Fill")
	_check(planning_cta_fill != null and planning_cta_fill.left_accent.is_equal_approx(AlveolusVisualTheme.TURQUOISE) and planning_cta_fill.right_accent.is_equal_approx(AlveolusVisualTheme.GOLD), "Startaktion verläuft wie im Mockup von Türkis zu Gold")
	_check(hud.preparation_start_button.get_node_or_null("BioLumenFill") == null, "Startaktion stapelt keinen allgemeinen Teal-Fill über den planungsspezifischen Verlauf")
	_check(hud.planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK and hud.planning_snapshot.selected_slot_id == LoadoutSlotId.TREATMENT, "Einsatzplanung startet ohne Zwischenschritt direkt in der Behandlungsauswahl")
	_check(bool((hud.preparation_slot_buttons[LoadoutSlotId.TREATMENT] as Button).get_meta(&"selected_slot", false)), "Der direkt gewählte Behandlungsplatz ist sichtbar markiert")
	_check(not hud.preparation_remove_button.visible, "Die nicht entfernbare Grundbehandlung zeigt keine Entfernen-Aktion")
	for selected_slot_id in LoadoutSlotId.planning():
		hud._on_preparation_slot_pressed(selected_slot_id)
		await process_frame
		for slot_id_value in hud.preparation_slot_buttons:
			var slot_id := StringName(slot_id_value)
			var slot_button := hud.preparation_slot_buttons[slot_id] as Button
			var expected_height := 72.0 if slot_id == selected_slot_id else 58.0
			var description := slot_button.find_child("Description", true, false) as Label
			_check(is_equal_approx(slot_button.custom_minimum_size.y, expected_height), "Auswahl von %s setzt nur Planplatz %s auf %.0f px" % [selected_slot_id, slot_id, expected_height])
			_check(description != null and not description.text.to_lower().contains("ausgewählt"), "Planplatz %s erklärt sich ohne redundantes ‚Ausgewählt‘" % slot_id)
	hud._on_preparation_slot_pressed(LoadoutSlotId.TREATMENT)
	await process_frame
	_check(not hud.preparation_editor_browse.visible and hud.preparation_editor_picker.visible, "Der alte Übersichtsmodus bleibt vollständig aus dem Navigationsfluss entfernt")
	_check(hud.preparation_catalog_panel.visible and hud.preparation_plan_panel.visible, "Plan und zugehöriger Editor bleiben gleichzeitig erreichbar")
	var current_treatment_candidate := hud.preparation_component_buttons.get(&"precise", null) as Button
	_check(
		current_treatment_candidate != null \
			and current_treatment_candidate.get_meta(&"catalog_state") == &"current" \
			and not bool(current_treatment_candidate.get_meta(&"catalog_available", true)),
		"Die bereits ausgerüstete Behandlung bleibt als ausgegrauter Kontext sichtbar, aber nicht erneut auswählbar"
	)
	var treatment_slot := hud.preparation_slot_buttons[LoadoutSlotId.TREATMENT] as Button
	var active_one_slot := hud.preparation_slot_buttons[LoadoutSlotId.ACTIVE_1] as Button
	var treatment_rect_before_focus := treatment_slot.get_global_rect()
	var active_rect_before_focus := active_one_slot.get_global_rect()
	active_one_slot.mouse_entered.emit()
	await process_frame
	_check(active_one_slot.scale.is_equal_approx(Vector2.ONE) and _rect_approx(active_rect_before_focus, active_one_slot.get_global_rect()), "Planplatz-Hover bleibt ohne Skalierung oder Geometriesprung")
	active_one_slot.grab_focus()
	await process_frame
	_check(get_root().gui_get_focus_owner() == active_one_slot, "Tastaturfokus kann unabhängig auf einem anderen Planplatz liegen")
	_check(hud.planning_snapshot.selected_slot_id == LoadoutSlotId.TREATMENT and bool(treatment_slot.get_meta(&"selected_slot", false)), "Fokus verschiebt die dauerhafte Zielplatzauswahl nicht")
	_check(treatment_slot.scale.is_equal_approx(Vector2.ONE) and active_one_slot.scale.is_equal_approx(Vector2.ONE), "Planplatzfokus skaliert keine Karte")
	_check(_rect_approx(treatment_rect_before_focus, treatment_slot.get_global_rect()) and _rect_approx(active_rect_before_focus, active_one_slot.get_global_rect()), "Planplatzfokus verändert weder Raster noch Kartenmaße")
	var slot_component_events: Array = []
	var direct_slot_events: Array[StringName] = []
	hud.preparation_slot_component_requested.connect(func(slot_id: StringName, component_id: StringName) -> void: slot_component_events.append([slot_id, component_id]))
	hud.preparation_slot_requested.connect(func(slot_id: StringName) -> void: direct_slot_events.append(slot_id))
	hud.preparation_scroll.scroll_vertical = 200
	hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_1)
	await process_frame
	_check(hud.preparation_scroll.scroll_vertical == 0, "Ein Planplatz öffnet seinen Editor am Anfang statt mit dem Scrollstand der Übersicht")
	_check(hud.planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK and hud.preparation_editor_picker.visible, "Ein Planplatz öffnet zuerst seinen gefilterten Komponentenmodus")
	_check(direct_slot_events.is_empty() and hud.current_preparation_slots[LoadoutSlotId.ACTIVE_1] == &"focus", "Ein Klick auf einen belegten Planplatz verändert ihn niemals still")
	_check(hud.preparation_catalog.columns == 2, "Der breite Komponentenpicker verwendet ein kompaktes Zweispaltenraster")
	_check(bool((hud.preparation_slot_buttons[LoadoutSlotId.ACTIVE_1] as Button).get_meta(&"selected_slot", false)), "Der geklickte Aktivplatz übernimmt die dauerhafte Auswahl")
	_check(is_equal_approx(active_one_slot.custom_minimum_size.y, 72.0) and is_equal_approx(treatment_slot.custom_minimum_size.y, 58.0), "Der explizit gewählte Aktivplatz wächst, während die vorige Auswahl wieder kompakt wird")
	var current_focus_candidate := hud.preparation_component_buttons.get(&"focus", null) as Button
	_check(
		current_focus_candidate != null \
			and current_focus_candidate.get_meta(&"catalog_state") == &"current" \
			and not bool(current_focus_candidate.get_meta(&"catalog_available", true)),
		"Der aktuelle Slotinhalt bleibt als ausgegrauter, nicht erneut auswählbarer Kontext im Katalog"
	)
	var active_one_order := _catalog_component_order(hud)
	hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_2)
	await process_frame
	var active_two_order := _catalog_component_order(hud)
	_check(
		active_one_order == [&"focus", &"emergency", &"shield", &"pulse", &"twin", &"ability_defense_burst"] and active_two_order == active_one_order,
		"Aktive Fähigkeiten behalten über alle Zielslots dieselbe räumliche Reihenfolge"
	)
	hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_1)
	await process_frame
	_check(hud.preparation_editor_hint.text.contains("Aktuell: Fokusfeld"), "Der feste Editorkopf nennt Zielslot und aktuellen Inhalt")
	var picker_focus := get_root().gui_get_focus_owner()
	_check(picker_focus == null or not hud.preparation_catalog.is_ancestor_of(picker_focus), "Ein Mausklick markiert keinen Kandidaten ungefragt")
	var keyboard_accept := InputEventKey.new()
	keyboard_accept.keycode = KEY_ENTER
	keyboard_accept.pressed = true
	hud._on_preparation_slot_gui_input(keyboard_accept)
	hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_1)
	await process_frame
	await process_frame
	var keyboard_picker_focus := get_root().gui_get_focus_owner()
	_check(keyboard_picker_focus != null and hud.preparation_catalog.is_ancestor_of(keyboard_picker_focus), "Enter auf einem Planplatz führt den Tastaturfokus direkt in den Kandidatenkatalog")
	_check(hud.preparation_component_buttons.has(&"shield") and not hud.preparation_component_buttons.has(&"steady"), "Der Katalog zeigt im Aktivplatz nur kompatible Komponenten")
	for component_button in hud.preparation_component_buttons.values():
		var candidate := component_button as Button
		_check(is_equal_approx(candidate.custom_minimum_size.y, 56.0), "Komponentenkarten reservieren exakt 56 px")
		_check(is_equal_approx(candidate.size.y, 56.0), "Gerenderte Komponentenkarten bleiben exakt 56 px hoch")
		_check(candidate.find_child("ChoiceRail", true, false) == null, "Komponentenkarte %s verwendet keinen separaten Auswahlbalken" % candidate.name)
		if bool(candidate.get_meta(&"catalog_available", false)):
			var candidate_description := candidate.find_child("Description", true, false) as Label
			var candidate_state := candidate.find_child("State", true, false) as Label
			_check(candidate_description == null and candidate_state != null and not candidate_state.visible and candidate_state.text.is_empty(), "Verfügbare Komponente %s hält die Beschreibung ausschließlich im Tooltip" % candidate.name)
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			_check(_style_does_not_expand(candidate.get_theme_stylebox(state)), "Komponentenkarte %s malt Zustand %s nicht aus ihrer Rasterzelle" % [candidate.name, state])
	_check(hud.preparation_inspector.name == "ComponentTooltip" and hud.preparation_inspector.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Der gemeinsame Komponenten-Tooltip blockiert keine Mausinteraktion")
	var remove_button := hud.preparation_remove_button as IconTextButton
	var remove_nodes := hud.preparation_overlay.find_children("RemoveSelectedSlot", "", true, false)
	_check(remove_nodes.size() == 1 and remove_nodes[0] == remove_button, "Die Einsatzplanung besitzt genau eine Entfernen-Aktion")
	_check(remove_button != null and remove_button.visible and remove_button.name == "RemoveSelectedSlot", "Ein belegter, entfernbarer Planplatz zeigt die kompakte Entfernen-Aktion")
	_check(remove_button.theme_type_variation == AlveolusVisualTheme.TYPE_DANGER_BUTTON, "Entfernen verwendet die semantische Danger-Rolle")
	_check(remove_button.icon_view != null and remove_button.icon_view.kind == &"remove", "Entfernen besitzt ein eindeutiges Entfernen-Icon")
	_check(is_equal_approx(remove_button.custom_minimum_size.y, 26.0), "Entfernen bleibt als ruhige Headeraktion exakt 26 Designpixel hoch")
	_check(remove_button.get_parent() != null and remove_button.get_parent().name == &"EditorHeaderAction" and _control_inside(hud.preparation_catalog_panel, remove_button), "Entfernen liegt vollständig in der stabil reservierten Editor-Kopfzone")
	_check(not hud.preparation_inspector.is_ancestor_of(remove_button), "Der schwebende Tooltip enthält keine Entfernen-Aktion")
	for component_button in hud.preparation_component_buttons.values():
		_check((component_button as Button).tooltip_text.is_empty(), "Der Komponenteninspektor wird nicht durch einen doppelten Tooltip überlagert")
	var shield_button := hud.preparation_component_buttons[&"shield"] as Button
	var shield_normal_style := shield_button.get_theme_stylebox("normal") as StyleBoxFlat
	var shield_hover_style := shield_button.get_theme_stylebox("hover") as StyleBoxFlat
	var shield_focus_style := shield_button.get_theme_stylebox("focus") as StyleBoxFlat
	_check(_stylebox_matches(shield_normal_style, PreparationBioLumenStyle.candidate(&"normal", true)), "Verfügbare Kandidaten verwenden die Bio-Lumen-Karte")
	_check(not _stylebox_matches(shield_normal_style, shield_hover_style), "Hover hebt einen Kandidaten sichtbar vom Normalzustand ab")
	_check(_stylebox_matches(shield_focus_style, PreparationBioLumenStyle.candidate(&"focus", true)), "Kandidatenfokus verwendet den lokalen Bio-Lumen-Fokusring")
	var shield_rect_before_hover := shield_button.get_global_rect()
	shield_button.mouse_entered.emit()
	await process_frame
	_check(shield_button.scale.is_equal_approx(Vector2.ONE) and _rect_approx(shield_rect_before_hover, shield_button.get_global_rect()), "Kandidaten-Hover verändert weder Scale noch Geometrie")
	_check(hud.preparation_inspector.visible and _control_inside(hud.preparation_overlay, hud.preparation_inspector), "Mouseover zeigt den vollständigen Komponenten-Tooltip innerhalb der Einsatzplanung")
	_check(_subtree_ignores_mouse(hud.preparation_inspector), "Tooltip und sämtliche Inhalte ignorieren die Maus und flackern nicht über Kandidaten")
	var hover_tooltip_rect := hud.preparation_inspector.get_global_rect()
	var shield_rect := shield_button.get_global_rect()
	var adjacent_horizontally := absf(hover_tooltip_rect.position.x - shield_rect.end.x) <= 8.0 or absf(shield_rect.position.x - hover_tooltip_rect.end.x) <= 8.0
	var adjacent_vertically := absf(hover_tooltip_rect.position.y - shield_rect.end.y) <= 8.0 or absf(shield_rect.position.y - hover_tooltip_rect.end.y) <= 8.0
	_check(not hover_tooltip_rect.intersects(shield_rect) and (adjacent_horizontally or adjacent_vertically), "Der Komponenten-Tooltip liegt kompakt direkt neben seinem Mouseover-Auslöser")
	var hover_tooltip_state := [hud.preparation_inspector_title.text, hud.preparation_inspector_description.text, hud.preparation_inspector_meta.text]
	_check(hover_tooltip_state[0] == "Schildfeld" and String(hover_tooltip_state[1]).contains("Reduziert Schaden im Zielgebiet"), "Mouseover zeigt Titel und vollständige Beschreibung im Komponenten-Tooltip")
	var pulse_button := hud.preparation_component_buttons[&"pulse"] as Button
	pulse_button.mouse_entered.emit()
	shield_button.mouse_exited.emit()
	await process_frame
	_check(hud.preparation_inspector_title.text == "Pulswelle", "Ein verspätetes Mouse-exit überschreibt niemals den neueren Hover-Tooltip")
	pulse_button.mouse_exited.emit()
	await process_frame
	shield_button.grab_focus()
	await process_frame
	_check(shield_button.scale.is_equal_approx(Vector2.ONE) and _rect_approx(shield_rect_before_hover, shield_button.get_global_rect()) and _control_inside(hud.preparation_catalog_panel, shield_button), "Kandidatenfokus bleibt ohne Scale oder Panelüberlauf")
	_check(not hud.preparation_inspector.visible, "Tastatur- oder Gamepadfokus allein öffnet keinen Maus-Tooltip")
	var unlock_map := {}
	for component in components:
		unlock_map[StringName(component["id"])] = true
	unlock_map[&"shield"] = false
	var locked_prep := prep_view.duplicate(true)
	locked_prep["unlocked_ids"] = unlock_map
	hud.refresh_preparation(locked_prep, components)
	await process_frame
	var locked_button := hud.preparation_component_buttons[&"shield"] as Button
	var locked_icon := locked_button.find_child("StateIcon", true, false) as SimpleIcon
	var locked_title := locked_button.find_child("Title", true, false) as Label
	var locked_cost := locked_button.find_child("Cost", true, false) as Label
	_check(not locked_button.disabled and locked_button.get_meta(&"catalog_state") == &"locked" and not bool(locked_button.get_meta(&"catalog_available", true)), "Nicht freigeschaltete Komponenten bleiben als erklärbarer, aber nicht auswählbarer Zustand fokussierbar")
	_check(locked_icon.kind == &"locked", "Gesperrte Komponenten zeigen zusätzlich zum Kontrast ein Schloss")
	_check(locked_icon.accent.is_equal_approx(locked_title.get_theme_color("font_color")) and locked_cost.get_theme_color("font_color").is_equal_approx(locked_title.get_theme_color("font_color")), "Icon, Titel und Kosten einer Sperre sind gemeinsam entsättigt")
	_check(not locked_cost.get_theme_color("font_color").is_equal_approx(AlveolusVisualTheme.GOLD), "Gesperrte Kosten leuchten nicht gold")
	_check(_stylebox_matches(locked_button.get_theme_stylebox("normal") as StyleBoxFlat, PreparationBioLumenStyle.candidate(&"normal", false)), "Gesperrte Kandidaten verwenden den entsättigten Bio-Lumen-Zustand")
	locked_button.focus_entered.emit()
	_check(not hud.preparation_inspector.visible, "Fokus allein öffnet auch für gesperrte Komponenten keinen Maus-Tooltip")
	locked_button.mouse_entered.emit()
	await process_frame
	_check(hud.preparation_inspector.visible and hud.preparation_inspector_meta.text.contains("Gesperrt"), "Mouseover erklärt eine gesperrte Komponente vollständig")
	locked_button.mouse_exited.emit()
	var sound_before_locked_plan := sound_service.next_player
	locked_button.pressed.emit()
	_check(slot_component_events.is_empty(), "Bestätigen auf einer fokussierbaren Sperre verändert keinen Planplatz")
	_check(sound_service.next_player == (sound_before_locked_plan + 1) % UISoundService.PLAYER_COUNT, "Eine gesperrte Plankomponente erzeugt genau einen Fehler-Cue")
	hud.refresh_preparation(prep_view, components)
	hud._on_preparation_component(&"shield", false)
	_check(slot_component_events == [[LoadoutSlotId.ACTIVE_1, &"shield"]], "Die Komponentenauswahl meldet den exakten Zielplatz")
	_check(hud.planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK and hud.preparation_editor_picker.visible and not hud.preparation_editor_confirm.visible, "Die direkte Auswahl bleibt ohne Austausch-Zwischendialog im Komponentenpicker")
	_check(hud.planning_snapshot.selected_slot_id == LoadoutSlotId.ACTIVE_1 and hud.planning_snapshot.candidate_component_id == &"shield", "Die direkte Auswahl behält Zielplatz und Kandidat eindeutig im Planungszustand")
	_check(direct_slot_events.is_empty(), "Direktes Ersetzen wird nicht mit der semantisch getrennten Entfernen-Aktion verwechselt")
	_check(not hud.cancel_preparation_step(), "Zurück aus der direkten Komponentenwahl verlässt den Screen statt einen alten Übersichtsmodus zu öffnen")
	_check(hud.planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK and hud.planning_snapshot.selected_slot_id == LoadoutSlotId.ACTIVE_1, "Ohne Übersichtsmodus bleibt der aktuell gewählte Planplatz stabil")
	hud.preparation_start_button.pressed.emit()
	_check(start_snapshots.size() == 1 and start_snapshots[0].get("treatment_id") == &"precise" and StringName(str(start_snapshots[0].get("reserve_id", ""))) == &"", "Start meldet einen reservefreien Snapshot")
	var module_catalog := ContentCatalog.loadout_module_definitions()
	var prepared := PreparedLoadout.default_loadout()
	var validation := LoadoutValidator.validate(prepared, module_catalog, {}, 8)
	hud.refresh_preparation({"trait": ContentCatalog.case_trait_definitions()[&"monster_health_15"], "validation": validation}, module_catalog.values(), prepared)
	_check(_named_label_text(hud.preparation_slots.get_child(0) as Control, "Title").contains("Impuls"), "PreparedLoadout wird ohne UI-Adapter gelesen")
	_check(hud.preparation_capacity_label.text.contains("2 / 8"), "Validator liefert die Kapazität direkt")
	_check(hud.current_preparation_snapshot.get("treatment_id") == "treatment_precision", "PreparedLoadout erzeugt den Start-Snapshot")
	prepared.treatment_id = &""
	validation = LoadoutValidator.validate(prepared, module_catalog, {}, 8)
	hud.refresh_preparation({"trait": ContentCatalog.case_trait_definitions()[&"monster_health_15"], "validation": validation}, module_catalog.values(), prepared)
	_check(_named_label_text(hud.preparation_slots.get_child(0) as Control, "Title").contains("Wählen") and _named_label_text(hud.preparation_slots.get_child(1) as Control, "Title").contains("Wählen"), "Leere Grundbehandlung verschiebt aktive Slots nicht")

	var intro_view := prep_view.duplicate(true)
	intro_view["tutorial_locked"] = true
	intro_view["can_skip_intro"] = true
	intro_view["timing_intel_revealed"] = false
	hud.show_preparation(intro_view, components)
	await process_frame
	await process_frame
	_check(hud.preparation_level_facts == null and hud.preparation_boss_fact == null, "Vor dem ersten Abschluss verrät die Einsatzplanung weder Zeit noch Bossspawn")
	intro_view["timing_intel_revealed"] = true
	hud.show_preparation(intro_view, components)
	await process_frame
	var intro_duration_copy := ""
	for label_node in hud.preparation_level_facts.find_children("*", "Label", true, false):
		intro_duration_copy += (label_node as Label).text
	_check(intro_duration_copy.contains("∞") and not intro_duration_copy.contains("Ereignisgesteuert") and not intro_duration_copy.contains("Ohne Zeitlimit"), "Die Einsatzplanung zeigt die unendliche Introzeit ausschließlich als ∞")
	_check(hud.preparation_lock_panel.visible and not hud.preparation_workspace.visible, "Die Einführung zeigt ausschließlich die volle Plan-Sperrfläche statt bearbeitbarer Planmodule")
	_check(_control_inside(hud.preparation_workspace_host, hud.preparation_lock_panel) and hud.preparation_lock_panel.get_global_rect().size.is_equal_approx(hud.preparation_workspace_host.get_global_rect().size), "Die Intro-Sperre deckt den gesamten Plan-Arbeitsbereich ab")
	_check(hud.preparation_lock_panel.z_index == 0, "Die Intro-Sperre bleibt im lokalen Plan-Layer und übermalt keine späteren Bestätigungsdialoge")
	_check(not hud.preparation_start_button.disabled, "Der festgelegte Einführungsplan kann ohne Planbearbeitung direkt gestartet werden")
	var slot_event_count_before_intro := slot_component_events.size()
	var clear_event_count_before_intro := direct_slot_events.size()
	var reserve_events: Array[StringName] = []
	hud.preparation_reserve_requested.connect(func(id: StringName) -> void: reserve_events.append(id))
	var locked_slot_before := hud.planning_snapshot.selected_slot_id
	hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_2)
	hud._on_preparation_component(&"shield", false)
	hud._remove_selected_preparation_slot()
	hud._begin_reserve_selection()
	_check(slot_component_events.size() == slot_event_count_before_intro and direct_slot_events.size() == clear_event_count_before_intro and reserve_events.is_empty(), "Die volle Intro-Sperre blockiert Ausrüsten, Entfernen und Reservewahl auf Signalebene")
	_check(hud.planning_snapshot.selected_slot_id == locked_slot_before and not hud.preparation_editor_confirm.visible, "Direkte HUD-Aufrufe können den gesperrten Einführungsplan nicht mutieren")

	var guided_view := prep_view.duplicate(true)
	guided_view["guidance_step"] = &"active_1"
	(guided_view["slot_snapshot"] as Dictionary)[LoadoutSlotId.ACTIVE_1] = &""
	(guided_view["loadout_snapshot"] as Dictionary)["ability_ids"] = [&"emergency"]
	hud.show_preparation(guided_view, components)
	await process_frame
	await process_frame
	_check(hud.preparation_guidance_panel.visible and hud.preparation_guidance_label.text.contains("Aktiv 1"), "Die Fall-1-Vorbereitung zeigt zuerst die Führung zum Zielplatz Aktiv 1")
	_check(not (hud.preparation_slot_buttons[LoadoutSlotId.ACTIVE_1] as Button).disabled and (hud.preparation_slot_buttons[LoadoutSlotId.TREATMENT] as Button).disabled, "Der erste Führungsschritt lässt nur den Zielplatz Aktiv 1 bedienbar")
	_check(hud.preparation_start_button.disabled, "Während der Fall-1-Führung kann der Run nicht vorzeitig starten")
	hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_1)
	await process_frame
	_check(hud.preparation_guidance_label.text.contains("Stoß") and hud.current_preparation_guidance_step == &"defense_burst", "Nach dem Zielplatz führt die Vorbereitung ausdrücklich zu Stoß")
	var guided_burst := hud.preparation_component_buttons.get(&"ability_defense_burst", null) as Button
	_check(guided_burst != null and not guided_burst.disabled, "Stoß bleibt im zweiten Führungsschritt als einziger Zielkandidat bedienbar")
	for component_id_value in hud.preparation_component_buttons:
		var component_id := StringName(component_id_value)
		var component_button := hud.preparation_component_buttons[component_id] as Button
		if component_id != &"ability_defense_burst":
			_check(component_button.disabled, "Die Stoß-Führung sperrt den abweichenden Kandidaten %s" % component_id)
	var guided_events_before := slot_component_events.size()
	hud._on_preparation_component(&"ability_defense_burst", false)
	_check(slot_component_events.size() == guided_events_before + 1 and slot_component_events.back() == [LoadoutSlotId.ACTIVE_1, &"ability_defense_burst"], "Die geführte Stoß-Auswahl meldet exakt Aktiv 1 und die Stoß-ID")
	var hints_disabled_count := [0]
	hud.hints_disabled.connect(func() -> void: hints_disabled_count[0] += 1)
	_check(hud.preparation_guidance_hide.text == "Hinweise ausblenden", "Die Fall-1-Führung bietet den verständlichen Ausblendpfad")
	hud.preparation_guidance_hide.pressed.emit()
	_check(hints_disabled_count[0] == 1, "Der Ausblendpfad emittiert genau den globalen Hinweise-aus-Intent")

	var meta := MetaProgressionState.new()
	meta.reset_defaults(1000)
	var research_events: Array[StringName] = []
	hud.research_purchase_requested.connect(func(id: StringName) -> void: research_events.append(id))
	hud.show_research_tabs(meta, ContentCatalog.research_definitions(), TalentDefinition.definitions())
	_check(hud.research_grid.columns == 4 and hud.research_grid.get_child_count() == 10, "Die zehn Forschungen nutzen bei 1280 Pixeln ein kompaktes Vierspaltenbrett")
	_check(hud.research_buy_buttons.has(&"movement_training") and SimpleIcon.supports(&"movement_training"), "Bewegungstraining ist als achte Forschung mit zentral registrierter Bewegungsglyphe verfügbar")
	var movement_training_card := hud.research_buy_buttons[&"movement_training"] as Button
	var movement_training_glyph_found := false
	for icon_node in movement_training_card.find_children("*", "SimpleIcon", true, false):
		if (icon_node as SimpleIcon).kind == &"movement_training":
			movement_training_glyph_found = true
			break
	_check(movement_training_glyph_found, "Die Forschungskarte verwendet ihre semantische Bewegungsglyphe statt eines Fallback-Icons")
	_check((hud.research_grid.get_child(0) as Control).custom_minimum_size.y <= 76.0, "Forschungskarten bleiben kompakt")
	for research_button in hud.research_buy_buttons.values():
		_check((research_button as Button).tooltip_text.is_empty(), "Forschung nutzt ausschließlich die gemeinsame Kontextkarte")
	var research_source := hud.research_buy_buttons[&"therapy_precision"] as Button
	research_source.mouse_entered.emit()
	await process_frame
	var research_payload := hud.context_detail_controller.current_payload()
	_check(hud.context_detail_controller.is_open() and not hud.context_detail_controller.is_explicit(), "Mouseover öffnet die kompakte Forschungs-Kontextkarte")
	var therapy_precision_definition := ContentCatalog.research_definitions().filter(func(definition: ResearchDefinition) -> bool: return definition.id == &"therapy_precision")[0] as ResearchDefinition
	_check(
		research_payload.get("title", "") == "Stärkere Behandlung"
		and String(research_payload.get("body", "")).contains("Schaden")
		and String(research_payload.get("body", "")).contains("Gesamt: %s" % therapy_precision_definition.total_effect_text(meta.rank(&"therapy_precision"))),
		"Die Forschungs-Kontextkarte erklärt die Karte und übernimmt ihre Gesamtwirkung aus der Definition"
	)
	research_source.mouse_exited.emit()
	await process_frame
	_check(not hud.context_detail_controller.is_open(), "Die Forschungs-Kontextkarte schließt beim Verlassen der Karte")
	var unavailable_research := hud.research_buy_buttons[&"therapy_precision"] as Button
	_check(
		not unavailable_research.disabled
		and unavailable_research.get_meta(&"item_state", &"") == &"locked"
		and not bool(unavailable_research.get_meta(&"item_interactive", true)),
		"Unbezahlbare Forschung bleibt für Fokusinformationen erreichbar, aber semantisch gesperrt"
	)
	var unavailable_state_icon := unavailable_research.find_child("StateIcon", true, false) as SimpleIcon
	_check(unavailable_state_icon != null and unavailable_state_icon.kind == &"locked", "Gesperrte Forschung kennzeichnet ihren Zustand mit dem zentralen Schloss-Icon")
	var sound_before_locked_research := sound_service.next_player
	unavailable_research.pressed.emit()
	_check(research_events.is_empty(), "Bestätigen einer fokussierbaren Forschungssperre gibt keinen Kauf aus")
	_check(sound_service.next_player == (sound_before_locked_research + 1) % UISoundService.PLAYER_COUNT, "Eine gesperrte Forschung erzeugt genau einen Fehler-Cue")
	hud._select_research_tab(&"talents")
	_check(hud.talent_content.visible and not hud.research_content.visible, "Talenttab ersetzt Forschung ohne neue Seite")
	_check(hud.talent_buttons.size() == 26 and hud.talent_grid.get_child_count() == 3, "Talenttab baut die drei produktiven Bäume mit allen sichtbaren Platzhaltern auf")
	for talent_button in hud.talent_buttons.values():
		_check((talent_button as Button).tooltip_text.is_empty(), "Talente nutzen ausschließlich die gemeinsame Kontextkarte")
	var expected_tree_topology := {
		"TalentBranch_upgrades": Vector2i(6, 5),
		"TalentBranch_active": Vector2i(4, 3),
		"TalentBranch_treatment": Vector2i(16, 15),
	}
	for branch_panel in hud.talent_grid.get_children():
		var branch := (branch_panel as Control).find_child("Tree", true, false) as TalentTreeBranch
		var expected: Vector2i = expected_tree_topology.get(String(branch_panel.name), Vector2i.ZERO)
		_check(branch != null and branch.node_count() == expected.x and branch.edge_count() == expected.y, "Jeder Talentbaum besitzt seine vollständige, gezeichnete Topologie")
		_check(branch_panel is VBoxContainer and (branch_panel as Control).theme_type_variation != AlveolusVisualTheme.TYPE_ACTION_CARD, "Der kompakte Talentbaum verwendet keine große Astkarte")
	await process_frame
	await process_frame
	var treatment_root := hud.talent_buttons[&"treatment_damage_training"] as Button
	var spread_branch := hud.talent_buttons[&"spread_shotgun"] as Button
	var manual_branch := hud.talent_buttons[&"manual_treatment_aim"] as Button
	var persistence_branch := hud.talent_buttons[&"piercing_persistence"] as Button
	var impulse_branch := hud.talent_buttons[&"impulse_splash"] as Button
	_check(
		int(treatment_root.get_meta(&"talent_rank_maximum", 0)) == 3
		and int(spread_branch.get_meta(&"talent_rank_maximum", 0)) == 1
		and String(spread_branch.get_meta(&"alveolus_accessible_name", "")).contains("Rang 0 von 1"),
		"Produktive Talentwerte steuern Rangpips und Accessible Name direkt"
	)
	var root_child := treatment_root.get_node_or_null(treatment_root.focus_neighbor_bottom) as Button
	var branch_sibling := spread_branch.get_node_or_null(spread_branch.focus_neighbor_right) as Button
	var branch_sibling_left := manual_branch.get_node_or_null(manual_branch.focus_neighbor_right) as Button
	var branch_sibling_right := persistence_branch.get_node_or_null(persistence_branch.focus_neighbor_right) as Button
	_check(root_child in [manual_branch, spread_branch, persistence_branch, impulse_branch], "D-Pad nach unten folgt vom Wurzeltalent einem gezeichneten Kind")
	_check(branch_sibling_left == spread_branch and branch_sibling == persistence_branch and branch_sibling_right == impulse_branch, "D-Pad seitwärts folgt den vier Geschwistertalenten derselben Baumstufe")
	_check(treatment_root.get_node_or_null(treatment_root.focus_neighbor_top) == hud.talent_tab_button, "D-Pad kann den Behandlungsbaum nach oben zu den festen Tabs verlassen")
	_check(not hud.talent_buttons.has(&"piercing_return"), "Die reservierte Revision-3-ID piercing_return erscheint nicht mehr im aktiven Talentbaum")
	_check(treatment_root.custom_minimum_size.y <= 76.0, "Talentknoten bleiben auf die kompakte Baumdichte begrenzt")
	persistence_branch.grab_focus()
	await process_frame
	_check(not hud.context_detail_controller.is_open(), "Reiner Tastatur- oder Gamepadfokus öffnet keine Tooltipkarte")
	_check(hud.toggle_focused_context_detail(persistence_branch), "ui_info öffnet die Detailkarte des fokussierten Talentknotens")
	await process_frame
	var talent_payload := hud.context_detail_controller.current_payload()
	_check(hud.context_detail_controller.is_explicit() and talent_payload.get("title", "") == "Anhaltender Laser" and String(talent_payload.get("body", "")).contains("0,5"), "Die ausdrückliche Talentdetailkarte ist vollständig")
	_check(String(talent_payload.get("meta", "")).contains("Behandlungsgrundlage"), "Die Talentdetailkarte nennt die aktuelle Wurzel als konkrete Voraussetzung")
	hud.close_context_detail()
	_check(hud.talent_points_label.text.to_lower().contains("0 frei"), "Freie Talentpunkte werden in Sentence Case gezeigt")
	var reset_caption := (hud.talent_reset_button as IconTextButton).caption.text
	_check(reset_caption.to_lower().contains("kostenlos"), "Umskillen ist in Sentence Case ausdrücklich kostenlos")
	var locked_talent := hud.talent_buttons[&"manual_treatment_aim"] as Button
	_check(locked_talent.get_meta(&"item_state", &"") == &"locked" and not bool(locked_talent.get_meta(&"item_interactive", true)), "Talentknoten exponieren Sperrstatus und Interaktivität semantisch")
	var sound_before_locked_talent := sound_service.next_player
	locked_talent.pressed.emit()
	_check(sound_service.next_player == (sound_before_locked_talent + 1) % UISoundService.PLAYER_COUNT, "Ein gesperrtes Talent erzeugt genau einen Fehler-Cue")
	var reset_view := hud._talent_view_from_meta(meta, TalentDefinition.definitions())
	reset_view["spent_points"] = 1
	reset_view["total_points"] = 1
	hud.refresh_talents(reset_view)
	await process_frame
	hud.talent_reset_button.grab_focus()
	reset_view["spent_points"] = 0
	hud.refresh_talents(reset_view)
	await process_frame
	await process_frame
	var focus_after_reset := get_root().gui_get_focus_owner()
	var first_tree_root := hud.talent_buttons[&"upgrade_rarity_training"] as Button
	_check(hud.talent_reset_button.disabled and focus_after_reset == first_tree_root, "Nach dem Talent-Reset wechselt der Fokus vom deaktivierten Reset sicher zum ersten Baumknoten")
	_check(_inside_viewport(first_tree_root, get_root().size), "Der Fokus nach dem Talent-Reset bleibt sichtbar im Talentbaum")

	hud.configure_active_abilities([
		{"id": &"ability_focus_field", "title": "Fokusfeld", "description": "Behandlung im Zielgebiet verursacht 25 % mehr Schaden.", "fact_rows": [{"label": "Abklingzeit", "value": "16 s"}, {"label": "Radius", "value": "6"}], "cooldown_remaining": 0.0, "cooldown_total": 16.0, "ready": true},
		{"id": &"ability_emergency_support", "title": "Notfallhilfe", "description": "", "fact_rows": [{"label": "Abklingzeit", "value": "28 s"}, {"label": "Heilung", "value": "14"}, {"label": "Schild", "value": "8"}], "cooldown_remaining": 7.2, "cooldown_total": 28.0, "ready": false}
	])
	hud.show_running_hud()
	hud.set_run_stats_visibility(true)
	hud.update_run_stats(PlayerStats.new())
	hud.update_defeat_research_reward(17)
	await process_frame
	_check(hud.run_hud_screen != null and hud.run_hud_screen.is_visible_in_tree(), "Das neue RunHUDOverlay ist im laufenden Run sichtbar")
	_check(hud.run_prompt != null and hud.run_prompt.find_children("*", "Panel", true, false).is_empty(), "Run-Meldungen verwenden die zentrale containerlose PlainRunPrompt-View")
	hud.show_boss(100.0, 2)
	await process_frame
	_check(hud.run_prompt.visible and hud.run_prompt.semantic_mode() == PlainRunPrompt.MODE_CORAL, "Die normale Bossmeldung verwendet dieselbe korallene Plain-View")
	_check(hud.run_prompt.message_label().text == "Infektionsherd erkannt", "Die Bossmeldung verwendet die freigegebene knappe Copy")
	_check(hud.run_prompt.message_label().get_global_rect().position.y >= hud.stability_panel.get_global_rect().end.y - 0.5, "Bosscopy liegt direkt unter dem zentrierten Lebensbalken")
	hud.hide_run_prompt()
	var prompt_confirmations: Array[bool] = []
	hud.run_prompt_confirmed.connect(func() -> void: prompt_confirmations.append(true))
	hud.show_run_prompt("Beobachte den ersten Erreger.", PlainRunPrompt.MODE_NORMAL, true, "Linksklick zum Fortfahren")
	await process_frame
	_check(hud.run_prompt.get_parent() == hud.root and hud.run_prompt.get_index() > hud.end_overlay.get_index(), "Der blockierende Run-Prompt ist als oberstes Root-Geschwister über allen Modalen montiert")
	_check(hud.run_prompt.message_label().get_global_rect().position.y >= hud.stability_panel.get_global_rect().end.y - 0.5, "Normale Introcopy liegt wie die Bossmeldung direkt unter dem Lebensbalken")
	_check(hud.run_prompt.message_label().get_global_rect().end.y <= PlainRunPrompt.RUN_HUD_BAND_BOTTOM + 0.5, "Normale Introcopy bleibt in der kompakten oberen Leseband")
	hud.show_boss(100.0, 2)
	_check(hud.run_prompt.message_label().text == "Beobachte den ersten Erreger." and hud.is_run_prompt_awaiting_confirmation(), "Eine normale Bossankündigung überschreibt keinen bereits blockierenden Intro-Prompt")
	var intro_left_click := InputEventMouseButton.new()
	intro_left_click.button_index = MOUSE_BUTTON_LEFT
	intro_left_click.pressed = true
	hud.run_prompt._gui_input(intro_left_click)
	hud.run_prompt._gui_input(intro_left_click)
	_check(prompt_confirmations.size() == 1 and not hud.is_run_prompt_awaiting_confirmation(), "Der blockierende Prompt konsumiert einen Linksklick und relayed genau eine Fortsetzungsabsicht")
	hud.hide_run_prompt()
	var expected_run_stat_ids: Array[StringName] = [
		&"defense", &"movement_speed", &"life_regeneration", &"experience_gain",
		&"resistance_fire", &"resistance_water", &"resistance_earth", &"resistance_wind",
	]
	var actual_run_stat_ids: Array[StringName] = []
	for stat_row in hud.run_hud_screen.stat_rows():
		actual_run_stat_ids.append(StringName(stat_row.get_meta(&"stat_id", &"")))
	_check(actual_run_stat_ids == expected_run_stat_ids and hud.run_stats_strip.visible, "Das RunHUDOverlay zeigt ausschließlich die acht stabilen Grundwerte in Prioritätsreihenfolge")
	for stat_row in hud.run_hud_screen.stat_rows():
		_check(stat_row.get_child_count() == 2 and stat_row.get_child(0) is SimpleIcon and stat_row.get_child(1) is Label, "Jede sichtbare Statzeile besteht kompakt aus Icon und Wert")
		var accessible_stat := String(stat_row.get_meta(&"alveolus_accessible_name", ""))
		_check(not accessible_stat.contains("Behandlung") and not accessible_stat.contains("Fokusfeld") and not accessible_stat.contains("Notfallhilfe"), "Das kompakte Run-HUD enthält keine Behandlungs- oder Fähigkeitswerte")
	var defeat_reward_panel := hud.run_hud_screen.defeat_research_reward_panel()
	_check(
		defeat_reward_panel.visible
		and hud.run_hud_screen.defeat_research_reward_icon().kind == &"research"
		and hud.run_hud_screen.defeat_research_reward_value_label().text == "+17"
		and String(defeat_reward_panel.get_meta(&"alveolus_accessible_name", "")).contains("17"),
		"Links der Rundendauer steht die zugängliche Forschungsprognose nur als Symbol und Zahl"
	)
	_check(defeat_reward_panel.get_global_rect().end.x <= hud.timer_panel.get_global_rect().position.x + 0.5, "Die Forschungsprognose liegt kollisionsfrei links vom Timer")
	_check(hud.ability_panel.visible, "Q/E-Anzeige erscheint für vorbereitete Fähigkeiten")
	_check(hud.ability_key_labels[0].text == "Q" and hud.ability_key_labels[1].text == "E", "Das RunHUDOverlay zeigt Fähigkeitsbelegungen als scharfen Glyph-Text")
	_check(hud.ability_cooldown_labels[0].text == "Bereit", "Bereite Fähigkeit wird in Sentence Case klar markiert")
	_check(hud.ability_cooldown_labels[1].text == "7.2 s", "Restzeit wird sekundengenau gezeigt")
	_check(not hud.ability_title_labels[0].visible and not hud.ability_title_labels[1].visible, "Das laufende HUD wiederholt keine Fähigkeitsnamen")
	for ability_card in hud.ability_cards:
		_check((ability_card as Panel).get_meta(&"alveolus_component", &"") == &"transparent_hud_ability", "Belegte Fähigkeiten erscheinen ohne massive Kartenfläche")
	var run_ability_button := (hud.run_hud_screen.ability_buttons()[0] as Button)
	run_ability_button.mouse_entered.emit()
	await process_frame
	var ability_detail_payload := hud.context_detail_controller.current_payload()
	var ability_detail_body := String(ability_detail_payload.get("body", ""))
	var ability_detail_meta := String(ability_detail_payload.get("meta", ""))
	_check(hud.context_detail_controller.is_open() and ability_detail_payload.get("title", "") == "Fokusfeld" and ability_detail_body.contains("25 % mehr Schaden"), "Mouseover erklärt Name und Kernwirkung der aktiven Fähigkeit")
	_check(ability_detail_meta.contains("Abklingzeit: 16 s") and ability_detail_meta.contains("Radius: 6") and not ability_detail_meta.contains("165") and not ability_detail_meta.to_lower().contains("px"), "Fähigkeitsdetails ergänzen ausschließlich strukturierte Fakten und zentrale Radiusstufen")
	run_ability_button.mouse_exited.emit()
	await process_frame
	hud.update_finding_progress(18, 30)
	_check(hud.finding_progress_label.text == "BEFUND · 18 / 30", "Befundleiste zeigt exakten Fortschritt")
	_check(hud.finding_progress_panel.size.y <= 30.5 and hud.finding_progress_bar.custom_minimum_size.y <= 5.0, "Befundfortschritt bleibt als dezente, niedrige HUD-Zeile sichtbar")

	var confirmed: Array = []
	hud.finding_confirmed.connect(func(reaction_id: StringName, incoming: StringName, outgoing: StringName) -> void: confirmed.append([reaction_id, incoming, outgoing]))
	hud.show_finding(
		{"title": "Gruppenbildung", "medical_text": "Mehrere Erreger sammeln sich.", "gameplay_text": "Bakteriengruppen treten häufiger auf."},
		[
			{"id": &"area", "title": "Flächenwirkung", "effect": "Gruppen schneller kontrollieren"},
			{"id": &"control", "title": "Kontrolle", "effect": "Tempo senken"},
			{"id": &"protect", "title": "Patientenschild", "effect": "Gegnerschaden senken"}
		],
		null,
		[]
	)
	_check(hud.finding_screen.reaction_grid().get_child_count() == 3, "Befund bietet drei Reaktionen")
	_check(hud.finding_screen.reserve_panel() == null and hud.finding_screen.swap_action() == null, "Der Befund baut keine Reservebedienung, solange das System ruht")
	var area_reaction := hud.finding_screen.reaction_action(&"area")
	_check(area_reaction != null and hud.finding_screen.confirm_action().disabled, "Die neue Befundaktion beginnt ohne versteckte Vorauswahl")
	area_reaction.pressed.emit()
	_check(hud.finding_screen.selected_reaction_id() == &"area" and not hud.finding_screen.confirm_action().disabled, "Die Reaktionswahl aktiviert genau die ausdrückliche Befundbestätigung")
	hud.finding_screen.confirm_action().pressed.emit()
	_check(confirmed == [[&"area", &"", &""]], "Befund meldet die Reaktion ohne versteckten Reservetausch")

	var level := ContentCatalog.level_definitions()[1]
	hud.show_end(level, true, "Kontrolliert", 120.0, 4, 50, 20, false)
	await process_frame
	await process_frame
	_check(get_root().gui_get_focus_owner() == null, "Auch das Ergebnis öffnet pointer-neutral ohne automatischen Fokus")
	hud.show_end_mastery([{"title": "Erster Sieg"}], 1, 4)
	_check(hud.end_mastery_panel.visible, "Ergebnis zeigt neue Meisterschaft")
	_check(hud.end_mastery_label.text.to_lower().contains("+1 talentpunkte"), "Talentbelohnung ist unabhängig von der Sentence-Case-Darstellung getrennt ausgewiesen")

	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(960, 540)]:
		get_root().size = viewport_size
		hud.show_preparation(prep_view, components)
		await process_frame
		await process_frame
		_check(hud.preparation_plan_panel.visible and hud.preparation_catalog_panel.visible, "Plan und Editor bleiben bei %s ohne Zwischenscreen erreichbar" % viewport_size)
		_check(_inside_viewport(hud.preparation_start_button, viewport_size), "Startbutton bleibt bei %s im Bild" % viewport_size)
		_check(_inside_viewport(hud.preparation_catalog, viewport_size), "Komponentenkatalog bleibt bei %s im Bild" % viewport_size)
		hud.show_finding({"title": "Test", "gameplay_text": "Schaden"}, [{"id": &"a", "title": "A"}, {"id": &"b", "title": "B"}, {"id": &"c", "title": "C"}, {"id": &"d", "title": "D"}])
		await process_frame
		_check(_inside_viewport(hud.finding_confirm_button, viewport_size), "Befundaktion bleibt bei %s im Bild" % viewport_size)

	hud.queue_free()
	sound_service.queue_free()
	await process_frame
	if failures.is_empty():
		print("ALVEOLUS_TACTICAL_UI_OK assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _inside_viewport(control: Control, viewport_size: Vector2i) -> bool:
	var rect := control.get_global_rect()
	# The project uses canvas_items stretching: Control coordinates remain in the
	# 1280x720 reference canvas and are proportionally scaled to viewport_size.
	var reference_size := Vector2(1280.0, 720.0) if viewport_size != Vector2i.ZERO else Vector2(viewport_size)
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= reference_size.x + 0.5 and rect.end.y <= reference_size.y + 0.5

func _control_inside(container: Control, child: Control) -> bool:
	if container == null or child == null:
		return false
	var bounds := container.get_global_rect()
	var rect := child.get_global_rect()
	return rect.position.x >= bounds.position.x - 0.5 \
		and rect.position.y >= bounds.position.y - 0.5 \
		and rect.end.x <= bounds.end.x + 0.5 \
		and rect.end.y <= bounds.end.y + 0.5

func _structured_slot_card(button: Button) -> bool:
	if button == null:
		return false
	var icon := button.find_child("Icon", true, false) as Control
	var title := button.find_child("Title", true, false) as Label
	var description := button.find_child("Description", true, false) as Label
	var cost := button.find_child("Cost", true, false) as Label
	if icon == null or title == null or description == null or cost == null:
		return false
	for child in [icon, title, description, cost]:
		if not _control_inside(button, child):
			return false
	return true

func _named_label_text(root_control: Control, child_name: String) -> String:
	if root_control == null:
		return ""
	var label := root_control.find_child(child_name, true, false) as Label
	return label.text if label != null else ""

func _catalog_component_order(hud: GameHUD) -> Array[StringName]:
	var result: Array[StringName] = []
	for child in hud.preparation_catalog.get_children():
		if child is Button and child.has_meta(&"component_id"):
			result.append(StringName(child.get_meta(&"component_id")))
	return result

func _rect_approx(first: Rect2, second: Rect2, tolerance: float = 0.5) -> bool:
	return first.position.distance_to(second.position) <= tolerance \
		and first.size.distance_to(second.size) <= tolerance

func _stylebox_matches(first: StyleBoxFlat, second: StyleBoxFlat) -> bool:
	if first == null or second == null:
		return false
	return first.bg_color.is_equal_approx(second.bg_color) \
		and first.border_color.is_equal_approx(second.border_color) \
		and first.border_width_left == second.border_width_left \
		and first.border_width_top == second.border_width_top \
		and first.border_width_right == second.border_width_right \
		and first.border_width_bottom == second.border_width_bottom \
		and first.corner_radius_top_left == second.corner_radius_top_left \
		and first.corner_radius_top_right == second.corner_radius_top_right \
		and first.corner_radius_bottom_right == second.corner_radius_bottom_right \
		and first.corner_radius_bottom_left == second.corner_radius_bottom_left \
		and is_equal_approx(first.content_margin_left, second.content_margin_left) \
		and is_equal_approx(first.content_margin_top, second.content_margin_top) \
		and is_equal_approx(first.content_margin_right, second.content_margin_right) \
		and is_equal_approx(first.content_margin_bottom, second.content_margin_bottom)

func _style_does_not_expand(style: StyleBox) -> bool:
	if style == null:
		return false
	return style.get_expand_margin(SIDE_LEFT) <= 0.5 \
		and style.get_expand_margin(SIDE_TOP) <= 0.5 \
		and style.get_expand_margin(SIDE_RIGHT) <= 0.5 \
		and style.get_expand_margin(SIDE_BOTTOM) <= 0.5

func _subtree_ignores_mouse(root_control: Control) -> bool:
	if root_control == null or root_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for candidate in root_control.find_children("*", "Control", true, false):
		if (candidate as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
	return true
