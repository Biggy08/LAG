class_name Player
extends CharacterBody2D

@onready var cam: Camera2D = $Camera2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const MAX_HEALTH = 100
const RESPAWN_TIME = 3
const SHOOT_COOLDOWN = 0.2

const BULLET = preload("res://scenes/game/bullet.tscn")

@onready var sprite_2d = $Sprite2D
@onready var sfx_death = $"Audio Node 2D/sfx_death"
@onready var sfx_respawn = $"Audio Node 2D/sfx_respawn"
@onready var sfx_shoot_1 = $"Audio Node 2D/sfx_shoot1"
@onready var health_bar = $HealthBar
@onready var muzzle = $GunContainer/GunSprite/Muzzle

@onready var game = get_node("/root/game")



var health = MAX_HEALTH
var facing_left = false
var can_shoot = true
var joystick_connected = false

func _enter_tree():
	set_multiplayer_authority(int(str(name)))

func _ready():
	cam = $Camera2D
	
	if is_multiplayer_authority():
		$"CanvasLayer/Control/Aim Joystick".visible = true
		call_deferred("_connect_joystick")
		cam.enabled = true
		cam.make_current()
	else:
		print("Disabling joystick for remote player:", name)
		var aim_joystick = $"CanvasLayer/Control/Aim Joystick"
		aim_joystick.visible = false
		aim_joystick.set_process_input(false)
		aim_joystick.set_process(false)
		sprite_2d.modulate = Color.RED
		health_bar.visible = false
		cam.enabled = false

func _connect_joystick():
	var aim_joystick = $"CanvasLayer/Control/Aim Joystick"
	if aim_joystick and not joystick_connected:
		aim_joystick.connect("shoot", Callable(self, "_on_AimJoystick_shoot"))
		joystick_connected = true
		print(" Joystick signal connected via call_deferred →", name)
	else:
		print("Joystick not found or already connected →", name)

func _on_AimJoystick_shoot(direction: Vector2):
	print(" Joystick SHOOT signal received on", name, "| authority?", is_multiplayer_authority())
	shoot_in_direction(direction)

func shoot_in_direction(direction: Vector2) -> void:
	if not can_shoot:
		print(" Can't shoot — on cooldown →", name)
		return

	print("SHOOTING from", name, "| Direction:", direction)
	can_shoot = false

	if is_multiplayer_authority():
		var pos = muzzle.global_position
		var rot = direction.angle()
		print("Spawning bullet from", name, "at", pos, "| angle:", rot)
		spawn_bullet.rpc(pos, rot, multiplayer.get_unique_id())
	else:
		print(" Not authority in shoot_in_direction →", name)

	await get_tree().create_timer(SHOOT_COOLDOWN).timeout
	can_shoot = true

var last_direction = 1  # 1 = right, -1 = left
func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return	

	$GunContainer.look_at(get_global_mouse_position())

	if get_global_mouse_position().x < global_position.x:
		$GunContainer/GunSprite.flip_v = true
	else:
		$GunContainer/GunSprite.flip_v = false

	if not is_on_floor():
		velocity += get_gravity() * delta
		sprite_2d.animation = "jumping"
	elif abs(velocity.x) > 1:
		sprite_2d.animation = "running"
		if not $"Audio Node 2D/sfx_run".playing:
			$"Audio Node 2D/sfx_run".play()
	else:
		sprite_2d.animation = "idle"

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		last_direction = direction  # store the last movement direction
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	sprite_2d.flip_h = last_direction < 0  # face left if last direction was left

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		$"Audio Node 2D/sfx_jump".play()

func set_camera_limits(left: int, right: int, top: int, bottom: int):
	cam.limit_left = left
	cam.limit_right = right
	cam.limit_top = top
	cam.limit_bottom = bottom

@rpc("call_local")
func spawn_bullet(pos: Vector2, rot: float, shooter_pid: int):
	$"Audio Node 2D/sfx_shoot1".play()
	print("🛠 Bullet spawned on", name, "| Owner:", shooter_pid, "| pos:", pos, "| rot:", rot)
	var bullet = BULLET.instantiate()
	bullet.set_multiplayer_authority(shooter_pid)
	bullet.global_position = pos
	bullet.rotation = rot
	get_parent().add_child(bullet)

@rpc("any_peer")
func take_damage(amount):
	print("💥", name, "took damage:", amount)
	health -= amount
	health_bar.value = health

	if health <= 0:
		print("☠️", name, "died")
		sync_hide.rpc()
		sfx_death.play()
		set_physics_process(false)
		$CollisionShape2D.disabled = true

		await get_tree().create_timer(RESPAWN_TIME).timeout

		health = MAX_HEALTH
		
		if Globals.current_map ==0:
			global_position = game.get_random_spawnpoint()
		elif Globals.current_map == 1:
			global_position = game.get_random_map1_spawnpoint()
		elif Globals.current_map == 2:
			global_position = game.get_random_map2_spawnpoint()
		

		sync_respawn.rpc(global_position)

@rpc("call_local")
func sync_hide():
	hide()
	set_physics_process(false)
	$CollisionShape2D.disabled = true



@rpc("call_local")
func sync_respawn(pos: Vector2):
	print(name,"  respawned at ", Globals.current_map)
	global_position = pos
	health = MAX_HEALTH
	health_bar.value = health
	show()
	set_physics_process(true)
	$CollisionShape2D.disabled = false
	sfx_respawn.play()
	
	
func reset_on_teleport():
	velocity = Vector2.ZERO
	if is_multiplayer_authority():
		cam.make_current()

@rpc("authority")
func rpc_teleport_to_position(pos: Vector2):
	teleport_to_position(pos)

func teleport_to_position(pos: Vector2):
	global_position = pos
	reset_on_teleport()
