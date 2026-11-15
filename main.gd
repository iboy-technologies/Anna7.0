extends Control

const USERS_PATH := "user://users.json"
const SESSION_PATH := "user://session.json"

@onready var username_input: LineEdit = $Panel/Form/Username
@onready var email_input: LineEdit = $Panel/Form/Email
@onready var message: Label = $Panel/Form/Message

var users: Dictionary = {}

func _ready() -> void:
	users = _load_users()
	if _has_valid_session():
		get_tree().change_scene_to_file("res://home.tscn")
		return
	$Panel/Form/Continue.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	var username := username_input.text.strip_edges()
	var email := email_input.text.strip_edges()
	if username.is_empty() or email.is_empty():
		message.text = "Enter both a username and email."
		return

	if users.has(username):
		if _save_session(username):
			get_tree().change_scene_to_file("res://home.tscn")
		else:
			message.text = "Could not save your login session."
		return

	users[username] = {"email": email}
	if _save_users() and _save_session(username):
		get_tree().change_scene_to_file("res://home.tscn")
	else:
		message.text = "Could not save your account."

func _load_users() -> Dictionary:
	if not FileAccess.file_exists(USERS_PATH):
		return {}
	var file := FileAccess.open(USERS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _save_users() -> bool:
	var file := FileAccess.open(USERS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(users))
	return true

func _has_valid_session() -> bool:
	if not FileAccess.file_exists(SESSION_PATH):
		return false
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return false
	var session = JSON.parse_string(file.get_as_text())
	return session is Dictionary and users.has(str(session.get("username", "")))

func _save_session(username: String) -> bool:
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"username": username}))
	return true
