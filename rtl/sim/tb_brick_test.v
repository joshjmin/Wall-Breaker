`timescale 1ns / 1ns
`default_nettype none

// Testbench for brick display and collision detection
// CORRECTED VERSION - Ensures ball only hits ONE brick per test
module tb_brick_test();

    // Clock and reset
    reg CLOCK_50;
    reg resetn;
    
    // Ball position (controlled by testbench)
    reg [9:0] ball_x;
    reg [9:0] ball_y;
    
    // Busy signals from other modules (simulated)
    reg paddle_busy;
    reg ball_busy;
    
    // Brick display outputs
    wire [9:0] brick_vga_x;
    wire [8:0] brick_vga_y;
    wire [8:0] brick_vga_color;
    wire brick_vga_write;
    wire brick_busy;
    wire brick_hit;
    wire [9:0] hit_brick_x;
    wire [9:0] hit_brick_y;
    wire [4:0] bricks_remaining;
    
    // Instantiate brick display module
    brick_display BRICK_DUT (
        .clk(CLOCK_50),
        .resetn(resetn),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .paddle_busy(paddle_busy),
        .ball_busy(ball_busy),
        .vga_x(brick_vga_x),
        .vga_y(brick_vga_y),
        .vga_color(brick_vga_color),
        .vga_write(brick_vga_write),
        .busy(brick_busy),
        .brick_hit(brick_hit),
        .hit_brick_x(hit_brick_x),
        .hit_brick_y(hit_brick_y),
        .bricks_remaining(bricks_remaining)
    );
    
    // Clock generation: 50MHz = 20ns period
    initial CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50;
    
    // Track number of bricks hit
    integer bricks_hit_count = 0;
    integer wait_counter = 0;
    
    // Monitor brick hits
    always @(posedge CLOCK_50) begin
        if (brick_hit) begin
            bricks_hit_count = bricks_hit_count + 1;
            $display(">>> BRICK HIT #%0d at position (%0d, %0d)", 
                     bricks_hit_count, hit_brick_x, hit_brick_y);
            $display("    Bricks remaining: %0d/24", bricks_remaining);
        end
    end
    
    // Monitor state transitions
    reg [1:0] prev_state;
    initial prev_state = 2'b00;
    
    always @(posedge CLOCK_50) begin
        if (BRICK_DUT.state != prev_state) begin
            case (BRICK_DUT.state)
                2'd0: $display("[STATE] INIT (drawing all bricks)");
                2'd1: $display("[STATE] IDLE (checking collisions)");
                2'd2: $display("[STATE] ERASE (removing brick)");
                default: $display("[STATE] UNKNOWN (%0d)", BRICK_DUT.state);
            endcase
            prev_state = BRICK_DUT.state;
        end
    end
    
    // Test stimulus
    initial begin
        $display("=======================================================");
        $display("===   Brick Display & Collision Detection Test     ===");
        $display("===   CORRECTED VERSION - Single Brick Hits         ===");
        $display("=======================================================");
        $display("");
        $display("BRICK LAYOUT:");
        $display("  24 bricks: 8 columns × 3 rows");
        $display("  Each brick: 80×20 pixels");
        $display("  Row 0 (RED):   Bricks 0-7   at Y: 0-19");
        $display("  Row 1 (GREEN): Bricks 8-15  at Y: 20-39");
        $display("  Row 2 (BLUE):  Bricks 16-23 at Y: 40-59");
        $display("");
        $display("BALL SIZE: 16×16 pixels");
        $display("  Ball position = top-left corner");
        $display("  Ball at (X,Y) occupies X to X+15, Y to Y+15");
        $display("=======================================================");
        $display("");
        
        // Initialize signals
        resetn = 0;
        ball_x = 320;  // Safe position (middle of screen, below bricks)
        ball_y = 240;
        paddle_busy = 0;
        ball_busy = 0;
        
        // Hold reset
        #200;
        resetn = 1;
        $display("Time: %0t - Reset released", $time);
        $display("Time: %0t - Brick module initializing...", $time);
        
        // Wait for INIT state to complete (drawing all 24 bricks)
        wait(BRICK_DUT.state == 2'd1);  // Wait until IDLE
        $display("");
        $display("Time: %0t - *** All bricks drawn ***", $time);
        $display("Time: %0t - Bricks remaining: %0d/24", $time, bricks_remaining);
        $display("");
        
        #1000;
        
        // =====================================================
        // TEST 1: Check initial state (no collision)
        // =====================================================
        $display("╔════════════════════════════════════════════════════╗");
        $display("║ TEST 1: No Collision (Ball Away From Bricks)      ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("Ball position: (%0d, %0d)", ball_x, ball_y);
        $display("Expected: No collision detected");
        #5000;
        if (!brick_hit)
            $display("✓ PASS: No false collision detected");
        else
            $display("✗ FAIL: False collision detected!");
        $display("");
        
        // =====================================================
        // TEST 2: Hit brick in top-left (Brick 0: Red)
        // =====================================================
        $display("╔════════════════════════════════════════════════════╗");
        $display("║ TEST 2: Hit Top-Left Brick (Brick 0)              ║");
        $display("╚════════════════════════════════════════════════════╝");
        ball_x = 10;
        ball_y = 2;   // Ball extends to Y:18, stays in row 0 (0-19)
        $display("Ball moved to: (%0d, %0d)", ball_x, ball_y);
        $display("Ball occupies: X:%0d-%0d, Y:%0d-%0d", ball_x, ball_x+15, ball_y, ball_y+15);
        $display("Target: Brick 0 (Column 0, Row 0) at (0, 0)");
        $display("Expected collision: YES");
        
        // Wait for collision detection (should happen within a few cycles)
        @(posedge brick_hit);
        $display("✓ Collision detected at time %0t", $time);
        
        // Immediately verify correct brick was hit
        if (hit_brick_x == 0 && hit_brick_y == 0)
            $display("✓ PASS: Correct brick hit (0, 0)");
        else
            $display("✗ FAIL: Wrong brick hit! Expected (0,0), got (%0d,%0d)", 
                     hit_brick_x, hit_brick_y);
        
        // Move ball away IMMEDIATELY to prevent multiple collisions
        ball_x = 320;
        ball_y = 240;
        
        // Wait for erase to complete
        wait(BRICK_DUT.state == 2'd1);
        $display("Brick erased, back to IDLE");
        #2000;
        $display("");
        
        // =====================================================
        // TEST 3: Hit brick in middle (Brick 12: Green)
        // =====================================================
        $display("╔════════════════════════════════════════════════════╗");
        $display("║ TEST 3: Hit Middle Brick (Brick 12)               ║");
        $display("╚════════════════════════════════════════════════════╝");
        ball_x = 250;  // Column 4 starts at 240 (3×80)
        ball_y = 20;   // Ball extends to Y:36, stays in row 1 (20-39)
        $display("Ball moved to: (%0d, %0d)", ball_x, ball_y);
        $display("Ball occupies: X:%0d-%0d, Y:%0d-%0d", ball_x, ball_x+15, ball_y, ball_y+15);
        $display("Target: Brick 12 (Column 4, Row 1) at (240, 20)");
        $display("Expected collision: YES");
        
        @(posedge brick_hit);
        $display("✓ Collision detected at time %0t", $time);
        
        if (hit_brick_x == 240 && hit_brick_y == 20)
            $display("✓ PASS: Correct brick hit (240, 20)");
        else
            $display("✗ FAIL: Wrong brick hit! Expected (240,20), got (%0d,%0d)", 
                     hit_brick_x, hit_brick_y);
        
        ball_x = 320;
        ball_y = 240;
        
        wait(BRICK_DUT.state == 2'd1);
        $display("Brick erased, back to IDLE");
        #2000;
        $display("");
        
        // =====================================================
        // TEST 4: Hit brick at right edge (Brick 7: Red)
        // =====================================================
        $display("╔════════════════════════════════════════════════════╗");
        $display("║ TEST 4: Hit Rightmost Top Brick (Brick 7)         ║");
        $display("╚════════════════════════════════════════════════════╝");
        ball_x = 570;  // Column 7 starts at 560 (7×80)
        ball_y = 2;    // Ball extends to Y:18, stays in row 0 (0-19)
        $display("Ball moved to: (%0d, %0d)", ball_x, ball_y);
        $display("Ball occupies: X:%0d-%0d, Y:%0d-%0d", ball_x, ball_x+15, ball_y, ball_y+15);
        $display("Target: Brick 7 (Column 7, Row 0) at (560, 0)");
        $display("Expected collision: YES");
        
        @(posedge brick_hit);
        $display("✓ Collision detected at time %0t", $time);
        
        if (hit_brick_x == 560 && hit_brick_y == 0)
            $display("✓ PASS: Correct brick hit (560, 0)");
        else
            $display("✗ FAIL: Wrong brick hit! Expected (560,0), got (%0d,%0d)", 
                     hit_brick_x, hit_brick_y);
        
        ball_x = 320;
        ball_y = 240;
        
        wait(BRICK_DUT.state == 2'd1);
        $display("Brick erased, back to IDLE");
        #2000;
        $display("");
        
        // =====================================================
        // TEST 5: Hit bottom row brick (Brick 20: Blue)
        // =====================================================
        $display("╔════════════════════════════════════════════════════╗");
        $display("║ TEST 5: Hit Bottom Row Brick (Brick 20)           ║");
        $display("╚════════════════════════════════════════════════════╝");
        ball_x = 330;  // Column 4 starts at 320 (4×80)
        ball_y = 40;   // Ball extends to Y:56, stays in row 2 (40-59)
        $display("Ball moved to: (%0d, %0d)", ball_x, ball_y);
        $display("Ball occupies: X:%0d-%0d, Y:%0d-%0d", ball_x, ball_x+15, ball_y, ball_y+15);
        $display("Target: Brick 20 (Column 4, Row 2) at (320, 40)");
        $display("Expected collision: YES");
        
        @(posedge brick_hit);
        $display("✓ Collision detected at time %0t", $time);
        
        if (hit_brick_x == 320 && hit_brick_y == 40)
            $display("✓ PASS: Correct brick hit (320, 40)");
        else
            $display("✗ FAIL: Wrong brick hit! Expected (320,40), got (%0d,%0d)", 
                     hit_brick_x, hit_brick_y);
        
        ball_x = 320;
        ball_y = 240;
        
        wait(BRICK_DUT.state == 2'd1);
        $display("Brick erased, back to IDLE");
        #2000;
        $display("");
        
        // =====================================================
        // TEST 6: Test busy signal coordination
        // =====================================================
        $display("╔════════════════════════════════════════════════════╗");
        $display("║ TEST 6: Busy Signal Coordination                  ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("Testing: Erase operation should stall when paddle_busy=1");
        
        ball_x = 90;   // Column 1 starts at 80
        ball_y = 2;    // Row 0
        $display("Ball moved to: (%0d, %0d)", ball_x, ball_y);
        $display("Target: Brick 1 at (80, 0)");
        
        @(posedge brick_hit);
        $display("✓ Collision detected");
        
        // Move ball away
        ball_x = 320;
        ball_y = 240;
        
        // Wait a bit then set paddle busy during erase
        #1000;
        paddle_busy = 1;
        $display("Setting paddle_busy = 1 (erase should stall)");
        
        // Monitor state - should stay in ERASE
        #10000;
        if (BRICK_DUT.state == 2'd2)
            $display("✓ PASS: Erase stalled while paddle busy");
        else
            $display("✗ FAIL: State changed despite paddle busy");
        
        paddle_busy = 0;
        $display("Clearing paddle_busy = 0 (erase should resume)");
        
        wait(BRICK_DUT.state == 2'd1);
        $display("✓ Erase completed after paddle became available");
        #2000;
        $display("");
        
        // =====================================================
        // TEST 7: Boundary collision detection
        // =====================================================
        $display("╔════════════════════════════════════════════════════╗");
        $display("║ TEST 7: Boundary Collision Detection              ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        // Test 7a: Just inside brick boundary
        $display("Test 7a: Ball at right edge of brick");
        ball_x = 64;   // Ball extends to X:80, just touches brick 0 boundary
        ball_y = 2;
        $display("Ball at (%0d, %0d), extends to X:%0d", ball_x, ball_y, ball_x+15);
        $display("Should overlap Brick 0 (ends at X:79)");
        
        #100;  // Wait a few cycles
        // Wait up to 5000 time units for `brick_hit` (ModelSim doesn't allow
        // a delay inside an event control expression). Poll with 1-timeunit
        // steps so we don't block forever.
        wait_counter = 0;
        while (!brick_hit && wait_counter < 5000) begin
            #1;
            wait_counter = wait_counter + 1;
        end
        if (brick_hit)
            $display("✓ PASS: Edge collision detected");
        else
            $display("✗ FAIL: Edge collision missed");
        
        ball_x = 320;
        ball_y = 240;
        wait(BRICK_DUT.state == 2'd1);
        #2000;
        
        // Test 7b: Just outside brick area
        $display("Test 7b: Ball outside brick area");
        ball_x = 320;
        ball_y = 100;  // Well below bricks (bricks end at Y:59)
        $display("Ball at (%0d, %0d)", ball_x, ball_y);
        $display("Should NOT hit any brick");
        
        #5000;
        if (!brick_hit)
            $display("✓ PASS: No false positive outside brick area");
        else
            $display("✗ FAIL: False positive detected!");
        $display("");
        
        // =====================================================
        // TEST 8: Multiple rapid position changes
        // =====================================================
        $display("╔════════════════════════════════════════════════════╗");
        $display("║ TEST 8: Rapid Ball Movement (Stress Test)         ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("Rapidly moving ball through multiple bricks...");
        
        // Hit brick 2
        ball_x = 170; ball_y = 2;
        @(posedge brick_hit);
        ball_x = 320; ball_y = 240;
        wait(BRICK_DUT.state == 2'd1);
        #500;
        
        // Hit brick 10
        ball_x = 170; ball_y = 20;
        @(posedge brick_hit);
        ball_x = 320; ball_y = 240;
        wait(BRICK_DUT.state == 2'd1);
        #500;
        
        // Hit brick 18
        ball_x = 170; ball_y = 40;
        @(posedge brick_hit);
        ball_x = 320; ball_y = 240;
        wait(BRICK_DUT.state == 2'd1);
        
        $display("✓ Stress test complete");
        $display("");
        
        // =====================================================
        // Summary
        // =====================================================
        #5000;
        $display("=======================================================");
        $display("===              TEST SUMMARY                       ===");
        $display("=======================================================");
        $display("Total bricks hit: %0d", bricks_hit_count);
        $display("Bricks remaining: %0d/24", bricks_remaining);
        $display("Expected: 9 bricks hit (1 per test + 3 in stress test)");
        $display("");
        
        if (bricks_hit_count == 9 && bricks_remaining == 15) begin
            $display("╔════════════════════════════════════════════════════╗");
            $display("║          ✓✓✓ ALL TESTS PASSED ✓✓✓                 ║");
            $display("╚════════════════════════════════════════════════════╝");
        end else if (bricks_hit_count >= 8 && bricks_hit_count <= 10) begin
            $display("RESULT: MOSTLY PASS - Minor discrepancies");
        end else begin
            $display("RESULT: FAIL - Unexpected collision behavior");
        end
        
        $display("");
        $display("=== Simulation Complete ===");
        $finish;
    end
    
    // Pixel counter monitor (for debugging INIT state)
    integer pixel_count = 0;
    always @(posedge CLOCK_50) begin
        if (BRICK_DUT.state == 2'd0 && brick_vga_write) begin
            pixel_count = pixel_count + 1;
            if (pixel_count % 5000 == 0) begin
                $display("  [INIT] Progress: %0d pixels drawn (brick %0d/24)", 
                         pixel_count, BRICK_DUT.current_brick + 1);
            end
        end
    end
    
    // Detect multiple hits on same position (shouldn't happen)
    reg [9:0] last_hit_x, last_hit_y;
    initial begin
        last_hit_x = 10'h3FF;
        last_hit_y = 10'h3FF;
    end
    
    always @(posedge brick_hit) begin
        if (hit_brick_x == last_hit_x && hit_brick_y == last_hit_y) begin
            $display("⚠ WARNING: Same brick hit twice at (%0d, %0d)!", 
                     hit_brick_x, hit_brick_y);
        end
        last_hit_x = hit_brick_x;
        last_hit_y = hit_brick_y;
    end
    
    // Timeout watchdog
    initial begin
        #10000000;  // 10ms simulation time
        $display("");
        $display("⚠ WARNING: Simulation timeout after 10ms");
        $display("Final state: %0d, Bricks hit: %0d", BRICK_DUT.state, bricks_hit_count);
        $finish;
    end

endmodule