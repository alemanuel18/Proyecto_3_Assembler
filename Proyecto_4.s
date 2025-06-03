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
.equ BOTON_AZUL, 0x00002000                // Bit de PC13 (botón azul)
.equ BOTON_NEGRO,0x00000001                // Bit de PC0 (botón negro)

//Delays para las velocidades de los ciclos
.equ DELAY_LENTO,   50000000                 // Delay para velocidad lenta (2.5 s)
.equ DELAY_MEDIO, 30000000                 // Delay para velocidad media (1.5 s)
.equ DELAY_RAPIDO,   3000000                  // Delay para velocidad rápida (0.5 s)
.equ TIEMPO_REBOTE, 20000                   // Tiempo de rebote para evitar lecturas falsas
.equ INTERVALO_BOTON, 500             // Intervalo entre verificaciones de botones

.syntax unified
.cpu cortex-m4
.thumb

//Datos a utilizar al principio del programa
.section .data
//Se empieza en la velocidad lenta con su respectivo delay
delay_actual: .word DELAY_LENTO             // Retardo actual inicial (lento)
estado_delay:   .word 1                      // Estado de velocidad: 1=lento, 2=medio, 3=rápido
contador_rebote: .word 0                   // Contador de rebote del botón
ultimo_estado_boton: .word 0                 // Estado anterior de los botones

.section .text
.global main
//Autor: Marcelo Detlefsen
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

//Alejandro Jerez
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
    BIC r1, r1, #0x00000003      // Limpia los bits de PC0 a (00) (como entrada
    BIC r1, r1, #0x0C000000      // Limpia los bits de PC13 a (00) (como entrada
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

//Marcelo Detlefsen
main_loop:
    BL revisar_botones                     // Verifica estado de botones
    LDR r5, =GPIOA_ODR //Carga las direcciones de salida del GPIOA

// Paso 1: PA0 encendido
    MOV r0, #(1 << 0)
    STR r0, [r5]
    BL loop_delay

// Paso 2: PA0 + PA1 + PA8
    MOV r0, #(1 << 0)
    MOV r1, #(1 << 1)
    MOV r2, #(1 << 8)
    ORR r6, r0, r1
    ORR r6, r6, r2
    STR r6, [r5]
    BL loop_delay

// Paso 3: Solo PA8
    STR r2, [r5]
    BL loop_delay

// Paso 4: PA8 + PA9 + PA4
    MOV r3, #(1 << 9)
    MOV r4, #(1 << 4)
    ORR r6, r2, r3
    ORR r6, r6, r4
    STR r6, [r5]
    BL loop_delay

// Paso 5: Solo PA4
    STR r4, [r5]
    BL loop_delay

// Paso 6: PA4 + PA5 + PA6
    MOV r7, #(1 << 5 | 1 << 6)
    ORR r6, r4, r7
    STR r6, [r5]
    BL loop_delay

// Paso 7: Solo PA6
    MOV r6, #(1 << 6)
    STR r6, [r5]
    BL loop_delay

// Paso 8: Solo PA7
    MOV r7, #(1 << 7)
    STR r7, [r5]
    BL loop_delay

    B main_loop

//Autor: Julián Divas
loop_delay:
	//Guarda los registros para no perder sus valores
    PUSH {r0-r5, lr}
    LDR r0, =delay_actual
    LDR r0, [r0]	//Se obtiene el valor del delay actual usado para controlar la velocidad (ciclos)

    LDR r1, =STK_LOAD //Carga en r1 la dirección en memoria del timer a utilizar
    STR r0, [r1]	  //carga en r0 el valor del timer utilizado (los ciclos que se deben esperar para lograr la velocidad deseadad)
    LDR r1, =STK_VAL  //Se carga el contador actual del timer
    MOV r2, #0		  //Se coloca en 0 para empezar el conteo
    STR r2, [r1]	  //Se guarda la configuración del conteo
    LDR r1, =STK_CTRL //Carga la dirección para controlar el timer
    MOV r2, #0x05	  //Coloca el valor en 0000 0101 (usar el reloj del sistema para el temporizador)
    STR r2, [r1]	  //Se guarda la configuración

	BL leer_botones_delay

//Autor: Julián Divas
leer_botones_delay:
	//Revisa dos veces que se hayan apachado los botones para poder cambiar de velocidad en un ciclo o entre ciclos
    BL revisar_botones
    BL revisar_botones

	//carga la dirección para controlar el timer
    LDR r1, =STK_CTRL
    LDR r2, [r1]	//Se obtiene el valor del timer
    ANDS r2, r2, #0x10000        //Se espera a que el timer deje de contar (bit 16 countflag == 1)
    BEQ leer_botones_delay				//Sigue eseprando a que termine de contar el timer
    MOV r2, #0
    STR r2, [r1]		//Si ya terminó de contar se carga el 0 al controlador del timer para detenerlo
    POP {r0-r5, pc}		//Se restauran los valores guardados

//Autor: Julián Divas
revisar_botones:
    PUSH {r0-r5, lr}
    LDR r0, =GPIOC_IDR //Registro de entradas del GPIOC
    LDR r1, [r0]                 // Lee entradas actuales (del GPIOC)
    LDR r2, =ultimo_estado_boton	////Carga a R2 la variable del ultimo estado del boton
    LDR r3, [r2]                 // Obtiene el valor del ultimo estado del boton
    STR r1, [r2]                 // Se actualiza el estado de last button state

    LDR r5, =contador_rebote //contador de rebote
    LDR r4, [r5] //Carga el valor de la cantidad de veces que rebotó
    CMP r4, #0 //Se compara que no hubieran habido rebotes contador de rebote == 0
    BEQ revisar_flancos_azules  //En caso de que no haya rebote
    SUBS r4, r4, #1 //Si era distinto de 0, le quita 1 para esperar a que no haya rebote
    STR r4, [r5] //guarda el nuevo valor en el contador de rebotes
    B finalizar_revision	//Fin de la funcion

//Autor: Julián Divas
revisar_flancos_azules:
    TST r3, #BOTON_AZUL         //Compara si el bit del botón azul estaba activo antes, valor de R3
    BEQ revisar_flancos_negro		//Si no estaba activado antes, revisa otro boton
    TST r1, #BOTON_AZUL        // R1 tiene las entradas actuales del GPIOC, lo compara con el boton azul para ver si sigue presionado
    BNE revisar_flancos_negro		//Si sigue presionado no pasa nada y revisa otro botón
								//Si si está liberado (se trabaja con flanco de subida)
    LDR r0, =estado_delay		//Retardo utilizado actualmente
    LDR r1, [r0]				//CArga el valor del retardo
    CMP r1, #3					//Si ya es la velocidad 3, no se hace nada
    BEQ asignar_tiempo_rebote			//Se reinicia el tiempo de rebote para usar nuevamente el boton
    ADD r1, r1, #1				//Si no ha llegado al mmaximo, se aumenta en 1 el delay (para de 1 lento a 2 medio por ejemplo)
    STR r1, [r0]				//Se guarda el cambio en la variable
    BL actualizar_velocidad				//Con este cambio conlleva un aumento de velocidad
    B asignar_tiempo_rebote				//Se reinicia el tiempo de rebote para usar nuevamente el boton

//Autor: Julián Divas
revisar_flancos_negro:
    TST r3, #BOTON_NEGRO	//Compara si el bit del botón negro estaba activo antes, valor de r3
    BEQ finalizar_revision			// Si el bit era 0, osease no estaba presionado, se deja de revisar ya que no hay cambio
    TST r1, #BOTON_NEGRO	//Se verifica si el botón sigue presionado en caso si se haya apachado
    BNE finalizar_revision			//Si sigue presionado se termimna,

    LDR r0, =estado_delay	//Si ya no está presionado (es decir detectamos un flanco de bajada)
    LDR r1, [r0]			//Se carga en r1 el valor del delay actual
    CMP r1, #1				//Se compara para ver si ya está en la velocidad 1 (la más baja)
    BEQ asignar_tiempo_rebote		//Si ya esta en la más baja solo se aplica el tiempo de rebote
    SUB r1, r1, #1			//Si no está en la más baja, se baja en una velocidad
    STR r1, [r0]			//Se guarda el cambio
    BL actualizar_velocidad			//Se actualiza la velocidad

//Autor: Julián Divas
asignar_tiempo_rebote:
	//Se carga a 0 la variable tiempo de rebote
    LDR r0, =TIEMPO_REBOTE
    //Carga el valor definidod al contador de rebote
    STR r0, [r5]

finalizar_revision:
	//Restaura el estado anterior de los registros y sale de la funcion
    POP {r0-r5, pc}

//Autor: Julián Divas
//Actualizar la velocidad del patrón
actualizar_velocidad:
	//Se almacenan en una pila los registros para no perder sus valores actuales
    PUSH {r0-r2, lr}
    //Se carga la dirección de memoria del delay actual (tiempo)
    LDR r0, =delay_actual
    //Se carga la direccion de memoria del delay (estado, 1 = lento, 2 = medio, 3 = rapido)
    LDR r1, =estado_delay
    //Se carga el valor del estado del delay en r1
    LDR r1, [r1]

	//Se verifica si se encuentra en el estado de velocidad 1 (lento)
    CMP r1, #1
    ITT EQ
    LDREQ r2, =DELAY_LENTO //Si es igual, se carga la velocidad correspondiente a lento
    STREQ r2, [r0]		   //Guarda la configuración

	//Se verifica si se encuentra en el estado de velocidad 2 (medio)
    CMP r1, #2
    ITT EQ
    LDREQ r2, =DELAY_MEDIO //Si es igual se carga la velocidad correspondiente a medio
    STREQ r2, [r0] 		   //Se guarda la configuración

	//Se verifica si se encuentra en la velocidad 3 (rapida)
    CMP r1, #3
    ITT EQ
    LDREQ r2, =DELAY_RAPIDO //Si es igual se carga la velocidad correspondiente a rapido
    STREQ r2, [r0]			//Se guarda la configuración
	//Se actualizan las leds encendidas dependiendo de la velocidad
    BL actualizar_leds
    //Restaura los valores de los registros originales
    POP {r0-r2, pc}

//Autor: Julián Divas
//Define que led se encenderá dependiendo del estado de velocidad en el que se encuentre
actualizar_leds:
	//Se guardan los valores de los registros para no perderlos durante la funcion
    PUSH {r0-r2, lr}
    LDR r0, =GPIOB_ODR	//Se carga en R0 las salidas del GPIOO
    //Se asigna 0 a R2 para apagar todos los leds
    MOV r2, #0
    STR r2, [r0]              //Se guarda la configuración con todos apagados
    //Se obtiene el valor del estado de velocidad actual (1 =lento, 2 =  medio, 3 = rapido)
    LDR r1, =estado_delay
    LDR r1, [r1]

	//Si nos encontramos en el estado de velocidad lento "1"
    CMP r1, #1
    ITT EQ
    MOVEQ r2, #0x01            //Encendemos PB0
    STREQ r2, [r0]				//Se guarda la configuración

	//Si nos encontramos en el estado de velocidad media "2"
    CMP r1, #2
    ITT EQ
    MOVEQ r2, #0x02            //Encendemos PB1
    STREQ r2, [r0]			   //Se guarda la configuración

	//Si nos encontramos en el estado de veloicdad rapido "3"
    CMP r1, #3
    ITT EQ
    MOVEQ r2, #0x04            //Se enciende PB2
    STREQ r2, [r0]

	//Se recuperan los valores anteriores de los registros para que siga funcionando correctamente el programa
    POP {r0-r2, pc}
