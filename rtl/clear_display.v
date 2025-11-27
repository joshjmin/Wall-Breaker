// ======================================================================
// clear_display.v - Clears entire screen to black on a trigger
// ======================================================================
// Assumes 640x480, COLOR_DEPTH=9
// Runs once per trigger pulse (game_reset) and writes black to every
// pixel in the VGA memory
// ======================================================================

module clear_display(
    input  wire        clk,
    input  wire        resetn,
    input  wire        trigger,     // pulse from game_reset
    output reg  [9:0]  vga_x,
    output reg  [8:0]  vga_y,
    output reg  [8:0]  vga_color,
    output reg         vga_write,
    output wire        busy,
    output reg         done
);

    localparam IDLE  = 2'd0;
    localparam CLEAR = 2'd1;

    reg [1:0] state = IDLE;

    // Screen counters
    reg [9:0] x = 10'd0;  // 0..639
    reg [8:0] y = 9'd0;   // 0..479

    assign busy = (state != IDLE);

    always @(posedge clk) begin
        if (!resetn) begin
            state     <= IDLE;
            x         <= 10'd0;
            y         <= 9'd0;
            vga_write <= 1'b0;
            vga_color <= 9'b0;
            done      <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    vga_write <= 1'b0;
                    done      <= 1'b0;
                    if (trigger) begin
                        // Start clearing
                        x     <= 10'd0;
                        y     <= 9'd0;
                        state <= CLEAR;
                    end
                end

                CLEAR: begin
                    // Write black pixel at (x,y)
                    vga_x     <= x;
                    vga_y     <= y;
                    vga_color <= 9'b000_000_000;
                    vga_write <= 1'b1;

                    if (x == 10'd639) begin
                        x <= 10'd0;
                        if (y == 9'd479) begin
                            // Done clearing full screen
                            y         <= 9'd0;
                            vga_write <= 1'b0;
                            done      <= 1'b1;
                            state     <= IDLE;
                        end
                        else begin
                            y <= y + 1'b1;
                        end
                    end
                    else begin
                        x <= x + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule


`default_nettype none
