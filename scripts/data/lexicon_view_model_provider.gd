class_name LexiconViewModelProvider
extends RefCounted

var enemy_definitions: Dictionary
var discovery_definitions: Dictionary
var player_stats: PlayerStats
var treatment_definitions: Dictionary

func _init(
	enemies: Dictionary = {},
	discoveries: Dictionary = {},
	stats: PlayerStats = null,
	treatments: Dictionary = {}
) -> void:
	enemy_definitions = ContentCatalog.enemy_definitions() if enemies.is_empty() else enemies
	discovery_definitions = ContentCatalog.discovery_definitions() if discoveries.is_empty() else discoveries
	player_stats = PlayerStats.new() if stats == null else stats
	treatment_definitions = TreatmentDefinition.catalog() if treatments.is_empty() else treatments

static func create_default() -> LexiconViewModelProvider:
	return LexiconViewModelProvider.new()

func make_view_model(entry: LexiconEntryDefinition, seen_discovery_ids: Variant = []) -> LexiconEntryViewModel:
	var view_model := LexiconEntryViewModel.new()
	view_model.id = entry.id
	view_model.category = entry.category
	view_model.visual_id = entry.visual_id
	view_model.locked = not _is_unlocked(entry, seen_discovery_ids)
	if view_model.locked:
		view_model.display_name = "Noch nicht beobachtet"
		view_model.summary = "Dieser Eintrag wird nach der ersten Beobachtung sichtbar."
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
	elif entry.source_kind == LexiconEntryDefinition.SOURCE_TERMINOLOGY:
		_apply_terminology_source(view_model, entry.source_id)
	view_model.related_names = _related_names(entry.related_ids)
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
	view_model.stat_rows = [
		StatRowViewModel.number(&"health", "Leben", definition.max_health, "", 0, definition.id, &"max_health"),
		StatRowViewModel.number(&"speed", "Tempo", definition.speed, "px/s", 0, definition.id, &"speed"),
		StatRowViewModel.number(&"contact_damage", "Kontaktschaden", definition.contact_damage, "", 1, definition.id, &"contact_damage"),
		StatRowViewModel.integer(&"sample_value", "Probenwert", definition.analysis_value, "", definition.id, &"analysis_value"),
		StatRowViewModel.number(&"body_radius", "Körperradius", definition.radius, "px", 0, definition.id, &"radius"),
		StatRowViewModel.boolean(&"boss", "Boss", definition.is_boss, definition.id, &"is_boss"),
	]

func _apply_player_source(view_model: LexiconEntryViewModel) -> void:
	view_model.stat_rows = [
		StatRowViewModel.number(&"movement_speed", "Bewegung", TherapyAvatar.MOVE_SPEED, "px/s", 0, &"therapy_avatar", &"MOVE_SPEED"),
		StatRowViewModel.number(&"treatment_damage", "Wirkung", player_stats.therapy_damage, "", 0, &"player_stats", &"therapy_damage"),
		StatRowViewModel.number(&"treatment_interval", "Intervall", player_stats.therapy_cooldown, "s", 2, &"player_stats", &"therapy_cooldown"),
		StatRowViewModel.number(&"treatment_range", "Reichweite", player_stats.therapy_range, "px", 0, &"player_stats", &"therapy_range"),
		StatRowViewModel.integer(&"treatment_targets", "Ziele", player_stats.therapy_targets, "", &"player_stats", &"therapy_targets"),
		StatRowViewModel.integer(&"treatment_projectiles", "Projektile", player_stats.therapy_projectiles, "", &"player_stats", &"therapy_projectiles"),
		StatRowViewModel.number(&"pickup_range", "Probenradius", player_stats.pickup_range, "px", 0, &"player_stats", &"pickup_range"),
	]

func _apply_discovery_source(view_model: LexiconEntryViewModel, discovery_id: StringName) -> void:
	var discovery := discovery_definitions.get(discovery_id) as DiscoveryDefinition
	if discovery != null:
		view_model.display_name = discovery.title
		view_model.medical_name = discovery.medical_name
		view_model.medical_text = discovery.medical_text
	match discovery_id:
		&"automatic_therapy":
			var treatment := treatment_definitions.get(&"treatment_precision") as TreatmentDefinition
			if treatment != null:
				view_model.stat_rows = _treatment_rows(treatment)
		&"neutrophil_orbit":
			var immune_stats := PlayerStats.new()
			immune_stats.immune_level = 1
			view_model.stat_rows = [
				StatRowViewModel.integer(&"cells", "Abwehrzellen", immune_stats.immune_cell_count(), "", &"player_stats", &"immune_cell_count"),
				StatRowViewModel.number(&"immune_damage", "Wirkung", immune_stats.immune_damage, "", 0, &"player_stats", &"immune_damage"),
				StatRowViewModel.number(&"immune_interval", "Intervall", immune_stats.immune_interval(), "s", 2, &"player_stats", &"immune_interval"),
				StatRowViewModel.number(&"immune_radius", "Radius", immune_stats.immune_radius(), "px", 0, &"player_stats", &"immune_radius"),
			]
		&"supportive_oxygenation":
			var support_stats := PlayerStats.new()
			support_stats.support_level = 1
			view_model.stat_rows = [
				StatRowViewModel.number(&"support_recovery", "Regeneration", support_stats.support_recovery(), "Zustand", 0, &"player_stats", &"support_recovery"),
				StatRowViewModel.number(&"support_interval", "Intervall", support_stats.support_interval(), "s", 2, &"player_stats", &"support_interval"),
			]

func _apply_terminology_source(view_model: LexiconEntryViewModel, terminology_id: StringName) -> void:
	var terminology := TerminologyCatalog.definition(terminology_id)
	if terminology == null:
		return
	view_model.display_name = terminology.display_name
	view_model.medical_name = terminology.medical_name
	view_model.summary = terminology.summary
	view_model.gameplay_text = terminology.gameplay_text

func _treatment_rows(definition: TreatmentDefinition) -> Array[StatRowViewModel]:
	return [
		StatRowViewModel.number(&"damage", "Wirkung", definition.base_damage, "", 0, definition.id, &"base_damage"),
		StatRowViewModel.number(&"interval", "Intervall", definition.base_interval, "s", 2, definition.id, &"base_interval"),
		StatRowViewModel.number(&"range", "Reichweite", definition.base_range, "px", 0, definition.id, &"base_range"),
		StatRowViewModel.integer(&"projectiles", "Projektile", definition.base_projectiles, "", definition.id, &"base_projectiles"),
		StatRowViewModel.integer(&"max_hits", "Maximale Treffer", definition.max_hits, "", definition.id, &"max_hits"),
	]

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

func _related_names(ids: Array[StringName]) -> PackedStringArray:
	var names := PackedStringArray()
	for id in ids:
		var terminology := TerminologyCatalog.definition(id)
		if terminology != null:
			names.append(terminology.display_name)
		else:
			names.append(TerminologyCatalog.simple(id, String(id).capitalize()))
	return names
