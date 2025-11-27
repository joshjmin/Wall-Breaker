`default_nettype none

/* VGA Breakout Game */

module vga_demo_original(
 CLOCK_50, SW, KEY, LEDR, PS2_CLK, PS2_DAT,
 HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
 VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK
);

 parameter RESOLUTION = "640x480";
 parameter COLOR_DEPTH = 9;
 parameter nX = (RESOLUTION == "640x480") ? 10 : ((RESOLUTION == "320x240") ? 9 : 8);
 parameter nY = (RESOLUTION == "640x480") ? 9 : ((RESOLUTION == "320x240") ? 8 : 7);

 input wire CLOCK_50;
 input wire [9:0] SW;
 input wire [3:0] KEY;
 output wire [9:0] LEDR;
 inout wire PS2_CLK;
 inout wire PS2_DAT;
 output wire [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0;
 output wire [7:0] VGA_R, VGA_G, VGA_B;
 output wire VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

 wire VGA_SYNC;

 // Game signals
 wire game_tick;
 wire [9:0] paddle_x_pos;
 wire [9:0] ball_x_pos, ball_y_pos;
 wire ball_lost;

 // PS/2 signals
 reg prev_ps2_clk;
 wire negedge_ps2_clk;
 reg [32:0] Serial;
 reg [3:0] Packet;
 wire [7:0] scancode;
 reg [7:0] scancode_reg;
 reg scancode_valid;

 // Control signals from PS/2
 wire paddle_left, paddle_right;
 wire shoot_ball;
 wire shoot_dir;
 wire spacebar_pressed; 

 // Game state signals
 wire game_over;
 wire game_reset;
 wire gameover_done;
 wire show_start_screen;
 wire clear_trigger;
 wire startscreen_done;
 wire enter_pressed;
 
 // Edge-detect game_reset to make a one-clock pulse
 reg game_reset_d;

always @(posedge CLOCK_50 or negedge Resetn) begin
if (!Resetn)
 game_reset_d <= 1'b0;
else
 game_reset_d <= game_reset;
end

wire game_reset_pulse = game_reset & ~game_reset_d;

// Edge-detect clear_trigger to make a one-clock pulse
reg clear_trigger_d;

always @(posedge CLOCK_50 or negedge Resetn) begin
if (!Resetn)
 clear_trigger_d <= 1'b0;
else
 clear_trigger_d <= clear_trigger;
end

wire clear_trigger_pulse = clear_trigger & ~clear_trigger_d;

 // VGA object signals for paddle
 wire [nX-1:0] paddle_vga_x;
 wire [nY-1:0] paddle_vga_y;
 wire [COLOR_DEPTH-1:0] paddle_color;
 wire paddle_write;
 wire paddle_busy;

 // VGA object signals for ball
 wire [nX-1:0] ball_vga_x;
 wire [nY-1:0] ball_vga_y;
 wire [COLOR_DEPTH-1:0] ball_color;
 wire ball_write;
 wire ball_busy;

 // VGA object signals for bricks
 wire [nX-1:0] brick_vga_x;
 wire [nY-1:0] brick_vga_y;
 wire [COLOR_DEPTH-1:0] brick_color;
 wire brick_write;
 wire brick_busy;
 wire brick_hit;
 wire [9:0] hit_brick_x, hit_brick_y;
 wire [4:0] bricks_remaining;

 // VGA object signals for game over screen
 wire [nX-1:0] gameover_vga_x;
 wire [nY-1:0] gameover_vga_y;
 wire [COLOR_DEPTH-1:0] gameover_color;
 wire gameover_write;
 wire gameover_busy;

// VGA object signals for start screen
 wire [nX-1:0] startscreen_vga_x;
 wire [nY-1:0] startscreen_vga_y;
 wire [COLOR_DEPTH-1:0] startscreen_color;
 wire startscreen_write;
 wire startscreen_busy;
 
// VGA object signals for clear screen
wire [nX-1:0] clear_vga_x;
wire [nY-1:0] clear_vga_y;
wire [COLOR_DEPTH-1:0] clear_color;
wire clear_write;
wire clear_busy;
wire clear_done;

 // Multiplexed VGA signals
 wire [nX-1:0] MUX_x;
 wire [nY-1:0] MUX_y;
 wire [COLOR_DEPTH-1:0] MUX_color;
 wire MUX_write;

 // Synchronized inputs
 wire Resetn, PS2_CLK_S, PS2_DAT_S;

 assign Resetn = KEY[0];

 sync S3 (PS2_CLK, Resetn, CLOCK_50, PS2_CLK_S);
 sync S4 (PS2_DAT, Resetn, CLOCK_50, PS2_DAT_S);

 // =========================================
 // PS/2 Keyboard Interface
 // =========================================

 always @(posedge CLOCK_50) begin
 if (!Resetn)
 prev_ps2_clk <= 1'b1;
 else
 prev_ps2_clk <= PS2_CLK_S;
 end

 assign negedge_ps2_clk = (prev_ps2_clk & !PS2_CLK_S);

 always @(posedge CLOCK_50) begin
 if (!Resetn)
 Serial <= 33'b0;
 else if (negedge_ps2_clk) begin
 Serial[31:0] <= Serial[32:1];
 Serial[32] <= PS2_DAT_S;
 end
 end

 always @(posedge CLOCK_50) begin
 if (!Resetn)
 Packet <= 4'b0;
 else if (Packet == 4'd11)
 Packet <= 4'b0;
 else if (negedge_ps2_clk)
 Packet <= Packet + 1'b1;
 end

 always @(posedge CLOCK_50) begin
 if (!Resetn) begin
 scancode_reg <= 8'h00;
 scancode_valid <= 1'b0;
 end
 else if (Packet == 4'd11) begin
 if (Serial[0] == 1'b0 && Serial[10] == 1'b1) begin
 scancode_reg <= Serial[8:1];
 scancode_valid <= 1'b1;
 end
 else begin
 scancode_valid <= 1'b0;
 end
 end
 else begin
 scancode_valid <= 1'b0;
 end
 end

 assign scancode = scancode_reg;

 // Key state handling
 reg paddle_left_held, paddle_right_held;
 reg break_code_next;

 always @(posedge CLOCK_50) begin
 if (!Resetn) begin
 paddle_left_held <= 1'b0;
 paddle_right_held <= 1'b0;
 break_code_next <= 1'b0;
 end
 else if (scancode_valid) begin
 if (scancode == 8'hF0) begin
 break_code_next <= 1'b1;
 end
 else if (break_code_next) begin
 if (scancode == 8'h1C)
 paddle_left_held <= 1'b0;
 else if (scancode == 8'h23)
 paddle_right_held <= 1'b0;
 break_code_next <= 1'b0;
 end
 else begin
 if (scancode == 8'h1C)
 paddle_left_held <= 1'b1;
 else if (scancode == 8'h23)
 paddle_right_held <= 1'b1;
 end
 end
 end

 assign paddle_left = paddle_left_held;
 assign paddle_right = paddle_right_held;
 assign shoot_ball = (scancode == 8'h1D) && scancode_valid && !break_code_next; // W key
 assign spacebar_pressed = (scancode == 8'h29) && scancode_valid && !break_code_next; // Spacebar
 assign shoot_dir = SW[0];
 assign enter_pressed = (scancode == 8'h5A) && scancode_valid && !break_code_next; // Enter key

 // =========================================
 // Game State Controller
 // =========================================

 game_state_controller GAME_STATE(
 .clk(CLOCK_50),
 .resetn(Resetn),
 .ball_lost(ball_lost),
 .spacebar_pressed(spacebar_pressed),
 .enter_pressed(enter_pressed),             
 .gameover_done(gameover_done),
 .startscreen_done(startscreen_done),        
 .bricks_remaining(bricks_remaining),
 .game_over(game_over),
 .game_reset(game_reset),
 .show_start_screen(show_start_screen),     
 .clear_trigger(clear_trigger)              
 );

 // =========================================
 // Game Logic Modules (with game_over/game_reset)
 // =========================================

 game_tick_timer TICK(
 .clk(CLOCK_50),
 .resetn(Resetn),
 .game_tick(game_tick)
 );

 paddle_controller PADDLE(
 .clk(CLOCK_50),
 .resetn(Resetn),
 .left(paddle_left),
 .right(paddle_right),
 .game_tick(game_tick),
 .paddle_x(paddle_x_pos)
 );

 ball BALL(
 .clk(CLOCK_50),
 .resetn(Resetn),
 .game_tick(game_tick),
 .start(shoot_ball),
 .shoot_dir(shoot_dir),
 .paddle_x(paddle_x_pos),
 .ball_x(ball_x_pos),
 .ball_y(ball_y_pos),
 .lost_life(ball_lost),
 .brick_hit(brick_hit),
 .hit_brick_x(hit_brick_x),
 .hit_brick_y(hit_brick_y),
 .game_over(game_over),
 .game_reset(game_reset) 
 );

 // =========================================
 // VGA Display Objects
 // =========================================

 paddle_display PADDLE_DISP(
 .clk(CLOCK_50),
 .resetn(Resetn),
 .game_reset(game_reset_pulse),
 .paddle_x(paddle_x_pos),
 .vga_x(paddle_vga_x),
 .vga_y(paddle_vga_y),
 .vga_color(paddle_color),
 .vga_write(paddle_write),
 .busy(paddle_busy),
 .clear_busy (clear_busy)
 );
 defparam PADDLE_DISP.RESOLUTION = RESOLUTION;
 defparam PADDLE_DISP.COLOR_DEPTH = COLOR_DEPTH;

 ball_display BALL_DISP(
 .clk(CLOCK_50),
 .resetn(Resetn),
 .game_reset(game_reset_pulse),
 .ball_x(ball_x_pos),
 .ball_y(ball_y_pos),
 .paddle_busy(paddle_busy),
 .vga_x(ball_vga_x),
 .vga_y(ball_vga_y),
 .vga_color(ball_color),
 .vga_write(ball_write),
 .busy(ball_busy),
 .clear_busy (clear_busy)
 );
 defparam BALL_DISP.RESOLUTION = RESOLUTION;
 defparam BALL_DISP.COLOR_DEPTH = COLOR_DEPTH;

brick_display BRICK_DISP(
    .clk(CLOCK_50),
    .resetn(Resetn),
    .game_reset(game_reset_pulse),
    .ball_x(ball_x_pos),
    .ball_y(ball_y_pos),
    .paddle_busy(paddle_busy),
    .ball_busy(ball_busy),
    .vga_x(brick_vga_x),
    .vga_y(brick_vga_y),
    .vga_color(brick_color),
    .vga_write(brick_write),
    .busy(brick_busy),
    .brick_hit(brick_hit),
    .hit_brick_x(hit_brick_x),
    .hit_brick_y(hit_brick_y),
    .bricks_remaining(bricks_remaining),
.clear_busy (clear_busy)
);
 defparam BRICK_DISP.RESOLUTION = RESOLUTION;
 defparam BRICK_DISP.COLOR_DEPTH = COLOR_DEPTH;
 
//SCORE DISPLAY
wire [4:0] score;
wire [3:0] ones_digit, tens_digit;
assign score = 5'd24 - bricks_remaining;

// Convert score to BCD (Binary Coded Decimal)
assign ones_digit = score % 10;  // Ones digit
assign tens_digit = score / 10;  // Tens digit

// Display score on HEX0 (ones) and HEX1 (tens), rest blank
dec7seg SCORE_H0 (ones_digit, HEX0);    // Ones digit (0-9)
dec7seg SCORE_H1 (tens_digit, HEX1);    // Tens digit (0-2 for 0-24)
dec7seg SCORE_H2 (4'd15, HEX2);        
dec7seg SCORE_H3 (4'd15, HEX3);        
dec7seg SCORE_H4 (4'd15, HEX4);        
dec7seg SCORE_H5 (4'd15, HEX5);

 // Game Over Display Module
 gameover_display GAMEOVER_DISP(
 .clk(CLOCK_50),
 .resetn(Resetn),
 .trigger(game_over),
 .vga_x(gameover_vga_x),
 .vga_y(gameover_vga_y),
 .vga_color(gameover_color),
 .vga_write(gameover_write),
 .busy(gameover_busy),
 .done(gameover_done)
 );

  // Start Screen Display Module
 startscreen_display STARTSCREEN_DISP(
 .clk(CLOCK_50),
 .resetn(Resetn),
 .trigger(show_start_screen),
 .vga_x(startscreen_vga_x),
 .vga_y(startscreen_vga_y),
 .vga_color(startscreen_color),
 .vga_write(startscreen_write),
 .busy(startscreen_busy),
 .done(startscreen_done)
 );
 
 // Clear Display Module
clear_display CLEAR_DISP(
    .clk      (CLOCK_50),
    .resetn   (Resetn),
    .trigger  (clear_trigger_pulse),
    .vga_x    (clear_vga_x),
    .vga_y    (clear_vga_y),
    .vga_color(clear_color),
    .vga_write(clear_write),
    .busy     (clear_busy),
    .done     (clear_done)
);

 // =========================================
 // VGA Object Mux with Start Screen, Game Over Priority & Display Gating
 // =========================================

 // Priority: Start screen, game over, clear screen, ball/paddle/bricks
wire paddle_write_gated = paddle_write & !game_over & !show_start_screen;
wire ball_write_gated   = ball_write   & !game_over & !show_start_screen;
wire brick_write_gated  = brick_write  & !game_over & !show_start_screen;

assign MUX_write = startscreen_write |      // HIGHEST PRIORITY
                   gameover_write |
                   clear_write   |
                   paddle_write_gated |
                   ball_write_gated   |
                   brick_write_gated;

assign MUX_x = startscreen_write ? startscreen_vga_x :
               gameover_write    ? gameover_vga_x :
               clear_write       ? clear_vga_x      :
               paddle_write_gated ? paddle_vga_x :
               ball_write_gated   ? ball_vga_x   :
               brick_write_gated  ? brick_vga_x  :
               {nX{1'b0}};

assign MUX_y = startscreen_write ? startscreen_vga_y :
               gameover_write    ? gameover_vga_y :
               clear_write       ? clear_vga_y      :
               paddle_write_gated ? paddle_vga_y :
               ball_write_gated   ? ball_vga_y   :
               brick_write_gated  ? brick_vga_y  :
               {nY{1'b0}};

assign MUX_color = startscreen_write ? startscreen_color :
                   gameover_write    ? gameover_color :
                   clear_write       ? clear_color      :
                   paddle_write_gated ? paddle_color :
                   ball_write_gated   ? ball_color   :
                   brick_write_gated  ? brick_color  :
                   {COLOR_DEPTH{1'b0}};


 // =========================================
 // VGA Adapter
 // =========================================

 vga_adapter VGA (
 .resetn(Resetn),
 .clock(CLOCK_50),
 .color(MUX_color),
 .x(MUX_x),
 .y(MUX_y),
 .write(MUX_write),
 .VGA_R(VGA_R),
 .VGA_G(VGA_G),
 .VGA_B(VGA_B),
 .VGA_HS(VGA_HS),
 .VGA_VS(VGA_VS),
 .VGA_BLANK_N(VGA_BLANK_N),
 .VGA_SYNC_N(VGA_SYNC_N),
 .VGA_CLK(VGA_CLK)
 );
 defparam VGA.RESOLUTION = RESOLUTION;
 defparam VGA.BACKGROUND_IMAGE =
 (RESOLUTION == "640x480") ?
 ((COLOR_DEPTH == 9) ? "black_640_9.mif" :
 ((COLOR_DEPTH == 6) ? "./MIF/rainbow_640_6.mif" :
 "./MIF/rainbow_640_3.mif")) :
 ((RESOLUTION == "320x240") ?
 ((COLOR_DEPTH == 9) ? "./MIF/rainbow_320_9.mif" :
 ((COLOR_DEPTH == 6) ? "./MIF/rainbow_320_6.mif" :
 "./MIF/rainbow_320_3.mif")) :
 ((COLOR_DEPTH == 9) ? "./MIF/rainbow_160_9.mif" :
 ((COLOR_DEPTH == 6) ? "./MIF/rainbow_160_6.mif" :
 "./MIF/rainbow_160_3.mif")));
 defparam VGA.COLOR_DEPTH = COLOR_DEPTH;

 assign LEDR = {game_over, gameover_busy, ball_lost, bricks_remaining, 2'b0, scancode[7:6]};

endmodule


// =========================================
// Paddle_display module
// =========================================

module paddle_display(
    clk,
    resetn,
    game_reset,
    paddle_x,
    vga_x,
    vga_y,
    vga_color,
    vga_write,
    busy,
    clear_busy
);
    parameter RESOLUTION   = "640x480";
    parameter nX           = 10;
    parameter nY           = 9;
    parameter COLOR_DEPTH  = 9;

    localparam PADDLE_WIDTH  = 80;
    localparam PADDLE_HEIGHT = 10;
    localparam PADDLE_Y      = 420;

    input  wire clk, resetn, game_reset, clear_busy;
    input  wire [9:0] paddle_x;
    output reg  [nX-1:0] vga_x;
    output reg  [nY-1:0] vga_y;
    output reg  [COLOR_DEPTH-1:0] vga_color;
    output reg  vga_write;
    output wire busy;

    reg [9:0] prev_paddle_x;
    reg [6:0] pixel_x;
    reg [3:0] pixel_y;
    reg [1:0] state;

    localparam S_IDLE  = 2'd0;
    localparam S_ERASE = 2'd1;
    localparam S_DRAW  = 2'd2;

    // Busy when not idle (ball_display uses this as paddle_busy)
    assign busy = (state != S_IDLE);

    always @(posedge clk) begin
        if (!resetn || game_reset) begin
            // On reset: next thing we do is draw the paddle at paddle_x
            prev_paddle_x <= 10'h3FF;               // sentinel "off-screen"
            pixel_x       <= 7'd0;
            pixel_y       <= 4'd0;
            state         <= S_DRAW;
            vga_write     <= 1'b0;
            vga_color     <= {COLOR_DEPTH{1'b0}};
        end else begin
            case (state)
                // ---------------------------------------------------------
                // IDLE: wait for paddle to move and for CLEAR to be idle
                // ---------------------------------------------------------
                S_IDLE: begin
                    vga_write <= 1'b0;
                    // Only start an update when CLEAR is not running
                    if (!clear_busy && (paddle_x != prev_paddle_x)) begin
                        pixel_x <= 7'd0;
                        pixel_y <= 4'd0;
                        state   <= S_ERASE;
                    end
                end

                // ---------------------------------------------------------
                // ERASE: draw a black rectangle at the old paddle position
                // ---------------------------------------------------------
                S_ERASE: begin
                    if (!clear_busy) begin
                        vga_x     <= prev_paddle_x + pixel_x;
                        vga_y     <= PADDLE_Y + pixel_y;
                        vga_color <= {COLOR_DEPTH{1'b0}};  // background (black)
                        vga_write <= 1'b1;

                        if (pixel_x < PADDLE_WIDTH - 1) begin
                            pixel_x <= pixel_x + 1'b1;
                        end else begin
                            pixel_x <= 7'd0;
                            if (pixel_y < PADDLE_HEIGHT - 1) begin
                                pixel_y <= pixel_y + 1'b1;
                            end else begin
                                pixel_y <= 4'd0;
                                state   <= S_DRAW;  // now draw at new position
                                vga_write <= 1'b0;
                            end
                        end
                    end else begin
                        // CLEAR is running → stall, do not advance
                        vga_write <= 1'b0;
                    end
                end

                // ---------------------------------------------------------
                // DRAW: draw the paddle at current paddle_x
                // ---------------------------------------------------------
                S_DRAW: begin
                    if (!clear_busy) begin
                        vga_x     <= paddle_x + pixel_x;
                        vga_y     <= PADDLE_Y + pixel_y;
                        vga_color <= {COLOR_DEPTH{1'b1}};  // white paddle
                        vga_write <= 1'b1;

                        if (pixel_x < PADDLE_WIDTH - 1) begin
                            pixel_x <= pixel_x + 1'b1;
                        end else begin
                            pixel_x <= 7'd0;
                            if (pixel_y < PADDLE_HEIGHT - 1) begin
                                pixel_y <= pixel_y + 1'b1;
                            end else begin
                                // Done drawing paddle
                                pixel_y       <= 4'd0;
                                prev_paddle_x <= paddle_x;
                                state         <= S_IDLE;
                                vga_write     <= 1'b0;
                            end
                        end
                    end else begin
                        // CLEAR is running → stall
                        vga_write <= 1'b0;
                    end
                end

                default: begin
                    state     <= S_IDLE;
                    vga_write <= 1'b0;
                end
            endcase
        end
    end
endmodule


// =========================================
// Ball_display module
// =========================================

module ball_display(
    clk,
    resetn,
    game_reset,
    ball_x,
    ball_y,
    paddle_busy,
    vga_x,
    vga_y,
    vga_color,
    vga_write,
    busy,
    clear_busy
);
    parameter RESOLUTION  = "640x480";
    parameter nX          = 10;
    parameter nY          = 9;
    parameter COLOR_DEPTH = 9;

    localparam BALL_SIZE    = 16;
    localparam BALL_X_RESET = 320;
    localparam BALL_Y_RESET = 420 - BALL_SIZE;

    input  wire clk, resetn, game_reset, clear_busy;
    input  wire [9:0] ball_x, ball_y;
    input  wire paddle_busy;
    output reg  [nX-1:0] vga_x;
    output reg  [nY-1:0] vga_y;
    output reg  [COLOR_DEPTH-1:0] vga_color;
    output reg  vga_write;
    output wire busy;

    // Previous ball position (for erase)
    reg [9:0] prev_ball_x;
    reg [9:0] prev_ball_y;
    reg [9:0] erase_ball_x;
    reg [9:0] erase_ball_y;

    // Pixel counters inside the 16x16 region
    reg [4:0] pixel_x;
    reg [4:0] pixel_y;

    // Simple FSM
    reg [1:0] state;
    localparam IDLE  = 2'd0;
    localparam ERASE = 2'd1;
    localparam DRAW  = 2'd2;

    assign busy = (state != IDLE);

    always @(posedge clk) begin
        if (!resetn || game_reset) begin
            // Reset state: ball at reset position, ready to draw it once
            prev_ball_x  <= BALL_X_RESET;
            prev_ball_y  <= BALL_Y_RESET;
            erase_ball_x <= BALL_X_RESET;
            erase_ball_y <= BALL_Y_RESET;
            pixel_x      <= 5'd0;
            pixel_y      <= 5'd0;
            state        <= DRAW; // draw initial ball
            vga_write    <= 1'b0;
            vga_color    <= {COLOR_DEPTH{1'b0}};
        end else begin
            case (state)
                // ---------------------------------------------------------
                // IDLE: wait for ball to move and VGA to be free
                // ---------------------------------------------------------
                IDLE: begin
                    vga_write <= 1'b0;

                    // Start an update only when VGA is free AND ball moved
                    if (!paddle_busy && !clear_busy &&
                        (ball_x != prev_ball_x || ball_y != prev_ball_y)) begin
                        erase_ball_x <= prev_ball_x;
                        erase_ball_y <= prev_ball_y;
                        pixel_x      <= 5'd0;
                        pixel_y      <= 5'd0;
                        state        <= ERASE;
                    end
                end

                // ---------------------------------------------------------
                // ERASE: erase the old ball at erase_ball_x/erase_ball_y
                // ---------------------------------------------------------
                ERASE: begin
                    if (!paddle_busy && !clear_busy) begin
                        vga_x <= erase_ball_x + pixel_x;
                        vga_y <= erase_ball_y + pixel_y;

                        // Circle mask: radius^2 = 8^2 = 64
                        if (((pixel_x - 8) * (pixel_x - 8) +
                             (pixel_y - 8) * (pixel_y - 8)) <= 64) begin
                            // Erase: draw black (or background color)
                            vga_color <= {COLOR_DEPTH{1'b0}};
                            vga_write <= 1'b1;
                        end else begin
                            vga_write <= 1'b0;
                        end

                        // Scan through 16x16 region
                        if (pixel_x < BALL_SIZE - 1) begin
                            pixel_x <= pixel_x + 1'b1;
                        end else begin
                            pixel_x <= 5'd0;
                            if (pixel_y < BALL_SIZE - 1) begin
                                pixel_y <= pixel_y + 1'b1;
                            end else begin
                                pixel_y <= 5'd0;
                                state   <= DRAW; // go draw at new position
                            end
                        end
                    end else begin
                        // VGA in use by paddle/clear; just stall
                        vga_write <= 1'b0;
                    end
                end

                // ---------------------------------------------------------
                // DRAW: draw the ball at current ball_x/ball_y
                // ---------------------------------------------------------
                DRAW: begin
                    if (!paddle_busy && !clear_busy) begin
                        vga_x <= ball_x + pixel_x;
                        vga_y <= ball_y + pixel_y;

                        if (((pixel_x - 8) * (pixel_x - 8) +
                             (pixel_y - 8) * (pixel_y - 8)) <= 64) begin
                            // Red ball: 9'b111_000_000
                            vga_color <= 9'b111_000_000;
                            vga_write <= 1'b1;
                        end else begin
                            vga_write <= 1'b0;
                        end

                        // Scan through 16x16 region
                        if (pixel_x < BALL_SIZE - 1) begin
                            pixel_x <= pixel_x + 1'b1;
                        end else begin
                            pixel_x <= 5'd0;
                            if (pixel_y < BALL_SIZE - 1) begin
                                pixel_y <= pixel_y + 1'b1;
                            end else begin
                                // Finished drawing ball
                                pixel_y     <= 5'd0;
                                prev_ball_x <= ball_x;
                                prev_ball_y <= ball_y;
                                state       <= IDLE;
                                vga_write   <= 1'b0;
                            end
                        end
                    end else begin
                        // VGA in use; stall the draw loop
                        vga_write <= 1'b0;
                    end
                end

                default: begin
                    state     <= IDLE;
                    vga_write <= 1'b0;
                end
            endcase
        end
    end

endmodule

// =========================================
// Supporting Modules
// =========================================

module sync(D, Resetn, Clock, Q);
    input wire D;
    input wire Resetn, Clock;
    output reg Q;
    reg Qi;

    always @(posedge Clock) begin
        if (!Resetn) begin
            Qi <= 1'b0;
            Q <= 1'b0;
        end
        else begin
            Qi <= D;
            Q <= Qi;
        end
    end
endmodule

module dec7seg (hex, display);
    input wire [3:0] hex;
    output reg [6:0] display;

    always @ (hex)
        case (hex)
            4'd0: display = 7'b1000000;  // 0
            4'd1: display = 7'b1111001;  // 1
            4'd2: display = 7'b0100100;  // 2
            4'd3: display = 7'b0110000;  // 3
            4'd4: display = 7'b0011001;  // 4
            4'd5: display = 7'b0010010;  // 5
            4'd6: display = 7'b0000010;  // 6
            4'd7: display = 7'b1111000;  // 7
            4'd8: display = 7'b0000000;  // 8
            4'd9: display = 7'b0011000;  // 9
            default: display = 7'b1111111;  // Blank (all segments off)
        endcase
endmodule

module game_tick_timer(clk, resetn, game_tick);
    input wire clk;
    input wire resetn;
    output reg game_tick;

    parameter TICK_HZ = 60;
    parameter DIV = 50000000 / TICK_HZ;
    reg [31:0] counter;

    always @(posedge clk) begin
        if (!resetn) begin
            counter <= 0;
            game_tick <= 0;
        end
        else begin
            if (counter >= DIV - 1) begin
                counter <= 0;
                game_tick <= 1;
            end
            else begin
                counter <= counter + 1;
                game_tick <= 0;
            end
        end
    end
endmodule

module paddle_controller(clk, resetn, left, right, game_tick, paddle_x);
    input wire clk;
    input wire resetn;
    input wire left;
    input wire right;
    input wire game_tick;
    output reg [9:0] paddle_x;

    reg [1:0] curr_state, next_state;
    reg [9:0] paddle_x_next;

    localparam SCREEN_WIDTH = 640;
    localparam PADDLE_WIDTH = 80;
    localparam STEP = 2;
    localparam CENTER_POS = (640 - 80) / 2;

    parameter IDLE = 2'b00;
    parameter MOVE_LEFT = 2'b01;
    parameter MOVE_RIGHT = 2'b10;

    wire [9:0] MAX_X;
    wire at_left_edge, at_right_edge;

    assign MAX_X = SCREEN_WIDTH - PADDLE_WIDTH;
    assign at_left_edge  = (paddle_x == 0);
    assign at_right_edge = (paddle_x >= MAX_X);

    always @(*) begin
        next_state = curr_state;
        case (curr_state)
            IDLE: begin
                if (left && !right && !at_left_edge)
                    next_state = MOVE_LEFT;
                else if (right && !left && !at_right_edge)
                    next_state = MOVE_RIGHT;
                else
                    next_state = IDLE;
            end
            MOVE_LEFT: begin
                if (!left || at_left_edge)
                    next_state = IDLE;
                else
                    next_state = MOVE_LEFT;
            end
            MOVE_RIGHT: begin
                if (!right || at_right_edge)
                    next_state = IDLE;
                else
                    next_state = MOVE_RIGHT;
            end
        endcase
    end

    always @(posedge clk) begin
        if (!resetn)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    always @(*) begin
        paddle_x_next = paddle_x;
        if (game_tick) begin
            if ((curr_state == MOVE_LEFT) && !at_left_edge) begin
                if (paddle_x <= STEP)
                    paddle_x_next = 0;
                else
                    paddle_x_next = paddle_x - STEP;
            end
            else if ((curr_state == MOVE_RIGHT) && !at_right_edge) begin
                if ((paddle_x + STEP) >= MAX_X)
                    paddle_x_next = MAX_X;
                else
                    paddle_x_next = paddle_x + STEP;
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn)
            paddle_x <= CENTER_POS;
        else
            paddle_x <= paddle_x_next;
    end
endmodule

module ball(
    clk, resetn, game_tick, start, shoot_dir, paddle_x,
    ball_x, ball_y, lost_life,
    brick_hit, hit_brick_x, hit_brick_y,
    game_over, game_reset 
);
    input  wire clk, resetn, game_tick, start, shoot_dir;
    input  wire [9:0] paddle_x;
    input  wire brick_hit;
    input  wire [9:0] hit_brick_x, hit_brick_y;
    input  wire game_over;       // Disable collisions during game over
    input  wire game_reset;      // External reset signal
   
    output reg  [9:0] ball_x, ball_y;
    output reg  lost_life;

    reg [2:0] state, next_state;

    localparam SCREEN_W  = 640;
    localparam SCREEN_H  = 480;
    localparam BALL_SIZE = 16;
    localparam PADDLE_W  = 80;
    localparam PADDLE_H  = 10;
    localparam PADDLE_Y  = 420;

    // Bottom position where the ball is considered "lost"
    localparam BOTTOM_Y  = SCREEN_H - BALL_SIZE;  // 480 - 16 = 464

    parameter RESET  = 3'b000;
    parameter IDLE   = 3'b001;
    parameter MOVE   = 3'b010;
    parameter BOUNCE = 3'b011;
    parameter LOSE   = 3'b100;

    reg vx_dir, vy_dir;
    reg [9:0] step_x, step_y;
    reg ball_bounced;

    // --------------------------------------------------------------------
    // Geometry wires for collision (use both left and right edges)
    // --------------------------------------------------------------------
    wire [9:0] ball_left   = ball_x;
    wire [9:0] ball_right  = ball_x + BALL_SIZE;
    wire [9:0] ball_top    = ball_y;
    wire [9:0] ball_bottom = ball_y + BALL_SIZE;

    wire [9:0] pad_left    = paddle_x;
    wire [9:0] pad_right   = paddle_x + PADDLE_W;
    wire [9:0] pad_top     = PADDLE_Y;
    wire [9:0] pad_bottom  = PADDLE_Y + PADDLE_H;

    wire overlap_x = (ball_right  >= pad_left)  &&
                     (ball_left   <= pad_right);

    wire overlap_y = (ball_bottom >= pad_top)   &&
                     (ball_top    <= pad_bottom);

    // Initial speed
    initial begin
        step_x = 2;
        step_y = 2;
    end

    // ------------------------
    // State register
    // ------------------------
    always @(posedge clk) begin
        if (!resetn || game_reset)
            state <= RESET;
        else
            state <= next_state;
    end

    // ------------------------
    // Next-state logic
    // ------------------------
    always @(*) begin
        next_state = state;
        case (state)
            RESET: begin
                next_state = IDLE;
            end

            IDLE: begin
                if (start)
                    next_state = MOVE;
                else
                    next_state = IDLE;
            end

            MOVE: begin
                if (game_tick)
                    next_state = BOUNCE;
                else
                    next_state = MOVE;
            end

            BOUNCE: begin
                // If we've reached the bottom, go to LOSE
                if (ball_y >= BOTTOM_Y)
                    next_state = LOSE;
                else
                    next_state = MOVE;
            end

            LOSE: begin
                // Stay in LOSE until external game_reset
                if (game_reset)
                    next_state = RESET;
                else
                    next_state = LOSE;
            end

            default: next_state = RESET;
        endcase
    end

    // ---------------------------------------------------------
    // Ball position / direction / lost_life logic
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (!resetn || game_reset) begin
            // Reset ball on paddle
            ball_x       <= paddle_x + (PADDLE_W - BALL_SIZE) / 2;
            ball_y       <= PADDLE_Y - BALL_SIZE;
            vx_dir       <= 1'b0;
            vy_dir       <= 1'b0;
            lost_life    <= 1'b0;
            ball_bounced <= 1'b0;
        end
        else begin
            // Default: deassert lost_life
            lost_life <= 1'b0;

            case (state)
                // ----------------------------------------------------------------
                // RESET: place ball on paddle, ready for idle
                // ----------------------------------------------------------------
                RESET: begin
                    ball_x       <= paddle_x + (PADDLE_W - BALL_SIZE) / 2;
                    ball_y       <= PADDLE_Y - BALL_SIZE;
                    vx_dir       <= 1'b0;
                    vy_dir       <= 1'b0;
                    ball_bounced <= 1'b0;
                end

                // ----------------------------------------------------------------
                // IDLE: ball sits on paddle, choose initial direction
                // ----------------------------------------------------------------
                IDLE: begin
                    ball_x <= paddle_x + (PADDLE_W - BALL_SIZE) / 2;
                    ball_y <= PADDLE_Y - BALL_SIZE;

                    // Choose horizontal direction before starting
                    if (shoot_dir)
                        vx_dir <= 1'b1;
                    else
                        vx_dir <= 1'b0;

                    vy_dir <= 1'b0; // start moving upward when launched

                    if (start) begin
                        ball_bounced <= 1'b1;
                        vy_dir       <= 1'b0;
                    end
                end

                // ----------------------------------------------------------------
                // MOVE: handle movement and brick collisions
                // ----------------------------------------------------------------
                MOVE: begin
                    // Disable brick collision during game_over
                    if (brick_hit && !game_over) begin
                        vy_dir       <= 1'b1;    // send ball downward
                        ball_bounced <= 1'b1;
                       
                        // crude side hit logic
                        if (ball_x < hit_brick_x + 20 ) begin
                            vx_dir <= 1'b0;
                            
                        end
                        else if (ball_x > hit_brick_x + 60) begin
                            vx_dir <= 1'b1;

                        end
                    end
                   
                    if (game_tick) begin
                        // Vertical movement
                        if (!vy_dir) begin
                            // Moving up
                            if (ball_y > step_y)
                                ball_y <= ball_y - step_y;
                            else
                                ball_y <= 0;
                        end
                        else begin
                            // Moving down, clamp to BOTTOM_Y
                            if (ball_y + step_y < BOTTOM_Y)
                                ball_y <= ball_y + step_y;
                            else
                                ball_y <= BOTTOM_Y;
                        end

                        // Horizontal movement
                        if (ball_bounced) begin
                            if (vx_dir) begin
                                // Moving right
                                if (ball_x + BALL_SIZE + step_x < SCREEN_W)
                                    ball_x <= ball_x + step_x;
                                else begin
                                    ball_x <= SCREEN_W - BALL_SIZE;
                                    vx_dir <= 1'b0;
                                end
                            end
                            else begin
                                // UPDATED: Left wall logic (bounce at x=0)
                                if (ball_x > step_x)
                                    ball_x <= ball_x - step_x;
                                else begin
                                    ball_x <= 0;
                                    vx_dir <= 1'b1;
                                end
                            end
                        end
                    end
                end

                // ----------------------------------------------------------------
                // BOUNCE: handle paddle, ceiling, and bottom detection
                // ----------------------------------------------------------------
                BOUNCE: begin
                    // UPDATED: Robust paddle collision using AABB overlap
                    // (fixes "phasing" when coming from right and clipping left edge)
                    if (overlap_x && overlap_y && !game_over) begin
                        vy_dir       <= 1'b0;  // go up
                        ball_bounced <= 1'b1;
                       
                        // change horizontal direction depending on where it hits
                        if (ball_x < paddle_x + (PADDLE_W / 3)) begin
                            vx_dir <= 1'b0;  // left
                        end
                        else if (ball_x > paddle_x + (2 * PADDLE_W / 3)) begin
                            vx_dir <= 1'b1;  // right
                        end
                    end

                    // UPDATED (optional): top wall collision at y <= 0
                    if (ball_y <= 0) begin
                        vy_dir       <= 1'b1;  // go down
                        ball_bounced <= 1'b1;
                    end

                    // Bottom (lose life)
                    if (ball_y >= BOTTOM_Y) begin
                        lost_life    <= 1'b1;
                        ball_bounced <= 0;
                    end
                end

                // ----------------------------------------------------------------
                // LOSE: hold lost_life high until game_reset
                // ----------------------------------------------------------------
                LOSE: begin
                    lost_life <= 1'b1;
                end
            endcase
        end
    end
endmodule
