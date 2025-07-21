#Bullet Code
extends Area2D


var speed = 1000  # Bullet Speed
var dmg = 20  # Damage when bullet hits a player

#Bullet Speed and Direction
func _physics_process(delta):
	
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

	
# Bullet Hitting the player body
func _on_body_entered(body: Node2D):
	if !is_multiplayer_authority():
		return

	if body is Player:
		var shooter_id = get_multiplayer_authority()
		var target_id = body.get_multiplayer_authority()

		if shooter_id != target_id:
			# Only tell other players to take damage
			body.take_damage.rpc_id(target_id, dmg)

	remove_bullet.rpc()



# Bullet Despawn  after hitting the player 
@rpc("call_local")
func remove_bullet():
	queue_free()



	
