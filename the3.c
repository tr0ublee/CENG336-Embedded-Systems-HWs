/*
 * Group No : Group 6
 * Student 1: Alperen Caykus, 2237170
 * Student 2: Yagiz Senal, 2237832
 * 
 * ==============================================================================================
 * 
 * Everything (TMR0, TMR1, TMR2, ADC, RB4) is interrupt driven, there is no polling.
 * We have seperated the game logic from the view logic with flag based approach.
 * 
 * Code Flow:
 * 
 * First, we initialize variables and SFRs.
 *
 * Then, program starts looping in the game loop.
 *
 * If an interrupt fires, we set the corresponding variable flag in our code and leave the ISR, everything is done in main function.
 * 
 * We used TMR2 that is configured to 10ms to check for RB4 debounce.
 *
 * When the game ends, we enter the blink loop, which blinks the 7 segment for 2s, and during that, it ignores everything except 
 * TMR1 interrupt, which controls hs_passed.
 *
 * After the game ends, i.e blink loop ends, we call our init function again, and game loop continues for the next game. 
 * 
 * ===============================================================================================
 * 
 * Tasks:
 * 
 * draw_hint -> Draws the given hint for the player, lights corresponding leds up (LATCDE) to draw an arrow.
 * 
 * clear_hint -> Turns off all leds (LATCDE) in the hint section
 * 
 * draw_seven_segment -> Draws the given value to the seven segment
 * 
 * clear_seven_segment -> Turns off the seven segment leds
 * 
 * parse_adc_value -> Reads the value entered from potentiometer and maps it into guess numbers
 * 
 * blink -> Waits for TMR1 interrupt and takes necessary action based on the blink state, such as turning on or off LEDs.
 * 
 * get_display_value -> Given the number as param, returns the corresponding number to be loaded to the seven segment display.
*/


#pragma config OSC = HSPLL, FCMEN = OFF, IESO = OFF, PWRT = OFF, BOREN = OFF, WDT = OFF, MCLRE = ON, LPT1OSC = OFF, LVP = OFF, XINST = OFF, DEBUG = OFF

#include <xc.h>
#include "breakpoints.h"
#include <pic18f8722.h>


#define TIMER0_PRELOAD_VALUE 3036
#define TIMER1_PRELOAD_VALUE 60720
#define TIMER1_HALF_SECOND_COUNT 20
#define TIMER2_POSTSCALE_COUNT 3
#define GAME_END_HALF_SECOND_COUNT 10

/**
 * Software level postscale for half second interrupts. TMR1 does not natively support 500ms delays, therefore we count
 *  the number of times the interrupt is fired and make calculations based on that.
 */
int postscale_interrupt_half_second;

/**
 * Counts how many half seconds has passed. We can check if the game ended with this variable.
 */
int counter_half_second;

/**
 * Used to calculate 10ms intervals using TMR2.
 */
int postscale_interrupt_ten_ms;

/**
 * Container variable for user guess.
 */
char user_guess;

/**
 * Flags start
 */
char game_ended;
char button_pressed;
char rb4_prev_state;
char adc_invalid;
char blink_state_invalid;
/**
 * Flags end
 */

/**
 * Container for special number for this instance of the game. Multiple calls to special_number function can generate
 *  different values within the same game.
 */
char current_special_number;

/**
 * The state of the blink part of the game.
 */
int blink_state;

/**
 * Dummy variable for PORTB read to reset INTCON (especially RBIF).
 */
char dummy_read_portb_for_reset;

/**
 * Describes which hint to be drawn.
 */
enum hint_t {
    ARROW_UP, ARROW_DOWN
};

void draw_hint(enum hint_t current_hint);

void draw_seven_segment(char value);

void clear_seven_segment(void);

void clear_hint(void);

char get_display_value(char);

char parse_adc_value(void);

void blink(void);

void __interrupt()interrupt_handler(){

    if (INTCONbits.RBIF) { // Button state changed

        rb4_prev_state = PORTBbits.RB4;
        INTCONbits.RBIF = 0;

        if (!game_ended) {
            
            if(!T2CONbits.TMR2ON){
                
                TMR2 = 0;
                T2CONbits.TMR2ON = 1;
                
            }else{
                
                TMR2 = 0;
                T2CONbits.TMR2ON = 0;
            }
            
            
        }
    }

    if (PIR1bits.TMR2IF) {
        PIR1bits.TMR2IF = 0;

        if (++postscale_interrupt_ten_ms == TIMER2_POSTSCALE_COUNT && !game_ended) {
            //10ms has passed (9.91ms actually)
            T2CONbits.TMR2ON = 0;
            postscale_interrupt_ten_ms = 0;
            button_pressed = rb4_prev_state;
            
        }
    }


    if (INTCONbits.TMR0IF) { // TMR0 overflowed
        // 50ms has passed, should sample potentiometer
        INTCONbits.TMR0IF = 0;

        TMR0 = TIMER0_PRELOAD_VALUE;

        if (!game_ended) {
            ADCON0bits.GO = 1;

        }
    }

    if (PIR1bits.ADIF) {
        // Conversion time is passed
        PIR1bits.ADIF = 0;

        if (!game_ended) {
            adc_value = ADRES;
            adc_invalid = 1;

            adc_complete();
        }
    }

    if (PIR1bits.TMR1IF) { // TMR1 overflowed
        PIR1bits.TMR1IF = 0;
        postscale_interrupt_half_second++;
        if (postscale_interrupt_half_second == TIMER1_HALF_SECOND_COUNT - 1){
            TMR1 = TIMER1_PRELOAD_VALUE;
        } else if (postscale_interrupt_half_second == TIMER1_HALF_SECOND_COUNT) {
            // Half a second is passed
            postscale_interrupt_half_second = 0;
            hs_passed();
            if (game_ended) {
                blink_state++;
                blink_state_invalid = 1;

            } else if (++counter_half_second == GAME_END_HALF_SECOND_COUNT) {
                counter_half_second = 0;
                game_ended = 1;
                game_over();
                blink_state = 1;
                blink_state_invalid = 1;
            }
        }
    }
}

void init_program() {

    dummy_read_portb_for_reset = PORTBbits.RB4;
    INTCON = 0x0;

    // Clear used ports
    PORTB = 0x0;
    PORTC = 0x0;
    PORTD = 0x0;
    PORTE = 0x0;
    PORTJ = 0x0;
    PORTH = 0x0;

    TRISB = 0x0;
    TRISC = 0x0;
    TRISD = 0x0;
    TRISE = 0x0;
    TRISJ = 0x0;
    TRISH = 0x0;  // RH4 = AN12

    TRISBbits.RB4 = 1; // Set RB4 as input

    TRISHbits.RH4 = 1; // Make potentiometer input

    PIE1 = 0x0;
    PIR1 = 0x0;


    ADCON0 = 0x0;
    ADCON1 = 0x0;
    ADCON2 = 0x0;

    TMR0 = 0x0;
    TMR1 = 0x0;
    TMR2 = 0x0;

    T0CON = 0x0;
    T1CON = 0x0;
    T2CON = 0x0;
    PR2 = 0x0;
    T0CONbits.T0PS = 2; // Make prescaler 1:8
    T0CONbits.T08BIT = 0; // Use 16 bit mode

    T1CONbits.T1CKPS = 2; // prescaler set to 8
    T1CONbits.RD16 = 1; // test

    T2CONbits.T2CKPS = 2; //  Prescaler 16
    // postscale is 8;
    T2CONbits.T2OUTPS0 = 1;
    T2CONbits.T2OUTPS1 = 1;
    T2CONbits.T2OUTPS2 = 1;
    T2CONbits.T2OUTPS3 = 0;
    PR2 = 255;

    ADCON0bits.CHS = 12; // Use channel RH4 = AN12 

    ADCON1bits.PCFG = 0;

    ADCON2bits.ADCS = 2; // Table 21-1
    ADCON2bits.ADFM = 1; // Right justified

    INTCONbits.RBIE = 1;
    INTCONbits.TMR0IE = 1;
    PIE1bits.TMR1IE = 1;
    PIE1bits.ADIE = 1;
    INTCONbits.PEIE = 1;
    PIE1bits.TMR2IE = 1;


    postscale_interrupt_half_second = 0;
    counter_half_second = 0;
    user_guess = 0;
    game_ended = 0;
    button_pressed = 0;
    adc_invalid = 0;
    blink_state_invalid = 0;
    blink_state = 0;
    current_special_number = special_number();
    postscale_interrupt_ten_ms = 0;
    rb4_prev_state = 0;

    TMR0 = TIMER0_PRELOAD_VALUE;
    T0CONbits.TMR0ON = 1;
    T1CONbits.TMR1ON = 1;
    T2CONbits.TMR2ON = 0;

    ADCON0bits.ADON = 1;

    INTCONbits.GIE = 1;
    init_complete();


}


void main(void) {
    init_program();
    while (1) {
        if (button_pressed) {

            button_pressed = 0;
            rb4_handled();
            int user_guess = parse_adc_value();

            if (user_guess == current_special_number) {
                game_ended = 1;
                correct_guess();
                TMR1 = 0;
                postscale_interrupt_half_second = 0;
                blink_state = 1;
                blink_state_invalid = 1;

            } else if (user_guess > current_special_number) {
                draw_hint(ARROW_DOWN);
            } else {
                draw_hint(ARROW_UP);
            }
        }

        if (adc_invalid) {
            adc_invalid = 0;
            draw_seven_segment(parse_adc_value());
        }

        if (game_ended) {
            clear_hint();
            TMR1 = 0;
            postscale_interrupt_half_second = 0;
            blink();
            restart();
            init_program();
            continue;
        }
    }
}


void blink() {
    while (1) {
        if (blink_state_invalid) {
            blink_state_invalid = 0;

            if (blink_state == 1 || blink_state == 3) {
                draw_seven_segment(current_special_number);
            } else if (blink_state == 2 || blink_state == 4) {
                clear_seven_segment();
            } else {
                blink_state = 0;
                break;
            }
        }
    }

}

char parse_adc_value() {

    // works on endpoints
    int value = -1;
    int adc_copy = adc_value;

    do {
        value++;
        adc_copy -= 102;
    } while (adc_copy > 0);
    if (value <= 9) {
        return value;
    } else {
        // when adc_value is greater than 1020, normalize value(i.e, return 9)
        return 9;
    }
}

void draw_hint(enum hint_t hint) {
    switch (hint) {
        case ARROW_DOWN:
            LATC = 0x4;
            LATD = 0xF;
            LATE = 0x4;
            break;
        case ARROW_UP:
            LATC = 0x2;
            LATD = 0xF;
            LATE = 0x2;
            break;
    }
    latcde_update_complete();
}

void clear_hint() {
    LATC = 0x0;
    LATD = 0x0;
    LATE = 0x0;
    latcde_update_complete();
}

void draw_seven_segment(char value) {
    PORTHbits.RH3 = 1;
    PORTHbits.RH2 = 0;
    PORTHbits.RH1 = 0;
    PORTHbits.RH0 = 0;

    PORTJ = get_display_value(value);
    latjh_update_complete();
}

void clear_seven_segment() {
    PORTHbits.RH3 = 1;
    PORTHbits.RH2 = 0;
    PORTHbits.RH1 = 0;
    PORTHbits.RH0 = 0;

    PORTJ = 0;
    latjh_update_complete();
}

char get_display_value(char num) {
    /*
        * A table which returns the value to be loaded to 
        * PORTJ to display given @param num on the 7 segment display
    */
    
    char display_value;
    switch (num) {
        case 0:
            display_value = 63;
            break;
        case 1:
            display_value = 6;
            break;
        case 2:
            display_value = 91;
            break;
        case 3:
            display_value = 79;
            break;
        case 4:
            display_value = 102;
            break;
        case 5:
            display_value = 109;
            break;
        case 6:
            display_value = 125;
            break;
        case 7:
            display_value = 7;
            break;
        case 8:
            display_value = 127;
            break;
        case 9:
            display_value = 111;
            break;
        default:
            display_value = 0;
            break;
    }
    
    return display_value;
}
