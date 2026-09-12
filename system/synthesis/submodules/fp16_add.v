`timescale 1ns / 1ps

module fp16_add (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [15:0] result
);

    // Các thành phần
    wire sign_a = a[15];
    wire sign_b = b[15];
    wire [4:0] exp_a = a[14:10];
    wire [4:0] exp_b = b[14:10];
    wire [10:0] mant_a = (|exp_a) ? {1'b1, a[9:0]} : 11'd0;
    wire [10:0] mant_b = (|exp_b) ? {1'b1, b[9:0]} : 11'd0;

    // Xác định số lớn và số bé để gióng hàng
    wire a_is_larger = ({exp_a, mant_a} > {exp_b, mant_b});
    
    wire sign_large = a_is_larger ? sign_a : sign_b;
    wire [4:0] exp_large = a_is_larger ? exp_a : exp_b;
    wire [10:0] mant_large = a_is_larger ? mant_a : mant_b;
    
    wire sign_small = a_is_larger ? sign_b : sign_a;
    wire [4:0] exp_small = a_is_larger ? exp_b : exp_a;
    wire [10:0] mant_small = a_is_larger ? mant_b : mant_a;

    // Độ lệch số mũ
    wire [4:0] exp_diff = exp_large - exp_small;
    
    // Dịch phải mantissa của số bé để gióng hàng với số lớn
    wire [12:0] aligned_large = {mant_large, 2'b00};
    wire [12:0] aligned_small = {mant_small, 2'b00} >> exp_diff;

    // Tính toán Cộng hoặc Trừ mantissa
    wire [13:0] mant_sum; // 14 bit để chứa cờ tràn (carry)
    assign mant_sum = (sign_large == sign_small) ? 
                      (aligned_large + aligned_small) : 
                      (aligned_large - aligned_small);

    // Chuẩn hóa: Tìm vị trí bit 1 đầu tiên (Priority Encoder)
    reg [3:0] shift_left;
    always @(*) begin
        if (mant_sum[13]) shift_left = 4'd0;       // Có carry tràn
        else if (mant_sum[12]) shift_left = 4'd1;  // Mức bình thường (bit 1 ẩn)
        else if (mant_sum[11]) shift_left = 4'd2;
        else if (mant_sum[10]) shift_left = 4'd3;
        else if (mant_sum[9])  shift_left = 4'd4;
        else if (mant_sum[8])  shift_left = 4'd5;
        else if (mant_sum[7])  shift_left = 4'd6;
        else if (mant_sum[6])  shift_left = 4'd7;
        else if (mant_sum[5])  shift_left = 4'd8;
        else if (mant_sum[4])  shift_left = 4'd9;
        else if (mant_sum[3])  shift_left = 4'd10;
        else shift_left = 4'd11;
    end

    wire [13:0] normalized_mant = mant_sum << (shift_left ? (shift_left - 1) : 0);
    wire [4:0]  normalized_exp  = exp_large + 1 - shift_left;

    // Chuẩn hóa và Gán kết quả 
    always @(*) begin
        // Kiểm tra nếu 1 trong 2 số là 0
        if (a[14:0] == 15'd0) begin
            result = b;
        end else if (b[14:0] == 15'd0) begin
            result = a;
        end else if (mant_sum == 14'd0) begin
            // Trường hợp 2 số bằng nhau nhưng ngược dấu cộng lại bằng 0
            result = 16'd0;
        end else begin
            result[15] = sign_large;
            
            if (mant_sum[13]) begin
                // Có carry, dịch phải 1 bit
                result[14:10] = exp_large + 1'b1;
                result[9:0]   = mant_sum[12:3];
            end else begin
                // Gắn số mũ và lấy 10 bit mantissa (bỏ bit ẩn)
                result[14:10] = normalized_exp;
                result[9:0]   = normalized_mant[11:2];
            end
        end
    end

endmodule