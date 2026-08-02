class_name PetVisual
extends Control

@export var idle_res_path: String = "res://assets/pet/idle.png"

@export var sleep_idle_seconds: float = 60.0
@export var busy_hold_seconds: float = 2.0

var _texture_button: TextureButton = null
var _zzz_label: Label = null
var _sleep_timer: Timer = null
var _busy_timer: Timer = null
var _tween: Tween = null

var _idle_tex: Texture2D = null
var _mode: String = "idle"


func setup(memory_store: MemoryStore) -> void:
	if memory_store != null:
		memory_store.event_appended.connect(_on_event_appended)


func _ready() -> void:
	_texture_button = _find_texture_button()
	_zzz_label = _find_zzz_label()

	_sleep_timer = Timer.new()
	_sleep_timer.one_shot = true
	_sleep_timer.wait_time = sleep_idle_seconds
	add_child(_sleep_timer)
	_sleep_timer.timeout.connect(func() -> void:
		_set_mode("sleep")
	)

	_busy_timer = Timer.new()
	_busy_timer.one_shot = true
	_busy_timer.wait_time = busy_hold_seconds
	add_child(_busy_timer)
	_busy_timer.timeout.connect(func() -> void:
		_set_mode("idle")
	)

	_load_textures()
	_set_mode("idle")
	_restart_sleep_timer()


func on_clicked() -> void:
	_set_mode("idle")
	_restart_sleep_timer()


func _on_event_appended(_event: Dictionary) -> void:
	_set_mode("busy")
	_restart_sleep_timer()


func _restart_sleep_timer() -> void:
	if _sleep_timer == null:
		return
	_sleep_timer.stop()
	if sleep_idle_seconds > 0:
		_sleep_timer.start()


func _load_textures() -> void:
	_idle_tex = _try_load_texture(idle_res_path)
	if _texture_button != null and _idle_tex != null:
		_texture_button.texture_normal = _idle_tex
		_texture_button.texture_pressed = _idle_tex
		_texture_button.texture_hover = _idle_tex
		_texture_button.texture_focused = _idle_tex


func _set_mode(mode: String) -> void:
	if mode == _mode:
		return
	_mode = mode

	if _tween != null:
		_tween.kill()
		_tween = null

	if _texture_button != null:
		_texture_button.pivot_offset = _texture_button.size * 0.5

	if mode == "idle":
		_apply_idle()
	elif mode == "busy":
		_apply_busy()
	else:
		_apply_sleep()


func _apply_idle() -> void:
	if _texture_button != null:
		_texture_button.modulate = Color(1, 1, 1, 1)
		_texture_button.rotation = 0.0
		_texture_button.scale = Vector2.ONE
	if _zzz_label != null:
		_zzz_label.visible = false


func _apply_busy() -> void:
	if _texture_button != null:
		_texture_button.modulate = Color(1, 1, 1, 1)
		_tween = create_tween()
		_tween.set_loops()
		_tween.tween_property(_texture_button, "rotation", 0.06, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(_texture_button, "rotation", -0.06, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(_texture_button, "rotation", 0.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _zzz_label != null:
		_zzz_label.visible = false

	if _busy_timer != null:
		_busy_timer.stop()
		if busy_hold_seconds > 0:
			_busy_timer.start()


func _apply_sleep() -> void:
	if _texture_button != null:
		_texture_button.modulate = Color(0.8, 0.8, 0.8, 1)
		_texture_button.rotation = 0.0
		_texture_button.scale = Vector2.ONE
	if _zzz_label != null:
		_zzz_label.visible = true


func _try_load_texture(path: String) -> Texture2D:
	var p := path.strip_edges()
	if p.is_empty():
		return null
	if not ResourceLoader.exists(p):
		return null
	var res := load(p)
	if res == null:
		return null
	if res is Texture2D:
		return res as Texture2D
	return null


func _find_texture_button() -> TextureButton:
	if self is TextureButton:
		return self as TextureButton
	if has_node("TextureButton"):
		var n := get_node("TextureButton")
		if n is TextureButton:
			return n as TextureButton
	return null


func _find_zzz_label() -> Label:
	var n := get_node_or_null("Zzz")
	if n != null and n is Label:
		return n as Label
	return null

