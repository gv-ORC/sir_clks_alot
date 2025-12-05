/**
 * Package: clks_alot_p
 * 
 * Package for sir_clks_alot
 * 
 * Giovanni Viscardi 2/Dec/2025
**/

package clks_alot_p;

// Parameters
    parameter COUNTER_WIDTH = 32;

// Enums

    // TODO: clean up these comments...
    /*
       SINGLE_CONTINUOUS - Single Continuous clocks, pauses throw errors
                         > Basic Monostable - sense_i = io_clk_i[0]
         SINGLE_PAUSABLE - Single Continuous, pause status forwarded
                         > Basic Monostable - sense_i = io_clk_i[0]
          DIF_CONTINUOUS - Differential Clock Pair, pauses throw errors
                         > Basic Monostable - (sense_i = io_clk_i[0]) & (sense_i = io_clk_i[1]) When opposing edges both fire, if mismatch: throw violation
            DIF_PAUSABLE - Differential Clock Pair, pause status forwarded
                         > Basic Monostable -(sense_i = io_clk_i[0]) & (sense_i = io_clk_i[1]) When opposing edges both fire, if mismatch: throw violation
         QUAD_CONTINUOUS - Differential Data Pair, pauses throw errors
                         > Basic Monostable - (sense_i = io_clk_i[0]) & (sense_i = io_clk_i[1]) When opposing edges both fire, mismatches use dedicated events
           QUAD_PAUSABLE - Differential Data Pair, pause status forwarded
                         > Basic Monostable - (sense_i = io_clk_i[0]) & (sense_i = io_clk_i[1]) When opposing edges both fire, mismatches use dedicated events
    */
    typedef enum { 
        SINGLE_CONTINUOUS,
        SINGLE_PAUSABLE,
        DIF_CONTINUOUS,
        DIF_PAUSABLE, // If using Data, Pause duration should be longer than the longest stretch of possible 0s/1s in a data-frame
        QUAD_CONTINUOUS,
        QUAD_PAUSABLE
    } recovery_mode_e;

// Structs
    // typedef struct packed {
    //     logic recovery_over_violation;
    //     logic recovery_under_violation;
    //     logic minimim_frequency_violation;
    //     logic maximim_frequency_violation;
    // } clock_status_s;

    typedef struct packed {
        logic pos;
        logic neg;
    } recovery_pins_s;

    typedef struct packed {
        logic primary;
        logic secondary;
    } recovery_drivers_s;

    typedef struct packed {
        logic primary_rising_edge;
        logic primary_falling_edge;
        logic primary_either_edge;
        logic secondary_rising_edge;
        logic secondary_falling_edge;
        logic secondary_either_edge;
    } driver_events_s;

    typedef struct packed {
        logic rising_edge;
        logic falling_edge;
        logic dual_high_edge;
        logic dual_low_edge;
        logic any_valid_edge;
        logic diff_rising_edge_violation;
        logic diff_falling_edge_violation;
    } recovered_events_s;

    typedef struct packed {
        logic rising_edge;
        logic steady_high;
        logic falling_edge;
        logic steady_low;
    } generated_events_s;

    typedef struct packed {
        logic                     clk;
        logic                     pause_active;
        logic [COUNTER_WIDTH-1:0] pause_duration; // In IO Cycles
        logic                     locked;
        generated_events_s        events;
    } clock_state_s;

endpackage
