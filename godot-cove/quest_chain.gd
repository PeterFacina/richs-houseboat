extends RefCounted

enum Status { AVAILABLE, IN_PROGRESS, READY, FINISHED }


static func current(state: Dictionary, quests: Array) -> Dictionary:
	var index := int(state.get("step", 0))
	return quests[index] if index >= 0 and index < quests.size() else {}


static func status(state: Dictionary, quests: Array) -> Status:
	var quest := current(state, quests)
	if quest.is_empty():
		return Status.FINISHED
	if not state.get("accepted", false):
		return Status.AVAILABLE
	return Status.READY if float(state.get("progress", 0.0)) >= quest.target else Status.IN_PROGRESS


static func accept(state: Dictionary, quests: Array, quest_id: String) -> bool:
	if status(state, quests) != Status.AVAILABLE or current(state, quests).id != quest_id:
		return false
	state.accepted = true
	return true


static func credit(state: Dictionary, quests: Array, quest_id: String, amount: float) -> bool:
	if amount <= 0.0 or not is_finite(amount) or status(state, quests) != Status.IN_PROGRESS:
		return false
	var quest := current(state, quests)
	if quest.id != quest_id:
		return false
	state.progress = minf(quest.target, float(state.progress) + amount)
	return true


static func complete(state: Dictionary, quests: Array, quest_id: String) -> bool:
	if status(state, quests) != Status.READY or current(state, quests).id != quest_id:
		return false
	state.step = int(state.step) + 1
	state.accepted = false
	state.progress = 0.0
	return true
