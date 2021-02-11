;*****************************************************************************
;Originally writen in z80 code by:
; XS - Xmodem Send for Z80 CP/M 2.2 using CON:
; Copyright 2017 Mats Engstrom, SmallRoomLabs
;
;Converted to 8080 code, and rewritten in part by Derek Cooper
;
; Licensed under the MIT license
;Copyright (c) 2021 Derek Cooper
;
;Permission is hereby granted, free of charge, to any person obtaining a copy
;of this software and associated documentation files (the "Software"), to deal
;in the Software without restriction, including without limitation the rights
;to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;copies of the Software, and to permit persons to whom the Software is
;furnished to do so, subject to the following conditions:
;
;THE SOFTWaRE IS PROVIDED "aS IS", WITHOUT WaRRaNTY OF aNY KIND, EXPRESS OR
;IMPLIED, INCLUDING BUT NOT LIMITED TO THE WaRRaNTIES OF MERCHaNTaBILITY,
;FITNESS FOR a PaRTICULaR PURPOSE aND NONINFRINGEMENT. IN NO EVENT SHaLL THE
;aUTHORS OR COPYRIGHT HOLDERS BE LIaBLE FOR aNY CLaIM, DaMaGES OR OTHER
;LIaBILITY, WHETHER IN aN aCTION OF CONTRaCT, TORT OR OTHERWISE, aRISING FROM,
;OUT OF OR IN CONNECTION WITH THE SOFTWaRE OR THE USE OR OTHER DEaLINGS IN THE
;SOFTWaRE.
;*****************************************************************************
;
;	Common entry points and locations
;
BOOT:	EQU	0000h	; Warm boot/Reset vector
BDOS:	EQU 	0005h	; BDOS function vector
DFCB:	EQU	5CH	; Default File Control Block
DFCBcr:	EQU 	DFCB+32 ; Current record
dbuf:	EQU	0080h

;
; BDOS function codes
;
;WBOOT:	 EQU	0	; System Reset
;GETCON: EQU	1	; Console Input a<char
;OUTCON: EQU	2	; Console Output E=char
;GETRDR: EQU	3	; Reader Input a<char
;PUNCH:	 EQU	4	; Punch Output E=char
;LIST:	 EQU	5	; List Output E=char
;DIRCIO: EQU	6	; Direct Console I/O E=char/FE/FF a<char
;GETIOB: EQU	7	; Get I/O Byte a<value
;SETIOB: EQU	8	; Set I/O Byte E=value
;PRTSTR: EQU	9	; Print $ String DE=addr
;RDBUFF: EQU	10	; Read Console Buffer DE=addr
;GETCSTS:EQU	11	; Get Console Status a<status (00empty FFdata)
;GETVER: EQU	12	; Return Version Number HL<version
;RSTDSK: EQU	13	; Reset Disk System
;SETDSK: EQU	14	; Select Disk E=diskno
OPENFIL: EQU	15	; Open File DE=FCBaddr a<handle (FFerr)
CLOSEFIL:EQU	16	; Close File DE=FCBaddr a<handle (FFerr)
;GETFST: EQU	17	; Search for First DE=FCBaddr a<handle (FFerr)
;GETNXT: EQU	18	; Search for Next a<handle (FFerr)
;DELFILE:EQU	19	; Delete File DE=FCBaddr a<handle (FFerr)
READSEQ: EQU	20	; Read Sequential DE=FCBaddr a<status (00ok)
;WRTSEQ: EQU	21	; Write Sequential DE=FCBaddr a<status (00ok)
;FCREaTE:EQU	22	; Make File  DE=FCBaddr a<handle (FFerr)
;RENFILE:EQU	23	; Rename File DE=FCBaddr a<handle (FFerr)
;GETLOG: EQU	24	; Return Log-in Vector HL<bitmap
;GETCRNT:EQU	25	; Return Current Disk a<diskno
PUTDMa:	 EQU	26	; Set DMa address DE=addr
;GETaLOC:EQU	27	; Get addr (aLLOC) HL<addr
;WRTPRTD:EQU	28	; Write Protect Current Disk
;GETROV: EQU	29	; Get Read-Only Vector HL<bitmap
;SETaTTR:EQU	30	; Set File attributes DE=FCBaddr a<handle
;GETPaRM:EQU	31	; Get addr (DISKPaRMS) a<DPBaddr
;GETUSER:EQU	32	; Set/Get User Code E=code (FFget) a<value
;RDRaNDOM:EQU	33	; Read Random DE=FCBaddr a<status
;WTRaNDOM:EQU	34	; Write Random DE=FCBaddr a<status
;FILESIZE:EQU	35	; Compute File Size DE=FCBaddr
;SETRaN: EQU	36	; Set Random Record DE=FCBaddr
;LOGOFF: EQU	37	; Reset Drive DE=drivevector
;WTSPECL:EQU	40	; Write Random with Zero Fill DE=FCBaddr a<status

;
; aSCII codes
;
LF:	EQU	'J'-40h	; ^J LF
CR: 	EQU 	'M'-40h	; ^M CR/ENTER
SOH:	EQU	'a'-40h	; ^a CTRL-a
EOT:	EQU	'D'-40h	; ^D = End of Transmission
ACK:	EQU	'F'-40h	; ^F = Positive acknowledgement
NAK:	EQU	'U'-40h	; ^U = Negative acknowledgement
CAN:	EQU	'X'-40h	; ^X = Cancel

;
; Start of code
;
	ORG 0100h

	lda	(2)		; High part of BIOS Warm Boot address
	sta	(CONST+2)	; Update jump target addressed
	sta	(CONIN+2)	; ...
	sta	(CONOUT+2)	; ...

	lxi	h,0		;save the old stack pointer
	dad	sp
	shld	(oldSP)
	lxi	sp,stackend	;local stack

	lxi	h,msgHeader	; Print a greeting
	call	PrintString0

	lda	(DFCB+1)	; Check if we got a filename
	cpi	' '
	jz	NoFileName

	lxi  	D,DFCB		; Then open a file
	xra	a		;a=0 Start at block 0
	sta	(DFCBcr)
	mvi 	C,OPENFIL
	call	BDOS		; Returns a in 255 if error opening
	inr 	a
	jz	FailOpenFile

	mvi 	a,SOH		; Start packet with SOH
	sta 	(packet)
	mvi 	a,1		; The first packet is number 1
	sta 	(pktNo)
	mvi 	a,255-1		; also store the 1-complement of it
	sta 	(pktNo1c)

	call	ReadSector
	ora	a
	jnz	Done

WaitForReply:
 	mvi 	a,60		; 60 Seconds of timeout before giving up
 	call	GetCharTmo
 	jc	Failure
 	cpi 	CAN		; Downloader wants to abort transfer?
 	jz	Cancelled	; Yes, then we're also done
 	cpi	NAK		; Downloader want retransmit?
 	jz	GotNAK		; Yes
	cpi	ACK		; Downloader approved and wants next pkt?
	jz	GotACK
	jmp	WaitForReply	; Got something else. Go back and get another

GotNAK:
TransmitPacket:
	mvi	a,132		; (Re-)Transmit the current packet
	mov	b,a
	lxi	h,packet
xmitloop:
	mov	c,m
	push	h
	push	b
	call	CONOUT
	pop	b
	pop	h
	inx	h
	dcr	b
	jnz	xmitloop
	jmp	WaitForReply

GotACK:
	lxi	h,pktNo		; Update the packet counters
	inr	m
	lxi	h,pktNo1c
	dcr	m

	call	ReadSector	; Fetch the next sector
	ora	a
	jnz	Done
	jmp	TransmitPacket

;
; Read the next sector from disk into the packet buffer.
; also calculate the checksum for the sector
; Returns 0 in a if OK, 1 in a if EOF
;
ReadSector:
 	lxi	d,data		; Set DMa address to the packet data buff
	mvi 	c,PUTDMa
	call	BDOS
	lxi  	d,DFCB		; File Description Block
	mvi 	c,READSEQ
	call	BDOS		; Returns a=0 if ok, a=1 if EOF

	push	psw		; Need to save a for later

	lxi	h,data		; Calculate checksum of the 128 data bytes
	mvi	b,128
	xra	a
csloop:	add	m		; Just add up the bytes
	inx	h
	dcr	b
	jnz	csloop
	sta	(chksum)	; and store it in chksum

	pop	psw		; Restore a holding the result code
	ret

CloseFile:
	lxi  	D,DFCB		; Close the file
	mvi 	C,CLOSEFIL
	jmp	BDOS

Done:
DoneLoop:
	mov	C,EOT		; Tell receiver we're done
	call	CONOUT
 	mvi 	a,10		; wait aprox 10 seconds
 	call	GetCharTmo
 	jc	DoneTmo
	mvi	C,EOT		; Tell receiver we're done again
	call	CONOUT

DoneTmo:
 	mvi 	a,1
 	call	GetCharTmo	; Delay 1 second

	lxi	h,msgSucces1	; Print success message and filename
	call	PrintString0
	call	PrintFilename
	lxi	h,msgSucces2
	jmp	Die

FailOpenFile:
	lxi	h,msgFailOpn
	call	PrintString0
	call	PrintFilename
	lxi	h,msgCRLF
	jmp	Exit

NoFileName:
	lxi	h,msgNoFile
	call 	PrintString0	; Prints message and exits from program
	jmp	Exit

Failure:
	lxi	h,msgFailure
	jmp	Die

Cancelled:
	lxi	h,msgCancel
	jmp	Die

Die:
	call 	PrintString0	; Prints message and exits from program
	call	CloseFile
Exit:
	lhld	(oldSP)		;restore original stack
   	sphl
	ret

;
; Waits for up to a seconds for a character to become available and
; returns it in a without echo and Carry clear. If timeout then Carry
; it set.
;
;
;Had to tweak the timing a bit to get it about right on a v20-mbc @8mhz. It seems
;the CONST routine takes a lot longer (relative term) than on a conventional hardware i/o
;serial port
;
GetCharTmo:
	mov 	b,a		;a=no of seconds to poll for
GCtmoa:
	push	b	
	mvi	b,255
GCtmob:
	push	b	
	mvi	b,103		;on v20-mbc @ 8mhz, about 1 sec inner loop
GCtmoc:
	push	b	
	call	CONST
	cpi	00h		; a char available?
	jnz	GotChar		; Yes, get out of loop
	lhld	0		; Waste some cycles
	lhld	0		; ...
	pop	b
	dcr	b
	jnz	GCtmoc
	pop	b
	dcr	b
	jnz	GCtmob
	pop	b
	dcr	b
	jnz	GCtmoa
	stc 			; Set carry signals timeout
	ret

GotChar:
	pop	b
	pop	b
	pop	b
	call	CONIN
	ora 	a 		; Clear Carry signals success
	ret

;
; Print message pointed top HL until 0
;
PrintString0:
	mov	a,m
	ora	a		; Check if got zero?
	rz			; If zero return to caller
	mov 	c,a
	call	CONOUT		; else print the character
	inx	h
	jmp	PrintString0

;
; Prints the 'B' bytes long string pointed to by HL, but no spaces
;
PrintNoSpaceB:
	push	b
	mov	a,m		; Get character pointed to by HL
	mov	C,a
	cpi	' '		; Don't print spaces
	cnz	CONOUT
	pop	b
	inx	h	; advance to next character
	dcr	b
	jnz	PrintNoSpaceB	; Loop until B=0
	ret
;
PrintFilename:
	lda	(DFCB)	; Print the drive
	ora	a		; If Default drive,then...
	jz	PFnoDrive	; ...don't print the drive name
	adi	'@'		; The drives are numbered 1-16...
	mov	c,a		; ...so we need to offset to get a..P
	call	CONOUT

	mvi	c,':'		; Print colon after the drive name
	call	CONOUT

PFnoDrive:
	lxi	h,DFCB+1	; Start of filename in File Control Block
	mvi	b,8		; First part is 8 characters
	call	PrintNoSpaceB

	mvi	c,'.'		; Print the dot between filname & extension
	call	CONOUT

	mvi 	b,3		; Then print the extension
	call	PrintNoSpaceB
	ret

;
; BIOS jump table vectors to be patched
;
CONST:	jmp 	0ff06h	; a=0 if no character is ready, 0FFh if one is
CONIN:	jmp	0ff09h	; Wait until character ready available and return in a
CONOUT:	jmp	0ff0ch	; Write the character in C to the screen

;
; Message strings
;
msgHeader: DB 	'CP/M XS8080 - Xmodem Send v0.1 / coopzone 2021',CR,LF,0
msgFailure:DB	CR,LF,'Transmssion failed',CR,LF,0
msgCancel: DB	CR,LF,'Transmission cancelled',CR,LF,0
msgSucces1:DB	CR,LF,'File ',0
msgSucces2:DB	' sent successfully',CR,LF,0
msgFailOpn:DB	'Failed opening file ',0
msgNoFile: DB	'Filename expeced',CR,LF,0
msgCRLF:   DB	CR,LF,0

;
; Variables
;
oldSP:	 DS	2	; The orginal SP to be restored before exiting

packet:	 DS 	1	; SOH
pktNo:	 DS 	1 	; Current packet Number
pktNo1c: DS 	1 	; Current packet Number 1-complemented
data:	 DS	128	; data*128,
chksum:	 DS	1 	; chksum

stack:	 DS 	256
stackend: EQU $

	END
