class_name ReportGenerator
extends Node

var _memory: MemoryStore = null
var _config: ConfigStore = null
var _client: DeepSeekClient = null


func setup(memory_store: MemoryStore, config_store: ConfigStore, client: DeepSeekClient) -> void:
	_memory = memory_store
	_config = config_store
	_client = client


func generate(kind: String) -> Dictionary:
	var now_s := Time.get_unix_time_from_system()
	var until_ms := int(now_s * 1000)
	var since_ms := until_ms
	var title := ""

	match kind:
		"daily":
			since_ms = until_ms - 86400 * 1000
			title = "日报"
		"weekly":
			since_ms = until_ms - 86400 * 7 * 1000
			title = "周报"
		"monthly":
			since_ms = until_ms - 86400 * 30 * 1000
			title = "月报"
		"semiannual":
			since_ms = until_ms - 86400 * 183 * 1000
			title = "半年报"
		_:
			return {"ok": false, "error": "unknown_kind"}

	return await generate_for_range(title, since_ms, until_ms)


func generate_for_range(title: String, since_ms: int, until_ms: int) -> Dictionary:
	if _memory == null or _config == null or _client == null:
		return {"ok": false, "error": "not_configured"}

	var items := _memory.get_essence()
	var picked: Array[Dictionary] = []
	for it in items:
		var ts := int(it.get("timestamp", 0))
		if ts >= since_ms and ts <= until_ms:
			picked.append(it)

	if picked.is_empty():
		return {"ok": true, "content": "%s：该时间范围内没有精华条目。" % title, "empty": true}

	var input := _format_essence_items(picked)
	var user_prompt := "%s\n时间范围：%d ~ %d\n\n材料如下：\n%s" % [title, since_ms, until_ms, input]

	var messages: Array[Dictionary] = [
		{"role": "system", "content": _config.get_report_system_prompt()},
		{"role": "user", "content": user_prompt},
	]
	var r := await _client.chat_complete(messages, 0.2, 900)
	if not bool(r.get("ok", false)):
		return r
	return {"ok": true, "content": String(r.get("content", ""))}


func _format_essence_items(items: Array[Dictionary]) -> String:
	var lines: PackedStringArray = []
	for it in items:
		var ts := int(it.get("timestamp", 0))
		var s := String(it.get("summary", "")).strip_edges()
		if s.is_empty():
			continue
		lines.append("- [%d] %s" % [ts, s])
	return "\n".join(lines)
