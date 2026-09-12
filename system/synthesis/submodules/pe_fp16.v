module pe_fp16 (
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire [15:0] a_in,    
    input wire [15:0] b_in,    
    
    output reg [15:0] a_out,   
    output reg [15:0] b_out,   
    output reg [15:0] c_out    // Kết quả nằm tại chỗ (Stationary)
);
    wire [15:0] mac_result;

    fp16_mac mac_inst (
        .clk     (clk),         // Nối xung clock
        .val_a   (a_in),        // Nối dữ liệu a
        .val_b   (b_in),        // Nối dữ liệu b
        .acc_in  (c_out),       // Nối giá trị C hiện tại để cộng dồn
        .acc_out (mac_result)   // Lấy kết quả C mới xuất ra
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 16'd0;
            b_out <= 16'd0;
            c_out <= 16'd0;
        end else if (en) begin
            a_out <= a_in;       // Truyền tay sang phải
            b_out <= b_in;       // Truyền tay xuống dưới
            c_out <= mac_result; // Cập nhật kết quả tích lũy
        end
    end
endmodule