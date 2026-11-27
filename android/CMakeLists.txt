cmake_minimum_required(VERSION 3.22.1)
project(VisionCameraWorklets LANGUAGES C CXX)

set (PACKAGE_NAME VisionCameraWorklets)

# Define C++ library and add all sources
add_library(${PACKAGE_NAME} SHARED
        src/main/cpp/cpp-adapter.cpp
        "../cpp/HybridWorkletQueueFactory.cpp"
)
target_compile_features(${PACKAGE_NAME} PUBLIC cxx_std_20)

# Add Nitrogen specs :)
include(${CMAKE_CURRENT_SOURCE_DIR}/../nitrogen/generated/android/VisionCameraWorklets+autolinking.cmake)

# Set up local includes
target_include_directories(${PACKAGE_NAME} PRIVATE
        "src/main/cpp"
        "../cpp"
)

find_library(LOG_LIB log)
# The generated NativeThread C++ adapter calls VisionCamera's JHybridNativeThreadSpec,
# which lives in libVisionCamera.so. Nitrogen's autolinking cmake does not add this
# cross-module link, so it stays here.
find_package(react-native-vision-camera REQUIRED CONFIG)
find_package(react-native-worklets REQUIRED CONFIG)

# Link all libraries together
target_link_libraries(
        ${PACKAGE_NAME}
        ${LOG_LIB}
        android                                   # <-- Android core
        react-native-vision-camera::VisionCamera
        react-native-worklets::worklets
)
