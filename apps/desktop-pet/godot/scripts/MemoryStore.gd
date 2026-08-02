class_name MemoryStore
extends Node

signal event_appended(event: Dictionary)

const BASE_DIR := "user://memory"
const EVENTS_PATH := BASE_DIR + "/events.jsonl"
const RAW_BUFFER_PATH := BASE_DIR + "/raw_buffer.json"
const ESSENCE_PATH := BASE_DIR + "/essence.json"

@export var raw_buffer_max_events: int = 200

var _raw_buffer: Array[Dictionary] = []
var _essence: Array[Dictionary] = []


func _ready() -> void:
	_ensure_dirs()
	_raw_buffer = _load_json_array(RAW_BUFFER_PATH)
	_essence = _load_json_array(ESSENCE_PATH)


func add_event(source: String, text: String, metadata: Dictionary = {}) -> Dictionary:
	var event := {
		"timestamp": Time.get_unix_time_from_system() * 1000,
		"source": source,
		"text": text,
	}
	if not metadata.is_empty():
		event["metadata"] = metadata
	append_event(event)
	return event


func append_event(event: Dictionary) -> void:
	_ensure_dirs()
	_append_jsonl_line(EVENTS_PATH, event)
	_push_raw_buffer(event)
	_save_json_array(RAW_BUFFER_PATH, _raw_buffer)
	event_appended.emit(event)


func get_raw_buffer() -> Array[Dictionary]:
	return _raw_buffer.duplicate(true)


func replace_raw_buffer(events: Array[Dictionary]) -> void:
	_raw_buffer = events.duplicate(true)
	_save_json_array(RAW_BUFFER_PATH, _raw_buffer)


func clear_raw_buffer() -> void:
	_raw_buffer = []
	_save_json_array(RAW_BUFFER_PATH, _raw_buffer)


func add_essence(summary: String, metadata: Dictionary = {}) -> Dictionary:
	_ensure_dirs()
	var item := {
		"timestamp": Time.get_unix_time_from_system() * 1000,
		"summary": summary,
	}
	if not metadata.is_empty():
		item["metadata"] = metadata
	_essence.append(item)
	_save_json_array(ESSENCE_PATH, _essence)
	return item


func get_essence() -> Array[Dictionary]:
	return _essence.duplicate(true)


func _push_raw_buffer(event: Dictionary) -> void:
	_raw_buffer.append(event)
	if _raw_buffer.size() > raw_buffer_max_events:
		_raw_buffer = _raw_buffer.slice(_raw_buffer.size() - raw_buffer_max_events, _raw_buffer.size())


func _ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(BASE_DIR)


func _append_jsonl_line(path: String, data: Dictionary) -> void:
	var json_line := JSON.stringify(data)
	var file: FileAccess = null

	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.close()
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()

	if file == null:
		push_error("MemoryStore: cannot open file for append: %s" % path)
		return

	file.store_line(json_line)
	file.flush()
	file.close()


func _load_json_array(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []

	var content := file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		return []

	var parsed := JSON.parse_string(content)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		return []

	var out: Array[Dictionary] = []
	for item in parsed:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	return out


func _save_json_array(path: String, data: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("MemoryStore: cannot write file: %s" % path)
		return

	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	file.close()
