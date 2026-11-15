class_name VoskSttBridge
extends Node

signal partial_transcript(text: String)
signal final_transcript(text: String)
signal status_changed(status: String)
signal error_occurred(message: String)

const PLUGIN_NAME := "VoskStt"
const MODEL_HINT := "vosk-model-small-en-us"
const WINDOWS_MODEL_PATH := "res://android/app/src/main/assets/vosk-model-small-en-us"

var _plugin: Object
var _listening := false
var _capture: AudioEffectCapture
var _microphone: AudioStreamPlayer

func _ready() -> void:
	if not OS.has_feature("android") and not OS.has_feature("windows"):
		status_changed.emit("Offline Vosk voice input is available on Android and Windows.")
		return
	if Engine.has_singleton(PLUGIN_NAME):
		_plugin = Engine.get_singleton(PLUGIN_NAME)
	elif OS.has_feature("windows") and ClassDB.can_instantiate("VoskSttWindows"):
		_plugin = ClassDB.instantiate("VoskSttWindows")
		add_child(_plugin)
	if _plugin == null:
		status_changed.emit("Vosk native plugin is unavailable on this build.")
		return
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
		error_occurred.emit("Vosk native plugin is not installed. %s" % MODEL_HINT)
		return
	if OS.has_feature("android") and not _has_microphone_permission():
		OS.request_permission("android.permission.RECORD_AUDIO")
		status_changed.emit("Microphone permission requested.")
		return
	if _plugin.has_method("start_listening"):
		var model_path := MODEL_HINT if OS.has_feature("android") else ProjectSettings.globalize_path(WINDOWS_MODEL_PATH)
		_plugin.start_listening(model_path)
		if OS.has_feature("windows"):
			_start_windows_microphone()
		_listening = true
		status_changed.emit("Listening with offline Vosk speech-to-text...")

func stop_listening() -> void:
	if _plugin != null and _plugin.has_method("stop_listening"):
		_plugin.stop_listening()
	_stop_windows_microphone()
	_listening = false
	status_changed.emit("Voice input stopped.")

func is_listening() -> bool:
	return _listening

func _has_microphone_permission() -> bool:
	if not OS.has_feature("android"):
		return false
	return OS.get_granted_permissions().has("android.permission.RECORD_AUDIO")

func _start_windows_microphone() -> void:
	var bus_index := AudioServer.get_bus_index("VoskMicrophone")
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, "VoskMicrophone")
	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus_index, _capture)
	_microphone = AudioStreamPlayer.new()
	_microphone.stream = AudioStreamMicrophone.new()
	_microphone.bus = "VoskMicrophone"
	add_child(_microphone)
	_microphone.play()

func _stop_windows_microphone() -> void:
	if _microphone != null:
		_microphone.stop()
		_microphone.queue_free()
		_microphone = null
	_capture = null

func _process(_delta: float) -> void:
	if not OS.has_feature("windows") or not _listening or _capture == null or _plugin == null:
		return
	var frames := _capture.get_buffer(512)
	if frames.is_empty() or not _plugin.has_method("accept_pcm"):
		return
	var pcm := PackedByteArray()
	pcm.resize(frames.size() * 2)
	for index in frames.size():
		var sample := clampi(roundi(frames[index].x * 32767.0), -32768, 32767)
		pcm.encode_s16(index * 2, sample)
	_plugin.accept_pcm(pcm)

func _on_partial_transcript(text: String) -> void:
	partial_transcript.emit(text)

func _on_final_transcript(text: String) -> void:
	final_transcript.emit(text)

func _on_plugin_status(status: String) -> void:
	status_changed.emit(status)

func _on_plugin_error(message: String) -> void:
	error_occurred.emit(message)
