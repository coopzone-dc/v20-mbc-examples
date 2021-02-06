;Test user LED and key
;
BDOS	equ	5	;cp/m 2.2 BDOS entry point
USRLED	equ	0	;optcode for user LED
USRKEY	equ	80h	;optcode for user switch
DPORT	equ	0	;data i/o port
CPORT	equ	1	;Command control port
;
	org	100h
 	lxi	h, msg	;say hello
	call	puts
main:
	mvi	a,1	;out 1 turn led on
	call	led
	call	delay
	jnz	done	;if delay returned as non-zero
	xra	a	;zero the led=0
	call	led
	call	delay
	jz	main	;if delay returned a zero, no key-press
;
done:	xra	a	;zero led, off
	call	led
	lxi	h, bye	;say bye and exit
	call	puts
	mvi	c,0	;exit to bdos
	call	BDOS	;you could just do jmp 0
;
puts:
	mov	a,m	;get the char to print
	ora	a	;is it zero
	rz		;return if zero, end of message
	mvi	c,2	;console output
	mov	e,a	;char to print
	push	h
	call	BDOS	;print it
	pop	h	;restor local regs
	inx	h
	jmp	puts	;next char to print
led:
	push	psw	;save the led value
	mov	a,USRLED ;LED optcode
	out	CPORT
	pop	psw	;get the on/off value
	out	DPORT
	ret
delay:
	lxi	b,0005h	;outer loop
lp1:	push	b	;save outer counter
	lxi	b,0210h	;inner loop
lp2:	push	b	;save counter
	mvi	c,6	;bdox function direct io
	mvi	e,0FFh	;see if a key is pressed
	call	BDOS
	ora	a	;check for 0
	jnz	exit1	;if char then exit
;No keyboard key pressed also check user key
	mvi	a,USRKEY ;user key port cmd
	out	CPORT
	in	DPORT	;get key
	ani	1	;bit 0 key press=1
	jnz	exit1	;user key pressed
	pop	b	;no key pressed so round again
	dcx	b	;count down inner loop
	mov	a,b
	ora	c	;if bc=0
	jnz	lp2	;inner loop
	pop	b	;outer loop counter
	dcx	b	;count down
	mov	a,b
	ora	c	;if bc=0
	jnz 	lp1	;not yet zero
	xra	a	;end with led off
	ret		;return after tmer no key
exit1:	pop	b	;exit because key pressed,loose counters
	pop	b
	ret
;
	msg	db	'User LED test, any key to exit'
		db	0ah,0dh,0
	bye	db	'Exit'
		db	0ah,0dh,0
