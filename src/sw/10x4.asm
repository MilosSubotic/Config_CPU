//
// @author Milos Subotic <milos.subotic.sm@gmail.com>
// @license MIT
//
// Multiply 4 with 10 by using sum and loop.
//

		ld_num %0=0   // i = 0;
		ld_num %1=1
		ld_num %2=4
		ld_num %3=0   // acc = 0;
		ld_num %4=10
loop_start:
		add %3=%3,%4    // acc += 10
		add %0=%0,%1    // i++
		sub %5=%0,%2    // i < 4
	(b)	jmp loop_start
		mov %leds=%3
infinite_loop:
		jmp infinite_loop
