extends Object

# Native implementation contract:
# - Expose a VoskStt singleton with start_listening(model_path) and stop_listening().
# - Emit partial_transcript(text), final_transcript(text), status_changed(status), and error(message).
# - Capture 16 kHz mono PCM with Android AudioRecord and feed Vosk Recognizer.
# See VOSK_ANDROID.md for the model and Android build integration steps.
