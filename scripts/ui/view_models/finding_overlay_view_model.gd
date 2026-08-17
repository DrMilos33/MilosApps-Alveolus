class_name FindingOverlayViewModel
extends RefCounted

## Immutable presentation boundary for the finding/reaction modal.
## Only ready-to-render primitives, colours and deeply copied child view models
## cross this boundary. Dormant reserve data remains optional presentation data.


class InfoViewModel extends RefCounted:
	var _title: String
	var _body: String
	var _meta: String
	var _icon_kind: StringName
	var _accent: Color


	func _init(
		title_value: String = "",
		body_value: String = "",
		meta_value: String = "",
		icon_kind_value: StringName = &"information",
		accent_value: Color = Color.TRANSPARENT
	) -> void:
		_title = title_value.strip_edges()
		_body = body_value.strip_edges()
		_meta = meta_value.strip_edges()
		_icon_kind = icon_kind_value
		_accent = accent_value


	func title() -> String:
		return _title


	func body() -> String:
		return _body


	func meta() -> String:
		return _meta


	func icon_kind() -> StringName:
		return _icon_kind


	func accent() -> Color:
		return _accent


	func payload() -> Dictionary:
		return {
			"title": _title,
			"body": _body,
			"meta": _meta,
			"icon_kind": _icon_kind,
			"accent": _accent,
		}


	func duplicate_immutable() -> InfoViewModel:
		return InfoViewModel.new(_title, _body, _meta, _icon_kind, _accent)


	func append_signature(parts: PackedStringArray) -> void:
		parts.append(FindingOverlayViewModel._signature_part(_title))
		parts.append(FindingOverlayViewModel._signature_part(_body))
		parts.append(FindingOverlayViewModel._signature_part(_meta))
		parts.append(FindingOverlayViewModel._signature_part(String(_icon_kind)))
		parts.append(_accent.to_html(true))


class ReactionViewModel extends RefCounted:
	var _id: StringName
	var _title: String
	var _accessible_summary: String
	var _icon_kind: StringName
	var _accent: Color
	var _interactive: bool
	var _info: InfoViewModel


	func _init(
		id_value: StringName,
		title_value: String,
		accessible_summary_value: String = "",
		icon_kind_value: StringName = &"ability",
		accent_value: Color = Color.TRANSPARENT,
		interactive_value: bool = true,
		info_value: InfoViewModel = null
	) -> void:
		_id = id_value
		_title = title_value.strip_edges()
		if _title.is_empty():
			_title = "Reaktion"
		_accessible_summary = accessible_summary_value.strip_edges()
		_icon_kind = icon_kind_value
		_accent = accent_value
		_interactive = interactive_value and id_value != &""
		_info = info_value.duplicate_immutable() if info_value != null else InfoViewModel.new(
			_title,
			_accessible_summary,
			"",
			icon_kind_value,
			accent_value
		)


	func id() -> StringName:
		return _id


	func title() -> String:
		return _title


	func accessible_summary() -> String:
		return _accessible_summary


	func icon_kind() -> StringName:
		return _icon_kind


	func accent() -> Color:
		return _accent


	func interactive() -> bool:
		return _interactive


	func info() -> InfoViewModel:
		return _info.duplicate_immutable()


	func duplicate_immutable() -> ReactionViewModel:
		return ReactionViewModel.new(
			_id,
			_title,
			_accessible_summary,
			_icon_kind,
			_accent,
			_interactive,
			_info
		)


	func append_signature(parts: PackedStringArray) -> void:
		parts.append(FindingOverlayViewModel._signature_part(String(_id)))
		parts.append(FindingOverlayViewModel._signature_part(_title))
		parts.append(FindingOverlayViewModel._signature_part(_accessible_summary))
		parts.append(FindingOverlayViewModel._signature_part(String(_icon_kind)))
		parts.append(_accent.to_html(true))
		parts.append("1" if _interactive else "0")
		_info.append_signature(parts)


class OutgoingOptionViewModel extends RefCounted:
	var _id: StringName
	var _title: String


	func _init(id_value: StringName, title_value: String) -> void:
		_id = id_value
		_title = title_value.strip_edges()
		if _title.is_empty():
			_title = String(id_value)


	func id() -> StringName:
		return _id


	func title() -> String:
		return _title


	func duplicate_immutable() -> OutgoingOptionViewModel:
		return OutgoingOptionViewModel.new(_id, _title)


	func append_signature(parts: PackedStringArray) -> void:
		parts.append(FindingOverlayViewModel._signature_part(String(_id)))
		parts.append(FindingOverlayViewModel._signature_part(_title))


class ReserveSwapViewModel extends RefCounted:
	var _visible: bool
	var _incoming_id: StringName
	var _incoming_title: String
	var _can_swap: bool
	var _swap_enabled: bool
	var _selected_outgoing_id: StringName
	var _outgoing_options: Array[OutgoingOptionViewModel]


	func _init(
		visible_value: bool = false,
		incoming_id_value: StringName = &"",
		incoming_title_value: String = "",
		can_swap_value: bool = false,
		swap_enabled_value: bool = false,
		outgoing_options_value: Array[OutgoingOptionViewModel] = [],
		selected_outgoing_id_value: StringName = &""
	) -> void:
		_visible = visible_value
		_incoming_id = incoming_id_value
		_incoming_title = incoming_title_value.strip_edges()
		_outgoing_options = _copy_options(outgoing_options_value)
		_can_swap = (
			_visible
			and can_swap_value
			and _incoming_id != &""
			and not _outgoing_options.is_empty()
		)
		_swap_enabled = _can_swap and swap_enabled_value
		_selected_outgoing_id = _normalized_outgoing_id(selected_outgoing_id_value)


	func is_visible() -> bool:
		return _visible


	func incoming_id() -> StringName:
		return _incoming_id


	func incoming_title() -> String:
		return _incoming_title


	func can_swap() -> bool:
		return _can_swap


	func swap_enabled() -> bool:
		return _swap_enabled


	func selected_outgoing_id() -> StringName:
		return _selected_outgoing_id


	func outgoing_options() -> Array[OutgoingOptionViewModel]:
		return _copy_options(_outgoing_options)


	func outgoing_index(id_value: StringName) -> int:
		for index in range(_outgoing_options.size()):
			if _outgoing_options[index].id() == id_value:
				return index
		return -1


	func duplicate_immutable() -> ReserveSwapViewModel:
		return ReserveSwapViewModel.new(
			_visible,
			_incoming_id,
			_incoming_title,
			_can_swap,
			_swap_enabled,
			_outgoing_options,
			_selected_outgoing_id
		)


	func append_structure_signature(parts: PackedStringArray) -> void:
		parts.append("1" if _visible else "0")
		parts.append(FindingOverlayViewModel._signature_part(String(_incoming_id)))
		parts.append(FindingOverlayViewModel._signature_part(_incoming_title))
		parts.append("1" if _can_swap else "0")
		parts.append(str(_outgoing_options.size()))
		for option in _outgoing_options:
			option.append_signature(parts)


	func append_content_signature(parts: PackedStringArray) -> void:
		append_structure_signature(parts)
		parts.append("1" if _swap_enabled else "0")
		parts.append(FindingOverlayViewModel._signature_part(String(_selected_outgoing_id)))


	func _normalized_outgoing_id(value: StringName) -> StringName:
		if outgoing_index(value) >= 0:
			return value
		return _outgoing_options[0].id() if not _outgoing_options.is_empty() else &""


	func _copy_options(source: Array[OutgoingOptionViewModel]) -> Array[OutgoingOptionViewModel]:
		var result: Array[OutgoingOptionViewModel] = []
		for option in source:
			if option != null:
				result.append(option.duplicate_immutable())
		return result


var _revision: int
var _content_hash: String
var _structure_hash: String
var _finding_id: StringName
var _title: String
var _medical_text: String
var _gameplay_text: String
var _reactions: Array[ReactionViewModel]
var _selected_reaction_id: StringName
var _reserve_swap: ReserveSwapViewModel
var _validation_valid: bool
var _validation_text: String


func _init(
	revision_value: int = 0,
	finding_id_value: StringName = &"",
	title_value: String = "",
	medical_text_value: String = "",
	gameplay_text_value: String = "",
	reactions_value: Array[ReactionViewModel] = [],
	selected_reaction_id_value: StringName = &"",
	reserve_swap_value: ReserveSwapViewModel = null,
	validation_valid_value: bool = true,
	validation_text_value: String = ""
) -> void:
	_revision = maxi(0, revision_value)
	_finding_id = finding_id_value
	_title = title_value.strip_edges()
	if _title.is_empty():
		_title = "Befund"
	_medical_text = medical_text_value.strip_edges()
	_gameplay_text = gameplay_text_value.strip_edges()
	_reactions = _copy_reactions(reactions_value)
	_selected_reaction_id = _normalized_reaction_id(selected_reaction_id_value)
	_reserve_swap = reserve_swap_value.duplicate_immutable() if reserve_swap_value != null else ReserveSwapViewModel.new()
	_validation_valid = validation_valid_value
	_validation_text = validation_text_value.strip_edges()
	_structure_hash = _calculate_structure_hash()
	_content_hash = _calculate_content_hash()


func revision() -> int:
	return _revision


func content_hash() -> String:
	return _content_hash


func structure_hash() -> String:
	return _structure_hash


func finding_id() -> StringName:
	return _finding_id


func title() -> String:
	return _title


func medical_text() -> String:
	return _medical_text


func gameplay_text() -> String:
	return _gameplay_text


func reactions() -> Array[ReactionViewModel]:
	return _copy_reactions(_reactions)


func reaction(id_value: StringName) -> ReactionViewModel:
	for item in _reactions:
		if item.id() == id_value:
			return item.duplicate_immutable()
	return null


func selected_reaction_id() -> StringName:
	return _selected_reaction_id


func reserve_swap() -> ReserveSwapViewModel:
	return _reserve_swap.duplicate_immutable()


func validation_valid() -> bool:
	return _validation_valid


func validation_text() -> String:
	return _validation_text


func can_confirm() -> bool:
	if _selected_reaction_id == &"" or not _validation_valid:
		return false
	if _reserve_swap.swap_enabled() and _reserve_swap.selected_outgoing_id() == &"":
		return false
	return true


func duplicate_immutable() -> FindingOverlayViewModel:
	return FindingOverlayViewModel.new(
		_revision,
		_finding_id,
		_title,
		_medical_text,
		_gameplay_text,
		_reactions,
		_selected_reaction_id,
		_reserve_swap,
		_validation_valid,
		_validation_text
	)


func _normalized_reaction_id(value: StringName) -> StringName:
	for item in _reactions:
		if item.id() == value and item.interactive():
			return value
	return &""


func _copy_reactions(source: Array[ReactionViewModel]) -> Array[ReactionViewModel]:
	var result: Array[ReactionViewModel] = []
	for item in source:
		if item != null:
			result.append(item.duplicate_immutable())
	return result


func _calculate_structure_hash() -> String:
	var parts := PackedStringArray([
		_signature_part(String(_finding_id)),
		_signature_part(_title),
		_signature_part(_medical_text),
		_signature_part(_gameplay_text),
		str(_reactions.size()),
	])
	for item in _reactions:
		item.append_signature(parts)
	_reserve_swap.append_structure_signature(parts)
	return "|".join(parts).sha256_text()


func _calculate_content_hash() -> String:
	var parts := PackedStringArray([
		_structure_hash,
		_signature_part(String(_selected_reaction_id)),
		"1" if _validation_valid else "0",
		_signature_part(_validation_text),
	])
	_reserve_swap.append_content_signature(parts)
	return "|".join(parts).sha256_text()


static func _signature_part(value: String) -> String:
	return "%d:%s" % [value.length(), value]
