extends Node

@onready var menu: AudioStreamPlayer = $Menu
@onready var click: AudioStreamPlayer = $Click

func play_music():
	$Menu.play()
	
func stop_music():
	$Menu.stop()
	
func click_sound():
	$Click.play()
