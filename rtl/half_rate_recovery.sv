module half_rate_recovery (
    input                  common_p::clk_dom_s sys_dom_i,
    
    input                                      recovery_en_i,
    // When enabled:
    // `polarity` == 0: Only track high-level rates
    // `polarity` == 1: Only track low-level rates
    input                                      polarity_en_i,
    input                                      polarity_i,
    input                                      primary_clk_i,
    input                                      clear_state_i,
    input      clks_alot_p::half_rate_limits_s half_rate_limits_i,

    input                                      sense_event_i,

    output  [(clks_alot_p::COUNTER_WIDTH)-1:0] current_rate_o,
    output                                     over_frequency_violation_o,
    output                                     under_frequency_violation_o
);

// Clock Config
    wire clk = sys_dom_i.clk;
    wire clk_en = sys_dom_i.clk_en;
    wire sync_rst = sys_dom_i.sync_rst;

/*
    Pausable signals are either clocks that can be paused between transactions, or data that needs its clock recovered

    SINGLE_CONTINUOUS - Lockin by grabbing the rate and only allowing a certain amount of skew.
      SINGLE_PAUSABLE - Update lockin when the new rate is less than half of the current rate, but still within the bounds.
       DIF_CONTINUOUS - Lockin by halving the captured full rate, allowing a certain amount of skew.
         DIF_PAUSABLE - Update lockin when the new rate is less than half of the current rate, but still within the bounds.
      QUAD_CONTINUOUS - Lockin by halving the captured full rate, allowing a certain amount of skew.
                        Force Use of `*.any_valid_edge`
        QUAD_PAUSABLE - Update lockin when the new rate is less than half of the current rate, but still within the bounds. 
                        Force Use of `*.any_valid_edge`

    For non-single modes: Violation range will be anything between below half-rate

    ? Polarity
     >    Disabled - Update Rate on `*.any_valid_edge`
     > Enabled Pos - Enable Counter on `*.rising_edge`, Update Rate on `*.falling_edge`
     > Enabled Neg - Enable Counter on `*.falling_edge`, Update Rate on `*.rising_edge`
*/


// Lock-In
    reg  [(clks_alot_p::COUNTER_WIDTH-1):0] rate_counter_current;
    wire                                    filtered_event;
    wire    clks_alot_p::half_rate_limits_s filtered_limits;

    //TODO: Complete this module
    lockin lockin (
        .sys_dom_i             (sys_dom_i),
        .recovery_en_i         (recovery_en_i),
        .half_rate_limits_i    (half_rate_limits_i),
        .current_rate_counter_i(rate_counter_current),
        .filtered_event_i      (filtered_event),
        .filtered_limits_o     (filtered_limits)
    );

// Sense Filtering - Only Allow `sense_event_i` to update when within the band max/min
    //TODO: Add polarity Filter
    sense_filtering sense_filtering (
        .half_rate_limits_i         (filtered_limits),
        .current_rate_counter_i     (rate_counter_current),
        .sense_event_i              (sense_event_i),
        .filtered_event_o           (filtered_event),
        .over_frequency_violation_o (over_frequency_violation_o),
        .under_frequency_violation_o(under_frequency_violation_o)
    );

// Rate Counter


endmodule : half_rate_recovery
