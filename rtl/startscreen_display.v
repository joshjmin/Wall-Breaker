// =========================================================================
// startscreen_display.v - Displays start screen from MIF file
// =========================================================================
// Scales 160x120 MIF image to 640x480 (4x4 pixel blocks)
// Paints entire screen once when triggered, then holds done state
// =========================================================================

module startscreen_display(
    input  wire        clk,
    input  wire        resetn,
    input  wire        trigger,      // HIGH during START_SCREEN state
    output reg  [9:0]  vga_x,
    output reg  [8:0]  vga_y,
    output reg  [8:0]  vga_color,
    output reg         vga_write,
    output wire        busy,
    output reg         done          // HIGH when finished painting
);

    // Parameters for 640x480 display
    localparam SCREEN_WIDTH  = 640;
    localparam SCREEN_HEIGHT = 480;
    localparam MIF_WIDTH     = 160;
    localparam MIF_HEIGHT    = 120;
    localparam SCALE_FACTOR  = 4;   // Each MIF pixel -> 4x4 screen pixels
   
    // State machine
    localparam IDLE     = 2'b00;
    localparam PAINTING = 2'b01;
    localparam DONE_ST  = 2'b10;
   
    reg [1:0] state;
   
    // Pixel counters for 640x480 screen
    reg [9:0] pixel_x;  // 0-639
    reg [8:0] pixel_y;  // 0-479

    // Calculate MIF address from current screen pixel
    wire [7:0]  mif_x    = pixel_x >> 2;  // Divide by 4 (scale down)
    wire [6:0]  mif_y    = pixel_y >> 2;  // Divide by 4 (scale down)
    wire [14:0] mif_addr = mif_y * MIF_WIDTH + mif_x;

    // ROM output pixel
    wire [8:0] startscreen_pixel;

    // Instantiate ROM that reads from startscreen.mif
    startscreen_mem startscreen_rom (
        .address (mif_addr),
        .clock   (clk),
        .q       (startscreen_pixel)
    );

    // Busy signal
    assign busy = (state != IDLE);
   
    // State machine
    always @(posedge clk) begin
        if (!resetn) begin
            state     <= IDLE;
            pixel_x   <= 10'd0;
            pixel_y   <= 9'd0;
            vga_x     <= 10'd0;
            vga_y     <= 9'd0;
            vga_color <= 9'd0;
            vga_write <= 1'b0;
            done      <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    vga_write <= 1'b0;
                    done      <= 1'b0;
                   
                    if (trigger) begin
                        // Start painting from top-left corner
                        pixel_x <= 10'd0;
                        pixel_y <= 9'd0;
                        state   <= PAINTING;
                    end
                end
               
                PAINTING: begin
                    // Output current pixel
                    vga_x     <= pixel_x;
                    vga_y     <= pixel_y;
                    vga_color <= startscreen_pixel;
                    vga_write <= 1'b1;
                   
                    // Advance to next pixel
                    if (pixel_x < SCREEN_WIDTH - 1) begin
                        pixel_x <= pixel_x + 1'b1;
                    end
                    else begin
                        pixel_x <= 10'd0;
                        if (pixel_y < SCREEN_HEIGHT - 1) begin
                            pixel_y <= pixel_y + 1'b1;
                        end
                        else begin
                            // Finished painting entire screen
                            vga_write <= 1'b0;
                            done      <= 1'b1;
                            state     <= DONE_ST;
                        end
                    end
                end
               
                DONE_ST: begin
                    vga_write <= 1'b0;
                    done      <= 1'b1;
                   
                    // Stay in DONE until trigger goes low
                    if (!trigger) begin
                        state <= IDLE;
                        done  <= 1'b0;
                    end
                end
               
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule