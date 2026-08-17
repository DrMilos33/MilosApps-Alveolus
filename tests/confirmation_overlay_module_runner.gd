extends SceneTree

const OVERLAY_PATH := "res://scripts/ui/screens/confirmation_overlay.gd"
const VIEW_MODEL_PATH := "res://scripts/ui/view_models/confirmation_overlay_view_model.gd"
const ConfirmationOverlayScript := preload(OVERLAY_PATH)
const ConfirmationOverlayViewModelScript := preload(VIEW_MODEL_PATH)

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_assert_dependency_contract()
	_assert_immutable_view_model()
	await _assert_abort_confirmation()
	await _assert_restart_and_intro_variants()
	_finish()


func _assert_immutable_view_model() -> void:
	var original := ConfirmationOverlayViewModelScript.new(
		7,
		"  Level abbrechen?  ",
		"  Der Fortschritt geht verloren.  ",
		"Abbrechen",
		"Zurück",
		true,
		&"cancel"
	)
	var copied := original.duplicate_immutable()
	_check(original.revision() == 7 and original.title() == "Level abbrechen?", "View-Model normalisiert seine primitiven Anzeigewerte")
	_check(copied != original and copied.content_hash() == original.content_hash(), "Immutable-Duplikat teilt keine View-Model-Identität")
	_check(copied.is_danger() and copied.cancel_policy() == &"cancel", "Gefahrrolle und Cancel-Policy bleiben im Duplikat erhalten")
	var equivalent := ConfirmationOverlayViewModelScript.new(
		8,
		"Level abbrechen?",
		"Der Fortschritt geht verloren.",
		"Abbrechen",
		"Zurück",
		true,
		&"cancel"
	)
	_check(equivalent.content_hash() == original.content_hash(), "Revision ist nicht Teil des semantischen Content-Hashs")
	var sanitized := ConfirmationOverlayViewModelScript.new(9, "Titel", "Kurztext", "Ja", "Nein", false, &"unsupported")
	_check(sanitized.cancel_policy() == ConfirmationOverlayViewModel.CANCEL_POLICY_CANCEL, "Unbekannte Cancel-Policies fallen sicher auf Abbrechen zurück")
	var accessible_fallback := ConfirmationOverlayViewModelScript.new(10, "Titel", "Kurztext", " ", " ")
	_check(accessible_fallback.confirm_label() == "Bestätigen" and accessible_fallback.cancel_label() == "Zurück", "Leere Aktionslabels erhalten zugängliche sichere Fallbacks")


func _assert_abort_confirmation() -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var overlay := ConfirmationOverlayScript.new() as ConfirmationOverlay
	overlay.theme = AlveolusVisualTheme.create_theme()
	host.add_child(overlay)
	var abort_model := ConfirmationOverlayViewModelScript.new(
		1,
		"Level abbrechen?",
		"Der Fortschritt dieses Runs und die mögliche Forschungsbelohnung gehen verloren.",
		"Runde abbrechen",
		"Zurück",
		true,
		ConfirmationOverlayViewModel.CANCEL_POLICY_CANCEL
	)
	_check(overlay.apply_view_model(abort_model), "Abbruchbestätigung wird angewendet")
	await _settle()
	_check(overlay.modal_sheet() != null and overlay.modal_sheet().get_meta(&"alveolus_component", &"") == &"modal_sheet", "Bestätigung verwendet ausschließlich den zentralen ModalSheet")
	_check(overlay.modal_sheet().theme_type_variation == AlveolusVisualTheme.TYPE_MODAL_SHEET, "Bestätigung besitzt die zentrale Bio-Lumen-Modalrolle")
	_check(bool(overlay.modal_sheet().get_meta(&"confirmation_danger", false)), "Abbruch ist redundant als Gefahrrolle markiert")
	_check(overlay.modal_sheet().custom_minimum_size.y <= 0.0, "Modal reserviert keine dekorative Leerraumhöhe")
	_check(overlay.modal_sheet().size.y <= overlay.modal_sheet().get_combined_minimum_size().y + 1.0, "Breites Modal bleibt exakt inhaltsgetrieben")
	_check(not overlay.body_scroll().get_v_scroll_bar().visible, "Kurzer Bestätigungstext erzeugt keine unnötige Scrollbar")
	_check(overlay.action_grid().columns == 2, "Breite Bestätigung zeigt zwei kompakte Aktionen")
	_check(overlay.confirm_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_DANGER, "Abbruch besitzt genau eine Gefahrbestätigung")
	_check(overlay.cancel_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_SECONDARY, "Zurück bleibt die sichere Sekundäraktion")
	_check(_decisive_action_count(overlay) == 1, "Modal enthält genau eine primäre oder gefährliche Bestätigung")
	_check(overlay.default_focus_control() == overlay.cancel_action() and overlay.get_default_focus_control() == overlay.cancel_action(), "Sichere Abbrechen-Aktion ist der Defaultfokus")
	_check(overlay.cancel_policy() == &"cancel" and overlay.get_cancel_policy() == &"cancel", "Router kann die Cancel-Policy über den gemeinsamen Getter lesen")
	_check(overlay.grab_initial_focus(), "Bestätigung kann ihren Anfangsfokus setzen")
	await process_frame
	_check(get_root().gui_get_focus_owner() == overlay.cancel_action(), "Anfangsfokus liegt tatsächlich auf Zurück")
	_assert_focus_trap(overlay)

	var confirm_intents: Array[bool] = []
	var cancel_intents: Array[bool] = []
	overlay.confirm.connect(func() -> void: confirm_intents.append(true))
	overlay.cancel.connect(func() -> void: cancel_intents.append(true))
	_check(not overlay.handle_ui_cancel(false) and cancel_intents.is_empty(), "Eine verdeckte Routerebene reagiert nicht auf ui_cancel")
	_check(overlay.handle_ui_cancel(true) and cancel_intents.size() == 1, "Nur die oberste Routerebene emittiert den sicheren Cancel-Intent")
	overlay.confirm_action().pressed.emit()
	overlay.cancel_action().pressed.emit()
	_check(confirm_intents.size() == 1 and cancel_intents.size() == 2, "Bestätigen und Abbrechen emittieren getrennte Intents")

	var same_content_new_revision := abort_model.duplicate_immutable()
	same_content_new_revision = ConfirmationOverlayViewModelScript.new(
		2,
		same_content_new_revision.title(),
		same_content_new_revision.short_text(),
		same_content_new_revision.confirm_label(),
		same_content_new_revision.cancel_label(),
		same_content_new_revision.is_danger(),
		same_content_new_revision.cancel_policy()
	)
	_check(not overlay.apply_view_model(same_content_new_revision) and overlay.applied_revision() == 2, "Neue identische Revision wird ohne Layout-Churn quittiert")
	overlay.hide()
	_check(not overlay.handle_ui_cancel(true), "Verborgenes Modal konsumiert keine Eingabe")
	host.queue_free()
	await process_frame


func _assert_restart_and_intro_variants() -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var overlay := ConfirmationOverlayScript.new() as ConfirmationOverlay
	overlay.theme = AlveolusVisualTheme.create_theme()
	host.add_child(overlay)
	var restart_model := ConfirmationOverlayViewModelScript.new(
		1,
		"Runde neu starten?",
		"Fall, Plan und Seed bleiben gleich.",
		"Neu starten",
		"Zurück",
		false,
		&"cancel"
	)
	_check(overlay.apply(restart_model), "Neustartvariante wird angewendet")
	await _settle()
	_check(not bool(overlay.modal_sheet().get_meta(&"confirmation_danger", true)), "Neustart verwendet keine Gefahrrolle")
	_check(overlay.confirm_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_PRIMARY, "Neustart besitzt genau eine Primärbestätigung")
	var restart_title := overlay.find_child("ConfirmationTitle", true, false) as Label
	_check(restart_title != null and restart_title.text == "Runde neu starten?", "Neustarttitel bleibt knapp und eindeutig")

	_resize_logical_host(host, Vector2i(480, 270))
	var intro_model := ConfirmationOverlayViewModelScript.new(
		2,
		"Einführung überspringen?",
		"Fall 1 wird freigeschaltet. Die Einführung bleibt später wiederholbar.",
		"Überspringen",
		"Zurück",
		false,
		&"cancel"
	)
	_check(overlay.apply(intro_model), "Intro-Skip-Variante wird angewendet")
	await _settle()
	_check(overlay.is_compact_layout() and overlay.action_grid().columns == 2, "200-Prozent-Kompaktansicht hält kurze Bestätigungsaktionen platzsparend nebeneinander")
	_check(overlay.modal_sheet().size.x <= overlay.body_scroll().size.x + 0.5, "Kompaktes Modal bleibt vollständig in der Scrollbreite")
	_check(not overlay.body_scroll().get_v_scroll_bar().visible, "Kurze Intro-Bestätigung erzeugt keinen unnötigen Scrollbalken")
	_check(overlay.default_focus_control() == overlay.cancel_action(), "Auch Intro-Skip fokussiert niemals ungefragt die irreversible Aktion")
	_check(_decisive_action_count(overlay) == 1, "Intro-Skip behält genau eine Primärbestätigung")

	var consume_model := ConfirmationOverlayViewModelScript.new(
		3,
		"Pflichtbestätigung",
		"Diese Ebene verarbeitet Zurück, bleibt aber geöffnet.",
		"Bestätigen",
		"Zurück",
		false,
		ConfirmationOverlayViewModel.CANCEL_POLICY_CONSUME
	)
	var cancels: Array[bool] = []
	overlay.cancel.connect(func() -> void: cancels.append(true))
	_check(overlay.apply(consume_model), "Consume-Policy wird als explizite Routervariante angewendet")
	await _settle()
	_check(overlay.handle_ui_cancel(true) and cancels.is_empty(), "Consume-Policy schließt die Pflichtbestätigung nicht unabsichtlich")
	host.queue_free()
	await process_frame


func _assert_focus_trap(overlay: ConfirmationOverlay) -> void:
	var cancel_button := overlay.cancel_action()
	var confirm_button := overlay.confirm_action()
	_check(cancel_button.get_node_or_null(cancel_button.focus_previous) == confirm_button, "Tab rückwärts bleibt im Modal")
	_check(confirm_button.get_node_or_null(confirm_button.focus_next) == cancel_button, "Tab vorwärts bleibt im Modal")
	_check(cancel_button.get_node_or_null(cancel_button.focus_neighbor_left) == confirm_button, "Rückwärtsfokus bleibt im Modal")
	_check(confirm_button.get_node_or_null(confirm_button.focus_neighbor_right) == cancel_button, "Vorwärtsfokus bleibt im Modal")


func _decisive_action_count(overlay: ConfirmationOverlay) -> int:
	var count := 0
	for button_value in overlay.find_children("*Button", "Button", true, false):
		var button := button_value as Button
		if button == null:
			continue
		var role := StringName(button.get_meta(&"alveolus_action_role", &""))
		if role in [AlveolusUIComponents.ACTION_PRIMARY, AlveolusUIComponents.ACTION_DANGER]:
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
		_check(not source.contains(forbidden), "Bestätigungsmodul bleibt frei von %s" % forbidden)
	_check(source.contains("AlveolusUIComponents.modal_sheet"), "Bestätigung nutzt die zentrale ModalSheet-Komponente")
	_check(source.contains("AlveolusUIComponents.action_button"), "Bestätigung nutzt zentrale semantische Aktionen")


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
		print("CONFIRMATION_OVERLAY_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("CONFIRMATION_OVERLAY_MODULE_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
