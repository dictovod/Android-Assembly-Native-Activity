// main_asm.S — ARM64 Assembly для Android NativeActivity
// Полностью на ассемблере: lifecycle, draw loop, logging

.section .text
.global android_main
.global asm_get_system_time
.global asm_fill_color
.global asm_calculate_fps
.global asm_memset_fast
.global asm_strlen
.global asm_event_loop

// ─── КОНСТАНТЫ ───────────────────────────────────────────────
.equ LOOPER_ID_MAIN,        1
.equ LOOPER_ID_INPUT,       2
.equ ANDROID_LOG_INFO,      4
.equ ANDROID_LOG_DEBUG,     3
.equ ANDROID_LOG_ERROR,     6

// ─── СТРОКИ (rodata) ─────────────────────────────────────────
.section .rodata
tag_str:        .asciz "ASM_NATIVE"
msg_start:      .asciz "=== Android Assembly App Started ==="
msg_loop:       .asciz "Main loop tick: %d"
msg_init:       .asciz "NativeActivity initialized from pure ASM"
msg_destroy:    .asciz "NativeActivity destroyed"
msg_resume:     .asciz "Activity RESUMED"
msg_pause:      .asciz "Activity PAUSED"
msg_fps:        .asciz "FPS: %d | Frame: %d | Time: %lld ms"
msg_mem:        .asciz "Memory ops: memset %d bytes in ASM"
msg_window:     .asciz "Window created, starting render loop"
msg_color:      .asciz "Frame color R:%d G:%d B:%d"

.section .text

// ═══════════════════════════════════════════════════════
// android_main — точка входа NativeActivity
// x0 = struct android_app*
// ═══════════════════════════════════════════════════════
android_main:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]

    mov     x19, x0                     // сохранить app pointer

    // Лог старта
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_start
    add     x1, x1, :lo12:msg_start
    mov     x2, ANDROID_LOG_INFO
    bl      asm_log_info

    // Установить callbacks
    mov     x0, x19
    bl      asm_setup_callbacks

    // Инициализировать счётчик кадров
    mov     x20, #0                     // frame counter
    mov     x21, #0                     // running flag
    mov     x22, #0                     // window ready

    // Лог инициализации
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_init
    add     x1, x1, :lo12:msg_init
    mov     x2, ANDROID_LOG_INFO
    bl      asm_log_info

    // Основной цикл
    b       .main_loop

.main_loop:
    // Обработать события
    mov     x0, x19
    bl      asm_process_events

    // Проверить флаг выхода
    ldr     w1, [x19, #8]               // app->destroyRequested
    cbnz    w1, .main_exit

    // Инкремент кадра
    add     x20, x20, #1

    // Лог каждые 60 кадров
    and     x1, x20, #63
    cbnz    x1, .skip_log

    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_loop
    add     x1, x1, :lo12:msg_loop
    mov     x2, x20
    bl      asm_log_debug

.skip_log:
    // Рендер если есть окно
    ldr     x1, [x19, #16]              // app->window
    cbz     x1, .main_loop

    // ASM отрисовка кадра
    mov     x0, x19
    mov     x1, x20
    bl      asm_render_frame

    b       .main_loop

.main_exit:
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_destroy
    add     x1, x1, :lo12:msg_destroy
    mov     x2, ANDROID_LOG_INFO
    bl      asm_log_info

    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ═══════════════════════════════════════════════════════
// asm_setup_callbacks — регистрация ASM callbacks
// x0 = android_app*
// ═══════════════════════════════════════════════════════
asm_setup_callbacks:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    // Callbacks хранятся как указатели на функции в структуре
    // NativeActivity управляет ими через JNI
    ldp     x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════
// asm_process_events — обработка событий looper
// x0 = android_app*
// ═══════════════════════════════════════════════════════
asm_process_events:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]

    mov     x19, x0

    // ALooper_pollOnce(0, NULL, NULL, NULL)
    mov     x0, #0
    mov     x1, #0
    mov     x2, #0
    mov     x3, #0
    bl      ALooper_pollOnce

    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ═══════════════════════════════════════════════════════
// asm_render_frame — отрисовка кадра через EGL
// x0 = android_app*, x1 = frame_number
// ═══════════════════════════════════════════════════════
asm_render_frame:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]

    mov     x19, x0
    mov     x20, x1                     // frame number

    // Вычислить цвет из номера кадра (ASM арифметика)
    // R = (frame >> 1) & 0xFF
    // G = (frame >> 2) & 0xFF
    // B = (frame >> 3) & 0xFF
    lsr     w2, w20, #1
    and     w2, w2, #0xFF               // R
    lsr     w3, w20, #2
    and     w3, w3, #0xFF               // G
    lsr     w4, w20, #3
    and     w4, w4, #0xFF               // B

    // Логировать цвет
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_color
    add     x1, x1, :lo12:msg_color
    bl      asm_log_debug

    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ═══════════════════════════════════════════════════════
// asm_fill_color — заполнение буфера цветом (чистый ASM)
// x0 = buffer ptr, w1 = size (bytes), w2 = color (RGBA)
// Использует NEON для максимальной скорости
// ═══════════════════════════════════════════════════════
asm_fill_color:
    cbz     w1, .fill_done
    cbz     x0, .fill_done

    // Дублировать цвет в NEON регистр (16 байт за раз)
    dup     v0.4s, w2

    // Выровненные блоки по 64 байта (4 * 16)
    lsr     w3, w1, #6                  // count / 64
    cbz     w3, .fill_remainder

.fill_loop64:
    st1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0], #64
    subs    w3, w3, #1
    bne     .fill_loop64

.fill_remainder:
    and     w1, w1, #63                 // остаток
    cbz     w1, .fill_done

.fill_byte_loop:
    str     w2, [x0], #4
    subs    w1, w1, #4
    bgt     .fill_byte_loop

.fill_done:
    ret

// ═══════════════════════════════════════════════════════
// asm_memset_fast — быстрый memset через NEON
// x0 = dst, w1 = value, x2 = count
// ═══════════════════════════════════════════════════════
asm_memset_fast:
    cbz     x2, .memset_done
    dup     v0.16b, w1                  // заполнить NEON регистр значением

    lsr     x3, x2, #4                  // блоки по 16 байт
    cbz     x3, .memset_tail

.memset_loop:
    st1     {v0.16b}, [x0], #16
    subs    x3, x3, #1
    bne     .memset_loop

.memset_tail:
    and     x2, x2, #15
    cbz     x2, .memset_done

.memset_byte:
    strb    w1, [x0], #1
    subs    x2, x2, #1
    bne     .memset_byte

.memset_done:
    ret

// ═══════════════════════════════════════════════════════
// asm_strlen — длина строки на ASM
// x0 = string ptr → возврат x0 = length
// ═══════════════════════════════════════════════════════
asm_strlen:
    mov     x1, x0
.strlen_loop:
    ldrb    w2, [x1], #1
    cbnz    w2, .strlen_loop
    sub     x0, x1, x0
    sub     x0, x0, #1
    ret

// ═══════════════════════════════════════════════════════
// asm_get_system_time — получить время в мс
// Возврат x0 = milliseconds
// ═══════════════════════════════════════════════════════
asm_get_system_time:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp

    // clock_gettime(CLOCK_MONOTONIC, &ts)
    mov     x0, #1                      // CLOCK_MONOTONIC
    add     x1, sp, #16                 // &timespec на стеке
    bl      clock_gettime

    // result = sec * 1000 + nsec / 1000000
    ldr     x0, [sp, #16]               // tv_sec
    ldr     x1, [sp, #24]               // tv_nsec
    mov     x2, #1000
    mul     x0, x0, x2                  // sec * 1000
    mov     x2, #1000000
    udiv    x1, x1, x2                  // nsec / 1000000
    add     x0, x0, x1

    ldp     x29, x30, [sp], #32
    ret

// ═══════════════════════════════════════════════════════
// asm_calculate_fps — вычислить FPS
// x0 = current_time_ms, x1 = last_time_ms, x2 = frames
// Возврат x0 = fps
// ═══════════════════════════════════════════════════════
asm_calculate_fps:
    sub     x3, x0, x1                  // delta = current - last
    cbz     x3, .fps_zero
    mov     x4, #1000
    mul     x2, x2, x4                  // frames * 1000
    udiv    x0, x2, x3                  // fps = frames*1000 / delta_ms
    ret
.fps_zero:
    mov     x0, #0
    ret

// ═══════════════════════════════════════════════════════
// asm_log_info / asm_log_debug — логирование
// x0 = tag, x1 = format, x2+ = args
// ═══════════════════════════════════════════════════════
asm_log_info:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x2, x1
    mov     x1, ANDROID_LOG_INFO
    bl      __android_log_print
    ldp     x29, x30, [sp], #16
    ret

asm_log_debug:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x2, x1
    mov     x1, ANDROID_LOG_DEBUG
    bl      __android_log_print
    ldp     x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════
// asm_event_loop — дополнительный event loop helper
// ═══════════════════════════════════════════════════════
asm_event_loop:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x0, #0
    mov     x1, xzr
    mov     x2, xzr
    mov     x3, xzr
    bl      ALooper_pollOnce
    ldp     x29, x30, [sp], #16
    ret

.end
