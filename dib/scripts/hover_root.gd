extends Control
class_name HoverAnim

@onready var anim: AnimationPlayer = $AnimationPlayer

@export var drop_percent := 2.0
@export var hover_percent := 0.1
@export var offset_norm: float = 0.0 :set = set_offset_norm
@export var hover_norm: float = 0.0 :set = set_hover_norm

func set_offset_norm(v: float) -> void:
	offset_norm = v
	_apply_offsets()

func set_hover_norm(v: float) -> void:
	hover_norm = v
	_apply_offsets()

func _slot_height() -> float:
	if get_parent() is Control:
		return (get_parent() as Control).size.y
	return get_viewport_rect().size.y

func _apply_offsets() -> void:
	var h := _slot_height()
	var drop_px := h*drop_percent
	var hover_px := h*hover_percent
	position.y = (-drop_px*offset_norm) + (hover_px*hover_norm)

func set_drop_in_start_pose() -> void:
	offset_norm = 1.0
	hover_norm = 0.0
	_apply_offsets()
	anim.play("start")
	anim.seek(0.0, true)
	anim.stop()

func play_drop_in() -> void:
	set_drop_in_start_pose()
	anim.play("start")
	await anim.animation_finished

func start_hover() -> void:
	anim.play("hover")

func stop_hover() -> void:
	if anim.is_playing():
		anim.stop()
	offset_norm = 0.0
	hover_norm = 0.0
	_apply_offsets()


func set_anim_speed(speed:float): anim.speed_scale = speed
