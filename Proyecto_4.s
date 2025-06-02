// Ensamblador ARM32 para STM32F446RE - Control de velocidad de secuencia con botones
// y visualización de velocidad en GPIOB

// Definición de direcciones de memoria para periféricos
.equ RCC_BASE,     0x40023800      // Base del reloj y reset
.equ RCC_AHB1ENR,  RCC_BASE + 0x30 // Registro de habilitación de periféricos AHB1
.equ GPIOA_BASE,   0x40020000      // Base del puerto GPIOA
.equ GPIOB_BASE,   0x40020400      // Base del puerto GPIOB
.equ GPIOC_BASE,   0x40020800      // Base del puerto GPIOC (botones)

// Registros GPIO
.equ GPIOA_MODER,  GPIOA_BASE + 0x00  // Registro modo
.equ GPIOA_ODR,    GPIOA_BASE + 0x14  // Registro de datos de salida
.equ GPIOB_MODER,  GPIOB_BASE + 0x00  // Registro modo GPIOB
.equ GPIOB_ODR,    GPIOB_BASE + 0x14  // Registro de datos de salida GPIOB
.equ GPIOC_MODER,  GPIOC_BASE + 0x00  // Registro modo GPIOC (botones)
.equ GPIOC_IDR,    GPIOC_BASE + 0x10  // Registro de datos de entrada GPIOC

// Registros del SysTick Timer para delays
.equ STK_BASE,    0xE000E010
.equ STK_CTRL,    STK_BASE + 0x00
.equ STK_LOAD,    STK_BASE + 0x04
.equ STK_VAL,     STK_BASE + 0x08

// Constantes
.equ RCC_GPIOAEN, 0x00000001      // Bit para habilitar GPIOA
.equ RCC_GPIOBEN, 0x00000002      // Bit para habilitar GPIOB
.equ RCC_GPIOCEN, 0x00000004      // Bit para habilitar GPIOC

// Botones (ajustar según tu placa)
.equ BUTTON_BLUE, 0x00002000      // PC13 (botón azul - USER en muchas placas)
.equ BUTTON_BLACK,0x00000001      // PC0 (botón negro - asumido)

// Velocidades (ajustar según frecuencia del reloj)
.equ DELAY_SLOW,   9000000        // 1.5 segundos (velocidad lenta)
.equ DELAY_MEDIUM, 4500000        // 0.75 segundos (velocidad media)
.equ DELAY_FAST,   2250000        // 0.375 segundos (velocidad rápida)

.syntax unified
.cpu cortex-m4
.thumb

.section .data
current_delay: .word DELAY_SLOW    // Variable para almacenar el delay actual
delay_state:   .word 0x0001        // Estado actual: 1=lento, 2=medio, 3=rápido
button_debounce: .word 0           // Variable para debounce

.section .text
.global main

main:
    // 1. Habilitar reloj para GPIOA, GPIOB y GPIOC
    LDR r0, =RCC_AHB1ENR
    LDR r1, [r0]
    ORR r1, r1, #(RCC_GPIOAEN | RCC_GPIOBEN | RCC_GPIOCEN)
    STR r1, [r0]

    // Pequeña espera para que los relojes se estabilicen
    MOV r2, #0x10
delay1:
    SUBS r2, r2, #1
    BNE delay1

    // 2. Configurar PA0-PA7 y PA8-PA9 como salidas (MODER = 01)
    LDR r0, =GPIOA_MODER
    LDR r1, [r0]
    LDR r2, =0xFFFF0000           // Máscara para limpiar bits 0-15
    AND r1, r1, r2
    LDR r2, =0x00005555           // 01 (salida) para cada pin de 0-7
    ORR r1, r1, r2
    // Configurar también PA8 y PA9 como salidas
    BIC r1, r1, #(0x03 << 16)     // Limpiar bits para PA8
    BIC r1, r1, #(0x03 << 18)     // Limpiar bits para PA9
    ORR r1, r1, #(0x01 << 16)     // PA8 como salida
    ORR r1, r1, #(0x01 << 18)     // PA9 como salida
    STR r1, [r0]

    // 3. Configurar PB0-PB2 como salidas (indicadores de velocidad)
    LDR r0, =GPIOB_MODER
    LDR r1, [r0]
    BIC r1, r1, #0x0000003F       // Limpiar bits para PB0-PB2
    ORR r1, r1, #0x00000015       // Configurar como salidas (01) para PB0-PB2
    STR r1, [r0]

    // 4. Configurar botones (PC13 y PC0) como entradas
    LDR r0, =GPIOC_MODER
    LDR r1, [r0]
    BIC r1, r1, #0x00000003       // Limpiar bits para PC0 (botón negro)
    BIC r1, r1, #0x0C000000       // Limpiar bits para PC13 (botón azul)
    STR r1, [r0]

    // Inicializar indicador de velocidad (PB0 encendido - lento)
    LDR r0, =GPIOB_ODR
    MOV r1, #0x0001               // Encender PB0 (velocidad lenta)
    STR r1, [r0]

    // Inicializar SysTick Timer
    LDR r0, =STK_CTRL
    MOV r1, #0
    STR r1, [r0]                  // Deshabilitar SysTick temporalmente

    // Bucle principal con la secuencia de LEDs
main_loop:
    // Verificar estado de los botones
    BL check_buttons

    // Ejecutar secuencia con el delay actual
    // Secuencia: PA0
    LDR r0, =GPIOA_ODR
    MOV r1, #0x0001               // PA0 = 1 (0x01)
    STR r1, [r0]
    BL delay_current

    // Secuencia: PA0 PA1 PA8 (en lugar de PA2)
    MOV r1, #0x0103               // PA0, PA1, PA8 = 1 (0x0103)
    STR r1, [r0]
    BL delay_current

    // Secuencia: PA8 (en lugar de PA2)
    MOV r1, #0x0100               // PA8 = 1 (0x0100)
    STR r1, [r0]
    BL delay_current

    // Secuencia: PA8 PA9 PA4 (en lugar de PA3)
    MOV r1, #0x0300               // PA8, PA9 = 1 (0x0300)
    ORR r1, r1, #0x0010           // PA4 = 1 (resultado 0x0310)
    STR r1, [r0]
    BL delay_current

    // Secuencia: PA4
    MOV r1, #0x0010               // PA4 = 1 (0x10)
    STR r1, [r0]
    BL delay_current

    // Secuencia: PA4 PA5 PA6
    MOV r1, #0x0070               // PA4-PA6 = 1 (0x70)
    STR r1, [r0]
    BL delay_current

    // Secuencia: PA6
    MOV r1, #0x0040               // PA6 = 1 (0x40)
    STR r1, [r0]
    BL delay_current

    // Secuencia: PA7
    MOV r1, #0x0080               // PA7 = 1 (0x80)
    STR r1, [r0]
    BL delay_current

    B main_loop                   // Repetir la secuencia

// Subrutina para verificar botones y cambiar velocidad
check_buttons:
    PUSH {r0-r5, lr}

    // Leer estado de los botones
    LDR r0, =GPIOC_IDR
    LDR r1, [r0]

    // Verificar si ya estamos en debounce
    LDR r5, =button_debounce
    LDR r4, [r5]
    CMP r4, #0
    BNE debounce_active

    // Verificar botón azul (PC13 - AUMENTAR velocidad)
    TST r1, #BUTTON_BLUE
    BEQ check_black_button        // Si no está presionado, verificar el otro

    // Botón azul presionado - AUMENTAR velocidad
    LDR r2, =delay_state
    LDR r3, [r2]
    CMP r3, #3                   // Si ya estamos en velocidad rápida, no hacer nada
    BEQ set_debounce

    ADD r3, r3, #1               // Aumentar velocidad (1->2->3)
    STR r3, [r2]

    // Actualizar delay actual según el estado
    LDR r2, =current_delay
    CMP r3, #1
    ITT EQ
    LDREQ r3, =DELAY_SLOW
    STREQ r3, [r2]
    CMP r3, #2
    ITT EQ
    LDREQ r3, =DELAY_MEDIUM
    STREQ r3, [r2]
    CMP r3, #3
    ITT EQ
    LDREQ r3, =DELAY_FAST
    STREQ r3, [r2]

    // Actualizar indicadores GPIOB (PB0=slow, PB1=med, PB2=fast)
    LDR r0, =GPIOB_ODR
    MOV r1, #0                   // Apagar todos
    STR r1, [r0]
    MOV r1, #1                   // Máscara base
    SUB r3, r3, #1               // Ajustar para desplazamiento (0-2)
    LSL r1, r1, r3               // Desplazar según velocidad
    STR r1, [r0]

    B set_debounce

check_black_button:
    // Verificar botón negro (PC0 - DISMINUIR velocidad)
    TST r1, #BUTTON_BLACK
    BEQ end_check_buttons         // Si no está presionado, salir

    // Botón negro presionado - DISMINUIR velocidad
    LDR r2, =delay_state
    LDR r3, [r2]
    CMP r3, #1                   // Si ya estamos en velocidad lenta, no hacer nada
    BEQ set_debounce

    SUB r3, r3, #1               // Disminuir velocidad (3->2->1)
    STR r3, [r2]

    // Actualizar delay actual según el estado
    LDR r2, =current_delay
    CMP r3, #1
    ITT EQ
    LDREQ r3, =DELAY_SLOW
    STREQ r3, [r2]
    CMP r3, #2
    ITT EQ
    LDREQ r3, =DELAY_MEDIUM
    STREQ r3, [r2]
    CMP r3, #3
    ITT EQ
    LDREQ r3, =DELAY_FAST
    STREQ r3, [r2]

    // Actualizar indicadores GPIOB (PB0=slow, PB1=med, PB2=fast)
    LDR r0, =GPIOB_ODR
    MOV r1, #0                   // Apagar todos
    STR r1, [r0]
    MOV r1, #1                   // Máscara base
    SUB r3, r3, #1               // Ajustar para desplazamiento (0-2)
    LSL r1, r1, r3               // Desplazar según velocidad
    STR r1, [r0]

set_debounce:
    // Establecer tiempo de debounce (evitar múltiples detecciones)
    MOV r0, #100                 // Valor de debounce (ajustar según necesidad)
    LDR r1, =button_debounce
    STR r0, [r1]
    B end_check_buttons

debounce_active:
    // Decrementar contador de debounce
    SUBS r4, r4, #1
    STR r4, [r5]

end_check_buttons:
    POP {r0-r5, pc}

// Subrutina de delay con el tiempo actual
delay_current:
    PUSH {r0-r2, lr}

    LDR r0, =current_delay
    LDR r0, [r0]                 // Obtener el delay actual

    // Configurar SysTick
    LDR r1, =STK_LOAD
    STR r0, [r1]                 // Cargar valor de cuenta

    LDR r1, =STK_VAL
    MOV r2, #0
    STR r2, [r1]                 // Limpiar el contador actual

    LDR r1, =STK_CTRL
    MOV r2, #0x05                // Habilitar SysTick con reloj del procesador
    STR r2, [r1]

current_delay_loop:
    LDR r2, [r1]
    ANDS r2, r2, #0x10000        // Verificar bit COUNTFLAG
    BEQ current_delay_loop

    // Deshabilitar SysTick
    MOV r2, #0
    STR r2, [r1]

    POP {r0-r2, pc}

.end
