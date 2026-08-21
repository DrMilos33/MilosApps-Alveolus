class_name ProgressionScreenViewModel
extends RefCounted

## Immutable presentation boundary for the combined Research/Talent screen.
## Only ready-to-render primitives and deeply copied child view-models cross
## this boundary; runtime progression and catalog objects stay in presenters.

enum ItemState {
	ACTIVE,
	AVAILABLE,
	LOCKED,
}


class InfoViewModel extends RefCounted:
	var _title: String
	var _body: String
	var _meta: String
	var _icon_kind: StringName
	var _accent: Color


	static func create(
		title_value: String,
		body_value: String,
		meta_value: String,
		icon_kind_value: StringName,
		accent_value: Color
	) -> InfoViewModel:
		var model := InfoViewModel.new()
		model._title = title_value
		model._body = body_value
		model._meta = meta_value
		model._icon_kind = icon_kind_value
		model._accent = accent_value
		return model


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


	func duplicate_value() -> InfoViewModel:
		return create(_title, _body, _meta, _icon_kind, _accent)


	func content_signature() -> Array:
		return [_title, _body, _meta, _icon_kind, _accent]


class ResearchItemViewModel extends RefCounted:
	var _id: StringName
	var _title: String
	var _rank_text: String
	var _cost_text: String
	var _icon_kind: StringName
	var _state: int
	var _interactive: bool
	var _info: InfoViewModel
	var _total_effect_text: String


	static func create(
		id_value: StringName,
		title_value: String,
		rank_text_value: String,
		cost_text_value: String,
		icon_kind_value: StringName,
		state_value: int,
		interactive_value: bool,
		info_value: InfoViewModel,
		total_effect_text_value: String = ""
	) -> ResearchItemViewModel:
		var model := ResearchItemViewModel.new()
		model._id = id_value
		model._title = title_value
		model._rank_text = rank_text_value
		model._cost_text = cost_text_value
		model._icon_kind = icon_kind_value
		model._state = clampi(state_value, ItemState.ACTIVE, ItemState.LOCKED)
		model._interactive = interactive_value and id_value != &"" and model._state == ItemState.AVAILABLE
		model._info = info_value.duplicate_value() if info_value != null else InfoViewModel.create(title_value, "", "", icon_kind_value, Color.TRANSPARENT)
		model._total_effect_text = total_effect_text_value
		return model


	func id() -> StringName:
		return _id


	func title() -> String:
		return _title


	func rank_text() -> String:
		return _rank_text


	func cost_text() -> String:
		return _cost_text


	func icon_kind() -> StringName:
		return _icon_kind


	func state() -> int:
		return _state


	func interactive() -> bool:
		return _interactive


	func info() -> InfoViewModel:
		return _info.duplicate_value()


	## Ready-to-render total effect supplied by the progression presenter. The
	## view-model only composes presentation copy; it never derives rank values.
	func total_effect_text() -> String:
		return _total_effect_text


	func detail_info() -> InfoViewModel:
		if _total_effect_text.is_empty():
			return _info.duplicate_value()
		var detail_body := _info.body()
		if not detail_body.is_empty():
			detail_body += "\n"
		detail_body += "Gesamt: %s" % _total_effect_text
		return InfoViewModel.create(
			_info.title(),
			detail_body,
			_info.meta(),
			_info.icon_kind(),
			_info.accent()
		)


	func duplicate_value() -> ResearchItemViewModel:
		return create(_id, _title, _rank_text, _cost_text, _icon_kind, _state, _interactive, _info, _total_effect_text)


	func content_signature() -> Array:
		return [_id, _title, _rank_text, _cost_text, _icon_kind, _state, _interactive, _info.content_signature(), _total_effect_text]


class TalentNodeViewModel extends RefCounted:
	var _id: StringName
	var _title: String
	var _cost_text: String
	var _icon_kind: StringName
	var _tier: int
	var _lane: int
	var _required_ids: PackedStringArray
	var _state: int
	var _interactive: bool
	var _info: InfoViewModel
	var _rank_current: int
	var _rank_maximum: int


	static func create(
		id_value: StringName,
		title_value: String,
		cost_text_value: String,
		icon_kind_value: StringName,
		tier_value: int,
		lane_value: int,
		required_ids_value: PackedStringArray,
		state_value: int,
		interactive_value: bool,
		info_value: InfoViewModel,
		rank_current_value: int = 0,
		rank_maximum_value: int = 0
	) -> TalentNodeViewModel:
		var model := TalentNodeViewModel.new()
		model._id = id_value
		model._title = title_value
		model._cost_text = cost_text_value
		model._icon_kind = icon_kind_value
		model._tier = maxi(0, tier_value)
		model._lane = clampi(lane_value, 0, 2)
		model._required_ids = required_ids_value.duplicate()
		model._state = clampi(state_value, ItemState.ACTIVE, ItemState.LOCKED)
		model._interactive = interactive_value and id_value != &"" and model._state != ItemState.LOCKED
		model._info = info_value.duplicate_value() if info_value != null else InfoViewModel.create(title_value, "", "", icon_kind_value, Color.TRANSPARENT)
		model._rank_maximum = maxi(0, rank_maximum_value)
		model._rank_current = clampi(rank_current_value, 0, model._rank_maximum)
		return model


	func id() -> StringName:
		return _id


	func title() -> String:
		return _title


	func cost_text() -> String:
		return _cost_text


	func icon_kind() -> StringName:
		return _icon_kind


	func tier() -> int:
		return _tier


	func lane() -> int:
		return _lane


	func required_ids() -> PackedStringArray:
		return _required_ids.duplicate()


	func state() -> int:
		return _state


	func interactive() -> bool:
		return _interactive


	func info() -> InfoViewModel:
		return _info.duplicate_value()


	## Already resolved rank primitives supplied by the presenter. The screen
	## only turns these into pips; cost, effect and prerequisites stay in detail.
	func rank_current() -> int:
		return _rank_current


	func rank_maximum() -> int:
		return _rank_maximum


	func duplicate_value() -> TalentNodeViewModel:
		return create(
			_id,
			_title,
			_cost_text,
			_icon_kind,
			_tier,
			_lane,
			_required_ids,
			_state,
			_interactive,
			_info,
			_rank_current,
			_rank_maximum
		)


	func content_signature() -> Array:
		return [
			_id,
			_title,
			_cost_text,
			_icon_kind,
			_tier,
			_lane,
			_required_ids,
			_state,
			_interactive,
			_info.content_signature(),
			_rank_current,
			_rank_maximum,
		]


class TalentBranchViewModel extends RefCounted:
	var _id: StringName
	var _title: String
	var _icon_kind: StringName
	var _accent: Color
	var _nodes: Array[TalentNodeViewModel] = []


	static func create(
		id_value: StringName,
		title_value: String,
		icon_kind_value: StringName,
		accent_value: Color,
		node_values: Array
	) -> TalentBranchViewModel:
		var model := TalentBranchViewModel.new()
		model._id = id_value
		model._title = title_value
		model._icon_kind = icon_kind_value
		model._accent = accent_value
		for node_value in node_values:
			if node_value is TalentNodeViewModel:
				model._nodes.append((node_value as TalentNodeViewModel).duplicate_value())
		return model


	func id() -> StringName:
		return _id


	func title() -> String:
		return _title


	func icon_kind() -> StringName:
		return _icon_kind


	func accent() -> Color:
		return _accent


	func nodes() -> Array[TalentNodeViewModel]:
		var result: Array[TalentNodeViewModel] = []
		for node in _nodes:
			result.append(node.duplicate_value())
		return result


	func node_count() -> int:
		return _nodes.size()


	func duplicate_value() -> TalentBranchViewModel:
		return create(_id, _title, _icon_kind, _accent, _nodes)


	func content_signature() -> Array:
		var node_signatures: Array = []
		for node in _nodes:
			node_signatures.append(node.content_signature())
		return [_id, _title, _icon_kind, _accent, node_signatures]


var _revision: int
var _content_hash: int
var _research_hash: int
var _talent_hash: int
var _selected_tab: StringName
var _research_balance_text: String
var _talent_balance_text: String
var _talent_reset_enabled: bool
var _talents_unlocked: bool
var _talent_lock_text: String
var _research_items: Array[ResearchItemViewModel] = []
var _talent_branches: Array[TalentBranchViewModel] = []


func _init() -> void:
	_selected_tab = &"research"
	_research_hash = hash([])
	_talent_hash = hash([])
	_content_hash = hash(_content_signature())


static func create(
	revision_value: int,
	selected_tab_value: StringName,
	research_balance_text_value: String,
	talent_balance_text_value: String,
	talent_reset_enabled_value: bool,
	research_item_values: Array,
	talent_branch_values: Array,
	talents_unlocked_value: bool = true,
	talent_lock_text_value: String = ""
) -> ProgressionScreenViewModel:
	var model := ProgressionScreenViewModel.new()
	model._revision = maxi(0, revision_value)
	model._selected_tab = &"talents" if selected_tab_value == &"talents" else &"research"
	model._research_balance_text = research_balance_text_value
	model._talent_balance_text = talent_balance_text_value
	model._talent_reset_enabled = talent_reset_enabled_value
	model._talents_unlocked = talents_unlocked_value
	model._talent_lock_text = talent_lock_text_value.strip_edges()
	if not model._talents_unlocked and model._talent_lock_text.is_empty():
		model._talent_lock_text = "Schließe die Einführung ab, um Talente freizuschalten."
	for item_value in research_item_values:
		if item_value is ResearchItemViewModel:
			model._research_items.append((item_value as ResearchItemViewModel).duplicate_value())
	for branch_value in talent_branch_values:
		if branch_value is TalentBranchViewModel:
			model._talent_branches.append((branch_value as TalentBranchViewModel).duplicate_value())
	model._research_hash = hash(model._research_signatures())
	model._talent_hash = hash(model._talent_signatures())
	model._content_hash = hash(model._content_signature())
	return model


func revision() -> int:
	return _revision


func content_hash() -> int:
	return _content_hash


func research_hash() -> int:
	return _research_hash


func talent_hash() -> int:
	return _talent_hash


func selected_tab() -> StringName:
	return _selected_tab


func research_balance_text() -> String:
	return _research_balance_text


func talent_balance_text() -> String:
	return _talent_balance_text


func talent_reset_enabled() -> bool:
	return _talent_reset_enabled


func talents_unlocked() -> bool:
	return _talents_unlocked


func talent_lock_text() -> String:
	return _talent_lock_text


func research_items() -> Array[ResearchItemViewModel]:
	var result: Array[ResearchItemViewModel] = []
	for item in _research_items:
		result.append(item.duplicate_value())
	return result


func talent_branches() -> Array[TalentBranchViewModel]:
	var result: Array[TalentBranchViewModel] = []
	for branch in _talent_branches:
		result.append(branch.duplicate_value())
	return result


func research_item_count() -> int:
	return _research_items.size()


func talent_branch_count() -> int:
	return _talent_branches.size()


func _content_signature() -> Array:
	return [
		_selected_tab,
		_research_balance_text,
		_talent_balance_text,
		_talent_reset_enabled,
		_talents_unlocked,
		_talent_lock_text,
		_research_signatures(),
		_talent_signatures(),
	]


func _research_signatures() -> Array:
	var result: Array = []
	for item in _research_items:
		result.append(item.content_signature())
	return result


func _talent_signatures() -> Array:
	var result: Array = []
	for branch in _talent_branches:
		result.append(branch.content_signature())
	return result
