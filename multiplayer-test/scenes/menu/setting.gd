extends Control

func _ready():
	$MarginContainer/VBoxContainer/Volume.value = AudioManager.music_volume_db
	$MarginContainer/VBoxContainer/CheckBox.button_pressed = AudioManager.is_music_muted


func _on_volume_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)


func _on_check_box_toggled(toggled_on: bool) -> void:
	AudioManager.mute_music(toggled_on)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
