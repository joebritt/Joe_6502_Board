
;
; 65C816 Board
; Joe Britt	original LED sign 10/2001
;		modified for new '816 board 04/2003
;
;	RAM:	$0000 - $7FFF	32KB
;
;	6551:	$BF00 - $BF03
;
;	VIA:	$BE00 - $BE0F	
;
;	ROM:	$C000 - $FFFF	16KB
;
; !!! NOTE !!!
;
; Addresses are only partially decoded, so don't access any
; other areas!  Other areas can cause multiple chip selects
; to assert.
;

; ------------------------------------------------------------------
;                      _              _
;   ___ ___  _ __  ___| |_ __ _ _ __ | |_ ___
;  / __/ _ \| '_ \/ __| __/ _` | '_ \| __/ __|
; | (_| (_) | | | \__ \ || (_| | | | | |_\__ \
;  \___\___/|_| |_|___/\__\__,_|_| |_|\__|___/
;
;

; --------
; HARDWARE
; --------

ROMBASE	.equ	$C000

ACIABASE .equ	$BF00
DATA	.equ	0
STAT	.equ	1
CMD	.equ	2
CTL	.equ	3

RAMBASE	.equ	$0000

; -------
; MONITOR
; -------

LOC0	.equ	$00
LOC1	.equ	$01
BASL	.equ	$28
BASH	.equ	$29
BAS2L	.equ	$2a
BAS2H	.equ	$2b
H2	.equ	$2c
LMNEM	.equ	$2c
RTNL	.equ	$2c
V2	.equ	$2d
RMNEM	.equ	$2d
RTNH	.equ	$2d
MASK	.equ	$2e
CHKSUM	.equ	$2e
FORMAT	.equ	$2e
LASTIN	.equ	$2f
LENGTH	.equ	$2f
SIGN	.equ	$2f
COLOR	.equ	$30
MODE	.equ	$31
INVFLG	.equ	$32
PROMPT	.equ	$33
YSAV	.equ	$34
YSAV1	.equ	$35
CSWL	.equ	$36
CSWH	.equ	$37
KSWL	.equ	$38
KSWH	.equ	$39
PCL	.equ	$3a
PCH	.equ	$3b
XQT	.equ	$3c
A1L	.equ	$3c
A1H	.equ	$3d
A2L	.equ	$3e
A2H	.equ	$3f
A3L	.equ	$40
A3H	.equ	$41
A4L	.equ	$42
A4H	.equ	$43
A5L	.equ	$44
A5H	.equ	$45
MON_ACC	.equ	$45
XREG	.equ	$46
YREG	.equ	$47
STATUS	.equ	$48
SPNT	.equ	$49
RNDL	.equ	$4e
RNDH	.equ	$4f
ACL	.equ	$50
ACH	.equ	$51
XTNDL	.equ	$52
XTNDH	.equ	$53
AUXL	.equ	$54
AUXH	.equ	$55
PICK	.equ	$95

IN	.equ	$0200
USRADR	.equ	$03f8
NMI	.equ	$03fb
IRQLOC	.equ	$03fe



; ------------------------------------------------------------------
;  _                 _
; | |__   ___   ___ | |_
; | '_ \ / _ \ / _ \| __|
; | |_) | (_) | (_) | |_
; |_.__/ \___/ \___/ \__|
;
;

	.org	$ROMBASE
RESET_HANDLER:

	; waste some time, in case /RESET doesn't settle
	;  right away...

	ldy	#$FF
zero:
	ldx	#$FF
one:
	nop
	nop
	nop
	nop
	dex
	bne	one
	dey
	bne	zero


initACIA:
	sta	ACIABASE+STAT	; soft reset
	lda	#$8b		; no par, normal, no ints, DTR active
	sta	ACIABASE+CMD
	lda	#$1e		; 9600, 1 stop, 8 bits, use BRG
	sta	ACIABASE+CTL

	ldy	#0
Greet:
	lda	GreetStr,Y
	beq	Greeted
	jsr	COUT1
	iny
	jmp	Greet
Greeted:

	jmp	RESET	


GreetStr:
	.byte	$0d,$0a,$0d,$0a,"** Joe"
	.byte	$27,"s Simple 6502 Board **"
	.byte	$0d,$0a,$00



; XMDMDP	16 bits, xmodem Data Pointer, src or dst
; XMDMLEN	16 bits, decoded file len
; XMDMBLK	 8 bits, xmodem sequence #
; XMDMCKSUM	 8 bits, checksum
; XMDMCNT	16 bits, used when waiting for SOH

XMDMDP		.equ	$10
XMDMLEN		.equ	$12
XMDMBLK		.equ	$14
XMDMCKSUM	.equ	$15
XMDMCNT		.equ	$18

; ================================================================
XmodemRcv:
	pha
	tya
	pha
	txa
	pha
	
	ldy	#0
xrcv_notice:
	lda	XrcvStr,Y
	beq	xrcv_start	
	jsr	COUT
	iny
	jmp	xrcv_notice	

XrcvStr:
	.byte	$0d,$0a,"READY TO RECEIVE"
	.byte	" VIA XMODEM...",$00

	; --- Send the initial <nak> to get things rolling ---
xrcv_start:
	lda	#$15		; <nak>
	jsr	COUT2

	lda	#0
	sta	XMDMCNT
	sta	XMDMCNT+1

xrcv_wait_first:
	clc
	lda	XMDMCNT
	adc	#1
	sta	XMDMCNT
	lda	XMDMCNT+1
	adc	#1
	sta	XMDMCNT+1

	lda	XMDMCNT
	bne	xrcv_check_first
	lda	XMDMCNT+1
	beq	xrcv_start	; go ping the other guy again
	
xrcv_check_first:
	lda	#$08
	bit	ACIABASE+STAT
	beq	xrcv_wait_first

	lda	ACIABASE+DATA
	cmp	#$01		; <soh>?
	bne	xrcv_start	; no, go ping the other guy again

	jmp	xrcv_got_soh

	; --- OK, now start xferring normally ---

xrcv_nak:
	lda	#$15		; <nak>
	jsr	COUT2
	jmp	xrcv_main

xrcv_ack:
	lda	#$06		; <ack>
	jsr	COUT2

xrcv_main:

xrcv_wait_soh:
	lda	#$08
	bit	ACIABASE+STAT
	beq	xrcv_wait_soh	

	lda	ACIABASE+DATA
	cmp	#$04		; <eot>?
	beq	xrcv_done
	cmp	#$01		; <soh>?
	bne	xrcv_wait_soh

xrcv_got_soh:
	jsr	RDKEY		; this will be blk #
	cmp	XMDMBLK
	bne	xrcv_newblk

	; --- make XMDMDP -> last 128-byte block ---

	sec	
	lda	XMDMDP	
	sbc	#128	
	sta	XMDMDP
	lda	XMDMDP+1	
	sbc	#0		; data ptr points to last 128 bytes
	sta	XMDMDP+1

	clc
	lda	#128
	adc	XMDMLEN
	sta	XMDMLEN
	lda	#0
	adc	XMDMLEN+1
	sta	XMDMLEN+1	; 128 more bytes

xrcv_newblk:
	sta	XMDMBLK
	jsr	RDKEY		; this will be ~blk #

	lda	#0
	sta	XMDMCKSUM	; init checksum

	ldy	#0		; y is index into block
	ldx	#128		; gonna read 128 byte block
xrcv_loop:
	jsr	RDKEY		; get byte

	pha			; hang on to it for after checksum
	
	clc
	adc	XMDMCKSUM
	sta	XMDMCKSUM

	lda	XMDMLEN		; still OK to update len?
	bne	xrcv_upd_len
	lda	XMDMLEN+1
	beq	xrcv_next_1

xrcv_upd_len:
	sec
	lda	XMDMLEN	
	sbc	#1	
	sta	XMDMLEN
	lda	XMDMLEN+1	
	sbc	#0
	sta	XMDMLEN+1	; count down as we get bytes 

	pla
	sta	(XMDMDP),y	; pull it & store it
	iny
	dex
	bne	xrcv_loop
	jmp	xrcv_vfy

xrcv_next_1:
	pla			; no more room, just pull it & discard
	dex
	bne	xrcv_loop

	; --- do the checksums match? ---

xrcv_vfy:
	jsr	RDKEY		; this will be the sent checksum
	cmp	XMDMCKSUM
	bne	xrcv_nak

	; --- make XMDMDP -> next 128-byte block ---

	clc
	lda	#128
	adc	XMDMDP
	sta	XMDMDP
	lda	#0
	adc	XMDMDP+1	; data ptr points to next 128 bytes
	sta	XMDMDP+1

	jmp	xrcv_ack

xrcv_done:

xrcv_exit:
	pla
	tax
	pla
	tay
	pla
	rts


; ================================================================
XmodemSend:
	pha
	tya
	pha
	txa
	pha

	ldy	#0
xsend_notice:
	lda	XsendStr,Y
	beq	xsend_start	
	jsr	COUT
	iny
	jmp	xsend_notice	

XsendStr:
	.byte	$0d,$0a,"SENDING VIA XMODEM...",$00


	; --- Wait for the initial <nak> to get things rolling ---
xsend_start:
	jsr	RDKEY
	cmp	#$15
	bne	xsend_start

	; --- Send 1st Block ---

xsend_first_blk:
	lda	#1
	sta	XMDMBLK

	; last block may be padded out to 128 bytes with $00's

	; ===============
xsend_blk:
	lda	#0
	sta	XMDMCKSUM

	tay			; Y is index into xmit buffer, runs 0->127

	; each block looks like:
	; <SOH><blk#><~blk#><--128 bytes data--><8 bit cksum>

	lda	#$01
	jsr	COUT2		; SOH = $01
	lda	XMDMBLK
	jsr	COUT2		; blk #
	eor	#$FF		; invert
	jsr	COUT2		; ~blk #

	ldx	#128
xsend_data:
	lda	XMDMLEN
	bne	xsend_real
	lda	XMDMLEN+1
	beq	xsend_d1	; is there data left to send?

xsend_real:
	sec
	lda	XMDMLEN	
	sbc	#1	
	sta	XMDMLEN
	lda	XMDMLEN+1	
	sbc	#0
	sta	XMDMLEN+1	; update the bytes-to-send count

	lda	(XMDMDP),y

xsend_d1:
	pha
	clc
	adc	XMDMCKSUM
	sta	XMDMCKSUM
	
	pla
	jsr	COUT2

	iny			; next byte in 128-byte block

	dex
	bne	xsend_data	; sent 128 bytes yet?

	lda	XMDMCKSUM
	jsr	COUT2

	jsr	RDKEY		; <ack> ($06) or <nak> ($15)?
	cmp	#$06
	bne	xsend_blk
	; ===============

	clc
	lda	#128
	adc	XMDMDP
	sta	XMDMDP
	lda	#0
	adc	XMDMDP+1	; data ptr points to next 128 bytes
	sta	XMDMDP+1
	
	inc	XMDMBLK		; next block...

	lda	XMDMLEN
	bne	xsend_blk
	lda	XMDMLEN+1
	bne	xsend_blk	; is there data left to send?

xsend_done:
	lda	#$04		; $04 = <eot>
	jsr	COUT2

	pla
	tax
	pla
	tay
	pla
	rts


XmodemSetup:
	clc			; inc A2
	lda	A2L
	adc	#1
	sta	A2L
	lda	A2H
	adc	#0
	sta	A2H

	sec
	lda	A2L
	sbc	A1L
	sta	XMDMLEN
	lda	A2H
	sbc	A1H
	sta	XMDMLEN+1
	bmi	ERROR		; dst > src?

	lda	A1L
	sta	XMDMDP
	lda	A1H
	sta	XMDMDP+1

	jsr	CROUT
	lda	XMDMLEN+1
	jsr	PRBYTE
	lda	XMDMLEN
	jsr	PRBYTE		; print # bytes sending
	clc
	rts


ERROR:
	lda	#'E'+$80
	jsr	COUT
	lda	#'R'+$80
	jsr	COUT
	lda	#'R'+$80
	jsr	COUT
	jsr	CROUT
	sec
	rts


; Use this to boot into a BASIC program stored in ROM

;BASIC_BOOT:
;BASIC_BOOT_END:

;LOAD_BOOT:
;	lda	#(BASIC_BOOT&$FF)
;	sta	XMDMDP
;	lda	#(BASIC_BOOT/256)
;	sta	XMDMDP+1

;	lda	#($07FE&$FF)
;	sta	XMDMLEN
;	lda	#($07FE/256)
;	sta	XMDMLEN+1

;	ldx	#48
;move_blocks:
;	ldy	#0
;move_blk:
;	lda	(XMDMDP),y
;	sta	(XMDMLEN),y
;	iny
;	cpy	#130		; gross cheat to get last 2 bytes
;	bne	move_blk
	
;	clc
;	lda	#128	
;	adc	XMDMDP	
;	sta	XMDMDP
;	lda	#0
;	adc	XMDMDP+1
;	sta	XMDMDP+1

;	clc
;	lda	#128	
;	adc	XMDMLEN	
;	sta	XMDMLEN
;	lda	#0
;	adc	XMDMLEN+1
;	sta	XMDMLEN+1

;	dex
;	bne	move_blocks

;	lda	$7FF
;	sta	ACC+1
;	lda	$7FE
;	sta	ACC		; recover ACC from just below LOMEM

;	jsr	LOAD2

;	rts


; ------------------------------------------------------------------
;  ____    _    ____ ___ ____
; | __ )  / \  / ___|_ _/ ___|
; |  _ \ / _ \ \___ \| | |
; | |_) / ___ \ ___) | | |___
; |____/_/   \_\____/___\____|
;
;
; APPLE ][ INTEGER BASIC, BY WOZ
;
; Originally disassembled by Paul R. Santa-Maria, with reference
; to "What's Where in the Apple" by William F. Luebbert,
; Peeking at Call-A.P.P.L.E. Vol 2, 1979 pp44-61.
;
; The Paul R. Santa-Maria disassembly used constructs (for 16-bit 
; ops, some looping stuff) not available on other 6502 assemblers.
;
; So, I re-disassembled the E0, E8, and F0 Apple ][ ROMs with
; IDA Pro, and used Paul's disassembly as a guide.  Most of the
; comments and symbols were lifted from his disassembly.
;
; Traditional, with feeling.
;


; zero-page 

LOMEM		.equ $004A ;ptr: start of vars
HIMEM		.equ $004C ;ptr: end of BASIC program
NOUNSTKL	.equ $0050 ;noun stack low bytes (80-87)
SYNSTKH		.equ $0058 ;syntax stack high byte
NOUNSTKH	.equ $0078 ;noun stack high bytes (78-97)
SYNSTKL		.equ $0080 ;syntax stack low bytes (80-9F)
NOUNSTKC	.equ $00A0 ;noun stack counter (A0-BF)
TXTNDXSTK	.equ $00A8 ;text index stack (A8-C7)
TXTNDX		.equ $00C8 ;text index val (OUTVAL)
LEADBL		.equ $00C9 ;leading blanks index (YTEMP)
PP		.equ $00CA ;ptr: start of program
PV		.equ $00CC ;ptr: end of vars
ACC		.equ $00CE ;word: main accumulator
SRCH		.equ $00D0 ;ptr to search var tbl
TOKNDXSTK	.equ $00D1 ;token index stack (D1-F0)
SRCH2		.equ $00D2 ;second var search ptr
IFFLAG		.equ $00D4 ;IF/THEN fail flag
CRFLAG		.equ $00D5 ;carriage return flag
VERBNOW		.equ $00D6 ;verb currently in use
PRFLAG		.equ $00D7 ;print it now flag
XSAVE		.equ $00D8 ;temp Xreg save
RUNFLAG		.equ $00D9 ;run mode flag
AUX		.equ $00DA ;word: aux ctr
PR		.equ $00DC ;word: current line value
;*PN		.equ $00DE ;ptr to current noun
PX		.equ $00E0 ;ptr to current verb
P1	 	.equ $00E2 ;aux ptr 1 (delete line ptr)
P2		.equ $00E4 ;aux ptr 2 ...
;*  (line num adr) (next line num) (general flag)
P3		.equ $00E6 ;aux ptr 3 (next ptr)
TOKNDX		.equ $00F1 ;token index val
PCON		.equ $00F2 ;continue ptr (PRDEC low/high)
AUTOINC		.equ $00F4 ;auto line increment
AUTOLN		.equ $00F6 ;current auto line
AUTOFLAG	.equ $00F8 ;auto line mode flag ($FF = on)
CHAR		.equ $00F9 ;current char
LEADZR		.equ $00FA ;leading zeros index ($00,$A0,$B0)
FORNDX		.equ $00FB ;FOR-NEXT loop index
GOSUBNDX	.equ $00FC ;GOSUB index
SYNSTKDX	.equ $00FD ;syntax stack index val
SYNPAG		.equ $00FE ;ptr: syntax page
;*if SYNPAG+1 <> 0 then error condition exists

STACK		.equ $0100 ;6502 STACK

;*   GOSUB/RETURN usage

STK_00		.equ STACK+$00
STK_10		.equ STACK+$10
STK_20		.equ STACK+$20
STK_30		.equ STACK+$30

;*   FOR/NEXT/STEP usage

STK_40		.equ STACK+$40
STK_50		.equ STACK+$50
STK_60		.equ STACK+$60
STK_70		.equ STACK+$70
STK_80		.equ STACK+$80
STK_90		.equ STACK+$90
STK_A0		.equ STACK+$A0
STK_B0		.equ STACK+$B0
STK_C0		.equ STACK+$C0
STK_D0		.equ STACK+$D0

byte_0_1D	.equ $1d
word_0_1E	.equ $1e

WNDWDTH		.equ $21
CH		.equ $24
CV		.equ $25
GBAS		.equ $26

A1		.equ $3c
A2		.equ $3e

ETX		.equ $03	; ctl-C
LF		.equ $0A
CR		.equ $0D
SPC		.equ $20
DQT		.equ $22
SQT		.equ $27

		.org	$e000

BASIC:
		JSR	COLD		; set up HIMEM & LOMEM, do a NEW and a CLR

		LSR	RUNFLAG		; not running	
		LDY	#0
		STY	LEADZR		; no leading zeros for AUTOLN
		
		;jsr	LOAD_BOOT
		;jsr	CROUT
		;jmp	RUN

BASIC2:
		JMP	WARM


;    Z = unreferenced area
;    V = referenced in verb table
;   VO = referenced in verb table ONLY
; solo = one reference only (could be in-line)

SetPrompt:				; solo
		STA	PROMPT	
		JMP	COUT	

		RTS	


sub_0_E00C:			
		TXA			; print a trailing blank?
		AND	#$20
		BEQ	locret_0_E034	; -> rts


sub_0_E011:				; solo 
		LDA	#SPC+$80
		STA	P2	
		JMP	COUT	


LineWrapCheck:				; solo
		LDA	#$20		; check line length
LineWrapCheckNum:
		jmp	NextByte	; HACK HACK

		CMP	CH	
		BCS	NextByte	; line too short?
		LDA	#CR+$80		; A = CR
		LDY	#7		; print CR, then 4 blanks

PutCRAndSpaces:
		JSR	COUT	
		LDA	#SPC+$80	; A = blank
		DEY	
		BNE	PutCRAndSpaces	


NextByte:				; get next byte 16-bit ptr
		LDY	#0
		LDA	(P1),Y
		INC	P1
		BNE	locret_0_E034
		INC	P1+1	
locret_0_E034:				
		RTS	


; token $75 , (with token $74 LIST)
; e.g., LIST 5,30

COMMA_LIST:				; VO
		JSR	GET16BIT
		JSR	loc_0_E576
loc_0_E03B:				
		LDA	P1
		CMP	P3		; get C right	
		LDA	P1+1	
		SBC	P3+1		; computing length of program?  (HIMEM - PP?)
		BCS	locret_0_E034	
		JSR	UNPACK		; do this line
		JMP	loc_0_E03B	; do another line

; token $76 LIST
; list entire program

BAS_LIST:				; VO
		LDA	PP	
		STA	P1
		LDA	PP+1	
		STA	P1+1		; P1 = Program Pointer (bottom of program)
		LDA	HIMEM
		STA	P3	
		LDA	HIMEM+1	
		STA	P3+1		; P3 = HIMEM (top of program)
		BNE	loc_0_E03B	; effectively a BRA

; token $74 LIST
; specific lines or range
; e.g., LIST 10:  LIST 5,30

LISTNUM:				; VO
		JSR	GET16BIT
		JSR	sub_0_E56D
		LDA	P2	
		STA	P1
		LDA	P2+1	
		STA	P1+1	
		BCS	locret_0_E034


UNPACK:					; unpack tokens to mnemonics 
		STX	XSAVE	
		LDA	#SPC+$80
		STA	LEADZR	
		JSR	NextByte
		TYA	
loc_0_E077:		
		STA	P2	
		JSR	NextByte
		TAX	
		JSR	NextByte
		JSR	PRDEC		; print line #, A = hi byte, X = lo byte
loc_0_E083:	
		JSR	LineWrapCheck	
		STY	LEADZR	
		TAX	
		BPL	loc_0_E0A3
		ASL	A
		BPL	loc_0_E077
		LDA	P2	
		BNE	loc_0_E095
		JSR	sub_0_E011
loc_0_E095:
		TXA	
loc_0_E096:
		JSR	COUT		; print a char from the string literal
loc_0_E099:
		LDA	#$25
		JSR	LineWrapCheckNum
		TAX	
		BMI	loc_0_E096
		STA	P2	
loc_0_E0A3:
		CMP	#1
		BNE	loc_0_E0AC
		LDX	XSAVE
		JMP	CROUT		; done printing this line of the program!

loc_0_E0AC:
		PHA	
		STY	ACC
		LDX	#(SYNTABL2>>8)
		STX	ACC+1	
		CMP	#$51		; END token
		BCC	loc_0_E0BB
		DEC	ACC+1	
		SBC	#$50		; TAB token

loc_0_E0BB:			
		PHA	
		LDA	(ACC),Y

loc_0_E0BE:		
		TAX	
		DEY	
		LDA	(ACC),Y
		BPL	loc_0_E0BE
		CPX	#$C0
		BCS	loc_0_E0CC
		CPX	#0
		BMI	loc_0_E0BE

loc_0_E0CC:	
		TAX	
		PLA	
		SBC	#1		; carry is set
		BNE	loc_0_E0BB
		BIT	P2	
		BMI	loc_0_E0D9
		JSR	sub_0_EFF8

loc_0_E0D9:
		LDA	(ACC),Y
		BPL	loc_0_E0ED
		TAX	
		AND	#$3F
		STA	P2	
		CLC	
		ADC	#SPC+$80
		JSR	COUT	
		DEY	
		CPX	#$C0
		BCC	loc_0_E0D9

loc_0_E0ED:			
		JSR	sub_0_E00C
		PLA	
		CMP	#$5D		; 93 ]
		BEQ	loc_0_E099
		CMP	#$28		; 40 (
		BNE	loc_0_E083
		BEQ	loc_0_E099


; token $2A (
; e.g., substring  PRINT A$(12,14)

PAREN_SUBSTR:
		JSR	sub_0_E118
		STA	NOUNSTKL,X
		CMP	NOUNSTKH,X

loc_0_E102:		
		BCC	loc_0_E115

loc_0_E104:	
		LDY	#Err_String	; "STRING"
loc_0_E106:
		JMP	ERRMESS


; token $23 ,
; e.g., substring  PRINT A$(3,3)

COMMA_SUBSTR:				; VO
		JSR	GETBYTE
		CMP	NOUNSTKL,X
		BCC	loc_0_E104
		JSR	sub_0_EFE4
		STA	NOUNSTKH,X
loc_0_E115:
		JMP	loc_0_E823

sub_0_E118:		
		JSR	GETBYTE
		BEQ	loc_0_E104
		SEC	
		SBC	#1
		RTS	


; token $42 (
; string array is destination of data
; A$(1)="HELLO"

loc_0_E121:				; VO
		JSR	sub_0_E118
		STA	NOUNSTKL,X
		CLC	
		SBC	NOUNSTKH,X
		JMP	loc_0_E102

loc_0_E12C:		
		LDY	#Err_MemFull	; "MEM FULL"
		BNE	loc_0_E106


; token $43 ,
; next var in DIM statement is string
; DIM X(5),A$(5)

; token $4E DIM
; string var, uses token $22
; DIM A$(5)

DIMSTR:
		JSR	sub_0_E118
		INX	
loc_0_E134:	
		LDA	NOUNSTKL,X
		STA	AUX
		ADC	ACC
		PHA	
		TAY	
		LDA	NOUNSTKH,X
		STA	AUX+1	
		ADC	ACC+1	
		PHA	
		CPY	PP	
		SBC	PP+1	
		BCS	loc_0_E12C
		LDA	AUX
		ADC	#-2
		STA	AUX
		LDA	#-1
		TAY	
		ADC	AUX+1	
		STA	AUX+1	

loc_0_E156:			
		INY	
		LDA	(AUX),Y
		CMP	PV,Y
		BNE	DimErr
		TYA	
		BEQ	loc_0_E156

loc_0_E161:		
		PLA	
		STA	(AUX),Y
		STA	PV,Y
		DEY	
		BPL	loc_0_E161
		INX	
		RTS	
		NOP	

DimErr:	
		LDY	#Err_Dim	; "DIM"
loc_0_E16F:			
		BNE	loc_0_E106


INPUTSTR:				; input a string	
		LDA	#0
		JSR	sub_0_E70A
		LDY	#2
		STY	NOUNSTKH,X
		JSR	sub_0_E70A
		STX	XSAVE	
		TAX	
		INC	PROMPT		; change '>' to '?'
		JSR	BAS_RDKEY
		DEC	PROMPT		; change '?' to '>'
		TXA	
		LDX	XSAVE	
		STA	NOUNSTKH,X


; token $70 =
; string - non-conditional
; A$ = "HELLO"

sub_0_E18C:
		LDA	NOUNSTKL+1,X
		STA	ACC
		LDA	NOUNSTKH+1,X
		STA	ACC+1	
		INX	
		INX	
		JSR	sub_0_E1BC

loc_0_E199:			
		LDA	NOUNSTKL-2,X
		CMP	NOUNSTKH-2,X
		BCS	loc_0_E1B4
		INC	NOUNSTKL-2,X
		TAY	
		LDA	(ACC),Y
		LDY	NOUNSTKL,X
		CPY	P2	
		BCC	loc_0_E1AE
		LDY	#-$7D		; "STR OVFL"
		BNE	loc_0_E16F

loc_0_E1AE:	
		STA	(AUX),Y
		INC	NOUNSTKL,X
		BCC	loc_0_E199

loc_0_E1B4:		
		LDY	NOUNSTKL,X
		TXA	
		STA	(AUX),Y
		JMP	loc_0_F223


sub_0_E1BC:				; solo
		LDA	NOUNSTKL+1,X
		STA	AUX
		SEC	
		SBC	#2
		STA	P2	
		LDA	NOUNSTKH+1,X
		STA	AUX+1	
		SBC	#0
		STA	P2+1	
		LDY	#0
		LDA	(P2),Y
		CLC	
		SBC	AUX
		STA	P2	
		RTS	


; token $39 =
; string logic op
; IF A$ = "CAT" THEN END

sub_0_E1D7:				; V 
		LDA	NOUNSTKL+3,X
		STA	ACC
		LDA	NOUNSTKH+3,X
		STA	ACC+1	
		LDA	NOUNSTKL+1,X
		STA	AUX
		LDA	NOUNSTKH+1,X
		STA	AUX+1	
		INX	
		INX	
		INX	
		LDY	#0
		STY	NOUNSTKH,X
		STY	NOUNSTKC,X
		INY	
		STY	NOUNSTKL,X

loc_0_E1F3:
		LDA	HIMEM+1,X
		CMP	NOUNSTKH-3,X
		PHP	
		PHA	
		LDA	NOUNSTKL-1,X
		CMP	NOUNSTKH-1,X
		BCC	loc_0_E206
		PLA	
		PLP	
		BCS	locret_0_E205
loc_0_E203:		
		LSR	NOUNSTKL,X
locret_0_E205:	
		RTS	

loc_0_E206:
		TAY	
		LDA	(ACC),Y
		STA	P2	
		PLA	
		TAY	
		PLP	
		BCS	loc_0_E203
		LDA	(AUX),Y
		CMP	P2	
		BNE	loc_0_E203
		INC	NOUNSTKL-1,X
		INC	HIMEM+1,X
		BCS	loc_0_E1F3


; token $3A #
; string logic op
; is A$ # "CAT" THEN END

loc_0_E21C:				; VO
		JSR	sub_0_E1D7
		JMP	NOT


; token $14 *
; num math op
; A = 27 * 2

MULT:					; V 
		JSR	sub_0_E254
loc_0_E225:		
		ASL	ACC
		ROL	ACC+1		; add partial product is C set
		BCC	loc_0_E238
		CLC	
		LDA	P3	
		ADC	AUX
		STA	P3	
		LDA	P3+1	
		ADC	AUX+1	
		STA	P3+1	

loc_0_E238:		
		DEY	
		BEQ	loc_0_E244
		ASL	P3	
		ROL	P3+1	
		BPL	loc_0_E225
		JMP	loc_0_E77E

loc_0_E244:	
		LDA	P3	
		JSR	sub_0_E708
		LDA	P3+1	
		STA	NOUNSTKC,X
		ASL	P2+1	
		BCC	locret_0_E279
		JMP	NEGATE


sub_0_E254:
		LDA	#$55
		STA	P2+1	
		JSR	loc_0_E25B

loc_0_E25B:
		LDA	ACC
		STA	AUX
		LDA	ACC+1	
		STA	AUX+1	
		JSR	GET16BIT
		STY	P3	
		STY	P3+1	
		LDA	ACC+1	
		BPL	loc_0_E277
		DEX	
		ASL	P2+1	
		JSR	NEGATE
		JSR	GET16BIT
loc_0_E277:	
		LDY	#$10
locret_0_E279:	
		RTS	


; token $1F MOD
; num op
; IF X MOD 13 THEN END

MOD:
		JSR	sub_0_EE6C
		BEQ	loc_0_E244
		
		.BYTE  $FF

sub_0_E280:				; solo
		INC	PROMPT		; change '>' to '?'
		LDY	#0
		JSR	GETCMD
		DEC	PROMPT		; change '?' to '>'
		RTS	


; token $3D SCRN(
; PRINT SCRN(X,Y)

SCRN:					; VO
		JSR	GETBYTE
		LSR	A		; A = A/2
		PHP			; stash C (lsb)
		JSR	GBASCALC	
		JSR	GETBYTE
		TAY	
		LDA	(GBAS),Y	; get screen byte
		PLP			; retrieve C
		BCC	loc_0_E29F
		LSR	A		; odd, upper half
		LSR	A
		LSR	A
		LSR	A

loc_0_E29F:	
		AND	#$F		; A = color #
		LDY	#0
		JSR	sub_0_E708
		STY	NOUNSTKC,X
		DEY	
		STY	PRFLAG		; PRFLAG = $FF	

COMMA_SCRN:				; VO
		RTS	

  	;	.BYTE  $FF,$FF,$FF,$FF	can do this since org $ec00 for SYNTABLs

		JSR	sub_0_EFD3	; old 4K cold start

; Warm Start!

WARM:					; main compile/execute code 
		JSR	CROUT		; emit blank line
loc_0_E2B6:
		LSR	RUNFLAG		; not running	
		LDA	#'>'+$80
		JSR	SetPrompt	; set & print prompt char
		LDY	#0
		STY	LEADZR		; no leading zeros for AUTOLN
		BIT	AUTOFLAG	; AUTO?
		BPL	loc_0_E2D1
		LDX	AUTOLN		; yes, print line number
		LDA	AUTOLN+1	
		JSR	PRDEC
		LDA	#SPC+$80	; and a blank
		JSR	COUT	

loc_0_E2D1:	
		LDX	#$FF		; init Stack
		TXS	
		JSR	GETCMD
		STY	TOKNDX		; init TOKNDX to offset to last char in IN	
		TXA	
		STA	TXTNDX		; init TXTNDX to $FF (-1)
		LDX	#$20
		JSR	sub_0_E491
		LDA	TXTNDX		; PX = TXTNDX+$0200+C flag	
		ADC	#(IN&$FF)
		STA	PX	
		LDA	#0
		TAX	
		ADC	#(IN/256)
		STA	PX+1	
		LDA	(PX,X)
		AND	#$F0
		CMP	#'0'+$80
		BEQ	loc_0_E2F9
		JMP	loc_0_E883

loc_0_E2F9:		
		LDY	#2		; move 2 bytes
loc_0_E2FB:	
		LDA	(PX),Y
		STA	ACC-1,Y
		DEY	
		BNE	loc_0_E2FB
		JSR	sub_0_E38A
		LDA	TOKNDX	
		SBC	TXTNDX	
		CMP	#4
		BEQ	loc_0_E2B6
		STA	(PX),Y
		LDA	PP		; P2 = PP-(PX),Y	
		SBC	(PX),Y
		STA	P2	
		LDA	PP+1	
		SBC	#0
		STA	P2+1	
		LDA	P2	
		CMP	PV
		LDA	P2+1
		SBC	PV+1	
		BCC	MEMFULL

loc_0_E326:		
		LDA	PP		; P3 = PP-(PX),Y	
		SBC	(PX),Y
		STA	P3	
		LDA	PP+1	
		SBC	#0
		STA	P3+1	
		LDA	(PP),Y
		STA	(P3),Y
		INC	PP	
		BNE	loc_0_E33C
		INC	PP+1	

loc_0_E33C:		
		LDA	P1
		CMP	PP	
		LDA	P1+1	
		SBC	PP+1	
		BCS	loc_0_E326

loc_0_E346:	
		LDA	P2,X
		STA	PP,X
		DEX	
		BPL	loc_0_E346
		LDA	(PX),Y
		TAY	

loc_0_E350:
		DEY	
		LDA	(PX),Y
		STA	(P3),Y
		TYA	
		BNE	loc_0_E350
		BIT	AUTOFLAG	
		BPL	loc_0_E365

loc_0_E35C:	
		LDA	AUTOLN+1,X
		ADC	AUTOINC+1,X
		STA	AUTOLN+1,X
		INX	
		BEQ	loc_0_E35C
loc_0_E365:
		BPL	loc_0_E3E5

;		.BYTE	 $00,$00,$00,$00

MEMFULL:
		LDY	#Err_MemFull	; "MEM FULL"
		BNE	ERRMESS


; token $0A ,
; DEL 0,10

COMMA_DEL:				; VO
		JSR	GET16BIT
		LDA	P1
		STA	P3	
		LDA	P1+1	
		STA	P3+1	
		JSR	sub_0_E575
		LDA	P1
		STA	P2	
		LDA	P1+1	
		STA	P2+1	
		BNE	loc_0_E395


; token $09 DEL

DEL:					; VO
		JSR	GET16BIT
sub_0_E38A:	
		JSR	sub_0_E56D
		LDA	P3	
		STA	P1
		LDA	P3+1	
		STA	P1+1	
loc_0_E395:		
		LDY	#0
loc_0_E397:	
		LDA	PP	
		CMP	P2	
		LDA	PP+1	
		SBC	P2+1	
		BCS	loc_0_E3B7
		LDA	P2	
		BNE	loc_0_E3A7
		DEC	P2+1	
loc_0_E3A7:	
		DEC	P2	
		LDA	P3	
		BNE	loc_0_E3AF
		DEC	P3+1	
loc_0_E3AF:
		DEC	P3	
		LDA	(P2),Y
		STA	(P3),Y
		BCC	loc_0_E397
loc_0_E3B7:				; solo
		LDA	P3	
		STA	PP	
		LDA	P3+1	
		STA	PP+1	
		RTS	

loc_0_E3C0:	
		JSR	COUT		; print error message
		INY	

ERRORMESS:				; print error message
		LDA	ErrorMsgs,Y
		BMI	loc_0_E3C0
		ORA	#$80
		JMP	COUT	

GETCMD:		
		TYA			; called with Y as desired index into IN (?)
		TAX			; NXTCHAR stores starting @ IN,X	
		JSR	NXTCHAR		; get a line from user into IN buffer	
		TXA	
		TAY	
		LDA	#'_'+$80
		STA	IN,Y		; overwrite CR with _ (?)
		LDX	#$FF
		RTS	


		RTS	

loc_0_E3DE:			
		LDY	#Err_TooLong	; "TOO LONG"
ERRMESS:				; print err msg and goto mainline
		JSR	PRINTERR
		BIT	RUNFLAG	

loc_0_E3E5:				
		BMI	loc_0_E3EA
		JMP	loc_0_E2B6

loc_0_E3EA:			
		JMP	loc_0_EB9A

loc_0_E3ED:		
		ROL	A
		ADC	#$A0
		CMP	IN,X
		BNE	loc_0_E448
		LDA	(SYNPAG),Y
		ASL	A
		BMI	loc_0_E400
		DEY	
		LDA	(SYNPAG),Y
		BMI	loc_0_E428
		INY	
loc_0_E400:	
		STX	TXTNDX	
		TYA	
		PHA	
		LDX	#0
		LDA	(SYNPAG,X)
		TAX	
loc_0_E409:
		LSR	A
		EOR	#$40
		ORA	(SYNPAG),Y
		CMP	#$C0
		BCC	loc_0_E413
		INX	
loc_0_E413:		
		INY	
		BNE	loc_0_E409
		PLA	
		TAY	
		TXA	
		JMP	loc_0_F2F8

sub_0_E41C:		
		INC	TOKNDX	
		LDX	TOKNDX	
		BEQ	loc_0_E3DE	; "TOO LONG"
		STA	IN,X
locret_0_E425:	
		RTS	

loc_0_E426:				; solo	
		LDX	TXTNDX	
loc_0_E428:			
		LDA	#SPC+$80
loc_0_E42A:	
		INX	
		CMP	IN,X
		BCS	loc_0_E42A
		LDA	(SYNPAG),Y
		AND	#$3F
		LSR	A
		BNE	loc_0_E3ED
		LDA	IN,X
		BCS	loc_0_E442
		ADC	#$3F
		CMP	#$1A
		BCC	loc_0_E4B1

loc_0_E442:		
		ADC	#$4F
		CMP	#$0A
		BCC	loc_0_E4B1

loc_0_E448:	
		LDX	SYNSTKDX	
loc_0_E44A:
		INY	
		LDA	(SYNPAG),Y
		AND	#$E0
		CMP	#$20
		BEQ	loc_0_E4CD
		LDA	TXTNDXSTK,X
		STA	TXTNDX	
		LDA	TOKNDXSTK,X
		STA	TOKNDX	
loc_0_E45B:		
		DEY	
		LDA	(SYNPAG),Y
		ASL	A
		BPL	loc_0_E45B
		DEY	
		BCS	loc_0_E49C
		ASL	A
		BMI	loc_0_E49C
		LDY	SYNSTKH,X
		STY	SYNPAG+1	
		LDY	SYNSTKL,X
		INX	
		BPL	loc_0_E44A

loc_0_E470:			
		BEQ	locret_0_E425
		CMP	#$7E
		BCS	loc_0_E498
		DEX	
		BPL	loc_0_E47D
		LDY	#Err_TooLong	; "TOO LONG"
		BPL	loc_0_E4A6

loc_0_E47D:		
		STY	SYNSTKL,X
		LDY	SYNPAG+1
		STY	SYNSTKH,X
		LDY	TXTNDX	
		STY	TXTNDXSTK,X
		LDY	TOKNDX	
		STY	TOKNDXSTK,X
		AND	#$1F
		TAY	
		LDA	SYNTABLNDX,Y
sub_0_E491:	
		ASL	A
		TAY	
		LDA	#(SYNTABL>>8)/2
		ROL	A
		STA	SYNPAG+1	
loc_0_E498:
		BNE	loc_0_E49B
		INY	
loc_0_E49B:
		INY	
loc_0_E49C:
		STX	SYNSTKDX	
		LDA	(SYNPAG),Y
		BMI	loc_0_E426
		BNE	loc_0_E4A9
		LDY	#Err_Syntax	; "SYNTAX"
loc_0_E4A6:	
		JMP	ERRMESS

loc_0_E4A9:
		CMP	#$03
		BCS	loc_0_E470
		LSR	A
		LDX	TXTNDX	
		INX	
loc_0_E4B1:				
		LDA	IN,X
		BCC	loc_0_E4BA
		CMP	#DQT+$80
		BEQ	loc_0_E4C4

loc_0_E4BA:	
		CMP	#'_'+$80
		BEQ	loc_0_E4C4
		STX	TXTNDX	

loc_0_E4C0:
		JSR	sub_0_E41C
		INY	
loc_0_E4C4:	
		DEY	
		LDX	SYNSTKDX	
loc_0_E4C7:
		LDA	(SYNPAG),Y
		DEY	
		ASL	A
		BPL	loc_0_E49C

loc_0_E4CD:		
		LDY	SYNSTKH,X
		STY	SYNPAG+1	
		LDY	SYNSTKL,X
		INX	
		LDA	(SYNPAG),Y
		AND	#%10011111
		BNE	loc_0_E4C7
		STA	PCON	
		STA	PCON+1	
		TYA	
		PHA	
		STX	SYNSTKDX	
		LDY	TOKNDXSTK-1,X
		STY	LEADBL	
		CLC	
loc_0_E4E7:				; ...
		LDA	#$0A
		STA	CHAR	
		LDX	#0
		INY	
		LDA	IN,Y
		AND	#$0F

loc_0_E4F3:				; ...
		ADC	PCON	
		PHA	
		TXA	
		ADC	PCON+1	
		BMI	loc_0_E517
		TAX	
		PLA	
		DEC	CHAR	
		BNE	loc_0_E4F3
		STA	PCON	
		STX	PCON+1	
		CPY	TOKNDX	
		BNE	loc_0_E4E7
		LDY	LEADBL	
		INY	
		STY	TOKNDX	
		JSR	sub_0_E41C
		PLA	
		TAY	
		LDA	PCON+1	
		BCS	loc_0_E4C0
loc_0_E517:	
		LDY	#Err_GT32767	; ">32767"
		BPL	loc_0_E4A6


; Print a 16-bit number in decimal
; 
;	A = hi byte
;	X = lo byte
;

PRDEC:
		STA	PCON+1	
		STX	PCON	
		LDX	#4
		STX	LEADBL	
loc_0_E523:
		LDA	#'0'+$80
		STA	CHAR	
loc_0_E527:
		LDA	PCON	
		CMP	NUMLOW,X
		LDA	PCON+1	
		SBC	NUMHI,X
		BCC	loc_0_E540
		STA	PCON+1	
		LDA	PCON	
		SBC	NUMLOW,X
		STA	PCON	
		INC	CHAR	
		BNE	loc_0_E527

loc_0_E540:				; ...
		LDA	CHAR	
		INX	
		DEX	
		BEQ	PRDEC5
		CMP	#'0'+$80
		BEQ	loc_0_E54C
		STA	LEADBL	
loc_0_E54C:		
		BIT	LEADBL	
		BMI	PRDEC5
		LDA	LEADZR	
		BEQ	PRDEC6

PRDEC5:	
		JSR	COUT	
		BIT	AUTOFLAG	; auto line?	
		BPL	PRDEC6
		STA	IN,Y
		INY	

PRDEC6:	
		DEX	
		BPL	loc_0_E523
		RTS	


NUMLOW:		.BYTE	1
		.BYTE	10
		.BYTE	100
		.BYTE	1000
		.BYTE	10000

NUMHI:		.BYTE	1/$0100
		.BYTE	10/$0100
		.BYTE	100/$0100
		.BYTE	1000/$0100
		.BYTE	10000/$0100


sub_0_E56D:
		LDA	PP	
		STA	P3	
		LDA	PP+1	
		STA	P3+1
sub_0_E575:
		INX	
loc_0_E576:
		LDA	P3+1	
		STA	P2+1	
		LDA	P3	
		STA	P2	
		CMP	HIMEM
		LDA	P2+1	
		SBC	HIMEM+1	
		BCS	locret_0_E5AC
		LDY	#1
		LDA	(P2),Y
		SBC	ACC
		INY	
		LDA	(P2),Y
		SBC	ACC+1	
		BCS	locret_0_E5AC
		LDY	#0
		LDA	P3		; P3 = P3.W + (P2).B	
		ADC	(P2),Y
		STA	P3	
		BCC	loc_0_E5A0
		INC	P3+1	
		CLC	
loc_0_E5A0:
		INY	
		LDA	ACC		; is ACC+1 <HS> (P2),Y?
		SBC	(P2),Y
		INY	
		LDA	ACC+1	
		SBC	(P2),Y
		BCS	loc_0_E576

locret_0_E5AC:	
		RTS	


; token $0B NEW
; turn off AUTO
; remove program
; fall into CLR

NEW:					; V	
		LSR	AUTOFLAG	
		LDA	HIMEM
		STA	PP	
		LDA	HIMEM+1	
		STA	PP+1		; BASIC program grows down from HIMEM
					; PP is BASIC Program Pointer

; token $0C CLR
; remove variables
; remove FOR loops & GOSUBs

CLR:					; V
		LDA	LOMEM
		STA	PV
		LDA	LOMEM+1	
		STA	PV+1		; BASIC vars grow up from LOMEM, PV is Program Vars
		LDA	#0
		STA	FORNDX		; no FORs	
		STA	GOSUBNDX	; no GOSUBs	
		STA	SYNPAG	
		LDA	#0
		STA	byte_0_1D
		RTS	

		LDA	SRCH	
loc_0_E5CE:
		JMP	MEMFULL

loc_0_E5D1:
		LDY	#$FF
loc_0_E5D3:
		STY	XSAVE	
loc_0_E5D5:
		INY	
		LDA	(PX),Y
		BMI	loc_0_E5E0
		CMP	#$40
		BNE	loc_0_E646
		STA	XSAVE	
loc_0_E5E0:
		CMP	(SRCH),Y
		BEQ	loc_0_E5D5

loc_0_E5E4:
		LDA	(SRCH),Y
loc_0_E5E6:
		INY	
		LSR	A
		BNE	loc_0_E5E4
		LDA	(SRCH),Y
		PHA	
		INY	
		LDA	(SRCH),Y
		TAY	
		PLA	
loc_0_E5F2:
		STA	SRCH	
		STY	SRCH+1	
		CMP	PV
		BNE	loc_0_E5D1
		CPY	PV+1	
		BNE	loc_0_E5D1
		LDY	#0
loc_0_E600:
		INY	
		LDA	(PX),Y
		BMI	loc_0_E600
		EOR	#$40
		BEQ	loc_0_E600
		TYA	
		ADC	#$04
		PHA	
		ADC	SRCH	
		TAY	
		LDA	SRCH+1
		ADC	#0
		PHA	
		CPY	PP	
		SBC	PP+1	
		BCS	loc_0_E5CE
		STY	PV
		PLA	
		STA	PV+1	
		PLA	
		TAY	
		LDA	#0
		DEY	
		STA	(SRCH),Y
		DEY	
		STA	(SRCH),Y
		DEY	
		LDA	PV+1	
		STA	(SRCH),Y
		DEY	
		LDA	PV
		STA	(SRCH),Y
		DEY	
		LDA	#0
loc_0_E637:
		STA	(SRCH),Y
		DEY	
		BMI	loc_0_E5D3
		LDA	(PX),Y
		BNE	loc_0_E637

loc_0_E640:		
		LDA	LOMEM
		LDY	LOMEM+1	
		BNE	loc_0_E5F2

loc_0_E646:
		LDA	(SRCH),Y
		CMP	#$40
		BCS	loc_0_E5E6
		STA	NOUNSTKC-1,X
		TYA	
		ADC	#$03
		PHA	
		ADC	SRCH	
		JSR	sub_0_E70A
loc_0_E657:
		JSR	GETVERB
		DEY	
		BNE	loc_0_E657
		TYA	
		ADC	SRCH+1	
		STA	NOUNSTKH,X
		PLA	
		BIT	XSAVE	
		BMI	loc_0_E684
		TAY	
		LDA	#0
		JSR	sub_0_E70A
		STA	NOUNSTKH,X
loc_0_E66F:
		LDA	(SRCH),Y
		BPL	loc_0_E682
		INC	NOUNSTKH,X
		INY	
		BNE	loc_0_E66F

		.BYTE	 9

sub_0_E679:				; solo	
		LDA	#0
		STA	IFFLAG		; pos
		STA	CRFLAG		; pos	
		LDX	#$20
loc_0_E681:
		PHA	
loc_0_E682:
		LDY	#0
loc_0_E684:
		LDA	(PX),Y
loc_0_E686:
		BPL	loc_0_E6A0
		ASL	A
		BMI	loc_0_E640
		JSR	GETVERB
		JSR	sub_0_E708
		JSR	GETVERB
		STA	NOUNSTKC,X
loc_0_E696:
		BIT	IFFLAG	
		BPL	loc_0_E69B
		DEX	
loc_0_E69B:
		JSR	GETVERB
		BCS	loc_0_E686

loc_0_E6A0:
		CMP	#$28
		BNE	loc_0_E6C3
		LDA	PX	
		JSR	sub_0_E70A
		LDA	PX+1	
		STA	NOUNSTKH,X
		BIT	IFFLAG	
		BMI	loc_0_E6BC
		LDA	#$01
		JSR	sub_0_E70A
		LDA	#0
		STA	NOUNSTKH,X
loc_0_E6BA:
		INC	NOUNSTKH,X
loc_0_E6BC:
		JSR	GETVERB
		BMI	loc_0_E6BA
		BCS	loc_0_E696

loc_0_E6C3:
		BIT	IFFLAG	
		BPL	loc_0_E6CD
		CMP	#$04
		BCS	loc_0_E69B
		LSR	IFFLAG		; pos	
loc_0_E6CD:
		TAY	
		STA	VERBNOW	
		LDA	TABLE_E980,Y
		AND	#%01010101	; even bits only
		ASL	A
		STA	PRFLAG		; temp	
loc_0_E6D8:
		PLA	
		TAY	
		LDA	TABLE_E980,Y
		AND	#%10101010	; odd bits only
		CMP	PRFLAG	
		BCS	loc_0_E6EC
		TYA	
		PHA	
		JSR	sub_0_F3EB
		LDA	VERBNOW	
		BCC	loc_0_E681

loc_0_E6EC:
		LDA	VERBADRL,Y
		STA	ACC
		LDA	VERBADRH,Y
		STA	ACC+1	
		JSR	j_ACC
		JMP	loc_0_E6D8

j_ACC:
                JMP     (ACC)

GETVERB:				; get next verb to use
		INC	PX	
		BNE	loc_0_E705
		INC	PX+1	
loc_0_E705:
		LDA	(PX),Y
		RTS	


sub_0_E708:
		STY	NOUNSTKH-1,X
sub_0_E70A:
		DEX	
		BMI	loc_0_E710
		STA	NOUNSTKL,X
		RTS	

loc_0_E710:
		LDY	#$66		; "PPED AT"
loc_0_E712:
		JMP	ERRMESS


GET16BIT:
		LDY	#0
		LDA	NOUNSTKL,X
		STA	ACC
		LDA	NOUNSTKC,X
		STA	ACC+1	
		LDA	NOUNSTKH,X
		BEQ	loc_0_E731
		STA	ACC+1	
		LDA	(ACC),Y		; ACC = (ACC),Y
		PHA			; save low byte
		INY			; Y = 1
		LDA	(ACC),Y
		STA	ACC+1	
		PLA			; restore low byte
		STA	ACC
		DEY			; Y = 0
loc_0_E731:
		INX	
		RTS	


; token $16 =
; num var logic op
; IF X = 13 THEN END

sub_0_E733:				; V0
		JSR	sub_0_E74A


; token $37 NOT
; numeric
; IF NOT X THEN END

NOT:					; V
		JSR	GET16BIT
		TYA			; A = 0
		JSR	sub_0_E708
		STA	NOUNSTKC,X
		CMP	ACC
		BNE	locret_0_E749
		CMP	ACC+1	
		BNE	locret_0_E749
		INC	NOUNSTKL,X
locret_0_E749:
		RTS	


; token $17 #
; num var logic op
; IF X # 13 THEN END

; token $1B <>
; num var logic op
; IF X <> 13 THEN END

sub_0_E74A:				; V 
		JSR	SUBTRACT
		JSR	SGN

; token $31 ABS

ABS:					; VO
		JSR	GET16BIT
		BIT	ACC+1	
		BMI	sub_0_E772

loc_0_E757:				; solo
		DEX	
locret_0_E758:
		RTS	


; token $30 SGN

SGN:					; V
		JSR	GET16BIT
		LDA	ACC+1		; ACC == 0?	
		BNE	loc_0_E764
		LDA	ACC
		BEQ	loc_0_E757

loc_0_E764:
		LDA	#$FF
		JSR	sub_0_E708
		STA	NOUNSTKC,X
		BIT	ACC+1	
		BMI	locret_0_E758


; token $36 -
; unary sign of number
; X = -5

NEGATE:					; V
		JSR	GET16BIT
sub_0_E772:
		TYA			; A = 0
		SEC	
		SBC	ACC
		JSR	sub_0_E708
		TYA	
		SBC	ACC+1	
		BVC	loc_0_E7A1

loc_0_E77E:
		LDY	#Err_GT32767	; ">32767"
		BPL	loc_0_E712


; token $13 -
; num op
; X = 27 -2

SUBTRACT:				; V
		JSR	NEGATE

; token $12 +
; num op
; X = 27 + 2

ADDITION:
		JSR	GET16BIT
		LDA	ACC
		STA	AUX
		LDA	ACC+1	
		STA	AUX+1	
		JSR	GET16BIT
loc_0_E793:
		CLC	
		LDA	ACC
		ADC	AUX
		JSR	sub_0_E708
		LDA	ACC+1	
		ADC	AUX+1	
		BVS	loc_0_E77E

loc_0_E7A1:
		STA	NOUNSTKC,X

; token $35 +
; unary sign of number
; X = +5

POSITIVE:				; VO
		RTS	


; token $50 TAB

TAB:					; VO
		JSR	GETBYTE
		TAY	
		BNE	loc_0_E7AD
		JMP	loc_0_EECB	; range error?

loc_0_E7AD:
		DEY	
loc_0_E7AE:				; solo
		JMP	loc_0_F3F4

; comma tab to next tab position (every 8 spaces)

sub_0_E7B1:
		LDA	CH		; get horz posn
		ORA	#$07		; set bits 2:0
		TAY	
		INY			; incr, is it 0?
loc_0_E7B7:
		BNE	loc_0_E7AE	; no, adjust CH
		INY			; yes, go to next tab posn
		BNE	sub_0_E7B1
		BCS	loc_0_E7B7
		RTS	

		.BYTE	$00,$00 


; token $49 ,
; num print follows
; PRINT A$,X

sub_0_E7C1:
		JSR	sub_0_E7B1


; token $46 ;
; num print follows
; PRINT A$ ; X

; token $62 PRINT
; num value
; PRINT 123: PRINT X: PRINT ASC(A$)

PRNTNUM:				; VO branch
		JSR	GET16BIT
sub_0_E7C7:				; solo
		LDA	ACC+1		; is it positive?	
		BPL	loc_0_E7D5
		LDA	#'-'+$80	; no, print minus sign
		JSR	COUT	
		JSR	sub_0_E772
		BVC	PRNTNUM

loc_0_E7D5:
		DEY			; Y = $FF
		STY	CRFLAG		; CRFLAG = $FF	
		STX	ACC+1		; save X	
		LDX	ACC
		JSR	PRDEC
		LDX	ACC+1		; restore X	
		RTS	


; token $0D AUTO

AUTO:
		JSR	GET16BIT
		LDA	ACC
		STA	AUTOLN	
		LDA	ACC+1	
		STA	AUTOLN+1	
		DEY	
		STY	AUTOFLAG	; AUTOFLAG = $FF	
		INY	
		LDA	#10		; default increment
loc_0_E7F3:
		STA	AUTOINC	
		STY	AUTOINC+1	
		RTS	


; token $0E ,
; AUTO 10, 20

COMMA_AUTO:				; VO
		JSR	GET16BIT
		LDA	ACC
		LDY	ACC+1	
		BPL	loc_0_E7F3


; token $56 =
; FOR X = 5 TO 10

; token $71 =
; num - non-conditional
; X = 5

sub_0_E801:				; V
		JSR	GET16BIT
		LDA	NOUNSTKL,X
		STA	AUX
		LDA	NOUNSTKH,X
		STA	AUX+1	
		LDA	ACC
		STA	(AUX),Y
		INY	
		LDA	ACC+1	
		JMP	loc_0_F207


; token $25 THEN
; IF X = 3 THEN Y = 5

; token $5E LET

LET:					; VO
		RTS	


; token $00
; internal begin-of-line

BEGIN_LINE:				; VO
		PLA	
		PLA	


; token $03 :
; statement separation
; X = 5: A$ = "HELLO"

COLON:					; VO
		BIT	CRFLAG	
		BPL	locret_0_E822


; token $63 PRINT
; dummy print
; PRINT: PRINT

PRINT_CR:				; VO
		JSR	CROUT	


; token $47 ;
; end of print statement
; PRINT A$;

sub_0_E820:
		LSR	CRFLAG	
locret_0_E822:
		RTS	


; token $22 (
; string DIM
; DIM A$(X)

; token $34 (
; num DIM
; DIM X(5)

; token $38 (
; logic statements and num ops
; IF C AND (A=14 OR B=12) THEN X=(27+3)/13

; token $3F (
; used after PEEK, RND, SGN, ABS, and PDL

loc_0_E823:				; V
		LDY	#$FF
		STY	PRFLAG		; PRFLAG = $FF	


; tkn $72 )
; the only right paren token

RIGHT_PAREN:				; VO
		RTS	


; token $60 IF

IF:					; VO
		JSR	sub_0_EFCD
		BEQ	loc_0_E834
		LDA	#$25
		STA	VERBNOW	
		DEY	
		STY	IFFLAG	
loc_0_E834:
		INX	
		RTS	


; RUN without CLR

RUNWARM:				; solo 
		LDA	PP	
		LDY	PP+1	
		BNE	loc_0_E896


; token $5C GOSUB

GOSUB:					; VO
		LDY	#Err_16GoSubs	; "16 GOSUBS"
		LDA	GOSUBNDX	
		CMP	#16		; 16 gosubs?
		BCS	loc_0_E8A2	; yes, error
		TAY	
		INC	GOSUBNDX

		LDA	PX	
		STA	STK_00,Y
		LDA	PX+1	
		STA	STK_10,Y

		LDA	PR	
		STA	STK_20,Y
		LDA	PR+1	
		STA	STK_30,Y


; token $24 THEN
; followed by a line number
; IF X = 3 THEN 10

; token $5F GOTO

GOTO:					; V
		JSR	GET16BIT
		JSR	sub_0_E56D
		BCC	loc_0_E867
		LDY	#Err_BadBranch	; "BAD BRANCH"
		BNE	loc_0_E8A2

loc_0_E867:
		LDA	P2	
		LDY	P2+1	

; main loop for running Integer BASIC programs
		
loc_0_E86B:
		STA	PR	
		STY	PR+1	
		CLC	
		ADC	#$03
		BCC	GETNEXT
		INY	
GETNEXT:				; fetch next stmt from text src 
		LDX	#$FF
		STX	RUNFLAG		; neg	
		TXS	
		STA	PX	
		STY	PX+1	
		JSR	sub_0_F02E	; test for ctl-C & TRACE mode
		LDY	#0
loc_0_E883:
		JSR	sub_0_E679	; execute statement
		BIT	RUNFLAG	
		BPL	END	
		CLC	
		LDY	#0
		LDA	PR	
		ADC	(PR),Y
		LDY	PR+1	
		BCC	loc_0_E896
		INY	
loc_0_E896:
		CMP	HIMEM
		BNE	loc_0_E86B
		CPY	HIMEM+1	
		BNE	loc_0_E86B
		LDY	#Err_NoEnd	; "NO END"
		LSR	RUNFLAG		; pos	
loc_0_E8A2:
		JMP	ERRMESS


; token $5B RETURN

RETURN:					; V
		LDY	#Err_BadReturn	; "BAD RETURN"
		LDA	GOSUBNDX	
		BEQ	loc_0_E8A2
		DEC	GOSUBNDX	
		TAY	
		LDA	STK_20-1,Y
		STA	PR	
		LDA	STK_30-1,Y
		STA	PR+1	
;		LDX	STK_00-1,Y
		.byte	$be,$ff,$00
		LDA	STK_10-1,Y
loc_0_E8BE:
		TAY	
		TXA	
		JMP	GETNEXT

STOPPED_AT:
		LDY	#Err_StoppedAt	; "STOPPED AT "
		JSR	ERRORMESS
		LDY	#1
		LDA	(PR),Y
		TAX	
		INY	
		LDA	(PR),Y
		JSR	PRDEC


; token $51 END

END:					; V
		JMP	WARM

loc_0_E8D6:
		DEC	FORNDX	


; token $59 NEXT

; token $5A ,
; NEXT X,Y

NEXT:					; VO
		LDY	#Err_BadNext	; "BAD NEXT"
		LDA	FORNDX	
loc_0_E8DC:
		BEQ	loc_0_E8A2	; no more FORs?
		TAY	
		LDA	NOUNSTKL,X
		CMP	STK_40-1,Y
		BNE	loc_0_E8D6
		LDA	NOUNSTKH,X
		CMP	STK_50-1,Y
		BNE	loc_0_E8D6
		
		LDA	STK_60-1,Y
		STA	AUX
		LDA	STK_70-1,Y
		STA	AUX+1	
		
		JSR	GET16BIT
		DEX	
		JSR	loc_0_E793
		JSR	sub_0_E801
		DEX	
		LDY	FORNDX	
		LDA	STK_D0-1,Y
		STA	NOUNSTKC-1,X
		LDA	STK_C0-1,Y
		LDY	#0
		JSR	sub_0_E708
		JSR	SUBTRACT
		JSR	SGN
		JSR	GET16BIT
		LDY	FORNDX	
		LDA	ACC
		BEQ	loc_0_E925
		EOR	STK_70-1,Y
		BPL	loc_0_E937

loc_0_E925:
		LDA	STK_80-1,Y
		STA	PR	
		LDA	STK_90-1,Y
		STA	PR+1	

		LDX	STK_A0-1,Y
		LDA	STK_B0-1,Y
		BNE	loc_0_E8BE

loc_0_E937:
		DEC	FORNDX	
		RTS	


; token $55 FOR

FOR:
		LDY	#Err_16Fors	; "16 FORS"
		LDA	FORNDX	
		CMP	#16		; 16 fors?
		BEQ	loc_0_E8DC	; yes, error
		INC	FORNDX	
		TAY	
		LDA	NOUNSTKL,X
		STA	STK_40,Y
		LDA	NOUNSTKH,X
		JMP	loc_0_F288
		RTS	


; token $57 TO

TO:					; VO
		JSR	GET16BIT
		LDY	FORNDX

		LDA	ACC
		STA	STK_C0-1,Y
		LDA	ACC+1	
		STA	STK_D0-1,Y

		LDA	#($0001&$FF)
		STA	STK_60-1,Y
		LDA	#($0001/256)
loc_0_E966:				; solo
		STA	STK_70-1,Y

		LDA	PR	
		STA	STK_80-1,Y
		LDA	PR+1	
		STA	STK_90-1,Y

		LDA	PX	
		STA	STK_A0-1,Y
		LDA	PX+1	
		STA	STK_B0-1,Y
		RTS	

		.BYTE  $20,$15

TABLE_E980:
		.BYTE	 0
		.BYTE	 0
		.BYTE	 0
		.BYTE  $AB
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE  $3F
		.BYTE  $3F
		.BYTE  $C0
		.BYTE  $C0
		.BYTE  $3C
		.BYTE  $3C
		.BYTE  $3C
		.BYTE  $3C
		.BYTE  $3C
		.BYTE  $3C
		.BYTE  $3C
		.BYTE  $30
		.BYTE	$F
		.BYTE  $C0
		.BYTE  $C3
		.BYTE  $FF
		.BYTE  $55
		.BYTE	 0
		.BYTE  $AB
		.BYTE  $AB
		.BYTE	 3
		.BYTE	 3
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $55
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $55
		.BYTE  $CF
		.BYTE  $CF
		.BYTE  $CF
		.BYTE  $CF
		.BYTE  $CF
		.BYTE  $FF
		.BYTE  $55
		.BYTE  $C6
		.BYTE  $C6
		.BYTE  $C6
		.BYTE  $55
		.BYTE  $F0
		.BYTE  $F0
		.BYTE  $CF
		.BYTE  $CF
		.BYTE  $55
		.BYTE	 1
		.BYTE  $55
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $55
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 0
		.BYTE  $AB
		.BYTE	 3
		.BYTE  $57
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 7
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE  $AA
		.BYTE  $FF
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3
		.BYTE	 3

; token address tables (verb dispatch tables)

VERBADRL:
		.byte	BEGIN_LINE&255
		.byte	$FF
		.byte	$FF
		.byte	COLON&255
		.byte  	LOAD&255
		.byte	BAS_SAVE&255
		.byte	CON&255
		.byte	RUNNUM&255
		.byte	RUN&255
		.byte	DEL&255
		.byte	COMMA_DEL&255
		.byte	NEW&255
		.byte	CLR&255
		.byte	AUTO&255
		.byte	COMMA_AUTO&255
		.byte	MAN&255
		.byte	VHIMEM&255
		.byte	VLOMEM&255
		.byte	ADDITION&255
		.byte	SUBTRACT&255
		.byte	MULT&255
		.byte	DIVIDE&255
		.byte	sub_0_E733&255
		.byte	sub_0_E74A&255
		.byte	sub_0_F25B&255
		.byte	sub_0_F24E&255
		.byte	sub_0_F253&255
		.byte	sub_0_E74A&255
		.byte	sub_0_F249&255
		.byte	VAND&255
		.byte	VOR&255
		.byte	MOD&255
		.byte	EXP&255
		.byte	$FF
		.byte	loc_0_E823&255
		.byte	COMMA_SUBSTR&255
		.byte	GOTO&255
		.byte	LET&255
		.byte	sub_0_EFB6&255
		.byte	sub_0_EBCB&255
		.byte	$FF
		.byte	$FF
		.byte	PAREN_SUBSTR&255
		.byte	$FF
		.byte	$FF
		.byte	sub_0_EF24&255
		.byte	PEEK&255
		.byte	RND&255
		.byte	SGN&255
		.byte	ABS&255
		.byte	PDL&255
		.byte	$FF
		.byte	loc_0_E823&255
		.byte	POSITIVE&255
		.byte	NEGATE&255
		.byte	NOT&255
		.byte	loc_0_E823&255
		.byte	sub_0_E1D7&255
		.byte	loc_0_E21C&255
		.byte	LEN&255
		.byte	ASC&255
		.byte	SCRN&255
		.byte	COMMA_SCRN&255
		.byte	loc_0_E823&255
		.byte	$FF
		.byte	$FF
		.byte	loc_0_E121&255
		.byte	DIMSTR&255
		.byte	DIMNUM&255
		.byte	PRNTSTR&255
		.byte	PRNTNUM&255
		.byte	sub_0_E820&255
		.byte	sub_0_EE00&255
		.byte	sub_0_E7C1&255
		.byte	sub_0_F3BA&255
		.byte	SETTXT&255
		.byte	SETGR&255
		.byte	CALL&255
		.byte	DIMSTR&255
		.byte	DIMNUM&255
		.byte	TAB&255
		.byte	END&255
		.byte	sub_0_EFB6&255
		.byte	INPUT_PROMPT&255
		.byte	loc_0_EBAA&255
		.byte	FOR&255
		.byte	sub_0_E801&255
		.byte	TO&255
		.byte	BAS_STEP&255
		.byte	NEXT&255
		.byte	NEXT&255
		.byte	RETURN&255
		.byte	GOSUB&255
		.byte	$FF
		.byte	LET&255
		.byte	GOTO&255
		.byte	IF&255
		.byte	PRNTSTR&255
		.byte	PRNTNUM&255
		.byte	PRINT_CR&255
		.byte	POKE&255
		.byte	GETVAL255&255
		.byte	BAS_COLOR&255
		.byte	GETVAL255&255
		.byte	COMMA_PLOT&255
		.byte	GETVAL255&255
		.byte	COMMA_HLIN&255
		.byte	AT_HLIN&255
		.byte	GETVAL255&255
		.byte	COMMA_VLIN&255
		.byte	AT_VLIN&255
		.byte	IVTAB&255
		.byte	sub_0_E18C&255
		.byte	sub_0_E801&255
		.byte	RIGHT_PAREN&255
		.byte	$FF
		.byte	LISTNUM&255
		.byte	COMMA_LIST&255
		.byte	BAS_LIST&255
		.byte	POP&255
		.byte	NODSP_STR&255
		.byte	NODSP_NUM&255
		.byte	NOTRACE&255
		.byte	DSP_NUM&255
		.byte	DSP_STR&255
		.byte	BAS_TRACE&255
		.byte	PRSLOT&255
		.byte	INSLOT&255

VERBADRH:
		.byte	BEGIN_LINE/256
		.byte	$FF
		.byte	$FF
		.byte	COLON/256
		.byte  	LOAD/256
		.byte	BAS_SAVE/256
		.byte	CON/256
		.byte	RUNNUM/256
		.byte	RUN/256
		.byte	DEL/256
		.byte	COMMA_DEL/256
		.byte	NEW/256
		.byte	CLR/256
		.byte	AUTO/256
		.byte	COMMA_AUTO/256
		.byte	MAN/256
		.byte	VHIMEM/256
		.byte	VLOMEM/256
		.byte	ADDITION/256
		.byte	SUBTRACT/256
		.byte	MULT/256
		.byte	DIVIDE/256
		.byte	sub_0_E733/256
		.byte	sub_0_E74A/256
		.byte	sub_0_F25B/256
		.byte	sub_0_F24E/256
		.byte	sub_0_F253/256
		.byte	sub_0_E74A/256
		.byte	sub_0_F249/256
		.byte	VAND/256
		.byte	VOR/256
		.byte	MOD/256
		.byte	EXP/256
		.byte	$FF
		.byte	loc_0_E823/256
		.byte	COMMA_SUBSTR/256
		.byte	GOTO/256
		.byte	LET/256
		.byte	sub_0_EFB6/256
		.byte	sub_0_EBCB/256
		.byte	$FF
		.byte	$FF
		.byte	PAREN_SUBSTR/256
		.byte	$FF
		.byte	$FF
		.byte	sub_0_EF24/256
		.byte	PEEK/256
		.byte	RND/256
		.byte	SGN/256
		.byte	ABS/256
		.byte	PDL/256
		.byte	$FF
		.byte	loc_0_E823/256
		.byte	POSITIVE/256
		.byte	NEGATE/256
		.byte	NOT/256
		.byte	loc_0_E823/256
		.byte	sub_0_E1D7/256
		.byte	loc_0_E21C/256
		.byte	LEN/256
		.byte	ASC/256
		.byte	SCRN/256
		.byte	COMMA_SCRN/256
		.byte	loc_0_E823/256
		.byte	$FF
		.byte	$FF
		.byte	loc_0_E121/256
		.byte	DIMSTR/256
		.byte	DIMNUM/256
		.byte	PRNTSTR/256
		.byte	PRNTNUM/256
		.byte	sub_0_E820/256
		.byte	sub_0_EE00/256
		.byte	sub_0_E7C1/256
		.byte	sub_0_F3BA/256
		.byte	SETTXT/256
		.byte	SETGR/256
		.byte	CALL/256
		.byte	DIMSTR/256
		.byte	DIMNUM/256
		.byte	TAB/256
		.byte	END/256
		.byte	sub_0_EFB6/256
		.byte	INPUT_PROMPT/256
		.byte	loc_0_EBAA/256
		.byte	FOR/256
		.byte	sub_0_E801/256
		.byte	TO/256
		.byte	BAS_STEP/256
		.byte	NEXT/256
		.byte	NEXT/256
		.byte	RETURN/256
		.byte	GOSUB/256
		.byte	$FF
		.byte	LET/256
		.byte	GOTO/256
		.byte	IF/256
		.byte	PRNTSTR/256
		.byte	PRNTNUM/256
		.byte	PRINT_CR/256
		.byte	POKE/256
		.byte	GETVAL255/256
		.byte	BAS_COLOR/256
		.byte	GETVAL255/256
		.byte	COMMA_PLOT/256
		.byte	GETVAL255/256
		.byte	COMMA_HLIN/256
		.byte	AT_HLIN/256
		.byte	GETVAL255/256
		.byte	COMMA_VLIN/256
		.byte	AT_VLIN/256
		.byte	IVTAB/256
		.byte	sub_0_E18C/256
		.byte	sub_0_E801/256
		.byte	RIGHT_PAREN/256
		.byte	$FF
		.byte	LISTNUM/256
		.byte	COMMA_LIST/256
		.byte	BAS_LIST/256
		.byte	POP/256
		.byte	NODSP_STR/256
		.byte	NODSP_NUM/256
		.byte	NOTRACE/256
		.byte	DSP_NUM/256
		.byte	DSP_STR/256
		.byte	BAS_TRACE/256
		.byte	PRSLOT/256
		.byte	INSLOT/256

ErrorMsgs:
Err_GT32767	.equ	*-ErrorMsgs
		.BYTE  $BE
		.BYTE  $B3
		.BYTE  $B2
		.BYTE  $B7
		.BYTE  $B6
		.BYTE  $37

Err_TooLong	.equ	*-ErrorMsgs
		.BYTE  $D4
		.BYTE  $CF
		.BYTE  $CF
		.BYTE  $A0
		.BYTE  $CC
		.BYTE  $CF
		.BYTE  $CE
		.BYTE  $47

Err_Syntax	.equ	*-ErrorMsgs
		.BYTE  $D3
		.BYTE  $D9
		.BYTE  $CE
		.BYTE  $D4
		.BYTE  $C1
		.BYTE  $58

Err_MemFull	.equ	*-ErrorMsgs
		.BYTE  $CD
		.BYTE  $C5
		.BYTE  $CD
		.BYTE  $A0
		.BYTE  $C6
		.BYTE  $D5
		.BYTE  $CC
		.BYTE  $4C

Err_ManyParens	.equ	*-ErrorMsgs
		.BYTE  $D4
		.BYTE  $CF
		.BYTE  $CF
		.BYTE  $A0
		.BYTE  $CD
		.BYTE  $C1
		.BYTE  $CE
		.BYTE  $D9
		.BYTE  $A0
		.BYTE  $D0
		.BYTE  $C1
		.BYTE  $D2
		.BYTE  $C5
		.BYTE  $CE
		.BYTE  $53

Err_String	.equ	*-ErrorMsgs
		.BYTE  $D3
		.BYTE  $D4
		.BYTE  $D2
		.BYTE  $C9
		.BYTE  $CE
		.BYTE  $47

Err_NoEnd	.equ	*-ErrorMsgs
		.BYTE  $CE
		.BYTE  $CF
		.BYTE  $A0
		.BYTE  $C5
		.BYTE  $CE
		.BYTE  $44

Err_BadBranch	.equ	*-ErrorMsgs
		.BYTE  $C2
		.BYTE  $C1
		.BYTE  $C4
		.BYTE  $A0
		.BYTE  $C2
		.BYTE  $D2
		.BYTE  $C1
		.BYTE  $CE
		.BYTE  $C3
		.BYTE  $48

Err_16GoSubs	.equ	*-ErrorMsgs
		.BYTE  $B1
		.BYTE  $B6
		.BYTE  $A0
		.BYTE  $C7
		.BYTE  $CF
		.BYTE  $D3
		.BYTE  $D5
		.BYTE  $C2
		.BYTE  $53

Err_BadReturn	.equ	*-ErrorMsgs
		.BYTE  $C2
		.BYTE  $C1
		.BYTE  $C4
		.BYTE  $A0
		.BYTE  $D2
		.BYTE  $C5
		.BYTE  $D4
		.BYTE  $D5
		.BYTE  $D2
		.BYTE  $4E

Err_16Fors	.equ	*-ErrorMsgs
		.BYTE  $B1
		.BYTE  $B6
		.BYTE  $A0
		.BYTE  $C6
		.BYTE  $CF
		.BYTE  $D2
		.BYTE  $53

Err_BadNext	.equ	*-ErrorMsgs
		.BYTE  $C2
		.BYTE  $C1
		.BYTE  $C4
		.BYTE  $A0
		.BYTE  $CE
		.BYTE  $C5
		.BYTE  $D8
		.BYTE  $54

Err_StoppedAt	.equ	*-ErrorMsgs
		.BYTE  $D3
		.BYTE  $D4
		.BYTE  $CF
		.BYTE  $D0
		.BYTE  $D0
		.BYTE  $C5
		.BYTE  $C4
		.BYTE  $A0
		.BYTE  $C1
		.BYTE  $D4
		.BYTE  $20

Err_Stars	.equ	*-ErrorMsgs
		.BYTE  $AA
		.BYTE  $AA
		.BYTE  $AA
		.BYTE  $20

Err_ERR		.equ	*-ErrorMsgs
		.BYTE  $A0
		.BYTE  $C5
		.BYTE  $D2
		.BYTE  $D2
		.BYTE	$D

Err_GT255	.equ	*-ErrorMsgs
		.BYTE  $BE
		.BYTE  $B2
		.BYTE  $B5
		.BYTE  $35

Err_Range	.equ	*-ErrorMsgs
		.BYTE  $D2
		.BYTE  $C1
		.BYTE  $CE
		.BYTE  $C7
		.BYTE  $45

Err_Dim		.equ	*-ErrorMsgs
		.BYTE  $C4
		.BYTE  $C9
		.BYTE  $4D

Err_StrOvfl	.equ	*-ErrorMsgs
		.BYTE  $D3
		.BYTE  $D4
		.BYTE  $D2
		.BYTE  $A0
		.BYTE  $CF
		.BYTE  $D6
		.BYTE  $C6
		.BYTE  $4C

		.BYTE  $DC
		.BYTE	$D

Err_Retype	.equ	*-ErrorMsgs
		.BYTE  $D2
		.BYTE  $C5
		.BYTE  $D4
		.BYTE  $D9
		.BYTE  $D0
		.BYTE  $C5
		.BYTE  $A0
		.BYTE  $CC
		.BYTE  $C9
		.BYTE  $CE
		.BYTE  $C5
		.BYTE  $8D

Err_Question	.equ	*-ErrorMsgs
		.BYTE  $3F


; continue running w/o deleting vars?

loc_0_EB9A:				; solo
		LSR	RUNFLAG		; pos	
		BCC	loc_0_EBA1
		JMP	STOPPED_AT

loc_0_EBA1:
		LDX	ACC+1	
		TXS	
		LDX	ACC
		LDY	#Err_Retype	; "RETYPE LINE",CR,"?"
		BNE	loc_0_EBAC


; token $54 INPUT
; num with no prompt
; INPUT X

loc_0_EBAA:				; VO branch	
		LDY	#Err_Question	; "?" for INPUT
loc_0_EBAC:
		JSR	ERRORMESS
		STX	ACC
		TSX	
		STX	ACC+1	
		JSR	sub_0_F366
		STY	TOKNDX	
		LDA	#$FF
		STA	TXTNDX	
		ASL	A
		STA	RUNFLAG		; neg	
		LDX	#$20
		LDA	#$15
		JSR	sub_0_E491
		INC	RUNFLAG	
		LDX	ACC


; token $27 ,
; num inputs
; INPUT "QUANTITY",Q

sub_0_EBCB:				; VO
		LDY	TXTNDX	
		ASL	A
loc_0_EBCE:
		STA	ACC
		INY	
		LDA	IN,Y
		CMP	#$80
		BEQ	loc_0_EBAA	; end of input?
		EOR	#'0'+$80
		CMP	#10
		BCS	loc_0_EBCE
		INY	
		INY	
		STY	TXTNDX	
		LDA	IN,Y
		PHA	
		LDA	IN-1,Y
		LDY	#0
		JSR	sub_0_E708
		PLA	
		STA	NOUNSTKC,X
		LDA	ACC
		CMP	#$33
		BNE	loc_0_EBFA
		JSR	NEGATE
loc_0_EBFA:
		JMP	sub_0_E801

	;	.BYTE  $FF,$FF,$FF	can turn this off since org $ec00 for SYNTABLs


; token/syntax table
;
; SYNTABL & SYNTABL2 ***MUST*** start on page boundaries!!
;
		.org	$ec00

SYNTABL:
		.BYTE  $50

		.BYTE  $20
		.BYTE  $4F
		.BYTE  $C0
	
		.byte	'T'+160, 'A'+96
		.byte	'D'+160, 'O'+96, 'M'+96
		.byte	'R'+160, 'O'+96
		.byte	'D'+160, 'N'+96, 'A'+96
		.byte	'P'+160, 'E'+96, 'T'+96, 'S'+96
		.byte	'O'+160, 'T'+96
		.byte	'N'+160, 'E'+96, 'H'+96, 'T'+96
		
		.BYTE  $5C,$80,$00,$40
		.BYTE  $60,$8D,$60,$8B,$7F,$1D,$20,$7E
		.BYTE  $8C,$33,$00,$00,$60,$03,$BF,$12

		.BYTE  	$47, '#'+96, 'N'+96, 'I'+96
		.BYTE  	$67, '#'+96, 'R'+96, 'P'+96

		.byte	'E'+160, 'C'+96, 'A'+96, 'R'+96, 'T'+96	
		.byte	$79, 'P'+96, 'S'+96, 'D'+96
		.byte	$69, 'P'+96, 'S'+96, 'D'+96
		.byte	'E'+160, 'C'+96, 'A'+96, 'R'+96, 'T'+96, 'O'+96, 'N'+96	
		.byte	$79, 'P'+96, 'S'+96, 'D'+96, 'O'+96, 'N'+96
		.byte	$69, 'P'+96, 'S'+96, 'D'+96, 'O'+96, 'N'+96
		
		.byte	'P'+160, 'O'+96, 'P'+96
		.byte	'T'+160, 'S'+96, 'I'+96, 'L'+96

		.byte	$60, ','+96

		.byte	$20, 'T'+96, 'S'+96, 'I'+96, 'L'+96

		.byte	$00
		.byte	$40, $89

		.byte	')'+160

		.byte	$47, '='+96

		.byte	$17, $68, '='+96

		.byte	$0A, $58, $7B, $67, 'B'+96, 'A'+96, 'T'+96, 'V'+96
		.byte	$67, 'T'+96, 'A'+96
		.byte	$07, ','+96
		.byte	$07, 'N'+96, 'I'+96, 'L'+96, 'V'+96
		.byte	$67, 'T'+96, 'A'+96
		.byte	$07, ','+96
		.byte	$07, 'N'+96, 'I'+96, 'L'+96, 'H'+96
		.byte	$67, ','+96
	
		.byte	$07, 'T'+96, 'O'+96, 'L'+96, 'P'+96
		.byte	$67, '='+96, 'R'+96, 'O'+96, 'L'+96, 'O'+96, 'C'+96
		.byte	$67, ','+96
		.byte	$07, 'E'+96, 'K'+96, 'O'+96, 'P'+96
		.byte	'T'+160, 'N'+96, 'I'+96, 'R'+96, 'P'+96
		.byte	$7F, $0E, $27, 'T'+96, 'N'+96, 'I'+96, 'R'+96, 'P'+96
		.byte	$7F, $0E, $28, 'T'+96, 'N'+96, 'I'+96, 'R'+96, 'P'+96

		.byte	$64, $07, 'F'+96, 'I'+96
		.byte	$67, 'O'+96, 'T'+96, 'O'+96, 'G'+96
		.byte	$78, 'T'+96, 'E'+96, 'L'+96
		.byte	$6B, $7F, $02, 'M'+96, 'E'+96, 'R'+96
		.byte	$67, 'B'+96, 'U'+96, 'S'+96, 'O'+96, 'G'+96
		.byte	'N'+160, 'R'+96, 'U'+96, 'T'+96, 'E'+96, 'R'+96
		
		.byte	$7E, ','+96
		.byte	$39, 'T'+96, 'X'+96, 'E'+96, 'N'+96
		.byte	$67, 'P'+96, 'E'+96, 'T'+96, 'S'+96
		.byte	$27, 'O'+96, 'T'+96
		.byte	$07, '='+96
		.byte	$19, 'R'+96, 'O'+96, 'F'+96
		.byte	$7F, $05, $37, 'T'+96, 'U'+96, 'P'+96, 'N'+96, 'I'+96
		.byte	$7F, $05, $28, 'T'+96, 'U'+96, 'P'+96, 'N'+96, 'I'+96
		.byte	$7F, $05, $2A, 'T'+96, 'U'+96, 'P'+96, 'N'+96, 'I'+96
		.byte	'D'+160, 'N'+96, 'E'+96

SYNTABL2:
		.byte	$00

		.byte	$47, 'B'+96, 'A'+96, 'T'+96
		.byte	$7F, $0D, $30, 'M'+96, 'I'+96, 'D'+96
		.byte	$7F, $0D, $23, 'M'+96, 'I'+96, 'D'+96
		.byte	$67, 'L'+96, 'L'+96, 'A'+96, 'C'+96
		
		.byte	'R'+160, 'G'+96
		.byte	'T'+160, 'X'+96, 'E'+96, 'T'+96

		.byte	0			; above are statements

		.byte	$4D, ','+160
		.byte	$67, ','+96
		.byte	$68, ','+96

		.byte	';'+160

		.byte	$67, ';'+96
		.byte	$68, ';'+96
		.byte	$50, ','+96
		.byte	$63, ','+96
		.byte	$7F, $01, $51, $07, '('+96
		.byte	$29, $84
		.byte	$80, '$'+160
		.byte	$19, $57, $71, $07, '('+96
		.byte	$14, $71, $07, ','+96

		.byte	$07, '('+96, 'N'+96, 'R'+96, 'C'+96, 'S'+96
		.byte	$71, $08, '('+96, 'C'+96, 'S'+96, 'A'+96
		.byte	$71, $08, '('+96, 'N'+96, 'E'+96, 'L'+96
		.byte	$68, '#'+96
		.byte	$08, $68, '='+96
		.byte	$08, $71, $07, '('+96
		.byte	$60, $75, 'T'+96, 'O'+96, 'N'+96

		.byte	$75, '-'+96
		.byte	$75, '+'+96
		.byte	$51, $07, '('+96
		.byte	$19, 'X'+96, 'D'+96, 'N'+96, 'R'+96
		.byte	'L'+160, 'D'+96, 'P'+96
		.byte	'S'+160, 'B'+96, 'A'+96
		.byte	'N'+160, 'G'+96, 'S'+96
		.byte	'D'+160, 'N'+96, 'R'+96
		.byte	'K'+160, 'E'+96, 'E'+96, 'P'+96
		
		.byte	$51, $07, '('+96
		.byte	$39, $81, $C1, $4F, $7F, $0F, $2F

		.byte	$00			; above are functions

		.byte	$51, $06, '('+96
		.byte	$29, $22+160		; open quote
		.byte	$0C, $22+96		; close quote
		.byte	$57, ','+96
		.byte	$6A, ','+96
		.byte	$42, 'N'+96, 'E'+96, 'H'+96, 'T'+96
		.byte	$60, 'N'+96, 'E'+96, 'H'+96, 'T'+96
	
		.byte	$4F, $7E, $1E, $35, ','+96
		.byte	$27, $51, $07, '('+96
		.byte	$09, '+'+96
		.byte	'^'+160			; exponent
		.byte	'D'+160, 'O'+96, 'M'+96
		.byte	'R'+160, 'O'+96
		.byte	'D'+160, 'N'+96, 'A'+96

		.byte	'<'+160			; LT
		.byte	'>'+160, '<'+96		; NE
		.byte	'='+160, '<'+96		; LE
		.byte	'>'+160			; GT
		.byte	'='+160, '>'+96		; GE
		.byte	'#'+160			; NE
		.byte	'='+160			; EQ
		.byte	'/'+160			; div
		.byte	'*'+160			; mul
		.byte	'-'+160			; sub
		.byte	'+'+160			; add

		.byte	$00			; above 4 are num ops

		.byte	$47, ':'+96, 'M'+96, 'E'+96, 'M'+96, 'O'+96, 'L'+96
		.byte	$67, ':'+96, 'M'+96, 'E'+96, 'M'+96, 'I'+96, 'H'+96
		.byte	'N'+160, 'A'+96, 'M'+96
		.byte	$60, ','+96
		.byte	$20, 'O'+96, 'T'+96, 'U'+96, 'A'+96
		.byte	'R'+160, 'L'+96, 'C'+96
		.byte	'W'+160, 'E'+96, 'N'+96
		.byte	$60, ','+96
		.byte	$20, 'L'+96, 'E'+96, 'D'+96
		.byte	'N'+160, 'U'+96, 'R'+96
		.byte	$60, 'N'+96, 'U'+96, 'R'+96
		.byte	'N'+160, 'O'+96, 'C'+96
		.byte	'E'+160, 'V'+96, 'A'+96, 'S'+96
		.byte	'D'+160, 'A'+96, 'O'+96, 'L'+96

		; above are commands

		.byte	$7A, $7E, $9A, $22, $20
		.byte	$00, $60, $03, $BF, $60, $03, $BF, $1F


; token $48 ,
; string prints
; PRINT T,A$

sub_0_EE00:
		JSR	sub_0_E7B1


; token $45 ;
; string prints
; PRINT anytype ; string

; token $61 PRINT
; string var or literal
; PRINT A$: PRINT "HELLO"

PRNTSTR:				; V
		INX	
		INX	
		LDA	NOUNSTKL-1,X
		STA	AUX
		LDA	NOUNSTKH-1,X
		STA	AUX+1	
		LDY	NOUNSTKL-2,X
loc_0_EE0F:
		TYA	
		CMP	NOUNSTKH-2,X
		BCS	loc_0_EE1D
		LDA	(AUX),Y
		JSR	COUT	
		INY	
		JMP	loc_0_EE0F

loc_0_EE1D:
		LDA	#$FF
		STA	CRFLAG		; CRFLAG = $FF	
		RTS	


; token $3B LEN(

LEN:
		INX	
		LDA	#0
		STA	NOUNSTKH,X
		STA	NOUNSTKC,X
		LDA	NOUNSTKH-1,X
		SEC	
		SBC	NOUNSTKL-1,X
		STA	NOUNSTKL,X
		JMP	loc_0_E823

		.BYTE  $FF

GETBYTE:
		JSR	GET16BIT
		LDA	ACC+1	
		BNE	HI255ERR
		LDA	ACC
		RTS	


; token $68 ,
; PLOT 20,15

COMMA_PLOT:
		JSR	GETBYTE
		LDY	TXTNDX	
		CMP	#48
		BCS	RANGERR
		CPY	#40
		BCS	RANGERR
		JMP	PLOT	


; token $66 COLOR=

BAS_COLOR:
		JSR	GETBYTE
		JMP	SETCOL	


; token $0F MAN

MAN:
		LSR	AUTOFLAG	; manual	
		RTS	


; token $6F VTAB

IVTAB:					; VO
		JSR	sub_0_F3B3
		CMP	#24
		BCS	RANGERR
		STA	CV	
		JMP	VTAB	

HI255ERR:		
		LDY	#Err_GT255	; ">255"
loc_0_EE65:
		JMP	ERRMESS

RANGERR:
		LDY	#Err_Range	; "RANGE"
		BNE	loc_0_EE65

; divide routine

sub_0_EE6C:
		JSR	sub_0_E254
		LDA	AUX
		BNE	loc_0_EE7A
		LDA	AUX+1	
		BNE	loc_0_EE7A
		JMP	loc_0_E77E

loc_0_EE7A:
		ASL	ACC
		ROL	ACC+1	
		ROL	P3	
		ROL	P3+1	
		LDA	P3	
		CMP	AUX
		LDA	P3+1	
		SBC	AUX+1	
		BCC	loc_0_EE96
		STA	P3+1	
		LDA	P3	
		SBC	AUX
		STA	P3	
		INC	ACC
loc_0_EE96:
		DEY	
		BNE	loc_0_EE7A
		RTS	

		.BYTE  $FF,$FF,$FF,$FF,$FF,$FF


; token $4D CALL

CALL:					; VO
		JSR	GET16BIT
		JMP	(ACC)


; token $6A ,
; HLIN 10,20 AT 30

COMMA_HLIN:				; VO
		JSR	GETBYTE
		CMP	TXTNDX	
		BCC	RANGERR
		STA	H2	
		RTS	


; token $6B AT
; HLIN 10,20 AT 30

AT_HLIN:
		JSR	GETBYTE
		CMP	#48
		BCS	RANGERR
		LDY	TXTNDX	
		JMP	HLINE	


; token $6D ,
; VLIN 10,20 AT 30

COMMA_VLIN:
		JSR	GETBYTE
		CMP	TXTNDX	
		BCC	RANGERR
		STA	V2	
		RTS	


; token $6E AT
; VLIN 10,20 AT 30

AT_VLIN:
		JSR	GETBYTE
		CMP	#40
loc_0_EECB:
		BCS	RANGERR
		TAY	
		LDA	TXTNDX	
		JMP	VLINE	


PRINTERR:
		TYA	
		TAX	
		LDY	#Err_Stars	; "*** "
		JSR	ERRORMESS
		TXA	
		TAY	
		JSR	ERRORMESS
		LDY	#Err_ERR	; " ERR" + CR
		JMP	PRTERR


sub_0_EEE4:
		JSR	sub_0_F23F
loc_0_EEE7:
		ASL	ACC
		ROL	ACC+1	
		BMI	loc_0_EEE7
		BCS	loc_0_EECB
		BNE	locret_0_EEF5
		CMP	ACC
		BCS	loc_0_EECB
locret_0_EEF5:
		RTS	


; token $2E PEEK
; uses token $3F (

PEEK:					; VO
		JSR	GET16BIT
		LDA	(ACC),Y
		STY	NOUNSTKC-1,X
		JMP	sub_0_E708


; token $65 ,
; POKE 20000,5

; token $67 PLOT

; token $69 HLIN

; token $6C VLIN

GETVAL255:				; VO
		JSR	GETBYTE
		LDA	ACC
		STA	TXTNDX	
		RTS	


; token $64 POKE

POKE:					; VO
		JSR	GET16BIT
		LDA	TXTNDX	
		STA	(ACC),Y
		RTS	


; token $15 /
; num op, uses $38 (
; A = 27 / 2

DIVIDE:					; VO
		JSR	sub_0_EE6C
		LDA	ACC
		STA	P3	
		LDA	ACC+1	
		STA	P3+1	
		JMP	loc_0_E244


; token $44 ,
; next var in DIM is num
; DIM X(5),A(5)

; token $4F DIM
; num var, uses $22 (
; DIM A(5)

DIMNUM:					; VO
		JSR	sub_0_EEE4
		JMP	loc_0_E134


; token $2D (
; var array
; X(12)

sub_0_EF24:				; VO
		JSR	sub_0_EEE4
		LDY	NOUNSTKH,X
		LDA	NOUNSTKL,X
		ADC	#-2
		BCS	loc_0_EF30
		DEY	
loc_0_EF30:
		STA	AUX
		STY	AUX+1	
		CLC	
		ADC	ACC
		STA	NOUNSTKL,X
		TYA	
		ADC	ACC+1	
		STA	NOUNSTKH,X
		LDY	#0
		LDA	NOUNSTKL,X
		CMP	(AUX),Y
		INY	
		LDA	NOUNSTKH,X
		SBC	(AUX),Y
		BCS	loc_0_EECB
		JMP	loc_0_E823


; token $2F RND
; uses $3F (

RND:					; VO
		JSR	GET16BIT
		LDA	RNDL	
		JSR	sub_0_E708
		LDA	RNDH	
		BNE	loc_0_EF5E
		CMP	RNDL	
		ADC	#0

loc_0_EF5E:
		AND	#$7F
		STA	RNDH	
		STA	NOUNSTKC,X
		LDY	#$11
loc_0_EF66:
		LDA	RNDH	
		ASL	A
		CLC	
		ADC	#$40
		ASL	A
		ROL	RNDL	
		ROL	RNDH	
		DEY	
		BNE	loc_0_EF66
		LDA	ACC
		JSR	sub_0_E708
		LDA	ACC+1	
		STA	NOUNSTKC,X
		JMP	MOD	


		JSR	GET16BIT
		LDY	ACC
		CPY	LOMEM
		LDA	ACC+1	
		SBC	LOMEM+1	
		BCC	loc_0_EFAB
		STY	HIMEM
		LDA	ACC+1	
		STA	HIMEM+1	
loc_0_EF93:
		JMP	NEW
		JSR	GET16BIT
		LDY	ACC
		CPY	HIMEM
		LDA	ACC+1	
		SBC	HIMEM+1	
		BCS	loc_0_EFAB
		STY	LOMEM
		LDA	ACC+1	
		STA	LOMEM+1	
		BCC	loc_0_EF93

loc_0_EFAB:
		JMP	loc_0_EECB

		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $FF


; token $26 ,
; string inputs
; INPUT "WHO",W$

; token $52 INPUT
; string with no prompt
; INPUT S$

sub_0_EFB6:				; VO
		JSR	INPUTSTR
		JMP	loc_0_EFBF


; token $53 INPUT
; string or num with prompt
; INPUT "WHO",W$: INPUT "QUANTITY",Q

INPUT_PROMPT:				; VO
		JSR	PRNTSTR
loc_0_EFBF:
		LDA	#-1
		STA	TXTNDX	
		LDA	#$80
		STA	IN	
		RTS	


sub_0_EFC9:
		JSR	NOT
		INX	
sub_0_EFCD:				; solo
		JSR	NOT
		LDA	NOUNSTKL,X
		RTS	


; old 4K cold start

sub_0_EFD3:
		LDA	#0
		STA	LOMEM		; LOMEM = $0800
		STA	HIMEM		; HIMEM = $1000
		LDA	#$0800/256
		STA	LOMEM+1	
		LDA	#$1000/256
		STA	HIMEM+1	
		JMP	NEW


sub_0_EFE4:				; solo
		CMP	NOUNSTKH,X
		BNE	loc_0_EFE9
		CLC	
loc_0_EFE9:
		JMP	loc_0_E102


; token $08 RUN
; run from 1st line of program

RUN:					; VO
		JSR	CLR
		JMP	RUNWARM


; token $07 RUN
; RUN 100

RUNNUM:
		JSR	CLR
		JMP	GOTO


sub_0_EFF8:				; solo
		CPX	#$80
		BNE	loc_0_EFFD
		DEY	
loc_0_EFFD:
		JMP	sub_0_E00C


; Cold Start
;	set LOMEM, find HIMEM
;	fall into NEW

COLD:
		ldy	#0
		sty	NOUNSTKC
		sty	LOMEM
		sty	HIMEM
		lda	#$0800/256
		sta	LOMEM+1		; LOMEM = $0800 (2KB)
		lda	#$8000/256
		sta	HIMEM+1		; HIMEM = $8000 (32KB)
		jmp	NEW


;		LDY	#0
;		STY	NOUNSTKC	
;		STY	LOMEM
;		STY	HIMEM
;		LDA	#$0800/256
;		STA	LOMEM+1	
;		STA	HIMEM+1		; LOMEM = HIMEM = $0800 (2KB)	
;loc_0_F00E:
;		INC	HIMEM+1		; HIMEM += 256  find top of RAM	
;		LDA	(HIMEM),Y	; fetch byte at test loc
;		EOR	#$FF		; and invert it
;		STA	(HIMEM),Y	; and write it back
;		CMP	(HIMEM),Y	; did it stick?
;		BNE	loc_0_F022	; no, must be end of RAM
;		EOR	#$FF		; yes, put it back like it was
;		STA	(HIMEM),Y
;		CMP	(HIMEM),Y	; did the un-inverted val stick?
;		BEQ	loc_0_F00E	; yes!

;loc_0_F022:
;		JMP	NEW


loc_0_F025:				; solo
		JMP	loc_0_F179

		jsr	sub_0_F032
		jmp	loc_0_E8BE

sub_0_F02E:				; solo
		LDX	PX	
		LDA	PX+1	
sub_0_F032:
		lda	#$08
		bit	ACIABASE+STAT
		beq	loc_0_F025
		lda	ACIABASE+DATA
		cmp	#ETX
		bne	loc_0_F025

	;	jmp	loc_0_F025	; HACK HACK HACK
		
	;	LDY	KBD		; get keypress
	;	CPY	#ETX+$80	; is it Ctl-C?
	;	BNE	loc_0_F025	; no
	;	BIT	KBDSTRB		; yes, clear keypress

		STX	NOUNSTKL
		STA	NOUNSTKL+1	
		LDA	PR	
		STA	NOUNSTKH
		LDA	PR+1	
		STA	NOUNSTKH+1	
		JMP	STOPPED_AT

		.BYTE  $FF
		.BYTE  $FF


; token $10 HIMEM:

VHIMEM:					; VO
		JSR	GET16BIT
		STX	XSAVE	
		LDX	#-2
		SEC	
loc_0_F055:
		LDA	ACC+2,X
		STA	P2+2,X
		LDA	HIMEM+2,X
		SBC	ACC+2,X
		STA	AUX+2,X
		INX	
		BNE	loc_0_F055
		BCC	loc_0_F0AF
		DEX	
loc_0_F065:
		LDA	PP+1,X
		STA	P3+1,X
		SBC	AUX+1,X
		STA	P2+1,X
		INX	
		BEQ	loc_0_F065
		BCC	loc_0_F07C
		LDA	PV
		CMP	P2	
		LDA	PV+1	
		SBC	P2+1	
		BCC	loc_0_F08F

loc_0_F07C:
		JMP	MEMFULL

loc_0_F07F:
		LDA	(P3),Y
		STA	(P2),Y
		INC	P2	
		BNE	loc_0_F089
		INC	P2+1	
loc_0_F089:
		INC	P3	
		BNE	loc_0_F08F
		INC	P3+1	

loc_0_F08F:
		LDA	P3	
		CMP	HIMEM
		LDA	P3+1	
		SBC	HIMEM+1	
		BCC	loc_0_F07F

loc_0_F099:
		LDX	#-2

loc_0_F09B:
		LDA	P2+2,X
		STA	HIMEM+2,X
		LDA	PP+2,X
		SBC	AUX+2,X
		STA	PP+2,X
		INX	
		BNE	loc_0_F09B
		LDX	XSAVE	
		RTS	

loc_0_F0AB:
		LDA	(HIMEM),Y
		STA	(ACC),Y
loc_0_F0AF:
		LDA	ACC
		BNE	loc_0_F0B5
		DEC	ACC+1	
loc_0_F0B5:
		DEC	ACC
		LDA	HIMEM
		BNE	loc_0_F0BD
		DEC	HIMEM+1	
loc_0_F0BD:
		DEC	HIMEM
		CMP	PP	
		LDA	HIMEM+1	
		SBC	PP+1	
		BCC	loc_0_F0AB
		BCS	loc_0_F099


; token $11 LOMEM:

VLOMEM:					; VO
		JSR	GET16BIT
		LDY	ACC		; is ACC <HS> PP?
		CPY	#PP
		LDA	ACC+1	
		SBC	PP+1	
loc_0_F0D4:
		BCS	loc_0_F07C
		STY	LOMEM
		LDA	ACC+1	
		STA	LOMEM+1	
		JMP	CLR


; token $04 LOAD

LOAD:					; VO
		jsr	LOAD_GROSS
	;	STX	XSAVE	
	;	JSR	SETHDR
	;	JSR	READ	

LOAD2:
		LDX	#-1
		SEC	
loc_0_F0EA:
		LDA	HIMEM+1,X	; AUX = HIMEM-ACC
		SBC	ACC+1,X
		STA	AUX+1,X
		INX	
		BEQ	loc_0_F0EA
		BCC	loc_0_F07C
		LDA	PV
		CMP	AUX
		LDA	PV+1	
		SBC	AUX+1	
		BCS	loc_0_F0D4
		LDA	ACC
		BNE	loc_0_F107
		LDA	ACC+1	
		BEQ	loc_0_F118

loc_0_F107:
		LDA	AUX
		STA	PP	
		LDA	AUX+1	
		STA	PP+1	
	;	JSR	SETPRG
	;	JSR	READ	
loc_0_F115:
		LDX	XSAVE	
		RTS	

loc_0_F118:				; solo
		JSR	BELL	
		JMP	loc_0_F115


LOAD_GROSS:
		; ### this is really gross
		lda	#($07FE&$FF)
		sta	A1L
		lda	#($07FE/256)
		sta	A1H

		lda	#($1FFF&$FF)
		sta	A2L
		lda	#($1FFF/256)
		sta	A2H

		jsr	READ		; pull in the entire BASIC space

		STX	XSAVE	

		lda	$7FF
		sta	ACC+1
		lda	$7FE
		sta	ACC		; recover ACC from just below LOMEM

		rts


SETHDR:
		LDY	#ACC		; y = $CE	 prepare to write
		STY	A1		; A1L = $CE	  whatever is in ACC
		INY			; y = $CF	
		STY	A2		; A2L = $CF
		LDY	#0		; y = $00
		STY	A1+1		; A1H = $00
		STY	A2+1		; A2H = $00
		RTS	


SETPRG:
		LDA	PP,X
		STA	A1,X		; A1L/H = BASIC Program Pointer L/H
		LDY	HIMEM,X
		STY	A2,X		; A2L/H = HIMEM L/H
		DEX	
		BPL	SETPRG
		LDA	A2	
		BNE	loc_0_F13D
		DEC	A2+1	
loc_0_F13D:
		DEC	A2	
		RTS	

		STX	XSAVE	


; token $05 SAVE

BAS_SAVE:				; VO
		SEC			; ACC = HIMEM-PP
		LDX	#-1
loc_0_F145:
		LDA	HIMEM+1,X
		SBC	PP+1,X
		STA	ACC+1,X
		INX	
		BEQ	loc_0_F145

		; ### this is a really gross hack
		lda	ACC+1
		sta	$7ff		; ACC+1 in (LOMEM),-1
		lda	ACC
		sta	$7fe		; ACC+0 in (LOMEM),-2

		lda	ACC+1
		jsr	PRBYTE
		lda	ACC
		jsr	PRBYTE
		
	;	JSR	SETHDR
	;	JSR	WRITE		; WRITE ACC

	;	LDX	#1
	;	JSR	SETPRG

	;	LDA	#$1A
	;	JSR	WRITE0	

		sec
		lda	LOMEM
		sbc	#2
		sta	A1L
		lda	LOMEM+1
		sbc	#0
		sta	A1H		; A1L/H -> 2 bytes below LOMEM

		lda	HIMEM
		sta	A2L
		lda	HIMEM+1
		sta	A2H		; A2L/H -> HIMEM

		jsr	WRITE		; write it! 

		LDX	XSAVE	
		RTS	



PRTERR:
		JSR	ERRORMESS
		JSR	CROUT
		JMP	BELL	


; token $77 POP

POP:					; VO
		LDA	GOSUBNDX	
		BNE	loc_0_F16E
		JMP	RETURN
loc_0_F16E:
		DEC	GOSUBNDX	
		RTS	


; token $7D TRACE

BAS_TRACE:				; VO
		LDA	#-1
		STA	NOUNSTKC	
		RTS	


; token $7A NOTRACE

NOTRACE:
		LSR	NOUNSTKC	; clear b7	
		RTS	


loc_0_F179:				; solo
		BIT	NOUNSTKC	; trace mode?	
		BPL	locret_0_F196

sub_0_F17D:
		LDA	#'#'+$80
		JSR	COUT	
		LDY	#1
		LDA	(PR),Y
		TAX	
		INY	
		LDA	(PR),Y
		JSR	PRDEC
		LDA	#SPC+$80
		JMP	COUT	

		LDA	PR	
		LDY	PR+1	
locret_0_F196:
		RTS	

SYNTABLNDX:				; indices into SYNTABL
		.BYTE  $C1
		.BYTE	 0
		.BYTE  $7F
		.BYTE  $D1
		.BYTE  $CC
		.BYTE  $C7
		.BYTE  $CF
		.BYTE  $CE
		.BYTE  $C5
		.BYTE  $9A
		.BYTE  $98
		.BYTE  $8D
		.BYTE  $96
		.BYTE  $95
		.BYTE  $93
		.BYTE  $BF
		.BYTE  $B2
		.BYTE  $32
		.BYTE  $12
		.BYTE	$F
		.BYTE  $BC
		.BYTE  $B0
		.BYTE  $AC
		.BYTE  $BE
		.BYTE  $35
		.BYTE	$C
		.BYTE  $61
		.BYTE  $30
		.BYTE  $10
		.BYTE	$B
		.BYTE  $DD
		.BYTE  $FB

loc_0_F1B7:				; solo
		LDY	#0
		JSR	sub_0_E7C7
		LDA	#SPC+$80
		JMP	COUT	

		.BYTE	 0
		.BYTE	 0
		.BYTE	 0
		.BYTE	 0
		.BYTE	 0
		.BYTE	 0
		.BYTE	 0
		.BYTE	 0


sub_0_F1C9:
		LDY	LOMEM
		LDA	LOMEM+1	
loc_0_F1CD:
		PHA	
		CPY	AUX
		SBC	AUX+1	
		BCS	loc_0_F1F0
		PLA	
		STY	SRCH		; SRCH = LOMEM	
		STA	SRCH+1	
		LDY	#-1
loc_0_F1DB:
		INY	
		LDA	(SRCH),Y
		BMI	loc_0_F1DB
		CMP	#$40
		BEQ	loc_0_F1DB
		INY	
		INY	
		LDA	(SRCH),Y
		PHA	
		DEY	
		LDA	(SRCH),Y
		TAY	
		PLA	
		BNE	loc_0_F1CD

loc_0_F1F0:
		PLA	
		LDY	#0

loc_0_F1F3:
		LDA	(SRCH),Y
		BMI	loc_0_F1FC
		LSR	A
		BEQ	loc_0_F202
		LDA	#'$'+$80
loc_0_F1FC:
		JSR	COUT	
		INY	
		BNE	loc_0_F1F3

loc_0_F202:
		LDA	#'='+$80
		JMP	COUT	

loc_0_F207:				; solo
		STA	(AUX),Y
		INX	
		LDA	NOUNSTKC-1,X
		BEQ	locret_0_F23E
		JMP	loc_0_F3D5

		.BYTE  $A0


loc_0_F212:				; solo
		BMI	loc_0_F21B
		LDA	PR	
		LDY	PR+1	
		JSR	sub_0_F17D
loc_0_F21B:
		JSR	sub_0_F1C9
		LDX	XSAVE	
		JMP	loc_0_F1B7


loc_0_F223:				; solo
		INX	
		INX	
		LDA	NOUNSTKC-1,X
		BEQ	locret_0_F248
		JMP	loc_0_F3E0


loc_0_F22C:				; solo
		BMI	loc_0_F235
		LDA	PR	
		LDY	PR+1	
		JSR	sub_0_F17D
loc_0_F235:
		JSR	sub_0_F1C9
		LDX	XSAVE	
		JMP	loc_0_F409

		inx
locret_0_F23E:
		RTS	


sub_0_F23F:				; solo
		JSR	GET16BIT
		INC	ACC
		BNE	locret_0_F248
		INC	ACC+1	
locret_0_F248:
		RTS	


; token $1C <
; IF X < 13 THEN END

sub_0_F249:				; V
		JSR	sub_0_F25B
		BNE	loc_0_F263


; token $19 >
; IF X > 13 THEN END

sub_0_F24E:				; VO
		JSR	sub_0_F253
		BNE	loc_0_F263


; token $1A <=
; IF X <= 13 THEN END

sub_0_F253:				; V 
		JSR	SUBTRACT
		JSR	NEGATE
		BVC	loc_0_F25E


; token $18 >=
; IF X >= 13 THEN END

sub_0_F25B:				; V 
		JSR	SUBTRACT
loc_0_F25E:
		JSR	SGN
		LSR	NOUNSTKL,X
loc_0_F263:
		JMP	NOT


; token $1D AND

VAND:					; VO
		JSR	sub_0_EFC9
		ORA	NOUNSTKL-1,X
		BPL	loc_0_F272


; token $1E OR

VOR:					; VO
		JSR	sub_0_EFC9
		AND	NOUNSTKL-1,X
loc_0_F272:
		STA	NOUNSTKL,X
		BPL	loc_0_F263
		JMP	sub_0_EFC9


; token $58 STEP

BAS_STEP:					; VO
		JSR	GET16BIT
		LDY	FORNDX	
		LDA	ACC
		STA	STK_60-1,Y
		LDA	ACC+1	
		JMP	loc_0_E966

loc_0_F288:				; solo
		STA	STK_50,Y
loc_0_F28B:
		DEY	
		BMI	locret_0_F2DF
		LDA	STK_40,Y
		CMP	NOUNSTKL,X
		BNE	loc_0_F28B
		LDA	STK_50,Y
		CMP	NOUNSTKH,X
		BNE	loc_0_F28B
		DEC	FORNDX	
loc_0_F29E:
		LDA	STK_40+1,Y
		STA	STK_40,Y
		LDA	STK_50+1,Y
		STA	STK_50,Y
		LDA	STK_C0+1,Y
		STA	STK_C0,Y
		LDA	STK_D0+1,Y
		STA	STK_D0,Y
		LDA	STK_60+1,Y
		STA	STK_60,Y
		LDA	STK_70+1,Y
		STA	STK_70,Y
		LDA	STK_80+1,Y
		STA	STK_80,Y
		LDA	STK_90+1,Y
		STA	STK_90,Y
		LDA	STK_A0+1,Y
		STA	STK_A0,Y
		LDA	STK_A0+1,Y
		STA	STK_A0,Y
		INY	
		CPY	FORNDX	
		BCC	loc_0_F29E
locret_0_F2DF:				; ...
		RTS	


; token $78 NODSP
; string car

NODSP_STR:
		INX	


; token $79 NODSP
; num var

NODSP_NUM:
		LDA	#0
loc_0_F2E3:
		PHA	
		LDA	NOUNSTKL,X
		SEC	
		SBC	#3
		STA	ACC
		LDA	NOUNSTKH,X
		SBC	#0
		STA	ACC+1	
		PLA	
		LDY	#0
		STA	(ACC),Y
		INX	
		RTS	

loc_0_F2F8:				; solo
		CMP	#$85
		BCS	loc_0_F2FF
		JMP	loc_0_E4C0

loc_0_F2FF:
		LDY	#2
		JMP	loc_0_E448


; token $7B DSP
; num var

DSP_NUM:				; VO
		INX	

; token $7C DSP
; string var

DSP_STR:				; VO
		LDA	#1
		BNE	loc_0_F2E3
		INX	

; token $06 CON

CON:
		LDA	NOUNSTKH
		STA	PR	
		LDA	NOUNSTKH+1	
		STA	PR+1	
		LDA	NOUNSTKL
		LDY	NOUNSTKL+1	
		JMP	GETNEXT
		LDA	#1
		BNE	loc_0_F2E3


; token $3C ASC(

ASC:					; VO
		LDA	NOUNSTKL,X
		CMP	NOUNSTKH,X
		BCC	loc_0_F326
		JMP	RANGERR

loc_0_F326:
		TAY	
		LDA	NOUNSTKL+1,X
		STA	ACC
		LDA	NOUNSTKH+1,X
		STA	ACC+1	
		LDA	(ACC),Y
		LDY	#0
		INX	
		INX	
		JSR	sub_0_E708
		JMP	loc_0_F404


; token $32 PDL

PDL:					; VO
		JSR	GETBYTE
		STX	XSAVE	
		AND	#3
		TAX	
		JSR	PREAD	
		LDX	XSAVE	
		TYA	
		LDY	#0
		JSR	sub_0_E708
		STY	NOUNSTKC,X
		RTS	

BAS_RDKEY:					; solo
		JSR	NXTCHAR	
sub_0_F354:
		TXA	
		PHA	
loc_0_F356:
		LDA	IN,X
		CMP	#ETX+$80	; ctl-C?
		BNE	loc_0_F360
		JMP	BASIC2	

loc_0_F360:				; ...
		DEX	
		BPL	loc_0_F356
		PLA	
		TAX	
		RTS	


sub_0_F366:				; solo
		JSR	sub_0_E280
		TYA	
		TAX	
		JSR	sub_0_F354
		TXA	
		TAY	
		RTS	


; token $20 ^

EXP:					; VO
		JSR	GET16BIT
		LDA	ACC+1	
		BPL	loc_0_F380
		TYA			; A = 0
		DEX	
		JSR	sub_0_E708
		STY	NOUNSTKC,X
locret_0_F37F:
		RTS	

loc_0_F380:
		STA	SRCH+1		; SRCH = ACC	
		LDA	ACC
		STA	SRCH	
		JSR	GET16BIT
		LDA	ACC
		STA	SRCH2	
		LDA	ACC+1	
		STA	SRCH2+1	
		LDA	#1
		JSR	sub_0_E708
		STY	NOUNSTKC,X
loc_0_F398:
		LDA	SRCH	
		BNE	loc_0_F3A0
		DEC	SRCH+1	
		BMI	locret_0_F37F

loc_0_F3A0:
		DEC	SRCH	
		LDA	SRCH2	
		LDY	#0
		JSR	sub_0_E708
		LDA	SRCH2+1	
		STA	NOUNSTKC,X
		JSR	MULT
		JMP	loc_0_F398


sub_0_F3B3:				; solo 
		JSR	GETBYTE
		CLC			; A = A-1
		ADC	#-1
locret_0_F3B9:
		RTS	


; token $4A ,
; end of PRINT statement
; PRINT A$,

sub_0_F3BA:				; VO
		JSR	sub_0_E7B1
		LSR	CRFLAG	
		RTS	


		STX	RUNFLAG	
		TXS	
		JSR	sub_0_F02E
		JMP	loc_0_E883


; token $7E PR#

PRSLOT:					; VO
		JSR	GETBYTE
		STX	XSAVE	
		JSR	OUTPORT	
		LDX	XSAVE	
		RTS	

		.BYTE  $FE

loc_0_F3D5:				; solo
		BIT	RUNFLAG	
		BPL	locret_0_F3B9
		STX	XSAVE	
		BIT	NOUNSTKC	
		JMP	loc_0_F212

loc_0_F3E0:				; solo
		BIT	RUNFLAG	
		BPL	locret_0_F3B9
		STX	XSAVE	
		BIT	NOUNSTKC	
		JMP	loc_0_F22C


sub_0_F3EB:				; solo
		LDY	#0
		JMP	GETVERB

loc_0_F3F0:
		TAY	
		JSR	CROUT	
loc_0_F3F4:				; solo
		TYA	
		SEC	
		SBC	WNDWDTH	
		BCS	loc_0_F3F0
		STY	CH	
		RTS	

		.BYTE	 0
		.BYTE	 0
		.BYTE	 0
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $FF
		.BYTE  $FF

loc_0_F404:				; solo
		STY	NOUNSTKC,X
		JMP	loc_0_E823

loc_0_F409:				; solo
		LDY	#0
		BEQ	loc_0_F411

loc_0_F40D:	
		JSR	COUT	
		INY	

loc_0_F411:		
		LDA	(AUX),Y
		BMI	loc_0_F40D
		LDA	#$FF
		STA	CRFLAG		; CRFLAG = $FF	
		RTS	


; token $7F IN#

INSLOT:
		JSR	GETBYTE
		STX	XSAVE	
		JSR	INPORT	
		LDX	XSAVE	
		RTS	

;
; END OF BASIC ROM
; --------------------------------------------------------------------

; ------------------------------------------------------------------
;                        _ _
;  _ __ ___   ___  _ __ (_) |_ ___  _ __
; | '_ ` _ \ / _ \| '_ \| | __/ _ \| '__|
; | | | | | | (_) | | | | | || (_) | |
; |_| |_| |_|\___/|_| |_|_|\__\___/|_|
;
; Apple ][ (non-Autostart) Monitor ROM (the F8 ROM)
; By Steve Wozniak and Allen Baum, 1977
;

	.org	$f800
MONITOR:

SCRN2:	
	BCC	RTMSKZ		; if even, use lo H
	LSR	A
	LSR	A
	LSR	A		; shift hi half byte down
	LSR	A
RTMSKZ:	
	AND	#$0F		; mask 4-bits
	RTS	


INDDS1:	
	LDX	PCL		; print PCL,H
	LDY	PCH	

	JSR	PRYX2
	JSR	PRBLNK		; followed by a blank
	LDA	(PCL,X)		; get op code
INSDS2:
	TAY	
	LSR	A		; even/odd test
	BCC	IEVEN
	ROR	A		; bit 1 test
	BCS	ERR		; XXXXXX11 invalid op
	CMP	#$a2
	BEQ	ERR		; opcode $89 invalid
	AND	#$87		; mask bits
IEVEN:	
	LSR	A		; lsb into C for L/R test
	TAX	
	LDA	FMT1,X		; get format index byte
	JSR	SCRN2		; R/L H-byte on C
	BNE	GETFMT
ERR:	
	LDY	#$80		; substitute $80 for invalid ops
	LDA	#0		; set print format index to 0
GETFMT:	
	TAX	
	LDA	FMT2,X		; index into print format table
	STA	FORMAT		; save for adr field formatting
	AND	#3		; mask for 2-bit length
	STA	LENGTH		;  (0=1 byte, 1 = 2 byte, 2 = 3 byte)
	TYA	
	AND	#$8f		; mask for 1XXX1010 test
	TAX			;  save it
	TYA			; opcode to A again
	LDY	#3
	CPX	#$8a
	BEQ	MNNDX3
MNNDX1:	
	LSR	A
	BCC	MNNDX3		; form index into mnemonic table
	LSR	A
MNNDX2:	
	LSR	A		; 1) 1XXX1010 => 00101XXX
	ORA	#$20		; 2) XXXYYY01 => 00111XXX
	DEY			; 3) XXXYYY10 => 00110XXX
	BNE	MNNDX2		; 4) XXXYY100 => 00100XXX
	INY			; 5) XXXXX000 => 000XXXXX
MNNDX3:	
	DEY	
	BNE	MNNDX1
	RTS	



INSTDSP:
	JSR	INDDS1		; gen fmt, len bytes
	PHA			; save mnemonic table index
PRNTOP:		
	LDA	(PCL),Y
	JSR	PRBYTE
	LDX	#1		; print 2 blanks
PRNTBL:		
	JSR	PRBL2
	CPY	LENGTH		; print inst (1-3 bytes)
	INY			;  in a 12 chr field
	BCC	PRNTOP
	LDX	#3		; char count for mnemonic print
	CPY	#4
	BCC	PRNTBL
	PLA			; recover mnemonic index
	TAY	
	LDA	MNEML,Y
	STA	LMNEM		; fetch 3-char mnemonic
	LDA	MNEMR,Y		;  (packed in 2 bytes)
	STA	RMNEM	
PRMN1:		
	LDA	#0
	LDY	#5
PRMN2:		
	ASL	RMNEM		; shift 5 bits of char into A
	ROL	LMNEM		;  (clears C)
	ROL	A
	DEY	
	BNE	PRMN2
	ADC	#$bf		; add "?" offset
	JSR	COUT		; output a char of mnemonic
	DEX	
	BNE	PRMN1
	JSR	PRBLNK		; output 3 blanks
	LDY	LENGTH	
	LDX	#6		; cnt for 6 format bits
PRADR1:		
	CPX	#3
	BEQ	PRADR5		; if X=3 then addr
PRADR2:			
	ASL	$2E
	BCC	PRADR3
	LDA	CHAR1-1,X
	JSR	COUT
	LDA	CHAR2-1,X
	BEQ	PRADR3
	JSR	COUT
PRADR3:			
	DEX	
	BNE	PRADR1
	RTS	
PRADR4:		
	DEY	
	BMI	PRADR2
	JSR	PRBYTE
PRADR5:		
	LDA	FORMAT	
	CMP	#$e8		; handle rel addr mode
	LDA	(PCL),Y		; special (print target, not offset)
	BCC	PRADR4
RELADR:
	JSR	PCADJ3
	TAX			; PCL,PCH+OFFSET+1 to A,Y
	INX	
	BNE	PRNTYX		; +1 to Y,X
	INY	
PRNTYX:		
	TYA	
PRNTAX:
	JSR	PRBYTE		; output target addr of branch and return
PRNTX:
	TXA
	JMP	PRBYTE

PRBLNK:		
	LDX	#3		; blank count
PRBL2:		
	LDA	#$a0		; load a space
PRBL3:
	JSR	COUT		; output a blank
	DEX	
	BNE	PRBL2		; loop until count = 0
	RTS	

PCADJ:		
	SEC			; 0=1-byte, 1=2-byte, 2=3-byte
PCADJ2:		
	LDA	LENGTH	
PCADJ3:		
	LDY	PCH	
	TAX			; test displacement sign (for rel branch)	
	BPL	PCADJ4
	DEY			; extend neg by decr PCH
PCADJ4:		
	ADC	PCL	
	BCC	RTS2		; PCL+LENGTH(or DISPL)+1 to A
	INY			;  C into Y (PCH)
RTS2:		
	RTS	

; FMT1 BYTES:		XXXXXXY0 instructions
; 		if Y=0	then left half byte
;		if Y=1	then right half byte
;			 (X=index)

FMT1:	.BYTE	 4 
	.BYTE  $20 
	.BYTE  $54 
	.BYTE  $30 
	.BYTE	$D 
	.BYTE  $80 
	.BYTE	 4 
	.BYTE  $90 
	.BYTE	 3 
	.BYTE  $22 
	.BYTE  $54 
	.BYTE  $33 
	.BYTE	$D 
	.BYTE  $80 
	.BYTE	 4 
	.BYTE  $90 
	.BYTE	 4 
	.BYTE  $20 
	.BYTE  $54 
	.BYTE  $33 
	.BYTE	$D 
	.BYTE  $80 
	.BYTE	 4 
	.BYTE  $90 
	.BYTE	 4 
	.BYTE  $20 
	.BYTE  $54 
	.BYTE  $3B 
	.BYTE	$D 
	.BYTE  $80 
	.BYTE	 4 
	.BYTE  $90 
	.BYTE	 0 
	.BYTE  $22 
	.BYTE  $44 
	.BYTE  $33 
	.BYTE	$D 
	.BYTE  $C8 
	.BYTE  $44 
	.BYTE	 0 
	.BYTE  $11 
	.BYTE  $22 
	.BYTE  $44 
	.BYTE  $33 
	.BYTE	$D 
	.BYTE  $C8 
	.BYTE  $44 
	.BYTE  $A9 
	.BYTE	 1 
	.BYTE  $22 
	.BYTE  $44 
	.BYTE  $33 
	.BYTE	$D 
	.BYTE  $80 
	.BYTE	 4 
	.BYTE  $90 
	.BYTE	 1 
	.BYTE  $22 
	.BYTE  $44 
	.BYTE  $33 
	.BYTE	$D 
	.BYTE  $80 
	.BYTE	 4 
	.BYTE  $90 
	.BYTE  $26 
	.BYTE  $31 
	.BYTE  $87 
	.BYTE  $9A 

FMT2:	.BYTE	 0 
	.BYTE  $21 
	.BYTE  $81 
	.BYTE  $82 
	.BYTE	 0 
	.BYTE	 0 
	.BYTE  $59 
	.BYTE  $4D 
	.BYTE  $91 
	.BYTE  $92 
	.BYTE  $86 
	.BYTE  $4A 
	.BYTE  $85 
	.BYTE  $9D 

CHAR1:	.BYTE  $AC  		; ,
	.BYTE  $A9  		; )
	.BYTE  $AC  		; ,
	.BYTE  $A3  		; #
	.BYTE  $A8  		; (
	.BYTE  $A4  		; $

CHAR2:	.BYTE  $D9  
	.BYTE	 0  
	.BYTE  $D8  
	.BYTE  $A4  
	.BYTE  $A4  
	.BYTE	 0  

MNEML:	.BYTE  $1C 
	.BYTE  $8A 
	.BYTE  $1C 
	.BYTE  $23 
	.BYTE  $5D 
	.BYTE  $8B 
	.BYTE  $1B 
	.BYTE  $A1 
	.BYTE  $9D 
	.BYTE  $8A 
	.BYTE  $1D 
	.BYTE  $23 
	.BYTE  $9D 
	.BYTE  $8B 
	.BYTE  $1D 
	.BYTE  $A1 
	.BYTE	 0 
	.BYTE  $29 
	.BYTE  $19 
	.BYTE  $AE 
	.BYTE  $69 
	.BYTE  $A8 
	.BYTE  $19 
	.BYTE  $23 
	.BYTE  $24 
	.BYTE  $53 
	.BYTE  $1B 
	.BYTE  $23 
	.BYTE  $24 
	.BYTE  $53 
	.BYTE  $19 
	.BYTE  $A1 
	.BYTE	 0 
	.BYTE  $1A 
	.BYTE  $5B 
	.BYTE  $5B 
	.BYTE  $A5 
	.BYTE  $69 
	.BYTE  $24 
	.BYTE  $24 
	.BYTE  $AE 
	.BYTE  $AE 
	.BYTE  $A8
	.BYTE  $AD 
	.BYTE  $29 
	.BYTE	 0 
	.BYTE  $7C 
	.BYTE	 0 
	.BYTE  $15 
	.BYTE  $9C 
	.BYTE  $6D 
	.BYTE  $9C 
	.BYTE  $A5 
	.BYTE  $69 
	.BYTE  $29 
	.BYTE  $53 
	.BYTE  $84 
	.BYTE  $13 
	.BYTE  $34 
	.BYTE  $11 
	.BYTE  $A5 
	.BYTE  $69 
	.BYTE  $23 
	.BYTE  $A0 

MNEMR:	.BYTE  $D8 
	.BYTE  $62 
	.BYTE  $5A 
	.BYTE  $48 
	.BYTE  $26 
	.BYTE  $62 
	.BYTE  $94 
	.BYTE  $88 
	.BYTE  $54 
	.BYTE  $44 
	.BYTE  $C8 
	.BYTE  $54 
	.BYTE  $68 
	.BYTE  $44 
	.BYTE  $E8 
	.BYTE  $94 
	.BYTE	 0 
	.BYTE  $B4 
	.BYTE	 8 
	.BYTE  $84 
	.BYTE  $74 
	.BYTE  $B4 
	.BYTE  $28 
	.BYTE  $6E 
	.BYTE  $74 
	.BYTE  $F4 
	.BYTE  $CC 
	.BYTE  $4A 
	.BYTE  $72 
	.BYTE  $F2 
	.BYTE  $A4 
	.BYTE  $8A 
	.BYTE	 0 
	.BYTE  $AA 
	.BYTE  $A2 
	.BYTE  $A2 
	.BYTE  $74 
	.BYTE  $74 
	.BYTE  $74 
	.BYTE  $72 
	.BYTE  $44 
	.BYTE  $68 
	.BYTE  $B2 
	.BYTE  $32 
	.BYTE  $B2 
	.BYTE	 0 
	.BYTE  $22 
	.BYTE	 0 
	.BYTE  $1A 
	.BYTE  $1A 
	.BYTE  $26 
	.BYTE  $26 
	.BYTE  $72 
	.BYTE  $72 
	.BYTE  $88 
	.BYTE  $C8 
	.BYTE  $C4 
	.BYTE  $CA 
	.BYTE  $26 
	.BYTE  $48 
	.BYTE  $44 
	.BYTE  $44 
	.BYTE  $A2 
	.BYTE  $C8 
	.BYTE  $FF 
	.BYTE  $FF 
	.BYTE  $FF 

STEP:		
	JSR	INSTDSP		; diassemble one inst at (PCL,H)
	PLA		
	STA	RTNL		; adjust to user stack, save rtn addr
	PLA	
	STA	RTNH	
	LDX	#8
XQINIT:		
	LDA	INITBL-1,X	; init XEQ area
	STA	XQT,X
	DEX	
	BNE	XQINIT
	LDA	(PCL,X)		; user opcode byte
	BEQ	XBRK		; special if BREAK
	LDY	LENGTH		; len from disassembly
	CMP	#$20
	BEQ	XJSR		; handle JSR, RTS, JMP, JMP (), RTI special
	CMP	#$60
	BEQ	XRTS
	CMP	#$4C
	BEQ	XJMP
	CMP	#$6C
	BEQ	XJMPAT
	CMP	#$40
	BEQ	XRTI
	AND	#$1F
	EOR	#$14
	CMP	#4		; copy user inst to xeq area with trailing nops
	BEQ	XQ2
XQ1:			
	LDA	(PCL),Y		; change rel branch disp to 4 for 
XQ2:		
	STA	XQT,Y
;	STA	XQTNZ,Y
	DEY			;  jmp to BRANCH or NBRANCH from XEQ
	BPL	XQ1
	JSR	RESTORE		; restore user reg contents
	JMP	XQT		; XEQ user op from RAM (return to NBRANCH)
;	JMP	XQTNZ	

IRQ:
	STA	MON_ACC	
	PLA	
	PHA	
	ASL	A
	ASL	A
	ASL	A
	BMI	BREAK		; test for BREAK
	JMP	(IRQLOC)	; user routine vector in RAM

BREAK:		
	PLP	
	JSR	SAV1		; save regs on break, including PC
	PLA	
	STA	PCL	
	PLA	
	STA	PCH	
XBRK:		
	JSR	INDDS1		; print user PC
	JSR	RGDSP1		;  and regs
	JMP	MON		; goto monitor

XRTI:		
	CLC	
	PLA			; simulate RTI by expecting status from
	STA	STATUS		;  stack, then RTS

XRTS:				; RTS simulation
	PLA			
	STA	PCL		;  extract PC from stack	
	PLA			;  and update PC by 1 (LEN=0)

PCINC2:			
	STA	PCH	
PCINC3:			
	LDA	LENGTH		; update PC by LEN	
	JSR	PCADJ3
	STY	PCH	
	CLC	
	BCC	NEWPCL
XJSR:		
	CLC	
	JSR	PCADJ2		; update PC and push onto stack for
	TAX			;  JSR simulate
	TYA	
	PHA	
	TXA	
	PHA	
	LDY	#2
XJMP:		
	CLC	
XJMPAT:		
	LDA	(PCL),Y
	TAX			; load PC for JMP, (JMP) simulate
	DEY			
	LDA	(PCL),Y
	STX	PCH	
NEWPCL:		
	STA	PCL	
	BCS	XJMP
RTNJMP:
	LDA	RTNH	
	PHA	
	LDA	RTNL	
	PHA	

REGDSP:			
	JSR	CROUT		; display user reg contents with labels
RGDSP1:		
	LDA	#MON_ACC
	STA	A3L	
	LDA	#MON_ACC/256
	STA	A3H	
	LDX	#$fb
RDSP1:		
	LDA	#$a0
	JSR	COUT
	LDA	RTBL-$fb,X
	JSR	COUT
	LDA	#$bd
	JSR	COUT
	LDA	MON_ACC+5,X
	JSR	PRBYTE
	INX	
	BMI	RDSP1
	RTS	


BRANCH:		
	CLC			; branch taken, add LEN+2 to PC	
	LDY	#1
	LDA	(PCL),Y
	JSR	PCADJ3
	STA	PCL	
	TYA	
	SEC	
	BCS	PCINC2
NBRNCH:		
	JSR	SAVE		; normal return after XEQ user op
	SEC	
	BCS	PCINC3		; go update PC
INITBL:
	NOP	
	NOP			; dummy fill for XEQ area
	JMP	NBRNCH
	JMP	BRANCH

RTBL:
	.byte	$c1
	.byte	$d8
	.byte	$d9
	.byte	$d0
	.byte	$d3


MULPM:
	JSR	MD1		; ABS val of AC AUX
MUL:
	LDY	#$10		; index for 16 bits
MUL2:		
	LDA	ACL		; ACX * AUX + XTND to AC, XTND
	LSR	A		
	BCC	MUL4		; if no C, no partial product
	CLC	
	LDX	#$fe
MUL3:		
	LDA	XTNDL+2,X	; add multiplicand (AUX) to partial product (XTND)
	ADC	AUXL+2,X
	STA	XTNDL+2,X
	INX	
	BNE	MUL3
MUL4:		
	LDX	#3
MUL5:		
	ROR	ACL,X		; in listing, was DFB $76, DFB $50
	DEX	
	BPL	MUL5
	DEY	
	BNE	MUL2
	RTS	


DIVPM:
	JSR	MD1		; ABS val of AC, AUX
DIV:	
	LDY	#$10		; index for 16 bits
DIV2:		
	ASL	ACL	
	ROL	ACH	
	ROL	XTNDL		; XTND/AUX to AC
	ROL	XTNDH	
	SEC	
	LDA	XTNDL	
	SBC	AUXL		; MOD to XTND
	TAX	
	LDA	XTNDH	
	SBC	AUXH	
	BCC	DIV3
	STX	XTNDL	
	STA	XTNDH	
	INC	ACL	
DIV3:		
	DEY	
	BNE	DIV2
	RTS	


MD1:		
	LDY	#0		; ABS val of AC, AUX with result sign in lsb of SIGN
	STY	SIGN	
	LDX	#AUXL
	JSR	MD2
	LDX	#ACL
MD2:		
	LDA	LOC1,X		; X specifies AC or AUX
	BPL	MDRTS
	SEC	
MD3:
	TYA	
	SBC	LOC0,X		; complement specified reg if neg
	STA	LOC0,X
	TYA	
	SBC	LOC1,X
	STA	LOC1,X
	INC	SIGN	
MDRTS:		
	RTS	


ESC1:
	RTS


NXTA4:			
	INC	A4L		; inc 2-byte A4 and A1
	BNE	NXTA1
	INC	A4H	
NXTA1:			
	LDA	A1L		; inc 2-byte A1
	CMP	A2L	
	LDA	A1H		;  and compare to A2
	SBC	A2H	
	INC	A1L		;  C set if >=
	BNE	RTS4B
	INC	A1H	
RTS4B:				
	RTS	


RDKEY:			
	JMP	(KSWL)		; go to user key-in


KEYIN:
	INC	RNDL	
	BNE	KEYIN2		; inc rnd number
	INC	RNDH	
KEYIN2:			
	lda	#$08		; 1 -> rx full
wait_acia_in:
	bit	ACIABASE+STAT	; Z = 1 -> rx EMPTY
	beq	wait_acia_in
	lda	ACIABASE+DATA
	rts

ESC:				
	JSR	RDKEY		; get keycode
	JSR	ESC1		;  handle esc function


RDCHAR:				
	JSR	RDKEY		; read key
	CMP	#$9b		; esc?
	BEQ	ESC		;  yes, don't return
	RTS	

BELL:
	lda	#$07
	jsr	COUT
	RTS

CLREOL:
	RTS


WAIT:
	sec
WAIT2:
	pha
WAIT3:
	sbc	#$01
	bne	WAIT3
	pla
	sbc	#$01
	bne	WAIT2
	rts
	

; ---------------------------------------------------------------
; Get a line, deal with BS and Ctl-X
;

NOTCR:				
	LDA	IN,X		; echo most recent char in buffer 
	JSR	COUT
	LDA	IN,X
	CMP	#$88		; check for edit keys
	BEQ	BCKSPC		; BS, ctrl-X
	CMP	#$98
	BEQ	CANCEL
	CPX	#$f8		; margin?
	BCC	NOTCR1
	JSR	BELL		; yes, sound bell
NOTCR1:			
	INX			; advance input index
	BNE	NXTCHAR
CANCEL:			
	LDA	#$dc		; backslash after cancelled line
	JSR	COUT


GETLNZ:			
	JSR	CROUT		; output CR
GETLN:
	LDA	PROMPT	
	JSR	COUT		; output prompt char
	LDX	#1		; init input index
BCKSPC:			
	TXA			;  will backspace to 0
	BEQ	GETLNZ		; try to backspace beyond left edge?
	DEX	
NXTCHAR:		
	JSR	RDCHAR
;	cmp	#$61		; >'a'?
;	bmi	CAPTST
;	cmp	#$7b		; <='z'?
;	bpl	CAPTST
;	and	#$df
CAPTST:	
	cmp	#$0a		; LF?
	beq	NXTCHAR		; discard
	ora	#$80	
;	CMP	#$e0
;	BCC	ADDINP		; convert to caps
;	AND	#$df
ADDINP:			
	STA	IN,X		; add to input buf
	CMP	#$8d		; CR?
	BNE	NOTCR		; echo char to user

	JSR	CLREOL		; clr to EOL if CR
				;  (just clears junk off rest of line)

CROUT:				
	LDA	#$8d		; CR + $80
	JSR	COUT
	LDA	#$8a		; LF + $80
	bne	COUT		; COUT will RTS, which will return to caller of GETLNZ


PRA1:			
	LDY	A1H		; print CR,A1 in hex
	LDX	A1L	
PRYX2:
	JSR	CROUT
	JSR	PRNTYX
	LDY	#0
	LDA	#'-'+$80	; print '-'
	JMP	COUT


XAM8:				
	LDA	A1L	
	ORA	#7		; set to finish at MOD 8=7
	STA	A2L	
	LDA	A1H	
	STA	A2H	
MOD8CHK:			
	LDA	A1L	
	AND	#7
	BNE	DATAOUT
XAM:				
	JSR	PRA1
DATAOUT:			
	LDA	#$a0
	JSR	COUT		; output blank
	LDA	(A1L),Y
	JSR	PRBYTE		; output byte in hex
	JSR	NXTA1
	BCC	MOD8CHK		; check if time to print addr
RTS4C:
	RTS	


XAMPM:				
	LSR	A		; determine if monitor mode is XAM, ADD, or SUB
	BCC	XAM
	LSR	A
	LSR	A
	LDA	A2L	
	BCC	ADD
	EOR	#$ff		; SUB: form 2's complement
ADD:				
	ADC	A1L	
	PHA	
	LDA	#$bd
	JSR	COUT		; print '=', then result
	PLA	

PRBYTE:				
	PHA			; print byte as 2 hex digits, destroys A-reg
	LSR	A
	LSR	A
	LSR	A
	LSR	A
	JSR	PRHEXZ		; first do the hi nybble
	PLA	
PRHEX:
	AND	#$0F		; print hex dig in A-reg LSBs
PRHEXZ:		
	ORA	#$b0
	CMP	#$ba
	BCC	COUT
	ADC	#6


COUT:				
	JMP	(CSWL)		; vector to user output routine

COUT1:
	pha			; char to send in A

	lda	#$10		; 1 -> tx empty
wait_acia_out:
	bit	ACIABASE+STAT	; Z = 1 -> tx FULL
	beq	wait_acia_out
	
	pla
	pha			; back in A, but leave on stack
	and	#$7f		; turn it into regular ASCII
	sta	ACIABASE+DATA
	pla			; return with it still in A
	rts

COUT2:
	pha			; char to send in A

	lda	#$10		; 1 -> tx empty
wait_acia_out_2:
	bit	ACIABASE+STAT	; Z = 1 -> tx FULL
	beq	wait_acia_out_2
	
	pla
	sta	ACIABASE+DATA
	rts



BL1:				
	DEC	YSAV	
	BEQ	XAM8
BLANK:
	DEX			; blank to mon
	BNE	SETMDZ		; after blank
	CMP	#$ba		; data store mode?
	BNE	XAMPM		;  no, XAM, ADD, or SUB
STOR:
	STA	MODE		; keep in store mode
	LDA	A2L	
	STA	(A3L),Y		; store as low byte as (A3)
	INC	A3L	
	BNE	RTS5		; inc A3, return
	INC	A3H	
RTS5:				
	RTS	


SETMODE:
	LDY	YSAV		; save converted ':', '+', '-', '.' as mode
	LDA	IN-1,Y		; need to back up 1, since iny already happened
SETMDZ:				
	STA	MODE	
	RTS	


LT:
	LDX	#1
LT2:				
	LDA	A2L,X		; copy A2 (2 bytes) to A4 and A5
	STA	A4L,X
	STA	A5L,X
	DEX	
	BPL	LT2
	RTS	


MOVE:				
	LDA	(A1L),Y		; move (A1 to A2) to (A4)
	STA	(A4L),Y
	JSR	NXTA4
	BCC	MOVE
	RTS	


VFY:				
	LDA	(A1L),Y		; verify (A1 to A2) with (A4)
	CMP	(A4L),Y
	BEQ	VFYOK
	JSR	PRA1
	LDA	(A1L),Y
	JSR	PRBYTE
	LDA	#$a0
	JSR	COUT
	LDA	#$a8
	JSR	COUT
	LDA	(A4L),Y
	JSR	PRBYTE
	LDA	#$a9
	JSR	COUT
VFYOK:				
	JSR	NXTA4
	BCC	VFY
	RTS	


MON_LIST:
	JSR	A1PC		; move A1 (2 bytes) to PC if specified
	LDA	#$14		;  and disassemble 20 instructions
MON_LIST2:				
	PHA	
	JSR	INSTDSP
	JSR	PCADJ		; adjust PC each instruction
	STA	PCL	
	STY	PCH	
	PLA	
	SEC	
	SBC	#1		; next of 20 instructions
	BNE	MON_LIST2
	RTS	


A1PC:				
	TXA			; if user specified addr, copy from A1 to PC
	BEQ	A1PCRTS
A1PCLP:				
	LDA	A1L,X
	STA	PCL,X
	DEX	
	BPL	A1PCLP
A1PCRTS:			
	RTS	




INPRT:
OUTPRT:
	RTS


SETKBD:			
	ldx	#KSWL
	lda	#(KEYIN&$ff)
	sta	LOC0,X
	lda	#KEYIN/256
	sta	LOC1,X
	rts

SETVID:				
	ldx	#CSWL
	lda	#(COUT1&$ff)
	sta	LOC0,X
	lda	#COUT1/256
	sta	LOC1,X
	rts	

	NOP	
	NOP	


XBASIC:
	JMP	BASIC		; to BASIC with scratch


BASCONT:
	JMP	BASIC2		; continue BASIC


GO:
	JSR	A1PC		; addr to PC if specified
	JSR	RESTORE		; restore meta regs
	JMP	(PCL)		; goto user subroutine


REGZ:
	JMP	REGDSP		; to reg display


TRACE:
	DEC	YSAV	

STEPZ:
	JSR	A1PC		; addr to PC if specified
	JMP	STEP		; take one step

USR:
	JMP	USRADR		; to user subroutine at USRADR


CRMON:
	JSR	BL1		; handle CR as blank
	PLA			;  then pop stack
	PLA			;  and return to monitor
	BNE	MONZ

	rts


WRITE:
	jsr	XmodemSetup
	bcs	Bail
	jsr	XmodemSend
Bail:
	RTS	

READ:
	jsr	XmodemSetup
	bcs	Bail
	jsr	XmodemRcv
	RTS


RESTORE:			
	LDA	STATUS		; restore 6502 reg contents	
	PHA	
	LDA	MON_ACC	
RESTR1:
	LDX	XREG	
	LDY	YREG	
	PLP	
	RTS	


SAVE:				
	STA	MON_ACC	
SAV1:				
	STX	XREG	
	STY	YREG	
	PHP	
	PLA	
	STA	STATUS	
	TSX	
	STX	SPNT	
	CLD	
	RTS	


SETNORM:
SETINV:
	RTS


RESET:
	LDA	#0		; clr status for debug software
	STA	STATUS	
	JSR	SETVID		;  and I/O devices
	JSR	SETKBD

	jmp	XBASIC	

MON:				
	CLD			; must set hex mode!
	JSR	BELL

MONZ:				
	LDA	#'*'+$80	; '*' prompt for mon
	STA	PROMPT	
	JSR	GETLNZ		; read a line
	JSR	ZMODE		; clear mon mode, scan idx (Y=0, MODE=0)
NXTITM:				
	JSR	GETNUM		; get item
	STY	YSAV		; remember where in the IN buffer we are 
				; A = massaged cmd byte
				; if X = 0, no hex digits before cmd

	; A = command char, try to find it in command table 

	LDY	#NUM_CMDS
CHRSRCH:		
	DEY	
	BMI	MON		; no cmd found, go back to mon
	CMP	CHRTBL,Y	; find command char in table
	BNE	CHRSRCH

	JSR	TOSUB		; found, call corresponding subroutine
	LDY	YSAV	
	JMP	NXTITM


; ---------------------------------------------------------------
; eat digits from left edge, looking for non-hex-digit as command
;

DIG:				
	LDX	#3
	ASL	A
	ASL	A		; got hex digit, shift into A2
	ASL	A
	ASL	A
NXTBIT:				
	ASL	A
	ROL	A2L	
	ROL	A2H	
	DEX			; leave X=$ff if digit
	BPL	NXTBIT
NXTBAS:			
	LDA	MODE	
	BNE	NXTBS2		; if mode is zero, then copy A2 to A1 and A3
	LDA	A2H,X
	STA	A1H,X
	STA	A3H,X
NXTBS2:				
	INX	
	BEQ	NXTBAS
	BNE	NXTCHR		; process until we get a cmd

; get digits into A2, return with "massaged" cmd in A

GETNUM:				
	LDX	#0		; clear A2
	STX	A2L	
	STX	A2H	
NXTCHR:				
	LDA	IN,Y		; get char
	INY			; next char in IN buffer	
	EOR	#$b0		; 0-9 = $b0-$b9, this makes $00-$09
	CMP	#$0A
	BCC	DIG		; if hex digit, then
	ADC	#$88
	CMP	#$fa
	BCS	DIG
;	sta	VIABASE
	RTS			; return w/A = cmd in CHRTBL 
				; A2 will hold any hex val before cmd
				; Y is index into IN buffer
				; X will be 0 if there were no digits before cmd

TOSUB:				
	LDA	#GO/256
	PHA			; push hi-order	subr adr on stk
	LDA	SUBTBL,Y
	PHA			; push lo-order	subr adr on stk
	LDA	MODE	

ZMODE:				; clr mode, old mode to A 
	LDY	#0
	STY	MODE	
	RTS			; go to subroutine via RTS	


HLINE:
VLINE:
WRITE0:
PREAD:
OUTPORT:
INPORT:
SETTXT:
SETGR:
PLOT:
SETCOL:
VTAB:
GBASCALC:
	rts

; dead test code
	pha
	txa
	pha
	tya
	pha

	lda	#':'
	jsr	COUT
	
	ldx	#4
	ldy	#0
dump:
	lda	IN,Y
	jsr	COUT
	iny
	dex
	bne	dump

	lda	#$8a
	jsr	COUT
	lda	#$8d
	jsr	COUT

	pla
	tay
	pla
	tax
	pla

; ---------------------------------------------------------------
; cmds in CHRTBL are pre-massaged, to look like what they look like when
; NXTCHR *doesn't* go to DIG
;

NUM_CMDS .equ	$17		; 17 monitor commands

CHRTBL:	.BYTE  $BC 		; F("CTRL-C")			re-enter BASIC
	.BYTE  $B2 		; F("CTRL-Y")			user cmd
	.BYTE  $BE 		; F("CTRL-E")			examine regs
	.BYTE  $ED 		; F("T")			trace
	.BYTE  $EF 		; F("V")			verify
	.BYTE  $C4 		; F("CTRL-K")			set input
	.BYTE  $EC 		; F("S")			step
	.BYTE  $A9 		; F("CTRL-P")			set output
	.BYTE  $BB 		; F("CTRL-B")			enter BASIC
	.BYTE  $A6 		; F("-")
	.BYTE  $A4 		; F("+")
	.BYTE  $06 		; F("M")  (F=EX-OR $B0+$89)  	move
	.BYTE  $95 		; F("<")
	.BYTE  $07 		; F("N") 			normal text
	.BYTE  $02 		; F("I") 			inverse text
	.BYTE  $05 		; F("L")			list (disassemble)
	.BYTE  $F0 		; F("W")			write to tape
	.BYTE  $00 		; F("G")			go
	.BYTE  $EB 		; F("R")			read from tape
	.BYTE  $93 		; F(":")			store
	.BYTE  $A7 		; F(".")			mem dump
	.BYTE  $C6 		; F("CR")
	.BYTE  $99 		; F(BLANK)


SUBTBL:	.byte	BASCONT-1
	.byte	USR-1
	.byte	REGZ-1
	.byte	TRACE-1
	.byte	VFY-1
	.byte	INPRT-1
	.byte	STEPZ-1
	.byte	OUTPRT-1
	.byte	XBASIC-1
	.byte	SETMODE-1
	.byte	SETMODE-1
	.byte	MOVE-1
	.byte	LT-1
	.byte	SETNORM-1
	.byte	SETINV-1
	.byte	MON_LIST-1
	.byte	WRITE-1
	.byte	GO-1
	.byte	READ-1
	.byte	SETMODE-1
	.byte	SETMODE-1
	.byte	CRMON-1
	.byte	BLANK-1

; ------------------------------------------------------------------
;                 _
; __   _____  ___| |_ ___  _ __ ___
; \ \ / / _ \/ __| __/ _ \| '__/ __|
;  \ V /  __/ (__| || (_) | |  \__ \
;   \_/ \___|\___|\__\___/|_|  |___/
;
;

	.ORG	$fffa

	.WORD	0
	;.WORD	NMI_HANDLER		; 6522 timer
	.WORD	RESET_HANDLER
	.WORD	IRQ			; 6551 ACIA

	.END



