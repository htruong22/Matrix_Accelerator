transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+D:/ProjectSoC2/DoAnSoC_new {D:/ProjectSoC2/DoAnSoC_new/matrix_accel_top_systolic_array.v}
vlog -vlog01compat -work work +incdir+D:/ProjectSoC2/DoAnSoC_new {D:/ProjectSoC2/DoAnSoC_new/fp16_mac.v}
vlog -vlog01compat -work work +incdir+D:/ProjectSoC2/DoAnSoC_new {D:/ProjectSoC2/DoAnSoC_new/fp16_mult.v}
vlog -vlog01compat -work work +incdir+D:/ProjectSoC2/DoAnSoC_new {D:/ProjectSoC2/DoAnSoC_new/fp16_add.v}
vlog -vlog01compat -work work +incdir+D:/ProjectSoC2/DoAnSoC_new {D:/ProjectSoC2/DoAnSoC_new/pe_fp16.v}
vlog -vlog01compat -work work +incdir+D:/ProjectSoC2/DoAnSoC_new {D:/ProjectSoC2/DoAnSoC_new/skew_buffer.v}
vlog -vlog01compat -work work +incdir+D:/ProjectSoC2/DoAnSoC_new {D:/ProjectSoC2/DoAnSoC_new/systolic_array.v}

vlog -vlog01compat -work work +incdir+D:/ProjectSoC2/DoAnSoC_new {D:/ProjectSoC2/DoAnSoC_new/tb_systolic_16x16.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneii_ver -L rtl_work -L work -voptargs="+acc"  tb_systolic_16x16

add wave *
view structure
view signals
run -all
