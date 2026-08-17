class_name ContentCatalog
extends RefCounted

static func create_run_config(level: LevelDefinition = null, quick_run: bool = false) -> RunConfig:
	var selected := level_definitions()[0] if level == null else level
	return RunConfig.from_level(selected, quick_run)

static func level_definitions() -> Array[LevelDefinition]:
	var all_traits: Array[StringName] = [&"high_load", &"mobile_pathogens", &"resistant_pathogens", &"fragile_condition"]
	var all_findings: Array[StringName] = [&"grouping", &"acceleration", &"pressure_surges", &"hidden_nests"]
	return [
		LevelDefinition.create(
			&"intro", 0, "Das Lungenmodell", "Einführung · die Grundlagen", true,
			0.0, 0.0, 120.0, 1.10, 0.55, 0.55, 0.70, 0.80, 0.50, 0.0, 0.05,
			0.18, PackedInt32Array(), 1.0,
			"Lerne Bewegung, automatische Behandlung, Proben und die drei Ausbauwege kennen.",
			"Das erste Lungenmodell ist stabilisiert. Die regulären Patientenfälle stehen nun bereit.",
			"Das Modell blieb instabil. Wiederhole die Einführung in deinem eigenen Tempo."
		).configure_case_variation([], [], 0),
		LevelDefinition.create(
			&"localized_focus", 1, "lol - name fehlt", "Fall 01 · lokalisierter Pneumokokkenherd", false,
			180.0, 135.0, 90.0, 0.62, 0.14, 1.15, 1.70, 1.08, 1.25, 0.10, 0.28,
			0.75, PackedInt32Array([3, 4]), 1.0,
			"Ein lokaler Bakterienherd belastet den Patienten. Stoppe ihn, bevor der Zustand auf null fällt.",
			"Der lokalisierte Infektionsherd wurde kontrolliert.",
			"Die Infektionslast konnte in diesem Versuch nicht ausreichend kontrolliert werden."
		).configure_case_variation(all_traits, all_findings, 30),
		LevelDefinition.create(
			&"spreading_infection", 2, "Die Ausbreitung", "Fall 02 · bakterielle Pneumonie", false,
			240.0, 180.0, 85.0, 0.52, 0.11, 1.35, 2.05, 1.16, 1.45, 0.18, 0.38,
			1.05, PackedInt32Array([4, 6]), 1.35,
			"Mehrere Bakteriengruppen breiten sich gleichzeitig aus. Bewegung und Ausbau werden jetzt entscheidend.",
			"Die ausbreitende Infektion wurde eingegrenzt.",
			"Die Ausbreitung überstieg den verfügbaren Zustand."
		).configure_case_variation(all_traits, all_findings, 42),
		LevelDefinition.create(
			&"severe_pneumonia", 3, "Schwerer Verlauf", "Fall 03 · schwere bakterielle Pneumonie", false,
			300.0, 225.0, 80.0, 0.44, 0.09, 1.55, 2.40, 1.24, 1.65, 0.25, 0.48,
			1.35, PackedInt32Array([6, 8]), 1.70,
			"Die Belastung steigt schnell. Du brauchst einen starken Ausbau und konsequente Bewegung.",
			"Auch der schwere Infektionsverlauf wurde kontrolliert.",
			"Der schwere Verlauf blieb außerhalb des kontrollierbaren Therapiefensters."
		).configure_case_variation(all_traits, all_findings, 55)
	]

static func tutorial_hint_definitions() -> Dictionary:
	return {
		&"movement": TutorialHintDefinition.create(&"movement", &"run_started", "Im Lungenmodell bewegen", "Bewege den Arzt mit WASD oder den Pfeiltasten. Gegnerkontakt senkt den Zustand."),
		&"therapy": TutorialHintDefinition.create(&"therapy", &"first_shot", "Behandlung arbeitet automatisch", "Die Behandlung wählt ein nahes Bakterium selbstständig aus."),
		&"analysis": TutorialHintDefinition.create(&"analysis", &"first_analysis", "Proben aufnehmen", "Proben sind Erfahrungspunkte. Eine volle Leiste erhöht dein Level und ermöglicht einen Ausbau."),
		&"upgrade": TutorialHintDefinition.create(&"upgrade", &"first_upgrade", "Drei Wege", "Behandlung verursacht direkten Schaden, Abwehr schützt den Nahbereich und Atemhilfe stabilisiert den Zustand."),
		&"boss": TutorialHintDefinition.create(&"boss", &"boss_spawned", "Infektionsherd", "Kontrolliere den Infektionsherd vor Ablauf der verbleibenden Behandlungszeit.")
	}

static func enemy_definitions() -> Dictionary:
	return {
		&"pneumococcus": EnemyDefinition.create(
			&"pneumococcus", "Bakterium", 22.0, 92.0, 2.2, 1, 18.0, Color("72b64a"), false, &"pneumococcus", &"pneumococcus", "Pneumokokke"
		),
		&"bacterial_cluster": EnemyDefinition.create(
			&"bacterial_cluster", "Bakteriengruppe", 74.0, 55.0, 5.0, 4, 30.0, Color("4e9338"), false, &"bacterial_cluster", &"bacterial_cluster", "Bakterienverband"
		),
		&"minor_focus": EnemyDefinition.create(
			&"minor_focus", "Kleiner Herd", 180.0, 0.0, 0.0, 8, 38.0, Color("9a5bbb"), false, &"minor_focus", &"infection_focus", "Kleiner Infektionsherd"
		),
		&"infection_focus": EnemyDefinition.create(
			&"infection_focus", "Infektionsherd", 2200.0, 34.0, 9.0, 30, 72.0, Color("9a5bbb"), true, &"infection_focus", &"infection_focus", "Lokaler Infektionsherd"
		)
	}

static func discovery_definitions() -> Dictionary:
	var enemies := enemy_definitions()
	var bacterium: EnemyDefinition = enemies[&"pneumococcus"]
	var group: EnemyDefinition = enemies[&"bacterial_cluster"]
	var minor_focus: EnemyDefinition = enemies[&"minor_focus"]
	var focus: EnemyDefinition = enemies[&"infection_focus"]
	return {
		&"pneumococcus": DiscoveryDefinition.create(
			&"pneumococcus", &"enemy_materialized", "Bakterium",
			"Pneumokokken sind Bakterien, die unter anderem eine Lungenentzündung verursachen können.",
			_enemy_values_text(bacterium, "Schneller Einzelerreger"), &"enemy", 100, &"erreger", &"pneumococcus", "Pneumokokke"
		),
		&"bacterial_cluster": DiscoveryDefinition.create(
			&"bacterial_cluster", &"enemy_materialized", "Bakteriengruppe",
			"Der Verband steht vereinfacht für eine größere lokale bakterielle Belastung.",
			_enemy_values_text(group, "Langsam und widerstandsfähig"), &"enemy", 90, &"erreger", &"bacterial_cluster", "Bakterienverband"
		),
		&"infection_focus": DiscoveryDefinition.create(
			&"infection_focus", &"enemy_materialized", "Infektionsherd",
			"Der Infektionsherd ist eine spielerische Darstellung der konzentrierten bakteriellen Belastung.",
			"%s\nBoss · löst bei 70 %% und 40 %% Leben neue Bakterienschübe aus. Leben, Tempo und Schaden werden je Fall skaliert." % _enemy_values_text(focus, "Bossgegner", false), &"enemy", 110, &"erreger", &"infection_focus", "Lokaler Infektionsherd"
		),
		&"minor_focus": DiscoveryDefinition.create(
			&"minor_focus", &"enemy_materialized", "Kleiner Herd",
			"Ein kleiner Herd steht vereinfacht für eine zusätzliche lokale Bakterienquelle.",
			"%s\nBleibt stehen · setzt nach 20 Sekunden vier Bakterien frei, falls er nicht kontrolliert wird." % _enemy_values_text(minor_focus, "Nebenziel", false), &"enemy", 95, &"erreger", &"infection_focus", "Kleiner Infektionsherd"
		),
		&"analysis_pickup": DiscoveryDefinition.create(
			&"analysis_pickup", &"pickup_spawned", "Probe",
			"Eine Probe steht vereinfacht für verwertbare Informationen aus kontrollierten Erregern.",
			"Proben sind die Erfahrungspunkte eines Runs. Aufnehmen füllt die Leiste am unteren Rand; eine volle Leiste erhöht dein Level und ermöglicht einen Ausbau.", &"pickup", 80, &"grundlagen", &"analysis_pickup", "Analyse"
		),
		&"character_stats": DiscoveryDefinition.create(
			&"character_stats", &"catalog", "Arztwerte",
			"Der Arzt koordiniert die Behandlung im Lungenmodell. Er besitzt keine eigene Lebensleiste; der Zustand gehört zum Patienten.",
			"GRUNDWERTE\nBewegung 275 · Wirkung 18 · Intervall 0,82 s · Reichweite 470 · 1 Ziel · Probenradius 185. Forschung und Ausbauten verändern diese Werte.", &"none", 0, &"grundlagen", &"doctor", "Therapie-Avatar"
		),
		&"patient_stability": DiscoveryDefinition.create(
			&"patient_stability", &"run_started", "Zustand",
			"Die Anzeige bündelt den allgemeinen Zustand des Patienten zu einem verständlichen Spielwert.",
			"Gegnerkontakt senkt den Zustand. Bei 0 endet die Behandlung.", &"stability_bar", 120, &"grundlagen", &"patient_stability", "Patientenstabilität"
		),
		&"automatic_therapy": DiscoveryDefinition.create(
			&"automatic_therapy", &"first_shot", "Behandlung",
			"Die automatisch abgegebenen Wirkstoffe stellen eine abstrahierte antibakterielle Behandlung dar.",
			"Ziele werden automatisch gewählt. Du steuerst Bewegung und Ausbau.", &"projectile", 85, &"therapie", &"automatic_therapy", "Automatische antibiotische Therapie"
		),
		&"neutrophil_orbit": DiscoveryDefinition.create(
			&"neutrophil_orbit", &"upgrade_applied", "Abwehrzellen",
			"Neutrophile Granulozyten gehören zur angeborenen Immunabwehr und reagieren früh auf Bakterien.",
			"2 Abwehrzellen · 10 Wirkung alle 0,76 s · Radius 116.", &"avatar", 70, &"therapie", &"immune_cell", "Neutrophile Granulozyten"
		),
		&"supportive_oxygenation": DiscoveryDefinition.create(
			&"supportive_oxygenation", &"upgrade_applied", "Atemhilfe",
			"Oxygenierung unterstützt den Patienten, bekämpft Bakterien aber nicht direkt.",
			"Regeneriert 4 Zustand alle 5,65 s.", &"stability_bar", 70, &"therapie", &"supportive_oxygenation", "Supportive Oxygenierung"
		),
		&"boss_phases": DiscoveryDefinition.create(
			&"boss_phases", &"boss_phase", "Bossphase",
			"Die Phasen stehen für eine sprunghaft zunehmende lokale bakterielle Belastung.",
			"Bei 70 % und 40 % Bossstabilität erscheint je ein Minion-Schub.", &"boss_bar", 60, &"erreger"
		),
		&"research_reward": DiscoveryDefinition.create(
			&"research_reward", &"run_result", "Forschungsbelohnung",
			"Forschung fasst die aus einem Fall gewonnenen, dauerhaft nutzbaren Erkenntnisse zusammen.",
			"Wird im Forschungsgebäude für kleine dauerhafte Verbesserungen ausgegeben.", &"reward", 50, &"praxis"
		)
	}

static func is_discovery_unlocked_by_default(id: StringName) -> bool:
	return id == &"character_stats"

static func _enemy_values_text(definition: EnemyDefinition, role: String, add_scaling_note: bool = true) -> String:
	var samples := "%d Probe" % definition.analysis_value if definition.analysis_value == 1 else "%d Proben" % definition.analysis_value
	var text := "%s.\nGRUNDWERTE\n%s Leben · Tempo %s · %s Kontaktschaden · %s." % [
		role,
		_number_text(definition.max_health),
		_number_text(definition.speed),
		_number_text(definition.contact_damage),
		samples,
	]
	if add_scaling_note:
		text += " Die Werte können je Fall steigen."
	return text

static func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return ("%.1f" % value).replace(".", ",")

static func arena_visual_definitions() -> Dictionary:
	return {
		&"intro": ArenaVisualDefinition.create(&"intro", Color("b87b84"), Color("c99096"), Color("f2d1c4"), Color("74465b"), Color("da6f74"), 3101, 0.12, "res://assets/art/visual_restart/alveolar_tissue_day.png"),
		&"localized_focus": ArenaVisualDefinition.create(&"localized_focus", Color("b1717d"), Color("c5848e"), Color("efd0c2"), Color("704055"), Color("df665f"), 4202, 0.34, "res://assets/art/visual_restart/alveolar_tissue_day.png"),
		&"spreading_infection": ArenaVisualDefinition.create(&"spreading_infection", Color("a96878"), Color("bd7888"), Color("ecc7bd"), Color("63364f"), Color("e25f5d"), 5303, 0.56, "res://assets/art/visual_restart/alveolar_tissue_day.png"),
		&"severe_pneumonia": ArenaVisualDefinition.create(&"severe_pneumonia", Color("945c70"), Color("aa697e"), Color("e4bdb6"), Color("562f49"), Color("e04f58"), 6404, 0.78, "res://assets/art/visual_restart/alveolar_tissue_day.png")
	}

static func upgrade_definitions() -> Array[UpgradeDefinition]:
	var treatments: Array[StringName] = [&"treatment_precision", &"treatment_spread", &"treatment_pierce"]
	var abilities: Array[StringName] = [
		&"ability_focus_field", &"ability_emergency_support", &"ability_defense_burst",
		&"ability_treatment_line", &"ability_protection_field", &"ability_sample_pull",
	]
	return [
		_run_upgrade(&"potency", "Stärkerer Impuls", "+8 Wirkung pro Treffer.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"damage", 8.0, "Gezielte Wirksamkeit", treatments, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 8.0, &"delta", "Wirkung", "Wirkung", 18.0, 0, &"enemy", PackedStringArray(["treatment"])),
		_run_upgrade(&"rhythm", "Schnellere Impulse", "16 % häufigere Anwendung.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"cooldown_multiplier", 0.84, "Verlässlicher Therapierhythmus", treatments, [&"treatment", &"rhythm"], RunBuildState.TREATMENT_INTERVAL, &"multiply", 0.84, &"tempo", "Tempo", "Intervall", 0.82, 2, &"", PackedStringArray(["treatment"])),
		_run_upgrade(&"penetration", "Mehr Reichweite", "+85 Reichweite.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"range", 85.0, "Gewebegängigkeit", treatments, [&"treatment", &"range"], RunBuildState.TREATMENT_RANGE, &"add", 85.0, &"delta", "Reichweite", "Reichweite", 470.0, 0, &"enemy", PackedStringArray(["treatment"])),
		_run_upgrade(&"parallel_sites", "Zusätzliches Ziel", "Ein zusätzliches Ziel je Impuls.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"targets", 1.0, "Parallele Wirkorte", [&"treatment_precision"], [&"precise", &"targets"], RunBuildState.TREATMENT_TARGETS, &"add", 1.0, &"count", "Projektil", "Ziele", 1.0, 0, &"enemy", PackedStringArray(["precise"])),
		UpgradeDefinition.create(&"neutrophils", "Abwehrzellen", "Zwei Zellen schützen den Nahbereich.", UpgradeDefinition.Path.IMMUNE, 3, &"immune_level", 1.0, "Neutrophile Rekrutierung"),
		UpgradeDefinition.create(&"phagocytosis", "Stärkere Abwehr", "+6 Wirkung jeder Abwehrreaktion.", UpgradeDefinition.Path.IMMUNE, 3, &"immune_damage", 6.0, "Effiziente Phagozytose"),
		UpgradeDefinition.create(&"oxygenation", "Regelmäßige Atemhilfe", "Regeneriert regelmäßig Zustand.", UpgradeDefinition.Path.SUPPORT, 3, &"support_level", 1.0, "Unterstützende Oxygenierung"),
		UpgradeDefinition.create(&"monitoring", "Mehr Reserve", "+14 maximaler und aktueller Zustand.", UpgradeDefinition.Path.SUPPORT, 2, &"max_stability", 14.0, "Engmaschiges Monitoring"),
		UpgradeDefinition.create(&"analysis_radius", "Stärkere Anziehung", "Proben werden aus größerer Entfernung erfasst.", UpgradeDefinition.Path.SUPPORT, 2, &"pickup_range", 75.0, "Gezielte Probengewinnung"),

		# Behandlungsspezifische Angebote. Nur die vorbereitete Grundbehandlung
		# kann sie ziehen; allgemeine Abwehr/Atemhilfe bleibt weiterhin möglich.
		_run_upgrade(&"precision_refinement", "Ruhiger Fokus", "+18 % Wirkung.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 1.18, "Präzisionssteigerung", [&"treatment_precision"], [&"precise", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"multiply", 1.18, &"percent", "Wirkung", "Wirkung", 18.0, 1, &"enemy", PackedStringArray(["precise"])),
		_run_upgrade(&"spread_density", "Dichter Streuimpuls", "+1 Projektil.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 1.0, "Erweiterte Wirkverteilung", [&"treatment_spread"], [&"spread", &"area"], RunBuildState.TREATMENT_PROJECTILES, &"add", 1.0, &"count", "Projektil", "Projektile", 3.0, 0, &"enemy", PackedStringArray(["spread"])),
		_run_upgrade(&"spread_effect", "Kräftigere Streuung", "+3 Wirkung pro Projektil.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 3.0, "Breitenwirkung", [&"treatment_spread"], [&"spread", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 3.0, &"delta", "Wirkung", "Wirkung", 8.0, 0, &"enemy", PackedStringArray(["spread"])),
		_run_upgrade(&"pierce_depth", "Tieferer Impuls", "+2 Durchdringungen.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"run_modifier", 2.0, "Erhöhte Gewebegängigkeit", [&"treatment_pierce"], [&"piercing", &"line"], RunBuildState.TREATMENT_MAX_HITS, &"add", 2.0, &"count", "Durchdringungen", "Treffer", 4.0, 0, &"enemy", PackedStringArray(["piercing"])),
		_run_upgrade(&"pierce_effect", "Stärkere Linie", "+5 Wirkung pro Treffer.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 5.0, "Linienwirkung", [&"treatment_pierce"], [&"piercing", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 5.0, &"delta", "Wirkung", "Wirkung", 14.0, 0, &"enemy", PackedStringArray(["piercing"])),

		# Aktive Eingriffe verbessern nur tatsächlich vorbereitete Q/E-Slots.
		_run_upgrade(&"focus_duration", "Längerer Fokus", "+2 s Dauer.", UpgradeDefinition.Path.SUPPORT, 3, &"run_modifier", 2.0, "Fokusfeld-Dauer", [&"ability_focus_field"], [&"active", &"focus"], RunBuildState.ABILITY_DURATION, &"add", 2.0, &"seconds", "Dauer", "Dauer", 7.0, 1, &"ability", PackedStringArray(["active", "focus"])),
		_run_upgrade(&"focus_effect", "Klarer Fokus", "+12 % Fokuswirkung.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 1.12, "Fokusverstärkung", [&"ability_focus_field"], [&"active", &"focus", &"damage"], RunBuildState.MARKED_DAMAGE, &"multiply", 1.12, &"percent", "Fokuswirkung", "Faktor", 1.25, 2, &"ability", PackedStringArray(["focus", "marked"])),
		_run_upgrade(&"emergency_recovery", "Stärkere Notfallhilfe", "+5 Zustand.", UpgradeDefinition.Path.SUPPORT, 3, &"run_modifier", 5.0, "Akute Stabilisierung", [&"ability_emergency_support"], [&"active", &"support"], RunBuildState.ABILITY_RECOVERY, &"add", 5.0, &"delta", "Zustand", "Zustand", 14.0, 0, &"stability_bar", PackedStringArray(["active", "support"])),
		_run_upgrade(&"emergency_shield", "Mehr Schutz", "+4 Schutz.", UpgradeDefinition.Path.SUPPORT, 3, &"run_modifier", 4.0, "Schutzreserve", [&"ability_emergency_support"], [&"active", &"support", &"shield"], RunBuildState.ABILITY_SHIELD, &"add", 4.0, &"delta", "Schutz", "Schutz", 8.0, 0, &"stability_bar", PackedStringArray(["active", "support"])),
		_run_upgrade(&"burst_effect", "Kräftiger Abwehrstoß", "+14 Wirkung.", UpgradeDefinition.Path.IMMUNE, 3, &"run_modifier", 14.0, "Akute Immunreaktion", [&"ability_defense_burst"], [&"active", &"defense", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 14.0, &"delta", "Wirkung", "Wirkung", 42.0, 0, &"enemy", PackedStringArray(["active", "defense"])),
		_run_upgrade(&"burst_radius", "Breiter Abwehrstoß", "+30 Radius.", UpgradeDefinition.Path.IMMUNE, 2, &"run_modifier", 30.0, "Ausgedehnte Immunreaktion", [&"ability_defense_burst"], [&"active", &"defense", &"area"], RunBuildState.ABILITY_RADIUS, &"add", 30.0, &"delta", "Radius", "Radius", 150.0, 0, &"ability", PackedStringArray(["active", "defense", "area"])),
		_run_upgrade(&"line_effect", "Stärkere Behandlungslinie", "+18 Wirkung.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 18.0, "Linienverstärkung", [&"ability_treatment_line"], [&"active", &"line", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 18.0, &"delta", "Wirkung", "Wirkung", 55.0, 0, &"enemy", PackedStringArray(["active", "treatment", "line"])),
		_run_upgrade(&"line_width", "Breitere Behandlungslinie", "+16 Breite.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"run_modifier", 16.0, "Erweiterte Behandlungslinie", [&"ability_treatment_line"], [&"active", &"line", &"area"], RunBuildState.ABILITY_WIDTH, &"add", 16.0, &"delta", "Breite", "Breite", 38.0, 0, &"ability", PackedStringArray(["active", "treatment", "line"])),
		_run_upgrade(&"field_duration", "Längeres Schutzfeld", "+2 s Dauer.", UpgradeDefinition.Path.SUPPORT, 3, &"run_modifier", 2.0, "Verlängerte Schutzwirkung", [&"ability_protection_field"], [&"active", &"control", &"support"], RunBuildState.ABILITY_DURATION, &"add", 2.0, &"seconds", "Dauer", "Dauer", 6.0, 1, &"ability", PackedStringArray(["active", "support", "area", "control"])),
		_run_upgrade_multi(&"field_control", "Stärkeres Schutzfeld", "Gegner werden 15 % stärker gebremst.", UpgradeDefinition.Path.SUPPORT, 3, "Verstärkte Schutzwirkung", [&"ability_protection_field"], [&"active", &"control"], [
			{"stat_id": RunBuildState.ABILITY_ENEMY_SPEED, "operation": &"multiply", "value": 0.85, "required_tags": [&"control"]},
			{"stat_id": RunBuildState.ABILITY_CONTACT, "operation": &"multiply", "value": 0.85, "required_tags": [&"control"]},
		], RunBuildState.ABILITY_ENEMY_SPEED, &"percent", "Gegnertempo", "Faktor", 0.65, 2, &"ability", PackedStringArray(["active", "support", "area", "control"])),
		_run_upgrade(&"sample_pull_radius", "Weiter Probenzug", "+50 Radius.", UpgradeDefinition.Path.SUPPORT, 2, &"run_modifier", 50.0, "Erweiterte Probengewinnung", [&"ability_sample_pull"], [&"active", &"sample"], RunBuildState.ABILITY_RADIUS, &"add", 50.0, &"delta", "Radius", "Radius", 230.0, 0, &"ability", PackedStringArray(["active", "sample", "diagnosis"])),
		_run_upgrade(&"sample_diagnosis", "Schnellere Auswertung", "+25 % Befundfortschritt.", UpgradeDefinition.Path.SUPPORT, 3, &"run_modifier", 1.25, "Beschleunigte Befundung", [&"ability_sample_pull"], [&"active", &"sample", &"diagnosis"], RunBuildState.FINDING_PROGRESS, &"multiply", 1.25, &"percent", "Befundfortschritt", "Faktor", 1.0, 2, &"ability", PackedStringArray(["active", "sample", "diagnosis"])),
		_run_upgrade(&"active_readiness", "Schneller bereit", "12 % kürzere aktive Abklingzeiten.", UpgradeDefinition.Path.SUPPORT, 3, &"run_modifier", 0.88, "Einsatzbereitschaft", abilities, [&"active", &"rhythm"], RunBuildState.ACTIVE_COOLDOWN, &"multiply", 0.88, &"percent", "Abklingzeit", "Faktor", 1.0, 2, &"ability", PackedStringArray(["active"])),
	]

static func _run_upgrade(
	id: StringName, title: String, description: String, path: int, max_level: int,
	effect: StringName, magnitude: float, medical: String, requirements: Array[StringName], synergies: Array[StringName],
	stat: StringName, operation: StringName, value: float, preview_style: StringName, preview_label: String,
	comparison_label: String, fallback: float, decimals: int, target: StringName, context_tags: PackedStringArray
) -> UpgradeDefinition:
	return _run_upgrade_multi(
		id, title, description, path, max_level, medical, requirements, synergies,
		[{"stat_id": stat, "operation": operation, "value": value, "required_tags": context_tags}],
		stat, preview_style, preview_label, comparison_label, fallback, decimals, target, context_tags,
		effect, magnitude
	)

static func _run_upgrade_multi(
	id: StringName, title: String, description: String, path: int, max_level: int,
	medical: String, requirements: Array[StringName], synergies: Array[StringName], modifiers: Array[Dictionary],
	preview_stat: StringName, preview_style: StringName, preview_label: String, comparison_label: String,
	fallback: float, decimals: int, target: StringName, context_tags: PackedStringArray,
	effect: StringName = &"run_modifier", magnitude: float = 0.0
) -> UpgradeDefinition:
	var definition := UpgradeDefinition.create(id, title, description, path, max_level, effect, magnitude, medical)
	definition.configure_pool(requirements, synergies)
	definition.configure_modifiers(modifiers)
	definition.configure_preview(preview_stat, preview_style, preview_label, comparison_label, fallback, decimals, target, context_tags)
	return definition

static func clinic_job_definitions() -> Dictionary:
	return {
		&"short_review": ClinicJobDefinition.create(&"short_review", "Kurzbefund", 5 * 60, 6),
		&"follow_up": ClinicJobDefinition.create(&"follow_up", "Verlaufskontrolle", 20 * 60, 18),
		&"complex_case": ClinicJobDefinition.create(&"complex_case", "Komplexer Fall", 60 * 60, 42)
	}

static func research_definitions() -> Array[ResearchDefinition]:
	return [
		ResearchDefinition.create(&"stability_reserve", "Startreserve", "+3 Startzustand je Rang", PackedInt32Array([20, 45, 80]), &"max_stability", 3.0).configure_unlock(&"stability_reserve", &"passive"),
		ResearchDefinition.create(&"therapy_precision", "Ruhige Hand", "+2 % Basiswirkung je Rang", PackedInt32Array([25, 55, 95]), &"damage_multiplier", 0.02).configure_unlock(&"therapy_precision", &"passive"),
		ResearchDefinition.create(&"sample_logistics", "Probenmagnet", "+5 % Aufnahmeradius je Rang", PackedInt32Array([20, 45, 80]), &"pickup_multiplier", 0.05).configure_unlock(&"sample_logistics", &"passive"),
		ResearchDefinition.create(&"preanalysis", "Startprobe", "Jeder Run beginnt mit 2 / 5 Proben", PackedInt32Array([70]), &"initial_analysis", 2.0).configure_unlock(&"preanalysis", &"passive"),
		ResearchDefinition.create(&"second_opinion", "Zweitmeinung", "Einmal pro Run drei neue Upgrades wählen", PackedInt32Array([100]), &"upgrade_reroll", 1.0).configure_unlock(&"second_opinion", &"passive"),
		ResearchDefinition.create(&"unlock_spread_treatment", "Streuimpuls", "Schaltet die streuende Grundbehandlung frei", PackedInt32Array([60]), &"unlock", 1.0).configure_unlock(&"treatment_spread", &"treatment"),
		ResearchDefinition.create(&"unlock_piercing_treatment", "Durchdringender Impuls", "Schaltet die durchdringende Grundbehandlung frei", PackedInt32Array([100]), &"unlock", 1.0).configure_unlock(&"treatment_pierce", &"treatment"),
		ResearchDefinition.create(&"unlock_defense_burst", "Abwehrstoß", "Schaltet den aktiven Abwehrstoß frei", PackedInt32Array([50]), &"unlock", 1.0).configure_unlock(&"ability_defense_burst", &"ability"),
		ResearchDefinition.create(&"unlock_treatment_line", "Behandlungslinie", "Schaltet die aktive Behandlungslinie frei", PackedInt32Array([80]), &"unlock", 1.0).configure_unlock(&"ability_treatment_line", &"ability"),
		ResearchDefinition.create(&"unlock_protection_field", "Schutzfeld", "Schaltet das verlangsamende Schutzfeld frei", PackedInt32Array([70]), &"unlock", 1.0).configure_unlock(&"ability_protection_field", &"ability"),
		ResearchDefinition.create(&"unlock_sample_pull", "Probenzug", "Schaltet den aktiven Probenzug frei", PackedInt32Array([70]), &"unlock", 1.0).configure_unlock(&"ability_sample_pull", &"ability"),
		ResearchDefinition.create(&"quick_test", "Schnelltest", "+20 % Befundfortschritt", PackedInt32Array([55]), &"finding_multiplier", 0.20).configure_unlock(&"quick_test", &"passive"),
		ResearchDefinition.create(&"reserve_buffer", "Reservepuffer", "Atemhilfe kann bis zu 12 Schutz aufbauen", PackedInt32Array([75]), &"overheal_shield", 12.0).configure_unlock(&"reserve_buffer", &"passive"),
		ResearchDefinition.create(&"defense_readiness", "Abwehrbereitschaft", "Start mit zwei Abwehrzellen", PackedInt32Array([80]), &"initial_immune", 1.0).configure_unlock(&"defense_readiness", &"passive"),
		ResearchDefinition.create(&"deployment_routine", "Einsatzroutine", "8 % kürzere aktive Abklingzeiten", PackedInt32Array([95]), &"ability_cooldown_multiplier", 0.92).configure_unlock(&"deployment_routine", &"passive")
	]

static func loadout_module_definitions() -> Dictionary:
	return {
		&"treatment_precision": LoadoutModuleDefinition.create(&"treatment_precision", "Präziser Impuls", "Verfolgt ein einzelnes Ziel mit hoher Grundwirkung.", LoadoutModuleDefinition.Kind.TREATMENT, 2, [&"treatment", &"precision"], &"", true),
		&"treatment_spread": LoadoutModuleDefinition.create(&"treatment_spread", "Streuimpuls", "Trifft drei Ziele mit schwächeren Einzelimpulsen.", LoadoutModuleDefinition.Kind.TREATMENT, 2, [&"treatment", &"spread"], &"unlock_spread_treatment"),
		&"treatment_pierce": LoadoutModuleDefinition.create(&"treatment_pierce", "Durchdringender Impuls", "Durchquert mehrere Gegner in einer Linie.", LoadoutModuleDefinition.Kind.TREATMENT, 2, [&"treatment", &"pierce"], &"unlock_piercing_treatment"),
		&"ability_focus_field": LoadoutModuleDefinition.create(&"ability_focus_field", "Fokusfeld", "Priorisiert und verstärkt die Behandlung im Zielgebiet.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"focus", &"control"], &"", true),
		&"ability_emergency_support": LoadoutModuleDefinition.create(&"ability_emergency_support", "Notfallhilfe", "Stellt Zustand wieder her und erzeugt einen Schutzpuffer.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"support"], &"", true),
		&"ability_defense_burst": LoadoutModuleDefinition.create(&"ability_defense_burst", "Abwehrstoß", "Flächenwirkung und Rückstoß am Zielpunkt.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"damage", &"control"], &"unlock_defense_burst"),
		&"ability_treatment_line": LoadoutModuleDefinition.create(&"ability_treatment_line", "Behandlungslinie", "Durchdringende Wirkung in Cursorrichtung.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"damage", &"pierce"], &"unlock_treatment_line"),
		&"ability_protection_field": LoadoutModuleDefinition.create(&"ability_protection_field", "Schutzfeld", "Verlangsamt Gegner und verringert ihren Kontaktdruck.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"control", &"support"], &"unlock_protection_field"),
		&"ability_sample_pull": LoadoutModuleDefinition.create(&"ability_sample_pull", "Probenzug", "Zieht Proben an und beschleunigt kurz den Befund.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"samples", &"diagnosis"], &"unlock_sample_pull"),
		&"stability_reserve": LoadoutModuleDefinition.create(&"stability_reserve", "Startreserve", "+3 Startzustand je gekauftem Rang.", LoadoutModuleDefinition.Kind.PASSIVE, 1, [&"passive", &"support"], &"stability_reserve"),
		&"therapy_precision": LoadoutModuleDefinition.create(&"therapy_precision", "Ruhige Hand", "+2 % Grundwirkung je gekauftem Rang.", LoadoutModuleDefinition.Kind.PASSIVE, 1, [&"passive", &"treatment"], &"therapy_precision"),
		&"sample_logistics": LoadoutModuleDefinition.create(&"sample_logistics", "Probenmagnet", "+5 % Aufnahmeradius je gekauftem Rang.", LoadoutModuleDefinition.Kind.PASSIVE, 1, [&"passive", &"samples"], &"sample_logistics"),
		&"preanalysis": LoadoutModuleDefinition.create(&"preanalysis", "Startprobe", "Startet mit 2 / 5 Proben.", LoadoutModuleDefinition.Kind.PASSIVE, 1, [&"passive", &"samples"], &"preanalysis"),
		&"second_opinion": LoadoutModuleDefinition.create(&"second_opinion", "Zweitmeinung", "Erlaubt eine Neuauswahl pro Run.", LoadoutModuleDefinition.Kind.PASSIVE, 1, [&"passive", &"choice"], &"second_opinion"),
		&"quick_test": LoadoutModuleDefinition.create(&"quick_test", "Schnelltest", "+20 % Befundfortschritt.", LoadoutModuleDefinition.Kind.PASSIVE, 1, [&"passive", &"diagnosis"], &"quick_test"),
		&"reserve_buffer": LoadoutModuleDefinition.create(&"reserve_buffer", "Reservepuffer", "Überschüssige Atemhilfe wird zu Schutz.", LoadoutModuleDefinition.Kind.PASSIVE, 2, [&"passive", &"support", &"shield"], &"reserve_buffer"),
		&"defense_readiness": LoadoutModuleDefinition.create(&"defense_readiness", "Abwehrbereitschaft", "Startet mit zwei Abwehrzellen.", LoadoutModuleDefinition.Kind.PASSIVE, 2, [&"passive", &"immune"], &"defense_readiness"),
		&"deployment_routine": LoadoutModuleDefinition.create(&"deployment_routine", "Einsatzroutine", "Aktive Fähigkeiten laden 8 % schneller.", LoadoutModuleDefinition.Kind.PASSIVE, 2, [&"passive", &"active"], &"deployment_routine")
	}

static func case_trait_definitions() -> Dictionary:
	var all_levels: Array[StringName] = [&"localized_focus", &"spreading_infection", &"severe_pneumonia"]
	return {
		&"high_load": CaseTraitDefinition.create(&"high_load", "Hohe Keimlast", "Gegner erscheinen 15 % schneller, besitzen aber 10 % weniger Leben.", [{"stat_id": &"spawn_interval", "operation": &"multiply", "value": 0.85}, {"stat_id": &"enemy_health", "operation": &"multiply", "value": 0.90}], all_levels),
		&"mobile_pathogens": CaseTraitDefinition.create(&"mobile_pathogens", "Bewegliche Erreger", "Gegner bewegen sich 18 % schneller, verursachen aber 10 % weniger Kontaktdruck.", [{"stat_id": &"enemy_speed", "operation": &"multiply", "value": 1.18}, {"stat_id": &"contact_damage", "operation": &"multiply", "value": 0.90}], all_levels),
		&"resistant_pathogens": CaseTraitDefinition.create(&"resistant_pathogens", "Widerstandsfähige Erreger", "Gegner besitzen 25 % mehr Leben und bewegen sich 10 % langsamer.", [{"stat_id": &"enemy_health", "operation": &"multiply", "value": 1.25}, {"stat_id": &"enemy_speed", "operation": &"multiply", "value": 0.90}], all_levels),
		&"fragile_condition": CaseTraitDefinition.create(&"fragile_condition", "Fragiler Zustand", "Der Startzustand sinkt um 15; Atemhilfe wirkt 20 % stärker.", [{"stat_id": &"initial_stability", "operation": &"add", "value": -15.0}, {"stat_id": &"support_effect", "operation": &"multiply", "value": 1.20}], all_levels),
	}

static func finding_definitions() -> Dictionary:
	var all_levels: Array[StringName] = [&"localized_focus", &"spreading_infection", &"severe_pneumonia"]
	return {
		&"grouping": FindingDefinition.create(&"grouping", "Gruppenbildung", "Die Bakterienlast sammelt sich vermehrt in lokalen Verbänden.", "Bakteriengruppen treten deutlich häufiger auf.", FindingDefinition.Behavior.GROUPING, 0.18, [&"group_area", &"group_control", &"group_safety"], all_levels),
		&"acceleration": FindingDefinition.create(&"acceleration", "Beschleunigte Ausbreitung", "Die Belastung nimmt in der zweiten Hälfte schneller zu.", "Die Spawnkurve verschärft sich ab der Runmitte um weitere 15 %.", FindingDefinition.Behavior.ACCELERATION, 0.15, [&"accel_rhythm", &"accel_active", &"accel_priority"], all_levels),
		&"pressure_surges": FindingDefinition.create(&"pressure_surges", "Belastungsschübe", "Kurze Belastungsspitzen beanspruchen den Zustand zusätzlich.", "Alle 25 Sekunden entsteht ein angekündigtes viersekündiges Gefahrenfenster.", FindingDefinition.Behavior.PRESSURE_SURGES, 0.30, [&"surge_buffer", &"surge_support", &"surge_guard"], all_levels),
		&"hidden_nests": FindingDefinition.create(&"hidden_nests", "Verdeckte Nester", "Kleine zusätzliche Herde halten die lokale Belastung aufrecht.", "Nach dem Befund erscheinen zwei kleine Herde, die nach 20 Sekunden Gegner freisetzen.", FindingDefinition.Behavior.HIDDEN_NESTS, 2.0, [&"nest_damage", &"nest_range", &"nest_samples"], all_levels),
	}

static func reaction_definitions() -> Dictionary:
	return {
		&"group_area": ReactionDefinition.create(&"group_area", &"grouping", "Breite Wirkung", "+20 % Flächenwirkung gegen Gruppen.", [{"stat_id": &"group_area_effect", "operation": &"multiply", "value": 1.20}], [&"damage"]),
		&"group_control": ReactionDefinition.create(&"group_control", &"grouping", "Gruppen bremsen", "+30 % Kontrollwirkung gegen Gruppen.", [{"stat_id": &"group_control", "operation": &"multiply", "value": 1.30}], [&"control"]),
		&"group_safety": ReactionDefinition.create(&"group_safety", &"grouping", "Sichere Distanz", "25 % weniger Kontaktdruck durch Gruppen.", [{"stat_id": &"group_contact", "operation": &"multiply", "value": 0.75}], [&"support"]),
		&"accel_rhythm": ReactionDefinition.create(&"accel_rhythm", &"acceleration", "Rhythmus anpassen", "+12 % Behandlungstempo.", [{"stat_id": &"therapy_cooldown", "operation": &"multiply", "value": 0.88}], [&"treatment"]),
		&"accel_active": ReactionDefinition.create(&"accel_active", &"acceleration", "Schneller eingreifen", "10 % kürzere aktive Abklingzeiten.", [{"stat_id": &"ability_cooldown", "operation": &"multiply", "value": 0.90}], [&"active"]),
		&"accel_priority": ReactionDefinition.create(&"accel_priority", &"acceleration", "Prioritäten setzen", "+25 % Wirkung auf markierte Ziele.", [{"stat_id": &"marked_damage", "operation": &"multiply", "value": 1.25}], [&"focus"]),
		&"surge_buffer": ReactionDefinition.create(&"surge_buffer", &"pressure_surges", "Reserve aktivieren", "+12 Schutzpuffer.", [{"stat_id": &"shield", "operation": &"add", "value": 12.0}], [&"shield"]),
		&"surge_support": ReactionDefinition.create(&"surge_support", &"pressure_surges", "Atemhilfe verstärken", "+30 % Atemhilfe.", [{"stat_id": &"support_effect", "operation": &"multiply", "value": 1.30}], [&"support"]),
		&"surge_guard": ReactionDefinition.create(&"surge_guard", &"pressure_surges", "Schub abfangen", "25 % weniger Kontaktdruck während Belastungsschüben.", [{"stat_id": &"surge_contact", "operation": &"multiply", "value": 0.75}], [&"control"]),
		&"nest_damage": ReactionDefinition.create(&"nest_damage", &"hidden_nests", "Herde fokussieren", "+25 % Wirkung gegen kleine Herde.", [{"stat_id": &"nest_damage", "operation": &"multiply", "value": 1.25}], [&"damage"]),
		&"nest_range": ReactionDefinition.create(&"nest_range", &"hidden_nests", "Reichweite nutzen", "+20 % Reichweite und +1 Durchdringung.", [{"stat_id": RunBuildState.TREATMENT_RANGE, "operation": &"multiply", "value": 1.20}, {"stat_id": RunBuildState.TREATMENT_MAX_HITS, "operation": &"add", "value": 1.0}], [&"pierce"]),
		&"nest_samples": ReactionDefinition.create(&"nest_samples", &"hidden_nests", "Nester auswerten", "Kleine Herde geben zusätzliche Proben und verkürzen aktive Restzeiten.", [{"stat_id": &"nest_samples", "operation": &"add", "value": 4.0}], [&"samples"]),
	}

static func choose_upgrades(
	levels: Dictionary,
	rng: RandomNumberGenerator,
	count: int = 3,
	force_all_paths: bool = false,
	excluded_ids: Array[StringName] = []
) -> Array[UpgradeDefinition]:
	var available: Array[UpgradeDefinition] = []
	for definition in upgrade_definitions():
		if int(levels.get(definition.id, 0)) < definition.max_level and not excluded_ids.has(definition.id):
			available.append(definition)
	if available.size() < count and not excluded_ids.is_empty():
		for definition in upgrade_definitions():
			if int(levels.get(definition.id, 0)) < definition.max_level and not available.has(definition):
				available.append(definition)
	if available.size() <= count:
		return available

	var selected: Array[UpgradeDefinition] = []
	if force_all_paths and count >= 3:
		for path in [UpgradeDefinition.Path.ANTIBIOTIC, UpgradeDefinition.Path.IMMUNE, UpgradeDefinition.Path.SUPPORT]:
			var matching := available.filter(func(item: UpgradeDefinition) -> bool: return item.path == path)
			if not matching.is_empty():
				var item: UpgradeDefinition = matching[rng.randi_range(0, matching.size() - 1)]
				selected.append(item)
				available.erase(item)

	while selected.size() < count and not available.is_empty():
		var index := rng.randi_range(0, available.size() - 1)
		selected.append(available[index])
		available.remove_at(index)
	return selected
