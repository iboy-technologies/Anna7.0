package org.annasoftware.vosk;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import androidx.annotation.NonNull;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.vosk.Model;
import org.vosk.Recognizer;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public final class VoskSttPlugin extends GodotPlugin {
    private static final String PLUGIN_NAME = "VoskStt";
    private static final int SAMPLE_RATE = 16000;

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private volatile boolean listening;
    private volatile AudioRecord recorder;
    private Future<?> worker;
    private Model model;
    private Recognizer recognizer;

    public VoskSttPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return PLUGIN_NAME;
    }

    @NonNull
    @Override
    public List<String> getPluginSignals() {
        return Arrays.asList("partial_transcript", "final_transcript", "status_changed", "error");
    }

    @NonNull
    @Override
    public List<String> getPluginMethods() {
        return Arrays.asList("start_listening", "stop_listening");
    }

    @UsedByGodot
    public void start_listening(String assetModelPath) {
        if (listening) {
            return;
        }
        Context context = getGodot().getActivity();
        if (context == null) {
            emitSignal("error", "Android activity is unavailable.");
            return;
        }
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            getGodot().getActivity().requestPermissions(
                    new String[]{Manifest.permission.RECORD_AUDIO}, 4107);
            emitSignal("status_changed", "Microphone permission requested.");
            return;
        }
        worker = executor.submit(() -> runRecognizer(context, assetModelPath));
    }

    @UsedByGodot
    public void stop_listening() {
        listening = false;
        AudioRecord activeRecorder = recorder;
        if (activeRecorder != null) {
            activeRecorder.stop();
        }
        emitSignal("status_changed", "Voice input stopped.");
    }

    private void runRecognizer(Context context, String assetModelPath) {
        try {
            emitSignal("status_changed", "Loading offline Vosk model...");
            File modelDirectory = copyAssets(context, assetModelPath);
            model = new Model(modelDirectory.getAbsolutePath());
            recognizer = new Recognizer(model, SAMPLE_RATE);
            int minimumBuffer = AudioRecord.getMinBufferSize(
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT);
            recorder = new AudioRecord(
                    MediaRecorder.AudioSource.VOICE_RECOGNITION,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    Math.max(minimumBuffer, SAMPLE_RATE));
            recorder.startRecording();
            listening = true;
            emitSignal("status_changed", "Listening with offline Vosk speech-to-text...");
            byte[] buffer = new byte[4096];
            while (listening) {
                int count = recorder.read(buffer, 0, buffer.length);
                if (count <= 0) {
                    continue;
                }
                if (recognizer.acceptWaveForm(buffer, count)) {
                    emitSignal("final_transcript", extractText(recognizer.getResult()));
                } else {
                    emitSignal("partial_transcript", extractText(recognizer.getPartialResult()));
                }
            }
        } catch (Exception exception) {
            emitSignal("error", exception.getMessage() == null
                    ? "Vosk initialization or microphone capture failed."
                    : exception.getMessage());
        } finally {
            releaseResources();
        }
    }

    private String extractText(String json) {
        int start = json.indexOf("\"text\"");
        if (start < 0) {
            return "";
        }
        int colon = json.indexOf(':', start);
        int firstQuote = json.indexOf('"', colon + 1);
        int secondQuote = json.indexOf('"', firstQuote + 1);
        return firstQuote >= 0 && secondQuote > firstQuote
                ? json.substring(firstQuote + 1, secondQuote)
                : "";
    }

    private File copyAssets(Context context, String assetModelPath) throws IOException {
        File destination = new File(context.getFilesDir(), assetModelPath);
        copyAssetTree(context, assetModelPath, destination);
        return destination;
    }

    private void copyAssetTree(Context context, String assetPath, File destination) throws IOException {
        String[] children = context.getAssets().list(assetPath);
        if (children == null || children.length == 0) {
            destination.getParentFile().mkdirs();
            try (InputStream input = context.getAssets().open(assetPath);
                 FileOutputStream output = new FileOutputStream(destination)) {
                byte[] buffer = new byte[8192];
                int count;
                while ((count = input.read(buffer)) != -1) {
                    output.write(buffer, 0, count);
                }
            }
            return;
        }
        if (!destination.exists() && !destination.mkdirs()) {
            throw new IOException("Unable to create model directory: " + destination);
        }
        for (String child : children) {
            copyAssetTree(context, assetPath + "/" + child, new File(destination, child));
        }
    }

    private void releaseResources() {
        listening = false;
        AudioRecord activeRecorder = recorder;
        recorder = null;
        if (activeRecorder != null) {
            activeRecorder.release();
        }
        if (recognizer != null) {
            recognizer.close();
            recognizer = null;
        }
        if (model != null) {
            model.close();
            model = null;
        }
    }

    @Override
    public void onMainDestroy() {
        stop_listening();
        executor.shutdownNow();
        releaseResources();
        super.onMainDestroy();
    }
}
