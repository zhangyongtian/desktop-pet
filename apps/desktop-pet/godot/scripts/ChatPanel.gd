class_name ChatPanel
extends Control

@onready var input_edit: LineEdit = %ChatInput
@onready var send_button: Button = %SendButton
@onready var as_news_toggle: CheckButton = %AsNewsToggle
@onready var output_edit: TextEdit = %ChatOutput

var _chat: ChatService = null


func _ready() -> void:
	_chat = _find_chat_service()
	send_button.pressed.connect(_on_send)
	input_edit.text_submitted.connect(func(_t: String) -> void:
		await _on_send()
	)


func _on_send() -> void:
	if _chat == null:
		output_edit.text = "缺少 ChatService"
		return
	var text := input_edit.text.strip_edges()
	if text.is_empty():
		return
	input_edit.text = ""
	_append_line("你：%s" % text)
	_append_line("……")

	var r: Dictionary
	if as_news_toggle.button_pressed:
		r = await _chat.reply_to_news(text)
	else:
		r = await _chat.reply_chat(text)

	_remove_trailing_wait()
	if bool(r.get("ok", false)):
		if bool(r.get("skipped", false)):
			_append_line("桌宠：我先冷静一下，过会儿再聊。")
		else:
			_append_line("桌宠：%s" % String(r.get("content", "")).strip_edges())
	else:
		_append_line("桌宠：%s" % _friendly_error(String(r.get("error", ""))))


func _friendly_error(err: String) -> String:
	var e := err.strip_edges()
	if e == "missing_api_key":
		return "DeepSeek 未配置（缺少 API Key）。请到【设置】填写后再聊。"
	if e == "missing_endpoint":
		return "DeepSeek 未配置（缺少 Endpoint）。请到【设置】填写后再聊。"
	if e == "missing_model":
		return "DeepSeek 未配置（缺少 Model）。请到【设置】填写后再聊。"
	if e == "not_configured":
		return "功能未就绪，请稍后重试。"
	return "出错了（%s）" % e


func _append_line(line: String) -> void:
	var current := output_edit.text
	if current.strip_edges().is_empty():
		output_edit.text = line
	else:
		output_edit.text = current + "\n" + line
	output_edit.scroll_vertical = output_edit.get_line_count()


func _remove_trailing_wait() -> void:
	var lines := output_edit.text.split("\n", false)
	if not lines.is_empty() and lines[lines.size() - 1] == "……":
		lines.remove_at(lines.size() - 1)
		output_edit.text = "\n".join(lines)


func _find_chat_service() -> ChatService:
	var p: Node = self
	while p != null:
		var n := p.get_node_or_null("ChatService")
		if n != null and n is ChatService:
			return n as ChatService
		p = p.get_parent()
	return null
