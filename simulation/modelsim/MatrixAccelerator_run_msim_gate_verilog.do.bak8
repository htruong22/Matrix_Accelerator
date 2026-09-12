transcript on
if {[file exists gate_work]} {
	vdel -lib gate_work -all
}
vlib gate_work
vmap work gate_work

vlog -vlog01compat -work work +incdir+. {MatrixAccelerator.vo}

vlog -vlog01compat -work work +incdir+D:/ProjectSoC2/DoAnSoC_new {D:/ProjectSoC2/DoAnSoC_new/tb_systolic_3x3.v}

vsim -t 1ps +transport_int_delays +transport_path_delays -L cycloneii_ver -L gate_work -L work -voptargs="+acc"  tb_systolic_3x3

add wave *
view structure
view signals
run -all
