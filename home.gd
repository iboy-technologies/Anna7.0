extends Control

const SESSION_PATH := "user://session.json"
const DEVICES_PATH := "user://devices.json"
const LAN_PORT := 24567

@onready var wake_status: Label = $WakeStatus
@onready var vad_listener: VadWakeListener = $VadWakeListener
@onready var voice_recognizer: GdVoskSpeechRecognizer = $GdVoskSpeechRecognizer
@onready var message_input: LineEdit = $ChatPanel/ChatLayout/Composer/Input
@onready var messages: VBoxContainer = $ChatPanel/ChatLayout/MessageScroll/Messages
@onready var device_list: ItemList = $DevicesPanel/DevicesLayout/List
@onready var device_status: Label = $DevicesPanel/DevicesLayout/Status

var _peer: ENetMultiplayerPeer
var _devices: Dictionary = {}
var _local_device_id := ""
var _conversation: Array[Dictionary] = []
var _switching_to_peer := 0

func _ready() -> void:
	$Welcome.text = "Welcome to Anna7.0"
	$Logout.pressed.connect(_on_logout_pressed)
	$ChatPanel/ChatLayout/Composer/Send.pressed.connect(_send_message)
	message_input.text_submitted.connect(_on_message_submitted)
	$ChatPanel/ChatLayout/Voice.pressed.connect(_toggle_voice_input)
	voice_recognizer.status_changed.connect(_on_voice_status_changed)
	voice_recognizer.error_occurred.connect(_on_voice_error)
	voice_recognizer.final_transcript.connect(_on_voice_transcript)
	_add_message("Hi! I’m Anna. How can I help?", false)
	$DevicesPanel/DevicesLayout/Host.pressed.connect(_host_lan)
	$DevicesPanel/DevicesLayout/Connect.pressed.connect(_connect_lan)
	$DevicesPanel/DevicesLayout/Command.pressed.connect(_send_selected_command)
	$DevicesPanel/DevicesLayout/Handoff.pressed.connect(_handoff_conversation)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_local_device_id = _get_device_id()
	_load_known_devices()
	vad_listener.status_changed.connect(_on_vad_status_changed)
	vad_listener.wake_word_detected.connect(_on_wake_word_detected)

func _on_logout_pressed() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	get_tree().change_scene_to_file("res://main.tscn")

func _on_vad_status_changed(status: String) -> void:
	wake_status.text = status

func _on_wake_word_detected() -> void:
	wake_status.text = "Hi Anna heard."

func _on_message_submitted(_text: String) -> void:
	_send_message()

func _send_message() -> void:
	var text := message_input.text.strip_edges()
	if text.is_empty():
		return
	_add_message(text, true)
	_conversation.append({"text": text, "from_user": true})
	message_input.clear()
	_add_message("I received your message: \"%s\"" % text, false)
	_conversation.append({"text": "I received your message: \"%s\"" % text, "from_user": false})

func _toggle_voice_input() -> void:
	if voice_recognizer.is_listening():
		voice_recognizer.stop_listening()
		$ChatPanel/ChatLayout/Voice.text = "Start voice input"
	else:
		voice_recognizer.start_listening()
		$ChatPanel/ChatLayout/Voice.text = "Stop voice input" if voice_recognizer.is_listening() else "Start voice input"

func _on_voice_status_changed(status: String) -> void:
	$ChatPanel/ChatLayout/VoiceStatus.text = status

func _on_voice_error(error_message: String) -> void:
	$ChatPanel/ChatLayout/VoiceStatus.text = "Voice error: %s" % error_message
	$ChatPanel/ChatLayout/Voice.text = "Start voice input"

func _on_voice_transcript(text: String) -> void:
	message_input.text = text
	_send_message()

func _add_message(text: String, from_user: bool) -> void:
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if from_user else Control.SIZE_SHRINK_BEGIN
	bubble.custom_minimum_size = Vector2(260, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#315b8f") if from_user else Color("#38504a")
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	bubble.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(236, 0)
	label.add_theme_color_override("font_color", Color("#ffffff"))
	bubble.add_child(label)
	messages.add_child(bubble)
	await get_tree().process_frame
	$ChatPanel/ChatLayout/MessageScroll.scroll_vertical = $ChatPanel/ChatLayout/MessageScroll.get_v_scroll_bar().max_value

func _host_lan() -> void:
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(LAN_PORT)
	if error != OK:
		device_status.text = "LAN host error: %s" % error_string(error)
		return
	multiplayer.multiplayer_peer = _peer
	_register_local_device(1)
	device_status.text = "LAN host ready on port %d (local network only)" % LAN_PORT

func _connect_lan() -> void:
	var address := $DevicesPanel/DevicesLayout/Address.text.strip_edges()
	if address.is_empty():
		device_status.text = "Enter the host's LAN IP address."
		return
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address, LAN_PORT)
	if error != OK:
		device_status.text = "LAN connection error: %s" % error_string(error)
		return
	multiplayer.multiplayer_peer = _peer
	device_status.text = "Connecting to %s:%d..." % [address, LAN_PORT]

func _register_local_device(peer_id: int) -> void:
	var info := {"username": _get_username(), "device_id": _local_device_id, "peer_id": peer_id}
	_devices[peer_id] = info
	_save_known_devices()
	_refresh_device_list()
	if peer_id != 1 and multiplayer.is_server():
		_register_device.rpc_id(1, info)

@rpc("any_peer", "reliable")
func _register_device(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	info["peer_id"] = sender
	_devices[sender] = info
	_save_known_devices()
	_refresh_device_list()
	_broadcast_devices.rpc(_devices)

@rpc("authority", "call_local", "reliable")
func _broadcast_devices(devices: Dictionary) -> void:
	_devices = devices
	_refresh_device_list()

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_broadcast_devices.rpc(_devices)
	else:
		_register_device.rpc_id(1, {"username": _get_username(), "device_id": _local_device_id})
	device_status.text = "LAN peer connected: %d" % peer_id

func _on_peer_disconnected(peer_id: int) -> void:
	_devices.erase(peer_id)
	_refresh_device_list()
	device_status.text = "LAN peer disconnected: %d" % peer_id

func _refresh_device_list() -> void:
	device_list.clear()
	for peer_id in _devices:
		var info: Dictionary = _devices[peer_id]
		device_list.add_item("%s (peer %s)" % [info.get("username", "unknown"), peer_id])
		device_list.set_item_metadata(device_list.item_count - 1, peer_id)

func _send_selected_command() -> void:
	var peer_id := _selected_peer_id()
	if peer_id == 0:
		device_status.text = "Select a connected device first."
		return
	_send_command.rpc_id(peer_id, "Ping from %s" % _get_device_id())
	device_status.text = "Command sent to peer %d." % peer_id

@rpc("any_peer", "reliable")
func _send_command(command: String) -> void:
	device_status.text = "Command received: %s" % command

func _handoff_conversation() -> void:
	var peer_id := _selected_peer_id()
	if peer_id == 0:
		device_status.text = "Select a connected device first."
		return
	if not multiplayer.has_multiplayer_peer():
		device_status.text = "Switch failed: no LAN connection."
		return
	_switching_to_peer = peer_id
	var device_name := _device_name(peer_id)
	device_status.text = "Switching to device %s..." % device_name
	_switch_conversation.rpc_id(peer_id, {"messages": _conversation}, _local_device_id)

@rpc("any_peer", "reliable")
func _switch_conversation(payload: Dictionary, sender_device_id: String) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	_conversation.clear()
	for child in messages.get_children():
		child.queue_free()
	for entry in payload.get("messages", []):
		var item: Dictionary = entry
		_conversation.append(item)
		_add_message(str(item.get("text", "")), bool(item.get("from_user", false)))
	device_status.text = "Connected from device %s. Conversation received." % sender_device_id
	var sender_peer_id := multiplayer.get_remote_sender_id()
	_switch_acknowledged.rpc_id(sender_peer_id, _local_device_id)

@rpc("any_peer", "reliable")
func _switch_acknowledged(receiver_device_id: String) -> void:
	if _switching_to_peer == 0:
		return
	device_status.text = "Device %s acknowledged the connection. Closing this device..." % receiver_device_id
	_switching_to_peer = 0
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func _device_name(peer_id: int) -> String:
	var info: Dictionary = _devices.get(peer_id, {})
	return str(info.get("username", "peer %d" % peer_id))

func _selected_peer_id() -> int:
	var selected := device_list.get_selected_items()
	if selected.is_empty():
		return 0
	return int(device_list.get_item_metadata(selected[0]))

func _get_username() -> String:
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return "unknown"
	var session = JSON.parse_string(file.get_as_text())
	return str(session.get("username", "unknown")) if session is Dictionary else "unknown"

func _get_device_id() -> String:
	var unique_id := OS.get_unique_id()
	return unique_id if not unique_id.is_empty() else str(Time.get_unix_time_from_system())

func _load_known_devices() -> void:
	if not FileAccess.file_exists(DEVICES_PATH):
		return
	var file := FileAccess.open(DEVICES_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file else {}
	if parsed is Dictionary:
		_devices = parsed
	_refresh_device_list()

func _save_known_devices() -> void:
	var file := FileAccess.open(DEVICES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_devices))
