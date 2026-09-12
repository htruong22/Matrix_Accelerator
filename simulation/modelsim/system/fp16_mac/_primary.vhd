library verilog;
use verilog.vl_types.all;
entity fp16_mac is
    port(
        clk             : in     vl_logic;
        val_a           : in     vl_logic_vector(15 downto 0);
        val_b           : in     vl_logic_vector(15 downto 0);
        acc_in          : in     vl_logic_vector(15 downto 0);
        acc_out         : out    vl_logic_vector(15 downto 0)
    );
end fp16_mac;
