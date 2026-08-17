extends SceneTree

const PAUSE_OVERLAY_PATH := "res://scripts/ui/screens/pause_overlay.gd"
const PAUSE_VIEW_MODEL_PATH := "res://scripts/ui/view_models/pause_overlay_view_model.gd"
const PauseOverlayScript := preload(PAUSE_OVERLAY_PATH)
const PauseOverlayViewModelScript := preload(PAUSE_VIEW_MODEL_PATH)

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_boundaries()
	var view_model := _test_immutable_view_model()
	await _test_pause_and_stats_modes(view_model)
	_finish()


func _test_source_boundaries() -> void:
	var source := _read_source(PAUSE_OVERLAY_PATH) + "\n" + _read_source(PAUSE_VIEW_MODEL_PATH)
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
		_check(not source.contains(forbidden), "Pause-Modul besitzt keine verbotene Abhängigkeit %s" % forbidden)
	_check(source.contains("AlveolusUIComponents.modal_sheet"), "Pause verwendet die zentrale ModalSheet-Konstruktion")
	_check(source.contains("AlveolusUIComponents.action_button"), "Pause verwendet zentrale Action-Komponenten")
	_check(source.contains("AlveolusUIComponents.value_row"), "Charakterwerte verwenden zentrale ValueRows")
	_check(source.contains("SimpleIcon.new"), "Charakterwerte besitzen semantische HUD-Icons")
	_check(not source.contains("add_theme_stylebox_override"), "Pause erzeugt keine lokale StyleBox-Kopie")
	_check(not source.contains("Shader.new") and not source.contains("ShaderMaterial.new"), "Pause erzeugt keine lokalen Shaderressourcen")
	_check(not source.contains("func _process") and not source.contains("func _physics_process"), "Pause besitzt keine dauerhafte Prozessschleife")
	_check(not source.to_lower().contains("runmenü"), "Pause enthält keine überflüssige Runmenü-Überschrift")


func _test_immutable_view_model() -> PauseOverlayViewModel:
	var source_rows := _dense_stat_rows()
	var view_model: PauseOverlayViewModel = PauseOverlayViewModelScript.create(source_rows, 12)
	_check(view_model.revision() == 12 and view_model.stat_count() == 14, "View-Model übernimmt Revision und alle vierzehn Werte")
	_check(view_model.content_hash().length() == 64, "View-Model besitzt einen stabilen SHA-256-Inhaltshash")
	_check(view_model.stat_at(0).label() == "Zustand" and view_model.stat_at(0).icon_id() == &"information", "Kind-View-Model enthält nur darstellungsfertige Werte")
	_check(view_model.stat_at(-1) == null and view_model.stat_at(14) == null, "Ungültige Statindizes werden sicher abgewiesen")

	source_rows[0]["label"] = "Fremde Mutation"
	(source_rows[0]["nested"] as Dictionary)["mutable"] = false
	var returned_rows := view_model.stats()
	returned_rows.clear()
	_check(view_model.stat_count() == 14, "Zurückgegebene Statarrays sind defensive Kopien")
	_check(view_model.stat_at(0).label() == "Zustand", "Spätere Quellmutationen erreichen das View-Model nicht")

	var equivalent_rows := _dense_stat_rows()
	var equivalent: PauseOverlayViewModel = PauseOverlayViewModelScript.create(equivalent_rows, 13)
	_check(equivalent.content_hash() == view_model.content_hash(), "Revision ist nicht Teil des semantischen Stat-Hashs")
	return view_model


func _test_pause_and_stats_modes(view_model: PauseOverlayViewModel) -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var overlay := PauseOverlayScript.new() as PauseOverlay
	overlay.theme = AlveolusVisualTheme.create_theme()
	host.add_child(overlay)
	_check(overlay.apply_view_model(view_model, PauseOverlay.Mode.MENU), "Erstes Apply zeichnet das Pausenmenü")
	await _settle()

	_check(overlay.modal_sheet().theme_type_variation == AlveolusVisualTheme.TYPE_MODAL_SHEET, "Pause besitzt die zentrale ModalSheet-Rolle")
	_check(overlay.modal_sheet().get_meta(&"alveolus_component", &"") == &"modal_sheet", "Pause stammt aus der gemeinsamen ModalSheet-Komponente")
	_check(overlay.title_text() == "Behandlung pausiert", "Pausenmenü zeigt nur seinen eigentlichen Titel")
	_check(overlay.body_scroll().follow_focus, "Der responsive Inhaltsviewport folgt dem Fokus")
	_check(overlay.body_scroll().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Pause scrollt niemals horizontal")
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Normales Pausenmenü benötigt keinen Scrollmodus")
	_check(not overlay.body_scroll().get_v_scroll_bar().visible, "Normales Pausenmenü zeigt keinen Scrollbalken")
	_check(overlay.menu_action_grid().columns == 3, "Breites Pausenmenü ordnet Nebenaktionen kompakt in einer Zeile an")
	_check(overlay.resume_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_PRIMARY, "Weiter ist die einzige Primäraktion")
	_check(overlay.settings_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_SECONDARY, "Einstellungen ist eine Sekundäraktion")
	_check(overlay.stats_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_SECONDARY, "Charakterwerte ist eine Sekundäraktion")
	_check(overlay.abort_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_DANGER, "Runde abbrechen besitzt ausschließlich die Gefahrrolle")
	_check(_primary_action_count(overlay) == 1, "Das gesamte Overlay enthält genau eine Primäraktion")
	_check(overlay.modal_sheet().size.y <= overlay.modal_sheet().get_combined_minimum_size().y + 1.0, "Pausenmodal reserviert keinen dekorativen Leerraum")
	_check(not overlay.apply_view_model(view_model, PauseOverlay.Mode.MENU), "Identisches Apply ist idempotent")

	_check(overlay.grab_initial_focus(), "Pause kann ihren Anfangsfokus setzen")
	await process_frame
	_check(get_root().gui_get_focus_owner() == overlay.resume_action(), "Anfangsfokus liegt auf Weiter")
	_check(overlay.resume_action().scale.is_equal_approx(Vector2.ONE), "Fokus skaliert die Hauptaktion nicht")
	_check(_focus_target_inside(overlay.resume_action(), overlay.resume_action().focus_neighbor_left, overlay), "Menüfokus bleibt beim Rückwärtsnavigieren im Overlay")
	_check(_focus_target_inside(overlay.resume_action(), overlay.resume_action().focus_neighbor_right, overlay), "Menüfokus bleibt beim Vorwärtsnavigieren im Overlay")

	var resume_intents: Array[bool] = []
	var settings_intents: Array[bool] = []
	var stats_intents: Array[bool] = []
	var abort_intents: Array[bool] = []
	var back_intents: Array[bool] = []
	overlay.resume_requested.connect(func() -> void: resume_intents.append(true))
	overlay.settings_requested.connect(func() -> void: settings_intents.append(true))
	overlay.stats_requested.connect(func() -> void: stats_intents.append(true))
	overlay.abort_requested.connect(func() -> void: abort_intents.append(true))
	overlay.back_requested.connect(func() -> void: back_intents.append(true))
	overlay.resume_action().pressed.emit()
	overlay.settings_action().pressed.emit()
	overlay.stats_action().pressed.emit()
	overlay.abort_action().pressed.emit()
	_check(resume_intents.size() == 1, "Weiter emittiert genau einen Resume-Intent")
	_check(settings_intents.size() == 1 and stats_intents.size() == 1, "Sekundäraktionen emittieren getrennte Intents")
	_check(abort_intents.size() == 1, "Gefahraktion emittiert ausschließlich Abort")
	_check(overlay.current_mode() == PauseOverlay.Mode.MENU, "Ein Intent verändert den präsentierten Modus nicht eigenmächtig")

	_check(overlay.set_mode(PauseOverlay.Mode.STATS, false), "Fassade kann die eingebetteten Charakterwerte öffnen")
	await _settle()
	_check(overlay.title_text() == "Charakterwerte", "Statmodus besitzt einen einfachen Titel")
	_check(not overlay.resume_action().visible and overlay.back_action().visible, "Statmodus ersetzt Weiter durch einen festen Rückweg")
	_check(overlay.stats_grid().columns == 2, "Breite Charakterwerte verwenden genau zwei Spalten")
	_check(overlay.stat_rows().size() == view_model.stat_count(), "Jeder View-Model-Wert besitzt genau eine sichtbare Zeile")
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Vierzehn Werte passen bei 1280 × 720 ohne Scrollen")
	_check(not overlay.body_scroll().get_v_scroll_bar().visible, "Breite Charakterwerte zeigen keinen unnötigen Scrollbalken")
	_assert_stat_rows(overlay)
	_assert_stat_grid_uses_available_width(overlay)
	_check(overlay.grab_initial_focus(), "Statmodus kann seinen festen Rückfokus setzen")
	await process_frame
	_check(get_root().gui_get_focus_owner() == overlay.back_action(), "Charakterwerte fokussieren standardmäßig Zurück")
	_check(overlay.back_action().focus_neighbor_left == NodePath(".") and overlay.back_action().focus_neighbor_right == NodePath("."), "Statmodus fängt Fokus am einzigen interaktiven Rückweg")
	overlay.back_action().pressed.emit()
	_check(back_intents.size() == 1, "Zurück emittiert genau einen Back-Intent")
	_check(overlay.handle_ui_cancel(), "ui_cancel wird im sichtbaren Overlay konsumiert")
	_check(back_intents.size() == 2, "ui_cancel emittiert denselben Back-Intent ohne Nebenaktion")

	# 480 × 270 models the logical area of the 960 × 540 / 200-percent case.
	_resize_logical_host(host, Vector2i(480, 270))
	await _settle()
	_check(overlay.stats_grid().columns == 2, "Bei 200 Prozent nutzen Charakterwerte weiterhin zwei lesbare Spalten")
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Nur der überlange Statinhalt aktiviert responsives Scrollen")
	_check(overlay.body_scroll().get_v_scroll_bar().visible, "Der notwendige Scrollbereich ist sichtbar erkennbar")
	_assert_stat_grid_uses_available_width(overlay)
	_check(overlay.back_action().is_visible_in_tree(), "Zurück bleibt außerhalb des Stat-Scrollbereichs sichtbar")
	_check(_inside(overlay.back_action(), overlay.modal_sheet()), "Zurück bleibt vollständig innerhalb des Modals")
	_check(overlay.grab_initial_focus(), "Kompakter Statmodus fokussiert weiterhin Zurück")
	await process_frame
	_check(get_root().gui_get_focus_owner() == overlay.back_action(), "Kompakter Statmodus verliert seinen Fokus nicht")

	_check(overlay.set_mode(PauseOverlay.Mode.MENU, false), "Fassade kann zum Pausenmenü zurückkehren")
	await _settle()
	_check(overlay.menu_action_grid().columns == 2, "Kompaktes Pausenmenü ordnet Routineaktionen in zwei Spalten an")
	_check(overlay.abort_action().get_parent() != overlay.menu_action_grid(), "Kompaktes Pausenmenü trennt die Gefahraktion von den Routineaktionen")
	_check(overlay.abort_action().size.x >= overlay.menu_action_grid().size.x - 2.0, "Kompakte Gefahraktion nutzt eine eigene volle Zeile")
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Alle kompakten Menüaktionen bleiben ohne Body-Scroll sichtbar")
	_check(not overlay.body_scroll().get_v_scroll_bar().visible, "Kompaktes Pausenmenü zeigt keinen Scrollbalken")
	_check(overlay.settings_action().is_visible_in_tree() and overlay.stats_action().is_visible_in_tree(), "Beide Routineaktionen sind kompakt gleichzeitig sichtbar")
	_check(overlay.abort_action().is_visible_in_tree(), "Runde abbrechen ist kompakt gleichzeitig sichtbar")
	_check(_inside(overlay.settings_action(), overlay.modal_sheet()), "Einstellungen bleibt vollständig innerhalb des kompakten Modals")
	_check(_inside(overlay.stats_action(), overlay.modal_sheet()), "Charakterwerte bleibt vollständig innerhalb des kompakten Modals")
	_check(_inside(overlay.abort_action(), overlay.modal_sheet()), "Runde abbrechen bleibt vollständig innerhalb des kompakten Modals")
	_check(_focus_target_inside(overlay.stats_action(), overlay.stats_action().focus_neighbor_right, overlay), "Kompaktes Reparenting erhält den Fokuspfad zur Gefahraktion")
	_check(overlay.resume_action().is_visible_in_tree(), "Weiter bleibt als feste Hauptaktion sichtbar")
	_check(_inside(overlay.resume_action(), overlay.modal_sheet()), "Weiter bleibt vollständig innerhalb des Modals")

	var intro_enabled: PauseOverlayViewModel = PauseOverlayViewModelScript.create(_dense_stat_rows(), 14, true)
	_check(overlay.apply_view_model(intro_enabled, PauseOverlay.Mode.MENU), "Optionaler Intro-Skip-Snapshot wird angewendet")
	await _settle()
	_check(overlay.intro_skip_action().is_visible_in_tree(), "Optionaler Intro-Skip bleibt im kompakten Menü verfügbar")
	_check(overlay.abort_action().get_parent() != overlay.menu_action_grid(), "Intro-Skip verändert die separate Gefahrzeile nicht")

	var empty: PauseOverlayViewModel = PauseOverlayViewModelScript.create([], 15)
	_check(overlay.apply_view_model(empty, PauseOverlay.Mode.MENU), "Leerer aktueller Snapshot wird angewendet")
	_check(overlay.stats_action().disabled, "Charakterwerte sind ohne Werte eindeutig deaktiviert")
	overlay.hide()
	_check(not overlay.handle_ui_cancel(), "Verdecktes Overlay konsumiert ui_cancel nicht")
	host.queue_free()
	await process_frame


func _assert_stat_rows(overlay: PauseOverlay) -> void:
	var right_edges: Dictionary = {}
	var has_measured_wide_value := false
	var rows := overlay.stat_rows()
	for index in range(rows.size()):
		var row := rows[index]
		_check(row.theme_type_variation == AlveolusVisualTheme.TYPE_VALUE_ROW, "Statzeile %d verwendet die zentrale ValueRow-Rolle" % index)
		_check(row.get_meta(&"alveolus_component", &"") == &"value_row", "Statzeile %d stammt aus der zentralen ValueRow-Komponente" % index)
		var icon := row.find_child("StatIcon", true, false) as SimpleIcon
		var label := row.find_child("StatLabel", true, false) as Label
		var value := row.find_child("StatValue", true, false) as Label
		_check(icon != null and label != null and value != null, "Statzeile %d besitzt Icon, Bezeichnung und Wert" % index)
		_check(row.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Statzeile %d füllt ihre Gridspalte" % index)
		if icon == null or label == null or value == null:
			continue
		_check(value.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Statwert %d ist rechtsbündig" % index)
		_check(value.custom_minimum_size.x >= 56.0 and value.custom_minimum_size.x <= 120.0, "Statwert %d bleibt in der 56–120-px-Spalte" % index)
		if value.custom_minimum_size.x > 56.0:
			has_measured_wide_value = true
		_check(label.size.x > 0.0, "Statbezeichnung %d behält sichtbaren Platz" % index)
		_check(not row.tooltip_text.is_empty(), "Statzeile %d behält den vollständigen Tooltip" % index)
		_check(icon.get_index() < label.get_index() and label.get_index() < value.get_index(), "Statzeile %d besitzt eine eindeutige Leserichtung" % index)
		var column := index % 2
		var right_edge := value.get_global_rect().end.x
		if right_edges.has(column):
			_check(is_equal_approx(float(right_edges[column]), right_edge), "Werte in Spalte %d enden an derselben Kante" % (column + 1))
		else:
			right_edges[column] = right_edge
	_check(has_measured_wide_value, "Längere Statwerte erhalten textgemessen mehr als die Mindestbreite")


func _assert_stat_grid_uses_available_width(overlay: PauseOverlay) -> void:
	var grid := overlay.stats_grid()
	var rows := overlay.stat_rows()
	if grid == null or rows.size() < grid.columns:
		_check(false, "Statgrid besitzt genügend Zeilen für die Breitenprüfung")
		return
	var first_row := rows[0]
	var last_column_row := rows[grid.columns - 1]
	_check(
		first_row.size.x >= (grid.size.x - float(AlveolusVisualTheme.CONTENT_GAP)) / float(grid.columns) - 2.0,
		"Statzeilen nutzen die verfügbare Spaltenbreite"
	)
	_check(
		last_column_row.get_global_rect().end.x >= grid.get_global_rect().end.x - 2.0,
		"Letzte Statspalte reicht bis an die rechte Gridkante"
	)


func _dense_stat_rows() -> Array:
	return [
		{"id": &"stability", "group": "ALLGEMEIN", "label": "Zustand", "value": "80 / 90", "nested": {"mutable": true}},
		{"id": &"movement", "group": "ALLGEMEIN", "label": "Bewegung", "value": "275"},
		{"id": &"therapy_power", "group": "BEHANDLUNG", "label": "Wirkung", "value": "18"},
		{"id": &"therapy_interval", "group": "BEHANDLUNG", "label": "Intervall", "value": "0,82 s → 0,69 s"},
		{"id": &"therapy_targets", "group": "BEHANDLUNG", "label": "Ziele", "value": "3"},
		{"id": &"ability_power", "group": "AKTIV", "label": "Fähigkeitswirkung", "value": "+20 %"},
		{"id": &"ability_cooldown", "group": "AKTIV", "label": "Abklingzeit", "value": "−10 %"},
		{"id": &"immune_cells", "group": "ABWEHR", "label": "Abwehrzellen", "value": "2"},
		{"id": &"immune_power", "group": "ABWEHR", "label": "Abwehrwirkung", "value": "12"},
		{"id": &"support_level", "group": "ATEMHILFE", "label": "Atemhilfe", "value": "2"},
		{"id": &"support_regen", "group": "ATEMHILFE", "label": "Regeneration", "value": "4"},
		{"id": &"sample_radius", "group": "PROBEN", "label": "Aufnahmeradius", "value": "96"},
		{"id": &"sample_count", "group": "PROBEN", "label": "Proben", "value": "4 / 5"},
		{"id": &"finding_progress", "group": "PROBEN", "label": "Befundfortschritt", "value": "+20 %"},
	]


func _primary_action_count(root: Node) -> int:
	var count := 0
	var overlay := root as PauseOverlay
	var buttons: Array[Button] = [
		overlay.resume_action(),
		overlay.settings_action(),
		overlay.stats_action(),
		overlay.abort_action(),
		overlay.back_action(),
	]
	for button in buttons:
		if button.get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_PRIMARY:
			count += 1
	return count


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


func _focus_target_inside(source: Control, path: NodePath, overlay: Control) -> bool:
	if source == null or path.is_empty():
		return false
	var target := source.get_node_or_null(path) as Control
	return target != null and (target == overlay or overlay.is_ancestor_of(target))


func _read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "%s ist lesbar" % path)
	return file.get_as_text() if file != null else ""


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _create_logical_host(logical_size: Vector2i) -> Control:
	var host := Control.new()
	host.name = "LogicalViewportHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = Vector2(logical_size)
	get_root().add_child(host)
	return host


func _resize_logical_host(host: Control, logical_size: Vector2i) -> void:
	host.size = Vector2(logical_size)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_PAUSE_OVERLAY_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
