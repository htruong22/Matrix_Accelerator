library verilog;
use verilog.vl_types.all;
entity skew_buffer is
    generic(
        N               : integer := 4
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        en              : in     vl_logic;
        a_in_flat       : in     vl_logic_vector;
        b_in_flat       : in     vl_logic_vector;
        a_out_flat      : out    vl_logic_vector;
        b_out_flat      : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of N : constant is 1;
end skew_buffer;
