/*
Parameterized class for converting between two's complement binary and gray.
Xilinx Vivado claims to support this for synthesis as of 2022.x.
*/

package gray_pkg;

    class Gray #(WIDTH=8);

        typedef bit [WIDTH-1:0] vec_t;

        // convert binary vector to gray
        // gray(x) = bin(x) xor bin(x+1) for x<msb
        // if x==msb, then gray(x)=bin(x)
        static function vec_t to_gray(vec_t bin_val);
            vec_t gray_val;
            foreach (bin_val[i]) begin
                gray_val[i] = (i<$left(bin_val))? bin_val[i] ^ bin_val[i+1] : bin_val[i];
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


// Test converting between gray and binary for values that are easy to predict
module tb_test_gray_onehot #(parameter WIDTH=8);

    Gray #(WIDTH) obj;

    initial begin
        obj = new;
        $display("testing one-hot cases")
        for (int i=1; i<=WIDTH; i++) begin
            obj.testme(1<<i, 1<<i | 1<<(i-1));
            obj.testme('hFF>>(7-i), 1<<i);
        end
    end
endmodule


module tb_gray_pkg;
    timeunit 1ns;
    timeprecision 1ps;
    import gray_pkg::*;

    initial begin
        // verify all possibilities for 3 bits
        obj3 = Gray#(3)::new();
        obj3.testme('b000, 'b000);
        obj3.testme('b001, 'b001);
        obj3.testme('b010, 'b011);
        obj3.testme('b011, 'b010);
        obj3.testme('b100, 'b110);
        obj3.testme('b101, 'b111);
        obj3.testme('b110, 'b101);
        obj3.testme('b111, 'b100);

        // verify all possibilities for 4 bits
        obj4 = Gray#(4)::new();
        obj4.testme('b0000, 'b0000);
        obj4.testme('b0001, 'b0001);
        obj4.testme('b0010, 'b0011);
        obj4.testme('b0011, 'b0010);
        obj4.testme('b0100, 'b0110);
        obj4.testme('b0101, 'b0111);
        obj4.testme('b0110, 'b0101);
        obj4.testme('b0111, 'b0100);
        obj4.testme('b1000, 'b1100);
        obj4.testme('b1001, 'b1101);
        obj4.testme('b1010, 'b1111);
        obj4.testme('b1011, 'b1110);
        obj4.testme('b1100, 'b1010)
        obj4.testme('b1101, 'b1011);
        obj4.testme('b1110, 'b1001);
        obj4.testme('b1111, 'b1000);
    end;

    for (genvar i=1; i<=8; i++) begin
        tb_test_gray_onehot testx #(i);
    end

endmodule


