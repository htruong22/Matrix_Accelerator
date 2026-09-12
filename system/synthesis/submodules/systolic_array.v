module systolic_array #(parameter N = 4) (
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire [(N*16)-1:0] a_left_in,   // Dữ liệu ma trận A vào từ biên trái
    input wire [(N*16)-1:0] b_top_in,    // Dữ liệu ma trận B vào từ biên trên
    output wire [(N*N*16)-1:0] c_matrix_out // Mảng phẳng chứa kết quả ma trận C
);
    // Khai báo lưới dây dẫn kết nối giữa các PE theo 2 chiều X và Y
    wire [15:0] a_wire [0:N][0:N]; // Đường truyền ma trận A (trái sang phải)
    wire [15:0] b_wire [0:N][0:N]; // Đường truyền ma trận B (trên xuống dưới)

    // 1. Đổ dữ liệu từ cổng vào của module vào các đường biên của lưới dây
    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : edges
            assign a_wire[k][0] = a_left_in[(k*16) +: 16]; // Biên trái
            assign b_wire[0][k] = b_top_in[(k*16) +: 16];  // Biên trên
        end
    endgenerate

    // 2. Khởi tạo và kết nối ma trận các phần tử xử lý PE (Processing Element)
    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : row        // Duyệt theo hàng
            for (j = 0; j < N; j = j + 1) begin : col    // Duyệt theo cột
                
                pe_fp16 pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .en(en),
                    
                    // Lấy dữ liệu vào từ ô lưới hiện tại (i, j)
                    .a_in  (a_wire[i][j]),       // Nhận từ bên trái
                    .b_in  (b_wire[i][j]),       // Nhận từ phía trên
                    
                    // Đẩy dữ liệu ra cho các ô kế tiếp
                    .a_out (a_wire[i][j+1]),     // Truyền sang bên phải
                    .b_out (b_wire[i+1][j]),     // Truyền xuống bên dưới
                    
                    // Xuất trực tiếp kết quả tích lũy của PE ra mảng C_flat
                    .c_out (c_matrix_out[ ((i*N + j)*16) +: 16 ]) 
                );
                
            end
        end
    endgenerate
endmodule