`timescale 1ns / 1ps

module fp16_mult (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [15:0] result
);

    // Các thành phần của A và B
    wire sign_a = a[15];
    wire sign_b = b[15];
    wire [4:0] exp_a = a[14:10];
    wire [4:0] exp_b = b[14:10];
    
    // Thêm bit 1 ẩn (implicit 1) vào trước mantissa nếu số mũ khác 0
    wire [10:0] mant_a = (|exp_a) ? {1'b1, a[9:0]} : 11'd0;
    wire [10:0] mant_b = (|exp_b) ? {1'b1, b[9:0]} : 11'd0;

    // Các biến trung gian cho phép tính
    wire sign_res;
    wire [5:0] exp_sum; // 6 bit để chống tràn
    wire [21:0] mant_mult; // 11 bit * 11 bit = 22 bit
    
    // Tính toán tổ hợp (Combinational)
    assign sign_res  = sign_a ^ sign_b;
    assign exp_sum   = exp_a + exp_b - 5'd15; // Trừ đi Bias
    assign mant_mult = mant_a * mant_b;

    // Chuẩn hóa (Dùng block always tổ hợp)
    always @(*) begin
        // Xử lý trường hợp nhân với 0
        if (a[14:0] == 15'd0 || b[14:0] == 15'd0) begin
            result = 16'd0;
        end else begin
            // Chuẩn hóa (Normalization)
            if (mant_mult[21]) begin 
                // Có tràn bit 1 lên vị trí cao nhất (1x.xxxx...) -> Dịch phải
                result[15]    = sign_res;
                result[14:10] = exp_sum[4:0] + 1'b1;
                result[9:0]   = mant_mult[20:11]; 
            end else begin
                // Không tràn (01.xxxx...) -> Giữ nguyên
                result[15]    = sign_res;
                result[14:10] = exp_sum[4:0];
                result[9:0]   = mant_mult[19:10];
            end
        end
    end

endmodule