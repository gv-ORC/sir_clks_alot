module generation (
    input                 common_p::clk_dom_s sys_dom_i,

    //? Generation
    input                                     set_polarity_i,
    input                                     starting_polarity_i,

    input                                     generation_en_i, // When this goes low, clock will stop on the next starting_polarity
    output                                    busy_o,
    input  [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] expected_half_rate_minus_two_i, // change every half-rate pulse, and you can get PWM
    input  [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] expected_quarter_rate_minus_one_i,
    input  [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] preemptive_half_rate_minus_one_i,
    input  [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] preemptive_quarter_rate_minus_one_i,

    //? Recovery - To accomodate for skew/drift
    input  [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] sync_cycle_offset_i,
    input          clks_alot_p::clock_state_s actual_clk_state_i, // for "Clock came too Early"

    //? Unpausable Output
    output         clks_alot_p::clock_state_s unpausable_expected_clk_state_o,
    output         clks_alot_p::clock_state_s unpausable_preemptive_clk_state_o,

    //? Pausable Output
    // Pauses maintain clock phasing when enabling and disabling
    // Pauses enable & disable when clock polarity matches
    input                                     pause_en_i,
    input                                     pause_polarity_i,
    output         clks_alot_p::clock_state_s pausable_expected_clk_state_o,
    output         clks_alot_p::clock_state_s pausable_preemptive_clk_state_o,
    output                                    pause_start_violation_o,
    output                                    pause_stop_violation_o
);

/*
> Do not update the rate if it's within the defined drift window...
  Or have the lockin be a set number of identical rates in a row... Just have a counter
> Have a max allowable amount of IO cycles with inconsitant rates that can occur before a "difficultly locking" violation is raised 
  (Kinda like a, "lockin timeout")
> Have an allowable drift-frequency... if drifting happens too often, then throw an "non-even multiple rate detected"
Expected Counter: (* = received edge, ? = Assumed edge)
30, 31, 32?, 33, 34, 35, 36?, 37, 38, 39*, 40, 41, 42, 43*, 44
Drift Accumulator:
0,  0,  0,   0,  0,  0,  0,   0,  0,  0,   -1, 0,  0,   0,  0
Expected Edge Limit: (* = Update Drift Accumulator)
32, 32, 32, 36, 36, 36, 36, 40, 40, 40,  43, 43, 43, 43,  47
Missed Cycle Counter: (Tracks how many times the local system has toggled its state without seeing any data edges - Only for Pausable)
0,      1,               2,                0,               0

> Have a drift-accumulator for preemptive counters that are overly preemptive.
> Apply the drift-accumulator at-most once every `n` IO Edges. (This should be configurable) 
  ^ NO.. if a drift happens that often, it should flag an error...
    > Instead, have a way to configure how offten a drift is allowed to occur
Preemptive Counter:
27, 28*, 29, 30, 31, 32*, 33, 34, 35, 36*, 37, 38, 39*, 40, 41, 42, 43*
Drift Accumulator:
0,  0,   0,  0,  0,  0,   0,  0,  0,  0,   -1, 0,  0,   0,  0,  0,  0
Preemtive Edge Limit: (* = Apply Drift Accumulator)
28, 28,  32, 32, 32, 32,  36, 36, 36, 36, 40*, 39, 39,  43, 43, 43, 43

TODO:
1. Create a lockin system that looks for repeating clock rates, or a multiple of clock rates (ex, rate is 10, next edge is at 20)
2. Create Drift-History system for assumed drifts during strings of like-bits (pausable data)
3. Create proper Counter system
4. Work on how pausing will work... (between transactions, not during like-bits inside the same transaction)
*/

// Counter
    reg  [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] generation_count_current;
    wire [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] generation_count_next = (sync_rst || clear_state_i)
                                                                       ? clks_alot_p::RATE_COUNTER_WIDTH'(0)
                                                                       : (generation_count_current + clks_alot_p::RATE_COUNTER_WIDTH'(1));
    wire                                         generation_count_trigger = sync_rst
                                                                         || (clk_en && generation_en_i)
                                                                         || (clk_en && clear_state_i);
    always_ff @(posedge clk) begin
        if (generation_count_trigger) begin
            generation_count_current <= generation_count_next;
        end
    end


// Next Expected Half-Rate Limit (Quarter-Rate is calculated off of this)
/*
Reacts instantly to incoming events.
Uses incoming events to calculate drifts.
Hold last Limit to check for the late-half of the drift window.
Detects and Forwards Drift Events
*/

// Lockin the state of the expected clock - Checks for High and Low rates together or Full rates if that is configured
//TODO: Refactor to support new architecture... and to include support for skipped-events during pausable data
//TODO:                                         ^ `~drift_detected && event` will support skipped-events,
//TODO:                                            as long as rate accumulator is reset by expected events
//TODO:                                       ! ^^^^^^^^ ! Already does this, with the same caveat ! ^^^^^^^^^ !
    lockin lockin (
        .sys_dom_i                (),
        .lockin_en_i              (),
        .clear_state_i            (),
        .active_drift_direction_i (),
        .half_rate_limits_i       (),
        .rate_accumulator_i       (),
        .filtered_event_i         (),
        .polarity_filtered_event_i(),
        .active_rate_valid_i      (),
        .active_rate_i            (),
        .drift_detected_o         (),
        .drift_direction_o        (),
        .drift_amount_o           (),
        .update_rate_o            (),
        .clear_rate_o             (),
        .locked_in_o              (),
        .rate_violation_o         ()
    );

// Drift Tracking
    drift_tracking drift_tracking (
        .sys_dom_i                       (sys_dom_i),
        .accumulator_en_i                (),
        .clear_state_i                   (),
        .drift_detected_i                (),
        .drift_direction_i               (),
        .max_drift_i                     (),
        .drift_acc_overflow_o            (),
        .inverse_drift_violation_o       (),
        .minimum_drift_lockout_duration_i(),
        .any_valid_edge_i                (),
        .expected_drift_req_o            (),
        .expected_drift_res_i            (),
        .expected_drift_direction_o      (),
        .preemptive_drift_req_o          (),
        .preemptive_drift_res_i          (),
        .preemptive_drift_direction_o    ()
    );

// Next Preemptive Half-Rate Limit (Quarter-Rate is calculated off of this)
/*
Reacts to drift events - Allows drifts to offset the next limit during preemptive events. 
Uses active High Half-Rate and Low Half-Rate during event updates.
*/

endmodule : generation
