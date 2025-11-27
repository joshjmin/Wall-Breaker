`default_nettype none

// =============================================================================
// startscreen_mem.v - ROM for start screen (Cyclone II / DE1)
//  - WIDTH = 9 bits
//  - DEPTH = 19200 locations (160 x 120)
// =============================================================================

module startscreen_mem (address, clock, q);

    input  wire [14:0] address;  // 0..19199
    input  wire        clock;
    output wire [8:0]  q;

    wire [8:0] sub_wire0;
    assign q = sub_wire0[8:0];

    altsyncram  altsyncram_component (
        .address_a       (address),
        .clock0          (clock),
        .q_a             (sub_wire0),

        // Unused ports tied off (standard DE1 style)
        .aclr0           (1'b0),
        .aclr1           (1'b0),
        .address_b       (1'b1),
        .addressstall_a  (1'b0),
        .addressstall_b  (1'b0),
        .byteena_a       (1'b1),
        .byteena_b       (1'b1),
        .clock1          (1'b1),
        .clocken0        (1'b1),
        .clocken1        (1'b1),
        .clocken2        (1'b1),
        .clocken3        (1'b1),
        .data_a          (9'b0),
        .data_b          (1'b1),
        .q_b             (),
        .rden_a          (1'b1),
        .rden_b          (1'b1),
        .wren_a          (1'b0),
        .wren_b          (1'b0)
    );

    defparam
        // Match your board
        altsyncram_component.intended_device_family = "Cyclone II",
        // ROM mode
        altsyncram_component.operation_mode         = "ROM",
        // Memory geometry
        altsyncram_component.width_a                = 9,
        altsyncram_component.numwords_a             = 19200,
        altsyncram_component.widthad_a              = 15,
        // Output behavior
        altsyncram_component.outdata_reg_a          = "UNREGISTERED",
        altsyncram_component.outdata_aclr_a         = "NONE",
        // Init file (put startscreen.mif in project root)
        altsyncram_component.init_file              = "startscreen.mif",
        altsyncram_component.init_file_layout       = "PORT_A",
        // Misc
        altsyncram_component.lpm_type               = "altsyncram",
        altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
        altsyncram_component.power_up_uninitialized = "FALSE";

endmodule

`default_nettype wire