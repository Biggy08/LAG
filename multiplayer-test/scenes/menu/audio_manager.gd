extends Node

@onready var menu: AudioStreamPlayer = $Menu
@onready var click: AudioStreamPlayer = $Click
@onready var music_1: AudioStreamPlayer = $music1

@onready var music_2: AudioStreamPlayer = $music2
@onready var music_3: AudioStreamPlayer = $music3

var music_volume_db: float = 0.0
var is_music_muted: bool = false

func play_music2():
	music_2.play()
	
func play_music3():
	music_3.play()


func play_music():
	if not is_music_muted:
		menu.volume_db = music_volume_db
		menu.play()

func stop_music():
	menu.stop()

func click_sound():
	click.play()

func set_music_volume(value: float):
	music_volume_db = value
	if not is_music_muted:
		menu.volume_db = value

func mute_music(mute: bool):
	is_music_muted = mute
	if mute:
		menu.volume_db = -80  # Fully muted
	else:
		menu.volume_db = music_volume_db  # Restore previous volume

func _ready():
	play_music()
