class_name LexiconEntryViewModel
extends RefCounted

var id: StringName
var category: StringName
var display_name: String
var medical_name: String
var summary: String
var gameplay_text: String
var medical_text: String
var visual_id: StringName
var locked: bool = false
var stat_rows: Array[StatRowViewModel] = []
var related_names: PackedStringArray = PackedStringArray()

func has_details() -> bool:
	return not locked
