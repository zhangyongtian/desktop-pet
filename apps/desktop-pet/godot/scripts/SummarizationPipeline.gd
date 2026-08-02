class_name SummarizationPipeline
extends Node

signal run_finished(result: Dictionary)

@export var trigger_min_chars: int = 2500
@export var check_interval_seconds: float = 8.0
@export var cooldown_seconds: float = 90.0
@export var chunk_max_chars: int = 1800
@export var segment_max_tokens: int = 420
@export var merge_max_tokens: int = 520

var _memory: MemoryStore = null
var _config: ConfigStore = null
var _client: DeepSeekClient = null
var _last_run_ms: int = 0
var _timer: Timer = null
var _running: bool = false


func setup(memory_store: MemoryStore, config_store: ConfigStore, client: DeepSeekClient) -> void:
	_memory = memory_store
	_config = config_store
	_client = client


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = check_interval_seconds
	add_child(_timer)
	_timer.timeout.connect(func() -> void:
		await run_if_needed(false)
	)
	_timer.start()


func run_if_needed(force: bool) -> Dictionary:
	if _running:
		return {"ok": false, "error": "running"}
	if _memory == null or _config == null or _client == null:
		return {"ok": false, "error": "not_configured"}

	if _config.get_api_key().strip_edges().is_empty():
		return {"ok": true, "skipped": true, "reason": "missing_api_key"}
	if _config.get_endpoint().strip_edges().is_empty():
		return {"ok": true, "skipped": true, "reason": "missing_endpoint"}
	if _config.get_model().strip_edges().is_empty():
		return {"ok": true, "skipped": true, "reason": "missing_model"}

	var now_ms := Time.get_unix_time_from_system() * 1000
	if not force:
		if _last_run_ms > 0 and now_ms - _last_run_ms < int(cooldown_seconds * 1000.0):
			return {"ok": true, "skipped": true, "reason": "cooldown"}

	var raw := _memory.get_raw_buffer()
	if raw.is_empty():
		return {"ok": true, "skipped": true, "reason": "no_raw"}

	var raw_text := _format_raw_events(raw)
	if raw_text.length() < trigger_min_chars and not force:
		return {"ok": true, "skipped": true, "reason": "below_threshold", "chars": raw_text.length()}

	_running = true
	var result := await _run_pipeline(raw, raw_text)
	_running = false
	run_finished.emit(result)
	return result


func _run_pipeline(raw_events: Array[Dictionary], raw_text: String) -> Dictionary:
	var segments := _chunk_text(raw_text, chunk_max_chars)
	var segment_summaries: Array[String] = []
	for seg in segments:
		var r := await _summarize_segment(seg)
		if not bool(r.get("ok", false)):
			return r
		segment_summaries.append(String(r.get("content", "")))

	var merged := ""
	if segment_summaries.size() == 1:
		merged = segment_summaries[0]
	else:
		var merge_input := ""
		for i in range(segment_summaries.size()):
			merge_input += "【段%d】\n%s\n\n" % [i + 1, segment_summaries[i]]
		var r2 := await _merge_summaries(merge_input.strip_edges())
		if not bool(r2.get("ok", false)):
			return r2
		merged = String(r2.get("content", ""))

	var meta := {
		"kind": "essence",
		"raw_events": raw_events.size(),
		"raw_chars": raw_text.length(),
		"segments": segments.size(),
	}
	_memory.add_essence(merged.strip_edges(), meta)
	_memory.clear_raw_buffer()
	_last_run_ms = Time.get_unix_time_from_system() * 1000
	return {"ok": true, "content": merged}


func _summarize_segment(text: String) -> Dictionary:
	var messages: Array[Dictionary] = [
		{"role": "system", "content": _config.get_summarize_system_prompt()},
		{"role": "user", "content": text},
	]
	return await _client.chat_complete(messages, 0.2, segment_max_tokens)


func _merge_summaries(text: String) -> Dictionary:
	var messages: Array[Dictionary] = [
		{"role": "system", "content": _config.get_merge_system_prompt()},
		{"role": "user", "content": text},
	]
	return await _client.chat_complete(messages, 0.2, merge_max_tokens)


func _format_raw_events(raw_events: Array[Dictionary]) -> String:
	var lines: PackedStringArray = []
	for e in raw_events:
		var ts := int(e.get("timestamp", 0))
		var src := String(e.get("source", ""))
		var txt := String(e.get("text", "")).strip_edges()
		if txt.is_empty():
			continue
		lines.append("[%d][%s] %s" % [ts, src, txt])
	return "\n".join(lines)


func _chunk_text(text: String, max_chars: int) -> Array[String]:
	var out: Array[String] = []
	var buf := ""
	for line in text.split("\n", false):
		var add := line + "\n"
		if buf.length() + add.length() > max_chars and not buf.is_empty():
			out.append(buf.strip_edges())
			buf = ""
		buf += add
	if not buf.strip_edges().is_empty():
		out.append(buf.strip_edges())
	return out
