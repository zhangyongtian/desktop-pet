class_name TaskPanel
extends Panel

@onready var task_input: LineEdit = %TaskInput
@onready var add_button: Button = %AddButton
@onready var show_done_toggle: CheckButton = %ShowDoneToggle
@onready var show_archived_toggle: CheckButton = %ShowArchivedToggle
@onready var task_list: VBoxContainer = %TaskList

var _task_store: TaskStore


func _ready() -> void:
	_task_store = _find_task_store()
	if _task_store == null:
		push_error("TaskPanel: missing TaskStore")
		return

	add_button.pressed.connect(_on_add_pressed)
	task_input.text_submitted.connect(_on_task_submitted)
	show_done_toggle.toggled.connect(_on_filter_changed)
	show_archived_toggle.toggled.connect(_on_filter_changed)
	_task_store.changed.connect(_refresh)

	_refresh()


func _find_task_store() -> TaskStore:
	var p: Node = self
	while p != null:
		var n := p.get_node_or_null("TaskStore")
		if n != null and n is TaskStore:
			return n as TaskStore
		p = p.get_parent()
	return null


func _on_task_submitted(text: String) -> void:
	_add_task(text)


func _on_add_pressed() -> void:
	_add_task(task_input.text)


func _add_task(text: String) -> void:
	var created := _task_store.add_task(text)
	if created.is_empty():
		return
	task_input.text = ""
	task_input.grab_focus()
	_refresh()


func _on_filter_changed(_v: bool) -> void:
	_refresh()


func _refresh() -> void:
	if _task_store == null:
		return

	for child in task_list.get_children():
		child.queue_free()

	var show_done := show_done_toggle.button_pressed
	var show_archived := show_archived_toggle.button_pressed

	var tasks := _task_store.get_all_tasks()
	tasks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_key(a) < _sort_key(b)
	)

	for task in tasks:
		var status := String(task.get("status", TaskStore.STATUS_TODO))
		if status == TaskStore.STATUS_DONE and not show_done:
			continue
		if status == TaskStore.STATUS_ARCHIVED and not show_archived:
			continue

		task_list.add_child(_build_row(task))


func _sort_key(task: Dictionary) -> int:
	var status := String(task.get("status", TaskStore.STATUS_TODO))
	var group := 0
	if status == TaskStore.STATUS_TODO:
		group = 0
	elif status == TaskStore.STATUS_DONE:
		group = 1
	else:
		group = 2

	var created := int(task.get("created_at", 0))
	return group * 10000000000000 + created


func _build_row(task: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var task_id := String(task.get("id", ""))
	var status := String(task.get("status", TaskStore.STATUS_TODO))

	var checkbox := CheckBox.new()
	checkbox.button_pressed = (status == TaskStore.STATUS_DONE)
	checkbox.disabled = (status == TaskStore.STATUS_ARCHIVED)
	checkbox.toggled.connect(func(pressed: bool) -> void:
		_task_store.set_done(task_id, pressed)
	)

	var label := Label.new()
	label.text = String(task.get("text", ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if status == TaskStore.STATUS_DONE:
		label.modulate = Color(0.7, 0.7, 0.7)
	if status == TaskStore.STATUS_ARCHIVED:
		label.modulate = Color(0.55, 0.55, 0.55)

	row.add_child(checkbox)
	row.add_child(label)

	if status == TaskStore.STATUS_DONE:
		var archive_btn := Button.new()
		archive_btn.text = "归档"
		archive_btn.pressed.connect(func() -> void:
			_task_store.archive(task_id)
		)
		row.add_child(archive_btn)
	elif status == TaskStore.STATUS_ARCHIVED:
		var unarchive_btn := Button.new()
		unarchive_btn.text = "取消归档"
		unarchive_btn.pressed.connect(func() -> void:
			_task_store.unarchive(task_id)
		)
		row.add_child(unarchive_btn)

	return row
