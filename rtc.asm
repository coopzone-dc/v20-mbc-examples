;Read the RTC and Temperature
;
BDOS	equ	5	;cp/m 2.2 BDOS entry point
TMDT	equ	132	;Time/Date optcode
DPORT	equ	0	;data i/o port
CPORT	equ	1	;Command control port
;
	org	100h
main:
	lxi	h,0	;keeping old stack to avoid wboot on exit
	dad	sp	;
	shld	(oldSP)
	lxi	sp,stackend
;
	mvi	a,TMDT	;Get the time,date and temp optcode
	out	CPORT
	in	DPORT	;get seconds
	lxi	h,sec	;where to store it
	call	savit
	in	DPORT	;get minutes
	lxi	h,min	;where to store it
	call	savit
	in	DPORT	;get hours
	lxi	h,hours	;save it
	call	savit
	in	DPORT	;get day
	lxi	h,day	;where to store it
	call	savit
	in	DPORT	;get month
	lxi	h,month	;where to store it
	call	savit
	in	DPORT	;year
	lxi	h,year	;save it here
	call	savit
	in	DPORT	;temp
	lxi	h,temp	; and save it here
	cpi	128	; check to see if it's negative
	jm	tempok	;if less than 128
	cma
	inr	a	;2's compl
tempok:
	call	savit	;store the  temp
;
;all the data has been aded to the string, so print it out
;
	lxi	h,str	;print the results
	call	puts		
exit:	
	lhld	(oldSP)	;get back the old stack
	sphl		;into stack
	ret		;exit without wboot
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
;
savit:
	mvi	b,'0'	;hold the 10's units with an ascii 0 offset
savnxt:	xri	0	;clear carry
	sbi	10	;subtract 10
	jc	savdon	;if it cause a borrow then done
	inr	b	;add up the 10's
	jmp	savnxt	;keep going
savdon:	adi	'0'+10	;add back the last 10 + ascii 0
	mov	m,b	;save the 10's units
	inx	h
	mov	m,a	;save the one's
	ret
;
	
;
str	db	'Current time: '
hours	db	'hh'
	db	':'
min	db	'mm'
	db	':'
sec	db	'ss'
	db	' '
day	db	'dd'
	db	'/'
month	db	'mm'
	db	'/'
year	db	'yy'
	db	0ah,0dh
	db	'Temperature:  '
temp	db	'xx'
	db	'C'
	db	0ah,0dh,0
oldSP:	ds	2
stack:	ds	64
stackend:	equ	$

