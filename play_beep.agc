.equ ADDR_AUDIODACFIFO, 0xFF203040

.global play_beep

play_beep:
	subi sp,sp,4*5
	stwio r2, 0(sp)
	stwio r4, 4(sp)
	stwio r5, 8(sp)
	stwio r9, 12(sp)
	stwio r10, 16(sp)
	
	movia r2, ADDR_AUDIODACFIFO
	movi r9,0							#initialize coounter
	movia r10, 90000					#set exit point for counter (90000 works on the our lab computers)

	#square wave's positive pulse
	initial1:
	movia r4, 99999999					#set the amplitude of the wave
	movia r5, 0x15						#set the frequency of the wave - 15 works
	loop1:
	stwio r4, 8(r2)
	stwio r4, 12(r2)
	subi r5, r5, 1
	addi r9,r9,1
	beq r5, r0, initial2				#if frequency is zero, go to negative pulse
	beq r9,r10,exit_play_beep						#if main counter is zero, exit the loop - plays only one beep
	br loop1


	#square wave's negative pulse
	initial2:
	movia r4, -99999999					#set negative amplitude
	movia r5, 0x15						#set frequency
	loop2:		
	stwio r4, 8(r2)						
	stwio r4, 12(r2)
	subi r5, r5, 1
	addi r9,r9,1
	beq r9,r10,exit_play_beep						#if frequency is zero, go to positive pulse
	beq r5, r0, initial1				#if main counter is zero, exit the loop - plays only one beep
	br loop2

	exit_play_beep:
		ldwio r2, 0(sp)
		ldwio r4, 4(sp)
		ldwio r5, 8(sp)
		ldwio r9, 12(sp)
		ldwio r10, 16(sp)
		addi sp,sp,4*5
		ret
