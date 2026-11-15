# Offline Vosk speech-to-text on Android

The Godot project contains a small bridge (`vosk_stt_bridge.gd`) and an Android plugin contract under `android/plugins/vosk_stt/`. The bridge remains safe on desktop/editor builds and reports when the native plugin is unavailable.

## Model setup

The official small English model is bundled in this repository under:

`android/app/src/main/assets/vosk-model-small-en-us/`

It is the `vosk-model-small-en-us-0.15` model from the official Vosk models page. Its Apache 2.0 attribution is preserved in the model directory's `NOTICE` and `LICENSE-APACHE-2.0` files.

The Android plugin should load that directory and feed 16 kHz, mono PCM from `AudioRecord` into the Vosk recognizer.

## Native plugin contract

Register a Godot Android singleton named `VoskStt` with:

- `start_listening(model_path)`
- `stop_listening()`
- `partial_transcript(text)` signal
- `final_transcript(text)` signal
- `status_changed(status)` signal
- `error(message)` signal

The project requests `android.permission.RECORD_AUDIO` before starting. Final transcripts are forwarded into the existing chat as user messages and receive the normal local Anna response.
