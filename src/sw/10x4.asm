
// Multiply 4 with 10 by using sum and loop.
		ld_const %0=0   // i = 0;
		ld_const %1=1
		ld_const %2=4
		ld_const %3=0   // acc = 0;
		ld_const %4=10
loop_start:
		add %3=%3,%4    // acc += 10
		add %0=%0,%1    // i++
		sub %5=%0,%2    // i < 4
	(b)	jmp loop_start
		mov %15=%3
infinite_loop:
		jmp infinite_loop

