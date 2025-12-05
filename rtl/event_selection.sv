/**
 *  Module: event_detection
 *
 *  About: 
 *
 *  Ports:
 *
**/
module event_detection (
    input                common_p::clk_dom sys_dom_i,

    input                                  recovery_en_i,
    // Used for differential and quad-state signals to decide which input is used to determine the primary clock edges
    // 0: io_clk_i.neg edges are forwarded, with io_clk_i.pos used for verification
    // 1: io_clk_i.pos edges are forwarded, with io_clk_i.neg used for verification
    // Use for single-ended signals to decide which input is used as the clock signal
    // 0: io_clk_i.neg used
    // 1: io_clk_i.pos used
    input     clks_alot_p::recovery_mode_e recovery_mode_i,

    input     clks_alot_p::recovery_pins_s io_clk_i,
    input     clks_alot_p::driver_events_s driver_events_i,

    output clks_alot_p::recovered_events_s recovered_events_o
);

clks_alot_p::recovery_drivers_s recovery_drivers;
always_comb begin : recovery_drivers_mux
    recovered_events_o.rising_edge = 1'b0;
    recovered_events_o.falling_edge = 1'b0;
    recovered_events_o.dual_high_edge = 1'b0;
    recovered_events_o.dual_low_edge = 1'b0;
    recovered_events_o.any_valid_edge = 1'b0;
    recovered_events_o.diff_rising_edge_violation = 1'b0;
    recovered_events_o.diff_falling_edge_violation = 1'b0;
    case (recovery_mode_i)
        SINGLE_CONTINUOUS : begin
            // Primary:   _-
            recovered_events_o.rising_edge = driver_events_i.primary_rising_edge;
            recovered_events_o.falling_edge = driver_events_i.primary_falling_edge;
            recovered_events_o.any_valid_edge = driver_events_i.primary_either_edge;
        end
        SINGLE_PAUSABLE : begin
            // Primary:   _-
            recovered_events_o.rising_edge = driver_events_i.primary_rising_edge;
            recovered_events_o.falling_edge = driver_events_i.primary_falling_edge;
            recovered_events_o.any_valid_edge = driver_events_i.primary_either_edge;
        end
        DIF_CONTINUOUS : begin
            // Primary:   _-
            // Secondary: -_
            recovered_events_o.rising_edge = driver_events_i.primary_rising_edge && driver_events_i.secondary_falling_edge;
            // Primary:   -_
            // Secondary: _-
            recovered_events_o.falling_edge = driver_events_i.primary_falling_edge && driver_events_i.primary_rising_edge;
            // Primary:   _- | -_
            // Secondary: -_ | _-
            recovered_events_o.any_valid_edge = driver_events_i.primary_either_edge && driver_events_i.secondary_either_edge;
            // Primary:   _- | _- | _-
            // Secondary: _- | __ | --
            recovered_events_o.diff_rising_edge_violation = driver_events_i.primary_rising_edge && ~driver_events_i.secondary_falling_edge;
            // Primary:   -_ | -_ | -_
            // Secondary: -_ | __ | --
            recovered_events_o.diff_falling_edge_violation = driver_events_i.primary_falling_edge && ~driver_events_i.primary_rising_edge;
        end
        DIF_PAUSABLE : begin
            // Primary:   _-
            // Secondary: -_
            recovered_events_o.rising_edge = driver_events_i.primary_rising_edge && driver_events_i.secondary_falling_edge;
            // Primary:   -_
            // Secondary: _-
            recovered_events_o.falling_edge = driver_events_i.primary_falling_edge && driver_events_i.primary_rising_edge;
            // Primary:   _- | -_
            // Secondary: -_ | _-
            recovered_events_o.any_valid_edge = driver_events_i.primary_either_edge && driver_events_i.secondary_either_edge;
            // Primary:   _- | _- | _-
            // Secondary: _- | __ | --
            recovered_events_o.diff_rising_edge_violation = driver_events_i.primary_rising_edge && ~driver_events_i.secondary_falling_edge;
            // Primary:   -_ | -_ | -_
            // Secondary: -_ | __ | --
            recovered_events_o.diff_falling_edge_violation = driver_events_i.primary_falling_edge && ~driver_events_i.primary_rising_edge;
        end
        QUAD_CONTINUOUS : begin
            // Primary:   _-
            // Secondary: -_
            recovered_events_o.rising_edge = driver_events_i.primary_rising_edge && driver_events_i.secondary_falling_edge;
            // Primary:   -_
            // Secondary: _-
            recovered_events_o.falling_edge = driver_events_i.primary_falling_edge && driver_events_i.primary_rising_edge;
            // Primary:   _- | --
            // Secondary: -- | _-
            recovered_events_o.dual_high_edge = (driver_events_i.primary_rising_edge && io_clk_i[0])
                                             || (driver_events_i.secondary_rising_edge && io_clk_i[1]);
            // Primary:   -_ | __
            // Secondary: __ | -_
            recovered_events_o.dual_low_edge = (driver_events_i.primary_falling_edge && ~io_clk_i[0])
                                            || (driver_events_i.secondary_falling_edge && ~io_clk_i[1]);
            // Primary:   _- | -_ | _- | -_ | _- | -- | -_ | __
            // Secondary: -_ | _- | _- | -_ | -- | _- | __ | -_
            recovered_events_o.any_valid_edge = driver_events_i.primary_either_edge || driver_events_i.secondary_either_edge;
        end
        QUAD_PAUSABLE : begin
            // Primary:   _-
            // Secondary: -_
            recovered_events_o.rising_edge = driver_events_i.primary_rising_edge && driver_events_i.secondary_falling_edge;
            // Primary:   -_
            // Secondary: _-
            recovered_events_o.falling_edge = driver_events_i.primary_falling_edge && driver_events_i.primary_rising_edge;
            // Primary:   _- | --
            // Secondary: -- | _-
            recovered_events_o.dual_high_edge = (driver_events_i.primary_rising_edge && io_clk_i[0])
                                             || (driver_events_i.secondary_rising_edge && io_clk_i[1]);
            // Primary:   -_ | __
            // Secondary: __ | -_
            recovered_events_o.dual_low_edge = (driver_events_i.primary_falling_edge && ~io_clk_i[0])
                                            || (driver_events_i.secondary_falling_edge && ~io_clk_i[1]);
            // Primary:   _- | -_ | _- | -_ | _- | -- | -_ | __
            // Secondary: -_ | _- | _- | -_ | -- | _- | __ | -_
            recovered_events_o.any_valid_edge = driver_events_i.primary_either_edge || driver_events_i.secondary_either_edge;
        end
        default: ; // Is this even allowed? - can put some bs here if syntax error lol... ive never tries this
    endcase
end

endmodule : event_detection
