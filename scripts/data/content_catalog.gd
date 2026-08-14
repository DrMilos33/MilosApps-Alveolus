class_name ContentCatalog
extends RefCounted

static func create_run_config(level: LevelDefinition = null, quick_run: bool = false) -> RunConfig:
	var selected := level_definitions()[0] if level == null else level
	return RunConfig.from_level(selected, quick_run)

static func level_definitions() -> Array[LevelDefinition]:
	return [
		LevelDefinition.create(
			&"intro", 0, "Das Lungenmodell", "Einführung · Grundlagen der Behandlung", true,
			0.0, 0.0, 120.0, 1.10, 0.55, 0.55, 0.70, 0.80, 0.50, 0.0, 0.05,
			0.18, PackedInt32Array(), 1.0,
			"Lerne Bewegung, automatische Therapie, Analyse und die drei Therapiepfade kennen.",
			"Das erste Lungenmodell ist stabilisiert. Die regulären Patientenfälle stehen nun bereit.",
			"Das Modell blieb instabil. Wiederhole die Einführung in deinem eigenen Tempo."
		),
		LevelDefinition.create(
			&"localized_focus", 1, "Lokalisierter Pneumokokkenherd", "Fall 01 · frühe Infektionskontrolle", false,
			180.0, 135.0, 90.0, 0.62, 0.14, 1.15, 1.70, 1.08, 1.25, 0.10, 0.28,
			0.75, PackedInt32Array([3, 4]), 1.0,
			"Ein lokalisierter bakterieller Herd erhöht die Infektionslast. Kontrolliere ihn, bevor die Stabilität erschöpft ist.",
			"Der lokalisierte Infektionsherd wurde kontrolliert.",
			"Die Infektionslast konnte in diesem Versuch nicht ausreichend kontrolliert werden."
		),
		LevelDefinition.create(
			&"spreading_infection", 2, "Ausbreitende bakterielle Pneumonie", "Fall 02 · zunehmende Bakterienverbände", false,
			240.0, 180.0, 85.0, 0.52, 0.11, 1.35, 2.05, 1.16, 1.45, 0.18, 0.38,
			1.05, PackedInt32Array([4, 6]), 1.35,
			"Mehrere Bakterienverbände breiten sich gleichzeitig aus. Positionierung und Therapieaufbau werden entscheidend.",
			"Die ausbreitende Infektion wurde eingegrenzt.",
			"Die Ausbreitung überstieg die verfügbare Patientenstabilität."
		),
		LevelDefinition.create(
			&"severe_pneumonia", 3, "Schwere bakterielle Pneumonie", "Fall 03 · hohe Infektionsdynamik", false,
			300.0, 225.0, 80.0, 0.44, 0.09, 1.55, 2.40, 1.24, 1.65, 0.25, 0.48,
			1.35, PackedInt32Array([6, 8]), 1.70,
			"Hohe Infektionsdynamik belastet den Patienten. Ein tragfähiger Build und konsequente Bewegung sind erforderlich.",
			"Auch der schwere Infektionsverlauf wurde kontrolliert.",
			"Der schwere Verlauf blieb außerhalb des kontrollierbaren Therapiefensters."
		)
	]

static func tutorial_hint_definitions() -> Dictionary:
	return {
		&"movement": TutorialHintDefinition.create(&"movement", &"run_started", "Im Lungenmodell bewegen", "Bewege den Therapie-Avatar mit WASD oder den Pfeiltasten. Gegnerkontakt senkt die Patientenstabilität."),
		&"therapy": TutorialHintDefinition.create(&"therapy", &"first_shot", "Therapie arbeitet automatisch", "Der antibiotische Impuls wählt ein nahes bakterielles Ziel selbstständig aus."),
		&"analysis": TutorialHintDefinition.create(&"analysis", &"first_analysis", "Analyse aufnehmen", "Besiegte Erreger hinterlassen Analyse. Eine volle Leiste ermöglicht eine Therapieanpassung."),
		&"upgrade": TutorialHintDefinition.create(&"upgrade", &"first_upgrade", "Therapiepfade verstehen", "Antibiotika wirken direkt gegen Bakterien, Immununterstützung schützt den Nahbereich und supportive Therapie stabilisiert den Patienten."),
		&"boss": TutorialHintDefinition.create(&"boss", &"boss_spawned", "Infektionsherd", "Kontrolliere den Infektionsherd vor Ablauf der verbleibenden Behandlungszeit.")
	}

static func enemy_definitions() -> Dictionary:
	return {
		&"pneumococcus": EnemyDefinition.create(
			&"pneumococcus", "Pneumokokke", 22.0, 92.0, 2.2, 1, 18.0, Color("e56379"), false, &"pneumococcus"
		),
		&"bacterial_cluster": EnemyDefinition.create(
			&"bacterial_cluster", "Bakterienverband", 74.0, 55.0, 5.0, 4, 30.0, Color("b64862"), false, &"bacterial_cluster"
		),
		&"infection_focus": EnemyDefinition.create(
			&"infection_focus", "Infektionsherd", 2200.0, 34.0, 9.0, 30, 72.0, Color("872d4d"), true, &"infection_focus"
		)
	}

static func discovery_definitions() -> Dictionary:
	return {
		&"pneumococcus": DiscoveryDefinition.create(
			&"pneumococcus", &"enemy_materialized", "Pneumokokke",
			"Pneumokokken sind Bakterien, die unter anderem eine Lungenentzündung verursachen können.",
			"Schneller Einzelerreger · geringer Kontaktschaden · 1 Analyse.", &"enemy", 100, &"erreger"
		),
		&"bacterial_cluster": DiscoveryDefinition.create(
			&"bacterial_cluster", &"enemy_materialized", "Bakterienverband",
			"Der Verband steht vereinfacht für eine größere lokale bakterielle Belastung.",
			"Langsamer, widerstandsfähiger und gefährlicher bei Kontakt · 4 Analyse.", &"enemy", 90, &"erreger"
		),
		&"infection_focus": DiscoveryDefinition.create(
			&"infection_focus", &"enemy_materialized", "Infektionsherd",
			"Der Infektionsherd ist eine spielerische Darstellung der konzentrierten bakteriellen Belastung.",
			"Bossgegner · löst bei 70 % und 40 % Stabilität Minion-Schübe aus.", &"enemy", 110, &"erreger"
		),
		&"analysis_pickup": DiscoveryDefinition.create(
			&"analysis_pickup", &"pickup_spawned", "Analyse",
			"Analyse steht vereinfacht für verwertbare Informationen aus kontrollierten Erregern.",
			"Aufnehmen füllt die Leiste am unteren Rand. Eine volle Leiste ermöglicht ein Upgrade.", &"pickup", 80, &"grundlagen"
		),
		&"patient_stability": DiscoveryDefinition.create(
			&"patient_stability", &"run_started", "Patientenstabilität",
			"Die Anzeige bündelt den allgemeinen Zustand des Patienten zu einem verständlichen Spielwert.",
			"Gegnerkontakt senkt die Stabilität. Bei 0 endet die Behandlung.", &"stability_bar", 120, &"grundlagen"
		),
		&"automatic_therapy": DiscoveryDefinition.create(
			&"automatic_therapy", &"first_shot", "Automatische Therapie",
			"Die Impulse stellen eine abstrahierte antibakterielle Behandlung dar.",
			"Ziele werden automatisch gewählt. Du steuerst Positionierung und Upgrades.", &"projectile", 85, &"therapie"
		),
		&"neutrophil_orbit": DiscoveryDefinition.create(
			&"neutrophil_orbit", &"upgrade_applied", "Neutrophile Umlaufbahn",
			"Neutrophile Granulozyten gehören zur angeborenen Immunabwehr und reagieren früh auf Bakterien.",
			"2 Neutrophile · 10 Wirkung alle 0,76 s · Schutzradius 116.", &"avatar", 70, &"therapie"
		),
		&"supportive_oxygenation": DiscoveryDefinition.create(
			&"supportive_oxygenation", &"upgrade_applied", "Supportive Oxygenierung",
			"Oxygenierung unterstützt den Patienten, bekämpft Bakterien aber nicht direkt.",
			"Regeneriert 4 Stabilität alle 5,65 s.", &"stability_bar", 70, &"therapie"
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

static func arena_visual_definitions() -> Dictionary:
	return {
		&"intro": ArenaVisualDefinition.create(&"intro", Color("10252b"), Color("23484b"), Color("779a91"), Color("492a33"), Color("a85e68"), 3101, 0.12),
		&"localized_focus": ArenaVisualDefinition.create(&"localized_focus", Color("132329"), Color("29484a"), Color("829b8f"), Color("4b2830"), Color("c95f68"), 4202, 0.34),
		&"spreading_infection": ArenaVisualDefinition.create(&"spreading_infection", Color("142127"), Color("304347"), Color("8a968d"), Color("52272f"), Color("d45b68"), 5303, 0.56),
		&"severe_pneumonia": ArenaVisualDefinition.create(&"severe_pneumonia", Color("151c23"), Color("393b42"), Color("8c8586"), Color("5a232e"), Color("d94b60"), 6404, 0.78)
	}

static func upgrade_definitions() -> Array[UpgradeDefinition]:
	return [
		UpgradeDefinition.create(&"potency", "Gezielte Wirksamkeit", "+8 Therapiewirkung pro Treffer.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"damage", 8.0),
		UpgradeDefinition.create(&"rhythm", "Verlässlicher Rhythmus", "Die automatische Therapie wird 16 % häufiger angewendet.", UpgradeDefinition.Path.ANTIBIOTIC, 3, &"cooldown_multiplier", 0.84),
		UpgradeDefinition.create(&"penetration", "Gewebegängigkeit", "+85 Reichweite im betroffenen Lungenareal.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"range", 85.0),
		UpgradeDefinition.create(&"parallel_sites", "Parallele Wirkorte", "Ein zusätzliches Ziel wird pro Intervall behandelt.", UpgradeDefinition.Path.ANTIBIOTIC, 2, &"targets", 1.0),
		UpgradeDefinition.create(&"neutrophils", "Neutrophile Rekrutierung", "Granulozyten schützen den unmittelbaren Nahbereich.", UpgradeDefinition.Path.IMMUNE, 3, &"immune_level", 1.0),
		UpgradeDefinition.create(&"phagocytosis", "Effiziente Phagozytose", "+6 Wirkung jeder Immunantwort.", UpgradeDefinition.Path.IMMUNE, 3, &"immune_damage", 6.0),
		UpgradeDefinition.create(&"oxygenation", "Unterstützende Oxygenierung", "Regeneriert regelmäßig Patientenstabilität, ohne Erreger zu schädigen.", UpgradeDefinition.Path.SUPPORT, 3, &"support_level", 1.0),
		UpgradeDefinition.create(&"monitoring", "Engmaschiges Monitoring", "+14 maximale und aktuelle Patientenstabilität.", UpgradeDefinition.Path.SUPPORT, 2, &"max_stability", 14.0),
		UpgradeDefinition.create(&"analysis_radius", "Gezielte Probengewinnung", "Analyse wird aus 75 größerer Entfernung erfasst.", UpgradeDefinition.Path.SUPPORT, 2, &"pickup_range", 75.0)
	]

static func clinic_job_definitions() -> Dictionary:
	return {
		&"short_review": ClinicJobDefinition.create(&"short_review", "Kurzbefund", 5 * 60, 6),
		&"follow_up": ClinicJobDefinition.create(&"follow_up", "Verlaufskontrolle", 20 * 60, 18),
		&"complex_case": ClinicJobDefinition.create(&"complex_case", "Komplexer Fall", 60 * 60, 42)
	}

static func research_definitions() -> Array[ResearchDefinition]:
	return [
		ResearchDefinition.create(&"stability_reserve", "Stabilitätsreserve", "+3 Start-Maximalstabilität je Rang", PackedInt32Array([20, 45, 80]), &"max_stability", 3.0),
		ResearchDefinition.create(&"therapy_precision", "Therapiepräzision", "+2 % Basiswirkung je Rang", PackedInt32Array([25, 55, 95]), &"damage_multiplier", 0.02),
		ResearchDefinition.create(&"sample_logistics", "Probenlogistik", "+5 % Analyse-Aufnahmereichweite je Rang", PackedInt32Array([20, 45, 80]), &"pickup_multiplier", 0.05),
		ResearchDefinition.create(&"preanalysis", "Voranalyse", "Jeder Run beginnt mit 2 / 5 Analyse", PackedInt32Array([70]), &"initial_analysis", 2.0),
		ResearchDefinition.create(&"second_opinion", "Zweitmeinung", "Einmal pro Run drei neue Upgrades wählen", PackedInt32Array([100]), &"upgrade_reroll", 1.0)
	]

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
