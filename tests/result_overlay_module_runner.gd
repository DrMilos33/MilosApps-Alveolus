extends SceneTree

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var stats_source := _stats_fixture()
	var success_model := ResultOverlayViewModel.new(
		1,
		true,
		"Herd kontrolliert",
		"Der Infektionsherd ist unter Kontrolle.",
		"Der Zustand des Patienten wurde stabilisiert.",
		stats_source,
		"+22 Forschung",
		"Fall 02 ist jetzt verfügbar.",
		"Erster Sieg · +1 Talentpunkt"
	)
	var success_hash := success_model.get_content_hash()
	stats_source.clear()
	_check(success_model.get_stats().size() == 3, "Ergebniswerte werden tief kopiert")
	var returned_stats := success_model.get_stats()
	returned_stats.clear()
	_check(success_model.get_stats().size() == 3, "Ergebnis-VM gibt keine veränderbare interne Collection frei")
	_check(success_model.get_content_hash() == success_hash, "Externe Mutationen verändern den Content-Hash nicht")

	var overlay := ResultOverlay.new()
	overlay.theme = AlveolusVisualTheme.create_theme()
	host.add_child(overlay)
	await process_frame
	_check(overlay.apply(success_model), "Siegreiche Ergebnisrevision wird angewendet")
	await _settle()
	_check(overlay.get_modal() != null and overlay.get_modal().get_meta(&"alveolus_component", &"") == &"modal_sheet", "Ergebnis verwendet den zentralen ModalSheet")
	_check(overlay.get_modal().get_meta(&"result_success", false), "Sieg besitzt die semantische Erfolgsrolle")
	_check(overlay.get_modal().custom_minimum_size.y <= 0.0, "Ergebnis reserviert keine feste Leerraumhöhe")
	var outcome_title := overlay.find_child("OutcomeTitle", true, false) as Label
	_check(outcome_title != null and outcome_title.get_line_count() == 1, "Ergebnistitel nutzt breit eine vollständige Zeile statt Zeichenumbruch")
	_check(outcome_title != null and outcome_title.size.x >= 180.0, "Ergebnistitel erhält die verfügbare Überschriftenbreite")
	_check(overlay.get_modal().size.y < host.size.y * 0.9, "Breites Ergebnis bleibt inhaltsgetrieben statt viewportfüllend")
	_check(overlay.get_stats_column_count() == 3, "Drei kompakte Wertezeilen stehen breit nebeneinander")
	_check(overlay.get_action_column_count() == 3, "Folgeaktionen stehen breit in drei Spalten")
	var result_actions := overlay.find_child("ResultActions", true, false) as GridContainer
	_check(overlay.get_modal().is_ancestor_of(overlay.get_scroll_container()), "Ergebnis besitzt einen internen Body-Scroll innerhalb des ModalSheets")
	_check(result_actions != null and not overlay.get_scroll_container().is_ancestor_of(result_actions), "Ergebnisaktionen liegen als fester Footer außerhalb des Body-Scrolls")
	_check(overlay.get_scroll_container().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Breiter kurzer Ergebnisinhalt erzeugt keinen unnötigen Scrollbereich")
	_check(_optional_section_count(overlay) == 3, "Belohnung, Freischaltung und Meisterschaft erscheinen nur bei vorhandenem Inhalt")
	_check(_primary_action_count(overlay) == 1, "Genau eine Folgeaktion ist visuell primär")
	_check(overlay.get_default_focus_control() == overlay.find_child("LevelsButton", true, false), "Fallübersicht ist die dominante Defaultaktion")
	overlay.grab_initial_focus()
	await process_frame
	_check(get_root().gui_get_focus_owner() == overlay.get_default_focus_control(), "Ergebnisfokus startet zuverlässig auf der Fallübersicht")
	_check(overlay.get_cancel_policy() == &"consume" and overlay.consumes_cancel() and overlay.handle_ui_cancel(), "ui_cancel wird am sichtbaren Ergebnis konsumiert statt den Abschluss zu schließen")
	_assert_focus_cycle(overlay)
	_check(not overlay.get_scroll_container().follow_focus and overlay.get_scroll_container().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Ergebnisrumpf bleibt vom Footerfokus entkoppelt und horizontal stabil")
	_assert_intents(overlay)

	_resize_logical_host(host, Vector2i(480, 270))
	await _settle()
	_check(overlay.is_compact_layout(), "480 logische Pixel bilden die 200-Prozent-Kompaktansicht ab")
	_check(overlay.get_stats_column_count() == 1, "Ergebniswerte stapeln kompakt einspaltig")
	_check(overlay.get_action_column_count() == 2, "Sekundäre Ergebnisaktionen sparen kompakt in zwei Spalten Platz für die Begründung")
	_check(overlay.get_modal().size.x <= overlay.size.x + 0.5, "ModalSheet bleibt vollständig in der kompakten Layerbreite")
	_check(_is_fully_visible(result_actions, overlay), "Der kompakte Aktionsfooter bleibt vollständig im sichtbaren Ergebnislayer")
	_check(overlay.get_scroll_container().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Nur der überlange kompakte Ergebnisrumpf aktiviert Scrollen")
	var footer_position_before_scroll := result_actions.global_position
	var compact_secondary_actions := overlay.find_child("CompactSecondaryActions", true, false) as GridContainer
	_check(compact_secondary_actions != null and compact_secondary_actions.visible and compact_secondary_actions.columns == 2, "Fallübersicht bleibt vollbreit über einer kompakten Sekundärzeile")
	_check(overlay.get_scroll_container().size.y >= 80.0, "Kompaktes Ergebnis zeigt neben dem Titel auch Begründung oder erste Werte")
	overlay.get_scroll_container().scroll_vertical = 100000
	await process_frame
	_check(overlay.get_scroll_container().scroll_vertical > 0, "Langer kompakter Ergebnisinhalt ist innerhalb des Modalrumpfs scrollbar")
	_check(result_actions.global_position.distance_to(footer_position_before_scroll) <= 0.5, "Body-Scrollen verschiebt den festen Aktionsfooter nicht")
	overlay.get_scroll_container().scroll_vertical = 100000
	overlay.grab_initial_focus()
	await _settle()
	_check(overlay.get_scroll_container().scroll_vertical == 0, "Kompaktes Ergebnis öffnet trotz CTA-Defaultfokus am Ergebnisanfang")
	var compact_title := overlay.find_child("OutcomeTitle", true, false) as Label
	_check(_is_visible_in_scroll(compact_title, overlay.get_scroll_container()), "Ausgang und Begründung beginnen sichtbar statt unterhalb der CTAs")
	_check(_is_fully_visible(result_actions, overlay), "Defaultfokus bleibt im sichtbaren Aktionsfooter ohne den Ergebnisrumpf zu verschieben")

	_resize_logical_host(host, Vector2i(1280, 720))
	var failure_model := ResultOverlayViewModel.new(
		2,
		false,
		"Zustand erschöpft",
		"Der Zustand ist auf null gefallen.",
		"Passe den Behandlungsplan vor dem nächsten Versuch an.",
		_stats_fixture(),
		"",
		"",
		""
	)
	_check(overlay.apply(failure_model), "Niederlagenrevision wird angewendet")
	await _settle()
	_check(not bool(overlay.get_modal().get_meta(&"result_success", true)), "Niederlage besitzt die semantische Gefahrenrolle")
	_check(_optional_section_count(overlay) == 0, "Leere Belohnungssektionen erzeugen weder Karten noch Blank-Space")
	var failure_title := overlay.find_child("OutcomeTitle", true, false) as Label
	_check(failure_title != null and failure_title.text == "Zustand erschöpft", "Niederlagentitel bleibt eindeutig und nicht nur farbcodiert")
	_check(_primary_action_count(overlay) == 1, "Auch die Niederlage behält genau eine primäre Folgeaktion")

	_assert_dependency_contract()
	overlay.hide()
	_check(not overlay.handle_ui_cancel(), "Ein verborgenes Ergebnis konsumiert keine Router-Eingabe")
	host.queue_free()
	await process_frame
	_finish()


func _assert_intents(overlay: ResultOverlay) -> void:
	var retry_count := [0]
	var levels_count := [0]
	var campus_count := [0]
	overlay.retry.connect(func() -> void: retry_count[0] += 1)
	overlay.levels.connect(func() -> void: levels_count[0] += 1)
	overlay.campus.connect(func() -> void: campus_count[0] += 1)
	(overlay.find_child("RetryButton", true, false) as Button).pressed.emit()
	(overlay.find_child("LevelsButton", true, false) as Button).pressed.emit()
	(overlay.find_child("CampusButton", true, false) as Button).pressed.emit()
	_check(retry_count[0] == 1 and levels_count[0] == 1 and campus_count[0] == 1, "Erneut, Fallübersicht und Campus emittieren getrennte Intents")


func _assert_focus_cycle(overlay: ResultOverlay) -> void:
	var levels_button := overlay.find_child("LevelsButton", true, false) as Button
	var retry_button := overlay.find_child("RetryButton", true, false) as Button
	var campus_button := overlay.find_child("CampusButton", true, false) as Button
	_check(levels_button != null and retry_button != null and campus_button != null, "Alle drei Ergebnisaktionen sind fokussierbar vorhanden")
	if levels_button == null or retry_button == null or campus_button == null:
		return
	_check(levels_button.get_node_or_null(levels_button.focus_neighbor_left) == campus_button, "Rückwärtsfokus bleibt in den Ergebnisaktionen")
	_check(campus_button.get_node_or_null(campus_button.focus_neighbor_right) == levels_button, "Vorwärtsfokus bleibt in den Ergebnisaktionen")


func _optional_section_count(overlay: ResultOverlay) -> int:
	var count := 0
	for panel in overlay.find_children("Optional_*", "PanelContainer", true, false):
		if (panel as Control).has_meta(&"result_optional_section"):
			count += 1
	return count


func _primary_action_count(overlay: ResultOverlay) -> int:
	var count := 0
	for button_value in overlay.find_children("*Button", "Button", true, false):
		var button := button_value as Button
		if button != null and button.theme_type_variation == AlveolusVisualTheme.TYPE_PRIMARY_BUTTON:
			count += 1
	return count


func _is_visible_in_scroll(control: Control, scroll: ScrollContainer) -> bool:
	if control == null or scroll == null:
		return false
	return Rect2(scroll.global_position, scroll.size).intersects(Rect2(control.global_position, control.size))


func _is_fully_visible(control: Control, viewport_control: Control) -> bool:
	if control == null or viewport_control == null:
		return false
	var viewport_rect := Rect2(viewport_control.global_position, viewport_control.size)
	var control_rect := Rect2(control.global_position, control.size)
	return viewport_rect.encloses(control_rect)


func _stats_fixture() -> Array[ResultOverlayViewModel.StatViewModel]:
	var result: Array[ResultOverlayViewModel.StatViewModel] = []
	result.append(ResultOverlayViewModel.StatViewModel.new(&"time", "Zeit", "2:31"))
	result.append(ResultOverlayViewModel.StatViewModel.new(&"analysis", "Befundstufe", "5", true))
	result.append(ResultOverlayViewModel.StatViewModel.new(&"defeats", "Bakterien", "74"))
	return result


func _assert_dependency_contract() -> void:
	for path in [
		"res://scripts/ui/screens/result_overlay.gd",
		"res://scripts/ui/view_models/result_overlay_view_model.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in ["ContentCatalog", "MetaProgressionState", "PlayerStats", "RunState", "LevelDefinition", "Save", "add_theme_stylebox_override", "ShaderMaterial", "func _process", "func _physics_process"]:
			_check(not source.contains(forbidden), "%s bleibt frei von %s" % [path, forbidden])


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
		print("RESULT_OVERLAY_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("RESULT_OVERLAY_MODULE_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
