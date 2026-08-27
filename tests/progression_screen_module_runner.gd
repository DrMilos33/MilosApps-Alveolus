extends SceneTree

const ProgressionScreenScript := preload("res://scripts/ui/screens/progression_screen.gd")
const ProgressionViewModelScript := preload("res://scripts/ui/view_models/progression_screen_view_model.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := ProgressionScreenScript.new() as ProgressionScreen
	screen.theme = AlveolusVisualTheme.create_theme()
	screen.size = Vector2(1280.0, 720.0)
	get_root().add_child(screen)
	await process_frame

	_check(screen.route_id() == &"research", "Progression-Screen bewahrt die bestehende Forschungsroute")
	_check(screen.context_detail_scope_id() == &"progression", "Progression-Screen besitzt einen stabilen ContextDetail-Scope")
	_check(not screen.is_processing(), "Progression-Screen besitzt keine Prozessschleife")
	_check(not screen.is_physics_processing(), "Progression-Screen besitzt keine Physikschleife")
	_check(screen.research_scroll().follow_focus, "Forschungsscroll folgt Tastatur- und Gamepadfokus")
	_check(screen.talent_scroll().follow_focus, "Talentscroll folgt Tastatur- und Gamepadfokus")

	var fixture: Variant = _fixture(1, &"research", "Forschung 18", "4 Talentpunkte · 2 frei")
	_check(fixture.research_item_count() == 4, "ViewModel bewahrt alle vier Forschungskarten")
	_check(fixture.talent_branch_count() == 1, "ViewModel bündelt Root und drei Abzweigungen in einem Talentbaum")
	_check(fixture.talents_unlocked(), "Bestehende Presenter bleiben durch den optionalen Unlockparameter rückwärtskompatibel")
	var copied_research: Array = fixture.research_items()
	copied_research.clear()
	_check(fixture.research_item_count() == 4, "Ausgelesene Forschungsliste verändert das ViewModel nicht")
	var copied_branches: Array = fixture.talent_branches()
	var first_branch_copy: Variant = copied_branches[0]
	copied_branches.clear()
	_check(fixture.talent_branch_count() == 1, "Ausgelesene Astliste verändert das ViewModel nicht")
	_check(first_branch_copy != fixture.talent_branches()[0], "Ast- und Knotendaten werden bei jedem Auslesen tief kopiert")

	_check(screen.apply_view_model(fixture), "Erstes Progression-ViewModel wird angewendet")
	await process_frame
	await process_frame
	_check(screen.selected_tab() == &"research", "ViewModel bestimmt den sichtbaren Tab")
	_check(screen.research_tab_action().theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB, "Aktiver Forschungstab verwendet den lesbaren Selected-Zustand")
	_check(screen.talent_tab_action().theme_type_variation == AlveolusVisualTheme.TYPE_SEGMENTED_TAB, "Inaktiver Talenttab bleibt visuell getrennt")
	_check(screen.research_columns() == 4, "Forschung nutzt bei 1280×720 exakt vier kompakte Spalten")
	var foundation_grid := screen.research_group_grid(&"foundation")
	var unlock_grid := screen.research_group_grid(&"unlock")
	_check(foundation_grid != null and unlock_grid != null and foundation_grid.columns == 4 and unlock_grid.columns == 4, "Grundlagen und Freischaltungen besitzen eigene Vier-Spalten-Laborgruppen")
	_check(foundation_grid.get_child_count() == 3 and unlock_grid.get_child_count() == 1, "Forschungskarten werden über explizite Präsentationsgruppen einsortiert")
	var group_titles := screen.find_children("ResearchGroupTitle", "Label", true, false)
	_check(group_titles.size() == 2 and (group_titles[0] as Label).text == "Grundlagen" and (group_titles[1] as Label).text == "Freischaltungen", "Laborboard benennt Grundlagen und Freischaltungen sichtbar")
	_check(screen.talent_columns() == 1, "Der gemeinsame Root-Baum nutzt die verfügbare Breite")

	var active_research := screen.research_action(&"research_active")
	var available_research := screen.research_action(&"research_available")
	var locked_research := screen.research_action(&"research_locked")
	_check(active_research.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_COMPACT_RESEARCH, "Aktive Forschung verwendet die semantische Kompaktrolle")
	_check(_state_icon_kind(active_research) == &"check", "Aktive Forschung ist zusätzlich mit Check markiert")
	_check(bool(available_research.get_meta(&"item_interactive", false)), "Verfügbare Forschung ist interaktiv")
	_check(not bool(locked_research.get_meta(&"item_interactive", true)), "Gesperrte Forschung löst keine Kaufabsicht aus")
	_check(_state_icon_kind(locked_research) == &"locked", "Gesperrte Forschung ist zusätzlich mit Schloss markiert")
	_check(_primary_icon_kind(locked_research) == &"question", "Unbekannte Meilensteinforschung zeigt Fragezeichen plus separates Schloss")
	_check(locked_research.theme_type_variation == AlveolusVisualTheme.TYPE_COMPACT_RESEARCH, "Gesperrte Forschung bewahrt die fokussierbare kompakte Grundrolle")
	_check(locked_research.focus_mode == Control.FOCUS_ALL, "Gesperrte Forschung bleibt für ui_info fokussierbar")
	var research_lock_cover := locked_research.find_child("ResearchMilestoneLock", true, false) as PanelContainer
	var research_lock_icon := locked_research.find_child("ResearchMilestoneLockIcon", true, false) as SimpleIcon
	_check(research_lock_cover != null and research_lock_cover.get_global_rect().is_equal_approx(locked_research.get_global_rect()), "Der Lazer-Meilenstein bedeckt exakt die ganze Forschungskarte")
	_check(research_lock_cover != null and research_lock_cover.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Die Sperrfläche lässt Hover und ui_info an die Karte durch")
	_check(research_lock_icon != null and research_lock_icon.kind == &"locked", "Die Vollflächensperre verwendet die zentrale Padlock-Glyphe")
	_check(screen.research_action(&"research_fourth").find_child("ResearchMilestoneLock", true, false) == null, "Normale unbezahlbare Forschung erhält keine Meilenstein-Sperrfläche")
	_check(String(locked_research.get_meta(&"alveolus_accessible_name", "")).contains("gesperrt"), "Nicht sichtbarer zugänglicher Name benennt den Zustand ausdrücklich")
	_check(String(screen.info_payload_for(locked_research).get("body", "")).contains("Abschluss von Fall 1"), "Meilensteinforschung erklärt ihren Unlock im Hoverdetail")
	_check(active_research.custom_minimum_size.y == AlveolusVisualTheme.COMPACT_RESEARCH_HEIGHT and active_research.get_combined_minimum_size().y <= 68.0, "Forschungskarten bleiben einschließlich Theme-Innenrändern kompakt")
	_check(active_research.get_meta(&"alveolus_component", &"") == &"compact_research", "Forschung verwendet die zentrale Komponentenrolle compact_research")
	_check(active_research.get_meta(&"research_group_id", &"") == &"foundation" and locked_research.get_meta(&"research_group_id", &"") == &"unlock", "Karten bewahren ihre semantische Laborgruppe")
	_check(_rank_segment_count(active_research) == 3 and _active_rank_segment_count(active_research) == 3, "Mehrfachränge erscheinen als vollständig gefüllte Segmente am Hauptmotiv")
	_check(_rank_segment_count(available_research) == 3 and _active_rank_segment_count(available_research) == 0, "Ungeskillte Forschung zeigt ihren erreichbaren Rang als leere Segmente")
	var cost_chip := available_research.find_child("ResearchCostChip", true, false) as PanelContainer
	var cost_icon := available_research.find_child("ResearchCostIcon", true, false) as SimpleIcon
	var cost_value := available_research.find_child("ResearchCostValue", true, false) as Label
	_check(cost_chip != null and cost_chip.theme_type_variation == AlveolusVisualTheme.TYPE_BADGE and cost_icon != null and cost_icon.kind == &"research" and cost_value != null and cost_value.text == "2", "Kosten erscheinen als kompaktes Forschungschip statt Browsercopy")
	for card in [active_research, available_research, locked_research]:
		var card_text := _descendant_text(card).to_lower()
		_check(not card_text.contains("aktiv") and not card_text.contains("verfügbar") and not card_text.contains("gesperrt"), "Karten wiederholen ihren Zustand nicht als Statuswort")
		_check(not card_text.contains("gesamt") and not card_text.contains("+9"), "Gesamtwirkung belegt nie dauerhaften Platz auf der Forschungskarte")

	var tooltip_provider := screen.tooltip_provider_for(available_research)
	var explicit_provider := screen.ui_info_provider_for(available_research)
	_check(tooltip_provider.is_valid(), "Forschung stellt einen Hover-Provider bereit")
	_check(explicit_provider.is_valid(), "Forschung stellt denselben Inhalt für ui_info bereit")
	_check(tooltip_provider == explicit_provider, "Hover und ui_info verwenden exakt denselben Provider")
	_check(tooltip_provider.call() == explicit_provider.call(), "Hover und ui_info liefern inhaltsgleiche Payloads")
	_check(screen.info_payload_for(available_research).get("title", "") == "Mehr Erfahrung", "Informationspayload bleibt quellenspezifisch")
	var active_research_payload := screen.info_payload_for(active_research)
	_check(String(active_research_payload.get("body", "")).contains("Gesamt: +9 Leben"), "Tooltip ergänzt den vorberechneten Gesamtwert mit dem exakten Präfix")
	_check(fixture.research_items()[0].total_effect_text() == "+9 Leben", "ViewModel transportiert Gesamtwirkung darstellungsfertig und ohne UI-Berechnung")
	_check(fixture.research_items()[0].group_id() == &"foundation" and fixture.research_items()[0].rank_current() == 3 and fixture.research_items()[0].rank_maximum() == 3, "ViewModel transportiert Gruppe und Ränge als unveränderliche Präsentationsprimitive")
	_check(available_research.tooltip_text.is_empty(), "Native Dauertooltips bleiben deaktiviert")
	_check(screen.registered_info_source_count() == 8, "Alle Forschungs- und Talentknoten besitzen eine Informationsquelle")
	var registrations := screen.context_detail_registrations()
	_check(registrations.size() == 8, "ContextDetail-API gibt jede aktuelle Quelle genau einmal aus")
	var registration_ids: Dictionary = {}
	for registration in registrations:
		_check(bool(registration.get("hover_enabled", false)), "Automatische Kontextinformation ist ausschließlich Hover-registriert")
		var registration_id := StringName(registration.get("id", &""))
		_check(registration_id != &"" and not registration_ids.has(registration_id), "Jede Kontextquelle besitzt eine eindeutige stabile ID")
		registration_ids[registration_id] = true
	_check(registration_ids.has(&"research:research_available") and registration_ids.has(&"talent:manual_treatment_aim"), "Stabile IDs unterscheiden Forschungs- und Talentquellen")

	var intents := {
		"tab": StringName(),
		"research": StringName(),
		"talent": StringName(),
		"talent_remove": StringName(),
		"reset": 0,
		"back": 0,
	}
	screen.tab_changed.connect(func(tab: StringName) -> void: intents["tab"] = tab)
	screen.research_purchase.connect(func(id: StringName) -> void: intents["research"] = id)
	screen.talent_toggle.connect(func(id: StringName) -> void: intents["talent"] = id)
	screen.talent_rank_remove.connect(func(id: StringName) -> void: intents["talent_remove"] = id)
	screen.talent_reset.connect(func() -> void: intents["reset"] = int(intents["reset"]) + 1)
	screen.back.connect(func() -> void: intents["back"] = int(intents["back"]) + 1)
	locked_research.pressed.emit()
	_check(intents["research"] == StringName(), "Gesperrte Forschung emittiert keine Kaufabsicht")
	available_research.pressed.emit()
	_check(intents["research"] == &"research_available", "Verfügbare Forschung emittiert ihre stabile ID")
	screen.talent_tab_action().pressed.emit()
	_check(intents["tab"] == &"talents" and screen.selected_tab() == &"talents", "Tabaktion wechselt sichtbar und emittiert eine Absicht")
	var available_talent := screen.talent_action(&"manual_treatment_aim")
	available_talent.pressed.emit()
	_check(intents["talent"] == &"manual_treatment_aim", "Verfügbares Talent emittiert seine stabile ID")
	var root_talent_for_removal := screen.talent_action(&"treatment_damage_training")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	root_talent_for_removal.gui_input.emit(right_click)
	_check(intents["talent_remove"] == &"treatment_damage_training", "Rechtsklick emittiert die stabile ID zum Entfernen eines Talentrangs")
	screen.talent_reset_action().pressed.emit()
	screen.back_action().pressed.emit()
	_check(int(intents["reset"]) == 1, "Neu verteilen emittiert genau eine Absicht")
	_check(int(intents["back"]) == 1, "Rückkehr emittiert genau eine Absicht")

	var planning_tree := screen.talent_branch(&"treatment")
	_check(planning_tree != null and planning_tree.edge_count() == 3, "Root zeichnet alle drei Voraussetzungen als Abwärtsverbindungen")
	_check(screen.find_child("TalentBranch_treatment", true, false) is VBoxContainer, "Talentbaum verzichtet auf eine große umgebende ActionCard")
	var root_talent := screen.talent_action(&"treatment_damage_training")
	var left_talent := screen.talent_action(&"spread_shotgun")
	var child_talent := screen.talent_action(&"manual_treatment_aim")
	var right_talent := screen.talent_action(&"piercing_persistence")
	var bottom_target := root_talent.get_node_or_null(root_talent.focus_neighbor_bottom)
	var top_target := child_talent.get_node_or_null(child_talent.focus_neighbor_top)
	_check(bottom_target == child_talent, "D-Pad nach unten folgt der Talenttopologie")
	_check(top_target == root_talent, "D-Pad nach oben kehrt zum vorausgesetzten Talent zurück")
	_check(left_talent.get_node_or_null(left_talent.focus_neighbor_right) == child_talent, "Der linke Ast erreicht horizontal den mittleren Ast")
	_check(child_talent.get_node_or_null(child_talent.focus_neighbor_left) == left_talent and child_talent.get_node_or_null(child_talent.focus_neighbor_right) == right_talent, "Der mittlere Ast erreicht beide seitlichen Spezialisierungen")
	_check(right_talent.get_node_or_null(right_talent.focus_neighbor_left) == child_talent, "Der rechte Ast kehrt horizontal zum mittleren Ast zurück")
	for branch_talent in [left_talent, child_talent, right_talent]:
		_check(branch_talent.get_node_or_null(branch_talent.focus_neighbor_top) == root_talent, "Jede Spezialisierung kehrt per D-Pad zum Root zurück")
	_check(_state_icon_kind(root_talent) == &"check", "Aktives Talent besitzt Check plus Auswahlfarbe")
	_check(root_talent.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_TALENT_NODE, "Aktiver Root besitzt den zentralen Selected-Ring der Talentrolle")
	_check(String(root_talent.get_meta(&"alveolus_accessible_name", "")).contains("Rang 1 von 1"), "Der zugängliche Rootname nennt den visuellen Rang ausdrücklich")
	_check(_state_icon_kind(child_talent) == &"diamond", "Verfügbares Talent ist zusätzlich zur Farbe mit einem Marker gekennzeichnet")
	var locked_talent := screen.talent_action(&"piercing_persistence")
	_check(_state_icon_kind(locked_talent) == &"locked", "Gesperrtes Talent besitzt Schloss plus gedämpfte Farbe")
	_check(locked_talent.theme_type_variation == AlveolusVisualTheme.TYPE_TALENT_NODE and locked_talent.focus_mode == Control.FOCUS_ALL, "Gesperrtes Talent bewahrt die fokussierbare zentrale Talentrolle")
	var talent_symbols: Dictionary = {}
	for talent_id in [&"treatment_damage_training", &"spread_shotgun", &"manual_treatment_aim", &"piercing_persistence"]:
		var talent_button := screen.talent_action(talent_id)
		var symbol := talent_button.find_child("TalentSymbol", true, false) as SimpleIcon
		_check(symbol != null, "Jeder Talentknoten besitzt ein eigenes Hauptsymbol")
		if symbol != null:
			talent_symbols[symbol.kind] = true
		_check(_descendant_text(talent_button).is_empty(), "Talentknoten zeigt weder Titel, Kosten noch Beschreibung dauerhaft")
		_check(is_equal_approx(talent_button.custom_minimum_size.x, TalentTreeBranch.NODE_WIDTH) and is_equal_approx(talent_button.custom_minimum_size.y, TalentTreeBranch.NODE_HEIGHT) and talent_button.get_combined_minimum_size().y <= TalentTreeBranch.NODE_HEIGHT, "Talentknoten bleibt einschließlich Theme-Innenrändern kompakt und quadratisch")
		_check(talent_button.get_meta(&"alveolus_component", &"") == &"talent_node", "Talentknoten verwendet die zentrale Komponentenrolle talent_node")
		_check(_rank_pip_count(talent_button) == int(talent_button.get_meta(&"talent_rank_maximum", 0)), "Mehrfachränge werden als kompakte Pips sichtbar")
	_check(talent_symbols.size() == 4, "Alle sichtbaren Talentknoten verwenden eindeutig verschiedene Symbole")
	var talent_tooltip := screen.tooltip_provider_for(child_talent)
	_check(talent_tooltip.is_valid() and talent_tooltip == screen.ui_info_provider_for(child_talent), "Talent-Hover und ui_info teilen exakt dieselbe Informationsquelle")
	var talent_payload := screen.info_payload_for(child_talent)
	_check(String(talent_payload.get("body", "")).contains("+2") and String(talent_payload.get("meta", "")).contains("1 P"), "Talentbeschreibung bleibt kurz und nennt Zahlen als Fakten")

	var research_instance := available_research.get_instance_id()
	var talent_instance := child_talent.get_instance_id()
	var research_provider_before := screen.tooltip_provider_for(available_research)
	var talent_provider_before := screen.tooltip_provider_for(child_talent)
	var same_content: Variant = _fixture(2, &"research", "Forschung 18", "4 Talentpunkte · 2 frei")
	_check(same_content.content_hash() == fixture.content_hash(), "Revision ist nicht Teil des Inhalts-Hashs")
	_check(not screen.apply_view_model(same_content), "Neue Revision mit gleichem Inhalt erzeugt keinen UI-Churn")
	_check(screen.applied_revision() == 2, "Inhaltsgleiche Revision wird quittiert")
	_check(screen.research_action(&"research_available").get_instance_id() == research_instance, "Idempotentes Apply bewahrt Karteninstanzen")

	var tab_only_change: Variant = _fixture(3, &"talents", "Forschung 18", "4 Talentpunkte · 2 frei")
	_check(screen.apply_view_model(tab_only_change), "Reiner Tabwechsel wird angewendet")
	_check(screen.research_action(&"research_available").get_instance_id() == research_instance, "Tabwechsel baut Forschungskarten nicht neu")
	_check(screen.selected_tab() == &"talents", "Tabwechsel aus dem ViewModel bleibt autoritativ")

	child_talent.grab_focus()
	await process_frame
	var rank_change: Variant = _rank_change_fixture(4, &"talents")
	_check(screen.apply_view_model(rank_change), "Rang- und Zustandsänderungen werden sichtbar angewendet")
	await process_frame
	_check(screen.research_action(&"research_available").get_instance_id() == research_instance, "Forschungsrang aktualisiert die bestehende Buttoninstanz in-place")
	_check(screen.talent_action(&"manual_treatment_aim").get_instance_id() == talent_instance, "Talentrang aktualisiert die bestehende Buttoninstanz in-place")
	_check(get_root().gui_get_focus_owner() == child_talent, "In-place-Rangupdate bewahrt den Fokus am Ausgangselement")
	_check(screen.tooltip_provider_for(screen.research_action(&"research_available")) == research_provider_before, "Forschungsquelle bewahrt ihren stabilen Provider")
	_check(screen.tooltip_provider_for(screen.talent_action(&"manual_treatment_aim")) == talent_provider_before, "Talentquelle bewahrt ihren stabilen Provider")
	var updated_research_payload := screen.info_payload_for(screen.research_action(&"research_available"))
	_check(String(updated_research_payload.get("body", "")).contains("+5 %") and String(updated_research_payload.get("meta", "")) == "3 Forschung", "Stabiler Forschungsprovider liefert die neuen Rangfakten")
	var updated_talent_payload := screen.info_payload_for(screen.talent_action(&"manual_treatment_aim"))
	_check(String(updated_talent_payload.get("body", "")).contains("+3") and String(updated_talent_payload.get("meta", "")) == "3 P", "Stabiler Talentprovider liefert die neuen Rangfakten")
	_check(_state_icon_kind(screen.talent_action(&"manual_treatment_aim")) == &"check", "In-place-Talentupdate aktualisiert den sichtbaren Zustand")
	_check(screen.talent_action(&"manual_treatment_aim").theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_TALENT_NODE, "In-place-Talentupdate wechselt in die zentrale Selected-Talentrolle")
	_check(int(screen.talent_action(&"manual_treatment_aim").get_meta(&"talent_rank_current", 0)) == 1, "In-place-Talentupdate aktualisiert die sichtbaren Rangpips")

	screen.size = Vector2(850.0, 720.0)
	await process_frame
	_check(screen.research_columns() == 2 and unlock_grid.columns == 2 and screen.talent_columns() == 1, "Mittlere Breite nutzt in beiden Laborgruppen zwei Forschungsspalten und einen Root-Baum")
	screen.size = Vector2(640.0, 720.0)
	await process_frame
	_check(screen.research_columns() == 1 and screen.talent_columns() == 1, "Kompakte Breite verwendet eine Spalte")
	_check(screen.default_focus_control() == screen.talent_tab_action(), "Standardfokus folgt dem sichtbaren Tab")

	var locked_talents: Variant = _talent_lock_fixture(5)
	_check(screen.apply_view_model(locked_talents), "Fall-2-Sperre wird als eigener Fortschrittszustand angewendet")
	await process_frame
	_check(not screen.talents_unlocked(), "Talente bleiben vor Fall-2-Abschluss semantisch gesperrt")
	_check(screen.talent_lock_panel().is_visible_in_tree(), "Talente zeigen die vollflächige Padlock-Sperrfläche")
	var talent_host := screen.find_child("TalentViewHost", true, false) as Control
	_check(talent_host != null and screen.talent_lock_panel().get_global_rect().is_equal_approx(talent_host.get_global_rect()), "Padlock bedeckt die komplette Talent-Inhaltsfläche")
	_check(screen.talent_lock_panel().mouse_filter == Control.MOUSE_FILTER_STOP, "Die vollflächige Sperre blockiert Eingaben auf den verdeckten Baum")
	_check(not screen.talent_reset_action().visible and not screen.talent_branch(&"treatment").is_visible_in_tree(), "Gesperrte Talente legen weder Reset noch Talentbaum unter die Sperrfläche")
	var lock_icon := screen.talent_lock_panel().find_child("TalentLockIcon", true, false) as SimpleIcon
	var lock_copy := screen.talent_lock_panel().find_child("TalentLockCopy", true, false) as Label
	_check(lock_icon != null and lock_icon.kind == &"locked", "Fall-2-Sperre verwendet die zentrale Padlock-Glyphe")
	_check(lock_copy != null and lock_copy.text.contains("Fall 2"), "Fall-2-Sperre erklärt ihre Freischaltbedingung sichtbar")
	intents["talent"] = StringName()
	screen.talent_action(&"manual_treatment_aim").pressed.emit()
	_check(intents["talent"] == StringName(), "Verdeckte Talentknoten emittieren vor Fall-2-Abschluss keine Absicht")
	screen.talent_reset_action().pressed.emit()
	_check(int(intents["reset"]) == 1, "Fall-2-Sperre blockiert auch direkte Resetabsichten")

	_check_source_contracts()
	screen.free()
	_finish()


func _fixture(revision: int, tab: StringName, research_balance: String, talent_balance: String) -> Variant:
	var research: Array = [
		_research_item(&"research_active", "Mehr Leben", "Rang 3/3", "Maximum", ProgressionViewModelScript.ItemState.ACTIVE, false, "+9 Leben", &"research", &"foundation", 3, 3),
		_research_item(&"research_available", "Mehr Erfahrung", "Rang 0/3", "2 Forschung", ProgressionViewModelScript.ItemState.AVAILABLE, true, "+0 % Erfahrung", &"research", &"foundation", 0, 3),
		_research_item(&"research_locked", "Fetter lazer", "Rang 0/1", "Nach Fall 1", ProgressionViewModelScript.ItemState.LOCKED, false, "Gesperrt", &"question", &"unlock", 0, 1),
		_research_item(&"research_fourth", "Bewegungstraining", "Rang 1/3", "6 Forschung", ProgressionViewModelScript.ItemState.LOCKED, false, "+3 % Geschwindigkeit", &"research", &"foundation", 1, 3),
	]
	return ProgressionViewModelScript.create(
		revision,
		tab,
		research_balance,
		talent_balance,
		true,
		research,
		_fixture_branches()
	)


func _rank_change_fixture(revision: int, tab: StringName) -> Variant:
	var research: Array = [
		_research_item(&"research_active", "Mehr Leben", "Rang 3/3", "Maximum", ProgressionViewModelScript.ItemState.ACTIVE, false, "+9 Leben", &"research", &"foundation", 3, 3),
		ProgressionViewModelScript.ResearchItemViewModel.create(
			&"research_available",
			"Mehr Erfahrung",
			"Rang 1/3",
			"3 Forschung",
			&"research",
			ProgressionViewModelScript.ItemState.AVAILABLE,
			true,
			_info("Mehr Erfahrung", "+5 % Erfahrung.", "3 Forschung", &"research", AlveolusVisualTheme.GOLD),
			"+5 % Erfahrung",
			false,
			&"foundation",
			1,
			3
		),
		_research_item(&"research_locked", "Erweiterte Analyse", "Rang 0/1", "4 Forschung", ProgressionViewModelScript.ItemState.LOCKED, false, "+0 Analyse", &"research", &"unlock", 0, 1),
		_research_item(&"research_fourth", "Bewegungstraining", "Rang 1/3", "6 Forschung", ProgressionViewModelScript.ItemState.LOCKED, false, "+3 % Geschwindigkeit", &"research", &"foundation", 1, 3),
	]
	var branches := _fixture_branches()
	branches[0] = _branch(&"treatment", "Behandlung", &"treatment", AlveolusVisualTheme.TEAL, [
		_talent(&"treatment_damage_training", "Behandlungstraining", "1/1 · Max", 0, 1, PackedStringArray(), ProgressionViewModelScript.ItemState.ACTIVE, false, 1, 1),
		_talent(&"spread_shotgun", "Schrotwirkung", "0/1 · 1 P", 1, 0, PackedStringArray(["treatment_damage_training"]), ProgressionViewModelScript.ItemState.AVAILABLE, true, 0, 1),
		ProgressionViewModelScript.TalentNodeViewModel.create(
			&"manual_treatment_aim",
			"Manuelles Behandlungsziel",
			"1/1 · Max",
			&"target",
			1,
			1,
			PackedStringArray(["treatment_damage_training"]),
			ProgressionViewModelScript.ItemState.ACTIVE,
			false,
			_info("Manuelles Behandlungsziel", "+3 Zielpräzision.", "3 P", &"target", AlveolusVisualTheme.TEAL),
			1,
			1
		),
		_talent(&"piercing_persistence", "Durchdringende Ausdauer", "0/2 · 1 P", 1, 2, PackedStringArray(["treatment_damage_training"]), ProgressionViewModelScript.ItemState.LOCKED, false, 0, 2),
	])
	return ProgressionViewModelScript.create(
		revision,
		tab,
		"Forschung 15",
		"4 Talentpunkte · 1 frei",
		true,
		research,
		branches
	)


func _research_item(
	id: StringName,
	title: String,
	rank: String,
	cost: String,
	state: int,
	interactive: bool,
	total_effect: String,
	icon_kind: StringName = &"research",
	group_id: StringName = &"foundation",
	rank_current: int = 0,
	rank_maximum: int = 0
) -> Variant:
	var info_body := "Wird nach Abschluss von Fall 1 freigeschaltet." if icon_kind == &"question" else "Wirkung pro Rang von %s." % title
	return ProgressionViewModelScript.ResearchItemViewModel.create(
		id,
		title,
		rank,
		cost,
		icon_kind,
		state,
		interactive,
		_info(title, info_body, cost, icon_kind, AlveolusVisualTheme.GOLD),
		total_effect,
		icon_kind == &"question",
		group_id,
		rank_current,
		rank_maximum
	)


func _fixture_branches() -> Array:
	return [
		_branch(&"treatment", "Behandlung", &"treatment", AlveolusVisualTheme.TEAL, [
			_talent(&"treatment_damage_training", "Behandlungstraining", "1/1 · Max", 0, 1, PackedStringArray(), ProgressionViewModelScript.ItemState.ACTIVE, false, 1, 1),
			_talent(&"spread_shotgun", "Schrotwirkung", "0/1 · 1 P", 1, 0, PackedStringArray(["treatment_damage_training"]), ProgressionViewModelScript.ItemState.AVAILABLE, true, 0, 1),
			_talent(&"manual_treatment_aim", "Manuelles Behandlungsziel", "0/1 · 1 P", 1, 1, PackedStringArray(["treatment_damage_training"]), ProgressionViewModelScript.ItemState.AVAILABLE, true, 0, 1),
			_talent(&"piercing_persistence", "Durchdringende Ausdauer", "0/2 · 1 P", 1, 2, PackedStringArray(["treatment_damage_training"]), ProgressionViewModelScript.ItemState.LOCKED, false, 0, 2),
		]),
	]


func _talent_lock_fixture(revision: int) -> Variant:
	var source: Variant = _fixture(revision, &"talents", "Forschung 18", "Talente gesperrt")
	return ProgressionViewModelScript.create(
		revision,
		&"talents",
		source.research_balance_text(),
		source.talent_balance_text(),
		true,
		source.research_items(),
		source.talent_branches(),
		false,
		"Schließe Fall 2 ab, um Talente freizuschalten."
	)


func _branch(id: StringName, title: String, icon: StringName, accent: Color, nodes: Array) -> Variant:
	return ProgressionViewModelScript.TalentBranchViewModel.create(id, title, icon, accent, nodes)


func _talent(
	id: StringName,
	title: String,
	cost: String,
	tier: int,
	lane: int,
	required_ids: PackedStringArray,
	state: int,
	interactive: bool,
	rank_current: int,
	rank_maximum: int
) -> Variant:
	return ProgressionViewModelScript.TalentNodeViewModel.create(
		id,
		title,
		cost,
		&"plan",
		tier,
		lane,
		required_ids,
		state,
		interactive,
		_info(title, "+2 Kapazität.", cost, &"treatment", AlveolusVisualTheme.TEAL),
		rank_current,
		rank_maximum
	)


func _info(title: String, body: String, meta: String, icon: StringName, accent: Color) -> Variant:
	return ProgressionViewModelScript.InfoViewModel.create(title, body, meta, icon, accent)


func _state_icon_kind(root: Node) -> StringName:
	var icon := root.find_child("StateIcon", true, false) as SimpleIcon
	return icon.kind if icon != null else &""


func _primary_icon_kind(root: Node) -> StringName:
	var icon := root.find_child("PrimaryIcon", true, false) as SimpleIcon
	return icon.kind if icon != null else &""


func _descendant_text(root: Node) -> String:
	var parts := PackedStringArray()
	for label_node in root.find_children("*", "Label", true, false):
		parts.append((label_node as Label).text)
	return " ".join(parts)


func _rank_pip_count(root: Node) -> int:
	var rank_strip := root.find_child("TalentRankPips", true, false)
	if rank_strip == null or rank_strip.get_child_count() != 1:
		return 0
	return rank_strip.get_child(0).get_child_count()


func _rank_segment_count(root: Node) -> int:
	return root.find_children("ResearchRankSegment_*", "ColorRect", true, false).size()


func _active_rank_segment_count(root: Node) -> int:
	var result := 0
	for node in root.find_children("ResearchRankSegment_*", "ColorRect", true, false):
		var segment := node as ColorRect
		if segment != null and segment.color.is_equal_approx(AlveolusVisualTheme.GOLD):
			result += 1
	return result


func _check_source_contracts() -> void:
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/screens/progression_screen.gd")
	var model_source := FileAccess.get_file_as_string("res://scripts/ui/view_models/progression_screen_view_model.gd")
	var branch_source := FileAccess.get_file_as_string("res://scripts/ui/talent_tree_branch.gd")
	for forbidden in ["MetaProgressionState", "ContentCatalog", "SaveRepository", "PlayerStats", "RunState"]:
		_check(not screen_source.contains(forbidden), "Progression-Screen greift nicht auf %s zu" % forbidden)
		_check(not model_source.contains(forbidden), "Progression-ViewModel greift nicht auf %s zu" % forbidden)
	_check(not model_source.contains("AlveolusVisualTheme"), "ViewModel hängt nicht vom visuellen Theme ab")
	_check(not screen_source.contains("StyleBox"), "Progression-Screen erzeugt keine lokale StyleBox-Kopie")
	_check(not screen_source.contains("selection_card("), "Progression verwendet keine 88-px-SelectionCard für kompakte Forschung oder Talente")
	_check(screen_source.contains("AlveolusUIComponents.compact_research") and screen_source.contains("AlveolusUIComponents.talent_node"), "Progression konstruiert beide kompakten Rollen über zentrale Komponenten")
	_check(not screen_source.contains("Shader"), "Progression-Screen erzeugt keinen lokalen Shader")
	_check(not screen_source.contains("func _process("), "Progression-Screen definiert keine Prozessschleife")
	_check(not screen_source.contains("func _physics_process("), "Progression-Screen definiert keine Physikschleife")
	_check(not screen_source.contains("focus_entered.connect"), "Fokus allein öffnet keine Detailkarte")
	_check(screen_source.contains("_sync_research") and screen_source.contains("_refresh_talents"), "Rangänderungen aktualisieren vorhandene Karten differenziell")
	_check(screen_source.contains("context_detail_id") and screen_source.contains("_info_payload_for_stable_id"), "Kontextprovider werden über stabile fachliche IDs aufgelöst")
	_check(screen_source.contains("TALENT_SYMBOLS_BY_ID") and screen_source.contains("_build_talent_symbol_content"), "Talentbaum baut seine Knoten ausschließlich aus eindeutigen Symbolen")
	_check(screen_source.contains("RESEARCH_WIDE_COLUMNS := 4") and screen_source.contains("logical_width >= 1100.0"), "Breite Forschung besitzt einen expliziten Vier-Spalten-Vertrag")
	_check(screen_source.contains("ResearchGroup_foundation") or screen_source.contains("_build_research_group"), "Forschung baut ein gruppiertes Laborboard statt eines einzelnen Kartenrasters")
	_check(screen_source.contains("TalentRankPips") and screen_source.contains("talent_rank_current"), "Talentknoten stellen Mehrfachränge redundant als Pips dar")
	_check(not screen_source.contains("AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)"), "Talentbaum erzeugt keine große ActionCard-Fläche")
	_check(branch_source.contains("draw_polyline") and not branch_source.contains("draw_circle"), "Talentverbindungen verwenden Linien ohne Kreispunkte")
	_check(model_source.contains("Array[ResearchItemViewModel]") and model_source.contains("Array[TalentBranchViewModel]"), "ViewModel hält Kindeinträge typisiert")
	_check(model_source.contains("total_effect_text_value") and model_source.contains("Gesamt: %s"), "Gesamtwirkung wird als vorbereiteter Wert ausschließlich im Detailpayload ergänzt")
	_check(model_source.contains("milestone_lock_cover_value") and screen_source.contains("ResearchMilestoneLock"), "Der Lazer-Meilenstein transportiert seine Vollflächensperre explizit statt über jeden Locked-Zustand")
	_check(model_source.contains("group_id_value") and model_source.contains("rank_current_value") and screen_source.contains("ResearchRankSegments"), "Forschungsgruppe und Rangsegmente gelangen als reine Präsentationsprimitive in die Oberfläche")
	_check(model_source.contains("rank_current_value") and model_source.contains("rank_maximum_value"), "Talentränge gelangen als reine Präsentationsprimitive ins ViewModel")


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_PROGRESSION_SCREEN_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
