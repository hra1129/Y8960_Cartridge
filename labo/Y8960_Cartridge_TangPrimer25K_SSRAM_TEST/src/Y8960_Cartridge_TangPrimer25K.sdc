create_clock -name clk_28m -period 34.923892 [get_ports {clk_28m}]
create_clock -name clk_50m -period 20.000000 [get_ports {clk_50m}]

create_generated_clock -name clk_200m -source [get_ports {clk_28m}] -multiply_by 7 -divide_by 1 [get_pins {u_pll/clkout0}]
set_clock_groups -asynchronous -group [get_clocks {clk_28m}] -group [get_clocks {clk_200m}]
