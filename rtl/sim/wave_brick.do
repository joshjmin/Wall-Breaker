# wave_brick.do - Waveform setup for brick display testing
# Usage: do wave_brick.do

onerror {resume}

# Clock and Reset
add wave -divider "CLOCK & RESET"
add wave /tb_brick_test/CLOCK_50
add wave /tb_brick_test/resetn

# Ball Position (Testbench Controlled)
add wave -divider "BALL POSITION (TEST INPUT)"
add wave -radix unsigned -color Magenta /tb_brick_test/ball_x
add wave -radix unsigned -color Magenta /tb_brick_test/ball_y

# Busy Signals
add wave -divider "BUSY SIGNALS"
add wave -color Yellow /tb_brick_test/paddle_busy
add wave -color Yellow /tb_brick_test/ball_busy
add wave -color Orange /tb_brick_test/brick_busy

# Brick Display State Machine
add wave -divider "BRICK STATE MACHINE"
add wave -color Cyan /tb_brick_test/BRICK_DUT/state
add wave -radix unsigned /tb_brick_test/BRICK_DUT/current_brick
add wave -radix unsigned /tb_brick_test/BRICK_DUT/pixel_x
add wave -radix unsigned /tb_brick_test/BRICK_DUT/pixel_y

# Collision Detection
add wave -divider "COLLISION DETECTION"
add wave -color Red /tb_brick_test/brick_hit
add wave /tb_brick_test/BRICK_DUT/collision_detected_comb
add wave /tb_brick_test/BRICK_DUT/collision_detected_reg
add wave -radix unsigned /tb_brick_test/BRICK_DUT/hit_brick_index_comb
add wave -radix unsigned /tb_brick_test/BRICK_DUT/hit_brick_index_reg

# Hit Brick Information
add wave -divider "HIT BRICK INFO"
add wave -radix unsigned -color Red /tb_brick_test/hit_brick_x
add wave -radix unsigned -color Red /tb_brick_test/hit_brick_y
add wave -radix unsigned /tb_brick_test/BRICK_DUT/brick_to_erase
add wave -radix unsigned /tb_brick_test/BRICK_DUT/brick_to_erase_x
add wave -radix unsigned /tb_brick_test/BRICK_DUT/brick_to_erase_y

# Brick State
add wave -divider "BRICK STATE"
add wave -radix binary /tb_brick_test/BRICK_DUT/brick_alive
add wave -radix unsigned -color Green /tb_brick_test/bricks_remaining

# VGA Output
add wave -divider "VGA OUTPUT"
add wave -color Orange /tb_brick_test/brick_vga_write
add wave -radix unsigned /tb_brick_test/brick_vga_x
add wave -radix unsigned /tb_brick_test/brick_vga_y
add wave -radix hex /tb_brick_test/brick_vga_color

# Configure wave window
configure wave -namecolwidth 250
configure wave -valuecolwidth 80
configure wave -justifyvalue right
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

echo "Waves added successfully!"
echo ""
echo "=========================================="
echo "SIGNAL GUIDE:"
echo "=========================================="
echo "State Encoding:"
echo "  00 = INIT  (Drawing all bricks at startup)"
echo "  01 = IDLE  (Checking for collisions)"
echo "  10 = ERASE (Erasing hit brick)"
echo ""
echo "Brick Layout:"
echo "  24 bricks total: 8 columns x 3 rows"
echo "  Each brick: 80x20 pixels"
echo "  Row 0 (0-7):   RED   (Y: 0-19)"
echo "  Row 1 (8-15):  GREEN (Y: 20-39)"
echo "  Row 2 (16-23): BLUE  (Y: 40-59)"
echo ""
echo "brick_alive (24-bit binary):"
echo "  Bit N = 1: Brick N is alive"
echo "  Bit N = 0: Brick N is destroyed"
echo ""
echo "Color Format (9-bit): RRR_GGG_BBB"
echo "  Red:   111_000_000"
echo "  Green: 000_111_000"
echo "  Blue:  000_000_111"
echo "  Black: 000_000_000"
echo ""
echo "=========================================="
echo "SUGGESTED COMMANDS:"
echo "=========================================="
echo "Run full test:      run 2ms"
echo "Run until IDLE:     run -all"
echo "Zoom to fit:        wave zoom full"
echo "Find collision:     when {brick_hit == 1}"
echo ""