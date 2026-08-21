class_name LexiconCatalog
extends RefCounted

const CATEGORY_ORDER: Array[StringName] = [
	LexiconEntryDefinition.CATEGORY_MONSTERS,
	LexiconEntryDefinition.CATEGORY_CHARACTER,
	LexiconEntryDefinition.CATEGORY_GAMEPLAY,
	LexiconEntryDefinition.CATEGORY_TERMS,
]

const CATEGORY_NAMES := {
	LexiconEntryDefinition.CATEGORY_MONSTERS: "Monster",
	LexiconEntryDefinition.CATEGORY_CHARACTER: "Charakter",
	LexiconEntryDefinition.CATEGORY_GAMEPLAY: "Spielelemente",
	LexiconEntryDefinition.CATEGORY_TERMS: "Begriffe",
}

const CHARACTER_TERM_IDS: Array[StringName] = [
	&"patient_stability",
	&"effect",
	&"treatment_speed",
	&"range",
	&"targets",
	&"projectiles",
	&"penetration",
	&"shield",
	&"defense",
	&"life_regeneration",
	&"movement_speed",
	&"experience_gain",
	&"resistance",
	&"fire_damage",
	&"water_damage",
	&"earth_damage",
	&"wind_damage",
	&"cooldown",
]

static func entries() -> Array[LexiconEntryDefinition]:
	var result: Array[LexiconEntryDefinition] = []
	_append_enemy_entries(result)
	_append_character_entries(result)
	_append_gameplay_entries(result)
	_append_terminology_entries(result)
	return result

static func entries_by_id() -> Dictionary:
	var result := {}
	for entry in entries():
		result[entry.id] = entry
	return result

static func entries_for_category(category: StringName) -> Array[LexiconEntryDefinition]:
	var result: Array[LexiconEntryDefinition] = []
	for entry in entries():
		if entry.category == category:
			result.append(entry)
	return result

static func category_name(category: StringName) -> String:
	return String(CATEGORY_NAMES.get(category, "Lexikon"))

static func _append_enemy_entries(result: Array[LexiconEntryDefinition]) -> void:
	var enemies := ContentCatalog.enemy_definitions()
	var roles := {
		&"pneumococcus": ["Schneller Einzelerreger", "Bewegt sich direkt auf Doctor Milos zu und verursacht Schaden, wenn er ihn erreicht."],
		&"bacterial_cluster": ["Widerstandsfähige Gruppe", "Bewegt sich langsamer, hält mehr aus und hinterlässt mehr Erfahrung."],
		&"minor_focus": ["Langsames Nebenziel", "Bewegt sich langsam und setzt nach einiger Zeit weitere Bakterien frei, wenn es nicht rechtzeitig kontrolliert wird."],
		&"localized_boss": ["Erster Bossgegner", "Ein einfacher lokaler Boss. Bei 70 Prozent Leben erscheinen drei Bakterien."],
		&"infection_focus": ["Bossgegner", "Seine Phasen erhöhen den Druck im Fall. Die tatsächlichen Werte werden je Fall skaliert."],
	}
	for id in [&"pneumococcus", &"bacterial_cluster", &"minor_focus", &"localized_boss", &"infection_focus"]:
		var enemy: EnemyDefinition = enemies[id]
		var role: Array = roles[id]
		result.append(LexiconEntryDefinition.create(
			enemy.id,
			LexiconEntryDefinition.CATEGORY_MONSTERS,
			enemy.display_name,
			enemy.medical_name,
			String(role[0]),
			String(role[1]),
			"",
			enemy.visual_id,
			LexiconEntryDefinition.SOURCE_ENEMY,
			enemy.id,
			enemy.discovery_id,
			false,
			[&"enemy_damage", &"resistance", &"analysis"]
		))

static func _append_character_entries(result: Array[LexiconEntryDefinition]) -> void:
	result.append(LexiconEntryDefinition.create(
		&"character_stats",
		LexiconEntryDefinition.CATEGORY_CHARACTER,
		"Doctor Milos",
		"",
		"Der beste Doctor mit Bandana.",
		"Doctor Milos besitzt eigenes Leben, Verteidigung, Lebensregeneration und Resistenzen. Die hier gezeigten Werte sind seine aktuelle Datenbasis vor Ausbauten im Run.",
		"Die Spielfigur stellt die koordinierende Rolle des Behandlungsteams vereinfacht dar.",
		&"character_stats",
		LexiconEntryDefinition.SOURCE_PLAYER,
		&"player_stats",
		&"character_stats",
		true,
		[&"patient_stability", &"defense", &"life_regeneration", &"resistance", &"basic_treatment", &"active_ability"]
	))

static func _append_gameplay_entries(result: Array[LexiconEntryDefinition]) -> void:
	var discoveries := ContentCatalog.discovery_definitions()
	var copy := {
		&"analysis_pickup": ["Erfahrung im laufenden Fall", "Gesammelte Erfahrung füllt die Leiste für das nächste Level."],
		&"patient_stability": ["Leben von Doctor Milos", "Gegnerschaden senkt das Leben. Bei null endet der Fall."],
		&"automatic_therapy": ["Automatische Grundbehandlung", "Wählt gültige Ziele selbstständig aus. Steuerung, aktive Fähigkeiten und Ausbau bleiben deine Entscheidungen."],
		&"neutrophil_orbit": ["Abwehr im Nahbereich", "Abwehrzellen umkreisen Doctor Milos und verursachen nur bei einer tatsächlichen Kollision Schaden."],
		&"supportive_oxygenation": ["Automatische Heilung", "Regeneration stellt jede Sekunde Leben wieder her. Forschung erhöht die geheilte Menge pro Sekunde."],
		&"boss_phases": ["Phasen des Bosses", "Phasengrenzen verändern den Kampf und können zusätzliche Bakterien freisetzen."],
		&"research_reward": ["Dauerhafter Fortschritt", "Forschung wird zwischen den Fällen für Freischaltungen und Verbesserungen ausgegeben."],
	}
	for id in [&"analysis_pickup", &"patient_stability", &"automatic_therapy", &"neutrophil_orbit", &"supportive_oxygenation", &"boss_phases", &"research_reward"]:
		var discovery: DiscoveryDefinition = discoveries[id]
		var text: Array = copy[id]
		result.append(LexiconEntryDefinition.create(
			discovery.id,
			LexiconEntryDefinition.CATEGORY_GAMEPLAY,
			discovery.title,
			"Lebensregeneration" if discovery.id == &"supportive_oxygenation" else discovery.medical_name,
			String(text[0]),
			String(text[1]),
			"Regeneration ist im Spiel eine abstrahierte, dauerhafte Erholung von Doctor Milos." if discovery.id == &"supportive_oxygenation" else discovery.medical_text,
			_illustration_id(discovery.id),
			LexiconEntryDefinition.SOURCE_DISCOVERY,
			discovery.id,
			discovery.id,
			discovery.id == &"supportive_oxygenation" or ContentCatalog.is_discovery_unlocked_by_default(discovery.id),
			_gameplay_related_ids(discovery.id)
		))

static func _append_terminology_entries(result: Array[LexiconEntryDefinition]) -> void:
	for terminology in TerminologyCatalog.all():
		if terminology.id == &"reserve":
			continue
		result.append(LexiconEntryDefinition.create(
			StringName("term_%s" % terminology.id),
			LexiconEntryDefinition.CATEGORY_CHARACTER if CHARACTER_TERM_IDS.has(terminology.id) else LexiconEntryDefinition.CATEGORY_TERMS,
			terminology.display_name,
			terminology.medical_name,
			terminology.summary,
			terminology.gameplay_text,
			"",
			terminology.visual_id,
			LexiconEntryDefinition.SOURCE_TERMINOLOGY,
			terminology.id,
			&"",
			true,
			terminology.related_ids
		))

static func _illustration_id(id: StringName) -> StringName:
	match id:
		&"neutrophil_orbit":
			return &"neutrophil_orbit"
		_:
			return id

static func _gameplay_related_ids(id: StringName) -> Array[StringName]:
	match id:
		&"analysis_pickup":
			return [&"analysis", &"level", &"finding"]
		&"patient_stability":
			return [&"patient_stability", &"enemy_damage", &"defense", &"life_regeneration"]
		&"automatic_therapy":
			return [&"basic_treatment", &"effect", &"interval"]
		&"neutrophil_orbit":
			return [&"immune_path", &"effect", &"range"]
		&"supportive_oxygenation":
			return [&"life_regeneration", &"patient_stability", &"research"]
		&"boss_phases":
			return [&"boss_phase", &"case_trait"]
		&"research_reward":
			return [&"research", &"talent_points", &"mastery"]
	return []
