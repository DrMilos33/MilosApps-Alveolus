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
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_NAVIGATION_BUTTON) == &"Button", "Navigation besitzt eine eigene semantische Theme-Variante")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_PANEL_MODAL) == &"PanelContainer", "Modalfläche ist eine semantische Theme-Variante")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_TOGGLE_ROW) == &"CheckButton", "ToggleRow behält native Toggle-Semantik")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_OPTION_ROW) == &"OptionButton", "OptionRow behält native Auswahlsemantik")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_SLIDER_ROW) == &"HSlider", "SliderRow behält native Range-Semantik")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_DAMAGE_TYPE_ROW) == &"PanelContainer", "DamageTypeRow besitzt eine zentrale semantische Theme-Variante")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_DAMAGE_TYPE_CHIP) == &"PanelContainer", "DamageTypeChip besitzt eine zentrale semantische Theme-Variante")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_COMPACT_RESEARCH) == &"Button", "CompactResearch besitzt eine zentrale semantische Theme-Variante")
	_check(visual_theme.get_type_variation_base(AlveolusVisualTheme.TYPE_TALENT_NODE) == &"Button", "TalentNode besitzt eine zentrale semantische Theme-Variante")
	var line_edit_style := visual_theme.get_stylebox("normal", &"LineEdit") as StyleBoxFlat
	_check(line_edit_style != null and _contrast_ratio(visual_theme.get_color("font_color", &"LineEdit"), line_edit_style.bg_color) >= 4.5, "Formfelder nutzen lesbare Bio-Lumen-Schrift auf dunkler Fläche")
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
		AlveolusVisualTheme.TYPE_PAGE_HEADER,
		AlveolusVisualTheme.TYPE_FORM_CONTROL,
		AlveolusVisualTheme.TYPE_VALUE_ROW,
		AlveolusVisualTheme.TYPE_TOOLTIP_CARD,
		AlveolusVisualTheme.TYPE_DETAIL_CARD,
	]:
		_check(visual_theme.get_type_variation_base(surface_type) == &"PanelContainer", "%s ist eine semantische SurfaceRole" % surface_type)
	for surface_role in [
		AlveolusVisualTheme.SurfaceRole.PAGE_CANVAS,
		AlveolusVisualTheme.SurfaceRole.SECTION_GROUP,
		AlveolusVisualTheme.SurfaceRole.ACTION_CARD,
		AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET,
		AlveolusVisualTheme.SurfaceRole.MODAL_SHEET,
		AlveolusVisualTheme.SurfaceRole.HUD_VITAL,
		AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE,
		AlveolusVisualTheme.SurfaceRole.HUD_ABILITY,
		AlveolusVisualTheme.SurfaceRole.HUD_ALERT,
		AlveolusVisualTheme.SurfaceRole.PAGE_HEADER,
		AlveolusVisualTheme.SurfaceRole.FORM_CONTROL,
		AlveolusVisualTheme.SurfaceRole.VALUE_ROW,
		AlveolusVisualTheme.SurfaceRole.TOOLTIP_CARD,
		AlveolusVisualTheme.SurfaceRole.DETAIL_CARD,
	]:
		var role_style := AlveolusVisualTheme.surface_role_style(surface_role)
		_check(not _is_accidental_black(role_style.bg_color), "SurfaceRole %s besitzt einen absichtlichen Petrol-Fallback statt Schwarz" % surface_role)
	for variation in [
		AlveolusVisualTheme.TYPE_PRIMARY_BUTTON,
		AlveolusVisualTheme.TYPE_SECONDARY_BUTTON,
		AlveolusVisualTheme.TYPE_DANGER_BUTTON,
		AlveolusVisualTheme.TYPE_QUIET_BUTTON,
		AlveolusVisualTheme.TYPE_NAVIGATION_BUTTON,
		AlveolusVisualTheme.TYPE_SELECTED_CARD,
		AlveolusVisualTheme.TYPE_COMPACT_RESEARCH,
		AlveolusVisualTheme.TYPE_SELECTED_COMPACT_RESEARCH,
		AlveolusVisualTheme.TYPE_TALENT_NODE,
		AlveolusVisualTheme.TYPE_SELECTED_TALENT_NODE,
		AlveolusVisualTheme.TYPE_CHOICE_ROW,
		AlveolusVisualTheme.TYPE_SELECTED_CHOICE_ROW,
	]:
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
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
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
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
			var expected_large_radius := 18 if bool(button_contract["primary"]) else (11 if bool(button_contract["danger"]) else 12)
			var expected_small_radius := 5 if bool(button_contract["primary"]) else 4
			_check(
				_asymmetric_corners(factory_style, expected_large_radius, expected_small_radius),
				"button_style %s/%s übernimmt die zentrale Bio-Lumen-Signatur" % [variation, state]
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
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
		var selected_tab_style := visual_theme.get_stylebox(state, AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB) as StyleBoxFlat
		_check(_contrast_ratio(selected_tab_text, selected_tab_style.bg_color) >= 4.5, "Ausgewählter Tab hält in Zustand %s mindestens 4,5:1 Textkontrast" % state)
	var selected_tab_normal := visual_theme.get_stylebox("normal", AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB) as StyleBoxFlat
	var selected_tab_focus := visual_theme.get_stylebox("focus", AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB) as StyleBoxFlat
	_check(selected_tab_focus.bg_color.is_equal_approx(selected_tab_normal.bg_color), "Der Fokusring eines ausgewählten Tabs überdeckt dessen Auswahlfüllung nicht")
	for compact_card_type in [
		AlveolusVisualTheme.TYPE_COMPACT_RESEARCH,
		AlveolusVisualTheme.TYPE_SELECTED_CARD,
		AlveolusVisualTheme.TYPE_SELECTED_COMPACT_RESEARCH,
		AlveolusVisualTheme.TYPE_TALENT_NODE,
		AlveolusVisualTheme.TYPE_SELECTED_TALENT_NODE,
	]:
		var compact_card_focus := visual_theme.get_stylebox("focus", compact_card_type) as StyleBoxFlat
		_check(compact_card_focus.bg_color.a <= 0.12 and compact_card_focus.border_color.is_equal_approx(AlveolusVisualTheme.FOCUS_RING) and compact_card_focus.border_width_left >= 3, "%s besitzt einen sichtbaren Fokusring ohne den Grundzustand zu überdecken" % compact_card_type)

	_check(AlveolusVisualTheme.DAMAGE_TYPE_ORDER == [&"fire", &"water", &"earth", &"wind"], "Schadenstypen besitzen die verbindliche Reihenfolge Feuer, Wasser, Erde, Wind")
	var expected_damage_accents := {
		&"fire": AlveolusVisualTheme.DAMAGE_FIRE_ACCENT,
		&"water": AlveolusVisualTheme.DAMAGE_WATER_ACCENT,
		&"earth": AlveolusVisualTheme.DAMAGE_EARTH_ACCENT,
		&"wind": AlveolusVisualTheme.DAMAGE_WIND_ACCENT,
	}
	_check(AlveolusVisualTheme.DAMAGE_FIRE_ACCENT.is_equal_approx(AlveolusVisualTheme.CORAL), "Feuer verwendet zentral Koralle/Orange")
	_check(AlveolusVisualTheme.DAMAGE_EARTH_ACCENT.is_equal_approx(AlveolusVisualTheme.GOLD), "Erde verwendet zentral Honiggold/Ocker")
	_check(AlveolusVisualTheme.DAMAGE_WIND_ACCENT.is_equal_approx(AlveolusVisualTheme.TURQUOISE), "Wind verwendet zentral Türkis/Mint")
	_check(AlveolusVisualTheme.DAMAGE_WATER_ACCENT.b > AlveolusVisualTheme.DAMAGE_WATER_ACCENT.r and AlveolusVisualTheme.DAMAGE_WATER_ACCENT.b > AlveolusVisualTheme.DAMAGE_WATER_ACCENT.g, "Wasser verwendet zentral Kobalt/Cyan")
	var damage_icon_kinds: Dictionary = {}
	for damage_type_id in AlveolusVisualTheme.DAMAGE_TYPE_ORDER:
		var icon_kind := AlveolusVisualTheme.damage_type_icon_kind(damage_type_id)
		damage_icon_kinds[icon_kind] = true
		_check(AlveolusVisualTheme.is_damage_type_role(damage_type_id), "%s besitzt eine zentrale Schadenstyp-Rolle" % damage_type_id)
		_check(AlveolusVisualTheme.damage_type_accent(damage_type_id).is_equal_approx(expected_damage_accents[damage_type_id]), "%s nutzt ausschließlich seinen zentralen Akzent" % damage_type_id)
		_check(not AlveolusVisualTheme.damage_type_display_name(damage_type_id).is_empty(), "%s besitzt einen ausgeschriebenen Namen" % damage_type_id)
		_check(SimpleIcon.supports(icon_kind), "%s besitzt ein registriertes SimpleIcon" % damage_type_id)
	_check(damage_icon_kinds.size() == AlveolusVisualTheme.DAMAGE_TYPE_ORDER.size(), "Alle vier Schadenstypen besitzen eindeutig verschiedene Glyphen")

	var page_canvas := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.PAGE_CANVAS)
	var section_group := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.SECTION_GROUP)
	var action_card := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.ACTION_CARD)
	var document_inset := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET)
	var modal_sheet := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.MODAL_SHEET)
	var page_header := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.PAGE_HEADER)
	var form_control := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.FORM_CONTROL, AlveolusVisualTheme.COBALT)
	var value_row_style := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.VALUE_ROW)
	var tooltip_style := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.TOOLTIP_CARD, AlveolusVisualTheme.TURQUOISE)
	var detail_style := AlveolusVisualTheme.surface_role_style(AlveolusVisualTheme.SurfaceRole.DETAIL_CARD, AlveolusVisualTheme.COBALT)
	_check(page_canvas.bg_color.is_equal_approx(AlveolusVisualTheme.PETROL_DEEP) and _contrast_ratio(page_canvas.bg_color, AlveolusVisualTheme.IVORY) >= 7.0, "PageCanvas ist die dunkle Petrol-Dossierfläche")
	_check(section_group.bg_color.a <= 0.12 and section_group.shadow_size == 0, "SectionGroup bleibt zurückhaltend transparent und flach")
	_check(_all_corner_radii(section_group, 0), "Große SectionGroup besitzt standardmäßig keinen Cut")
	_check(action_card.bg_color.a < 1.0 and action_card.shadow_size <= 3, "ActionCard ist begrenzt transluzent und nur leicht erhöht")
	_check(document_inset.shadow_size == 0 and _all_corner_radii(document_inset, 4), "DocumentInset ist flach mit CONTROL_4")
	_check(modal_sheet.shadow_size > action_card.shadow_size and _signature_corners(modal_sheet), "ModalSheet nutzt die feste SIGNATURE_6-Behandlung")
	_check(page_header.bg_color.a >= 0.90 and page_header.shadow_size <= 4, "PageHeader bleibt eine ruhige, klar abgegrenzte Bio-Lumen-Fläche")
	_check(form_control.shadow_size == 0 and _all_corner_radii(form_control, 4), "FormControl ist flach, dunkel und besitzt feste Insets")
	_check(value_row_style.shadow_size == 0 and value_row_style.bg_color.a < 0.80, "ValueRow ordnet Werte ohne unnötige Erhöhung")
	_check(tooltip_style.shadow_size > 0 and _all_corner_radii(tooltip_style, 4), "TooltipCard ist kompakt, kontrastreich und leicht abgehoben")
	_check(detail_style.shadow_size > 0 and _all_corner_radii(detail_style, 6), "DetailCard trennt explizite Information semantisch vom Hover-Tooltip")
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
	var second_primary := AlveolusUIComponents.action_button("Weiter", AlveolusUIComponents.ACTION_PRIMARY, &"", AlveolusVisualTheme.COBALT)
	var planning_start := AlveolusUIComponents.planning_start_button()
	var navigation_action := AlveolusUIComponents.action_button("Zurück", AlveolusUIComponents.ACTION_NAVIGATION, &"back")
	var segmented := AlveolusUIComponents.segmented_tab("Befunde", true)
	var toggle := AlveolusUIComponents.toggle_row("Charakterwerte im Run", true)
	var option_parts := AlveolusUIComponents.option_row("UI-Größe", ["75 %", "90 %", "100 %", "200 %"], 2)
	var slider_parts := AlveolusUIComponents.slider_row("Menülautstärke", 0.0, 100.0, 65.0)
	var choice_row := AlveolusUIComponents.choice_row("Bakterium", "Pneumokokke")
	var choice_card := AlveolusUIComponents.choice_card("Fokusfeld", "Verstärkt den Zielbereich")
	var compact_research := AlveolusUIComponents.compact_research(true)
	var talent_node := AlveolusUIComponents.talent_node(true)
	var damage_row_parts := AlveolusUIComponents.damage_type_row(&"water", "", "10 %", "Resistenz", "+")
	var damage_row := damage_row_parts["panel"] as PanelContainer
	var damage_chip_parts := AlveolusUIComponents.damage_type_chip(&"fire", "", "15 %", "Verwundbarkeit", "−")
	var damage_chip := damage_chip_parts["panel"] as PanelContainer
	_check(primary_action.custom_minimum_size.y >= 48.0 and primary_action.get_meta(&"alveolus_action_role") == AlveolusUIComponents.ACTION_PRIMARY, "ActionButton bündelt Rolle und Mindestziel")
	_check(primary_action.scale == Vector2.ONE and bool(primary_action.get_meta(&"disable_motion_scale", false)), "Hover und Fokus verändern niemals die Buttongeometrie")
	var bio_lumen_fill := primary_action.get_node_or_null("BioLumenFill") as BioLumenButtonFill
	var bio_lumen_count := 0
	for child in primary_action.get_children():
		if child is BioLumenButtonFill:
			bio_lumen_count += 1
	_check(bio_lumen_fill != null and bio_lumen_count == 1 and primary_action.get_child(0) == bio_lumen_fill, "Jede zentrale Primäraktion besitzt genau den BioLumenFill als unterste Füllebene")
	var bio_material: ShaderMaterial = bio_lumen_fill.material as ShaderMaterial if bio_lumen_fill != null else null
	var second_fill := second_primary.get_node_or_null("BioLumenFill") as BioLumenButtonFill
	var second_material: ShaderMaterial = second_fill.material as ShaderMaterial if second_fill != null else null
	_check(bio_lumen_fill != null and not bio_lumen_fill.is_processing(), "BioLumenFill benötigt keinen dauerhaften Process-Callback")
	_check(bio_material != null and second_material != null and bio_material != second_material and bio_material.shader == second_material.shader, "Primäraktionen teilen den Shader, behalten aber WebGL-portable Materialuniformen pro Control")
	var second_top: Color = second_material.get_shader_parameter(&"top_color") if second_material != null else Color.TRANSPARENT
	_check(_hue_distance(second_top.h, AlveolusVisualTheme.TEAL.h) <= 0.06, "Globale Primäraktionen bleiben auch bei abweichendem Aufrufer-Akzent Teal-zu-Teal")
	var bio_top: Color = bio_material.get_shader_parameter(&"top_color") if bio_material != null else Color.TRANSPARENT
	var bio_bottom: Color = bio_material.get_shader_parameter(&"bottom_color") if bio_material != null else Color.TRANSPARENT
	_check(_hue_distance(bio_top.h, AlveolusVisualTheme.TEAL.h) <= 0.06 and _hue_distance(bio_bottom.h, AlveolusVisualTheme.TEAL.h) <= 0.06, "Der Bio-Lumen-Verlauf bleibt rollenrein im Teal-Spektrum")
	_check(not _is_accidental_black(bio_top) and not _is_accidental_black(bio_bottom), "Globale Primärverläufe besitzen keinen schwarzen Web-Fallback")
	_check(_rgb_distance(bio_top, AlveolusVisualTheme.GOLD) > _rgb_distance(bio_top, AlveolusVisualTheme.TEAL) and _rgb_distance(bio_bottom, AlveolusVisualTheme.GOLD) > _rgb_distance(bio_bottom, AlveolusVisualTheme.TEAL), "Bio-Lumen verwendet Gold weder oben noch unten als Dekorationsfarbe")
	var bio_spread := _rgb_distance(bio_top, bio_bottom)
	_check(bio_spread >= 0.02 and bio_spread <= 0.18, "Der Bio-Lumen-Verlauf bleibt mit geringer, aber sichtbarer Spreizung zurückhaltend")
	var planning_fill := planning_start.get_node_or_null("PreparationBioLumenFill") as PreparationBioLumenFill
	_check(planning_fill != null and planning_start.get_node_or_null("BioLumenFill") == null, "Nur PlanningStart verwendet den expliziten Türkis-Warmgold-Verlauf")
	_check(planning_fill != null and not planning_fill.is_processing(), "PlanningStart aktualisiert Zustände ohne Process-Polling")
	var planning_material := planning_fill.material as ShaderMaterial if planning_fill != null else null
	var planning_left: Color = planning_material.get_shader_parameter(&"left_color") if planning_material != null else Color.TRANSPARENT
	var planning_right: Color = planning_material.get_shader_parameter(&"right_color") if planning_material != null else Color.TRANSPARENT
	_check(not _is_accidental_black(planning_left) and not _is_accidental_black(planning_right), "PlanningStart behält Türkis und Warmgold auch im Webmaterial")
	_check(navigation_action.theme_type_variation == AlveolusVisualTheme.TYPE_NAVIGATION_BUTTON and navigation_action.get_meta(&"ui_sound_cue") == &"back", "Navigation bündelt Variante und Zurück-Soundcue")
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var visual_state: StringName = &"hover" if state == &"hover_pressed" else state
		var navigation_factory := AlveolusVisualTheme.navigation_button_style(visual_state)
		var navigation_registered := visual_theme.get_stylebox(state, AlveolusVisualTheme.TYPE_NAVIGATION_BUTTON) as StyleBoxFlat
		_check(
			navigation_registered != null and _same_button_chassis(navigation_registered, navigation_factory),
			"NavigationButton verwendet in Zustand %s ausschließlich navigation_button_style" % state
		)
	var navigation_membranes: Array[PreparationBioLumenSurfaceFill] = []
	for child in navigation_action.get_children():
		if child is PreparationBioLumenSurfaceFill:
			navigation_membranes.append(child as PreparationBioLumenSurfaceFill)
	var navigation_fill := navigation_action.get_node_or_null("MembraneFill") as PreparationBioLumenSurfaceFill
	var navigation_material := navigation_fill.material as ShaderMaterial if navigation_fill != null else null
	var navigation_left: Color = navigation_material.get_shader_parameter(&"left_color") if navigation_material != null else Color.TRANSPARENT
	var navigation_right: Color = navigation_material.get_shader_parameter(&"right_color") if navigation_material != null else Color.TRANSPARENT
	_check(navigation_membranes.size() == 1 and navigation_fill == navigation_membranes[0], "Navigation besitzt genau einen zentralen MembraneFill")
	_check(
		navigation_left.is_equal_approx(PreparationBioLumenSurfaceFill.NORMAL_LEFT) \
			and navigation_right.is_equal_approx(PreparationBioLumenSurfaceFill.NORMAL_RIGHT),
		"Navigation übernimmt den freigegebenen Planning-Normalverlauf"
	)
	_check(navigation_action is IconTextButton and (navigation_action as IconTextButton).content_row.alignment == BoxContainer.ALIGNMENT_CENTER, "Navigation zentriert Icon und Text als gemeinsame Einheit")
	var navigation_minimum_before := navigation_action.custom_minimum_size
	var navigation_scale_before := navigation_action.scale
	navigation_action.mouse_entered.emit()
	navigation_action.focus_entered.emit()
	_check(
		navigation_action.custom_minimum_size.is_equal_approx(navigation_minimum_before) \
			and navigation_action.scale.is_equal_approx(navigation_scale_before) \
			and navigation_action.scale.is_equal_approx(Vector2.ONE),
		"Hover und Fokus verändern die Navigationsgeometrie nicht"
	)
	navigation_action.mouse_exited.emit()
	navigation_action.focus_exited.emit()
	AlveolusUIComponents.set_button_disabled(primary_action, true)
	var disabled_top: Color = bio_material.get_shader_parameter(&"top_color") if bio_material != null else Color.TRANSPARENT
	_check(primary_action.disabled and _hue_distance(disabled_top.h, AlveolusVisualTheme.MUTED.h) <= 0.08, "Programmatisches Disabled synchronisiert den Shader ereignisgesteuert")

	var header_parts := AlveolusUIComponents.page_header("Einstellungen", "Laborsteuerung", navigation_action)
	var shell_content := AlveolusUIComponents.label("Inhalt", AlveolusVisualTheme.TYPE_BODY_LABEL)
	var shell_parts := AlveolusUIComponents.page_shell(header_parts["panel"] as Control, shell_content)
	var shell := shell_parts["shell"] as PanelContainer
	_check(shell.get_meta(&"alveolus_component") == &"page_shell" and (header_parts["panel"] as PanelContainer).theme_type_variation == AlveolusVisualTheme.TYPE_PAGE_HEADER, "PageShell und PageHeader besitzen zentrale semantische Komponenten")
	var page_stack := shell_parts["stack"] as VBoxContainer
	var page_header_control := header_parts["panel"] as PanelContainer
	var page_body_safe_area := shell_parts["safe_area"] as MarginContainer
	_check(
		page_stack != null and page_header_control.get_parent() == page_stack \
			and page_stack.get_child(0) == page_header_control \
			and page_body_safe_area.get_parent() == page_stack \
			and page_stack.get_child(1) == page_body_safe_area \
			and page_header_control.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"PageHeader ist das direkte vollbreite Topband; erst danach folgt PageBodySafeArea"
	)
	var page_medallion := header_parts["medallion"] as PanelContainer
	var page_icon := header_parts["icon"] as SimpleIcon
	var page_title := header_parts["title"] as Label
	var page_heading := header_parts["heading"] as VBoxContainer
	_check(page_medallion != null and page_medallion.custom_minimum_size.is_equal_approx(Vector2(44.0, 44.0)), "PageHeader besitzt das feste 44-px-Medaillon")
	_check(page_icon != null and page_icon.kind == &"settings" and SimpleIcon.supports(page_icon.kind), "PageHeader verwendet ein semantisches SimpleIcon")
	_check(page_title != null and page_title.text == "Einstellungen" and page_title.theme_type_variation == AlveolusVisualTheme.TYPE_TITLE_LABEL, "PageHeader enthält genau den Seitentitel")
	_check(page_heading != null and page_heading.size_flags_vertical == Control.SIZE_SHRINK_CENTER and page_title.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "Jeder zentrale Seitentitel ist wie die Einsatzplanung vertikal im Kopfband zentriert")
	_check(shell.oversampling_with_scale == CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED, "PageShell aktiviert skalierungsabhängiges Font-Oversampling")
	var tooltip_parts := AlveolusUIComponents.tooltip_card("Fokusfeld", "Verstärkt die Behandlung.", "Aktiv · 2 K")
	var detail_parts := AlveolusUIComponents.detail_card("Fokusfeld", "Verstärkt die Behandlung.", "I · Information")
	_check((tooltip_parts["panel"] as PanelContainer).theme_type_variation == AlveolusVisualTheme.TYPE_TOOLTIP_CARD and float((tooltip_parts["panel"] as PanelContainer).get_meta(&"alveolus_maximum_width")) <= 288.0, "TooltipCard bleibt kompakt und semantisch typisiert")
	_check((detail_parts["panel"] as PanelContainer).theme_type_variation == AlveolusVisualTheme.TYPE_DETAIL_CARD, "Explizite Detailkarte ist vom Hover-Tooltip getrennt")
	var modal_actions: Array[Control] = [AlveolusUIComponents.action_button("Weiter", AlveolusUIComponents.ACTION_PRIMARY)]
	var modal_parts := AlveolusUIComponents.modal_sheet("☕  Pause", AlveolusUIComponents.label("Doctor Milos"), modal_actions)
	_check((modal_parts["panel"] as PanelContainer).theme_type_variation == AlveolusVisualTheme.TYPE_MODAL_SHEET and (modal_parts["actions"] as HBoxContainer).get_child_count() == 1, "ModalSheet bündelt Inhalt und Aktionen ohne Leerraumreserve")
	var semantic_fills: Array[BioLumenSurfaceFill] = [
		(header_parts["panel"] as PanelContainer).get_node_or_null("BioLumenSurface") as BioLumenSurfaceFill,
		(tooltip_parts["panel"] as PanelContainer).get_node_or_null("BioLumenSurface") as BioLumenSurfaceFill,
		(detail_parts["panel"] as PanelContainer).get_node_or_null("BioLumenSurface") as BioLumenSurfaceFill,
		(modal_parts["panel"] as PanelContainer).get_node_or_null("BioLumenSurface") as BioLumenSurfaceFill,
	]
	var shared_surface_shader: Shader = null
	var surface_materials: Array[ShaderMaterial] = []
	for semantic_fill in semantic_fills:
		_check(semantic_fill != null and not semantic_fill.is_processing(), "Jede zentrale Bio-Lumen-Fläche ist prozessfrei")
		if semantic_fill == null:
			continue
		var surface_material := semantic_fill.material as ShaderMaterial
		_check(surface_material != null, "Semantische Fläche besitzt ein ShaderMaterial")
		if surface_material == null:
			continue
		if shared_surface_shader == null:
			shared_surface_shader = surface_material.shader
		_check(surface_material.shader == shared_surface_shader, "Semantische Flächen teilen den gecachten Surface-Shader")
		_check(not surface_materials.has(surface_material), "Jede semantische Fläche besitzt WebGL-portable eigene Uniformwerte")
		surface_materials.append(surface_material)
		var live_left: Color = surface_material.get_shader_parameter(&"left_color")
		var live_right: Color = surface_material.get_shader_parameter(&"right_color")
		_check(not _is_accidental_black(live_left) and not _is_accidental_black(live_right), "Semantische Fläche rendert mit Petrolpalette statt Schwarz")
	_check(not BioLumenMaterialCache.SURFACE_SHADER_CODE.contains("instance uniform"), "Surface-Shader vermeidet den unzuverlässigen WebGL-Instanzuniformpfad")
	_check(not BioLumenButtonFill.SHADER_CODE.contains("instance uniform"), "Primary-Shader vermeidet den unzuverlässigen WebGL-Instanzuniformpfad")
	_check(not PreparationBioLumenFill.SHADER_CODE.contains("instance uniform"), "Planning-CTA vermeidet den unzuverlässigen WebGL-Instanzuniformpfad")
	var value_row := AlveolusUIComponents.value_row("Wirkung", "18")
	_check(value_row.theme_type_variation == AlveolusVisualTheme.TYPE_VALUE_ROW, "ValueRow besitzt eine zentrale semantische Dichte")
	_check(segmented.toggle_mode and segmented.button_pressed and segmented.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB, "SegmentedTab besitzt einen echten Auswahlzustand")
	_check(toggle.custom_minimum_size.y >= 44.0 and toggle.button_pressed, "ToggleRow ist konsistent groß und zustandsbehaftet")
	_check((option_parts["control"] as OptionButton).custom_minimum_size.y >= 44.0, "OptionRow erfüllt das Mindestziel")
	_check((slider_parts["control"] as HSlider).custom_minimum_size.y >= 44.0, "SliderRow erfüllt das Mindestziel")
	_check(choice_row.custom_minimum_size.y == 64.0 and choice_card.custom_minimum_size.y == float(AlveolusVisualTheme.SELECTION_CARD_HEIGHT), "ChoiceRow und ChoiceCard besitzen getrennte feste Dichten")
	_check(choice_row.theme_type_variation == AlveolusVisualTheme.TYPE_CHOICE_ROW, "ChoiceRow nutzt die kompakte zentrale Kartenrolle")
	_check(choice_card.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTION_CARD, "ChoiceCard behält die ausführliche zentrale Kartenrolle")
	_check(compact_research.custom_minimum_size.y == AlveolusVisualTheme.COMPACT_RESEARCH_HEIGHT and compact_research.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_COMPACT_RESEARCH, "CompactResearch bündelt 68-px-Dichte und Selected-Zustand")
	_check(talent_node.custom_minimum_size == Vector2.ONE * AlveolusVisualTheme.TALENT_NODE_SIZE and talent_node.theme_type_variation == AlveolusVisualTheme.TYPE_SELECTED_TALENT_NODE, "TalentNode bündelt quadratische Dichte und Selected-Zustand")
	var selection_card_theme_minimum := visual_theme.get_stylebox("normal", AlveolusVisualTheme.TYPE_SELECTION_CARD).get_minimum_size().y
	var compact_research_theme_minimum := visual_theme.get_stylebox("normal", AlveolusVisualTheme.TYPE_COMPACT_RESEARCH).get_minimum_size().y
	var talent_node_theme_minimum := visual_theme.get_stylebox("normal", AlveolusVisualTheme.TYPE_TALENT_NODE).get_minimum_size().y
	_check(compact_research_theme_minimum < selection_card_theme_minimum and talent_node_theme_minimum < selection_card_theme_minimum, "Kompakte Progressionsrollen erben nicht die 88-px-Innenränder der SelectionCard")
	_check(compact_research.get_meta(&"alveolus_component", &"") == &"compact_research" and talent_node.get_meta(&"alveolus_component", &"") == &"talent_node", "Kompakte Progressionscontrols tragen ihre zentralen Komponentenrollen")
	_check(not compact_research.has_theme_stylebox_override("normal") and not talent_node.has_theme_stylebox_override("normal"), "Kompakte Progressionsrollen erzeugen keine lokalen StyleBox-Kopien")
	_check(damage_row.theme_type_variation == AlveolusVisualTheme.TYPE_DAMAGE_TYPE_ROW and damage_row.get_meta(&"damage_type_id") == &"water", "DamageTypeRow transportiert seine semantische Rolle")
	_check((damage_row_parts["icon"] as SimpleIcon).kind == &"damage_water" and (damage_row_parts["name"] as Label).text == "Wasser" and (damage_row_parts["value"] as Label).text == "10 %", "DamageTypeRow enthält Icon, ausgeschriebenen Namen und fertig formatierten Wert")
	_check((damage_row_parts["indicator"] as Label).text == "+" and (damage_row_parts["meaning"] as Label).text == "Resistenz", "DamageTypeRow unterstützt Vorzeichen und Bedeutungslabel")
	_check(damage_chip.theme_type_variation == AlveolusVisualTheme.TYPE_DAMAGE_TYPE_CHIP and String(damage_chip.get_meta(&"alveolus_accessible_name", "")).contains("Feuer"), "DamageTypeChip bleibt strukturiert und zugänglich benannt")
	_check(not damage_row.has_theme_stylebox_override("panel") and damage_row.material == null and damage_row.get_node_or_null("BioLumenSurface") == null, "DamageTypeRow erzeugt keine lokale StyleBox- oder Shaderkopie")
	_check(not damage_chip.has_theme_stylebox_override("panel") and damage_chip.material == null and damage_chip.get_node_or_null("BioLumenSurface") == null, "DamageTypeChip erzeugt keine lokale StyleBox- oder Shaderkopie")
	var gallery_damage_ids: Array[StringName] = []
	for candidate in gallery.find_children("DamageTypeChip_*", "PanelContainer", true, false):
		gallery_damage_ids.append((candidate as PanelContainer).get_meta(&"damage_type_id", &""))
	_check(gallery_damage_ids == AlveolusVisualTheme.DAMAGE_TYPE_ORDER, "Die Stilgalerie zeigt alle vier Schadenstypen in verbindlicher Reihenfolge")
	primary_action.free()
	second_primary.free()
	planning_start.free()
	shell.free()
	(tooltip_parts["panel"] as PanelContainer).free()
	(detail_parts["panel"] as PanelContainer).free()
	(modal_parts["panel"] as PanelContainer).free()
	value_row.free()
	segmented.free()
	toggle.free()
	(option_parts["row"] as Control).free()
	(slider_parts["row"] as Control).free()
	choice_row.free()
	choice_card.free()
	damage_row.free()
	damage_chip.free()

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

func _asymmetric_corners(style: StyleBoxFlat, large_radius: int, small_radius: int) -> bool:
	return style.corner_radius_top_left == large_radius \
		and style.corner_radius_top_right == small_radius \
		and style.corner_radius_bottom_right == large_radius \
		and style.corner_radius_bottom_left == small_radius

func _same_button_chassis(first: StyleBoxFlat, second: StyleBoxFlat) -> bool:
	if first == null or second == null:
		return false
	return first.bg_color.is_equal_approx(second.bg_color) \
		and first.border_color.is_equal_approx(second.border_color) \
		and first.border_width_left == second.border_width_left \
		and first.border_width_top == second.border_width_top \
		and first.border_width_right == second.border_width_right \
		and first.border_width_bottom == second.border_width_bottom \
		and first.corner_radius_top_left == second.corner_radius_top_left \
		and first.corner_radius_top_right == second.corner_radius_top_right \
		and first.corner_radius_bottom_right == second.corner_radius_bottom_right \
		and first.corner_radius_bottom_left == second.corner_radius_bottom_left \
		and is_equal_approx(first.content_margin_left, second.content_margin_left) \
		and is_equal_approx(first.content_margin_top, second.content_margin_top) \
		and is_equal_approx(first.content_margin_right, second.content_margin_right) \
		and is_equal_approx(first.content_margin_bottom, second.content_margin_bottom)

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

func _is_accidental_black(color: Color) -> bool:
	return color.a > 0.25 and maxf(color.r, maxf(color.g, color.b)) <= 0.015

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
