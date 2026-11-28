extends Node

signal connection_failed
signal pick_received
signal restart_received

const PORT = 7777
const LOBBY_SCENE = "res://scenes/lobby.tscn"
const MAIN_SCENE = "res://scenes/main.tscn"

# 0 for a local game, 1 for the host, 2 for the player who joined
var my_player = 0
# shown by the lobby the next time it opens
var status_message = ""

# a pick can arrive before the pick screen is ready for it, so it waits here
var opponent_pick = {}
var opponent_pick_ready = false


func _ready():
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	multiplayer.connection_failed.connect(on_connection_failed)
	multiplayer.server_disconnected.connect(on_server_disconnected)


func is_online():
	return my_player != 0


func host():
	close()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 1)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	my_player = 1
	return OK


func join(ip):
	close()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, PORT)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	my_player = 2
	return OK


func start_local():
	close()
	get_tree().change_scene_to_file(MAIN_SCENE)


# player number is cleared first so the disconnect signals of the closing peer are ignored
func close():
	my_player = 0
	opponent_pick = {}
	opponent_pick_ready = false
	var peer = multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = null


# local addresses of this computer, the joining player needs one of them
func local_ips():
	var result = []
	for address in IP.get_local_addresses():
		if address.contains(":"):
			continue
		if address.begins_with("127.") or address.begins_with("169.254."):
			continue
		result.append(address)
	return result


func leave_match(message):
	if not is_online():
		return
	close()
	status_message = message
	get_tree().change_scene_to_file(LOBBY_SCENE)


# the host starts the match for both players as soon as the opponent is in
func on_peer_connected(_id):
	if my_player != 1:
		return
	start_match.rpc()
	get_tree().change_scene_to_file(MAIN_SCENE)


# the peer is still polling while these signals fire, so closing it waits for the next frame
func on_peer_disconnected(_id):
	leave_match.call_deferred("Opponent disconnected")


func on_server_disconnected():
	leave_match.call_deferred("Host closed the game")


func on_connection_failed():
	fail_connection.call_deferred()


func fail_connection():
	close()
	connection_failed.emit()


@rpc("authority", "reliable")
func start_match():
	get_tree().change_scene_to_file(MAIN_SCENE)


func send_pick(pick):
	receive_pick.rpc(pick)


@rpc("any_peer", "reliable")
func receive_pick(pick):
	opponent_pick = pick
	opponent_pick_ready = true
	pick_received.emit()


func take_opponent_pick():
	var pick = opponent_pick
	opponent_pick = {}
	opponent_pick_ready = false
	return pick


func send_restart():
	receive_restart.rpc()


@rpc("any_peer", "reliable")
func receive_restart():
	restart_received.emit()
