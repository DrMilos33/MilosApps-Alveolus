extends SceneTree

const DiscoveryTooltipScript := preload("res://scripts/ui/discovery_tooltip.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.name = "DiscoveryModalHost"
	host.size = Vector2(720.0, 540.0)
	host.theme = AlveolusVisualTheme.create_theme()
	get_root().add_child(host)

	var background_action := Button.new()
	background_action.name = "BlockedBackgroundAction"
	background_action.text = "Hintergrund"
	background_action.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(background_action)

	var target := Control.new()
	target.name = "DiscoveryTarget"
	target.position = Vector2(126.0, 216.0)
	target.size = Vector2(48.0, 48.0)
	host.add_child(target)

	var tooltip: DiscoveryTooltip = DiscoveryTooltipScript.new()
	host.add_child(tooltip)
	await _settle()

	var dismissed_count := [0]
	tooltip.dismissed.connect(func() -> void: dismissed_count[0] += 1)
	var short_definition := DiscoveryDefinition.create(
		&"short_biolumen_discovery",
		&"test",
		"Schnelltest",
		"Der Schnelltest ordnet eine Probe medizinisch ein.",
		"Der Befundfortschritt steigt sofort.",
		&"target",
		0,
		&"mechanic"
	)
	tooltip.present(short_definition, target)
	await _settle()

	_check(tooltip.visible, "Der Entdeckungsdialog wird durch present sichtbar")
	_check(tooltip.mouse_filter == Control.MOUSE_FILTER_STOP, "Der Full-rect-Dialog blockiert Mausinteraktionen im Hintergrund")
	_check(tooltip.panel.theme_type_variation == AlveolusVisualTheme.TYPE_MODAL_SHEET, "Die Entdeckung verwendet die zentrale ModalSheet-Variation")
	_check(tooltip.panel.get_meta(&"alveolus_component", &"") == &"modal_sheet", "Die sichtbare Fläche stammt aus der zentralen ModalSheet-Komponente")
	_check(tooltip.panel.get_meta(&"alveolus_surface_role", -1) == AlveolusVisualTheme.SurfaceRole.MODAL_SHEET, "Die Entdeckung bezieht ihre sichtbare Rolle aus der zentralen ModalSheet-Komponente")
	_check(tooltip.panel.get_node_or_null("BioLumenSurface") is BioLumenSurfaceFill, "Die Entdeckung nutzt die zentrale Bio-Lumen-Fläche statt einer lokalen Stylekopie")
	_check(tooltip.panel.size.y <= tooltip.copy_stack.get_combined_minimum_size().y + 170.0, "Das Modal folgt seiner tatsächlichen Inhaltshöhe ohne Leerraumreserve")
	_check(tooltip.title_label.text == "Neu · Schnelltest", "Der Titel benennt die konkrete neue Entdeckung ohne Obertitel-Dopplung")
	_check(tooltip.gameplay_label.text == short_definition.gameplay_text, "Die Spielwirkung übernimmt ihre unveränderten Inhaltsdaten")
	_check(tooltip.medical_label.text == short_definition.medical_text, "Der medizinische Kontext übernimmt seine unveränderten Inhaltsdaten")
	_check(tooltip.copy_stack.get_child_count() == 2, "Spielwirkung und medizinischer Kontext bilden exakt zwei semantische Flächen")
	for section in tooltip.copy_stack.get_children():
		_check(
			section.get_meta(&"alveolus_component", &"") == &"semantic_copy_section",
			"Beide Informationsbereiche stammen aus der zentralen semantischen Copy-Komponente"
		)

	var actions := _action_buttons(tooltip.panel)
	_check(actions.size() == 1 and actions[0] == tooltip.understood_button, "Der Pflichtdialog besitzt genau eine Aktion")
	_check(tooltip.understood_button.get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_PRIMARY, "Verstanden ist die einzige semantische Hauptaktion")
	_check(tooltip.understood_button.theme_type_variation == AlveolusVisualTheme.TYPE_PRIMARY_BUTTON, "Verstanden verwendet den globalen PrimaryButton statt eines lokalen Styles")
	_check(not tooltip.understood_button.has_theme_stylebox_override(&"normal"), "Die Hauptaktion besitzt keine lokale StyleBox-Kopie")
	_check(tooltip.understood_button.get_node_or_null("BioLumenFill") != null, "Die Hauptaktion nutzt die zentrale Bio-Lumen-Füllung")
	_check(get_root().gui_get_focus_owner() == tooltip.understood_button, "present setzt den Fokus auf die einzige sichere Aktion")
	_check(_focus_cycle_returns_to_self(tooltip.understood_button), "Der Ein-Aktions-Dialog fängt Tab und Richtungsfokus vollständig")
	_check(_inside_viewport(tooltip.panel, host.size), "Das inhaltsgetriebene Modal bleibt im logischen Viewport")
	_check(not tooltip.is_compact_sheet_active() and tooltip.highlighter.visible, "Mit ausreichendem Seitenraum bleibt die Entdeckung am sichtbaren Ziel verankert")
	_check(not tooltip.is_processing() and not tooltip.is_physics_processing(), "Der Dialog besitzt keine dauerhafte Process-Schleife")
	_check(not tooltip.highlighter.is_processing(), "Die pausierte Zielmarkierung benötigt keine Polling-Schleife")
	_check(tooltip.copy_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Kurzer Inhalt erzeugt keine unnötige Scrollfläche")
	var short_height := tooltip.panel.size.y

	var longer_definition := DiscoveryDefinition.create(
		&"long_biolumen_discovery",
		&"test",
		"Abwehrreaktion",
		"Abwehrzellen erkennen typische Oberflächenmerkmale. Sie umschließen Erreger und unterstützen deren kontrollierten Abbau im Lungengewebe.",
		"Die Abwehrreaktion bindet nahe Erreger. Für kurze Zeit sinkt ihr Kontaktdruck und die Behandlung kann die Gruppe sicher erreichen.",
		&"target",
		0,
		&"mechanic"
	)
	tooltip.present(longer_definition, target, "Die Reaktion bindet mehrere nahe Erreger und senkt vorübergehend ihren Kontaktdruck.")
	await _settle()
	_check(tooltip.gameplay_label.text.begins_with("Die Reaktion bindet"), "Ein Gameplay-Override bewahrt die bestehende present-Semantik")
	_check(tooltip.panel.size.y > short_height, "Die Modalhöhe wächst mit tatsächlichem Mehrinhalt statt mit einer festen Reserve")
	_check(_inside_viewport(tooltip.panel, host.size), "Auch mehrzeiliger Inhalt bleibt vollständig im Viewport")

	host.size = Vector2(480.0, 270.0)
	target.position = Vector2(216.0, 111.0)
	tooltip.present(longer_definition, target)
	await _settle()
	_check(tooltip.is_compact_sheet_active(), "Ohne ausreichenden Seitenraum wechselt die Entdeckung in das kompakte Sheet")
	_check(not tooltip.highlighter.visible, "Das kompakte Sheet verdeckt sein Ziel nicht zusätzlich mit einem irreführenden Highlighter")
	_check(_approximately_centered(tooltip.panel, host.size), "Das kompakte Entdeckungs-Sheet wird im logischen Viewport zentriert")
	_check(_inside_viewport(tooltip.panel, host.size), "Das kompakte Entdeckungs-Sheet bleibt vollständig im Viewport")

	tooltip.present(short_definition, null)
	await _settle()
	_check(tooltip.target_position.distance_to(host.size * 0.5) <= 0.5, "Ein fehlendes Ziel verwendet den logischen statt des physischen Viewport-Mittelpunkts")
	_check(tooltip.is_compact_sheet_active(), "Auch ohne Ziel bleibt die kompakte Entdeckung ein zentriertes Sheet")

	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	tooltip._gui_input(cancel_event)
	_check(dismissed_count[0] == 1, "ui_cancel fordert genau einmal das Schließen der obersten Entdeckung an")
	tooltip._gui_input(cancel_event)
	_check(dismissed_count[0] == 1, "Ein einzelner Eingabeimpuls kann die dismiss-Absicht nicht doppelt auslösen")

	tooltip.conceal()
	_check(not tooltip.visible and tooltip.target_object == null, "conceal versteckt den Dialog und löst sein Ziel ohne API-Änderung")
	_check(not tooltip.highlighter.visible, "conceal entfernt die verpflichtende Zielmarkierung")

	host.queue_free()
	await process_frame
	_finish()


func _settle() -> void:
	for _frame in range(3):
		await process_frame


func _action_buttons(root: Node) -> Array[Button]:
	var result: Array[Button] = []
	if root is Button and root.get_meta(&"alveolus_component", &"") == &"action_button":
		result.append(root as Button)
	for child in root.get_children():
		result.append_array(_action_buttons(child))
	return result


func _focus_cycle_returns_to_self(button: Button) -> bool:
	for path in [
		button.focus_previous,
		button.focus_next,
		button.focus_neighbor_left,
		button.focus_neighbor_right,
		button.focus_neighbor_top,
		button.focus_neighbor_bottom,
	]:
		if button.get_node_or_null(path) != button:
			return false
	return true


func _inside_viewport(control: Control, viewport_size: Vector2) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= -0.5 \
		and rect.position.y >= -0.5 \
		and rect.end.x <= viewport_size.x + 0.5 \
		and rect.end.y <= viewport_size.y + 0.5


func _approximately_centered(control: Control, viewport_size: Vector2) -> bool:
	var center_delta := control.get_global_rect().get_center() - viewport_size * 0.5
	return absf(center_delta.x) <= 1.0 and absf(center_delta.y) <= 1.0


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_DISCOVERY_MODAL_BIOLUMEN_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
