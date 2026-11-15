class_name WakeWordDetector
extends RefCounted

const WAKE_PHRASE := "hi anna"

signal wake_word_detected

func process_transcript(transcript: String) -> bool:
	var normalized := transcript.strip_edges().to_lower()
	if normalized == WAKE_PHRASE:
		wake_word_detected.emit()
		return true
	return false

func get_integration_hint() -> String:
	return "Connect an offline speech-to-text model and pass its transcript to process_transcript()."
