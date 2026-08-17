extends SceneTree

const OVERLAY_PATH := "res://scripts/ui/screens/finding_overlay.gd"
const VIEW_MODEL_PATH := "res://scripts/ui/view_models/finding_overlay_view_model.gd"
const FindingOverlayScript := preload(OVERLAY_PATH)
const FindingOverlayViewModelScript := preload(VIEW_MODEL_PATH)

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_assert_dependency_contract()
	_assert_immutable_view_model()
	await _assert_finding_interaction()
	_finish()


func _assert_immutable_view_model() -> void:
	var reaction_source := _reaction_fixture(6)
	var outgoing_source := _outgoing_fixture()
	var reserve := FindingOverlayViewModel.ReserveSwapViewModel.new(
		false,
		&"reserve_buffer",
		"Startreserve",
		true,
		false,
		outgoing_source,
		&"passive_a"
	)
	var model := FindingOverlayViewModelScript.new(
		7,
		&"grouping",
		"Gruppenbildung",
		"Mehrere Erreger sammeln sich im Gewebe.",
		"Bakteriengruppen treten häufiger auf.",
		reaction_source,
		&"observe",
		reserve,
		true,
		""
	)
	var original_hash := model.content_hash()
	reaction_source.clear()
	outgoing_source.clear()
	_check(model.reactions().size() == 3, "Befund-VM begrenzt die stabile Eingabereihenfolge deterministisch auf drei Reaktionen")
	_check(model.reaction(&"observe") != null and model.reaction(&"protect") != null and model.reaction(&"treat") == null, "Die ersten drei Reaktions-IDs bleiben erhalten; spätere Optionen gelangen nicht in die UI-Grenze")
	_check(model.mechanical_effect_text() == "Bakteriengruppen treten häufiger auf.", "Mechanischer Effekt bleibt als fertiger Präsentationstext verfügbar")
	_check(model.reserve_swap().outgoing_options().size() == 2, "Dormante Reserveoptionen bleiben als defensive Kopie erhalten")
	var returned_reactions := model.reactions()
	returned_reactions.clear()
	var returned_options := model.reserve_swap().outgoing_options()
	returned_options.clear()
	_check(model.reactions().size() == 3 and model.reserve_swap().outgoing_options().size() == 2, "Getter geben keine veränderbaren internen Collections frei")
	var info := model.reaction(&"observe").info()
	var payload := info.payload()
	payload["title"] = "Fremde Mutation"
	_check(model.reaction(&"observe").info().title() == "Weiter beobachten", "Info-Payload ist eine defensive Wertkopie")
	_check(model.content_hash() == original_hash and model.content_hash().length() == 64, "Externe Mutationen ändern den stabilen Inhaltshash nicht")
	_check(not model.reserve_swap().is_visible() and model.reserve_swap().incoming_id() == &"reserve_buffer", "Dormante Reserve bewahrt ihre ID ohne sichtbare Bedienung")

	var dynamic_variant := FindingOverlayViewModelScript.new(
		8,
		&"grouping",
		"Gruppenbildung",
		"Mehrere Erreger sammeln sich im Gewebe.",
		"Bakteriengruppen treten häufiger auf.",
		_reaction_fixture(3),
		&"protect",
		FindingOverlayViewModel.ReserveSwapViewModel.new(
			false,
			&"reserve_buffer",
			"Startreserve",
			true,
			false,
			_outgoing_fixture(),
			&"passive_b"
		),
		false,
		"Auswahl prüfen."
	)
	_check(dynamic_variant.structure_hash() == model.structure_hash(), "Auswahl und Validierung verändern den stabilen Strukturhash nicht")
	_check(dynamic_variant.content_hash() != model.content_hash(), "Dynamische Auswahl besitzt dennoch einen neuen Inhaltshash")
	_check(model.duplicate_immutable() != model and model.duplicate_immutable().content_hash() == model.content_hash(), "Gesamtes Befundmodell lässt sich identisch und ohne Objektidentität duplizieren")


func _assert_finding_interaction() -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var overlay := FindingOverlayScript.new() as FindingOverlay
	overlay.theme = AlveolusVisualTheme.create_theme()
	host.add_child(overlay)
	var base_model := _finding_model(1, _reaction_fixture(3), &"", _dormant_reserve(), true, "")
	_check(overlay.apply_view_model(base_model), "Erster Befund wird angewendet")
	await _settle()

	_check(overlay.modal_sheet() != null and overlay.modal_sheet().get_meta(&"alveolus_component", &"") == &"modal_sheet", "Befund verwendet den zentralen ModalSheet")
	_check(overlay.modal_sheet().custom_minimum_size.y <= 0.0, "Befund reserviert keine dekorative Leerraumhöhe")
	_check(overlay.modal_sheet().size.y <= overlay.modal_sheet().get_combined_minimum_size().y + 1.0, "Breiter Befund folgt seiner tatsächlichen Inhaltshöhe")
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and not overlay.body_scroll().get_v_scroll_bar().visible, "Kurzer Befund zeigt keine unnötige Scrollbar")
	_check(overlay.copy_grid().columns == 1 and overlay.copy_grid().get_child_count() == 1, "Befund zeigt genau eine kompakte mechanische Effektzeile")
	_check(overlay.copy_grid().get_meta(&"alveolus_component", &"") == &"finding_effect_line", "Effektzeile besitzt keine Karten- oder Erklärungsflächenrolle")
	_check(overlay.effect_label() != null and overlay.effect_label().text == "Bakteriengruppen treten häufiger auf." and overlay.effect_label().horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Spielwirkung steht zentral und ohne Überschrift bereit")
	_check(overlay.copy_grid().find_children("*", "PanelContainer", true, false).is_empty(), "Medizinischer Hintergrund und Im-Spiel-Kachel sind vollständig entfernt")
	_check(not _contains_label_text(overlay, "Mehrere Erreger sammeln sich im Gewebe."), "Medizinischer Langtext wird im kompakten Befund nicht mehr gerendert")
	_check(overlay.copy_grid().get_index() < overlay.reaction_grid().get_index(), "Breit steht der kompakte Effekt ohne zusätzlichen Leerraum vor der Auswahl")
	_check(overlay.reaction_grid().columns == 3 and overlay.reaction_grid().get_child_count() == 3, "Drei Reaktionen bleiben als kompakte Auswahl sichtbar")
	_check(overlay.reserve_panel() == null, "Dormanter Reservewechsel erzeugt weder Control noch Blank-Space")
	_check(overlay.confirm_action().disabled, "Ohne Reaktion bleibt die einzige Hauptaktion deaktiviert")
	_check(_primary_action_count(overlay) == 1, "Befund besitzt genau eine Hauptaktion")

	var observe := overlay.reaction_action(&"observe")
	_check(observe != null and observe.tooltip_text.is_empty() and bool(observe.get_meta(&"compact_reaction", false)), "Reaktionskarte bleibt kompakt und ohne doppelten nativen Tooltip")
	var hover_provider := overlay.tooltip_provider_for(observe)
	var info_provider := overlay.ui_info_provider_for(observe)
	_check(hover_provider.is_valid() and info_provider.is_valid() and hover_provider == info_provider, "Hover und ui_info verwenden denselben registrierbaren Provider")
	_check(hover_provider.call() == info_provider.call(), "Hover und ui_info liefern inhaltsgleiche Details")
	_check(overlay.registered_info_source_count() == 3, "Jede Reaktion besitzt genau eine Informationsquelle")
	var registrations := overlay.context_detail_registrations()
	var all_hover_only := registrations.size() == 3
	for registration in registrations:
		all_hover_only = all_hover_only and bool(registration.get("hover_enabled", false))
	_check(all_hover_only, "Registrierungen öffnen automatisch ausschließlich per Maus-Hover")

	var selected: Array[StringName] = []
	var confirmed: Array[Array] = []
	var cancelled: Array[bool] = []
	overlay.reaction_selected.connect(func(id: StringName) -> void: selected.append(id))
	overlay.confirm.connect(func(reaction_id: StringName, incoming_id: StringName, outgoing_id: StringName) -> void:
		confirmed.append([reaction_id, incoming_id, outgoing_id])
	)
	overlay.cancel.connect(func() -> void: cancelled.append(true))
	observe.pressed.emit()
	_check(selected == [&"observe"] and overlay.selected_reaction_id() == &"observe", "Reaktionsklick emittiert ausschließlich die stabile Reaktions-ID")
	_check(not overlay.confirm_action().disabled, "Vollständige gültige Auswahl aktiviert die Hauptaktion")
	overlay.confirm_action().pressed.emit()
	_check(confirmed == [[&"observe", &"", &""]], "Bestätigung ohne Reserve meldet keine versteckten Swap-IDs")
	_check(not overlay.handle_ui_cancel(false) and cancelled.is_empty(), "Nur die oberste Modalebene darf ui_cancel behandeln")
	_check(overlay.handle_ui_cancel(true) and cancelled.size() == 1, "Oberstes Befundmodal emittiert den Cancel-Intent")
	_check(overlay.grab_initial_focus(), "Befund kann seinen Auswahlfokus setzen")
	await process_frame
	_check(get_root().gui_get_focus_owner() == observe, "Ausgewählte Reaktion wird beim Fokus-Restore bevorzugt")
	_assert_focus_trap(overlay)

	var reserve_invalid := FindingOverlayViewModel.ReserveSwapViewModel.new(
		true,
		&"reserve_buffer",
		"Startreserve",
		true,
		true,
		_outgoing_fixture(),
		&"passive_a"
	)
	var invalid_model := _finding_model(2, _reaction_fixture(4), &"observe", reserve_invalid, false, "Kapazität überschritten.")
	_check(overlay.apply(invalid_model), "Reservevariante wird angewendet")
	await _settle()
	_check(overlay.reserve_panel() != null and bool(overlay.reserve_panel().get_meta(&"dormant_compatible", false)), "Optional aktivierter Reservezweig nutzt die bestehende kompatible Datenform")
	_check(overlay.swap_action() != null and overlay.swap_action().button_pressed, "Reservewechsel spiegelt den VM-Zustand")
	_check(overlay.outgoing_action() != null and not overlay.outgoing_action().disabled, "Aktiver Reservewechsel macht die Austauschwahl erreichbar")
	_check(overlay.validation_label().visible and overlay.validation_label().text == "Kapazität überschritten.", "Externe Validierung bleibt sichtbar und verständlich")
	_check(overlay.confirm_action().disabled, "Ungültiger Reservewechsel blockiert die Hauptaktion")

	var toggles: Array[bool] = []
	var outgoing: Array[StringName] = []
	overlay.swap_toggled.connect(func(enabled: bool) -> void: toggles.append(enabled))
	overlay.outgoing_selected.connect(func(id: StringName) -> void: outgoing.append(id))
	overlay.swap_action().toggled.emit(false)
	overlay.swap_action().toggled.emit(true)
	overlay.outgoing_action().item_selected.emit(1)
	_check(toggles == [false, true], "Reserve-Toggle emittiert nur den Präsentationszustand")
	_check(outgoing == [&"passive_b"] and overlay.selected_outgoing_id() == &"passive_b", "Austauschwahl emittiert die stabile ausgehende ID")

	var reaction_before := overlay.reaction_action(&"observe")
	var scroll_before := overlay.body_scroll()
	reaction_before.grab_focus()
	var reserve_valid := FindingOverlayViewModel.ReserveSwapViewModel.new(
		true,
		&"reserve_buffer",
		"Startreserve",
		true,
		true,
		_outgoing_fixture(),
		&"passive_b"
	)
	var valid_model := _finding_model(3, _reaction_fixture(4), &"observe", reserve_valid, true, "Reservewechsel ist gültig.")
	var structure_before := overlay.applied_structure_hash()
	_check(overlay.apply(valid_model), "Gültige dynamische Validierung wird angewendet")
	await _settle()
	_check(overlay.applied_structure_hash() == structure_before, "Validierung ändert die Befundstruktur nicht")
	_check(overlay.reaction_action(&"observe") == reaction_before and overlay.body_scroll() == scroll_before, "Dynamische Validierung verursacht keinen Karten- oder Scroll-Rebuild")
	_check(get_root().gui_get_focus_owner() == reaction_before, "Dynamisches Apply bewahrt den fokussierten Auslöser")
	_check(not overlay.confirm_action().disabled, "Gültiger vollständiger Reservewechsel aktiviert die Hauptaktion")
	overlay.confirm_action().pressed.emit()
	_check(confirmed.back() == [&"observe", &"reserve_buffer", &"passive_b"], "Bestätigung meldet Reaktion sowie beide unveränderten Content-IDs")

	var hidden_reserve := FindingOverlayViewModel.ReserveSwapViewModel.new(
		false,
		&"reserve_buffer",
		"Startreserve",
		true,
		true,
		_outgoing_fixture(),
		&"passive_b"
	)
	_check(overlay.apply(_finding_model(4, _reaction_fixture(4), &"observe", hidden_reserve, true, "")), "Reserve kann wieder dormant präsentiert werden")
	await _settle()
	_check(overlay.reserve_panel() == null and overlay.selected_outgoing_id() == &"passive_b", "Dormante Darstellung entfernt nur Controls und bewahrt die VM-ID")

	_resize_logical_host(host, Vector2i(480, 270))
	_check(overlay.apply(_finding_model(5, _reaction_fixture(6), &"protect", _dormant_reserve(), true, "")), "Dichter kompakter Befund wird angewendet")
	await _settle()
	_check(overlay.is_compact_layout(), "480 × 270 bildet den 200-Prozent-Kompaktfall ab")
	_check(overlay.copy_grid().columns == 1 and overlay.reaction_grid().columns == 1 and overlay.reaction_grid().get_child_count() == 3, "Kompakt bleiben Effekt und höchstens drei Reaktionen in lesbaren Einzelspalten")
	_check(overlay.reaction_action(&"treat") == null and overlay.registered_info_source_count() == 3, "Auch ein übergroßes Presenterarray erzeugt stabil nur drei Reaktionen und Tooltipquellen")
	_check(overlay.action_grid().columns == 2, "Zurück und Anwenden bleiben im 480-Pixel-Kompaktfall nebeneinander")
	_check(
		overlay.copy_grid().get_index() < overlay.reaction_grid().get_index(),
		"Kompakt bleibt die knappe mechanische Wirkung vor den Reaktionskarten sichtbar"
	)
	var compact_reaction_heading := overlay.find_child("ReactionHeading", true, false) as Label
	_check(compact_reaction_heading != null and not compact_reaction_heading.visible, "Kompakt entfällt die redundante Reaktionsüberschrift zugunsten der Wirkung und ersten Wahl")
	_check(
		_is_visible_in_scroll(overlay.effect_label(), overlay.body_scroll()),
		"Die mechanische Effektzeile ist beim Öffnen des kompakten Befunds sichtbar"
	)
	_check(
		_is_visible_in_scroll(overlay.reaction_action(&"observe"), overlay.body_scroll()),
		"Die erste Reaktionsentscheidung ist beim Öffnen des kompakten Befunds sichtbar"
	)
	_check(
		overlay.reaction_action(&"observe").size.y <= 72.0,
		"Kompakte Reaktionskarten bleiben inhaltsgetrieben statt freien Viewportplatz aufzublähen (%.1f px)" % overlay.reaction_action(&"observe").size.y
	)
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Nur echter kompakter Inhaltsüberlauf aktiviert Scrollen")
	_check(not overlay.body_scroll().is_ancestor_of(overlay.confirm_action()) and overlay.confirm_action().is_visible_in_tree(), "Hauptaktion bleibt fest außerhalb des Scrollinhalts sichtbar")
	_check(not overlay.body_scroll().is_ancestor_of(overlay.cancel_action()) and overlay.cancel_action().is_visible_in_tree(), "Zurück bleibt fest außerhalb des Scrollinhalts sichtbar")

	var no_effect_model := FindingOverlayViewModelScript.new(
		6,
		&"grouping",
		"Gruppenbildung",
		"Dieser medizinische Text bleibt außerhalb des Befunds.",
		"",
		_reaction_fixture(3),
		&"observe",
		_dormant_reserve(),
		true,
		""
	)
	_check(overlay.apply(no_effect_model), "Befund ohne mechanischen Präsentationstext wird sicher angewendet")
	await _settle()
	_check(overlay.effect_label() == null and overlay.copy_grid() == null, "Leerer Effekt erzeugt weder Platzhalter noch Blank-Space")

	overlay.hide()
	_check(not overlay.handle_ui_cancel(true), "Verborgenes Befundmodal konsumiert keine Routereingabe")
	host.queue_free()
	await process_frame


func _finding_model(
	revision: int,
	reactions: Array[FindingOverlayViewModel.ReactionViewModel],
	selected_id: StringName,
	reserve: FindingOverlayViewModel.ReserveSwapViewModel,
	valid: bool,
	validation_text: String
) -> FindingOverlayViewModel:
	return FindingOverlayViewModelScript.new(
		revision,
		&"grouping",
		"Gruppenbildung",
		"Mehrere Erreger sammeln sich im Gewebe.",
		"Bakteriengruppen treten häufiger auf.",
		reactions,
		selected_id,
		reserve,
		valid,
		validation_text
	)


func _reaction_fixture(count: int) -> Array[FindingOverlayViewModel.ReactionViewModel]:
	var definitions := [
		[&"observe", "Weiter beobachten", "Befundfortschritt erhöhen.", &"analysis"],
		[&"stabilize", "Stabilisieren", "Zustand kurzfristig schützen.", &"support"],
		[&"protect", "Patientenschutz", "Kontaktschaden reduzieren.", &"immune"],
		[&"treat", "Gezielt behandeln", "Behandlung verstärken.", &"treatment"],
		[&"slow", "Ausbreitung bremsen", "Gegnertempo senken.", &"clock"],
		[&"sample", "Probe sichern", "Zusätzliche Probe gewinnen.", &"sample"],
	]
	var result: Array[FindingOverlayViewModel.ReactionViewModel] = []
	for index in range(mini(count, definitions.size())):
		var definition: Array = definitions[index]
		var info := FindingOverlayViewModel.InfoViewModel.new(
			String(definition[1]),
			String(definition[2]),
			"Reaktion",
			StringName(definition[3]),
			AlveolusVisualTheme.GOLD
		)
		result.append(FindingOverlayViewModel.ReactionViewModel.new(
			StringName(definition[0]),
			String(definition[1]),
			String(definition[2]),
			StringName(definition[3]),
			AlveolusVisualTheme.GOLD,
			true,
			info
		))
	return result


func _outgoing_fixture() -> Array[FindingOverlayViewModel.OutgoingOptionViewModel]:
	var result: Array[FindingOverlayViewModel.OutgoingOptionViewModel] = []
	result.append(FindingOverlayViewModel.OutgoingOptionViewModel.new(&"passive_a", "Startprobe"))
	result.append(FindingOverlayViewModel.OutgoingOptionViewModel.new(&"passive_b", "Schnelltest"))
	return result


func _dormant_reserve() -> FindingOverlayViewModel.ReserveSwapViewModel:
	return FindingOverlayViewModel.ReserveSwapViewModel.new(
		false,
		&"reserve_buffer",
		"Startreserve",
		true,
		false,
		_outgoing_fixture(),
		&"passive_a"
	)


func _assert_focus_trap(overlay: FindingOverlay) -> void:
	var first := overlay.reaction_action(&"observe")
	var confirm_button := overlay.confirm_action()
	_check(first.get_node_or_null(first.focus_previous) == confirm_button, "Tab rückwärts bleibt im Befundmodal")
	_check(confirm_button.get_node_or_null(confirm_button.focus_next) == first, "Tab vorwärts bleibt im Befundmodal")


func _primary_action_count(overlay: FindingOverlay) -> int:
	var count := 0
	for button_value in overlay.find_children("*Button", "Button", true, false):
		var button := button_value as Button
		if button != null and button.get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_PRIMARY:
			count += 1
	return count


func _assert_dependency_contract() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_PATH) + "\n" + FileAccess.get_file_as_string(VIEW_MODEL_PATH)
	for forbidden in [
		"ContentCatalog",
		"MetaProgressionState",
		"PlayerStats",
		"RunState",
		"RunSession",
		"ConfigFile",
		"FileAccess",
		"save_game",
		"add_theme_stylebox_override",
		"Shader.new",
		"ShaderMaterial.new",
		"func _process",
		"func _physics_process",
	]:
		_check(not source.contains(forbidden), "Befundmodul bleibt frei von %s" % forbidden)
	_check(source.contains("AlveolusUIComponents.modal_sheet"), "Befund verwendet die zentrale ModalSheet-Komponente")
	_check(not source.contains("AlveolusUIComponents.semantic_copy_section"), "Befund erzeugt keine medizinische oder Im-Spiel-Erklärungskachel")
	_check(source.contains("finding_effect_line"), "Befund markiert die kartenlose mechanische Effektzeile semantisch")
	_check(source.contains("AlveolusUIComponents.choice_row"), "Reaktionsauswahl verwendet die zentrale kompakte Auswahlkomponente")
	_check(source.contains("AlveolusUIComponents.action_button"), "Befund verwendet zentrale semantische Aktionen")


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


func _is_visible_in_scroll(control: Control, scroll: ScrollContainer) -> bool:
	if control == null or scroll == null:
		return false
	return Rect2(scroll.global_position, scroll.size).intersects(control.get_global_rect())


func _contains_label_text(root: Control, expected_text: String) -> bool:
	for node_value in root.find_children("*", "Label", true, false):
		var label := node_value as Label
		if label != null and label.text == expected_text:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FINDING_OVERLAY_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FINDING_OVERLAY_MODULE_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
