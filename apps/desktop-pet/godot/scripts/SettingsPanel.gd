class_name SettingsPanel
extends Control

@onready var endpoint_input: LineEdit = %EndpointInput
@onready var model_input: LineEdit = %ModelInput
@onready var api_key_input: LineEdit = %ApiKeyInput
@onready var clear_key_button: Button = %ClearKeyButton
@onready var user_name_input: LineEdit = %UserNameInput
@onready var report_prompt_edit: TextEdit = %ReportPromptEdit
@onready var chat_prompt_edit: TextEdit = %ChatPromptEdit
@onready var summarize_prompt_edit: TextEdit = %SummarizePromptEdit
@onready var merge_prompt_edit: TextEdit = %MergePromptEdit
@onready var pause_capture_toggle: CheckButton = %PauseCaptureToggle
@onready var emergency_stop_button: Button = %EmergencyStopButton
@onready var save_button: Button = %SaveButton
@onready var reset_button: Button = %ResetButton

var _config: ConfigStore = null
var _helper_bridge: HelperBridge = null


func _ready() -> void:
	_config = _find_config_store()
	_helper_bridge = _find_helper_bridge()

	if _config != null:
		save_button.pressed.connect(_on_save_pressed)
		reset_button.pressed.connect(_on_reset_pressed)
		clear_key_button.pressed.connect(func() -> void:
			_config.clear_api_key()
			api_key_input.text = ""
		)
		_load_from_config()
	else:
		save_button.disabled = true
		reset_button.disabled = true
		clear_key_button.disabled = true

	if _helper_bridge != null:
		pause_capture_toggle.button_pressed = _helper_bridge.is_user_paused()
		pause_capture_toggle.toggled.connect(_on_pause_capture_toggled)
		emergency_stop_button.pressed.connect(_on_emergency_stop_pressed)
	else:
		pause_capture_toggle.disabled = true
		emergency_stop_button.disabled = true


func _on_pause_capture_toggled(pressed: bool) -> void:
	if _helper_bridge == null:
		return
	_helper_bridge.set_user_paused(pressed)


func _on_emergency_stop_pressed() -> void:
	if _helper_bridge == null:
		return
	_helper_bridge.shutdown()


func _on_save_pressed() -> void:
	if _config == null:
		return
	_config.set_user_name(user_name_input.text)
	_config.set_deepseek_config(endpoint_input.text, model_input.text, api_key_input.text)
	_config.set_prompt_overrides(
		report_prompt_edit.text,
		chat_prompt_edit.text,
		summarize_prompt_edit.text,
		merge_prompt_edit.text
	)
	api_key_input.text = ""


func _on_reset_pressed() -> void:
	if _config == null:
		return
	_config.set_prompt_overrides("", "", "", "")
	_load_from_config()


func _load_from_config() -> void:
	if _config == null:
		return
	endpoint_input.text = _config.get_endpoint()
	model_input.text = _config.get_model()
	user_name_input.text = _config.get_user_name()
	report_prompt_edit.text = _config.get_report_system_prompt()
	chat_prompt_edit.text = _config.get_chat_system_prompt()
	summarize_prompt_edit.text = _config.get_summarize_system_prompt()
	merge_prompt_edit.text = _config.get_merge_system_prompt()


func _find_config_store() -> ConfigStore:
	var p: Node = self
	while p != null:
		var n := p.get_node_or_null("ConfigStore")
		if n != null and n is ConfigStore:
			return n as ConfigStore
		p = p.get_parent()
	return null


func _find_helper_bridge() -> HelperBridge:
	var p: Node = self
	while p != null:
		var n := p.get_node_or_null("HelperBridge")
		if n != null and n is HelperBridge:
			return n as HelperBridge
		p = p.get_parent()
	return null
