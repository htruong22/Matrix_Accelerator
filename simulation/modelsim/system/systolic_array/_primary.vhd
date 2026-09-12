library verilog;
use verilog.vl_types.all;
entity systolic_array is
    generic(
        N               : integer := 4
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        en              : in     vl_logic;
        a_left_in       : in     vl_logic_vector;
        b_top_in        : in     vl_logic_vector;
        c_matrix_out    : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of N : constant is 1;
end systolic_array;
