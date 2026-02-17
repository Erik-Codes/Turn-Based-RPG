#fade_to_scene: fades out and fades into the new string in the entered time
#fade_out: fades the screen to black in the duration provided
#fade_in: fades the screen in in the duration provided
extends CanvasLayer

@onready var fade: ColorRect = $Fade

var _busy := false

func is_busy() -> bool:
	return _busy

func fade_to_scene(scene_path: String, out_time := 0.18, in_time := 0.18) -> void:
	await fade_out(out_time)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_in(in_time)

func fade_out(duration := 0.18) -> void:
	if _busy: return
	_busy = true
	fade.visible = true
	fade.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, duration)
	await tw.finished

func fade_in(duration := 0.18) -> void:
	fade.visible = true
	fade.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, duration)
	await tw.finished
	fade.visible = false
	_busy = false
