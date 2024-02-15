//_\TLV_version 1d: tl-x.org, generated by SandPiper(TM) 1.14-2022/10/10-beta-Pro
//_\source top.tlv 39

//_\SV
   // Include Tiny Tapeout Lab.
   // Included URL: "https://raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/35e36bd144fddd75495d4cbc01c4fc50ac5bde6f/tlv_lib/tiny_tapeout_lib.tlv"// Included URL: "https://raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlv_lib/fpga_includes.tlv"
//_\source top.tlv 64

//_\SV

// ================================================
// A simple Makerchip Verilog test bench driving random stimulus.
// Modify the module contents to your needs.
// ================================================

module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uo_out;
   
   logic [31:0] r;  // a random value
   always @(posedge clk) r <= 0;
   //assign ui_in = r[7:0];
   
   logic ena = 1'b0;
   logic rst_n = ! reset;

   // Or, to provide specific inputs at specific times (as for lab C-TB) ...
   // BE SURE TO COMMENT THE ASSIGNMENT OF INPUTS ABOVE.
   // BE SURE TO DRIVE THESE ON THE B-PHASE OF THE CLOCK (ODD STEPS).
   // Driving on the rising clock edge creates a race with the clock that has unpredictable simulation behavior.
   initial begin
      #1  // Drive inputs on the B-phase.
         ui_in = 8'h0;
      #10 // Step 5 cycles, past reset.
         ui_in = 8'h0;
      #10 // Step 5 cycles, send data.
         ui_in = 8'hD5;
      #400 // Step 200 cycles, set different data.
         ui_in = 8'h2A;
      #400 // Step 200 cycles, send the data.
         ui_in = 8'hAA;
;
   end

   // Instantiate the Tiny Tapeout module.
   my_design tt(.*);

   assign passed = uo_out == 8'h2A && top.cyc_cnt > 600;
   assign failed = 1'b0;
endmodule


// Provide a wrapper module to debounce input signals if requested.
// The Tiny Tapeout top-level module.
// This simply debounces and synchronizes inputs.
// Debouncing is based on a counter. A change to any input will only be recognized once ALL inputs
// are stable for a certain duration. This approach uses a single counter vs. a counter for each
// bit.
module tt_um_template (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    /*   // The FPGA is based on TinyTapeout 3 which has no bidirectional I/Os (vs. TT6 for the ASIC).
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    */
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    
    // Synchronize.
    logic [9:0] inputs_ff, inputs_sync;
    always @(posedge clk) begin
        inputs_ff <= {ui_in, ena, rst_n};
        inputs_sync <= inputs_ff;
    end

    // Debounce.
    `define DEBOUNCE_MAX_CNT 14'h3fff
    logic [9:0] inputs_candidate, inputs_captured;
    logic sync_rst_n = inputs_sync[0];
    logic [13:0] cnt;
    always @(posedge clk) begin
        if (!sync_rst_n)
           cnt <= `DEBOUNCE_MAX_CNT;
        else if (inputs_sync != inputs_candidate) begin
           // Inputs changed before stablizing.
           cnt <= `DEBOUNCE_MAX_CNT;
           inputs_candidate <= inputs_sync;
        end
        else if (cnt > 0)
           cnt <= cnt - 14'b1;
        else begin
           // Cnt == 0. Capture candidate inputs.
           inputs_captured <= inputs_candidate;
        end
    end
    logic [7:0] clean_ui_in;
    logic clean_ena, clean_rst_n;
    assign {clean_ui_in, clean_ena, clean_rst_n} = inputs_captured;

    my_design my_design (
        .ui_in(clean_ui_in),
        
        .ena(clean_ena),
        .rst_n(clean_rst_n),
        .*);
endmodule
//_\SV



// =======================
// The Tiny Tapeout module
// =======================

module my_design (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    /*   // The FPGA is based on TinyTapeout 3 which has no bidirectional I/Os (vs. TT6 for the ASIC).
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    */
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
   wire reset = ! rst_n;

   logic count_en, count_en1, count_en2;
   /* logic [7:0] count;

   always_ff @(posedge clk) begin
      if (reset) count <= 8'h00;
      else if (count_en1 || count_en2) count <= count + 8'h01;
   end*/

   assign count_en = count_en1 | count_en2;
   //assign uo_out = count;

   uart_timer #(
      .CYCLES_PER_BIT(20000000)
   )
   dummy_timer (
      .clk(clk),
      .rst(reset),
      .half_bit(count_en1),
      .full_bit(count_en2)
   );

   shift_register #(
      .RST_VALUE(1)
   )
   dummy_shifter (
      .clk(clk),
      .rst(reset),
      .serial_in(uo_out[7]),
      .shift_enable(count_en),
      .parallel_in(8'h00),
      .load_enable(1'b0),
      .serial_out(),
      .parallel_out(uo_out)
   );

   // Just set up a simple timer to test things
   /*
   logic [31:0] count;
   always_ff @(posedge clk) begin
      if (reset) count <= 32'h0000_0000;
      else if (count >= 32'd80000000) count <= 32'h0000_0000;
      else count <= count + 32'h0000_0001;
   end

   assign uo_out[0] = count < 32'd10000000 ? 1'b1 : 1'b0;
   assign uo_out[1] = count < 32'd20000000 && count >= 32'd10000000 ? 1'b1 : 1'b0;
   assign uo_out[2] = count < 32'd30000000 && count >= 32'd20000000 ? 1'b1 : 1'b0;
   assign uo_out[3] = count < 32'd40000000 && count >= 32'd30000000 ? 1'b1 : 1'b0;
   assign uo_out[4] = count < 32'd50000000 && count >= 32'd40000000 ? 1'b1 : 1'b0;
   assign uo_out[5] = count < 32'd60000000 && count >= 32'd50000000 ? 1'b1 : 1'b0;
   assign uo_out[6] = count < 32'd70000000 && count >= 32'd60000000 ? 1'b1 : 1'b0;
   assign uo_out[7] = count < 32'd80000000 && count >= 32'd70000000 ? 1'b1 : 1'b0;

   */

   /*

   // UART Feedback
   // localparam int unsigned CYCLES_PER_BIT = 16;
   localparam bit [15:0] CYCLES_PER_BIT = 16;

   wire uart_link, data_ready;
   wire [7:0] data_out;
   wire request;
   logic [7:0] data_out_latched;
   logic request_ff, data_ready_ff;

   //assign uo_out = data_out_latched;
   assign uo_out[7] = ~reset & ui_in[7];
   assign uo_out[6:0] = data_out_latched[6:0];
   assign request = ui_in[7] & ~request_ff;

   always_ff @(posedge clk) begin
      request_ff <= ui_in[7];
      data_ready_ff <= data_ready;
   end

   always_ff @(posedge clk) begin
      if (reset) data_out_latched <= 8'h00;
      else if (data_ready && !data_ready_ff) data_out_latched <= data_out;
   end

   uart_tx #(
      .CYCLES_PER_BIT(CYCLES_PER_BIT))
   uart_tx0 (
      .clk(clk),
      .rst(reset),
      .uart_tx_out(uart_link),
      .data({1'b0, ui_in[6:0]}),
      .req(request),
      .empty(),
      .error());

   uart_rx #(
      .CYCLES_PER_BIT(CYCLES_PER_BIT))
   uart_rx0 (
      .clk(clk),
      .rst(reset),
      .uart_rx_in(uart_link),
      .data(data_out),
      .ready(data_ready));

   */

// ---------- Generated Code Inlined Here (before 1st \TLV) ----------
// Generated by SandPiper(TM) 1.14-2022/10/10-beta-Pro from Redwood EDA, LLC.
// (Installed here: /usr/local/mono/sandpiper/distro.)
// Redwood EDA, LLC does not claim intellectual property rights to this file and provides no warranty regarding its correctness or quality.


// For silencing unused signal messages.
`define BOGUS_USE(ignore)


genvar digit, input_label, leds, switch;


//
// Signals declared top-level.
//

// For $slideswitch.
logic [7:0] L0_slideswitch_a0;

// For $sseg_decimal_point_n.
logic L0_sseg_decimal_point_n_a0;

// For $sseg_digit_n.
logic [7:0] L0_sseg_digit_n_a0;

// For $sseg_segment_n.
logic [6:0] L0_sseg_segment_n_a0;





//
// Debug Signals
//

   if (1) begin : DEBUG_SIGS_GTKWAVE

      (* keep *) logic [7:0] \@0$slideswitch ;
      assign \@0$slideswitch = L0_slideswitch_a0;
      (* keep *) logic  \@0$sseg_decimal_point_n ;
      assign \@0$sseg_decimal_point_n = L0_sseg_decimal_point_n_a0;
      (* keep *) logic [7:0] \@0$sseg_digit_n ;
      assign \@0$sseg_digit_n = L0_sseg_digit_n_a0;
      (* keep *) logic [6:0] \@0$sseg_segment_n ;
      assign \@0$sseg_segment_n = L0_sseg_segment_n_a0;

      //
      // Scope: /digit[0:0]
      //
      for (digit = 0; digit <= 0; digit++) begin : \/digit 

         //
         // Scope: /leds[7:0]
         //
         for (leds = 0; leds <= 7; leds++) begin : \/leds 
            (* keep *) logic  \//@0$viz_lit ;
            assign \//@0$viz_lit = L1_Digit[digit].L2_Leds[leds].L2_viz_lit_a0;
         end
      end

      //
      // Scope: /switch[7:0]
      //
      for (switch = 0; switch <= 7; switch++) begin : \/switch 
         (* keep *) logic  \/@0$viz_switch ;
         assign \/@0$viz_switch = L1_Switch[switch].L1_viz_switch_a0;
      end


   end

// ---------- Generated Code Ends ----------
//_\TLV
   /* verilator lint_off UNOPTFLAT */
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/35e36bd144fddd75495d4cbc01c4fc50ac5bde6f/tlvlib/tinytapeoutlib.tlv 76   // Instantiated from top.tlv, 182 as: m5+tt_connections()
      assign L0_slideswitch_a0[7:0] = ui_in;
      assign L0_sseg_segment_n_a0[6:0] = ~ uo_out[6:0];
      assign L0_sseg_decimal_point_n_a0 = ~ uo_out[7];
      assign L0_sseg_digit_n_a0[7:0] = 8'b11111110;
   //_\end_source

   // Instantiate the Virtual FPGA Lab.
   //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv 307   // Instantiated from top.tlv, 185 as: m5+board(/top, /fpga, 7, $, , my_design)
      
      //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv 355   // Instantiated from /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv, 309 as: m4+thanks(m5__l(309)m5_eval(m5_get(BOARD_THANKS_ARGS)))
         //_/thanks
            
      //_\end_source
      
   
      // Board VIZ.
   
      // Board Image.
      
      //_/fpga_pins
         
         //_/fpga
            //_\source top.tlv 46   // Instantiated from /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv, 340 as: m4+my_design.
            
            
            
               // ==================
               // |                |
               // | YOUR CODE HERE |
               // |                |
               // ==================
            
               // Note that pipesignals assigned here can be found under /fpga_pins/fpga.
            
            
            
            
               // Connect Tiny Tapeout outputs. Note that uio_ outputs are not available in the Tiny-Tapeout-3-based FPGA boards.
               // *uo_out = 8'b0;
               
               
            //_\end_source
   
      // LEDs.
      
   
      // 7-Segment
      //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv 395   // Instantiated from /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv, 346 as: m4+fpga_sseg.
         for (digit = 0; digit <= 0; digit++) begin : L1_Digit //_/digit
            
            for (leds = 0; leds <= 7; leds++) begin : L2_Leds //_/leds

               // For $viz_lit.
               logic L2_viz_lit_a0;

               assign L2_viz_lit_a0 = (! L0_sseg_digit_n_a0[digit]) && ! ((leds == 7) ? L0_sseg_decimal_point_n_a0 : L0_sseg_segment_n_a0[leds % 7]);
               
            end
         end
      //_\end_source
   
      // slideswitches
      //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv 454   // Instantiated from /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv, 349 as: m4+fpga_switch.
         for (switch = 0; switch <= 7; switch++) begin : L1_Switch //_/switch

            // For $viz_switch.
            logic L1_viz_switch_a0;

            assign L1_viz_switch_a0 = L0_slideswitch_a0[switch];
            
         end
      //_\end_source
   
      // pushbuttons
      
   //_\end_source
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (top-to-bottom).
   //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/35e36bd144fddd75495d4cbc01c4fc50ac5bde6f/tlvlib/tinytapeoutlib.tlv 82   // Instantiated from top.tlv, 187 as: m5+tt_input_labels_viz(⌈"UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED"⌉)
      for (input_label = 0; input_label <= 7; input_label++) begin : L1_InputLabel //_/input_label
         
      end
   //_\end_source

//_\SV
endmodule

//_\SV
   // UART Synchronizer
   module synchronizer
      (
         input clk, //your local clock
         input async, //unsynchronized signal
         output sync //synchronized signal
      );

      // Create a signal buffer
      logic [1:0] buff;

      always_ff @ (posedge clk) begin
         buff <= {buff[0], async};
      end

      assign sync = buff[1];

   endmodule

   // UART Start Detector
   module uart_start_detector
      (
         input clk,
         input rst,
         input uart_rx_in,
         output logic start_detected
      );

      logic register;

      always_ff @(posedge clk) begin
         if (rst) register <= 1;
         else register <= uart_rx_in;
      end

      assign start_detected = register & ~uart_rx_in;

   endmodule

   // UART Shift Register
   module shift_register
      #(
         parameter int unsigned NUM_BITS = 8,
         parameter int unsigned RST_VALUE = 0
      )
      (
         input clk,
         input rst,
         input serial_in,
         input shift_enable,
         input [NUM_BITS-1:0] parallel_in,
         input load_enable,
         output logic serial_out,
         output logic [NUM_BITS-1:0] parallel_out
      );

      logic [NUM_BITS-1:0] register;

      always_ff @(posedge clk) begin
         if (rst) register <= RST_VALUE[NUM_BITS-1:0];
         else if (load_enable) register <= parallel_in;
         else if (shift_enable) begin
            for (int unsigned i = 0; i < NUM_BITS-1; i++) register[i] <= register[i+1];
            register[NUM_BITS-1] <= serial_in;
         end
         else register <= register;
      end

      always_comb begin
         parallel_out = register;
         serial_out = register[0];
      end

   endmodule

   // UART Timer
   module uart_timer
      #(
         // parameter int unsigned CYCLES_PER_BIT = 2083 // 20MHz clock, 9600 bit/sec
         parameter bit [31:0] CYCLES_PER_BIT = 2083 // 20MHz clock, 9600 bit/sec
      )
      (
         input clk,
         input rst,
         output logic half_bit,
         output logic full_bit
      );

      // localparam int unsigned HALF_BIT_CLOCKS = CYCLES_PER_BIT / 2;
      localparam bit [31:0] HALF_BIT_CLOCKS = CYCLES_PER_BIT / 2;
      // localparam int unsigned COUNTER_WIDTH = $clog2(HALF_BIT_CLOCKS);

      // logic [COUNTER_WIDTH-1:0] count;
      logic [31:0] count; // This should be plenty of bits
      logic count_complete, toggle;

      // Counter, used to indicate when one half-bit has completed
      always_ff @(posedge clk) begin
         if (rst) count <= 'h0;
         else if (count >= (HALF_BIT_CLOCKS-1)) count <= 'h0;
         else count <= count + 'h1;
      end

      assign count_complete = (count >= (HALF_BIT_CLOCKS-1)) ? 1'b1:1'b0;

      // Toggle, used to indicate when two half-bits (AKA one full bit) have completed
      always_ff @(posedge clk) begin
         if (rst) toggle <= 1'b0;
         else if (count_complete) toggle <= ~toggle;
         else toggle <= toggle;
      end

      // Output flags
      assign half_bit = count_complete & ~toggle;
      assign full_bit = count_complete & toggle;

   endmodule

   // UART RX Module
   module uart_rx
      #(
         // parameter int unsigned CYCLES_PER_BIT = 2083 // 20MHz clock, 9600 bit/sec
         parameter bit [31:0] CYCLES_PER_BIT = 2083 // 20MHz clock, 9600 bit/sec
      )
      (
         input clk,
         input rst,
         input uart_rx_in,
         output logic [7:0] data, // Valid only when "ready" is high, undefined otherwise
         output ready             // Held high for duration of STOP bit, low all other times
      );

      // Declare intermediate wires
      logic start_detected, timer_rst, half_bit, full_bit, shift_en;
      enum logic [3:0] {
         STATE_IDLE  = 4'h0,
         STATE_START = 4'h1,
         STATE_D0    = 4'h2,
         STATE_D1    = 4'h3,
         STATE_D2    = 4'h4,
         STATE_D3    = 4'h5,
         STATE_D4    = 4'h6,
         STATE_D5    = 4'h7,
         STATE_D6    = 4'h8,
         STATE_D7    = 4'h9,
         STATE_STOP  = 4'hA
      } state, next_state;

      // Connect start bit detector
      uart_start_detector start_detector(
         .clk(clk),
         .rst(rst),
         .uart_rx_in(uart_rx_in),
         .start_detected(start_detected));

      // Connect shift register
      assign shift_en = ((state > STATE_START) && (state < STATE_STOP) && half_bit) ? 1'b1:1'b0;
      shift_register #(
         .NUM_BITS(8),
         .RST_VALUE(0))
      shift_reg(
         .clk(clk),
         .rst(rst),
         .serial_in(uart_rx_in),
         .shift_enable(shift_en),
         .parallel_in(8'h0),
         .load_enable(1'b0),
         .serial_out(),
         .parallel_out(data));

      // Connect timer
      assign timer_rst = ((state == STATE_IDLE) || (state == STATE_STOP && start_detected) || rst) ? 1'b1:1'b0;
      uart_timer #(
         .CYCLES_PER_BIT(CYCLES_PER_BIT))
      timer(
         .clk(clk),
         .rst(timer_rst),
         .half_bit(half_bit),
         .full_bit(full_bit));

      // State machine logic
      always_ff @(posedge clk) begin
         if (rst || (state > STATE_STOP)) state <= STATE_IDLE;
         else if (start_detected && (state == STATE_IDLE || state == STATE_STOP)) state <= STATE_START;
         else if (full_bit)
            case (state)
               STATE_START:    state <= STATE_D0;
               STATE_D0:       state <= STATE_D1;
               STATE_D1:       state <= STATE_D2;
               STATE_D2:       state <= STATE_D3;
               STATE_D3:       state <= STATE_D4;
               STATE_D4:       state <= STATE_D5;
               STATE_D5:       state <= STATE_D6;
               STATE_D6:       state <= STATE_D7;
               STATE_D7:       state <= STATE_STOP;
               STATE_STOP:     state <= STATE_IDLE;
               default:        state <= state;
            endcase
         else state <= state;
      end

      // Connect outputs
      assign ready = (state == STATE_STOP) ? 1'b1:1'b0;

   endmodule

   // UART TX Module
   module uart_tx
      #(
         // parameter int unsigned CYCLES_PER_BIT = 2083 // 20MHz clock, 9600 bit/sec
         parameter bit [31:0] CYCLES_PER_BIT = 2083 // 20MHz clock, 9600 bit/sec
      )
      (
         input clk,
         input rst,
         output uart_tx_out,
         input [7:0] data,
         input req,
         output empty,
         output error
      );

      // Declare intermediate wires
      logic full_bit, idle_state;
      enum logic [3:0] {
         STATE_IDLE  = 4'h0,
         STATE_START = 4'h1,
         STATE_D0    = 4'h2,
         STATE_D1    = 4'h3,
         STATE_D2    = 4'h4,
         STATE_D3    = 4'h5,
         STATE_D4    = 4'h6,
         STATE_D5    = 4'h7,
         STATE_D6    = 4'h8,
         STATE_D7    = 4'h9,
         STATE_STOP  = 4'hA
      } state, next_state;

      assign idle_state = (state == STATE_IDLE) ? 1'b1:1'b0;

      // Connect shift register
      shift_register #(
         .NUM_BITS(9),
         .RST_VALUE(1))
      shift_reg(
         .clk(clk),
         .rst(rst),
         .serial_in(1'b1),
         .shift_enable(full_bit),
         .parallel_in({data, 1'b0}),
         .load_enable(idle_state & req),
         .serial_out(uart_tx_out),
         .parallel_out());

      // Connect timer
      uart_timer #(
         .CYCLES_PER_BIT(CYCLES_PER_BIT))
      timer(
         .clk(clk),
         .rst(idle_state | rst),
         .half_bit(),
         .full_bit(full_bit));

      // State machine logic
      always_ff @(posedge clk) begin
         if (rst || (state > STATE_STOP)) state <= STATE_IDLE;
         else if (idle_state & req) state <= STATE_START;
         else if (full_bit)
            case (state)
               STATE_START:    state <= STATE_D0;
               STATE_D0:       state <= STATE_D1;
               STATE_D1:       state <= STATE_D2;
               STATE_D2:       state <= STATE_D3;
               STATE_D3:       state <= STATE_D4;
               STATE_D4:       state <= STATE_D5;
               STATE_D5:       state <= STATE_D6;
               STATE_D6:       state <= STATE_D7;
               STATE_D7:       state <= STATE_STOP;
               STATE_STOP:     state <= STATE_IDLE;
               default:        state <= STATE_IDLE;
            endcase
         else state <= state;
      end

      // Connect outputs
      assign empty = idle_state;
      assign error = ~idle_state & req;

   endmodule


// Undefine macros defined by SandPiper.
`undef BOGUS_USE
