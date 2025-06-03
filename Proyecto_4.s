//
// Universidad del Valle de Guatemala
// Algoritmos y Estructuras de Datos
// Ing. Douglas Barrios
// @author: Marcelo Detlefsen, Alejandro Jerez, Julián Divas
// Creación: 01/06/2025
// última modificación: 02/06/2025
// File Name: principal.s
// Descripción: Programa en ensamblador correspondiente al proyecto 4 donde se solicita encender un patrón de leds y
// ajustar la velocidad de cambio utilizando dos botones
//

//Asignación de variables con las direcciones, bits  y constantes a utilizar dentro del programa
//Autor: Alejandro Jerez
.equ RCC_BASE,     0x40023800               // Dirección base del RCC (Reset and Clock Control)
.equ RCC_AHB1ENR,  RCC_BASE + 0x30          // Registro para habilitar reloj de los puertos AHB1 (GPIOA, B, C)
.equ GPIOA_BASE,   0x40020000               // Dirección base de GPIOA
.equ GPIOB_BASE,   0x40020400               // Dirección base de GPIOB
.equ GPIOC_BASE,   0x40020800               // Dirección base de GPIOC

// Direcciones de registros de los GPIOs
.equ GPIOA_MODER,  GPIOA_BASE + 0x00        // Registro de modo de GPIOA
.equ GPIOA_ODR,    GPIOA_BASE + 0x14        // Registro de salida (Output Data Register) de GPIOA
.equ GPIOB_MODER,  GPIOB_BASE + 0x00        // Registro de modo de GPIOB
.equ GPIOB_ODR,    GPIOB_BASE + 0x14        // Registro de salida de GPIOB
.equ GPIOC_MODER,  GPIOC_BASE + 0x00        // Registro de modo de GPIOC
.equ GPIOC_IDR,    GPIOC_BASE + 0x10        // Registro de entrada (Input Data Register) de GPIOC
.equ GPIOC_PUPDR,  GPIOC_BASE + 0x0C        // Registro de resistencias pull-up/pull-down de GPIOC

// Direcciones del temporizador SysTick
.equ STK_BASE,    0xE000E010                // Dirección base del SysTick
.equ STK_CTRL,    STK_BASE + 0x00           // Registro de control de SysTick
.equ STK_LOAD,    STK_BASE + 0x04           // Carga del contador
.equ STK_VAL,     STK_BASE + 0x08           // Valor actual del contador

// Constantes generales
.equ RCC_GPIOAEN, 0x00000001                // Bit para habilitar reloj a GPIOA
.equ RCC_GPIOBEN, 0x00000002                // Bit para habilitar reloj a GPIOB
.equ RCC_GPIOCEN, 0x00000004                // Bit para habilitar reloj a GPIOC
.equ BUTTON_BLUE, 0x00002000                // Bit de PC13 (botón azul)
.equ BUTTON_BLACK,0x00000001                // Bit de PC0 (botón negro)

//Delays para las velocidades de los ciclos
.equ DELAY_LENTO,   50000000                 // Delay para velocidad lenta (2.5 s)
.equ DELAY_MEDIO, 30000000                 // Delay para velocidad media (1.5 s)
.equ DELAY_RAPIDO,   3000000                  // Delay para velocidad rápida (0.5 s)
.equ DEBOUNCE_TIME, 20000                   // Tiempo de rebote para evitar lecturas falsas
.equ BUTTON_CHECK_INTERVAL, 500             // Intervalo entre verificaciones de botones

.syntax unified
.cpu cortex-m4
.thumb

//Datos a utilizar al principio del programa
.section .data
//Se empieza en la velocidad lenta con su respectivo delay
current_delay: .word DELAY_LENTO             // Retardo actual inicial (lento)
delay_state:   .word 1                      // Estado de velocidad: 1=lento, 2=medio, 3=rápido
button_debounce: .word 0                   // Contador de rebote del botón
last_button_state: .word 0                 // Estado anterior de los botones

.section .text
.global main
main:
// Habilita el reloj para GPIOA, GPIOB y GPIOC
    LDR r0, =RCC_AHB1ENR //Direccion para habilitar el clock de los puertos A B y C
	LDR r1, [r0]             // Leer valor actual del registro

	// Habilitar GPIOA (bit 0)
	ORR r1, r1, #RCC_GPIOAEN //ORR para habilitar el GPIOA
	STR r1, [r0]             //Escribir para aplicar el cambio
	LDR r1, [r0]             //Se guarda la configuración guardando el valor actualizado

	// Habilitar GPIOB (bit 1)
	ORR r1, r1, #RCC_GPIOBEN //ORR para habilitar el GPIOB
	STR r1, [r0]			//Se escribe en el espacio correspondiente para aplicar el cambio
	LDR r1, [r0]            //Se guarda la configuración guardando el valor actualizado

	// Habilitar GPIOC (bit 2)
	ORR r1, r1, #RCC_GPIOCEN //ORR para habilitar el GPIOA
	STR r1, [r0]			//Se escribe en el espacio correspondiente para aplicar el cambio

// Pequeño retardo para estabilizar el sistema
    MOV r2, #0x1000

delay1:
    SUBS r2, r2, #1
    BNE delay1

// Configura GPIOA: PA0–PA7, PA8 y PA9 como salidas
    LDR r0, =GPIOA_MODER
    LDR r1, [r0] //Carga el valor del moder A
    LDR r2, =0xFFFF0000 //Conjunto de bits de 0-15 correspondientes desde PA0 a PA7
    AND r1, r1, r2 //Limpia el conjunto de bits a 00 para configurarlo como input
    LDR r2, =0x00005555 //Establece 01 en cada bit para que sean salidas
    ORR r1, r1, r2  	//Establece las salidas en los bits
    ORR r1, r1, #(0x01 << 16)    // PA8 como salida
    ORR r1, r1, #(0x01 << 18)    // PA9 como salida
    STR r1, [r0] //Guarda el nuevo valor de los pines en el moder

// Configura GPIOB: PB0–PB2 como salidas
    LDR r0, =GPIOB_MODER
    LDR r1, [r0] //Carga el valor del moder b
    BIC r1, r1, #0x000000FF //Limpia los bits en caso de otra configuracion del moder b
    ORR r1, r1, #0x00000055 //Los establece como salida
    STR r1, [r0]	//Guarda el nuevo valor

// Configura botones (PC0 y PC13) como entradas con pull-up
    LDR r0, =GPIOC_MODER
    LDR r1, [r0] //Valor actual del moder c
    BIC r1, r1, #0x00000003      // Limpia los bits de PC0 a (00) (como entrada)
    BIC r1, r1, #0x0C000000      // Limpia los bits de PC13 a (00) (como entrada)
    STR r1, [r0]

    LDR r0, =GPIOC_PUPDR //Entradas del registro c
    LDR r1, [r0] //Valor de las entradas
    BIC r1, r1, #0x00000003 //Limpia los bits de configuracón de PC0
    BIC r1, r1, #0x0C000000 //Limpia los bits de configuracion de PC13
    ORR r1, r1, #0x00000001      // pone en pull-up para PC0
    ORR r1, r1, #0x04000000      // pone en pull-up para PC13
    STR r1, [r0] //Se guardan los cambios

// Enciende PB0 como indicador de velocidad lenta (la inicial en este caso)
    LDR r0, =GPIOB_ODR
    MOV r1, #0x01 //PIN PB0
    STR r1, [r0] //Se guarda el encendido

// Inicializa SysTick desactivado
    LDR r0, =STK_CTRL //Se carga la dirección del timer
    MOV r1, #0 //Se desactiva el timer
    STR r1, [r0] //Se guarda la configuracion

main_loop:
    BL check_buttons                     // Verifica estado de botones
    LDR r5, =GPIOA_ODR                   // Dirección de salida de GPIOA

// Paso 1: PA0 encendido
    MOV r0, #(1 << 0)
    STR r0, [r5]
    BL responsive_delay

// Paso 2: PA0 + PA1 + PA8
    MOV r0, #(1 << 0)
    MOV r1, #(1 << 1)
    MOV r2, #(1 << 8)
    ORR r6, r0, r1
    ORR r6, r6, r2
    STR r6, [r5]
    BL responsive_delay

// Paso 3: Solo PA8
    STR r2, [r5]
    BL responsive_delay

// Paso 4: PA8 + PA9 + PA4
    MOV r3, #(1 << 9)
    MOV r4, #(1 << 4)
    ORR r6, r2, r3
    ORR r6, r6, r4
    STR r6, [r5]
    BL responsive_delay

// Paso 5: Solo PA4
    STR r4, [r5]
    BL responsive_delay

// Paso 6: PA4 + PA5 + PA6
    MOV r7, #(1 << 5 | 1 << 6)
    ORR r6, r4, r7
    STR r6, [r5]
    BL responsive_delay

// Paso 7: Solo PA6
    MOV r6, #(1 << 6)
    STR r6, [r5]
    BL responsive_delay

// Paso 8: Solo PA7
    MOV r7, #(1 << 7)
    STR r7, [r5]
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
    BL check_buttons             // Permite cambiar velocidad en medio del retardo
    BL check_buttons

    LDR r1, =STK_CTRL
    LDR r2, [r1]
    ANDS r2, r2, #0x10000        // Espera hasta que cuente a cero
    BEQ delay_loop

    MOV r2, #0
    STR r2, [r1]
    POP {r0-r5, pc}

check_buttons:
    PUSH {r0-r5, lr}
    LDR r0, =GPIOC_IDR
    LDR r1, [r0]                 // Lee entradas actuales
    LDR r2, =last_button_state
    LDR r3, [r2]                 // Último estado guardado
    STR r1, [r2]                 // Guarda nuevo estado

    LDR r5, =button_debounce
    LDR r4, [r5]
    CMP r4, #0
    BEQ check_edges              // Solo si no hay rebote
    SUBS r4, r4, #1
    STR r4, [r5]
    B end_check

check_edges:
    TST r3, #BUTTON_BLUE         // Estaba presionado antes
    BEQ check_black_edge
    TST r1, #BUTTON_BLUE         // Ahora liberado
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
    LDREQ r2, =DELAY_LENTO
    STREQ r2, [r0]

    CMP r1, #2
    ITT EQ
    LDREQ r2, =DELAY_MEDIO
    STREQ r2, [r0]

    CMP r1, #3
    ITT EQ
    LDREQ r2, =DELAY_RAPIDO
    STREQ r2, [r0]

    BL update_leds
    POP {r0-r2, pc}

update_leds:
    PUSH {r0-r2, lr}
    LDR r0, =GPIOB_ODR
    MOV r2, #0
    STR r2, [r0]               // Apaga todos
    LDR r1, =delay_state
    LDR r1, [r1]

    CMP r1, #1
    ITT EQ
    MOVEQ r2, #0x01            // PB0 encendido = lento
    STREQ r2, [r0]

    CMP r1, #2
    ITT EQ
    MOVEQ r2, #0x02            // PB1 encendido = medio
    STREQ r2, [r0]

    CMP r1, #3
    ITT EQ
    MOVEQ r2, #0x04            // PB2 encendido = rápido
    STREQ r2, [r0]

    POP {r0-r2, pc}