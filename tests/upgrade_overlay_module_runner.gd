extends SceneTree

const UPGRADE_OVERLAY_PATH := "res://scripts/ui/screens/upgrade_overlay.gd"
const UPGRADE_VIEW_MODEL_PATH := "res://scripts/ui/view_models/upgrade_overlay_view_model.gd"
const UpgradeOverlayScript := preload(UPGRADE_OVERLAY_PATH)
const UpgradeOverlayViewModelScript := preload(UPGRADE_VIEW_MODEL_PATH)

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_boundaries()
	var ordinary_single := _test_immutable_view_model()
	await _test_overlay_contract(ordinary_single)
	_finish()


func _test_source_boundaries() -> void:
	var source := _read_source(UPGRADE_OVERLAY_PATH) + "\n" + _read_source(UPGRADE_VIEW_MODEL_PATH)
	for forbidden in [
		"MetaProgressionState",
		"PlayerStats",
		"RunState",
		"RunSession",
		"ContentCatalog",
		"UpgradeDefinition",
		"ConfigFile",
		"FileAccess",
		"save_game",
	]:
		_check(not source.contains(forbidden), "Ausbaumodul besitzt keine verbotene Abhängigkeit %s" % forbidden)
	_check(source.contains("AlveolusUIComponents.modal_sheet"), "Ausbauwahl verwendet die zentrale ModalSheet-Konstruktion")
	_check(source.contains("AlveolusUIComponents.choice_card"), "Ausbauoptionen verwenden zentrale Auswahlkarten")
	_check(source.contains("AlveolusUIComponents.semantic_copy_section"), "Explizite Einführung verwendet die zentrale semantische Infokarte")
	_check(source.contains("AlveolusUIComponents.action_button"), "Nebenaktionen verwenden zentrale Action-Komponenten")
	_check(not source.contains("add_theme_stylebox_override"), "Ausbauwahl erzeugt keine lokale StyleBox-Kopie")
	_check(not source.contains("Shader.new") and not source.contains("ShaderMaterial.new"), "Ausbauwahl erzeugt keine lokalen Shaderressourcen")
	_check(not source.contains("func _process") and not source.contains("func _physics_process"), "Ausbauwahl besitzt keine dauerhafte Prozessschleife")
	_check(not source.contains("scale = Vector2(") and source.contains("scale = Vector2.ONE"), "Ausbauwahl nutzt keine Fokus- oder Hover-Skalierung")


func _test_immutable_view_model() -> UpgradeOverlayViewModel:
	var source_rows: Array = [
		{
			"id": &"faster_impulse",
			"title": "Schnellere Impulse",
			"effect": "Behandlung erfolgt häufiger.",
			"before": "0,82 s",
			"after": "0,69 s",
			"icon_id": &"treatment",
			"accent_role": &"turquoise",
			"ignored_nested_state": {"mutable": true},
		},
	]
	var ordinary: UpgradeOverlayViewModel = UpgradeOverlayViewModelScript.create(
		source_rows,
		8,
		false,
		"Wähle in dieser Einführung genau diesen Ausbau.",
		false,
		false
	)
	_check(ordinary.is_valid() and ordinary.option_count() == 1, "Eine legitime einzelne normale Option bleibt vollständig gültig")
	_check(not ordinary.scripted_intro() and not ordinary.shows_education(), "Eine einzelne Option leitet niemals eigenmächtig einen Einführungstext ab")
	_check(ordinary.education_text().begins_with("Wähle"), "Verdeckter Education-Text bleibt als primitive Präsentationsinformation erhalten")
	_check(ordinary.option_at(0).comparison_text() == "0,82 s → 0,69 s", "Option stellt den kompakten Vorher-nachher-Vergleich bereit")
	_check(ordinary.option_at(-1) == null and ordinary.option_at(1) == null, "Ungültige Optionsindizes werden sicher abgewiesen")
	_check(ordinary.content_hash().length() == 64, "Ausbau-View-Model besitzt einen stabilen SHA-256-Inhaltshash")

	source_rows[0]["title"] = "Fremde Mutation"
	(source_rows[0]["ignored_nested_state"] as Dictionary)["mutable"] = false
	var returned_options := ordinary.options()
	returned_options.clear()
	_check(ordinary.option_count() == 1, "Zurückgegebene Optionsarrays sind defensive Kopien")
	_check(ordinary.option_at(0).title() == "Schnellere Impulse", "Spätere Quellmutationen erreichen das View-Model nicht")

	var equivalent: UpgradeOverlayViewModel = UpgradeOverlayViewModelScript.create([
		{
			"id": &"faster_impulse",
			"title": "Schnellere Impulse",
			"effect": "Behandlung erfolgt häufiger.",
			"before": "0,82 s",
			"after": "0,69 s",
			"icon_id": &"treatment",
			"accent_role": &"turquoise",
		},
	], 9, false, "Wähle in dieser Einführung genau diesen Ausbau.", false, false)
	_check(equivalent.content_hash() == ordinary.content_hash(), "Revision ist nicht Teil des semantischen Inhaltshashs")

	var scripted: UpgradeOverlayViewModel = UpgradeOverlayViewModelScript.create(
		_single_option_rows(), 10, true, "Dieser Hinweis gehört nur zum ausdrücklich geskripteten Einstieg."
	)
	_check(scripted.option_count() == 1 and scripted.shows_education(), "Nur das explizite scripted_intro-Flag aktiviert Education")

	var capped: UpgradeOverlayViewModel = UpgradeOverlayViewModelScript.create([
		{"id": &"a", "title": "A", "effect": "Effekt A"},
		{"id": &"a", "title": "Duplikat", "effect": "Darf nicht erscheinen"},
		{"id": &"b", "title": "B", "effect": "Effekt B"},
		{"id": &"c", "title": "C", "effect": "Effekt C"},
		{"id": &"d", "title": "D", "effect": "Effekt D"},
	], 11)
	_check(capped.option_count() == 3, "View-Model entfernt doppelte IDs und begrenzt die Darstellung auf drei Optionen")
	_check(capped.option_at(0).id() == &"a" and capped.option_at(2).id() == &"c", "Reihenfolge gültiger stabiler IDs bleibt erhalten")
	return ordinary


func _test_overlay_contract(ordinary_single: UpgradeOverlayViewModel) -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var overlay := UpgradeOverlayScript.new() as UpgradeOverlay
	overlay.theme = AlveolusVisualTheme.create_theme()
	host.add_child(overlay)
	_check(overlay.present(ordinary_single, false), "Erstes Present zeichnet eine normale einzelne Option")
	await _settle()

	_check(overlay.modal_sheet().theme_type_variation == AlveolusVisualTheme.TYPE_MODAL_SHEET, "Ausbauwahl besitzt die zentrale ModalSheet-Rolle")
	_check(overlay.modal_sheet().get_meta(&"alveolus_component", &"") == &"modal_sheet", "Ausbauwahl stammt aus der gemeinsamen ModalSheet-Komponente")
	_check(overlay.body_scroll().follow_focus, "Responsiver Inhaltsviewport folgt Tastatur- und Gamepadfokus")
	_check(overlay.body_scroll().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Ausbauwahl scrollt niemals horizontal")
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Eine normale einzelne Option benötigt keinen Scrollmodus")
	_check(not overlay.education_panel().visible, "Eine einzelne normale Option zeigt trotz vorhandenem Text keine Einführung")
	_check(overlay.cards().size() == 1 and overlay.cards_grid().columns == 1, "Eine einzelne Option bleibt eine eigenständige kompakte Karte")
	_assert_card_contract(overlay.cards()[0], ordinary_single.option_at(0).id())
	_check(get_root().gui_get_focus_owner() == overlay.neutral_focus_target(), "Mauspräsentation parkt Fokus sicher im Modal statt auf einer Hintergrundaktion")
	_check(not _visible_focus_ring(overlay.cards()[0]), "Ohne expliziten Fokus bleibt der Cyanring verborgen")
	_check(_focus_target_inside(overlay.neutral_focus_target(), overlay.neutral_focus_target().focus_next, overlay), "Tab vom neutralen Fokusplatz bleibt im blockierenden Modal")
	_check(_focus_target_inside(overlay.neutral_focus_target(), overlay.neutral_focus_target().focus_previous, overlay), "Shift+Tab vom neutralen Fokusplatz bleibt im blockierenden Modal")
	_check(overlay.modal_sheet().size.y <= overlay.modal_sheet().get_combined_minimum_size().y + 1.0, "Modal reserviert keinen dekorativen Leerraum")

	var selected_ids: Array[StringName] = []
	var reroll_intents: Array[bool] = []
	var cancel_intents: Array[bool] = []
	overlay.upgrade_selected.connect(func(id: StringName) -> void: selected_ids.append(id))
	overlay.reroll_requested.connect(func() -> void: reroll_intents.append(true))
	overlay.cancel_requested.connect(func() -> void: cancel_intents.append(true))
	overlay.cards()[0].pressed.emit()
	_check(selected_ids == [&"faster_impulse"], "Mausauswahl emittiert genau die stabile Ausbau-ID")
	_check(overlay.grab_initial_focus(), "Keyboard- und Gamepadpfad kann ausdrücklich den ersten Ausbau fokussieren")
	await process_frame
	var first_target := overlay.focus_targets()[0]
	_check(get_root().gui_get_focus_owner() == first_target, "Expliziter Anfangsfokus landet auf der ersten Ausbauoption")
	_check(_visible_focus_ring(overlay.cards()[0]), "Keyboardfokus wird klar mit Cyan statt Mausauswahl markiert")
	_check(overlay.cards()[0].scale.is_equal_approx(Vector2.ONE), "Fokus verändert die Kartengeometrie nicht")
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	first_target.gui_input.emit(accept)
	_check(selected_ids == [&"faster_impulse", &"faster_impulse"], "ui_accept emittiert dieselbe stabile ID genau einmal")

	var scripted: UpgradeOverlayViewModel = UpgradeOverlayViewModelScript.create(
		_single_option_rows(), 10, true, "Der erste Ausbau erklärt kurz die Vorher-nachher-Wirkung."
	)
	_check(overlay.present(scripted, false), "Expliziter Einführungssnapshot wird angewendet")
	await _settle()
	_check(overlay.education_panel().visible, "Explizites scripted_intro zeigt Education")
	var education_copy := overlay.education_panel().find_child("*", true, false)
	_check(overlay.education_panel().find_children("*", "Label", true, false).any(func(node: Node) -> bool: return (node as Label).text.contains("Vorher-nachher")), "Education bindet ihren geskripteten Text")
	_check(education_copy != null and overlay.cards().size() == 1, "Education ergänzt die eine Option statt sie aus der Anzahl abzuleiten")

	var three: UpgradeOverlayViewModel = UpgradeOverlayViewModelScript.create(_three_option_rows(), 11, false, "", true, true)
	_check(overlay.present(three, false), "Drei Ausbauoptionen werden gemeinsam präsentiert")
	await _settle()
	_check(overlay.cards().size() == 3 and overlay.cards_grid().columns == 3, "Breiter Viewport zeigt drei kompakte Karten ohne Browse-Churn")
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Drei normale Karten passen ohne Scrollbalken")
	_check(overlay.reroll_action().visible and overlay.cancel_action().visible, "Explizite optionale Nebenaktionen werden sichtbar")
	_check(overlay.reroll_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_SECONDARY, "Neu würfeln bleibt eine Sekundäraktion")
	_check(overlay.cancel_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_QUIET, "Abbrechen bleibt eine ruhige Nebenaktion")
	_check(not overlay.focus_targets().any(func(target: Control) -> bool: return _visible_focus_ring(target.get_parent() as Button)), "Mauspräsentation entfernt jeden früheren sichtbaren Fokuszustand")
	overlay.reroll_action().pressed.emit()
	overlay.cancel_action().pressed.emit()
	_check(reroll_intents.size() == 1 and cancel_intents.size() == 1, "Neu würfeln und Abbrechen emittieren getrennte Intents")
	_check(overlay.handle_ui_cancel() and cancel_intents.size() == 2, "ui_cancel wird konsumiert und emittiert nur bei erlaubtem Abbruch")

	_check(overlay.grab_initial_focus(), "Drei Optionen besitzen einen expliziten Fokusstart")
	await process_frame
	var targets := overlay.focus_targets()
	_check(targets.size() == 3, "Jede Karte besitzt genau ein Keyboard-/Gamepad-Fokusziel")
	_check(_focus_target_inside(targets[0], targets[0].focus_neighbor_left, overlay), "Rückwärtsnavigation bleibt im Overlay gefangen")
	_check(_focus_target_inside(targets[2], targets[2].focus_neighbor_right, overlay), "Vorwärtsnavigation erreicht nur Overlayaktionen")
	_check(_focus_target_inside(targets[0], targets[0].focus_previous, overlay), "Shift+Tab bleibt innerhalb des Overlay-Fokuszyklus")
	_check(_focus_target_inside(overlay.cancel_action(), overlay.cancel_action().focus_next, overlay), "Tab vom letzten sichtbaren Element kehrt in den Overlay-Zyklus zurück")
	_check(_visible_focus_ring(overlay.cards()[0]) and not _visible_focus_ring(overlay.cards()[1]), "Nur das tatsächlich fokussierte Feld trägt den Cyanring")

	# 480 × 270 models the logical viewport at 960 × 540 / 200-percent UI.
	_resize_logical_host(host, Vector2i(480, 270))
	await _settle()
	_check(overlay.cards_grid().columns == 1, "Bei 200 Prozent stapeln sich die Ausbaukarten lesbar")
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Nur der überlange kompakte Inhalt aktiviert Scrollen")
	_check(overlay.body_scroll().get_v_scroll_bar().visible, "Der notwendige Scrollbereich ist sichtbar erkennbar")
	_check(overlay.modal_sheet().size.x <= host.size.x + 0.5 and overlay.modal_sheet().size.y <= host.size.y + 0.5, "Kompaktes Modal bleibt vollständig im logischen Viewport")
	_check(overlay.reroll_action().is_visible_in_tree(), "Neu würfeln bleibt außerhalb des Scrollinhalts erreichbar")
	_check(overlay.grab_initial_focus(), "Kompaktes Layout behält einen sichtbaren Fokusstart")
	await process_frame
	_check(get_root().gui_get_focus_owner() == overlay.focus_targets()[0], "Kompakter Fokus bleibt am ersten Auswahlfeld")

	var mandatory: UpgradeOverlayViewModel = UpgradeOverlayViewModelScript.create(_single_option_rows(), 12, false, "", false, false)
	_check(overlay.present(mandatory, false), "Pflichtauswahl kann optionale Actions entfernen")
	await _settle()
	var prior_cancel_count := cancel_intents.size()
	_check(overlay.handle_ui_cancel(), "Pflichtmodal konsumiert ui_cancel ohne Durchfall")
	_check(cancel_intents.size() == prior_cancel_count, "Pflichtmodal emittiert ohne explizite Erlaubnis keinen Cancel-Intent")

	var stale: UpgradeOverlayViewModel = UpgradeOverlayViewModelScript.create(_three_option_rows(), 7)
	_check(not overlay.apply_view_model(stale), "Veraltete Presenter-Revision wird abgewiesen")
	_check(overlay.cards().size() == 1, "Veraltetes Apply verändert die sichtbare Pflichtauswahl nicht")
	overlay.hide()
	_check(not overlay.handle_ui_cancel(), "Verdecktes Overlay konsumiert ui_cancel nicht")
	host.queue_free()
	await process_frame


func _assert_card_contract(card: Button, option_id: StringName) -> void:
	_check(card.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTION_CARD, "Ausbaukarte verwendet die zentrale SelectionCard-Rolle")
	_check(card.get_meta(&"alveolus_component", &"") == &"choice_card", "Ausbaukarte stammt aus der gemeinsamen ChoiceCard-Komponente")
	_check(card.get_meta(&"upgrade_id", &"") == option_id, "Ausbaukarte trägt ausschließlich ihre stabile ID")
	_check(card.focus_mode == Control.FOCUS_NONE, "Mauskarten übernehmen keinen Keyboardfokus")
	_check(card.scale.is_equal_approx(Vector2.ONE), "Ausbaukarte bleibt ohne Scale-Transform")
	var title := card.find_child("UpgradeTitle", true, false) as Label
	var effect := card.find_child("UpgradeEffect", true, false) as Label
	var comparison := card.find_child("UpgradeComparison", true, false) as Label
	_check(title != null and effect != null and comparison != null, "Karte besitzt Iconzeile, Kurztext und Vorher-nachher-Wert")
	if effect != null:
		_check(effect.max_lines_visible == 2 and effect.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Kurze Wirkung nutzt höchstens zwei lesbare Zeilen")


func _single_option_rows() -> Array:
	return [
		{
			"id": &"faster_impulse",
			"title": "Schnellere Impulse",
			"effect": "Behandlung erfolgt häufiger.",
			"before": "0,82 s",
			"after": "0,69 s",
			"icon_id": &"treatment",
		},
	]


func _three_option_rows() -> Array:
	return [
		{"id": &"faster_impulse", "title": "Schnellere Impulse", "effect": "Behandlung erfolgt häufiger.", "before": "0,82 s", "after": "0,69 s", "icon_id": &"treatment"},
		{"id": &"stronger_impulse", "title": "Stärkerer Impuls", "effect": "Erhöht die Grundwirkung.", "before": "18", "after": "26", "icon_id": &"ability", "accent_role": &"gold"},
		{"id": &"wider_field", "title": "Breiteres Feld", "effect": "Erreicht mehr Ziele.", "before": "1 Ziel", "after": "3 Ziele", "icon_id": &"target", "accent_role": &"cobalt"},
	]


func _visible_focus_ring(card: Button) -> bool:
	if card == null:
		return false
	var ring := card.find_child("CyanFocusRing", false, false) as Control
	return ring != null and ring.visible and ring.get_meta(&"focus_color", Color.TRANSPARENT).is_equal_approx(AlveolusVisualTheme.TURQUOISE)


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
		print("ALVEOLUS_UPGRADE_OVERLAY_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
