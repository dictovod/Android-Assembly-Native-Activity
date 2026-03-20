cmake_minimum_required(VERSION 3.22.1)
project(AssemblyNativeActivity C ASM)

# Включить поддержку ASM для ARM64
enable_language(ASM)

# Установить флаги для максимального ASM
set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -march=armv8-a+simd")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O2 -march=armv8-a+simd")

# Найти системные библиотеки
find_library(log-lib     log)
find_library(android-lib android)

# Собрать .so из ASM исходников
add_library(
    AssemblyNativeActivity
    SHARED
    # Основной ASM файл — весь код на ассемблере
    asm/main_asm.S
    # Минимальный C glue — только для NativeActivity entry
    native_glue.c
)

# Линковать с системными библиотеками
target_link_libraries(
    AssemblyNativeActivity
    ${log-lib}
    ${android-lib}
    android
    log
)
