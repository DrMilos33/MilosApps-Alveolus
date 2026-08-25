class_name PracticeScreenViewModel
extends RefCounted

## Immutable presentation data for PracticeScreen.
##
## The integration layer decides whether local tests are visible and converts
## practice definitions into these primitive offers. No save, progression or
## platform/debug service crosses this boundary.

const EVENT_TEST_GROUP_ID := &"event_test"
const EVENT_TEST_SCENARIO_PREFIX := "event_test:"


class ScenarioOfferViewModel extends RefCounted:
	var _id: StringName
	var _title: String
	var _description: String
	var _facts_text: String
	var _enabled: bool
	var _requires_boss_profile: bool


	static func create(
		id_value: StringName,
		title_value: String,
		description_value: String,
		facts_text_value: String,
		enabled_value: bool = true,
		requires_boss_profile_value: bool = false
	) -> ScenarioOfferViewModel:
		var model := ScenarioOfferViewModel.new()
		model._id = id_value
		model._title = title_value
		model._description = description_value
		model._facts_text = facts_text_value
		model._enabled = enabled_value and id_value != &""
		model._requires_boss_profile = requires_boss_profile_value
		return model


	func id() -> StringName:
		return _id


	func title() -> String:
		return _title


	func description() -> String:
		return _description


	func facts_text() -> String:
		return _facts_text


	func enabled() -> bool:
		return _enabled


	func requires_boss_profile() -> bool:
		return _requires_boss_profile


	func duplicate_value() -> ScenarioOfferViewModel:
		return create(
			_id,
			_title,
			_description,
			_facts_text,
			_enabled,
			_requires_boss_profile
		)


	func content_signature() -> Array:
		return [
			_id,
			_title,
			_description,
			_facts_text,
			_enabled,
			_requires_boss_profile,
		]


class BossProfileOfferViewModel extends RefCounted:
	var _id: StringName
	var _title: String
	var _description: String
	var _facts_text: String
	var _enabled: bool


	static func create(
		id_value: StringName,
		title_value: String,
		description_value: String,
		facts_text_value: String,
		enabled_value: bool = true
	) -> BossProfileOfferViewModel:
		var model := BossProfileOfferViewModel.new()
		model._id = id_value
		model._title = title_value
		model._description = description_value
		model._facts_text = facts_text_value
		model._enabled = enabled_value and id_value != &""
		return model


	func id() -> StringName:
		return _id


	func title() -> String:
		return _title


	func description() -> String:
		return _description


	func facts_text() -> String:
		return _facts_text


	func enabled() -> bool:
		return _enabled


	func duplicate_value() -> BossProfileOfferViewModel:
		return create(_id, _title, _description, _facts_text, _enabled)


	func content_signature() -> Array:
		return [_id, _title, _description, _facts_text, _enabled]


var _revision: int
var _content_hash: int
var _scenario_offers_hash: int
var _boss_profile_offers_hash: int
var _tests_visible: bool
var _selected_scenario_id: StringName
var _selected_boss_profile_id: StringName
var _scenario_offers: Array[ScenarioOfferViewModel] = []
var _boss_profile_offers: Array[BossProfileOfferViewModel] = []


func _init() -> void:
	_scenario_offers_hash = hash([])
	_boss_profile_offers_hash = hash([])
	_content_hash = hash(_content_signature())


static func create(
	revision_value: int,
	tests_visible_value: bool,
	selected_scenario_id_value: StringName,
	selected_boss_profile_id_value: StringName,
	scenario_offer_values: Array,
	boss_profile_offer_values: Array
) -> PracticeScreenViewModel:
	var model := PracticeScreenViewModel.new()
	model._revision = maxi(0, revision_value)
	model._tests_visible = tests_visible_value
	for offer_value in scenario_offer_values:
		if offer_value is ScenarioOfferViewModel:
			model._scenario_offers.append((offer_value as ScenarioOfferViewModel).duplicate_value())
	for profile_value in boss_profile_offer_values:
		if profile_value is BossProfileOfferViewModel:
			model._boss_profile_offers.append((profile_value as BossProfileOfferViewModel).duplicate_value())
	model._selected_scenario_id = model._validated_scenario_id(selected_scenario_id_value)
	if model.selected_scenario_requires_boss_profile():
		model._selected_boss_profile_id = model._validated_boss_profile_id(selected_boss_profile_id_value)
	model._scenario_offers_hash = hash(model._scenario_offer_signatures())
	model._boss_profile_offers_hash = hash(model._boss_profile_offer_signatures())
	model._content_hash = hash(model._content_signature())
	return model


func revision() -> int:
	return _revision


func content_hash() -> int:
	return _content_hash


func scenario_offers_hash() -> int:
	return _scenario_offers_hash


func boss_profile_offers_hash() -> int:
	return _boss_profile_offers_hash


func tests_visible() -> bool:
	return _tests_visible


func selected_scenario_id() -> StringName:
	return _selected_scenario_id


func selected_boss_profile_id() -> StringName:
	return _selected_boss_profile_id


func selected_scenario_requires_boss_profile() -> bool:
	for offer in _scenario_offers:
		if offer.id() == _selected_scenario_id:
			return offer.requires_boss_profile()
	return false


func selected_scenario_is_event_test() -> bool:
	return is_event_test_scenario_id(_selected_scenario_id)


static func is_event_test_scenario_id(id_value: StringName) -> bool:
	return String(id_value).begins_with(EVENT_TEST_SCENARIO_PREFIX)


func scenario_offers() -> Array[ScenarioOfferViewModel]:
	var result: Array[ScenarioOfferViewModel] = []
	for offer in _scenario_offers:
		result.append(offer.duplicate_value())
	return result


func primary_scenario_offers() -> Array[ScenarioOfferViewModel]:
	var result: Array[ScenarioOfferViewModel] = []
	for offer in _scenario_offers:
		if not is_event_test_scenario_id(offer.id()):
			result.append(offer.duplicate_value())
	return result


func event_scenario_offers() -> Array[ScenarioOfferViewModel]:
	var result: Array[ScenarioOfferViewModel] = []
	for offer in _scenario_offers:
		if is_event_test_scenario_id(offer.id()):
			result.append(offer.duplicate_value())
	return result


func event_scenario_offer_count() -> int:
	var result := 0
	for offer in _scenario_offers:
		if is_event_test_scenario_id(offer.id()):
			result += 1
	return result


func scenario_offer_count() -> int:
	return _scenario_offers.size()


func scenario_offer_at(index: int) -> ScenarioOfferViewModel:
	if index < 0 or index >= _scenario_offers.size():
		return null
	return _scenario_offers[index].duplicate_value()


func boss_profile_offers() -> Array[BossProfileOfferViewModel]:
	var result: Array[BossProfileOfferViewModel] = []
	for offer in _boss_profile_offers:
		result.append(offer.duplicate_value())
	return result


func boss_profile_offer_count() -> int:
	return _boss_profile_offers.size()


func boss_profile_offer_at(index: int) -> BossProfileOfferViewModel:
	if index < 0 or index >= _boss_profile_offers.size():
		return null
	return _boss_profile_offers[index].duplicate_value()


func _validated_scenario_id(candidate: StringName) -> StringName:
	if not _tests_visible:
		return &""
	for offer in _scenario_offers:
		if offer.id() == candidate and offer.enabled():
			return candidate
	return &""


func _validated_boss_profile_id(candidate: StringName) -> StringName:
	for offer in _boss_profile_offers:
		if offer.id() == candidate and offer.enabled():
			return candidate
	return &""


func _content_signature() -> Array:
	return [
		_tests_visible,
		_selected_scenario_id,
		_selected_boss_profile_id,
		_scenario_offer_signatures(),
		_boss_profile_offer_signatures(),
	]


func _scenario_offer_signatures() -> Array:
	var signatures: Array = []
	for offer in _scenario_offers:
		signatures.append(offer.content_signature())
	return signatures


func _boss_profile_offer_signatures() -> Array:
	var signatures: Array = []
	for offer in _boss_profile_offers:
		signatures.append(offer.content_signature())
	return signatures
