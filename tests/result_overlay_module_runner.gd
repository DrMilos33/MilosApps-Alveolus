extends SceneTree

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var stats_source := _stats_fixture()
	var reward_source: Array[ResultOverlayViewModel.RewardViewModel] = [
		ResultOverlayViewModel.RewardViewModel.new(&"research", &"research", "+22", &"gold", "Forschung +22"),
	]
	var ability_damage_source := _ability_damage_fixture()
	var talent_source := _talent_fixture()
	var success_model := ResultOverlayViewModel.new(
		1,
		true,
		"Herd kontrolliert",
		"Der Infektionsherd ist unter Kontrolle.",
		"Der Zustand des Patienten wurde stabilisiert.",
		stats_source,
		"+22 Forschung",
		"Fall 02 ist jetzt verfügbar.",
		"Erster Sieg · +1 Talentpunkt",
		reward_source,
		"Fallübersicht",
		"Erneut behandeln",
		"Zum Campus",
		ability_damage_source,
		talent_source,
		true
	)
	var success_hash := success_model.get_content_hash()
	stats_source.clear()
	reward_source.clear()
	ability_damage_source.clear()
	talent_source.clear()
	_check(success_model.get_stats().size() == 3, "Ergebniswerte werden tief kopiert")
	_check(success_model.get_reward_items().size() == 1 and success_model.get_reward_items()[0].get_value() == "+22", "Reward-DTOs werden tief und wertfertig kopiert")
	_check(success_model.get_ability_damage_stats().size() == 3, "Fähigkeitsschäden werden getrennt und tief kopiert")
	_check(success_model.get_talent_stats().size() == 2 and success_model.are_talents_unlocked(), "Aktive Talente und Fall-2-Gate werden immutable übernommen")
	var returned_stats := success_model.get_stats()
	returned_stats.clear()
	var returned_rewards := success_model.get_reward_items()
	returned_rewards.clear()
	var returned_ability_damage := success_model.get_ability_damage_stats()
	returned_ability_damage.clear()
	var returned_talents := success_model.get_talent_stats()
	returned_talents.clear()
	_check(success_model.get_stats().size() == 3, "Ergebnis-VM gibt keine veränderbare interne Collection frei")
	_check(success_model.get_reward_items().size() == 1, "Ergebnis-VM gibt keine veränderbare Reward-Collection frei")
	_check(success_model.get_ability_damage_stats().size() == 3, "Ergebnis-VM gibt keine veränderbare Schadenscollection frei")
	_check(success_model.get_talent_stats().size() == 2, "Ergebnis-VM gibt keine veränderbare Talentcollection frei")
	_check(success_model.get_content_hash() == success_hash, "Externe Mutationen verändern den Content-Hash nicht")

	var overlay := ResultOverlay.new()
	overlay.theme = AlveolusVisualTheme.create_theme()
	host.add_child(overlay)
	await process_frame
	_check(overlay.apply(success_model), "Siegreiche Ergebnisrevision wird angewendet")
	await _settle()
	_check(overlay.get_modal() != null and overlay.get_modal().get_meta(&"alveolus_component", &"") == &"modal_sheet", "Ergebnis verwendet den zentralen ModalSheet")
	_check(overlay.get_modal().get_meta(&"result_success", false), "Sieg besitzt die semantische Erfolgsrolle")
	_check(overlay.get_modal().custom_minimum_size.y <= 0.0, "Ergebnis reserviert keine feste Leerraumhöhe")
	var outcome_title := overlay.find_child("OutcomeTitle", true, false) as Label
	_check(outcome_title != null and outcome_title.get_line_count() == 1, "Ergebnistitel nutzt breit eine vollständige Zeile statt Zeichenumbruch")
	_check(outcome_title != null and outcome_title.size.x >= 180.0, "Ergebnistitel erhält die verfügbare Überschriftenbreite")
	_check(overlay.get_modal().size.y < host.size.y * 0.9, "Breites Ergebnis bleibt inhaltsgetrieben statt viewportfüllend")
	_check(overlay.get_stats_column_count() == 3, "Drei kompakte Wertezeilen stehen breit nebeneinander")
	var ability_section := overlay.find_child("AbilitySection", true, false) as PanelContainer
	var ability_header := overlay.get_ability_section_header()
	var ability_title := ability_header.find_child("AbilitySectionTitle", true, false) as Label if ability_header != null else null
	var ability_chevron := ability_header.find_child("AbilitySectionChevron", true, false) as SimpleIcon if ability_header != null else null
	var ability_body := overlay.get_ability_section_body()
	_check(ability_section != null and ability_section.get_meta(&"alveolus_component", &"") == &"stat_accordion_section", "Fähigkeitsdetails verwenden die semantische Accordionfläche")
	_check(ability_header != null and ability_header.toggle_mode and ability_header.focus_mode == Control.FOCUS_ALL, "Der vollständige Fähigkeitskopf ist klick- und fokussierbar")
	_check(ability_header != null and ability_header.get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_QUIET, "Der Fähigkeitskopf verwendet die zentrale Quiet-Buttonrolle")
	_check(ability_title != null and ability_title.text == "Fähigkeiten", "Der klickbare Kopf trägt exakt Fähigkeiten")
	_check(ability_title != null and ability_title.mouse_filter == Control.MOUSE_FILTER_IGNORE and ability_chevron != null and ability_chevron.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Text und Chevron geben die vollständige Klickfläche an den Kopf weiter")
	_check(not overlay.is_ability_section_expanded() and ability_body != null and not ability_body.visible, "Fähigkeitsdetails beginnen standardmäßig eingeklappt")
	_check(ability_chevron != null and ability_chevron.kind == &"chevron_right" and ability_chevron.get_meta(&"accordion_state", &"") == &"collapsed", "Der eingeklappte Zustand verwendet das semantische Rechts-Chevron")
	_check(ability_header != null and String(ability_header.get_meta(&"alveolus_accessible_name", "")).contains("eingeklappt"), "Der Accessible Name benennt den eingeklappten Zustand")
	_check(overlay.get_action_column_count() == 3, "Folgeaktionen stehen breit in drei Spalten")
	var result_actions := overlay.find_child("ResultActions", true, false) as GridContainer
	_check(overlay.get_modal().is_ancestor_of(overlay.get_scroll_container()), "Ergebnis besitzt einen internen Body-Scroll innerhalb des ModalSheets")
	_check(result_actions != null and not overlay.get_scroll_container().is_ancestor_of(result_actions), "Ergebnisaktionen liegen als fester Footer außerhalb des Body-Scrolls")
	_check(overlay.get_scroll_container().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Breiter kurzer Ergebnisinhalt erzeugt keinen unnötigen Scrollbereich")
	_check(_optional_section_count(overlay) == 2, "Nur Freischaltung und Meisterschaft bleiben optionale Textsektionen")
	var reward_strip := overlay.find_child("RewardStrip", true, false) as GridContainer
	_check(reward_strip != null and overlay.get_reward_column_count() == 4, "Rewardstrip besitzt breit exakt vier Spalten")
	_check(not overlay.find_children("*", "Label", true, false).any(func(node: Node) -> bool: return (node as Label).text == "Belohnung"), "Ergebnis reserviert keine Überschrift Belohnung")
	var reward_column := overlay.find_child("Reward_research", true, false) as VBoxContainer
	var reward_icon := reward_column.find_child("RewardIcon", true, false) as SimpleIcon if reward_column != null else null
	var reward_value := overlay.find_child("Optional_reward_Body", true, false) as Label
	_check(reward_icon != null and reward_icon.kind == &"research" and reward_value != null and reward_value.text == "+22", "Forschungsreward zeigt ausschließlich Datenicon und Wert darunter")
	_check(overlay.reward_anchor(&"research") == reward_icon, "Der Ergebnis-Hinweis verankert sich am tatsächlichen Forschungssymbol")
	_check(overlay.reward_anchor(&"missing") == null, "Unbekannte Ergebnisbelohnungen erzeugen keinen falschen Hinweisanker")
	_check(reward_column != null and reward_column.get_meta(&"alveolus_accessible_name", "") == "Forschung +22", "Iconreward transportiert einen redundanten Accessible Name")
	_check(_reward_placeholder_texts(overlay) == PackedStringArray(["+ irgendwas", "+ maybe nochwas", "+ idk"]), "Drei zusätzliche Rewardspalten besitzen exakt die freigegebene Placeholder-Copy")
	_check(_primary_action_count(overlay) == 1, "Genau eine Folgeaktion ist visuell primär")
	_check(overlay.get_default_focus_control() == overlay.find_child("LevelsButton", true, false), "Fallübersicht ist die dominante Defaultaktion")
	overlay.grab_initial_focus()
	await process_frame
	_check(get_root().gui_get_focus_owner() == overlay.get_default_focus_control(), "Ergebnisfokus startet zuverlässig auf der Fallübersicht")
	_check(overlay.get_cancel_policy() == &"consume" and overlay.consumes_cancel() and overlay.handle_ui_cancel(), "ui_cancel wird am sichtbaren Ergebnis konsumiert statt den Abschluss zu schließen")
	_assert_focus_cycle(overlay)
	_check(not overlay.get_scroll_container().follow_focus and overlay.get_scroll_container().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Ergebnisrumpf bleibt vom Footerfokus entkoppelt und horizontal stabil")
	_assert_intents(overlay)
	ability_header.toggled.emit(true)
	await _settle()
	_check(overlay.is_ability_section_expanded() and ability_body.visible and ability_header.button_pressed, "Klick beziehungsweise Accept klappt die Fähigkeitsdetails vollständig aus")
	_check(ability_chevron.kind == &"chevron_down" and ability_chevron.get_meta(&"accordion_state", &"") == &"expanded", "Der ausgeklappte Zustand verwendet das semantische Abwärts-Chevron")
	_check(String(ability_header.get_meta(&"alveolus_accessible_name", "")).contains("ausgeklappt"), "Der Accessible Name benennt den ausgeklappten Zustand")
	_assert_ability_detail_order(overlay)

	_resize_logical_host(host, Vector2i(480, 270))
	await _settle()
	_check(overlay.is_compact_layout(), "480 logische Pixel bilden die 200-Prozent-Kompaktansicht ab")
	_check(overlay.get_stats_column_count() == 1, "Ergebniswerte stapeln kompakt einspaltig")
	_check(overlay.get_reward_column_count() == 2, "Der Vierer-Rewardstrip bricht kompakt ohne horizontales Scrollen zweispaltig um")
	_check(overlay.get_action_column_count() == 2, "Sekundäre Ergebnisaktionen sparen kompakt in zwei Spalten Platz für die Begründung")
	_check(overlay.get_modal().size.x <= overlay.size.x + 0.5, "ModalSheet bleibt vollständig in der kompakten Layerbreite")
	_check(_is_fully_visible(result_actions, overlay), "Der kompakte Aktionsfooter bleibt vollständig im sichtbaren Ergebnislayer")
	_check(overlay.get_scroll_container().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Nur der überlange kompakte Ergebnisrumpf aktiviert Scrollen")
	var footer_position_before_scroll := result_actions.global_position
	var compact_secondary_actions := overlay.find_child("CompactSecondaryActions", true, false) as GridContainer
	_check(compact_secondary_actions != null and compact_secondary_actions.visible and compact_secondary_actions.columns == 2, "Fallübersicht bleibt vollbreit über einer kompakten Sekundärzeile")
	_check(overlay.get_scroll_container().size.y >= 80.0, "Kompaktes Ergebnis zeigt neben dem Titel auch Begründung oder erste Werte")
	overlay.get_scroll_container().scroll_vertical = 100000
	await process_frame
	_check(overlay.get_scroll_container().scroll_vertical > 0, "Langer kompakter Ergebnisinhalt ist innerhalb des Modalrumpfs scrollbar")
	_check(result_actions.global_position.distance_to(footer_position_before_scroll) <= 0.5, "Body-Scrollen verschiebt den festen Aktionsfooter nicht")
	overlay.get_scroll_container().scroll_vertical = 100000
	overlay.grab_initial_focus()
	await _settle()
	_check(overlay.get_scroll_container().scroll_vertical == 0, "Kompaktes Ergebnis öffnet trotz CTA-Defaultfokus am Ergebnisanfang")
	var compact_title := overlay.find_child("OutcomeTitle", true, false) as Label
	_check(_is_visible_in_scroll(compact_title, overlay.get_scroll_container()), "Ausgang und Begründung beginnen sichtbar statt unterhalb der CTAs")
	_check(_is_fully_visible(result_actions, overlay), "Defaultfokus bleibt im sichtbaren Aktionsfooter ohne den Ergebnisrumpf zu verschieben")

	_resize_logical_host(host, Vector2i(1280, 720))
	var empty_talent_model := ResultOverlayViewModel.new(
		2,
		true,
		"Herd kontrolliert",
		"",
		"",
		_stats_fixture(),
		"",
		"",
		"",
		[],
		"Fallübersicht",
		"Erneut behandeln",
		"Zum Campus",
		_ability_damage_fixture(),
		[],
		true
	)
	_check(overlay.apply(empty_talent_model), "Leerer freigeschalteter Talentzustand wird angewendet")
	await _settle()
	_check(not overlay.is_ability_section_expanded() and not overlay.get_ability_section_body().visible, "Jeder neue Ergebnisinhalt startet mit eingeklappten Fähigkeitsdetails")
	var empty_talent_title := overlay.find_child("TalentSectionTitle", true, false) as Label
	var empty_talent_copy := overlay.find_child("TalentEmptyState", true, false) as Label
	_check(empty_talent_title != null and empty_talent_title.text == "Talente", "Freigeschaltete Talente erhalten ihren Untertitel unterhalb der Fähigkeitsschäden")
	_check(empty_talent_copy != null and empty_talent_copy.text == "Noch keine Talente aktiv", "Ein Run ohne aktive Talente zeigt exakt den freigegebenen Leerzustand")
	_check(overlay.find_child("TalentRows", true, false) == null, "Der Talent-Leerzustand reserviert kein leeres Zeilenraster")

	var locked_talent_model := ResultOverlayViewModel.new(
		3,
		false,
		"You suck",
		"",
		"",
		_stats_fixture(),
		"",
		"",
		"",
		[],
		"Fallübersicht",
		"Erneut behandeln",
		"Zum Campus",
		_ability_damage_fixture()
	)
	_check(overlay.apply(locked_talent_model), "Vor Fall 2 bleiben reine Fähigkeitsschäden darstellbar")
	await _settle()
	_check(overlay.find_child("AbilitySection", true, false) != null, "Fähigkeitsschäden bleiben unabhängig vom Talent-Gate im Accordion")
	_check(overlay.find_child("TalentSectionTitle", true, false) == null and overlay.find_child("TalentEmptyState", true, false) == null, "Vor Fall 2 entsteht weder Talentuntertitel noch irreführender Leerzustand")

	var failure_model := ResultOverlayViewModel.new(
		4,
		false,
		"You suck",
		"",
		"   ",
		_stats_fixture(),
		"",
		"",
		""
	)
	_check(overlay.apply(failure_model), "Niederlagenrevision wird angewendet")
	await _settle()
	_check(not bool(overlay.get_modal().get_meta(&"result_success", true)), "Niederlage besitzt die semantische Gefahrenrolle")
	_check(_optional_section_count(overlay) == 0, "Leere Belohnungssektionen erzeugen weder Karten noch Blank-Space")
	_check(overlay.find_child("AbilitySection", true, false) == null and not overlay.is_ability_section_expanded(), "Ein Ergebnis ohne Detaildaten erzeugt kein Accordion und setzt dessen nächsten Default zurück")
	_check(overlay.find_child("RewardStrip", true, false) == null, "Ohne Reward-DTO entsteht weder Strip noch Placeholder-Leerraum")
	var failure_title := overlay.find_child("OutcomeTitle", true, false) as Label
	_check(failure_title != null and failure_title.text == "You suck", "Niederlagen-View-Model stellt den verbindlichen Titel exakt dar")
	_check(overlay.find_child("Reason", true, false) == null, "Leerer Niederlagengrund erzeugt keinen Untertitelknoten")
	_check(overlay.find_child("Detail", true, false) == null, "Inhaltsloses Niederlagendetail erzeugt keinen Reserveknoten")
	var failure_content := overlay.find_child("ResultContent", true, false) as VBoxContainer
	_check(
		failure_content != null
		and overlay.get_scroll_container().custom_minimum_size.y <= failure_content.get_combined_minimum_size().y + 1.0,
		"Niederlage reserviert keine Höhe für ausgelassene Copy"
	)
	var result_overlay_source := FileAccess.get_file_as_string("res://scripts/ui/screens/result_overlay.gd")
	_check(not result_overlay_source.contains("You suck"), "Niederlagentitel bleibt Presenter-Daten statt hardcodierter Overlay-Entscheidung")
	_check(_primary_action_count(overlay) == 1, "Auch die Niederlage behält genau eine primäre Folgeaktion")

	_assert_dependency_contract()
	overlay.hide()
	_check(not overlay.handle_ui_cancel(), "Ein verborgenes Ergebnis konsumiert keine Router-Eingabe")
	host.queue_free()
	await process_frame
	_finish()


func _assert_intents(overlay: ResultOverlay) -> void:
	var retry_count := [0]
	var levels_count := [0]
	var campus_count := [0]
	overlay.retry.connect(func() -> void: retry_count[0] += 1)
	overlay.levels.connect(func() -> void: levels_count[0] += 1)
	overlay.campus.connect(func() -> void: campus_count[0] += 1)
	(overlay.find_child("RetryButton", true, false) as Button).pressed.emit()
	(overlay.find_child("LevelsButton", true, false) as Button).pressed.emit()
	(overlay.find_child("CampusButton", true, false) as Button).pressed.emit()
	_check(retry_count[0] == 1 and levels_count[0] == 1 and campus_count[0] == 1, "Erneut, Fallübersicht und Campus emittieren getrennte Intents")


func _assert_focus_cycle(overlay: ResultOverlay) -> void:
	var levels_button := overlay.find_child("LevelsButton", true, false) as Button
	var retry_button := overlay.find_child("RetryButton", true, false) as Button
	var campus_button := overlay.find_child("CampusButton", true, false) as Button
	var ability_header := overlay.get_ability_section_header()
	_check(levels_button != null and retry_button != null and campus_button != null, "Alle drei Ergebnisaktionen sind fokussierbar vorhanden")
	if levels_button == null or retry_button == null or campus_button == null:
		return
	_check(levels_button.get_node_or_null(levels_button.focus_neighbor_left) == campus_button, "Rückwärtsfokus bleibt in den Ergebnisaktionen")
	_check(campus_button.get_node_or_null(campus_button.focus_neighbor_right) == levels_button, "Vorwärtsfokus bleibt in den Ergebnisaktionen")
	_check(ability_header != null and levels_button.get_node_or_null(levels_button.focus_neighbor_top) == ability_header, "Vertikalfokus erreicht den Fähigkeitskopf aus dem festen Footer")
	_check(ability_header != null and ability_header.get_node_or_null(ability_header.focus_neighbor_bottom) == levels_button, "Der Fähigkeitskopf führt per D-Pad zur dominanten Ergebnisaktion zurück")


func _assert_ability_detail_order(overlay: ResultOverlay) -> void:
	var body := overlay.get_ability_section_body()
	var damage_rows := overlay.find_child("AbilityDamageRows", true, false) as GridContainer
	var talent_title := overlay.find_child("TalentSectionTitle", true, false) as Label
	var talent_rows := overlay.find_child("TalentRows", true, false) as GridContainer
	_check(body != null and damage_rows != null and talent_title != null and talent_rows != null, "Ausgeklappte Fähigkeitsdetails besitzen Schaden, Talentuntertitel und Talentzeilen")
	if body == null or damage_rows == null or talent_title == null or talent_rows == null:
		return
	_check(damage_rows.get_index() < talent_title.get_index() and talent_title.get_index() < talent_rows.get_index(), "Fähigkeitsschäden stehen vor dem optionalen Talentblock")
	_check(damage_rows.get_child_count() == 3 and talent_rows.get_child_count() == 2, "Alle gelieferten Schadens- und Talentzeilen erscheinen genau einmal")
	var first_damage := damage_rows.get_child(0) as PanelContainer
	var first_talent := talent_rows.get_child(0) as PanelContainer
	var first_damage_name := first_damage.find_child("ValueName", true, false) as Label if first_damage != null else null
	var first_damage_value := first_damage.find_child("Value", true, false) as Label if first_damage != null else null
	var first_talent_name := first_talent.find_child("ValueName", true, false) as Label if first_talent != null else null
	var first_talent_value := first_talent.find_child("Value", true, false) as Label if first_talent != null else null
	_check(first_damage_name != null and first_damage_name.text == "Impuls" and first_damage_value != null and first_damage_value.text == "42 Schaden", "Erste Fähigkeitsschadenszeile bewahrt Label und formatierten Wert")
	_check(first_talent_name != null and first_talent_name.text == "Behandlungsgrundlage" and first_talent_value != null and first_talent_value.text == "Rang 1/1", "Erste Talentzeile bewahrt aktiven Run-Rang")


func _optional_section_count(overlay: ResultOverlay) -> int:
	var count := 0
	for panel in overlay.find_children("Optional_*", "PanelContainer", true, false):
		if (panel as Control).has_meta(&"result_optional_section"):
			count += 1
	return count


func _primary_action_count(overlay: ResultOverlay) -> int:
	var count := 0
	for button_value in overlay.find_children("*Button", "Button", true, false):
		var button := button_value as Button
		if button != null and button.theme_type_variation == AlveolusVisualTheme.TYPE_PRIMARY_BUTTON:
			count += 1
	return count


func _reward_placeholder_texts(overlay: ResultOverlay) -> PackedStringArray:
	var result := PackedStringArray()
	for index in range(1, 4):
		var column := overlay.find_child("RewardPlaceholder%d" % index, true, false) as VBoxContainer
		var value := column.find_child("PlaceholderValue", true, false) as Label if column != null else null
		if value != null:
			result.append(value.text)
	return result


func _is_visible_in_scroll(control: Control, scroll: ScrollContainer) -> bool:
	if control == null or scroll == null:
		return false
	return Rect2(scroll.global_position, scroll.size).intersects(Rect2(control.global_position, control.size))


func _is_fully_visible(control: Control, viewport_control: Control) -> bool:
	if control == null or viewport_control == null:
		return false
	var viewport_rect := Rect2(viewport_control.global_position, viewport_control.size)
	var control_rect := Rect2(control.global_position, control.size)
	return viewport_rect.encloses(control_rect)


func _stats_fixture() -> Array[ResultOverlayViewModel.StatViewModel]:
	var result: Array[ResultOverlayViewModel.StatViewModel] = []
	result.append(ResultOverlayViewModel.StatViewModel.new(&"time", "Zeit", "2:31"))
	result.append(ResultOverlayViewModel.StatViewModel.new(&"analysis", "Befundstufe", "5", true))
	result.append(ResultOverlayViewModel.StatViewModel.new(&"defeats", "Bakterien", "74"))
	return result


func _ability_damage_fixture() -> Array[ResultOverlayViewModel.StatViewModel]:
	var result: Array[ResultOverlayViewModel.StatViewModel] = []
	result.append(ResultOverlayViewModel.StatViewModel.new(&"treatment_precision", "Impuls", "42 Schaden"))
	result.append(ResultOverlayViewModel.StatViewModel.new(&"ability_defense_burst", "Stoß", "0 Schaden"))
	result.append(ResultOverlayViewModel.StatViewModel.new(&"ability_treatment_line", "Fetter lazer", "30 Schaden"))
	return result


func _talent_fixture() -> Array[ResultOverlayViewModel.StatViewModel]:
	var result: Array[ResultOverlayViewModel.StatViewModel] = []
	result.append(ResultOverlayViewModel.StatViewModel.new(&"treatment_damage_training", "Behandlungsgrundlage", "Rang 1/1"))
	result.append(ResultOverlayViewModel.StatViewModel.new(&"piercing_persistence", "Anhaltender Laser", "Rang 2/2"))
	return result


func _assert_dependency_contract() -> void:
	for path in [
		"res://scripts/ui/screens/result_overlay.gd",
		"res://scripts/ui/view_models/result_overlay_view_model.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in ["ContentCatalog", "MetaProgressionState", "PlayerStats", "RunState", "LevelDefinition", "Save", "add_theme_stylebox_override", "ShaderMaterial", "func _process", "func _physics_process"]:
			_check(not source.contains(forbidden), "%s bleibt frei von %s" % [path, forbidden])


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
		print("RESULT_OVERLAY_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("RESULT_OVERLAY_MODULE_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
