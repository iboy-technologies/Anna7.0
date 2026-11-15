class_name VoskSttBridge
extends Node

signal partial_transcript(text: String)
signal final_transcript(text: String)
signal status_changed(status: String)
signal error_occurred(message: String)

const PLUGIN_NAME := "VoskStt"
const MODEL_HINT := "vosk-model-small-en-us"

var _plugin: Object
var _listening := false

func _ready() -> void:
	if not OS.has_feature("android") or not Engine.has_singleton(PLUGIN_NAME):
		status_changed.emit("Offline voice input is available on Android with the Vosk plugin.")
		return
	_plugin = Engine.get_singleton(PLUGIN_NAME)
	if _plugin.has_signal("partial_transcript"):
		_plugin.partial_transcript.connect(_on_partial_transcript)
	if _plugin.has_signal("final_transcript"):
		_plugin.final_transcript.connect(_on_final_transcript)
	if _plugin.has_signal("status_changed"):
		_plugin.status_changed.connect(_on_plugin_status)
	if _plugin.has_signal("error"):
		_plugin.error.connect(_on_plugin_error)
	status_changed.emit("Vosk ready. Bundled model: %s" % MODEL_HINT)

func start_listening() -> void:
	if _plugin == null:
		error_occurred.emit("Vosk Android plugin is not installed. %s" % MODEL_HINT)
		return
	if not _has_microphone_permission():
		OS.request_permission("android.permission.RECORD_AUDIO")
		status_changed.emit("Microphone permission requested.")
		return
	if _plugin.has_method("start_listening"):
		_plugin.start_listening(MODEL_HINT)
		_listening = true
		status_changed.emit("Listening with offline Vosk speech-to-text...")

func stop_listening() -> void:
	if _plugin != null and _plugin.has_method("stop_listening"):
		_plugin.stop_listening()
	_listening = false
	status_changed.emit("Voice input stopped.")

func is_listening() -> bool:
	return _listening

func _has_microphone_permission() -> bool:
	if not OS.has_feature("android"):
		return false
	return OS.get_granted_permissions().has("android.permission.RECORD_AUDIO")

func _on_partial_transcript(text: String) -> void:
	partial_transcript.emit(text)

func _on_final_transcript(text: String) -> void:
	final_transcript.emit(text)

func _on_plugin_status(status: String) -> void:
	status_changed.emit(status)

func _on_plugin_error(message: String) -> void:
	error_occurred.emit(message)
