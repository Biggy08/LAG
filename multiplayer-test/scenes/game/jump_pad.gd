extends StaticBody2D

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_parent()  is Player:
		area.get_parent().velocity.y = -500
