extends SceneTree

const OUTPUT_DIR := "res://.codex-temp/style-gallery"

var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var packed := load("res://scenes/ui/style_gallery.tscn") as PackedScene
	_check(packed != null, "Stilgalerie ist als eigenständige Szene ladbar")
	if packed == null:
		_finish()
		return
	var gallery := packed.instantiate() as AlveolusStyleGallery
	get_root().add_child(gallery)
	await _settle()

	var visual_theme := gallery.theme
	_check(visual_theme.default_font_size >= 16, "Globaler Fließtext ist mindestens 16 Designpixel groß")
	for token in [
		AlveolusVisualTheme.SCREEN_MARGIN,
		AlveolusVisualTheme.SCREEN_MARGIN_COMPACT,
		AlveolusVisualTheme.HEADER_HEIGHT,
		AlveolusVisualTheme.HEADER_HEIGHT_COMPACT,
		AlveolusVisualTheme.HEADER_CONTENT_GAP,
		AlveolusVisualTheme.HEADER_CONTENT_GAP_COMPACT,
		AlveolusVisualTheme.SECTION_GAP,
		AlveolusVisualTheme.CONTENT_GAP,
		AlveolusVisualTheme.CONTROL_GAP,
		AlveolusVisualTheme.TOUCH_TARGET_MINIMUM,
	]:
		_check(token % AlveolusVisualTheme.GRID_UNIT == 0, "Rastertoken %d folgt dem 4-px-Raster" % token)
	_check(AlveolusVisualTheme.HEADER_HEIGHT == 76 and AlveolusVisualTheme.HEADER_HEIGHT_COMPACT == 60, "Headerhöhen folgen dem Dossiervertrag")
	_check(AlveolusVisualTheme.HEADER_CONTENT_GAP == 20 and AlveolusVisualTheme.HEADER_CONTENT_GAP_COMPACT == 12, "Header und Inhalt besitzen einen expliziten Abstand")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_PRIMARY_BUTTON) == &"Button", "Primäraktion ist eine semantische Theme-Variante")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_PANEL_MODAL) == &"PanelContainer", "Modalfläche ist eine semantische Theme-Variante")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_TOGGLE_ROW) == &"CheckButton", "ToggleRow behält native Toggle-Semantik")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_OPTION_ROW) == &"OptionButton", "OptionRow behält native Auswahlsemantik")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_SLIDER_ROW) == &"HSlider", "SliderRow behält native Range-Semantik")
	_check(visual_theme.has_stylebox("focus", AlveolusVisualTheme.TYPE_SLIDER_ROW), "SliderRow besitzt einen sichtbaren Fokusvertrag")
	_check(visual_theme.has_stylebox("hover_pressed", AlveolusVisualTheme.TYPE_TOGGLE_ROW), "Ein aktiver Toggle besitzt einen eigenen Hover-Pressed-Zustand")
	var toggle_hover_pressed := visual_theme.get_stylebox("hover_pressed", AlveolusVisualTheme.TYPE_TOGGLE_ROW) as StyleBoxFlat
	_check(toggle_hover_pressed != null and toggle_hover_pressed.bg_color.a >= 0.90, "Aktive Switches bleiben beim Mouseover deckend sichtbar")
	_check(visual_theme.get_color("font_hover_pressed_color", AlveolusVisualTheme.TYPE_TOGGLE_ROW).a > 0.0, "Aktive Switches behalten beim Mouseover lesbaren Text")
	for surface_type in [
		AlveolusVisualTheme.TYPE_PAGE_CANVAS,
		AlveolusVisualTheme.TYPE_SECTION_GROUP,
		AlveolusVisualTheme.TYPE_ACTION_CARD,
		AlveolusVisualTheme.TYPE_DOCUMENT_INSET,
		AlveolusVisualTheme.TYPE_MODAL_SHEET,
		AlveolusVisualTheme.TYPE_HUD_VITAL,
		AlveolusVisualTheme.TYPE_HUD_OBJECTIVE,
		AlveolusVisualTheme.TYPE_HUD_ABILITY,
		AlveolusVisualTheme.TYPE_HUD_ALERT,
	]:
		_check(visual_theme.get_type_variation_base(surface_type) == &"PanelContainer", "%s ist eine semantische SurfaceRole" % surface_type)
	for variation in [
		AlveolusVisualTheme.TYPE_PRIMARY_BUTTON,
		AlveolusVisualTheme.TYPE_SECONDARY_BUTTON,
		AlveolusVisualTheme.TYPE_DANGER_BUTTON,
		AlveolusVisualTheme.TYPE_SELECTED_CARD,
	]:
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			_check(visual_theme.has_stylebox(state, variation), "%s besitzt Zustand %s" % [variation, state])
	for button_contract in [
		{
			"variation": AlveolusVisualTheme.TYPE_PRIMARY_BUTTON,
			"accent": AlveolusVisualTheme.TEAL,
			"primary": true,
			"danger": false,
			"vertical_inset": 16.0,
		},
		{
			"variation": AlveolusVisualTheme.TYPE_SECONDARY_BUTTON,
			"accent": AlveolusVisualTheme.COBALT,
			"primary": false,
			"danger": false,
			"vertical_inset": 14.0,
		},
		{
			"variation": AlveolusVisualTheme.TYPE_DANGER_BUTTON,
			"accent": AlveolusVisualTheme.CORAL,
			"primary": false,
			"danger": true,
			"vertical_inset": 14.0,
		},
	]:
		var variation: StringName = button_contract["variation"]
		var minimum_vertical_inset: float = button_contract["vertical_inset"]
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			var factory_style := AlveolusVisualTheme.button_style(
				button_contract["accent"],
				state,
				button_contract["primary"],
				button_contract["danger"]
			)
			_check(
				_has_minimum_content_insets(factory_style, 18.0, minimum_vertical_inset),
				"button_style %s/%s bewahrt mindestens 18 px horizontalen und %.0f px vertikalen Innenrand" % [variation, state, minimum_vertical_inset]
			)
			var registered_style := visual_theme.get_stylebox(state, variation)
			_check(
				_has_minimum_content_insets(registered_style, 18.0, minimum_vertical_inset),
				"Registrierter Button %s/%s übernimmt den verbindlichen Content-Inset" % [variation, state]
			)

	var normal := visual_theme.get_stylebox("normal", AlveolusVisualTheme.TYPE_SECONDARY_BUTTON) as StyleBoxFlat
	var hover := visual_theme.get_stylebox("hover", AlveolusVisualTheme.TYPE_SECONDARY_BUTTON) as StyleBoxFlat
	var focus := visual_theme.get_stylebox("focus", AlveolusVisualTheme.TYPE_SECONDARY_BUTTON) as StyleBoxFlat
	var disabled := visual_theme.get_stylebox("disabled", AlveolusVisualTheme.TYPE_SECONDARY_BUTTON) as StyleBoxFlat
	_check(normal.bg_color != hover.bg_color, "Hover verändert die Oberfläche sichtbar")
	_check(focus.border_width_left >= 3 and focus.border_color.is_equal_approx(AlveolusVisualTheme.FOCUS_RING), "Tastaturfokus besitzt eine breite kontrastreiche Kontur")
	_check(disabled.shadow_size == 0 and disabled.bg_color != normal.bg_color, "Gesperrter Zustand ist zusätzlich zur Farbe strukturell reduziert")
	_check(_contrast_ratio(AlveolusVisualTheme.PETROL, AlveolusVisualTheme.IVORY) >= 4.5, "Petrol auf Elfenbein erfüllt den Textkontrast")
	var primary := visual_theme.get_stylebox("normal", AlveolusVisualTheme.TYPE_PRIMARY_BUTTON) as StyleBoxFlat
	_check(primary.bg_color.a <= 0.12, "Der Primärbutton-Chassis bleibt transparent genug für den zentralen Bio-Lumen-Verlauf")
	_check(_contrast_ratio(AlveolusVisualTheme.MUTED, AlveolusVisualTheme.IVORY) >= 4.5, "Sekundärtext erfüllt den normalen Textkontrast")
	_check(_contrast_ratio(AlveolusVisualTheme.FOCUS_RING, AlveolusVisualTheme.PETROL_DEEP) >= 3.0, "Fokuskontur erreicht auf den dunklen Interaktionsflächen mindestens 3:1")
	var selected_tab_text := visual_theme.get_color("font_color", AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB)
	_check(selected_tab_text.is_equal_approx(AlveolusVisualTheme.IVORY), "Ausgewählte Tabs verwenden verbindlich Elfenbein statt dunkler Schrift auf Teal")
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		var selected_tab_style := visual_theme.get_stylebox(state, AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB) as StyleBoxFlat
		_check(_contrast_ratio(selected_tab_text, selected_tab_style.bg_color) >= 4.5, "Ausgewählter Tab hält in Zustand %s mindestens 4,5:1 Textkontrast" % state)
	var selected_tab_normal := visual_theme.get_stylebox("normal", AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB) as StyleBoxFlat
	var selected_tab_focus := visual_theme.get_stylebox("focus", AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB) as StyleBoxFlat
	_check(selected_tab_focus.bg_color.is_equal_approx(selected_tab_normal.bg_color), "Der Fokusring eines ausgewählten Tabs überdeckt dessen Auswahlfüllung nicht")
	var selected_card_focus := visual_theme.get_stylebox("focus", AlveolusVisualTheme.TYPE_SELECTED_CARD) as StyleBoxFlat
	_check(selected_card_focus.bg_color.a <= 0.12 and selected_card_focus.border_color.is_equal_approx(AlveolusVisualTheme.FOCUS_RING), "Der Kartenfokus bleibt ein transparenter Ring über dem sichtbaren Auswahlzustand")

	var page_canvas := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.PAGE_CANVAS)
	var section_group := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.SECTION_GROUP)
	var action_card := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.ACTION_CARD)
	var document_inset := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET)
	var modal_sheet := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.MODAL_SHEET)
	_check(page_canvas.bg_color.is_equal_approx(AlveolusVisualTheme.PETROL_DEEP) and _contrast_ratio(page_canvas.bg_color, AlveolusVisualTheme.IVORY) >= 7.0, "PageCanvas ist die dunkle Petrol-Dossierfläche")
	_check(section_group.bg_color.a <= 0.12 and section_group.shadow_size == 0, "SectionGroup bleibt zurückhaltend transparent und flach")
	_check(_all_corner_radii(section_group, 0), "Große SectionGroup besitzt standardmäßig keinen Cut")
	_check(action_card.bg_color.a < 1.0 and action_card.shadow_size <= 3, "ActionCard ist begrenzt transluzent und nur leicht erhöht")
	_check(document_inset.shadow_size == 0 and _all_corner_radii(document_inset, 4), "DocumentInset ist flach mit CONTROL_4")
	_check(modal_sheet.shadow_size > action_card.shadow_size and _signature_corners(modal_sheet), "ModalSheet nutzt die feste SIGNATURE_6-Behandlung")
	for treatment_data in [
		[AlveolusVisualTheme.CornerTreatment.NONE, 0],
		[AlveolusVisualTheme.CornerTreatment.CONTROL_4, 4],
		[AlveolusVisualTheme.CornerTreatment.CARD_6, 6],
	]:
		var corner_probe := StyleBoxFlat.new()
		AlveolusVisualTheme.apply_corner_treatment(corner_probe, treatment_data[0])
		_check(_all_corner_radii(corner_probe, treatment_data[1]), "CornerTreatment %s verwendet feste Designpixel" % treatment_data[0])

	var vertical_track := visual_theme.get_stylebox("scroll", &"VScrollBar") as StyleBoxFlat
	var horizontal_track := visual_theme.get_stylebox("scroll", &"HScrollBar") as StyleBoxFlat
	_check(vertical_track.get_minimum_size().x >= 12.0, "Vertikale Scrollanzeige ist mindestens 12 px breit")
	_check(horizontal_track.get_minimum_size().y >= 12.0, "Horizontale Scrollanzeige ist mindestens 12 px hoch")
	_check(visual_theme.get_constant("minimum_grab_length", &"VScrollBar") >= 36, "Scrollgrabber bleibt greifbar")

	var icon_button := AlveolusUIComponents.button("Zurück", AlveolusVisualTheme.TYPE_SECONDARY_BUTTON, &"back", AlveolusVisualTheme.COBALT) as IconTextButton
	icon_button.position = Vector2(40.0, 40.0)
	icon_button.size = Vector2(220.0, 48.0)
	gallery.add_child(icon_button)
	await _settle()
	_check(icon_button.content_center_error().length() <= 1.0, "Icon und Text werden als gemeinsame Einheit zentriert")
	_check(icon_button.caption.get_theme_font_size("font_size") >= 16, "Iconbutton nutzt lesbare Aktionsschrift")
	_check(icon_button.custom_minimum_size.y >= AlveolusVisualTheme.TOUCH_TARGET_MINIMUM, "Iconbutton erfüllt das Mindestziel")
	_check(icon_button.get_meta(&"ui_sound_cue", &"") == &"back", "Navigationsbutton trägt seinen semantischen Soundcue")
	icon_button.queue_free()

	var primary_action := AlveolusUIComponents.action_button("Behandlung starten", AlveolusUIComponents.ACTION_PRIMARY)
	var segmented := AlveolusUIComponents.segmented_tab("Befunde", true)
	var toggle := AlveolusUIComponents.toggle_row("Charakterwerte im Run", true)
	var option_parts := AlveolusUIComponents.option_row("UI-Größe", ["75 %", "90 %", "100 %", "200 %"], 2)
	var slider_parts := AlveolusUIComponents.slider_row("Menülautstärke", 0.0, 100.0, 65.0)
	var choice_row := AlveolusUIComponents.choice_row("Bakterium", "Pneumokokke")
	var choice_card := AlveolusUIComponents.choice_card("Fokusfeld", "Verstärkt den Zielbereich")
	_check(primary_action.custom_minimum_size.y >= 48.0 and primary_action.get_meta(&"alveolus_action_role") == AlveolusUIComponents.ACTION_PRIMARY, "ActionButton bündelt Rolle und Mindestziel")
	var bio_lumen_fill := primary_action.get_node_or_null("BioLumenFill") as BioLumenButtonFill
	var bio_lumen_count := 0
	for child in primary_action.get_children():
		if child is BioLumenButtonFill:
			bio_lumen_count += 1
	_check(bio_lumen_fill != null and bio_lumen_count == 1 and primary_action.get_child(0) == bio_lumen_fill, "Jede zentrale Primäraktion besitzt genau den BioLumenFill als unterste Füllebene")
	var bio_material: ShaderMaterial = bio_lumen_fill.material as ShaderMaterial if bio_lumen_fill != null else null
	var bio_top: Color = bio_material.get_shader_parameter("top_color") if bio_material != null else Color.TRANSPARENT
	var bio_bottom: Color = bio_material.get_shader_parameter("bottom_color") if bio_material != null else Color.TRANSPARENT
	_check(_hue_distance(bio_top.h, AlveolusVisualTheme.TEAL.h) <= 0.06 and _hue_distance(bio_bottom.h, AlveolusVisualTheme.TEAL.h) <= 0.06, "Der Bio-Lumen-Verlauf bleibt rollenrein im Teal-Spektrum")
	_check(_rgb_distance(bio_top, AlveolusVisualTheme.GOLD) > _rgb_distance(bio_top, AlveolusVisualTheme.TEAL) and _rgb_distance(bio_bottom, AlveolusVisualTheme.GOLD) > _rgb_distance(bio_bottom, AlveolusVisualTheme.TEAL), "Bio-Lumen verwendet Gold weder oben noch unten als Dekorationsfarbe")
	var bio_spread := _rgb_distance(bio_top, bio_bottom)
	_check(bio_spread >= 0.02 and bio_spread <= 0.18, "Der Bio-Lumen-Verlauf bleibt mit geringer, aber sichtbarer Spreizung zurückhaltend")
	_check(segmented.toggle_mode and segmented.button_pressed and segmented.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB, "SegmentedTab besitzt einen echten Auswahlzustand")
	_check(toggle.custom_minimum_size.y >= 44.0 and toggle.button_pressed, "ToggleRow ist konsistent groß und zustandsbehaftet")
	_check((option_parts["control"] as OptionButton).custom_minimum_size.y >= 44.0, "OptionRow erfüllt das Mindestziel")
	_check((slider_parts["control"] as HSlider).custom_minimum_size.y >= 44.0, "SliderRow erfüllt das Mindestziel")
	_check(choice_row.custom_minimum_size.y == 64.0 and choice_card.custom_minimum_size.y == 88.0, "ChoiceRow und ChoiceCard besitzen getrennte feste Dichten")
	primary_action.free()
	segmented.free()
	toggle.free()
	(option_parts["row"] as Control).free()
	(slider_parts["row"] as Control).free()
	choice_row.free()
	choice_card.free()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for viewport_size in [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1024, 576), Vector2i(960, 540)]:
		get_root().size = viewport_size
		gallery.size = Vector2(viewport_size)
		await _settle()
		_check(_inside_viewport(gallery.top_header, viewport_size), "Kopfbereich bleibt bei %s vollständig sichtbar" % viewport_size)
		_check(_inside_viewport(gallery.view_host, viewport_size), "Referenzfläche bleibt bei %s vollständig sichtbar" % viewport_size)
		var expected_gap := AlveolusVisualTheme.HEADER_CONTENT_GAP_COMPACT if viewport_size.x < 1040 or viewport_size.y < 620 else AlveolusVisualTheme.HEADER_CONTENT_GAP
		var actual_gap := gallery.view_host.get_global_rect().position.y - gallery.top_header.get_global_rect().end.y
		_check(is_equal_approx(actual_gap, float(expected_gap)), "Kopfbereich und Inhalt besitzen bei %s exakt %d px Abstand" % [viewport_size, expected_gap])
		for view_id in AlveolusStyleGallery.VIEW_ORDER:
			_check(gallery.select_view(view_id), "Referenz %s ist auswählbar" % view_id)
			await _settle()
			_check(gallery.visible_reference_name() == view_id, "Referenz %s wird eindeutig angezeigt" % view_id)
			_check(gallery.reference_root != null and gallery.reference_root.is_visible_in_tree(), "Referenz %s besitzt sichtbaren Inhalt" % view_id)
			await _capture("%s_%dx%d.png" % [view_id, viewport_size.x, viewport_size.y], viewport_size)

	gallery.queue_free()
	await process_frame
	_finish()

func _settle() -> void:
	for _frame in range(3):
		await process_frame

func _capture(filename: String, expected_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(not image.is_empty(), "Screenshot %s enthält ein Bild" % filename)
	_check(image.get_size() == expected_size, "Screenshot %s besitzt die erwartete Auflösung" % filename)
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, filename])
	_check(error == OK, "Screenshot %s lässt sich speichern" % filename)

func _inside_viewport(control: Control, viewport_size: Vector2i) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= -0.5 \
		and rect.position.y >= -0.5 \
		and rect.end.x <= float(viewport_size.x) + 0.5 \
		and rect.end.y <= float(viewport_size.y) + 0.5

func _all_corner_radii(style: StyleBoxFlat, expected: int) -> bool:
	return style.corner_radius_top_left == expected \
		and style.corner_radius_top_right == expected \
		and style.corner_radius_bottom_right == expected \
		and style.corner_radius_bottom_left == expected

func _signature_corners(style: StyleBoxFlat) -> bool:
	return style.corner_radius_top_left == 6 \
		and style.corner_radius_top_right == 0 \
		and style.corner_radius_bottom_right == 6 \
		and style.corner_radius_bottom_left == 0

func _has_minimum_content_insets(style: StyleBox, horizontal: float, vertical: float) -> bool:
	return style != null \
		and style.get_content_margin(SIDE_LEFT) >= horizontal \
		and style.get_content_margin(SIDE_RIGHT) >= horizontal \
		and style.get_content_margin(SIDE_TOP) >= vertical \
		and style.get_content_margin(SIDE_BOTTOM) >= vertical

func _contrast_ratio(first: Color, second: Color) -> float:
	var lighter := maxf(_relative_luminance(first), _relative_luminance(second))
	var darker := minf(_relative_luminance(first), _relative_luminance(second))
	return (lighter + 0.05) / (darker + 0.05)

func _relative_luminance(color: Color) -> float:
	var values: Array[float] = [color.r, color.g, color.b]
	var linear: Array[float] = []
	for value in values:
		linear.append(value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4))
	return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722

func _rgb_distance(first: Color, second: Color) -> float:
	return Vector3(first.r, first.g, first.b).distance_to(Vector3(second.r, second.g, second.b))

func _hue_distance(first: float, second: float) -> float:
	var direct := absf(first - second)
	return minf(direct, 1.0 - direct)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_STYLE_GALLERY_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
