module systolic_array #(parameter N = 4) (
    input wire clk,
    input wire rst_n,
    input wire clr,                      // [THÊM MỚI]: Nhận cờ xóa mềm từ Top
    input wire en,
    input wire drain_en,                 
    input wire [(N*16)-1:0] a_left_in,   
    input wire [(N*16)-1:0] b_top_in,    
    output wire [(N*16)-1:0] c_right_out 
);
    // Khai báo lưới dây dẫn kết nối giữa các PE (Kích thước [0:N] để chứa cả dây ngõ ra cuối)
    wire [15:0] a_wire [0:N][0:N]; 
    wire [15:0] b_wire [0:N][0:N]; 

    // 1. Đổ dữ liệu từ cổng vào của module vào các đường biên của lưới dây
    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : edges
            assign a_wire[k][0] = a_left_in[(k*16) +: 16]; 
            assign b_wire[0][k] = b_top_in[(k*16) +: 16];  
        end
    endgenerate

    // 2. Khởi tạo và kết nối ma trận các phần tử xử lý PE
    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : row        
            for (j = 0; j < N; j = j + 1) begin : col    
                
                pe_fp16 pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clr(clr),           // [THÊM MỚI]: Nối cờ xóa mềm vào PE
                    .en(en),
                    .drain_en(drain_en), 
                    
                    // Lấy dữ liệu vào
                    .a_in  (a_wire[i][j]),    
                    .b_in  (b_wire[i][j]),    
                    
                    // Đẩy dữ liệu ra 
                    .a_out (a_wire[i][j+1]),  
                    .b_out (b_wire[i+1][j])   
                );
                
            end
        end
    endgenerate

    // 3. Trích xuất ma trận C từ cột ngoài cùng bên phải
    generate
        for (k = 0; k < N; k = k + 1) begin : out_assign
            // Lấy dữ liệu từ a_wire của cột cuối cùng (cột thứ N)
            // Vì khi drain_en = 1, cổng a_out của PE sẽ nhả giá trị C ra đường dây này
            assign c_right_out[(k*16) +: 16] = a_wire[k][N];
        end
    endgenerate

endmodule