// ARM32 Assembly for STM32F446RE - Sequence speed control with buttons
// Improved version with button detection during delays

// Peripheral memory addresses
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

// SysTick registers
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
.equ DELAY_SLOW,   9000000
.equ DELAY_MEDIUM, 4500000
.equ DELAY_FAST,   2250000
.equ DEBOUNCE_TIME, 50000
.equ BUTTON_CHECK_INTERVAL, 1000 // Check buttons every 1000 cycles

.syntax unified
.cpu cortex-m4
.thumb

.section .data
current_delay: .word DELAY_SLOW
delay_state:   .word 0x0001       // 1=slow, 2=medium, 3=fast
button_debounce: .word 0
button_pressed: .word 0           // Button press flag

.section .text
.global main

main:
    // Enable clocks
    LDR r0, =RCC_AHB1ENR
    LDR r1, [r0]
    ORR r1, r1, #(RCC_GPIOAEN | RCC_GPIOBEN | RCC_GPIOCEN)
    STR r1, [r0]

    // Small delay for clock stabilization
    MOV r2, #0x10
delay1:
    SUBS r2, r2, #1
    BNE delay1

    // Configure GPIOA outputs (PA0-PA9)
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

    // Configure GPIOB outputs (PB0-PB2 speed indicators)
    LDR r0, =GPIOB_MODER
    LDR r1, [r0]
    BIC r1, r1, #0x0000003F
    ORR r1, r1, #0x00000015
    STR r1, [r0]

    // Configure buttons with pull-up
    LDR r0, =GPIOC_MODER
    LDR r1, [r0]
    BIC r1, r1, #0x00000003      // PC0
    BIC r1, r1, #0x0C000000      // PC13
    STR r1, [r0]

    LDR r0, =GPIOC_PUPDR
    LDR r1, [r0]
    BIC r1, r1, #0x00000003      // PC0
    BIC r1, r1, #0x0C000000      // PC13
    ORR r1, r1, #0x00000001      // PC0 pull-up
    ORR r1, r1, #0x04000000      // PC13 pull-up
    STR r1, [r0]

    // Initialize speed indicator (PB0 on - slow)
    LDR r0, =GPIOB_ODR
    MOV r1, #0x0001
    STR r1, [r0]

    // Initialize SysTick
    LDR r0, =STK_CTRL
    MOV r1, #0
    STR r1, [r0]

main_loop:
    // Check buttons at start of each sequence
    BL check_buttons

    // Sequence with responsive button checking
    LDR r0, =GPIOA_ODR
    MOV r1, #0x0001               // PA0
    STR r1, [r0]
    BL delay_with_button_check

    MOV r1, #0x0103               // PA0, PA1, PA8
    STR r1, [r0]
    BL delay_with_button_check

    MOV r1, #0x0100               // PA8
    STR r1, [r0]
    BL delay_with_button_check

    MOV r1, #0x0300               // PA8, PA9
    ORR r1, r1, #0x0010           // + PA4
    STR r1, [r0]
    BL delay_with_button_check

    MOV r1, #0x0010               // PA4
    STR r1, [r0]
    BL delay_with_button_check

    MOV r1, #0x0070               // PA4-PA6
    STR r1, [r0]
    BL delay_with_button_check

    MOV r1, #0x0040               // PA6
    STR r1, [r0]
    BL delay_with_button_check

    MOV r1, #0x0080               // PA7
    STR r1, [r0]
    BL delay_with_button_check

    B main_loop

// Improved delay function with button checking
delay_with_button_check:
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
    // Button check interval
    MOV r3, #BUTTON_CHECK_INTERVAL
button_check_loop:
    SUBS r3, r3, #1
    BEQ check_buttons_during_delay
    B button_check_loop

check_buttons_during_delay:
    BL check_buttons
    LDR r1, =STK_CTRL
    LDR r2, [r1]
    ANDS r2, r2, #0x10000        // Check COUNTFLAG
    BEQ delay_loop

    // Disable SysTick
    MOV r2, #0
    STR r2, [r1]
    POP {r0-r5, pc}

// Button check function
check_buttons:
    PUSH {r0-r5, lr}
    LDR r5, =button_debounce
    LDR r4, [r5]
    CMP r4, #0
    BNE debounce_active

    LDR r0, =GPIOC_IDR
    LDR r1, [r0]

    // Check blue button (PC13 - active low)
    TST r1, #BUTTON_BLUE
    BNE check_black_button

    // Blue button pressed
    LDR r2, =button_pressed
    MOV r3, #1
    STR r3, [r2]
    B set_debounce

check_black_button:
    // Check black button (PC0 - active low)
    TST r1, #BUTTON_BLACK
    BNE end_check_buttons

    // Black button pressed
    LDR r2, =button_pressed
    MOV r3, #2
    STR r3, [r2]

set_debounce:
    LDR r0, =DEBOUNCE_TIME
    STR r0, [r5]
    B end_check_buttons

debounce_active:
    SUBS r4, r4, #1
    STR r4, [r5]
    LDR r2, =button_pressed
    LDR r3, [r2]
    CMP r3, #0
    BEQ end_check_buttons

    // Handle button press after debounce
    MOV r4, #0
    STR r4, [r2]                 // Reset press flag

    CMP r3, #1                   // Blue button
    BNE handle_black_button

    // Increase speed
    LDR r0, =delay_state
    LDR r1, [r0]
    CMP r1, #3
    BEQ end_check_buttons
    ADD r1, r1, #1
    STR r1, [r0]
    B update_speed

handle_black_button:
    // Decrease speed
    LDR r0, =delay_state
    LDR r1, [r0]
    CMP r1, #1
    BEQ end_check_buttons
    SUB r1, r1, #1
    STR r1, [r0]

update_speed:
    // Update current delay
    LDR r0, =current_delay
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

    // Update speed indicators
    LDR r0, =GPIOB_ODR
    MOV r2, #0
    STR r2, [r0]
    MOV r2, #1
    SUB r1, r1, #1
    LSL r2, r2, r1
    STR r2, [r0]

end_check_buttons:
    POP {r0-r5, pc}

.end
