cmake_minimum_required(VERSION 3.22)
project(vosk_stt_windows LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(GODOT_CPP_DIR "" CACHE PATH "Path to a matching godot-cpp checkout")
set(VOSK_SDK_DIR "" CACHE PATH "Path to the Vosk native SDK")

add_subdirectory("${GODOT_CPP_DIR}" godot-cpp)
add_library(vosk_stt SHARED vosk_stt_windows.cpp)
target_include_directories(vosk_stt PRIVATE "${VOSK_SDK_DIR}/include")
target_link_directories(vosk_stt PRIVATE "${VOSK_SDK_DIR}/lib")
target_link_libraries(vosk_stt PRIVATE godot-cpp vosk)
target_compile_definitions(vosk_stt PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
