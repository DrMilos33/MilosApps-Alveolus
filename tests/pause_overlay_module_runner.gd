extends SceneTree

const PAUSE_OVERLAY_PATH := "res://scripts/ui/screens/pause_overlay.gd"
const PAUSE_VIEW_MODEL_PATH := "res://scripts/ui/view_models/pause_overlay_view_model.gd"
const PauseOverlayScript := preload(PAUSE_OVERLAY_PATH)
const PauseOverlayViewModelScript := preload(PAUSE_VIEW_MODEL_PATH)

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_boundaries()
	var view_model := _test_immutable_section_view_model()
	await _test_pause_and_stats_modes(view_model)
	_finish()


func _test_source_boundaries() -> void:
	var source := _read_source(PAUSE_OVERLAY_PATH) + "\n" + _read_source(PAUSE_VIEW_MODEL_PATH)
	for forbidden in [
		"MetaProgressionState",
		"PlayerStats",
		"RunState",
		"RunSession",
		"ContentCatalog",
		"ConfigFile",
		"FileAccess",
		"save_game",
	]:
		_check(not source.contains(forbidden), "Pause-Modul besitzt keine verbotene Abhängigkeit %s" % forbidden)
	_check(source.contains("stat_sections") and source.contains("section_by_id"), "Pause übernimmt stabile getter-only Sektions-DTOs")
	_check(source.contains("AlveolusUIComponents.modal_sheet"), "Pause verwendet die zentrale ModalSheet-Konstruktion")
	_check(source.contains("AlveolusUIComponents.action_button"), "Pause verwendet zentrale Action- und Accordion-Köpfe")
	_check(source.contains("AlveolusUIComponents.value_row"), "Charakterwerte verwenden zentrale ValueRows")
	_check(source.contains("SimpleIcon.new"), "Charakterwerte besitzen semantische HUD-Icons")
	_check(not source.contains("add_theme_stylebox_override"), "Pause erzeugt keine lokale StyleBox-Kopie")
	_check(not source.contains("Shader.new") and not source.contains("ShaderMaterial.new"), "Pause erzeugt keine lokalen Shaderressourcen")
	_check(not source.contains("func _process") and not source.contains("func _physics_process"), "Pause besitzt keine dauerhafte Prozessschleife")
	_check(not source.to_lower().contains("runmenü"), "Pause enthält keine überflüssige Runmenü-Überschrift")
	_check(not source.contains("Behandlung pausiert"), "Pause verwendet keinen alten langen Behandlungstitel")
	_check(not source.contains("CoffeeSymbol") and not source.contains("☕"), "Pause besitzt kein dekoratives Symbol links vom Titel")


func _test_immutable_section_view_model() -> PauseOverlayViewModel:
	var source_sections := _stat_sections()
	var view_model: PauseOverlayViewModel = PauseOverlayViewModelScript.create(source_sections, 12)
	_check(view_model.revision() == 12, "View-Model übernimmt die Presenter-Revision")
	_check(view_model.section_count() == 4 and view_model.stat_count() == 20, "View-Model übernimmt vier belegte Sektionen und zwanzig Werte")
	_check(view_model.content_hash().length() == 64, "View-Model besitzt einen stabilen SHA-256-Inhaltshash")
	_check(view_model.section_at(0).id() == &"general" and view_model.section_at(0).title() == "Grundwerte", "Allgemeine DTO-Werte werden zur stabilen Grundwertesektion")
	_check(view_model.section_at(1).id() == &"treatment:treatment_precision" and view_model.section_at(1).display_title() == "Behandlung  ·  Impuls", "Behandlung behält ihre stabile ID und sichtbare Identität")
	_check(view_model.section_at(2).title() == "Aktiv 1" and view_model.section_at(3).title() == "Aktiv 2", "Aktivsektionen werden ausschließlich aus ihren stabilen Slot-IDs benannt")
	_check(view_model.section_at(-1) == null and view_model.section_at(4) == null, "Ungültige Sektionsindizes werden sicher abgewiesen")
	_check(view_model.section_by_id(&"ability:1:ability_treatment_line").detail_title() == "Behandlungslinie", "Sektionslookup verwendet die vollständige stabile Produktions-ID")
	_check(view_model.section_by_id(&"ability:0:ability_focus_field").icon_id() == &"ability_focus_field", "Bereits präfixierte Ability-ID wird ohne Doppelpräfix als Produktionsglyphe transportiert")
	_check(view_model.stat_at(0).label() == "Leben" and view_model.stat_at(0).icon_id() == &"stability_reserve", "Kind-View-Model enthält nur darstellungsfertige Werte")
	_check(view_model.stat_at(2).icon_id() == &"movement_training", "Bewegung verwendet die zentrale Training-Glyphe")
	_check(view_model.stat_at(6).icon_id() == &"damage_fire" and view_model.stat_at(6).accent_role() == &"coral", "Typresistenzen verwenden semantische Icon- und Farbrollen")

	(source_sections[0] as Dictionary)["title"] = "Fremde Mutation"
	var source_rows := (source_sections[0] as Dictionary)["rows"] as Array
	(source_rows[0] as Dictionary)["label"] = "Fremde Mutation"
	var returned_sections := view_model.sections()
	returned_sections.clear()
	var returned_rows := view_model.section_by_id(&"general").rows()
	returned_rows.clear()
	_check(view_model.section_count() == 4 and view_model.section_by_id(&"general").row_count() == 10, "Zurückgegebene Sektions- und Statarrays sind defensive Kopien")
	_check(view_model.stat_at(0).label() == "Leben", "Spätere Quellmutationen erreichen das View-Model nicht")

	var equivalent: PauseOverlayViewModel = PauseOverlayViewModelScript.create(_stat_sections(), 13)
	_check(equivalent.content_hash() == view_model.content_hash(), "Revision ist nicht Teil des semantischen Sektions-Hashs")
	var changed: PauseOverlayViewModel = PauseOverlayViewModelScript.create(_stat_sections("79 / 90"), 13)
	_check(changed.content_hash() != view_model.content_hash(), "Ein sichtbarer Statwert verändert den Inhaltshash")
	var one_empty_slot: PauseOverlayViewModel = PauseOverlayViewModelScript.create(_stat_sections("80 / 90", false), 14)
	_check(one_empty_slot.section_count() == 3 and one_empty_slot.section_by_id(&"ability:1:ability_treatment_line") == null, "Ein leerer Aktivslot erzeugt keine leere Sektion")

	var legacy := PauseOverlayViewModelScript.create([
		{"id": &"life", "group": "ALLGEMEIN", "label": "Leben", "value": "80 / 90"},
		{"id": &"damage", "group": "BEHANDLUNG", "label": "Schaden", "value": "16"},
	], 1)
	_check(legacy.section_count() == 2 and legacy.section_at(0).id() == &"general", "Legacyzeilen bleiben während der GameHUD-Bridge sicher lesbar")
	return view_model


func _test_pause_and_stats_modes(view_model: PauseOverlayViewModel) -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var overlay := PauseOverlayScript.new() as PauseOverlay
	overlay.theme = AlveolusVisualTheme.create_theme()
	host.add_child(overlay)
	_check(overlay.apply_view_model(view_model, PauseOverlay.Mode.MENU), "Erstes Apply zeichnet das Pausenmenü")
	await _settle()

	_check(overlay.modal_sheet().theme_type_variation == AlveolusVisualTheme.TYPE_MODAL_SHEET, "Pause besitzt die zentrale ModalSheet-Rolle")
	_check(overlay.modal_sheet().get_meta(&"alveolus_component", &"") == &"modal_sheet", "Pause stammt aus der gemeinsamen ModalSheet-Komponente")
	_check(overlay.title_text() == "Pause", "Pausenmenü zeigt den knappen Titel Pause")
	var title_line := overlay.find_child("PauseTitleLine", true, false) as HBoxContainer
	var title_label := overlay.find_child("Title", true, false) as Label
	var doctor_balance := overlay.find_child("DoctorBalance", true, false) as Control
	var doctor_meta := overlay.find_child("DoctorMeta", true, false) as Label
	_check(overlay.find_child("CoffeeSymbol", true, false) == null, "Links neben Pause wird kein Symbol erzeugt")
	_check(doctor_meta != null and doctor_meta.text == "Doctor Milos" and doctor_meta.is_visible_in_tree(), "Pausenkopf nennt Doctor Milos knapp als Metaangabe")
	_check(doctor_balance != null and doctor_meta != null and is_equal_approx(doctor_balance.size.x, doctor_meta.size.x), "Unsichtbare Gegenbreite gleicht die rechte Doctor-Metaangabe aus")
	_check(title_label != null and title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Pause verwendet eine echte zentrierte Textausrichtung")
	_check(title_line != null and title_label != null and absf(title_label.get_global_rect().get_center().x - title_line.get_global_rect().get_center().x) <= 1.0, "Pausentitel liegt geometrisch in der horizontalen Modalmitte")
	_check(overlay.body_scroll().follow_focus and overlay.body_scroll().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Der Inhaltsviewport folgt Fokus ohne horizontalen Scroll")
	_check(overlay.menu_action_grid().columns == 3, "Breites Pausenmenü ordnet Nebenaktionen kompakt in einer Zeile an")
	_check(overlay.resume_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_PRIMARY, "Weiter ist die einzige Primäraktion")
	_check(overlay.abort_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_DANGER, "Runde abbrechen besitzt ausschließlich die Gefahrrolle")
	_check(_primary_action_count(overlay) == 1, "Das gesamte Overlay enthält genau eine Primäraktion")
	_check(not overlay.apply_view_model(view_model, PauseOverlay.Mode.MENU), "Identisches Apply ist idempotent")

	_check(overlay.set_mode(PauseOverlay.Mode.STATS, false), "Fassade kann die eingebetteten Charakterwerte öffnen")
	await _settle()
	_check(overlay.title_text() == "Charakterwerte", "Statmodus besitzt einen einfachen Titel")
	_check(doctor_balance != null and not doctor_balance.visible and doctor_meta != null and not doctor_meta.visible, "Charakterwerte übernehmen keinen Pausenmeta-Leerraum")
	_check(not overlay.resume_action().visible and overlay.back_action().visible, "Statmodus ersetzt Weiter durch einen festen Rückweg")
	_check(overlay.stats_grid().columns == 1, "Accordion-Sektionen stehen als eindeutige volle Zeilen untereinander")
	_check(overlay.stat_sections().size() == 4 and overlay.stats_grid().get_child_count() == 4, "Jede belegte DTO-Sektion besitzt genau einen stabilen Accordion-Container")
	_check(overlay.stat_rows().size() == view_model.stat_count(), "Jeder DTO-Wert besitzt genau eine wiederverwendbare ValueRow")
	_assert_section_contract(overlay, view_model)
	_assert_stat_rows(overlay)
	_check(overlay.is_section_expanded(&"general"), "Grundwerte sind semantisch standardmäßig geöffnet")
	_check(not overlay.is_section_expanded(&"treatment:treatment_precision") and not overlay.is_section_expanded(&"ability:0:ability_focus_field"), "Weitere Sektionen bleiben bis zur ausdrücklichen Auswahl kompakt")
	_assert_section_disclosure_state(overlay, &"general", true)
	_assert_section_disclosure_state(overlay, &"treatment:treatment_precision", false)
	_check(overlay.section_body(&"general").is_visible_in_tree(), "Geöffnete Grundwerte sind sichtbar")
	_check(not overlay.section_body(&"treatment:treatment_precision").visible, "Geschlossene Behandlung reserviert keinen Body-Leerraum")

	_check(overlay.grab_initial_focus(), "Statmodus kann seinen festen Rückfokus setzen")
	await process_frame
	_check(get_root().gui_get_focus_owner() == overlay.back_action(), "Statmodus markiert nicht automatisch eine Wertsektion")
	_check(_focus_target_inside(overlay.back_action(), overlay.back_action().focus_neighbor_right, overlay), "Rückweg und Accordion-Köpfe bilden einen geschlossenen Fokuspfad")
	var treatment_header := overlay.section_header(&"treatment:treatment_precision")
	treatment_header.grab_focus()
	_check(overlay.set_section_expanded(&"treatment:treatment_precision", true), "Behandlung lässt sich unabhängig ausklappen")
	_check(overlay.set_section_expanded(&"general", false), "Grundwerte lassen sich unabhängig einklappen")
	await _settle()
	_check(treatment_header.button_pressed and overlay.section_body(&"treatment:treatment_precision").is_visible_in_tree(), "Buttonzustand und sichtbarer Sektionsbody bleiben synchron")
	_check(not overlay.section_body(&"general").visible, "Eingeklappte Grundwerte lassen keinen versteckten Platz stehen")
	_assert_section_disclosure_state(overlay, &"treatment:treatment_precision", true)
	_assert_section_disclosure_state(overlay, &"general", false)

	# 480 × 270 models the logical area of the 960 × 540 / 200-percent case.
	_resize_logical_host(host, Vector2i(480, 270))
	overlay.set_section_expanded(&"general", true)
	overlay.set_section_expanded(&"ability:0:ability_focus_field", true)
	await _settle()
	_check(overlay.section_body(&"general").columns == 2, "Bei 200 Prozent nutzen Statwerte weiterhin zwei lesbare Spalten")
	_check(overlay.body_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Nur der tatsächlich geöffnete lange Inhalt aktiviert Scrollen")
	_check(overlay.body_scroll().get_v_scroll_bar().visible, "Der notwendige Scrollbereich ist sichtbar erkennbar")
	_check(overlay.back_action().is_visible_in_tree() and _inside(overlay.back_action(), overlay.modal_sheet()), "Zurück bleibt außerhalb des Accordion-Scrollbereichs sichtbar")

	# Stable IDs allow in-place refreshes without losing disclosure state, focus,
	# scroll position or row instances.
	treatment_header.grab_focus()
	overlay.body_scroll().scroll_vertical = 24
	await process_frame
	var preserved_scroll := overlay.body_scroll().scroll_vertical
	var treatment_header_instance := treatment_header.get_instance_id()
	var general_row_instance := overlay.section_body(&"general").get_child(0).get_instance_id()
	var refreshed: PauseOverlayViewModel = PauseOverlayViewModelScript.create(_stat_sections("79 / 90"), 13)
	_check(overlay.apply_view_model(refreshed, PauseOverlay.Mode.STATS), "Neuer DTO-Snapshot wird im Statmodus angewendet")
	await _settle()
	_check(overlay.section_header(&"treatment:treatment_precision").get_instance_id() == treatment_header_instance, "Stabile Sektions-ID aktualisiert den vorhandenen Accordion-Kopf in-place")
	_check(overlay.section_body(&"general").get_child(0).get_instance_id() == general_row_instance, "Stabile Stat-ID aktualisiert die vorhandene ValueRow in-place")
	_check(overlay.is_section_expanded(&"general") and overlay.is_section_expanded(&"treatment:treatment_precision") and overlay.is_section_expanded(&"ability:0:ability_focus_field"), "Aufklappzustand bleibt bei VM-Refresh vollständig erhalten")
	_check(get_root().gui_get_focus_owner() == overlay.section_header(&"treatment:treatment_precision"), "Fokus bleibt beim gleichen stabilen Accordion-Kopf")
	_check(overlay.body_scroll().scroll_vertical == preserved_scroll, "Scrollposition bleibt bei einem Werte-Refresh erhalten")
	var life_value := overlay.section_body(&"general").get_child(0).find_child("StatValue", true, false) as Label
	_check(life_value != null and life_value.text == "79 / 90", "Differenzieller Refresh aktualisiert den sichtbaren Wert")

	var one_empty_slot: PauseOverlayViewModel = PauseOverlayViewModelScript.create(_stat_sections("79 / 90", false), 14)
	_check(overlay.apply_view_model(one_empty_slot, PauseOverlay.Mode.STATS), "Snapshot mit leerem zweiten Aktivslot wird angewendet")
	await _settle()
	_check(overlay.stat_sections().size() == 3 and overlay.section_header(&"ability:1:ability_treatment_line") == null, "Leerer Aktivslot hinterlässt weder Sektion noch Blank-Space-Reserve")

	_check(overlay.set_mode(PauseOverlay.Mode.MENU, false), "Fassade kann zum Pausenmenü zurückkehren")
	await _settle()
	_check(overlay.menu_action_grid().columns == 2, "Kompaktes Pausenmenü ordnet Routineaktionen in zwei Spalten an")
	_check(overlay.abort_action().get_parent() != overlay.menu_action_grid(), "Kompaktes Pausenmenü trennt die Gefahraktion von den Routineaktionen")
	_check(overlay.resume_action().is_visible_in_tree() and _inside(overlay.resume_action(), overlay.modal_sheet()), "Weiter bleibt als feste Hauptaktion sichtbar")

	var intro_enabled: PauseOverlayViewModel = PauseOverlayViewModelScript.create(_stat_sections(), 15, true)
	_check(overlay.apply_view_model(intro_enabled, PauseOverlay.Mode.MENU), "Optionaler Intro-Skip-Snapshot wird angewendet")
	await _settle()
	_check(overlay.intro_skip_action().is_visible_in_tree(), "Optionaler Intro-Skip bleibt im kompakten Menü verfügbar")

	var empty: PauseOverlayViewModel = PauseOverlayViewModelScript.create([], 16)
	_check(overlay.apply_view_model(empty, PauseOverlay.Mode.MENU), "Leerer aktueller Snapshot wird angewendet")
	_check(overlay.stats_action().disabled and overlay.stat_sections().is_empty(), "Charakterwerte sind ohne Sektionen eindeutig deaktiviert")
	overlay.hide()
	_check(not overlay.handle_ui_cancel(), "Verdecktes Overlay konsumiert ui_cancel nicht")
	host.queue_free()
	await process_frame


func _assert_section_contract(overlay: PauseOverlay, view_model: PauseOverlayViewModel) -> void:
	for section in view_model.sections():
		var panel := overlay.stat_sections()[view_model.sections().find(section)]
		var header := overlay.section_header(section.id())
		var body := overlay.section_body(section.id())
		_check(panel.get_meta(&"alveolus_component", &"") == &"stat_accordion_section", "%s verwendet den zentralen Accordion-Container" % section.title())
		_check(panel.theme_type_variation == AlveolusVisualTheme.TYPE_PANEL_INSET, "%s verwendet die semantische Inset-Fläche" % section.title())
		_check(header != null and header.focus_mode == Control.FOCUS_ALL, "%s besitzt einen tastatur- und gamepadfähigen Kopf" % section.title())
		_check(header.get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_QUIET, "%s verwendet die zentrale Quiet-Buttonrolle" % section.title())
		_check(not String(header.get_meta(&"alveolus_accessible_name", "")).is_empty(), "%s besitzt einen eindeutigen Accessible Name" % section.title())
		var chevron := header.find_child("SectionChevron", true, false) as SimpleIcon
		_check(chevron != null and chevron.kind == &"back" and chevron.custom_minimum_size.x >= 20.0, "%s besitzt ein gut sichtbares zentrales Chevron" % section.title())
		_check(body != null and body.get_parent() == header.get_parent() and body.get_index() > header.get_index(), "%s ordnet den Inhalt direkt nach seinem Kopf an" % section.title())


func _assert_section_disclosure_state(overlay: PauseOverlay, section_id: StringName, expanded: bool) -> void:
	var header := overlay.section_header(section_id)
	var chevron := header.find_child("SectionChevron", true, false) as SimpleIcon if header != null else null
	var expected_state: StringName = &"expanded" if expanded else &"collapsed"
	var expected_word := "ausgeklappt" if expanded else "eingeklappt"
	_check(header != null and header.get_meta(&"accordion_state", &"") == expected_state, "%s transportiert den Ein-/Ausklappzustand am Kopf" % section_id)
	_check(chevron != null and chevron.get_meta(&"accordion_state", &"") == expected_state, "%s transportiert den Zustand redundant am Chevron" % section_id)
	_check(header != null and String(header.get_meta(&"alveolus_accessible_name", "")).contains(expected_word), "%s aktualisiert den Accessible Name mit dem aktuellen Zustand" % section_id)
	if chevron != null:
		var expected_rotation := -PI * 0.5 if expanded else PI
		_check(is_equal_approx(chevron.rotation, expected_rotation), "%s unterscheidet Ein-/Ausklappen sichtbar durch die Chevron-Richtung" % section_id)


func _assert_stat_rows(overlay: PauseOverlay) -> void:
	var has_measured_wide_value := false
	for index in range(overlay.stat_rows().size()):
		var row := overlay.stat_rows()[index]
		_check(row.theme_type_variation == AlveolusVisualTheme.TYPE_VALUE_ROW, "Statzeile %d verwendet die zentrale ValueRow-Rolle" % index)
		_check(row.get_meta(&"alveolus_component", &"") == &"value_row", "Statzeile %d stammt aus der zentralen ValueRow-Komponente" % index)
		var icon := row.find_child("StatIcon", true, false) as SimpleIcon
		var label := row.find_child("StatLabel", true, false) as Label
		var value := row.find_child("StatValue", true, false) as Label
		_check(icon != null and label != null and value != null, "Statzeile %d besitzt Icon, Bezeichnung und Wert" % index)
		if icon == null or label == null or value == null:
			continue
		_check(value.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Statwert %d ist rechtsbündig" % index)
		_check(value.custom_minimum_size.x >= 56.0 and value.custom_minimum_size.x <= 120.0, "Statwert %d bleibt in der 56–120-px-Spalte" % index)
		if value.custom_minimum_size.x > 56.0:
			has_measured_wide_value = true
		_check(not row.tooltip_text.is_empty(), "Statzeile %d behält den vollständigen Tooltip" % index)
		_check(icon.get_index() < label.get_index() and label.get_index() < value.get_index(), "Statzeile %d besitzt eine eindeutige Leserichtung" % index)
	_check(has_measured_wide_value, "Längere Statwerte erhalten textgemessen mehr als die Mindestbreite")


func _stat_sections(life_value: String = "80 / 90", include_second_ability: bool = true) -> Array:
	var sections: Array = [
		{
			"id": &"general",
			"title": "ALLGEMEIN",
			"rows": [
				{"id": &"life", "label": "Leben", "value": life_value},
				{"id": &"shield", "label": "Schild", "value": "12 / 20"},
				{"id": &"movement_speed", "label": "Bewegung", "value": "338"},
				{"id": &"defense", "label": "Verteidigung", "value": "18,4 %"},
				{"id": &"life_regeneration", "label": "Regeneration", "value": "4/s"},
				{"id": &"experience_gain", "label": "Erfahrung", "value": "+20 %"},
				{"id": &"resistance_fire", "label": "Resistenz Feuer", "value": "0 %"},
				{"id": &"resistance_water", "label": "Resistenz Wasser", "value": "9,8 %"},
				{"id": &"resistance_earth", "label": "Resistenz Erde", "value": "4,7 %"},
				{"id": &"resistance_wind", "label": "Resistenz Wind", "value": "−10 %"},
			],
		},
		{
			"id": &"treatment:treatment_precision",
			"title": "Impuls",
			"rows": [
				{"id": &"damage", "label": "Schaden", "value": "16"},
				{"id": &"interval", "label": "Intervall", "value": "0,82 s"},
				{"id": &"targets", "label": "Ziele", "value": "1"},
				{"id": &"range_stage", "label": "Reichweite", "value": "5"},
				{"id": &"projectiles", "label": "Projektile", "value": "1"},
			],
		},
		{
			"id": &"ability:0:ability_focus_field",
			"title": "Fokusfeld",
			"rows": [
				{"id": &"cooldown", "label": "Abklingzeit", "value": "8,0 s"},
				{"id": &"damage", "label": "Schaden", "value": "0"},
				{"id": &"radius_stage", "label": "Radius", "value": "3"},
			],
		},
	]
	if include_second_ability:
		sections.append({
			"id": &"ability:1:ability_treatment_line",
			"title": "Behandlungslinie",
			"rows": [
				{"id": &"cooldown", "label": "Abklingzeit", "value": "11,0 s"},
				{"id": &"range_stage", "label": "Reichweite", "value": "6"},
			],
		})
	return sections


func _primary_action_count(root: Node) -> int:
	var count := 0
	var overlay := root as PauseOverlay
	var buttons: Array[Button] = [
		overlay.resume_action(),
		overlay.settings_action(),
		overlay.stats_action(),
		overlay.abort_action(),
		overlay.back_action(),
	]
	for button in buttons:
		if button.get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_PRIMARY:
			count += 1
	return count


func _inside(control: Control, container: Control) -> bool:
	if control == null or container == null:
		return false
	var inner := control.get_global_rect()
	var outer := container.get_global_rect()
	return (
		inner.position.x >= outer.position.x - 0.5
		and inner.position.y >= outer.position.y - 0.5
		and inner.end.x <= outer.end.x + 0.5
		and inner.end.y <= outer.end.y + 0.5
	)


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
		print("ALVEOLUS_PAUSE_OVERLAY_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
