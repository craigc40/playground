/*
Parameterized class for converting between two's complement binary and gray.
Xilinx Vivado claims to support this for synthesis as of 2022.x.
*/
package gray_pkg;

    class Gray #(WIDTH=8);

        typedef bit [WIDTH-1:0] vec_t;

        static function vec_t to_gray(vec_t bin_val);
            vec_t gray_val;
            gray_val = bin_val;
            foreach (bin_val[i]) begin
                if (i < $left(bin_val)) begin
                    gray_val[i] = bin_val[i] ^ bin_val[i+1];
                end
            end
            return gray_val;
        endfunction

        // convert gray vector to binary
        // bin_val(x) = xor all gray_val bits at x and above
        static function vec_t to_bin(vec_t gray_val);
            vec_t bin_val = gray_val;
            foreach (gray_val[i]) begin
                bin_val[i] = ^(gray_val >> i);
            end
            return bin_val;
        endfunction

        // function for verifying conversions
        task testme(vec_t bin_val, gray_val);
            $display("conversion between bin %b <-> gray %b", bin_val, gray_val);
            assert (to_gray(bin_val)==gray_val) else $error("to_gray(%b) exp %b, rcv %b", bin_val, gray_val, to_gray(bin_val));
            assert (to_bin(gray_val)==bin_val) else $error("to_bin(%b) exp %b, rcv %b", gray_val, bin_val, to_bin(gray_val));
        endtask

    endclass

endpackage

module tb_gray_pkg;
    timeunit 1ns;
    timeprecision 1ps;
    import gray_pkg::*;

    Gray #(3) gobj3 = new();
    Gray #(4) gobj4 = new();
    Gray #(8) gobj8 = new();

    initial begin
        // verify all possibilities for 3 bits
        gobj3.testme('b000, 'b000);
        gobj3.testme('b001, 'b001);
        gobj3.testme('b010, 'b011);
        gobj3.testme('b011, 'b010);
        gobj3.testme('b100, 'b110);
        gobj3.testme('b101, 'b111);
        gobj3.testme('b110, 'b101);
        gobj3.testme('b111, 'b100);

        // verify all possibilities for 4 bits
        gobj4.testme('b0000, 'b0000);
        gobj4.testme('b0001, 'b0001);
        gobj4.testme('b0010, 'b0011);
        gobj4.testme('b0011, 'b0010);
        gobj4.testme('b0100, 'b0110);
        gobj4.testme('b0101, 'b0111);
        gobj4.testme('b0110, 'b0101);
        gobj4.testme('b0111, 'b0100);
        gobj4.testme('b1000, 'b1100);
        gobj4.testme('b1001, 'b1101);
        gobj4.testme('b1010, 'b1111);
        gobj4.testme('b1011, 'b1110);
        gobj4.testme('b1100, 'b1010);
        gobj4.testme('b1101, 'b1011);
        gobj4.testme('b1110, 'b1001);
        gobj4.testme('b1111, 'b1000);

        // verify one-hot cases for 8 bits
        for (integer i=0; i<=7; i++) begin
            gobj8.testme(1<<i, 1<<i | 1<<(i-1));
            gobj8.testme('hFF>>(7-i), 1<<i);
        end;

        $stop();
    end

endmodule


