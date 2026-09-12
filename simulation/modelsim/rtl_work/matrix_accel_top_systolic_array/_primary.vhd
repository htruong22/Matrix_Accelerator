library verilog;
use verilog.vl_types.all;
entity matrix_accel_top_systolic_array is
    generic(
        N               : integer := 3
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        avs_address     : in     vl_logic_vector(13 downto 0);
        avs_write       : in     vl_logic;
        avs_writedata   : in     vl_logic_vector(31 downto 0);
        avs_read        : in     vl_logic;
        avs_readdata    : out    vl_logic_vector(31 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of N : constant is 1;
end matrix_accel_top_systolic_array;
