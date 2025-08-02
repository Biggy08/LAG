class_name Player
extends CharacterBody2D

@onready var cam: Camera2D = $Camera2D

const SPEED = 300.0
const JUMP_VELOCITY = -500.0
const MAX_HEALTH = 100
var kills: int = 0
var deaths: int = 0
const RESPAWN_TIME = 3
const SHOOT_COOLDOWN = 0.2
var is_local_player := false
var base_gun_pos = Vector2.ZERO

const jump_pad_height: float = -500.0

# Ammo system
const MAX_AMMO = 10
const RELOAD_TIME = 2.0 

var current_ammo := MAX_AMMO
var is_reloading := false

const BULLET = preload("res://scenes/game/bullet.tscn")

@onready var sprite_2d = $Sprite2D
@onready var sfx_death = $"Audio Node 2D/sfx_death"
@onready var sfx_respawn = $"Audio Node 2D/sfx_respawn"
@onready var sfx_shoot_1 = $"Audio Node 2D/sfx_shoot1"
@onready var health_bar = $HealthBar
@onready var NameLabel = $NameLabel
@onready var muzzle = $GunContainer/GunSprite/Muzzle
@onready var game = get_node("/root/game")


var health = MAX_HEALTH
var facing_left = false
var can_shoot = true
var joystick_connected = false
var username: String = "Unnamed"

func _enter_tree():
	add_to_group("Player")
	set_multiplayer_authority(int(str(name)))
	

func _ready():
	cam = $Camera2D
	var my_id = str(multiplayer.get_unique_id())
	base_gun_pos = $GunContainer.position
	
	if name == my_id:
		is_local_player = true
		health_bar.visible = true
	else:
		is_local_player = false
		health_bar.visible = false

	# ✅ Display the username
	NameLabel.text = username

	if is_local_player:
		$"CanvasLayer/Control/Aim Joystick".visible = true
		call_deferred("_connect_joystick")
		cam.enabled = true
		cam.make_current()
		
		$CanvasLayer/Control/AmmoLabel.visible = true
		update_ammo_label()
	else:
		var aim_joystick = $"CanvasLayer/Control/Aim Joystick"
		aim_joystick.visible = false
		aim_joystick.set_process_input(false)
		aim_joystick.set_process(false)
		sprite_2d.modulate = Color.RED
		cam.enabled = false

func update_ammo_label():
	if not is_local_player: return
	var ammo_label = $"CanvasLayer/Control/AmmoLabel"
	if is_reloading:
		ammo_label.text = "Reloading..."
	else:
		ammo_label.text = "Ammo: %d / %d" % [current_ammo, MAX_AMMO]

func set_display_name(pname: String):
	username = pname
	NameLabel.text = username

@rpc("authority", "call_local")
func sync_username(pname: String):
	set_display_name(pname)

@rpc("call_local")
func update_name_label(pusername: String):
	NameLabel.text = pusername

func _connect_joystick():
	var aim_joystick = $"CanvasLayer/Control/Aim Joystick"
	if aim_joystick and not joystick_connected:
		aim_joystick.connect("shoot", Callable(self, "_on_AimJoystick_shoot"))
		joystick_connected = true
		#print(" Joystick signal connected via call_deferred →", name)
	else:
		print("Joystick not found or already connected →", name)

func _on_AimJoystick_shoot(direction: Vector2):
	#print(" Joystick SHOOT signal received on", name, "| authority?", is_multiplayer_authority())
	shoot_in_direction(direction)

func shoot_in_direction(direction: Vector2) -> void:
	if not can_shoot:
		#print(" Can't shoot — on cooldown →", name)
		return
		
	if current_ammo <= 0:
		reload()
		return

	#print("SHOOTING from", name, "| Direction:", direction)
	can_shoot = false
	current_ammo -= 1
	update_ammo_label()

	if is_multiplayer_authority():
		var pos = muzzle.global_position
		var rot = direction.angle()
		#print("Spawning bullet from", name, "at", pos, "| angle:", rot)
		spawn_bullet.rpc(pos, rot, multiplayer.get_unique_id())
	else:
		print(" Not authority in shoot_in_direction →", name)

	await get_tree().create_timer(SHOOT_COOLDOWN).timeout
	can_shoot = true

func reload():
	if is_reloading or current_ammo == MAX_AMMO:
		return

	is_reloading = true
	update_ammo_label()

	print("🔄 Reloading...")
	await get_tree().create_timer(RELOAD_TIME).timeout
	current_ammo = MAX_AMMO
	is_reloading = false
	update_ammo_label()
	print("✅ Reload complete")

var last_direction = 1  # 1 = right, -1 = left

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return	

	#$GunContainer.look_at(get_global_mouse_position())

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

	#sprite_2d.flip_h = last_direction < 0  # face left if last direction was left

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		$"Audio Node 2D/sfx_jump".play()


func _process(delta):
	if not is_local_player:
		return

	var aim_joystick = $"CanvasLayer/Control/Aim Joystick"
	if aim_joystick and aim_joystick.is_pressed:
		var aim_x = aim_joystick.output.x

		if aim_x < -0.1:
			facing_left = true
		elif aim_x > 0.1:
			facing_left = false

	sprite_2d.flip_h = facing_left
	$GunContainer/GunSprite.flip_h = facing_left
	var Muzzle = $GunContainer/GunSprite/Muzzle
	Muzzle.position.x = -abs(Muzzle.position.x) if facing_left else abs(Muzzle.position.x)
	# Oscillate gun container vertically with sine wave bobbing
	var bob_speed = 85.0
	var time = Time.get_ticks_msec() / bob_speed
	var bob = sin(time) * 2  # 2 pixels up/down
	$GunContainer.position = base_gun_pos + Vector2(0, bob)

	





		# No else: keep current facing if aim_x between -0.1 and 0.1



func set_camera_limits(left: int, right: int, top: int, bottom: int):
	cam.limit_left = left
	cam.limit_right = right
	cam.limit_top = top
	cam.limit_bottom = bottom
	




@rpc("call_local")
func spawn_bullet(pos: Vector2, rot: float, shooter_pid: int):
	$"Audio Node 2D/sfx_shoot1".play()
	#print("🛠 Bullet spawned on", name, "| Owner:", shooter_pid, "| pos:", pos, "| rot:", rot)
	var bullet = BULLET.instantiate()
	bullet.set_multiplayer_authority(shooter_pid)
	bullet.global_position = pos
	bullet.rotation = rot
	get_parent().add_child(bullet)
	
@rpc("any_peer", "call_local")
func update_health_bar(new_health: int):
	health = new_health
	health_bar.max_value = MAX_HEALTH  # make sure it's correct
	health_bar.value = health
	print("🩸 Health updated on", name, "→", new_health)
	print("🩸 Bar node info → max:", health_bar.max_value, "val:", health_bar.value, "visible:", health_bar.visible)

@rpc("any_peer")
func take_damage(amount: int, shooter_pid: int = -1):
	print("💥", name, "took damage:", amount)
	health -= amount
	update_health_bar.rpc_id(get_multiplayer_authority(), health)
	
	if health <= 0:
		sync_hide.rpc()
		sfx_death.play()
		if multiplayer.is_server():
			game.register_death(int(name))
		
		# Award kill to the shooter
		if shooter_pid != -1:
			var shooter = game.get_node_or_null(str(shooter_pid))
			if shooter and shooter.has_method("add_kill"):
				shooter.add_kill()
				

		set_physics_process(false)
		call_deferred("_disable_collision")

		await get_tree().create_timer(RESPAWN_TIME).timeout

		health = MAX_HEALTH
		update_health_bar.rpc_id(get_multiplayer_authority(), health)
		
		if Globals.current_map ==0:
			global_position = game.get_random_spawnpoint()
		elif Globals.current_map == 1:
			global_position = game.get_random_map1_spawnpoint()
		elif Globals.current_map == 2:
			global_position = game.get_random_map2_spawnpoint()
		

		sync_respawn.rpc(global_position)

func _disable_collision():
	$CollisionShape2D.disabled = true

@rpc("any_peer", "call_local")
func sync_hide():
	hide()
	set_physics_process(false)
	call_deferred("_disable_collision")



@rpc("any_peer", "call_local")
func sync_respawn(pos: Vector2):
	print(name,"  respawned at ", Globals.current_map)
	global_position = pos
	health = MAX_HEALTH
	update_health_bar(health)
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

func add_kill():
	if multiplayer.is_server():
		game.register_kill(int(name))
