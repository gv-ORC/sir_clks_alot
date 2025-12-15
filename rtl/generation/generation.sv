module generation (
    input                     common_p::clk_dom_s sys_dom_i,

    input                                         generation_en_i,
    input                                         clear_state_i,

// Recovery Feedback
    input         clks_alot_p::recovered_events_s recovered_events_i,
    input                                         fully_locked_in_i,
    input [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] high_rate_i,
    input [(clks_alot_p::RATE_COUNTER_WIDTH)-1:0] low_rate_i,

// Violations

// Unpausable Output
    output             clks_alot_p::clock_state_s unpausable_expected_clk_state_o,
    output             clks_alot_p::clock_state_s unpausable_preemptive_clk_state_o,

// Pause Control & Output
    // Pauses maintain clock phasing when enabling and disabling
    // Pauses enable & disable when clock polarity matches
    input                                         pause_en_i,
    input                                         pause_polarity_i,

    output             clks_alot_p::clock_state_s pausable_expected_clk_state_o,
    output             clks_alot_p::clock_state_s pausable_preemptive_clk_state_o,
    output                                        pause_start_violation_o,
    output                                        pause_stop_violation_o
);

/*
Enable the free-running counter any time `generation_en_i` is high.

Once recovery rates have locked-in, (use monostable to trigger a re-sync if lockin drops out and raises again)
> Seed the following targets and enable rate based toggling
    2. Expected Target
    3. Preemptive Target

> Latch Expected and Preemptive Deltas 1 cycle after each incoming event.
> Consider clock generation locked, when both deltas show lock-in status via value prioritization
> Once both deltas are locked-in, apply the locked in deltas at every incoming edge event

! Insta-Sync Drift
? Mimic Not 50-50: Low Half-Rate 4(h), High Half-Rate 4(l), Starts at (s) = 10, Rx Delay (r) = 5, Tx Delay (t) = 6, Counter(c), Drift Window (w) = 1  -- hl indicates either High or Low rate
>NOTE: (r + w) <= (h + l) 
                                                                                                                        Seed Sync              Start Sync             Neg Drift
Incoming Edge Name:                                f0          r0          f1          r1          f2          r2         [f3]         r3         [f4]         r4      (f5)         r5          f6          r6          f7          r7
Incoming Clock:                 xxxxxxx---------------____________------------____________------------____________------------____________------------____________---------____________------------____________------------____________---
Counter(c):                     0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70
High Half-Rate:                 x x x x x x x x x x x  -  -  -  -  -  -  -  -  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4
Low Half-Rate:                  x x x x x x x x x x x  -  -  -  -  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4
Counter:Expected Limit Delta:   x x x x x x x x x x x  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3
Counter:Preemptive Limit Delta: x x x x x x x x x x x  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1  0  3  2  1
Drift Edge Name:                                                                                     f2          r2         [f3]         r3         [f4]         r4      (f5)         r5          f6          r6          f7          r7
Drift Clock (fake):             xxxxxxxxxxxxxxxxxxxxxx------------------------------------------------____________------------____________------------____________---------____________------------____________------------____________---
Expected Edge Name:                                                                                           f3          r3          f4          r4          f5          r5      (f6)         r6          f7          r7          f8
Expected Clock:                 xxxxxxxxxxxxxxxxxxxxxx---------------------------------------------------------____________------------____________------------____________---------____________------------____________------------______
Expected Half-Rate Limit:       x x x x x x x x x x x  -  -  -  -  -  -  -  -  29 29 29 29 29 29 29 29 29 29 29 33 33 33 33 37 37 37 37 41 41 41 41 45 45 45 45 49 49 49 49 52 52 52 56 56 56 56 60 60 60 60 64 64 64 64 68 68 68 68 70 70
Preemptive Edge Name:                                                                       f3          r3          f4          r4          f5          r6          f7      (r7)         f8          r8          f9          r9
Preemptive Clock:               xxxxxxxxxxxxxxxxxxxxxx---------------------------------------____________------------____________------------____________------------_________------------____________------------____________------------
Preemptive Half-Rate Limit:     x x x x x x x x x x x  -  -  -  -  -  -  -  -  23 23 23 23 23 27 27 27 27 31 31 31 31 35 35 35 35 39 39 39 39 43 43 43 43 47 47 47 47 51 51 50 54 54 54 54 58 58 58 58 62 62 62 62 66 66 66 66 70 70 70 70


! Insta-Sync Drift
? Mimic Not 50-50: Low Half-Rate 3(h), High Half-Rate 4(l), Starts at (s) = 10, Rx Delay (r) = 5, Tx Delay (t) = 6, Counter(c), Drift Window (w) = 1  -- hl indicates either High or Low rate
>NOTE: (r + w) <= (h + l) 
                                                                                                               Seed Sync           Start Sync          Neg Drift
Incoming Edge Name:                                  f0       r0          f1       r1          f2       r2         [f3]      r3         [f4]       r4     (f5)      r5          f6       r6          f7       r7          f8       r8
Incoming Clock:                 xxxxxxx---------------_________------------_________------------_________------------_________------------_________---------_________------------_________------------_________------------_________------
Counter(c):                     0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70
High Half-Rate:                 x x x x x x x x x x x  -  -  -  -  -  -  -  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4  4
Low Half-Rate:                  x x x x x x x x x x x  -  -  -  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3  3
Counter:Expected Limit Delta:   x x x x x x x x x x x  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  2  1  0  3  2  1  0  2  1  0  3  2  1  0  2  1  0  3
Counter:Preemptive Limit Delta: x x x x x x x x x x x  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  0  2  1  0  3  2  1  0  2  1  0  3  2  1  0  2  1  0
Drift Edge Name:                                                                               f2       r2         [f3]      r3         [f4]       r4     (f5)      r5          f6       r6          f7       r7          f8       r8
Drift Clock (fake):             xxxxxxxxxxxxxxxxxxxxxx------------------------------------------_________------------_________------------_________---------_________------------_________------------_________------------_________------
Expected Edge Name:                                                                                  f3       r3          f4       r4          f5       r6
Expected Clock:                 xxxxxxxxxxxxxxxxxxxxxx------------------------------------------------_________------------_________------------_________---
Expected Half-Rate Limit:       x x x x x x x x x x x  -  -  -  -  -  -  -  26 26 26 26 26 26 26 26 26 29 29 29 33 33 33 33 36 36 36 40 40 40 40 43 43 43 47
Preemptive Edge Name:                                                              f3       r3          f4       r4          f5       r6          f7
Preemptive Clock:               xxxxxxxxxxxxxxxxxxxxxx------------------------------_________------------_________------------_________------------_________
Preemptive Half-Rate Limit:     x x x x x x x x x x x  -  -  -  -  -  -  -  20 20 20 23 23 23 27 27 27 27 30 30 30 34 34 34 34 37 37 37 41 41 41 41 44 44 44

*/

clock_generation expected_clock_generation (

);

clock_generation preemptive_clock_generation (

);

endmodule : generation
