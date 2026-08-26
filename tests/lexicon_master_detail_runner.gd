extends SceneTree

class RelatedTermPresentationStub:
	extends RefCounted

	var id: StringName
	var display_name: String
	var explanation: String
	var meaning: String
	var icon_id: StringName

	func _init(id_value: StringName, display_name_value: String, explanation_value: String, icon_value: StringName) -> void:
		id = id_value
		display_name = display_name_value
		explanation = explanation_value
		meaning = explanation_value
		icon_id = icon_value


class RelatedLexiconViewModelStub:
	extends LexiconEntryViewModel

	var _related_presentations: Array = []

	func related_term_presentations() -> Array:
		return _related_presentations.duplicate()


var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var scene := load("res://scenes/ui/lexicon_master_detail.tscn") as PackedScene
	var lexicon := scene.instantiate() as LexiconMasterDetail
	lexicon.configure(null, [&"pneumococcus", &"analysis_pickup", &"patient_stability"])
	get_root().add_child(lexicon)
	await process_frame
	await process_frame

	_test_master_detail_structure(lexicon)
	await _test_dense_grid_overview(lexicon)
	await _test_related_term_chips(lexicon)
	_test_lock_and_selection(lexicon)
	await _test_mouse_and_focus_navigation(lexicon)
	await _test_responsive_detail_density(lexicon)
	await _test_layout_sizes(lexicon)
	await _test_game_hud_embedding()

	lexicon.queue_free()
	await process_frame
	if failures.is_empty():
		print("ALVEOLUS_LEXICON_MASTER_DETAIL_OK assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_master_detail_structure(lexicon: LexiconMasterDetail) -> void:
	_check(lexicon.theme != null, "Die eigenständig geladene Lexikonszene erhält ein lokales Fallback-Theme")
	_check(lexicon.category_buttons.size() == 5, "Fünf übergeordnete Kategorien einschließlich Fähigkeiten sind sichtbar")
	_check(lexicon.category_bar.columns == 5, "Die fünf kompakten Lexikonreiter stehen am breiten Inhaltsrand in einer Reihe")
	var surface := lexicon.get_node("Surface") as PanelContainer
	_check(surface != null and surface.theme_type_variation == AlveolusVisualTheme.TYPE_PAGE_CANVAS, "Die Lexikonbühne verwendet die zentrale PageCanvas-Rolle")
	_check(lexicon.overview_toolbar.theme_type_variation == AlveolusVisualTheme.TYPE_DOCUMENT_INSET, "Suche und Fortschritt verwenden eine gemeinsame semantische Dokumentfläche")
	_check(lexicon.list_panel.theme_type_variation == AlveolusVisualTheme.TYPE_DOCUMENT_INSET, "Das Eintragsraster verwendet die zentrale Dokumentfläche")
	_check(lexicon.detail_panel.theme_type_variation == AlveolusVisualTheme.TYPE_ACTION_CARD, "Das Detail verwendet die zentrale Aktionskartenfläche")
	_check(lexicon.category_bar.get_parent() == lexicon.overview_toolbar.get_parent() and lexicon.overview_toolbar.get_parent() == lexicon.content_row.get_parent(), "Kategorien, gemeinsame Suchzeile und Inhaltsstufe besitzen eine klare direkte Reihenfolge")
	_check(lexicon.category_bar.get_index() < lexicon.overview_toolbar.get_index() and lexicon.overview_toolbar.get_index() < lexicon.content_row.get_index(), "Kategorien stehen direkt über Suche/Fortschritt und Raster")
	for category_button in lexicon.category_buttons.values():
		_check((category_button as Button).get_meta(&"alveolus_component", &"") == &"segmented_tab", "Jede Lexikonkategorie verwendet die zentrale Tab-Komponente")
	_check(lexicon.entry_filter.get_parent() == lexicon.entry_count_label.get_parent() and lexicon.entry_filter.get_parent() == lexicon.toolbar_row, "Suche und Fortschritt teilen genau eine kompakte Zeile")
	_check(lexicon.entry_filter.custom_minimum_size.y >= 44.0, "Das Suchfeld wahrt die zentrale Mindestzielhöhe")
	_check(lexicon.entry_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Das Eintragsraster scrollt nur vertikal")
	_check(lexicon.detail_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Detailbereich scrollt nur vertikal")
	_check(lexicon.page_scroll != null and lexicon.page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Die kompakte Gesamtbühne kann niemals horizontal aus dem Viewport laufen")
	_check(lexicon.page_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Breites Lexikon benötigt keinen zusätzlichen vertikalen Seitenscroll")
	_check(lexicon.entry_list is GridContainer and lexicon.entry_list.columns == LexiconMasterDetail.GRID_COLUMNS_WIDE, "Die breite Übersicht verwendet ein sechsspaltiges Kachelraster")
	_check(lexicon.entry_buttons.size() == 5, "Monsterliste enthält reguläre Gegner und beide Fallbosse")
	_check(lexicon.selected_entry_id == &"", "Beim Öffnen ist kein Lexikoneintrag automatisch ausgewählt")
	_check(lexicon.list_panel.visible and lexicon.overview_toolbar.visible and not lexicon.detail_panel.visible, "Das Lexikon öffnet auf der flächenfüllenden Übersicht statt auf einer leeren Detailhälfte")
	_check(not lexicon.compact_back_button.visible, "Die Rückkehraktion erscheint erst auf der Detail-Zweitebene")
	_check(lexicon.entry_filter != null and lexicon.entry_filter.placeholder_text.contains("durchsuchen"), "Die Eintragsübersicht besitzt eine klare Suche")
	_check(lexicon.entry_count_label.text.contains("entdeckt") and not lexicon.entry_count_label.text.contains("freigeschaltet"), "Die gemeinsame Kopfzeile benennt den Fortschritt als entdeckt")
	_check(not lexicon.detail_type_sections.visible, "Die leere Detailfläche zeigt keine veralteten Typdaten")
	_check(MedicalLexiconIllustration.SAFE_MARGIN >= 4.0, "Lexikonillustrationen reservieren einen festen Sicherheitsabstand zum Kachelrand")
	for button in lexicon.entry_buttons.values():
		var tile := button as Button
		_check(tile.theme_type_variation in [AlveolusVisualTheme.TYPE_SELECTION_CARD, AlveolusVisualTheme.TYPE_SELECTED_CARD], "Jede Lexikonkachel verwendet eine zentrale Auswahlkartenrolle")
		_check(tile.custom_minimum_size == Vector2(LexiconMasterDetail.GRID_TILE_MIN_WIDTH, LexiconMasterDetail.GRID_TILE_HEIGHT), "Jede Übersichtskachel bleibt dicht und besitzt eine stabile Mindestgröße")
		_check(not tile.button_pressed, "Keine Lexikonkachel ist beim Öffnen automatisch markiert")
		_check(not tile.tooltip_text.is_empty(), "Der native Kurztooltip bleibt auf Maus-Hover verfügbar")
		_check(not String(tile.get_meta(&"alveolus_accessible_name", "")).is_empty(), "Jede Kachel benennt Inhalt und Freischaltzustand zugänglich")
		var tile_state := String(tile.get_meta(&"lexicon_base_state_text", ""))
		if tile_state.is_empty():
			_check(tile.find_child("UnlockReason", true, false) == null, "Entdeckte Kacheln zeigen keine redundante Freigeschaltet-Zeile")
		else:
			var lock_icon := tile.find_child("LockedIcon", true, false) as SimpleIcon
			_check(lock_icon != null and lock_icon.kind == &"locked", "Gesperrte Kacheln zeigen ein echtes Padlock vor dem Namen")
			_check(String(tile.get_meta(&"alveolus_accessible_name", "")).contains("Gesperrt"), "Der Padlockzustand wird im Accessible Name ausgeschrieben")
		var illustrations: Array[Node] = button.find_children("*", "MedicalLexiconIllustration", true, false)
		_check(illustrations.size() == 1, "Jede Lexikonkachel besitzt genau eine Illustration oder Silhouette")
		if not illustrations.is_empty():
			_check(_artboard_fits_safely(illustrations[0] as MedicalLexiconIllustration), "Jede kompakte Lexikonillustration skaliert innerhalb ihrer sicheren Kachelfläche")
	_check(_artboard_fits_safely(lexicon.detail_illustration), "Auch die große Detailillustration wahrt ihre Icon-Safe-Area")
	_check(lexicon.detail_gameplay_text.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Lange Spieltexte umbrechen")
	_check(lexicon.detail_medical_text.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Lange medizinische Texte umbrechen")
	var safe_inset := lexicon.detail_scroll.get_node_or_null("ScrollbarSafeInset") as MarginContainer
	_check(safe_inset != null and safe_inset.get_parent() == lexicon.detail_scroll, "Der Detailinhalt besitzt direkt vor der Scrollbar einen eigenen Sicherheits-Inset")
	if safe_inset != null:
		var scrollbar_width := lexicon.detail_scroll.get_v_scroll_bar().get_combined_minimum_size().x
		_check(safe_inset.get_theme_constant("margin_right") >= ceili(scrollbar_width), "Der rechte Sicherheits-Inset hält Texte und Werte vollständig von der Scrollbar frei")
		_check(safe_inset.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Der Scrollbar-Inset füllt die verfügbare Detailbreite")
	var entry_safe_inset := lexicon.entry_scroll.get_node_or_null("ScrollbarSafeInset") as MarginContainer
	_check(entry_safe_inset != null and entry_safe_inset.get_parent() == lexicon.entry_scroll, "Auch die Eintragsliste hält eine eigene Scrollbar-Safe-Area frei")
	if entry_safe_inset != null:
		var entry_scrollbar_width := lexicon.entry_scroll.get_v_scroll_bar().get_combined_minimum_size().x
		_check(entry_safe_inset.get_theme_constant("margin_right") >= ceili(entry_scrollbar_width), "Eintragskacheln reichen nicht unter die Scrollbar")
	var context_sources := lexicon.context_detail_sources()
	_check(context_sources.size() == lexicon.entry_buttons.size(), "Jede sichtbare Lexikonzeile stellt eine registrierbare ui_info-Quelle bereit")
	if not context_sources.is_empty():
		_check(String(context_sources[0].get("id", &"")).begins_with("lexicon:entry:"), "Jede Kontextquelle transportiert eine stabile, screenlokale ID")
		_check(not bool(context_sources[0].get("hover_enabled", true)), "Der gemeinsame Detailcontroller bleibt für Lexikoneinträge explizit; Maus-Hover nutzt ausschließlich den nativen Kurztooltip")
		var content_provider: Callable = context_sources[0].get("provider", Callable())
		var payload: Dictionary = content_provider.call() if content_provider.is_valid() else {}
		_check(payload.has("title") and payload.has("body") and payload.has("sections"), "Der Detailprovider liefert eine abgelöste, semantisch gegliederte Inhaltskopie")
	_check(lexicon.detail_gameplay_panel != lexicon.detail_medical_panel, "Spielwirkung und medizinischer Hintergrund besitzen getrennte Flächen")
	for semantic_panel in [lexicon.detail_gameplay_panel, lexicon.detail_medical_panel]:
		_check(semantic_panel is PanelContainer and semantic_panel.get_meta(&"alveolus_component", &"") == &"semantic_copy_section", "Jede Bedeutungsebene verwendet die semantische Textflächen-Komponente")
	_check(lexicon.detail_gameplay_panel.is_ancestor_of(lexicon.detail_gameplay_text), "Der Spieltext bleibt innerhalb seiner semantischen Fläche")
	_check(lexicon.detail_medical_panel.is_ancestor_of(lexicon.detail_medical_text), "Der medizinische Text bleibt innerhalb seiner semantischen Fläche")


func _test_dense_grid_overview(lexicon: LexiconMasterDetail) -> void:
	lexicon.select_category(LexiconEntryDefinition.CATEGORY_TERMS)
	await process_frame
	await process_frame
	_check(lexicon.entry_buttons.size() >= 20, "Das Begriffslexikon liefert genügend Einträge für die Dichteprüfung")
	_check(lexicon.entry_list.columns == LexiconMasterDetail.GRID_COLUMNS_WIDE, "Bei 1280x720 stehen sechs kleine Kacheln pro Reihe")
	var visible_rows := floori(lexicon.entry_scroll.size.y / float(LexiconMasterDetail.GRID_TILE_HEIGHT + AlveolusVisualTheme.CONTROL_GAP))
	_check(visible_rows * lexicon.entry_list.columns >= 18, "Bei 1280x720 sind mindestens achtzehn Einträge zugleich ohne Scrollen sichtbar")
	_check(lexicon.list_panel.visible and not lexicon.detail_panel.visible, "Die dichte Übersicht nutzt vor einer Auswahl die vollständige Inhaltsfläche")
	_set_filter_text(lexicon, "Attack Speed")
	await process_frame
	_check(lexicon.selected_entry_id == &"" and not lexicon.detail_panel.visible, "Die Suche verändert weder Auswahl noch Detailstufe")
	_check(lexicon.entry_count_label.text.contains("Treffer"), "Ein aktiver Filter ergänzt die Fortschrittszeile um seine Trefferzahl")
	_set_filter_text(lexicon, "")
	lexicon.select_category(LexiconEntryDefinition.CATEGORY_MONSTERS)
	await process_frame


func _test_related_term_chips(lexicon: LexiconMasterDetail) -> void:
	var emitted_registrations: Array[Dictionary] = []
	var capture := func(source: Control, content_provider: Callable, hover_enabled: bool) -> void:
		emitted_registrations.append({
			"source": source,
			"provider": content_provider,
			"hover_enabled": hover_enabled,
		})
	lexicon.context_detail_source_available.connect(capture)
	var view_model := RelatedLexiconViewModelStub.new()
	view_model.id = &"test_parent"
	view_model.category = LexiconEntryDefinition.CATEGORY_GAMEPLAY
	view_model.display_name = "Testeintrag"
	view_model.summary = "Test für DTO-basierte verwandte Begriffe."
	view_model._related_presentations = [
		RelatedTermPresentationStub.new(&"term_treatment_speed", "Attack Speed", "Bestimmt die Anzahl automatischer Impulse pro Sekunde.", &"damage_wind"),
		RelatedTermPresentationStub.new(&"term_radius", "Radius", "Bestimmt die Größe einer Flächenwirkung.", &"damage_earth"),
	]
	lexicon._show_detail(view_model)
	lexicon.compact_detail_visible = true
	lexicon._apply_responsive_layout()
	await process_frame
	lexicon.context_detail_source_available.disconnect(capture)

	var chips: Array[Node] = lexicon.detail_related_chips.get_children()
	_check(chips.size() == 2 and lexicon.detail_related_title.visible, "Verwandte DTOs werden als kompakte fokussierbare Chips statt als Fließtext dargestellt")
	_check(emitted_registrations.size() == 2, "Jeder verwandte Begriff wird über denselben zentralen Kontextdetailweg registriert")
	if chips.size() == 2 and emitted_registrations.size() == 2:
		var first_chip := chips[0] as Button
		_check(first_chip != null and first_chip.focus_mode == Control.FOCUS_ALL, "Verwandte Begriffe sind per Tastatur fokussierbar")
		_check(first_chip.tooltip_text.is_empty(), "Verwandte Chips erzeugen keinen konkurrierenden nativen Tooltip")
		_check(first_chip.get_meta(&"lexicon_related_term_id", &"") == &"term_treatment_speed", "Der Chip bewahrt die stabile Term-ID des DTOs")
		var chip_icons: Array[Node] = first_chip.find_children("*", "SimpleIcon", true, false)
		_check(chip_icons.size() == 1 and (chip_icons[0] as SimpleIcon).kind == &"damage_wind", "Der verwandte Begriff übernimmt sein datengetriebenes DTO-Icon")
		_check(String(first_chip.get_meta(&"context_detail_stable_id", &"")).begins_with("lexicon:related:test_parent:"), "Die Controllerregistrierung besitzt eine stabile Parent-/Term-ID")
		_check(bool(emitted_registrations[0].get("hover_enabled", false)), "Mouse-Hover ist ausschließlich für verwandte Begriffschips aktiviert")
		var provider: Callable = emitted_registrations[0].get("provider", Callable())
		var hover_payload: Dictionary = provider.call() if provider.is_valid() else {}
		_check(String(hover_payload.get("title", "")) == "Attack Speed" and String(hover_payload.get("body", "")).contains("Impulse pro Sekunde"), "Hover und ui_info erhalten dieselbe fertige DTO-Erklärung")
		_check(StringName(hover_payload.get("icon_kind", &"")) == &"damage_wind", "Der Kontextpayload übernimmt dasselbe DTO-Icon wie der Chip")

		var controller := ContextDetailController.new()
		get_root().add_child(controller)
		await process_frame
		controller.register_source(first_chip, provider, true)
		first_chip.grab_focus()
		await process_frame
		_check(not controller.is_open(), "Fokus allein öffnet auch bei verwandten Begriffen keine Detailkarte")
		first_chip.mouse_entered.emit()
		await process_frame
		_check(controller.is_open() and not controller.is_explicit(), "Mouse-Hover öffnet die Erklärung über den globalen Controller")
		controller.close_all()
		_check(controller.toggle_focused(first_chip), "ui_info löst den fokussierten verwandten Begriff über dieselbe Registrierung auf")
		_check(controller.is_explicit() and controller.current_payload().get("body", "") == hover_payload.get("body", ""), "ui_info zeigt exakt dieselbe Erklärung wie Hover")
		controller.queue_free()
		await process_frame

	lexicon.select_category(LexiconEntryDefinition.CATEGORY_MONSTERS)

func _test_lock_and_selection(lexicon: LexiconMasterDetail) -> void:
	_check(lexicon.select_entry(&"pneumococcus"), "Entdecktes Bakterium ist auswählbar")
	_check(lexicon.detail_panel.visible and not lexicon.list_panel.visible and not lexicon.overview_toolbar.visible, "Eine bestätigte Kachel öffnet das große Detail als eigene zweite Ebene")
	_check(lexicon.compact_back_button.visible and String(lexicon.compact_back_button.get_meta(&"alveolus_accessible_name", "")).contains("Übersicht"), "Die Detailstufe besitzt eine eindeutige Rückkehraktion")
	_check(not lexicon.detail_illustration.locked, "Entdeckte Illustration ist sichtbar")
	_check(lexicon.detail_stats_grid.get_child_count() == 6, "Sechs kompakte Gegnerwerte bleiben neben der strukturierten Typdarstellung sichtbar")
	_assert_type_presentations(lexicon, &"pneumococcus")
	_check(lexicon.detail_title.text == "Bakterium", "Detailtitel verwendet einfachen Namen")
	_check(lexicon.detail_medical_name.text == "Pneumokokke", "Fachbegriff bleibt als zweite Ebene")
	_set_filter_text(lexicon, "keine passenden monster")
	_check(lexicon.selected_entry_id == &"pneumococcus", "Filtern löscht die ausdrücklich gewählte Lexikonauswahl nicht")
	_check(lexicon.detail_title.text == "Bakterium" and lexicon.detail_title.visible, "Das gewählte Detail bleibt auch bei ausgefilterter Zeile sichtbar")
	_set_filter_text(lexicon, "")
	_check(lexicon.cancel_step(), "Cancel schließt auf jeder Breite zuerst die Detail-Zweitebene")
	_check(lexicon.list_panel.visible and lexicon.overview_toolbar.visible and not lexicon.detail_panel.visible, "Cancel kehrt in die unveränderte Rasterübersicht zurück")
	var restored_selection := lexicon.entry_buttons.get(&"pneumococcus") as Button
	_check(restored_selection != null and restored_selection.button_pressed and restored_selection.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CARD, "Nach der Rückkehr ist die bestehende Auswahl weiter sichtbar markiert")

	_check(lexicon.select_entry(&"bacterial_cluster"), "Gesperrter Eintrag bleibt als Silhouette anwählbar")
	_check(lexicon.detail_illustration.locked, "Gesperrter Eintrag zeichnet die Silhouette")
	_check(lexicon.detail_title.text == "Bakteriengruppe", "Gesperrter Eintrag behält seinen Namen neben der sichtbaren Schlosskennzeichnung")
	_check(lexicon.detail_summary.text.contains("Besiege"), "Gesperrter Eintrag nennt seinen konkreten Entdeckungsgrund")
	_check(not lexicon.detail_stats_grid.visible, "Gesperrter Eintrag verrät keine Werte")
	_check(not lexicon.detail_type_sections.visible, "Gesperrter Eintrag verrät keine Schadenstypen oder Resistenzen")
	_check(not lexicon.detail_medical_name.visible, "Gesperrter Eintrag verrät keinen Fachbegriff")
	_check(lexicon.cancel_step(), "Auch ein gesperrtes Detail kehrt mit Cancel zur Übersicht zurück")

	lexicon.select_category(LexiconEntryDefinition.CATEGORY_TERMS)
	_check(lexicon.entry_buttons.size() >= 20, "Begriffslexikon enthält weiterhin den allgemeinen Startkatalog")
	_check(lexicon.selected_entry_id == &"", "Auch ein Kategorienwechsel wählt nicht automatisch den ersten Begriff")
	_check(lexicon.list_panel.visible and not lexicon.detail_panel.visible, "Ein Kategorienwechsel zeigt ausschließlich das neue Eintragsraster")
	_check(lexicon.context_detail_sources().is_empty(), "Begriffe erzeugen keine ui_info-Detailquellen")
	for term_button_value in lexicon.entry_buttons.values():
		var term_button := term_button_value as Button
		_check(term_button != null and term_button.tooltip_text.is_empty(), "Begriffe erzeugen keinen Maus-Tooltip")

	lexicon.select_category(LexiconEntryDefinition.CATEGORY_CHARACTER)
	var tempo_id := &"term_treatment_speed"
	_check(lexicon.entry_buttons.has(tempo_id), "Attack Speed steht bei den Charakterwerten")
	_check(not lexicon.context_detail_payload(tempo_id).is_empty(), "Ein Charakterwert liefert seine normale Detailkarte")
	_check(lexicon.select_entry(tempo_id), "Attack Speed ist unter Charakter direkt lesbar")
	_check(lexicon.detail_gameplay_text.text.contains("Attack Speed"), "Detail erklärt Attack Speed verständlich")
	lexicon.cancel_step()

	_check(lexicon.select_entry(&"character_stats"), "Charakterwerte sind unter Charakter direkt lesbar")
	var expected_sections: Array[StringName] = [&"defense", &"attack", &"other"]
	var expected_titles := ["Verteidigung", "Angriff", "Sonstiges"]
	for index in range(expected_sections.size()):
		var group := lexicon.detail_stats_sections.get_node_or_null("StatSection_%s" % expected_sections[index]) as VBoxContainer
		_check(group != null and group.get_meta(&"lexicon_stat_section", &"") == expected_sections[index], "Charakterwerte besitzen die stabile Gruppe %s" % expected_titles[index])
		_check(group != null and group.find_children("*", "Label", true, false).any(func(node: Node) -> bool: return (node as Label).text == expected_titles[index]), "Charakterwertgruppe zeigt den Titel %s" % expected_titles[index])
	_check(lexicon.detail_stats_grid.get_child_count() == 0 and not lexicon.detail_stats_grid.visible, "Nur Charakterwerte ersetzen das unveränderte flache Basiswerteraster")
	lexicon.cancel_step()

func _test_responsive_detail_density(lexicon: LexiconMasterDetail) -> void:
	lexicon.select_category(LexiconEntryDefinition.CATEGORY_MONSTERS)
	_check(lexicon.select_entry(&"pneumococcus"), "Bekannter Gegner stellt seine Basiswerte für die Dichteprüfung bereit")
	await process_frame
	_check(lexicon.detail_panel.visible and not lexicon.list_panel.visible, "Das breite Detail ersetzt die Rasterstufe vollständig")
	_check(lexicon.detail_stats_grid.columns == 2, "Breites Lexikon zeigt zwei kompakte Wertkarten pro Zeile")
	_check(lexicon.detail_stats_grid.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Die Werteansicht nutzt die gesamte verfügbare Detailbreite")
	_check(lexicon.detail_stats_grid.get_child_count() == 6, "Die Zwei-Spalten-Wertansicht behält alle nicht redundanten Basiswerte")
	for stat_child in lexicon.detail_stats_grid.get_children():
		var stat_panel := stat_child as PanelContainer
		_check(stat_panel != null and stat_panel.get_meta(&"alveolus_component", &"") == &"value_row", "Jeder Basiswert verwendet die zentrale kompakte Wertzeile")
		if stat_panel != null:
			var labels: Array[Node] = stat_panel.find_children("*", "Label", true, false)
			_check(labels.size() == 2 and (labels[1] as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Bezeichnung und Wert bleiben als links-/rechtsbündiges Paar in derselben Karte")
			var name_label := stat_panel.find_child("ValueName", true, false) as Label
			var value_label := stat_panel.find_child("Value", true, false) as Label
			_check(name_label != null and name_label.autowrap_mode == TextServer.AUTOWRAP_OFF, "Wertbezeichnungen brechen niemals zeichenweise um")
			_check(value_label != null and value_label.custom_minimum_size.x >= 72.0, "Der rechtsbündige Wert behält eine stabile lesbare Spalte")
	for type_grid in lexicon._detail_type_grids:
		_check(type_grid.columns == 2, "Breite Schadenstypgruppen ordnen ihre vier Einträge in zwei Spalten")

	# Pin the component to 800 logical pixels so the test covers the compact
	# Detaildichte unabhängig vom Viewport-Stretchmodus.
	lexicon.set_anchor(SIDE_RIGHT, 0.0)
	lexicon.set_anchor(SIDE_BOTTOM, 0.0)
	lexicon.size = Vector2(800.0, 620.0)
	await process_frame
	await process_frame
	_check(lexicon.detail_stats_grid.columns == 1, "Kompaktes Lexikon zeigt genau eine Wertkarte pro Zeile")
	for type_grid in lexicon._detail_type_grids:
		_check(type_grid.columns == 1, "Kompakte Schadenstypgruppen bleiben als einzelne lesbare Zeilen erhalten")
	_check(lexicon.category_bar.columns == 5, "Bei 800 Pixeln bleiben die kompakten Kategorien in einer einzigen Reihe")
	_check(lexicon.category_bar.custom_minimum_size.y == 44.0, "Die einreihigen Kategorien belegen nur ihre Mindestzielhöhe")
	_check(lexicon.page_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Kompaktes Lexikon aktiviert den vertikalen Seitenscroll")
	_check(lexicon.content_row.custom_minimum_size.y >= LexiconMasterDetail.COMPACT_CONTENT_MIN_HEIGHT, "Übersicht und Detail kollabieren bei kompakter Höhe nicht")
	_check(lexicon.cancel_step(), "Cancel schließt das 800-Pixel-Detail vor der Seite")
	_check(lexicon.entry_list.columns == 4 and lexicon.list_panel.visible, "Die 800-Pixel-Übersicht verwendet vier dichte Kachelspalten")

	# 960 x 540 at 200 percent corresponds to only 480 x 270 logical pixels;
	# after the shared page header the component can be even shorter. Exercise
	# that exact density contract independently of the GameHUD transform.
	var scene_minimum := lexicon.custom_minimum_size
	lexicon.custom_minimum_size = Vector2.ZERO
	lexicon.size = Vector2(480.0, 210.0)
	await process_frame
	await process_frame
	_check(lexicon.page_scroll.get_v_scroll_bar().max_value > lexicon.page_scroll.get_v_scroll_bar().page, "Bei 960x540 @ 200 % besitzt die Bühne einen echten vertikalen Scrollbereich")
	_check(lexicon.category_bar.columns == 3 and lexicon.category_bar.custom_minimum_size.y < 120.0, "Sehr kompakte Kategorien benötigen nur zwei statt drei Reihen")
	_check(lexicon.entry_list.columns == 2, "Die sehr kompakte Übersicht bleibt als zweispaltiges Kachelraster lesbar")
	_check(lexicon.list_panel.visible and lexicon.entry_scroll.size.y >= 300.0, "Das kompakte Raster behält unter der gemeinsamen Suchzeile eine nutzbare Scrollfläche")
	_check(lexicon.select_entry(&"pneumococcus", true), "Kompakte Auswahl öffnet weiterhin das Detail")
	await process_frame
	await process_frame
	_check(lexicon.detail_panel.visible and not lexicon.list_panel.visible and lexicon.detail_scroll.size.y >= 300.0, "Auch das kompakte Detail ist eine eigene nutzbare zweite Ebene")
	_check(lexicon.cancel_step(), "Cancel kehrt aus dem sehr kompakten Detail zum Raster zurück")

	lexicon.custom_minimum_size = scene_minimum
	lexicon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	_check(lexicon.detail_stats_grid.columns == 2, "Nach Rückkehr zur breiten Ansicht werden wieder zwei Wertkarten je Zeile gezeigt")
	_check(lexicon.category_bar.columns == 5, "Nach Rückkehr zur breiten Ansicht stehen wieder alle fünf Reiter in einer Reihe")
	_check(lexicon.entry_list.columns == LexiconMasterDetail.GRID_COLUMNS_WIDE, "Nach Rückkehr zur breiten Ansicht verwendet die Übersicht wieder sechs Kachelspalten")
	for type_grid in lexicon._detail_type_grids:
		_check(type_grid.columns == 2, "Nach Rückkehr zur breiten Ansicht nutzen auch Schadenstypen wieder zwei Spalten")

func _assert_type_presentations(lexicon: LexiconMasterDetail, entry_id: StringName) -> void:
	var model := lexicon.entry_view_models.get(entry_id) as LexiconEntryViewModel
	var presentations := model.type_presentations() if model != null else []
	var chips: Array[Node] = lexicon.detail_type_sections.find_children("DamageTypeChip_*", "PanelContainer", true, false)
	_check(lexicon.detail_type_sections.visible, "Schadenstypen und effektive Resistenzen besitzen einen sichtbaren strukturierten Bereich")
	_check(presentations.size() == 8 and chips.size() == presentations.size(), "Vier Schadensanteile und vier effektive Resistenzen werden vollständig als zentrale Chips dargestellt")
	if presentations.size() != chips.size():
		return
	var expected_order: Array[StringName] = [&"fire", &"water", &"earth", &"wind", &"fire", &"water", &"earth", &"wind"]
	for index in range(chips.size()):
		var chip := chips[index] as PanelContainer
		var presentation := presentations[index]
		_check(chip.get_meta(&"alveolus_component", &"") == &"damage_type_chip", "Jeder Typwert verwendet ausschließlich die zentrale DamageTypeChip-Komponente")
		_check(chip.get_meta(&"damage_type_id", &"") == expected_order[index], "Typwert %d folgt der festen Reihenfolge Feuer, Wasser, Erde, Wind" % index)
		_check(chip.get_meta(&"lexicon_semantic_role", &"") == presentation.semantic_role, "Typwert %d transportiert seine DTO-Semantik ohne UI-Ableitung" % index)
		_check(chip.get_meta(&"lexicon_icon_id", &"") == presentation.icon_id, "Typwert %d übernimmt seine fertige Iconrolle aus dem DTO" % index)
		var icon := chip.find_child("DamageTypeIcon", true, false) as SimpleIcon
		var name_label := chip.find_child("DamageTypeName", true, false) as Label
		var value_label := chip.find_child("DamageTypeValue", true, false) as Label
		var meaning_label := chip.find_child("DamageTypeMeaning", true, false) as Label
		_check(icon != null and icon.kind == presentation.icon_id, "Typwert %d zeigt das DTO-Icon" % index)
		_check(name_label != null and name_label.text == presentation.display_name, "Typwert %d nennt den Schadenstyp ausgeschrieben" % index)
		_check(value_label != null and value_label.text == presentation.formatted_value, "Typwert %d zeigt ausschließlich den fertig formatierten DTO-Wert" % index)
		if presentation.semantic_role == &"resistance_effective":
			_check(meaning_label == null, "Resistenzwert %d zeigt keinen redundanten Untertext" % index)
		else:
			_check(meaning_label != null and meaning_label.text == presentation.meaning, "Schadenstyp %d erklärt seinen Wert zusätzlich zur Farbe" % index)

func _test_game_hud_embedding() -> void:
	var hud := GameHUD.new()
	get_root().add_child(hud)
	await process_frame
	await process_frame
	_check(hud.lexicon_master_detail != null, "Der GameHUD bindet die Master/Detail-Komponente direkt ein")
	if hud.lexicon_master_detail != null:
		_check(not _has_scroll_ancestor(hud.lexicon_master_detail), "Das Lexikon besitzt im GameHUD keinen zweiten äußeren ScrollContainer")
		_check(hud.lexicon_master_detail.theme == null, "Das eingebettete Lexikon erbt das gemeinsame HUD-Theme statt eine lokale Theme-Insel zu erzeugen")
	hud.queue_free()
	await process_frame

func _test_mouse_and_focus_navigation(lexicon: LexiconMasterDetail) -> void:
	var monster_tab := lexicon.category_buttons[LexiconEntryDefinition.CATEGORY_MONSTERS] as Button
	var character_tab := lexicon.category_buttons[LexiconEntryDefinition.CATEGORY_CHARACTER] as Button
	_check(monster_tab.focus_neighbor_right == monster_tab.get_path_to(character_tab), "Kategorien besitzen explizite horizontale Fokusnavigation")
	monster_tab.pressed.emit()
	_check(lexicon.selected_category == LexiconEntryDefinition.CATEGORY_MONSTERS, "Mausklick wechselt die Kategorie")
	_check(lexicon.selected_entry_id == &"", "Der Kategorienklick markiert nicht automatisch den ersten Eintrag")
	_check(lexicon.list_panel.visible and not lexicon.detail_panel.visible, "Der Kategorienklick zeigt zunächst ausschließlich das Eintragsraster")
	var visible_entries := LexiconCatalog.entries_for_category(LexiconEntryDefinition.CATEGORY_MONSTERS)
	var first := lexicon.entry_buttons[visible_entries[0].id] as Button
	var second := lexicon.entry_buttons[visible_entries[1].id] as Button
	_check(first.focus_neighbor_right == first.get_path_to(second), "Kacheln besitzen explizite horizontale Fokusnavigation")
	_check(first.focus_neighbor_top == first.get_path_to(lexicon.entry_filter), "Die oberste Kachelreihe führt nach oben zur Suche")
	_check(first.focus_neighbor_left == first.get_path_to(monster_tab), "Linksnavigation führt zur aktiven Kategorie")
	second.mouse_entered.emit()
	await process_frame
	_check(lexicon.selected_entry_id == &"", "Mouseover verändert die ausdrückliche Lexikonauswahl nicht")
	lexicon.grab_initial_focus()
	await process_frame
	_check(get_root().gui_get_focus_owner() == monster_tab, "Anfangsfokus ist für Tastatur und Gamepad sichtbar")
	first.grab_focus()
	await process_frame
	_check(lexicon.selected_entry_id == &"", "Tastatur- und Gamepadfokus verändert die Auswahl nicht ohne Bestätigung")
	var activation_events: Array[StringName] = []
	lexicon.entry_selected.connect(func(entry_id: StringName) -> void: activation_events.append(entry_id))
	_send_action(&"ui_accept", true)
	await process_frame
	_send_action(&"ui_accept", false)
	await process_frame
	# The detail layer and its ScrollContainer settle focus on separate deferred
	# frames under the full headless matrix; wait for both deterministically.
	await process_frame
	_check(not activation_events.is_empty() and activation_events[-1] == visible_entries[0].id, "Tastatur und Gamepad Aktivierung bestätigen den fokussierten Eintrag")
	_check(lexicon.detail_panel.visible and not lexicon.list_panel.visible, "Accept öffnet ausschließlich die Detail-Zweitebene")
	_check(get_root().gui_get_focus_owner() == lexicon.compact_back_button, "Nach dem Öffnen ist die Rückkehraktion der sichtbare Detailfokus")
	_check(lexicon.cancel_step(), "Cancel schließt das per Accept geöffnete Detail")
	await process_frame
	_check(get_root().gui_get_focus_owner() == first and first.button_pressed, "Die Rasterstufe stellt Fokus und persistente Markierung am Auslöser wieder her")

func _test_layout_sizes(lexicon: LexiconMasterDetail) -> void:
	lexicon.select_category(LexiconEntryDefinition.CATEGORY_MONSTERS)
	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(960, 540)]:
		get_root().size = viewport_size
		await process_frame
		await process_frame
		var root_rect := lexicon.get_global_rect()
		# canvas_items keeps Control coordinates in the 1280 x 720 reference
		# canvas and scales that complete canvas to the physical viewport.
		var reference_size := Vector2(1280.0, 720.0)
		_check(root_rect.position.x >= -0.5 and root_rect.position.y >= -0.5, "Lexikon beginnt bei %s im sichtbaren Bereich" % viewport_size)
		_check(root_rect.end.x <= reference_size.x + 0.5 and root_rect.end.y <= reference_size.y + 0.5, "Lexikon bleibt bei %s vollständig im Bild" % viewport_size)
		_check(lexicon.list_panel.visible and lexicon.entry_scroll.size.x >= 900.0, "Das Übersichtsraster nutzt bei %s die breite Referenzfläche" % viewport_size)
		_check(lexicon.entry_list.columns == LexiconMasterDetail.GRID_COLUMNS_WIDE, "Das Referenzcanvas behält bei %s sechs dichte Kachelspalten" % viewport_size)
		_check(lexicon.select_entry(&"pneumococcus"), "Die Detailstufe ist bei %s erreichbar" % viewport_size)
		await process_frame
		_check(lexicon.detail_panel.visible and lexicon.detail_scroll.size.x >= 900.0, "Der Detailtext nutzt bei %s die eigene breite Ebene" % viewport_size)
		_check(lexicon.cancel_step(), "Die Detailstufe schließt bei %s vor der Seite" % viewport_size)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _artboard_fits_safely(illustration: MedicalLexiconIllustration) -> bool:
	if illustration == null:
		return false
	var control_size := illustration.size
	if control_size.x <= 0.0 or control_size.y <= 0.0:
		control_size = illustration.custom_minimum_size
	var short_side := minf(control_size.x, control_size.y)
	var available_diameter := maxf(0.0, short_side - MedicalLexiconIllustration.SAFE_MARGIN * 2.0)
	var rendered_diameter := minf(MedicalLexiconIllustration.ARTBOARD_DIAMETER, available_diameter)
	return rendered_diameter > 0.0 and (short_side - rendered_diameter) * 0.5 >= MedicalLexiconIllustration.SAFE_MARGIN - 0.01

func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _set_filter_text(lexicon: LexiconMasterDetail, text: String) -> void:
	lexicon.entry_filter.text = text
	lexicon.entry_filter.text_changed.emit(text)


func _has_scroll_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current is ScrollContainer:
			return true
		current = current.get_parent()
	return false
