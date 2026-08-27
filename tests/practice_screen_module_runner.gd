extends SceneTree

const PracticeScreenScript := preload("res://scripts/ui/screens/practice_screen.gd")
const PracticeViewModelScript := preload("res://scripts/ui/view_models/practice_screen_view_model.gd")
const FIRST_EVENT_ID := &"event_test:early_localized_focus"

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := PracticeScreenScript.new() as PracticeScreen
	screen.theme = AlveolusVisualTheme.create_theme()
	screen.size = Vector2(1280.0, 720.0)
	get_root().add_child(screen)
	await process_frame

	_check(screen.route_id() == &"practice", "Praxis meldet eine stabile Route-ID")
	_check(not screen.is_processing(), "Praxis besitzt keine dauerhafte Prozessschleife")
	_check(not screen.is_physics_processing(), "Praxis besitzt keine Physikschleife")
	_check(screen.oversampling_with_scale == CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED, "Praxis aktiviert skalierungsabhängiges Font-Oversampling")
	_check(screen.layout_columns() == 4, "Breite Praxis zeigt die vier Haupttests nebeneinander")
	_check(screen.event_layout_columns() == 2, "Breite Praxis zeigt Eventprofile zweispaltig")
	_check(screen.boss_layout_columns() == 2, "Breite Praxis zeigt Bossprofile zweispaltig")

	var shell := screen.get_node_or_null("PracticePageShell") as PanelContainer
	_check(shell != null and shell.theme_type_variation == AlveolusVisualTheme.TYPE_PAGE_CANVAS, "Praxis verwendet den zentralen PageShell")
	_check_page_header_contract(shell, "Praxis")
	var scenario_card := screen.find_child("ScenarioSelectionCard", true, false) as PanelContainer
	var event_card := screen.find_child("EventScenarioSelectionCard", true, false) as PanelContainer
	var boss_card := screen.find_child("BossProfileSelectionCard", true, false) as PanelContainer
	_check(scenario_card != null and scenario_card.theme_type_variation == AlveolusVisualTheme.TYPE_OPEN_GROUP and scenario_card.get_meta(&"alveolus_component", &"") == &"open_group", "Testauswahl verwendet den zentralen offenen Kartenträger")
	_check(event_card != null and event_card.theme_type_variation == AlveolusVisualTheme.TYPE_OPEN_GROUP and event_card.get_meta(&"alveolus_component", &"") == &"open_group", "Eventauswahl verwendet denselben zentralen offenen Kartenträger wie die Bossauswahl")
	_check(boss_card != null and boss_card.theme_type_variation == AlveolusVisualTheme.TYPE_OPEN_GROUP and boss_card.get_meta(&"alveolus_component", &"") == &"open_group", "Bossauswahl verwendet den zentralen offenen Kartenträger")
	_check(screen.back_action().theme_type_variation == AlveolusVisualTheme.TYPE_NAVIGATION_BUTTON, "Rückkehr verwendet die zentrale Navigation")
	var back_action := screen.back_action() as IconTextButton
	_check(
		back_action != null \
			and back_action.get_meta(&"alveolus_component", &"") == &"page_navigation_action" \
			and back_action.caption.text == "Campus" \
			and back_action.get_meta(&"alveolus_accessible_name", "") == "Zum Campus" \
			and back_action.tooltip_text.is_empty(),
		"Breite Praxisnavigation zeigt das kurze Ziel und bewahrt den vollständigen zugänglichen Namen"
	)

	var scenarios := _scenario_offers()
	var profiles := _boss_profile_offers()
	var first := PracticeViewModelScript.create(1, true, &"spawn_test", &"", scenarios, profiles)
	_check(first.revision() == 1, "ViewModel bewahrt seine Revision")
	_check(first.content_hash() != 0, "ViewModel liefert einen Inhalts-Hash")
	_check(first.scenario_offer_count() == 9, "ViewModel bewahrt drei direkte und sechs fallbezogene Testangebote")
	_check(first.primary_scenario_offers().size() == 3, "ViewModel trennt nur die drei echten Hauptangebote ab")
	_check(first.event_scenario_offer_count() == 6, "ViewModel leitet sechs Eventprofile aus den übergebenen Angeboten ab")
	_check(first.boss_profile_offer_count() == 4, "ViewModel bewahrt genau vier Bossprofile")
	_check(first.selected_scenario_id() == &"spawn_test", "ViewModel bewahrt eine gültige Testauswahl")
	_check(first.selected_boss_profile_id() == &"", "Nicht-Boss-Test verwirft eine Bossauswahl")
	var presentation_group := PracticeViewModelScript.create(
		1,
		true,
		PracticeViewModelScript.EVENT_TEST_GROUP_ID,
		&"",
		scenarios,
		profiles
	)
	_check(presentation_group.selected_scenario_id() == &"", "Lokale Event-Hauptkachel wird nie als erfundene Runtime-Auswahl validiert")
	var returned_scenarios: Array = first.scenario_offers()
	returned_scenarios.clear()
	_check(first.scenario_offer_count() == 9, "Ausgelesene Testliste kann das ViewModel nicht verändern")
	_check(first.scenario_offer_at(0) != scenarios[0], "Ausgelesene Testangebote sind tiefe Kopien")
	var returned_profiles: Array = first.boss_profile_offers()
	returned_profiles.clear()
	_check(first.boss_profile_offer_count() == 4, "Ausgelesene Bossliste kann das ViewModel nicht verändern")

	_check(screen.apply_view_model(first), "Erstes Praxis-ViewModel wird angewendet")
	_check(screen.tests_visible(), "Integrator kann lokale Tests sichtbar schalten")
	_check(not screen.boss_profile_selection_visible(), "Spawn-Test reserviert keinen Platz für Bossprofile")
	_check(not screen.event_scenario_selection_visible(), "Spawn-Test reserviert keinen Platz für Eventprofile")
	_check(screen.scenario_action(&"spawn_test") != null, "Spawn-Test ist über stabile ID adressierbar")
	_check(screen.scenario_action(&"obstacle_test") != null, "Hindernis-Test ist über stabile ID adressierbar")
	_check(screen.scenario_action(&"boss_test") != null, "Boss-Test ist über stabile ID adressierbar")
	_check(screen.scenario_action(PracticeViewModelScript.EVENT_TEST_GROUP_ID) != null, "Event-Test besitzt genau eine lokale Hauptkachel")
	_check(screen.event_scenario_action(FIRST_EVENT_ID) != null, "Fallbezogenes Eventangebot bleibt über seine vollständige stabile ID adressierbar")
	var scenario_grid := screen.find_child("ScenarioOffers", true, false) as GridContainer
	_check(scenario_grid != null and scenario_grid.get_child_count() == 4, "Die Hauptauswahl enthält exakt Spawn, Hindernis, Boss und Event")
	_check(screen.scenario_action(&"spawn_test").theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CARD, "Gewählter Test verwendet die zentrale Auswahlvariante")
	_check(screen.default_focus_control() == screen.scenario_action(&"spawn_test"), "Erster sinnvoller Praxisfokus liegt auf dem ersten Test")
	var spawn_instance := screen.scenario_action(&"spawn_test").get_instance_id()

	var same_content := PracticeViewModelScript.create(2, true, &"spawn_test", &"", scenarios, profiles)
	_check(same_content.content_hash() == first.content_hash(), "Revision gehört nicht zum Inhalts-Hash")
	_check(not screen.apply_view_model(same_content), "Neue Revision mit identischem Inhalt erzeugt keinen UI-Neuaufbau")
	_check(screen.applied_revision() == 2, "Inhaltsgleiche neue Revision wird dennoch quittiert")
	_check(screen.scenario_action(&"spawn_test").get_instance_id() == spawn_instance, "Idempotentes Apply bewahrt bestehende Controls")
	_check(not screen.apply_view_model(first), "Veraltete Revision wird verworfen")

	var scenario_intents: Array[StringName] = []
	var profile_intents: Array[StringName] = []
	var back_intents := {"count": 0}
	screen.scenario_selected.connect(func(id: StringName) -> void: scenario_intents.append(id))
	screen.boss_profile_selected.connect(func(id: StringName) -> void: profile_intents.append(id))
	screen.back_requested.connect(func() -> void: back_intents["count"] = int(back_intents["count"]) + 1)

	screen.scenario_action(PracticeViewModelScript.EVENT_TEST_GROUP_ID).pressed.emit()
	await process_frame
	_check(screen.event_scenario_selection_visible(), "Event-Test öffnet erst die fallbezogene Unterauswahl")
	_check(not screen.boss_profile_selection_visible(), "Event- und Boss-Unterauswahl sind nie gleichzeitig sichtbar")
	_check(scenario_intents.is_empty(), "Die lokale Event-Hauptkachel emittiert keine erfundene Runtime-ID")
	_check(screen.default_focus_control() == screen.event_scenario_action(FIRST_EVENT_ID), "Geöffnete Eventauswahl setzt den Standardfokus auf das erste Fallprofil")
	_check(screen.get_viewport().gui_get_focus_owner() == screen.event_scenario_action(FIRST_EVENT_ID), "Eventauswahl verschiebt den aktiven Fokus in die neue oberste Stufe")
	_check(screen.scenario_action(PracticeViewModelScript.EVENT_TEST_GROUP_ID).theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CARD, "Offene Eventauswahl markiert ihre Hauptkachel")
	screen.event_scenario_action(FIRST_EVENT_ID).pressed.emit()
	_check(scenario_intents == [FIRST_EVENT_ID], "Erst das gewählte Fallprofil emittiert unverändert seine vollständige Event-ID")
	_check(screen.handle_ui_cancel(), "Cancel schließt eine sichtbare Event-Unterauswahl")
	await process_frame
	_check(not screen.event_scenario_selection_visible(), "Cancel entfernt zuerst nur die Event-Unterauswahl")
	_check(screen.get_viewport().gui_get_focus_owner() == screen.scenario_action(PracticeViewModelScript.EVENT_TEST_GROUP_ID), "Cancel stellt den Fokus auf der Event-Hauptkachel wieder her")
	_check(int(back_intents["count"]) == 0, "Unterauswahl-Cancel verlässt die Praxisseite nicht")

	screen.scenario_action(&"obstacle_test").pressed.emit()
	_check(scenario_intents[-1] == &"obstacle_test", "Hindernis-Test startet wie bisher direkt über seine stabile ID")
	screen.scenario_action(&"spawn_test").pressed.emit()
	_check(scenario_intents[-1] == &"spawn_test", "Spawn-Test startet wie bisher direkt über seine stabile ID")

	screen.scenario_action(&"boss_test").pressed.emit()
	_check(scenario_intents[-1] == &"boss_test", "Boss-Hauptkachel reicht weiterhin ihre stabile ID an den Integrator")
	var boss_selected := PracticeViewModelScript.create(3, true, &"boss_test", &"", scenarios, profiles)
	_check(screen.apply_view_model(boss_selected), "Boss-Test-Auswahl wird angewendet")
	await process_frame
	_check(screen.boss_profile_selection_visible(), "Boss-Test blendet die zusätzliche Profilauswahl ein")
	_check(not screen.event_scenario_selection_visible(), "Boss-Test schließt eine eventuell offene Eventauswahl")
	_check(screen.get_viewport().gui_get_focus_owner() == screen.boss_profile_action(&"intro_boss"), "Bossauswahl verschiebt den Fokus wie die Eventauswahl in ihre Profilstufe")
	_check(screen.scenario_action(&"spawn_test").get_instance_id() == spawn_instance, "Reine Auswahländerung baut Testkarten nicht neu")
	_check(screen.boss_profile_action(&"intro_boss") != null, "Intro-Bossprofil ist adressierbar")
	_check(screen.boss_profile_action(&"bacterial_core") != null, "Bakterienkernprofil ist adressierbar")
	_check(screen.boss_profile_action(&"diamond_infection_focus") != null, "Rautenprofil ist adressierbar")
	_check(screen.boss_profile_action(&"standard_infection_focus") != null, "Standardprofil ist adressierbar")

	var profile_selected := PracticeViewModelScript.create(
		4,
		true,
		&"boss_test",
		&"diamond_infection_focus",
		scenarios,
		profiles
	)
	_check(screen.apply_view_model(profile_selected), "Bossprofilauswahl wird angewendet")
	_check(profile_selected.selected_scenario_requires_boss_profile(), "Boss-Test kennzeichnet seine Profilpflicht")
	_check(screen.boss_profile_action(&"diamond_infection_focus").theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CHOICE_ROW, "Gewähltes Bossprofil verwendet die zentrale Auswahlvariante")

	screen.boss_profile_action(&"bacterial_core").pressed.emit()
	screen.back_action().pressed.emit()
	await process_frame
	_check(profile_intents == [&"bacterial_core"], "Bossauswahl emittiert ausschließlich ihre stabile Profil-ID")
	_check(not screen.boss_profile_selection_visible(), "Zurück schließt zuerst nur die Boss-Unterauswahl")
	_check(screen.get_viewport().gui_get_focus_owner() == screen.scenario_action(&"boss_test"), "Geschlossene Bossauswahl stellt den Fokus auf ihrer Hauptkachel wieder her")
	_check(int(back_intents["count"]) == 0, "Boss-Unterauswahl reicht Zurück nicht an den Integrator weiter")
	screen.scenario_action(&"boss_test").pressed.emit()
	await process_frame
	_check(screen.boss_profile_selection_visible(), "Erneuter Klick auf den bereits gewählten Boss-Test öffnet seine Unterauswahl lokal wieder")
	_check(scenario_intents.count(&"boss_test") == 1, "Lokales Wiederöffnen emittiert die Boss-ID nicht doppelt")
	screen.back_action().pressed.emit()
	screen.back_action().pressed.emit()
	_check(int(back_intents["count"]) == 1, "Rückkehr emittiert genau eine Absicht")

	var event_selected := PracticeViewModelScript.create(5, true, FIRST_EVENT_ID, &"", scenarios, profiles)
	_check(screen.apply_view_model(event_selected), "Fallbezogene Eventauswahl wird angewendet")
	await process_frame
	_check(event_selected.selected_scenario_is_event_test(), "ViewModel erkennt ausschließlich die stabile Event-ID als Eventtest")
	_check(screen.event_scenario_selection_visible(), "Eine bestehende Eventauswahl öffnet dieselbe fallbezogene Auswahlstufe")
	_check(screen.event_scenario_action(FIRST_EVENT_ID).theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CHOICE_ROW, "Gewähltes Eventprofil verwendet dieselbe Auswahlvariante wie ein Bossprofil")

	var hidden := PracticeViewModelScript.create(6, false, &"boss_test", &"intro_boss", scenarios, profiles)
	_check(hidden.selected_scenario_id() == &"", "Ausgeblendetes Modell trägt keine versteckte Testauswahl")
	_check(hidden.selected_boss_profile_id() == &"", "Ausgeblendetes Modell trägt keine versteckte Bossauswahl")
	_check(screen.apply_view_model(hidden), "Integrator kann lokale Tests ausblenden")
	_check(not screen.tests_visible(), "Release-Sichtbarkeit wird ausschließlich über das ViewModel angewendet")
	_check(not screen.boss_profile_selection_visible(), "Ausgeblendete Tests zeigen keine Bossprofile")
	_check(not screen.event_scenario_selection_visible(), "Ausgeblendete Tests zeigen keine Eventprofile")
	_check(screen.default_focus_control() == screen.back_action(), "Ohne sichtbare Tests bleibt die Navigation der Standardfokus")

	screen.size = Vector2(800.0, 720.0)
	await process_frame
	_check(screen.layout_columns() == 2, "Mittlere Praxis zeigt zwei Testspalten")
	screen.size = Vector2(580.0, 720.0)
	await process_frame
	_check(screen.layout_columns() == 1, "Kompakte Praxis stapelt Testkarten")
	_check(screen.event_layout_columns() == 1, "Kompakte Praxis stapelt Eventprofile")
	_check(screen.boss_layout_columns() == 1, "Kompakte Praxis stapelt Bossprofile")
	_check(back_action.caption.text.is_empty(), "Kompakte Praxisnavigation zeigt ausschließlich die Zurück-Glyphe")
	_check(back_action.get_meta(&"alveolus_accessible_name", "") == "Zum Campus" and back_action.tooltip_text == "Zum Campus", "Kompakte Praxisnavigation behält vollständigen zugänglichen Namen und Tooltip")
	_check(back_action.get_combined_minimum_size().x >= AlveolusVisualTheme.TOUCH_TARGET_MINIMUM and back_action.get_combined_minimum_size().y >= AlveolusVisualTheme.TOUCH_TARGET_MINIMUM, "Kompakte Praxisnavigation behält ein mindestens 44 px großes Ziel")
	_check(screen.back_action().focus_mode == Control.FOCUS_ALL, "Navigation bleibt per Tastatur und Gamepad fokussierbar")
	_check(screen.scenario_action(&"spawn_test").focus_mode == Control.FOCUS_ALL, "Testauswahl bleibt per Tastatur und Gamepad fokussierbar")

	get_root().size = Vector2i(480, 270)
	screen.size = Vector2(480.0, 270.0)
	for _frame in range(3):
		await process_frame
	var compact_header := _semantic_component(shell, &"page_header")
	_check(_fully_inside(compact_header, screen), "Praxisheader bleibt im logischen 480×270-Host vollständig sichtbar")
	_check(_fully_inside(screen.back_action(), screen) and _fully_inside(screen.back_action(), compact_header), "Praxisnavigation bleibt bei 480×270 vollständig im Header und Host")

	_check_source_contracts()
	screen.free()
	_finish()


func _scenario_offers() -> Array:
	return [
		PracticeViewModelScript.ScenarioOfferViewModel.create(
			&"spawn_test", "Spawn-Test", "Viele kleine und mittlere Gegner", "12 klein · 6 mittel"
		),
		PracticeViewModelScript.ScenarioOfferViewModel.create(
			&"obstacle_test", "Hindernis-Test", "Viele Gegner und Hindernisse", "8 klein · 4 mittel · 3 Hindernisse"
		),
		PracticeViewModelScript.ScenarioOfferViewModel.create(
			&"boss_test", "Boss-Test", "Ein Boss ohne Begleitwellen", "Bossprofil wählen", true, true
		),
		PracticeViewModelScript.ScenarioOfferViewModel.create(
			FIRST_EVENT_ID, "Event-Test · Fall 1", "Aktuelles Eventmonster aus Fall 1", "Originalprofil · keine Wellen"
		),
		PracticeViewModelScript.ScenarioOfferViewModel.create(
			&"event_test:localized_focus", "Event-Test · Fall 2", "Aktuelles Eventmonster aus Fall 2", "Originalprofil · keine Wellen"
		),
		PracticeViewModelScript.ScenarioOfferViewModel.create(
			&"event_test:advancing_infection", "Event-Test · Fall 3", "Aktuelles Eventmonster aus Fall 3", "Originalprofil · keine Wellen"
		),
		PracticeViewModelScript.ScenarioOfferViewModel.create(
			&"event_test:spreading_infection", "Event-Test · Fall 4", "Aktuelles Eventmonster aus Fall 4", "Originalprofil · keine Wellen"
		),
		PracticeViewModelScript.ScenarioOfferViewModel.create(
			&"event_test:critical_infection", "Event-Test · Fall 5", "Aktuelles Eventmonster aus Fall 5", "Originalprofil · keine Wellen"
		),
		PracticeViewModelScript.ScenarioOfferViewModel.create(
			&"event_test:severe_pneumonia", "Event-Test · Fall 6", "Aktuelles Eventmonster aus Fall 6", "Originalprofil · keine Wellen"
		),
	]


func _boss_profile_offers() -> Array:
	return [
		PracticeViewModelScript.BossProfileOfferViewModel.create(
			&"intro_boss", "Intro-Boss", "Intro-Infektionsherd", "Fernkampf · keine Phase"
		),
		PracticeViewModelScript.BossProfileOfferViewModel.create(
			&"bacterial_core", "Bakterienkern", "Lokalisierter Boss", "Nahkampf · Phase 3"
		),
		PracticeViewModelScript.BossProfileOfferViewModel.create(
			&"diamond_infection_focus", "Infektionsherd · Raute", "Schneller Fernkampf", "Phasen 4 + 4"
		),
		PracticeViewModelScript.BossProfileOfferViewModel.create(
			&"standard_infection_focus", "Infektionsherd · Standard", "Robuster Nahkampf", "Phasen 6 + 8"
		),
	]


func _check_source_contracts() -> void:
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/screens/practice_screen.gd")
	var model_source := FileAccess.get_file_as_string("res://scripts/ui/view_models/practice_screen_view_model.gd")
	for forbidden in ["MetaProgressionState", "ContentCatalog", "SaveRepository", "PlayerStats", "RunState", "OS.is_debug_build"]:
		_check(not screen_source.contains(forbidden), "Praxis-Screen greift nicht auf %s zu" % forbidden)
		_check(not model_source.contains(forbidden), "Praxis-ViewModel greift nicht auf %s zu" % forbidden)
	for retired in ["OfflineResearch", "ClinicJob", "offline_claim_requested", "clinic_job_start_requested", "clinic_job_claim_requested"]:
		_check(not screen_source.contains(retired), "Praxis-Screen entfernt Altvertrag %s vollständig" % retired)
		_check(not model_source.contains(retired), "Praxis-ViewModel entfernt Altvertrag %s vollständig" % retired)
	_check(not screen_source.contains("StyleBox"), "Praxis erzeugt keine lokale StyleBox-Kopie")
	_check(not screen_source.contains("Shader"), "Praxis erzeugt keinen lokalen Shader")
	_check(not screen_source.contains("func _process("), "Praxis definiert keine Prozessschleife")
	_check(not screen_source.contains("func _physics_process("), "Praxis definiert keine Physikschleife")
	_check(model_source.contains("Array[ScenarioOfferViewModel]"), "ViewModel hält Tests typisiert")
	_check(model_source.contains("Array[BossProfileOfferViewModel]"), "ViewModel hält Bossprofile typisiert")
	_check(model_source.contains("EVENT_TEST_SCENARIO_PREFIX"), "ViewModel gruppiert Eventangebote ausschließlich über ihren stabilen ID-Vertrag")
	_check(screen_source.contains("func _shortcut_input("), "Praxis konsumiert ui_cancel vor dem globalen Seiten-Back")


func _check_page_header_contract(shell: PanelContainer, expected_title: String) -> void:
	var stack := shell.find_child("PageStack", true, false) as VBoxContainer
	var header := _semantic_component(shell, &"page_header")
	var safe_area := shell.find_child("PageBodySafeArea", true, false) as MarginContainer
	var medallion := header.find_child("PageMedallion", true, false) as PanelContainer if header != null else null
	var icon := header.find_child("PageIcon", true, false) as SimpleIcon if header != null else null
	var title := _page_title(header)
	_check(
		stack != null and header != null and safe_area != null \
			and header.get_parent() == stack and stack.get_child(0) == header \
			and safe_area.get_parent() == stack and stack.get_child(1) == safe_area,
		"%s verwendet PageHeader als direktes Topband vor PageBodySafeArea" % expected_title
	)
	_check(medallion != null and medallion.custom_minimum_size.is_equal_approx(Vector2(44.0, 44.0)), "%s verwendet das 44-px-PageMedallion" % expected_title)
	_check(icon != null and SimpleIcon.supports(icon.kind), "%s verwendet ein semantisches SimpleIcon" % expected_title)
	_check(title != null and title.text == expected_title, "%s zeigt genau den erwarteten Seitentitel" % expected_title)


func _semantic_component(scope: Node, component_id: StringName) -> Control:
	if scope == null:
		return null
	for node in scope.find_children("*", "Control", true, false):
		var control := node as Control
		if control != null and control.get_meta(&"alveolus_component", &"") == component_id:
			return control
	return null


func _page_title(header: Control) -> Label:
	if header == null:
		return null
	for node in header.find_children("*", "Label", true, false):
		var title := node as Label
		if title.theme_type_variation == AlveolusVisualTheme.TYPE_TITLE_LABEL:
			return title
	return null


func _fully_inside(control: Control, container: Control, tolerance: float = 0.5) -> bool:
	if control == null or container == null:
		return false
	var rect := control.get_global_rect()
	var bounds := container.get_global_rect()
	return rect.position.x >= bounds.position.x - tolerance \
		and rect.position.y >= bounds.position.y - tolerance \
		and rect.end.x <= bounds.end.x + tolerance \
		and rect.end.y <= bounds.end.y + tolerance


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_PRACTICE_SCREEN_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
