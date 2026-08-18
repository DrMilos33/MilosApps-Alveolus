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
	_check(hud.settings_master_slider != null and hud.settings_scale_option == null and hud.settings_glyph_option == null, "Einstellungen bieten Audio und verbleibende Anzeigeoptionen ohne ausgeblendete Größen- oder Moduscontrols")
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
	for level in levels:
		var level_button := hud.level_buttons[level.id] as Button
		var placeholder: PanelContainer = null
		var question: Label = null
		if level_button != null:
			placeholder = level_button.find_child("CasePlaceholder", true, false) as PanelContainer
			question = level_button.find_child("QuestionMark", true, false) as Label
		_check(level_button != null and level_button.find_child("CaseIllustration", true, false) == null and placeholder != null and question != null and question.text == "?", "Fallkarten ersetzen dekorative Icons durch einen klaren Fragezeichen-Platzhalter")
		_check(level_button != null and level_button.find_child("Title", true, false) != null and level_button.find_child("Status", true, false) != null, "Fallkarten tragen ihren Zustand über klare Text- und Kartenrollen")
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
	_check(meta.set_talent_active(&"treatment_damage_training", true), "Der Testzustand aktiviert die Revision-4-Wurzel des Behandlungsbaums")
	hud.show_research_tabs(meta, ContentCatalog.research_definitions(), TalentDefinition.definitions())
	await process_frame
	_check(hud.research_grid.columns == 4 and hud.research_grid.get_child_count() == 8, "Die acht aktiven Forschungen zeigen bei 1280 Pixeln vier kompakte Spalten")
	_check(hud.research_buy_buttons.has(&"movement_training") and SimpleIcon.supports(&"movement_training"), "Bewegungstraining besitzt eine zentrale, registrierte Bewegungsglyphe")
	for research_card in hud.research_grid.get_children():
		_check((research_card as Control).custom_minimum_size.y <= 76.0, "Forschungskarten überschreiten die kompakte Höhe nicht")
	hud._select_research_tab(&"talents")
	await process_frame
	_check(hud.talent_grid.get_child_count() == 1, "Talente zeigen den einen aktiven Behandlungsbaum")
	_check(hud.talent_buttons.size() == 4, "Alle vier Talente bleiben im Behandlungsbaum erreichbar")
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
	_check(talent_tree_count == 1 and talent_node_count == 4, "Der aktive Bereich besitzt einen echten verzweigten Behandlungsbaum")
	_check(talent_edge_count == 3, "Alle drei Abhängigkeiten bleiben als Baumverbindungen erhalten")
	_check(branch_accents.size() == 1, "Der Behandlungsbaum verwendet einen einheitlichen Astakzent")
	for talent_button in hud.talent_buttons.values():
		var node_button := talent_button as Button
		_check(node_button.custom_minimum_size.y <= TalentTreeBranch.NODE_HEIGHT, "Talentknoten bleiben auf die kompakte Baumhöhe begrenzt")
		_check(not _contains_text(node_button, "VERFÜGBAR") and not _contains_text(node_button, "AKTIV") and not _contains_text(node_button, "BRAUCHT"), "Talentknoten erklären ihren Zustand ohne wiederholte Statuswörter")
		_check(node_button.has_meta(&"item_state") and node_button.has_meta(&"item_interactive"), "Talentstatus bleibt semantisch prüfbar, obwohl er visuell über Farbe und Icon vermittelt wird")
	var active_talent := hud.talent_buttons[&"treatment_damage_training"] as Button
	var active_state_icon := active_talent.find_child("StateIcon", true, false) as SimpleIcon
	_check(active_talent.get_meta(&"item_state", &"") == &"active" and active_talent.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_TALENT_NODE and active_state_icon != null and active_state_icon.kind == &"check", "Aktive Talente werden durch Highlight und Check-Icon statt Statustext markiert")
	var available_talent := hud.talent_buttons[&"manual_treatment_aim"] as Button
	_check(available_talent.get_meta(&"item_state", &"") == &"available" and bool(available_talent.get_meta(&"item_interactive", false)), "Nach aktiver Wurzel sind die drei Revision-4-Kinder ohne künstliche Zwischenstufe verfügbar")
	_check(not hud.talent_buttons.has(&"piercing_return"), "Die reservierte Revision-3-ID piercing_return erscheint nicht mehr im aktiven Talentbaum")

	var finding_reactions: Array = [
		{"id": &"observe", "title": "Weiter beobachten", "description": "Befundfortschritt erhöhen."},
		{"id": &"stabilize", "title": "Stabilisieren", "description": "Kurzzeitig Leben schützen."},
		{"id": &"treat", "title": "Gezielt behandeln", "description": "Behandlung verstärken."},
	]
	hud.show_finding({
		"title": "Lokaler Herd",
		"medical_text": "Ein lokaler Entzündungsherd belastet das umliegende Gewebe.",
		"gameplay_text": "+2 Bakteriengruppen",
	}, finding_reactions)
	await process_frame
	await process_frame
	_assert_compact_modal(hud.finding_panel, 432.0, "Befund")
	_check(hud.finding_copy_grid.columns == 1 and hud.finding_copy_grid.get_meta(&"alveolus_component", &"") == &"finding_effect_line", "Befund zeigt nur eine kompakte mechanische Effektzeile")
	var finding_effect := hud.finding_copy_grid.get_child(0) as Label
	_check(finding_effect != null and finding_effect.text == "+2 Bakteriengruppen" and hud.finding_copy_grid.find_children("*", "PanelContainer", true, false).is_empty(), "Befund verzichtet auf medizinische und spielerische Erklärungskacheln")
	hud.show_end(levels[1], false, "Das Leben ist auf null gefallen.", 95.0, 2, 8, 20, false)
	hud.set_result_reward_presentations([
		RewardPresentation.research(20),
		RewardPresentation.experience(9),
	])
	await process_frame
	await process_frame
	_assert_compact_modal(hud.end_panel, GameHUD.END_PANEL_SIZE.y, "Ergebnis You suck")
	var failure_title := hud.result_screen.find_child("OutcomeTitle", true, false) as Label
	_check(failure_title != null and failure_title.text == "You suck", "Niederlage verwendet den verbindlichen Titel exakt")
	_check(
		hud.result_screen.find_child("Reason", true, false) == null
		and hud.result_screen.find_child("Detail", true, false) == null,
		"Niederlage zeigt weder Untertitel noch Grundtext"
	)
	var reward_strip := hud.result_screen.find_child("RewardStrip", true, false) as GridContainer
	var research_reward := hud.result_screen.find_child("Reward_research", true, false) as Control
	var reward_value := hud.result_screen.find_child("Optional_reward_Body", true, false) as Label
	_check(reward_strip != null and reward_strip.columns == 4 and reward_strip.get_child_count() == 4, "Das Ergebnis zeigt Forschung plus exakt drei angeforderte Platzhalter")
	_check(research_reward != null and reward_value != null and reward_value.text == "+20" and research_reward.get_meta(&"alveolus_accessible_name", "") == "Forschung: +20", "Die Forschung wird ausschließlich als Icon mit reinem Wert und Accessible Name dargestellt")
	_check(hud.result_screen.find_child("Reward_experience", true, false) == null, "Die additive Erfahrungspräsentation erzeugt bewusst keine fünfte Ergebnisspalte")
	_check(hud.result_screen.find_child("Optional_unlock", true, false) == null and hud.result_screen.find_child("Optional_mastery", true, false) == null, "Leere Freischaltungs- und Meisterschaftszeilen reservieren keinen Platz")

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
	hud.update_defeat_research_reward(23)
	await process_frame
	var run_stat_rows := hud.run_hud_screen.stat_rows()
	var expected_run_stat_ids: Array[StringName] = [
		&"defense", &"movement_speed", &"life_regeneration", &"experience_gain",
		&"resistance_fire", &"resistance_water", &"resistance_earth", &"resistance_wind",
	]
	var actual_run_stat_ids: Array[StringName] = []
	for row in run_stat_rows:
		actual_run_stat_ids.append(StringName(row.get_meta(&"stat_id", &"")))
		var accessible_text := String(row.get_meta(&"alveolus_accessible_name", ""))
		_check(not accessible_text.contains("Behandlung") and not accessible_text.contains("Fokusfeld") and not accessible_text.contains("Notfallhilfe"), "Das Run-HUD hält Behandlungs- und Fähigkeitswerte aus dem Grundwertband heraus")
	_check(hud.run_hud_screen.run_stats_strip().visible and actual_run_stat_ids == expected_run_stat_ids, "Oben rechts erscheinen ausschließlich die acht stabilen Grundwerte")
	_check(not hud.run_hud_screen.run_stats_strip().is_class("Panel"), "Die Runstatistik besitzt keine eigene Hintergrundkachel")
	_check(hud.run_hud_screen.run_stats_strip().mouse_filter == Control.MOUSE_FILTER_IGNORE, "Die Runstatistik blockiert keine Ziele im Spiel")
	_check(run_stat_rows.size() == 8, "Die Runstatistik zeigt genau die vier Kernwerte und vier Typresistenzen")
	_check(hud.run_hud_screen.run_stats_strip() is HFlowContainer and hud.run_hud_screen.run_stats_strip().get_meta(&"alveolus_component", &"") == &"transparent_run_stats", "Die Runstatistik verwendet ein flaches transparentes Statband")
	var defeat_reward_panel := hud.run_hud_screen.defeat_research_reward_panel()
	_check(
		defeat_reward_panel.visible
		and hud.run_hud_screen.defeat_research_reward_icon().kind == &"research"
		and hud.run_hud_screen.defeat_research_reward_value_label().text == "+23"
		and String(defeat_reward_panel.get_meta(&"alveolus_accessible_name", "")).contains("23"),
		"Die Niederlagenprognose steht als zugängliches Forschungssymbol mit Zahl links vom Timer"
	)
	_check(defeat_reward_panel.get_global_rect().end.x <= hud.timer_panel.get_global_rect().position.x + 0.5, "Forschungsprognose und Rundendauer überlappen nicht")
	var stat_strip_rect := hud.run_hud_screen.run_stats_strip().get_global_rect()
	var timer_rect := hud.timer_panel.get_global_rect()
	var hud_rect := hud.run_hud_screen.get_global_rect()
	_check(stat_strip_rect.position.y >= timer_rect.end.y - 0.5 and stat_strip_rect.end.x <= hud_rect.end.x + 0.5, "Das transparente Statband sitzt kollisionsfrei rechts unter der Rundendauer")
	var previous_row: Control = null
	var stat_row_populations: Dictionary = {}
	var stat_row_order: Array[int] = []
	for row_index in range(run_stat_rows.size()):
		var row := run_stat_rows[row_index]
		var row_level := roundi(row.global_position.y)
		if not stat_row_populations.has(row_level):
			stat_row_populations[row_level] = 0
			stat_row_order.append(row_level)
		stat_row_populations[row_level] = int(stat_row_populations[row_level]) + 1
		_check(row.is_visible_in_tree(), "Jeder präsentierte Runwert ist tatsächlich sichtbar")
		_check(row.get_child_count() == 2, "Eine Statistikzeile enthält ausschließlich Icon und Wert")
		_check(row.get_child(0) is SimpleIcon and row.get_child(1) is Label, "Icon und Wert besitzen eine eindeutige Reihenfolge")
		if row_index > 0 and row_index < 4:
			_check(previous_row != null and row.position.x > previous_row.position.x and is_equal_approx(row.position.y, previous_row.position.y), "Die ersten vier Werte füllen die obere Reihe horizontal")
		previous_row = row
	var stat_row_counts: Array[int] = []
	for row_level in stat_row_order:
		stat_row_counts.append(int(stat_row_populations[row_level]))
	_check(stat_row_counts == [4, 4], "Kampfgrundwerte stehen rechts unter der Zeit in zwei vollständigen Viererreihen")
	# Force the reusable strip into a genuinely constrained width. Target
	# resolutions normally still expose the 1280×720 design canvas, while the
	# FlowContainer must nevertheless wrap correctly if future HUD elements use
	# part of its available band.
	hud.run_stats_panel.set_anchor(SIDE_LEFT, 0.0)
	hud.run_stats_panel.set_anchor(SIDE_RIGHT, 0.0)
	hud.run_stats_panel.offset_left = 0.0
	hud.run_stats_panel.offset_right = 280.0
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
	var pause_stat_sections := hud.pause_screen.stat_sections()
	var pause_stat_rows := hud.pause_screen.stat_rows()
	_check(pause_stats_grid.columns == 1, "Die Accordion-Abschnitte bleiben in einer klaren vertikalen Reihenfolge")
	var expected_section_ids: Array[StringName] = [
		&"general",
		&"treatment:treatment_precision",
		&"ability:0:ability_focus_field",
		&"ability:1:ability_emergency_support",
	]
	var actual_section_ids: Array[StringName] = []
	for section_panel in pause_stat_sections:
		var stable_section_id := StringName(section_panel.get_meta(&"section_id", &""))
		actual_section_ids.append(stable_section_id)
		_check(section_panel.get_meta(&"alveolus_component", &"") == &"stat_accordion_section", "Jede Charakterwertegruppe verwendet die gemeinsame Accordion-Sektion")
		_check(hud.pause_screen.section_header(stable_section_id) != null, "Jede Charakterwertegruppe besitzt eine fokussierbare Abschnittsüberschrift")
		_check(hud.pause_screen.section_body(stable_section_id).columns == 2, "Geöffnete Abschnittswerte nutzen bei 1280 × 720 zwei kompakte Spalten")
	_check(actual_section_ids == expected_section_ids and pause_stats_grid.get_child_count() == expected_section_ids.size(), "Grundwerte, Behandlung und beide belegten Aktivslots erscheinen als vier stabile Abschnitte")
	_check(hud.pause_screen.is_section_expanded(&"general"), "Grundwerte sind beim ersten Öffnen sichtbar")
	_check(not hud.pause_screen.is_section_expanded(&"treatment:treatment_precision") and not hud.pause_screen.is_section_expanded(&"ability:0:ability_focus_field") and not hud.pause_screen.is_section_expanded(&"ability:1:ability_emergency_support"), "Behandlung und Aktivslots beginnen platzsparend eingeklappt")
	var expected_stat_rows := 0
	for section in stats.stat_sections(state.stability, state.max_stability):
		expected_stat_rows += section.row_count()
	_check(pause_stat_rows.size() == expected_stat_rows and expected_stat_rows > 13, "Alle Werte liegen genau einmal in ihren stabilen Abschnitten")
	var value_right_edges := {}
	var previous_rows := {}
	for row_index in range(pause_stat_rows.size()):
		var stat_row := pause_stat_rows[row_index]
		_check(stat_row.has_meta(&"stat_group") and stat_row.has_meta(&"stat_id"), "Jeder Charakterwert besitzt stabile Abschnitts- und Zeilen-IDs")
		var marker := stat_row.find_child("StatIcon", true, false) as SimpleIcon
		var caption := stat_row.find_child("StatLabel", true, false) as Label
		var value := stat_row.find_child("StatValue", true, false) as Label
		_check(marker != null and caption != null and value != null, "Jede StatRow besitzt Icon, Label und rechtsbündigen Value")
		if marker == null or caption == null or value == null:
			continue
		_check(value.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Jeder Charakterwert ist am rechten Spaltenrand ausgerichtet")
		# Eingeklappte Accordion-Abschnitte bleiben als stabile Controls erhalten,
		# nehmen aber bewusst nicht am Layout teil. Geometrie wird daher nur für
		# die tatsächlich sichtbaren Grundwerte geprüft.
		if not stat_row.is_visible_in_tree():
			continue
		var marker_rect := marker.get_global_rect()
		var caption_rect := caption.get_global_rect()
		var value_rect := value.get_global_rect()
		_check(marker_rect.end.x <= caption_rect.position.x + 0.5 and caption_rect.end.x <= value_rect.position.x + 0.5, "Icon, Label und Value einer StatRow überlappen einander nicht")
		var section_id := StringName(stat_row.get_meta(&"stat_group", &""))
		var section_body := hud.pause_screen.section_body(section_id)
		var column_index := stat_row.get_index() % maxi(1, section_body.columns)
		if previous_rows.has(column_index):
			var previous_stat_row := previous_rows[column_index] as PanelContainer
			if previous_stat_row.is_visible_in_tree() and stat_row.is_visible_in_tree():
				_check(previous_stat_row.get_global_rect().end.y <= stat_row.get_global_rect().position.y + 0.5, "Sichtbare Charakterwertzeilen überlappen vertikal nicht")
		previous_rows[column_index] = stat_row
		var value_column_key := "%s:%d" % [section_id, column_index]
		if value_right_edges.has(value_column_key):
			_check(is_equal_approx(float(value_right_edges[value_column_key]), value_rect.end.x), "Alle Value-Endkanten einer Abschnittsspalte sind bündig")
		else:
			value_right_edges[value_column_key] = value_rect.end.x
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

	var upgrade_by_id: Dictionary = {}
	for definition in ContentCatalog.upgrade_definitions():
		upgrade_by_id[definition.id] = definition
	var heading_upgrade_ids: Array[StringName] = [&"potency", &"burst_effect", &"line_effect", &"mobility"]
	var heading_upgrades: Array[UpgradeDefinition] = []
	for upgrade_id in heading_upgrade_ids:
		heading_upgrades.append(upgrade_by_id[upgrade_id] as UpgradeDefinition)
	hud.show_upgrade_choices(heading_upgrades, stats, false, false)
	await process_frame
	var expected_upgrade_headings := {
		&"potency": "Impuls",
		&"burst_effect": "idk name stoß",
		&"line_effect": "Fetter lazer",
		&"mobility": "Geschwindigkeit",
	}
	for upgrade_card in hud.upgrade_cards.get_children():
		var upgrade_id := StringName((upgrade_card as Control).get_meta(&"upgrade_id", &""))
		var upgrade_title := (upgrade_card as Control).find_child("UpgradeTitle", true, false) as Label
		_check(upgrade_title != null and upgrade_title.text == String(expected_upgrade_headings.get(upgrade_id, "")), "GameHUD löst die Ausbauüberschrift %s auf den betroffenen Komponentenname auf" % upgrade_id)
	var movement_upgrades: Array[UpgradeDefinition] = [upgrade_by_id[&"mobility"] as UpgradeDefinition]
	hud.show_upgrade_choices(movement_upgrades, stats, false, false)
	await process_frame
	var movement_card := hud.upgrade_cards.get_child(0) as Control
	var movement_title := movement_card.find_child("UpgradeTitle", true, false) as Label
	var movement_icon := movement_card.find_child("UpgradeIcon", true, false) as SimpleIcon
	_check(movement_title != null and movement_title.text == "Geschwindigkeit", "Der Geschwindigkeitsausbau verwendet den verbindlichen Komponentennamen")
	_check(movement_icon != null and movement_icon.kind == &"movement_training", "Der Bewegungsausbau verwendet dieselbe semantische Trainingsglyphe wie die Forschung")
	var presentation_upgrades: Array[UpgradeDefinition] = [
		upgrade_by_id[&"rhythm"] as UpgradeDefinition,
		upgrade_by_id[&"neutrophils"] as UpgradeDefinition,
		upgrade_by_id[&"defense_cell_radius"] as UpgradeDefinition,
	]
	hud.show_upgrade_choices(presentation_upgrades, stats, false, false)
	await process_frame
	var rhythm_card := hud.upgrade_cards.get_child(0) as Control
	var rhythm_row := rhythm_card.find_child("UpgradeValue_*", true, false) as RichTextLabel
	_check(rhythm_row != null and String(rhythm_row.get_meta(&"semantic_before", "")) == "1,22/s" and String(rhythm_row.get_meta(&"semantic_value", "")) == "1,45/s", "Behandlungstempo erscheint als datenformatierte Rate ohne Intervallcopy")
	var defense_cell_card := hud.upgrade_cards.get_child(1) as Control
	var defense_cell_icon := defense_cell_card.find_child("UpgradeIcon", true, false) as SimpleIcon
	var defense_cell_comparison := defense_cell_card.find_child("UpgradeComparison", true, false) as RichTextLabel
	_check(defense_cell_icon != null and defense_cell_icon.kind == &"neutrophil_orbit", "Abwehrzellen verwenden das datengetriebene Komponentenicon")
	var defense_cell_copy := defense_cell_comparison.get_parsed_text() if defense_cell_comparison != null else "<fehlend>"
	_check(
		defense_cell_comparison != null \
			and defense_cell_copy.contains("10/s") \
			and defense_cell_copy.contains("Radius 4") \
			and not defense_cell_copy.contains("Intervall") \
			and not defense_cell_copy.contains("Stufe") \
			and not defense_cell_copy.contains("px"),
		"Abwehrzellen zeigen Rate und Radius ohne interne Einheiten (sichtbar: %s)" % defense_cell_copy
	)
	var radius_card := hud.upgrade_cards.get_child(2) as Control
	var radius_row := radius_card.find_child("UpgradeValue_*", true, false) as RichTextLabel
	_check(radius_row != null and radius_row.get_meta(&"semantic_label", "") == "Radius" and String(radius_row.get_meta(&"semantic_before", "")) == "4", "Radiusausbauten besitzen eine semantische Zeile mit nackter Stufenzahl")

	var upgrade_options := ContentCatalog.upgrade_definitions().slice(0, 3)
	hud.show_upgrade_choices(upgrade_options, stats, false, false)
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
	var first_upgrade_preview := stats.preview_upgrade(upgrade_options[0])
	var first_upgrade_card := hud.upgrade_cards.get_child(0) as Control
	var first_upgrade_comparison := first_upgrade_card.find_child("UpgradeValue_*", true, false) as RichTextLabel
	if first_upgrade_comparison == null:
		first_upgrade_comparison = first_upgrade_card.find_child("UpgradeComparison", true, false) as RichTextLabel
	var first_upgrade_after := String(first_upgrade_comparison.get_meta(
		&"semantic_value",
		first_upgrade_comparison.get_meta(&"semantic_after", "")
	)) if first_upgrade_comparison != null else ""
	_check(
		first_upgrade_comparison != null \
			and String(first_upgrade_comparison.get_meta(&"semantic_before", "")) == first_upgrade_preview.before_value \
			and first_upgrade_after == first_upgrade_preview.after_value,
		"Der GameHUD-Presenter übernimmt die strukturierten Ausbauwerte ohne UI-Parsing"
	)
	hud.show_upgrade_choices(ContentCatalog.upgrade_definitions().slice(0, 1), stats, false, false)
	await process_frame
	var single_regular_upgrade := hud.upgrade_cards.get_child(0) as Control
	_check(is_equal_approx(single_regular_upgrade.custom_minimum_size.y, UpgradeOverlay.CARD_HEIGHT), "Eine einzelne reguläre Ausbauoption wird nicht fälschlich als Introkarte klassifiziert")
	hud.show_abort_confirmation()
	await process_frame
	_check(hud.abort_panel.custom_minimum_size.y <= GameHUD.ABORT_PANEL_SIZE.y, "Abbruchdialog reserviert keinen leeren unteren Bereich")

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
