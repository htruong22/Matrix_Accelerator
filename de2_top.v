module de2_top(
	input CLOCK_50,
	input [0:0] KEY
);

	system Nios_system(
		.clk_clk       (CLOCK_50),
		.reset_reset_n (KEY[0])
	);

endmodule