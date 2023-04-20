/*
Parameterized class for converting between two's complement binary and gray.
Xilinx Vivado claims to support this for synthesis as of 2022.x.
*/
package classes;

virtual class base;
    // virtual function bit [511:0] get_zeros();
    //     return 512'b0;
    // endfunction
endclass

class my_class#(int WIDTH) extends base;
    typedef bit [WIDTH-1:0] vec_t;
    function vec_t get_zeros();
        vec_t x = '0;
        return x;
   endfunction
endclass

endpackage : classes

module top;

    import classes::*;

    // This works
    base my_array[1:3];
    initial begin
        my_array[1] = my_class#(1)::new;
        my_array[2] = my_class#(2)::new;
        my_array[3] = my_class#(3)::new;
        foreach(my_array[i])
            $display("i=%d, vec=%b", i, my_array[i].get_zeros());
    end

    // So does this
    for (genvar i=1; i<=3; i++) begin
        initial begin
            static my_class#(i)  obj = new();
            $display("i=%d, vec=%b", i, obj.get_zeros());
        end
    end

    // But what I really want is this so that I have an array I can operate on later in the file.
    // It fails ModelSim compilation with this error:
    //    'new' expression can only be assigned to a class or covergroup variable
    // base my_arrayx[1:3];
    // for (genvar i=1; i<=3; i++) begin
    //     my_class#(i) my_arrayx[i] = new();
    // end
    // initial begin
    //     foreach(my_arrayx[i])
    //         $display("i=%d, vec=%b", i, my_arrayx[i].get_zeros());
    // end

endmodule : top


package gray_pkg;

    virtual class GrayBase;
        //virtual static function vec_t to_gray(bit [511:0] bin_val);

    endclass

    class Gray #(WIDTH=8) extends GrayBase;

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

    // GrayBase ary[1:9];

    // for (genvar i=1; i<10; i++) begin
    //     Gray#(i) ary[i] = new();
    //     //assign ary[i] = Gray#(i)::new;
    // end

    Gray #(3) gobj3 = new();
    Gray #(4) gobj4 = new();
    Gray #(8) gobj8 = new();

    initial begin
        // for (int i=1; i<=10; i++) begin
        //     ary[i] = Gray#(i)::new;
        // end

        // // verify all possibilities for 3 bits
        // ary[3].testme('b000, 'b000);
        // ary[3].testme('b001, 'b001);
        // ary[3].testme('b010, 'b011);
        // ary[3].testme('b011, 'b010);
        // ary[3].testme('b100, 'b110);
        // ary[3].testme('b101, 'b111);
        // ary[3].testme('b110, 'b101);
        // ary[3].testme('b111, 'b100);


        // // verify all possibilities for 3 bits
        gobj3.testme('b000, 'b000);
        gobj3.testme('b001, 'b001);
        gobj3.testme('b010, 'b011);
        gobj3.testme('b011, 'b010);
        gobj3.testme('b100, 'b110);
        gobj3.testme('b101, 'b111);
        gobj3.testme('b110, 'b101);
        gobj3.testme('b111, 'b100);

        // // verify all possibilities for 4 bits
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


