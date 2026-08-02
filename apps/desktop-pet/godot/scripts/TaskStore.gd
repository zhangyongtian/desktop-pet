class_name TaskStore
extends Node

signal changed

const SAVE_DIR := "user://tasks"
const SAVE_PATH := SAVE_DIR + "/tasks.json"

const STATUS_TODO := "todo"
const STATUS_DONE := "done"
const STATUS_ARCHIVED := "archived"

var _tasks: Array[Dictionary] = []
var _memory_store: MemoryStore = null


func _ready() -> void:
	load_from_disk()


func set_memory_store(store: MemoryStore) -> void:
	_memory_store = store


func get_all_tasks() -> Array[Dictionary]:
	return _tasks.duplicate(true)


func add_task(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return {}

	var now_ms := Time.get_unix_time_from_system() * 1000
	var task := {
		"id": _make_id(),
		"text": trimmed,
		"status": STATUS_TODO,
		"created_at": now_ms,
		"updated_at": now_ms,
	}
	_tasks.append(task)
	save_to_disk()
	_emit_task_event("create", task)
	changed.emit()
	return task


func set_done(task_id: String, done: bool) -> void:
	var idx := _find_task_index(task_id)
	if idx < 0:
		return

	var task := _tasks[idx]
	if task.get("status", STATUS_TODO) == STATUS_ARCHIVED:
		return

	var now_ms := Time.get_unix_time_from_system() * 1000
	task["updated_at"] = now_ms

	if done:
		task["status"] = STATUS_DONE
		task["done_at"] = now_ms
		_emit_task_event("done", task)
	else:
		task["status"] = STATUS_TODO
		task.erase("done_at")
		_emit_task_event("undone", task)

	_tasks[idx] = task
	save_to_disk()
	changed.emit()


func archive(task_id: String) -> void:
	var idx := _find_task_index(task_id)
	if idx < 0:
		return

	var task := _tasks[idx]
	if task.get("status", STATUS_TODO) != STATUS_DONE:
		return

	var now_ms := Time.get_unix_time_from_system() * 1000
	task["status"] = STATUS_ARCHIVED
	task["updated_at"] = now_ms
	task["archived_at"] = now_ms
	_tasks[idx] = task
	save_to_disk()
	_emit_task_event("archive", task)
	changed.emit()


func unarchive(task_id: String) -> void:
	var idx := _find_task_index(task_id)
	if idx < 0:
		return

	var task := _tasks[idx]
	if task.get("status", STATUS_TODO) != STATUS_ARCHIVED:
		return

	var now_ms := Time.get_unix_time_from_system() * 1000
	task["status"] = STATUS_DONE
	task["updated_at"] = now_ms
	task.erase("archived_at")
	_tasks[idx] = task
	save_to_disk()
	_emit_task_event("unarchive", task)
	changed.emit()


func load_from_disk() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if not FileAccess.file_exists(SAVE_PATH):
		_tasks = []
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_tasks = []
		return

	var content := file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		_tasks = []
		return

	var parsed := JSON.parse_string(content)
	if parsed == null:
		_tasks = []
		return

	var data_array: Array = []
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("tasks") and typeof(parsed["tasks"]) == TYPE_ARRAY:
		data_array = parsed["tasks"]
	elif typeof(parsed) == TYPE_ARRAY:
		data_array = parsed

	var out: Array[Dictionary] = []
	for item in data_array:
		if typeof(item) == TYPE_DICTIONARY and item.has("id") and item.has("text"):
			out.append(item)
	_tasks = out


func save_to_disk() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := {
		"version": 1,
		"tasks": _tasks,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("TaskStore: cannot write file: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.flush()
	file.close()


func _emit_task_event(action: String, task: Dictionary) -> void:
	if _memory_store == null:
		return
	_memory_store.add_event(
		"task",
		String(task.get("text", "")),
		{
			"action": action,
			"task_id": String(task.get("id", "")),
			"status": String(task.get("status", "")),
		}
	)


func _find_task_index(task_id: String) -> int:
	for i in range(_tasks.size()):
		if String(_tasks[i].get("id", "")) == task_id:
			return i
	return -1


func _make_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%d_%d" % [Time.get_unix_time_from_system(), rng.randi()]
