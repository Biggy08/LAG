extends Node2D

@export var force = -500.0


func _on_area_2d_area_entered(area: Area2D) -> void:
	print("entered   jump pad")
	if area.get_parent() is Player:
		area.get_parent().velocity.y = force
