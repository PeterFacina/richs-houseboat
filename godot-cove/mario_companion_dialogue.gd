extends RefCounted

## Offline-first boundary for Mario's future companion model.
## Providers may return display text only; they cannot invoke game actions or mutate saves.
const MAX_OUTPUT_CHARS := 480
const MAX_MEMORY_ITEMS := 8

const AUTHORED := {
	"greeting": "Rich put us in touch because you know boats. His old outboard is reliable; I think we can build something quieter and more efficient. We should measure it, not argue about it.",
	"parts": "Good. A battery, controller and motor are enough for a first bench assembly. We will leave the complicated fabrication for later.",
	"test": "Take it out on the river and keep the first run short. Watch the current draw. If it climbs, back off the throttle and bring the prototype home.",
	"low_battery": "The pack is dropping faster than the model predicted. Ease off now; we have enough data for today.",
	"complete": "The test is over and the prototype is safe. The endurance is poor, but now we know where to improve it. Rich can keep his old motor for one more race.",
}


func context(location: String, quest_stage: String, nearby_objects: Array[String], memory: Array[String]) -> Dictionary:
	var safe_memory: Array[String] = []
	for item in memory.slice(maxi(0, memory.size() - MAX_MEMORY_ITEMS)):
		if item is String:
			safe_memory.append(_clean(item, 100))
	return {
		"persona": "Mario is serious, practical and fact-driven. He likes science and health, dislikes politics, and speaks natural English. Never caricature his Romanian background or invent biography.",
		"location": _clean(location, 80),
		"quest_stage": _clean(quest_stage, 80),
		"nearby_objects": nearby_objects.slice(0, 12).map(func(value: String) -> String: return _clean(value, 48)),
		"shared_memory": safe_memory,
		"allowed_output": "One short, player-facing dialogue string only. No code, commands, quest changes, rewards, medical advice or requests for secrets.",
	}


func authored(key: String) -> String:
	return str(AUTHORED.get(key, AUTHORED.greeting))


func remember(quest_state: Dictionary, event: String) -> void:
	var memory: Array = quest_state.get("companion_memory", [])
	memory.append(_clean(event, 120))
	quest_state.companion_memory = memory.slice(maxi(0, memory.size() - MAX_MEMORY_ITEMS))


func accept_provider_text(value: Variant) -> String:
	if not value is String:
		return ""
	var result := _clean(value, MAX_OUTPUT_CHARS)
	if result.is_empty() or result.contains("```") or result.contains("/save") or result.contains("quest="):
		return ""
	return result


func _clean(value: String, maximum: int) -> String:
	var result := value.strip_edges().replace("\u0000", " ")
	result = result.replace("\r", " ").replace("\n", " ")
	while result.contains("  "):
		result = result.replace("  ", " ")
	return result.left(maximum)
