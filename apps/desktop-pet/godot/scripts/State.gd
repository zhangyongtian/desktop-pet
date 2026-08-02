class_name State
extends RefCounted

var owner: Node

func _init(p_owner: Node) -> void:
	owner = p_owner

func on_enter(_data: Variant = null) -> void:
	pass

func on_exit() -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

