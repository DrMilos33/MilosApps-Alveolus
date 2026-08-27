extends SceneTree

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var screen_source := _read_source("res://scripts/ui/screens/case_archive_screen.gd")
	_check(not screen_source.contains("LevelCaseIllustration"), "Fallarchiv baut keine Fallillustrationen mehr")
	_check(screen_source.contains("CaseBoard") and not screen_source.contains("JourneyConnector"), "Fallarchiv baut ein kompaktes chronologisches Fallbrett ohne Pfaddekoration")
	_check(screen_source.contains("AlveolusUIComponents.choice_row"), "Einsatzstationen verwenden die zentrale kompakte ChoiceRow-Rolle")
	_check(screen_source.contains("MOUSE_BUTTON_WHEEL_UP") and screen_source.contains("MOUSE_BUTTON_WHEEL_DOWN"), "Fallbrett besitzt eine explizite Mausradnavigation")
	_check(not screen_source.contains("add_theme_stylebox_override"), "Fallarchiv erzeugt keine lokalen StyleBoxen")
	var host := _create_logical_host(Vector2i(1280, 720))
	var source_entries := _fixture_entries()
	source_entries.reverse()
	var view_model := CaseArchiveViewModel.new(7, source_entries, &"case_01")
	var original_hash := view_model.get_content_hash()
	source_entries.clear()
	_check(view_model.get_entries().size() == 7, "View-Model kopiert das Eingabearray tief")
	var returned_entries := view_model.get_entries()
	returned_entries.remove_at(0)
	_check(view_model.get_entries().size() == 7, "View-Model gibt keine veränderbare interne Collection frei")
	_check(view_model.get_content_hash() == original_hash, "Externe Arrayänderungen verändern den Content-Hash nicht")
	_check(view_model.get_entry(&"case_01").get_order() == 1, "IDs und Reihenfolge bleiben im View-Model erhalten")
	_check(view_model.get_entry(&"intro").is_completed(), "Abschlusszustand wird explizit und ohne Statustextanalyse transportiert")
	_check(view_model.get_next_case_id() == &"case_01", "Der früheste freigeschaltete unvollständige Fall ist das einzige nächste Ziel")
	var completion_changed := CaseArchiveViewModel.new(7, _fixture_entries(true), &"case_01")
	_check(completion_changed.get_content_hash() != original_hash and completion_changed.get_next_case_id() == &"case_02", "Abschlusszustand beeinflusst Hash und Next-Bestimmung")

	var screen := CaseArchiveScreen.new()
	screen.theme = AlveolusVisualTheme.create_theme()
	host.add_child(screen)
	await process_frame
	_check(screen.apply(view_model), "Erste View-Model-Revision wird angewendet")
	await process_frame
	await process_frame
	_check(screen.get_applied_revision() == 7, "Screen quittiert die angewendete Revision")
	_check(screen.get_applied_content_hash() == original_hash, "Screen hält den angewendeten Content-Hash")
	_check(not screen.apply_view_model(view_model.duplicate_immutable()), "Identischer Inhalt wird idempotent nicht neu aufgebaut")
	var same_content_new_revision := CaseArchiveViewModel.new(8, view_model.get_entries(), &"case_01")
	_check(same_content_new_revision.get_content_hash() == original_hash, "Revision ist nicht Teil des visuellen Content-Hashs")
	_check(not screen.apply_view_model(same_content_new_revision), "Neue Revision ohne Inhaltsänderung baut Karten nicht erneut")
	_check(screen.get_applied_revision() == 8, "Inhaltsgleiche neue Revision wird dennoch quittiert")
	_check(screen.get_view_model().get_revision() == 8, "Quittierte Revision und gespeicherte View-Model-Kopie bleiben konsistent")
	var changed_same_revision := CaseArchiveViewModel.new(8, _fixture_entries(), &"intro")
	_check(not screen.apply_view_model(changed_same_revision), "Abweichender Inhalt ohne neue Revision wird als ungültig verworfen")
	_check(screen.get_scroll_container().follow_focus, "Fallliste hält fokussierte Karten sichtbar")
	_check(screen.get_scroll_container().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Fallbrett wächst mit weiteren Fällen vertikal statt als endloses horizontales Band")
	_check(screen.get_default_focus_control() == screen.card_for_case(&"case_01"), "Vorbereiteter Defaultfokus folgt dem nächsten freigeschalteten Fall")
	_check(get_root().gui_get_focus_owner() == null, "Apply greift keinen sichtbaren Fokus")
	_check(screen.get_node_or_null("PageShell") != null, "Fallarchiv verwendet den zentralen PageShell")
	_check(screen.get_node("PageShell").get_meta(&"alveolus_component", &"") == &"page_shell", "PageShell stammt aus AlveolusUIComponents")
	_check_page_header_contract(screen.get_node("PageShell") as PanelContainer, "Fallarchiv")

	var unlocked := screen.card_for_case(&"case_01")
	var locked := screen.card_for_case(&"case_02")
	var completed := screen.card_for_case(&"intro")
	_check(unlocked != null and not unlocked.disabled, "Freigeschalteter Fall bleibt auswählbar")
	_check(locked != null and locked.disabled, "Gesperrter Fall ist funktional deaktiviert")
	_check(unlocked.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CHOICE_ROW, "Nächster Fall ist als dominante Einsatzstation markiert")
	_check(locked.theme_type_variation == AlveolusVisualTheme.TYPE_CHOICE_ROW, "Gesperrter Fall bleibt eine zentrale kompakte Station")
	_check(completed.get_meta(&"journey_state", &"") == &"completed" and unlocked.get_meta(&"journey_state", &"") == &"current" and locked.get_meta(&"journey_state", &"") == &"locked", "Stationsrollen unterscheiden Abschluss, nächstes Ziel und Fernziel explizit")
	var locked_status := locked.find_child("Status", true, false) as Label
	_check(locked_status != null and locked_status.text.contains("GESPERRT"), "Gesperrt wird zusätzlich zur Farbe als Text genannt")
	_check(unlocked.find_child("CaseIllustration", true, false) == null and locked.find_child("CaseIllustration", true, false) == null, "Fallkarten verwenden weiterhin keine Fallillustration oder externes Bildasset")
	_assert_case_station(completed, &"check")
	_assert_case_station(unlocked, &"target")
	_assert_case_station(locked, &"locked")
	_check(unlocked.find_child("Facts", true, false) == null, "Minuten- und Bosszeit-Fakten belegen keine sichtbare Kartenzeile mehr")
	var visible_copy := _visible_label_copy(unlocked)
	_check(not visible_copy.contains("Boss") and not visible_copy.contains("Min."), "Sichtbare Fallkartencopy enthält weder Boss- noch Minutenzeit")
	var summary := unlocked.find_child("Summary", true, false) as Label
	_check(summary != null and summary.max_lines_visible == 1 and summary.text == "Bereit zur Einsatzplanung", "Nächster Fall zeigt eine knappe handlungsbezogene Zusammenfassung")
	var unlocked_title := unlocked.find_child("Title", true, false) as Label
	_check(unlocked_title != null and unlocked_title.size.x >= 80.0 and unlocked_title.text == "Lokaler Herd", "Falltitel bleibt in der kompakten Rasterkarte lesbar")
	_check(unlocked.find_child("Best", true, false) == null and unlocked.find_child("Record", true, false) == null, "Fallkarte reserviert keine getrennten Metadatenzeilen")
	_check(completed.custom_minimum_size.y == CaseArchiveScreen.CARD_HEIGHT and unlocked.custom_minimum_size.y == CaseArchiveScreen.CARD_HEIGHT and locked.custom_minimum_size.y == CaseArchiveScreen.CARD_HEIGHT, "Alle Fälle verwenden eine gleichmäßig kompakte Kartenhöhe")
	var board := screen.find_child("CaseBoard", true, false) as GridContainer
	_check(board != null and board.get_meta(&"alveolus_component", &"") == &"case_board", "Fallbrett besitzt eine stabile semantische Komponente")
	_check(board != null and board.columns == 4 and board.get_child_count() == 7 and ceili(float(board.get_child_count()) / float(board.columns)) == 2, "Sieben Fälle stehen auf der breiten Bühne in genau zwei Reihen")
	_check(board != null and board.get_child(0) == completed and board.get_child(6) == screen.card_for_case(&"case_06"), "Raster und Eingaben verwenden trotz unsortierter Quelldaten dieselbe Chronologie")
	_check(screen.find_children("JourneyConnector", "ColorRect", true, false).is_empty(), "Das kompakte Fallbrett reserviert keinen Platz für Pfadverbinder")
	_check(unlocked.get_node_or_null(unlocked.focus_neighbor_left) == completed and unlocked.get_node_or_null(unlocked.focus_neighbor_right) == screen.find_child("BackButton", true, false), "Räumliche Pfeilnavigation verbindet Bedienbares, überspringt Locks und endet in der Kopfaktion")
	_check(bool(unlocked.get_meta(&"alveolus_owns_directional_focus", false)), "Fallkarten schützen ihre räumliche Navigation vor dem globalen Fokuszyklus")

	var selected_ids: Array[StringName] = []
	screen.case_selected.connect(func(case_id: StringName) -> void: selected_ids.append(case_id))
	_emit_wheel(screen.get_scroll_container(), MOUSE_BUTTON_WHEEL_UP)
	_check(get_root().gui_get_focus_owner() == completed, "Mausradnavigation bewegt den vorbereiteten Marker zu einem früheren Fall")
	_check(get_root().gui_get_focus_owner() == completed and selected_ids.is_empty(), "Reine Navigation fokussiert den früheren Fall, startet ihn aber nicht")
	_emit_wheel(screen.get_scroll_container(), MOUSE_BUTTON_WHEEL_DOWN)
	_check(get_root().gui_get_focus_owner() == unlocked, "Mausradnavigation bewegt den Marker wieder zum nächsten Fall")
	_check(get_root().gui_get_focus_owner() == unlocked and selected_ids.is_empty(), "Vorwärtsnavigation fokussiert exakt den nächsten bedienbaren Fall")
	_check(not screen._move_focus_by_case(1) and get_root().gui_get_focus_owner() == unlocked, "Mausradnavigation klemmt am letzten freigeschalteten Fall ohne Wrap")
	unlocked.pressed.emit()
	_check(selected_ids == [&"case_01"], "Kartenklick emittiert ausschließlich den stabilen Fall-ID-Intent")
	var replay_count := [0]
	var back_count := [0]
	screen.replay_story.connect(func() -> void: replay_count[0] += 1)
	screen.back.connect(func() -> void: back_count[0] += 1)
	(screen.find_child("ReplayStoryButton", true, false) as Button).pressed.emit()
	(screen.find_child("BackButton", true, false) as Button).pressed.emit()
	_check(replay_count[0] == 1 and back_count[0] == 1, "Prolog und Zurück bleiben getrennte, explizite Intents")

	_resize_logical_host(host, Vector2i(480, 270))
	await process_frame
	await process_frame
	await process_frame
	var shell := screen.get_node_or_null("PageShell") as Control
	var header_actions := screen.find_child("HeaderActions", true, false) as Control
	var back_button := screen.find_child("BackButton", true, false) as Control
	var page_header := _semantic_component(shell, &"page_header")
	var scroll := screen.get_scroll_container()
	var scroll_bar := scroll.get_v_scroll_bar()
	board = screen.find_child("CaseBoard", true, false) as GridContainer
	_check(shell != null and _fully_inside(shell, host), "PageShell bleibt im echten logischen 480-mal-270-Host")
	_check(page_header != null and _fully_inside(page_header, host), "Fallarchivheader bleibt im echten logischen 480-mal-270-Host")
	_check(header_actions != null and _fully_inside(header_actions, host) and _fully_inside(header_actions, page_header), "Kompakte Headeraktionen bleiben vollständig in Header und Host")
	_check(back_button != null and _fully_inside(back_button, host) and _fully_inside(back_button, page_header), "Campus-Navigation bleibt vollständig in Header und Host")
	_check(scroll != null and _right_inside(scroll, host), "Fallscrollfläche bleibt rechts vollständig im Host")
	_check(board != null and board.columns == 2 and ceili(float(board.get_child_count()) / float(board.columns)) == 4, "Kompakte Bühne stapelt dieselben Fälle als vier zweispaltige Reihen")
	_check(scroll_bar.visible, "Vier kompakte Fallreihen aktivieren den erwarteten vertikalen Scrollpfad")
	_check(shell != null and shell.size.x <= host.size.x + 0.5 and _right_inside(shell, host), "Scrollbarreserve verbreitert die kompakte PageShell nicht horizontal")
	for entry in view_model.get_entries():
		var card := screen.card_for_case(entry.get_id())
		_check(card != null and card.size.x <= screen.get_scroll_container().size.x + 0.5, "Responsive Karte %s bleibt schmaler als der sichtbare Scrollbereich" % entry.get_id())
		_check(card != null and _right_inside_scroll_content(card, scroll), "Responsive Karte %s respektiert die vertikale Scrollbarreserve" % entry.get_id())

	var replay_model := CaseArchiveViewModel.new(9, _fixture_entries(true), &"case_02")
	_check(screen.apply_view_model(replay_model), "Ein späterer Fortschrittsstand baut das Fallbrett gezielt neu")
	await process_frame
	await process_frame
	var replay_case := screen.card_for_case(&"case_01")
	var next_case := screen.card_for_case(&"case_02")
	_check(replay_case != null and not replay_case.disabled and replay_case.get_meta(&"journey_state", &"") == &"completed", "Abgeschlossene Kampagnenfälle bleiben als Grind-Ziele bedienbar")
	_check(next_case != null and next_case.get_meta(&"journey_state", &"") == &"current", "Der Fortschrittsmarker wandert unabhängig von wiederholbaren Fällen weiter")
	selected_ids.clear()
	replay_case.pressed.emit()
	_check(selected_ids == [&"case_01"], "Ein wiederholter abgeschlossener Kampagnenfall emittiert weiterhin seine stabile ID")

	host.queue_free()
	await process_frame
	_finish()


func _fixture_entries(case_one_completed: bool = false) -> Array[CaseArchiveViewModel.CaseEntryViewModel]:
	var result: Array[CaseArchiveViewModel.CaseEntryViewModel] = []
	result.append(CaseArchiveViewModel.CaseEntryViewModel.new(
		&"intro", 0, "Das Lungenmodell", "Intro · Abgeschlossen", "∞ · Lektion 3",
		"", "1 Sieg · Lv 1 · 4 Bakt.", true, true, AlveolusVisualTheme.GOLD, true
	))
	result.append(CaseArchiveViewModel.CaseEntryViewModel.new(
		&"case_01", 1, "Lokaler Herd", "Fall 01 · Bereit", "3:00 Min. · Boss 2:15 Min.",
		"", "1 Sieg · Lv 2 · 20 Bakt." if case_one_completed else "Noch kein Sieg", false, true, AlveolusVisualTheme.COBALT, case_one_completed
	))
	result.append(CaseArchiveViewModel.CaseEntryViewModel.new(
		&"case_02", 2, "Die Ausbreitung", "Fall 02 · Gesperrt", "4:00 Min. · Boss 3:00 Min.",
		"", "Noch kein Sieg", false, case_one_completed, AlveolusVisualTheme.CORAL
	))
	result.append(CaseArchiveViewModel.CaseEntryViewModel.new(
		&"case_03", 3, "Schwerer Verlauf", "Fall 03 · Gesperrt", "5:00 Min. · Boss 3:45 Min.",
		"", "Noch kein Sieg", false, false, AlveolusVisualTheme.TURQUOISE
	))
	for order in range(4, 7):
		result.append(CaseArchiveViewModel.CaseEntryViewModel.new(
			StringName("case_%02d" % order), order, "Fallziel %02d" % order, "Fall %02d · Gesperrt" % order, "5:00 Min.",
			"", "Noch kein Sieg", false, false, AlveolusVisualTheme.COBALT
		))
	return result


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _create_logical_host(logical_size: Vector2i) -> Control:
	var host := Control.new()
	host.name = "LogicalViewportHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = Vector2(logical_size)
	get_root().add_child(host)
	return host


func _resize_logical_host(host: Control, logical_size: Vector2i) -> void:
	host.size = Vector2(logical_size)


func _emit_wheel(control: Control, button_index: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	control.gui_input.emit(event)


func _fully_inside(control: Control, container: Control, tolerance: float = 0.5) -> bool:
	if control == null or container == null:
		return false
	var rect := control.get_global_rect()
	var bounds := container.get_global_rect()
	return rect.position.x >= bounds.position.x - tolerance \
		and rect.position.y >= bounds.position.y - tolerance \
		and rect.end.x <= bounds.end.x + tolerance \
		and rect.end.y <= bounds.end.y + tolerance


func _right_inside(control: Control, container: Control, tolerance: float = 0.5) -> bool:
	if control == null or container == null:
		return false
	var rect := control.get_global_rect()
	var bounds := container.get_global_rect()
	return rect.position.x >= bounds.position.x - tolerance and rect.end.x <= bounds.end.x + tolerance


func _right_inside_scroll_content(control: Control, scroll: ScrollContainer, tolerance: float = 0.5) -> bool:
	if control == null or scroll == null:
		return false
	var content_right := scroll.get_global_rect().end.x
	var scroll_bar := scroll.get_v_scroll_bar()
	if scroll_bar != null and scroll_bar.visible:
		content_right = minf(content_right, scroll_bar.get_global_rect().position.x)
	return control.get_global_rect().end.x <= content_right + tolerance


func _assert_case_station(card: Button, expected_icon: StringName) -> void:
	var medallion := card.find_child("CaseStationMedallion", true, false) as PanelContainer
	var icon := card.find_child("CaseStationIcon", true, false) as SimpleIcon
	_check(medallion != null and medallion.theme_type_variation == AlveolusVisualTheme.TYPE_DOCUMENT_INSET, "Station verwendet ein zentral gestyltes Wegpunktmedaillon")
	_check(medallion != null and medallion.get_meta(&"alveolus_component", &"") == &"case_station_medallion", "Wegpunktmedaillon besitzt eine stabile semantische Rolle")
	_check(icon != null and icon.kind == expected_icon, "Stationszustand verwendet das erwartete semantische Wegpunktsymbol")


func _visible_label_copy(card: Button) -> String:
	var parts := PackedStringArray()
	for node in card.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.visible:
			parts.append(label.text)
	return " ".join(parts)


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


func _finish() -> void:
	if failures.is_empty():
		print("CASE_ARCHIVE_SCREEN_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("CASE_ARCHIVE_SCREEN_MODULE_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
