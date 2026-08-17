extends SceneTree

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var source_entries := _fixture_entries()
	var view_model := CaseArchiveViewModel.new(7, source_entries, &"case_01")
	var original_hash := view_model.get_content_hash()
	source_entries.clear()
	_check(view_model.get_entries().size() == 4, "View-Model kopiert das Eingabearray tief")
	var returned_entries := view_model.get_entries()
	returned_entries.remove_at(0)
	_check(view_model.get_entries().size() == 4, "View-Model gibt keine veränderbare interne Collection frei")
	_check(view_model.get_content_hash() == original_hash, "Externe Arrayänderungen verändern den Content-Hash nicht")
	_check(view_model.get_entry(&"case_01").get_order() == 1, "IDs und Reihenfolge bleiben im View-Model erhalten")

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
	_check(screen.get_scroll_container().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Responsive Fallkarten benötigen keinen horizontalen Scrollzwang")
	_check(screen.get_default_focus_control() == screen.card_for_case(&"case_01"), "Defaultfokus folgt dem gewählten freigeschalteten Fall")
	_check(screen.get_node_or_null("PageShell") != null, "Fallarchiv verwendet den zentralen PageShell")
	_check(screen.get_node("PageShell").get_meta(&"alveolus_component", &"") == &"page_shell", "PageShell stammt aus AlveolusUIComponents")
	_check_page_header_contract(screen.get_node("PageShell") as PanelContainer, "Fallarchiv")

	var unlocked := screen.card_for_case(&"case_01")
	var locked := screen.card_for_case(&"case_02")
	_check(unlocked != null and not unlocked.disabled, "Freigeschalteter Fall bleibt auswählbar")
	_check(locked != null and locked.disabled, "Gesperrter Fall ist funktional deaktiviert")
	_check(unlocked.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_CARD, "Gewählter Fall nutzt den zentralen Auswahlzustand")
	_check(locked.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTION_CARD, "Gesperrter Fall bleibt eine zentrale Auswahlkarte")
	var locked_status := locked.find_child("Status", true, false) as Label
	var locked_icon := locked.find_child("CaseIllustration", true, false) as LevelCaseIllustration
	_check(locked_status != null and locked_status.text.contains("Gesperrt"), "Gesperrt wird zusätzlich zur Farbe als Text genannt")
	_check(locked_icon != null and locked_icon.locked, "Gesperrt wird zusätzlich als Schloss in der Illustration gezeigt")
	_check(locked_icon.custom_minimum_size.x == locked_icon.custom_minimum_size.y, "Ungerahmte Fallillustration besitzt einen quadratischen Zeichenraum")
	_check(locked_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE and locked_icon.get_child_count() == 0, "Fallillustration ist eine ungerahmte, input-transparente Glyphe")

	var selected_ids: Array[StringName] = []
	screen.case_selected.connect(func(case_id: StringName) -> void: selected_ids.append(case_id))
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
	_check(shell != null and _fully_inside(shell, host), "PageShell bleibt im echten logischen 480-mal-270-Host")
	_check(page_header != null and _fully_inside(page_header, host), "Fallarchivheader bleibt im echten logischen 480-mal-270-Host")
	_check(header_actions != null and _fully_inside(header_actions, host) and _fully_inside(header_actions, page_header), "Kompakte Headeraktionen bleiben vollständig in Header und Host")
	_check(back_button != null and _fully_inside(back_button, host) and _fully_inside(back_button, page_header), "Campus-Navigation bleibt vollständig in Header und Host")
	_check(scroll != null and _right_inside(scroll, host), "Fallscrollfläche bleibt rechts vollständig im Host")
	_check(scroll_bar.visible, "Vier kompakte Fallkarten aktivieren den erwarteten vertikalen Scrollpfad")
	_check(shell != null and shell.size.x <= host.size.x + 0.5 and _right_inside(shell, host), "Scrollbarreserve verbreitert die kompakte PageShell nicht horizontal")
	for entry in view_model.get_entries():
		var card := screen.card_for_case(entry.get_id())
		_check(card != null and card.size.x <= screen.get_scroll_container().size.x + 0.5, "Responsive Karte %s bleibt im sichtbaren Scrollbereich" % entry.get_id())
		_check(card != null and _right_inside(card, host), "Responsive Karte %s bleibt rechts vollständig im Host" % entry.get_id())
		_check(card != null and _right_inside_scroll_content(card, scroll), "Responsive Karte %s respektiert die vertikale Scrollbarreserve" % entry.get_id())

	host.queue_free()
	await process_frame
	_finish()


func _fixture_entries() -> Array[CaseArchiveViewModel.CaseEntryViewModel]:
	var result: Array[CaseArchiveViewModel.CaseEntryViewModel] = []
	result.append(CaseArchiveViewModel.CaseEntryViewModel.new(
		&"intro", 0, "Das Lungenmodell", "Intro · Abgeschlossen", "Ereignisgesteuert · Lektion 3",
		"Beste Zeit 2:10", "1 Sieg · Lv 1 · Ziele 1/1", true, true, AlveolusVisualTheme.GOLD
	))
	result.append(CaseArchiveViewModel.CaseEntryViewModel.new(
		&"case_01", 1, "Lokaler Herd", "Fall 01 · Bereit", "3:00 Min. · Boss 2:15 Min.",
		"Noch kein Sieg", "0 Siege · Lv 0 · Ziele 0/3", false, true, AlveolusVisualTheme.COBALT
	))
	result.append(CaseArchiveViewModel.CaseEntryViewModel.new(
		&"case_02", 2, "Die Ausbreitung", "Fall 02 · Gesperrt", "4:00 Min. · Boss 3:00 Min.",
		"Noch kein Sieg", "0 Siege · Lv 0 · Ziele 0/3", false, false, AlveolusVisualTheme.CORAL
	))
	result.append(CaseArchiveViewModel.CaseEntryViewModel.new(
		&"case_03", 3, "Schwerer Verlauf", "Fall 03 · Gesperrt", "5:00 Min. · Boss 3:45 Min.",
		"Noch kein Sieg", "0 Siege · Lv 0 · Ziele 0/3", false, false, AlveolusVisualTheme.TURQUOISE
	))
	return result


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _create_logical_host(logical_size: Vector2i) -> Control:
	var host := Control.new()
	host.name = "LogicalViewportHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = Vector2(logical_size)
	get_root().add_child(host)
	return host


func _resize_logical_host(host: Control, logical_size: Vector2i) -> void:
	host.size = Vector2(logical_size)


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
