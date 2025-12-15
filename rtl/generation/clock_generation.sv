/**
 *  Module: clock_generation
 *
 *  About: 
 *
 *  Ports:
 *
**/
module clock_generation (
    input                    common_p::clk_dom_s sys_dom_i,

    input                                         generation_en_i,
    input                                         clear_state_i,

// Recovery Feedback
    input         clks_alot_p::recovered_events_s recovered_events_i,
    input                                         fully_locked_in_i,
    input [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] high_rate_i,
    input [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] low_rate_i,

    output             clks_alot_p::clock_state_s unpausable_clk_state_o,

    input                                         pause_en_i,
    input                                         pause_polarity_i,
    output             clks_alot_p::clock_state_s pausable_clk_state_o,
    output                                        pause_start_violation_o,
    output                                        pause_stop_violation_o
);

/*
Have seeding/init interface
Track post-event deltas with value prioritizer
Add respective rate when targets are reached
Once delta has locked-in, update the counter every event

*/

// Delta Tracking

// Half-Rate Target

// Clock DFF

// Pause Control (Only mutes pausable output.... Pause needs to start in the Preemptive, then goes into the expected... so they can stop on the same edge)

// Event Generation
    event_generation event_generation (
        .sys_dom_i             (sys_dom_i),
        .clock_active_i        (),
        .io_clk_i              (),
        .half_rate_elapsed_i   (),
        .quarter_rate_elapsed_i(),
        .clk_events_o          (),
    );

endmodule : clock_generation
