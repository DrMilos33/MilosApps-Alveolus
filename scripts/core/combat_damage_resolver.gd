class_name CombatDamageResolver
extends RefCounted

const DEFENSE_SCALE := 100.0


## Resolves type resistance first and general defense second. DamageProfile and
## ResistanceProfile contain fixed PackedFloat32Array buffers, so this hot path
## performs a constant seven iterations without dictionaries or allocations.
static func resolve(
	base_amount: float,
	damage_profile: DamageProfile,
	resistance_profile: ResistanceProfile = null,
	defense: float = 0.0
) -> float:
	if base_amount <= 0.0:
		return 0.0
	var after_resistance := base_amount
	# Catalog tests validate normalization once. The hot path only checks the
	# fixed buffer width and then reads both packed arrays directly.
	if damage_profile != null and damage_profile.weights.size() == DamageTypeCatalog.count():
		after_resistance = 0.0
		for type_index in range(DamageTypeCatalog.count()):
			var weight := float(damage_profile.weights[type_index])
			if weight <= 0.0:
				continue
			var resistance := float(resistance_profile.values[type_index]) if resistance_profile != null and resistance_profile.values.size() == DamageTypeCatalog.count() else 0.0
			after_resistance += base_amount * weight * maxf(0.0, 1.0 - resistance)
	return after_resistance * defense_multiplier(defense)


static func defense_multiplier(defense: float) -> float:
	return DEFENSE_SCALE / (DEFENSE_SCALE + maxf(defense, 0.0))
