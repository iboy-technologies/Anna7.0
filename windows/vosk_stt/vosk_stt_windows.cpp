#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <vosk_api.h>

#include <cstring>
#include <string>

using namespace godot;

class VoskSttWindows : public Node {
	GDCLASS(VoskSttWindows, Node);

	VoskModel *model = nullptr;
	VoskRecognizer *recognizer = nullptr;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("start_listening", "model_path"), &VoskSttWindows::start_listening);
		ClassDB::bind_method(D_METHOD("stop_listening"), &VoskSttWindows::stop_listening);
		ClassDB::bind_method(D_METHOD("accept_pcm", "pcm"), &VoskSttWindows::accept_pcm);
		ADD_SIGNAL(MethodInfo("partial_transcript", PropertyInfo(Variant::STRING, "text")));
		ADD_SIGNAL(MethodInfo("final_transcript", PropertyInfo(Variant::STRING, "text")));
		ADD_SIGNAL(MethodInfo("status_changed", PropertyInfo(Variant::STRING, "status")));
		ADD_SIGNAL(MethodInfo("error", PropertyInfo(Variant::STRING, "message")));
	}

public:
	void start_listening(const String &model_path) {
		stop_listening();
		model = vosk_model_new(model_path.utf8().get_data());
		if (!model) {
			emit_signal("error", String("Unable to load Vosk model: ") + model_path);
			return;
		}
		recognizer = vosk_recognizer_new(model, 16000.0f);
		if (!recognizer) {
			emit_signal("error", "Unable to initialize the Vosk recognizer.");
			return;
		}
		emit_signal("status_changed", "Windows Vosk recognizer ready.");
	}

	void stop_listening() {
		if (recognizer) {
			vosk_recognizer_free(recognizer);
			recognizer = nullptr;
		}
		if (model) {
			vosk_model_free(model);
			model = nullptr;
		}
	}

	void accept_pcm(const PackedByteArray &pcm) {
		if (!recognizer || pcm.is_empty()) {
			return;
		}
		const char *data = reinterpret_cast<const char *>(pcm.ptr());
		if (vosk_recognizer_accept_waveform(recognizer, data, pcm.size())) {
			emit_signal("final_transcript", extract_text(vosk_recognizer_result(recognizer)));
		} else {
			emit_signal("partial_transcript", extract_text(vosk_recognizer_partial_result(recognizer)));
		}
	}

	~VoskSttWindows() { stop_listening(); }

private:
	static String extract_text(const char *json) {
		std::string value(json ? json : "");
		const std::string key = "\"text\"";
		size_t start = value.find(key);
		if (start == std::string::npos) return String();
		start = value.find('"', value.find(':', start) + 1);
		size_t end = value.find('"', start + 1);
		return start != std::string::npos && end != std::string::npos
			? String(value.substr(start + 1, end - start - 1).c_str())
			: String();
	}
};

void initialize_vosk_stt(ModuleInitializationLevel level) {
	if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		ClassDB::register_class<VoskSttWindows>();
	}
}

void uninitialize_vosk_stt(ModuleInitializationLevel level) {}

extern "C" GDExtensionBool GDE_EXPORT vosk_stt_library_init(
	GDExtensionInterfaceGetProcAddress get_proc_address,
	GDExtensionClassLibraryPtr library,
	GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init_object(get_proc_address, library, initialization);
	init_object.register_initializer(initialize_vosk_stt);
	init_object.register_terminator(uninitialize_vosk_stt);
	init_object.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_object.init();
}
