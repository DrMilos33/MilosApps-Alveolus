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
	_check(fixture.research_item_count() == 3, "ViewModel bewahrt alle Forschungskarten")
	_check(fixture.talent_branch_count() == 3, "ViewModel bewahrt genau drei Talentäste")
	var copied_research: Array = fixture.research_items()
	copied_research.clear()
	_check(fixture.research_item_count() == 3, "Ausgelesene Forschungsliste verändert das ViewModel nicht")
	var copied_branches: Array = fixture.talent_branches()
	var first_branch_copy: Variant = copied_branches[0]
	copied_branches.clear()
	_check(fixture.talent_branch_count() == 3, "Ausgelesene Astliste verändert das ViewModel nicht")
	_check(first_branch_copy != fixture.talent_branches()[0], "Ast- und Knotendaten werden bei jedem Auslesen tief kopiert")

	_check(screen.apply_view_model(fixture), "Erstes Progression-ViewModel wird angewendet")
	await process_frame
	await process_frame
	_check(screen.selected_tab() == &"research", "ViewModel bestimmt den sichtbaren Tab")
	_check(screen.research_tab_action().theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB, "Aktiver Forschungstab verwendet den lesbaren Selected-Zustand")
	_check(screen.talent_tab_action().theme_type_variation == AlveolusVisualTheme.TYPE_SEGMENTED_TAB, "Inaktiver Talenttab bleibt visuell getrennt")
	_check(screen.research_columns() == 3, "Breite Forschung nutzt drei Spalten")
	_check(screen.talent_columns() == 3, "Breiter Talentbaum nutzt drei Äste nebeneinander")

	var active_research := screen.research_action(&"research_active")
	var available_research := screen.research_action(&"research_available")
	var locked_research := screen.research_action(&"research_locked")
	_check(active_research.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CARD, "Aktive Forschung verwendet die semantische Auswahlkarte")
	_check(_state_icon_kind(active_research) == &"check", "Aktive Forschung ist zusätzlich mit Check markiert")
	_check(bool(available_research.get_meta(&"item_interactive", false)), "Verfügbare Forschung ist interaktiv")
	_check(not bool(locked_research.get_meta(&"item_interactive", true)), "Gesperrte Forschung löst keine Kaufabsicht aus")
	_check(_state_icon_kind(locked_research) == &"locked", "Gesperrte Forschung ist zusätzlich mit Schloss markiert")
	_check(locked_research.focus_mode == Control.FOCUS_ALL, "Gesperrte Forschung bleibt für ui_info fokussierbar")
	_check(String(locked_research.get_meta(&"alveolus_accessible_name", "")).contains("gesperrt"), "Nicht sichtbarer zugänglicher Name benennt den Zustand ausdrücklich")
	_check(active_research.custom_minimum_size.y <= 76.0, "Forschungskarten bleiben kompakt")
	for card in [active_research, available_research, locked_research]:
		var card_text := _descendant_text(card).to_lower()
		_check(not card_text.contains("aktiv") and not card_text.contains("verfügbar") and not card_text.contains("gesperrt"), "Karten wiederholen ihren Zustand nicht als Statuswort")

	var tooltip_provider := screen.tooltip_provider_for(available_research)
	var explicit_provider := screen.ui_info_provider_for(available_research)
	_check(tooltip_provider.is_valid(), "Forschung stellt einen Hover-Provider bereit")
	_check(explicit_provider.is_valid(), "Forschung stellt denselben Inhalt für ui_info bereit")
	_check(tooltip_provider == explicit_provider, "Hover und ui_info verwenden exakt denselben Provider")
	_check(tooltip_provider.call() == explicit_provider.call(), "Hover und ui_info liefern inhaltsgleiche Payloads")
	_check(screen.info_payload_for(available_research).get("title", "") == "Schnellauswertung", "Informationspayload bleibt quellenspezifisch")
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
	_check(registration_ids.has(&"research:research_available") and registration_ids.has(&"talent:plan_child"), "Stabile IDs unterscheiden Forschungs- und Talentquellen")

	var intents := {
		"tab": StringName(),
		"research": StringName(),
		"talent": StringName(),
		"reset": 0,
		"back": 0,
	}
	screen.tab_changed.connect(func(tab: StringName) -> void: intents["tab"] = tab)
	screen.research_purchase.connect(func(id: StringName) -> void: intents["research"] = id)
	screen.talent_toggle.connect(func(id: StringName) -> void: intents["talent"] = id)
	screen.talent_reset.connect(func() -> void: intents["reset"] = int(intents["reset"]) + 1)
	screen.back.connect(func() -> void: intents["back"] = int(intents["back"]) + 1)
	locked_research.pressed.emit()
	_check(intents["research"] == StringName(), "Gesperrte Forschung emittiert keine Kaufabsicht")
	available_research.pressed.emit()
	_check(intents["research"] == &"research_available", "Verfügbare Forschung emittiert ihre stabile ID")
	screen.talent_tab_action().pressed.emit()
	_check(intents["tab"] == &"talents" and screen.selected_tab() == &"talents", "Tabaktion wechselt sichtbar und emittiert eine Absicht")
	var available_talent := screen.talent_action(&"plan_child")
	available_talent.pressed.emit()
	_check(intents["talent"] == &"plan_child", "Verfügbares Talent emittiert seine stabile ID")
	screen.talent_reset_action().pressed.emit()
	screen.back_action().pressed.emit()
	_check(int(intents["reset"]) == 1, "Neu verteilen emittiert genau eine Absicht")
	_check(int(intents["back"]) == 1, "Rückkehr emittiert genau eine Absicht")

	var planning_tree := screen.talent_branch(&"planning")
	_check(planning_tree != null and planning_tree.edge_count() == 2, "Talentast zeichnet jede Voraussetzung als Verbindung")
	var root_talent := screen.talent_action(&"plan_root")
	var child_talent := screen.talent_action(&"plan_child")
	var bottom_target := root_talent.get_node_or_null(root_talent.focus_neighbor_bottom)
	var top_target := child_talent.get_node_or_null(child_talent.focus_neighbor_top)
	_check(bottom_target == child_talent, "D-Pad nach unten folgt der Talenttopologie")
	_check(top_target == root_talent, "D-Pad nach oben kehrt zum vorausgesetzten Talent zurück")
	_check(_state_icon_kind(root_talent) == &"check", "Aktives Talent besitzt Check plus Auswahlfarbe")
	_check(_state_icon_kind(screen.talent_action(&"plan_locked")) == &"locked", "Gesperrtes Talent besitzt Schloss plus gedämpfte Farbe")
	var talent_symbols: Dictionary = {}
	for talent_id in [&"plan_root", &"plan_child", &"plan_locked", &"diagnosis_root", &"deployment_root"]:
		var talent_button := screen.talent_action(talent_id)
		var symbol := talent_button.find_child("TalentSymbol", true, false) as SimpleIcon
		_check(symbol != null, "Jeder Talentknoten besitzt ein eigenes Hauptsymbol")
		if symbol != null:
			talent_symbols[symbol.kind] = true
		_check(_descendant_text(talent_button).is_empty(), "Talentknoten zeigt weder Titel, Kosten noch Beschreibung dauerhaft")
		_check(is_equal_approx(talent_button.custom_minimum_size.x, TalentTreeBranch.NODE_WIDTH) and is_equal_approx(talent_button.custom_minimum_size.y, TalentTreeBranch.NODE_HEIGHT), "Talentknoten bleibt ein kompakter quadratischer Symbolknoten")
	_check(talent_symbols.size() == 5, "Alle sichtbaren Talentknoten verwenden eindeutig verschiedene Symbole")
	var talent_tooltip := screen.tooltip_provider_for(child_talent)
	_check(talent_tooltip.is_valid() and talent_tooltip == screen.ui_info_provider_for(child_talent), "Talent-Hover und ui_info teilen exakt dieselbe Informationsquelle")
	var talent_payload := screen.info_payload_for(child_talent)
	_check(String(talent_payload.get("body", "")).contains("+2") and String(talent_payload.get("meta", "")).contains("2 P"), "Talentbeschreibung bleibt kurz und nennt Zahlen als Fakten")

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
	_check(screen.talent_action(&"plan_child").get_instance_id() == talent_instance, "Talentrang aktualisiert die bestehende Buttoninstanz in-place")
	_check(get_root().gui_get_focus_owner() == child_talent, "In-place-Rangupdate bewahrt den Fokus am Ausgangselement")
	_check(screen.tooltip_provider_for(screen.research_action(&"research_available")) == research_provider_before, "Forschungsquelle bewahrt ihren stabilen Provider")
	_check(screen.tooltip_provider_for(screen.talent_action(&"plan_child")) == talent_provider_before, "Talentquelle bewahrt ihren stabilen Provider")
	var updated_research_payload := screen.info_payload_for(screen.research_action(&"research_available"))
	_check(String(updated_research_payload.get("body", "")).contains("+25 %") and String(updated_research_payload.get("meta", "")) == "3 Forschung", "Stabiler Forschungsprovider liefert die neuen Rangfakten")
	var updated_talent_payload := screen.info_payload_for(screen.talent_action(&"plan_child"))
	_check(String(updated_talent_payload.get("body", "")).contains("+3") and String(updated_talent_payload.get("meta", "")) == "3 P", "Stabiler Talentprovider liefert die neuen Rangfakten")
	_check(_state_icon_kind(screen.talent_action(&"plan_child")) == &"check", "In-place-Talentupdate aktualisiert den sichtbaren Zustand")

	screen.size = Vector2(850.0, 720.0)
	await process_frame
	_check(screen.research_columns() == 2 and screen.talent_columns() == 2, "Mittlere Breite verwendet zwei Spalten")
	screen.size = Vector2(640.0, 720.0)
	await process_frame
	_check(screen.research_columns() == 1 and screen.talent_columns() == 1, "Kompakte Breite verwendet eine Spalte")
	_check(screen.default_focus_control() == screen.talent_tab_action(), "Standardfokus folgt dem sichtbaren Tab")

	_check_source_contracts()
	screen.free()
	_finish()


func _fixture(revision: int, tab: StringName, research_balance: String, talent_balance: String) -> Variant:
	var research: Array = [
		_research_item(&"research_active", "Frühe Einordnung", "Rang 2/2", "Maximum", ProgressionViewModelScript.ItemState.ACTIVE, false),
		_research_item(&"research_available", "Schnellauswertung", "Rang 0/2", "2 Forschung", ProgressionViewModelScript.ItemState.AVAILABLE, true),
		_research_item(&"research_locked", "Erweiterte Analyse", "Rang 0/1", "4 Forschung", ProgressionViewModelScript.ItemState.LOCKED, false),
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
		_research_item(&"research_active", "Frühe Einordnung", "Rang 2/2", "Maximum", ProgressionViewModelScript.ItemState.ACTIVE, false),
		ProgressionViewModelScript.ResearchItemViewModel.create(
			&"research_available",
			"Schnellauswertung",
			"Rang 1/2",
			"3 Forschung",
			&"research",
			ProgressionViewModelScript.ItemState.AVAILABLE,
			true,
			_info("Schnellauswertung", "+25 % Befundfortschritt.", "3 Forschung", &"research", AlveolusVisualTheme.GOLD)
		),
		_research_item(&"research_locked", "Erweiterte Analyse", "Rang 0/1", "4 Forschung", ProgressionViewModelScript.ItemState.LOCKED, false),
	]
	var branches := _fixture_branches()
	branches[0] = _branch(&"planning", "Planung", &"plan", AlveolusVisualTheme.GOLD, [
		_talent(&"plan_root", "Organisation I", "2 P", 0, 1, PackedStringArray(), ProgressionViewModelScript.ItemState.ACTIVE, true),
		ProgressionViewModelScript.TalentNodeViewModel.create(
			&"plan_child",
			"Organisation II",
			"3 P",
			&"plan",
			1,
			0,
			PackedStringArray(["plan_root"]),
			ProgressionViewModelScript.ItemState.ACTIVE,
			true,
			_info("Organisation II", "+3 Kapazität.", "3 P", &"plan", AlveolusVisualTheme.COBALT)
		),
		_talent(&"plan_locked", "Karte halten", "1 P", 1, 2, PackedStringArray(["plan_root"]), ProgressionViewModelScript.ItemState.LOCKED, false),
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


func _research_item(id: StringName, title: String, rank: String, cost: String, state: int, interactive: bool) -> Variant:
	return ProgressionViewModelScript.ResearchItemViewModel.create(
		id,
		title,
		rank,
		cost,
		&"research",
		state,
		interactive,
		_info(title, "Vollständige Wirkung von %s." % title, cost, &"research", AlveolusVisualTheme.GOLD)
	)


func _fixture_branches() -> Array:
	return [
		_branch(&"planning", "Planung", &"plan", AlveolusVisualTheme.GOLD, [
			_talent(&"plan_root", "Organisation I", "2 P", 0, 1, PackedStringArray(), ProgressionViewModelScript.ItemState.ACTIVE, true),
			_talent(&"plan_child", "Organisation II", "2 P", 1, 0, PackedStringArray(["plan_root"]), ProgressionViewModelScript.ItemState.AVAILABLE, true),
			_talent(&"plan_locked", "Karte halten", "1 P", 1, 2, PackedStringArray(["plan_root"]), ProgressionViewModelScript.ItemState.LOCKED, false),
		]),
		_branch(&"diagnosis", "Diagnose", &"finding", AlveolusVisualTheme.CORAL, [
			_talent(&"diagnosis_root", "Frühe Einordnung", "2 P", 0, 1, PackedStringArray(), ProgressionViewModelScript.ItemState.AVAILABLE, true),
		]),
		_branch(&"deployment", "Einsatz", &"ability", AlveolusVisualTheme.COBALT, [
			_talent(&"deployment_root", "Wechselrhythmus", "1 P", 0, 1, PackedStringArray(), ProgressionViewModelScript.ItemState.LOCKED, false),
		]),
	]


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
	interactive: bool
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
		_info(title, "+2 Kapazität.", cost, &"plan", AlveolusVisualTheme.COBALT)
	)


func _info(title: String, body: String, meta: String, icon: StringName, accent: Color) -> Variant:
	return ProgressionViewModelScript.InfoViewModel.create(title, body, meta, icon, accent)


func _state_icon_kind(root: Node) -> StringName:
	var icon := root.find_child("StateIcon", true, false) as SimpleIcon
	return icon.kind if icon != null else &""


func _descendant_text(root: Node) -> String:
	var parts := PackedStringArray()
	for label_node in root.find_children("*", "Label", true, false):
		parts.append((label_node as Label).text)
	return " ".join(parts)


func _check_source_contracts() -> void:
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/screens/progression_screen.gd")
	var model_source := FileAccess.get_file_as_string("res://scripts/ui/view_models/progression_screen_view_model.gd")
	var branch_source := FileAccess.get_file_as_string("res://scripts/ui/talent_tree_branch.gd")
	for forbidden in ["MetaProgressionState", "ContentCatalog", "SaveRepository", "PlayerStats", "RunState"]:
		_check(not screen_source.contains(forbidden), "Progression-Screen greift nicht auf %s zu" % forbidden)
		_check(not model_source.contains(forbidden), "Progression-ViewModel greift nicht auf %s zu" % forbidden)
	_check(not model_source.contains("AlveolusVisualTheme"), "ViewModel hängt nicht vom visuellen Theme ab")
	_check(not screen_source.contains("StyleBox"), "Progression-Screen erzeugt keine lokale StyleBox-Kopie")
	_check(not screen_source.contains("Shader"), "Progression-Screen erzeugt keinen lokalen Shader")
	_check(not screen_source.contains("func _process("), "Progression-Screen definiert keine Prozessschleife")
	_check(not screen_source.contains("func _physics_process("), "Progression-Screen definiert keine Physikschleife")
	_check(not screen_source.contains("focus_entered.connect"), "Fokus allein öffnet keine Detailkarte")
	_check(screen_source.contains("_sync_research") and screen_source.contains("_refresh_talents"), "Rangänderungen aktualisieren vorhandene Karten differenziell")
	_check(screen_source.contains("context_detail_id") and screen_source.contains("_info_payload_for_stable_id"), "Kontextprovider werden über stabile fachliche IDs aufgelöst")
	_check(screen_source.contains("TALENT_SYMBOLS_BY_ID") and screen_source.contains("_build_talent_symbol_content"), "Talentbaum baut seine Knoten ausschließlich aus eindeutigen Symbolen")
	_check(branch_source.contains("draw_polyline") and not branch_source.contains("draw_circle"), "Talentverbindungen verwenden Linien ohne Kreispunkte")
	_check(model_source.contains("Array[ResearchItemViewModel]") and model_source.contains("Array[TalentBranchViewModel]"), "ViewModel hält Kindeinträge typisiert")


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
