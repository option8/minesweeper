	DSK MS

**************************************************
*	minesweeper
*
*	test board
*
*	0 0 0 0 0 0 0 0 
*	0 0 0 0 0 0 0 0 
*	0 0 0 0 0 0 0 0 
*	0 0 0 1 0 0 0 0 = 0x10
*	0 0 0 0 1 0 0 0 = 0x08
*	0 0 0 0 0 0 0 0 
*	0 0 0 0 0 0 0 0 
*	0 0 0 0 0 0 0 0 
*
*	solve result:
*
*	0 0 0 0 0 0 0 0 
*	0 0 0 0 0 0 0 0 
*	0 0 1 1 1 0 0 0 
*	0 0 1 X 2 1 0 0 
*	0 0 1 2 X 1 0 0 
*	0 0 0 1 1 1 0 0 
*	0 0 0 0 0 0 0 0 
*	0 0 0 0 0 0 0 0 
*
**************************************************

**************************************************
*
*	TO DO: 	win message when progress = 64 and all bombs marked
*			lose message when clearing a cell with bomb
*			sounds?
*
**************************************************



**************************************************
* Variables
**************************************************

SOLVEORIGIN		EQU		$9100		; 'solved' board to reveal
PROGRESSORIGIN	EQU		$9200		; revealed squares
BOMBLOC			EQU 	$FC	
ROWBYTE			EQU		$FD
ROW				EQU		$FA			; row/col in board
COLUMN			EQU		$FB
PLOTROW			EQU		$FE			; row/col in text page
PLOTCOLUMN		EQU		$FF
]ROWS			=		#$8
]COLUMNS		=		#$8
CHAR			EQU		$FC			; char to plot
STRLO			EQU		$EB			; string lo/hi for printing
STRHI			EQU		$EC
SCORE			EQU		$ED			; bombs found
PROGRESS 		EQU		$EE			; cells cleared
BOMBS			EQU		$EF			; total bombs

**************************************************
* Apple Standard Memory Locations
**************************************************
CLRLORES     EQU   $F832
LORES        EQU   $C050
TXTSET       EQU   $C051
MIXCLR       EQU   $C052
MIXSET       EQU   $C053
TXTPAGE1     EQU   $C054
TXTPAGE2     EQU   $C055
KEY          EQU   $C000
C80STOREOFF  EQU   $C000
C80STOREON   EQU   $C001
STROBE       EQU   $C010
SPEAKER      EQU   $C030
VBL          EQU   $C02E
RDVBLBAR     EQU   $C019       ;not VBL (VBL signal low
WAIT		 EQU   $FCA8 
RAMWRTAUX    EQU   $C005
RAMWRTMAIN   EQU   $C004
SETAN3       EQU   $C05E       ;Set annunciator-3 output to 0
SET80VID     EQU   $C00D       ;enable 80-column display mode (WR-only)
HOME 		 EQU   $FC58			; clear the text screen

CH           EQU   $24			; cursor Horiz
CV           EQU   $25			; cursor Vert
VTAB         EQU   $FC22       ; Sets the cursor vertical position (from CV)
COUT         EQU   $FDED       ; Calls the output routine whose address is stored in CSW,
                               ;  normally COUTI
STROUT		 EQU   $DB3A 		;Y=String ptr high, A=String ptr low


**************************************************
* START
**************************************************

				ORG $1000			; PROGRAM DATA STARTS AT $1000
					
**************************************************
*	Draws the blank board borders, corners, borders
**************************************************
DRAWBOARD				JSR HOME
						
CORNERS					LDA #$01
						STA PLOTROW
						STA PLOTCOLUMN
						LDA #$2E		; .
						STA CHAR
						JSR PLOTCHAR
						
						LDA #$11
						STA PLOTCOLUMN
						JSR PLOTCHAR
						
						LDA #$27
						STA CHAR		; '
						LDA #$11
						STA PLOTROW
						STA PLOTCOLUMN
						JSR PLOTCHAR
						
						LDA #$01
						STA PLOTCOLUMN
						JSR PLOTCHAR
;/CORNERS

HLINES					LDA #$02	; start at column 2
						STA PLOTCOLUMN
						LDA #$2D	; -
						STA CHAR
						
HLINESLOOP				LDA #$01	; row 1
						STA PLOTROW
						JSR PLOTCHAR

HROWSLOOP				INC PLOTROW
						INC PLOTROW		; row 3, 5, ...
						JSR PLOTCHAR
						LDA PLOTROW
						CMP #$10	; goes to 17
						BMI HROWSLOOP
;/HROWSLOOP						
						INC PLOTCOLUMN
						LDA PLOTCOLUMN
						CMP #$11	; goes to 16
						BMI HLINESLOOP
;/HLINES						

VLINES					LDA #$02	; start at column 2
						STA PLOTROW
						LDA #$3A	; :
						STA CHAR
						
VLINESLOOP				LDA #$01	; row 1
						STA PLOTCOLUMN
						JSR PLOTCHAR

VCOLUMNSLOOP			INC PLOTCOLUMN	; row 2, 4, ...
						INC PLOTCOLUMN	; row 3, 5, ...
						JSR PLOTCHAR
						LDA PLOTCOLUMN
						CMP #$11	; goes to 16
						BMI VCOLUMNSLOOP
;/VCOLUMNSLOOP

						INC PLOTROW
						LDA PLOTROW
						CMP #$11	; goes to 16
						BMI VLINESLOOP
;/VLINES						

* 	+ ROW*2 + 1, COLUMN*2 + 1

PLUSES

						LDA #$03	; starts at 3,3
						STA PLOTROW
						LDA #$2B	; +
						STA CHAR
						
PLUSLOOP				
						LDA #$03	; starts at 3,3
						STA PLOTCOLUMN
PLUSCOLS				
						JSR PLOTCHAR
						INC PLOTCOLUMN
						INC PLOTCOLUMN
						LDA PLOTCOLUMN
						CMP #$10
						BMI PLUSCOLS
;/PLUSCOLS
						INC PLOTROW
						INC PLOTROW
						LDA PLOTROW
						CMP #$10
						BMI PLUSLOOP
;/PLUSLOOP

**************************************************
*	sets up solving matrix, resets scoreboard
*	each cell = 1 byte
**************************************************
SETUP			LDX #$0
				STX BOMBS
				STX PROGRESS
				STX SCORE
SETUPLOOP		LDA #$0
				STA SOLVEORIGIN,X		; set byte at origin + x = 0
				LDA #$FF
				STA PROGRESSORIGIN,X	; progress reset - FF = unsolved
				INX
				CPX ]ROWS*]COLUMNS		; $#40 = hex 64 = 8x8
				BNE SETUPLOOP
;/setuploop
				
SETUPBOARD		
				LDX #$8					; X = 8
ROWLOOP3								; (ROW 7 to 0)
				DEX
				STX ROW
				LDA #$0
				STA BOARDORIGIN,X 		; set byte at BOARDORIGIN,x 0

				LDY #$8					;	start columnloop (COLUMN 0 to 7)
COLUMNLOOP3		CLC						; clear CARRY to 0 
				DEY
				STY COLUMN				; store column for later retrieval
				LDA #$05				; SLIGHT DELAY
				JSR WAIT
				LDA SPEAKER				; get byte, pseudorandom source?
				ROL						; random bit into Carry
				ROL						; random bit into Carry
				ROL BOARDORIGIN,X		; random bit into row byte
				
				TYA						; last COLUMN?
				BNE COLUMNLOOP3			; loop
;	/columnloop3
			
				TXA						; current row into Accumulator
										; last ROW?
				BNE ROWLOOP3			; loop 
	
;/rowloop3		
;/SETUPBOARD
									 
									

**************************************************
*	solves the board
**************************************************
SOLVEBOARD						
				LDX #$8					; X = 8
ROWLOOP 								; (ROW 8 to 0)
				DEX
				STX ROW
				LDA BOARDORIGIN,X 		; puts byte at ROW into accumulator
				STA ROWBYTE				; byte is in ROWBYTE

;	start columnloop (COLUMN 0 to 7)
				LDY #$8
COLUMNLOOP		CLC						; clear CARRY to 0 
				DEY
				STY COLUMN				; store column for later retrieval
				ROL ROWBYTE				; rotate accumulator bit into CARRY
				BCC NOBOMB				; if CARRY = 0
				JSR FOUNDBOMB			; if CARRY > 0

NOBOMB									; do nothing.

				TYA						; last COLUMN?
				BNE COLUMNLOOP			; loop
;	/columnloop
			
				TXA						; current row into Accumulator
										; last ROW?
				BNE ROWLOOP				; loop 
	
;/rowloop		


**************************************************
*	draws the blank squares to be solved
*
**************************************************
; FOR EACH ROW/COLUMN

				LDA #$8					; X = 8
				STA ROW
ROWLOOP2 								; (ROW 8 to 0)
				DEC ROW

;	start columnloop (COLUMN 0 to 7)
				LDA #$8
				STA COLUMN
COLUMNLOOP2		DEC COLUMN				

				JSR DRAWSQUARE

				LDA COLUMN				; last COLUMN?
				BNE COLUMNLOOP2			; loop
;	/columnloop2
			
				LDA ROW					; last ROW?
				BNE ROWLOOP2			; loop 
	
;/rowloop2		


**************************************************
*	writes instructions, scoreboard
**************************************************

				JSR INSTRUCTIONS
				JSR PRINTSCORE
				JSR PRINTBOMBS
				JSR PRINTPROGRESS
				

**************************************************
*	MAIN LOOP
*	waits for keyboard input, moves cursor, etc
**************************************************

MAIN			LDA #$0					; highlight 0,0 to start with
				STA ROW
				STA COLUMN				; set row/column
				JSR HILITESQUARE		;

MAINLOOP		LDA KEY					; check for keydown
				CMP #$A0				; space bar
				BEQ GOTSPACE
				CMP #$C9				; I
				BEQ GOTUP
				CMP #$CB				; K
				BEQ GOTDOWN
				CMP #$CA				; J
				BEQ GOTLEFT
				CMP #$CC				; L
				BEQ GOTRIGHT
				CMP #$CD				; M
				BEQ GOTMINE
				CMP #$D2				; R
				BEQ GOTRESET
				CMP #$9B				; ESC
				BEQ END					; exit on ESC?
				
				BNE MAINLOOP			; loop until a key
	

GOTSPACE		JSR SPACE
				JMP MAINLOOP			; back to waiting for a key
GOTUP			JSR UP
				JMP MAINLOOP			; back to waiting for a key
GOTDOWN			JSR DOWN
				JMP MAINLOOP			; back to waiting for a key
GOTLEFT			JSR LEFT	
				JMP MAINLOOP			; back to waiting for a key
GOTRIGHT		JSR RIGHT
				JMP MAINLOOP			; back to waiting for a key
GOTMINE			JSR MARKMINE
				JMP MAINLOOP
GOTRESET		STA STROBE
				JSR RESET
				JMP MAINLOOP
END				JSR HOME
				RTS						; END



MARKMINE		STA STROBE				; solve current square and move to next space

										; if current square is already solved, ignore
				LDA ROW					; get ROW and COLUMN
				CLC
				ROL						
				ROL						; offset = ROW * 8 + COLUMN
				ROL
				CLC
				ADC COLUMN
				TAX			
				LDA PROGRESSORIGIN,X	; is progress already marked?
				CLC
				CMP #$FF
				BEQ	GOMARKMINE			; STILL UNMARKED
				JSR BONK				; ignore the mark, keep as solved.
				RTS

GOMARKMINE		JSR DRAWMINE			; solve square
				
				JMP NEXTSQUARE
;/MARKMINE
	
					
SPACE			STA STROBE				; solve current square and move to next space

				JSR DRAWSOLVEDSQUARE	; solve square if not already solved
										; highlight next square
NEXTSQUARE		INC COLUMN				; increment column
				LDA COLUMN				
				CMP #$8
				BMI HILITENEXTSQUARE	
				INC ROW					; if column = 8, column = 0, row ++
				LDA #$0
				STA COLUMN

				LDA ROW					; if row = 8, row = 0
				CMP #$8
				BMI HILITENEXTSQUARE	
				LDA #$0
				STA ROW
				
HILITENEXTSQUARE
				JSR HILITESQUARE		;
				RTS
;/GOTSPACE
	
UP 				STA STROBE				;
				JSR DESELECTSQUARE		; resolve current square from progress
										
				LDA ROW					; if row = 0, then row = 7
				BNE GOTUPROW
				LDA #$08
				STA ROW
					
GOTUPROW		DEC ROW					; else, DEC ROW
										; highlight current square	
				JSR HILITESQUARE		;
				RTS
;/GOTUP				

DOWN 			STA STROBE				;
				JSR DESELECTSQUARE		; resolve current square from progress
										
				LDA ROW					; if row = 7, then row = 0
				CMP #$07
				BMI GOTDOWNROW
				LDA #$FF
				STA ROW
					
GOTDOWNROW		INC ROW					; else, INC ROW
										; highlight current square	
				JSR HILITESQUARE		;
				RTS
;/GOTDOWN				

LEFT		STA STROBE				; solve current square and move to previous space
				JSR DESELECTSQUARE		; resolve current square from progress
										; highlight prev square
				DEC COLUMN				; decrement column
				LDA COLUMN				
				CMP #$FF
				BNE LEFTNEXTSQUARE	
				DEC ROW					; if column = 0, column = 7, row ++
				LDA #$7
				STA COLUMN

				LDA ROW					; if row = 0, row = 8
				CMP #$FF
				BNE LEFTNEXTSQUARE	
				LDA #$7
				STA ROW
				
LEFTNEXTSQUARE
				JSR HILITESQUARE		;
				RTS
;/GOTLEFT

RIGHT		STA STROBE				; solve current square and move to next space
				JSR DESELECTSQUARE		; resolve current square from progress
										; highlight next square
				INC COLUMN				; increment column
				LDA COLUMN				
				CMP #$8
				BMI RIGHTNEXTSQUARE	
				INC ROW					; if column = 8, column = 0, row ++
				LDA #$0
				STA COLUMN

				LDA ROW					; if row = 8, row = 0
				CMP #$8
				BMI RIGHTNEXTSQUARE	
				LDA #$0
				STA ROW
				
RIGHTNEXTSQUARE
				JSR HILITESQUARE		;
				RTS
;/GOTRIGHT

**************************************************
*	subroutines
*
**************************************************

**************************************************
*	writes number of bombs to find, etc
**************************************************
PRINTBOMBS		; move cursor to 0x14,0x15, VTAB, LDA BOMBS, JSR FDDA
				LDA #$14
				STA CV
				LDA #$15
				STA CH
				JSR VTAB
				LDA BOMBS
				JSR $FDDA			; prints HEX of Accumulator
				RTS
				

PRINTSCORE					; prints number of bombs marked
				LDA #$14
				STA CV
				LDA #$0F
				STA CH
				JSR VTAB
				LDA SCORE
				JSR $FDDA			; prints HEX of Accumulator
				RTS

PRINTPROGRESS					; prints number of bombs marked
				LDA #$15
				STA CV
				LDA #$11
				STA CH
				JSR VTAB
				LDA PROGRESS
				JSR $FDDA			; prints HEX of Accumulator
				RTS

**************************************************
*	writes instructions and scoreboard
**************************************************
HELLOWORLD		ASC	"MINESWEEPER",00	; set to ascii for message
LINE1			ASC "By Charles Mangin", 00
LINE2			ASC "I, J, K, L to move",00
LINE3			ASC "SPC to clear cell",00
LINE4			ASC "M to mark a mine",00
LINE5			ASC "ESC=QUIT R=RESET",00
LINE6			ASC "Mines found:  0 of",00
LINE7			ASC "Cells cleared:  0 of 64",00

INSTRUCTIONS	LDA #$1
				STA CV					; get screen address at row 2, column 20

				JSR RIGHTCOLUMN
				LDY #>HELLOWORLD
				LDA #<HELLOWORLD
				JSR STROUT				;Y=String ptr high, A=String ptr low
				
				JSR RIGHTCOLUMN
				LDY #>LINE1
				LDA #<LINE1
				JSR STROUT				;Y=String ptr high, A=String ptr low
				
				INC CV
				JSR RIGHTCOLUMN
				LDY #>LINE2
				LDA #<LINE2
				JSR STROUT				;Y=String ptr high, A=String ptr low

				JSR RIGHTCOLUMN
				LDY #>LINE3
				LDA #<LINE3
				JSR STROUT				;Y=String ptr high, A=String ptr low

				JSR RIGHTCOLUMN
				LDY #>LINE4
				LDA #<LINE4
				JSR STROUT				;Y=String ptr high, A=String ptr low

				JSR RIGHTCOLUMN
				LDY #>LINE5
				LDA #<LINE5
				JSR STROUT				;Y=String ptr high, A=String ptr low
				
				LDA #$13
				STA CV					; jump down
				JSR LEFTCOLUMN
				LDY #>LINE6
				LDA #<LINE6
				JSR STROUT				;Y=String ptr high, A=String ptr low
				
				JSR LEFTCOLUMN
				LDY #>LINE7
				LDA #<LINE7
				JSR STROUT				;Y=String ptr high, A=String ptr low
				RTS
;/INSTRUCTIONS

RIGHTCOLUMN		INC CV
				JSR VTAB		
				LDA #$14
				STA CH								
				RTS

LEFTCOLUMN		INC CV
				JSR VTAB		
				LDA #$02
				STA CH								
				RTS

**************************************************
*	puts ? in unsolved square by ROW, COLUMN
**************************************************
DRAWSQUARE								; puts ? in unsolved square
				LDA #$BF				; "?"
				STA CHAR				; store as CHAR 
				LDA ROW
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTROW
				LDA COLUMN
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTCOLUMN				 
				JSR PLOTCHAR 
				RTS
;/DRAWSQUARE
**************************************************
*	puts _ in selected square by ROW, COLUMN
**************************************************
HILITESQUARE								; puts _ in selected square
				LDA #$5F				; "_"
				STA CHAR				; store as CHAR 
				LDA ROW
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTROW
				LDA COLUMN
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTCOLUMN				 
				JSR PLOTCHAR 
				RTS
;/HILITESQUARE


**************************************************
*	restores progress or ? to selected square by ROW, COLUMN
**************************************************
DESELECTSQUARE							; puts number/? in deselected square
				LDA ROW					; get ROW and COLUMN
				CLC
				ROL						
				ROL						
				ROL
				CLC
				ADC COLUMN				; offset = ROW * 8 + COLUMN
				TAX			
				LDA PROGRESSORIGIN,X	; get SOLVEORIGIN + offset
				CMP #$FF
				BNE SHOWSOLVED			; if == FF , not yet solved. CHAR = ?
				LDA #$8F
				STA CHAR				; store as CHAR 				
SHOWSOLVED		CLC
				ADC #$30				; add #$30  (becomes #)
				STA CHAR				; store as CHAR 
				LDA ROW
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTROW
				LDA COLUMN
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTCOLUMN				 
				JSR PLOTCHAR 
				RTS
;/DESELECTSQUARE


**************************************************
*	puts * in selected square by ROW, COLUMN, increments score
**************************************************

DRAWMINE		JSR BEEP				; puts * in selected square
				LDA ROW					; get ROW and COLUMN
				CLC
				ROL						
				ROL						; offset = ROW * 8 + COLUMN
				ROL
				CLC
				ADC COLUMN
				TAX			
				LDA #$7A				; * for mine
				STA PROGRESSORIGIN,X	; store marker in progress				
				CLC
				ADC #$30				; add #$30  (becomes *)
				STA CHAR				; store as CHAR
				LDA ROW
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTROW
				LDA COLUMN
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTCOLUMN				 
				JSR PLOTCHAR 
										; update score
				LDA SCORE				; inc as decimal for printy printy.
				SED
				CLC
				ADC #1
				CLD
				STA SCORE
				JSR PRINTSCORE
											; mark a mine, increment "cleared" as well
				LDA PROGRESS				; inc as decimal for printy printy.
				SED
				CLC
				ADC #1
				CLD
				STA PROGRESS
				JSR PRINTPROGRESS

				RTS
;/DRAWMINE

**************************************************
*	puts # of adjacent bombs in selected square by ROW, COLUMN, increments progress
**************************************************
DRAWSOLVEDSQUARE						; puts number in selected/solved square
				JSR CLICK				; little sound clicks
				LDA ROW					; get ROW and COLUMN
				CLC
				ROL						
				ROL						; offset = ROW * 8 + COLUMN
				ROL
				CLC
				ADC COLUMN
				TAX			
				LDA PROGRESSORIGIN,X	; check if it hasn't been solved yet, 
				CMP #$7A				; if it's already been marked as a mine
				BEQ SOLVEBOMB		    ; mark it unsolved
				CLC
				CMP #$FF				; put the solution in the square, 
				BNE	SOLVENOBOMB			; increment the progress
										
				LDA PROGRESS			; inc as decimal for printy printy.
				SED
				CLC
				ADC #1
				CLD
				STA PROGRESS
				JSR PRINTPROGRESS
										
				LDA SOLVEORIGIN,X		; get SOLVEORIGIN + offset
				STA PROGRESSORIGIN,X	; store progress
				CMP #$08				; IF >= F0, found a bomb
				BMI	SOLVENOBOMB	
				JSR BONK				; BONK!
				LDA #$52				; FOUND BOMB. YOU LOSE.
								
SOLVENOBOMB		CLC
				ADC #$30				; add #$30  (becomes #)
				STA CHAR				; store as CHAR 
				LDA ROW
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTROW
				LDA COLUMN
				CLC
				ADC #$01				; zero-based to 1-based
				ROL						; ROW * 2, COLUMN * 2
				STA PLOTCOLUMN				 
				JSR PLOTCHAR 
				RTS

SOLVEBOMB		LDA #$FF				; unmark as bomb
				STA PROGRESSORIGIN,X	;
										; decrement bombs found
				LDA SCORE				; decrement as decimal for printy printy.
				SED
				SEC
				SBC #1
				CLD
				STA SCORE
				JSR PRINTSCORE

				LDA PROGRESS				; decrement progress as well, so it will increment properly on jump
				SED
				SEC
				SBC #1
				CLD
				STA PROGRESS
				JSR PRINTPROGRESS

				JMP DRAWSOLVEDSQUARE	; go back and solve it as normal


;/DRAWSOLVEDSQUARE



**************************************************
*	solves squares for adjacent bombs, updates solved map, increments bomb count
**************************************************
FOUNDBOMB								; how many have we found?	
				LDA BOMBS				; inc as decimal for printy printy.
				SED
				CLC
				ADC #1
				CLD
				STA BOMBS
				
				CLC						; clear the carry in case we found a bomb
				TXA						; accum = ROW
				ROL						; 
				ROL						; 
				ROL						; accum = ROW * 8
				CLC	
				STY BOMBLOC				; BOMBLOC = COLUMN
				ADC	BOMBLOC				; accum += COLUMN
				STA BOMBLOC				; BOMBLOC = (row*8) + column = offset from origin
					
				LDA #$0F				; F0 doesn't want to work? 
				LDX BOMBLOC				; X = bomb offset
				STA SOLVEORIGIN,X		; 
	
				DEX	
					
				TYA						; Does Y = 0
				CLC	
				BEQ	MINUSSONE			; if == 0, then skip the - 1
					
				INC SOLVEORIGIN,X		; INC (byte at BOMBBYTE - 1)
	
MINUSSONE		INX
				INX

				SEC
				SBC #$7					; does y = 8
				BEQ PLUSONE	
					
				INC SOLVEORIGIN,X		; INC (byte at BOMBBYTE + 1)
					
PLUSONE			TXA						; accumulator holds offset + 1
				SEC	
				SBC #$A					; subtract 10 from offset
				TAX						; back to X
	
				TYA						; Does Y = 0
				CLC	
				BEQ	MINUSNINE			; if == 0, then skip the - 9
					
				INC SOLVEORIGIN,X		; INC (byte at BOMBBYTE - 9)
MINUSNINE		INX	
				INC SOLVEORIGIN,X		; INC (byte at BOMBBYTE - 8)
				INX	
	
				SEC	
				SBC #$7					; does y = 8
				BEQ MINUSSEVEN	
	
				INC SOLVEORIGIN,X		; INC (byte at BOMBBYTE - 7)
	
MINUSSEVEN		TXA						; accumulator holds offset - 7
				CLC						
				ADC #$E					; add 15
				TAX						; back to X
	
				TYA						; Does Y = 0
				CLC
				BEQ	PLUSSEVEN			; if == 0, then skip the + 7
					
				INC SOLVEORIGIN,X		; INC (byte at BOMBBYTE + 7)
PLUSSEVEN		INX	
				INC SOLVEORIGIN,X		; INC (byte at BOMBBYTE + 8)
	
				TYA						
				SEC	
				SBC #$7					; does y = 8
				BEQ PLUSNINE	
	
				INX	
				INC SOLVEORIGIN,X		; INC (byte at BOMBBYTE + 9)
	
PLUSNINE		LDY COLUMN
				LDX ROW
				RTS

;/FOUNDBOMB


**************************************************
*	prints one CHAR at PLOTROW,PLOTCOLUMN
**************************************************
PLOTCHAR
				LDY PLOTROW
				LDA LoLineTableL,Y
				STA $0
				LDA LoLineTableH,Y
				STA $1       		  	; now word/pointer at $0+$1 points to line 
				LDY PLOTCOLUMN
				LDA CHAR				; this would be a byte with two pixels
				STA ($0),Y  
				RTS
;/PLOTCHAR					   


RESET			JMP DRAWBOARD

**************************************************
*	CLICKS and BEEPS
**************************************************
CLICK			LDX #$06
CLICKLOOP		LDA #$10				; SLIGHT DELAY
				JSR WAIT
				LDA SPEAKER				
				DEX
				BNE CLICKLOOP
				RTS
;/CLICK

BEEP			LDX #$30
BEEPLOOP		LDA #$08				; short DELAY
				JSR WAIT
				LDA SPEAKER				
				DEX
				BNE BEEPLOOP
				RTS
;/BEEP


BONK			LDX #$50
BONKLOOP		LDA #$20				; longer DELAY
				JSR WAIT
				LDA SPEAKER				
				DEX
				BNE BONKLOOP
				RTS
;/BONK



**************************************************
* Data Tables
*
**************************************************

BOARDORIGIN		 	HEX 	80,00,00,10,08,00,00,01 ; sets up the board



**************************************************
* Lores/Text lines
**************************************************
Lo01                 equ   $400
Lo02                 equ   $480
Lo03                 equ   $500
Lo04                 equ   $580
Lo05                 equ   $600
Lo06                 equ   $680
Lo07                 equ   $700
Lo08                 equ   $780
Lo09                 equ   $428
Lo10                 equ   $4a8
Lo11                 equ   $528
Lo12                 equ   $5a8
Lo13                 equ   $628
Lo14                 equ   $6a8
Lo15                 equ   $728
Lo16                 equ   $7a8
Lo17                 equ   $450
Lo18                 equ   $4d0
Lo19                 equ   $550
Lo20                 equ   $5d0
* the "plus four" lines
Lo21                 equ   $650
Lo22                 equ   $6d0
Lo23                 equ   $750
Lo24                 equ   $7d0

LoLineTable          da    	Lo01,Lo02,Lo03,Lo04
                     da    	Lo05,Lo06,Lo07,Lo08
                     da		Lo09,Lo10,Lo11,Lo12
                     da    	Lo13,Lo14,Lo15,Lo16
                     da		Lo17,Lo18,Lo19,Lo20
                     da		Lo21,Lo22,Lo23,Lo24
** Here we split the table for an optimization
** We can directly get our line numbers now
** Without using ASL
LoLineTableH         db    >Lo01,>Lo02,>Lo03
                     db    >Lo04,>Lo05,>Lo06
                     db    >Lo07,>Lo08,>Lo09
                     db    >Lo10,>Lo11,>Lo12
                     db    >Lo13,>Lo14,>Lo15
                     db    >Lo16,>Lo17,>Lo18
                     db    >Lo19,>Lo20,>Lo21
                     db    >Lo22,>Lo23,>Lo24
LoLineTableL         db    <Lo01,<Lo02,<Lo03
                     db    <Lo04,<Lo05,<Lo06
                     db    <Lo07,<Lo08,<Lo09
                     db    <Lo10,<Lo11,<Lo12
                     db    <Lo13,<Lo14,<Lo15
                     db    <Lo16,<Lo17,<Lo18
                     db    <Lo19,<Lo20,<Lo21
                     db    <Lo22,<Lo23,<Lo24

*	ROW, COLUMN		

*   . at 1,1 			#$2E
*   . at 1,17
*   ' at 17,1 			#$27
*   ' at 17,17
*   - 1,2 to 1,16		#$2D
*   - 17,2 to 17,16
*   : 2,1 to 16,1		#$3A
*   : ROW*2,COLUMN*2 + 1
*   - ROW*2 + 1, COLUMN*2 
* 	+ ROW*2 + 1, COLUMN*2 + 1

* .---------------.  			
* :1:2:3:4:5:6:7:8:			
* :-+-+-+-+-+-+-+-:
* :2:2:3:4:5:6:7:8:			
* :-+-+-+-+-+-+-+-:
* :3:2:3:4:5:6:7:8:			
* :-+-+-+-+-+-+-+-:
* :4:2:3:4:5:6:7:8:			
* :-+-+-+-+-+-+-+-:
* :5:2:3:4:5:6:7:8:			
* :-+-+-+-+-+-+-+-:
* :6:2:3:4:5:6:7:8:			
* :-+-+-+-+-+-+-+-:
* :7:2:3:4:5:6:7:8:			
* :-+-+-+-+-+-+-+-:
* :8:2:3:4:5:6:7:8:			
* '---------------'