class_name TerminologyCatalog
extends RefCounted

# Compatibility surface for existing HUD and tutorial callers. Rich explanations
# live in TerminologyDefinition instances below.
const ENTRIES := {
	&"patient_stability": {"simple": "Leben", "medical": "Lebenspunkte"},
	&"analysis": {"simple": "Erfahrung", "medical": "Analysepunkt"},
	&"level": {"simple": "Level", "medical": "Fortschrittsstufe"},
	&"run": {"simple": "Run", "medical": "Behandlungsdurchlauf"},
	&"case": {"simple": "Fall", "medical": "Patientenfall"},
	&"upgrade": {"simple": "Ausbau", "medical": "Temporäre Therapieanpassung"},
	&"reaction": {"simple": "Reaktion", "medical": "Reaktion auf einen Befund"},
	&"boss": {"simple": "Boss", "medical": "Zentraler Infektionsherd"},
	&"effect": {"simple": "Schaden", "medical": "Therapeutischer Schaden"},
	&"treatment_speed": {"simple": "Attack Speed", "medical": "Applikationsfrequenz"},
	&"interval": {"simple": "Intervall", "medical": "Zeitabstand"},
	&"range": {"simple": "Reichweite", "medical": "Wirkradius"},
	&"targets": {"simple": "Ziele", "medical": "Zielzahl"},
	&"projectiles": {"simple": "Projektile", "medical": "Behandlungsimpulse"},
	&"penetration": {"simple": "Durchdringung", "medical": "Gewebegängigkeit"},
	&"antibiotic_path": {"simple": "Behandlung", "medical": "Antibiotische Therapie"},
	&"immune_path": {"simple": "Abwehr", "medical": "Immununterstützung"},
	&"support_path": {"simple": "Regeneration", "medical": "Supportive Therapie"},
	&"shield": {"simple": "Schild", "medical": "Temporärer Schutzpuffer"},
	&"finding": {"simple": "Befund", "medical": "Diagnostischer Befund"},
	&"finding_progress": {"simple": "Befundfortschritt", "medical": "Diagnostischer Fortschritt"},
	&"case_trait": {"simple": "Fallmerkmal", "medical": "Klinische Besonderheit"},
	&"basic_treatment": {"simple": "Grundbehandlung", "medical": "Basistherapie"},
	&"active_ability": {"simple": "Aktive Fähigkeit", "medical": "Aktive Maßnahme"},
	&"passive_module": {"simple": "Passivmodul", "medical": "Vorbereitete Unterstützung"},
	&"reserve": {"simple": "Reserve", "medical": "Vorbereitete Ersatzmaßnahme"},
	&"capacity": {"simple": "Kapazität", "medical": "Planungskapazität"},
	&"research": {"simple": "Forschung", "medical": "Dauerhafter Erkenntnisgewinn"},
	&"talent_points": {"simple": "Talentpunkte", "medical": "Planungspunkte"},
	&"mastery": {"simple": "Meisterschaft", "medical": "Fallbezogene Erfahrung"},
	&"enemy_damage": {"simple": "Gegnerschaden", "medical": "Verursachter Schaden"},
	&"defense": {"simple": "Verteidigung", "medical": "Schadensminderung"},
	&"life_regeneration": {"simple": "Lebensregeneration", "medical": "Regenerative Erholung"},
	&"resistance": {"simple": "Resistenz", "medical": "Schadenstypresistenz"},
	&"fire_damage": {"simple": "Feuer", "medical": "Feuerschaden"},
	&"water_damage": {"simple": "Wasser", "medical": "Wasserschaden"},
	&"earth_damage": {"simple": "Erde", "medical": "Erdschaden"},
	&"wind_damage": {"simple": "Luft", "medical": "Luftschaden"},
	&"cooldown": {"simple": "Abklingzeit", "medical": "Erholungszeit"},
	&"boss_phase": {"simple": "Bossphase", "medical": "Belastungsphase des Infektionsherds"},
	&"pneumococcus": {"simple": "Bakterium", "medical": "Pneumokokke"},
	&"bacterial_cluster": {"simple": "Bakteriengruppe", "medical": "Bakterienverband"},
	&"infection_focus": {"simple": "Infektionsherd", "medical": "Lokaler Infektionsherd"},
	&"neutrophil_orbit": {"simple": "Abwehrzellen", "medical": "Neutrophile Granulozyten"},
	&"supportive_oxygenation": {"simple": "Regeneration", "medical": "Supportive Oxygenierung"},
	&"automatic_therapy": {"simple": "Behandlung", "medical": "Automatische antibiotische Therapie"},
}

static var _definitions: Dictionary = {}

static func simple(id: StringName, fallback: String = "") -> String:
	return String(ENTRIES.get(id, {}).get("simple", fallback))

static func medical(id: StringName, fallback: String = "") -> String:
	return String(ENTRIES.get(id, {}).get("medical", fallback))

static func definition(id: StringName) -> TerminologyDefinition:
	return definitions().get(id) as TerminologyDefinition

static func definitions() -> Dictionary:
	if _definitions.is_empty():
		_definitions = _build_definitions()
	return _definitions

static func all() -> Array[TerminologyDefinition]:
	var result: Array[TerminologyDefinition] = []
	for definition_value in definitions().values():
		result.append(definition_value as TerminologyDefinition)
	result.sort_custom(func(a: TerminologyDefinition, b: TerminologyDefinition) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return result

static func _build_definitions() -> Dictionary:
	var result := {}
	_add(result, &"patient_stability", "Die Lebenspunkte von Doctor Milos.", "Gegnerschaden senkt das Leben. Erreicht es null, endet der Fall.", [&"enemy_damage", &"defense", &"life_regeneration", &"shield"], "Punkte", &"patient_stability")
	_add(result, &"analysis", "Die Erfahrung eines laufenden Falls.", "Kontrollierte Gegner hinterlassen Erfahrung. Gesammelte Erfahrung füllt die Leiste für das nächste Level.", [&"level", &"finding"], "Punkte", &"analysis_pickup")
	_add(result, &"level", "Die aktuelle Fortschrittsstufe im Run.", "Eine volle Erfahrungsleiste erhöht das Level und bietet einen neuen Ausbau an.", [&"analysis", &"effect"], "Stufe", &"analysis_pickup")
	_add(result, &"run", "Ein einzelner Durchlauf durch ein Lungenmodell.", "Vorbereitung und Forschung bleiben zwischen Runs erhalten. Erfahrung, Level und Ausbauten beginnen bei jedem neuen Run von vorn.", [&"case", &"analysis", &"upgrade"], "", &"character_stats")
	_add(result, &"case", "Ein auswählbarer Patientenfall mit eigenen Bedingungen.", "Jeder Fall besitzt einen Bosszeitpunkt und kann nach dem ersten Abschluss Fallmerkmale erhalten. Freigeschaltete Fälle können wiederholt werden.", [&"run", &"case_trait", &"boss"], "", &"boss_phases")
	_add(result, &"upgrade", "Eine vorübergehende Verbesserung im laufenden Run.", "Beim Levelaufstieg wird ein Ausbau gewählt. Er wirkt nur bis zum Ende dieses Runs.", [&"level", &"run", &"effect"], "", &"automatic_therapy")
	_add(result, &"reaction", "Eine Entscheidung nach einem abgeschlossenen Befund.", "Die gewählte Reaktion verändert den aktuellen Run und kann mit dem vorbereiteten Plan zusammenwirken.", [&"finding", &"run"], "", &"analysis_pickup")
	_add(result, &"boss", "Das zentrale Ziel eines regulären Falls.", "Der Boss besitzt viel Leben und kann mehrere Belastungsphasen auslösen. Ein Sieg erfordert seine vollständige Kontrolle.", [&"boss_phase", &"case"], "", &"infection_focus")
	_add(result, &"effect", "Die Stärke eines offensiven Treffers.", "Mehr Schaden zieht einem getroffenen Gegner mehr Leben ab. Schadenstyp und Resistenz bestimmen, wie viel davon tatsächlich ankommt.", [&"basic_treatment", &"resistance"], "Punkte", &"automatic_therapy")
	_add(result, &"treatment_speed", "Wie häufig die automatische Behandlung ausgelöst wird.", "Ein höherer Attack Speed erzeugt in derselben Zeit mehr Impulse.", [&"interval", &"cooldown"], "Pro Sekunde", &"automatic_therapy")
	_add(result, &"interval", "Der Zeitabstand zwischen zwei automatischen Impulsen.", "Ein kleineres Intervall bedeutet eine häufigere Behandlung.", [&"treatment_speed", &"basic_treatment"], "Sekunden", &"automatic_therapy")
	_add(result, &"range", "Die maximale Distanzstufe, in der ein Effekt ein Ziel erreicht.", "Ziele außerhalb der Reichweitenstufe werden von der jeweiligen Behandlung oder Fähigkeit nicht erfasst.", [&"targets", &"basic_treatment"], "Stufe", &"automatic_therapy")
	_add(result, &"targets", "Die Zahl gleichzeitig ausgewählter Gegner.", "Zusätzliche Ziele verteilen einen Behandlungsimpuls auf mehrere Gegner, sofern genug gültige Ziele vorhanden sind.", [&"projectiles", &"range"], "Anzahl", &"automatic_therapy")
	_add(result, &"projectiles", "Die Zahl sichtbarer Impulse pro Auslösung.", "Mehrere Projektile können verschiedene Richtungen oder Ziele abdecken. Die Behandlung legt ihr genaues Verhalten fest.", [&"targets", &"penetration"], "Anzahl", &"automatic_therapy")
	_add(result, &"penetration", "Wie viele Gegner ein Impuls nacheinander treffen kann.", "Ein durchdringender Impuls endet erst nach seiner maximalen Trefferzahl oder am Ende seiner Reichweite.", [&"projectiles", &"range"], "Treffer", &"automatic_therapy")
	_add(result, &"antibiotic_path", "Der direkte Weg gegen Bakterien.", "Behandlung verbessert Schaden, Attack Speed, Reichweite und Zielabdeckung der Behandlung.", [&"basic_treatment", &"effect"], "", &"automatic_therapy")
	_add(result, &"immune_path", "Nahbereichsangriff durch Abwehrzellen.", "Abwehrzellen umkreisen Doctor Milos. Eine Zelle verursacht nur dann Schaden, wenn sie einen Gegner tatsächlich trifft.", [&"neutrophil_orbit", &"effect"], "", &"neutrophil_orbit")
	_add(result, &"support_path", "Stellt verlorenes Leben mit der Zeit wieder her.", "Regeneration heilt Doctor Milos regelmäßig. Sie verursacht keinen direkten Schaden an Gegnern.", [&"patient_stability", &"life_regeneration"], "", &"supportive_oxygenation")
	_add(result, &"shield", "Ein zusätzlicher vorübergehender Puffer.", "Das Schild fängt Schaden ab, bevor das Leben sinkt. Es ist von den maximalen Lebenspunkten getrennt.", [&"patient_stability", &"defense"], "Punkte", &"patient_stability")
	_add(result, &"finding", "Eine neue Beobachtung während eines Falls.", "Befunde zeigen derzeit Platzhalterreaktionen und verändern den laufenden Run noch nicht.", [&"finding_progress", &"case_trait"], "", &"analysis_pickup")
	_add(result, &"finding_progress", "Der Fortschritt bis zur nächsten Beobachtung.", "Bestimmte Erfahrung, Fähigkeiten und Module beschleunigen den Befund. Bei vollem Fortschritt wird eine Reaktion gewählt.", [&"finding", &"analysis"], "Punkte", &"analysis_pickup")
	_add(result, &"case_trait", "Eine bekannte Besonderheit des gewählten Falls.", "Das Merkmal ist bereits in der Einsatzplanung sichtbar und hilft bei der Auswahl passender Komponenten.", [&"finding", &"capacity"], "", &"boss_phases")
	_add(result, &"basic_treatment", "Die ständig automatisch eingesetzte Behandlung.", "Jeder Plan benötigt genau eine Grundbehandlung. Ihre Werte bilden die Basis für Ausbauten im Run.", [&"antibiotic_path", &"interval", &"effect"], "", &"automatic_therapy")
	_add(result, &"active_ability", "Eine bewusst ausgelöste Maßnahme.", "Aktive Fähigkeiten werden mit Q oder E eingesetzt und benötigen danach ihre Abklingzeit.", [&"cooldown", &"capacity"], "", &"automatic_therapy")
	_add(result, &"passive_module", "Ein dauerhaft wirkender Teil der Einsatzplanung.", "Passivmodule verändern Startwerte oder Regeln, ohne während des Runs ausgelöst werden zu müssen.", [&"capacity"], "", &"character_stats")
	_add(result, &"reserve", "Ein vorbereitetes Modul außerhalb des aktiven Plans.", "Die Reserve verbraucht keine Kapazität. Ein Befund kann einen Tausch mit einem aktiven Passivmodul ermöglichen.", [&"passive_module", &"finding"], "", &"character_stats")
	_add(result, &"capacity", "Das Größenlimit des aktiven Einsatzplans.", "Grundbehandlung, aktive Fähigkeiten und Passivmodule kosten Kapazität.", [&"basic_treatment", &"active_ability", &"passive_module"], "Punkte", &"character_stats")
	_add(result, &"research", "Dauerhafter Fortschritt zwischen den Fällen.", "Forschung schaltet Komponenten frei und verbessert ausgewählte Grundlagen der Praxis.", [&"talent_points", &"mastery"], "Punkte", &"research_reward")
	_add(result, &"talent_points", "Begrenzt verteilbare Punkte für die Vorbereitung.", "Talentpunkte werden vor einem Fall verteilt. Eine andere Verteilung ermöglicht neue Spezialisierungen.", [&"research", &"capacity"], "Punkte", &"research_reward")
	_add(result, &"mastery", "Dauerhafte Erfahrung mit einzelnen Fällen.", "Meisterschaft dokumentiert besondere Leistungen und kann zusätzliche Talentpunkte freischalten.", [&"talent_points", &"case_trait"], "Stufe", &"research_reward")
	_add(result, &"enemy_damage", "Der Grundschaden eines Gegners.", "Wenn ein Gegner Doctor Milos trifft, werden Schadenstyp, Resistenz und Verteidigung verrechnet. Danach fängt ein vorhandenes Schild Schaden ab.", [&"patient_stability", &"resistance", &"defense", &"shield"], "Punkte", &"patient_stability")
	_add(result, &"defense", "Die effektive allgemeine Minderung eingehenden Schadens.", "Verteidigung reduziert den Schaden nach der Typresistenz. Sie kann einen Treffer abschwächen, aber nicht heilen.", [&"enemy_damage", &"resistance", &"shield"], "Prozent", &"patient_stability")
	_add(result, &"life_regeneration", "Automatische Heilung über Zeit.", "Lebensregeneration stellt fortlaufend Leben wieder her, solange Doctor Milos nicht bereits sein maximales Leben besitzt.", [&"patient_stability", &"support_path"], "Leben pro Sekunde", &"supportive_oxygenation")
	_add(result, &"resistance", "Minderung oder Verwundbarkeit gegenüber einem Schadenstyp.", "Ein positiver effektiver Wert verringert diesen Schadenstyp. Ein negativer Wert bedeutet Verwundbarkeit und erhöht den erlittenen Schaden.", [&"enemy_damage", &"defense", &"fire_damage", &"water_damage", &"earth_damage", &"wind_damage"], "Prozent", &"patient_stability")
	_add(result, &"fire_damage", "Ein offensiver Schadenstyp.", "Feuerschaden wird mit der Feuerresistenz des Ziels verrechnet.", [&"resistance", &"effect"], "", &"automatic_therapy")
	_add(result, &"water_damage", "Ein offensiver Schadenstyp.", "Wasserschaden wird mit der Wasserresistenz des Ziels verrechnet.", [&"resistance", &"effect"], "", &"automatic_therapy")
	_add(result, &"earth_damage", "Ein offensiver Schadenstyp.", "Erdschaden wird mit der Erdresistenz des Ziels verrechnet.", [&"resistance", &"effect"], "", &"automatic_therapy")
	_add(result, &"wind_damage", "Ein offensiver Schadenstyp.", "Luftschaden wird mit der Luftresistenz des Ziels verrechnet.", [&"resistance", &"effect"], "", &"automatic_therapy")
	_add(result, &"cooldown", "Die Wartezeit nach einer aktiven Fähigkeit.", "Erst nach Ablauf der Abklingzeit kann die Fähigkeit erneut ausgelöst werden.", [&"active_ability", &"treatment_speed"], "Sekunden", &"automatic_therapy")
	_add(result, &"boss_phase", "Ein Belastungsschub des Infektionsherds.", "Beim Erreichen einer Phasengrenze verändert der Boss den Kampf und kann zusätzliche Bakterien freisetzen.", [&"infection_focus", &"case_trait"], "", &"boss_phases")
	return result

static func _add(
	target: Dictionary,
	id: StringName,
	summary: String,
	gameplay_text: String,
	related: Array,
	unit: String,
	visual_id: StringName
) -> void:
	var names: Dictionary = ENTRIES[id]
	target[id] = TerminologyDefinition.create(
		id,
		String(names["simple"]),
		String(names["medical"]),
		summary,
		gameplay_text,
		_to_string_name_array(related),
		unit,
		visual_id
	)

static func _to_string_name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result
