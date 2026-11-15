# gdvosk voice input

Anna7.0 now uses the `SpeechRecognizer` node supplied by the gdvosk GDExtension. The
addon metadata and editor icon are committed under `addons/gdvosk`; native binaries
are intentionally not committed.

Copy the gdvosk libraries supplied for the target platform into the paths declared
by `addons/gdvosk/gdvosk.gdextension`:

- `addons/gdvosk/lib/windows/x86_64/libgdvosk.dll`
- `addons/gdvosk/lib/windows/x86_64/libgdvosk-d.dll`
- `addons/gdvosk/lib/android/arm32/libgdvosk.so`
- `addons/gdvosk/lib/android/arm32/libgdvosk-d.so`
- `addons/gdvosk/lib/android/arm64/libgdvosk.so`
- `addons/gdvosk/lib/android/arm64/libgdvosk-d.so`

The existing Vosk model directory remains at
`android/app/src/main/assets/vosk-model-small-en-us`. gdvosk expects a
`VoskModel` resource (as used by Anna 6.0), so voice controls report a clear
status until `res://vosk-model-small-en-us-0.15.vosk` is added or the
`MODEL_RESOURCE_PATH` in `gdvosk_speech_recognizer.gd` is updated to the
project's converted model resource.
