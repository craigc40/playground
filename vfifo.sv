/* Functions for converting vectors between gray and two's complement binary
 This doesn't work well because it doesn't adapt to the size of its inputs.
 Going to change this to use parameterized classes since Vivado 2022.x
 has added support for it.*/
// package gray_pkg;

//     localparam vecsize = 256;

//     // convert binary vector to gray
//     // gray_val(x) = bin_val(x) xor bin_val(x+1)
//     function automatic [vecsize-1:0] to_gray(input [vecsize-1:0] bin_val);
//         var [vecsize-1:0] gray_val;
//         gray_val = bin_val;
//         foreach (bin_val[i]) begin
//             if (i < $left(bin_val)) begin
//                 gray_val[i] = bin_val[i] ^ bin_val[i+1];
//             end
//         end
//         return gray_val;
//     endfunction

//     // convert gray vector to binary
//     // bin_val(x) = xor all gray_val bits at x and above
//     function automatic [vecsize-1:0] to_bin(input [vecsize-1:0] gray_val);
//         var [vecsize-1:0] bin_val = gray_val;
//         foreach (gray_val[i]) begin
//             bin_val[i] = ^(gray_val >> i);
//         end
//         return bin_val;
//     endfunction

// endpackage

/* In a dual-clock FIFO, we need to perform the same operations on both the write pointer
and read pointer: increment and transfer across a clock boundary. This module takes care
of those operations. In order to transfer across the clock boundary, the module converts
the address to gray, double-synchronizes it, and then converts back to binary.*/
module update_addr
import gray_pkg::*;
# (parameter PTR_WIDTH=4)
(
    input xclk, yclk, ax_rst, ay_rst, x_inc,
    output logic [PTR_WIDTH-1:0] x_addr, y_addr
);
    logic [PTR_WIDTH-1:0] x_incaddr, x_gray_addr, y_gray_addr, y_gray_addr_ms;

    // Increment two copies of the same address, binary and gray,
    // based on the assertion of the x_inc signal
    assign x_incaddr = x_addr + 1;
    always_ff @(posedge xclk, posedge ax_rst) begin
        if (ax_rst) begin
            x_addr <= 0;
            x_gray_addr <= 0;
        end else begin
            if (x_inc) begin
                x_addr <= x_incaddr;
                x_gray_addr <= to_gray(x_incaddr);
            end
        end
    end

    // Double-synchronize x_gray_addr to yclk. Note that this
    // is only safe if all transitions of x_gray_addr are gray.
    // This is only assured with the gray conversion function AND
    // a guarantee that x_addr rolls over at 2^ADDRWIDTH-1
    always_ff @(posedge yclk, posedge ay_rst) begin
        if (ay_rst) begin
            y_gray_addr_ms <= 0;
            y_gray_addr <= 0;
        end else begin
            y_gray_addr_ms <= x_gray_addr;
            y_gray_addr <= y_gray_addr_ms;
        end
    end

    assign y_addr = to_bin(y_gray_addr);

endmodule


/* This module implements a dual-clock FIFO. Each assertion of wt
(synchronous to wclk) pushes one element into the FIFO. Each assertion
of rd (synchronous to rclk) pops an element. rd_data_valid indicates
when the data is valid (since there is one clock of latency from
assertion of rd to data valid.*/
module fifo_2clk #(
    parameter WIDTH=8,
    parameter DEPTH=16
)
(
    input wclk, rclk, aw_rst, ar_rst, wt, rd,
    input [WIDTH-1:0] wtdata,
    output logic [WIDTH-1:0] rddata,
    output [$clog2(DEPTH):0] w_emptycount, r_fullcount,
    output logic rd_data_valid
);

    // Address width is actually one larger than necessary to access the DRAM. Because we measure fullness
    // by subtracting the read pointer from the write pointer, we can't tell the difference between completely
    // full or completely empty (wtptr-rdptr = 0 in both cases). But with an extra bit, wtptr-rdptr=0 when
    // the FIFO is empty, and wtptr-rdptr=DEPTH when the FIFO is full.
    localparam PTR_WIDTH = $size(w_emptycount);
    typedef logic [PTR_WIDTH-1:0] addr_t;

    addr_t w_wt_addr, r_wt_addr, r_rd_addr, w_rd_addr;

    update_addr #(.PTR_WIDTH(PTR_WIDTH)) update_waddrx
        (.xclk(wclk), .yclk(rclk), .ax_rst(aw_rst), .ay_rst(ar_rst), .x_inc(wt),
         .x_addr(w_wt_addr), .y_addr(r_wt_addr));
    update_addr #(.PTR_WIDTH(PTR_WIDTH)) update_raddrx
        (.xclk(rclk), .yclk(wclk), .ax_rst(ar_rst), .ay_rst(aw_rst), .x_inc(rd),
         .x_addr(r_rd_addr), .y_addr(w_rd_addr));

    // create the full and empty flags.
    // If w_emptycount=0, then we can't write because the FIFO is full
    // If r_fullcount=0, then we can't read, because the FIFO is empty
    assign w_emptycount = DEPTH - (w_wt_addr - w_rd_addr);
    assign r_fullcount = r_wt_addr - r_rd_addr;

    // Implement the memory and the write/read access
    localparam MEM_ADDR_WIDTH = PTR_WIDTH-1;
    logic [MEM_ADDR_WIDTH-1:0] mem [DEPTH-1:0];

    always_ff @(posedge wclk) begin
        if (wt) begin
            mem[w_wt_addr[MEM_ADDR_WIDTH-1:0]] <= wtdata;
        end
    end

    always_ff @(posedge rclk, posedge ar_rst) begin
        if (ar_rst) begin
            rddata <= 0;
            rd_data_valid <= 1'b0;
        end else begin
            rddata <= mem[r_rd_addr[MEM_ADDR_WIDTH-1:0]];
            rd_data_valid <= rd;
        end
    end

endmodule

module tb_fifo_2clk_param #(parameter WIDTH=8, parameter DEPTH=4);

    logic clk, rst, wt, rd = 0;
    logic rd_data_valid;
    logic [WIDTH-1:0] wtdata, rddata;
    logic [$clog2(DEPTH):0] w_emptycount, r_fullcount;

    fifo_2clk #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dutx (.wclk(clk), .rclk(clk), .aw_rst(rst), .ar_rst(rst), .*);

    // wait 'c' rising edges of clk
    task cwait (input int c=1);
        for (integer i=0; i<c; i++) @(posedge clk);
    endtask

    // explore fork/join for simultaneous write/read

    // Set up timing, clock, and reset
    timeunit 1ns;
    timeprecision 1ps;
    initial begin
        $display("Testing WIDTH=%d DEPTH=%d", WIDTH, DEPTH);
        rst = 1'b1;
        clk = 0;
        wt = 0;
        #12 rst = 1'b0;
    end
    always #5 clk=~clk;

    task dowt([WIDTH-1:0] data);
        wt = 1;
        wtdata = data;
        cwait;
        wt = 0;
        wtdata = 0;
    endtask;

    task dowrites(int numwords);
        for (integer i=1; i<=numwords; i++) dowt(wtdata++);
    endtask;

    task dord([WIDTH-1:0] expdata);
      rd = 1;
      cwait;
      rd = 0;
    endtask;

    initial begin
        //wt = 0;
        wtdata = 0;
        @(negedge rst);
        cwait;
        dowrites(1);
        wait(r_fullcount==1);
        dord(1);

        dowt(2);
        dowt(3);
        dowt(4);
        dowt(5);
        cwait(4);
        dord(1);
        cwait(4);
        $stop();
    end

endmodule
