module skew_buffer #(parameter N = 4) (
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire [(N*16)-1:0] a_in_flat,
    input wire [(N*16)-1:0] b_in_flat,
    output wire [(N*16)-1:0] a_out_flat,
    output wire [(N*16)-1:0] b_out_flat
);
    genvar i;
    generate
        // Làm trễ ma trận A theo hàng
        for (i = 0; i < N; i = i + 1) begin : skew_a
            if (i == 0) begin
                assign a_out_flat[15:0] = a_in_flat[15:0];
            end else begin
                reg [15:0] delay_a [0:i-1];
                integer k;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for(k = 0; k < i; k = k + 1) delay_a[k] <= 16'd0;
                    end else if (en) begin
                        delay_a[0] <= a_in_flat[(i*16)+15 : i*16];
                        for(k = 1; k < i; k = k + 1) delay_a[k] <= delay_a[k-1];
                    end
                end
                assign a_out_flat[(i*16)+15 : i*16] = delay_a[i-1];
            end
        end

        // Làm trễ ma trận B theo cột
        for (i = 0; i < N; i = i + 1) begin : skew_b
            if (i == 0) begin
                assign b_out_flat[15:0] = b_in_flat[15:0];
            end else begin
                reg [15:0] delay_b [0:i-1];
                integer k;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for(k = 0; k < i; k = k + 1) delay_b[k] <= 16'd0;
                    end else if (en) begin
                        delay_b[0] <= b_in_flat[(i*16)+15 : i*16];
                        for(k = 1; k < i; k = k + 1) delay_b[k] <= delay_b[k-1];
                    end
                end
                assign b_out_flat[(i*16)+15 : i*16] = delay_b[i-1];
            end
        end
    endgenerate
endmodule