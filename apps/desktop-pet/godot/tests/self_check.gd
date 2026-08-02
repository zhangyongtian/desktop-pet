extends SceneTree

const MemoryStoreScript := preload("res://scripts/MemoryStore.gd")
const ConfigStoreScript := preload("res://scripts/ConfigStore.gd")
const DeepSeekClientScript := preload("res://scripts/DeepSeekClient.gd")
const HelperBridgeScript := preload("res://scripts/HelperBridge.gd")

const EXIT_OK := 0
const EXIT_FAIL := 1

var _errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_errors.append(msg)
	printerr("[SELF_CHECK][FAIL] " + msg)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _resolve(maybe_state: Variant) -> Variant:
	if maybe_state is GDScriptFunctionState:
		return await maybe_state
	return maybe_state


func _run() -> void:
	print("[SELF_CHECK] start")

	var memory := MemoryStoreScript.new()
	root.add_child(memory)
	await process_frame

	var event := memory.add_event("self_check", "memory_store_write_ok", {"kind": "self_check"})
	_assert(typeof(event) == TYPE_DICTIONARY, "MemoryStore.add_event 返回值不是 Dictionary")
	_assert(String(event.get("text", "")) == "memory_store_write_ok", "MemoryStore.add_event 返回 text 不符合预期")

	var raw := memory.get_raw_buffer()
	_assert(raw.size() > 0, "MemoryStore 写入后 raw_buffer 为空")
	_assert(
		FileAccess.file_exists(MemoryStoreScript.EVENTS_PATH),
		"MemoryStore 未创建 events 文件：" + MemoryStoreScript.EVENTS_PATH
	)

	var config := ConfigStoreScript.new()
	root.add_child(config)
	await process_frame

	config.clear_api_key()

	var client := DeepSeekClientScript.new()
	client.set_config_store(config)
	root.add_child(client)
	await process_frame

	var r_chat := await _resolve(client.chat_complete([{"role": "user", "content": "ping"}]))
	_assert(typeof(r_chat) == TYPE_DICTIONARY, "DeepSeekClient.chat_complete 返回值不是 Dictionary")
	_assert(not bool(r_chat.get("ok", false)), "缺失 API key 时 chat_complete 不应 ok=true")
	_assert(
		String(r_chat.get("error", "")).find("missing_api_key") >= 0,
		"缺失 API key 的错误信息不可理解（期望包含 missing_api_key）：%s" % JSON.stringify(r_chat)
	)

	var bridge := HelperBridgeScript.new()
	bridge.base_url = "http://127.0.0.1:1"
	bridge.setup(memory)
	root.add_child(bridge)
	await process_frame

	var detail := bridge.get_availability_detail()
	_assert(not bridge.is_available(), "HelperBridge 在 self-check 中应不可用（不应连接到实际 helper）")
	_assert(not String(detail).strip_edges().is_empty(), "HelperBridge 不可用时 availability detail 不能为空")

	await process_frame
	detail = bridge.get_availability_detail()
	_assert(not String(detail).strip_edges().is_empty(), "HelperBridge 探活后 availability detail 仍不应为空")

	if _errors.is_empty():
		print("[SELF_CHECK] PASS")
		quit(EXIT_OK)
		return

	print("[SELF_CHECK] FAIL (%d)" % _errors.size())
	for e in _errors:
		printerr(" - " + e)
	quit(EXIT_FAIL)
