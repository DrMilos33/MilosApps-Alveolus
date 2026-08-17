extends SceneTree

const ContextDetailControllerScript := preload("res://scripts/ui/context_detail_controller.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(480.0, 320.0)
	host.theme = AlveolusVisualTheme.create_theme()
	get_root().add_child(host)

	var source := PanelContainer.new()
	source.position = Vector2(406.0, 78.0)
	source.size = Vector2(62.0, 48.0)
	host.add_child(source)
	var focus_child := Button.new()
	focus_child.text = "Probe"
	focus_child.focus_mode = Control.FOCUS_ALL
	source.add_child(focus_child)

	var controller := ContextDetailControllerScript.new()
	host.add_child(controller)
	await _settle()

	var long_copy := [false]
	var provider_calls := [0]
	var provider := func() -> Dictionary:
		provider_calls[0] += 1
		return {
			"title": "Schnelltest",
			"body": "Ein kompakter Befundhinweis." if not long_copy[0] else "Ein längerer Befundhinweis nutzt mehrere sinnvoll umgebrochene Zeilen und vergrößert die Karte nur um seinen tatsächlichen Inhalt.",
			"meta": "Passiv · 1 K",
			"accent": AlveolusVisualTheme.COBALT,
			"icon_kind": &"finding_progress",
		}
	controller.register_source(source, provider)

	_check(controller.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Der Full-rect-Controller ignoriert Mausereignisse")
	_check(not controller.is_processing(), "Der Controller besitzt keine dauerhafte Prozessschleife")
	_check(not controller.is_open(), "Fokus allein öffnet keine Kontextkarte")
	focus_child.grab_focus()
	await _settle()
	_check(get_root().gui_get_focus_owner() == focus_child, "Die registrierte Kindquelle erhält regulären Fokus")
	_check(not controller.is_open(), "focus_entered bleibt ohne ausdrückliches ui_info stumm")

	source.mouse_entered.emit()
	await _settle()
	_check(controller.is_open() and not controller.is_explicit(), "Mouseover öffnet die Hoverkarte")
	_check(provider_calls[0] == 1, "Der Provider wird beim Öffnen frisch ausgewertet")
	var hover_copy := [controller.title_label.text, controller.body_label.text, controller.meta_label.text]
	_check(hover_copy == ["Schnelltest", "Ein kompakter Befundhinweis.", "Passiv · 1 K"], "Hover übernimmt Titel, Body und Meta vollständig")
	_check(_inside_viewport(controller.card, Vector2(480.0, 320.0)), "Die Hoverkarte bleibt vollständig im Viewport: %s" % controller.card.get_global_rect())
	_check(not controller.card.get_global_rect().intersects(source.get_global_rect()), "Die Hoverkarte überdeckt ihren Auslöser nicht")
	_check(_tree_ignores_mouse(controller.card), "Karte und kompletter Unterbaum ignorieren Mausereignisse")
	var short_height := controller.card.size.y

	source.mouse_exited.emit()
	await _settle()
	_check(not controller.is_open(), "mouse_exited schließt ausschließlich den Hovermodus")
	var focus_before: Control = get_root().gui_get_focus_owner()
	_check(controller.toggle_focused(focus_child), "ui_info löst eine registrierte Kindquelle zum Kartenursprung auf")
	await _settle()
	_check(controller.is_explicit(), "ui_info öffnet dieselben Daten ausdrücklich")
	_check([controller.title_label.text, controller.body_label.text, controller.meta_label.text] == hover_copy, "Hover und ui_info zeigen identische Copy")
	_check(get_root().gui_get_focus_owner() == focus_before, "Die ausdrückliche Detailkarte verändert den Fokus nicht")
	source.mouse_exited.emit()
	await _settle()
	_check(controller.is_explicit(), "mouse_exited schließt eine ausdrückliche Detailkarte nicht")
	_check(controller.toggle_focused(focus_child), "Erneutes ui_info wird vom selben Ursprung verarbeitet")
	_check(not controller.is_open(), "Erneutes ui_info schließt die ausdrückliche Karte")

	long_copy[0] = true
	source.mouse_entered.emit()
	await _settle()
	_check(provider_calls[0] == 3, "Dynamische Provider werden bei jedem erneuten Öffnen ausgewertet")
	_check(controller.card.size.y > short_height, "Die Kartenhöhe folgt dem tatsächlichen mehrzeiligen Inhalt: kurz=%.1f lang=%.1f" % [short_height, controller.card.size.y])
	_check(is_zero_approx(controller.card.custom_minimum_size.y), "Die Karte reserviert keine feste Leerraumhöhe")
	source.hide()
	await _settle()
	_check(not controller.is_open(), "Eine ausgeblendete Quelle schließt ihre Karte sicher")

	source.show()
	await _settle()
	source.mouse_entered.emit()
	await _settle()
	_check(controller.is_open(), "Eine wieder sichtbare Quelle kann erneut Details öffnen")
	source.queue_free()
	await _settle()
	_check(not controller.is_open() and controller.active_source() == null, "Eine freigegebene Quelle hinterlässt keine schwebende Karte")

	# Refreshes replace progression cards while the pointer is stationary. The
	# replacement must recover the same hover detail without waiting for another
	# physical mouse movement.
	var replacement := PanelContainer.new()
	replacement.position = Vector2(406.0, 78.0)
	replacement.size = Vector2(62.0, 48.0)
	host.add_child(replacement)
	controller.register_source(replacement, func() -> Dictionary:
		return {"title": "Schnelltest II", "body": "+25 % Befund", "accent": AlveolusVisualTheme.COBALT}
	)
	await _settle()
	controller.close_all()
	_check(
		controller._recover_hover_at(replacement.position + replacement.size * 0.5),
		"Eine neu gebaute Karte unter dem ruhenden Zeiger wird als Hoverquelle wiedererkannt"
	)
	await _settle()
	_check(controller.is_open() and controller.title_label.text == "Schnelltest II", "Der wiederhergestellte Tooltip zeigt die Daten der neuen Karteninstanz")
	replacement.queue_free()
	await _settle()

	host.queue_free()
	await process_frame
	_finish()


func _settle() -> void:
	for _frame in range(3):
		await process_frame


func _inside_viewport(control: Control, viewport_size: Vector2) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= -0.5 \
		and rect.position.y >= -0.5 \
		and rect.end.x <= viewport_size.x + 0.5 \
		and rect.end.y <= viewport_size.y + 0.5


func _tree_ignores_mouse(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _tree_ignores_mouse(child):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_CONTEXT_DETAIL_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
