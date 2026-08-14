class_name PlayerStats
extends RefCounted

var therapy_damage: float = 18.0
var therapy_cooldown: float = 0.82
var therapy_range: float = 470.0
var therapy_targets: int = 1
var immune_level: int = 0
var immune_damage: float = 10.0
var support_level: int = 0
var max_stability_bonus: float = 0.0
var pickup_range: float = 185.0
var upgrade_levels: Dictionary = {}

func apply_meta_progression(research_ranks: Dictionary) -> void:
	var stability_rank := int(research_ranks.get(&"stability_reserve", 0))
	var precision_rank := int(research_ranks.get(&"therapy_precision", 0))
	var logistics_rank := int(research_ranks.get(&"sample_logistics", 0))
	max_stability_bonus = float(stability_rank) * 3.0
	therapy_damage *= 1.0 + float(precision_rank) * 0.02
	pickup_range *= 1.0 + float(logistics_rank) * 0.05

func preview_upgrade(definition: UpgradeDefinition) -> UpgradePreview:
	var current_level := int(upgrade_levels.get(definition.id, 0))
	var next_level := current_level + 1
	var level_text := "Stufe %d / %d" % [next_level, definition.max_level]
	match definition.effect:
		&"damage":
			var after := therapy_damage + definition.magnitude
			return UpgradePreview.create(
				"+%s Wirkung" % _number(definition.magnitude),
				"%s Wirkung  >  %s Wirkung" % [_number(therapy_damage), _number(after)],
				level_text,
				&"enemy"
			)
		&"cooldown_multiplier":
			var after := maxf(0.22, therapy_cooldown * definition.magnitude)
			var percent := roundi((1.0 - after / maxf(therapy_cooldown, 0.001)) * 100.0)
			return UpgradePreview.create(
				"+%d %% Therapierhythmus" % percent,
				"%s s  >  %s s Intervall" % [_decimal(therapy_cooldown, 2), _decimal(after, 2)],
				level_text
			)
		&"range":
			return UpgradePreview.create(
				"+%s Reichweite" % _number(definition.magnitude),
				"%s  >  %s Reichweite" % [_number(therapy_range), _number(therapy_range + definition.magnitude)],
				level_text
			)
		&"targets":
			var added := int(definition.magnitude)
			return UpgradePreview.create(
				"+%d Projektil%s" % [added, "e" if added != 1 else ""],
				"%d Ziel%s  >  %d Ziele" % [therapy_targets, "e" if therapy_targets != 1 else "", therapy_targets + added],
				level_text
			)
		&"immune_level":
			var after_level := immune_level + int(definition.magnitude)
			var count := mini(after_level + 1, 4)
			var interval := maxf(0.42, 0.82 - float(after_level) * 0.06)
			var radius := 98.0 + float(after_level) * 18.0
			return UpgradePreview.create(
				"%d Neutrophile" % count,
				"%s Wirkung alle %s s · Radius %s" % [_number(immune_damage), _decimal(interval, 2), _number(radius)],
				level_text,
				&"avatar",
				PackedStringArray(["Nahbereichsschutz", "Kein Bonus auf Projektile"])
			)
		&"immune_damage":
			return UpgradePreview.create(
				"+%s Immunwirkung" % _number(definition.magnitude),
				"%s Wirkung  >  %s Wirkung" % [_number(immune_damage), _number(immune_damage + definition.magnitude)],
				level_text
			)
		&"support_level":
			var after_level := support_level + int(definition.magnitude)
			var interval := maxf(3.8, 6.2 - float(after_level) * 0.55)
			var recovery := 2.0 + float(after_level) * 2.0
			return UpgradePreview.create(
				"+%s Stabilität" % _number(recovery),
				"0  >  %s je Impuls · alle %s s" % [_number(recovery), _decimal(interval, 2)],
				level_text,
				&"stability_bar"
			)
		&"max_stability":
			var after_bonus := max_stability_bonus + definition.magnitude
			return UpgradePreview.create(
				"+%s Stabilität" % _number(definition.magnitude),
				"%s  >  %s Startbonus" % [_number(max_stability_bonus), _number(after_bonus)],
				level_text,
				&"stability_bar"
			)
		&"pickup_range":
			return UpgradePreview.create(
				"+%s Analyse-Reichweite" % _number(definition.magnitude),
				"%s  >  %s Reichweite" % [_number(pickup_range), _number(pickup_range + definition.magnitude)],
				level_text
			)
	return UpgradePreview.create("Unbekannter Effekt", "", level_text)

func apply_upgrade(definition: UpgradeDefinition) -> bool:
	var current_level := int(upgrade_levels.get(definition.id, 0))
	if current_level >= definition.max_level:
		return false
	upgrade_levels[definition.id] = current_level + 1
	match definition.effect:
		&"damage":
			therapy_damage += definition.magnitude
		&"cooldown_multiplier":
			therapy_cooldown = maxf(0.22, therapy_cooldown * definition.magnitude)
		&"range":
			therapy_range += definition.magnitude
		&"targets":
			therapy_targets += int(definition.magnitude)
		&"immune_level":
			immune_level += int(definition.magnitude)
		&"immune_damage":
			immune_damage += definition.magnitude
		&"support_level":
			support_level += int(definition.magnitude)
		&"max_stability":
			max_stability_bonus += definition.magnitude
		&"pickup_range":
			pickup_range += definition.magnitude
		_:
			return false
	return true

func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return _decimal(value, 1)

func _decimal(value: float, digits: int) -> String:
	return ("%.*f" % [digits, value]).replace(".", ",")
