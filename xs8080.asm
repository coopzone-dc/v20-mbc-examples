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
;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;SOFTWARE.
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
;GETCON: EQU	1	; Console Input A<char
;OUTCON: EQU	2	; Console Output E=char
;GETRDR: EQU	3	; Reader Input A<char
;PUNCH:	 EQU	4	; Punch Output E=char
;LIST:	 EQU	5	; List Output E=char
;DIRCIO: EQU	6	; Direct Console I/O E=char/FE/FF A<char
;GETIOB: EQU	7	; Get I/O Byte A<value
;SETIOB: EQU	8	; Set I/O Byte E=value
;PRTSTR: EQU	9	; Print $ String DE=addr
;RDBUFF: EQU	10	; Read Console Buffer DE=addr
;GETCSTS:EQU	11	; Get Console Status A<status (00empty FFdata)
;GETVER: EQU	12	; Return Version Number HL<version
;RSTDSK: EQU	13	; Reset Disk System
;SETDSK: EQU	14	; Select Disk E=diskno
OPENFIL: EQU	15	; Open File DE=FCBaddr A<handle (FFerr)
CLOSEFIL:EQU	16	; Close File DE=FCBaddr A<handle (FFerr)
;GETFST: EQU	17	; Search for First DE=FCBaddr A<handle (FFerr)
;GETNXT: EQU	18	; Search for Next A<handle (FFerr)
;DELFILE:EQU	19	; Delete File DE=FCBaddr A<handle (FFerr)
READSEQ: EQU	20	; Read Sequential DE=FCBaddr A<status (00ok)
;WRTSEQ: EQU	21	; Write Sequential DE=FCBaddr A<status (00ok)
;FCREATE:EQU	22	; Make File  DE=FCBaddr A<handle (FFerr)
;RENFILE:EQU	23	; Rename File DE=FCBaddr A<handle (FFerr)
;GETLOG: EQU	24	; Return Log-in Vector HL<bitmap
;GETCRNT:EQU	25	; Return Current Disk A<diskno
PUTDMA:	 EQU	26	; Set DMA Address DE=addr
;GETALOC:EQU	27	; Get Addr (ALLOC) HL<addr
;WRTPRTD:EQU	28	; Write Protect Current Disk
;GETROV: EQU	29	; Get Read-Only Vector HL<bitmap
;SETATTR:EQU	30	; Set File Attributes DE=FCBaddr A<handle
;GETPARM:EQU	31	; Get Addr (DISKPARMS) A<DPBaddr
;GETUSER:EQU	32	; Set/Get User Code E=code (FFget) A<value
;RDRANDOM:EQU	33	; Read Random DE=FCBaddr A<status
;WTRANDOM:EQU	34	; Write Random DE=FCBaddr A<status
;FILESIZE:EQU	35	; Compute File Size DE=FCBaddr
;SETRAN: EQU	36	; Set Random Record DE=FCBaddr
;LOGOFF: EQU	37	; Reset Drive DE=drivevector
;WTSPECL:EQU	40	; Write Random with Zero Fill DE=FCBaddr A<status

;
; ASCII codes
;
LF:	EQU	'J'-40h	; ^J LF
CR: 	EQU 	'M'-40h	; ^M CR/ENTER
SOH:	EQU	'A'-40h	; ^A CTRL-A
EOT:	EQU	'D'-40h	; ^D = End of Transmission
ACK:	EQU	'F'-40h	; ^F = Positive Acknowledgement
NAK:	EQU	'U'-40h	; ^U = Negative Acknowledgement
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

	lxi  	D,DFCB		; Then create new file
	xra	a		;a=0 Start at block 0
	sta	(DFCBcr)
	mvi 	C,OPENFIL
	call	BDOS		; Returns A in 255 if error opening
	inr 	A
	jz	FailOpenFile

	mvi 	A,SOH		; Start packet with SOH
	sta 	(packet)
	mvi 	A,1		; The first packet is number 1
	sta 	(pktNo)
	mvi 	A,255-1		; Also store the 1-complement of it
	sta 	(pktNo1c)

	call	ReadSector
	ora	A
	jnz	Done

WaitForReply:
 	mvi 	A,60		; 60 Seconds of timeout before giving up
 	call	GetCharTmo
 	jc	Failure
 	cpi 	CAN		; Downloader wants to abort transfer?
 	jz	Cancelled	; Yes, then we're also done
 	cpi	NAK		; Downloader want retransmit?
 	jz	GotNAK	; Yes
	cpi	ACK		; Downloader approved and wants next pkt?
	jz	GotACK
	jmp	WaitForReply	; Got something else. Go back and get another

GotNAK:
TransmitPacket:
	mvi	A,132		; (Re-)Transmit the current packet
	mov	B,A
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
	ora	A
	jnz	Done
	jmp	TransmitPacket

;
; Read the next sector from disk into the packet buffer.
; Also calculate the checksum for the sector
; Returns 0 in A if OK, 1 in A if EOF
;
ReadSector:
 	lxi	D,data		; Set DMA address to the packet data buff
	mvi 	C,PUTDMA
	call	BDOS
	lxi  	D,DFCB		; File Description Block
	mvi 	C,READSEQ
	call	BDOS		; Returns A=0 if ok, A=1 if EOF

	push	psw		; Need to save A for later

	lxi	h,data		; Calculate checksum of the 128 data bytes
	mvi	b,128
	xra	a
csloop:	add	m		; Just add up the bytes
	inx	h
	dcr	b
	jnz	csloop
	sta	(chksum)	; And store it in chksum

	pop	psw		; Restore A holding the result code

	ret

CloseFile:
	lxi  	D,DFCB		; Close the file
	mvi 	C,CLOSEFIL
	jmp	BDOS

Done:
DoneLoop:
	mov	C,EOT		; Tell receiver we're done
	call	CONOUT
 	mvi 	A,10
 	call	GetCharTmo
 	jc	DoneTmo
	mvi	C,EOT		; Tell receiver we're done again
	call	CONOUT

DoneTmo:
 	mvi 	A,1
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
	lhld	(oldSP)
   	sphl
	ret

;
; Waits for up to A seconds for a character to become available and
; returns it in A without echo and Carry clear. If timeout then Carry
; it set.
;
GetCharTmo:
	mov 	B,A
GCtmoa:
	push	B
	mvi	B,255
GCtmob:
	push	B
	mvi	B,255
GCtmoc:
	push	B
	call	CONST
	cpi	00h		; A char available?
	jnz	GotChar		; Yes, get out of loop
	lhld	0		; Waste some cycles
	lhld	0		; ...
	lhld	0		; ...
	lhld	0		; ...
	lhld	0		; ...
	lhld	0		; ...
	pop	B
	dcr	b
	jnz	GCtmoc
	pop	B
	dcr	b
	jnz	GCtmob
	pop	B
	dcr	b
	jnz	GCtmoa
	stc 			; Set carry signals timeout
	ret

GotChar:
	pop	B
	pop	B
	pop	B
	call	CONIN
	ora 	A 		; Clear Carry signals success
	ret

;
; Print message pointed top HL until 0
;
PrintString0:
	mov	a,m
	ora	A		; Check if got zero?
	rz			; If zero return to caller
	mov 	C,A
	call	CONOUT		; else print the character
	inx	h
	jmp	PrintString0

;
; Prints the 'B' bytes long string pointed to by HL, but no spaces
;
PrintNoSpaceB:
	push	B
	mov	a,m		; Get character pointed to by HL
	mov	C,A
	cpi	' '		; Don't print spaces
	cnz	CONOUT
	pop	B
	inx	H		; Advance to next character
	dcr	b
	jnz	PrintNoSpaceB	; Loop until B=0
	ret
;
;
;
PrintFilename:
	lda	(DFCB)	; Print the drive
	ora	A		; If Default drive,then...
	jz	PFnoDrive	; ...don't print the drive name
	adi	'@'		; The drives are numbered 1-16...
	mov	C,A		; ...so we need to offset to get A..P
	call	CONOUT

	mvi	C,':'		; Print colon after the drive name
	call	CONOUT

PFnoDrive:
	lxi	h,DFCB+1	; Start of filename in File Control Block
	mvi	B,8		; First part is 8 characters
	call	PrintNoSpaceB

	mvi	C,'.'		; Print the dot between filname & extension
	call	CONOUT

	mvi 	B,3		; Then print the extension
	call	PrintNoSpaceB
	ret

;
; BIOS jump table vectors to be patched
;
CONST:	jmp 	0ff06h	; A=0 if no character is ready, 0FFh if one is
CONIN:	jmp	0ff09h	; Wait until character ready available and return in A
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
