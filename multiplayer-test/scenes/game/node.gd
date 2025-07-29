class_name Game #for simplifications (like type hints)
extends Node

@export var match_duration := 15 # seconds
var match_time_left := match_duration
var match_timer := Timer.new()

@onready var multiplayer_ui = $UI/Multiplayer
@onready var host_ip_label = $UI/HostIPLabel
@onready var game_timer_label = $UI/GameTimer
@onready var ScoreboardBox = $UI/ScoreboardBox
@onready var MapSelection = $UI/MapSelection

const PLAYER = preload("res://scenes/game/player.tscn")

var peer = ENetMultiplayerPeer.new()
var players: Array[Player] = []
var player_stats := {} # Dictionary: peer_id -> {kills, deaths}

func _ready():
	add_to_group("Game")
	$MultiplayerSpawner.spawn_function = add_player
	host_ip_label.hide()   #hides ip label for clients 
	ScoreboardBox.visible = false 
	MapSelection.visible = false
	multiplayer_ui.visible = true
	
	
# Get Valid LAN IP (Android + PC)
func get_valid_lan_ip() -> String:
	var valid_ips = []
	for ip in IP.get_local_addresses():
		if ip.is_valid_ip_address() and not ip.begins_with("127.") and ip.find(":") == -1:
			if ip.begins_with("192.") or ip.begins_with("10.") or ip.begins_with("172."):
				valid_ips.append(ip)

	if valid_ips.size() > 0:
		print("Valid LAN IPs: ", valid_ips)
		return valid_ips[0]
	else:
		print("No valid LAN IP found. All IPs: ", IP.get_local_addresses())
		return "IP_NOT_FOUND"

func update_match_timer():
	match_time_left -= 1
	update_timer_label.rpc("⏱️ " + str(match_time_left))

	if match_time_left <= 0:
		match_timer.stop()
		game_timer_label.hide()
		host_ip_label.hide()
		
		# 🎮 Hide joysticks from the local player
		var pid = get_safe_unique_id()
		if pid != -1:
			var player_node = get_node_or_null(str(pid))
			if player_node:
				var joystick_path = "CanvasLayer/Control"
				var joystick_container = player_node.get_node_or_null(joystick_path)
				if joystick_container:
					# Hide both joysticks
					if joystick_container.has_node("Virtual Joystick"):
						joystick_container.get_node("Virtual Joystick").visible = false
					if joystick_container.has_node("Aim Joystick"):
						joystick_container.get_node("Aim Joystick").visible = false
						
		hide_local_player_ui.rpc()
		
		show_scoreboard(player_stats) # ← Local call for host
		show_scoreboard.rpc(player_stats) # ← RPC for clients	
		
		
@rpc("authority", "reliable")
func hide_local_player_ui():
	var pid = get_safe_unique_id()
	if pid != -1:
		var player_node = get_node_or_null(str(pid))
		if player_node:
			var joystick_path = "CanvasLayer/Control"
			var joystick_container = player_node.get_node_or_null(joystick_path)
			if joystick_container:
				if joystick_container.has_node("Virtual Joystick"):
					joystick_container.get_node("Virtual Joystick").visible = false
				if joystick_container.has_node("Aim Joystick"):
					joystick_container.get_node("Aim Joystick").visible = false
		
@rpc("authority", "call_local")
func update_timer_label(text: String):
	game_timer_label.text = text
	game_timer_label.show()
	


@rpc("reliable")
func show_scoreboard(stats: Dictionary):
	var container = $UI/ScoreboardBox/PlayerStatsContainer
	
	if not is_instance_valid(container):
		push_error("PlayerStatsContainer missing!")
		return

	# Keep header, delete dynamic rows
	for child in container.get_children():
		child.queue_free()

	# ➕ Add Header Row
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 40)

	var player_header = Label.new()
	player_header.text = "Player"
	player_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_header.custom_minimum_size = Vector2(200, 0)
	player_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_header.add_theme_color_override("font_color", Color.SKY_BLUE)

	var kills_header = Label.new()
	kills_header.text = "Kills"
	kills_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kills_header.custom_minimum_size = Vector2(80, 0)
	kills_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_header.add_theme_color_override("font_color", Color.SKY_BLUE)

	var deaths_header = Label.new()
	deaths_header.text = "Deaths"
	deaths_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deaths_header.custom_minimum_size = Vector2(80, 0)
	deaths_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deaths_header.add_theme_color_override("font_color", Color.SKY_BLUE)

	header.add_child(player_header)
	header.add_child(kills_header)
	header.add_child(deaths_header)
	container.add_child(header)

	# Track max kills for winner
	var max_kills = -1
	var winners = []

	
	for pid in stats.keys():
		var data = stats[pid]
		var kills = data["kills"]

		# Update winner tracking
		if kills > max_kills:
			max_kills = kills
			winners = [pid]
		elif kills == max_kills:
			winners.append(pid)

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 40)

		var name_label = Label.new()
		name_label.text = "Player %s" % str(pid)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size = Vector2(200, 0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", Color.WHITE)

		var kill_label = Label.new()
		kill_label.text = str(data["kills"])
		kill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kill_label.custom_minimum_size = Vector2(80, 0)
		kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kill_label.add_theme_color_override("font_color", Color.GREEN)

		var death_label = Label.new()
		death_label.text = str(data["deaths"])
		death_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		death_label.custom_minimum_size = Vector2(80, 0)
		death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		death_label.add_theme_color_override("font_color", Color.RED)

		row.add_child(name_label)
		row.add_child(kill_label)
		row.add_child(death_label)
		container.add_child(row)
	
	# 🏆 Show winner
	var winner_label = Label.new()
	winner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 20)
	winner_label.add_theme_color_override("font_color", Color.YELLOW)

	if winners.size() == 1:
		winner_label.text = "🏆 Winner: Player %s " % [str(winners[0])]
	else:
		var names = []
		for pid in winners:
			names.append("Player %s" % str(pid))
		winner_label.text = "🏆 Tie! %s " % [", ".join(names)]

	container.add_child(winner_label)

	$UI/ScoreboardBox.show()

func start_match():
	match_time_left = match_duration
	game_timer_label.text = "⏱️ " + str(match_time_left)
	game_timer_label.show()

	match_timer.wait_time = 1
	match_timer.timeout.connect(update_match_timer)
	match_timer.autostart = true
	match_timer.one_shot = false
	if match_timer.get_parent():
		match_timer.queue_free()
		match_timer = Timer.new()
	add_child(match_timer)
	match_timer.start()
	

# HOST
func _on_host_pressed() -> void:
	$sound_click.play()
	print("🎮 GAME HOSTED")
	MapSelection.visible = true
	

	peer.create_server(8848)
	multiplayer.multiplayer_peer = peer

	multiplayer.peer_connected.connect(func(pid):
		print(" PLAYER JOINED: ", pid)
		$MultiplayerSpawner.spawn(pid)
	)

	multiplayer.peer_disconnected.connect(func(pid):
		print("PLAYER LEFT: ", pid)
		var player_node = get_node_or_null(str(pid))
		if player_node:
			player_node.queue_free()
			players = players.filter(func(p): return p.name != str(pid))
	)

	$MultiplayerSpawner.spawn(multiplayer.get_unique_id())

	# 🖥 Show Host IP
	var ip = get_valid_lan_ip()
	print(" Host LAN IP: ", ip)
	host_ip_label.text = " IP not found!" if ip == "IP_NOT_FOUND" else "📡 Your IP: " + ip
	host_ip_label.show()

	multiplayer_ui.hide()
	
#  JOIN
func _on_join_pressed() -> void:
	$sound_click.play()
	$UI/MapSelection.hide()  # hide map selection for client players

	var input_field = multiplayer_ui.get_node("VBoxContainer/HostIPField")
	var ip_address = input_field.text.strip_edges()
	if ip_address == "":
		ip_address = "192.168.1.67"  # Fallback for test

	print("🔌 Connecting to host at: ", ip_address)

	peer.create_client(ip_address, 8848)
	multiplayer.multiplayer_peer = peer

	multiplayer.peer_disconnected.connect(func(pid):
		print("❌ PLAYER LEFT: ", pid)
		var player_node = get_node_or_null(str(pid))
		if player_node:
			player_node.queue_free()
			players = players.filter(func(p): return p.name != str(pid))
	)

	multiplayer.server_disconnected.connect(
		func():
		print("🔌 Disconnected from host")
		show_host_disconnected_message()
	)

	multiplayer_ui.hide()
	host_ip_label.hide() 

func register_kill(killer_id: int):
	if !player_stats.has(killer_id): return
	player_stats[killer_id]["kills"] += 1
	print("✅ REGISTERED KILL - ID:", killer_id, " → ", player_stats[killer_id])
	
func register_death(pid: int):
	if !player_stats.has(pid): return
	player_stats[pid]["deaths"] += 1

@rpc("any_peer")
func request_damage(target_id: int, damage: int, shooter_id: int):
	var target_player = get_node_or_null(str(target_id))
	if target_player and target_player.has_method("take_damage"):
		print("📦 Server applying", damage, "damage to", target_id, "from", shooter_id)
		target_player.take_damage(damage, shooter_id)
	else:
		print("❌ Failed to find target:", target_id)

# SPAWN PLAYER
func add_player(pid):
	$sfx_join.play()
	var player = PLAYER.instantiate()
	player.name = str(pid)
	player.set_multiplayer_authority(pid)
	player.global_position = $TextureRect1/Lobby.get_child(players.size()).global_position
	players.append(player)
	player_stats[pid] = {"kills": 0, "deaths": 0}
	
	add_child(player)
	return player


#  Get Safe Unique ID
func get_safe_unique_id():
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return -1


# Host Disconnected Popup

func show_host_disconnected_message():
	var popup = AcceptDialog.new()
	popup.dialog_text = "Host disconnected. Returning to menu."
	add_child(popup)
	popup.popup_centered()

	popup.confirmed.connect(func():
		get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
	)


# BACK Button

func _on_back_pressed() -> void:
	AudioManager.click_sound()
	var pid = get_safe_unique_id()
	if pid != -1:
		var player_node = get_node_or_null(str(pid))
		if player_node:
			player_node.queue_free()

	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
	AudioManager.play_music()


## Random Spawn Points for respawn

func get_random_spawnpoint():
	return $TextureRect1/Lobby.get_children().pick_random().get_position()


func get_local_player():
	for player in get_tree().get_nodes_in_group("Player"):
		if player.get_multiplayer_authority() == multiplayer.get_unique_id():
			return player
	return null

#Teleport to map1

@rpc("any_peer", "call_local")
func teleport_all_players_to_map1():
	Globals.current_map = 1
	print("Map 1 was pressed via RPC")
	print("Current Map : " + str(Globals.current_map))

	var local_player: Player = get_local_player()
	if local_player:
		var spawn_points1 = [
			$TextureRect3/Map1/Map1Spawn1,
			$TextureRect3/Map1/Map1Spawn2,
			$TextureRect3/Map1/Map1Spawn3,
			$TextureRect3/Map1/Map1Spawn4,
			$TextureRect3/Map1/Map1Spawn5
		]
		var spawn: Marker2D = spawn_points1.pick_random()
		local_player.rpc_teleport_to_position(spawn.global_position)

func _on_map_1_pressed() -> void:
	AudioManager.click_sound()
	rpc("teleport_all_players_to_map1")
	start_match()
	$UI/MapSelection.hide()
	
# Teleport to map2
@rpc("any_peer","call_local")  #any_peer for clients  #call_local for host device
func teleport_all_players_to_map2():
	Globals.current_map = 2
	print("Map 2 was pressed via RPC")
	print("Current Map : " + str(Globals.current_map))

	var local_player: Player = get_local_player()
	if local_player:
		var spawn_points2 = [
			$TextureRect2/Map2/Map2Spawn1,
			$TextureRect2/Map2/Map2Spawn2,
			$TextureRect2/Map2/Map2Spawn3,
			$TextureRect2/Map2/Map2Spawn4,
			$TextureRect2/Map2/Map2Spawn5
		]
		var spawn: Marker2D = spawn_points2.pick_random()
		local_player.rpc_teleport_to_position(spawn.global_position)

func _on_map_2_pressed() -> void:
	AudioManager.click_sound()
	rpc("teleport_all_players_to_map2")
	start_match()
	$UI/MapSelection.hide()
			
			
func get_random_map1_spawnpoint():
	print("Respawn Updated to map2")
	var spawn_points1 = [
			$TextureRect3/Map1/Map1Spawn1,
			$TextureRect3/Map1/Map1Spawn2,
			$TextureRect3/Map1/Map1Spawn3,
			$TextureRect3/Map1/Map1Spawn4,
			$TextureRect3/Map1/Map1Spawn5
		]
	var spawn: Marker2D = spawn_points1.pick_random()
	return spawn.global_position
			
func get_random_map2_spawnpoint():
	print("Respawn Updated to map2")
	var spawn_points2 = [
		$TextureRect2/Map2/Map2Spawn1,
		$TextureRect2/Map2/Map2Spawn2,
		$TextureRect2/Map2/Map2Spawn3,
		$TextureRect2/Map2/Map2Spawn4,
		$TextureRect2/Map2/Map2Spawn5
	]
	var spawn: Marker2D = spawn_points2.pick_random()
	return spawn.global_position





func _on_map_1_visibility_changed() -> void:
	pass # Replace with function body.


func _on_map_2_visibility_changed() -> void:
	pass # Replace with function body.
