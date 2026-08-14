class_name ClinicJobDefinition
extends Resource

@export var id: StringName
@export var title: String
@export var duration_seconds: int
@export var reward: int

static func create(job_id: StringName, display_title: String, duration: int, research_reward: int) -> ClinicJobDefinition:
	var definition := ClinicJobDefinition.new()
	definition.id = job_id
	definition.title = display_title
	definition.duration_seconds = duration
	definition.reward = research_reward
	return definition

func duration_text() -> String:
	if duration_seconds < 3600:
		return "%d Min." % (duration_seconds / 60)
	return "%d Std." % (duration_seconds / 3600)

