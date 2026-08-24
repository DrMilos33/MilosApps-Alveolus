extends SceneTree

var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_names_and_level_language()
	_test_active_damage_type_terms()
	_test_enemy_and_character_values()
	_test_default_character_entry()
	_test_centered_lexicon_sprites()
	_test_passive_research_icon()
	if failures.is_empty():
		print("ALVEOLUS_LEXICON_STATS_OK assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_names_and_level_language() -> void:
	var discoveries := ContentCatalog.discovery_definitions()
	var sample: DiscoveryDefinition = discoveries[&"analysis_pickup"]
	var treatment: DiscoveryDefinition = discoveries[&"automatic_therapy"]
	_check(sample.title == "Erfahrung", "Erfahrung ist der sichtbare Name des Runfortschritts")
	_check(sample.gameplay_text.contains("Erfahrung"), "Das Lexikon erklärt Erfahrung als Runfortschritt")
	_check(sample.gameplay_text.contains("Level"), "Das Lexikon nennt den Fortschritt Level")
	_check(not sample.gameplay_text.contains("Probenstufe"), "Das Lexikon verwendet keine Probenstufe")
	_check(treatment.title == "Behandlung", "Die automatische Behandlung besitzt einen einfachen Namen")
	_check(TerminologyCatalog.simple(&"automatic_therapy") == "Behandlung", "Terminologiekatalog nutzt denselben Behandlungsnamen")
	_check(ContentCatalog.level_definitions()[2].title == "lol - name fehlt", "Fall 2 verwendet den gewünschten Platzhalternamen")

func _test_active_damage_type_terms() -> void:
	var expected_ids: Array[StringName] = [&"fire", &"water", &"earth", &"wind"]
	_check(DamageTypeCatalog.ALL_IDS == expected_ids, "Das sichtbare Lexikon verwendet ausschließlich Feuer, Wasser, Erde und Luft")
	for type_id in expected_ids:
		var terminology_id := StringName("%s_damage" % type_id)
		var definition := TerminologyCatalog.definition(terminology_id)
		_check(definition != null and not definition.display_name.is_empty(), "%s besitzt einen ausgeschriebenen Lexikonbegriff" % type_id)
	_check(TerminologyCatalog.simple(&"wind_damage") == "Luft", "Der stabile interne Wind-Typ heißt sichtbar Luft")
	for retired_id in [&"blood_damage", &"holy_damage", &"undead_damage"]:
		_check(TerminologyCatalog.definition(retired_id) == null, "%s erscheint nicht mehr als aktiver Lexikonbegriff" % retired_id)

func _test_enemy_and_character_values() -> void:
	var discoveries := ContentCatalog.discovery_definitions()
	for id in [&"pneumococcus", &"bacterial_cluster", &"infection_focus"]:
		var definition: DiscoveryDefinition = discoveries[id]
		_check(not definition.gameplay_text.contains("GRUNDWERTE"), "%s hält Grundwerte aus dem Entdeckungsfenster heraus" % id)
		_check(not definition.gameplay_text.contains(" px"), "%s zeigt im Entdeckungsfenster keine technischen Grundwerte" % id)
		_check(not definition.gameplay_text.contains("Kontaktschaden"), "%s verwendet keinen veralteten Schadensbegriff" % id)
		_check(not definition.gameplay_text.contains("Erfahrung pro"), "%s zeigt im Entdeckungsfenster keinen tabellarischen Erfahrungsertrag" % id)
	var character: DiscoveryDefinition = discoveries[&"character_stats"]
	for label in ["Galopp", "Leben", "Schaden", "Attack Speed", "Reichweite", "Ziel", "Erfahrungsradius"]:
		_check(character.gameplay_text.contains(label), "Arztwerte enthalten %s" % label)

func _test_default_character_entry() -> void:
	var meta := MetaProgressionState.new(func() -> int: return 1000)
	meta.reset_defaults(1000)
	_check(meta.has_seen_discovery(&"character_stats"), "Arztwerte sind ohne Popup sofort lesbar")
	_check(meta.seen_discovery_ids.is_empty(), "Der Standardlexikoneintrag verfälscht keine Entdeckungsstatistik")

func _test_centered_lexicon_sprites() -> void:
	var illustration := MedicalLexiconIllustration.new()
	var center := Vector2(41.0, 37.0)
	for id in [&"analysis_pickup", &"neutrophil_orbit", &"pneumococcus"]:
		illustration.entry_id = id
		var texture := illustration._sprite_for_entry()
		_check(texture != null, "%s besitzt eine Lexikongrafik" % id)
		var layout := illustration.centered_texture_layout(texture, center, Vector2(56.0, 56.0))
		_check(not layout.is_empty(), "%s besitzt sichtbare Pixel" % id)
		if not layout.is_empty():
			var target: Rect2 = layout["target"]
			_check(target.get_center().is_equal_approx(center), "%s wird anhand seiner sichtbaren Pixel zentriert" % id)
	illustration.free()

func _test_passive_research_icon() -> void:
	var icon := SimpleIcon.new()
	icon.configure(&"passive_research", Color("159b99"))
	_check(icon.kind == &"passive_research", "Automatische Forschung besitzt einen eigenen Icon-Typ")
	_check(VisualAssetCatalog.icon(&"passive_research") == null, "Das neue Symbol wird als skalierbare Godot-Vektorform gezeichnet")
	icon.free()

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
