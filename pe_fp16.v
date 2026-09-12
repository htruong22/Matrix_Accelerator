module pe_fp16 (
    input wire clk,
    input wire rst_n,
    input wire clr,            // [THÊM MỚI]: Tín hiệu xóa mềm từ FSM
    input wire en,
    input wire drain_en,       // Cờ cho phép xả dữ liệu C
    input wire [15:0] a_in,  
    input wire [15:0] b_in,  
    
    output reg [15:0] a_out,   // Vừa dùng truyền A (khi tính), vừa truyền C (khi xả)
    output reg [15:0] b_out  
);
    wire [15:0] mac_result;
    reg  [15:0] c_reg;         // Thanh ghi nội bộ giữ giá trị C tại chỗ

    fp16_mac mac_inst (
        .clk     (clk),         
        .val_a   (a_in),        
        .val_b   (b_in),        
        .acc_in  (c_reg),      // Nối giá trị C hiện tại vào bộ MAC
        .acc_out (mac_result)  // Lấy kết quả C mới 
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 16'd0;
            b_out <= 16'd0;
            c_reg <= 16'd0;
        end else if (clr) begin // [THÊM MỚI]: Xóa sạch kết quả cũ khi có lệnh START
            a_out <= 16'd0;
            b_out <= 16'd0;
            c_reg <= 16'd0;
        end else if (en) begin
            b_out <= b_in; // Luôn truyền B xuống dưới
            
            if (drain_en) begin
                // TRẠNG THÁI XẢ DỮ LIỆU (DRAIN)
                a_out <= c_reg; // Đẩy C của mình sang phải cho PE kế tiếp (hoặc ra ngoài)
                c_reg <= a_in;  // Nhận giá trị C của PE bên trái đẩy tới để nhịp sau truyền tiếp
            end else begin
                // TRẠNG THÁI TÍNH TOÁN BÌNH THƯỜNG
                a_out <= a_in;       // Truyền A sang phải
                c_reg <= mac_result; // Cộng dồn và giữ C đứng yên tại chỗ
            end
        end
    end
endmodule