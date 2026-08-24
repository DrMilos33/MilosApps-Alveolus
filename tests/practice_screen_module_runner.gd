extends SceneTree

const PracticeScreenScript := preload("res://scripts/ui/screens/practice_screen.gd")
const PracticeViewModelScript := preload("res://scripts/ui/view_models/practice_screen_view_model.gd")

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
	_check(screen.layout_columns() == 3, "Breite Praxis zeigt alle drei Tests nebeneinander")
	_check(screen.boss_layout_columns() == 2, "Breite Praxis zeigt Bossprofile zweispaltig")

	var shell := screen.get_node_or_null("PracticePageShell") as PanelContainer
	_check(shell != null and shell.theme_type_variation == AlveolusVisualTheme.TYPE_PAGE_CANVAS, "Praxis verwendet den zentralen PageShell")
	_check_page_header_contract(shell, "Praxis")
	var scenario_card := screen.find_child("ScenarioSelectionCard", true, false) as PanelContainer
	var boss_card := screen.find_child("BossProfileSelectionCard", true, false) as PanelContainer
	_check(scenario_card != null and scenario_card.theme_type_variation == AlveolusVisualTheme.TYPE_ACTION_CARD, "Testauswahl verwendet die zentrale ActionCard")
	_check(boss_card != null and boss_card.theme_type_variation == AlveolusVisualTheme.TYPE_ACTION_CARD, "Bossauswahl verwendet die zentrale ActionCard")
	_check(screen.back_action().theme_type_variation == AlveolusVisualTheme.TYPE_NAVIGATION_BUTTON, "Rückkehr verwendet die zentrale Navigation")

	var scenarios := _scenario_offers()
	var profiles := _boss_profile_offers()
	var first := PracticeViewModelScript.create(1, true, &"spawn_test", &"", scenarios, profiles)
	_check(first.revision() == 1, "ViewModel bewahrt seine Revision")
	_check(first.content_hash() != 0, "ViewModel liefert einen Inhalts-Hash")
	_check(first.scenario_offer_count() == 3, "ViewModel bewahrt genau drei Testangebote")
	_check(first.boss_profile_offer_count() == 4, "ViewModel bewahrt genau vier Bossprofile")
	_check(first.selected_scenario_id() == &"spawn_test", "ViewModel bewahrt eine gültige Testauswahl")
	_check(first.selected_boss_profile_id() == &"", "Nicht-Boss-Test verwirft eine Bossauswahl")
	var returned_scenarios: Array = first.scenario_offers()
	returned_scenarios.clear()
	_check(first.scenario_offer_count() == 3, "Ausgelesene Testliste kann das ViewModel nicht verändern")
	_check(first.scenario_offer_at(0) != scenarios[0], "Ausgelesene Testangebote sind tiefe Kopien")
	var returned_profiles: Array = first.boss_profile_offers()
	returned_profiles.clear()
	_check(first.boss_profile_offer_count() == 4, "Ausgelesene Bossliste kann das ViewModel nicht verändern")

	_check(screen.apply_view_model(first), "Erstes Praxis-ViewModel wird angewendet")
	_check(screen.tests_visible(), "Integrator kann lokale Tests sichtbar schalten")
	_check(not screen.boss_profile_selection_visible(), "Spawn-Test reserviert keinen Platz für Bossprofile")
	_check(screen.scenario_action(&"spawn_test") != null, "Spawn-Test ist über stabile ID adressierbar")
	_check(screen.scenario_action(&"obstacle_test") != null, "Hindernis-Test ist über stabile ID adressierbar")
	_check(screen.scenario_action(&"boss_test") != null, "Boss-Test ist über stabile ID adressierbar")
	_check(screen.scenario_action(&"spawn_test").theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CARD, "Gewählter Test verwendet die zentrale Auswahlvariante")
	_check(screen.default_focus_control() == screen.scenario_action(&"spawn_test"), "Erster sinnvoller Praxisfokus liegt auf dem ersten Test")
	var spawn_instance := screen.scenario_action(&"spawn_test").get_instance_id()

	var same_content := PracticeViewModelScript.create(2, true, &"spawn_test", &"", scenarios, profiles)
	_check(same_content.content_hash() == first.content_hash(), "Revision gehört nicht zum Inhalts-Hash")
	_check(not screen.apply_view_model(same_content), "Neue Revision mit identischem Inhalt erzeugt keinen UI-Neuaufbau")
	_check(screen.applied_revision() == 2, "Inhaltsgleiche neue Revision wird dennoch quittiert")
	_check(screen.scenario_action(&"spawn_test").get_instance_id() == spawn_instance, "Idempotentes Apply bewahrt bestehende Controls")
	_check(not screen.apply_view_model(first), "Veraltete Revision wird verworfen")

	var boss_selected := PracticeViewModelScript.create(3, true, &"boss_test", &"", scenarios, profiles)
	_check(screen.apply_view_model(boss_selected), "Boss-Test-Auswahl wird angewendet")
	_check(screen.boss_profile_selection_visible(), "Boss-Test blendet die zusätzliche Profilauswahl ein")
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

	var intents := {
		"scenario": StringName(),
		"profile": StringName(),
		"back": 0,
	}
	screen.scenario_selected.connect(func(id: StringName) -> void: intents["scenario"] = id)
	screen.boss_profile_selected.connect(func(id: StringName) -> void: intents["profile"] = id)
	screen.back_requested.connect(func() -> void: intents["back"] = int(intents["back"]) + 1)
	screen.scenario_action(&"obstacle_test").pressed.emit()
	screen.boss_profile_action(&"bacterial_core").pressed.emit()
	screen.back_action().pressed.emit()
	_check(intents["scenario"] == &"obstacle_test", "Testauswahl emittiert ausschließlich ihre stabile ID")
	_check(intents["profile"] == &"bacterial_core", "Bossauswahl emittiert ausschließlich ihre stabile Profil-ID")
	_check(int(intents["back"]) == 1, "Rückkehr emittiert genau eine Absicht")

	var hidden := PracticeViewModelScript.create(5, false, &"boss_test", &"intro_boss", scenarios, profiles)
	_check(hidden.selected_scenario_id() == &"", "Ausgeblendetes Modell trägt keine versteckte Testauswahl")
	_check(hidden.selected_boss_profile_id() == &"", "Ausgeblendetes Modell trägt keine versteckte Bossauswahl")
	_check(screen.apply_view_model(hidden), "Integrator kann lokale Tests ausblenden")
	_check(not screen.tests_visible(), "Release-Sichtbarkeit wird ausschließlich über das ViewModel angewendet")
	_check(not screen.boss_profile_selection_visible(), "Ausgeblendete Tests zeigen keine Bossprofile")
	_check(screen.default_focus_control() == screen.back_action(), "Ohne sichtbare Tests bleibt die Navigation der Standardfokus")

	screen.size = Vector2(800.0, 720.0)
	await process_frame
	_check(screen.layout_columns() == 2, "Mittlere Praxis zeigt zwei Testspalten")
	screen.size = Vector2(580.0, 720.0)
	await process_frame
	_check(screen.layout_columns() == 1, "Kompakte Praxis stapelt Testkarten")
	_check(screen.boss_layout_columns() == 1, "Kompakte Praxis stapelt Bossprofile")
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
