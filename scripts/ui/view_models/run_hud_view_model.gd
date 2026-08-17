class_name RunHUDViewModel
extends RefCounted

## Immutable, presentation-ready snapshot for the run HUD chrome.
##
## The presenter owns clocks, cooldown progression and all gameplay decisions.
## This model copies only stable IDs and primitive values; no run/domain object
## crosses into the screen module.

class StatValueViewModel:
	extends RefCounted

	var _id: StringName
	var _icon_id: StringName
	var _formatted_value: String
	var _accessible_name: String
	var _priority: int

	func _init(
		id_value: StringName,
		icon_value: StringName,
		formatted_value: String,
		accessible_value: String,
		priority_value: int
	) -> void:
		_id = id_value
		_icon_id = icon_value
		_formatted_value = formatted_value
		_accessible_name = accessible_value
		_priority = priority_value

	func id() -> StringName:
		return _id

	func icon_id() -> StringName:
		return _icon_id

	func formatted_value() -> String:
		return _formatted_value

	func accessible_name() -> String:
		return _accessible_name

	func priority() -> int:
		return _priority


class AbilitySlotViewModel:
	extends RefCounted

	var _slot: int
	var _title: String
	var _icon_id: StringName
	var _effect_text: String
	var _occupied: bool
	var _ready: bool
	var _cooldown_remaining: float
	var _cooldown_total: float
	var _targeting: bool
	var _key_glyph_text: String

	func _init(
		slot_value: int,
		title_value: String,
		icon_value: StringName,
		effect_value: String,
		occupied_value: bool,
		ready_value: bool,
		remaining_value: float,
		total_value: float,
		targeting_value: bool,
		glyph_value: String
	) -> void:
		_slot = slot_value
		_title = title_value
		_icon_id = icon_value
		_effect_text = effect_value
		_occupied = occupied_value
		_ready = ready_value and occupied_value
		_cooldown_remaining = maxf(0.0, remaining_value)
		_cooldown_total = maxf(0.0, total_value)
		_targeting = targeting_value and occupied_value
		_key_glyph_text = glyph_value

	func slot() -> int:
		return _slot

	func title() -> String:
		return _title

	func icon_id() -> StringName:
		return _icon_id

	func effect_text() -> String:
		return _effect_text

	func occupied() -> bool:
		return _occupied

	func ready() -> bool:
		return _ready

	func cooldown_remaining() -> float:
		return _cooldown_remaining

	func cooldown_total() -> float:
		return _cooldown_total

	func targeting() -> bool:
		return _targeting

	func key_glyph_text() -> String:
		return _key_glyph_text

	func cooldown_progress() -> float:
		if not _occupied:
			return 0.0
		if _ready or _cooldown_total <= 0.001:
			return 1.0
		return clampf(1.0 - _cooldown_remaining / _cooldown_total, 0.0, 1.0)

	func status_text() -> String:
		if not _occupied:
			return "Nicht belegt"
		if _targeting:
			return "Ziel wählen"
		if _ready:
			return "Bereit"
		return "%.1f s" % _cooldown_remaining


var _stability_current := 0.0
var _stability_maximum := 1.0
var _shield_current := 0.0
var _shield_maximum := 0.0
var _timer_text := "00:00"
var _timer_tone: StringName = &"neutral"
var _boss_visible := false
var _boss_title := "Infektionsherd"
var _boss_current := 0.0
var _boss_maximum := 1.0
var _boss_phase_text := ""
var _analysis_current := 0
var _analysis_target := 0
var _analysis_level := 0
var _stats: Array[StatValueViewModel] = []
var _abilities: Array[AbilitySlotViewModel] = []
var _revision := 0
var _content_hash := ""


## Vital snapshot keys:
## stability_current/maximum, shield_current/maximum, timer_text/tone,
## boss_visible/title/current/maximum/phase, analysis_current/target/level.
## Stat rows accept id, icon_id, value, accessible_name and priority.
## Ability rows accept slot (0/1), title, icon_id, occupied, ready,
## effect_text, cooldown_remaining/total, targeting and key_glyph_text.
static func create(
	vital_snapshot: Dictionary,
	stat_rows: Array,
	ability_rows: Array,
	revision_value: int = 0
) -> RunHUDViewModel:
	var result := RunHUDViewModel.new()
	var vital: Dictionary = vital_snapshot.duplicate(true)
	result._revision = maxi(0, revision_value)
	result._stability_maximum = maxf(1.0, float(vital.get("stability_maximum", 1.0)))
	result._stability_current = clampf(
		float(vital.get("stability_current", 0.0)),
		0.0,
		result._stability_maximum
	)
	result._shield_maximum = maxf(0.0, float(vital.get("shield_maximum", 0.0)))
	result._shield_current = clampf(
		float(vital.get("shield_current", 0.0)),
		0.0,
		result._shield_maximum
	)
	result._timer_text = String(vital.get("timer_text", "00:00")).strip_edges()
	if result._timer_text.is_empty():
		result._timer_text = "00:00"
	result._timer_tone = StringName(String(vital.get("timer_tone", "neutral")))
	if result._timer_tone not in [&"neutral", &"attention", &"danger"]:
		result._timer_tone = &"neutral"
	result._boss_visible = bool(vital.get("boss_visible", false))
	result._boss_title = String(vital.get("boss_title", "Infektionsherd")).strip_edges()
	if result._boss_title.is_empty():
		result._boss_title = "Infektionsherd"
	result._boss_maximum = maxf(1.0, float(vital.get("boss_maximum", 1.0)))
	result._boss_current = clampf(float(vital.get("boss_current", 0.0)), 0.0, result._boss_maximum)
	result._boss_phase_text = String(vital.get("boss_phase", "")).strip_edges()
	result._analysis_target = maxi(0, int(vital.get("analysis_target", 0)))
	result._analysis_current = clampi(
		int(vital.get("analysis_current", 0)),
		0,
		result._analysis_target
	)
	result._analysis_level = maxi(0, int(vital.get("analysis_level", 0)))
	result._copy_stats(stat_rows)
	result._copy_abilities(ability_rows)
	result._content_hash = result._calculate_content_hash()
	return result


func revision() -> int:
	return _revision


func content_hash() -> String:
	return _content_hash


func is_valid() -> bool:
	return _abilities.size() == 2 and _stability_maximum > 0.0


func stability_current() -> float:
	return _stability_current


func stability_maximum() -> float:
	return _stability_maximum


func stability_text() -> String:
	return "%d / %d" % [roundi(_stability_current), roundi(_stability_maximum)]


func shield_current() -> float:
	return _shield_current


func shield_maximum() -> float:
	return _shield_maximum


func shield_text() -> String:
	return "%d" % ceili(_shield_current)


func timer_text() -> String:
	return _timer_text


func timer_tone() -> StringName:
	return _timer_tone


func boss_visible() -> bool:
	return _boss_visible


func boss_title() -> String:
	return _boss_title


func boss_current() -> float:
	return _boss_current


func boss_maximum() -> float:
	return _boss_maximum


func boss_phase_text() -> String:
	return _boss_phase_text


func boss_percentage_text() -> String:
	return "%d %%" % roundi(100.0 * _boss_current / _boss_maximum)


func analysis_current() -> int:
	return _analysis_current


func analysis_target() -> int:
	return _analysis_target


func analysis_level() -> int:
	return _analysis_level


func analysis_text() -> String:
	return "Lv %d · %d/%d" % [_analysis_level, _analysis_current, _analysis_target]


func stat_count() -> int:
	return _stats.size()


func stat_at(index_value: int) -> StatValueViewModel:
	if index_value < 0 or index_value >= _stats.size():
		return null
	return _stats[index_value]


func stats() -> Array[StatValueViewModel]:
	var result: Array[StatValueViewModel] = []
	result.assign(_stats)
	return result


func ability_count() -> int:
	return _abilities.size()


func ability_at(slot_value: int) -> AbilitySlotViewModel:
	if slot_value < 0 or slot_value >= _abilities.size():
		return null
	return _abilities[slot_value]


func abilities() -> Array[AbilitySlotViewModel]:
	var result: Array[AbilitySlotViewModel] = []
	result.assign(_abilities)
	return result


func _copy_stats(source_rows: Array) -> void:
	var copied_rows: Array = source_rows.duplicate(true)
	var seen_ids: Dictionary = {}
	for row_value in copied_rows:
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		var stat_id := StringName(String(row.get("id", "")))
		var value_text := String(row.get("value", "")).strip_edges()
		if stat_id == &"" or value_text.is_empty() or seen_ids.has(stat_id):
			continue
		seen_ids[stat_id] = true
		var icon_id := StringName(String(row.get("icon_id", "information")))
		if icon_id == &"":
			icon_id = &"information"
		var accessible := String(row.get("accessible_name", String(stat_id))).strip_edges()
		if accessible.is_empty():
			accessible = String(stat_id)
		_stats.append(StatValueViewModel.new(
			stat_id,
			icon_id,
			value_text,
			accessible,
			int(row.get("priority", 0))
		))
	_stats.sort_custom(func(a: StatValueViewModel, b: StatValueViewModel) -> bool:
		if a.priority() == b.priority():
			return String(a.id()) < String(b.id())
		return a.priority() > b.priority()
	)


func _copy_abilities(source_rows: Array) -> void:
	var copied_rows: Array = source_rows.duplicate(true)
	var rows_by_slot: Dictionary = {}
	for row_value in copied_rows:
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		var slot_value := int(row.get("slot", -1))
		if slot_value < 0 or slot_value > 1 or rows_by_slot.has(slot_value):
			continue
		rows_by_slot[slot_value] = row
	for slot_value in range(2):
		var row: Dictionary = rows_by_slot.get(slot_value, {})
		var title_value := String(row.get("title", "")).strip_edges()
		var occupied_value := bool(row.get("occupied", not title_value.is_empty()))
		if not occupied_value or title_value.is_empty():
			title_value = "Nicht belegt"
			occupied_value = false
		var icon_value := StringName(String(row.get("icon_id", "ability")))
		if icon_value == &"":
			icon_value = &"ability"
		var effect_value := String(row.get(
			"effect_text",
			row.get("description", row.get("effect", ""))
		)).strip_edges()
		if not occupied_value:
			effect_value = ""
		var glyph_default := "Q" if slot_value == 0 else "E"
		var glyph_value := String(row.get("key_glyph_text", glyph_default)).strip_edges()
		if glyph_value.is_empty():
			glyph_value = glyph_default
		_abilities.append(AbilitySlotViewModel.new(
			slot_value,
			title_value,
			icon_value,
			effect_value,
			occupied_value,
			bool(row.get("ready", false)),
			float(row.get("cooldown_remaining", 0.0)),
			float(row.get("cooldown_total", 0.0)),
			bool(row.get("targeting", false)),
			glyph_value
		))


func _calculate_content_hash() -> String:
	var canonical := PackedStringArray([
		_float_key(_stability_current),
		_float_key(_stability_maximum),
		_float_key(_shield_current),
		_float_key(_shield_maximum),
		_length_prefixed(_timer_text),
		_length_prefixed(String(_timer_tone)),
		"1" if _boss_visible else "0",
		_length_prefixed(_boss_title),
		_float_key(_boss_current),
		_float_key(_boss_maximum),
		_length_prefixed(_boss_phase_text),
		str(_analysis_current),
		str(_analysis_target),
		str(_analysis_level),
	])
	for stat in _stats:
		canonical.append(_length_prefixed(String(stat.id())))
		canonical.append(_length_prefixed(String(stat.icon_id())))
		canonical.append(_length_prefixed(stat.formatted_value()))
		canonical.append(_length_prefixed(stat.accessible_name()))
		canonical.append(str(stat.priority()))
	for ability in _abilities:
		canonical.append(str(ability.slot()))
		canonical.append(_length_prefixed(ability.title()))
		canonical.append(_length_prefixed(String(ability.icon_id())))
		canonical.append(_length_prefixed(ability.effect_text()))
		canonical.append("1" if ability.occupied() else "0")
		canonical.append("1" if ability.ready() else "0")
		canonical.append(_float_key(ability.cooldown_remaining()))
		canonical.append(_float_key(ability.cooldown_total()))
		canonical.append("1" if ability.targeting() else "0")
		canonical.append(_length_prefixed(ability.key_glyph_text()))
	return "|".join(canonical).sha256_text()


func _float_key(value: float) -> String:
	return String.num(value, 4)


func _length_prefixed(value: String) -> String:
	return "%d:%s" % [value.length(), value]
