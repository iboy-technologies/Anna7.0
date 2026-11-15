class_name VadWakeListener
extends Node

const BUS_NAME := "AnnaMicrophone"
const SAMPLE_FRAMES := 512
const RMS_THRESHOLD := 0.02

signal voice_activity_changed(active: bool)
signal status_changed(status: String)
signal wake_word_detected

var _capture: AudioEffectCapture
var _microphone: AudioStreamPlayer
var _detector := WakeWordDetector.new()
var _voice_active := false

func _ready() -> void:
	_detector.wake_word_detected.connect(func() -> void: wake_word_detected.emit())
	_setup_microphone()

func _process(_delta: float) -> void:
	if _capture == null:
		return
	var frames := _capture.get_buffer(SAMPLE_FRAMES)
	if frames.is_empty():
		return

	var peak := 0.0
	for frame in frames:
		peak = max(peak, max(abs(frame.x), abs(frame.y)))
	var active := peak >= RMS_THRESHOLD
	if active != _voice_active:
		_voice_active = active
		voice_activity_changed.emit(active)
		status_changed.emit("Voice detected. Listening for \"Hi Anna\"..." if active else "Listening for \"Hi Anna\"...")

func submit_transcript(transcript: String) -> bool:
	return _detector.process_transcript(transcript)

func _setup_microphone() -> void:
	var bus_index := AudioServer.get_bus_index(BUS_NAME)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, BUS_NAME)
	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus_index, _capture)

	_microphone = AudioStreamPlayer.new()
	_microphone.stream = AudioStreamMicrophone.new()
	_microphone.bus = BUS_NAME
	add_child(_microphone)
	_microphone.play()
	status_changed.emit("Listening for \"Hi Anna\"...")
