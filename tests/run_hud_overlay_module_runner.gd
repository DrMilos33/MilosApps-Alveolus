extends SceneTree

const RUN_HUD_PATH := "res://scripts/ui/screens/run_hud_overlay.gd"
const RUN_HUD_VIEW_MODEL_PATH := "res://scripts/ui/view_models/run_hud_view_model.gd"
const RunHUDOverlayScript := preload(RUN_HUD_PATH)
const RunHUDViewModelScript := preload(RUN_HUD_VIEW_MODEL_PATH)

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_boundaries()
	var view_model := _test_immutable_view_model()
	await _test_screen_contract(view_model)
	_finish()


func _test_source_boundaries() -> void:
	var source := _read_source(RUN_HUD_PATH) + "\n" + _read_source(RUN_HUD_VIEW_MODEL_PATH)
	for forbidden in [
		"MetaProgressionState",
		"PlayerStats",
		"RunState",
		"RunSession",
		"ContentCatalog",
		"AbilityDefinition",
		"UpgradeDefinition",
		"calculate_run_reward",
		"award_run",
		"ConfigFile",
		"FileAccess",
		"save_game",
	]:
		_check(not source.contains(forbidden), "Run-HUD-Modul besitzt keine verbotene Abhängigkeit %s" % forbidden)
	_check(source.contains("AlveolusUIComponents.apply_surface_role"), "Run-HUD nutzt ausschließlich zentrale Bio-Lumen-Surface-Rollen")
	_check(source.contains("AlveolusUIComponents.progress"), "Run-HUD verwendet zentrale Fortschrittskomponenten")
	_check(source.contains("AlveolusUIComponents.action_button"), "Pause und Fähigkeitstrefferflächen verwenden zentrale Actions")
	_check(source.contains("AlveolusUIComponents.label"), "Run-HUD-Typografie stammt aus zentralen Rollen")
	_check(not source.contains("add_theme_stylebox_override"), "Run-HUD erzeugt keine lokale StyleBox-Kopie")
	_check(not source.contains("Shader.new") and not source.contains("ShaderMaterial.new"), "Run-HUD erzeugt keine lokalen Shaderressourcen")
	_check(not source.contains("func _process") and not source.contains("func _physics_process"), "Run-HUD besitzt keine dauerhafte Prozessschleife")
	_check(not source.contains("Timer.new") and not source.contains("create_timer"), "Run-HUD besitzt keinen eigenen Countdown oder Animationstimer")
	_check(not source.contains("Color.WHITE") and not source.contains("PAPER_LIGHT"), "Run-HUD erzeugt keine weißen Flächen")
	_check(source.contains("BASIC_STAT_IDS"), "Run-HUD-View-Model begrenzt den Kampfstreifen auf stabile Grundwert-IDs")


func _test_immutable_view_model() -> RunHUDViewModel:
	var vital := _vital_snapshot()
	var stats := _stat_rows()
	var abilities := _ability_rows()
	var view_model: RunHUDViewModel = RunHUDViewModelScript.create(vital, stats, abilities, 22)
	_check(view_model.is_valid() and view_model.revision() == 22, "View-Model übernimmt einen gültigen revisionsgebundenen Snapshot")
	_check(view_model.content_hash().length() == 64, "Run-HUD-View-Model besitzt einen SHA-256-Inhaltshash")
	_check(view_model.stability_text() == "76 / 100" and view_model.shield_text() == "12", "Leben und Schild sind präsentationsfertig und nur lesbar")
	_check(view_model.round_time_text() == "03:36" and view_model.timer_text() == "03:36", "Rundendauer ist präsentationsfertig und frei von Boss-Chrome")
	_check(
		view_model.defeat_research_reward_visible()
		and view_model.defeat_research_reward_icon_id() == &"research"
		and view_model.defeat_research_reward_formatted_value() == "+18"
		and view_model.defeat_research_reward_accessible_name() == "Forschungsgewinn bei Niederlage: 18",
		"Niederlagenprognose ist als reine Symbol-Zahl-Präsentation mit Accessible Name kopiert"
	)
	_check(view_model.boss_visible() and view_model.boss_percentage_text() == "64 %", "Bossstatus enthält Sichtbarkeit und Prozentwert")
	_check(view_model.analysis_text() == "Lv 3 · 7/12", "Analyse und Proben bilden eine kompakte gemeinsame Anzeige")
	_check(view_model.stat_count() == 8 and view_model.ability_count() == 2, "Snapshot enthält acht kompakte Grundwerte und exakt zwei Fähigkeitsslots")
	_check(view_model.stat_at(0).id() == &"defense", "Grundwerte werden nach stabiler Priorität sortiert")
	_check(view_model.stats().all(func(stat: RunHUDViewModel.StatValueViewModel) -> bool:
		return RunHUDViewModel.BASIC_STAT_IDS.has(stat.id())
	), "Behandlungs- und Fähigkeitswerte gelangen nicht in den Kampfstreifen")
	_check(view_model.ability_at(0).title() == "Fokusfeld" and view_model.ability_at(1).title() == "Notfallhilfe", "Fähigkeiten werden unabhängig von der Eingabereihenfolge nach Slot normalisiert")
	_check(view_model.ability_at(0).effect_text() == "Priorisiert Ziele und verstärkt die Behandlung im Zielgebiet.", "Fähigkeitswirkung wird präsentationsfertig und nur lesbar kopiert")
	_check(view_model.ability_at(0).facts_text() == "Abklingzeit: 10 s\nRadius: 4", "Fähigkeit stellt ausschließlich strukturierte Fakten ohne interne Weltmaße bereit")
	_check(view_model.ability_at(0).icon_fact_rows().size() == 1 and view_model.ability_at(0).icon_fact_rows()[0].value == "100 %", "Schadenstyp bleibt als reine Icon-Wert-Zeile getrennt von Textfakten")
	_check(view_model.ability_at(0).targeting() and view_model.ability_at(0).status_text() == "Ziel wählen", "Targeting besitzt Vorrang vor dem Bereitstatus")
	_check(is_equal_approx(view_model.ability_at(1).cooldown_progress(), 0.4), "Cooldownfortschritt wird aus kopierten Presenterwerten berechnet")
	_check(view_model.ability_at(-1) == null and view_model.ability_at(2) == null, "Ungültige Fähigkeitsslots werden sicher abgewiesen")

	vital["timer_text"] = "Fremde Mutation"
	(vital["nested"] as Dictionary)["mutable"] = false
	(vital["defeat_research_reward"] as Dictionary)["value"] = "+999"
	stats[0]["value"] = "999"
	abilities[0]["title"] = "Fremde Fähigkeit"
	abilities[0]["effect_text"] = "Fremde Wirkung"
	var mutable_fact_rows := abilities[0]["fact_rows"] as Array
	var mutable_fact := mutable_fact_rows[0] as Dictionary
	mutable_fact["value"] = "999 s"
	var returned_stats := view_model.stats()
	var returned_abilities := view_model.abilities()
	returned_stats.clear()
	returned_abilities.clear()
	_check(view_model.timer_text() == "03:36", "Tiefe Quellmutationen erreichen den Vital-Snapshot nicht")
	_check(view_model.defeat_research_reward_formatted_value() == "+18", "Tiefe Quellmutationen erreichen die Niederlagenprognose nicht")
	_check(view_model.stat_count() == 8 and view_model.stat_at(0).formatted_value() == "8 %", "Grundwertarrays sind defensiv kopiert")
	_check(view_model.ability_count() == 2 and view_model.ability_at(1).title() == "Notfallhilfe" and view_model.ability_at(1).facts_text().contains("12 s"), "Fähigkeitsarrays, Namen und Fakten sind defensiv kopiert")

	var equivalent: RunHUDViewModel = RunHUDViewModelScript.create(_vital_snapshot(), _stat_rows(), _ability_rows(), 23)
	_check(equivalent.content_hash() == view_model.content_hash(), "Revision ist nicht Teil des semantischen HUD-Hashs")
	var changed_reward_vital := _vital_snapshot()
	(changed_reward_vital["defeat_research_reward"] as Dictionary)["value"] = "+19"
	var changed_reward: RunHUDViewModel = RunHUDViewModelScript.create(changed_reward_vital, _stat_rows(), _ability_rows(), 23)
	_check(changed_reward.content_hash() != view_model.content_hash(), "Niederlagenprognose ist Bestandteil des semantischen HUD-Hashs")
	var legacy_vital := _vital_snapshot()
	legacy_vital.erase("round_time_text")
	var legacy_timer: RunHUDViewModel = RunHUDViewModelScript.create(legacy_vital, _stat_rows(), _ability_rows(), 23)
	_check(legacy_timer.timer_text() == "01:24", "Legacy-Bosschrome wird bis zur Presenterumstellung auf den reinen Uhrwert reduziert")
	var no_reward_vital := _vital_snapshot()
	no_reward_vital.erase("defeat_research_reward")
	var no_reward: RunHUDViewModel = RunHUDViewModelScript.create(no_reward_vital, _stat_rows(), _ability_rows(), 23)
	_check(not no_reward.defeat_research_reward_visible(), "Ohne Presenterprognose bleibt die Niederlagenforschung vollständig ausgeblendet")
	var one_slot: RunHUDViewModel = RunHUDViewModelScript.create(_vital_snapshot(), [], [
		{"slot": 0, "title": "Fokusfeld", "effect_text": "Verstärkt die Behandlung.", "occupied": true, "key_glyph_text": "Q"},
	], 24)
	_check(one_slot.ability_count() == 2 and not one_slot.ability_at(1).occupied(), "Fehlende Belegung bleibt nur als stabiles logisches Slot-Mapping erhalten")
	_check(one_slot.ability_at(1).key_glyph_text() == "E", "Leerslot besitzt weiterhin seinen konfigurierbaren Glyphtext-Fallback")
	return view_model


func _test_screen_contract(view_model: RunHUDViewModel) -> void:
	var host := _create_logical_host(Vector2i(1280, 720))
	var hud := RunHUDOverlayScript.new() as RunHUDOverlay
	hud.theme = AlveolusVisualTheme.create_theme()
	host.add_child(hud)
	_check(hud.apply_view_model(view_model), "Erstes Apply bindet das vollständige Run-HUD")
	await _settle()

	_assert_surface(hud.stability_panel(), AlveolusVisualTheme.SurfaceRole.HUD_VITAL, "Leben")
	_assert_surface(hud.shield_panel(), AlveolusVisualTheme.SurfaceRole.HUD_VITAL, "Schild")
	_assert_surface(hud.defeat_research_reward_panel(), AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE, "Niederlagenforschung")
	_assert_surface(hud.timer_panel(), AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE, "Timer")
	_assert_surface(hud.boss_panel(), AlveolusVisualTheme.SurfaceRole.HUD_ALERT, "Boss")
	_assert_surface(hud.analysis_panel(), AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE, "Analyse")
	for card in hud.ability_cards():
		_assert_surface(card, AlveolusVisualTheme.SurfaceRole.HUD_ABILITY, "Fähigkeit")

	_check(hud.stability_bar().value == 76.0 and hud.stability_bar().max_value == 100.0, "Lebensleiste übernimmt Presenterwerte")
	_check(hud.stability_value_label().text == "76 / 100", "Lebenswert bleibt immer sichtbar")
	_check(hud.shield_panel().visible and hud.shield_bar().value == 12.0, "Schild bleibt auch als eigene kritische Anzeige sichtbar")
	_check(
		hud.defeat_research_reward_panel().visible
		and hud.defeat_research_reward_icon().kind == &"research"
		and hud.defeat_research_reward_value_label().text == "+18",
		"Niederlagenforschung zeigt ausschließlich Symbol und Zahl"
	)
	_check(
		hud.defeat_research_reward_panel().get_meta(&"alveolus_accessible_name", "") == "Forschungsgewinn bei Niederlage: 18",
		"Niederlagenforschung besitzt ihren vollständigen Accessible Name"
	)
	_check(hud.timer_value_label().text == "03:36", "Freistehende Rundendauer besitzt keine eigene Fortschrittslogik")
	_check(not hud.boss_panel().visible and hud.boss_value_label().text == "64 %", "Die frühere Bosskarte bleibt dormant, während der Kompatibilitätssnapshot gebunden bleibt")
	_check(hud.analysis_value_label().text == "Lv 3 · 7/12" and hud.analysis_bar().value == 7.0, "Proben und Analyse bleiben als kompakte Zielanzeige sichtbar")
	_check(hud.stability_panel().size.y <= 30.0 and hud.stability_panel().size.x >= 360.0 and hud.stability_panel().find_child("StabilityIcon", true, false) == null, "Leben nutzt einen niedrigen, breiten und zentrierten Balken ohne redundantes Vital-Icon")
	_check(hud.stability_panel().get_meta(&"alveolus_component", &"") == &"transparent_hud_vital" and is_zero_approx(hud.stability_panel().self_modulate.a), "Leben schwebt ohne Kartenfläche über dem Run")
	_check(hud.analysis_panel().size.y <= 30.0 and is_zero_approx(hud.analysis_panel().self_modulate.a), "Befund und Level bleiben ohne Kachel als dezente Zielzeile kompakt")
	_check(hud.timer_panel().size.x <= 82.0 and hud.timer_panel().global_position.x > 640.0 and is_zero_approx(hud.timer_panel().self_modulate.a), "Rundendauer sitzt freistehend oben rechts")
	_check(
		is_zero_approx(hud.defeat_research_reward_panel().self_modulate.a)
		and hud.defeat_research_reward_panel().get_global_rect().end.x <= hud.timer_panel().get_global_rect().position.x + 0.5
		and hud.timer_panel().get_global_rect().position.x - hud.defeat_research_reward_panel().get_global_rect().end.x <= 4.5,
		"Symbol und Zahl der Niederlagenforschung liegen transparent unmittelbar links vom Timer"
	)

	_check(hud.run_stats_strip().is_class("HFlowContainer") and not hud.run_stats_strip().is_class("Panel"), "Runwerte besitzen einen transparenten Flow statt einer eigenen Panel-Fläche")
	_check(hud.stat_rows().size() == 8, "Alle acht präsentierten Grundwerte sind sichtbar")
	for row in hud.stat_rows():
		_check(row.get_child_count() == 2 and row.get_child(0) is SimpleIcon and row.get_child(1) is Label, "Runwert zeigt ausschließlich Icon und Wert")
		_check(row.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Transparenter Runwert blockiert kein Gameplay-Pointerevent")
		_check((row.get_child(0) as SimpleIcon).accent == (row.get_child(1) as Label).modulate, "Icon und Wert teilen ihren semantischen Farbakzent")
		var stat_icon := row.get_child(0) as SimpleIcon
		var stat_value := row.get_child(1) as Label
		_check(stat_value.global_position.x - stat_icon.get_global_rect().end.x <= 3.5, "Icon und Zahl bilden eine enge lesbare Einheit")
		_check(stat_value.size.x >= RunHUDOverlay.STAT_VALUE_MINIMUM_WIDTH - 0.5 and not stat_value.text.is_empty(), "Jeder kompakte Grundwert besitzt sichtbar lesbare Zahlenbreite")
		_check(RunHUDViewModel.BASIC_STAT_IDS.has(row.get_meta(&"stat_id", &"")), "Kampfstreifen enthält ausschließlich stabile Grundwert-IDs")
	_check(_row_populations(hud.stat_rows()) == [4, 4], "Grundwerte stehen rechts unter der Zeit in exakt vier Spalten")

	_check(hud.ability_cards().size() == 2 and hud.ability_buttons().size() == 2, "Run-HUD behält exakt zwei stabile logische Fähigkeitsslots")
	_check(hud.ability_icons().size() == 2 and hud.ability_key_labels().size() == 2, "Jeder Fähigkeitsslot besitzt Icon und Glyphtext")
	_check(hud.ability_title_labels()[0].text == "Fokusfeld" and not hud.ability_title_labels()[0].visible and hud.ability_key_labels()[0].text == "Q", "Titel bleibt für Kompatibilität gebunden, aber dauerhaft aus dem knappen HUD ausgeblendet")
	_check(hud.ability_cards().all(func(card: Panel) -> bool: return is_zero_approx(card.self_modulate.a) and card.get_meta(&"alveolus_component", &"") == &"transparent_hud_ability"), "Fähigkeiten zeigen keine massive Kachel hinter Icon und Readout")
	_check(hud.ability_cooldown_bars().all(func(bar: ProgressBar) -> bool: return bar.position.is_equal_approx(Vector2.ZERO) and is_equal_approx(bar.size.y, 38.0)), "Cooldownleiste selbst trägt Icon, Shortcut und Timer kompakt über exakt 38 Pixel")
	for bar in hud.ability_cooldown_bars():
		var track_background := bar.get_theme_stylebox("background") as StyleBoxFlat
		var track_fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
		_check(bar.get_meta(&"alveolus_component", &"") == &"ability_cooldown_track", "Cooldown verwendet die explizite kompakte Track-Komponente")
		_check(track_background != null and track_background.bg_color.a >= 0.70 and track_background.bg_color.a <= 0.75, "Cooldowntrack besitzt genug dunklen Kontrast über hellem Gewebe")
		_check(track_background != null and track_background.border_color.a >= 0.90, "Cooldowntrack erhält eine klar lesbare semantische Kontur")
		_check(track_fill != null and track_fill.bg_color.a >= 0.34 and track_fill.bg_color.a <= 0.38, "Cooldownfortschritt bleibt transparent, ist aber auch auf hellem Gewebe eindeutig sichtbar")
	var readouts := hud.find_children("*", "HBoxContainer", true, false).filter(func(node: Node) -> bool: return node.get_meta(&"alveolus_component", &"") == &"ability_track_readout")
	_check(readouts.size() == 2 and readouts.all(func(node: Node) -> bool: return (node as CanvasItem).z_index == 0), "Fähigkeitsreadouts bleiben hinter späteren blockierenden Modalebenen")
	for icon in hud.ability_icons():
		_check(icon.visible and icon.custom_minimum_size.x >= 22.0 and icon.modulate.a > 0.95, "Belegte Fähigkeit zeigt ihr Icon klar über dem Cooldowntrack")
	_check(hud.ability_key_labels().all(func(label: Label) -> bool: return label.modulate == AlveolusVisualTheme.IVORY), "Shortcuts bleiben unabhängig vom Cooldownzustand kräftig lesbar")
	_check(hud.ability_key_labels().all(func(label: Label) -> bool: return label.visible), "Shortcuts liegen sichtbar direkt auf dem Cooldowntrack")
	_check(hud.ability_cooldown_labels().all(func(label: Label) -> bool: return label.visible), "Timer beziehungsweise Bereitstatus liegen sichtbar direkt auf dem Cooldowntrack")
	_check(hud.ability_cooldown_labels()[0].text == "Ziel wählen", "Targeting wird im ersten Slot eindeutig angezeigt")
	_check(hud.ability_cooldown_labels()[1].text == "7.2 s", "Zweiter Slot zeigt seinen Presenter-Cooldown")
	_check(is_equal_approx(hud.ability_cooldown_bars()[1].value, 0.4), "Cooldownleiste bindet den normalisierten Fortschritt")
	_check(hud.ability_cards()[0].get_meta(&"targeting", false), "Targetingstatus bleibt am kompatiblen Slot-Control verfügbar")
	_check(not hud.ability_buttons()[0].disabled and not hud.ability_buttons()[1].disabled, "Belegte Slots bleiben interaktiv")
	_check(hud.ability_buttons()[0].scale.is_equal_approx(Vector2.ONE), "Fähigkeitsfokus verwendet keine Scale-Transformation")
	for slot_index in range(hud.ability_buttons().size()):
		_check(_inside(hud.ability_buttons()[slot_index], hud.ability_cards()[slot_index]), "Fähigkeitstrefferfläche %d bleibt vollständig in der 38-px-Cooldownleiste" % (slot_index + 1))
	_check(hud.ability_buttons().all(func(button: Button) -> bool: return button.tooltip_text.is_empty()), "Native Tooltips konkurrieren nicht mit der zentralen Hoverkarte")
	_check(hud.ability_buttons().all(func(button: Button) -> bool: return UISoundService.sound_role(button) == UISoundService.NONE), "Fähigkeitstrefferflächen überlassen Soundfeedback ausschließlich dem Gameplay-Intent")
	var registrations := hud.context_detail_registrations()
	_check(registrations.size() == 2 and bool(registrations[0].get("hover_enabled", false)), "Beide stabilen Slots exponieren hoverfähige ContextDetail-Registrierungen")
	_check(registrations.all(func(registration: Dictionary) -> bool:
		return (
			registration.get("source") is Control
			and not registration.has("anchor")
			and not registration.has("placement")
		)
	), "Beide Fähigkeiten übergeben ausschließlich ihr tatsächliches Source-Control an die globale AUTO-Regel")
	var hover_provider := hud.tooltip_provider_for(hud.ability_buttons()[0])
	_check(hover_provider.is_valid() and hover_provider == hud.ui_info_provider_for(hud.ability_buttons()[0]), "Maus-Hover und ui_info teilen dieselbe stabile Informationsquelle")
	var hover_payload: Dictionary = hover_provider.call()
	_check(
		hover_payload.get("title", "") == "Fokusfeld"
		and hover_payload.get("body", "") == "Priorisiert Ziele und verstärkt die Behandlung im Zielgebiet."
		and hover_payload.get("meta", "") == "Abklingzeit: 10 s\nRadius: 4"
		and (hover_payload.get("icon_rows", []) as Array).size() == 1
		and StringName(String(hover_payload.get("icon_kind", ""))) == &"",
		"Fähigkeitstooltip verbindet Namen, Kernwirkung und strukturierte Fakten"
	)
	_check(is_equal_approx(float(hover_payload.get("surface_opacity", 0.0)), 0.86), "Fähigkeitstooltip fordert eine dezente halbtransparente Fläche an")
	_check(hud.pause_action().get_meta(&"alveolus_action_role", &"") == AlveolusUIComponents.ACTION_QUIET, "Pause bleibt eine ruhige HUD-Aktion")
	_check(hud.pause_action().flat and hud.pause_action().get_meta(&"alveolus_component", &"") == &"transparent_pause_action", "Pause erscheint als freistehendes Icon ohne Kachel")
	_check(get_root().gui_get_focus_owner() == null or not hud.is_ancestor_of(get_root().gui_get_focus_owner()), "Presenterupdate erzeugt keinen unerwarteten HUD-Fokus")

	var ability_intents: Array[int] = []
	var pause_intents: Array[bool] = []
	hud.ability_requested.connect(func(slot: int) -> void: ability_intents.append(slot))
	hud.pause_requested.connect(func() -> void: pause_intents.append(true))
	hud.ability_buttons()[0].pressed.emit()
	hud.ability_buttons()[1].pressed.emit()
	hud.pause_action().pressed.emit()
	_check(ability_intents == [0, 1], "Beide Fähigkeitstrefferflächen emittieren ausschließlich ihren Slot")
	_check(pause_intents.size() == 1, "Pause emittiert genau einen Intent")
	_check(hud.pause_action().size.is_equal_approx(Vector2(44.0, 44.0)), "Pause bleibt visuell kompakt bei vollständiger 44-Pixel-Trefferfläche")
	_check(hud.grab_ability_focus(0), "Fassade kann den ersten belegten Fähigkeitsslot fokussieren")
	await process_frame
	_check(get_root().gui_get_focus_owner() == hud.ability_buttons()[0], "Expliziter Fokus landet auf dem angeforderten Slot")
	_check(_focus_target_inside(hud.ability_buttons()[0], hud.ability_buttons()[0].focus_next, hud), "Tabnavigation bleibt in den HUD-Aktionen")

	var original_stat_ids: Array[int] = []
	for row in hud.stat_rows():
		original_stat_ids.append(row.get_instance_id())
	var original_ability_ids: Array[int] = []
	for card in hud.ability_cards():
		original_ability_ids.append(card.get_instance_id())
	var updated_vital := _vital_snapshot()
	updated_vital["round_time_text"] = "03:37"
	(updated_vital["defeat_research_reward"] as Dictionary)["value"] = "+19"
	(updated_vital["defeat_research_reward"] as Dictionary)["accessible_name"] = "Forschungsgewinn bei Niederlage: 19"
	var updated_stats := _stat_rows()
	updated_stats[0]["value"] = "9 %"
	var updated_abilities := _ability_rows()
	updated_abilities[0]["cooldown_remaining"] = 6.8
	var updated: RunHUDViewModel = RunHUDViewModelScript.create(updated_vital, updated_stats, updated_abilities, 23)
	_check(hud.apply_view_model(updated), "Inkrementeller Presenter-Snapshot wird angewendet")
	await _settle()
	_check(_instance_ids(hud.stat_rows()) == original_stat_ids, "Wertupdates erzeugen keine neuen Stat-Nodes")
	_check(_instance_ids(hud.ability_cards()) == original_ability_ids, "Cooldownupdates erzeugen keine neuen Fähigkeitsslots")
	_check(hud.timer_value_label().text == "03:37", "Presenterupdate ändert die Rundendauer exakt einmal")
	_check(hud.defeat_research_reward_value_label().text == "+19", "Presenterupdate aktualisiert die Niederlagenprognose in-place")
	_check(not hud.apply_view_model(updated), "Identischer Snapshot ist idempotent")

	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(960, 540)]:
		_resize_logical_host(host, viewport_size)
		await _settle()
		_assert_critical_layout(hud, viewport_size)
		_check(_row_populations(hud.stat_rows()) == [4, 4], "%s hält rechts unter der Zeit exakt vier Grundwerte pro Reihe" % viewport_size)

	# Logical 480 × 270 corresponds to the required 960 × 540 at 200 percent.
	_resize_logical_host(host, Vector2i(480, 270))
	await _settle()
	_assert_critical_layout(hud, Vector2i(480, 270))
	_check(hud.ability_panel().columns == 2, "Auch bei 200 Prozent bleiben zwei belegte Fähigkeiten eindeutig nebeneinander")
	_check(hud.stability_panel().visible and hud.shield_panel().visible and hud.defeat_research_reward_panel().visible and hud.timer_panel().visible and hud.analysis_panel().visible, "200-Prozent-Layout blendet keinen gameplaykritischen Wert aus")
	_check(_row_populations(hud.stat_rows()) == [4, 4], "Auch bei 200 Prozent bleiben exakt vier Grundwerte pro Reihe")
	_check(hud.run_stats_strip().get_global_rect().end.y <= hud.analysis_panel().get_global_rect().position.y + 0.5, "Kompakte Statzeilen kollidieren nicht mit Analyse und Proben")

	var one_slot_model: RunHUDViewModel = RunHUDViewModelScript.create(updated_vital, [], [
		{
			"slot": 0,
			"title": "Fokusfeld",
			"effect_text": "Verstärkt die Behandlung.",
			"icon_id": &"ability_focus_field",
			"occupied": true,
			"ready": true,
			"key_glyph_text": "Q",
		},
	], 24)
	_check(hud.apply_view_model(one_slot_model), "Snapshot mit nur einer belegten Fähigkeit wird angewendet")
	await _settle()
	_check(hud.ability_cards()[0].visible and not hud.ability_cards()[1].visible, "Unbelegter Fähigkeitsslot wird vollständig ausgeblendet")
	_check(hud.ability_panel().visible and hud.ability_panel().columns == 1, "Ein belegter Slot nutzt allein den kompakten HUD-Platz")
	var empty_payload: Dictionary = hud.info_payload_for(hud.ability_buttons()[1])
	_check(empty_payload.is_empty(), "Unbelegter Slot stellt weder Anzeige noch Tooltipinhalt bereit")
	var no_slots_model: RunHUDViewModel = RunHUDViewModelScript.create(updated_vital, [], [], 25)
	_check(hud.apply_view_model(no_slots_model), "Leerer Fähigkeits-Snapshot wird sicher angewendet")
	await _settle()
	_check(not hud.ability_panel().visible, "Ohne belegte Fähigkeiten nimmt das HUD keinerlei Slotplatz ein")
	hud.ability_buttons()[0].pressed.emit()
	_check(ability_intents == [0, 1], "Ein technisch ausgelöster Leerslot emittiert keinen Gameplay-Intent")

	var stale: RunHUDViewModel = RunHUDViewModelScript.create(_vital_snapshot(), _stat_rows(), _ability_rows(), 8)
	_check(not hud.apply_view_model(stale), "Veraltete Presenterrevision wird abgewiesen")
	_check(hud.timer_value_label().text == "03:37", "Veraltetes Apply verändert keinen sichtbaren HUD-Wert")
	host.queue_free()
	await process_frame


func _assert_surface(control: Control, role: int, label_text: String) -> void:
	_check(control.get_meta(&"alveolus_surface_role", -1) == role, "%s verwendet die passende zentrale HUD-Surface-Rolle" % label_text)
	_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s blockiert kein Gameplay-Pointerevent" % label_text)


func _assert_critical_layout(hud: RunHUDOverlay, viewport_size: Vector2i) -> void:
	var controls: Array[Control] = [
		hud.stability_panel(),
		hud.shield_panel(),
		hud.defeat_research_reward_panel(),
		hud.timer_panel(),
		hud.boss_panel(),
		hud.run_stats_strip(),
		hud.pause_action(),
		hud.analysis_panel(),
		hud.ability_panel(),
	]
	for control in controls:
		if not control.visible:
			continue
		_check(_inside_viewport(control, viewport_size), "%s hält %s vollständig im Viewport" % [viewport_size, control.name])
	for first_index in range(controls.size()):
		var first := controls[first_index]
		if not first.visible:
			continue
		for second_index in range(first_index + 1, controls.size()):
			var second := controls[second_index]
			if not second.visible:
				continue
			_check(not first.get_global_rect().intersects(second.get_global_rect()), "%s hält %s und %s kollisionsfrei" % [viewport_size, first.name, second.name])
	_check(hud.ability_cards().all(func(card: Panel) -> bool: return _inside(card, hud.ability_panel())), "%s hält beide Fähigkeitsslots im Slotcontainer" % viewport_size)
	_check(hud.stat_rows().all(func(row: HBoxContainer) -> bool: return _inside(row, hud.run_stats_strip())), "%s schneidet keinen transparenten Runwert ab" % viewport_size)


func _vital_snapshot() -> Dictionary:
	return {
		"stability_current": 76.0,
		"stability_maximum": 100.0,
		"shield_current": 12.0,
		"shield_maximum": 20.0,
		"timer_text": "BOSS IN · 01:24",
		"round_time_text": "03:36",
		"defeat_research_reward": {
			"visible": true,
			"icon_id": &"research",
			"value": "+18",
			"accessible_name": "Forschungsgewinn bei Niederlage: 18",
		},
		"boss_visible": true,
		"boss_title": "Infektionsherd",
		"boss_current": 64.0,
		"boss_maximum": 100.0,
		"boss_phase": "Phase 2",
		"analysis_current": 7,
		"analysis_target": 12,
		"analysis_level": 3,
		"nested": {"mutable": true},
	}


func _stat_rows() -> Array:
	return [
		{"id": &"defense", "icon_id": &"defense_training", "value": "8 %", "accessible_name": "Effektive Verteidigung", "priority": 100},
		{"id": &"movement_speed", "icon_id": &"movement_training", "value": "300", "accessible_name": "Geschwindigkeit", "priority": 90},
		{"id": &"life_regeneration", "icon_id": &"life_regeneration", "value": "0,8/s", "accessible_name": "Regeneration", "priority": 80},
		{"id": &"experience_gain", "icon_id": &"experience_gain", "value": "+15 %", "accessible_name": "EXP-Multiplikator", "priority": 70},
		{"id": &"resistance_fire", "icon_id": &"damage_fire", "value": "0 %", "accessible_name": "Feuerresistenz", "priority": 60},
		{"id": &"resistance_water", "icon_id": &"damage_water", "value": "9 %", "accessible_name": "Wasserresistenz", "priority": 50},
		{"id": &"resistance_earth", "icon_id": &"damage_earth", "value": "5 %", "accessible_name": "Erdresistenz", "priority": 40},
		{"id": &"resistance_wind", "icon_id": &"damage_wind", "value": "-10 %", "accessible_name": "Windresistenz", "priority": 30},
		{"id": &"therapy_damage", "icon_id": &"treatment", "value": "16", "accessible_name": "Behandlungsschaden", "priority": 200},
		{"id": &"ability_damage", "icon_id": &"ability", "value": "38", "accessible_name": "Fähigkeitsschaden", "priority": 190},
	]


func _ability_rows() -> Array:
	return [
		{
			"slot": 1,
			"title": "Notfallhilfe",
			"effect_text": "Stellt Leben wieder her und erzeugt einen Schild.",
			"icon_id": &"ability_emergency_support",
			"occupied": true,
			"ready": false,
			"cooldown_remaining": 7.2,
			"cooldown_total": 12.0,
			"fact_rows": [
				{"label": "Abklingzeit", "value": "12 s"},
				{"label": "Heilung", "value": "24 Leben"},
			],
			"targeting": false,
			"key_glyph_text": "E",
		},
		{
			"slot": 0,
			"title": "Fokusfeld",
			"effect_text": "Priorisiert Ziele und verstärkt die Behandlung im Zielgebiet.",
			"icon_id": &"ability_focus_field",
			"occupied": true,
			"ready": true,
			"cooldown_remaining": 0.0,
			"cooldown_total": 10.0,
			"fact_rows": [
				{"label": "Abklingzeit", "value": "10 s"},
				{"label": "Radius", "value": "4"},
				{"label": "", "value": "100 %", "icon_kind": &"damage_water", "accessible_label": "Wasserschaden"},
			],
			"targeting": true,
			"key_glyph_text": "Q",
		},
	]


func _instance_ids(controls: Array) -> Array[int]:
	var result: Array[int] = []
	for control in controls:
		result.append((control as Control).get_instance_id())
	return result


func _row_populations(rows: Array[HBoxContainer]) -> Array[int]:
	var levels: Dictionary = {}
	var order: Array[int] = []
	for row in rows:
		var level := roundi(row.global_position.y)
		if not levels.has(level):
			levels[level] = 0
			order.append(level)
		levels[level] = int(levels[level]) + 1
	var result: Array[int] = []
	for level in order:
		result.append(int(levels[level]))
	return result


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


func _inside_viewport(control: Control, viewport_size: Vector2i) -> bool:
	var rect := control.get_global_rect()
	return (
		rect.position.x >= -0.5
		and rect.position.y >= -0.5
		and rect.end.x <= float(viewport_size.x) + 0.5
		and rect.end.y <= float(viewport_size.y) + 0.5
	)


func _focus_target_inside(source: Control, path: NodePath, root_control: Control) -> bool:
	if source == null or path.is_empty():
		return false
	var target := source.get_node_or_null(path) as Control
	return target != null and (target == root_control or root_control.is_ancestor_of(target))


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
		print("ALVEOLUS_RUN_HUD_OVERLAY_MODULE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
