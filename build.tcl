import_device eagle_s20.db -package BG256
read_verilog full.v -top hub75e
read_adc hub75e.adc
optimize_rtl
map_macro
map
pack
place
route
report_area -io_info -file hub75e_phy.area
bitgen -bit hub75e.bit -version 0X0000 -svf hub75e.svf -svf_comment_on -g ucode:00000000000000000000000000000000
