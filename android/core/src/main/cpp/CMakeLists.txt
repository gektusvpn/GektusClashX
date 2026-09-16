cmake_minimum_required(VERSION 3.22.1)

project("core")

message("CMAKE_SOURCE_DIR ${CMAKE_SOURCE_DIR}")

message("CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE}")

if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    add_compile_options(-O3 -flto -g0 -fno-exceptions -fno-rtti)
    add_link_options(-flto -Wl,--gc-sections,--strip-all)
endif ()

get_filename_component(PROJECT_ROOT "${CMAKE_SOURCE_DIR}/../../../../.." ABSOLUTE)
set(LIB_CLASH_ROOT "${PROJECT_ROOT}/libclash/android")
set(LIB_CLASH_PATH "${LIB_CLASH_ROOT}/${ANDROID_ABI}/libclash.so")

message("LIB_CLASH_PATH ${LIB_CLASH_PATH}")
if (NOT EXISTS "${LIB_CLASH_PATH}")
    message(FATAL_ERROR
            "libclash.so not found for ABI ${ANDROID_ABI}. "
            "Run 'dart setup.dart android --out core' before building the Android app.")
endif ()

message("Found libclash.so for ABI ${ANDROID_ABI}")
add_compile_definitions(LIBCLASH)
include_directories("${LIB_CLASH_ROOT}/includes/${ANDROID_ABI}")

add_library(clash SHARED IMPORTED)
set_target_properties(clash PROPERTIES
        IMPORTED_LOCATION "${LIB_CLASH_PATH}"
        IMPORTED_NO_SONAME TRUE)

add_library(${CMAKE_PROJECT_NAME} SHARED
        jni_helper.cpp
        core.cpp)
target_link_libraries(${CMAKE_PROJECT_NAME} clash)
