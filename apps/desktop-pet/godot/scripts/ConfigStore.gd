class_name ConfigStore
extends Node

signal changed

const SAVE_DIR := "user://config"
const SAVE_PATH := SAVE_DIR + "/config.json"

var _data: Dictionary = {}


func _ready() -> void:
	load_from_disk()


func get_endpoint() -> String:
	return String(_data.get("deepseek_endpoint", "https://api.deepseek.com/v1/chat/completions"))


func get_model() -> String:
	return String(_data.get("deepseek_model", "deepseek-chat"))


func get_api_key() -> String:
	var encoded := String(_data.get("deepseek_api_key_obf", ""))
	if encoded.is_empty():
		return ""
	return _deobfuscate(encoded)


func get_user_name() -> String:
	return String(_data.get("user_name", ""))


func get_report_system_prompt() -> String:
	var v := String(_data.get("prompt_report_system", ""))
	if not v.strip_edges().is_empty():
		return v
	return PromptTemplates.default_report_system_prompt(get_user_name())


func get_chat_system_prompt() -> String:
	var v := String(_data.get("prompt_chat_system", ""))
	if not v.strip_edges().is_empty():
		return v
	return PromptTemplates.default_chat_system_prompt(get_user_name())


func get_summarize_system_prompt() -> String:
	var v := String(_data.get("prompt_summarize_system", ""))
	if not v.strip_edges().is_empty():
		return v
	return PromptTemplates.default_summarize_system_prompt()


func get_merge_system_prompt() -> String:
	var v := String(_data.get("prompt_merge_system", ""))
	if not v.strip_edges().is_empty():
		return v
	return PromptTemplates.default_merge_system_prompt()


func set_deepseek_config(endpoint: String, model: String, api_key: String) -> void:
	_data["deepseek_endpoint"] = endpoint.strip_edges()
	_data["deepseek_model"] = model.strip_edges()
	if not api_key.strip_edges().is_empty():
		_data["deepseek_api_key_obf"] = _obfuscate(api_key.strip_edges())
	save_to_disk()
	changed.emit()


func clear_api_key() -> void:
	_data.erase("deepseek_api_key_obf")
	save_to_disk()
	changed.emit()


func set_user_name(name: String) -> void:
	_data["user_name"] = name.strip_edges()
	save_to_disk()
	changed.emit()


func set_prompt_overrides(report_system: String, chat_system: String, summarize_system: String, merge_system: String) -> void:
	_data["prompt_report_system"] = report_system
	_data["prompt_chat_system"] = chat_system
	_data["prompt_summarize_system"] = summarize_system
	_data["prompt_merge_system"] = merge_system
	save_to_disk()
	changed.emit()


func load_from_disk() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if not FileAccess.file_exists(SAVE_PATH):
		_data = {}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_data = {}
		return
	var content := file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		_data = {}
		return
	var parsed := JSON.parse_string(content)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		_data = {}
		return
	_data = parsed


func save_to_disk() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ConfigStore: cannot write file: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_data, "  "))
	file.flush()
	file.close()


func _obfuscate(plain: String) -> String:
	var bytes := plain.to_utf8_buffer()
	var key := _obf_key_bytes()
	for i in range(bytes.size()):
		bytes[i] = bytes[i] ^ key[i % key.size()]
	return Marshalls.raw_to_base64(bytes)


func _deobfuscate(encoded: String) -> String:
	var bytes := Marshalls.base64_to_raw(encoded)
	var key := _obf_key_bytes()
	for i in range(bytes.size()):
		bytes[i] = bytes[i] ^ key[i % key.size()]
	return bytes.get_string_from_utf8()


func _obf_key_bytes() -> PackedByteArray:
	var seed := OS.get_unique_id() + "|trea_cli|desktop_pet"
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(seed.to_utf8_buffer())
	var digest := ctx.finish()
	if digest.is_empty():
		return PackedByteArray([17, 23, 31, 47, 59, 61, 71, 73])
	return digest
