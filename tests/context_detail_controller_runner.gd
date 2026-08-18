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
	source.position = Vector2(406.0, 168.0)
	source.size = Vector2(62.0, 48.0)
	host.add_child(source)
	var focus_child := Button.new()
	focus_child.text = "Probe"
	focus_child.focus_mode = Control.FOCUS_ALL
	source.add_child(focus_child)

	var controller := ContextDetailControllerScript.new()
	host.add_child(controller)
	await _settle()
	var opened_events := [0]
	var closed_events := [0]
	controller.detail_opened.connect(func(_source: Control, _explicit: bool) -> void: opened_events[0] += 1)
	controller.detail_closed.connect(func() -> void: closed_events[0] += 1)

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
	controller.sync_sources(&"progression", [{
		"id": &"research:quick_test",
		"source": source,
		"provider": provider,
		"hover_enabled": true,
	}])

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
	_check(controller.card.get_global_rect().end.x <= source.get_global_rect().position.x - 5.5, "AUTO fällt am rechten Rand diagonal nach links oberhalb zurück")
	_check(controller.card.get_global_rect().end.y <= source.get_global_rect().position.y - 5.5, "AUTO hält auch im Links-Fallback die Karte oberhalb der Quelle")
	_check(_tree_ignores_mouse(controller.card), "Karte und kompletter Unterbaum ignorieren Mausereignisse")
	controller._measure_and_place(source.get_instance_id(), controller._layout_generation, 0)
	controller._measure_and_place(source.get_instance_id(), controller._layout_generation, 0)
	_check(
		_connection_count(process_frame, controller, &"_on_layout_settle_frame") == 1,
		"Mehrere Refreshes vor dem Layoutframe teilen genau einen Settle-Callback"
	)
	await process_frame
	_check(not controller._layout_settle_scheduled, "Der gemeinsame Settle-Callback räumt seinen Pending-Zustand auf")
	var short_height := controller.card.size.y
	long_copy[0] = true
	controller.sync_sources(&"progression", [{
		"id": &"research:quick_test",
		"source": source,
		"provider": provider,
		"hover_enabled": true,
	}])
	await _settle()
	_check(controller.is_open() and controller.active_source() == source, "Stable-ID-Sync bewahrt die geöffnete Quellinstanz")
	_check(opened_events[0] == 1 and closed_events[0] == 0, "Provider-Update erzeugt keinen Close/Open-Zyklus")
	_check(provider_calls[0] == 2, "Stable-ID-Sync wertet ausschließlich die aktive Quelle neu aus")
	_check(controller.body_label.text.contains("längerer Befundhinweis"), "Offener Tooltip übernimmt aktualisierte Rangdaten in-place")
	_check(controller.card.size.y > short_height, "In-place-Refresh misst die neue Inhaltshöhe erneut")
	hover_copy = [controller.title_label.text, controller.body_label.text, controller.meta_label.text]

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

	source.mouse_entered.emit()
	await _settle()
	_check(provider_calls[0] == 4, "Dynamische Provider werden bei jedem erneuten Öffnen ausgewertet")
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

	var preferred_source := PanelContainer.new()
	preferred_source.position = Vector2(24.0, 188.0)
	preferred_source.size = Vector2(62.0, 48.0)
	host.add_child(preferred_source)
	controller.register_source(preferred_source, func() -> Dictionary:
		return {"title": "Befund", "body": "+2 Monsterherden", "accent": AlveolusVisualTheme.CORAL}
	)
	preferred_source.mouse_entered.emit()
	await _settle()
	_check(controller.card.get_global_rect().position.x >= preferred_source.get_global_rect().end.x + 5.5, "AUTO bevorzugt diagonal rechts oberhalb")
	_check(controller.card.get_global_rect().end.y <= preferred_source.get_global_rect().position.y - 5.5, "Bevorzugte AUTO-Position liegt vollständig oberhalb")
	_check(_inside_viewport(controller.card, Vector2(480.0, 320.0)), "Bevorzugte diagonale Position bleibt viewportgebunden")
	preferred_source.mouse_exited.emit()
	await _settle()
	preferred_source.queue_free()
	await _settle()

	var placement_viewport := Vector2(480.0, 320.0)
	var placement_card_size := Vector2(100.0, 60.0)
	var right_above_source := Rect2(Vector2(100.0, 100.0), Vector2(40.0, 30.0))
	var right_above := controller._contained_position(right_above_source, placement_card_size, placement_viewport)
	_check(
		right_above == Vector2(146.0, 34.0),
		"AUTO verwendet als ersten vollständigen Kandidaten diagonal rechts oberhalb"
	)
	var left_above_source := Rect2(Vector2(400.0, 100.0), Vector2(40.0, 30.0))
	var left_above := controller._contained_position(left_above_source, placement_card_size, placement_viewport)
	_check(
		left_above == Vector2(294.0, 34.0),
		"AUTO verwendet bei fehlendem Rechtsraum als zweiten Kandidaten diagonal links oberhalb"
	)
	var right_below_source := Rect2(Vector2(100.0, 18.0), Vector2(40.0, 30.0))
	var right_below := controller._contained_position(right_below_source, placement_card_size, placement_viewport)
	_check(
		right_below == Vector2(146.0, 54.0),
		"Am oberen Viewportrand folgt auf beide oberen Kandidaten diagonal rechts unterhalb"
	)
	var left_below_source := Rect2(Vector2(400.0, 18.0), Vector2(40.0, 30.0))
	var left_below := controller._contained_position(left_below_source, placement_card_size, placement_viewport)
	_check(
		left_below == Vector2(294.0, 54.0),
		"AUTO verwendet erst nach rechts unten den vierten Kandidaten diagonal links unterhalb"
	)
	var complete_placements: Array[Vector2] = [right_above, left_above, right_below, left_below]
	for placement in complete_placements:
		_check(
			_inside_detail_bounds(placement, placement_card_size, placement_viewport),
			"Jeder vollständige AUTO-Kandidat bleibt innerhalb des Detail-Viewports: %s" % placement
		)

	var wide_source_rect := Rect2(Vector2(24.0, 188.0), Vector2(432.0, 48.0))
	var wide_card_size := Vector2(280.0, 60.0)
	var wide_fallback := controller._contained_position(
		wide_source_rect,
		wide_card_size,
		Vector2(480.0, 320.0)
	)
	_check(
		is_equal_approx(wide_fallback.x, 480.0 - ContextDetailController.VIEWPORT_MARGIN - wide_card_size.x),
		"Nach allen vier diagonalen Kandidaten wird die bevorzugte Rechtsposition deterministisch an den Viewport gebunden"
	)
	_check(
		wide_fallback.y + wide_card_size.y <= wide_source_rect.position.y - ContextDetailController.SOURCE_GAP + 0.5,
		"Der Vollbreiten-Fallback bleibt vollständig oberhalb der Quelle"
	)
	_check(
		_inside_detail_bounds(wide_fallback, wide_card_size, placement_viewport),
		"Auch der geklemmte Vollbreiten-Fallback bleibt vollständig innerhalb der Viewport-Margen"
	)
	_check(
		not Rect2(wide_fallback, wide_card_size).intersects(wide_source_rect),
		"Viewport-Clamping überdeckt die tatsächliche Quelle nicht"
	)
	var overlap_prone_source := Rect2(Vector2(300.0, 100.0), Vector2(60.0, 60.0))
	var overlap_prone_card_size := Vector2(220.0, 200.0)
	var source_safe_fallback := controller._contained_position(
		overlap_prone_source,
		overlap_prone_card_size,
		placement_viewport
	)
	_check(
		source_safe_fallback == Vector2(74.0, ContextDetailController.VIEWPORT_MARGIN),
		"Der deterministische Clamp verwirft einen überdeckenden Rechtskandidaten zugunsten des sicheren Linkskandidaten"
	)
	_check(
		_inside_detail_bounds(source_safe_fallback, overlap_prone_card_size, placement_viewport),
		"Der quellenexklusive Fallback bleibt vollständig innerhalb der Viewport-Margen"
	)
	_check(
		not Rect2(source_safe_fallback, overlap_prone_card_size).intersects(overlap_prone_source),
		"Der geklemmte Fallback überdeckt die Quelle auch bei fehlendem vertikalem Platz nie"
	)

	var ability_strip := PanelContainer.new()
	ability_strip.position = Vector2(112.0, 264.0)
	ability_strip.size = Vector2(256.0, 40.0)
	host.add_child(ability_strip)
	var ability_source := Button.new()
	ability_source.position = Vector2(6.0, 2.0)
	ability_source.size = Vector2(116.0, 36.0)
	ability_strip.add_child(ability_source)
	controller.register_source(
		ability_source,
		func() -> Dictionary:
			return {
				"title": "",
				"body": "Abklingzeit: 10 s\nSchaden: 55",
				"meta": "",
				"icon_kind": &"",
				"maximum_width": 244.0,
				"surface_opacity": 0.86,
			},
		true,
		ability_strip,
		ContextDetailController.Placement.ABOVE_CENTER
	)
	ability_source.mouse_entered.emit()
	await _settle()
	_check(controller.is_open() and not controller.header.visible, "Body-only-Tooltip entfernt den vollständigen leeren Header")
	_check(controller.body_label.text == "Abklingzeit: 10 s\nSchaden: 55" and not controller.meta_label.visible, "Kompakter Tooltip zeigt ausschließlich Faktenzeilen")
	_check(controller.card.get_global_rect().end.y <= ability_source.get_global_rect().position.y + 0.5, "Auch ein alter ABOVE_CENTER-Aufruf hält den Tooltip oberhalb der tatsächlichen Quelle")
	_check(is_equal_approx(controller.card.get_global_rect().end.x, 480.0 - ContextDetailController.VIEWPORT_MARGIN), "Veraltete Ability-Anker werden ignoriert und AUTO bleibt viewportgebunden an der tatsächlichen Quelle")
	_check(is_equal_approx(controller.card.self_modulate.a, 0.86), "Tooltipfläche respektiert die angeforderte Halbtransparenz")
	var tooltip_membrane := controller.card.get_node_or_null("BioLumenSurface") as CanvasItem
	_check(tooltip_membrane == null or not tooltip_membrane.visible, "Dekorative Bio-Lumen-Füllung überdeckt die halbtransparente Faktenfläche nicht")
	ability_source.mouse_exited.emit()
	await _settle()
	ability_strip.queue_free()
	await _settle()

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
	_check(is_equal_approx(controller.card.self_modulate.a, 1.0), "Ein normaler Folgetooltip setzt die optionale Halbtransparenz vollständig zurück")
	var restored_membrane := controller.card.get_node_or_null("BioLumenSurface") as CanvasItem
	_check(restored_membrane == null or restored_membrane.visible, "Ein normaler Folgetooltip stellt die Bio-Lumen-Füllung wieder her")
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


func _inside_detail_bounds(position: Vector2, card_size: Vector2, viewport_size: Vector2) -> bool:
	var margin := ContextDetailController.VIEWPORT_MARGIN
	var rect := Rect2(position, card_size)
	return rect.position.x >= margin - 0.5 \
		and rect.position.y >= margin - 0.5 \
		and rect.end.x <= viewport_size.x - margin + 0.5 \
		and rect.end.y <= viewport_size.y - margin + 0.5


func _tree_ignores_mouse(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _tree_ignores_mouse(child):
			return false
	return true


func _connection_count(signal_value: Signal, target: Object, method: StringName) -> int:
	var count := 0
	for connection_value in signal_value.get_connections():
		var connection := connection_value as Dictionary
		var callback: Callable = connection.get("callable", Callable())
		if callback.is_valid() and callback.get_object() == target and callback.get_method() == method:
			count += 1
	return count


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
