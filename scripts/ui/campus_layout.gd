@tool
class_name CampusLayout
extends Control

const CampusStaffComponent = preload("res://scripts/ui/campus_staff_sprite.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		return
	_spawn_staff_from_markers()


func _spawn_staff_from_markers() -> void:
	var runtime_staff := get_node_or_null("RuntimeStaff") as Control
	var routes := get_node_or_null("StaffMarkers")
	if runtime_staff == null or routes == null:
		return
	for route in routes.get_children():
		var start_marker := route.get_node_or_null("Start") as Marker2D
		var end_marker := route.get_node_or_null("End") as Marker2D
		if start_marker == null or end_marker == null:
			continue
		var staff = CampusStaffComponent.new()
		var route_origin: Vector2 = route.position
		staff.configure(
			route_origin + start_marker.position,
			route_origin + end_marker.position,
			float(route.get_meta("phase", 0.0)),
			float(route.get_meta("speed", 0.08))
		)
		runtime_staff.add_child(staff)
