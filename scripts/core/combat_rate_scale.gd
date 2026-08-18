class_name CombatRateScale
extends RefCounted


static func per_second(interval_seconds: float) -> float:
	if interval_seconds <= 0.0:
		return 0.0
	return 1.0 / interval_seconds


static func formatted_per_second(interval_seconds: float, decimals: int = 2) -> String:
	var rate := per_second(interval_seconds)
	var digits := maxi(0, decimals)
	var number := str(roundi(rate)) if digits == 0 or is_equal_approx(rate, roundf(rate)) else ("%.*f" % [digits, rate]).replace(".", ",")
	return "%s/s" % number
