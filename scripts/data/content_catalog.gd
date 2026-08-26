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
	var all_findings: Array[StringName] = [&"grouping", &"hidden_nests"]
	return [
		LevelDefinition.create(
			&"intro", 0, "Das Lungenmodell", "Einführung · die Grundlagen", true,
			0.0, 0.0, 50.0, 1.10, 0.55, 0.55, 0.70, 0.80, 0.50, 0.0, 0.05,
			0.09, PackedInt32Array(), 1.0,
			"Lerne Galopp, Behandlung, Erfahrung und Abwehrzellen kennen.",
			"Das erste Lungenmodell ist stabilisiert. Die regulären Patientenfälle stehen nun bereit.",
			"Das Modell blieb instabil. Wiederhole die Einführung in deinem eigenen Tempo."
		).configure_runtime(0, 0, 0.0, false).configure_case_variation([], [], 0).configure_boss(&"intro_focus", true).configure_case_pressure(CasePressurePlan.default_for_case_order(0)),
		LevelDefinition.create(
			&"early_localized_focus", 1, "Früher Verlauf", "Fall 01 · beginnender Pneumokokkenherd", false,
			-1.0, 300.0, 50.0, 1.16125, 0.28289474, 1.05, 1.525, 1.04, 1.15, 0.06, 0.23,
			0.75, PackedInt32Array([2]), 0.85,
			"Ein früher lokaler Infektionsherd bildet den ersten regulären Patientenfall.",
			"Der frühe Verlauf wurde kontrolliert.",
			"Der frühe Verlauf konnte in diesem Versuch nicht kontrolliert werden."
		).configure_runtime(1).configure_case_variation(all_traits, all_findings, 24).configure_boss(&"localized_boss", true).configure_boss_aura(1.20, 1.45, 1.45).configure_boss_reinforcements(15.0, 4).configure_boss_projectile_contract(1.0, EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS, 1.3, true, 2.0).configure_boss_projectile_pattern(&"normal").configure_case_pressure(CasePressurePlan.default_for_case_order(1)).configure_case_pressure_targets(false, 0.75),
		LevelDefinition.create(
			&"localized_focus", 2, "lol - name fehlt", "Fall 02 · lokalisierter Pneumokokkenherd", false,
			-1.0, 300.0, 50.0, 1.03375, 0.23375, 1.15, 1.70, 1.08, 1.25, 0.10, 0.28,
			1.0, PackedInt32Array([3]), 1.0,
			"Ein lokaler Bakterienherd belastet Doctor Milos. Stoppe ihn, bevor das Leben auf null fällt.",
			"Der lokalisierte Infektionsherd wurde kontrolliert.",
			"Die Infektionslast konnte in diesem Versuch nicht ausreichend kontrolliert werden."
		).configure_runtime(3).configure_case_variation(all_traits, all_findings, 30).configure_boss(&"localized_boss", true, 1.5).configure_boss_reinforcements(15.0, 4, 1).configure_boss_projectile_contract(1.53, EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS, 1.5).configure_boss_projectile_pattern(&"double_turn").configure_boss_projectile_turn_time_variation(0.10).configure_boss_phase_thresholds(PackedFloat32Array([0.80])).configure_case_pressure(CasePressurePlan.default_for_case_order(2)),
		LevelDefinition.create(
			&"advancing_infection", 3, "Fortschreitender Verlauf", "Fall 03 · fortschreitende Pneumonie", false,
			-1.0, 300.0, 50.0, 0.9075, 0.200, 1.25, 1.875, 1.12, 1.35, 0.14, 0.33,
			0.60, PackedInt32Array([3, 3]), 1.175,
			"Die Infektion breitet sich weiter aus und fordert mehr Kontrolle über den Raum.",
			"Der fortschreitende Verlauf wurde eingegrenzt.",
			"Der fortschreitende Verlauf blieb unkontrolliert."
		).configure_runtime(3).configure_case_variation(all_traits, all_findings, 36).configure_boss_behavior(1.20).configure_boss(&"infection_focus", true, 2.0, 136.0, 550.0).configure_boss_projectile_contract(1.0, EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS, 1.26).configure_case_pressure(CasePressurePlan.default_for_case_order(3)),
		LevelDefinition.create(
			&"spreading_infection", 4, "Die Ausbreitung", "Fall 04 · bakterielle Pneumonie", false,
			-1.0, 300.0, 50.0, 0.780, 0.165, 1.35, 2.05, 1.16, 1.45, 0.18, 0.38,
			0.75, PackedInt32Array([4, 4]), 1.35,
			"Mehrere Bakteriengruppen breiten sich gleichzeitig aus. Galopp und Ausbau werden jetzt entscheidend.",
			"Die ausbreitende Infektion wurde eingegrenzt.",
			"Doctor Milos verlor sein gesamtes Leben."
		).configure_runtime(3).configure_case_variation(all_traits, all_findings, 42).configure_boss_behavior(1.35).configure_boss(&"infection_focus", true, 2.5, 115.0).configure_case_pressure(CasePressurePlan.default_for_case_order(4)).configure_case_pressure_targets(true),
		LevelDefinition.create(
			&"critical_infection", 5, "Kritischer Verlauf", "Fall 05 · kritische Pneumonie", false,
			-1.0, 300.0, 50.0, 0.720, 0.150, 1.45, 2.225, 1.20, 1.55, 0.215, 0.43,
			1.05, PackedInt32Array([5, 6]), 1.525,
			"Stationäre Herde verengen den Raum, während die bakterielle Belastung weiter steigt.",
			"Der kritische Verlauf wurde kontrolliert.",
			"Der kritische Verlauf blieb außerhalb des kontrollierbaren Therapiefensters."
		).configure_runtime(3).configure_case_variation(all_traits, all_findings, 48).configure_boss(&"infection_focus", false).configure_case_pressure(CasePressurePlan.default_for_case_order(5)).configure_case_pressure_targets(true),
		LevelDefinition.create(
			&"severe_pneumonia", 6, "Schwerer Verlauf", "Fall 06 · schwere bakterielle Pneumonie", false,
			-1.0, 300.0, 50.0, 0.660, 0.135, 1.55, 2.40, 1.24, 1.65, 0.25, 0.48,
			1.35, PackedInt32Array([6, 8]), 1.70,
			"Die Belastung steigt schnell. Du brauchst einen starken Ausbau und konsequenten Galopp.",
			"Auch der schwere Infektionsverlauf wurde kontrolliert.",
			"Der schwere Verlauf blieb außerhalb des kontrollierbaren Therapiefensters."
		).configure_runtime(3).configure_case_variation(all_traits, all_findings, 55).configure_boss(&"infection_focus", false).configure_case_pressure(CasePressurePlan.default_for_case_order(6)).configure_case_pressure_targets(true)
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
	var result := {
		&"pneumococcus": EnemyDefinition.create(
			&"pneumococcus", "Bakterium", 22.0, 94.0, 2.0, 1, 18.0, Color("72b64a"), false, &"pneumococcus", &"pneumococcus", "Pneumokokke"
		).configure_contact_radius(17.0).configure_player_push(true, 2.0),
		&"bacterial_cluster": EnemyDefinition.create(
			&"bacterial_cluster", "Bakteriengruppe", 74.0, 94.0, 5.0, 4, 30.0, Color("4e9338"), false, &"bacterial_cluster", &"bacterial_cluster", "Bakterienverband"
		).configure_contact_radius(23.0).configure_player_push(true, 1.5),
		&"minor_focus": EnemyDefinition.create(
			&"minor_focus", "Kleiner Herd", 180.0, 42.0, 0.0, 8, 38.0, Color("9a5bbb"), false, &"minor_focus", &"infection_focus", "Kleiner Infektionsherd"
		).configure_contact_radius(31.0).configure_projectile_attack(2.0, 2.6, &"normal", false),
		&"infection_focus": EnemyDefinition.create(
			&"infection_focus", "Infektionsherd", 2200.0, 79.0, 9.0, 30, 72.0, Color("9a5bbb"), true, &"infection_focus", &"infection_focus", "Lokaler Infektionsherd"
		).configure_contact_radius(56.0).configure_projectile_attack(4.0, 1.6, &"diamond", true),
		&"localized_boss": EnemyDefinition.create(
			&"localized_boss", "Bakterienkern", 900.0, 73.0, 6.0, 20, 60.0, Color("d45d64"), true, &"localized_boss", &"infection_focus", "Lokaler Bakterienkern"
		).configure_contact_radius(47.0).configure_projectile_attack(4.0, 1.6, &"double_turn", true),
		&"intro_focus": EnemyDefinition.create(
			&"intro_focus", "Infektionsherd", 2200.0, 79.0, 9.0, 30, 72.0, Color("9a5bbb"), true, &"infection_focus", &"infection_focus", "Lokaler Infektionsherd"
		).configure_contact_radius(56.0).configure_projectile_attack(6.0, 2.6, &"normal", true)
	}
	return result


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
	var localized_boss: EnemyDefinition = enemies[&"localized_boss"]
	return {
		&"pneumococcus": DiscoveryDefinition.create(
			&"pneumococcus", &"enemy_defeated", "Bakterium",
			"Pneumokokken sind Bakterien, die unter anderem eine Lungenentzündung verursachen können.",
			_enemy_values_text(bacterium, "Schneller Einzelerreger"), &"enemy", 100, &"erreger", &"pneumococcus", "Pneumokokke"
		),
		&"bacterial_cluster": DiscoveryDefinition.create(
			&"bacterial_cluster", &"enemy_defeated", "Bakteriengruppe",
			"Der Verband steht vereinfacht für eine größere lokale bakterielle Belastung.",
			_enemy_values_text(group, "Langsam und widerstandsfähig"), &"enemy", 90, &"erreger", &"bacterial_cluster", "Bakterienverband"
		),
		&"infection_focus": DiscoveryDefinition.create(
			&"infection_focus", &"enemy_defeated", "Infektionsherd",
			"Der Infektionsherd ist eine spielerische Darstellung der konzentrierten bakteriellen Belastung.",
			"%s\nBoss · feuert fortlaufend zwei rautenförmig fliegende Projektile. Bei 70 %% und 40 %% Leben erscheinen je vier schießende Bakterien; nach der zweiten Phase folgen alle 20 Sekunden vier weitere." % _enemy_values_text(focus, "Bossgegner", false), &"enemy", 110, &"erreger", &"infection_focus", "Lokaler Infektionsherd"
		),
		&"localized_boss": DiscoveryDefinition.create(
			&"localized_boss", &"enemy_defeated", "Bakterienkern",
			"Der Bakterienkern steht vereinfacht für einen noch lokal begrenzten Schwerpunkt der Infektion.",
			"%s\nBossgegner mit fallabhängigem Verhalten. In Fall 1 verstärkt seine Aura Tempo und Schaden naher Monster um 45 %% und ruft alle 15 Sekunden vier schnell schießende Bakterien. Ist seine Aura leer, feuert der Kern selbst. In Fall 2 feuert er mit 1,53-facher Rate 50 %% schnellere und stärkere Doppelkurven-Projektile; ab 80 %% Leben erscheinen drei Bakterien und danach alle 15 Sekunden vier weitere. Ein Stoß unterbindet den Beschuss schießender Nichtbosse zehn Sekunden lang; der Kern selbst bleibt schussfähig." % _enemy_values_text(localized_boss, "Bossgegner", false), &"enemy", 105, &"erreger", &"infection_focus", "Lokaler Bakterienkern"
		),
		&"minor_focus": DiscoveryDefinition.create(
			&"minor_focus", &"enemy_defeated", "Kleiner Herd",
			"Ein kleiner Herd steht vereinfacht für eine zusätzliche lokale Bakterienquelle.",
			"%s\nBewegt sich langsam auf Doctor Milos zu. Je nach Fall feuert er Projektile und setzt nach 20 Sekunden vier Bakterien frei, falls er nicht kontrolliert wird; der Fall-2-Bakterienschwarm schießt nicht." % _enemy_values_text(minor_focus, "Mobiles Nebenziel", false), &"enemy", 95, &"erreger", &"infection_focus", "Kleiner Infektionsherd"
		),
		&"analysis_pickup": DiscoveryDefinition.create(
			&"analysis_pickup", &"pickup_spawned", "Erfahrung",
			"Erfahrung steht vereinfacht für verwertbare Informationen aus kontrollierten Erregern.",
			"Erfahrung füllt die Leiste am unteren Rand; eine volle Leiste erhöht dein Level und ermöglicht einen Ausbau.", &"pickup", 80, &"grundlagen", &"analysis_pickup", "Analyse"
		),
		&"character_stats": DiscoveryDefinition.create(
			&"character_stats", &"catalog", "Doctor Milos",
			"Der beste Doctor mit Bandana.",
			"GRUNDWERTE\n50 Leben · Galopp 171 · Schaden 13 · Attack Speed 1,04/s · Reichweite 16 · 1 Ziel · Erfahrungsradius 6. Forschung und Ausbauten verändern diese Werte.", &"none", 0, &"grundlagen", &"doctor", ""
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
			"2 Abwehrzellen · 5 Schaden · 5/s · Radius 4.", &"avatar", 70, &"therapie", &"immune_cell", "Neutrophile Granulozyten"
		),
		&"supportive_oxygenation": DiscoveryDefinition.create(
			&"supportive_oxygenation", &"upgrade_applied", "Regeneration",
			"Oxygenierung unterstützt den Patienten, bekämpft Bakterien aber nicht direkt.",
			"Regeneriert regelmäßig Leben.", &"stability_bar", 70, &"therapie", &"supportive_oxygenation", "Supportive Oxygenierung"
		),
		&"boss_phases": DiscoveryDefinition.create(
			&"boss_phases", &"boss_phase", "Bossphase",
			"Die Phasen stehen für eine sprunghaft zunehmende lokale bakterielle Belastung.",
			"Bei 70 % und 40 % Bossleben erscheinen je vier schießende Bakterien. Nach Phase zwei folgen alle 20 Sekunden weitere vier.", &"boss_bar", 60, &"erreger"
		),
		&"research_reward": DiscoveryDefinition.create(
			&"research_reward", &"run_result", "Forschungsbelohnung",
			"Forschung fasst die aus einem Fall gewonnenen, dauerhaft nutzbaren Erkenntnisse zusammen.",
			"Wird im Forschungsgebäude für kleine dauerhafte Verbesserungen ausgegeben.", &"reward", 50, &"praxis"
		),
		&"fall_one_event_vulnerability": DiscoveryDefinition.create(
			&"fall_one_event_vulnerability", &"case_event", "Anfällige Monster",
			"",
			"Manche Monster sind anfällig gegen bestimmte Fähigkeiten. Probiere Stoß aus.", &"enemy", 125, &"erreger"
		)
	}

static func is_discovery_unlocked_by_default(id: StringName) -> bool:
	return id == &"character_stats"

static func _enemy_values_text(definition: EnemyDefinition, role: String, add_scaling_note: bool = true) -> String:
	var text := "%s." % role
	if add_scaling_note:
		text += " Ausführliche Werte stehen im Lexikon."
	return text

static func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return ("%.1f" % value).replace(".", ",")

static func arena_visual_definitions() -> Dictionary:
	return {
		&"intro": ArenaVisualDefinition.create(&"intro", Color("b87b84"), Color("c99096"), Color("f2d1c4"), Color("74465b"), Color("da6f74"), 3101, 0.12, "res://assets/art/visual_restart/alveolar_tissue_day.png"),
		&"early_localized_focus": ArenaVisualDefinition.create(&"early_localized_focus", Color("b1717d"), Color("c5848e"), Color("efd0c2"), Color("704055"), Color("df665f"), 4101, 0.34, "res://assets/art/visual_restart/alveolar_tissue_day.png"),
		&"localized_focus": ArenaVisualDefinition.create(&"localized_focus", Color("b1717d"), Color("c5848e"), Color("efd0c2"), Color("704055"), Color("df665f"), 4202, 0.34, "res://assets/art/visual_restart/alveolar_tissue_day.png"),
		&"advancing_infection": ArenaVisualDefinition.create(&"advancing_infection", Color("a96878"), Color("bd7888"), Color("ecc7bd"), Color("63364f"), Color("e25f5d"), 5202, 0.56, "res://assets/art/visual_restart/alveolar_tissue_day.png"),
		&"spreading_infection": ArenaVisualDefinition.create(&"spreading_infection", Color("a96878"), Color("bd7888"), Color("ecc7bd"), Color("63364f"), Color("e25f5d"), 5303, 0.56, "res://assets/art/visual_restart/alveolar_tissue_day.png"),
		&"critical_infection": ArenaVisualDefinition.create(&"critical_infection", Color("945c70"), Color("aa697e"), Color("e4bdb6"), Color("562f49"), Color("e04f58"), 6303, 0.78, "res://assets/art/visual_restart/alveolar_tissue_day.png"),
		&"severe_pneumonia": ArenaVisualDefinition.create(&"severe_pneumonia", Color("945c70"), Color("aa697e"), Color("e4bdb6"), Color("562f49"), Color("e04f58"), 6404, 0.78, "res://assets/art/visual_restart/alveolar_tissue_day.png")
	}

static func upgrade_definitions() -> Array[UpgradeDefinition]:
	var treatments: Array[StringName] = [&"treatment_precision", &"treatment_spread", &"treatment_pierce"]
	var precise_treatment: Array[StringName] = [&"treatment_precision"]
	var spread_treatment: Array[StringName] = [&"treatment_spread"]
	var piercing_treatment: Array[StringName] = [&"treatment_pierce"]
	return [
		# Schaden, Attack Speed und Galopp sind endlose Familien. Pro Auswahl
		# erscheint höchstens eine Raritätsstufe derselben Familie.
		_run_upgrade(&"precision_refinement", "Behandlungsschaden", "+3 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 3.0, "Präzisionssteigerung", precise_treatment, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 3.0, &"delta", "Schaden", "Schaden", 10.0, 0, &"enemy", PackedStringArray(["treatment", "precise"])).configure_offer(&"damage", UpgradeDefinition.Rarity.COMMON, true, false, 70.0),
		_run_upgrade(&"treatment_damage_magic", "Behandlungsschaden", "+5 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 5.0, "Vertiefte Wirksamkeit", precise_treatment, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 5.0, &"delta", "Schaden", "Schaden", 10.0, 0, &"enemy", PackedStringArray(["treatment", "precise"])).configure_offer(&"damage", UpgradeDefinition.Rarity.MAGIC, true, false, 25.0),
		_run_upgrade(&"potency", "Behandlungsschaden", "+7 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"damage", 7.0, "Gezielte Wirksamkeit", precise_treatment, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 7.0, &"delta", "Schaden", "Schaden", 10.0, 0, &"enemy", PackedStringArray(["treatment", "precise"])).configure_offer(&"damage", UpgradeDefinition.Rarity.RARE, true, false, 5.0),
		_run_upgrade(&"spread_damage_common", "Behandlungsschaden", "+2 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 2.0, "Streuverstärkung", spread_treatment, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 2.0, &"delta", "Schaden", "Schaden", 5.0, 0, &"enemy", PackedStringArray(["treatment", "spread"])).configure_offer(&"damage", UpgradeDefinition.Rarity.COMMON, true, false, 70.0),
		_run_upgrade(&"spread_damage_magic", "Behandlungsschaden", "+3 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 3.0, "Vertiefte Streuwirkung", spread_treatment, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 3.0, &"delta", "Schaden", "Schaden", 5.0, 0, &"enemy", PackedStringArray(["treatment", "spread"])).configure_offer(&"damage", UpgradeDefinition.Rarity.MAGIC, true, false, 25.0),
		_run_upgrade(&"spread_damage_rare", "Behandlungsschaden", "+4 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 4.0, "Maximale Streuwirkung", spread_treatment, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 4.0, &"delta", "Schaden", "Schaden", 5.0, 0, &"enemy", PackedStringArray(["treatment", "spread"])).configure_offer(&"damage", UpgradeDefinition.Rarity.RARE, true, false, 5.0),
		_run_upgrade(&"pierce_damage_common", "Behandlungsschaden", "+3 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 3.0, "Durchdringungsstärkung", piercing_treatment, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 3.0, &"delta", "Schaden", "Schaden", 9.0, 0, &"enemy", PackedStringArray(["treatment", "piercing"])).configure_offer(&"damage", UpgradeDefinition.Rarity.COMMON, true, false, 70.0),
		_run_upgrade(&"pierce_damage_magic", "Behandlungsschaden", "+5 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 5.0, "Vertiefte Durchdringung", piercing_treatment, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 5.0, &"delta", "Schaden", "Schaden", 9.0, 0, &"enemy", PackedStringArray(["treatment", "piercing"])).configure_offer(&"damage", UpgradeDefinition.Rarity.MAGIC, true, false, 25.0),
		_run_upgrade(&"pierce_damage_rare", "Behandlungsschaden", "+6 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 6.0, "Maximale Durchdringung", piercing_treatment, [&"treatment", &"damage"], RunBuildState.TREATMENT_DAMAGE, &"add", 6.0, &"delta", "Schaden", "Schaden", 9.0, 0, &"enemy", PackedStringArray(["treatment", "piercing"])).configure_offer(&"damage", UpgradeDefinition.Rarity.RARE, true, false, 5.0),
		_run_upgrade(&"rhythm", "Attack Speed", "+3 % Attack Speed.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 0.03, "Verlässlicher Therapierhythmus", treatments, [&"treatment", &"rhythm"], RunBuildState.TREATMENT_INTERVAL, &"attack_speed_add", 0.03, &"tempo", "Attack Speed", "Attack Speed", 0.965, 0, &"", PackedStringArray(["treatment"])).configure_offer(&"attack_speed", UpgradeDefinition.Rarity.COMMON, true, false, 70.0),
		_run_upgrade(&"rhythm_magic", "Attack Speed", "+5 % Attack Speed.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 0.05, "Beschleunigter Therapierhythmus", treatments, [&"treatment", &"rhythm"], RunBuildState.TREATMENT_INTERVAL, &"attack_speed_add", 0.05, &"tempo", "Attack Speed", "Attack Speed", 0.965, 0, &"", PackedStringArray(["treatment"])).configure_offer(&"attack_speed", UpgradeDefinition.Rarity.MAGIC, true, false, 25.0),
		_run_upgrade(&"rhythm_rare", "Attack Speed", "+7 % Attack Speed.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 0.07, "Hochfrequenter Therapierhythmus", treatments, [&"treatment", &"rhythm"], RunBuildState.TREATMENT_INTERVAL, &"attack_speed_add", 0.07, &"tempo", "Attack Speed", "Attack Speed", 0.965, 0, &"", PackedStringArray(["treatment"])).configure_offer(&"attack_speed", UpgradeDefinition.Rarity.RARE, true, false, 5.0),
		_run_upgrade(&"parallel_sites", "Zusätzliches Projektil", "+1 Projektil.", UpgradeDefinition.Path.ANTIBIOTIC, 5, &"targets", 1.0, "Parallele Wirkorte", [&"treatment_precision"], [&"precise", &"projectiles"], RunBuildState.TREATMENT_PROJECTILES, &"add", 1.0, &"count", "Projektil", "Projektile", 1.0, 0, &"enemy", PackedStringArray(["precise"])).configure_offer(&"projectiles", UpgradeDefinition.Rarity.RARE, false, false, 5.0, 0.60),

		UpgradeDefinition.create(&"neutrophils", "Abwehrzellen", "Zwei Abwehrzellen umkreisen Doctor Milos.", UpgradeDefinition.Path.IMMUNE, 1, &"immune_level", 1.0, "Neutrophile Rekrutierung").configure_offer(&"unlock", UpgradeDefinition.Rarity.RARE, false, false).configure_case_availability(3),
		_run_upgrade(&"phagocytosis", "Abwehrzellenschaden", "+2 Schaden.", UpgradeDefinition.Path.IMMUNE, 0, &"immune_damage", 2.0, "Effiziente Phagozytose", [], [&"defense_cell", &"damage"], RunBuildState.DEFENSE_CELL_DAMAGE, &"add", 2.0, &"delta", "Schaden", "Schaden", 5.0, 0, &"enemy", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]).configure_offer(&"damage", UpgradeDefinition.Rarity.COMMON, true, false, 70.0),
		_run_upgrade(&"defense_cell_damage_magic", "Abwehrzellenschaden", "+3 Schaden.", UpgradeDefinition.Path.IMMUNE, 0, &"immune_damage", 3.0, "Vertiefte Phagozytose", [], [&"defense_cell", &"damage"], RunBuildState.DEFENSE_CELL_DAMAGE, &"add", 3.0, &"delta", "Schaden", "Schaden", 5.0, 0, &"enemy", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]).configure_offer(&"damage", UpgradeDefinition.Rarity.MAGIC, true, false, 25.0),
		_run_upgrade(&"defense_cell_damage_rare", "Abwehrzellenschaden", "+4 Schaden.", UpgradeDefinition.Path.IMMUNE, 0, &"immune_damage", 4.0, "Maximale Phagozytose", [], [&"defense_cell", &"damage"], RunBuildState.DEFENSE_CELL_DAMAGE, &"add", 4.0, &"delta", "Schaden", "Schaden", 5.0, 0, &"enemy", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]).configure_offer(&"damage", UpgradeDefinition.Rarity.RARE, true, false, 5.0),
		_run_upgrade(&"defense_cell_speed", "Attack Speed", "+3 % Attack Speed.", UpgradeDefinition.Path.IMMUNE, 0, &"run_modifier", 0.03, "Schnelle Abwehrreaktion", [], [&"defense_cell", &"rhythm"], RunBuildState.DEFENSE_CELL_HIT_INTERVAL, &"attack_speed_add", 0.03, &"tempo", "Attack Speed", "Attack Speed", 0.2, 0, &"", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]).configure_offer(&"attack_speed", UpgradeDefinition.Rarity.COMMON, true, false, 70.0),
		_run_upgrade(&"defense_cell_speed_magic", "Attack Speed", "+5 % Attack Speed.", UpgradeDefinition.Path.IMMUNE, 0, &"run_modifier", 0.05, "Beschleunigte Abwehrreaktion", [], [&"defense_cell", &"rhythm"], RunBuildState.DEFENSE_CELL_HIT_INTERVAL, &"attack_speed_add", 0.05, &"tempo", "Attack Speed", "Attack Speed", 0.2, 0, &"", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]).configure_offer(&"attack_speed", UpgradeDefinition.Rarity.MAGIC, true, false, 25.0),
		_run_upgrade(&"defense_cell_speed_rare", "Attack Speed", "+7 % Attack Speed.", UpgradeDefinition.Path.IMMUNE, 0, &"run_modifier", 0.07, "Hochfrequente Abwehrreaktion", [], [&"defense_cell", &"rhythm"], RunBuildState.DEFENSE_CELL_HIT_INTERVAL, &"attack_speed_add", 0.07, &"tempo", "Attack Speed", "Attack Speed", 0.2, 0, &"", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]).configure_offer(&"attack_speed", UpgradeDefinition.Rarity.RARE, true, false, 5.0),
		_run_upgrade(&"defense_cell_radius", "Größere Abwehrzellen", "+1 Radius.", UpgradeDefinition.Path.IMMUNE, 3, &"run_modifier", 30.0, "Erweiterte Zellreichweite", [], [&"defense_cell", &"area"], RunBuildState.DEFENSE_CELL_RADIUS, &"add", 30.0, &"distance_stage", "Radius", "Radius", CombatDistanceScale.world_from_stage(RunBuildState.BASE_DEFENSE_CELL_RADIUS_STAGE), 0, &"avatar", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]).configure_offer(&"radius", UpgradeDefinition.Rarity.COMMON, false, false),
		_run_upgrade(&"defense_cell_projectiles", "Mehr Abwehrzellen", "+1 Projektil.", UpgradeDefinition.Path.IMMUNE, 2, &"run_modifier", 1.0, "Zusätzliche Abwehrzelle", [], [&"defense_cell", &"projectiles"], RunBuildState.DEFENSE_CELL_PROJECTILES, &"add", 1.0, &"count", "Projektil", "Projektile", 2.0, 0, &"avatar", PackedStringArray(["defense_cell"])).require_upgrades([&"neutrophils"]).configure_offer(&"projectiles", UpgradeDefinition.Rarity.MAGIC, false, false, 1.0, 0.60),

		# Behandlungsspezifische Utility-Upgrades behalten ihre verdeckten Caps.
		_run_upgrade(&"spread_density", "Durchdringender Streuimpuls", "+1 Durchdringung.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"run_modifier", 1.0, "Vertiefte Streuwirkung", [&"treatment_spread"], [&"spread", &"line"], RunBuildState.TREATMENT_MAX_HITS, &"add", 1.0, &"count", "Durchdringung", "Treffer", 1.0, 0, &"enemy", PackedStringArray(["spread"])).configure_offer(&"penetration", UpgradeDefinition.Rarity.RARE, false, false, 5.0, 0.60),
		_run_upgrade(&"pierce_depth", "Tieferer Impuls", "+2 Durchdringungen.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"run_modifier", 2.0, "Erhöhte Gewebegängigkeit", [&"treatment_pierce"], [&"piercing", &"line"], RunBuildState.TREATMENT_MAX_HITS, &"add", 2.0, &"count", "Durchdringungen", "Treffer", 4.0, 0, &"enemy", PackedStringArray(["piercing"])).configure_offer(&"penetration", UpgradeDefinition.Rarity.MAGIC, false, false, 1.0, 0.70),

		# Stoß bleibt ohne das ausdrückliche Aktivtalent vollständig schadensfrei.
		_run_upgrade(&"burst_radius", "Breiter Stoß", "+1 Radius.", UpgradeDefinition.Path.IMMUNE, 2, &"run_modifier", 30.0, "Ausgedehnte Immunreaktion", [&"ability_defense_burst"], [&"active", &"defense", &"area"], RunBuildState.ABILITY_RADIUS, &"add", 30.0, &"distance_stage", "Radius", "Radius", 150.0, 0, &"ability", PackedStringArray(["active", "defense", "area"])).configure_offer(&"radius", UpgradeDefinition.Rarity.COMMON, false, false),
		_run_upgrade(&"burst_effect", "Stoßschaden", "+6 Schaden.", UpgradeDefinition.Path.IMMUNE, 0, &"run_modifier", 6.0, "Stoßwirkung", [&"ability_defense_burst"], [&"active", &"defense", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 6.0, &"delta", "Schaden", "Schaden", 0.0, 0, &"enemy", PackedStringArray(["active", "defense", "area"])).require_talents([&"defense_burst_damage"]).configure_offer(&"damage", UpgradeDefinition.Rarity.COMMON, true, false, 70.0),
		_run_upgrade(&"burst_effect_magic", "Stoßschaden", "+10 Schaden.", UpgradeDefinition.Path.IMMUNE, 0, &"run_modifier", 10.0, "Vertiefte Stoßwirkung", [&"ability_defense_burst"], [&"active", &"defense", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 10.0, &"delta", "Schaden", "Schaden", 0.0, 0, &"enemy", PackedStringArray(["active", "defense", "area"])).require_talents([&"defense_burst_damage"]).configure_offer(&"damage", UpgradeDefinition.Rarity.MAGIC, true, false, 25.0),
		_run_upgrade(&"burst_effect_rare", "Stoßschaden", "+14 Schaden.", UpgradeDefinition.Path.IMMUNE, 0, &"run_modifier", 14.0, "Maximale Stoßwirkung", [&"ability_defense_burst"], [&"active", &"defense", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 14.0, &"delta", "Schaden", "Schaden", 0.0, 0, &"enemy", PackedStringArray(["active", "defense", "area"])).require_talents([&"defense_burst_damage"]).configure_offer(&"damage", UpgradeDefinition.Rarity.RARE, true, false, 5.0),
		_run_upgrade(&"line_effect", "Lazerschaden", "+9 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 9.0, "Linienverstärkung", [&"ability_treatment_line"], [&"active", &"line", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 9.0, &"delta", "Schaden", "Schaden", 30.0, 0, &"enemy", PackedStringArray(["active", "treatment", "line"])).configure_offer(&"damage", UpgradeDefinition.Rarity.COMMON, true, false, 70.0),
		_run_upgrade(&"line_effect_magic", "Lazerschaden", "+15 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 15.0, "Vertiefte Linienwirkung", [&"ability_treatment_line"], [&"active", &"line", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 15.0, &"delta", "Schaden", "Schaden", 30.0, 0, &"enemy", PackedStringArray(["active", "treatment", "line"])).configure_offer(&"damage", UpgradeDefinition.Rarity.MAGIC, true, false, 25.0),
		_run_upgrade(&"line_effect_rare", "Lazerschaden", "+21 Schaden.", UpgradeDefinition.Path.ANTIBIOTIC, 0, &"run_modifier", 21.0, "Maximale Linienwirkung", [&"ability_treatment_line"], [&"active", &"line", &"damage"], RunBuildState.ABILITY_DAMAGE, &"add", 21.0, &"delta", "Schaden", "Schaden", 30.0, 0, &"enemy", PackedStringArray(["active", "treatment", "line"])).configure_offer(&"damage", UpgradeDefinition.Rarity.RARE, true, false, 5.0),
		_run_upgrade(&"line_width", "Breiterer Lazer", "+16 Breite.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"run_modifier", 16.0, "Erweiterte Linie", [&"ability_treatment_line"], [&"active", &"line", &"area"], RunBuildState.ABILITY_WIDTH, &"add", 16.0, &"delta", "Breite", "Breite", 38.0, 0, &"ability", PackedStringArray(["active", "treatment", "line"])).configure_offer(&"width", UpgradeDefinition.Rarity.MAGIC, false, false),
		_run_upgrade(&"mobility", "Galopp", "+6 Galopp.", UpgradeDefinition.Path.SUPPORT, 0, &"run_modifier", 6.0, "Mobilitätsreserve", [], [&"movement"], RunBuildState.MOVEMENT_SPEED, &"add", 6.0, &"delta", "Galopp", "Galopp", PlayerStats.BASE_MOVEMENT_SPEED, 0, &"avatar", PackedStringArray()).configure_offer(&"movement", UpgradeDefinition.Rarity.COMMON, true, false, 70.0),
		_run_upgrade(&"mobility_magic", "Galopp", "+10 Galopp.", UpgradeDefinition.Path.SUPPORT, 0, &"run_modifier", 10.0, "Vertiefte Mobilitätsreserve", [], [&"movement"], RunBuildState.MOVEMENT_SPEED, &"add", 10.0, &"delta", "Galopp", "Galopp", PlayerStats.BASE_MOVEMENT_SPEED, 0, &"avatar", PackedStringArray()).configure_offer(&"movement", UpgradeDefinition.Rarity.MAGIC, true, false, 25.0),
		_run_upgrade(&"mobility_rare", "Galopp", "+14 Galopp.", UpgradeDefinition.Path.SUPPORT, 0, &"run_modifier", 14.0, "Maximale Mobilitätsreserve", [], [&"movement"], RunBuildState.MOVEMENT_SPEED, &"add", 14.0, &"delta", "Galopp", "Galopp", PlayerStats.BASE_MOVEMENT_SPEED, 0, &"avatar", PackedStringArray()).configure_offer(&"movement", UpgradeDefinition.Rarity.RARE, true, false, 5.0),
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
	# Timed clinic work and offline research were retired. The empty compatibility
	# catalog keeps old callers harmless while the Practice UI is now test-only.
	return {}

static func research_definitions() -> Array[ResearchDefinition]:
	return [
		ResearchDefinition.create(&"stability_reserve", "Mehr Leben", "+3 maximales Leben je Rang", PackedInt32Array([50, 350, 800]), &"max_health", 3.0),
		ResearchDefinition.create(&"therapy_precision", "Stärkere Behandlung", "+2 % Schaden der Behandlungen je Rang", PackedInt32Array([63, 425, 950]), &"damage_multiplier", 0.02),
		ResearchDefinition.create(&"experience_gain", "Mehr Erfahrung", "+5 % Erfahrung je Rang", PackedInt32Array([63, 425, 950]), &"experience_multiplier", 0.05),
		ResearchDefinition.create(&"defense_training", "Mehr Verteidigung", "+2 Verteidigung je Rang", PackedInt32Array([75, 450, 1000]), &"defense", 2.0),
		ResearchDefinition.create(&"life_regeneration", "Lebensregeneration", "+0,25 Leben pro Sekunde je Rang", PackedInt32Array([75, 450, 1000]), &"life_regeneration", 0.25),
		ResearchDefinition.create(&"unlock_spread_treatment", "Streuimpuls", "Schaltet die streuende Grundbehandlung frei", PackedInt32Array([300]), &"unlock", 1.0).configure_unlock(&"treatment_spread", &"treatment"),
		ResearchDefinition.create(&"unlock_piercing_treatment", "Durchdringender Impuls", "Schaltet die durchdringende Grundbehandlung frei", PackedInt32Array([500]), &"unlock", 1.0).configure_unlock(&"treatment_pierce", &"treatment"),
		ResearchDefinition.create(&"movement_training", "Mehr Galopp", "+3 % Galopp je Rang", PackedInt32Array([75, 450, 1000]), &"movement_speed_multiplier", 0.03),
		ResearchDefinition.create(&"unlock_defense_burst", "Stoß", "Schaltet Stoß frei", PackedInt32Array([30]), &"unlock", 1.0).configure_unlock(&"ability_defense_burst", &"ability"),
		ResearchDefinition.create(&"unlock_treatment_line", "Fetter lazer", "Nach Fall 1 kostenlos im Forschungsgebäude freischalten", PackedInt32Array([0]), &"unlock", 1.0).configure_unlock(&"ability_treatment_line", &"ability"),
	]

static func loadout_module_definitions() -> Dictionary:
	return {
		&"treatment_precision": LoadoutModuleDefinition.create(&"treatment_precision", "Impuls", "Verfolgt ein einzelnes Ziel mit hohem Grundschaden.", LoadoutModuleDefinition.Kind.TREATMENT, 2, [&"treatment", &"precision"], &"", true),
		&"treatment_spread": LoadoutModuleDefinition.create(&"treatment_spread", "Streuimpuls", "Trifft drei Ziele mit schwächeren Einzelimpulsen.", LoadoutModuleDefinition.Kind.TREATMENT, 2, [&"treatment", &"spread"], &"unlock_spread_treatment"),
		&"treatment_pierce": LoadoutModuleDefinition.create(&"treatment_pierce", "Durchdringender Impuls", "Durchquert mehrere Gegner in einer Linie.", LoadoutModuleDefinition.Kind.TREATMENT, 2, [&"treatment", &"pierce"], &"unlock_piercing_treatment"),
		&"ability_focus_field": LoadoutModuleDefinition.create(&"ability_focus_field", "Fokusfeld", "Behandlung im Zielgebiet verursacht 25 % mehr Schaden.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"focus", &"control"], &"", true),
		&"ability_emergency_support": LoadoutModuleDefinition.create(&"ability_emergency_support", "Notfallhilfe", "Stellt 14 Leben wieder her und gewährt 8 Schild.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"support"], &"", true),
		&"ability_defense_burst": LoadoutModuleDefinition.create(&"ability_defense_burst", "Stoß", "Stößt Gegner zurück, betäubt sie für 1 Sekunde und unterbindet den Beschuss getroffener Nichtbosse für 10 Sekunden. Verursacht ohne Talent keinen Schaden.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"control"], &"unlock_defense_burst"),
		&"ability_treatment_line": LoadoutModuleDefinition.create(&"ability_treatment_line", "Fetter lazer", "30 Schaden in einer durchdringenden Linie.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"damage", &"pierce"], &"unlock_treatment_line"),
		&"ability_protection_field": LoadoutModuleDefinition.create(&"ability_protection_field", "Schildfeld", "Gegner im Feld: −35 % Geschwindigkeit und Schaden.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"control", &"support"], &"unlock_protection_field"),
		&"ability_sample_pull": LoadoutModuleDefinition.create(&"ability_sample_pull", "Erfahrungszug", "Zieht Erfahrung an und beschleunigt kurz den Befund.", LoadoutModuleDefinition.Kind.ABILITY, 2, [&"active", &"samples", &"diagnosis"], &"unlock_sample_pull"),
	}

static func case_trait_definitions() -> Dictionary:
	var all_levels: Array[StringName] = [&"early_localized_focus", &"localized_focus", &"advancing_infection", &"spreading_infection", &"critical_infection", &"severe_pneumonia"]
	return {
		&"monster_resistance_20": CaseTraitDefinition.create(&"monster_resistance_20", "Resistente Erreger", "+20 % Widerstand für Gegner.", [{"stat_id": &"enemy_resistance_effective", "operation": &"add", "value": 20.0}], all_levels, &"negative"),
		&"monster_defense_10": CaseTraitDefinition.create(&"monster_defense_10", "Gepanzerte Erreger", "+10 Gegnerverteidigung.", [{"stat_id": &"enemy_defense", "operation": &"add", "value": 10.0}], all_levels, &"negative"),
		&"monster_speed_15": CaseTraitDefinition.create(&"monster_speed_15", "Schnelle Erreger", "+15 % Gegnergeschwindigkeit.", [{"stat_id": &"enemy_speed", "operation": &"multiply", "value": 1.15}], all_levels, &"negative"),
		&"monster_health_15": CaseTraitDefinition.create(&"monster_health_15", "Robuste Erreger", "+15 % Leben für reguläre Gegner und Bosse.", [{"stat_id": &"enemy_health", "operation": &"multiply", "value": 1.15}, {"stat_id": &"boss_health", "operation": &"multiply", "value": 1.15}], all_levels, &"negative"),
		&"monster_damage_15": CaseTraitDefinition.create(&"monster_damage_15", "Aggressive Erreger", "+15 % Gegnerschaden.", [{"stat_id": &"enemy_damage", "operation": &"multiply", "value": 1.15}], all_levels, &"negative"),
		&"double_boss": CaseTraitDefinition.create(&"double_boss", "Doppelherd", "Zwei Infektionsherde müssen kontrolliert werden.", [{"stat_id": &"boss_count", "operation": &"override", "value": 2.0}], all_levels, &"mixed"),
		&"monster_spawn_10": CaseTraitDefinition.create(&"monster_spawn_10", "Hohe Keimlast", "+10 % Spawnrate.", [{"stat_id": &"spawn_rate", "operation": &"multiply", "value": 1.10}], all_levels, &"mixed"),
		&"experience_10": CaseTraitDefinition.create(&"experience_10", "Lerngewinn", "+10 % Erfahrung.", [{"stat_id": &"experience_gain", "operation": &"multiply", "value": 1.10}], all_levels, &"positive"),
	}

static func finding_definitions() -> Dictionary:
	var all_levels: Array[StringName] = [&"early_localized_focus", &"localized_focus", &"advancing_infection", &"spreading_infection", &"critical_infection", &"severe_pneumonia"]
	return {
		&"grouping": FindingDefinition.create(&"grouping", "Gruppenbildung", "Platzhalter für einen später ausgearbeiteten medizinischen Befund.", "Platzhalter · dieser Befund verändert den aktuellen Run nicht.", FindingDefinition.Behavior.NONE, 0.0, [&"group_area", &"group_control", &"group_safety"], all_levels),
		&"hidden_nests": FindingDefinition.create(&"hidden_nests", "Verdeckte Nester", "Platzhalter für einen später ausgearbeiteten medizinischen Befund.", "Platzhalter · dieser Befund verändert den aktuellen Run nicht.", FindingDefinition.Behavior.NONE, 0.0, [&"nest_damage", &"nest_range", &"nest_samples"], all_levels),
	}

static func reaction_definitions() -> Dictionary:
	return {
		&"group_area": ReactionDefinition.create(&"group_area", &"grouping", "Option A", "Platzhalter · noch keine Spielwirkung.", [], [&"damage"]),
		&"group_control": ReactionDefinition.create(&"group_control", &"grouping", "Option B", "Platzhalter · noch keine Spielwirkung.", [], [&"control"]),
		&"group_safety": ReactionDefinition.create(&"group_safety", &"grouping", "Option C", "Platzhalter · noch keine Spielwirkung.", [], [&"support"]),
		&"nest_damage": ReactionDefinition.create(&"nest_damage", &"hidden_nests", "Option A", "Platzhalter · noch keine Spielwirkung.", [], [&"damage"]),
		&"nest_range": ReactionDefinition.create(&"nest_range", &"hidden_nests", "Option B", "Platzhalter · noch keine Spielwirkung.", [], [&"pierce"]),
		&"nest_samples": ReactionDefinition.create(&"nest_samples", &"hidden_nests", "Option C", "Platzhalter · noch keine Spielwirkung.", [], [&"samples"]),
	}

static func choose_upgrades(
	levels: Dictionary,
	rng: RandomNumberGenerator,
	count: int = 3,
	force_all_paths: bool = false,
	excluded_ids: Array[StringName] = [],
	campaign_case_order: int = -1,
	talent_ranks: Dictionary = {},
	higher_rarity_factor: float = 1.0
) -> Array[UpgradeDefinition]:
	var definitions := upgrade_definitions()
	var component_ids: Array[StringName] = [
		&"treatment_precision", &"treatment_spread", &"treatment_pierce",
		&"ability_defense_burst", &"ability_treatment_line"
	]
	var tags: Array[StringName] = [
		&"treatment", &"precise", &"spread", &"piercing", &"tracking",
		&"active", &"defense", &"line", &"defense_cell", &"movement"
	]
	var selected: Array[UpgradeDefinition] = []
	if force_all_paths and count >= 3:
		for path in [UpgradeDefinition.Path.ANTIBIOTIC, UpgradeDefinition.Path.IMMUNE, UpgradeDefinition.Path.SUPPORT]:
			var matching: Array[UpgradeDefinition] = []
			for definition in definitions:
				if definition.path == path:
					matching.append(definition)
			var path_pick := UpgradePoolBuilder.choose(matching, levels, rng, component_ids, tags, 1, excluded_ids, false, campaign_case_order, talent_ranks, higher_rarity_factor)
			if not path_pick.is_empty():
				selected.append(path_pick[0])
	var combined_excluded := excluded_ids.duplicate()
	for item in selected:
		combined_excluded.append(item.id)
	if selected.size() < count:
		var remaining := UpgradePoolBuilder.choose(
			definitions,
			levels,
			rng,
			component_ids,
			tags,
			count - selected.size(),
			combined_excluded,
			false,
			campaign_case_order,
			talent_ranks,
			higher_rarity_factor
		)
		selected.append_array(remaining)
	return selected
