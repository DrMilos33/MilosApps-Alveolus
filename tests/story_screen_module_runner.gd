extends SceneTree

const STORY_SCREEN_PATH := "res://scripts/ui/screens/story_screen.gd"
const STORY_VIEW_MODEL_PATH := "res://scripts/ui/view_models/story_screen_view_model.gd"
const StoryScreenScript := preload(STORY_SCREEN_PATH)
const StoryScreenViewModelScript := preload(STORY_VIEW_MODEL_PATH)

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_boundaries()
	var view_model := _test_immutable_view_model()
	await _test_screen_contract(view_model)
	_finish()


func _test_source_boundaries() -> void:
	var combined_source := _read_source(STORY_SCREEN_PATH) + "\n" + _read_source(STORY_VIEW_MODEL_PATH)
	for forbidden in [
		"MetaProgressionState",
		"PlayerStats",
		"RunState",
		"RunSession",
		"ContentCatalog",
		"ConfigFile",
		"FileAccess",
		"save_game",
	]:
		_check(not combined_source.contains(forbidden), "Story-Modul besitzt keine verbotene Abhängigkeit %s" % forbidden)
	_check(combined_source.contains("AlveolusUIComponents.page_shell"), "Story verwendet die zentrale PageCanvas-Konstruktion")
	_check(combined_source.contains("AlveolusUIComponents.modal_sheet"), "Story verwendet die zentrale ModalSheet-Konstruktion")
	_check(combined_source.contains("AlveolusUIComponents.action_button"), "Story verwendet ausschließlich zentrale Action-Komponenten")
	_check(not combined_source.contains("add_theme_stylebox_override"), "Story erzeugt keine lokale StyleBox-Insel")
	_check(not combined_source.contains("func _process") and not combined_source.contains("func _physics_process"), "Story besitzt keine dauerhafte Prozessschleife")


func _test_immutable_view_model() -> StoryScreenViewModel:
	var source_rows: Array = [
		{
			"id": &"welcome",
			"title": "Willkommen bei ALVEOLUS",
			"body": "Du leitest einen Forschungscampus für schwierige Lungenfälle.",
			"next_label": "Weiter",
			"ignored_nested_state": {"mutable": true},
		},
		{
			"id": &"lung_model",
			"title": "Das Lungenmodell",
			"body": "Jeder Fall wird als begehbares Lungenmodell dargestellt.",
			"next_label": "Weiter",
		},
		{
			"id": &"mission",
			"title": "Deine Aufgabe",
			"body": "Stoppe Bakterien, stärke die Abwehr und halte den Zustand stabil.",
			"next_label": "Zum Campus",
		},
	]
	var view_model: StoryScreenViewModel = StoryScreenViewModelScript.create(source_rows, 7, &"prologue", true, true)
	_check(view_model != null and view_model.step_count() == 3, "View-Model übernimmt drei gültige Schritte")
	_check(view_model.revision() == 7 and view_model.story_id() == &"prologue", "View-Model stellt Revision und Story-ID nur lesend bereit")
	_check(view_model.content_hash().length() == 64, "View-Model besitzt einen stabilen SHA-256-Inhaltshash")
	_check(view_model.step_at(0).title() == "Willkommen bei ALVEOLUS", "Kind-View-Model stellt primitive Schrittdaten bereit")
	_check(view_model.step_at(-1) == null and view_model.step_at(3) == null, "View-Model weist ungültige Schrittindizes sicher ab")

	# Mutating either the source rows or the returned array cannot reach the VM.
	source_rows[0]["title"] = "Fremde Mutation"
	(source_rows[0]["ignored_nested_state"] as Dictionary)["mutable"] = false
	var returned_steps := view_model.steps()
	returned_steps.clear()
	_check(view_model.step_count() == 3, "Zurückgegebene Schrittarrays sind defensive Kopien")
	_check(view_model.step_at(0).title() == "Willkommen bei ALVEOLUS", "Spätere Quellmutationen verändern das View-Model nicht")

	var equivalent: StoryScreenViewModel = StoryScreenViewModelScript.create([
		{"id": &"welcome", "title": "Willkommen bei ALVEOLUS", "body": "Du leitest einen Forschungscampus für schwierige Lungenfälle.", "next_label": "Weiter"},
		{"id": &"lung_model", "title": "Das Lungenmodell", "body": "Jeder Fall wird als begehbares Lungenmodell dargestellt.", "next_label": "Weiter"},
		{"id": &"mission", "title": "Deine Aufgabe", "body": "Stoppe Bakterien, stärke die Abwehr und halte den Zustand stabil.", "next_label": "Zum Campus"},
	], 8, &"prologue", true, true)
	_check(equivalent.content_hash() == view_model.content_hash(), "Revision ist nicht Teil des semantischen Inhaltshashs")
	return view_model


func _test_screen_contract(view_model: StoryScreenViewModel) -> void:
	get_root().size = Vector2i(1280, 720)
	var screen := StoryScreenScript.new() as StoryScreen
	screen.theme = AlveolusVisualTheme.create_theme()
	get_root().add_child(screen)
	_check(screen.apply_view_model(view_model, 0), "Erstes Apply zeichnet den Prolog")
	await _settle()

	_check(screen.page_canvas().theme_type_variation == AlveolusVisualTheme.TYPE_PAGE_CANVAS, "Screen besitzt die zentrale PageCanvas-Rolle")
	_check(screen.story_sheet().theme_type_variation == AlveolusVisualTheme.TYPE_MODAL_SHEET, "Prologkarte besitzt die zentrale ModalSheet-Rolle")
	_check(screen.story_sheet().get_meta(&"alveolus_component", &"") == &"modal_sheet", "Prologkarte stammt aus der gemeinsamen ModalSheet-Komponente")
	_check(screen.focus_scroll().follow_focus, "Responsive Prologfläche folgt Tastatur- und Gamepadfokus")
	_check(screen.focus_scroll().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Prolog scrollt niemals horizontal")
	_check(screen.title_label().theme_type_variation == AlveolusVisualTheme.TYPE_TITLE_LABEL, "Titel verwendet zentrale Typografie")
	_check(screen.body_label().theme_type_variation == AlveolusVisualTheme.TYPE_BODY_LABEL, "Fließtext verwendet zentrale Typografie")
	_check(screen.next_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_PRIMARY, "Weiter ist die einzige Primäraktion")
	_check(screen.skip_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_QUIET, "Überspringen bleibt eine ruhige Nebenaktion")
	_check(not screen.back_action().visible, "Der erste Schritt zeigt keine unpassende Zurückaktion")
	_check(screen.title_label().text == "Willkommen bei ALVEOLUS" and screen.progress_label().text == "Schritt 1 von 3", "Erster Schritt ist vollständig gebunden")
	_check(not screen.apply_view_model(view_model, 0), "Identisches Apply ist idempotent")

	_check(screen.grab_initial_focus(), "Screen kann seinen sichtbaren Anfangsfokus setzen")
	await process_frame
	_check(get_root().gui_get_focus_owner() == screen.next_action(), "Anfangsfokus liegt auf Weiter und niemals auf Überspringen")
	_check(_inside(screen.next_action(), screen.focus_scroll()), "Anfangsfokus bleibt im sichtbaren Scrollviewport")
	_check(screen.next_action().scale.is_equal_approx(Vector2.ONE), "Fokus verändert die Buttongeometrie nicht")

	var next_intents: Array[int] = []
	var back_intents: Array[int] = []
	var skip_intents: Array[bool] = []
	screen.next_requested.connect(func(index: int) -> void: next_intents.append(index))
	screen.back_requested.connect(func(index: int) -> void: back_intents.append(index))
	screen.skip_requested.connect(func() -> void: skip_intents.append(true))
	screen.next_action().pressed.emit()
	_check(next_intents == [0], "Weiter emittiert nur den aktuellen Schrittintent")
	_check(screen.set_step_index(1), "Fassade kann den nächsten Schritt ausdrücklich anwenden")
	await _settle()
	_check(screen.back_action().visible, "Ab dem zweiten Schritt ist Zurück sinnvoll verfügbar")
	screen.back_action().pressed.emit()
	screen.skip_action().pressed.emit()
	_check(back_intents == [1] and skip_intents.size() == 1, "Zurück und Überspringen emittieren getrennte Intents")
	_check(screen.set_step_index(2) and screen.next_action().text == "Zum Campus", "Letzter Schritt bindet seine Abschlussbeschriftung")

	# A stale presenter revision must never overwrite the active screen.
	var stale: StoryScreenViewModel = StoryScreenViewModelScript.create([
		{"id": &"stale", "title": "Veraltet", "body": "Dieser Inhalt darf nicht erscheinen.", "next_label": "Weiter"},
	], 6)
	_check(not screen.apply_view_model(stale, 0), "Veraltete Revision wird verworfen")
	_check(screen.title_label().text == "Deine Aufgabe", "Veraltetes Apply verändert die sichtbare Story nicht")

	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(960, 540), Vector2i(480, 270)]:
		get_root().size = viewport_size
		await _settle()
		_check(screen.story_sheet().size.x <= screen.focus_scroll().size.x + 0.5, "%s hält die Storykarte innerhalb der sicheren Breite" % viewport_size)
		_check(screen.story_sheet().size.y <= screen.story_sheet().get_combined_minimum_size().y + 1.0, "%s reserviert im Modal keinen dekorativen Leerraum" % viewport_size)
		_check(screen.next_action().is_visible_in_tree(), "%s hält die Hauptaktion erreichbar" % viewport_size)

	screen.queue_free()
	await process_frame


func _read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "%s ist lesbar" % path)
	return file.get_as_text() if file != null else ""


func _inside(control: Control, container: Control) -> bool:
	if control == null or container == null:
		return false
	var inner := control.get_global_rect()
	var outer := container.get_global_rect()
	return (
		inner.position.x >= outer.position.x - 0.5
		and inner.position.y >= outer.position.y - 0.5
		and inner.end.x <= outer.end.x + 0.5
		and inner.end.y <= outer.end.y + 0.5
	)


func _settle() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_STORY_SCREEN_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
