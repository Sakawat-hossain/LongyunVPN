cmake_minimum_required(VERSION 3.22.1)

project("core")

message("CMAKE_SOURCE_DIR ${CMAKE_SOURCE_DIR}")

message("CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE}")


if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    add_compile_options(-O3 -flto -g0 -fno-exceptions -fno-rtti)
    add_link_options(-flto -Wl,--gc-sections,--strip-all)
endif ()

set(LONGYUN_CORE_PATH "${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/liblongyuncore.so")
set(LONGYUN_CORE_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/../cpp/includes/${ANDROID_ABI}")
set(LONGYUN_CORE_HEADER_PATH "${LONGYUN_CORE_INCLUDE_DIR}/liblongyuncore.h")
set(BRIDE_HEADER_PATH "${LONGYUN_CORE_INCLUDE_DIR}/bride.h")

message("LONGYUN_CORE_PATH ${LONGYUN_CORE_PATH}")
if (EXISTS ${LONGYUN_CORE_PATH} AND EXISTS ${LONGYUN_CORE_HEADER_PATH} AND EXISTS ${BRIDE_HEADER_PATH})
    message("Found liblongyuncore.so and headers for ABI ${ANDROID_ABI}")
    add_compile_definitions(LONGYUN_CORE)
    include_directories(${LONGYUN_CORE_INCLUDE_DIR})
    link_directories(${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})
    add_library(${CMAKE_PROJECT_NAME} SHARED
            jni_helper.cpp
            core.cpp)
    target_link_libraries(${CMAKE_PROJECT_NAME}
            longyuncore)
else ()
    message("Not found complete liblongyuncore output for ABI ${ANDROID_ABI}; building core without LONGYUN_CORE")
    add_library(${CMAKE_PROJECT_NAME} SHARED
            jni_helper.cpp
            core.cpp)
    target_link_libraries(${CMAKE_PROJECT_NAME})
endif ()
