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
	_check(screen.layout_columns() == 2, "Breite Praxis zeigt zwei inhaltshohe Spalten")

	var shell := screen.get_node_or_null("PracticePageShell") as PanelContainer
	_check(shell != null and shell.theme_type_variation == AlveolusVisualTheme.TYPE_PAGE_CANVAS, "Praxis verwendet den zentralen PageShell")
	_check_page_header_contract(shell, "Praxis")
	var offline_card := screen.find_child("OfflineResearchCard", true, false) as PanelContainer
	var clinic_card := screen.find_child("ClinicCard", true, false) as PanelContainer
	_check(offline_card != null and offline_card.theme_type_variation == AlveolusVisualTheme.TYPE_ACTION_CARD, "Offline-Forschung verwendet die zentrale ActionCard")
	_check(clinic_card != null and clinic_card.theme_type_variation == AlveolusVisualTheme.TYPE_ACTION_CARD, "Klinikfall verwendet die zentrale ActionCard")
	_check(screen.back_action().theme_type_variation == AlveolusVisualTheme.TYPE_NAVIGATION_BUTTON, "Rückkehr verwendet die zentrale Navigation")
	_check(screen.offline_claim_action().theme_type_variation == AlveolusVisualTheme.TYPE_PRIMARY_BUTTON, "Offline-Abholung verwendet die globale Primäraktion")
	_check(screen.clinic_claim_action().theme_type_variation == AlveolusVisualTheme.TYPE_PRIMARY_BUTTON, "Klinikbelohnung verwendet die globale Primäraktion")
	_check(screen.clinic_progress_control() is ProgressBar, "Klinikstatus verwendet den zentralen Fortschrittsbaustein")

	var offline := PracticeViewModelScript.OfflineResearchViewModel.create(
		"2 Std. 15 Min.",
		"8 Stunden",
		"4 Forschung abholen",
		4,
		true
	)
	var offers: Array = [
		PracticeViewModelScript.ClinicJobOfferViewModel.create(&"short_review", "Kurzbefund", "10 Min.", "+6 Forschung"),
		PracticeViewModelScript.ClinicJobOfferViewModel.create(&"follow_up", "Nachkontrolle", "30 Min.", "+14 Forschung"),
	]
	var idle := PracticeViewModelScript.ClinicStatusViewModel.idle()
	var first := PracticeViewModelScript.create(1, "Forschung 12", offline, idle, offers)

	_check(first.revision() == 1, "ViewModel bewahrt seine Revision")
	_check(first.content_hash() != 0, "ViewModel liefert einen Inhalts-Hash")
	_check(first.job_offer_count() == 2, "ViewModel bewahrt alle Klinikangebote")
	var returned_offers: Array = first.job_offers()
	returned_offers.clear()
	_check(first.job_offer_count() == 2, "Ausgelesene Angebotsliste kann das ViewModel nicht verändern")
	_check(first.job_offer_at(0) != offers[0], "Ausgelesene Kindeinträge sind tiefe Kopien")

	_check(screen.apply_view_model(first), "Erstes Praxis-ViewModel wird angewendet")
	_check(screen.applied_revision() == 1 and screen.applied_content_hash() == first.content_hash(), "Screen quittiert Revision und Inhalts-Hash")
	_check(screen.clinic_offers_visible(), "Ohne aktiven Fall bleiben Angebote sichtbar")
	_check(screen.clinic_job_action(&"short_review") != null, "Angebot wird über stabile ID adressierbar")
	_check(screen.default_focus_control() == screen.offline_claim_action(), "Erster sinnvoller Praxisfokus liegt auf einer verfügbaren Hauptaktion")
	var first_offer_instance := screen.clinic_job_action(&"short_review").get_instance_id()

	var second := PracticeViewModelScript.create(2, "Forschung 12", offline, idle, offers)
	_check(second.content_hash() == first.content_hash(), "Revision gehört nicht zum Inhalts-Hash")
	_check(not screen.apply_view_model(second), "Neue Revision mit identischem Inhalt erzeugt keinen UI-Neuaufbau")
	_check(screen.applied_revision() == 2, "Inhaltsgleiche neue Revision wird dennoch quittiert")
	_check(screen.clinic_job_action(&"short_review").get_instance_id() == first_offer_instance, "Idempotentes Apply bewahrt bestehende Controls")
	_check(not screen.apply_view_model(first), "Veraltete Revision wird verworfen")

	var running := PracticeViewModelScript.ClinicStatusViewModel.create(
		true,
		&"short_review",
		"Kurzbefund läuft",
		false,
		300.0,
		600.0,
		"5 Min. verbleibend",
		"+6 Forschung",
		"Voraussichtlich fertig um 14:30"
	)
	var third := PracticeViewModelScript.create(3, "Forschung 12", offline, running, offers)
	_check(screen.apply_view_model(third), "Laufender Klinikfall aktualisiert sichtbare Werte")
	_check(not screen.clinic_offers_visible(), "Laufender Klinikfall ersetzt Angebote ohne Leerraumreserve")
	_check(screen.clinic_progress_control().visible, "Laufender Klinikfall zeigt Fortschritt")
	_check(screen.clinic_job_action(&"short_review").get_instance_id() == first_offer_instance, "Reine Fortschrittsupdates bauen versteckte Angebote nicht neu")

	var completed := PracticeViewModelScript.ClinicStatusViewModel.create(
		true,
		&"short_review",
		"Kurzbefund abgeschlossen · Belohnung bereit",
		true,
		600.0,
		600.0,
		"",
		"+6 Forschung",
		"Abgeschlossen um 14:30"
	)
	var fourth := PracticeViewModelScript.create(4, "Forschung 12", offline, completed, offers)
	_check(screen.apply_view_model(fourth), "Abgeschlossener Klinikfall wird angewendet")
	_check(screen.clinic_claim_action().visible, "Abgeschlossener Klinikfall zeigt genau seine Abholaktion")
	_check(not screen.clinic_progress_control().visible, "Abgeschlossener Klinikfall reserviert keinen Fortschrittsleerraum")

	var intents := {
		"offline": 0,
		"start": StringName(),
		"claim": 0,
		"back": 0,
	}
	screen.offline_claim_requested.connect(func() -> void: intents["offline"] = int(intents["offline"]) + 1)
	screen.clinic_job_start_requested.connect(func(id: StringName) -> void: intents["start"] = id)
	screen.clinic_job_claim_requested.connect(func() -> void: intents["claim"] = int(intents["claim"]) + 1)
	screen.back_requested.connect(func() -> void: intents["back"] = int(intents["back"]) + 1)
	screen.offline_claim_action().pressed.emit()
	screen.clinic_job_action(&"short_review").pressed.emit()
	screen.clinic_claim_action().pressed.emit()
	screen.back_action().pressed.emit()
	_check(int(intents["offline"]) == 1, "Offline-Abholung emittiert genau eine Absicht")
	_check(intents["start"] == &"short_review", "Klinikangebot emittiert ausschließlich seine stabile ID")
	_check(int(intents["claim"]) == 1, "Klinikabholung emittiert genau eine Absicht")
	_check(int(intents["back"]) == 1, "Rückkehr emittiert genau eine Absicht")

	screen.size = Vector2(800.0, 720.0)
	await process_frame
	_check(screen.layout_columns() == 1, "Kompakte Praxis stapelt beide Karten in einer Spalte")
	_check(screen.back_action().focus_mode == Control.FOCUS_ALL, "Navigation bleibt per Tastatur und Gamepad fokussierbar")
	_check(screen.offline_claim_action().focus_mode == Control.FOCUS_ALL, "Hauptaktion bleibt per Tastatur und Gamepad fokussierbar")

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


func _check_source_contracts() -> void:
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/screens/practice_screen.gd")
	var model_source := FileAccess.get_file_as_string("res://scripts/ui/view_models/practice_screen_view_model.gd")
	for forbidden in ["MetaProgressionState", "ContentCatalog", "SaveRepository", "PlayerStats", "RunState"]:
		_check(not screen_source.contains(forbidden), "Praxis-Screen greift nicht auf %s zu" % forbidden)
		_check(not model_source.contains(forbidden), "Praxis-ViewModel greift nicht auf %s zu" % forbidden)
	_check(not screen_source.contains("StyleBox"), "Praxis erzeugt keine lokale StyleBox-Kopie")
	_check(not screen_source.contains("Shader"), "Praxis erzeugt keinen lokalen Shader")
	_check(not screen_source.contains("func _process("), "Praxis definiert keine Prozessschleife")
	_check(not screen_source.contains("func _physics_process("), "Praxis definiert keine Physikschleife")
	_check(model_source.contains("Array[ClinicJobOfferViewModel]"), "ViewModel hält Kindeinträge typisiert")


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
