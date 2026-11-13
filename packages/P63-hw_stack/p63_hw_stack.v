// P63 Hardware stack
// RC-V Computer Architecture Project
// Package: P63 - Hardware Stack (Slot 21, base address 0x00020540)
//
// 8-entry x 32-bit hardware stack.
// Registers:
//   0: PUSH   - writing wdata pushes to stack (if not full; else sets sticky ovf)
//   1: POP    - reading returns top of stack and pops on clock edge (if not empty; else sets sticky unf)
//   2: TOP    - reading returns top of stack without popping
//   3: COUNT  - reading returns number of items on stack (0..8)
//   4: STATUS - reading returns {unf, ovf, full, empty} (bits 3..0)
//               writing clears sticky overflow and underflow flags (bits 2..3)
//  15: ID     - reads package number 63 (32'h0000003f)
//
// Keep the module name and the port list exactly as they are.

module p63_hw_stack (
    input  wire        clk,
    input  wire        rst,
    input  wire        sel,
    input  wire        we,
    input  wire        re,
    input  wire [3:0]  ridx,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);

    // 8 entries of 32-bit data storage
    reg [31:0] mem [0:7];

    // Stack pointer / depth counter (0 to 8)
    reg [3:0] count;

    // Sticky status flags: overflow (bit 2) and underflow (bit 3)
    reg ovf;
    reg unf;

    // Synchronous state update on the rising edge of clk
    always @(posedge clk) begin
        if (rst) begin
            count <= 4'd0;
            ovf   <= 1'b0;
            unf   <= 1'b0;
        end else if (sel) begin
            if (we) begin
                if (ridx == 4'd0) begin
                    // PUSH operation
                    if (count < 4'd8) begin
                        mem[count] <= wdata;
                        count      <= count + 1'b1;
                    end else begin
                        ovf <= 1'b1; // Push when full sets sticky overflow
                    end
                end else if (ridx == 4'd4) begin
                    // Write to STATUS clears sticky overflow and underflow
                    ovf <= 1'b0;
                    unf <= 1'b0;
                end
            end else if (re) begin
                if (ridx == 4'd1) begin
                    // POP operation (read removes top item at clock edge)
                    if (count > 4'd0) begin
                        count <= count - 1'b1;
                    end else begin
                        unf   <= 1'b1; // Pop when empty sets sticky underflow
                    end
                end
            end
        end
    end

    // Combinational read data multiplexer based on register index (ridx)
    always @(*) begin
        case (ridx)
            4'd1, 4'd2: begin
                // POP (1) or TOP (2): returns top of stack, or 0 if empty
                if (count > 4'd0)
                    rdata = mem[count - 1'b1];
                else
                    rdata = 32'd0;
            end
            4'd3: begin
                // COUNT (3): depth of stack (0 to 8)
                rdata = {28'd0, count};
            end
            4'd4: begin
                // STATUS (4):
                //   bit 0: empty
                //   bit 1: full
                //   bit 2: overflow (sticky)
                //   bit 3: underflow (sticky)
                rdata = {28'd0, unf, ovf, (count == 4'd8), (count == 4'd0)};
            end
            4'd15: begin
                // ID register (15): package ID 63 (0x3F)
                rdata = 32'd63;
            end
            default: begin
                rdata = 32'd0;
            end
        endcase
    end

endmodule
