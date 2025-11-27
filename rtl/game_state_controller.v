// =========================================================================
// game_state_controller.v - Manages overall game state transitions
// =========================================================================
// States: START_SCREEN -> PLAYING -> GAME_OVER -> RESETTING -> PLAYING
// Triggers screen displays and coordinates reset sequence
// =========================================================================

module game_state_controller(
    input wire clk,
    input wire resetn,
    input wire ball_lost,           // From ball module
    input wire spacebar_pressed,    // From PS/2 keyboard
    input wire enter_pressed,       // From PS/2 keyboard
    input wire gameover_done,       // From gameover_display module
    input wire startscreen_done,    // From startscreen_display module
    input wire [4:0] bricks_remaining,
    output reg game_over,           // HIGH when in game over state
    output reg game_reset,          // Pulse to reset game modules
    output reg show_start_screen,   // HIGH when showing start screen
    output reg clear_trigger        // Pulse to trigger clear_display
);

    // State encoding
    localparam START_SCREEN = 3'b000;  // NEW: Initial state
    localparam PLAYING      = 3'b001;
    localparam GAME_OVER    = 3'b010;
    localparam RESETTING    = 3'b011;
   
    reg [2:0] state, next_state;
   
    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            START_SCREEN: begin
                // Wait for start screen to finish painting, then wait for Enter
                if (startscreen_done && enter_pressed)
                    next_state = PLAYING;
            end
            
            PLAYING: begin
                // Check for lose condition (ball lost) or win condition (no bricks)
                if (ball_lost || bricks_remaining == 0)
                    next_state = GAME_OVER;
            end
           
            GAME_OVER: begin
                // Wait for spacebar press
                if (spacebar_pressed)
                    next_state = RESETTING;
            end
           
            RESETTING: begin
                // Give one cycle for clear and reset pulses
                next_state = PLAYING;
            end
           
            default: next_state = START_SCREEN;
        endcase
    end
   
    // State register
    always @(posedge clk) begin
        if (!resetn)
            state <= START_SCREEN;
        else
            state <= next_state;
    end
   
    // Output logic
    always @(*) begin
        // Default all outputs to 0
        game_over = 1'b0;
        game_reset = 1'b0;
        show_start_screen = 1'b0;
        clear_trigger = 1'b0;
        
        case (state)
            START_SCREEN: begin
                show_start_screen = 1'b1;
                // On transition to PLAYING, trigger clear and reset
                if (startscreen_done && enter_pressed) begin
                    clear_trigger = 1'b1;
                    game_reset = 1'b1;
                end
            end
            
            PLAYING: begin
                // Normal gameplay - all outputs stay at default (0)
            end
            
            GAME_OVER: begin
                game_over = 1'b1;
            end
            
            RESETTING: begin
                clear_trigger = 1'b1;  // Clear game over screen
                game_reset = 1'b1;     // Reset game objects
            end
        endcase
    end

endmodule

`default_nettype none