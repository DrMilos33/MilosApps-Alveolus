class_name MitigationCurve
extends RefCounted

const DEFENSE_CAP_PERCENT := 90.0
const RESISTANCE_CAP_PERCENT := 75.0
const MIN_RESISTANCE_RATING := -100.0


static func reduction_percent(rating: float, cap_percent: float) -> float:
	var positive_rating := maxf(rating, 0.0)
	var positive_cap := maxf(cap_percent, 0.0)
	if positive_rating <= 0.0 or positive_cap <= 0.0:
		return 0.0
	return positive_cap * positive_rating / (positive_cap + positive_rating)


static func resistance_effective_percent(rating: float) -> float:
	if rating < 0.0:
		return maxf(rating, MIN_RESISTANCE_RATING)
	return reduction_percent(rating, RESISTANCE_CAP_PERCENT)


static func resistance_multiplier(rating: float) -> float:
	return 1.0 - resistance_effective_percent(rating) / 100.0


static func defense_effective_percent(rating: float) -> float:
	return reduction_percent(rating, DEFENSE_CAP_PERCENT)


static func defense_multiplier(rating: float) -> float:
	return 1.0 - defense_effective_percent(rating) / 100.0
