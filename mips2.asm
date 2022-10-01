	.eqv	INTERUPT_ADDR		0x80000180		#location to raise an interrupt
	.eqv	BUTTON_ADDR		0xFFFF0013		#location for the button status
	.eqv	ENABLE_TIMER_ADDR	0xFFFF0012		#location to enable timer
	.eqv	CAR_LIGHT_ADDR		0xFFFF0011		#location of car light
	.eqv	PED_LIGHT_ADDR		0xFFFF0010		#location of pedestrian light
	
	.eqv	EXCEPTION_MASK		0x007C			#exception mask, bits 2-6 in the cause register
	.eqv	TIMER_INTERUPT_MASK	0x0400			#bit 10 of the status register (allows for timer interrupt)
	.eqv	BUTTON_INTERUPT_MASK	0x0800			#bit 11 of the status register (allows for button interupt)
	.eqv	CLEAR_INTERUPTS		0xFFFFF3FF		#clear both timer and button interrups
	.eqv	INTERUPT_MASK		0x0C00			#mask for timer and button interrupts
	.eqv	RESET_CAR_BUTTON_STATUS	0xFFFFFFFD		#reset car button
	.eqv	RESET_PED_BUTTON_STATUS	0xFFFFFFFE		#reset ped button
	
	.eqv	ENALBE_TIMER		0x01			#non-zero number to enable timer
	.eqv	PED_LIGHT_RED		0x1			#red light code for pedestrian light
	.eqv	DARK_LIGHT		0x0			#dark light for both signals
	.eqv	PED_LIGHT_GREEN		0x2			#green light for pedestrian light
	.eqv	CAR_LIGHT_RED		0x1			#red light for car light
	.eqv	CAR_LIGHT_ORANGE	0x2			#orange light for car
	.eqv	CAR_LIGHT_GREEN		0x4			#green light for car light
	.eqv	CAR_BUTTON		0x2			#car button signifier
	.eqv	PED_BUTTON		0x1			#pedestrian button signifier

.data

	timer: .word 0
	carGreenTime: .word 0
	pedGreenTime: .word 0
	carOrangeTime: .word 0
	
	space: .asciiz " "
	
	buttonStatus: .word 0
	pedLightState: .word PED_LIGHT_RED
	carLightState: .word CAR_LIGHT_GREEN
	
	restoreCarLight: .word 0
	

	.ktext	INTERUPT_ADDR
	la	$t1,	intRoutine
	jr	$t1
	nop

.text

#----------------------------------------------------------------------------------------
.globl incrementTimer
incrementTimer:
	lw	$a0,	timer
	addi	$a0	$a0,	1
	sw	$a0,	timer
	
	jr $ra

.globl printTime
printTime:
	lw	$a0,	timer
	li	$v0,	1
	syscall
	la	$a0,	space
	li	$v0,	4
	syscall

	jr 	$ra	
	
#-------------------------------------------------Control lights---------------------------
.globl setPedLightGreen
setPedLightGreen:
	li	$a0,	PED_LIGHT_GREEN
	sb	$a0,	PED_LIGHT_ADDR
	sw	$a0,	pedLightState
	jr	$ra
.globl setPedLightRed
setPedLightRed:
	li	$a0,	PED_LIGHT_RED
	sb	$a0,	PED_LIGHT_ADDR
	sw	$a0,	pedLightState
	jr	$ra
.globl setPedLightDark
setPedLightDark:
	li	$a0,	DARK_LIGHT
	sb	$a0,	PED_LIGHT_ADDR
	sw	$a0,	pedLightState
	jr	$ra
	
.globl setCarLightGreen
setCarLightGreen:
	li	$a0,	CAR_LIGHT_GREEN
	sb	$a0,	CAR_LIGHT_ADDR
	sw	$a0,	carLightState
	jr	$ra
.globl setCarLightOrange
setCarLightOrange:
	li	$a0,	CAR_LIGHT_ORANGE
	sb	$a0,	CAR_LIGHT_ADDR
	sw	$a0,	carLightState
	jr	$ra
.globl setCarLightRed
setCarLightRed:
	li	$a0,	CAR_LIGHT_RED
	sb	$a0,	CAR_LIGHT_ADDR
	sw	$a0,	carLightState
	jr	$ra
#-------------------------------------------------------------------------

.globl main
main:
	mfc0	$t0	$12				#read status register
	ori	$t0,	$t0,	INTERUPT_MASK		#enable timer and button interupts
	ori	$t0,	$t0,	1			#allow programer defined interupts
	mtc0	$t0,	$12				#save status register
	
	jal	setCarLightGreen
	jal	setPedLightRed
	
	li	$t0,	ENALBE_TIMER			#enable timer
	sb	$t0,	ENABLE_TIMER_ADDR
loop:
	nop
	b loop
	
	li	$v0,	10
	syscall

.globl intRoutine
intRoutine:
	subu	$sp,	$sp,	16
	sw	$ra,	12($sp)
	sw	$at,	8($sp)
	sw	$a0,	4($sp)
	sw	$v0,	0($sp)
	
	#establish nature of interrupt
	mfc0	$k1,	$13				#read cause register
	andi	$k0,	$k1,	EXCEPTION_MASK		#read exception bits
	bne	$k0,	$zero,	restore			#if non zero break (internal interupt)
	andi	$k0,	$k1,	BUTTON_INTERUPT_MASK	#checks if the interupt contains a sim interupt
	beq	$k0,	$zero,	changeLights		#skip sim instructions if no sim interrupt exists
	
	#handle sim interrupt
	lb	$k0,	BUTTON_ADDR			#get buttons status
	andi	$k1,	$k0,	CAR_BUTTON		#check if car button was pressed
	beq	$k1,	$zero,	checkPedBtn		#skip to next button if car was not pressed
	lw	$k1,	buttonStatus			#load button status
	ori	$k1,	CAR_BUTTON 			#record car button press
	sw	$k1,	buttonStatus			#store status
	j	changeLights				#jump past pedestrian button
	
	checkPedBtn:					
	lw	$k1,	buttonStatus			#load button status
	ori	$k1,	PED_BUTTON			#record pedestrian button press
	sw	$k1,	buttonStatus			#store status
	
changeLights:
	
	#skip if not a timer interupt
	mfc0,	$k1,	$13
	andi	$k0,	$k1,	TIMER_INTERUPT_MASK
	beq	$k0,	$zero,	restore
	
	#check if timer >= 10 & Ped btn pressed: TODO check that car light: red
	lw	$k0,	restoreCarLight
	andi	$k0,	$k0,	1
	bne	$k0,	$zero,	notPedBlinkTime
	lw	$k0,	carGreenTime			#load timer value
	slti	$k1,	$k0,	10			#check if timer < 10
	bne	$k1,	$zero,	notTimeGreen		#if so, skip to notTimeGreen
	lw	$k0,	buttonStatus			#load button status
	andi	$k1,	$k0,	PED_BUTTON		#check if pedestrian button is pressed
	beq	$k1,	$zero,	notTimeGreen		#if not, skip to noTimeGreen
	lw	$k1,	carLightState			#else:	load car light state
	andi	$k0,	$k1,	CAR_LIGHT_RED		#check if the light is red
	bne	$k0,	$zero,	timeGreenOrange		#if true, set light to orange
	andi	$k0,	$k1,	CAR_LIGHT_ORANGE	#check if the light is orange
	bne	$k0,	$zero,	timeGreenRed		#if true, set light to red
	timeGreenOrange:
	jal	setCarLightOrange			#set car light to orange
	j	timerWork				#skip to timerwork
	timeGreenRed:
	lw	$k0,	carOrangeTime
	addi	$k0,	$k0,	1
	sw	$k0,	carOrangeTime
	slti	$k0,	$k0,	4
	bne	$k0,	$zero,	timerWork
	jal 	setCarLightRed				#set car light to red
	li	$k0,	0				#reset the car green time
	sw	$k0,	carGreenTime
	sw	$k0,	carOrangeTime
	j	timerWork				#jump to timerWork
	
	notTimeGreen:
	
	#check if ped button is pressed & car light is red
	lw	$k0,	buttonStatus			#load button status
	andi	$k0,	$k0,	PED_BUTTON		#check if ped button is pressed
	beq	$k0,	$zero,	notPedSwitchTime	#break if not
	lw	$k0,	carLightState			#load car light state
	andi	$k0,	$k0,	CAR_LIGHT_RED		#check if car light is red
	beq	$k0,	$zero,	notPedSwitchTime	#if not break
	jal	setPedLightGreen			#set pedestrian light to green
	
	lw	$k0,	buttonStatus			#load button status
	andi	$k0,	$k0,	RESET_PED_BUTTON_STATUS	#remove pedestrian button from status
	sw	$k0,	buttonStatus			#store new status
	
	notPedSwitchTime:
	
	#check if ped light should switch
	lw	$k1,	pedGreenTime			#load pedestrian green time
	slti	$k0,	$k1,	8			#if less than 8, break (stay green)
	bne	$k0,	$zero,	notPedBlinkTime		
	slti	$k0,	$k1,	9			#if less than 9 (8), set to red
	bne	$k0,	$zero,	setPedBlinkRed
	slti	$k0,	$k1,	10			#if less than 10(9), set to dark
	bne	$k0,	$zero,	setPedBlinkDark
	slti	$k0,	$k1,	11			#if less than 11(10), set to red
	bne	$k0,	$zero,	setPedBlinkRed
	li	$k0,	0				#else (>11) set greentime to 0
	sw	$k0,	pedGreenTime
	li	$k0,	1				#set restoreCarLight to 1
	sw	$k0,	restoreCarLight		
	j	notPedBlinkTime
	setPedBlinkDark:
	jal setPedLightDark				#set pedestrian light to dark
	lw	$k0,	pedGreenTime			#increment pedGreenTime
	addi	$k0,	$k0,	1
	sw	$k0,	pedGreenTime
	j	notPedBlinkTime				#break to noPedBlinkTime
	setPedBlinkRed:
	jal 	setPedLightRed				#set pedestrian light to red
	lw	$k0,	pedGreenTime			#increment pedGreenTime
	addi	$k0,	$k0,	1
	sw	$k0,	pedGreenTime			
	
	notPedBlinkTime:
	
	#check if car light needs to be restored
	lw 	$k0,	restoreCarLight			#load restoreCarLight
	andi	$k0,	$k0,	1			#check if 1
	beq	$k0,	$zero,	timerWork		#if not break
	lw	$k0,	carLightState			#load car light state
	andi	$k0,	$k0,	CAR_LIGHT_RED		#check if car light is red
	bne	$k0,	$zero,	restoreToOrange		#if so, break to restoreToOrange
	j 	restoreToRed				#if not (is orange), jump to restoreToRed
	
	restoreToOrange:
	jal	setCarLightOrange
	j	timerWork
	restoreToRed:
	lw	$k0,	carOrangeTime
	addi	$k0,	$k0,	1
	sw	$k0,	carOrangeTime
	slti	$k0,	$k0,	4
	bne	$k0,	$zero,	timerWork
	jal	setCarLightGreen
	li	$k0,	0
	sw	$k0,	restoreCarLight
	sw	$k0,	carOrangeTime
	
	timerWork:
	
	#increment timer
	mfc0	$k1,	$13
	andi	$k0,	$k1,	TIMER_INTERUPT_MASK	#if interupt is not caused by the timer, skip
	beq	$k0,	$zero,	restore
	jal incrementTimer
	jal printTime
	
	#inrement carGreenLight timer
	lw	$k0,	carLightState
	andi	$k0,	$k0,	CAR_LIGHT_GREEN
	beq	$k0,	$zero,	incrementGreenPedLight
	lw	$k0,	carGreenTime
	addi	$k0,	$k0,	1
	sw	$k0,	carGreenTime
		
	incrementGreenPedLight:
	#increment pedGreenLight timer
	lw	$k0,	pedLightState
	andi	$k0,	$k0,	PED_LIGHT_GREEN
	beq	$k0,	$zero,	restore
	lw	$k0,	pedGreenTime
	addi	$k0,	$k0,	1
	sw	$k0,	pedGreenTime
	
	restore:
	lw	$ra,	12($sp)
	lw	$at,	8($sp)
	lw	$a0,	4($sp)
	lw	$v0,	0($sp)
	addiu	$sp,	$sp,	16
	mfc0	$k1,	$13
	andi	$k1,	$k1,	CLEAR_INTERUPTS
	mtc0	$k1,	$13
	eret