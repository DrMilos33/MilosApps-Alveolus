class_name DiscoveryManager
extends RefCounted

signal seen_changed(id: StringName)

var definitions: Dictionary = {}
var seen_ids: Dictionary = {}
var queue: Array[Dictionary] = []
var active: Dictionary = {}

func configure(catalog: Dictionary, already_seen: Dictionary) -> void:
	definitions = catalog
	# Runtime queue ownership stays local. The integration layer persists newly
	# seen IDs through seen_changed instead of letting this helper mutate the
	# meta-save dictionary behind its signals.
	seen_ids = already_seen.duplicate()
	queue.clear()
	active.clear()

func request(id: StringName, target: Variant = null, context: Dictionary = {}) -> bool:
	if id == &"" or not definitions.has(id) or has_seen(id) or is_active(id) or is_queued(id):
		return false
	queue.append({"id": id, "target": target, "context": context})
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return definition(a["id"]).priority > definition(b["id"]).priority
	)
	return true

func take_next() -> Dictionary:
	if not active.is_empty() or queue.is_empty():
		return {}
	active = queue.pop_front()
	return active

func complete_active() -> StringName:
	if active.is_empty():
		return &""
	var id: StringName = active["id"]
	active.clear()
	mark_seen(id)
	return id

func mark_seen(id: StringName) -> void:
	if id == &"" or seen_ids.has(id):
		return
	seen_ids[id] = true
	queue = queue.filter(func(item: Dictionary) -> bool: return item["id"] != id)
	seen_changed.emit(id)

func has_seen(id: StringName) -> bool:
	return bool(seen_ids.get(id, false))

func is_queued(id: StringName) -> bool:
	for item in queue:
		if item["id"] == id:
			return true
	return false

func is_active(id: StringName) -> bool:
	return not active.is_empty() and active["id"] == id

func definition(id: StringName) -> DiscoveryDefinition:
	return definitions.get(id) as DiscoveryDefinition

func clear_pending() -> void:
	queue.clear()
	active.clear()
