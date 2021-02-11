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
;OPENFIL:EQU	15	; Open File DE=FCBaddr A<handle (FFerr)
CLOSEFIL:EQU	16	; Close File DE=FCBaddr A<handle (FFerr)
;GETFST: EQU	17	; Search for First DE=FCBaddr A<handle (FFerr)
;GETNXT: EQU	18	; Search for Next A<handle (FFerr)
DELFILE: EQU	19	; Delete File DE=FCBaddr A<handle (FFerr)
;READSEQ:EQU	20	; Read Sequential DE=FCBaddr A<status (00ok)
WRTSEQ:  EQU	21	; Write Sequential DE=FCBaddr A<status (00ok)
FCREATE: EQU	22	; Make File  DE=FCBaddr A<handle (FFerr)
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

	lxi	h,0		;save stack
	dad	sp
	shld	(oldSP)
	lxi	SP,stackend	;local stack

	lxi	h,msgHeader	; Print a greeting
	call	PrintString0

	lda	(DFCB+1)	; Check if we got a filename
	cpi	' '
	jz	NoFileName

	lxi  	d,DFCB		; Then create new file
	xra	a		;A,0 Start at block 0
	sta	(DFCBcr)
	mvi  	c,FCREATE
	call	BDOS		; Returns A in 255 if error opening
	cpi	3		;2=file exists,3=created,255=disk full
	jz	xget		;exit file already exits
	lxi	h,msgFailex
	call	PrintString0
	call	PrintFilename
	lxi	h,msgCRLF
	call	PrintString0
	jmp	exit
;
xget:	mvi 	a,1		; The first packet is number 1
	sta 	(pktNo)
	mvi	a,255-1		; Also store the 1-complement of it
	sta 	(pktNo1c)

GetNewPacket:
	mvi	a,12		; We retry 12x5s = 60 sec times before giving up
	sta 	(retrycnt)

NPloop:
	mvi 	a,5		; 5 Seconds of timeout before each new block
	call	GetCharTmo
	jnc	NotPacketTimeout

	lxi	h,retrycnt	; Reached max number of retries?
	dcr	m
	jz	Failure		; Yes, print message and exit

	mvi	c,NAK		; Send a NAK to the uploader
	call	CONOUT
	jmp 	NPloop

NotPacketTimeout:
	cpi	EOT		; Did uploader say we're finished?
	jz	Done		; Yes, then we're done
	cpi 	CAN		; Uploader wants to abort transfer?
	jz	Cancelled	; Yes, then we're also done
	cpi	SOH		; Did we get a start-of-new-packet?
	jnz	NPloop		; No, go back and try again

	lxi	h,packet	; Save the received char into the...
	mov	m,a		; ...packet buffer and...
	inx 	h		; ...point to the next location
	push 	h

	mvi	b,131		; Get 131 more characters for a full packet
GetRestOfPacket:
	push 	b
	mvi	a,1
	call	GetCharTmo
	pop 	b

	pop	h		; Save the received char into the...
	mov	m,a		; ...packet buffer and...
	inx 	h		; ...point to the next location
	push 	h	

	dcr	b
	jnz	GetRestOfPacket

	pop	h		; Added to prevent stack overflow previously caused fail at 122 blocks
	lxi	h,packet+3	; Calculate checksum from 128 bytes of data
	mvi	b,128
	xra	a		;A,0
csloop:	add	m		; Just add up the bytes
	inx	h
	dcr	b
	jnz	csloop

	xra	m		; HL points to the received checksum so
	jnz	Failure		; by xoring it to our sum we check for equality

	lda	(pktNo)		; Check if agreement of packet numbers
	mov	c,a
	lda	(packet+1)
	cmp	c
	jnz	Failure

	lda	(pktNo1c)	; Check if agreement of 1-compl packet numbers
	mov	c,a
	lda	(packet+2)
	cmp	c
	jnz	Failure

	lxi	d,packet+3	; Reset DMA address to the packet data buff
	mvi 	c,PUTDMA
	call	BDOS
	lxi	d,DFCB		; File Description Block
	mvi	c,WRTSEQ
	call	BDOS		; Returns A=0 if ok
	cpi	0
	jnz	FailWrite

	lxi	h,pktNo		; Update the packet counters
	inr	m
	lxi	h,pktNo1c
	dcr	m

	mvi 	c,ACK		; Tell uploader that we're happy with with
	call	CONOUT		; packet and go back and fetch some more
	jmp	GetNewPacket

Done:
	call	CloseFile
	mvi	c,ACK		; Tell uploader we're done
	call	CONOUT
	lxi	h,msgSucces1	; Print success message and filename
	call	PrintString0
	call	PrintFilename
	lxi	h,msgSucces2
	call 	PrintString0
	jmp	Exit

FailCreateFile:
	lxi	h,msgFailCre
	call	PrintString0
	call	PrintFilename
	lxi	h,msgCRLF
	call	PrintString0
	jmp	Exit

FailWrite:
	lxi	h,msgFailWrt
	jmp	Die

NoFileName:
	lxi	h,msgNoFile
	call 	PrintString0
	jmp	Exit

Failure:
	lxi	h,msgFailure
	jmp	Die
Cancelled:
	lxi	h,msgCancel
	jmp	Die

CloseFile:
	lxi  	d,DFCB		; Close the file
	mvi 	c,CLOSEFIL
	call	BDOS
	ret

Die:
	call 	PrintString0	; Prints message and exits from program
	call	CloseFile
	lxi	d,DFCB		; Delete file first
	mvi 	c,DELFILE	;
	call	BDOS		; Returns A=255 if error, but we don't care

Exit:
	lhld	(oldSP)		; get old stack
	sphl			; into SP
	ret


;
; Waits for up to A seconds for a character to become available and
; returns it in A without echo and Carry clear. If timeout then Carry
; it set.
;
;Had to tweak the timing a bit to get it about right on a v20-mbc @8mhz. It seems
;the CONST routine takes a lot longer (relative term) than on a conventional hardware i/o 
;serial port
;
GetCharTmo:
	mov	b,a		;a=number of seconds to poll for
GCtmoa:
	push	B
	mvi	b,255
GCtmob:
	push	B
	mvi	b,103		;around 1sec innerloop, v20-mbc @8mhz
GCtmoc:
	push	b
	call	CONST
	cpi	00h		; A char available?
	jnz	GotChar		; Yes, get out of loop
	lhld	0		; Waste some cycles
	lhld	0		;...
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
	call	CONIN
	pop	b
	pop	b
	pop	b
	ora	a 		; Clear Carry signals success
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
	mov	c,a	
	cpi	' '		; Don't print spaces
	cnz	CONOUT
	pop	b
	inx	h		; Advance to next character
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
msgHeader: 	DB 	'CP/M XR8080 - Xmodem receive v0.3 / coopzone 2021',CR,LF,0
msgFailWrt:	DB	CR,LF,'Failed writing to disk',CR,LF,0
msgFailure:	DB	CR,LF,'Transmssion failed',CR,LF,0
msgCancel: 	DB	CR,LF,'Transmission cancelled',CR,LF,0
msgSucces1:	DB	CR,LF,'File ',0
msgSucces2:	DB	' received successfully',CR,LF,0
msgFailCre:	DB	'Failed creating file named ',0
msgFailex:	DB	'Failed file already exists ',0
msgNoFile: 	DB	'Filename expeced',CR,LF,0
msgCRLF:	DB	CR,LF,0

;
; Variables
;
oldSP:	 DS	2	; The orginal SP to be restored before exiting
retrycnt:DS 	1	; Counter for retries before giving up
chksum:	 DS	1	; For claculating the ckecksum of the packet
pktNo:	 DS 	1 	; Current packet Number
pktNo1c: DS 	1 	; Current packet Number 1-complemented
packet:	 DS 	1	; SOH
	 DS	1	; PacketN
	 DS	1	; -PacketNo,
	 DS	128	; data*128,
	 DS	1 	; chksum

stack:	 DS 	256
stackend: EQU $

	END
