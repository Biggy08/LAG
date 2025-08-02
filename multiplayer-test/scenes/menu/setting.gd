extends Control

func _ready():
	$Volume.value = AudioManager.music_volume_db


func _on_volume_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)



func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
