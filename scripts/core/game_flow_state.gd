class_name GameFlowState
extends RefCounted

enum State {
	CAMPUS,
	PRACTICE,
	RESEARCH,
	LEVEL_SELECT,
	LEXICON,
	STORY,
	SETTINGS,
	BRIEFING,
	RUNNING,
	DISCOVERY_PAUSE,
	LEVEL_UP,
	MANUAL_PAUSE,
	ABORT_CONFIRMATION,
	INTRO_SKIP_CONFIRMATION,
	RESULT
}

static func pauses_simulation(state: State) -> bool:
	return state != State.RUNNING
