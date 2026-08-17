class_name StoryScreenViewModel
extends RefCounted

## Immutable, presentation-only data for StoryScreen.
##
## The factory copies every incoming collection before reading it and stores
## only primitives plus immutable child view models. Consumers receive either
## primitive values or a fresh array, so a screen can never mutate presenter or
## domain state through this object.

class StoryStepViewModel:
	extends RefCounted

	var _id: StringName
	var _title: String
	var _body: String
	var _next_label: String

	func _init(
		step_id: StringName,
		title_value: String,
		body_value: String,
		next_label_value: String
	) -> void:
		_id = step_id
		_title = title_value
		_body = body_value
		_next_label = next_label_value

	func id() -> StringName:
		return _id

	func title() -> String:
		return _title

	func body() -> String:
		return _body

	func next_label() -> String:
		return _next_label


var _story_id: StringName = &"story"
var _steps: Array[StoryStepViewModel] = []
var _allow_skip := true
var _allow_back := true
var _skip_label := "Überspringen"
var _revision := 0
var _content_hash := ""


## Accepted row keys: id, title, body and next_label. Unknown data is discarded
## at this boundary instead of leaking a mutable Dictionary into the screen.
static func create(
	step_rows: Array,
	revision_value: int = 0,
	story_id_value: StringName = &"story",
	allow_skip_value: bool = true,
	allow_back_value: bool = true,
	skip_label_value: String = "Überspringen"
) -> StoryScreenViewModel:
	var result := StoryScreenViewModel.new()
	result._story_id = story_id_value if story_id_value != &"" else &"story"
	result._allow_skip = allow_skip_value
	result._allow_back = allow_back_value
	result._skip_label = skip_label_value.strip_edges()
	if result._skip_label.is_empty():
		result._skip_label = "Überspringen"
	result._revision = maxi(0, revision_value)

	var copied_rows: Array = step_rows.duplicate(true)
	for index in range(copied_rows.size()):
		var row_value: Variant = copied_rows[index]
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		var title_value := String(row.get("title", "")).strip_edges()
		var body_value := String(row.get("body", "")).strip_edges()
		if title_value.is_empty() or body_value.is_empty():
			continue
		var step_id := StringName(String(row.get("id", "step_%d" % (index + 1))))
		if step_id == &"":
			step_id = StringName("step_%d" % (index + 1))
		var next_label_value := String(row.get("next_label", "Weiter")).strip_edges()
		if next_label_value.is_empty():
			next_label_value = "Weiter"
		result._steps.append(StoryStepViewModel.new(
			step_id,
			title_value,
			body_value,
			next_label_value
		))
	result._content_hash = result._calculate_content_hash()
	return result


func story_id() -> StringName:
	return _story_id


func revision() -> int:
	return _revision


func content_hash() -> String:
	return _content_hash


func allow_skip() -> bool:
	return _allow_skip


func allow_back() -> bool:
	return _allow_back


func skip_label() -> String:
	return _skip_label


func step_count() -> int:
	return _steps.size()


func is_empty() -> bool:
	return _steps.is_empty()


func step_at(index_value: int) -> StoryStepViewModel:
	if index_value < 0 or index_value >= _steps.size():
		return null
	return _steps[index_value]


func steps() -> Array[StoryStepViewModel]:
	var result: Array[StoryStepViewModel] = []
	result.assign(_steps)
	return result


func _calculate_content_hash() -> String:
	var canonical := PackedStringArray()
	canonical.append(_length_prefixed(String(_story_id)))
	canonical.append("1" if _allow_skip else "0")
	canonical.append("1" if _allow_back else "0")
	canonical.append(_length_prefixed(_skip_label))
	for step in _steps:
		canonical.append(_length_prefixed(String(step.id())))
		canonical.append(_length_prefixed(step.title()))
		canonical.append(_length_prefixed(step.body()))
		canonical.append(_length_prefixed(step.next_label()))
	return "|".join(canonical).sha256_text()


func _length_prefixed(value: String) -> String:
	return "%d:%s" % [value.length(), value]
