extends Node2D


func _on_play_pressed() -> void:
	AudioManager.click_sound()
	get_tree().change_scene_to_file("res://scenes/game/node.tscn")
	AudioManager.stop_music()
	


func _on_options_pressed() -> void:
	AudioManager.click_sound()


func _on_exit_pressed() -> void:
	AudioManager.click_sound()
	get_tree().quit()
