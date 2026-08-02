extends Control

@onready var pet_button: BaseButton = $PetButton
@onready var popup_panel: Panel = $PopupPanel
@onready var state_machine: StateMachine = $StateMachine
@onready var task_store: TaskStore = $TaskStore
@onready var memory_store: MemoryStore = $MemoryStore
@onready var config_store: ConfigStore = $ConfigStore
@onready var deepseek_client: DeepSeekClient = $DeepSeekClient
@onready var summarization_pipeline: SummarizationPipeline = $SummarizationPipeline
@onready var report_generator: ReportGenerator = $ReportGenerator
@onready var chat_service: ChatService = $ChatService
@onready var helper_bridge: HelperBridge = $HelperBridge
@onready var pet_visual: PetVisual = $PetButton

class IdleState extends State:
	func on_enter(_data: Variant = null) -> void:
		var panel := owner.get_node("PopupPanel") as CanvasItem
		panel.visible = false

class PanelOpenState extends State:
	func on_enter(_data: Variant = null) -> void:
		var panel := owner.get_node("PopupPanel") as CanvasItem
		panel.visible = true

func _ready() -> void:
	popup_panel.visible = false

	task_store.set_memory_store(memory_store)

	deepseek_client.set_config_store(config_store)
	summarization_pipeline.setup(memory_store, config_store, deepseek_client)
	report_generator.setup(memory_store, config_store, deepseek_client)
	chat_service.setup(config_store, deepseek_client)

	helper_bridge.setup(memory_store)
	pet_visual.setup(memory_store)

	state_machine.add_state(&"idle", IdleState.new(self))
	state_machine.add_state(&"panel_open", PanelOpenState.new(self))
	state_machine.state_changed.connect(_on_state_changed)
	state_machine.change_state(&"idle")

	pet_button.pressed.connect(_on_pet_pressed)


func _on_state_changed(_from: StringName, to: StringName) -> void:
	if to == &"panel_open":
		helper_bridge.set_auto_paused(true)
	else:
		helper_bridge.set_auto_paused(false)

func _process(delta: float) -> void:
	state_machine.update(delta)

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.handle_input(event)

func _on_pet_pressed() -> void:
	if pet_visual != null:
		pet_visual.on_clicked()
	var current := state_machine.get_current_state_name()
	if current == &"idle":
		state_machine.change_state(&"panel_open")
	else:
		state_machine.change_state(&"idle")
