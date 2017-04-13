.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000
.equ ADDR_START_1, 0x0801E050 /* store the address of (40,120) */
.equ ADDR_START_2, 0x0801E08C /* store the address of (70,120) */
.equ ADDR_START_3, 0x0801E0C8 /* store the address of (100,120) */
.equ ADDR_START_4, 0x0801E104 /* store the address of (130,120) */
.equ ADDR_START_5, 0x0801E140 /* store the address of (160,120) */
.equ ADDR_START_6, 0x0801E17C /* store the address of (190,120) */
.equ ADDR_START_7, 0x0801E1B8 /* store the address of (220,120) */
.equ ADDR_START_8, 0x0801E1F4 /* store the address of (250,120) */

.global VGA_startscreen
.global VGA_CLEARscreen
.global VGA_draw_all_keybars

.global VGA_print_key_number
.global VGA_clear_key_number

/* r3 stores addr to print char*/
/* r4 stores addr of ASCII code of char*/
/* r5 stores char */

VGA_startscreen:
	subi sp,sp,4*3
	stwio r3,0(sp)
	stwio r4,4(sp)
	stwio r5,8(sp)
	
	/* show "Xylophone" on screen */
	movia r3, ADDR_CHAR
	addi r3,r3,3604	 # X in (20,28) 
	movia r4,startscreen_line1
	
	loop_startscreen_line1:
		ldwio r5,0(r4)
		beq r5,r0,print_startscreen_line2
		
		ldbuio r5,0(r4)	# load ASCII code of the char
		stbio r5, 0(r3)	# store char for VGA
		addi r4,r4,1
		addi r3,r3,2
		br loop_startscreen_line1
		
	/*press key[0] to start */
	print_startscreen_line2:
		movia r3, ADDR_CHAR
		addi r3,r3,5787		 # P in (27,45) 
		movia r4,startscreen_line2
		
		loop_startscreen_line2:
			ldwio r5,0(r4)
			beq r5,r0,exit_VGA_startscreen
			
			ldbuio r5,0(r4)	# load ASCII code of the char
			stbio r5, 0(r3)	# store char for VGA
			addi r4,r4,1
			addi r3,r3,1
			br loop_startscreen_line2
		
	exit_VGA_startscreen:
		ldwio r3,0(sp)
		ldwio r4,4(sp)
		ldwio r5,8(sp)
		addi sp,sp,4*3
		ret
	
	
VGA_CLEARscreen:
	subi sp,sp,4*3
	stwio r3,0(sp)
	stwio r4,4(sp)
	stwio r5,8(sp)
	
	movi r5, 0x20	# ASCII code for space
	movia r3, ADDR_CHAR
	addi r4,r3,7760		# r4 is end of VGA char screen 80*60
	# basically for all pixels, print a space in black
	loop_VGA_CLEARscreen_char:
		beq r4,r3,VGA_CLEARscreen_colour
		stbio r5, 0(r3)	# store char for VGA
		addi r3,r3,1
		br loop_VGA_CLEARscreen_char
		
	VGA_CLEARscreen_colour:
	movia r3, ADDR_VGA 	# use VGA colour mode to draw each pixel black
	movia r5, (320*2)+(240*1024)
	add r4, r3, r5
	movui r5, 0x0000 # set color to black
	
	#loop through the whole screen
	loop_VGA_CLEARscreen_colour:
		beq r4,r3,exit_VGA_CLEARscreen
		sthio r5, 0(r3) #draw one pixel black
		addi r3,r3,2
		br loop_VGA_CLEARscreen_colour
		
	exit_VGA_CLEARscreen:
		
		ldwio r3,0(sp)
		ldwio r4,4(sp)
		ldwio r5,8(sp)
		addi sp,sp,4*3
		ret
		
# r4: 16 bit (hword) colour
# r5: start pixel address
# r6: vertical length of colour bar
# r8: counter for 20 pixels horizontally
VGA_draw_colour_bar:
	subi sp,sp,4
	stwio r8,0(sp)
	
	# go back to end of previous line to be continuous with the looping condition
	subi r5,r5,1024
	addi r5,r5,40
	
	vertical_colour_bar:
		beq r6,r0,exit_VGA_draw_colour_bar
		subi r6,r6,1
		# push r5 to start of the next line (colour pixels on the next line)
		subi r5,r5,40
		addi r5,r5,1024
		movi r8,20
		
		loop_horizontal_colour_bar:
			beq r8,r0,vertical_colour_bar
			sthio r4, 0(r5)
			addi r5,r5,2
			subi r8,r8,1
			br loop_horizontal_colour_bar
	
	exit_VGA_draw_colour_bar:
		ldwio r8,0(sp)
		addi sp,sp,4
		ret
		
VGA_draw_all_keybars:
	subi sp,sp,4*4
	stwio ra,0(sp)
	stwio r4,4(sp)
	stwio r5,8(sp)
	stwio r6,12(sp)
	
	# key 0 (longest key on the left)
	movui r4, 0x680F 	# 16 bit color PURPLE
	movia r5, ADDR_START_1
	movi r6, 80
	call VGA_draw_colour_bar
	
	# key 1 (2nd key from the left)
	movui r4, 0x001F 	# 16 bit color BLUE
	movia r5, ADDR_START_2
	movi r6, 75
	call VGA_draw_colour_bar
	
	# key 2 (3rd key from the left)
	movui r4, 0x07FF 	# 16 bit color CYAN
	movia r5, ADDR_START_3
	movi r6, 70
	call VGA_draw_colour_bar
	
	# key 3 (4th key from the left)
	movui r4, 0x1700 	# 16 bit color GREEN
	movia r5, ADDR_START_4
	movi r6, 65
	call VGA_draw_colour_bar
	
	# key 4 (5th key from the left)
	movui r4, 0xFFE0 	# 16 bit color YELLOW
	movia r5, ADDR_START_5
	movi r6, 60
	call VGA_draw_colour_bar
	
	# key 5 (6th key from the left)
	movui r4, 0xF400 	# 16 bit color ORANGE
	movia r5, ADDR_START_6
	movi r6, 55
	call VGA_draw_colour_bar
	
	# key 6 (7th key from the left)
	movui r4, 0xF800 	# 16 bit color RED
	movia r5, ADDR_START_7
	movi r6, 50
	call VGA_draw_colour_bar
	
	# key 7 (shortest key on the right)
	movui r4, 0xF81F 	# 16 bit color PINK
	movia r5, ADDR_START_8
	movi r6, 45
	call VGA_draw_colour_bar
	
	ldwio ra,0(sp)
	ldwio r4,4(sp)
	ldwio r5,8(sp)
	ldwio r6,12(sp)
	addi sp,sp,4*4
	ret
	
VGA_print_key_number:
	subi sp,sp,4*4
	stwio r3, 0(sp)
	stwio r5, 4(sp)
	stwio r6, 8(sp)
	stwio ra, 12(sp)
	
	movia r3, ADDR_CHAR
	movi r6, 0
	beq r4, r6, draw_and_clear_dot_left_most_1

	movi r6, 1
	beq r4, r6, draw_and_clear_dot_2

	movi r6, 2
	beq r4, r6, draw_and_clear_dot_3

	movi r6, 3
	beq r4, r6, draw_and_clear_dot_4

	movi r6, 4
	beq r4, r6, draw_and_clear_dot_5

	movi r6, 5
	beq r4, r6, draw_and_clear_dot_6

	movi r6, 6
	beq r4, r6, draw_and_clear_dot_7

	movi r6, 7
	beq r4, r6, draw_and_clear_dot_8
	br finish_responese

	draw_and_clear_dot_left_most_1:
	  movi r5, 0x31  /* ASCII for 1 */
	  stbio r5, 3596(r3) /* (12,28) */
	  br finish_responese

	draw_and_clear_dot_2:
	  movi r5, 0x32  /* ASCII for 2 */
	  stbio r5, 3604(r3) /* (20,28) */
	  br finish_responese

	draw_and_clear_dot_3:
	  movi r5, 0x33  /* ASCII for 3 */
	  stbio r5, 3611(r3) /* (27,28) */
	  br finish_responese

	draw_and_clear_dot_4:
	  movi r5, 0x34  /* ASCII for 4 */
	  stbio r5, 3619(r3) /* (35,28) */
      br finish_responese      

	draw_and_clear_dot_5:
	  movi r5, 0x35  /* ASCII for 5 */
	  stbio r5, 3626(r3) /* (42,28) */
      br finish_responese	  

	draw_and_clear_dot_6:
	  movi r5, 0x36  /* ASCII for 6 */
	  stbio r5, 3633(r3) /* (49,28) */
	  br finish_responese

	draw_and_clear_dot_7:
	  movi r5, 0x37  /* ASCII for 7 */
	  stbio r5, 3641(r3) /* (57,28) */
	  br finish_responese

	draw_and_clear_dot_8:
	  movi r5, 0x38  /* ASCII for 8 */
	  stbio r5, 3648(r3) /* (64,28) */
	  br finish_responese
	  
	finish_responese:
		ldwio r3, 0(sp)
		ldwio r5, 4(sp)
		ldwio r6, 8(sp)
		ldwio ra, 12(sp)
		addi sp,sp,4*4
		ret
		
		
VGA_clear_key_number:
	subi sp,sp,4*3
	stwio r3,0(sp)
	stwio r4,4(sp)
	stwio r5,8(sp)
	
	movi r5, 0x20	# ASCII code for space
	movia r3, ADDR_CHAR
	addi r3,r3,3596		# start clearing from (12,28)
	addi r4,r3,53		# r4 is (64,28)
	# basically for all pixels, print a space in black
	loop_VGA_clear_key_number:
		beq r4,r3,exit_VGA_clear_key_number
		stbio r5, 0(r3)	# store char for VGA
		addi r3,r3,1
		br loop_VGA_clear_key_number
		
	exit_VGA_clear_key_number:
		ldwio r3,0(sp)
		ldwio r4,4(sp)
		ldwio r5,8(sp)
		addi sp,sp,4*3
		ret
	
	
