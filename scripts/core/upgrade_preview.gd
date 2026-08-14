class_name UpgradePreview
extends RefCounted

var effect_text: String
var before_after_text: String
var level_text: String
var target_type: StringName
var detail_lines: PackedStringArray

static func create(effect: String, comparison: String, level: String, target: StringName = &"", details: PackedStringArray = PackedStringArray()) -> UpgradePreview:
	var preview := UpgradePreview.new()
	preview.effect_text = effect
	preview.before_after_text = comparison
	preview.level_text = level
	preview.target_type = target
	preview.detail_lines = details
	return preview
