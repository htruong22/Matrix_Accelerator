`timescale 1ns / 1ps

// ko chay duoc gate level simulation do ko ghi de duoc .N(16)
module tb_systolic_16x16;

    // --- CÁC TÍN HIỆU KẾT NỐI VỚI DUT ---
    reg         clk;
    reg         rst_n;
    reg  [13:0] avs_address;
    reg         avs_write;
    reg  [31:0] avs_writedata;
    reg         avs_read;
    wire [31:0] avs_readdata;

    // Biến dùng trong vòng lặp
    integer i, j;
    reg [31:0] read_val;

    // --- KHỞI TẠO MODULE TOP (Kích thước N = 16) ---
    matrix_accel_top_systolic_array #( .N(16) ) dut (
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

    // --- CÁC TASK GIAO TIẾP AVALON-MM (Giả lập Nios II) ---
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
            @(posedge clk);
            #1; 
            data        = avs_readdata;
            avs_read    = 0;
        end
    endtask

    // --- HÀM GIẢI MÃ FP16 SANG SỐ THỰC (DECIMAL) ---
    function real fp16_to_real;
        input [15:0] fp16_val;
        reg sign;
        reg [4:0] exp;
        reg [9:0] frac;
        real mantissa_real;
        real exp_real;
        real final_val;
        begin
            sign = fp16_val[15];
            exp  = fp16_val[14:10];
            frac = fp16_val[9:0];

            if (exp == 5'h00) begin
                if (frac == 10'h000) 
                    final_val = 0.0;
                else 
                    final_val = (frac / 1024.0) * (2.0 ** -14.0);
            end else if (exp == 5'h1F) begin
                final_val = 99999.0; // Đại diện cho Infinity / NaN
            end else begin
                mantissa_real = 1.0 + (frac / 1024.0);
                if (exp >= 15) exp_real = exp - 15;
                else           exp_real = -(15 - exp);
                
                final_val = mantissa_real * (2.0 ** exp_real);
            end

            if (sign) fp16_to_real = -final_val;
            else      fp16_to_real = final_val;
        end
    endfunction

    // --- KỊCH BẢN MÔ PHỎNG CHÍNH ---
    initial begin
        // 1. Reset hệ thống
        rst_n = 0;
        avs_write = 0;
        avs_read = 0;
        #50;
        rst_n = 1;
        #20;
        
        $display("==================================================");
        $display("   BAT DAU TEST SYSTOLIC ARRAY MATRIX 16x16");
        $display("==================================================");

        // 2. Nạp ma trận A (Ví dụ: Số 1.5 -> Mã Hex: 0x3E00)
        $display("[1] Dang nap Ma tran A (Toan so 1.5)...");
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                avalon_write(14'h400 + (i * 16) + j, 32'h3E00);
            end
        end

        // 3. Nạp ma trận B (Ví dụ: Số 2.0 -> Mã Hex: 0x4000)
        $display("[2] Dang nap Ma tran B (Toan so 2.0)...");
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                avalon_write(14'h800 + (i * 16) + j, 32'h4000);
            end
        end

        // 4. Kích hoạt mảng Systolic
        $display("[3] Phat lenh START, kich hoat 256 PEs...");
        avalon_write(14'h00, 32'h00000001);

        // 5. Polling chờ Hardware xử lý xong
        $display("[4] Dang doi FSM chay xong Pipeline...");
        read_val = 0;
        while ((read_val & 32'h02) == 0) begin
            avalon_read(14'h00, read_val);
        end
        $display("    -> Da nhan co DONE tu Hardware!");

        // 6. In kết quả trực quan dạng thập phân
        // Kỳ vọng: 1.5 * 2.0 * 16 = 48.00
        $display("\n=====================================================================================================================================");
        $display("                                   KET QUA MA TRAN C NHAN DUOC (Ky vong: Toan so 48.00)");
        $display("=====================================================================================================================================\n");
        
        for (i = 0; i < 16; i = i + 1) begin
            $write("Row %2d:  ", i);
            for (j = 0; j < 16; j = j + 1) begin
                // Đọc phần tử C[i][j] tại offset 0xC00
                avalon_read(14'hC00 + (i * 16) + j, read_val); 
                // In ra giá trị
                $write("%8.2f ", fp16_to_real(read_val[15:0]));
            end
            $display(""); 
        end
        
        $display("\n=====================================================================================================================================");

        #100;
        $finish;
    end

endmodule