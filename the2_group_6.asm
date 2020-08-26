; Group : 6
; Student 1: Alperen Caykus, 2237170
; Student 2: Yagiz Senal   , 2237832
; Grading Choice: Simulation (THE2_v2)
; Implemented on simulation environment: YES
; Also tested on board : YES
; Both work same: YES

#include "p18f8722.inc"

CONFIG OSC=HSPLL, FCMEN=OFF, IESO=OFF,PWRT=OFF,BOREN=OFF, WDT=OFF, MCLRE=ON, LPT1OSC=OFF, LVP=OFF, XINST=OFF, DEBUG=OFF

;*******************************************************************************
; Variables & Constants
;*******************************************************************************
UDATA_ACS

;bit 0: flag_spawn_balls
;bit 1: X
;bit 2: flag_board_invalid : IF SET, REDRAW THE BOARD
;bit 3: X
;bit 4: flag_hp_invalid
;bit 5: reset_game
flag_con res 1  ; A generic flag for the flags below.


; LAST = RIGHTMOST
game_state res 1 ; USES LAST THREE BITS
                    ; ...001 -> LEVEL_ONE
                    ; ...010 -> LEVEL_TWO
                    ; ...100 -> LEVEL_THREE


ball_positions_column_1 res 1  ; RA, LAST 6 BITS, 0 BIT RA0
ball_positions_column_2 res 1  ; RB, LAST 6 BITS, 0 BIT RB0
ball_positions_column_3 res 1  ; RC, LAST 6 BITS, 0 BIT RC0
ball_positions_column_4 res 1  ; RD, LAST 6 BITS, 0 BIT RD0 

; DOWN <- UP
; X000 0100 PORTA
; X000 0010 PORTB
;                                 3210
;                                 ABCD
; player_bar_position_left = 0000 1000
player_bar_position_left res 1   

player_hp res 1

balls_will_spawn_left res 1

interrupt_counter res 1

seven_segment_counter_high res 1 ; REDRAWS SEVEN SEGMENT ON OVERFLOW
seven_segment_counter_low res 1 ; REDRAWS SEVEN SEGMENT ON OVERFLOW
seven_segment_switch res 1  ; CHOOSES WHICH SEGMENT TO DRAW
                            ; RIGHTMOST BIT 0 => DRAW HP
                            ; RIGHTMOST BIT 1 => DRAW LEVEL

temp res 1
temp2 res 1
temp3 res 1

random_ball_seed_high res 1  
random_ball_seed_low res 1  

rg2_prev res 1
rg3_prev res 1

PLAYER_INITIAL_HEALTH equ 05H  

BALL_SPAWN_COUNT_LEVEL_ONE equ 05H 
BALL_SPAWN_COUNT_LEVEL_TWO equ 0AH 
BALL_SPAWN_COUNT_LEVEL_THREE equ 0FH 

LEVEL_ONE_TIMER_COUNT equ 4CH
LEVEL_TWO_TIMER_COUNT equ 3DH
LEVEL_THREE_TIMER_COUNT equ 35H

;*******************************************************************************
; Interrupt Vector
;*******************************************************************************
ORG 08h
GOTO INTERRUPT_START

  
;*******************************************************************************
; Reset Vector
;*******************************************************************************

ORG 00h           ; processor reset vector
GOTO START                   ; go to beginning of program

;*******************************************************************************
; MAIN PROGRAM
;*******************************************************************************

MAIN_PROG CODE  ; let linker place main program

INTERRUPT_START
    ;MOVF TMR0IF,1
   ; BCF INTCON, GIE
    BCF INTCON, TMR0IF
    DECFSZ interrupt_counter, 1 ;store it back in the interrupt_counter
    RETFIE				; skip this if zero

;****start handling the interrupt*****
    BSF flag_con,0
    BTFSC game_state,2
    GOTO level_3_handle
    BTFSC game_state,1
    GOTO level_2_handle
    MOVLW LEVEL_ONE_TIMER_COUNT
    MOVWF interrupt_counter
    ;BSF INTCON,GIE
    RETFIE

level_3_handle:
    MOVLW LEVEL_THREE_TIMER_COUNT
    MOVWF interrupt_counter
    ;BSF INTCON,GIE
    RETFIE
    
    
level_2_handle:
    MOVLW LEVEL_TWO_TIMER_COUNT
    MOVWF interrupt_counter
    ;BSF INTCON,GIE
    RETFIE
    

ACTION_INITIALIZE
    ; Set PORTA,B,C,D as output
    
    CLRF PORTA
    MOVLW 0Fh
    MOVWF ADCON1 ; SET ADCON
    CLRF PORTB
    CLRF PORTC
    CLRF PORTD 
    CLRF PORTG
    CLRF PORTH
    CLRF PORTJ
    CLRF TRISA
    CLRF TRISB
    CLRF TRISC
    CLRF TRISD 
    CLRF TRISG
    CLRF TRISH
    CLRF TRISJ  
 
    ; DONE
    CLRF flag_con
    CLRF game_state
    CLRF ball_positions_column_1
    CLRF ball_positions_column_2
    CLRF ball_positions_column_3
    CLRF ball_positions_column_4
    CLRF player_hp
    CLRF balls_will_spawn_left
    CLRF interrupt_counter
    CLRF temp
    CLRF temp2
    CLRF temp3
    CLRF random_ball_seed_high
    CLRF random_ball_seed_low
    CLRF rg2_prev
    CLRF rg3_prev
    CLRF seven_segment_counter_high
    CLRF seven_segment_counter_low
    CLRF seven_segment_switch
    ; Set PORTG as input
    BSF TRISG, 0
    BSF TRISG, 2
    BSF TRISG, 3
    ; DONE

    CLRF player_bar_position_left
    BSF player_bar_position_left,3
    BSF LATA,5
    BSF LATB,5


    CALL INIT_LEVEL
    CALL ACTION_DRAW_HP
    ; Configure 7 segment display
    ; DONE

    ; Configure TIMER1
    CLRF T1CON
    BSF T1CON, TMR1ON ; Enable TIMER1
    BSF T1CON, RD16 ; Enables register read/write of Timer1 in one 16-bit operation
    ; DONE

    ; Configure TIMER0
    CLRF T0CON  ; T0CON, PSA is not set (prescaler is enabled)
    BSF T0CON, T08BIT ; Set TIMER0 as 8bit
    BSF T0CON,T0PS0 ; Set prescaler value to 1:256
    BSF T0CON,T0PS1
    BSF T0CON,T0PS2
    
    BSF T0CON, TMR0ON ; Enable Timer0
    ; DONE
    CLRF TMR0 
    CLRF INTCON
    BSF INTCON, TMR0IE

    RETURN
START
    CALL ACTION_INITIALIZE
    GOTO LOOP_GAME_NOT_STARTED
    
EVENT_START_GAME_BUTTON_PRESS

 wait_RG0_button_press:
    CALL ACTION_DRAW_SEVEN_SEGMENT
    BTFSC PORTG,0 ; test if button is pressed
    GOTO wait_RG0_button_release ; when 1
    GOTO wait_RG0_button_press		  ; when 0
wait_RG0_button_release:
    CALL ACTION_DRAW_SEVEN_SEGMENT
    BTFSC PORTG,0 ; test
    GOTO wait_RG0_button_release ; when 1 (still pressing)
    BSF game_state,0        ;release
    MOVFF TMR1L,random_ball_seed_low
    MOVFF TMR1H,random_ball_seed_high
    CLRF TMR0
    BSF flag_con,0
    BSF INTCON,GIE
    RETURN   
LOOP_GAME_NOT_STARTED
    CALL EVENT_START_GAME_BUTTON_PRESS
    GOTO GAME_LOOP
INIT_LEVEL ; Call level specific initializer based on current level
    CLRF TMR0
    BTFSC game_state, 2           
    GOTO init_level3_and_return
    BTFSC game_state, 1
    GOTO init_level2_and_return
    CALL  ACTION_INITIALIZE_LEVEL_ONE
    RETURN 
init_level3_and_return:
    CALL ACTION_INITIALIZE_LEVEL_THREE
    CALL ACTION_DRAW_LEVEL
    RETURN
init_level2_and_return:
    CALL ACTION_INITIALIZE_LEVEL_TWO 
    CALL ACTION_DRAW_LEVEL
    RETURN


ACTION_INITIALIZE_LEVEL_ONE
    CLRF balls_will_spawn_left
    CLRF interrupt_counter
    CLRF player_hp
    CLRF game_state
    BSF game_state,0
    BSF INTCON, GIE
    MOVLW LEVEL_ONE_TIMER_COUNT
    MOVWF interrupt_counter
    MOVLW BALL_SPAWN_COUNT_LEVEL_ONE
    MOVWF balls_will_spawn_left
    MOVLW PLAYER_INITIAL_HEALTH
    MOVWF player_hp
    RETURN
    
ACTION_INITIALIZE_LEVEL_TWO
    MOVLW BALL_SPAWN_COUNT_LEVEL_TWO
    MOVWF balls_will_spawn_left
    CLRF interrupt_counter
    MOVLW LEVEL_TWO_TIMER_COUNT
    MOVWF interrupt_counter
    BCF game_state,0
    BSF game_state,1
    RETURN

ACTION_INITIALIZE_LEVEL_THREE
    MOVLW BALL_SPAWN_COUNT_LEVEL_THREE
    MOVWF balls_will_spawn_left
    CLRF interrupt_counter
    MOVLW LEVEL_THREE_TIMER_COUNT
    MOVWF interrupt_counter
    BCF game_state,1
    BSF game_state,2
    RETURN
    

GAME_LOOP
;user pressed rg3 first then rg2

    CALL EVENT_PLAYER_MOVE_LEFT_BUTTON_PRESS
    CALL EVENT_PLAYER_MOVE_RIGHT_BUTTON_PRESS
    BTFSC flag_con,0
    CALL ACTION_SPAWN_BALLS
    BTFSC flag_con, 2
    CALL ACTION_DRAW_BOARD
    CALL ACTION_DRAW_SEVEN_SEGMENT
    CALL ACTION_CHECK_GAME_ENDED
    BTFSC flag_con,5
    GOTO START
    GOTO GAME_LOOP


ACTION_DRAW_SEVEN_SEGMENT
    DECFSZ seven_segment_counter_low
    RETURN
    BTFSC seven_segment_switch,0
    GOTO draw_level
    BSF seven_segment_switch,0
    CALL ACTION_DRAW_HP
    RETURN

draw_level:
    CALL ACTION_DRAW_LEVEL
    BCF seven_segment_switch,0
    RETURN


EVENT_PLAYER_MOVE_LEFT_BUTTON_PRESS
    ; Check if currently 0
    BTFSC PORTG,3
    GOTO LEFT_CURRENT_ONE ; RG3 = 1
    BTFSS rg3_prev,0 ; RG3 = 0, CHECK PREV
    GOTO LEFT_CURRENT_ZERO_PREV_ZERO ; RG3 = 0, PREV = 0

    ; RG3 = 0, PREV = 1 -- MEANS RELEASED
    BCF rg3_prev,0
    BTFSC player_bar_position_left, 3
    RETURN
    BTFSS player_bar_position_left, 2
    GOTO left_move_default_case       ; no case left, left end of the bar is on PORTC 
    ; BC => AB
    BTFSC ball_positions_column_1,5
    BCF ball_positions_column_1,5
    BCF player_bar_position_left, 2
    BSF player_bar_position_left, 3
    BCF LATC,5
    BSF LATA,5
    RETURN
LEFT_CURRENT_ZERO_PREV_ZERO
    BCF rg3_prev,0
    RETURN
LEFT_CURRENT_ONE
    BSF rg3_prev,0 ; SET PREV TO 1
    RETURN
left_move_default_case:
    ; CD => BC
    BTFSC ball_positions_column_2,5
    BCF ball_positions_column_2,5
    BCF player_bar_position_left, 1
    BSF player_bar_position_left, 2 
    BCF LATD,5
    BSF LATB,5
    RETURN



EVENT_PLAYER_MOVE_RIGHT_BUTTON_PRESS
    ; Check if currently 0
    BTFSC PORTG,2
    GOTO RIGHT_CURRENT_ONE ; RG2 = 1
    BTFSS rg2_prev,0 ; RG2 = 0, CHECK PREV
    GOTO RIGHT_CURRENT_ZERO_PREV_ZERO ; RG2 = 0, PREV = 0

    ; RG2 = 0, PREV = 1 -- MEANS RELEASED
    BCF rg2_prev,0
    BTFSC player_bar_position_left, 1
    RETURN
    BTFSS player_bar_position_left, 2
    GOTO right_move_default_case
    ; BC => CD
    BTFSC ball_positions_column_4,5
    BCF ball_positions_column_4,5           ;when 1
    
    BCF player_bar_position_left, 2
    BSF player_bar_position_left, 1
    BCF LATB, 5
    BSF LATD, 5
    RETURN
RIGHT_CURRENT_ZERO_PREV_ZERO
    BCF rg2_prev,0
    RETURN
RIGHT_CURRENT_ONE
    BSF rg2_prev,0 ; SET PREV TO 1
    RETURN
right_move_default_case:
    ; AB => BC
    BTFSC ball_positions_column_3,5
    BCF ball_positions_column_3,5
    BCF player_bar_position_left, 3
    BSF player_bar_position_left, 2
    BCF LATA, 5
    BSF LATC, 5
    RETURN
ACTION_CHECK_GAME_ENDED

    TSTFSZ player_hp
    GOTO CHECK_BALLS ; HP != 0
    BSF flag_con,5 ; HP = 0
    RETURN
CHECK_BALLS:

    BTFSS game_state,2
    RETURN
    TSTFSZ balls_will_spawn_left
    RETURN

    TSTFSZ ball_positions_column_1 
    RETURN                          ; COLUMN 1 HAS BALLS, RETURN
    TSTFSZ ball_positions_column_2 
    RETURN                          ; COLUMN 2 HAS BALLS, RETURN
    TSTFSZ ball_positions_column_3 
    RETURN                          ; COLUMN 3  HAS BALLS, RETURN
    TSTFSZ ball_positions_column_4 
    RETURN                          ; COLUMN 4 HAS BALLS, RETURN
    BSF flag_con,5
    RETURN



ACTION_MOVE_BALLS_ONE_LEVEL_DOWN

    ; SHIFT COLUMN 1
    BCF ball_positions_column_1,7
    RLNCF ball_positions_column_1
    BTFSC ball_positions_column_1,6
    CALL MISS_BALL
    BCF ball_positions_column_1,6

    ; SHIFT COLUMN 2
    BCF ball_positions_column_2,7
    RLNCF ball_positions_column_2
    BTFSC ball_positions_column_2,6
    CALL MISS_BALL
    BCF ball_positions_column_2,6

    ; SHIFT COLUMN 3
    BCF ball_positions_column_3,7
    RLNCF ball_positions_column_3
    BTFSC ball_positions_column_3,6
    CALL MISS_BALL
    BCF ball_positions_column_3,6

    ; SHIFT COLUMN 4
    BCF ball_positions_column_4,7
    RLNCF ball_positions_column_4
    BTFSC ball_positions_column_4,6
    CALL MISS_BALL
    BCF ball_positions_column_4,6

    ; CLEAR BALL HITS
    BTFSS player_bar_position_left,3 ; PLAYER_BAR -> 1100
    GOTO clear_hits_bar_middle
    BCF ball_positions_column_1, 5
    BCF ball_positions_column_2, 5
    RETURN

clear_hits_bar_middle:
    BTFSS player_bar_position_left,2 ; PLAYER_BAR -> 0110
    GOTO clear_hits_bar_right
    BCF ball_positions_column_2, 5
    BCF ball_positions_column_3, 5
    RETURN
clear_hits_bar_right:
    BTFSS player_bar_position_left,1 ; PLAYER_BAR -> 0011
    RETURN
    BCF ball_positions_column_3, 5
    BCF ball_positions_column_4, 5
    RETURN


MISS_BALL
    TSTFSZ player_hp
    GOTO decrement_health
    RETURN
decrement_health:
    DECF player_hp
    BSF flag_con, 4
    RETURN

GET_SPAWN_COLUMN_NUMBER
    ; random_ball_seed => 1011 0010
    ; rightmost 3 => 0000 0010

    MOVF random_ball_seed_low,W
    BCF WREG,2
    BCF WREG,3
    BCF WREG,4
    BCF WREG,5
    BCF WREG,6
    BCF WREG,7

    ; Apply modulo operation
    ;MOVWF temp
    ;MOVLW 4H
    ;SUBWF temp,0
    ;BTFSC STATUS,N ; Check negative bit of status register
    ;MOVF temp,W ; Means subtraction overflowed

    MOVWF temp ; temp holds the column value

    ; Shift random seed values
    
    BTFSC game_state,2
    GOTO shift_five_times 
    BTFSC game_state,1
    GOTO shift_three_times 
    CALL SHIFT_RIGHT_RANDOM_BALL_SEEDS
    GOTO normalize_and_return
   

shift_five_times:
    CALL SHIFT_RIGHT_RANDOM_BALL_SEEDS
    CALL SHIFT_RIGHT_RANDOM_BALL_SEEDS
    CALL SHIFT_RIGHT_RANDOM_BALL_SEEDS
    CALL SHIFT_RIGHT_RANDOM_BALL_SEEDS
    CALL SHIFT_RIGHT_RANDOM_BALL_SEEDS
    GOTO normalize_and_return
shift_three_times:
    CALL SHIFT_RIGHT_RANDOM_BALL_SEEDS
    CALL SHIFT_RIGHT_RANDOM_BALL_SEEDS
    CALL SHIFT_RIGHT_RANDOM_BALL_SEEDS
    GOTO normalize_and_return
normalize_and_return:
    TSTFSZ temp
    GOTO temp_not_zero
    RETLW b'00001000'

temp_not_zero:
    DCFSNZ temp
    RETLW b'00000100'
    DCFSNZ temp
    RETLW b'00000010'
    RETLW b'00000001'

SHIFT_RIGHT_RANDOM_BALL_SEEDS
    CLRF temp2 ; TEMP REGISTER LAST TWO BITS HOLDS VALUES FOR RIGHTMOST BITS
                ; BIT 0 -> RIGHTMOST BIT OF LOW
                ; BIT 1 -> RIGHTMOST BIT OF HIGH
    BTFSC random_ball_seed_low,0    
    BSF temp2,0                     
    BTFSC random_ball_seed_high,0
    BSF temp2,1

    BCF random_ball_seed_high,0 ; CLEAR RIGHTMOST BITS SO 
    BCF random_ball_seed_low,0  ; LEFTMOST BITS WILL BE ZERO AFTER SHIFT

    RRNCF random_ball_seed_high
    RRNCF random_ball_seed_low

    BTFSC temp2,0 ; LOW RIGHTMOST ZERO?
    BSF random_ball_seed_high,7 ; LOW RIGHTMOST != 0
    BTFSC temp2,1               ; LOW RIGHTMOST = 0
    BSF random_ball_seed_low,7

    RETURN
    
ACTION_SPAWN_BALLS

    BCF flag_con,0
    TSTFSZ balls_will_spawn_left
    GOTO spawn_and_decrement;skip when 0 ( take when > 0)
    GOTO move_balls_down; no balls left

spawn_and_decrement:
    CALL GET_SPAWN_COLUMN_NUMBER  ; W=0000 0000 => 4TH COL => W= 0000 1000
move_balls_down:
    CALL ACTION_MOVE_BALLS_ONE_LEVEL_DOWN
    BSF flag_con, 2    ; set flag_board_invalid
    TSTFSZ balls_will_spawn_left
    GOTO add_new_balls_to_columns	    ;skip when 0 (do when 1)
    GOTO change_game_state
    
add_new_balls_to_columns:
    BTFSC WREG, 0
    BSF ball_positions_column_1,0    ; W0=1
    BTFSC WREG, 1
    BSF ball_positions_column_2,0    ; W1=1
    BTFSC WREG, 2
    BSF ball_positions_column_3,0    ; W2=1
    BTFSC WREG,3
    BSF ball_positions_column_4,0    ; W3=1     
    DECFSZ balls_will_spawn_left,1  ; store it back in F
    RETURN
change_game_state:
    BTFSC game_state,0          ;no balls will spawn, check if level is one
    GOTO set_game_state_level2  ;
    BTFSC game_state,1          ; level is not one, check if level is two
    GOTO set_game_state_level3
    RETURN
set_game_state_level2:
    BCF game_state,0
    BSF game_state,1
    CALL INIT_LEVEL
    RETURN
set_game_state_level3:
    BCF game_state,1
    BSF game_state,2
    CALL INIT_LEVEL
    RETURN


ACTION_DRAW_BOARD
    BCF flag_con, 2
    
    MOVFF ball_positions_column_1, LATA
    MOVFF ball_positions_column_2, LATB
    MOVFF ball_positions_column_3, LATC
    MOVFF ball_positions_column_4, LATD
    
    BTFSC player_bar_position_left,3 ; PORTA CHECK
    GOTO bar_position_left_PORTA       
    BTFSC player_bar_position_left,2 ; PORTB CHECK
    GOTO bar_position_left_PORTB    
    BSF LATC,5
    BSF LATD,5
    RETURN
bar_position_left_PORTA:                                    
    BSF LATA,5
    BSF LATB,5
    RETURN
bar_position_left_PORTB:                                    
    BSF LATB,5
    BSF LATC,5
    RETURN

ACTION_DRAW_HP
    BSF PORTH,3
    BCF PORTH,0
    BCF PORTH,1
    BCF PORTH,2
    MOVF player_hp,W
    CALL CONVERT_TO_DISPLAY_VALUE
    MOVWF PORTJ
    RETURN

ACTION_DRAW_LEVEL
    BTFSC game_state,2
    GOTO draw_level_3               
    BTFSC game_state,1           
    GOTO draw_level_2
    GOTO draw_level_1

draw_level_3:
    BSF PORTH,0
    BCF PORTH,1
    BCF PORTH,2
    BCF PORTH,3
    MOVLW 3
    CALL CONVERT_TO_DISPLAY_VALUE
    MOVWF PORTJ
    RETURN
draw_level_2:
    BSF PORTH,0
    BCF PORTH,1
    BCF PORTH,2
    BCF PORTH,3
    MOVLW 2
    CALL CONVERT_TO_DISPLAY_VALUE
    MOVWF PORTJ
    RETURN
draw_level_1:
    BSF PORTH,0
    BCF PORTH,1
    BCF PORTH,2
    BCF PORTH,3
    MOVLW 1
    CALL CONVERT_TO_DISPLAY_VALUE
    MOVWF PORTJ
    RETURN
; 
; Takes the value in WREG as decimal and sets the corresponding value to WREG in display value format
;
CONVERT_TO_DISPLAY_VALUE
    ; b'(dp)(g)(f)(e)(d)(c)(b)(a)'
    CLRF temp ; Set temp to 0
    CPFSLT temp ; Compare WREG with temp, skip if less than temp (zero)
    RETLW b'00111111' ; 0
    MOVWF temp
    DCFSNZ temp
    RETLW b'00000110' ; 1 
    DCFSNZ temp
    RETLW b'01011011' ; 2
    DCFSNZ temp
    RETLW b'01001111' ; 3
    DCFSNZ temp
    RETLW b'01100110' ; 4
    DCFSNZ temp
    RETLW b'01101101' ; 5
    DCFSNZ temp
    RETLW b'01111101' ; 6
    DCFSNZ temp
    RETLW b'00000111' ; 7
    DCFSNZ temp
    RETLW b'11111111' ; 8
    RETLW b'11101111' ; 9
  RETURN

END