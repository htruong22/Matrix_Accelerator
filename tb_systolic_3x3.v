`timescale 1ns / 1ps

module tb_systolic_3x3;

    localparam N = 3; 

    // --- CÁC TÍN HIỆU KẾT NỐI VỚI DUT ---
    reg         clk;
    reg         rst_n;
    reg  [13:0] avs_address;
    reg         avs_write;
    reg  [31:0] avs_writedata;
    reg         avs_read;
    wire [31:0] avs_readdata;

    integer i, j;
    reg [31:0] read_val;

    // --- KHỞI TẠO MODULE TOP ---
    matrix_accel_top_systolic_array dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .avs_address   (avs_address),
        .avs_write     (avs_write),
        .avs_writedata (avs_writedata),
        .avs_read      (avs_read),
        .avs_readdata  (avs_readdata)
    );

    // --- TẠO XUNG CLOCK 50MHz ---
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // --- CÁC TASK GIAO TIẾP AVALON-MM (Trễ 1 nhịp đồng bộ phần cứng thực tế) ---
    task avalon_write;
        input [13:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            avs_address   = addr;
            avs_writedata = data;
            avs_write     = 1;
            @(posedge clk);
            avs_write     = 0;
        end
    endtask

		task avalon_read;
        input  [13:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            avs_address = addr;
            avs_read    = 1;
            
            @(posedge clk);     // Sườn clock này phần cứng nhận địa chỉ và bắt đầu đổi dữ liệu
            @(negedge clk);     // CHỜ 10NS: Đợi dữ liệu qua các cổng logic Gate-level và ổn định 
            data        = avs_readdata; // Lúc này lấy dữ liệu 
            
            avs_read    = 0;
        end
    endtask

    // --- HÀM GIẢI MÃ FP16 SANG SỐ THỰC ---
    function real fp16_to_real;
        input [15:0] fp16_val;
        reg sign;
        reg [4:0] exp;
        reg [9:0] frac;
        real mantissa_real;
        real final_val;
        integer exp_int;
        begin
            sign = fp16_val[15];
            exp  = fp16_val[14:10];
            frac = fp16_val[9:0];

            if (exp == 5'h00) begin
                if (frac == 10'h000) begin
                    final_val = 0.0;
                end else begin
                    final_val = (frac / 1024.0) * (2.0 ** -14.0);
                end
            end else if (exp == 5'h1F) begin
                final_val = 99999.0; 
            end else begin
                mantissa_real = 1.0 + (frac / 1024.0);
                exp_int = exp - 15;
                final_val = mantissa_real * (2.0 ** exp_int);
            end

            if (sign) fp16_to_real = -final_val;
            else      fp16_to_real = final_val;
        end
    endfunction

    // --- KỊCH BẢN MÔ PHỎNG CHÍNH ---
    initial begin
        // 1. Reset hệ thống
        rst_n = 0; avs_write = 0; avs_read = 0; avs_address = 0; avs_writedata = 0;
        #100; rst_n = 1; #40;
        
        $display("=========================================================");
        $display("      BAT DAU TEST SYSTOLIC ARRAY MATRIX 3x3");
        $display("=========================================================");

        // 2. Nạp Ma trận A (Hàng 0: 1,3,2 | Hàng 1: 2,1,3 | Hàng 2: 3,2,1)
        $display("[1] Dang nap Ma tran A...");
        avalon_write(14'h400 + 0, 32'h3C00); // A[0][0] = 1.0
        avalon_write(14'h400 + 1, 32'h4200); // A[0][1] = 3.0
        avalon_write(14'h400 + 2, 32'h4000); // A[0][2] = 2.0
        
        avalon_write(14'h400 + 3, 32'h4000); // A[1][0] = 2.0
        avalon_write(14'h400 + 4, 32'h3C00); // A[1][1] = 1.0
        avalon_write(14'h400 + 5, 32'h4200); // A[1][2] = 3.0
        
        avalon_write(14'h400 + 6, 32'h4200); // A[2][0] = 3.0
        avalon_write(14'h400 + 7, 32'h4000); // A[2][1] = 2.0
        avalon_write(14'h400 + 8, 32'h3C00); // A[2][2] = 1.0

        // 3. Nạp Ma trận B (Hàng 0: 3,2,1 | Hàng 1: 1,3,2 | Hàng 2: 2,1,3)
        $display("[2] Dang nap Ma tran B...");
        avalon_write(14'h800 + 0, 32'h4200); // B[0][0] = 3.0
        avalon_write(14'h800 + 1, 32'h4000); // B[0][1] = 2.0
        avalon_write(14'h800 + 2, 32'h3C00); // B[0][2] = 1.0
        
        avalon_write(14'h800 + 3, 32'h3C00); // B[1][0] = 1.0
        avalon_write(14'h800 + 4, 32'h4200); // B[1][1] = 3.0
        avalon_write(14'h800 + 5, 32'h4000); // B[1][2] = 2.0
        
        avalon_write(14'h800 + 6, 32'h4000); // B[2][0] = 2.0
        avalon_write(14'h800 + 7, 32'h3C00); // B[2][1] = 1.0
        avalon_write(14'h800 + 8, 32'h4200); // B[2][2] = 3.0

        // 4. Kích hoạt lệnh tính toán
        $display("[3] Phat lenh START, kich hoat 9 PEs...");
        avalon_write(14'h00, 32'h00000001);

        // 5. Polling chờ Hardware xử lý xong
        $display("[4] Dang doi FSM hoan thanh Pipeline...");
        read_val = 0;
        while ((read_val & 32'h02) == 0) begin
            avalon_read(14'h00, read_val);
            #20;
        end
        $display("    -> Da nhan co DONE tu Hardware!");

        // Đợi thêm 5 chu kỳ để dữ liệu phân phối toàn vẹn trên mạch logic Gate-level
        repeat (5) @(posedge clk); 

        // 6. Đọc và hiển thị kết quả Ma trận C ổn định
        $display("\n=========================================================");
        $display("          KET QUA MA TRAN C ");
        $display("     (Ky vong: Cheo chinh la 10.00, Cac o khac la 13.00)");
        $display("=========================================================\n");
        
        for (i = 0; i < N; i = i + 1) begin
            $write("Row %2d:  ", i);
            for (j = 0; j < N; j = j + 1) begin
                avalon_read(14'hC00 + (i * N) + j, read_val); 
                $write("%8.2f (Hex: 0x%h) | ", fp16_to_real(read_val[15:0]), read_val[15:0]);
            end
            $display(""); 
        end
        $display("\n=========================================================");

        repeat (10) @(posedge clk);
        $finish;
    end

endmodule