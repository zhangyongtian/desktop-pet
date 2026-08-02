class_name PopupPanel
extends Panel

@onready var tabs: TabContainer = %Tabs
@onready var status_label: Label = %StatusLabel
@onready var go_settings_button: Button = %GoSettingsButton

var _helper_bridge: HelperBridge = null
var _config_store: ConfigStore = null


func _ready() -> void:
	if tabs != null:
		tabs.current_tab = 0
	_helper_bridge = _find_helper_bridge()
	_config_store = _find_config_store()

	if go_settings_button != null:
		go_settings_button.pressed.connect(func() -> void:
			if tabs != null:
				tabs.current_tab = 3
		)

	if _helper_bridge != null:
		_helper_bridge.availability_changed.connect(func(_a: bool, _d: String) -> void:
			_refresh_status()
		)
	if _config_store != null:
		_config_store.changed.connect(_refresh_status)

	_refresh_status()


func _refresh_status() -> void:
	if status_label == null:
		return

	var parts: Array[String] = []

	if _helper_bridge == null:
		parts.append("采集：不可用（缺少 HelperBridge）")
	else:
		if _helper_bridge.is_available():
			parts.append("采集：可用")
		else:
			var d := _helper_bridge.get_availability_detail()
			if d.strip_edges().is_empty():
				d = "不可用"
			parts.append("采集：不可用（%s）" % d)

	var deepseek_ok := false
	if _config_store != null:
		deepseek_ok = not _config_store.get_api_key().strip_edges().is_empty()
	if deepseek_ok:
		parts.append("DeepSeek：已配置")
		if go_settings_button != null:
			go_settings_button.visible = false
	else:
		parts.append("DeepSeek：未配置（去设置填写 API Key）")
		if go_settings_button != null:
			go_settings_button.visible = true

	status_label.text = " | ".join(parts)


func _find_helper_bridge() -> HelperBridge:
	var p: Node = self
	while p != null:
		var n := p.get_node_or_null("HelperBridge")
		if n != null and n is HelperBridge:
			return n as HelperBridge
		p = p.get_parent()
	return null


func _find_config_store() -> ConfigStore:
	var p: Node = self
	while p != null:
		var n := p.get_node_or_null("ConfigStore")
		if n != null and n is ConfigStore:
			return n as ConfigStore
		p = p.get_parent()
	return null
