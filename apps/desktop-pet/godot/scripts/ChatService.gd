class_name ChatService
extends Node

@export var news_cooldown_seconds: float = 45.0
@export var comfort_cooldown_seconds: float = 120.0

var _config: ConfigStore = null
var _client: DeepSeekClient = null

var _last_news_ms: int = 0
var _last_comfort_ms: int = 0


func setup(config_store: ConfigStore, client: DeepSeekClient) -> void:
	_config = config_store
	_client = client


func reply_to_news(news_text: String) -> Dictionary:
	if _config == null or _client == null:
		return {"ok": false, "error": "not_configured"}
	var now_ms := Time.get_unix_time_from_system() * 1000
	if _last_news_ms > 0 and now_ms - _last_news_ms < int(news_cooldown_seconds * 1000.0):
		return {"ok": true, "skipped": true, "reason": "cooldown"}
	_last_news_ms = now_ms

	var user_prompt := "下面是一段新闻或热点内容，请用陪聊的方式回应：先给一句观点/态度，再给 3-5 句聊天延展（提问或吐槽），不要编造来源链接。\n\n内容：\n%s" % news_text.strip_edges()
	return await _chat(user_prompt, 420)


func reply_chat(text: String) -> Dictionary:
	if _config == null or _client == null:
		return {"ok": false, "error": "not_configured"}

	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		return {"ok": true, "content": ""}

	if _looks_like_emotion_need(cleaned):
		return await comfort(cleaned)

	var user_prompt := "用户说：%s\n\n请用陪聊方式回应，尽量短句。" % cleaned
	return await _chat(user_prompt, 360)


func comfort(text: String) -> Dictionary:
	if _config == null or _client == null:
		return {"ok": false, "error": "not_configured"}
	var now_ms := Time.get_unix_time_from_system() * 1000
	if _last_comfort_ms > 0 and now_ms - _last_comfort_ms < int(comfort_cooldown_seconds * 1000.0):
		return {"ok": true, "skipped": true, "reason": "cooldown"}
	_last_comfort_ms = now_ms

	var user_prompt := "用户出现负面情绪或压力信号，请先共情，再给 3 个非常小的、可执行的缓解动作（例如喝水/走两分钟/写下一句话），最后给一句鼓励。\n\n用户原话：\n%s" % text.strip_edges()
	return await _chat(user_prompt, 420)


func _chat(user_prompt: String, max_tokens: int) -> Dictionary:
	var messages: Array[Dictionary] = [
		{"role": "system", "content": _config.get_chat_system_prompt()},
		{"role": "user", "content": user_prompt},
	]
	return await _client.chat_complete(messages, 0.7, max_tokens)


func _looks_like_emotion_need(text: String) -> bool:
	var s := text
	var patterns := [
		"难受", "崩溃", "焦虑", "抑郁", "绝望", "想哭", "烦", "压力", "失眠", "不想干了", "撑不住", "好累",
	]
	for p in patterns:
		if s.find(p) >= 0:
			return true
	return false
