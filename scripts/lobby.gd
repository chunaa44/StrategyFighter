extends Control

@onready var host_button = $Center/Card/Box/HostButton
@onready var ip_edit = $Center/Card/Box/IpEdit
@onready var join_button = $Center/Card/Box/JoinButton
@onready var local_button = $Center/Card/Box/LocalButton
@onready var status_label = $Center/Card/Box/StatusLabel


func _ready():
	host_button.pressed.connect(on_host_pressed)
	join_button.pressed.connect(on_join_pressed)
	local_button.pressed.connect(on_local_pressed)
	Network.connection_failed.connect(on_connection_failed)

	status_label.text = Network.status_message
	Network.status_message = ""


func on_host_pressed():
	var error = Network.host()
	if error != OK:
		status_label.text = "Could not host, is the game already running?"
		return
	status_label.text = "Waiting for opponent...\nYour IP: " + ", ".join(Network.local_ips())


func on_join_pressed():
	var ip = ip_edit.text.strip_edges()
	if ip == "":
		status_label.text = "Type the host's IP first"
		return
	var error = Network.join(ip)
	if error != OK:
		status_label.text = "Could not connect to " + ip
		return
	status_label.text = "Connecting to " + ip + "..."


func on_local_pressed():
	Network.start_local()


func on_connection_failed():
	status_label.text = "Could not reach the host"
