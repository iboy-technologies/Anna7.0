class_name GdVoskSpeechRecognizer
extends Node

signal partial_transcript(text: String)
signal final_transcript(text: String)
signal status_changed(status: String)
signal error_occurred(message: String)

const RECORDING_BUS_NAME := "Record"
const MODEL_RESOURCE_PATH := "res://vosk-model-small-en-us-0.15.vosk"

var _recognizer: Object
var _microphone: AudioStreamPlayer
var _listening := false
var _model_configured := false

func _ready() -> void:
	if not ClassDB.can_instantiate("SpeechRecognizer"):
		status_changed.emit("gdvosk native library is unavailable. Voice input is disabled.")
		return

	_recognizer = ClassDB.instantiate("SpeechRecognizer")
	add_child(_recognizer)
	_recognizer.set("recording_bus_name", RECORDING_BUS_NAME)
	if ResourceLoader.exists(MODEL_RESOURCE_PATH):
		var model = load(MODEL_RESOURCE_PATH)
		_recognizer.set("vosk_model", model)
		_model_configured = true
	if _recognizer.has_signal("partial_result"):
		_recognizer.partial_result.connect(_on_partial_result)
	if _recognizer.has_signal("result"):
		_recognizer.result.connect(_on_result)
	if _model_configured:
		status_changed.emit("gdvosk ready.")
	else:
		status_changed.emit("gdvosk is installed, but no VoskModel resource is configured.")

func start_listening() -> void:
	if _recognizer == null:
		error_occurred.emit("Install the gdvosk native library before starting voice input.")
		return
	if not _model_configured:
		error_occurred.emit("Add a gdvosk VoskModel resource before starting voice input.")
		return
	if OS.has_feature("android") and not OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
		OS.request_permission("android.permission.RECORD_AUDIO")
		status_changed.emit("Microphone permission requested.")
		return
	_ensure_recording_bus()
	_microphone = AudioStreamPlayer.new()
	_microphone.stream = AudioStreamMicrophone.new()
	_microphone.bus = RECORDING_BUS_NAME
	add_child(_microphone)
	_microphone.play()
	_listening = true
	status_changed.emit("Listening with gdvosk...")

func stop_listening() -> void:
	if _microphone != null:
		_microphone.stop()
		_microphone.queue_free()
		_microphone = null
	_listening = false
	status_changed.emit("Voice input stopped.")

func is_listening() -> bool:
	return _listening

func _ensure_recording_bus() -> void:
	if AudioServer.get_bus_index(RECORDING_BUS_NAME) != -1:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, RECORDING_BUS_NAME)

func _on_partial_result(text: String) -> void:
	partial_transcript.emit(text)

func _on_result(_confidence: float, text: String) -> void:
	final_transcript.emit(text)
