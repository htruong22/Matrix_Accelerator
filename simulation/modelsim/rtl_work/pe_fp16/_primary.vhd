library verilog;
use verilog.vl_types.all;
entity pe_fp16 is
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        en              : in     vl_logic;
        drain_en        : in     vl_logic;
        a_in            : in     vl_logic_vector(15 downto 0);
        b_in            : in     vl_logic_vector(15 downto 0);
        a_out           : out    vl_logic_vector(15 downto 0);
        b_out           : out    vl_logic_vector(15 downto 0)
    );
end pe_fp16;
