extends SceneTree

var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var host := Control.new()
	host.size = Vector2(1280.0, 720.0)
	host.theme = AlveolusVisualTheme.create_theme()
	get_root().add_child(host)

	var card := CampusBuildingCard.new()
	card.size = Vector2(190.0, 178.0)
	card.position = Vector2(260.0, 160.0)
	card.configure("FORSCHUNG", _test_texture(), AlveolusVisualTheme.GOLD, 166.0, 136.0)
	host.add_child(card)
	await process_frame
	await process_frame

	_check(card.title_panel != null and card.status_panel != null, "Campuskarte besitzt getrennte zentrale Titel- und Statuschrome")
	_check(card.title_panel.theme_type_variation == AlveolusVisualTheme.TYPE_HUD_OBJECTIVE, "Titelchrome verwendet die semantische HUD-Objective-Rolle")
	_check(card.status_panel.theme_type_variation == AlveolusVisualTheme.TYPE_DOCUMENT_INSET, "Statuschrome verwendet die semantische Document-Inset-Rolle")
	_check(card.title_panel.get_meta(&"alveolus_surface_role", -1) == AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE, "Titelchrome bezieht ihren Stil aus der zentralen HUD-Objective-Rolle")
	_check(card.status_panel.get_meta(&"alveolus_surface_role", -1) == AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET, "Statuschrome bezieht ihren Stil aus der zentralen Document-Inset-Rolle")
	_check(card.title_label.theme_type_variation == AlveolusVisualTheme.TYPE_VALUE_LABEL, "Gebäudetitel verwendet die zentrale Werte-Typografie")
	_check(card.status_label.theme_type_variation == AlveolusVisualTheme.TYPE_MUTED_LABEL, "Gebäudestatus verwendet die zentrale Metadaten-Typografie")
	_check(card.title_label.get_theme_font_size("font_size") >= AlveolusVisualTheme.TEXT_BODY, "Gebäudetitel bleibt mindestens in Fließtextgröße lesbar")
	_check(card.status_label.get_theme_font_size("font_size") >= AlveolusVisualTheme.TEXT_CAPTION, "Gebäudestatus unterschreitet die zulässige Metadatengröße nicht")
	_check(card.status_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and card.status_label.max_lines_visible == 2, "Langer Gebäudestatus nutzt zwei lesbare Zeilen statt einer abgeschnittenen Textleiste")

	card.set_status("Belohnung bereit und neue Forschung verfügbar", true)
	await process_frame
	_check(card.status_panel.visible and card.status_label.text == "Belohnung bereit und neue Forschung verfügbar", "Verfügbarer Status bleibt als redundanter Text erhalten")
	_check(card.status_label.get_theme_color("font_color") != AlveolusVisualTheme.SKY_DEEP, "Hervorgehobener Status erhält zusätzlich zur Beschriftung einen semantischen Akzent")

	var card_geometry := Rect2(card.position, card.size)
	var sprite_geometry := Rect2(card.building_sprite.position, card.building_sprite.size)
	var title_geometry := Rect2(card.title_panel.position, card.title_panel.size)
	var status_geometry := Rect2(card.status_panel.position, card.status_panel.size)
	card._set_mouse_over(true)
	card._process(1.0)
	_check(Rect2(card.position, card.size).is_equal_approx(card_geometry), "Hover verändert die Campus-Kartengeometrie nicht")
	_check(Rect2(card.building_sprite.position, card.building_sprite.size).is_equal_approx(sprite_geometry), "Hover verändert weder Gebäudegröße noch Anker")
	_check(card.building_sprite.scale.is_equal_approx(Vector2.ONE), "Hover skaliert das Gebäude-Asset nicht")
	_check(Rect2(card.title_panel.position, card.title_panel.size).is_equal_approx(title_geometry), "Hover verändert die Titelchrome nicht")
	_check(Rect2(card.status_panel.position, card.status_panel.size).is_equal_approx(status_geometry), "Hover verändert die Statuschrome nicht")

	card.grab_focus()
	await process_frame
	card._process(1.0)
	_check(card.building_sprite.scale.is_equal_approx(Vector2.ONE), "Tastatur- und Gamepadfokus bleibt geometrieneutral")
	var focus_outline_color: Color = card.outline_material.get_shader_parameter("outline_color")
	_check(focus_outline_color.is_equal_approx(AlveolusVisualTheme.GOLD), "Fokus verwendet den verbindlichen goldenen Outline-Akzent")
	_check(card.title_label.get_theme_color("font_color").is_equal_approx(AlveolusVisualTheme.GOLD), "Fokus ist zusätzlich über die Titeltypografie erkennbar")

	var emissions: Array[int] = [0]
	card.selected.connect(func() -> void: emissions[0] += 1)
	card.set_available(false, "Noch nicht freigeschaltet")
	_check(card.focus_mode == Control.FOCUS_NONE and card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Gesperrte Campuskarte ist weder per Fokus noch Maus aktivierbar")
	_check(card.status_label.text == "Noch nicht freigeschaltet", "Gesperrter Zustand wird redundant und verständlich benannt")
	_check(card.title_panel.modulate.a < 1.0 and card.status_panel.modulate.a < 1.0, "Gesperrte UI-Chrome ist zusätzlich sichtbar entsättigt")
	var accept_event := InputEventKey.new()
	accept_event.keycode = KEY_ENTER
	accept_event.pressed = true
	card._gui_input(accept_event)
	_check(emissions[0] == 0, "Gesperrte Campuskarte emittiert keine Auswahl")
	card.set_available(true)
	card._gui_input(accept_event)
	_check(emissions[0] == 1, "Freigeschaltete Campuskarte bewahrt ihr öffentliches selected-Signal")

	host.theme.default_base_scale = 2.0
	await process_frame
	await process_frame
	card._refresh_chrome_layout()
	_check(card.title_panel.size.x + 0.5 >= card.title_panel.get_combined_minimum_size().x, "Titelchrome schneidet ihren Text bei 200 Prozent nicht horizontal ab")
	_check(card.title_panel.size.y + 0.5 >= card.title_panel.get_combined_minimum_size().y, "Titelchrome schneidet ihren Text bei 200 Prozent nicht vertikal ab")
	_check(card.status_panel.size.x + 0.5 >= card.status_panel.get_combined_minimum_size().x, "Statuschrome respektiert die Textbreite bei 200 Prozent")
	_check(card.status_panel.size.y + 0.5 >= card.status_panel.get_combined_minimum_size().y, "Statuschrome respektiert zweizeiligen Text bei 200 Prozent")
	_check(not card.title_panel.clip_contents and not card.status_panel.clip_contents, "Campus-Chrome versteckt bei 200 Prozent keinen überlaufenden Text")

	card._set_mouse_over(false)
	card.release_focus()
	card._process(1.0)
	_check(not card.is_processing(), "Die Hoveranimation beendet ihren transienten Prozess nach Erreichen des Zielzustands")

	host.queue_free()
	await process_frame
	print("Campus building card Bio-Lumen checks: %d assertions" % assertions)
	if failures.is_empty():
		print("CAMPUS BUILDING CARD BIOLUMEN OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_texture() -> Texture2D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
