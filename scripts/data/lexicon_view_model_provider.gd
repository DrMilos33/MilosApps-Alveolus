class_name LexiconViewModelProvider
extends RefCounted

var enemy_definitions: Dictionary
var discovery_definitions: Dictionary
var player_stats: PlayerStats
var treatment_definitions: Dictionary
var ability_definitions: Dictionary

func _init(
	enemies: Dictionary = {},
	discoveries: Dictionary = {},
	stats: PlayerStats = null,
	treatments: Dictionary = {},
	abilities: Dictionary = {}
) -> void:
	enemy_definitions = ContentCatalog.enemy_definitions() if enemies.is_empty() else enemies
	discovery_definitions = ContentCatalog.discovery_definitions() if discoveries.is_empty() else discoveries
	player_stats = PlayerStats.new() if stats == null else stats
	treatment_definitions = TreatmentDefinition.catalog() if treatments.is_empty() else treatments
	ability_definitions = AbilityDefinition.catalog() if abilities.is_empty() else abilities

static func create_default() -> LexiconViewModelProvider:
	return LexiconViewModelProvider.new()

func make_view_model(entry: LexiconEntryDefinition, seen_discovery_ids: Variant = []) -> LexiconEntryViewModel:
	var view_model := LexiconEntryViewModel.new()
	view_model.id = entry.id
	view_model.category = entry.category
	view_model.visual_id = entry.visual_id
	view_model.locked = not _is_unlocked(entry, seen_discovery_ids)
	if view_model.locked:
		view_model.display_name = entry.display_name
		if entry.category == LexiconEntryDefinition.CATEGORY_MONSTERS:
			view_model.unlock_reason = "Besiege diesen Gegner, um den Eintrag zu entdecken."
		else:
			view_model.unlock_reason = "Entdecke diesen Eintrag im Spiel."
		view_model.summary = view_model.unlock_reason
		return view_model

	view_model.display_name = entry.display_name
	view_model.medical_name = entry.medical_name
	view_model.summary = entry.summary
	view_model.gameplay_text = entry.gameplay_text
	view_model.medical_text = entry.medical_text
	if entry.source_kind == LexiconEntryDefinition.SOURCE_ENEMY:
		_apply_enemy_source(view_model, entry.source_id)
	elif entry.source_kind == LexiconEntryDefinition.SOURCE_PLAYER:
		_apply_player_source(view_model)
	elif entry.source_kind == LexiconEntryDefinition.SOURCE_DISCOVERY:
		_apply_discovery_source(view_model, entry.source_id)
	elif entry.source_kind == LexiconEntryDefinition.SOURCE_ABILITY:
		_apply_ability_source(view_model, entry.source_id)
	elif entry.source_kind == LexiconEntryDefinition.SOURCE_TERMINOLOGY:
		_apply_terminology_source(view_model, entry.source_id)
	view_model.set_related_term_presentations(related_term_presentations(entry.related_ids))
	return view_model

func _apply_enemy_source(view_model: LexiconEntryViewModel, enemy_id: StringName) -> void:
	var definition := enemy_definitions.get(enemy_id) as EnemyDefinition
	if definition == null:
		return
	view_model.display_name = definition.display_name
	view_model.medical_name = definition.medical_name
	var discovery := discovery_definitions.get(definition.discovery_id) as DiscoveryDefinition
	if discovery != null:
		view_model.medical_text = discovery.medical_text
	var presentations := _damage_type_presentations(definition.damage_profile)
	presentations.append_array(_resistance_type_presentations(definition.resistance_profile))
	view_model.set_type_presentations(presentations)
	view_model.stat_rows = [
		StatRowViewModel.number(&"health", "Leben", definition.max_health, "", 0, definition.id, &"max_health"),
		StatRowViewModel.number(&"speed", "Geschwindigkeit", definition.speed, "", 0, definition.id, &"speed"),
		StatRowViewModel.number(&"damage", "Schaden", definition.base_damage, "", 1, definition.id, &"base_damage"),
		StatRowViewModel.text(&"damage_types", "Schadenstyp", _damage_profile_text(definition.damage_profile), definition.id, &"damage_profile"),
		StatRowViewModel.text(&"resistances", "Resistenzen", _resistance_profile_text(definition.resistance_profile), definition.id, &"resistance_profile"),
		StatRowViewModel.integer(&"sample_value", "Erfahrung", definition.analysis_value, "", definition.id, &"analysis_value"),
		StatRowViewModel.text(&"body_size", "Körpergröße", BodySizeCatalog.display_name(definition.body_size_class), definition.id, &"body_size_class"),
		StatRowViewModel.boolean(&"boss", "Boss", definition.is_boss, definition.id, &"is_boss"),
	]
	if definition.projectile_damage > 0.0:
		view_model.stat_rows.insert(3, StatRowViewModel.number(
			&"projectile_damage",
			"Projektilschaden",
			definition.projectile_damage,
			"",
			1,
			definition.id,
			&"projectile_damage"
		))

func _apply_player_source(view_model: LexiconEntryViewModel) -> void:
	var treatment := player_stats.prepared_treatment
	if treatment == null:
		treatment = treatment_definitions.get(&"treatment_precision") as TreatmentDefinition
	var presentations := _resistance_type_presentations(player_stats.resistances)
	if treatment != null:
		var damage_presentations := _damage_type_presentations(treatment.damage_profile)
		damage_presentations.append_array(presentations)
		presentations = damage_presentations
	view_model.set_type_presentations(presentations)
	var rows: Array[StatRowViewModel] = [
		StatRowViewModel.number(&"movement_speed", "Galopp", player_stats.movement_speed, "", 0, &"player_stats", &"movement_speed"),
		StatRowViewModel.number(&"max_life", "Leben", PlayerStats.BASE_MAX_HEALTH + player_stats.max_stability_bonus, "", 0, &"player_stats", &"max_stability_bonus"),
		StatRowViewModel.number(&"defense", "Verteidigung", MitigationCurve.defense_effective_percent(player_stats.defense), "%", 1, &"player_stats", &"defense"),
		StatRowViewModel.number(&"life_regeneration", "Lebensregeneration", player_stats.life_regeneration_per_second, "/s", 2, &"player_stats", &"life_regeneration_per_second"),
		StatRowViewModel.text(&"resistances", "Resistenzen", _resistance_profile_text(player_stats.resistances), &"player_stats", &"resistances"),
		StatRowViewModel.number(&"treatment_damage", "Schaden", player_stats.therapy_damage, "", 0, &"player_stats", &"therapy_damage"),
		StatRowViewModel.text(&"treatment_interval", "Attack Speed", CombatRateScale.formatted_per_second(player_stats.therapy_cooldown), &"player_stats", &"therapy_cooldown"),
		StatRowViewModel.integer(&"treatment_range", "Reichweite", CombatDistanceScale.stage_from_world(player_stats.therapy_range), "", &"player_stats", &"therapy_range_stage"),
		StatRowViewModel.integer(&"treatment_targets", "Ziele", player_stats.therapy_targets, "", &"player_stats", &"therapy_targets"),
		StatRowViewModel.integer(&"treatment_projectiles", "Projektile", player_stats.therapy_projectiles, "", &"player_stats", &"therapy_projectiles"),
		StatRowViewModel.integer(&"pickup_range", "Erfahrungsradius", CombatDistanceScale.stage_from_world(player_stats.pickup_range), "", &"player_stats", &"pickup_range_stage"),
	]
	if treatment != null:
		rows.insert(6, StatRowViewModel.text(
			&"treatment_damage_type",
			"Schadenstyp",
			_damage_profile_text(treatment.damage_profile),
			treatment.id,
			&"damage_profile"
		))
	view_model.stat_rows = rows
	var rows_by_id: Dictionary = {}
	for row in rows:
		rows_by_id[row.id] = row
	var defense_ids: Array[StringName] = [&"max_life", &"defense", &"life_regeneration", &"resistances"]
	var attack_ids: Array[StringName] = [&"treatment_damage", &"treatment_damage_type", &"treatment_interval", &"treatment_range", &"treatment_targets", &"treatment_projectiles"]
	var other_ids: Array[StringName] = [&"movement_speed", &"pickup_range"]
	var other_rows := _rows_for_ids(rows_by_id, other_ids)
	var assigned_ids := defense_ids + attack_ids + other_ids
	for row in rows:
		if row.id not in assigned_ids:
			other_rows.append(row)
	var stat_sections: Array[LexiconEntryViewModel.StatSectionPresentation] = [
		LexiconEntryViewModel.StatSectionPresentation.create(
			&"defense",
			"Verteidigung",
			&"defense_training",
			_rows_for_ids(rows_by_id, defense_ids)
		),
		LexiconEntryViewModel.StatSectionPresentation.create(
			&"attack",
			"Angriff",
			&"treatment",
			_rows_for_ids(rows_by_id, attack_ids)
		),
		LexiconEntryViewModel.StatSectionPresentation.create(
			&"other",
			"Sonstiges",
			&"character_stats",
			other_rows
		),
	]
	view_model.set_stat_section_presentations(stat_sections)


func _rows_for_ids(rows_by_id: Dictionary, ids: Array[StringName]) -> Array[StatRowViewModel]:
	var result: Array[StatRowViewModel] = []
	for id in ids:
		var row := rows_by_id.get(id) as StatRowViewModel
		if row != null:
			result.append(row)
	return result

func _apply_discovery_source(view_model: LexiconEntryViewModel, discovery_id: StringName) -> void:
	var discovery := discovery_definitions.get(discovery_id) as DiscoveryDefinition
	if discovery != null:
		view_model.display_name = _discovery_display_name(discovery_id, discovery.title)
		view_model.medical_name = discovery.medical_name
		view_model.medical_text = discovery.medical_text
		if discovery_id == &"supportive_oxygenation":
			view_model.medical_name = "Lebensregeneration"
			view_model.medical_text = "Regeneration ist im Spiel eine abstrahierte, dauerhafte Erholung von Doctor Milos."
	match discovery_id:
		&"automatic_therapy":
			var treatment := treatment_definitions.get(&"treatment_precision") as TreatmentDefinition
			if treatment != null:
				view_model.set_type_presentations(_damage_type_presentations(treatment.damage_profile))
				view_model.stat_rows = _treatment_rows(treatment)
		&"neutrophil_orbit":
			var immune_stats := PlayerStats.new()
			immune_stats.immune_level = 1
			view_model.stat_rows = [
				StatRowViewModel.integer(&"cells", "Abwehrzellen", immune_stats.immune_cell_count(), "", &"player_stats", &"immune_cell_count"),
				StatRowViewModel.number(&"immune_damage", "Schaden", immune_stats.immune_damage, "", 0, &"player_stats", &"immune_damage"),
				StatRowViewModel.text(&"immune_interval", "Attack Speed", CombatRateScale.formatted_per_second(immune_stats.immune_interval()), &"player_stats", &"immune_interval"),
				StatRowViewModel.integer(&"immune_radius", "Radius", CombatDistanceScale.stage_from_world(immune_stats.immune_radius()), "", &"player_stats", &"immune_radius_stage"),
			]
		&"supportive_oxygenation":
			view_model.stat_rows = [
				StatRowViewModel.number(
					&"life_regeneration",
					"Lebensregeneration",
					player_stats.life_regeneration_per_second,
					"Leben/s",
					2,
					&"player_stats",
					&"life_regeneration_per_second"
				),
			]

func _apply_terminology_source(view_model: LexiconEntryViewModel, terminology_id: StringName) -> void:
	var terminology := TerminologyCatalog.definition(terminology_id)
	if terminology == null:
		return
	view_model.display_name = terminology.display_name
	view_model.medical_name = terminology.medical_name
	view_model.summary = terminology.summary
	view_model.gameplay_text = terminology.gameplay_text


func _apply_ability_source(view_model: LexiconEntryViewModel, ability_id: StringName) -> void:
	var definition := ability_definitions.get(ability_id) as AbilityDefinition
	if definition == null:
		return
	view_model.display_name = definition.display_name
	view_model.medical_name = "" if definition.medical_name == definition.display_name else definition.medical_name
	view_model.summary = definition.description
	view_model.gameplay_text = definition.description
	var damage_amount := float(definition.parameters.get("damage", 0.0))
	if damage_amount > 0.0:
		view_model.set_type_presentations(_damage_type_presentations(definition.damage_profile))
	var target_mode_text := "Zielgebiet"
	match definition.target_mode:
		AbilityDefinition.TargetMode.SELF:
			target_mode_text = "Doctor Milos"
		AbilityDefinition.TargetMode.CURSOR_DIRECTION:
			target_mode_text = "Zielrichtung"
	view_model.stat_rows = [
		StatRowViewModel.text(&"target_mode", "Ziel", target_mode_text, definition.id, &"target_mode"),
		StatRowViewModel.number(&"cooldown", "Abklingzeit", definition.cooldown, "s", 1, definition.id, &"cooldown"),
		StatRowViewModel.integer(&"capacity", "Kapazität", definition.capacity_cost, "", definition.id, &"capacity_cost"),
	]
	if damage_amount > 0.0 and definition.damage_profile != null and definition.damage_profile.is_valid():
		view_model.stat_rows.append(StatRowViewModel.text(
			&"damage_type", "Schadenstyp", _damage_profile_text(definition.damage_profile), definition.id, &"damage_profile"
		))
	if damage_amount > 0.0:
		view_model.stat_rows.append(StatRowViewModel.number(
			&"damage", "Schaden", damage_amount, "", 0, definition.id, &"parameters"
		))
	for distance_id in [&"radius", &"range", &"width"]:
		var distance_key := String(distance_id)
		if not definition.parameters.has(distance_key):
			continue
		var label := "Radius" if distance_id == &"radius" else ("Reichweite" if distance_id == &"range" else "Breite")
		view_model.stat_rows.append(StatRowViewModel.integer(
			distance_id, label, definition.parameter_stage(distance_id), "", definition.id, &"parameters"
		))
	for numeric_data in [
		[&"duration", "Dauer", "s", 1],
		[&"recovery", "Heilung", "", 0],
		[&"shield", "Schild", "", 0],
		[&"knockback", "Rückstoß", "", 0],
		[&"stun_duration", "Betäubung", "s", 1],
	]:
		var parameter_id: StringName = numeric_data[0]
		var parameter_key := String(parameter_id)
		if not definition.parameters.has(parameter_key):
			continue
		view_model.stat_rows.append(StatRowViewModel.number(
			parameter_id,
			String(numeric_data[1]),
			float(definition.parameters[parameter_key]),
			String(numeric_data[2]),
			int(numeric_data[3]),
			definition.id,
			&"parameters"
		))

func _treatment_rows(definition: TreatmentDefinition) -> Array[StatRowViewModel]:
	return [
		StatRowViewModel.number(&"damage", "Schaden", definition.base_damage, "", 0, definition.id, &"base_damage"),
		StatRowViewModel.text(&"damage_type", "Schadenstyp", _damage_profile_text(definition.damage_profile), definition.id, &"damage_profile"),
		StatRowViewModel.text(&"interval", "Attack Speed", CombatRateScale.formatted_per_second(definition.base_interval), definition.id, &"base_interval"),
		StatRowViewModel.integer(&"range", "Reichweite", definition.base_range_stage(), "", definition.id, &"base_range_stage"),
		StatRowViewModel.integer(&"projectiles", "Projektile", definition.base_projectiles, "", definition.id, &"base_projectiles"),
		StatRowViewModel.integer(&"max_hits", "Maximale Treffer", definition.max_hits, "", definition.id, &"max_hits"),
	]

func _discovery_display_name(discovery_id: StringName, fallback: String) -> String:
	match discovery_id:
		&"patient_stability":
			return TerminologyCatalog.simple(&"patient_stability", fallback)
		&"supportive_oxygenation":
			return TerminologyCatalog.simple(&"supportive_oxygenation", fallback)
	return fallback

func _damage_profile_text(profile: DamageProfile) -> String:
	if profile == null or not profile.is_valid():
		return "Keiner"
	var parts := PackedStringArray()
	for presentation in _damage_type_presentations(profile):
		if presentation.percent <= 0.0:
			continue
		if is_equal_approx(presentation.percent, 100.0):
			parts.append(presentation.display_name)
		else:
			parts.append("%d %% %s" % [roundi(presentation.percent), presentation.display_name])
	return " · ".join(parts) if not parts.is_empty() else "Keiner"

func _resistance_profile_text(profile: ResistanceProfile) -> String:
	if profile == null or not profile.is_valid() or profile.is_neutral():
		return "Keine"
	var parts := PackedStringArray()
	for presentation in _resistance_type_presentations(profile):
		if is_zero_approx(presentation.percent):
			continue
		var percentage := roundi(presentation.percent)
		parts.append("%s %s%d %%" % [presentation.display_name, "+" if percentage > 0 else "", percentage])
	return " · ".join(parts) if not parts.is_empty() else "Keine"


func _damage_type_presentations(profile: DamageProfile) -> Array[LexiconEntryViewModel.TypePresentation]:
	var result: Array[LexiconEntryViewModel.TypePresentation] = []
	for type_index in range(DamageTypeCatalog.count()):
		var type_id := DamageTypeCatalog.id_at(type_index)
		var percentage := profile.weight_at(type_index) * 100.0 if profile != null and profile.is_valid() else 0.0
		result.append(LexiconEntryViewModel.TypePresentation.create(
			type_id,
			StringName("damage_%s" % String(type_id)),
			&"damage_share",
			DamageTypeCatalog.display_name(type_id),
			percentage,
			&"share"
		))
	return result


func _resistance_type_presentations(profile: ResistanceProfile) -> Array[LexiconEntryViewModel.TypePresentation]:
	var result: Array[LexiconEntryViewModel.TypePresentation] = []
	for type_index in range(DamageTypeCatalog.count()):
		var type_id := DamageTypeCatalog.id_at(type_index)
		var percentage := profile.effective_percent_at(type_index) if profile != null and profile.is_valid() else 0.0
		var value_role := &"mitigation" if percentage > 0.0 else (&"vulnerability" if percentage < 0.0 else &"neutral")
		result.append(LexiconEntryViewModel.TypePresentation.create(
			type_id,
			StringName("damage_%s" % String(type_id)),
			&"resistance_effective",
			DamageTypeCatalog.display_name(type_id),
			percentage,
			value_role
		))
	return result

func _is_unlocked(entry: LexiconEntryDefinition, seen_discovery_ids: Variant) -> bool:
	if entry.unlocked_by_default or entry.discovery_id.is_empty():
		return true
	if seen_discovery_ids is Dictionary:
		return (seen_discovery_ids as Dictionary).has(entry.discovery_id)
	if seen_discovery_ids is PackedStringArray:
		return (seen_discovery_ids as PackedStringArray).has(String(entry.discovery_id))
	if seen_discovery_ids is Array:
		return (seen_discovery_ids as Array).has(entry.discovery_id) or (seen_discovery_ids as Array).has(String(entry.discovery_id))
	return false

func related_term_presentations(ids: Array[StringName]) -> Array[LexiconEntryViewModel.RelatedTermPresentation]:
	var result: Array[LexiconEntryViewModel.RelatedTermPresentation] = []
	for id in ids:
		var terminology := TerminologyCatalog.definition(id)
		if terminology != null:
			result.append(LexiconEntryViewModel.RelatedTermPresentation.create(
				id,
				terminology.display_name,
				terminology.summary,
				terminology.visual_id
			))
		else:
			result.append(LexiconEntryViewModel.RelatedTermPresentation.create(
				id,
				TerminologyCatalog.simple(id, String(id).capitalize()),
				"",
				id
			))
	return result
