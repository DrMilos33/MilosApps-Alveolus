extends SceneTree

const CampusSceneComponent = preload("res://scripts/ui/campus_scene.gd")
const LayoutScene = preload("res://scenes/ui/campus_layout.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var layout := LayoutScene.instantiate() as Control
	if layout == null:
		_fail("layout could not be instantiated")
		return
	var slots := layout.get_node_or_null("BuildingSlots") as Control
	if slots == null:
		_fail("missing shared building slot layer")
		return
	if layout.get_node_or_null("EnvironmentBackdrop") == null:
		_fail("campus environment backdrop is missing")
		return
	if layout.get_node_or_null("RuntimeStaff") != null or layout.get_node_or_null("StaffMarkers") != null:
		_fail("campus still contains the retired walking doctor layer")
		return
	for id in [&"practice", &"research", &"levels", &"lexicon", &"settings"]:
		var slot := layout.get_node_or_null("BuildingSlots/%s" % id) as Control
		if slot == null:
			_fail("missing editor building slot: %s" % id)
			return
		var expected := slots.position + slot.position + Vector2(slot.size.x * 0.5, slot.size.y)
		if not CampusSceneComponent.building_anchor(id).is_equal_approx(expected):
			_fail("runtime anchor differs from editor slot: %s" % id)
			return
		var card_top := expected.y - slot.size.y
		if card_top < 112.0:
			_fail("building violates the 92 px header plus 20 px safe gap: %s" % id)
			return
	if slots.position.y < 40.0:
		_fail("campus world was not lowered into the available canvas")
		return
	layout.free()
	var host := CampusSceneComponent.new()
	get_root().add_child(host)
	await process_frame
	if host.get_child_count() != 1:
		_fail("campus runtime host did not instantiate exactly one layout")
		return
	var runtime_layout := host.get_child(0)
	if runtime_layout.get_node_or_null("RuntimeStaff") != null or runtime_layout.get_node_or_null("StaffMarkers") != null:
		_fail("campus runtime recreated walking doctors")
		return
	host.queue_free()
	print("ALVEOLUS_CAMPUS_LAYOUT_OK")
	quit(0)


func _fail(message: String) -> void:
	printerr("ALVEOLUS_CAMPUS_LAYOUT_FAILED: %s" % message)
	quit(1)
