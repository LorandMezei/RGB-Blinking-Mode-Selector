#include <msp430.h>

#define PC r0
#define SP r1
#define SR r2
#define CG r3

;------------------------------------------------------------------------------
; PROGRAM DATA (READ-ONLY)
		.section .rodata	; this should be placed in ROM
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; PROGRAM DATA (READ AND WRITE)
		.section .data		; this should be placed in RAM
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; PROGRAM INSTRUCTIONS
		.text				; this section isl for instructions
		.global MAIN
;------------------------------------------------------------------------------
MAIN:

		;============= DEFAULT ================
		; disable watchdog and run at 1Mhz
		mov		#WDTPW|WDTHOLD, &WDTCTL
		mov.b	&CALBC1_1MHZ,	&BCSCTL1
		mov.b	&CALDCO_1MHZ,	&DCOCTL
		;======================================

		;======== DEFAULT ========
		; initialize stack pointer
		mov		#0x400, SP
		;=========================

		;===================== SET UP TIMER 0 FOR BLUE LED =====================
		; (only pin p1.6, BLUE led)
		mov #TASSEL_2|ID_3|MC_1, &TA0CTL // sets up timer 0 (SMCLK, /4, Up mode)
		mov #31250, &TA0CCR0 // sets the limit we can count up to (1/4 a second)
		;;mov #CCIlE, &TA0CCTL0
		mov #OUTMOD_4, &TA0CCTL1 // associate timer 0 with a signal
	
		;---------------- TURNS ON BLUE LED --------------------
		; alternate output mode for P1.6 (bit 6 affects blue led)
		; set up P1.6 to listen to TA0.1
		mov.b #BIT6, &P1DIR // changes the output, whether the port is input or output, set = output, clear = input ( recieve interrupts)		
		mov.b #BIT6, &P1SEL // changes to its primary function (makes it blink?)
		;-------------------------------------------------------

		;======================================================================

		;====== SET UP TIMER 1 FOR GREEN LED ========
		; SET UP TIMER 1 (GREEN led, use an interrupt)
		;---------------------------------------------
		mov #TASSEL_2|ID_3|MC_1, &TA1CTL // sets up timer 1 (SMCLK, /4, Up mode)
		mov #41666, &TA1CCR0 // sets the limit we can count up to (1/3 a second)
		mov #CCIE, &TA1CCTL0 // associate timer 1 with an interrupt
	        ;;mov #OUTMOD_4, &TA1CCTL1
		;============================================
		
		//// mov.b #BIT1, &P1DIR
		//// mov.b #BIT1, &P1DIR // sets green led to output
		//// clr &P1DIR|
		//// bic.b #BIT1, &P1 // clear
		//// red led targeting via loop (delay)

		clr r11
	
		;========= INTERRUPTS =========
		// Execute once, button stuff //
	        // For old boards
		mov.b #~BIT3, &P1DIR 
		mov.b #BIT3, &P1REN
		mov.b #BIT3, &P1OUT
		// For interrupts
		bis.b #BIT3, &P1IE  ; OR
		bis.b #BIT3, &P1IES
		bic.b #BIT3, &P1IFG ; clear // mov #0, &P1IFG // clear all interrupts

		eint // enable interrupts
		;==============================

		;======== SET UP MODE COUNTER =========
		mov #0, r6
		;======================================


		;======= TURN OFF BLUE/GREEN LED TIMERS =========
		bic.b #MC_3, &TA0CTL // stop timer 0 (blue led)
		bic.b #MC_3, &TA1CTL // stop timer 1 (green led)
		;================================================

		// Additional ways to turn on/off timers and leds
		;bis.b #MC_1, &TA0CTL // turn off blue led timer
		;bis.b #MC_1, &TA1CTL // turn off green led timer
		;mov #TASSEL_2|ID_3|MC_1, &TA0CTL // turn blue timer back on
		;mov #TASSEL_2|ID_3|MC_1, &TA1CTL // turn green timer back on
		;bic.b #BIT1, &P1OUT // turn off green led
		;bic.b #BIT6, &P1OUT // turn off blue led

;=============== EXECUTION LOOP ==================
.Lloop:
	
		;jmp .MODE_3

		cmp #0, r6
		jeq .MODE_0

		cmp #1, r6
		jeq .MODE_1

		cmp #2, r6
		jeq .MODE_2

		cmp #3, r6
		jeq .MODE_3
	
		// Reset counter after mode 3 
		cmp #4, r6
		jge .reset_counter

		jmp		.Lloop

;==================================================

;============================= MODE 0 ====================================	
.MODE_0: ; Red LED blinks every 1/2 a second (using execution loop)
; ------------------------------------------------------------------------

		bic.b #MC_3, &TA0CTL // stop timer 0 (blue led)
		bic.b #MC_3, &TA1CTL // stop timer 1 (green led)
		bic.b #BIT1, &P1OUT // turn off green led
		bic.b #BIT6, &P1OUT // turn off blue led

		;--------------- MAKE RED LED BLINK -------------------
		xor.b #BIT0, &P1OUT // Swap if red LED is on or off.
		mov #500, r15  //
		call #delay_ms // Make red led blink every half second.
		;------------------------------------------------------

		jmp .Lloop // Jump back into the execution loop

;=========================================================================

;============================= MODE 1 ====================================
.MODE_1: ; Red LED blinks every 1/2 second (using execution loop)
         ; Green LED blinks every 1/3 second (using timer & interrupt)
;-------------------------------------------------------------------------

		;--------------- MAKE RED LED BLINK -------------------
		xor.b #BIT0, &P1OUT // Swap if red LED is on or off.
		mov #500, r15  //
		call #delay_ms // Make red led blink every half second.
		;------------------------------------------------------

		mov #TASSEL_2|ID_3|MC_1, &TA1CTL // turn green timer back on

		jmp .Lloop // Jump back into the execution loop	

;=========================================================================

;============================= MODE 2 ====================================
.MODE_2: ; Red LED turns off
	 ; Green LED blinks every 1/3 second (using timer & interrupt)
	 ; Blue LED blinks every 1/4 second (using timer & signal)
;-------------------------------------------------------------------------

		// red led will either be always ON or always OFF depending on its state
		// when you changed from mode 1 to mode 2 (since not looping to blink anymore)

		bic.b #BIT0, &P1OUT // turn off red led
		
		mov #TASSEL_2|ID_3|MC_1, &TA0CTL // turn blue timer back on

		jmp .Lloop
;=========================================================================

;============================= MODE 3 ====================================
.MODE_3: ; Red LED stays off
	 ; Green LED turns off
	 ; Blue LED blinks slower, every 1/2 second (using timer & signal)
;-------------------------------------------------------------------------

		mov #62500, &TA0CCR0 // sets the limit we can count up to (1/2 a second)

		bic.b #MC_3, &TA1CTL // stop timer 1 (green led)
		bic.b #BIT1, &P1OUT // turn off green led

		jmp .Lloop
;=========================================================================
	

.reset_counter:
		bic.b r6, r6

		ret

;------------------------------------------------------------------------------
; DELAY_MS FUNCTION
;------------------------------------------------------------------------------
delay_ms:
		mov		r15, r14
1:		mov		#245, r15
2:		dec		r15
		tst		r15
		jnz		2b
		dec		r14
		jnz		1b
		ret

/////////////////////////////////////////////////////////
// BUTTON INTERRUPT SERVICE ROUTINE for CHANGING MODES //
/////////////////////////////////////////////////////////
BUTTON_ISR: // PORT1_VECTOR
	
		// Saving the values in r15 and r14
		push r15
		push r14

		add #1, r6 // Increment mode counter by 1

		mov #500, r15  //
		call #delay_ms // Delay to prevent double clicking

		// Pop the values
		pop r14
		pop r15

		bic.b #BIT3, &P1IFG // clear bit3 from p1ifg

		reti

////////////////////////////////////////////////////
// TIMER1 INTERRUPT SERVICE ROUTINE for GREEN LED //
////////////////////////////////////////////////////
Timer1_A0_ISR:

		xor.b #BIT1, &P1OUT // Swap if green LED is on or off.

		reti
	

;------------------------------------------------------------------------------
; UNEXPECTED INTERRUPT SERVICE ROUTINE
;------------------------------------------------------------------------------
UNEXPECTED_ISR:
		reti

;------------------------------------------------------------------------------
; INTERRUPT VECTORS
;------------------------------------------------------------------------------
		.section ".vectors", "ax", @progbits
		.word UNEXPECTED_ISR	;0xffe0
		.word UNEXPECTED_ISR	;0xffe2
		.word BUTTON_ISR        ;0xffe4 (PORT1_VECTOR
		;.word UNEXPECTED_ISR	;0xffe4 (PORT1_VECTOR)
		.word UNEXPECTED_ISR	;0xffe6 (PORT2_VECTOR)
		.word UNEXPECTED_ISR	;0xffe8
		.word UNEXPECTED_ISR	;0xffea (ADC10_VECTOR)
		.word UNEXPECTED_ISR	;0xffec (USCIAB0TX_VECTOR)
		.word UNEXPECTED_ISR	;0xffee (USCIAB0RX_VECTOR)
		.word UNEXPECTED_ISR	;0xfff0 (TIMER0_A1_VECTOR)
		.word UNEXPECTED_ISR	;0xfff2 (TIMER0_A0_VECTOR)
		.word UNEXPECTED_ISR	;0xfff4 (WDT_VECTOR)
		.word UNEXPECTED_ISR	;0xfff6 (COMPARATORA_VECTOR)
		.word UNEXPECTED_ISR	;0xfff8 (TIMER1_A1_VECTOR)
		.word Timer1_A0_ISR
		;.word UNEXPECTED_ISR	;0xfffa (TIMER1_A0_VECTOR)
		.word UNEXPECTED_ISR	;0xfffc (NMI_VECTOR)
		.word MAIN				;0xfffe (RESET_VECTOR)
		.end


// BIT 0 is RED, BIT 1 is GREEN, BIT 6 is BLUE
// timer1 just handles turning green light on and off
// XOR for changing color
// CCIE is interrupt enable
// get out of interrupts in modes? jump into modes from loop?


// Button 1 ISR functionality:1) Turn on/off lights,
// irrespective of loops or timers
// 2) Alter timer speeds.