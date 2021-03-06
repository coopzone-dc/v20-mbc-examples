;Test GPIO LED and key
;
BDOS	equ	5	;cp/m-86 BDOS entry point
IODIRA	equ	5	;gpio port A input/output direction
GPIOA	equ	3	;gpio port A data
USRKEY	equ	80h	;optcode for user switch
DPORT	equ	0	;data i/o port
CPORT	equ	1	;Command control port
;
	org	100h
;
        lxi     h, msg  ;say hello
        call    puts
;setup the GPIO chip Port A as output
	mvi	a,IODIRA
	out	CPORT
	xra	a
	out	DPORT	;all 0 means output for all bits

main:
	mvi	a,32	;turn on led, GPIOA5=32, B00100000=32
	call	gpio
	call	delay
	jnz	done
	xra	a	;zero gpio data pin=0
	call	gpio
	call	delay
	jz	main
;
done:	cpi	'w'     ;did the delay routine end with a w pressed?
	jnz	finish	;if no then we realy have finished
	lxi	h, dia	;print diagram
	call	puts
	jmp	main	;continue in our execution loop
;
finish:	xra	a	;zero led, off
	call	gpio
	lxi	h, bye 	;say by then exit to cp/m
	call	puts
	mvi	c,0	;exit to bdos
	call	BDOS	;This never returns to us, could use jmp 0
;
puts:
        mov     a,m     ;get the char to print
        ora     a       ;is it zero
        rz		;if it's a 0 then return
        mvi     c,2     ;console output
        mov     e,a     ;char to print
        push    h
        call    BDOS    ;print it
        pop     h       ;restor local regs
        inx     h
        jmp     puts    ;next char to print
gpio:
        push    psw     ;save the led value
        mvi     a,GPIOA ;port optcode
        out     CPORT
        pop     psw     ;get the on/off value
        out     DPORT
        ret

delay:
;timer is complete guess work with cpu at 8mhz
        lxi     b,0005h ;outer loop,
;outer looo starts
lp1:    push    b       ;save outer counter
        lxi     b,0210h ;inner loop
;inner-loop starts
lp2:    push    b       ;save inner counter
        mvi     c,6     ;bdox function direct io
        mvi     e,0FFh  ;see if a key is pressed
        call    BDOS
        ora     a       ;check for 0 would be no-key
        jnz     exit1   ;if char then exit
;No keyboard key pressed also check user key
        mvi     a,USRKEY ;user key port cmd
        out     CPORT
        in      DPORT   ;get key
        ani     1       ;bit 0 key press=1
        jnz     exit1   ;user key pressed
        pop     b       ;no key pressed so count down
        dcx     b	;count down
        mov     a,b	;are both b and c =0
        ora     c
        jnz     lp2	;keep going,iner loop
;
        pop     b       ;outer loop
        dcx     b	;loop countdown and repeat
        mov     a,b
        ora     c
        jnz     lp1	;keep going,outer loop
        xra     a
        ret             ;return if both loops=0 and no key
exit1:  pop     b
        pop     b
        ret
;
bye	db	'Exit'
	db	0ah,0dh,0
dia	db	'Demo HW wiring (See A250220-sch.pdf schematic):'
	db	0ah,0dh
	db	' GPIO'
	db	0ah,0dh
        db      ' (J7)'
       	db      0ah,0dh
       	db      '+-----+'
       	db      0ah,0dh
       	db      '| 1 2 |'
       	db      0ah,0dh
       	db      '| 3 4 |   LED         RESISTOR'
       	db      0ah,0dh
       	db      '| 5 6 |                 680'
       	db      0ah,0dh
       	db      '| 7 8-+--->|-----------/\/\/--+'
       	db      0ah,0dh
       	db      '| 9 10|                       |'
       	db      0ah,0dh
       	db      '|11 12|                       |'
       	db      0ah,0dh
       	db      '|13 14|                       |'
       	db      0ah,0dh
       	db      '|15 16|                       |'
       	db      0ah,0dh
       	db      '|17 18|                       |'
       	db      0ah,0dh
       	db      '|19 20+-----------------------+ GND'
       	db      0ah,0dh
       	db      '+-----+'
	db	0ah,0dh
msg	db	'User GPIO test, press w for diagram, any key to exit'
	db	0ah,0dh,0
