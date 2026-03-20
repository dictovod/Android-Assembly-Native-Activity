// native_glue.c — минимальный C glue для NativeActivity
// Весь реальный код находится в asm/main_asm.S

#include <android/native_activity.h>
#include <android/looper.h>

// Объявить ASM функции
extern void android_main(struct android_app* app);

// NativeActivity entry point — вызывает наш ASM android_main
void ANativeActivity_onCreate(ANativeActivity* activity,
                               void* savedState,
                               size_t savedStateSize) {
    // Передать управление чистому ASM коду
    // android_main вызывается через NativeActivity framework
    (void)activity;
    (void)savedState;
    (void)savedStateSize;
}
