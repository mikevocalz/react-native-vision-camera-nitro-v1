cmake_minimum_required(VERSION 3.22.1)
project(VisionCamera LANGUAGES C CXX)

set (PACKAGE_NAME VisionCamera)

# Define C++ library and add all sources
add_library(${PACKAGE_NAME} SHARED
        src/main/cpp/cpp-adapter.cpp
        src/main/cpp/NativeBufferHelper.cpp
)
target_compile_features(${PACKAGE_NAME} PUBLIC cxx_std_20)

# Add Nitrogen specs :)
include(${CMAKE_CURRENT_SOURCE_DIR}/../nitrogen/generated/android/VisionCamera+autolinking.cmake)

# Set up local includes
target_include_directories(${PACKAGE_NAME} PRIVATE
        "src/main/cpp"
)

find_library(LOG_LIB log)
# The generated JNI bindings call into NitroImage's JHybridImageSpec, which
# lives in libNitroImage.so. Nitrogen's autolinking cmake does not add this
# cross-module link, so it stays here.
find_package(react-native-nitro-image REQUIRED CONFIG)

# Link all libraries together
target_link_libraries(
        ${PACKAGE_NAME}
        ${LOG_LIB}
        android                                   # <-- Android core
        react-native-nitro-image::NitroImage
)
