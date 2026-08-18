class_name ContentCatalog
extends RefCounted

const RESERVED_CASE_TRAIT_IDS: Array[StringName] = [
	&"high_load", &"mobile_pathogens", &"resistant_pathogens", &"fragile_condition",
]


static func reserved_case_trait_ids() -> Array[StringName]:
	return RESERVED_CASE_TRAIT_IDS.duplicate()

static func create_run_config(level: LevelDefinition = null, quick_run: bool = false) -> RunConfig:
	var selected := level_definitions()[0] if level == null else level
	return RunConfig.from_level(selected, quick_run)

static func level_definitions() -> Array[LevelDefinition]:
	var all_traits: Array[StringName] = [
		&"monster_resistance_20", &"monster_defense_10", &"monster_speed_15", &"monster_health_15",
		&"monster_damage_15", &"double_boss", &"monster_spawn_10", &"experience_10",
	]
	var all_findings: Array[StringName] = [&"grouping", &"acceleration", &"pressure_surges", &"hidden_nests"]
	return [
		LevelDefinition.create(
			&"intro", 0, "Das Lungenmodell", "Einführung · die Grundlagen", true,
			0.0, 0.0, 100.0, 1.10, 0.55, 0.55, 0.70, 0.80, 0.50, 0.0, 0.05,
			0.18, PackedInt32Array(), 1.0,
			"Lerne Geschwindigkeit, Behandlung, Erfahrung und Abwehrzellen kennen.",
			"Das erste Lungenmodell ist stabilisiert. Die regulären Patientenfälle stehen nun bereit.",
			"Das Modell blieb instabil. Wiederhole die Einführung in deinem eigenen Tempo."
		).configure_case_variation([], [], 0),
		LevelDefinition.create(
			&"localized_focus", 1, "lol - name fehlt", "Fall 01 · lokalisierter Pneumokokkenherd", false,
			-1.0, 180.0, 100.0, 0.744, 0.168, 1.15, 1.70, 1.08, 1.25, 0.10, 0.28,
			0.75, PackedInt32Array([3, 4]), 1.0,
			"Ein lokaler Bakterienherd belastet Doctor Milos. Stoppe ihn, bevor das Leben auf null fällt.",
			"Der lokalisierte Infektionsherd wurde kontrolliert.",
			"Die Infektionslast konnte in diesem Versuch nicht ausreichend kontrolliert werden."
		).configure_case_variation(all_traits, all_findings, 30),
		LevelDefinition.create(
			&"spreading_infection", 2, "Die Ausbreitung", "Fall 02 · bakterielle Pneumonie", false,
			-1.0, 180.0, 100.0, 0.624, 0.132, 1.35, 2.05, 1.16, 1.45, 0.18, 0.38,
			1.05, PackedInt32Array([4, 6]), 1.35,
			"Mehrere Bakteriengruppen breiten sich gleichzeitig aus. Geschwindigkeit und Ausbau werden jetzt entscheidend.",
			"Die ausbreitende Infektion wurde eingegrenzt.",
			"Doctor Milos verlor sein gesamtes Leben."
		).configure_case_variation(all_traits, all_findings, 42),
		LevelDefinition.create(
			&"severe_pneumonia", 3, "Schwerer Verlauf", "Fall 03 · schwere bakterielle Pneumonie", false,
			-1.0, 180.0, 100.0, 0.528, 0.108, 1.55, 2.40, 1.24, 1.65, 0.25, 0.48,
			1.35, PackedInt32Array([6, 8]), 1.70,
			"Die Belastung steigt schnell. Du brauchst einen starken Ausbau und konsequente Geschwindigkeit.",
			"Auch der schwere Infektionsverlauf wurde kontrolliert.",
			"Der schwere Verlauf blieb außerhalb des kontrollierbaren Therapiefensters."
		).configure_case_variation(all_traits, all_findings, 55)
	]

static func tutorial_hint_definitions() -> Dictionary:
	return {
		&"movement": TutorialHintDefinition.create(&"movement", &"run_started", "Im Lungenmodell bewegen", "Bewege Doctor Milos mit WASD oder den Pfeiltasten. Gegnerschaden senkt das Leben."),
		&"therapy": TutorialHintDefinition.create(&"therapy", &"first_shot", "Behandlung arbeitet automatisch", "Die Behandlung wählt ein nahes Bakterium selbstständig aus."),
		&"analysis": TutorialHintDefinition.create(&"analysis", &"first_analysis", "Erfahrung aufnehmen", "Erfahrung füllt die Leiste. Eine volle Leiste erhöht dein Level und ermöglicht einen Ausbau."),
		&"upgrade": TutorialHintDefinition.create(&"upgrade", &"first_upgrade", "Ausbauten", "Behandlung verursacht direkten Schaden, Abwehrzellen schützen den Nahbereich und Regeneration stellt Leben wieder her."),
		&"boss": TutorialHintDefinition.create(&"boss", &"boss_spawned", "Infektionsherd", "Kontrolliere den Infektionsherd, um die Einführung abzuschließen.")
	}

static func enemy_definitions() -> Dictionary:
	return {
		&"pneumococcus": EnemyDefinition.create(
			&"pneumococcus", "Bakterium", 22.0, 60.0, 2.2, 1, 18.0, Color("72b64a"), false, &"pneumococcus", &"pneumococcus", "Pneumokokke"
		),
		&"bacterial_cluster": EnemyDefinition.create(
			&"bacterial_cluster", "Bakteriengruppe", 74.0, 45.0, 5.0, 4, 30.0, Color("4e9338"), false, &"bacterial_cluster", &"bacterial_cluster", "Bakterienverband"
		),
		&"minor_focus": EnemyDefinition.create(
			&"minor_focus", "Kleiner Herd", 180.0, 20.0, 0.0, 8, 38.0, Color("9a5bbb"), false, &"minor_focus", &"infection_focus", "Kleiner Infektionsherd"
		),
		&"infection_focus": EnemyDefinition.create(
			&"infection_focus", "Infektionsherd", 2200.0, 30.0, 9.0, 30, 72.0, Color("9a5bbb"), true, &"infection_focus", &"infection_focus", "Lokaler Infektionsherd"
		)
	}


static func validate_combat_profiles(
	enemies: Dictionary = {},
	treatments: Dictionary = {},
	abilities: Dictionary = {}
) -> PackedStringArray:
	var enemy_catalog := enemy_definitions() if enemies.is_empty() else enemies
	var treatment_catalog := TreatmentDefinition.catalog() if treatments.is_empty() else treatments
	var ability_catalog := AbilityDefinition.catalog() if abilities.is_empty() else abilities
	var errors := PackedStringArray()
	for id in enemy_catalog:
		var enemy := enemy_catalog[id] as EnemyDefinition
		if enemy == null or enemy.damage_profile == null or not enemy.damage_profile.is_valid():
			errors.append("enemy:%s:damage_profile" % String(id))
		if enemy == null or enemy.resistance_profile == null or not enemy.resistance_profile.is_valid():
			errors.append("enemy:%s:resistance_profile" % String(id))
	for id in treatment_catalog:
		var treatment := treatment_catalog[id] as TreatmentDefinition
		if treatment == null or treatment.damage_profile == null or not treatment.damage_profile.is_valid():
			errors.append("treatment:%s:damage_profile" % String(id))
	for id in ability_catalog:
		var ability := ability_catalog[id] as AbilityDefinition
		if ability == null:
			errors.append("ability:%s:definition" % String(id))
			continue
		var deals_damage := float(ability.parameters.get("damage", 0.0)) > 0.0
		if deals_damage and (ability.damage_profile == null or not ability.damage_profile.is_valid()):
			errors.append("ability:%s:damage_profile" % String(id))
		elif ability.damage_profile != null and not ability.damage_profile.is_valid():
			errors.append("ability:%s:invalid_optional_damage_profile" % String(id))
	return errors

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
			"%s\nBoss · löst bei 70 %% und 40 %% Leben neue Bakterienschübe aus. Leben, Geschwindigkeit und Schaden werden je Fall skaliert." % _enemy_values_text(focus, "Bossgegner", false), &"enemy", 110, &"erreger", &"infection_focus", "Lokaler Infektionsherd"
		),
		&"minor_focus": DiscoveryDefinition.create(
			&"minor_focus", &"enemy_materialized", "Kleiner Herd",
			"Ein kleiner Herd steht vereinfacht für eine zusätzliche lokale Bakterienquelle.",
			"%s\nBewegt sich langsam auf Doctor Milos zu · setzt nach 20 Sekunden vier Bakterien frei, falls er nicht kontrolliert wird." % _enemy_values_text(minor_focus, "Mobiles Nebenziel", false), &"enemy", 95, &"erreger", &"infection_focus", "Kleiner Infektionsherd"
		),
		&"analysis_pickup": DiscoveryDefinition.create(
			&"analysis_pickup", &"pickup_spawned", "Erfahrung",
			"Erfahrung steht vereinfacht für verwertbare Informationen aus kontrollierten Erregern.",
			"Erfahrung füllt die Leiste am unteren Rand; eine volle Leiste erhöht dein Level und ermöglicht einen Ausbau.", &"pickup", 80, &"grundlagen", &"analysis_pickup", "Analyse"
		),
		&"character_stats": DiscoveryDefinition.create(
			&"character_stats", &"catalog", "Doctor Milos",
			"Der beste Doctor mit Bandana.",
			"GRUNDWERTE\n100 Leben · Geschwindigkeit 300 · Schaden 16 · Rate 1,22/s · Reichweite 16 · 1 Ziel · Erfahrungsradius 6. Forschung und Ausbauten verändern diese Werte.", &"none", 0, &"grundlagen", &"doctor", ""
		),
		&"patient_stability": DiscoveryDefinition.create(
			&"patient_stability", &"run_started", "Leben",
			"Leben zeigt, wie viel Schaden Doctor Milos noch aushält.",
			"Gegnerschaden senkt das Leben. Bei 0 endet der Fall.", &"stability_bar", 120, &"grundlagen", &"patient_stability", "Lebenspunkte"
		),
		&"automatic_therapy": DiscoveryDefinition.create(
			&"automatic_therapy", &"first_shot", "Behandlung",
			"Die automatisch abgegebenen Wirkstoffe stellen eine abstrahierte antibakterielle Behandlung dar.",
			"Ziele werden automatisch gewählt. Du steuerst Doctor Milos und den Ausbau.", &"projectile", 85, &"therapie", &"automatic_therapy", "Automatische antibiotische Therapie"
		),
		&"neutrophil_orbit": DiscoveryDefinition.create(
			&"neutrophil_orbit", &"upgrade_applied", "Abwehrzellen",
			"Neutrophile Granulozyten gehören zur angeborenen Immunabwehr und reagieren früh auf Bakterien.",
			"2 Abwehrzellen · 5,4 Schaden · 10/s · Radius 4.", &"avatar", 70, &"therapie", &"immune_cell", "Neutrophile Granulozyten"
		),
		&"supportive_oxygenation": DiscoveryDefinition.create(
			&"supportive_oxygenation", &"upgrade_applied", "Regeneration",
			"Oxygenierung unterstützt den Patienten, bekämpft Bakterien aber nicht direkt.",
			"Regeneriert regelmäßig Leben.", &"stability_bar", 70, &"therapie", &"supportive_oxygenation", "Supportive Oxygenierung"
		),
		&"boss_phases": DiscoveryDefinition.create(
			&"boss_phases", &"boss_phase", "Bossphase",
			"Die Phasen stehen für eine sprunghaft zunehmende lokale bakterielle Belastung.",
			"Bei 70 % und 40 % Bossleben erscheint je ein Minion-Schub.", &"boss_bar", 60, &"erreger"
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
	var samples := "%d Erfahrung" % definition.analysis_value
	var text := "%s.\nGRUNDWERTE\n%s Leben · Geschwindigkeit %s · %s Schaden · %s." % [
		role,
		_number_text(definition.max_health),
		_number_text(definition.speed),
		_number_text(definition.base_damage),
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
	return [
		_run_upgrade(&"potency", "Stärkerer Impuls", "+7 Schaden pro Treffer.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"damage", 7.0, "Gezielte Wirksamkeit", treatments, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 7.0, &"delta", "Schaden", "Schaden", 16.0, 0, &"enemy", PackedStringArray(["treatment"])),
		_run_upgrade(&"rhythm", "Schnellere Impulse", "16 % häufigere Anwendung.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"cooldown_multiplier", 0.84, "Verlässlicher Therapierhythmus", treatments, [&"treatment", &"rhythm"], RunBuildState.TREATMENT_INTERVAL, &"multiply", 0.84, &"tempo", "Rate", "Rate", 0.82, 2, &"", PackedStringArray(["treatment"])),
		_run_upgrade(&"penetration", "Mehr Reichweite", "+3 Reichweitenstufen.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"range", 90.0, "Gewebegängigkeit", treatments, [&"treatment", &"range"], RunBuildState.TREATMENT_RANGE, &"add", 90.0, &"distance_stage", "Stufen", "Reichweitenstufen", 480.0, 0, &"enemy", PackedStringArray(["treatment"])),
		_run_upgrade(&"parallel_sites", "Zusätzliches Ziel", "Ein zusätzliches Ziel je Impuls.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"targets", 1.0, "Parallele Wirkorte", [&"treatment_precision"], [&"precise", &"targets"], RunBuildState.TREATMENT_TARGETS, &"add", 1.0, &"count", "Projektil", "Ziele", 1.0, 0, &"enemy", PackedStringArray(["precise"])),
		UpgradeDefinition.create(&"neutrophils", "Abwehrzellen", "Zwei Abwehrzellen umkreisen Doctor Milos.", UpgradeDefinition.Path.IMMUNE, 1, &"immune_level", 1.0, "Neutrophile Rekrutierung"),
		_run_upgrade(&"phagocytosis", "Stärkere Abwehrzellen", "+3,6 Schaden je Treffer.", UpgradeDefinition.Path.IMMUNE, 3, &"immune_damage", 3.6, "Effiziente Phagozytose", [], [&"defense_cell", &"damage"], RunBuildState.DEFENSE_CELL_DAMAGE, &"add", 3.6, &"delta", "Schaden", "Schaden", 5.4, 1, &"enemy", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]),
		_run_upgrade(&"defense_cell_radius", "Größere Abwehrzellen", "+1 Radiusstufe.", UpgradeDefinition.Path.IMMUNE, 3, &"run_modifier", 30.0, "Erweiterte Zellreichweite", [], [&"defense_cell", &"area"], RunBuildState.DEFENSE_CELL_RADIUS, &"add", 30.0, &"distance_stage", "Stufe", "Radiusstufen", CombatDistanceScale.world_from_stage(RunBuildState.BASE_DEFENSE_CELL_RADIUS_STAGE), 0, &"avatar", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]),
		_run_upgrade(&"defense_cell_projectiles", "Mehr Abwehrzellen", "+1 Projektil.", UpgradeDefinition.Path.IMMUNE, 2, &"run_modifier", 1.0, "Zusätzliche Abwehrzelle", [], [&"defense_cell", &"projectiles"], RunBuildState.DEFENSE_CELL_PROJECTILES, &"add", 1.0, &"count", "Projektil", "Projektile", 2.0, 0, &"avatar", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]),

		# Behandlungsspezifische Angebote. Nur die vorbereitete Grundbehandlung
		# kann sie ziehen.
		_run_upgrade(&"precision_refinement", "Ruhiger Fokus", "+18 % Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 1.18, "Präzisionssteigerung", [&"treatment_precision"], [&"precise", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"multiply", 1.18, &"percent", "Schaden", "Schaden", 16.0, 1, &"enemy", PackedStringArray(["precise"])),
		_run_upgrade(&"spread_density", "Dichter Streuimpuls", "+1 Projektil.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 1.0, "Erweiterte Wirkverteilung", [&"treatment_spread"], [&"spread", &"area"], RunBuildState.TREATMENT_PROJECTILES, &"add", 1.0, &"count", "Projektil", "Projektile", 3.0, 0, &"enemy", PackedStringArray(["spread"])),
		_run_upgrade(&"spread_effect", "Kräftigere Streuung", "+2 Schaden pro Projektil.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 2.0, "Breitenwirkung", [&"treatment_spread"], [&"spread", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 2.0, &"delta", "Schaden", "Schaden", 5.0, 0, &"enemy", PackedStringArray(["spread"])),
		_run_upgrade(&"pierce_depth", "Tieferer Impuls", "+2 Durchdringungen.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"run_modifier", 2.0, "Erhöhte Gewebegängigkeit", [&"treatment_pierce"], [&"piercing", &"line"], RunBuildState.TREATMENT_MAX_HITS, &"add", 2.0, &"count", "Durchdringungen", "Treffer", 4.0, 0, &"enemy", PackedStringArray(["piercing"])),
		_run_upgrade(&"pierce_effect", "Stärkere Linie", "+3 Schaden pro Treffer.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 3.0, "Linienwirkung", [&"treatment_pierce"], [&"piercing", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 3.0, &"delta", "Schaden", "Schaden", 9.0, 0, &"enemy", PackedStringArray(["piercing"])),

		# Aktive Eingriffe verbessern nur tatsächlich vorbereitete Q/E-Slots.
		_run_upgrade(&"burst_effect", "Kräftiger Stoß", "+8 Schaden.", UpgradeDefinition.Path.IMMUNE, 3, &"run_modifier", 8.0, "Akute Immunreaktion", [&"ability_defense_burst"], [&"active", &"defense", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 8.0, &"delta", "Schaden", "Schaden", 25.0, 0, &"enemy", PackedStringArray(["active", "defense"])),
		_run_upgrade(&"burst_radius", "Breiter Stoß", "+1 Radiusstufe.", UpgradeDefinition.Path.IMMUNE, 2, &"run_modifier", 30.0, "Ausgedehnte Immunreaktion", [&"ability_defense_burst"], [&"active", &"defense", &"area"], RunBuildState.ABILITY_RADIUS, &"add", 30.0, &"distance_stage", "Stufe", "Radiusstufen", 150.0, 0, &"ability", PackedStringArray(["active", "defense", "area"])),
		_run_upgrade(&"line_effect", "Stärkerer Lazer", "+10 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 10.0, "Linienverstärkung", [&"ability_treatment_line"], [&"active", &"line", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 10.0, &"delta", "Schaden", "Schaden", 30.0, 0, &"enemy", PackedStringArray(["active", "treatment", "line"])),
		_run_upgrade(&"line_width", "Breiterer Lazer", "+16 Breite.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"run_modifier", 16.0, "Erweiterte Linie", [&"ability_treatment_line"], [&"active", &"line", &"area"], RunBuildState.ABILITY_WIDTH, &"add", 16.0, &"delta", "Breite", "Breite", 38.0, 0, &"ability", PackedStringArray(["active", "treatment", "line"])),
		_run_upgrade(&"mobility", "Geschwindigkeit", "+5 % Geschwindigkeit.", UpgradeDefinition.Path.SUPPORT, 3, &"run_modifier", 1.05, "Mobilitätsreserve", [], [&"movement"], RunBuildState.MOVEMENT_SPEED, &"multiply", 1.05, &"percent", "Geschwindigkeit", "Geschwindigkeit", PlayerStats.BASE_MOVEMENT_SPEED, 0, &"avatar", PackedStringArray()),
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
		ResearchDefinition.create(&"stability_reserve", "Mehr Leben", "+3 maximales Leben je Rang", PackedInt32Array([20, 45, 80]), &"max_health", 3.0),
		ResearchDefinition.create(&"therapy_precision", "Stärkere Behandlung", "+2 % Schaden der Grundbehandlung je Rang", PackedInt32Array([25, 55, 95]), &"damage_multiplier", 0.02),
		ResearchDefinition.create(&"experience_gain", "Mehr Erfahrung", "+5 % Erfahrung je Rang", PackedInt32Array([25, 55, 95]), &"experience_multiplier", 0.05),
		ResearchDefinition.create(&"defense_training", "Mehr Verteidigung", "+2 Verteidigung je Rang", PackedInt32Array([30, 60, 100]), &"defense", 2.0),
		ResearchDefinition.create(&"life_regeneration", "Lebensregeneration", "+0,25 Leben pro Sekunde je Rang", PackedInt32Array([30, 60, 100]), &"life_regeneration", 0.25),
		ResearchDefinition.create(&"unlock_spread_treatment", "Streuimpuls", "Schaltet die streuende Grundbehandlung frei", PackedInt32Array([60]), &"unlock", 1.0).configure_unlock(&"treatment_spread", &"treatment"),
		ResearchDefinition.create(&"unlock_piercing_treatment", "Durchdringender Impuls", "Schaltet die durchdringende Grundbehandlung frei", PackedInt32Array([100]), &"unlock", 1.0).configure_unlock(&"treatment_pierce", &"treatment"),
		ResearchDefinition.create(&"movement_training", "Mehr Geschwindigkeit", "+3 % Geschwindigkeit je Rang", PackedInt32Array([30, 60, 100]), &"movement_speed_multiplier", 0.03),
	]

static func loadout_module_definitions() -> Dictionary:
	return {
		&"treatment_precision": LoadoutModuleDefinition.create(&"treatment_precision", "Impuls", "Verfolgt ein einzelnes Ziel mit hohem Grundschaden.", LoadoutModuleDefinition.Kind.TREATMENT, 2, [&"treatment", &"precision"], &"", true),
		&"treatment_spread": LoadoutModuleDefinition.create(&"treatment_spread", "Streuimpuls", "Trifft drei Ziele mit schwächeren Einzelimpulsen.", LoadoutModuleDefinition.Kind.TREATMENT, 2, [&"treatment", &"spread"], &"unlock_spread_treatment"),
		&"treatment_pierce": LoadoutModuleDefinition.create(&"treatment_pierce", "Durchdringender Impuls", "Durchquert mehrere Gegner in einer Linie.", LoadoutModuleDefinition.Kind.TREATMENT, 2, [&"treatment", &"pierce"], &"unlock_piercing_treatment"),
		&"ability_focus_field": LoadoutModuleDefinition.create(&"ability_focus_field", "Fokusfeld", "Behandlung im Zielgebiet verursacht 25 % mehr Schaden.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"focus", &"control"], &"", true),
		&"ability_emergency_support": LoadoutModuleDefinition.create(&"ability_emergency_support", "Notfallhilfe", "Stellt 14 Leben wieder her und gewährt 8 Schild.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"support"], &"", true),
		&"ability_defense_burst": LoadoutModuleDefinition.create(&"ability_defense_burst", "idk name stoß", "25 Schaden und starker Rückstoß im Zielbereich.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"damage", &"control"], &"unlock_defense_burst"),
		&"ability_treatment_line": LoadoutModuleDefinition.create(&"ability_treatment_line", "Fetter lazer", "30 Schaden in einer durchdringenden Linie.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"damage", &"pierce"], &"unlock_treatment_line"),
		&"ability_protection_field": LoadoutModuleDefinition.create(&"ability_protection_field", "Schildfeld", "Gegner im Feld: −35 % Geschwindigkeit und Schaden.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"control", &"support"], &"unlock_protection_field"),
		&"ability_sample_pull": LoadoutModuleDefinition.create(&"ability_sample_pull", "Erfahrungszug", "Zieht Erfahrung an und beschleunigt kurz den Befund.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"samples", &"diagnosis"], &"unlock_sample_pull"),
	}

static func case_trait_definitions() -> Dictionary:
	var all_levels: Array[StringName] = [&"localized_focus", &"spreading_infection", &"severe_pneumonia"]
	return {
		&"monster_resistance_20": CaseTraitDefinition.create(&"monster_resistance_20", "Resistente Erreger", "+20 Prozentpunkte auf alle effektiven Gegnerresistenzen.", [{"stat_id": &"enemy_resistance_effective", "operation": &"add", "value": 20.0}], all_levels, &"negative"),
		&"monster_defense_10": CaseTraitDefinition.create(&"monster_defense_10", "Gepanzerte Erreger", "+10 Gegnerverteidigung.", [{"stat_id": &"enemy_defense", "operation": &"add", "value": 10.0}], all_levels, &"negative"),
		&"monster_speed_15": CaseTraitDefinition.create(&"monster_speed_15", "Schnelle Erreger", "+15 % Gegnergeschwindigkeit.", [{"stat_id": &"enemy_speed", "operation": &"multiply", "value": 1.15}], all_levels, &"negative"),
		&"monster_health_15": CaseTraitDefinition.create(&"monster_health_15", "Robuste Erreger", "+15 % Leben für reguläre Gegner und Bosse.", [{"stat_id": &"enemy_health", "operation": &"multiply", "value": 1.15}, {"stat_id": &"boss_health", "operation": &"multiply", "value": 1.15}], all_levels, &"negative"),
		&"monster_damage_15": CaseTraitDefinition.create(&"monster_damage_15", "Aggressive Erreger", "+15 % Gegnerschaden.", [{"stat_id": &"enemy_damage", "operation": &"multiply", "value": 1.15}], all_levels, &"negative"),
		&"double_boss": CaseTraitDefinition.create(&"double_boss", "Doppelherd", "Zwei Infektionsherde müssen kontrolliert werden.", [{"stat_id": &"boss_count", "operation": &"override", "value": 2.0}], all_levels, &"mixed"),
		&"monster_spawn_10": CaseTraitDefinition.create(&"monster_spawn_10", "Hohe Keimlast", "+10 % Spawnrate.", [{"stat_id": &"spawn_rate", "operation": &"multiply", "value": 1.10}], all_levels, &"mixed"),
		&"experience_10": CaseTraitDefinition.create(&"experience_10", "Lerngewinn", "+10 % Erfahrung.", [{"stat_id": &"experience_gain", "operation": &"multiply", "value": 1.10}], all_levels, &"positive"),
	}

static func finding_definitions() -> Dictionary:
	var all_levels: Array[StringName] = [&"localized_focus", &"spreading_infection", &"severe_pneumonia"]
	return {
		&"grouping": FindingDefinition.create(&"grouping", "Gruppenbildung", "Die Bakterienlast sammelt sich vermehrt in lokalen Verbänden.", "+18 % Bakteriengruppen", FindingDefinition.Behavior.GROUPING, 0.18, [&"group_area", &"group_control", &"group_safety"], all_levels),
		&"acceleration": FindingDefinition.create(&"acceleration", "Beschleunigte Ausbreitung", "Die Belastung nimmt in der zweiten Hälfte schneller zu.", "+15 % Ausbreitung ab Runmitte", FindingDefinition.Behavior.ACCELERATION, 0.15, [&"accel_rhythm", &"accel_active", &"accel_priority"], all_levels),
		&"pressure_surges": FindingDefinition.create(&"pressure_surges", "Belastungsschübe", "Kurze Belastungsspitzen erhöhen den eingehenden Schaden.", "Alle 25 s · 4 s Belastungsschub", FindingDefinition.Behavior.PRESSURE_SURGES, 0.30, [&"surge_buffer", &"surge_support", &"surge_guard"], all_levels),
		&"hidden_nests": FindingDefinition.create(&"hidden_nests", "Verdeckte Nester", "Kleine zusätzliche Herde halten die lokale Belastung aufrecht.", "+2 kleine Herde", FindingDefinition.Behavior.HIDDEN_NESTS, 2.0, [&"nest_damage", &"nest_range", &"nest_samples"], all_levels),
	}

static func reaction_definitions() -> Dictionary:
	return {
		&"group_area": ReactionDefinition.create(&"group_area", &"grouping", "Breiter Schaden", "+20 % Flächenschaden gegen Gruppen.", [{"stat_id": &"group_area_effect", "operation": &"multiply", "value": 1.20}], [&"damage"]),
		&"group_control": ReactionDefinition.create(&"group_control", &"grouping", "Gruppen bremsen", "+30 % Kontrollwirkung gegen Gruppen.", [{"stat_id": &"group_control", "operation": &"multiply", "value": 1.30}], [&"control"]),
		&"group_safety": ReactionDefinition.create(&"group_safety", &"grouping", "Sichere Distanz", "25 % weniger Schaden durch Gruppen.", [{"stat_id": &"group_contact", "operation": &"multiply", "value": 0.75}], [&"support"]),
		&"accel_rhythm": ReactionDefinition.create(&"accel_rhythm", &"acceleration", "Rhythmus anpassen", "+12 % Behandlungstempo.", [{"stat_id": &"therapy_cooldown", "operation": &"multiply", "value": 0.88}], [&"treatment"]),
		&"accel_active": ReactionDefinition.create(&"accel_active", &"acceleration", "Schneller eingreifen", "10 % kürzere aktive Abklingzeiten.", [{"stat_id": &"ability_cooldown", "operation": &"multiply", "value": 0.90}], [&"active"]),
		&"accel_priority": ReactionDefinition.create(&"accel_priority", &"acceleration", "Prioritäten setzen", "+25 % Schaden auf markierte Ziele.", [{"stat_id": &"marked_damage", "operation": &"multiply", "value": 1.25}], [&"focus"]),
		&"surge_buffer": ReactionDefinition.create(&"surge_buffer", &"pressure_surges", "Reserve aktivieren", "+12 Schild.", [{"stat_id": &"shield", "operation": &"add", "value": 12.0}], [&"shield"]),
		&"surge_support": ReactionDefinition.create(&"surge_support", &"pressure_surges", "Regeneration verstärken", "+30 % Regeneration.", [{"stat_id": &"support_effect", "operation": &"multiply", "value": 1.30}], [&"support"]),
		&"surge_guard": ReactionDefinition.create(&"surge_guard", &"pressure_surges", "Schub abfangen", "25 % weniger Schaden während Belastungsschüben.", [{"stat_id": &"surge_contact", "operation": &"multiply", "value": 0.75}], [&"control"]),
		&"nest_damage": ReactionDefinition.create(&"nest_damage", &"hidden_nests", "Herde fokussieren", "+25 % Schaden gegen kleine Herde.", [{"stat_id": &"nest_damage", "operation": &"multiply", "value": 1.25}], [&"damage"]),
		&"nest_range": ReactionDefinition.create(&"nest_range", &"hidden_nests", "Reichweite nutzen", "+20 % Reichweite und +1 Durchdringung.", [{"stat_id": RunBuildState.TREATMENT_RANGE, "operation": &"multiply", "value": 1.20}, {"stat_id": RunBuildState.TREATMENT_MAX_HITS, "operation": &"add", "value": 1.0}], [&"pierce"]),
		&"nest_samples": ReactionDefinition.create(&"nest_samples", &"hidden_nests", "Nester auswerten", "Kleine Herde geben zusätzliche Erfahrung.", [{"stat_id": &"nest_samples", "operation": &"add", "value": 4.0}], [&"samples"]),
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
