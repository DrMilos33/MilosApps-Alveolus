extends SceneTree

var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var hud := GameHUD.new()
	get_root().add_child(hud)
	await process_frame
	await process_frame
	_test_icon_assets()

	_check(not _contains_text(hud.research_overlay, "Kleine, gedeckelte"), "Forschungsseite enthält den entfernten Untertext nicht")
	_check(not _contains_text(hud.practice_overlay, "Automatische Forschung und Klinikfälle laufen"), "Praxisseite enthält den entfernten Untertext nicht")
	_check(not _contains_text(hud.settings_overlay, "Placeholder"), "Einstellungen verwenden keine veraltete Platzhalterseite")
	_check(hud.settings_master_slider != null and hud.settings_scale_option != null, "Einstellungen bieten funktionsfähige Audio- und Anzeigeoptionen")
	for shell in hud.page_shells:
		_check(not shell.has("header_glow"), "Dokumentseiten besitzen keinen dekorativen Balken unter dem Header")
		var header := shell.get("header") as HBoxContainer
		var title := shell.get("title") as Label
		var direct_label_count := 0
		for header_child in header.get_children():
			if header_child is Label:
				direct_label_count += 1
		_check(not shell.has("kicker") and direct_label_count == 1, "Dokumentseiten verwenden einen einzeiligen Header ohne Obertitel")
		_check(title != null and title.get_parent() == header and title.autowrap_mode == TextServer.AUTOWRAP_OFF and not title.text.contains("\n"), "Der Seitentitel bleibt eine einzelne klar getrennte Headerzeile")
		_check(header.get_theme_constant("separation") >= 16, "Icon und Seitentitel besitzen den verbindlichen Innenabstand")
	for scroll_value in hud.root.find_children("*", "ScrollContainer", true, false):
		var scroll := scroll_value as ScrollContainer
		if scroll != null and not _has_ancestor_type(scroll, "PopupMenu") and _has_focusable_descendant(scroll):
			_check(
				scroll.follow_focus or bool(scroll.get_meta(&"manual_focus_scroll", false)),
				"Interaktive Scrollfläche %s hält Tastatur- und Gamepadfokus im sichtbaren Ausschnitt" % scroll.get_path()
			)
	hud.show_settings(true, true)
	await process_frame
	await process_frame
	_check(hud.settings_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Einstellungen scrollen nur dann, wenn ihr vollständiger Inhalt die Fläche wirklich überschreitet")
	for section_title in ["Audio", "Anzeige und Bedienung", "Steuerung"]:
		var title_label := _find_label_exact(hud.settings_overlay, section_title)
		var section_panel := _panel_container_ancestor(title_label)
		_check(section_panel != null, "Einstellungsbereich %s verwendet einen inhaltsmessenden PanelContainer" % section_title)
		if section_panel != null:
			_check(not section_panel.clip_contents, "Einstellungsbereich %s schneidet seinen Inhalt nicht an einer festen Kartenhöhe ab" % section_title)
			_check(section_panel.size.y + 0.5 >= section_panel.get_combined_minimum_size().y, "Einstellungsbereich %s erhält mindestens die vom Inhalt benötigte Höhe" % section_title)
	var campus_header_layer := hud.campus_overlay.get_node_or_null("CampusHeaderLayer") as Control
	_check(campus_header_layer != null and campus_header_layer.z_index == 0, "Der Campusheader bleibt in der lokalen Campusebene und übermalt keine Dokumentseite")
	if campus_header_layer != null:
		for campus_card in hud.campus_buttons.values():
			_check((campus_card as Control).get_parent() == campus_header_layer.get_parent() and (campus_card as Control).get_index() < campus_header_layer.get_index(), "Der lokale Campusheader liegt per Baumreihenfolge über jeder Gebäudekarte")
	for campus_card in hud.campus_buttons.values():
		_check((campus_card as Control).position.y >= 112.0, "Campusgebäude beginnen unter Header und Inhaltsabstand")
	var levels := ContentCatalog.level_definitions()
	var level_meta := MetaProgressionState.new()
	hud.show_level_select(level_meta, levels)
	await process_frame
	_check(hud.level_overlay.visible and campus_header_layer.z_index == 0, "Der Fallarchivheader bleibt frei vom abgedunkelten Campusheader")
	var archive_accents := {}
	var locked_illustrations := 0
	for level in levels:
		var level_button := hud.level_buttons[level.id] as Button
		var illustration := hud.level_illustrations[level.id] as LevelCaseIllustration
		_check(illustration != null, "Jeder Fall besitzt eine eigene ungerahmte Fallillustration")
		if illustration == null:
			continue
		archive_accents[illustration.accent.to_html()] = true
		_check(is_equal_approx(illustration.custom_minimum_size.x, illustration.custom_minimum_size.y), "Fallillustrationen behalten einen quadratischen Zeichenraum")
		_check(illustration.mouse_filter == Control.MOUSE_FILTER_IGNORE and illustration.get_child_count() == 0, "Fallillustrationen sind ungerahmte, nicht interaktive Glyphen statt verschachtelter Kacheln")
		_check(illustration.locked == level_button.disabled, "Gesperrte Fälle tragen direkt in der Illustration ein Schloss")
		if illustration.locked:
			locked_illustrations += 1
	_check(archive_accents.size() >= 3, "Das Fallarchiv unterscheidet Fälle mit mehreren semantischen Akzentfarben")
	_check(locked_illustrations > 0, "Das Fallarchiv prüft den sichtbaren Lock-Zustand noch nicht freigeschalteter Fälle")
	hud.show_story()
	await process_frame
	var story_focus := get_root().gui_get_focus_owner()
	_check(story_focus != hud.story_skip_button, "Der Prolog markiert Überspringen beim Öffnen niemals ungefragt")
	hud.story_next_button.focus_entered.emit()
	await process_frame
	_check(hud.story_next_button.scale.is_equal_approx(Vector2.ONE), "Prologfokus bleibt innerhalb der Buttongeometrie")
	_check(ContentCatalog.level_definitions()[1].title == "lol - name fehlt", "Fall 1 zeigt den gewünschten Platzhalternamen")
	_assert_compact_modal(hud.story_panel, 260.0, "Prolog")

	var meta := MetaProgressionState.new()
	meta.set_unlimited_test_progression(true)
	_check(meta.set_talent_active(&"organization_1", true), "Der Testzustand aktiviert einen Talentknoten für die visuelle Statusprüfung")
	hud.show_research_tabs(meta, ContentCatalog.research_definitions(), TalentDefinition.definitions())
	await process_frame
	_check(hud.research_grid.columns == 3 and hud.research_grid.get_child_count() == 15, "Forschung zeigt bei 1280 Pixeln drei kompakte Spalten")
	for research_card in hud.research_grid.get_children():
		_check((research_card as Control).custom_minimum_size.y <= 76.0, "Forschungskarten überschreiten die kompakte Höhe nicht")
	hud._select_research_tab(&"talents")
	await process_frame
	_check(hud.talent_grid.columns == 3 and hud.talent_grid.get_child_count() == 3, "Talente zeigen bei 1280 Pixeln drei kompakte Baumäste")
	_check(hud.talent_buttons.size() == 12, "Alle zwölf Talente bleiben in den drei Baumästen erreichbar")
	var talent_tree_count := 0
	var talent_node_count := 0
	var talent_edge_count := 0
	var branch_accents := {}
	for talent_branch in hud.talent_grid.get_children():
		var trees: Array[Node] = talent_branch.find_children("*", "TalentTreeBranch", true, false)
		talent_tree_count += trees.size()
		for tree in trees:
			var branch := tree as TalentTreeBranch
			talent_node_count += branch.node_count()
			talent_edge_count += branch.edge_count()
			branch_accents[branch.branch_accent.to_html()] = true
			_check(branch.get_child_count() == branch.node_count(), "Talentverbindungen werden als ruhige Linien gezeichnet und erzeugen keine zusätzlichen Kreispunkt-Controls")
			for node in branch.get_children():
				_check(node is Button, "Im Talentbaum bleiben ausschließlich die interaktiven Knoten als Controls bestehen")
	_check(talent_tree_count == 3 and talent_node_count == 12, "Jeder Bereich besitzt einen echten verzweigten Talentbaum statt großer Listenkacheln")
	_check(talent_edge_count == 9, "Alle neun Abhängigkeiten bleiben als Baumverbindungen erhalten")
	_check(branch_accents.size() == 3, "Planung, Diagnose und Einsatz behalten jeweils ihren eigenen Astakzent")
	for talent_button in hud.talent_buttons.values():
		var node_button := talent_button as Button
		_check(node_button.custom_minimum_size.y <= TalentTreeBranch.NODE_HEIGHT, "Talentknoten bleiben auf die kompakte Baumhöhe begrenzt")
		_check(not _contains_text(node_button, "VERFÜGBAR") and not _contains_text(node_button, "AKTIV") and not _contains_text(node_button, "BRAUCHT"), "Talentknoten erklären ihren Zustand ohne wiederholte Statuswörter")
		_check(node_button.has_meta(&"item_state") and node_button.has_meta(&"item_interactive"), "Talentstatus bleibt semantisch prüfbar, obwohl er visuell über Farbe und Icon vermittelt wird")
	var active_talent := hud.talent_buttons[&"organization_1"] as Button
	var active_state_icon := active_talent.find_child("StateIcon", true, false) as SimpleIcon
	_check(active_talent.get_meta(&"item_state", &"") == &"active" and active_talent.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CARD and active_state_icon != null and active_state_icon.kind == &"check", "Aktive Talente werden durch Highlight und Check-Icon statt Statustext markiert")
	var locked_talent := hud.talent_buttons[&"hold_card"] as Button
	var locked_state_icon := locked_talent.find_child("StateIcon", true, false) as SimpleIcon
	_check(locked_talent.get_meta(&"item_state", &"") == &"locked" and not bool(locked_talent.get_meta(&"item_interactive", true)) and locked_state_icon != null and locked_state_icon.kind == &"locked", "Noch gesperrte Folgeknoten zeigen ein eindeutiges Schloss ohne Textballast")

	var finding_reactions: Array = [
		{"id": &"observe", "title": "Weiter beobachten", "description": "Befundfortschritt erhöhen."},
		{"id": &"stabilize", "title": "Stabilisieren", "description": "Kurzzeitig Zustand schützen."},
		{"id": &"treat", "title": "Gezielt behandeln", "description": "Behandlung verstärken."},
	]
	hud.show_finding({
		"title": "Lokaler Herd",
		"medical_text": "Ein lokaler Entzündungsherd belastet das umliegende Gewebe.",
		"gameplay_text": "Wähle eine Reaktion für den weiteren Verlauf.",
	}, finding_reactions)
	await process_frame
	await process_frame
	_assert_compact_modal(hud.finding_panel, 432.0, "Befund")
	_check(hud.finding_copy_grid.columns == 2, "Befund trennt medizinische Einordnung und Spielwirkung in zwei kompakte Flächen")
	for copy_surface in hud.finding_copy_grid.get_children():
		_check(copy_surface is PanelContainer and copy_surface.get_meta(&"alveolus_component", &"") == &"semantic_copy_section", "Befundtexte bleiben visuell nach Bedeutung abgegrenzt")
	hud.show_end(levels[1], false, "Der Zustand ist auf null gefallen.", 95.0, 2, 8, 0, false)
	await process_frame
	await process_frame
	_assert_compact_modal(hud.end_panel, GameHUD.END_PANEL_SIZE.y, "Ergebnis Zustand erschöpft")
	_check(
		hud.result_screen.find_child("Optional_reward", true, false) == null
		and hud.result_screen.find_child("Optional_unlock", true, false) == null
		and hud.result_screen.find_child("Optional_mastery", true, false) == null,
		"Leere Belohnungs-, Freischaltungs- und Meisterschaftszeilen reservieren im Ergebnis keinen Platz"
	)

	var stats := PlayerStats.new()
	# Exercise the dense, late-run form of the character sheet. A sparse
	# baseline would not catch collisions or accidental scrolling once optional
	# treatment and ability rows are present.
	stats.configure_prepared_treatment(TreatmentDefinition.catalog()[&"treatment_precision"])
	stats.therapy_projectiles = 2
	stats.therapy_max_hits = 3
	stats.immune_level = 2
	stats.support_level = 2
	stats.prepared_abilities.assign([
		AbilityDefinition.catalog()[&"ability_focus_field"],
		AbilityDefinition.catalog()[&"ability_emergency_support"],
	])
	var state := RunState.new()
	state.reset(ContentCatalog.create_run_config(ContentCatalog.level_definitions()[1], true))
	hud.update_run_stats(stats, state)
	hud.set_run_stats_visibility(true)
	hud.show_running_hud()
	await process_frame
	var run_stat_rows := hud.run_hud_screen.stat_rows()
	_check(hud.run_hud_screen.run_stats_strip().visible and not run_stat_rows.is_empty(), "Optionale Charakterwerte erscheinen oben rechts")
	var has_treatment_power := false
	for row in run_stat_rows:
		var accessible_text := String(row.get_meta(&"alveolus_accessible_name", ""))
		if accessible_text.contains("Behandlungswirkung") and accessible_text.contains("18"):
			has_treatment_power = true
	_check(has_treatment_power, "HUD-Anzeige zeigt echte dynamische Werte")
	_check(not hud.run_hud_screen.run_stats_strip().is_class("Panel"), "Die Runstatistik besitzt keine eigene Hintergrundkachel")
	_check(hud.run_hud_screen.run_stats_strip().mouse_filter == Control.MOUSE_FILTER_IGNORE, "Die Runstatistik blockiert keine Ziele im Spiel")
	_check(run_stat_rows.size() <= 5, "Die Runstatistik bleibt auf höchstens fünf Werte begrenzt")
	_check(hud.run_hud_screen.run_stats_strip() is HFlowContainer and hud.run_hud_screen.run_stats_strip().get_meta(&"alveolus_component", &"") == &"transparent_run_stats", "Die Runstatistik verwendet ein flaches transparentes Statband")
	_check(hud.run_hud_screen.run_stats_strip().get_global_rect().position.x >= hud.timer_panel.get_global_rect().end.x, "Das Statband beginnt erst rechts neben dem Timer")
	var previous_row: Control = null
	for row in run_stat_rows:
		_check(row.is_visible_in_tree(), "Jeder präsentierte Runwert ist tatsächlich sichtbar")
		_check(row.get_child_count() == 2, "Eine Statistikzeile enthält ausschließlich Icon und Wert")
		_check(row.get_child(0) is SimpleIcon and row.get_child(1) is Label, "Icon und Wert besitzen eine eindeutige Reihenfolge")
		if previous_row != null:
			_check(row.position.x > previous_row.position.x and is_equal_approx(row.position.y, previous_row.position.y), "Werte füllen das breite Statband zuerst horizontal")
		previous_row = row
	# Force the reusable strip into a genuinely constrained width. Target
	# resolutions normally still expose the 1280×720 design canvas, while the
	# FlowContainer must nevertheless wrap correctly if future HUD elements use
	# part of its available band.
	hud.run_stats_panel.set_anchor(SIDE_LEFT, 0.0)
	hud.run_stats_panel.set_anchor(SIDE_RIGHT, 0.0)
	hud.run_stats_panel.offset_left = 0.0
	hud.run_stats_panel.offset_right = 250.0
	await process_frame
	await process_frame
	var wrapped_rows := {}
	for row in hud.run_hud_screen.stat_rows():
		wrapped_rows[roundi(row.position.y)] = true
	_check(wrapped_rows.size() == 2, "Bei begrenztem Platz beginnt das Statband genau eine zweite Zeile")
	hud._apply_ui_scale()
	await process_frame
	hud.show_pause(false, stats, state)
	_check(not _contains_text(hud.pause_overlay, "RUNMENÜ"), "Das Pausemenü wiederholt keinen überflüssigen Runmenü-Obertitel")
	_check(hud.pause_screen.current_mode() == PauseOverlay.Mode.MENU, "Das PauseOverlay öffnet im expliziten Menümodus")
	_check(hud.pause_screen.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and not hud.pause_screen.body_scroll().get_v_scroll_bar().visible, "Alle Pausenaktionen sind ohne unnötiges Scrollen sichtbar")
	hud._show_pause_stats()
	await process_frame
	await process_frame
	_check(hud.is_pause_stats_open() and hud.pause_screen.current_mode() == PauseOverlay.Mode.STATS, "Charakterwerte-Submenü öffnet als expliziter Modus innerhalb der Pause")
	var pause_stats_grid := hud.pause_screen.stats_grid()
	var pause_stats_scroll := hud.pause_screen.body_scroll()
	var pause_stat_rows := hud.pause_screen.stat_rows()
	_check(pause_stats_grid.columns == 2, "Charakterwerte verwenden bei 1280 × 720 exakt zwei Wertspalten")
	var expected_stat_rows := stats.stat_rows(state.stability, state.max_stability, TherapyAvatar.MOVE_SPEED).size()
	_check(pause_stat_rows.size() == expected_stat_rows and pause_stats_grid.get_child_count() == expected_stat_rows and expected_stat_rows > 13, "Alle Basis- und optionalen Charakterwerte erscheinen als einzelne sichtbare Zeilen")
	var value_right_edges := {}
	var previous_rows := {}
	for row_index in range(pause_stat_rows.size()):
		var stat_row := pause_stat_rows[row_index]
		_check(stat_row.has_meta(&"stat_group") and stat_row.is_visible_in_tree(), "Jeder Charakterwert ist eine sichtbare StatRow statt einer Gruppenkarte")
		var marker := stat_row.find_child("StatIcon", true, false) as SimpleIcon
		var caption := stat_row.find_child("StatLabel", true, false) as Label
		var value := stat_row.find_child("StatValue", true, false) as Label
		_check(marker != null and caption != null and value != null, "Jede StatRow besitzt Icon, Label und rechtsbündigen Value")
		if marker == null or caption == null or value == null:
			continue
		_check(value.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Jeder Charakterwert ist am rechten Spaltenrand ausgerichtet")
		var marker_rect := marker.get_global_rect()
		var caption_rect := caption.get_global_rect()
		var value_rect := value.get_global_rect()
		_check(marker_rect.end.x <= caption_rect.position.x + 0.5 and caption_rect.end.x <= value_rect.position.x + 0.5, "Icon, Label und Value einer StatRow überlappen einander nicht")
		var column_index := row_index % pause_stats_grid.columns
		if previous_rows.has(column_index):
			var previous_stat_row := previous_rows[column_index] as PanelContainer
			_check(previous_stat_row.get_global_rect().end.y <= stat_row.get_global_rect().position.y + 0.5, "Charakterwertzeilen überlappen vertikal nicht")
		previous_rows[column_index] = stat_row
		if value_right_edges.has(column_index):
			_check(is_equal_approx(float(value_right_edges[column_index]), value_rect.end.x), "Alle Value-Endkanten einer Charakterwertspalte sind bündig")
		else:
			value_right_edges[column_index] = value_rect.end.x
	_check(
		pause_stats_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and not pause_stats_scroll.get_v_scroll_bar().visible,
		"Charakterwerte benötigen bei 1280 × 720 keinen Scrollbalken (Inhalt %.1f, Fläche %.1f, Modus %d)" % [pause_stats_grid.get_combined_minimum_size().y, pause_stats_scroll.size.y, pause_stats_scroll.vertical_scroll_mode]
	)
	hud.return_to_pause_menu()
	_check(hud.pause_screen.visible and hud.pause_screen.current_mode() == PauseOverlay.Mode.MENU, "Zurück führt in den Menümodus der Pause statt in den Run")

	var visibility_events: Array[bool] = []
	hud.run_stats_visibility_changed.connect(func(enabled: bool) -> void: visibility_events.append(enabled))
	hud._on_run_stats_toggle(false)
	_check(visibility_events == [false], "Anzeigeeinstellung meldet Änderungen an den Spielstand")
	_check(not hud.run_stats_panel.visible, "Deaktivierte Anzeige verschwindet sofort")

	hud.show_upgrade_choices(ContentCatalog.upgrade_definitions().slice(0, 3), stats, false, false)
	await process_frame
	_check(hud.upgrade_panel != null and _has_scroll_ancestor(hud.upgrade_cards), "Ausbaukarten bleiben bei großer UI in einem scrollbaren Dialog")
	_check(hud.upgrade_panel.custom_minimum_size.y <= 240.0, "Ausbaudialog folgt ohne Zusatzbereiche seiner Inhaltshöhe")
	var upgrade_focus := get_root().gui_get_focus_owner()
	_check(upgrade_focus == hud.upgrade_screen.neutral_focus_target(), "Mausöffnung parkt den Fokus auf dem neutralen Modalsentinel statt ungefragt einen Ausbau zu markieren")
	_check(hud.upgrade_screen.cards().all(func(card: Button) -> bool: return card != upgrade_focus), "Mausöffnung fokussiert keine Ausbaukarte vor der Auswahl")
	for card in hud.upgrade_cards.get_children():
		_check((card as Control).scale.is_equal_approx(Vector2.ONE), "Ausbaukarten wachsen nicht über ihre Rasterzelle")
		var has_left_strip := false
		for child in card.get_children():
			if child is ColorRect:
				has_left_strip = true
		_check(not has_left_strip, "Ausbaukarten besitzen keinen linken Farbbalken")
	hud.show_upgrade_choices(ContentCatalog.upgrade_definitions().slice(0, 1), stats, false, false)
	await process_frame
	var single_regular_upgrade := hud.upgrade_cards.get_child(0) as Control
	_check(is_equal_approx(single_regular_upgrade.custom_minimum_size.y, UpgradeOverlay.CARD_HEIGHT), "Eine einzelne reguläre Ausbauoption wird nicht fälschlich als Introkarte klassifiziert")
	hud.show_abort_confirmation()
	await process_frame
	_check(hud.abort_panel.custom_minimum_size.y <= GameHUD.ABORT_PANEL_SIZE.y, "Abbruchdialog reserviert keinen leeren unteren Bereich")
	var scaled_settings := UISettingsState.new()
	scaled_settings.ui_scale = 2.0
	hud.configure_ui_settings(scaled_settings)
	await process_frame
	_check(hud.upgrade_cards.columns == 1, "Der Ausbau-Dialog wechselt bei 200 Prozent in eine scrollbare Einspaltenansicht")
	_check(hud.upgrade_panel.custom_minimum_size.x <= hud.root.size.x, "Der Ausbau-Dialog bleibt bei 200 Prozent innerhalb der logischen Breite")
	_check(hud.upgrade_panel.custom_minimum_size.y <= hud.root.size.y, "Der Ausbau-Dialog bleibt bei 200 Prozent innerhalb der logischen Höhe")

	hud.queue_free()
	await process_frame
	if failures.is_empty():
		print("ALVEOLUS_UI_POLISH_OK assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_icon_assets() -> void:
	var sample := VisualAssetCatalog.gameplay_sprite(&"analysis_pickup")
	_check(sample != null, "Probe besitzt ein eigenes Laufzeitasset")
	if sample != null:
		_check(not sample is AtlasTexture, "Probe stammt nicht mehr aus dem alten Gameplayatlas")
		_assert_normalized_texture(sample, "Probe")
		var batch_sample := VisualAssetCatalog.gameplay_batch_texture(&"analysis_pickup")
		_check(batch_sample != null and batch_sample.get_size() == sample.get_size(), "Probe nutzt für Einzel- und Batchdarstellung denselben Bildrahmen")

	var imported := VisualAssetCatalog.icon(&"information")
	_check(imported != null, "Kenney-Chromeicon ist verfügbar")
	if imported != null:
		_assert_normalized_texture(imported, "Kenney-Chromeicon")
	var immune := VisualAssetCatalog.gameplay_sprite(&"immune_cell")
	_check(immune != null, "Abwehrzelle besitzt einen normalisierten Rasterausschnitt")
	if immune != null:
		_assert_normalized_texture(immune, "Abwehrzelle")

	var icon := SimpleIcon.new()
	icon.configure(&"finding", AlveolusVisualTheme.COBALT)
	_check(not icon.framed, "SimpleIcon rendert standardmäßig nur die Glyph")
	icon.set_framed(true)
	_check(icon.framed, "SimpleIcon kann den Kompatibilitätsrahmen explizit aktivieren")
	icon.free()

	var required_ids: Array[StringName] = [
		&"analysis_pickup", &"reaction", &"finding", &"finding_progress", &"plan", &"components",
		&"ability", &"passive", &"reserve", &"antibiotic", &"immune", &"support",
		&"practice", &"research", &"levels", &"lexicon", &"settings",
	]
	for definition in ContentCatalog.research_definitions():
		required_ids.append(definition.id)
	for module_id in ContentCatalog.loadout_module_definitions():
		required_ids.append(StringName(module_id))
	for icon_id in required_ids:
		_check(SimpleIcon.supports(icon_id), "Produktionsicon %s besitzt eine eindeutige Zuordnung" % icon_id)

func _assert_normalized_texture(texture: Texture2D, label: String) -> void:
	var image := texture.get_image()
	_check(image != null and not image.is_empty(), "%s besitzt lesbare Pixeldaten" % label)
	if image == null or image.is_empty():
		return
	_check(image.get_width() == image.get_height(), "%s liegt auf einem quadratischen Bildrahmen" % label)
	var used := image.get_used_rect()
	_check(used.size != Vector2i.ZERO, "%s besitzt sichtbare Pixel" % label)
	if used.size == Vector2i.ZERO:
		return
	var left := used.position.x
	var top := used.position.y
	var right := image.get_width() - used.end.x
	var bottom := image.get_height() - used.end.y
	_check(absi(left - right) <= 2 and absi(top - bottom) <= 2, "%s ist anhand sichtbarer Pixel optisch zentriert" % label)
	var safe_margin := maxi(1, floori(float(image.get_width()) * 0.05))
	_check(mini(mini(left, right), mini(top, bottom)) >= safe_margin, "%s wahrt transparentes Sicherheitspadding" % label)

func _contains_text(node: Node, fragment: String) -> bool:
	if node is Label and (node as Label).text.contains(fragment):
		return true
	if node is Button and (node as Button).text.contains(fragment):
		return true
	for child in node.get_children():
		if _contains_text(child, fragment):
			return true
	return false

func _has_scroll_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current is ScrollContainer:
			return true
		current = current.get_parent()
	return false

func _has_focusable_descendant(node: Node) -> bool:
	for candidate in node.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control != null and control.focus_mode != Control.FOCUS_NONE:
			if not control is BaseButton or not (control as BaseButton).disabled:
				return true
	return false

func _has_ancestor_type(node: Node, class_name_value: String) -> bool:
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor.get_class() == class_name_value:
			return true
		ancestor = ancestor.get_parent()
	return false

func _find_label_exact(root_node: Node, text_value: String) -> Label:
	for candidate in root_node.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label != null and label.text == text_value:
			return label
	return null

func _panel_container_ancestor(node: Node) -> PanelContainer:
	var ancestor := node.get_parent() if node != null else null
	while ancestor != null:
		if ancestor is PanelContainer:
			return ancestor as PanelContainer
		ancestor = ancestor.get_parent()
	return null

func _assert_compact_modal(panel: Control, maximum_height: float, label: String) -> void:
	_check(panel != null and panel.custom_minimum_size.y <= maximum_height + 0.5, "%s-Dialog bleibt auf seine kompakte Inhaltshöhe begrenzt" % label)
	if panel == null:
		return
	_check(not _has_empty_vertical_expander(panel), "%s-Dialog enthält keinen leeren Expand-Spacer am unteren Rand" % label)
	var scrolls: Array[Node] = panel.find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		var scroll := scrolls[0] as ScrollContainer
		var content := scroll.get_child(0) as Control if scroll != null and scroll.get_child_count() > 0 else null
		if scroll != null and content != null:
			var lower_blank := maxf(0.0, scroll.size.y - content.size.y)
			_check(lower_blank <= 72.0, "%s-Dialog reserviert keinen auffälligen ungenutzten Leerraum unter seinem Inhalt (Scroll %.1f, Inhalt %.1f, Differenz %.1f)" % [label, scroll.size.y, content.size.y, lower_blank])

func _has_empty_vertical_expander(root_node: Node) -> bool:
	for candidate in root_node.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control == null or not control.visible or control.get_class() != "Control":
			continue
		if control.get_child_count() == 0 and (control.size_flags_vertical & Control.SIZE_EXPAND) != 0 and control.custom_minimum_size == Vector2.ZERO:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
