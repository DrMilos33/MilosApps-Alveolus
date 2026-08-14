class_name LevelRecord
extends RefCounted

var attempts: int = 0
var victories: int = 0
var best_time: float = -1.0
var highest_analysis: int = 0
var best_defeats: int = 0

func register_result(success: bool, elapsed: float, analysis_level: int, defeats: int) -> void:
	attempts += 1
	highest_analysis = maxi(highest_analysis, analysis_level)
	best_defeats = maxi(best_defeats, defeats)
	if not success:
		return
	victories += 1
	if best_time < 0.0 or elapsed < best_time:
		best_time = elapsed

func to_dict() -> Dictionary:
	return {
		"attempts": attempts,
		"victories": victories,
		"best_time": best_time,
		"highest_analysis": highest_analysis,
		"best_defeats": best_defeats
	}

static func from_dict(data: Dictionary) -> LevelRecord:
	var record := LevelRecord.new()
	record.attempts = maxi(0, int(data.get("attempts", 0)))
	record.victories = maxi(0, int(data.get("victories", 0)))
	record.best_time = float(data.get("best_time", -1.0))
	record.highest_analysis = maxi(0, int(data.get("highest_analysis", 0)))
	record.best_defeats = maxi(0, int(data.get("best_defeats", 0)))
	return record

