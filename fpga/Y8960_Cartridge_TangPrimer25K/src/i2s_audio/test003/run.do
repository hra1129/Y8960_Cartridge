onerror {quit -code 1}
onbreak {
    if {[examine -radix unsigned sim:/tb/test_passed] == 1} {quit -code 0}
    quit -code 1
}
run -all
quit -code 1
