class_name DeepSeekClient
extends Node

var _config: ConfigStore = null


func set_config_store(store: ConfigStore) -> void:
	_config = store


func chat_complete(messages: Array[Dictionary], temperature: float = 0.2, max_tokens: int = 512) -> Dictionary:
	if _config == null:
		return {"ok": false, "error": "missing_config_store"}
	var endpoint := _config.get_endpoint()
	var model := _config.get_model()
	var api_key := _config.get_api_key()
	if endpoint.strip_edges().is_empty():
		return {"ok": false, "error": "missing_endpoint"}
	if model.strip_edges().is_empty():
		return {"ok": false, "error": "missing_model"}
	if api_key.strip_edges().is_empty():
		return {"ok": false, "error": "missing_api_key"}

	var payload := {
		"model": model,
		"messages": messages,
		"temperature": temperature,
		"max_tokens": max_tokens,
	}

	var req := HTTPRequest.new()
	add_child(req)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
	])

	var err := req.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "request_failed_%d" % err}

	var result: Array = await req.request_completed
	req.queue_free()

	if result.size() < 4:
		return {"ok": false, "error": "bad_response"}

	var http_code := int(result[1])
	var body_bytes: PackedByteArray = result[3]
	var body_text := body_bytes.get_string_from_utf8()

	if http_code < 200 or http_code >= 300:
		return {"ok": false, "error": "http_%d" % http_code, "body": body_text}

	var parsed := JSON.parse_string(body_text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "json_parse_failed", "body": body_text}

	if not parsed.has("choices") or typeof(parsed["choices"]) != TYPE_ARRAY or parsed["choices"].is_empty():
		return {"ok": false, "error": "no_choices", "body": body_text}

	var choice := parsed["choices"][0]
	if typeof(choice) != TYPE_DICTIONARY:
		return {"ok": false, "error": "bad_choice", "body": body_text}
	var msg := choice.get("message", {})
	if typeof(msg) != TYPE_DICTIONARY:
		return {"ok": false, "error": "bad_message", "body": body_text}

	var content := String(msg.get("content", ""))
	return {"ok": true, "content": content, "raw": parsed}
