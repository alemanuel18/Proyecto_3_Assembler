// ARM32 Assembly for STM32F446RE - LED Speed Control
// Final version with guaranteed sequential speed changes

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
.equ DELAY_SLOW,   9000000       // 1.5s
.equ DELAY_MEDIUM, 4500000       // 0.75s
.equ DELAY_FAST,   1500000       // 0.25s
.equ DEBOUNCE_TIME, 20000        // Reduced debounce
.equ BUTTON_CHECK_INTERVAL, 500  // More frequent checks

.syntax unified
.cpu cortex-m4
.thumb

.section .data
current_delay: .word DELAY_SLOW
delay_state:   .word 1            // 1=slow, 2=medium, 3=fast
button_debounce: .word 0
last_button_state: .word 0        // Previous button state

.section .text
.global main

main:
    // 1. Enable clocks
    LDR r0, =RCC_AHB1ENR
    LDR r1, [r0]
    ORR r1, r1, #(RCC_GPIOAEN | RCC_GPIOBEN | RCC_GPIOCEN)
    STR r1, [r0]

    // Short stabilization delay
    MOV r2, #0x10
delay1:
    SUBS r2, r2, #1
    BNE delay1

    // 2. Configure PA0-PA9 as outputs
    LDR r0, =GPIOA_MODER
    LDR r1, [r0]
    LDR r2, =0xFFFF0000
    AND r1, r1, r2
    LDR r2, =0x00005555
    ORR r1, r1, r2
    BIC r1, r1, #(0x03 << 16)    // PA8
    BIC r1, r1, #(0x03 << 18)    // PA9
    ORR r1, r1, #(0x01 << 16)    // PA8 output
    ORR r1, r1, #(0x01 << 18)    // PA9 output
    STR r1, [r0]

    // 3. Configure GPIOB (PB0-PB2 as outputs)
    LDR r0, =GPIOB_MODER
    LDR r1, [r0]
    BIC r1, r1, #0x000000FF       // Clear PB0-PB3
    ORR r1, r1, #0x00000055       // PB0-PB2 as outputs
    STR r1, [r0]

    // 4. Configure buttons with pull-up
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

    // Initialize indicator (PB0 on)
    LDR r0, =GPIOB_ODR
    MOV r1, #0x01
    STR r1, [r0]

    // Initialize SysTick
    LDR r0, =STK_CTRL
    MOV r1, #0
    STR r1, [r0]

main_loop:
    BL check_buttons

    // LED sequence with constant button checking
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

// Optimized delay with constant button checking
responsive_delay:
    PUSH {r0-r5, lr}
    LDR r0, =current_delay
    LDR r0, [r0]

    // Configure SysTick
    LDR r1, =STK_LOAD
    STR r0, [r1]
    LDR r1, =STK_VAL
    MOV r2, #0
    STR r2, [r1]
    LDR r1, =STK_CTRL
    MOV r2, #0x05
    STR r2, [r1]

delay_loop:
    // Ultra-frequent button checking
    BL check_buttons
    BL check_buttons  // Double check for responsiveness

    LDR r1, =STK_CTRL
    LDR r2, [r1]
    ANDS r2, r2, #0x10000
    BEQ delay_loop

    MOV r2, #0
    STR r2, [r1]
    POP {r0-r5, pc}

// Enhanced button handler with strict sequential changes
check_buttons:
    PUSH {r0-r5, lr}

    // 1. Read current button state
    LDR r0, =GPIOC_IDR
    LDR r1, [r0]
    LDR r2, =last_button_state
    LDR r3, [r2]
    STR r1, [r2]        // Store current state for next cycle

    // 2. Check debounce
    LDR r5, =button_debounce
    LDR r4, [r5]
    CMP r4, #0
    BEQ check_edges
    SUBS r4, r4, #1
    STR r4, [r5]
    B end_check

check_edges:
    // 3. Edge detection (only on changes)
    // Blue button (PC13) - falling edge
    TST r3, #BUTTON_BLUE    // Previous state
    BEQ check_black_edge    // If was already pressed, ignore
    TST r1, #BUTTON_BLUE    // Current state
    BNE check_black_edge    // If still pressed, ignore

    // Blue button pressed (falling edge detected)
    LDR r0, =delay_state
    LDR r1, [r0]
    CMP r1, #3
    BEQ set_debounce        // If already at max, ignore

    // Strict sequential increase
    ADD r1, r1, #1         // 1->2 or 2->3 only
    STR r1, [r0]
    BL update_speed
    B set_debounce

check_black_edge:
    // Black button (PC0) - falling edge
    TST r3, #BUTTON_BLACK   // Previous state
    BEQ end_check           // If was already pressed, ignore
    TST r1, #BUTTON_BLACK   // Current state
    BNE end_check           // If still pressed, ignore

    // Black button pressed (falling edge detected)
    LDR r0, =delay_state
    LDR r1, [r0]
    CMP r1, #1
    BEQ set_debounce        // If already at min, ignore

    // Strict sequential decrease
    SUB r1, r1, #1         // 3->2 or 2->1 only
    STR r1, [r0]
    BL update_speed

set_debounce:
    LDR r0, =DEBOUNCE_TIME
    STR r0, [r5]

end_check:
    POP {r0-r5, pc}

// Update speed based on current state
update_speed:
    PUSH {r0-r2, lr}
    LDR r0, =current_delay
    LDR r1, =delay_state
    LDR r1, [r1]

    CMP r1, #1
    ITT EQ
    LDREQ r2, =DELAY_SLOW
    STREQ r2, [r0]

    CMP r1, #2
    ITT EQ
    LDREQ r2, =DELAY_MEDIUM
    STREQ r2, [r0]

    CMP r1, #3
    ITT EQ
    LDREQ r2, =DELAY_FAST
    STREQ r2, [r0]

    BL update_leds
    POP {r0-r2, pc}

// Update indicator LEDs
update_leds:
    PUSH {r0-r2, lr}
    LDR r0, =GPIOB_ODR
    MOV r2, #0
    STR r2, [r0]        // Turn all off first

    LDR r1, =delay_state
    LDR r1, [r1]

    CMP r1, #1
    ITT EQ
    MOVEQ r2, #0x01     // PB0 for slow
    STREQ r2, [r0]

    CMP r1, #2
    ITT EQ
    MOVEQ r2, #0x02     // PB1 for medium
    STREQ r2, [r0]

    CMP r1, #3
    ITT EQ
    MOVEQ r2, #0x04     // PB2 for fast
    STREQ r2, [r0]

    POP {r0-r2, pc}

.end
