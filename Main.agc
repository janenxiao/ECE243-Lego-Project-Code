# ECE243-Project-Code

# r14: push_buttons/switches address
# r12: previous switch values
# r17: current position of our lego car
# r18: initialized to 1, if xylophone is drawn once (user has pressed a key), set to 0 to not draw xylophone again

.equ PUSHBUTTONS, 0xFF200050
.equ SWITCHES, 0xFF200040
.equ ADDR_JP1, 0xFF200060		#address GPIO JP1
.equ PS_2, 0xFF200100   		#address for the PS_2 keyboard

.global	startscreen_line1
.global	startscreen_line2
.global	_start

.data
song1:	# first hword is number of steps to go, next is direction (right is 1, left is -1, forward or backward determined in subroutine "move_steps")
	.hword 2, 1  	# 3
	.hword 1, -1	# 2
	.hword 1, -1	# 1
	.hword 1, 1		# 2
	.hword 1, 1		# 3
	.hword 0, 1		# 3
	.hword 0, 1		# 3
	.hword 1, -1	# 2
	.hword 0, 1		# 2
	.hword 0, 1		# 2
	.hword 1, 1		# 3
	.hword 2, 1		# 5
	.hword 0, 1		# 5
	.word 0
	
keys_makecode:
	.hword 0x16, 0  #1
	.hword 0x1E, 1	#2
	.hword 0x26, 2	#3
	.hword 0x25, 3	#4
	.hword 0x2E, 4	#5
	.hword 0x36, 5	#6
	.hword 0x3D, 6	#7
	.hword 0x3E, 7	#8
	.word 0
	
startscreen_line1:
	.byte 0x58,0x59,0x4C,0x4F,0x50,0x48,0x4F,0x4E,0x45	 # "XYLOPHONE"
	.word 0
	
startscreen_line2:
	.byte 0x50,0x72,0x65,0x73,0x73,0x20		# "Press "
	.byte 0x6E,0x75,0x6D,0x62,0x65,0x72,0x73,0x20,0x6F,0x6E,0x20,0x6B,0x65,0x79,0x62,0x6F,0x61,0x72,0x64,0x20,0x6F,0x72,0x20	# "numbers on keyboard or "
	.byte 0x4B,0x45,0x59,0x30,0x20,0x74,0x6F,0x20,0x73,0x74,0x61,0x72,0x74 		# "KEY0 to start"
	.word 0
	
# Interrupt rountine
# only r4,r8,r10 used in ISR
.section .exceptions, "ax"	
	subi sp,sp, 4*5
	#save the registers used 
	stwio ra,0(sp)
	stwio r4,4(sp)
	stwio r8,8(sp)
	stwio r10,12(sp)
	stwio r11,16(sp)
	rdctl et,ctl1
	
	movia r8,PUSHBUTTONS
	movia r4,0x8	# Clear edge capture register to acknowledge this interrupt (write 1 to clear)
	stwio r4,12(r8) 
	
	movia r8,ADDR_JP1
	#ldwio r4,0(r8)
	movia r10, 0xFFFFFBFC	#enable sensor 0 and motor 0 (set direction backward) and disable all other sensors (coz u can only get data from one sensor at a time)
	#and r4,r4,r10
	stwio r10, 0(r8)
	
	movia r11, 2000000		# counter for play_beep
	
	#poll the touch sensor (sensor 0) until it's pressed
	loop_touch_sensor:
		ldwio r10,0(r8)
		srli r4,r10,11			#11 bit is valid for sensor 0
		andi r4,r4,1			#extract the valid bit
		bne r0,r4,loop_touch_sensor		#wait for valid bit to be low
		# if sensor data valid
		srli r10,r10,27			#shift to the right by 27 so that the 4-bit sensor value can be extracted
		andi r10,r10,0xF		#r10 now has the value of the touch sensor
	
	movi r4,0xF		# if touch sensor value is still 0xF, keep polling
	bne r10,r4,STOP_ISR
		# call play_beep if counter reaches 10000000
		subi r11,r11,1
		bne r11,r0,loop_touch_sensor
		call play_beep
		movia r11, 2000000
	br loop_touch_sensor
	
	STOP_ISR:
	/*Stop the motors*/
	movia r4, 0xFFFEFFFF	#motor0 disabled (bit 0=1), sensor 3 enabled still 
	stwio r4, 0(r8)
	
	# reset r17(current position) to 0
	mov r17,r0
	# reset r18 to draw xylophone after start screen
	
	ldwio ra,0(sp)
	ldwio r4,4(sp)
	ldwio r8,8(sp)
	ldwio r10,12(sp)
	ldwio r11,16(sp)
	addi sp,sp,4*5
	wrctl ctl1, et
	#subi ea,ea,4				#why subtract 4 from ea?
	movia ea, _start
	eret
	
	
.text
_start:	
	movia sp, 0x03FFFFFC  # initialize stack pointer
	mov r12, r0		# initialize previous switch values to be 0
	mov r17, r0		# initialize current position f lego to be at 0
	
	movia r14, ADDR_JP1
	movia r9, 0xFFFFFFFF	# enable sensor 3, disable all motors
	stwio r9, 0(r14)
	
	# initialization for pushbutton interrupt
	movia r14,PUSHBUTTONS
	movia r4,0x8	# Clear edge capture register to prevent unexpected interrupt (write 1 to clear)
	stwio r4,12(r14) 
	stwio r4,8(r14)  # Enable interrupt for pushbutton 3
	
	movi r4,0b010	# Pushbuttons use IRQ 1
	wrctl ctl3,r4	# set ienable
	movi r4,1
	wrctl ctl0,r4   # Enable global Interrupts on Processor (PIE bit)
	
	call VGA_CLEARscreen
	call VGA_startscreen
	movi r18, 1
	
	
poll_button0:
	movia r14,PUSHBUTTONS
	# try polling KEY[0], if it's not high, go for the switches
	ldwio r8,0(r14)
	andi r8,r8, 1	# only take value of KEY[0]
	beq r8,r0,check_keyboard
	
	# if KEY[0] is pressed, send move_instructions to lego until we hit word 0, then we go back to poll KEY[0]
	movia r15,song1
loop_move_instructions:
	ldwio r8,0(r15)
	beq r8,r0,poll_button0
	ldhio r8,0(r15)	# first we get number of steps
	mov r4,r8
	mov r9,r8		# number of steps in r9
	ldhio r8,2(r15)	# next we get direction
	mov r5,r8
	
	bge r8,r0,move_right_note
	# if relative position is negative, lego needs to move left
	sub r9,r0,r9	# 0 subtract a positive value is its negative value
	move_right_note:
	add r17,r9,r17	# update current position
	
	call move_steps
	
	addi r15,r15,4
	br loop_move_instructions
	
check_keyboard:
	movia r14,PS_2
	loop_check_keyboard:
		ldwio r9, 0(r14)		#get the keyboard data from base of the PS_2
		srli r9,r9,15			#shift to get the valid bit for reading data
		andi r9,r9,1			#extract the valid bit
		beq r9,r0,check_switches			# if valid bit is 0 (not valid), goto check switches
		
		ldwio r9, 0(r14)
		andi r9, r9, 0x0FF 	#Data read is now in r9
		
		# Check for which character it is
		movia r15, keys_makecode
	loop_check_makecode:
		ldwio r8,0(r15)
		beq r8,r0,poll_buffer_cleared	# if does not match any number characters, goto clear input buffer
		ldhuio r8,0(r15)	# first we check if data matches a make code
		addi r15, r15, 4
		bne r9,r8,loop_check_makecode	# if does not match the first number character, check next
		
		# if keyboard data match a number, load the number associated with it (that's the position our car needs to move to)
		subi r15, r15, 4
		ldhuio r8,2(r15)
		sub r13,r8,r17		# get the relative position of the note to hit w.r.t lego's current position
		
		mov r17,r8			# the note we'll goto would become our current position
		blt r13,r0,move_left_note_keyboard	# if relative position is negative, lego needs to move left (almost the same as the "move_left_note" section in check_switches)
		# if relative position is positive or 0
		mov r4,r13		# set number of steps to move
		movi r5,1		# direction to right/forward
		call move_steps
		br poll_buffer_cleared
		
		move_left_note_keyboard:	# if relative position(in r13) is negative, lego needs to move left
			sub r13, r0,r13	# 0 subtract a negative number is its absolute value
			mov r4,r13		# set number of steps to move
			movi r5,-1		# direction to right/forward
			call move_steps
			br poll_buffer_cleared
		
	poll_buffer_cleared:
		ldwio r9, 0(r14)		#get the keyboard data from base of the PS_2
		srli r9,r9,15			#shift to get the valid bit for reading data
		andi r9,r9,1			#extract the valid bit
		beq r9,r0,poll_button0			# if valid bit goes back to 0 (input buffer cleared, ready to accept next key press), go back
		br poll_buffer_cleared
	
check_switches:
	movia r14,SWITCHES
	ldwio r8,0(r14)	# get values of switches
	beq r8,r12,poll_button0		# if no switches changed position, go back to poll buttons
	# if switch values have changed, extract each bit to see which one has changed
	mov r13,r12
	mov r12,r8	# store new switch values
	movi r10, 8	# counter, keep track of how many switches we've check (8 notes on xylophone, thus 8 switches we'll check)
	check_each_switch:
		beq r10,r0,poll_button0	# if it's a switch changing from high to low, we ignore
		subi r10,r10,1
		andi r9,r8,1	# take only the rightmost switch value and compare it to its previous value
		andi r14,r13,1
		srli r8,r8,1
		srli r13,r13,1
		beq r9,r14,check_each_switch
		# if a switch changed from high to low, ignore and continue checking other switches
		beq r9,r0,check_each_switch
	# a switch has changed from 0 to 1, calculate which switch is this from the counter (if it's SW[0], r10 would be 8-1=7, so 7-r10 gives 0 back)
	movi r9, 7
	sub r10,r9,r10
	# if result in r10 is 5, it means it's SW[5] that has changed from 0 to 1, then we'll move our lego to the position of note 5 (which is position 5)
	
	sub r13,r10,r17		# get the relative position of the note to hit w.r.t lego's current position
	mov r17,r10			# the note we'll goto would become our current position
	blt r13,r0,move_left_note	# if relative position is negative, lego needs to move left
	# if relative position is positive or 0
	mov r4,r13		# set number of steps to move
	movi r5,1		# direction to right/forward
	call move_steps
	br poll_button0
	
	move_left_note:	# if relative position(in r13) is negative, lego needs to move left
		sub r13, r0,r13	# 0 subtract a negative number is its absolute value
		mov r4,r13		# set number of steps to move
		movi r5,-1		# direction to right/forward
		call move_steps
		br poll_button0
	
	

# r4: receiving number of steps to move
# r5: receiving direction
# r8: address of the GPIO
# r13: current value of sensors
# r14: counter (how many steps we've moved)
# r15: threshold for sensor


move_steps:
	subi sp,sp,4*7
	stwio r8,0(sp)
	stwio r9,4(sp)
	stwio r13,8(sp)
	stwio r14,12(sp)
	stwio r15,16(sp)
	stwio r16,20(sp)
	stwio ra,24(sp)
	
	# if first time moving lego, clear start screen to draw xylophone
	beq r18,r0,dont_draw_xylophone
		call VGA_CLEARscreen
		call VGA_draw_all_keybars
		mov r18,r0
	
	dont_draw_xylophone:
	# print key number on VGA
	subi sp,sp,4
	stwio r4,0(sp)
	mov r4,r17
	call VGA_print_key_number
	ldwio r4,0(sp)
	addi sp,sp,4
	
	movi r15,9	# threshold for sensor (below 9 white region, >=9 black region)
	movi r14,0	# initialize step counter to 0

	movia r8, ADDR_JP1
	movia r9, 0x07F557FF	# initialize direction to all output
	stwio r9, 4(r8)
	
	movia r9, 0xFFFEFFFF	# enable sensor 3, disable all motors
	stwio r9, 0(r8)	
	call check_sensors

	condition:	
		/*check whether the sensor is higher than threshold*/
		beq r14,r4, STOP	# if we've moved enough steps, stop there to hit the note
		call check_direction
		blt r13, r15, WHITE	# it's in the light region
		bge r13,r15, BLACK	# it's in the dark region
		
		WHITE:
			call check_sensors
			movi r15,10
			ble r13,r15,WHITE	# if it was in the light region and it is still in light region (if sensor<=10 it's still considered light region)
			movi r15,9
			
			br counter
			# hold values of r4,r5 on stack, then call timer to see if it has actually reached region of another colour(should be BLACK now) (keep moving till middle of that region)
			# subi sp,sp,4*2
			# stwio r4,0(sp)
			# stwio r5,4(sp)
			# movi r4, %lo(10000000)	# 0.1 second
			# movi r5, %hi(10000000)
			# call timer
			# ldwio r4,0(sp)
			# ldwio r5,4(sp)
			# addi sp,sp,4*2
			
			# call check_sensors
			# bgt r13,r15,counter	# if it has gone on BLACK region and it is still in BLACK region after some time, it has reached the middle of that region, we can increment counter
			# # else it has gone backwards to the previous region(was in WHITE region) (for some reason..), go back to poll until it reaches BLACK again
			# br WHITE
		
		BLACK: 
			call check_sensors
			movi r15,8
			bge r13,r15,BLACK	# if it was in the dark region and it is still in dark region (if sensor>=8 it's still considered dark region))
			movi r15,9
			
			br counter
			# hold values of r4,r5 on stack, then call timer to see if it has actually reached region of another colour(should be WHITE now) (keep moving till middle of that region)
			# subi sp,sp,4*2
			# stwio r4,0(sp)
			# stwio r5,4(sp)
			# movi r4, %lo(10000000)	# 0.1 second
			# movi r5, %hi(10000000)
			# call timer
			# ldwio r4,0(sp)
			# ldwio r5,4(sp)
			# addi sp,sp,4*2
			
			# call check_sensors
			# blt r13,r15,counter	# if it has gone on WHITE region and it is still in WHITE region after some time, it has reached the middle of that region, we can increment counter
			# # else it has gone backwards to the previous region(was in BLACK region) (for some reason..), go back to poll until it reaches WHITE again
			# br BLACK
		
		counter:
			addi r14,r14,1
			br condition
	
	
	check_direction:	# set motor to move in the desired direction
		blt r5,r0,FORWARD
		bge r5,r0,REVERSE
		
		FORWARD:
			/*Set the motor to run in the forward direction after checking the sensors*/
			movia r9, 0xFFFEFFFC	# motor0 enabled (bit 0=0), direction set to forward (bit1 =0)
			stwio r9, 0(r8)
			ret
			
		REVERSE:
			/*Set the motor to run in the reverse direction after checking the sensors*/
			movia r9, 0xFFFEFFFE	# motor0 enabled (bit 0=0), direction set to reverse (bit1 =1)
			stwio r9, 0(r8)
	ret
	
	check_sensors:
		/*check if the sensor has changed*/
		/*get current value of the sensor3*/
		loop:
			ldwio r13, 0(r8)
			srli r16,r13,17		#17 bit is valid for sensor 3
			andi r16,r16,0x1		#extract the valid bit
			bne  r0,r16,loop		#wait for valid bit to be low
		good:
			srli r13,r13,27		#shift to the right by 27 so that the 4-bit sensor value can be extracted
			andi r13,r13,0x0F	
		ret
		
	STOP_there:		# run motor in the opposite moving direction for a very short time to counteract inertia
		subi sp,sp,4
		stwio ra,0(sp)
		# check how many steps the car has moved, if moved >=3 steps, run motor in opposite direction for a longer time to counteract inertia
		movi r15, 1
		bne r4,r15,check_inertia
			# if moved just 1 step
			movi r15, %lo(1000)	# 0.00001 second
			movi r16, %hi(1000)	# 0.00001 second
			br STOP_motor
			
		check_inertia:	# if car has moved more than 1 step
		movi r15, 3
		bge r4,r15,large_inertia
		# put lower 16 bits of period in r15 and upper 16 bits in r16
			# if moved 2 steps
			movi r15, %lo(1000000)	# 0.01 second	
			movi r16, %hi(1000000)
			br STOP_motor
			
		large_inertia:
			#movi r15, 6
			#bge r4,r15,large_large_inertia
			movi r15, %lo(10000000)	# 0.1 second	
			movi r16, %hi(10000000)
			br STOP_motor
			
		large_large_inertia:	# if car was going FORWARD and has moved >=6 steps
			bge r5,r0,STOP_motor
			movi r15, %lo(20000000)	# 0.2 second	
			movi r16, %hi(20000000)
			br STOP_motor
			
		STOP_motor:
		blt r5,r0,stop_FORWARD	# should oppose the setting in "check_direction"
		
		# bge r5,r0,stop_REVERSE
			# to stop reverse motion, set motor FORWARD (according to the setting in "check_direction")
			movia r9, 0xFFFEFFFC	# motor0 enabled (bit 0=0), direction set to forward (bit1 =0)
			stwio r9, 0(r8)
			
			subi sp,sp,4*2
			stwio r4,0(sp)
			stwio r5,4(sp)
			mov r4, r15		# set period for timer
			mov r5, r16
			call timer
			ldwio r4,0(sp)
			ldwio r5,4(sp)
			addi sp,sp,4*2
			
			movia r9, 0xFFFEFFFF	#motor0 disabled (bit 0=1)	# stop the motor
			stwio r9, 0(r8)
			
			ldwio ra,0(sp)
			addi sp,sp,4
			ret
		
		stop_FORWARD:
			# to stop forward motion, set motor REVERSE (according to the setting in "check_direction")
			movia r9, 0xFFFEFFFE	# motor0 enabled (bit 0=0), direction set to reverse (bit1 =1)
			stwio r9, 0(r8)
			
			subi sp,sp,4*2
			stwio r4,0(sp)
			stwio r5,4(sp)
			mov r4, r15		# set period for timer
			mov r5, r16
			call timer
			ldwio r4,0(sp)
			ldwio r5,4(sp)
			addi sp,sp,4*2
			
			movia r9, 0xFFFEFFFF	#motor0 disabled (bit 0=1)	# stop the motor
			stwio r9, 0(r8)
			
			ldwio ra,0(sp)
			addi sp,sp,4
			ret
		
	STOP:
		/*Stop the motors*/
		call STOP_there
		#movia r9, 0xFFFEFFFF	#motor0 disabled (bit 0=1)	# stop the motor again
		#stwio r9, 0(r8)	
		call move_mallet	
		
		# clear the key number printed on VGA
		call VGA_clear_key_number
		
		ldwio r8,0(sp)
		ldwio r9,4(sp)
		ldwio r13,8(sp)
		ldwio r14,12(sp)
		ldwio r15,16(sp)
		ldwio r16,20(sp)
		ldwio ra,24(sp)
		addi sp,sp,4*7
		ret	# return to get the next move_instructions
		
move_mallet:
	subi sp, sp, 4*4
	stwio ra, 0(sp)
	stwio r9, 4(sp)
	stwio r4, 8(sp)
	stwio r5, 12(sp)

	movia r8, ADDR_JP1
	
	movia r9, 0x07F557FF	#set direction to all output
	stwio r9, 4(r8)

	movia r9, 0xFFFEFFF3	#motor1 enabled (bit 0=0), direction set to forward (bit1 =0) # mallet moves down to hit key
	stwio r9, 0(r8)

	movi r4, %lo(12000000)
	movi r5, %hi(12000000)
	call timer

	movia r9, 0xFFFEFFFB	#motor1 enabled (bit 0=0), direction set to reverse (bit1 =1) # mallet moves up to initial position
	stwio r9, 0(r8)	

	movi r4, %lo(8500000)
	movi r5, %hi(8500000)
	call timer

	movia r9, 0xFFFEFFFF	#motor1 disabled (bit 0=0), direction set to forward (bit1 =0)
	stwio r9, 0(r8)	

	ldwio ra, 0(sp)
	ldwio r9, 4(sp)
	ldwio r4, 8(sp)
	ldwio r5, 12(sp)
	addi sp, sp, 4*4
	ret

timer:
	# save registers used in this subroutine
	subi sp, sp, 8
	stwio r10, 0(sp)	
	stwio r9, 4(sp)
	
	movia r10, 0xFF202000	# timer address
	
	stwio r4, 8(r10)		# lower 8 bits of period
	stwio r5, 12(r10)		# upper 8 bits of period
	movi r9, 0b100			# set interrupt=0, continue=0, start=1 and stop=0 for timer
	stwio r9, 4(r10)		# start the timer
	
	Loop:
	ldwio r9, 0(r10)	# poll timeout bit
	andi r9, r9, 1
	beq r9, r0, Loop
	# if timeout, clear timeout bit
	stwio r0, 0(r10)
	
	ldwio r10, 0(sp)
	ldwio r9, 4(sp)
	addi sp, sp, 8
	ret
