module fp16_mac (
    input  wire        clk,    
    input  wire [15:0] val_a,
    input  wire [15:0] val_b,
    input  wire [15:0] acc_in,  // Dữ liệu c_out từ PE truyền vào
    output wire [15:0] acc_out
);

    wire [15:0] mult_res;

    fp16_mult u_mult (
        .a(val_a),
        .b(val_b),
        .result(mult_res)
    );

    fp16_add u_add (
        .a(mult_res),
        .b(acc_in),
        .result(acc_out)
    );

endmodule