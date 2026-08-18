extends SceneTree

const PROMPT_PATH := "res://scripts/ui/plain_run_prompt.gd"
const PlainRunPromptScript := preload(PROMPT_PATH)

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_assert_static_contract()
	await _assert_presentation_contract()
	await _assert_blocking_and_focus_contract()
	_finish()


func _assert_static_contract() -> void:
	var source := FileAccess.get_file_as_string(PROMPT_PATH)
	for forbidden in [
		"Panel",
		"ColorRect",
		"StyleBox",
		"Shader",
		"add_theme_color_override",
		"func _process",
		"func _physics_process",
		"Beobachte den ersten Erreger.",
		"Du greifst automatisch an.",
		"Geh nah ran, um die EXP einzusammeln.",
		"Infektionsherd erkannt",
	]:
		_check(not source.contains(forbidden), "PlainRunPrompt bleibt frei von %s" % forbidden)
	_check(source.contains("AlveolusUIComponents.label"), "Promptcopy wird ausschließlich über die zentrale Label-Komponente gebaut")
	_check(source.contains("AlveolusVisualTheme.TYPE_HUD_VALUE_LABEL"), "Haupttext verwendet die zentrale lesbare HUD-Typografie")
	_check(source.contains("AlveolusVisualTheme.CORAL"), "Korallenwarnung stammt aus der zentralen semantischen Farbe")
	_check(source.contains("func wait_for_left_click"), "Komponente besitzt eine ausdrückliche await-fähige Linksklickgrenze")


func _assert_presentation_contract() -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var prompt := PlainRunPromptScript.new() as PlainRunPrompt
	prompt.theme = AlveolusVisualTheme.create_theme()
	host.add_child(prompt)
	await _settle()
	_check(not prompt.visible, "PlainRunPrompt öffnet nicht ungefragt")
	_check(prompt.get_meta(&"alveolus_component", &"") == &"plain_run_prompt", "Komponente ist für Host und Router stabil markiert")
	_check(prompt.find_children("*", "Panel", true, false).is_empty(), "Prompt enthält keinerlei Panel")
	_check(prompt.find_children("*", "ColorRect", true, false).is_empty(), "Prompt enthält keinerlei Hintergrundfläche")
	_check(prompt.set_content("  Beobachtung läuft.  "), "Presentertext wird erstmalig angewendet")
	prompt.set_content_band(44.0, 102.0)
	_check(prompt.message_label().text == "Beobachtung läuft.", "Presentertext wird nur an den Rändern normalisiert")
	_check(prompt.message_label().modulate.is_equal_approx(AlveolusVisualTheme.IVORY), "Normalmodus bleibt ruhig und lesbar")
	_check(prompt.semantic_mode() == PlainRunPrompt.MODE_NORMAL, "Normalmodus ist semantisch abfragbar")
	prompt.show_prompt(false)
	await _settle()
	_check(prompt.visible and not prompt.owns_input(), "Normale Laufmeldung bleibt sichtbar und input-transparent")
	_check(prompt.mouse_filter == Control.MOUSE_FILTER_IGNORE and prompt.focus_mode == Control.FOCUS_NONE, "Nichtblockierende Meldung stiehlt weder Maus noch Fokus")
	_check(prompt.default_focus_control() == null, "Nichtblockierende Meldung exponiert kein künstliches Fokusziel")
	_check(prompt.get_meta(&"blocking_input", true) == false, "Hostmetadata kennzeichnet die passive Ebene eindeutig")
	_check(prompt.content_stack().size.x <= PlainRunPrompt.MAXIMUM_TEXT_WIDTH + 0.5, "Breiter Prompt begrenzt seine Zeilenlänge")
	_check(prompt.message_label().horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Run-Prompt ist als Textblock zentriert")
	_check(prompt.get_global_rect().is_equal_approx(host.get_global_rect()), "Die transparente Prompt-Ebene deckt trotz begrenzter Textzone den vollständigen Eingaberaum ab")
	var message_rect := prompt.message_label().get_global_rect()
	_check(message_rect.position.y >= 44.0 and message_rect.end.y <= 102.0, "Der Host kann die Plain-Copy direkt unter dem Lebensbalken in eine feste Bandzone legen")

	_check(prompt.set_content("Infektionssignal", PlainRunPrompt.MODE_CORAL), "Korallenmodus kann in-place gesetzt werden")
	_check(prompt.message_label().modulate.is_equal_approx(AlveolusVisualTheme.CORAL), "Warntext verwendet die zentrale Korallenrolle")
	_check(not prompt.mouse_hint_label().visible, "Eine normale Bossmeldung zeigt keinen Bestätigungshinweis")
	_check(not prompt.set_content("Infektionssignal", PlainRunPrompt.MODE_CORAL), "Identischer Presenterinhalt bleibt idempotent")
	prompt.hide_prompt(false)
	host.queue_free()
	await process_frame


func _assert_blocking_and_focus_contract() -> void:
	var host := _create_logical_host(Vector2i(960, 540))
	var return_button := Button.new()
	return_button.focus_mode = Control.FOCUS_ALL
	host.add_child(return_button)
	var prompt := PlainRunPromptScript.new() as PlainRunPrompt
	prompt.theme = AlveolusVisualTheme.create_theme()
	host.add_child(prompt)
	return_button.grab_focus()
	await process_frame

	prompt.set_content("Weiter beobachten.", PlainRunPrompt.MODE_NORMAL, true, "Linksklick zum Fortfahren")
	prompt.show_prompt()
	await _settle()
	_check(prompt.visible and prompt.owns_input() and prompt.confirmation_required(), "Bestätigung übernimmt ihre blockierende Ebene")
	_check(prompt.mouse_filter == Control.MOUSE_FILTER_STOP and prompt.focus_mode == Control.FOCUS_ALL, "Blockierende Meldung fängt Maus und Tastatur sicher ab")
	_check(get_root().gui_get_focus_owner() == prompt, "Blockierende Meldung besitzt den Fokus statt einer verdeckten HUD-Aktion")
	_check(prompt.default_focus_control() == prompt and prompt.grab_initial_focus(), "Host erhält ein stabiles Defaultfokusziel")
	_check(prompt.mouse_hint_label().visible and prompt.mouse_hint_label().text == "Linksklick zum Fortfahren", "Optionaler Maus-Hinweis erscheint nur für Bestätigungscopy")
	_check(prompt.is_awaiting_left_click() and prompt.get_meta(&"awaiting_left_click", false), "Await-Zustand ist API-seitig und als Hostmetadata sichtbar")
	_check(prompt.left_click_signal() == prompt.left_click_acknowledged, "Presenter kann dieselbe Bestätigung ausdrücklich awaiten")
	_check(not prompt.handle_ui_cancel(false) and prompt.handle_ui_cancel(true), "Nur die oberste blockierende Ebene konsumiert ui_cancel ohne fortzufahren")

	var acknowledgements: Array[bool] = []
	prompt.left_click_acknowledged.connect(func() -> void: acknowledgements.append(true))
	var keyboard_accept := InputEventKey.new()
	keyboard_accept.keycode = KEY_ENTER
	keyboard_accept.pressed = true
	prompt._gui_input(keyboard_accept)
	_check(acknowledgements.is_empty() and prompt.is_awaiting_left_click(), "Tastatur-Accept setzt ein Linksklick-Intro nicht fort")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	prompt._gui_input(right_click)
	_check(acknowledgements.is_empty() and prompt.is_awaiting_left_click(), "Andere Maustasten bestätigen nicht")
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	prompt._gui_input(left_click)
	prompt._gui_input(left_click)
	_check(acknowledgements.size() == 1, "Ein Linksklick emittiert genau eine Bestätigungsabsicht")
	_check(not prompt.is_awaiting_left_click(), "Bestätigte Copy wird bis zum nächsten Presenterinhalt entprellt")
	_check(prompt.owns_input(), "Presenterwechsel bleibt nach Klick atomar blockiert")
	_check(prompt.set_content("Passiver Hinweis", PlainRunPrompt.MODE_NORMAL), "Persistente View kann ohne Node-Neubau auf passive Copy wechseln")
	await _settle()
	_check(not prompt.owns_input() and get_root().gui_get_focus_owner() == return_button, "Wechsel auf passive Copy gibt Eingabe und Fokus cleanup-sicher frei")
	prompt.set_content("Weiter beobachten.", PlainRunPrompt.MODE_NORMAL, true, "Linksklick zum Fortfahren")
	prompt.show_prompt()
	await _settle()
	_check(prompt.owns_input() and prompt.is_awaiting_left_click(), "Dieselbe Instanz kann eine weitere Bestätigung persistent anzeigen")

	prompt.hide_prompt()
	await _settle()
	_check(not prompt.visible and not prompt.owns_input(), "Explizites Hide gibt die Eingabehoheit vollständig frei")
	_check(get_root().gui_get_focus_owner() == return_button, "Hide stellt den Fokus am vorherigen Auslöser wieder her")
	_check(prompt.mouse_hint_label().visible, "Hide mutiert die vom Presenter gelieferte Copy nicht")

	_resize_logical_host(host, Vector2i(480, 270))
	prompt.show_prompt()
	await _settle()
	_check(prompt.content_stack().size.x <= 448.5, "Kompakte logische Breite hält Text innerhalb des 16-Pixel-Sicherheitsrands")
	prompt.hide_prompt(false)
	host.queue_free()
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


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PLAIN_RUN_PROMPT_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PLAIN_RUN_PROMPT_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
