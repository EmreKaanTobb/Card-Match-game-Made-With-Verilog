module hafizaoyunu(
    input clk,
    input btnC, btnUp, btnDown, btnR, btnL,
    output reg [6:0] seg = 0,
    output reg [3:0] an = 4'b1111,
    output hsync,             // VGA horizontal sync
    output vsync,             // VGA vertical sync
    output reg[3:0] red,      // VGA red channel
    output reg[3:0] green,    // VGA green channel
    output reg[3:0] blue,      // VGA blue channel
    output reg buzzer
);

    localparam ZERO  = 7'b100_0000;  // 0
    localparam ONE   = 7'b1111_001;  // 1 -> 100_1111 reversed
    localparam TWO   = 7'b0100_100;  // 2 -> 001_0010 reversed
    localparam THREE = 7'b0110_000;  // 3 -> 000_0110 reversed
    localparam FOUR  = 7'b0011_001;  // 4 -> 100_1100 reversed
    localparam FIVE  = 7'b0010_010;  // 5 -> 010_0100 reversed
    localparam SIX   = 7'b0000_010;  // 6 -> 010_0000 reversed
    localparam SEVEN = 7'b1111_000;  // 7 -> 000_1111 reversed
    localparam L     = 7'b1110_001;  // L -> 100_0111 reversed
    localparam U     = 7'b1000_001;  // U -> 100_0001 reversed
    localparam I     = 7'b1111_011;  // I -> 110_1111 reversed
    localparam N     = 7'b0101_011;  // N -> 010_1011 reversed
    
    wire [9:0] x;   // X-coordinate
    wire [8:0] y;   // Y-coordinate
    wire active_video; // Active Video Region
    wire clk_25mhz;    // 25 MHz Clock for VGA


    // Clock Divider: 100MHz to 25MHz
    clk_divider clk_div(
        .clk_in(clk),
        .clk_out(clk_25mhz)
    );

    // VGA Controller
    vga_controller vga_ctrl(
        .clk(clk_25mhz),
        .hsync(hsync),
        .vsync(vsync),
        .x(x),
        .y(y),
        .active_video(active_video)
    );

    // Gameplay
    reg start = 0;                        // Start of the game
    reg [3:0] index = 0, prevIndex = 0;   // Card index trackers
    reg [2:0] kare [15:0];                // Cards (2-bit color ID per card)
    reg reset;                            // Reset signal
    
    // Shuffling
    reg [2:0] tempKare;
    reg [3:0] rand0to15 = 0;
    
    reg [15:0] openCards = 0;             // Tracks open cards
    reg [3:0] correctGuess = 0;           // Number of correct matches
    reg numOfSelection = 0;               // Card selection state
    reg clockOff = 0;                     // Mismatch delay flag
    reg [31:0] delay_counter = 0;         // Delay counter for mismatch
    reg [31:0] flash_counter = 0;         // Delay counter for the initial flash
    reg [8:0] sayac;                      // Counter for shuffling
    reg gir_pressed;                      // Center button signal
    reg is_flashed = 0;
    
    // Buzzer signals
    reg [31:0] buzzer_counter = 0;
    reg buzzer_active = 0;

    // Grid Calculation Variables
    reg [3:0] row, col;       // Row and column coordinates
    reg [3:0] grid_index;     // Grid index (0-15)
    
    // Button edge detection and debouncing
    wire db_btnC, db_btnUp, db_btnDown, db_btnR, db_btnL;
    reg btnUp_prev = 0, btnDown_prev = 0, btnR_prev = 0, btnL_prev = 0, btnC_prev = 0;
    wire UP, DOWN, LEFT, RIGHT, gir;
    debouncer debounce_btnC (.clk_i(clk), .btn_i(btnC), .debounce_o(db_btnC));
    debouncer debounce_btnUp (.clk_i(clk), .btn_i(btnUp), .debounce_o(db_btnUp));
    debouncer debounce_btnDown (.clk_i(clk), .btn_i(btnDown), .debounce_o(db_btnDown));
    debouncer debounce_btnR (.clk_i(clk), .btn_i(btnR), .debounce_o(db_btnR));
    debouncer debounce_btnL (.clk_i(clk), .btn_i(btnL), .debounce_o(db_btnL));  
    
    assign UP    = db_btnUp && !btnUp_prev;
    assign DOWN  = db_btnDown && !btnDown_prev;
    assign RIGHT = db_btnR && !btnR_prev;
    assign LEFT  = db_btnL && !btnL_prev;
    assign gir   = db_btnC && !btnC_prev;

    always @(posedge clk) begin
        btnUp_prev <= db_btnUp;
        btnDown_prev <= db_btnDown;
        btnR_prev <= db_btnR;
        btnL_prev <= db_btnL;
        btnC_prev <= db_btnC;
    end

    // Initialize Cards (8 Pairs: 0-7)
    initial begin
        kare[0] = 3'd0; kare[1] = 3'd0; kare[2] = 3'd1; kare[3] = 3'd1;
        kare[4] = 3'd2; kare[5] = 3'd2; kare[6] = 3'd3; kare[7] = 3'd3;
        kare[8] = 3'd4; kare[9] = 3'd4; kare[10] = 3'd5; kare[11] = 3'd5;
        kare[12] = 3'd6; kare[13] = 3'd6; kare[14] = 3'd7; kare[15] = 3'd7;
    end

    // Cursor Movement Logic
    always @(posedge clk) begin
        if (UP && index >= 4) index <= index - 4;
        if (DOWN && index <= 11) index <= index + 4;
        if (RIGHT && index % 4 != 3) index <= index + 1;
        if (LEFT && index % 4 != 0) index <= index - 1;
        if (reset) index = 0;
    end

    // Main Game Logic
    integer i;
    always @(posedge clk) begin
        if (gir) begin
            gir_pressed <= 1;
        end
        if (gir_pressed && !start) begin
            for (i = 15; i >= 0; i = i - 1) begin
                if (i == 15) begin
                    rand0to15 = 6;
                end
                else begin
                    rand0to15 = sayac % (15 - i);
                end
                tempKare = kare[i];
                kare[i] = kare[rand0to15];
                kare[rand0to15] = tempKare;
            end
            start = 1;  
            gir_pressed <= 0;
            openCards <= 16'b1111111111111111;          
        end
        else if (start && !is_flashed) begin
             if (flash_counter == 100_000_000) begin
                openCards <= 16'b0000000000000000;
                flash_counter <= 0;
                is_flashed <= 1;
            end else
                flash_counter <= flash_counter + 1;
        end
        else if (correctGuess == 8 && reset) begin
            start <= 0;
            reset <= 0;
            correctGuess <= 0;
            flash_counter <= 0;
            delay_counter <= 0;
            is_flashed <= 0;
            prevIndex <= 0;
            clockOff <= 0;
            numOfSelection <= 0;
            openCards <= 16'b0000000000000000;
        end
        
        if (gir && start) begin
            if (!numOfSelection && !openCards[index]) begin
                openCards[index] <= 1;
                prevIndex <= index;
                numOfSelection <= 1;
            end else if (numOfSelection && !openCards[index]) begin
                openCards[index] <= 1;
                if (kare[index] != kare[prevIndex])
                    clockOff <= 1;
                else
                    correctGuess <= correctGuess + 1;
                numOfSelection <= 0;
            end
            else if (correctGuess == 8) begin
                reset <= 1;
            end
        end

        // Delay for mismatched cards
        if (clockOff) begin
            if (delay_counter == 20_000_000) begin
                openCards[index] <= 0;
                openCards[prevIndex] <= 0;
                clockOff <= 0;
                delay_counter <= 0;
                buzzer_active <= 0;  // Deactivate the buzzer when mismatch handling ends
                buzzer <= 0;         // Ensure buzzer is off
            end else begin
                delay_counter <= delay_counter + 1;
                buzzer_active <= 1;
            end
        end

        // Manage the buzzer duration
        if (buzzer_active) begin
            if (buzzer_counter == 25_000) begin // Toggle every 25k cycles for a 2 kHz tone
                buzzer_counter <= 0;
                buzzer <= ~buzzer;
            end else begin
                buzzer_counter <= buzzer_counter + 1;
            end
        end else begin
            buzzer <= 0;  // Ensure buzzer is off when inactive
        end
    end

    // VGA Grid Display
    always @(posedge clk) begin
        row = y / 120;
        col = x / 160;
        grid_index = row * 4 + col;

        red = 0; green = 0; blue = 0;

        if (active_video) begin
            if (openCards[grid_index] && row < 4 && col < 4) begin
                case (kare[grid_index])
                    3'd0: red = 15;          // Red
                    3'd1: green = 15;        // Green
                    3'd2: blue = 15;         // Blue
                    3'd3: begin red = 15; green = 15; end // Yellow
                    3'd4: begin green = 15; blue = 15; end // Cyan
                    3'd5: begin red = 15; blue = 15; end// Magenta
                    3'd6: red = 3;           // Maroon
                    3'd7: blue = 5;          // Navy Blue
                endcase
            end else begin
                red = 4; green = 4; blue = 4; // Gray for hidden cards
            end
            
            // Draw the cursor
            if (grid_index == index && is_flashed) begin
                if ((x % 160 < 5) || (x % 160 > 155) || (y % 120 < 5) || (y % 120 > 115)) begin
                    red = 15; green = 15; blue = 15; // White frame
                end
            end
        end
    end

    reg clk_yavas = 0;

    always @(posedge clk) begin 
        if (sayac == 499) begin
            sayac <= 0;
            clk_yavas <= ~clk_yavas;
        end else begin
            sayac <= sayac + 1;
        end
    end

    reg [1:0] k = 0;

    always @(posedge clk_yavas) begin
        if (correctGuess < 8) begin
            an = 4'b0111;
            case (correctGuess)
                4'h0: seg = ZERO;
                4'h1: seg = ONE;
                4'h2: seg = TWO;
                4'h3: seg = THREE;
                4'h4: seg = FOUR;
                4'h5: seg = FIVE;
                4'h6: seg = SIX;
                4'h7: seg = SEVEN;
            endcase
        end else begin
            case (k)
                2'b11: begin an = 4'b0111; seg = U; end
                2'b10: begin an = 4'b1011; seg = U; end
                2'b01: begin an = 4'b1101; seg = I; end
                2'b00: begin an = 4'b1110; seg = N; end
            endcase
            k = k + 1;
        end
    end

endmodule

module clk_divider(
    input clk_in,
    output reg clk_out
);
    reg [1:0] count = 0;
    always @(posedge clk_in) begin
        count <= count + 1;
        clk_out <= count[1];
    end
endmodule