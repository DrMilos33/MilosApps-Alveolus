class_name PracticeScreenViewModel
extends RefCounted

## Immutable presentation data for PracticeScreen.
##
## Domain objects are deliberately converted before they reach this boundary.
## Every child value is copied on construction and on read so callers cannot
## mutate a model that has already been applied by the screen.


class OfflineResearchViewModel extends RefCounted:
	var _stored_text: String
	var _capacity_text: String
	var _claim_button_text: String
	var _claimable_amount: int
	var _claim_enabled: bool


	static func create(
		stored_text_value: String,
		capacity_text_value: String,
		claim_button_text_value: String,
		claimable_amount_value: int,
		claim_enabled_value: bool
	) -> OfflineResearchViewModel:
		var model := OfflineResearchViewModel.new()
		model._stored_text = stored_text_value
		model._capacity_text = capacity_text_value
		model._claim_button_text = claim_button_text_value
		model._claimable_amount = maxi(0, claimable_amount_value)
		model._claim_enabled = claim_enabled_value and model._claimable_amount > 0
		return model


	func stored_text() -> String:
		return _stored_text


	func capacity_text() -> String:
		return _capacity_text


	func claim_button_text() -> String:
		return _claim_button_text


	func claimable_amount() -> int:
		return _claimable_amount


	func claim_enabled() -> bool:
		return _claim_enabled


	func duplicate_value() -> OfflineResearchViewModel:
		return create(
			_stored_text,
			_capacity_text,
			_claim_button_text,
			_claimable_amount,
			_claim_enabled
		)


	func content_signature() -> Array:
		return [
			_stored_text,
			_capacity_text,
			_claim_button_text,
			_claimable_amount,
			_claim_enabled,
		]


class ClinicJobOfferViewModel extends RefCounted:
	var _id: StringName
	var _title: String
	var _duration_text: String
	var _reward_text: String
	var _enabled: bool


	static func create(
		id_value: StringName,
		title_value: String,
		duration_text_value: String,
		reward_text_value: String,
		enabled_value: bool = true
	) -> ClinicJobOfferViewModel:
		var model := ClinicJobOfferViewModel.new()
		model._id = id_value
		model._title = title_value
		model._duration_text = duration_text_value
		model._reward_text = reward_text_value
		model._enabled = enabled_value and id_value != &""
		return model


	func id() -> StringName:
		return _id


	func title() -> String:
		return _title


	func duration_text() -> String:
		return _duration_text


	func reward_text() -> String:
		return _reward_text


	func enabled() -> bool:
		return _enabled


	func duplicate_value() -> ClinicJobOfferViewModel:
		return create(_id, _title, _duration_text, _reward_text, _enabled)


	func content_signature() -> Array:
		return [_id, _title, _duration_text, _reward_text, _enabled]


class ClinicStatusViewModel extends RefCounted:
	var _has_active_job: bool
	var _job_id: StringName
	var _status_text: String
	var _completed: bool
	var _progress_value: float
	var _progress_maximum: float
	var _remaining_text: String
	var _reward_text: String
	var _finish_text: String


	static func idle(status_text_value: String = "Wähle einen zeitgesteuerten Fall") -> ClinicStatusViewModel:
		return create(
			false,
			&"",
			status_text_value,
			false,
			0.0,
			1.0,
			"",
			"",
			""
		)


	static func create(
		has_active_job_value: bool,
		job_id_value: StringName,
		status_text_value: String,
		completed_value: bool,
		progress_value_value: float,
		progress_maximum_value: float,
		remaining_text_value: String,
		reward_text_value: String,
		finish_text_value: String
	) -> ClinicStatusViewModel:
		var model := ClinicStatusViewModel.new()
		model._has_active_job = has_active_job_value and job_id_value != &""
		model._job_id = job_id_value if model._has_active_job else &""
		model._status_text = status_text_value
		model._completed = completed_value and model._has_active_job
		model._progress_maximum = maxf(1.0, progress_maximum_value)
		model._progress_value = clampf(progress_value_value, 0.0, model._progress_maximum)
		model._remaining_text = remaining_text_value
		model._reward_text = reward_text_value
		model._finish_text = finish_text_value
		return model


	func has_active_job() -> bool:
		return _has_active_job


	func job_id() -> StringName:
		return _job_id


	func status_text() -> String:
		return _status_text


	func completed() -> bool:
		return _completed


	func progress_value() -> float:
		return _progress_value


	func progress_maximum() -> float:
		return _progress_maximum


	func remaining_text() -> String:
		return _remaining_text


	func reward_text() -> String:
		return _reward_text


	func finish_text() -> String:
		return _finish_text


	func duplicate_value() -> ClinicStatusViewModel:
		return create(
			_has_active_job,
			_job_id,
			_status_text,
			_completed,
			_progress_value,
			_progress_maximum,
			_remaining_text,
			_reward_text,
			_finish_text
		)


	func content_signature() -> Array:
		return [
			_has_active_job,
			_job_id,
			_status_text,
			_completed,
			_progress_value,
			_progress_maximum,
			_remaining_text,
			_reward_text,
			_finish_text,
		]


var _revision: int
var _content_hash: int
var _job_offers_hash: int
var _research_balance_text: String
var _offline: OfflineResearchViewModel
var _clinic: ClinicStatusViewModel
var _job_offers: Array[ClinicJobOfferViewModel] = []


func _init() -> void:
	_offline = OfflineResearchViewModel.create("", "", "", 0, false)
	_clinic = ClinicStatusViewModel.idle()
	_job_offers_hash = hash([])
	_content_hash = hash(_content_signature())


static func create(
	revision_value: int,
	research_balance_text_value: String,
	offline_value: OfflineResearchViewModel,
	clinic_value: ClinicStatusViewModel,
	job_offer_values: Array
) -> PracticeScreenViewModel:
	var model := PracticeScreenViewModel.new()
	model._revision = maxi(0, revision_value)
	model._research_balance_text = research_balance_text_value
	model._offline = offline_value.duplicate_value() if offline_value != null else OfflineResearchViewModel.create("", "", "", 0, false)
	model._clinic = clinic_value.duplicate_value() if clinic_value != null else ClinicStatusViewModel.idle()
	for offer_value in job_offer_values:
		if offer_value is ClinicJobOfferViewModel:
			model._job_offers.append((offer_value as ClinicJobOfferViewModel).duplicate_value())
	model._job_offers_hash = hash(model._job_offer_signatures())
	model._content_hash = hash(model._content_signature())
	return model


func revision() -> int:
	return _revision


func content_hash() -> int:
	return _content_hash


func job_offers_hash() -> int:
	return _job_offers_hash


func research_balance_text() -> String:
	return _research_balance_text


func offline() -> OfflineResearchViewModel:
	return _offline.duplicate_value()


func clinic() -> ClinicStatusViewModel:
	return _clinic.duplicate_value()


func job_offers() -> Array[ClinicJobOfferViewModel]:
	var result: Array[ClinicJobOfferViewModel] = []
	for offer in _job_offers:
		result.append(offer.duplicate_value())
	return result


func job_offer_count() -> int:
	return _job_offers.size()


func job_offer_at(index: int) -> ClinicJobOfferViewModel:
	if index < 0 or index >= _job_offers.size():
		return null
	return _job_offers[index].duplicate_value()


func _content_signature() -> Array:
	return [
		_research_balance_text,
		_offline.content_signature(),
		_clinic.content_signature(),
		_job_offer_signatures(),
	]


func _job_offer_signatures() -> Array:
	var offer_signatures: Array = []
	for offer in _job_offers:
		offer_signatures.append(offer.content_signature())
	return offer_signatures
