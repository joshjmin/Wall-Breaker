// =========================================================================
// brick_display.v - Complete Brick Display Module with Collision Detection
// =========================================================================
// This module:
// - Draws 24 bricks (8 columns × 3 rows) at startup
// - Detects collisions with ball (AABB algorithm)
// - Erases bricks when hit
// - Coordinates with paddle/ball via busy signals
// - Provides collision info to ball physics
// =========================================================================

module brick_display(
    clk,
    resetn,
    game_reset,
    ball_x,
    ball_y,
    paddle_busy,
    ball_busy,
    vga_x,
    vga_y,
    vga_color,
    vga_write,
    busy,
    brick_hit,
    hit_brick_x,
    hit_brick_y,
    bricks_remaining,
clear_busy
);

    // Parameters (must match vga_demo_original.v)
    parameter RESOLUTION = "640x480";
    parameter nX = 10;
    parameter nY = 9;
    parameter COLOR_DEPTH = 9;
   
    // Brick layout constants
    localparam NUM_BRICKS = 24;
    localparam BRICKS_PER_ROW = 8;
    localparam NUM_ROWS = 3;
    localparam BRICK_WIDTH = 80;   // 640 / 8 = 80
    localparam BRICK_HEIGHT = 20;  // 60 / 3 = 20
    localparam BALL_SIZE = 16;     // Must match ball_display module
    localparam BORDER_SIZE = 2;    // Black border around each brick
   
    // Ports
    input wire clk, resetn, game_reset;
    input wire [9:0] ball_x, ball_y;
    input wire paddle_busy, ball_busy, clear_busy;
    output reg [nX-1:0] vga_x;
    output reg [nY-1:0] vga_y;
    output reg [COLOR_DEPTH-1:0] vga_color;
    output reg vga_write;
    output wire busy;
    output reg brick_hit;           // Pulses when collision occurs
    output reg [9:0] hit_brick_x;   // Top-left X of hit brick
    output reg [9:0] hit_brick_y;   // Top-left Y of hit brick
    output reg [4:0] bricks_remaining;
   
    // =========================================================================
    // SECTION 1: BRICK STATE STORAGE
    // =========================================================================
   
    // Track which bricks are alive (1) or destroyed (0)
    reg [NUM_BRICKS-1:0] brick_alive = {NUM_BRICKS{1'b1}};
   
    // =========================================================================
    // SECTION 2: BRICK POSITION CALCULATION FUNCTIONS
    // =========================================================================
   
    // Calculate brick X position from index (0-23)
    function [9:0] get_brick_x;
        input [4:0] brick_index;
        begin
            get_brick_x = (brick_index % BRICKS_PER_ROW) * BRICK_WIDTH;
        end
    endfunction
   
    // Calculate brick Y position from index (0-23)
    function [9:0] get_brick_y;
        input [4:0] brick_index;
        begin
            get_brick_y = (brick_index / BRICKS_PER_ROW) * BRICK_HEIGHT;
        end
    endfunction
   
    // Get brick color based on row (Red, Green, Blue from top to bottom)
    function [COLOR_DEPTH-1:0] get_brick_color;
        input [4:0] brick_index;
        reg [1:0] row;
        begin
            row = brick_index / BRICKS_PER_ROW;
            case (row)
                2'd0: get_brick_color = 9'b111_000_000;  // Red
                2'd1: get_brick_color = 9'b000_111_000;  // Green
                2'd2: get_brick_color = 9'b000_000_111;  // Blue
                default: get_brick_color = 9'b111_111_111;  // White
            endcase
        end
    endfunction
   
    // Determine if pixel should be border (black) or brick color
    function is_border_pixel;
        input [6:0] px;  // pixel_x within brick
        input [4:0] py;  // pixel_y within brick
        begin
            is_border_pixel = (px < BORDER_SIZE) ||
                             (px >= BRICK_WIDTH - BORDER_SIZE) ||
                             (py < BORDER_SIZE) ||
                             (py >= BRICK_HEIGHT - BORDER_SIZE);
        end
    endfunction
   
    // =========================================================================
    // SECTION 3: COLLISION DETECTION (COMBINATIONAL)
    // =========================================================================
   
    // Collision detection runs in parallel for all bricks
    reg collision_detected_comb;
    reg [4:0] hit_brick_index_comb;
   
    integer i;
    always @(*) begin
        // Default: no collision
        collision_detected_comb = 1'b0;
        hit_brick_index_comb = 5'd0;
       
        // Check all bricks in parallel (synthesizes to parallel comparators)
        // If multiple bricks hit, last one wins
        for (i = 0; i < NUM_BRICKS; i = i + 1) begin
            if (brick_alive[i]) begin
                // AABB (Axis-Aligned Bounding Box) collision detection
                // Detects ANY overlap, even 1 pixel
                if ((ball_x + BALL_SIZE > get_brick_x(i)) &&
                    (ball_x < get_brick_x(i) + BRICK_WIDTH) &&
                    (ball_y + BALL_SIZE > get_brick_y(i)) &&
                    (ball_y < get_brick_y(i) + BRICK_HEIGHT)) begin
                   
                    collision_detected_comb = 1'b1;
                    hit_brick_index_comb = i[4:0];
                end
            end
        end
    end
   
    // Register collision detection to avoid timing issues
    reg collision_detected_reg;
    reg [4:0] hit_brick_index_reg;
   
    always @(posedge clk) begin
    if (!resetn) begin
    collision_detected_reg <= 1'b0;
    hit_brick_index_reg    <= 5'd0;
    end
    else if (game_reset) begin  // pulse
    collision_detected_reg <= 1'b0;
    hit_brick_index_reg    <= 5'd0;
    end
    else begin
    collision_detected_reg <= collision_detected_comb;
    hit_brick_index_reg    <= hit_brick_index_comb;
    end
    end
   
    // =========================================================================
    // SECTION 4: STATE MACHINE
    // =========================================================================
   
    // State machine parameters
    localparam INIT = 2'd0;   // Draw all bricks at startup
    localparam IDLE = 2'd1;   // Check for collisions
    localparam ERASE = 2'd2;  // Erase one brick
   
    // Initialize registers with default values for proper FPGA power-on
    reg [1:0] state = INIT;
   
    // Busy when not in IDLE state
    assign busy = (state != IDLE);
   
    // Counters for iterating through pixels (initialized to ensure proper startup)
    reg [4:0] current_brick = 5'd0;   // Which brick (0-23)
    reg [6:0] pixel_x = 7'd0;         // Pixel within brick X-axis (0-79)
    reg [4:0] pixel_y = 5'd0;         // Pixel within brick Y-axis (0-19)
   
    // Info about which brick to erase
    reg [4:0] brick_to_erase = 5'd0;
    reg [9:0] brick_to_erase_x = 10'd0;
    reg [9:0] brick_to_erase_y = 10'd0;
    reg [COLOR_DEPTH-1:0] brick_to_erase_color = {COLOR_DEPTH{1'b0}};
   
    // Count remaining bricks
    integer j;
    always @(*) begin
        bricks_remaining = 0;
        for (j = 0; j < NUM_BRICKS; j = j + 1) begin
            if (brick_alive[j])
                bricks_remaining = bricks_remaining + 1'b1;
        end
    end
   
    // =========================================================================
    // SECTION 5: STATE MACHINE LOGIC
    // =========================================================================
   
    always @(posedge clk) begin
    if (!resetn) begin
    // RESET: Initialize everything
    brick_alive        <= {NUM_BRICKS{1'b1}};
    state              <= INIT;
    current_brick      <= 5'd0;
    pixel_x            <= 7'd0;
    pixel_y            <= 5'd0;
    vga_write          <= 1'b0;
    brick_to_erase     <= 5'd0;
    brick_to_erase_x   <= 10'd0;
    brick_to_erase_y   <= 10'd0;
    brick_to_erase_color <= {COLOR_DEPTH{1'b0}};
    brick_hit          <= 1'b0;
    hit_brick_x        <= 10'd0;
    hit_brick_y        <= 10'd0;
    end

    else if (game_reset) begin
    // GAME RESET: same as power-on, but from pulse
    brick_alive        <= {NUM_BRICKS{1'b1}};
    state              <= INIT;
    current_brick      <= 5'd0;
    pixel_x            <= 7'd0;
    pixel_y            <= 5'd0;
    vga_write          <= 1'b0;
    brick_to_erase     <= 5'd0;
    brick_to_erase_x   <= 10'd0;
    brick_to_erase_y   <= 10'd0;
    brick_to_erase_color <= {COLOR_DEPTH{1'b0}};
    brick_hit          <= 1'b0;
    hit_brick_x        <= 10'd0;
    hit_brick_y        <= 10'd0;
    end

    else begin
        // Default: clear one-shot signals
        brick_hit <= 1'b0;
        
        case (state)
            // =============================================================
            // INIT STATE: Draw all bricks once (interleaved with game)
            // =============================================================
                INIT: begin
                // Wait for paddle and ball to finish their initial drawing
                // Only advance counters when we can actually write
                if (!paddle_busy && !ball_busy && !clear_busy) begin
                    if (current_brick < NUM_BRICKS) begin
                        // Draw this pixel if brick is alive
                        if (brick_alive[current_brick]) begin
                            vga_x <= get_brick_x(current_brick) + pixel_x;
                            vga_y <= get_brick_y(current_brick) + pixel_y;
                            
                            // Check if this pixel is on the border
                            if (is_border_pixel(pixel_x, pixel_y)) begin
                                vga_color <= {COLOR_DEPTH{1'b0}};  // Black border
                            end
                            else begin
                                vga_color <= get_brick_color(current_brick);  // Brick color
                            end
                            
                            vga_write <= 1'b1;
                        end
                        else begin
                            vga_write <= 1'b0;
                        end
                        
                        if (pixel_x < BRICK_WIDTH - 1) begin
                            pixel_x <= pixel_x + 1'b1;
                        end
                        else begin
                            pixel_x <= 7'd0;
                            if (pixel_y < BRICK_HEIGHT - 1) begin
                                pixel_y <= pixel_y + 1'b1;
                            end
                            else begin
                                pixel_y <= 5'd0;
                                current_brick <= current_brick + 1'b1;
                            end
                        end
                    end
                    else begin
                        // All bricks drawn, go to IDLE
                        vga_write <= 1'b0;
                        state <= IDLE;
                    end
                end
                else begin
                    // Stall: paddle or ball is busy, don't advance counters
                    vga_write <= 1'b0;
                end
            end
            
            // =============================================================
            // IDLE STATE: Check for collisions
            // =============================================================
            IDLE: begin
                vga_write <= 1'b0;
                
                // Check registered collision detection
                // (Collision detection happens in combinational block)
                if (collision_detected_reg && brick_alive[hit_brick_index_reg]) begin
                    // Brick hit! Mark it as destroyed
                    brick_alive[hit_brick_index_reg] <= 1'b0;
                    
                    // Save info about brick to erase
                    brick_to_erase <= hit_brick_index_reg;
                    brick_to_erase_x <= get_brick_x(hit_brick_index_reg);
                    brick_to_erase_y <= get_brick_y(hit_brick_index_reg);
                    brick_to_erase_color <= get_brick_color(hit_brick_index_reg);
                    
                    // Pulse collision signal for game logic
                    brick_hit <= 1'b1;
                    hit_brick_x <= get_brick_x(hit_brick_index_reg);
                    hit_brick_y <= get_brick_y(hit_brick_index_reg);
                    
                    // Reset pixel counters for erasing
                    pixel_x <= 7'd0;
                    pixel_y <= 5'd0;
                    
                    state <= ERASE;
                end
                // else stay in IDLE
            end
            
            // =============================================================
            // ERASE STATE: Black out the destroyed brick
            // =============================================================
            ERASE: begin
                // Only erase when paddle and ball aren't busy
                // This prevents our pixels from being overridden
                if (!paddle_busy && !ball_busy && !clear_busy) begin
                    // Write black pixel
                    vga_x <= brick_to_erase_x + pixel_x;
                    vga_y <= brick_to_erase_y + pixel_y;
                    vga_color <= {COLOR_DEPTH{1'b0}};  // Black
                    vga_write <= 1'b1;
                    
                    // Advance pixel counters
                    if (pixel_x < BRICK_WIDTH - 1) begin
                        pixel_x <= pixel_x + 1'b1;
                    end
                    else begin
                        pixel_x <= 7'd0;
                        if (pixel_y < BRICK_HEIGHT - 1) begin
                            pixel_y <= pixel_y + 1'b1;
                        end
                        else begin
                            // Done erasing this brick
                            pixel_y <= 5'd0;
                            vga_write <= 1'b0;
                            state <= IDLE;
                        end
                    end
                end
                else begin
                    // Stall while other modules are busy
                    vga_write <= 1'b0;
                end
            end
            
            default: begin
                state <= IDLE;
                vga_write <= 1'b0;
            end
        endcase
    end
end

endmodule


`default_nettype none