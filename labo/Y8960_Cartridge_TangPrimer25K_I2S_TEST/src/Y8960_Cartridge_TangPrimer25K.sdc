create_clock -name clk_28m -period 34.923892 [get_ports {clk_28m}]
create_clock -name clk_50m -period 20.000000 [get_ports {clk_50m}]

create_generated_clock -name clk_129m -source [get_ports {clk_28m}] -multiply_by 9 -divide_by 2 [get_pins {u_pll/clkout0}]
create_generated_clock -name clk_25m -source [get_ports {clk_50m}] -multiply_by 12288 -divide_by 25000 [get_pins {u_pll/clkout1}]
set_clock_groups -asynchronous -group [get_clocks {clk_28m}] -group [get_clocks {clk_129m}]
