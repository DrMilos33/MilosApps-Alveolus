class_name UpgradePreview
extends RefCounted

var effect_text: String
var before_after_text: String
var level_text: String
var target_type: StringName
var detail_lines: PackedStringArray
var before_value: String
var after_value: String
var presentation_icon_id: StringName

static func create(
	effect: String,
	comparison: String,
	level: String,
	target: StringName = &"",
	details: PackedStringArray = PackedStringArray(),
	before: String = "",
	after: String = "",
	icon_id: StringName = &""
) -> UpgradePreview:
	var preview := UpgradePreview.new()
	preview.effect_text = effect
	preview.before_after_text = comparison
	preview.level_text = level
	preview.target_type = target
	preview.detail_lines = details
	preview.before_value = before
	preview.after_value = after
	preview.presentation_icon_id = icon_id
	return preview
