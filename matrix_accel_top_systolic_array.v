`timescale 1ns / 1ps

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
    output wire [31:0] avs_readdata   
);

    // --- KHÔNG GIAN BỘ NHỚ CỤC BỘ ---
    reg [15:0] mem_A [0:(N*N)-1];
    reg [15:0] mem_B [0:(N*N)-1];
    reg [15:0] mem_C [0:(N*N)-1];   

    // --- THANH GHI ĐIỀU KHIỂN & TRẠNG THÁI ---
    reg ctrl_start;
    reg ctrl_done;
    
    // --- FSM ĐẾM NHỊP ---
    reg [7:0] cycle_cnt;
    reg state_calc;
    reg state_drain;                

    // --- LUỒNG DỮ LIỆU NỘI BỘ ---
    wire [(N*16)-1:0] a_col_feed;
    wire [(N*16)-1:0] b_row_feed;
    wire [(N*16)-1:0] a_skewed;
    wire [(N*16)-1:0] b_skewed;
    wire [(N*16)-1:0] c_sys_out;    

    // --- TÍN HIỆU CLEAR MỀM CHO MẢNG PE ---
    wire clr_pe_sig; // [THÊM MỚI]

    // --- THANH GHI CHỐT DỮ LIỆU NGÕ RA AVALON-MM (REGISTERED READ) ---
    reg [31:0] avs_readdata_reg;
    assign avs_readdata = avs_readdata_reg;

    // --- BIẾN TOÀN CỤC SỬ DỤNG TRONG VÒNG LẶP LOOP (FIX LỖI CÚ PHÁP QUARTUS) ---
    integer m;
    integer k;

    // =======================================================
    // 0. TẠO TÍN HIỆU CLEAR TỪ LỆNH AVALON-MM CỦA CPU
    // =======================================================
    // [THÊM MỚI]: Bắn 1 xung clear ngay tại thời điểm CPU ghi START = 1
    assign clr_pe_sig = (avs_write && (avs_address == 14'h00) && avs_writedata[0]);

    // =======================================================
    // 1. LOGIC ĐẨY DỮ LIỆU VÀO SKEW BUFFER THEO NHỊP CLOCK
    // =======================================================
    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : feeder
            // Cột thứ cycle_cnt của ma trận A
            assign a_col_feed[(g*16) +: 16] = (state_calc && cycle_cnt < N) ? mem_A[g * N + cycle_cnt] : 16'd0;
            // Hàng thứ cycle_cnt của ma trận B
            assign b_row_feed[(g*16) +: 16] = (state_calc && cycle_cnt < N) ? mem_B[cycle_cnt * N + g] : 16'd0;
        end
    endgenerate

    // =======================================================
    // 2. KHỞI TẠO SKEW BUFFER
    // =======================================================
    skew_buffer #(.N(N)) skew_inst (
        .clk(clk), .rst_n(rst_n), .en(state_calc),
        .a_in_flat(a_col_feed), .b_in_flat(b_row_feed),
        .a_out_flat(a_skewed), .b_out_flat(b_skewed)
    );

    // =======================================================
    // 3. KHỞI TẠO SYSTOLIC ARRAY
    // =======================================================
    systolic_array #(.N(N)) sys_arr_inst (
        .clk(clk), 
        .rst_n(rst_n), 
        .clr(clr_pe_sig),               // [THÊM MỚI]: Đưa dây clear vào mảng PE
        .en(state_calc | state_drain),  
        .drain_en(state_drain),         
        .a_left_in(a_skewed), 
        .b_top_in(b_skewed),
        .c_right_out(c_sys_out)         
    );

    // =======================================================
    // 4. MÁY TRẠNG THÁI (FSM): TÍNH TOÁN -> XẢ KẾT QUẢ -> DONE
    // =======================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_calc  <= 1'b0;
            state_drain <= 1'b0;
            cycle_cnt   <= 8'd0;
            ctrl_done   <= 1'b0;
            ctrl_start  <= 1'b0;
            for (m = 0; m < N*N; m = m + 1) begin
                mem_C[m] <= 16'd0;
            end
        end else begin
            // Bắt cờ Start từ Avalon-MM
            if (avs_write && avs_address == 14'h00) begin
                ctrl_start <= avs_writedata[0];
                if (avs_writedata[0]) begin
                    state_calc  <= 1'b1;
                    state_drain <= 1'b0;
                    cycle_cnt   <= 8'd0;
                    ctrl_done   <= 1'b0;
                end
            end
            
            // PHA 1: Chạy Pipeline Tính toán
            if (state_calc) begin
                cycle_cnt <= cycle_cnt + 1;
                if (cycle_cnt == (3 * N + 2)) begin 
                    state_calc  <= 1'b0;
                    state_drain <= 1'b1; 
                    cycle_cnt   <= 8'd0;
                end
            end

            // PHA 2: Xả dữ liệu chuẩn hóa Pipeline (Fix lỗi rỗng và lệch cột)
            if (state_drain) begin
                cycle_cnt <= cycle_cnt + 1;
                
                // Trích xuất tại các chu kỳ lẻ: 1, 3, 5 do dữ liệu trễ 2 nhịp/PE
                if (cycle_cnt[0] == 1'b1 && cycle_cnt < (2 * N)) begin
                    for (m = 0; m < N; m = m + 1) begin
                        mem_C[m * N + (N - 1 - (cycle_cnt >> 1))] <= c_sys_out[m*16 +: 16];
                    end
                end

                // Chờ đủ 2*N chu kỳ (6 chu kỳ với ma trận 3x3) để xả sạch lưới PE
                if (cycle_cnt == (2 * N)) begin
                    state_drain <= 1'b0;
                    ctrl_done   <= 1'b1; 
                    ctrl_start  <= 1'b0;
                end
            end
        end
    end

    // =======================================================
    // 5. GIAO TIẾP GHI/ĐỌC AVALON-MM CHO CPU (NIOS II)
    // =======================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            avs_readdata_reg <= 32'd0;
            for (k = 0; k < N*N; k = k + 1) begin
                mem_A[k] <= 16'd0;
                mem_B[k] <= 16'd0;
            end
        end else begin
            // Logic GHI (Write) vào RAM cục bộ A và B
            if (avs_write) begin
                if (avs_address >= 14'h400 && avs_address < (14'h400 + N*N))
                    mem_A[avs_address - 14'h400] <= avs_writedata[15:0];
                else if (avs_address >= 14'h800 && avs_address < (14'h800 + N*N))
                    mem_B[avs_address - 14'h800] <= avs_writedata[15:0];
            end
            
            // Logic ĐỌC (Read) thanh ghi trạng thái hoặc RAM cục bộ C
            if (avs_read) begin
                if (avs_address == 14'h00) begin
                    avs_readdata_reg <= {30'd0, ctrl_done, ctrl_start};
                end else if (avs_address >= 14'hC00 && avs_address < (14'hC00 + N*N)) begin
                    avs_readdata_reg <= {16'd0, mem_C[avs_address - 14'hC00]};
                end else begin
                    avs_readdata_reg <= 32'd0;
                end
            end
        end
    end

endmodule