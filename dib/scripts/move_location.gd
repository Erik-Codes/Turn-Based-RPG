extends TextureButton
signal chosen(node_id: String)

@export var node_id: String

func _ready() -> void:
	pressed.connect(func(): chosen.emit(node_id))
