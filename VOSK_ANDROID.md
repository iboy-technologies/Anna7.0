# Offline Vosk speech-to-text on Android

The Godot project contains a bridge (`vosk_stt_bridge.gd`) and a native Android plugin under `android/plugins/vosk_stt/`. The bridge remains safe on desktop/editor builds and reports when the native plugin is unavailable.

## Model setup

The official small English model is bundled in this repository under:

`android/app/src/main/assets/vosk-model-small-en-us/`

It is the `vosk-model-small-en-us-0.15` model from the official Vosk models page. Its Apache 2.0 attribution is preserved in the model directory's `NOTICE` and `LICENSE-APACHE-2.0` files.

The Android plugin copies that asset tree into the app's private files directory on first use and feeds 16 kHz, mono PCM from `AudioRecord` into the Vosk recognizer.

## Android build/export requirements

Build `android/plugins/vosk_stt` as an Android library and include it in the Godot Android export template. Its `build.gradle` depends on `com.alphacephei:vosk-android:0.3.45`; the export must have Maven Central access. The plugin class is `org.annasoftware.vosk.VoskSttPlugin` and registers the singleton named `VoskStt`.

The plugin manifest declares `android.permission.RECORD_AUDIO`. The app must target Android API 24 or newer. The model directory must be packaged into the exported APK at `assets/vosk-model-small-en-us/`; do not rename or flatten its files.

## Native plugin API

- `start_listening(model_path)`
- `stop_listening()`
- `partial_transcript(text)` signal
- `final_transcript(text)` signal
- `status_changed(status)` signal
- `error(message)` signal

The project and native plugin request `android.permission.RECORD_AUDIO` before starting. The Java worker emits partial and final results while capturing audio, and releases `AudioRecord`, `Recognizer`, and `Model` on stop or app shutdown. Final transcripts are forwarded into the existing chat as user messages and receive the normal local Anna response.

## Windows desktop build

Windows uses the GDExtension in `windows/vosk_stt/`. It captures microphone PCM through Godot's `AudioStreamMicrophone`/`AudioEffectCapture` path and sends 16 kHz mono samples to the native Vosk recognizer. Build requirements are a `godot-cpp` checkout from the same Godot 4.7 ABI as this project, the Vosk native SDK headers/library, and a C++17 Windows toolchain. Configure and build from the repository root:

```powershell
cmake -S windows/vosk_stt -B windows/vosk_stt/build `
  -DGODOT_CPP_DIR=C:\path\to\godot-cpp `
  -DVOSK_SDK_DIR=C:\path\to\vosk-sdk
cmake --build windows/vosk_stt/build --config Release
```

The CMake target writes `windows/vosk_stt/bin/vosk_stt.windows.x86_64.dll`, matching the `entry_symbol` and library path in `windows/vosk_stt/vosk_stt.gdextension`. Copy the Vosk runtime DLL beside that extension DLL and beside the exported executable as required by the Vosk SDK. The native entry point is exported as `vosk_stt_library_init`; do not rename it without changing `entry_symbol` too.

Windows reuses the committed model at `android/app/src/main/assets/vosk-model-small-en-us`; ensure that directory is included in the desktop export or update the path in `vosk_stt_bridge.gd`. If the DLL is absent, the UI remains usable and reports that native Vosk is unavailable.
