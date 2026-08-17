class_name FindingController
extends RefCounted

signal progress_changed(current: int, target: int)
signal finding_revealed(definition: FindingDefinition)
signal reaction_applied(definition: ReactionDefinition)

var definition: FindingDefinition
var target: int = 0
var progress: int = 0
var revealed: bool = false
var resolved: bool = false
var selected_reaction_id: StringName = &""

func configure(finding: FindingDefinition, required_progress: int) -> void:
	definition = finding
	target = maxi(1, required_progress)
	progress = 0
	revealed = false
	resolved = false
	selected_reaction_id = &""
	progress_changed.emit(progress, target)

func add_progress(amount: int, multiplier: float = 1.0) -> bool:
	if definition == null or revealed or amount <= 0:
		return false
	progress = mini(target, progress + maxi(0, roundi(float(amount) * maxf(multiplier, 0.0))))
	progress_changed.emit(progress, target)
	if progress >= target:
		revealed = true
		finding_revealed.emit(definition)
		return true
	return false

func resolve(reaction: ReactionDefinition) -> bool:
	if not revealed or resolved or reaction == null or reaction.finding_id != definition.id:
		return false
	resolved = true
	selected_reaction_id = reaction.id
	reaction_applied.emit(reaction)
	return true

func fraction() -> float:
	return clampf(float(progress) / float(maxi(target, 1)), 0.0, 1.0)
