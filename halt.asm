;Test user LED and key
;
BDOS	equ	5	;cp/m 2.2 BDOS entry point
;
	org	100h
 	lxi	h, msg	;say hello
	call	puts
;
	halt
;	
	mvi	c,0	;exit to bdos
	call	BDOS
;
puts:
	mov	a,m	;get the char to print
	ora	a	;is it zero
	jz	return	;finished
	mvi	c,2	;console output
	mov	e,a	;char to print
	push	h
	call	BDOS	;print it
	pop	h	;restor local regs
	inx	h
	jmp	puts	;next char to print
return:	
	ret
;
	msg	db	'Testing HALT LED, you will need to press reset to exit'
		db	0ah,0dh,0
