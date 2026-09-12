module matrix_accel_top_systolic_array #(
    parameter N = 3
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Avalon-MM Slave Interface
    input  wire [13:0] avs_address,   // Word offset address
    input  wire        avs_write,
    input  wire [31:0] avs_writedata,
    input  wire        avs_read,
    output wire [31:0] avs_readdata   // Chuyển thành dây wire nối từ thanh ghi nội bộ
);

    // Không gian bộ nhớ cục bộ
    reg [15:0] mem_A [0:(N*N)-1];
    reg [15:0] mem_B [0:(N*N)-1];
    wire [(N*N*16)-1:0] mem_C_flat; // Kết quả nối thẳng từ lưới PE

    // Thanh ghi điều khiển
    reg ctrl_start;
    reg ctrl_done;
    
    // FSM đếm nhịp
    reg [7:0] cycle_cnt;
    reg state_calc;

    // Luồng dữ liệu nội bộ
    wire [(N*16)-1:0] a_col_feed;
    wire [(N*16)-1:0] b_row_feed;
    wire [(N*16)-1:0] a_skewed;
    wire [(N*16)-1:0] b_skewed;

    // Thanh ghi chốt dữ liệu ngõ ra Avalon-MM (Registered Read)
    reg [31:0] avs_readdata_reg;
    assign avs_readdata = avs_readdata_reg;

    // 1. Logic đẩy dữ liệu vào Skew Buffer theo nhịp clock
    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : feeder
            // Cột thứ cycle_cnt của ma trận A
            assign a_col_feed[(g*16) +: 16] = (state_calc && cycle_cnt < N) ? mem_A[g * N + cycle_cnt] : 16'd0;
            // Hàng thứ cycle_cnt của ma trận B
            assign b_row_feed[(g*16) +: 16] = (state_calc && cycle_cnt < N) ? mem_B[cycle_cnt * N + g] : 16'd0;
        end
    endgenerate

    // 2. Khởi tạo Skew Buffer
    skew_buffer #(.N(N)) skew_inst (
        .clk(clk), .rst_n(rst_n), .en(state_calc),
        .a_in_flat(a_col_feed), .b_in_flat(b_row_feed),
        .a_out_flat(a_skewed), .b_out_flat(b_skewed)
    );

    // 3. Khởi tạo Systolic Array
    systolic_array #(.N(N)) sys_arr_inst (
        .clk(clk), .rst_n(rst_n), .en(state_calc),
        .a_left_in(a_skewed), .b_top_in(b_skewed),
        .c_matrix_out(mem_C_flat)
    );

    // 4. Máy trạng thái (FSM) đếm nhịp Pipeline
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_calc <= 1'b0;
            cycle_cnt <= 8'd0;
            ctrl_done <= 1'b0;
            ctrl_start <= 1'b0;
        end else begin
            // Bắt cờ Start từ Avalon-MM
            if (avs_write && avs_address == 14'h00) begin
                ctrl_start <= avs_writedata[0];
                if (avs_writedata[0]) begin
                    state_calc <= 1'b1;
                    cycle_cnt <= 8'd0;
                    ctrl_done <= 1'b0;
                end
            end
            
            // Chạy Pipeline
            if (state_calc) begin
                cycle_cnt <= cycle_cnt + 1;
                if (cycle_cnt == (3 * N + 2)) begin
                    state_calc <= 1'b0;
                    ctrl_done <= 1'b1; // Báo DONE cho CPU
                    ctrl_start <= 1'b0;
                end
            end
        end
    end

    // 5. Giao tiếp ghi/đọc Avalon-MM cho Nios II (cấu trúc Đồng bộ/Thanh ghi)
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Khởi tạo và reset sạch bộ nhớ tránh rác Gate-level
            avs_readdata_reg <= 32'd0;
            for (k = 0; k < N*N; k = k + 1) begin
                mem_A[k] <= 16'd0;
                mem_B[k] <= 16'd0;
            end
        end else begin
            // Logic GHI (Write)
            if (avs_write) begin
                if (avs_address >= 14'h400 && avs_address < (14'h400 + N*N))
                    mem_A[avs_address - 14'h400] <= avs_writedata[15:0];
                else if (avs_address >= 14'h800 && avs_address < (14'h800 + N*N))
                    mem_B[avs_address - 14'h800] <= avs_writedata[15:0];
            end
            
            // Logic ĐỌC (Read)
            if (avs_read) begin
                if (avs_address == 14'h00) begin
                    avs_readdata_reg <= {30'd0, ctrl_done, ctrl_start};
                end else if (avs_address >= 14'hC00 && avs_address < (14'hC00 + N*N)) begin
                    avs_readdata_reg <= {16'd0, mem_C_flat[ ((avs_address - 14'hC00)*16) +: 16 ]};
                end else begin
                    avs_readdata_reg <= 32'd0;
                end
            end
        end
    end

endmodule