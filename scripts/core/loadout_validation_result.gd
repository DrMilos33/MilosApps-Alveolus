class_name LoadoutValidationResult
extends RefCounted

var valid: bool = false
var errors: PackedStringArray = PackedStringArray()
var capacity_used: int = 0
var capacity_limit: int = 0

static func create(messages: PackedStringArray, used: int, limit: int) -> LoadoutValidationResult:
	var result := LoadoutValidationResult.new()
	result.errors = messages
	result.valid = messages.is_empty()
	result.capacity_used = used
	result.capacity_limit = limit
	return result

func first_error() -> String:
	return "" if errors.is_empty() else errors[0]
