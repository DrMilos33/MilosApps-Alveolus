class_name AlveolusStyleGallery
extends Control

## Standalone visual contract and regression surface for the ALVEOLUS UI.
## It intentionally contains no gameplay dependencies and can be opened directly
## in the Godot editor to compare components and reference layouts.

const VIEW_COMPONENTS := &"components"
const VIEW_PREPARATION := &"preparation"
const VIEW_LEXICON := &"lexicon"
const VIEW_PAUSE := &"pause"
const VIEW_ORDER: Array[StringName] = [VIEW_COMPONENTS, VIEW_PREPARATION, VIEW_LEXICON, VIEW_PAUSE]
const VIEW_LABELS := {
	VIEW_COMPONENTS: "Bausteine",
	VIEW_PREPARATION: "Einsatz",
	VIEW_LEXICON: "Lexikon",
	VIEW_PAUSE: "Pause",
}

var current_view: StringName = VIEW_COMPONENTS
var navigation_buttons: Dictionary = {}
var top_header: PanelContainer
var view_host: MarginContainer
var reference_root: Control
var safe_area: Control
var navigation_group: ButtonGroup
var header_content_margin: MarginContainer

func _ready() -> void:
	theme = AlveolusVisualTheme.create_theme()
	_build_shell()
	select_view(current_view)
	resized.connect(_apply_responsive_shell)
	_apply_responsive_shell()

func select_view(view_id: StringName) -> bool:
	if not VIEW_ORDER.has(view_id) or view_host == null:
		return false
	current_view = view_id
	if reference_root != null:
		view_host.remove_child(reference_root)
		reference_root.queue_free()
	match current_view:
		VIEW_COMPONENTS:
			reference_root = _build_components_view()
		VIEW_PREPARATION:
			reference_root = _build_preparation_view()
		VIEW_LEXICON:
			reference_root = _build_lexicon_view()
		VIEW_PAUSE:
			reference_root = _build_pause_view()
	view_host.add_child(reference_root)
	_update_navigation()
	return true

func visible_reference_name() -> StringName:
	return current_view

func grab_initial_focus() -> void:
	var button := navigation_buttons.get(current_view) as Button
	if button != null:
		button.grab_focus()

func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = AlveolusVisualTheme.PETROL_DEEP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	safe_area = Control.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.offset_left = AlveolusVisualTheme.SCREEN_MARGIN
	safe_area.offset_top = AlveolusVisualTheme.SCREEN_MARGIN
	safe_area.offset_right = -AlveolusVisualTheme.SCREEN_MARGIN
	safe_area.offset_bottom = -AlveolusVisualTheme.SCREEN_MARGIN
	add_child(safe_area)

	top_header = AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_SECTION_GROUP)
	top_header.name = "GalleryHeader"
	top_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_header.offset_bottom = AlveolusVisualTheme.HEADER_HEIGHT
	safe_area.add_child(top_header)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", AlveolusVisualTheme.SECTION_GAP)
	var title_group := VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_group.add_theme_constant_override("separation", 2)
	title_group.add_child(AlveolusUIComponents.label("ALVEOLUS UI · DOSSIER", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL))
	title_group.add_child(AlveolusUIComponents.label("Stilgalerie", AlveolusVisualTheme.TYPE_HUD_VALUE_LABEL))
	header_row.add_child(title_group)

	var navigation := HBoxContainer.new()
	navigation.name = "GalleryNavigation"
	navigation.alignment = BoxContainer.ALIGNMENT_END
	navigation.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	header_row.add_child(navigation)
	navigation_group = ButtonGroup.new()
	for view_id in VIEW_ORDER:
		var button := AlveolusUIComponents.segmented_tab(VIEW_LABELS[view_id], view_id == current_view, navigation_group)
		button.name = "View_%s" % view_id
		button.pressed.connect(select_view.bind(view_id))
		navigation.add_child(button)
		navigation_buttons[view_id] = button
	header_content_margin = AlveolusUIComponents.margin(header_row, 12)
	top_header.add_child(header_content_margin)

	view_host = MarginContainer.new()
	view_host.name = "ReferenceView"
	view_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_host.offset_top = AlveolusVisualTheme.HEADER_HEIGHT + AlveolusVisualTheme.HEADER_CONTENT_GAP
	safe_area.add_child(view_host)

func _update_navigation() -> void:
	for view_id in navigation_buttons:
		var button := navigation_buttons[view_id] as Button
		button.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB if view_id == current_view else AlveolusVisualTheme.TYPE_SEGMENTED_TAB
		button.set_pressed_no_signal(view_id == current_view)

func _apply_responsive_shell() -> void:
	if safe_area == null or top_header == null or view_host == null:
		return
	var compact := size.x < 1040.0 or size.y < 620.0
	var screen_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	var header_height := AlveolusVisualTheme.HEADER_HEIGHT_COMPACT if compact else AlveolusVisualTheme.HEADER_HEIGHT
	var content_gap := AlveolusVisualTheme.HEADER_CONTENT_GAP_COMPACT if compact else AlveolusVisualTheme.HEADER_CONTENT_GAP
	safe_area.offset_left = screen_margin
	safe_area.offset_top = screen_margin
	safe_area.offset_right = -screen_margin
	safe_area.offset_bottom = -screen_margin
	# Prefer the compact token, but never force the header below the real text and
	# control minimum. The content then starts after the resolved header plus the
	# contract gap, so a localization can grow without colliding with the body.
	var resolved_header_height := maxf(header_height, top_header.get_combined_minimum_size().y)
	top_header.offset_bottom = resolved_header_height
	view_host.offset_top = resolved_header_height + content_gap
	top_header.set_meta(&"alveolus_header_content_gap", content_gap)
	if header_content_margin != null:
		var header_padding := 8 if compact else 12
		for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			header_content_margin.add_theme_constant_override(side, header_padding)

func _build_components_view() -> Control:
	var scroll := _vertical_scroll("ComponentsReference")
	var page := _scroll_page(scroll)
	page.add_child(AlveolusUIComponents.section_header(
		"Zentrale Bausteine",
		"Ein System, alle Zustände",
		"Dieselben Komponenten werden in Campus, Planung, Lexikon und Run verwendet.",
		true
	))

	var palette := HBoxContainer.new()
	palette.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	for swatch in [
		["Elfenbein", AlveolusVisualTheme.IVORY],
		["Petrol", AlveolusVisualTheme.PETROL],
		["Türkis", AlveolusVisualTheme.TEAL],
		["Kobalt", AlveolusVisualTheme.COBALT],
		["Koralle", AlveolusVisualTheme.CORAL],
		["Honiggold", AlveolusVisualTheme.GOLD],
	]:
		palette.add_child(_color_swatch(swatch[0], swatch[1]))
	page.add_child(palette)
	page.add_child(AlveolusUIComponents.section_header("Flächenrollen", "Dossier statt Kachelwand", "Elevation folgt Bedeutung, nicht jedem Inhaltsblock.", true))
	var surfaces := HBoxContainer.new()
	surfaces.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	for surface_data in [
		[AlveolusVisualTheme.SurfaceRole.SECTION_GROUP, "Section group", AlveolusVisualTheme.TEAL],
		[AlveolusVisualTheme.SurfaceRole.ACTION_CARD, "Action card", AlveolusVisualTheme.COBALT],
		[AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET, "Document inset", AlveolusVisualTheme.GOLD],
		[AlveolusVisualTheme.SurfaceRole.HUD_VITAL, "HUD vital", AlveolusVisualTheme.TEAL],
	]:
		var surface_role: int = surface_data[0]
		var surface_title: String = surface_data[1]
		var surface_accent: Color = surface_data[2]
		surfaces.add_child(_surface_sample(surface_role, surface_title, surface_accent))
	page.add_child(surfaces)

	page.add_child(AlveolusUIComponents.section_header("Interaktion", "Buttons und Zustände", "Alle Ziele bleiben mindestens 44 Designpixel hoch.", true))
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	button_row.add_child(AlveolusUIComponents.button("Behandlung starten", AlveolusVisualTheme.TYPE_PRIMARY_BUTTON, &"play", AlveolusVisualTheme.TEAL))
	button_row.add_child(AlveolusUIComponents.action_button("Zurück", AlveolusUIComponents.ACTION_NAVIGATION, &"back", AlveolusVisualTheme.TEAL))
	var selected := AlveolusUIComponents.button("Ausgewählt", AlveolusVisualTheme.TYPE_SELECTED_CARD)
	selected.button_pressed = true
	button_row.add_child(selected)
	var disabled := AlveolusUIComponents.button("Noch gesperrt", AlveolusVisualTheme.TYPE_QUIET_BUTTON)
	disabled.disabled = true
	button_row.add_child(disabled)
	button_row.add_child(AlveolusUIComponents.button("Level abbrechen", AlveolusVisualTheme.TYPE_DANGER_BUTTON))
	page.add_child(button_row)
	var form_card := _reference_panel("Formularzeilen", "Toggle, Auswahl und Regler teilen Raster, Fokus und Mindestziel.")
	var form_content := form_card.get_meta("content") as VBoxContainer
	form_content.add_child(AlveolusUIComponents.toggle_row("Charakterwerte im Run", true))
	var option_parts := AlveolusUIComponents.option_row("UI-Größe", ["100 %", "150 %", "200 %"], 1)
	form_content.add_child(option_parts["row"])
	var slider_parts := AlveolusUIComponents.slider_row("Menülautstärke", 0.0, 100.0, 65.0)
	form_content.add_child(slider_parts["row"])
	page.add_child(form_card)

	var information_row := HBoxContainer.new()
	information_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	var tooltip_parts := AlveolusUIComponents.tooltip_card(
		"Fokusfeld",
		"Priorisiert und verstärkt die Behandlung im Zielgebiet.",
		"Aktiv · 2 K"
	)
	var tooltip_panel := tooltip_parts["panel"] as PanelContainer
	tooltip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information_row.add_child(tooltip_panel)
	var detail_parts := AlveolusUIComponents.detail_card(
		"Notfallhilfe",
		"Stellt Leben wieder her und erzeugt einen Schildpuffer.",
		"I · Information",
		AlveolusVisualTheme.COBALT
	)
	var detail_panel := detail_parts["panel"] as PanelContainer
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information_row.add_child(detail_panel)
	page.add_child(information_row)

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	var card_group := VBoxContainer.new()
	card_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_group.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	card_group.add_child(AlveolusUIComponents.section_header("Auswahl", "Karten", "", true))
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	var regular_card := AlveolusUIComponents.selection_card("Fokusfeld", "Verstärkt die Behandlung im Zielbereich.", "2 Kapazität")
	regular_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_row.add_child(regular_card)
	var selected_card := AlveolusUIComponents.selection_card("Notfallhilfe", "Stellt sofort Leben wieder her.", "Aktiv 2", true)
	selected_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_row.add_child(selected_card)
	card_group.add_child(card_row)
	content_row.add_child(card_group)

	var stat_group := VBoxContainer.new()
	stat_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_group.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	stat_group.add_child(AlveolusUIComponents.section_header("Lesbarkeit", "Werte und Fortschritt", "", true))
	stat_group.add_child(AlveolusUIComponents.stat_row("Schaden", "18 > 26", true))
	stat_group.add_child(AlveolusUIComponents.stat_row("Behandlungstempo", "0,82 s"))
	var progress := AlveolusUIComponents.progress(64.0)
	progress.custom_minimum_size.y = 14.0
	stat_group.add_child(progress)
	content_row.add_child(stat_group)
	page.add_child(content_row)
	return scroll

func _build_preparation_view() -> Control:
	var scroll := _vertical_scroll("PreparationReference")
	var page := _scroll_page(scroll)
	var summary := AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_SECTION_GROUP)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", AlveolusVisualTheme.SECTION_GAP)
	var summary_text := AlveolusUIComponents.section_header("Fall 02", "Die Ausbreitung", "4:00 Min.  ·  Herd nach 3:00 Min.", true)
	summary_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_child(summary_text)
	summary_row.add_child(AlveolusUIComponents.badge("Hohe Keimlast", AlveolusVisualTheme.CORAL))
	summary.add_child(AlveolusUIComponents.margin(summary_row))
	page.add_child(summary)

	var planning_row := HBoxContainer.new()
	planning_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	planning_row.add_theme_constant_override("separation", AlveolusVisualTheme.SECTION_GAP)
	var plan := _reference_panel("Dein Plan", "Feste Plätze verhindern zufälligen Austausch.")
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plan_content := plan.get_meta("content") as VBoxContainer
	var slots := GridContainer.new()
	slots.columns = 2
	slots.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	slots.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	for data in [
		["Grundbehandlung", "Präziser Impuls", true],
		["Aktiv 1", "Fokusfeld", true],
		["Aktiv 2", "Freier Platz", false],
		["Passiv 1", "Ruhige Hand", true],
		["Passiv 2", "Freier Platz", false],
	]:
		var slot := AlveolusUIComponents.selection_card(data[0], data[1], "Ausgerüstet" if data[2] else "Auswählen", data[2])
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(slot)
	plan_content.add_child(slots)
	plan_content.add_child(AlveolusUIComponents.stat_row("Kapazität", "5 / 8", true))
	planning_row.add_child(plan)

	var catalog := _reference_panel("Komponenten", "Wähle eine freie Position oder starte gezielt einen Austausch.")
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var catalog_content := catalog.get_meta("content") as VBoxContainer
	for data in [
		["Behandlungslinie", "Trifft alle Bakterien in einer Linie.", "Aktiv · 2"],
		["Schildfeld", "Verlangsamt Gegner im Bereich.", "Aktiv · 2"],
		["Schnelltest", "Proben füllen den Befund schneller.", "Passiv · 1"],
	]:
		catalog_content.add_child(AlveolusUIComponents.selection_card(data[0], data[1], data[2]))
	planning_row.add_child(catalog)
	page.add_child(planning_row)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	actions.add_child(AlveolusUIComponents.action_button("Zur Fallauswahl", AlveolusUIComponents.ACTION_NAVIGATION, &"back", AlveolusVisualTheme.TEAL))
	actions.add_child(AlveolusUIComponents.planning_start_button())
	page.add_child(actions)
	return scroll

func _build_lexicon_view() -> Control:
	var page := VBoxContainer.new()
	page.name = "LexiconReference"
	page.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	var category_group := ButtonGroup.new()
	for index in range(4):
		var names := ["Monster", "Charakter", "Spielelemente", "Begriffe"]
		categories.add_child(AlveolusUIComponents.segmented_tab(names[index], index == 0, category_group))
	page.add_child(categories)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", AlveolusVisualTheme.SECTION_GAP)
	var list_panel := _reference_panel("Monster", "Bereits beobachtete Erreger")
	list_panel.custom_minimum_size.x = 290.0
	var list_content := list_panel.get_meta("content") as VBoxContainer
	list_content.add_child(AlveolusUIComponents.selection_card("Bakterium", "Pneumokokke", "Entdeckt", true))
	list_content.add_child(AlveolusUIComponents.selection_card("Bakteriengruppe", "Lokale Belastung", "Entdeckt"))
	list_content.add_child(AlveolusUIComponents.selection_card("Noch nicht beobachtet", "Unbekannter Erreger", "Gesperrt", false, true))
	split.add_child(list_panel)

	var detail := _reference_panel("Bakterium", "Medizinisch: Pneumokokke")
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_content := detail.get_meta("content") as VBoxContainer
	var gameplay_text := AlveolusUIComponents.label(
		"Ein schneller Einzelerreger. Halte Abstand und lasse deine Behandlung automatisch arbeiten.",
		AlveolusVisualTheme.TYPE_BODY_LABEL
	)
	gameplay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(gameplay_text)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	stats.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	for data in [["Leben", "18"], ["Tempo", "72"], ["Schaden", "5"], ["Proben", "1"]]:
		var row := AlveolusUIComponents.stat_row(data[0], data[1])
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(row)
	detail_content.add_child(stats)
	detail_content.add_child(AlveolusUIComponents.section_header(
		"Medizinischer Hintergrund",
		"Warum dieser Erreger hier erscheint",
		"Pneumokokken sind Bakterien, die unter anderem eine Lungenentzündung auslösen können."
	))
	split.add_child(detail)
	page.add_child(split)
	return page

func _build_pause_view() -> Control:
	var backdrop := AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_HUD_OBJECTIVE)
	backdrop.name = "PauseReference"
	var center := CenterContainer.new()
	backdrop.add_child(center)
	var modal := AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_MODAL_SHEET)
	modal.custom_minimum_size = Vector2(390.0, 0.0)
	center.add_child(modal)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	var title := AlveolusUIComponents.label("☕  Pause", AlveolusVisualTheme.TYPE_TITLE_LABEL)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := AlveolusUIComponents.label("Doctor Milos", AlveolusVisualTheme.TYPE_MUTED_LABEL)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	content.add_child(AlveolusUIComponents.button("Weiter", AlveolusVisualTheme.TYPE_PRIMARY_BUTTON, &"play", AlveolusVisualTheme.TEAL))
	content.add_child(AlveolusUIComponents.button("Charakterwerte", AlveolusVisualTheme.TYPE_SECONDARY_BUTTON))
	content.add_child(AlveolusUIComponents.button("Einstellungen", AlveolusVisualTheme.TYPE_SECONDARY_BUTTON, &"settings", AlveolusVisualTheme.COBALT))
	content.add_child(AlveolusUIComponents.button("Level abbrechen", AlveolusVisualTheme.TYPE_DANGER_BUTTON))
	modal.add_child(AlveolusUIComponents.margin(content, 22))
	return backdrop

func _reference_panel(title: String, description: String = "") -> PanelContainer:
	var result := AlveolusUIComponents.panel(AlveolusVisualTheme.TYPE_ACTION_CARD)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	content.add_child(AlveolusUIComponents.section_header("", title, description))
	result.add_child(AlveolusUIComponents.margin(content))
	result.set_meta("content", content)
	return result

func _vertical_scroll(node_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return scroll

func _scroll_page(scroll: ScrollContainer) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", AlveolusVisualTheme.SECTION_GAP)
	scroll.add_child(page)
	return page

func _surface_sample(role: int, title_text: String, accent: Color) -> PanelContainer:
	var sample := AlveolusUIComponents.surface(role, accent)
	sample.custom_minimum_size.y = 72.0
	sample.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on_dark := role in [
		AlveolusVisualTheme.SurfaceRole.SECTION_GROUP,
		AlveolusVisualTheme.SurfaceRole.HUD_VITAL,
		AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE,
		AlveolusVisualTheme.SurfaceRole.HUD_ABILITY,
		AlveolusVisualTheme.SurfaceRole.HUD_ALERT,
	]
	var caption := AlveolusUIComponents.label(
		title_text,
		AlveolusVisualTheme.TYPE_HUD_LABEL if on_dark else AlveolusVisualTheme.TYPE_VALUE_LABEL
	)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sample.add_child(AlveolusUIComponents.margin(caption, 8))
	return sample

func _color_swatch(label_text: String, color: Color) -> PanelContainer:
	var swatch := PanelContainer.new()
	swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swatch.custom_minimum_size.y = 66.0
	var style := AlveolusVisualTheme.surface_style(color, color.lightened(0.18), &"flat")
	style.bg_color = color
	style.border_color = Color(AlveolusVisualTheme.PETROL, 0.16)
	swatch.add_theme_stylebox_override("panel", style)
	var luminance := color.get_luminance()
	var caption := AlveolusUIComponents.label(label_text, AlveolusVisualTheme.TYPE_VALUE_LABEL)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", AlveolusVisualTheme.IVORY if luminance < 0.42 else AlveolusVisualTheme.PETROL)
	swatch.add_child(AlveolusUIComponents.margin(caption, 8))
	return swatch
