extends SceneTree

const UnitBodyComponent = preload("res://scripts/ui/unit_body_2d.gd")

var assertions: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	_test_stability_and_run_outcomes()
	_test_analysis_leveling()
	_test_upgrade_application_and_caps()
	_test_upgrade_selection()
	_test_medical_boundaries()
	_test_pressure_guard_contract()
	_test_torus_topology()
	_test_object_highlighter_geometry()
	_test_unit_body_geometry()
	_test_batched_sprite_regions()
	_test_centered_icon_buttons()
	_test_projectile_discovery_timing()
	_test_upgrade_previews()
	_test_character_stat_rows()
	_test_level_catalog_and_run_config()
	_test_enemy_spawn_and_boss_phases()
	_test_discovery_catalog_and_queue()
	_test_meta_progression()
	_test_level_progression_and_records()
	_test_meta_save_roundtrip_and_recovery()
	if failures == 0:
		print("ALVEOLUS_TESTS_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_TESTS_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)

func _test_stability_and_run_outcomes() -> void:
	var config := ContentCatalog.create_run_config(ContentCatalog.level_definitions()[1], true)
	config.run_duration_seconds = 1.0
	config.final_deadline_seconds = 2.0
	config.initial_stability = 100.0
	var state := RunState.new()
	var outcomes: Array = []
	state.run_finished.connect(func(success: bool, reason: String) -> void: outcomes.append([success, reason]))
	state.reset(config)
	state.change_stability(-35.0)
	_assert_equal(state.stability, 65.0, "Schaden reduziert Stabilität")
	state.change_stability(80.0)
	_assert_equal(state.stability, 100.0, "Heilung bleibt am Maximum")
	state.increase_max_stability(14.0)
	_assert_equal(state.max_stability, 114.0, "Monitoring erhöht maximale Stabilität")
	_assert_equal(state.stability, 114.0, "Monitoring erhöht auch aktuelle Stabilität")
	state.tick(1.05)
	_assert_true(state.boss_spawned, "Infektionsherd wird nach der Eskalationsphase fällig")
	state.mark_boss_defeated()
	_assert_true(not state.active, "Boss-Sieg beendet den Run")
	_assert_true(bool(outcomes[-1][0]), "Boss-Sieg wird als Erfolg gemeldet")

	outcomes.clear()
	state.reset(config)
	state.change_stability(-999.0)
	_assert_equal(state.stability, 0.0, "Stabilität fällt nicht unter null")
	_assert_true(not bool(outcomes[-1][0]), "Stabilitätsverlust wird als Niederlage gemeldet")

	outcomes.clear()
	state.reset(config)
	state.tick(2.1)
	_assert_true(not state.active, "Therapiedeadline beendet den Run")
	_assert_true(not bool(outcomes[-1][0]), "Deadline wird als Niederlage gemeldet")

func _test_analysis_leveling() -> void:
	var state := RunState.new()
	state.reset(ContentCatalog.create_run_config(null, true))
	var requested_levels: Array[int] = []
	state.level_up_requested.connect(func(level: int) -> void: requested_levels.append(level))
	state.add_analysis(4)
	_assert_true(requested_levels.is_empty(), "Unterhalb der Schwelle entsteht kein Level-up")
	state.add_analysis(2)
	_assert_equal(requested_levels, [1], "Analyse fordert genau ein Level-up an")
	_assert_true(state.level_up_pending, "Level-up bleibt bis zur Auswahl pausiert")
	state.add_analysis(50)
	_assert_equal(requested_levels.size(), 1, "Während einer Auswahl entsteht keine zweite Anfrage")
	state.resolve_level_up()
	_assert_equal(requested_levels.size(), 2, "Überschüssige Analyse wird nach der Auswahl verarbeitet")

func _test_object_highlighter_geometry() -> void:
	var highlighter := ObjectHighlighter.new()
	var silhouette := PackedVector2Array([Vector2(10, 8), Vector2(70, 12), Vector2(62, 54), Vector2(14, 50)])
	highlighter.show_polygon(silhouette, Color.WHITE)
	_assert_equal(highlighter.shape, ObjectHighlighter.Shape.POLYGON, "Highlighter unterstützt Objekt-Silhouetten")
	_assert_equal(highlighter.bounds(), Rect2(10, 8, 60, 46), "Polygon-Umrandung berechnet ihre Grenzen")
	_assert_equal(highlighter.center(), Vector2(40, 31), "Polygon-Umrandung liefert einen stabilen Pfeilanker")
	highlighter.show_circle(Vector2(120, 90), 24.0, Color.WHITE)
	_assert_equal(highlighter.bounds(), Rect2(96, 66, 48, 48), "Kreis-Umrandung besitzt korrekte Zielgrenzen")
	highlighter.show_rect(Rect2(18, 22, 206, 7), Color.WHITE)
	_assert_equal(highlighter.bounds(), Rect2(18, 22, 206, 7), "UI-Umrandung folgt einem echten Rechteck")
	highlighter.clear()
	_assert_equal(highlighter.shape, ObjectHighlighter.Shape.NONE, "Highlighter lässt sich vollständig deaktivieren")
	highlighter.free()

func _test_unit_body_geometry() -> void:
	var body = UnitBodyComponent.new()
	body.position = Vector2(20, 12)
	body.configure_polygon(PackedVector2Array([Vector2(0, 0), Vector2(60, 0), Vector2(50, 40), Vector2(0, 40)]))
	_assert_equal(body.local_bounds(), Rect2(0, 0, 60, 40), "Unit-Körper berechnet seine lokale Silhouette")
	_assert_true(body.contains_parent_point(Vector2(30, 24)), "Unit-Körper übernimmt den Interaktionstest")
	_assert_true(not body.contains_parent_point(Vector2(90, 24)), "Interaktion endet außerhalb des Unit-Körpers")
	var transformed := body.contours_transformed(Transform2D(0.0, Vector2(100, 80)), 0.0)
	_assert_equal(transformed[0][0], Vector2(100, 80), "Unit-Körper lässt sich in den Zeichenraum des Highlighters übertragen")
	body.free()
	var alpha_body = UnitBodyComponent.new()
	alpha_body.position = Vector2(10, 20)
	var practice_texture := VisualAssetCatalog.campus_building(&"practice")
	alpha_body.configure_alpha_texture(practice_texture, Rect2(0, 0, 190, 178), 0.12)
	_assert_true(alpha_body.uses_alpha_texture(), "Gebäude-Unit verwendet die sichtbare Sprite-Alpha als Körper")
	_assert_true(alpha_body.contains_parent_point(Vector2(95, 100)), "Sichtbare Gebäudepixel sind interaktiv")
	_assert_true(not alpha_body.contains_parent_point(Vector2(2, 2)), "Transparente Spritebereiche gehören nicht zur Klickfläche")
	alpha_body.free()

func _test_batched_sprite_regions() -> void:
	var bacterium := VisualAssetCatalog.gameplay_batch_texture(&"pneumococcus")
	var cluster := VisualAssetCatalog.gameplay_batch_texture(&"bacterial_cluster")
	var sample := VisualAssetCatalog.gameplay_batch_texture(&"analysis_pickup")
	_assert_true(bacterium != null and cluster != null and sample != null, "Batch-Sprites werden als eigenständige Texturen erzeugt")
	_assert_equal(bacterium.get_width(), bacterium.get_height(), "Keimregion wird verzerrungsfrei auf eine quadratische Textur gepolstert")
	_assert_equal(cluster.get_width(), cluster.get_height(), "Bakteriengruppe wird verzerrungsfrei auf eine quadratische Textur gepolstert")
	_assert_true(not (bacterium is AtlasTexture) and not (cluster is AtlasTexture) and not (sample is AtlasTexture), "MultiMesh erhält keine ungefilterten Atlasregionen")
	_assert_true(bacterium == VisualAssetCatalog.gameplay_batch_texture(&"pneumococcus"), "Zugeschnittene Batch-Texturen werden wiederverwendet")
	_assert_true(VisualAssetCatalog.has_gameplay_visual(&"pneumococcus") and VisualAssetCatalog.has_gameplay_visual(&"analysis_pickup"), "Der Katalog erkennt explizit registrierte Gameplay-Grafiken")
	_assert_true(not VisualAssetCatalog.has_gameplay_visual(&"missing_visual") and not VisualAssetCatalog.has_gameplay_visual(&""), "Unbekannte und leere Grafik-IDs gelten nicht als registriert")
	_assert_true(VisualAssetCatalog.gameplay_sprite(&"missing_visual") == null, "Unbekannte Gameplay-IDs fallen nicht auf das Proben-Symbol zurück")
	_assert_true(VisualAssetCatalog.gameplay_batch_texture(&"") == null, "Eine leere Batch-ID erzeugt keine falsche Textur")
	var doctor_right := VisualAssetCatalog.doctor_frame(Vector2.RIGHT, 0, true)
	var doctor_left := VisualAssetCatalog.doctor_frame(Vector2.LEFT, 0, true)
	_assert_equal(Vector2i(doctor_right.get_width(), doctor_right.get_height()), Vector2i(30, 30), "Medical-Examiner-Frame wird ohne gelbe Rasterkante ausgeschnitten")
	_assert_true(doctor_right != doctor_left, "Medical Examiner verwendet richtungsabhängige Frames")

func _test_centered_icon_buttons() -> void:
	var button := IconTextButton.new()
	button.size = Vector2(184, 40)
	button.configure("ZUM CAMPUS", &"home", AlveolusVisualTheme.COBALT)
	_assert_true(button.text.is_empty(), "Icon-Buttons zeichnen keinen zweiten unabhängig zentrierten Buttontext")
	_assert_equal(button.content_center.anchor_left, 0.0, "Icon-Button-Inhalt beginnt am linken Buttonrand")
	_assert_equal(button.content_center.anchor_right, 1.0, "Icon-Button-Inhalt umfasst die vollständige Buttonbreite")
	_assert_true(button.content_row.get_parent() == button.content_center, "Icon und Text bilden eine gemeinsam zentrierte Layoutgruppe")
	button.free()

func _test_projectile_discovery_timing() -> void:
	var topology := ArenaTopology.new(Rect2(-1000, -700, 2000, 1400))
	var avatar := TherapyAvatar.new()
	avatar.configure(topology.bounds, PlayerStats.new(), topology)
	var enemy := InfectionEnemy.new()
	enemy.configure(ContentCatalog.enemy_definitions()[&"pneumococcus"], avatar, topology)
	enemy.position = Vector2(220, 0)
	var projectile := TherapyProjectile.new()
	projectile.position = Vector2.ZERO
	var announcements := [0]
	projectile.discovery_ready.connect(func(_projectile: TherapyProjectile) -> void: announcements[0] += 1)
	projectile.configure(enemy, 18.0, topology, true)
	projectile._physics_process(0.03)
	projectile._physics_process(0.03)
	_assert_equal(announcements[0], 0, "Therapiehinweis erscheint nicht unsichtbar am Avatar")
	projectile._physics_process(0.03)
	_assert_equal(announcements[0], 0, "Langsamer Impuls löst den Hinweis nicht vor dem sichtbaren Abstand aus")
	projectile._physics_process(0.03)
	_assert_equal(announcements[0], 1, "Therapiehinweis erscheint bei einem sichtbaren Projektil")
	_assert_true(projectile.position.length() >= 52.0, "Markiertes Projektil hat sichtbaren Abstand zum Avatar")
	projectile.free()
	enemy.free()
	avatar.free()

func _test_upgrade_application_and_caps() -> void:
	var stats := PlayerStats.new()
	var definitions := ContentCatalog.upgrade_definitions()
	var potency: UpgradeDefinition = _find_upgrade(definitions, &"potency")
	var rhythm: UpgradeDefinition = _find_upgrade(definitions, &"rhythm")
	_assert_true(stats.apply_upgrade(potency), "Wirksamkeitsupgrade kann angewendet werden")
	_assert_equal(stats.therapy_damage, 20.0, "Wirksamkeitsupgrade verändert den Schaden ganzzahlig")
	stats.apply_upgrade(potency)
	stats.apply_upgrade(potency)
	_assert_true(stats.apply_upgrade(potency), "Schadensupgrades bleiben über die frühere Maximalstufe hinaus sammelbar")
	_assert_equal(stats.upgrade_pick_count(potency), 4, "Endloses Schadensupgrade zählt nur seine Familienwahlen")
	for index in range(3):
		stats.apply_upgrade(rhythm)
	_assert_true(stats.therapy_cooldown >= 0.22, "Therapieintervall unterschreitet nicht das Sicherheitslimit")

func _test_upgrade_selection() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var selected := ContentCatalog.choose_upgrades({}, rng, 3, true)
	_assert_equal(selected.size(), 3, "Drei Upgrade-Karten werden gewählt")
	var ids := {}
	var paths := {}
	for definition in selected:
		ids[definition.id] = true
		paths[definition.path] = true
	_assert_equal(ids.size(), 3, "Upgrade-Karten sind eindeutig")
	_assert_equal(paths.size(), 3, "Erste Auswahl nutzt alle drei aktiven Ausbaupfade")

func _test_medical_boundaries() -> void:
	var treatments := TreatmentDefinition.catalog()
	_assert_equal(treatments[&"treatment_precision"].damage_profile.dominant_type_id(), &"water", "Präzise Behandlung verwendet Wasserschaden")
	_assert_equal(treatments[&"treatment_spread"].damage_profile.dominant_type_id(), &"fire", "Streuimpuls verwendet Feuerschaden")
	_assert_equal(treatments[&"treatment_pierce"].damage_profile.dominant_type_id(), &"wind", "Durchdringender Impuls verwendet Windschaden")
	var enemies := ContentCatalog.enemy_definitions()
	_assert_true(enemies.has(&"pneumococcus") and enemies.has(&"bacterial_cluster"), "Antibiotischer Fall enthält bakterielle Gegner")
	_assert_true(enemies[&"pneumococcus"].base_damage > 0.0, "Gegner besitzen typisierten Basisschaden")

func _test_pressure_guard_contract() -> void:
	var state := RunState.new()
	state.reset(ContentCatalog.create_run_config(null, true))
	state.add_analysis(5)
	_assert_true(state.level_up_pending, "Level-up-Pause markiert den Zustand vor weiteren Kontakttreffern")

func _test_torus_topology() -> void:
	var topology := ArenaTopology.new(Rect2(-100.0, -50.0, 200.0, 100.0))
	_assert_equal(topology.wrap_position(Vector2(101.0, 51.0)), Vector2(-99.0, -49.0), "Positionen umlaufen beide Arenaränder")
	_assert_equal(topology.wrap_position_if_needed(Vector2(101.0, 51.0)), Vector2(-99.0, -49.0), "Schneller Randwechsel entspricht der allgemeinen Torusberechnung")
	_assert_equal(topology.shortest_delta(Vector2(95.0, 0.0), Vector2(-95.0, 0.0)), Vector2(10.0, 0.0), "Torus nutzt horizontal den kürzesten Weg")
	_assert_equal(topology.shortest_delta(Vector2(0.0, -46.0), Vector2(0.0, 47.0)), Vector2(0.0, -7.0), "Torus nutzt vertikal den kürzesten Weg")
	_assert_equal(topology.distance_squared(Vector2(95.0, 0.0), Vector2(-95.0, 0.0)), 100.0, "Torus-Distanz stimmt über die Naht")

func _test_upgrade_previews() -> void:
	var stats := PlayerStats.new()
	var definitions := ContentCatalog.upgrade_definitions()
	var targets: UpgradeDefinition = _find_upgrade(definitions, &"parallel_sites")
	var rhythm: UpgradeDefinition = _find_upgrade(definitions, &"rhythm")
	var immune_damage: UpgradeDefinition = _find_upgrade(definitions, &"phagocytosis")
	var target_preview := stats.preview_upgrade(targets)
	_assert_equal(target_preview.effect_text, "+1 Projektil", "Zielupgrade benennt den exakten Projektilzuwachs")
	_assert_equal(target_preview.before_after_text, "1  >  2 Projektile", "Projektilupgrade zeigt Vorher und Nachher")
	var rhythm_preview := stats.preview_upgrade(rhythm)
	_assert_equal(rhythm_preview.effect_text, "+3 % Attack Speed", "Rhythmusupgrade verwendet einen linearen prozentualen Bonus")
	_assert_equal(rhythm_preview.before_after_text, "0 %  >  3 %", "Attack-Speed-Ausbau zeigt ausschließlich den akkumulierten Bonus")
	var immune_preview := stats.preview_upgrade(immune_damage)
	_assert_equal(immune_preview.effect_text, "+3 Schaden", "Common-Abwehrupgrade verwendet eine ganzzahlige Effektzeile")
	_assert_equal(immune_preview.before_after_text, "5 Schaden  >  8 Schaden", "Abwehrupgrade zeigt ganzzahlige Werte")

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var first := ContentCatalog.choose_upgrades({}, rng, 3, false)
	var excluded: Array[StringName] = []
	for definition in first:
		excluded.append(definition.id)
	var rerolled := ContentCatalog.choose_upgrades({}, rng, 3, false, excluded)
	var rerolled_ids: Dictionary = {}
	for definition in rerolled:
		rerolled_ids[definition.id] = true
	_assert_equal(rerolled_ids.size(), rerolled.size(), "Neuauswahl enthält keine doppelten Upgrades")
	for id in excluded:
		_assert_true(not rerolled_ids.has(id), "Neuauswahl vermeidet die zuvor sichtbaren Upgrades")

func _test_character_stat_rows() -> void:
	var stats := PlayerStats.new()
	var rows := stats.stat_rows(80.0, 90.0, 275.0)
	_assert_equal(rows.size(), 16, "Charakterwertemenü enthält alle relevanten dynamischen Werte")
	_assert_equal(_row_value(rows, "ALLGEMEIN", "Leben"), "80 / 90", "Aktuelles und maximales Leben werden gemeinsam angezeigt")
	var sections := stats.stat_sections(80.0, 90.0)
	_assert_equal(sections[0].id(), &"general", "Allgemeine Werte besitzen eine stabile Section-ID")
	_assert_equal(sections[1].id(), &"treatment:treatment_precision", "Behandlungswerte besitzen eine content-stabile Section-ID")
	_assert_equal(_row_value_by_id(sections[1].rows(), &"damage"), "13", "Behandlungsschaden entspricht dem echten Basiswert")
	var copied_rows := sections[1].rows()
	copied_rows[0]["value"] = "verändert"
	_assert_equal(_row_value_by_id(sections[1].rows(), &"damage"), "13", "Section-Zeilen werden defensiv kopiert")
	stats.immune_level = 1
	var compact := stats.compact_stat_text(80.0, 90.0)
	_assert_true(compact.contains("Schaden  13"), "Optionale HUD-Anzeige nutzt dieselben Charakterwerte")
	_assert_true(compact.contains("Abwehrzellen  2"), "Kompakte Anzeige aktualisiert Ausbauwerte")

func _test_level_catalog_and_run_config() -> void:
	var levels := ContentCatalog.level_definitions()
	_assert_equal(levels.size(), 4, "Levelkatalog enthält Intro und drei Hauptfälle")
	var expected_durations := [0.0, -1.0, -1.0, -1.0]
	var expected_boss_times := [0.0, 180.0, 180.0, 180.0]
	var expected_stability := [50.0, 50.0, 50.0, 50.0]
	for index in range(levels.size()):
		var level: LevelDefinition = levels[index]
		_assert_equal(level.order, index, "Levelreihenfolge ist datengetrieben und lückenlos")
		_assert_equal(level.total_seconds, expected_durations[index], "Gesamtdauer stimmt mit dem Levelplan überein")
		_assert_equal(level.boss_spawn_seconds, expected_boss_times[index], "Bosszeitpunkt stimmt mit dem Levelplan überein")
		_assert_equal(level.initial_stability, expected_stability[index], "Startstabilität stimmt mit dem Levelplan überein")
		var config := ContentCatalog.create_run_config(level)
		_assert_equal(config.run_duration_seconds, level.boss_spawn_seconds, "RunConfig übernimmt den Bosszeitpunkt")
		_assert_equal(config.final_deadline_seconds, level.total_seconds, "RunConfig übernimmt die Leveldeadline")
		_assert_true(not config.has_deadline(), "Intro und Hauptfälle besitzen keine Zeitniederlage")
	_assert_equal(levels[0].boss_health_multiplier, 0.09, "Intro verwendet den um weitere 50 Prozent reduzierten Boss")
	_assert_true(levels[0].boss_phase_minions.is_empty(), "Intro hat keine vollständige Bossphasenmechanik")
	_assert_equal(levels[3].boss_phase_minions, PackedInt32Array([6, 8]), "Fall 3 verwendet die geplanten Minion-Schübe")

func _test_enemy_spawn_and_boss_phases() -> void:
	var target := TherapyAvatar.new()
	get_root().add_child(target)
	var topology := ArenaTopology.new(Rect2(-500.0, -300.0, 1000.0, 600.0))
	var enemies := ContentCatalog.enemy_definitions()
	var regular := InfectionEnemy.new()
	regular.position = Vector2(271.0, -118.0)
	regular.configure(enemies[&"pneumococcus"], target, topology)
	get_root().add_child(regular)
	var health_before := regular.health
	regular.take_damage(999.0)
	_assert_equal(regular.health, health_before, "Gegner ist während der Materialisierung nicht treffbar")
	_assert_true(not regular.is_targetable(), "Spawntelegraph blockiert Zielsuche und Kontakt")
	regular._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_assert_true(regular.is_targetable(), "Gegner wird erst nach vollständiger Materialisierung aktiv")
	_assert_equal(regular.position, Vector2(271.0, -118.0), "Spawnposition bleibt vor dem ersten aktiven Frame erhalten")
	regular.take_damage(1.0)
	_assert_equal(regular.hit_reaction_amount(), 1.0, "Treffer startet die kurze Keimreaktion")
	regular._physics_process(InfectionEnemy.HIT_REACTION_SECONDS * 0.5)
	_assert_true(regular.hit_reaction_amount() > 0.0 and regular.hit_reaction_amount() < 1.0, "Keimreaktion klingt über mehrere Physikframes ab")
	regular._physics_process(InfectionEnemy.HIT_REACTION_SECONDS)
	_assert_equal(regular.hit_reaction_amount(), 0.0, "Trefferreaktion endet vollständig und hinterlässt keine Dauerskalierung")
	var defeat_count := [0]
	regular.defeated.connect(func(_enemy: InfectionEnemy, _analysis: int, _boss: bool) -> void: defeat_count[0] += 1)
	regular.take_damage(999.0)
	_assert_equal(defeat_count[0], 1, "Besiegte Gegner verschwinden ohne verzögerte Todesanimation")
	_assert_equal(InfectionEnemy.DEATH_SECONDS, 0.0, "Todesanimation ist vollständig deaktiviert")

	var boss := InfectionEnemy.new()
	boss.position = Vector2(-190.0, 80.0)
	boss.configure(enemies[&"infection_focus"], target, topology, 1.0, 1.0, 1.0, PackedInt32Array([3, 4]))
	get_root().add_child(boss)
	boss._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	var requested: Array[int] = []
	boss.minions_requested.connect(func(_origin: Vector2, count: int) -> void: requested.append(count))
	boss.take_damage(boss.max_health * 0.31)
	boss.take_damage(boss.max_health * 0.31)
	boss.take_damage(1.0)
	_assert_equal(requested, [3, 4], "Bossphasen lösen bei 70 und 40 Prozent genau einmal aus")
	regular.queue_free()
	boss.queue_free()
	target.queue_free()

func _test_discovery_catalog_and_queue() -> void:
	var discoveries := ContentCatalog.discovery_definitions()
	_assert_true(discoveries.size() >= 10, "Entdeckungskatalog enthält Gegner, Therapie und Praxismechaniken")
	for enemy in ContentCatalog.enemy_definitions().values():
		_assert_true(enemy.discovery_id != &"", "Jede Gegnerdefinition besitzt eine discovery_id")
		_assert_true(discoveries.has(enemy.discovery_id), "Jede Gegner-discovery_id verweist auf einen gültigen Eintrag")
	var seen: Dictionary = {}
	var manager := DiscoveryManager.new()
	manager.configure(discoveries, seen)
	_assert_true(manager.request(&"analysis_pickup"), "Neue Entdeckung wird in die Warteschlange aufgenommen")
	_assert_true(manager.request(&"pneumococcus"), "Zweite Entdeckung wird geordnet aufgenommen")
	var first := manager.take_next()
	_assert_equal(first["id"], &"pneumococcus", "Höhere Priorität wird zuerst erklärt")
	manager.complete_active()
	_assert_true(seen.has(&"pneumococcus"), "Abgeschlossene Entdeckung wird spielstandweit markiert")
	_assert_true(not manager.request(&"pneumococcus"), "Gesehene Entdeckung erscheint nicht erneut")

func _test_level_progression_and_records() -> void:
	var meta := MetaProgressionState.new(func() -> int: return 250000)
	meta.reset_defaults(250000)
	var levels := ContentCatalog.level_definitions()
	_assert_true(meta.is_level_unlocked(0), "Neuer Spielstand startet mit freigeschaltetem Intro")
	_assert_true(not meta.is_level_unlocked(1), "Fall 1 ist vor dem Intro-Sieg gesperrt")
	_assert_true(meta.register_level_result(levels[0], true, 51.0, 3, 18), "Intro-Sieg schaltet exakt den nächsten Fall frei")
	_assert_equal(meta.highest_unlocked_level, 1, "Nach Intro ist nur Fall 1 zusätzlich frei")
	_assert_true(not meta.register_level_result(levels[0], true, 49.0, 4, 22), "Intro-Wiederholung schaltet keinen weiteren Fall frei")
	var intro_record := meta.get_level_record(&"intro")
	_assert_equal(intro_record.attempts, 2, "Wiederholungen werden als Versuche gespeichert")
	_assert_equal(intro_record.victories, 2, "Wiederholte Siege werden gespeichert")
	_assert_equal(intro_record.best_time, 49.0, "Beste Siegzeit wird aktualisiert")
	_assert_equal(intro_record.highest_analysis, 4, "Höchste Analysestufe wird gespeichert")
	_assert_equal(intro_record.best_defeats, 22, "Höchste Erregerzahl wird gespeichert")
	meta.register_level_result(levels[1], false, 120.0, 5, 45)
	_assert_equal(meta.highest_unlocked_level, 1, "Niederlagen schalten kein Level frei")
	var reward_before := meta.research_points
	var repeated_reward := meta.award_run(true, 60.0, 2, 20, 0.25)
	_assert_equal(repeated_reward, roundi(float(2 + 2 + 1 + 12) * 0.25 * 2.5), "Intro-Wiederholung verwendet den global erhöhten Forschungsgewinn")
	_assert_equal(meta.research_points, reward_before + repeated_reward, "Belohnungsmultiplikator wird genau einmal gutgeschrieben")

func _test_meta_progression() -> void:
	var current_time := [100000]
	var meta := MetaProgressionState.new(func() -> int: return current_time[0])
	meta.reset_defaults(current_time[0])
	current_time[0] += 4 * 60 * 60
	meta.accrue_time()
	_assert_equal(meta.claimable_research(), 60, "Vier Stunden ergeben nach der Erhöhung 60 passive Forschung")
	_assert_equal(meta.claim_passive(), 60, "Passive Forschung wird exakt einmal abgeholt")
	_assert_equal(meta.claim_passive(), 0, "Passive Forschung kann nicht doppelt abgeholt werden")

	meta.reset_defaults(current_time[0])
	current_time[0] += 12 * 60 * 60
	meta.accrue_time()
	_assert_equal(meta.claimable_research(), 120, "Offline-Forschung ist auf acht Stunden mit erhöhtem Ertrag begrenzt")
	var bank_before_rollback := meta.passive_seconds
	current_time[0] -= 24 * 60 * 60
	meta.accrue_time()
	_assert_equal(meta.passive_seconds, bank_before_rollback, "Zurückgestellte Systemzeit erzeugt keinen Ertrag")

	current_time[0] = 200000
	meta.reset_defaults(current_time[0])
	var jobs := ContentCatalog.clinic_job_definitions()
	var short_job: ClinicJobDefinition = jobs[&"short_review"]
	_assert_true(meta.start_job(short_job), "Ein Klinikfall kann gestartet werden")
	_assert_true(not meta.start_job(jobs[&"follow_up"]), "Ein zweiter Klinikfall kann nicht parallel starten")
	current_time[0] += short_job.duration_seconds - 1
	_assert_true(not meta.is_job_complete(), "Klinikfall endet nicht zu früh")
	current_time[0] += 1
	_assert_equal(meta.claim_job(jobs), 15, "Abgeschlossener Kurzbefund erhält den globalen Forschungsfaktor")
	_assert_equal(meta.claim_job(jobs), 0, "Klinikfall kann nicht doppelt abgeholt werden")

	meta.research_points = 2000
	var research := ContentCatalog.research_definitions()
	var reserve: ResearchDefinition = _find_research(research, &"stability_reserve")
	_assert_true(meta.purchase(reserve), "Forschungsknoten kann gekauft werden")
	_assert_equal(meta.research_points, 1950, "Erster Forschungsrang kostet 50")
	meta.purchase(reserve)
	meta.purchase(reserve)
	_assert_true(not meta.purchase(reserve), "Forschungsknoten respektiert seine Maximalstufe")
	_assert_equal(meta.rank(&"stability_reserve"), 3, "Forschungsrang wird dauerhaft gezählt")

	var reward_meta := MetaProgressionState.new(func() -> int: return current_time[0])
	reward_meta.reset_defaults(current_time[0])
	_assert_equal(reward_meta.award_run(true, 600.0, 15, 200), 93, "Run-Belohnung deckelt alle Leistungsbestandteile und skaliert sie global")
	_assert_equal(MetaProgressionState.calculate_run_reward(true, 600.0, 15, 200, 1.0, 1), 116, "Ein besiegter Boss erhöht die Endbelohnung um 25 Prozent")
	_assert_equal(MetaProgressionState.calculate_run_reward(true, 600.0, 15, 200, 1.0, 2), 139, "Zwei besiegte Bosse erhöhen die Endbelohnung additiv um 50 Prozent")
	_assert_equal(reward_meta.lifetime_runs, 1, "Beendeter Run wird genau einmal gezählt")

func _test_meta_save_roundtrip_and_recovery() -> void:
	var path := "user://alveolus_meta_test.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var source := MetaProgressionState.new(func() -> int: return 300000)
	source.reset_defaults(300000)
	source.research_points = 123
	source.research_ranks[&"therapy_precision"] = 2
	source.mark_prologue_seen()
	source.mark_discovery_seen(&"pneumococcus")
	source.mark_intro_skipped()
	source.set_tutorial_step(&"movement")
	source.show_run_stats = true
	source.register_level_result(ContentCatalog.level_definitions()[0], true, 54.0, 3, 20)
	var repository := MetaSaveRepository.new(path)
	_assert_true(repository.save(source), "Meta-Spielstand wird als JSON gespeichert")
	var loaded := MetaProgressionState.new(func() -> int: return 300000)
	_assert_true(repository.load_into(loaded), "Meta-Spielstand kann wieder geladen werden")
	_assert_equal(loaded.research_points, 123, "Forschungsstand überlebt den Savegame-Roundtrip")
	_assert_equal(loaded.rank(&"therapy_precision"), 2, "StringName-Forschungsränge überleben JSON")
	_assert_true(loaded.prologue_seen, "Prologstatus überlebt den Savegame-Roundtrip")
	_assert_equal(loaded.highest_unlocked_level, 1, "Level-Freischaltung überlebt den Savegame-Roundtrip")
	_assert_equal(loaded.get_level_record(&"intro").best_time, 54.0, "Levelrekorde überleben den Savegame-Roundtrip")
	_assert_true(loaded.has_seen_discovery(&"pneumococcus"), "Entdeckungen überleben den Savegame-Roundtrip")
	_assert_true(loaded.intro_skipped, "Intro-Überspringen überlebt den Savegame-Roundtrip")
	_assert_true(bool(loaded.tutorial_status.get(&"movement", false)), "Tutorialstatus überlebt den Savegame-Roundtrip")
	_assert_true(loaded.show_run_stats, "Anzeigeeinstellung für Charakterwerte überlebt den Savegame-Roundtrip")

	var version_two := FileAccess.open(path, FileAccess.WRITE)
	version_two.store_string(JSON.stringify({
		"version": 2,
		"research_points": 88,
		"passive_seconds": 1200.0,
		"last_seen_unix": 300000,
		"active_job_id": "follow_up",
		"job_started_at": 299000,
		"job_finishes_at": 301000,
		"research_ranks": {"therapy_precision": 1},
		"lifetime_runs": 4,
		"prologue_seen": true,
		"highest_unlocked_level": 2,
		"level_records": {"localized_focus": {"attempts": 2, "victories": 1, "best_time": 140.0, "highest_analysis": 5, "best_defeats": 40}}
	}))
	version_two.close()
	var migrated_v2 := MetaProgressionState.new(func() -> int: return 300000)
	_assert_true(repository.load_into(migrated_v2), "Savegame-Version 2 wird automatisch auf Version 3 migriert")
	_assert_equal(migrated_v2.research_points, 88, "V2-Migration bewahrt Forschung")
	_assert_equal(migrated_v2.highest_unlocked_level, 2, "V2-Migration bewahrt Level-Freischaltungen")
	_assert_equal(migrated_v2.get_level_record(&"localized_focus").victories, 1, "V2-Migration bewahrt Levelrekorde")
	_assert_true(migrated_v2.seen_discovery_ids.is_empty(), "V2-Migration erfindet keine Entdeckungen")
	_assert_true(not migrated_v2.show_run_stats, "Ältere Spielstände starten mit ausgeblendeten Charakterwerten")

	var version_one := FileAccess.open(path, FileAccess.WRITE)
	version_one.store_string(JSON.stringify({
		"version": 1,
		"research_points": 77,
		"passive_seconds": 7200.0,
		"last_seen_unix": 300000,
		"active_job_id": "short_review",
		"job_started_at": 299000,
		"job_finishes_at": 301000,
		"research_ranks": {"sample_logistics": 2},
		"lifetime_runs": 9
	}))
	version_one.close()
	var migrated := MetaProgressionState.new(func() -> int: return 300000)
	_assert_true(repository.load_into(migrated), "Savegame-Version 1 wird automatisch migriert")
	_assert_equal(migrated.research_points, 77, "Migration bewahrt vorhandene Forschung")
	_assert_equal(migrated.rank(&"sample_logistics"), 2, "Migration bewahrt Forschungsränge")
	_assert_equal(migrated.active_job_id, &"short_review", "Migration bewahrt den aktiven Klinikfall")
	_assert_equal(migrated.highest_unlocked_level, 0, "Migrierte Spielstände beginnen beim Intro")
	_assert_true(not migrated.prologue_seen, "Migrierte Spielstände nehmen keinen Prologabschluss an")

	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("{kaputt")
	corrupt.close()
	var recovered := MetaProgressionState.new(func() -> int: return 300000)
	_assert_true(not repository.load_into(recovered), "Beschädigtes JSON wird erkannt")
	_assert_equal(recovered.research_points, 0, "Beschädigtes JSON fällt auf einen leeren Stand zurück")
	var unknown := FileAccess.open(path, FileAccess.WRITE)
	unknown.store_string('{"version":99,"research_points":999}')
	unknown.close()
	var unknown_state := MetaProgressionState.new(func() -> int: return 300000)
	_assert_true(not repository.load_into(unknown_state), "Unbekannte Savegame-Version wird erkannt")
	_assert_equal(unknown_state.research_points, 0, "Unbekannte Savegame-Version fällt auf Standardwerte zurück")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _find_upgrade(definitions: Array[UpgradeDefinition], id: StringName) -> UpgradeDefinition:
	for definition in definitions:
		if definition.id == id:
			return definition
	return null

func _find_research(definitions: Array[ResearchDefinition], id: StringName) -> ResearchDefinition:
	for definition in definitions:
		if definition.id == id:
			return definition
	return null

func _row_value(rows: Array[Dictionary], group: String, label: String) -> String:
	for row in rows:
		if String(row.get("group", "")) == group and String(row.get("label", "")) == label:
			return String(row.get("value", ""))
	return ""

func _row_value_by_id(rows: Array[Dictionary], id: StringName) -> String:
	for row in rows:
		if StringName(str(row.get("id", ""))) == id:
			return String(row.get("value", ""))
	return ""

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual == expected:
		return
	failures += 1
	printerr("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
