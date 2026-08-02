class_name StateMachine
extends Node

signal state_changed(from: StringName, to: StringName)

var _states: Dictionary = {}
var _current: State
var _current_name: StringName = &""

func add_state(name: StringName, state: State) -> void:
	_states[name] = state

func has_state(name: StringName) -> bool:
	return _states.has(name)

func get_current_state_name() -> StringName:
	return _current_name

func change_state(name: StringName, data: Variant = null) -> void:
	if not _states.has(name):
		push_error("StateMachine: missing state '%s'" % String(name))
		return

	var from_name := _current_name
	if _current != null:
		_current.on_exit()

	_current = _states[name]
	_current_name = name
	_current.on_enter(data)
	state_changed.emit(from_name, name)

func handle_input(event: InputEvent) -> void:
	if _current != null:
		_current.handle_input(event)

func update(delta: float) -> void:
	if _current != null:
		_current.update(delta)

func physics_update(delta: float) -> void:
	if _current != null:
		_current.physics_update(delta)

