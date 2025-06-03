// ARM32 Assembly for STM32F446RE - LED Speed Control
// Versión con lógica original pero velocidades corregidas

// Peripheral addresses
.equ RCC_BASE,     0x40023800
.equ RCC_AHB1ENR,  RCC_BASE + 0x30
.equ GPIOA_BASE,   0x40020000
.equ GPIOB_BASE,   0x40020400
.equ GPIOC_BASE,   0x40020800

// GPIO registers
.equ GPIOA_MODER,  GPIOA_BASE + 0x00
.equ GPIOA_ODR,    GPIOA_BASE + 0x14
.equ GPIOB_MODER,  GPIOB_BASE + 0x00
.equ GPIOB_ODR,    GPIOB_BASE + 0x14
.equ GPIOC_MODER,  GPIOC_BASE + 0x00
.equ GPIOC_IDR,    GPIOC_BASE + 0x10
.equ GPIOC_PUPDR,  GPIOC_BASE + 0x0C

// SysTick Timer
.equ STK_BASE,    0xE000E010
.equ STK_CTRL,    STK_BASE + 0x00
.equ STK_LOAD,    STK_BASE + 0x04
.equ STK_VAL,     STK_BASE + 0x08

// Constants
.equ RCC_GPIOAEN, 0x00000001
.equ RCC_GPIOBEN, 0x00000002
.equ RCC_GPIOCEN, 0x00000004
.equ BUTTON_BLUE, 0x00002000     // PC13
.equ BUTTON_BLACK,0x00000001     // PC0
.equ DELAY_SLOW,   50000000      // 2.0s (valor más grande = más lento)
.equ DELAY_MEDIUM, 30000000      // 1.0s
.equ DELAY_FAST,   3000000       // 0.5s (valor más pequeño = más rápido)
.equ DEBOUNCE_TIME, 20000
.equ BUTTON_CHECK_INTERVAL, 500

.syntax unified
.cpu cortex-m4
.thumb

.section .data
current_delay: .word DELAY_SLOW
delay_state:   .word 1            // 1=slow, 2=medium, 3=fast
button_debounce: .word 0
last_button_state: .word 0

.section .text
.global main

main:
    // Enable clocks
    LDR r0, =RCC_AHB1ENR
    LDR r1, [r0]
    ORR r1, r1, #(RCC_GPIOAEN | RCC_GPIOBEN | RCC_GPIOCEN)
    STR r1, [r0]

    // Short delay for stabilization
    MOV r2, #0x1000
delay1:
    SUBS r2, r2, #1
    BNE delay1

    // Configure GPIOA (PA0-PA7, PA8-PA9 as outputs)
    LDR r0, =GPIOA_MODER
    LDR r1, [r0]
    LDR r2, =0xFFFF0000
    AND r1, r1, r2
    LDR r2, =0x00005555
    ORR r1, r1, r2
    ORR r1, r1, #(0x01 << 16)    // PA8 output
    ORR r1, r1, #(0x01 << 18)    // PA9 output
    STR r1, [r0]

    // Configure GPIOB (PB0-PB2 as outputs)
    LDR r0, =GPIOB_MODER
    LDR r1, [r0]
    BIC r1, r1, #0x000000FF
    ORR r1, r1, #0x00000055
    STR r1, [r0]

    // Configure buttons (PC0 and PC13) with pull-up
    LDR r0, =GPIOC_MODER
    LDR r1, [r0]
    BIC r1, r1, #0x00000003      // PC0
    BIC r1, r1, #0x0C000000      // PC13
    STR r1, [r0]

    LDR r0, =GPIOC_PUPDR
    LDR r1, [r0]
    BIC r1, r1, #0x00000003
    BIC r1, r1, #0x0C000000
    ORR r1, r1, #0x00000001      // PC0 pull-up
    ORR r1, r1, #0x04000000      // PC13 pull-up
    STR r1, [r0]

    // Initialize indicator (PB0 on for slow speed)
    LDR r0, =GPIOB_ODR
    MOV r1, #0x01
    STR r1, [r0]

    // Initialize SysTick
    LDR r0, =STK_CTRL
    MOV r1, #0
    STR r1, [r0]

main_loop:
    BL check_buttons

    // LED sequence
    LDR r0, =GPIOA_ODR
    MOV r1, #0x0001       // PA0
    STR r1, [r0]
    BL responsive_delay

    MOV r1, #0x0103       // PA0, PA1, PA8
    STR r1, [r0]
    BL responsive_delay

    MOV r1, #0x0100       // PA8
    STR r1, [r0]
    BL responsive_delay

    MOV r1, #0x0310       // PA8, PA9, PA4
    STR r1, [r0]
    BL responsive_delay

    MOV r1, #0x0010       // PA4
    STR r1, [r0]
    BL responsive_delay

    MOV r1, #0x0070       // PA4-PA6
    STR r1, [r0]
    BL responsive_delay

    MOV r1, #0x0040       // PA6
    STR r1, [r0]
    BL responsive_delay

    MOV r1, #0x0080       // PA7
    STR r1, [r0]
    BL responsive_delay

    B main_loop

responsive_delay:
    PUSH {r0-r5, lr}
    LDR r0, =current_delay
    LDR r0, [r0]

    LDR r1, =STK_LOAD
    STR r0, [r1]
    LDR r1, =STK_VAL
    MOV r2, #0
    STR r2, [r1]
    LDR r1, =STK_CTRL
    MOV r2, #0x05
    STR r2, [r1]

delay_loop:
    BL check_buttons
    BL check_buttons

    LDR r1, =STK_CTRL
    LDR r2, [r1]
    ANDS r2, r2, #0x10000
    BEQ delay_loop

    MOV r2, #0
    STR r2, [r1]
    POP {r0-r5, pc}

check_buttons:
    PUSH {r0-r5, lr}
    LDR r0, =GPIOC_IDR
    LDR r1, [r0]
    LDR r2, =last_button_state
    LDR r3, [r2]
    STR r1, [r2]

    LDR r5, =button_debounce
    LDR r4, [r5]
    CMP r4, #0
    BEQ check_edges
    SUBS r4, r4, #1
    STR r4, [r5]
    B end_check

check_edges:
    // Blue button (increase speed)
    TST r3, #BUTTON_BLUE
    BEQ check_black_edge
    TST r1, #BUTTON_BLUE
    BNE check_black_edge

    LDR r0, =delay_state
    LDR r1, [r0]
    CMP r1, #3
    BEQ set_debounce
    ADD r1, r1, #1
    STR r1, [r0]
    BL update_speed
    B set_debounce

check_black_edge:
    // Black button (decrease speed)
    TST r3, #BUTTON_BLACK
    BEQ end_check
    TST r1, #BUTTON_BLACK
    BNE end_check

    LDR r0, =delay_state
    LDR r1, [r0]
    CMP r1, #1
    BEQ set_debounce
    SUB r1, r1, #1
    STR r1, [r0]
    BL update_speed

set_debounce:
    LDR r0, =DEBOUNCE_TIME
    STR r0, [r5]

end_check:
    POP {r0-r5, pc}

update_speed:
    PUSH {r0-r2, lr}
    LDR r0, =current_delay
    LDR r1, =delay_state
    LDR r1, [r1]

    CMP r1, #1
    ITT EQ
    LDREQ r2, =DELAY_SLOW      // Slow speed (largest delay)
    STREQ r2, [r0]

    CMP r1, #2
    ITT EQ
    LDREQ r2, =DELAY_MEDIUM
    STREQ r2, [r0]

    CMP r1, #3
    ITT EQ
    LDREQ r2, =DELAY_FAST      // Fast speed (smallest delay)
    STREQ r2, [r0]

    BL update_leds
    POP {r0-r2, pc}

update_leds:
    PUSH {r0-r2, lr}
    LDR r0, =GPIOB_ODR
    MOV r2, #0
    STR r2, [r0]

    LDR r1, =delay_state
    LDR r1, [r1]

    CMP r1, #1
    ITT EQ
    MOVEQ r2, #0x01     // PB0 for slow speed
    STREQ r2, [r0]

    CMP r1, #2
    ITT EQ
    MOVEQ r2, #0x02     // PB1 for medium speed
    STREQ r2, [r0]

    CMP r1, #3
    ITT EQ
    MOVEQ r2, #0x04     // PB2 for fast speed
    STREQ r2, [r0]

    POP {r0-r2, pc}

.end
