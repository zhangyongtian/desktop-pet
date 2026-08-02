class_name HelperBridge
extends Node

@export var base_url: String = "http://127.0.0.1:28999"
@export var poll_interval_sec: float = 0.5

signal availability_changed(available: bool, detail: String)

var _memory_store: MemoryStore = null
var _poll_timer: Timer = null
var _probe_timer: Timer = null
var _events_req: HTTPRequest = null
var _control_req: HTTPRequest = null
var _health_req: HTTPRequest = null
var _events_in_flight := false
var _control_in_flight := false
var _health_in_flight := false
var _user_paused := false
var _auto_paused := false
var _desired_paused := false
var _last_sent_paused: Variant = null
var _pending_shutdown := false
var _shutdown_sent := false
var _control_action_in_flight := ""

var _available := false
var _availability_detail := "未连接"
var _helper_pid: int = -1
var _start_attempts: int = 0
var _probe_attempts: int = 0


func setup(memory_store: MemoryStore) -> void:
	_memory_store = memory_store


func _ready() -> void:
	_events_req = HTTPRequest.new()
	add_child(_events_req)
	_events_req.request_completed.connect(_on_events_completed)

	_control_req = HTTPRequest.new()
	add_child(_control_req)
	_control_req.request_completed.connect(_on_control_completed)

	_health_req = HTTPRequest.new()
	add_child(_health_req)
	_health_req.request_completed.connect(_on_health_completed)

	_poll_timer = Timer.new()
	_poll_timer.one_shot = false
	_poll_timer.wait_time = poll_interval_sec
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_poll)

	_probe_timer = Timer.new()
	_probe_timer.one_shot = false
	_probe_timer.wait_time = 0.5
	add_child(_probe_timer)
	_probe_timer.timeout.connect(_probe_health)
	_probe_timer.start()

	_set_availability(false, "正在探活 helper…")


func set_paused(paused: bool) -> void:
	set_auto_paused(paused)


func set_user_paused(paused: bool) -> void:
	var changed := paused != _user_paused
	_user_paused = paused
	if changed and _memory_store != null:
		_memory_store.add_event("helper_control", "user_pause" if paused else "user_resume")
	_update_desired_paused()
	_sync_control()


func set_auto_paused(paused: bool) -> void:
	_auto_paused = paused
	_update_desired_paused()
	_sync_control()


func is_user_paused() -> bool:
	return _user_paused


func is_auto_paused() -> bool:
	return _auto_paused


func is_paused() -> bool:
	return _desired_paused


func shutdown() -> void:
	if _pending_shutdown or _shutdown_sent:
		return
	_pending_shutdown = true
	if _memory_store != null:
		_memory_store.add_event("helper_control", "shutdown")
	_sync_control()


func _poll() -> void:
	if _shutdown_sent:
		return
	if not _available:
		return
	_fetch_events()
	_sync_control()


func _base_url() -> String:
	var u := base_url.strip_edges()
	if u.ends_with("/"):
		u = u.substr(0, u.length() - 1)
	return u


func is_available() -> bool:
	return _available


func get_availability_detail() -> String:
	return _availability_detail


func _fetch_events() -> void:
	if _events_in_flight:
		return
	if not _available:
		return
	var u := _base_url()
	if u.is_empty():
		return

	_events_in_flight = true
	var err := _events_req.request(
		u + "/events",
		PackedStringArray(["Accept: application/json"]),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		_events_in_flight = false


func _sync_control() -> void:
	if _control_in_flight:
		return
	if not _available:
		return
	var u := _base_url()
	if u.is_empty():
		return
	if _pending_shutdown:
		_send_control(u, "shutdown")
		return
	if _last_sent_paused != null and bool(_last_sent_paused) == _desired_paused:
		return

	var action := "resume"
	if _desired_paused:
		action = "pause"

	_send_control(u, action)


func _send_control(u: String, action: String) -> void:
	_control_in_flight = true
	_control_action_in_flight = action
	var err := _control_req.request(
		u + "/control",
		PackedStringArray(["Content-Type: application/json", "Accept: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"action": action})
	)
	if err != OK:
		_control_in_flight = false
		_control_action_in_flight = ""


func _on_events_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_events_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_mark_unavailable("连接 helper 失败（events）")
		return

	var parsed := JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		return

	for item in parsed:
		if typeof(item) == TYPE_DICTIONARY:
			_ingest_event(item)


func _ingest_event(ev: Dictionary) -> void:
	if _memory_store == null:
		return

	var ts_ms := int(ev.get("ts_ms", Time.get_unix_time_from_system() * 1000))
	var helper_source := String(ev.get("source", ""))
	var text := String(ev.get("text", ""))

	var metadata := {
		"helper_source": helper_source,
	}
	if ev.has("id"):
		metadata["id"] = ev["id"]
	if ev.has("metadata"):
		metadata["metadata"] = ev["metadata"]

	_memory_store.append_event(
		{
			"timestamp": ts_ms,
			"source": "helper/" + helper_source,
			"text": text,
			"metadata": metadata,
		}
	)


func _on_control_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var action := _control_action_in_flight
	_control_in_flight = false
	_control_action_in_flight = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_mark_unavailable("连接 helper 失败（control）")
		return

	var parsed := JSON.parse_string(body.get_string_from_utf8())
	if parsed != null and typeof(parsed) == TYPE_DICTIONARY and parsed.has("paused"):
		_last_sent_paused = bool(parsed.get("paused", false))
	else:
		_last_sent_paused = _desired_paused

	if action == "shutdown":
		_pending_shutdown = false
		_shutdown_sent = true
		if _poll_timer != null:
			_poll_timer.stop()
		if _probe_timer != null:
			_probe_timer.stop()


func _update_desired_paused() -> void:
	var before := _desired_paused
	_desired_paused = _user_paused or _auto_paused
	if before != _desired_paused and _memory_store != null:
		_memory_store.add_event(
			"helper_control",
			"pause" if _desired_paused else "resume",
			{"user_paused": _user_paused, "auto_paused": _auto_paused}
		)


func _probe_health() -> void:
	if _shutdown_sent:
		return
	if _health_in_flight:
		return
	var u := _base_url()
	if u.is_empty():
		_set_availability(false, "helper 地址为空")
		return

	_health_in_flight = true
	var err := _health_req.request(u + "/health", PackedStringArray([]), HTTPClient.METHOD_GET)
	if err != OK:
		_health_in_flight = false
		_mark_unavailable("探活请求失败（%d）" % err)


func _on_health_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_health_in_flight = false
	var ok := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
	if ok:
		_probe_attempts = 0
		_set_availability(true, "已连接")
		if _probe_timer != null:
			_probe_timer.stop()
		if _poll_timer != null and _poll_timer.is_stopped():
			_poll_timer.start()
		return

	_probe_attempts += 1
	if _start_attempts == 0:
		_set_availability(false, "helper 不可达，正在尝试启动…")
		var started := _try_start_helper_from_exe_dir()
		if started:
			_start_attempts += 1
			_set_availability(false, "已尝试启动 helper，等待就绪…")
		else:
			_start_attempts += 1
			_set_availability(false, "启动 helper 失败：未找到可执行文件")
	else:
		_mark_unavailable("helper 不可达（%d）" % _probe_attempts)

	if _probe_timer != null:
		_probe_timer.wait_time = min(5.0, 0.5 + float(_probe_attempts) * 0.5)


func _try_start_helper_from_exe_dir() -> bool:
	if _helper_pid > 0 and OS.is_process_running(_helper_pid):
		return true

	var exe_path := OS.get_executable_path()
	var exe_dir := exe_path.get_base_dir()
	if exe_dir.strip_edges().is_empty():
		return false

	var candidates: Array[String] = [
		exe_dir.path_join("helper-win.exe"),
		exe_dir.path_join("helper.exe"),
		exe_dir.path_join("helper-win"),
		exe_dir.path_join("helper"),
	]

	var helper_path := ""
	for c in candidates:
		if FileAccess.file_exists(c):
			helper_path = c
			break
	if helper_path.is_empty():
		return false

	var bind := _extract_bind_from_base_url()
	var args := PackedStringArray(["--bind", bind])
	var pid := OS.create_process(helper_path, args, false)
	if pid <= 0:
		return false
	_helper_pid = pid
	return true


func _extract_bind_from_base_url() -> String:
	var u := _base_url()
	u = u.replace("http://", "").replace("https://", "")
	var slash := u.find("/")
	if slash >= 0:
		u = u.substr(0, slash)

	var parts := u.split(":", false)
	if parts.size() == 2 and not String(parts[0]).strip_edges().is_empty() and not String(parts[1]).strip_edges().is_empty():
		return "%s:%s" % [String(parts[0]).strip_edges(), String(parts[1]).strip_edges()]
	return "127.0.0.1:28999"


func _mark_unavailable(detail: String) -> void:
	if not _available:
		_availability_detail = detail
		availability_changed.emit(_available, _availability_detail)
		return
	_set_availability(false, detail)
	if _poll_timer != null:
		_poll_timer.stop()
	if _probe_timer != null and _probe_timer.is_stopped():
		_probe_timer.start()


func _set_availability(available: bool, detail: String) -> void:
	var changed := (available != _available) or (detail != _availability_detail)
	_available = available
	_availability_detail = detail
	if changed:
		availability_changed.emit(_available, _availability_detail)
