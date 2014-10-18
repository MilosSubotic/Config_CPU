view wave
view structure
view signals

radix -unsigned

add wave *
add wave dut/*

if [batch_mode] {
} else {
	run 100ns
	wave zoom full 
}

#run -all
#run 100ns


