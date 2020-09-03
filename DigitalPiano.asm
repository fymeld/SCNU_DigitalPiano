IOY0     EQU  0600H        		;IOY0起始地址
A8254    EQU  IOY0+00H*2
B8254    EQU  IOY0+01H*2
C8254    EQU  IOY0+02H*2
CON8254  EQU  IOY0+03H*2

IOY1     EQU  0640H
MY8255_A    EQU  IOY1+00H*2
MY8255_B    EQU  IOY1+01H*2
MY8255_C    EQU  IOY1+02H*2
MY8255_CON  EQU  IOY1+03H*2

SSTACK	SEGMENT STACK
		DW 32 DUP(?)
SSTACK	ENDS

DATA SEGMENT
	Time   		DW 0
	LED     	DB 00H,08H,00H,01H,00H,01H
	DTABLE		DB 3FH,06H,5BH,4FH,66H,6DH,7DH,07H
		;       	 0,   1,  2, 3, 4,  5,  6,  7
				DB 77H,7CH,39H,5EH,79H,71H,6FH
		;       	 a,  b, c,  d,  e,  f,  g,  
	NowKey  	DB 00H
	Lastkey 	DB 00H
	Play    	DB 00H
	FREQ_LIST 	DW 221,248,278,294,330,371,416
				DW 248,278,312,330,371,416,467
				DW 131,147,165,175,196,221,248
				DW 147,165,185,196,221,248,278
				DW 165,185,208,221,248,278,312
				DW 175,196,221,234,262,294,330
				DW 196,221,248,262,294,330,371   ;低音区
				DW 441,495,556,589,661,742,833
				DW 495,556,624,661,742,833,935
				DW 262,294,330,350,393,441,495
				DW 294,331,371,393,441,495,556
				DW 330,371,416,441,495,556,624
				DW 350,393,441,467,525,589,661
				DW 393,441,495,525,589,661,742    ;中音区
				DW 882,990,1112,1178,1322,1484,1665
				DW 990,1112,1248,1322,1484,1665,1869
				DW 525,589,661,700,786,882,990
				DW 589,661,742,786,882,990,1112
				DW 661,742,833,882,990,1112,1248
				DW 700,786,882,935,1049,1178,1322
				DW 786,882,990,1049,1178,1322,1484  ;高音区
	Mem         DW 100 DUP(0)
DATA ENDS
	
CODE	SEGMENT
		ASSUME CS:CODE, SS:SSTACK,DS:DATA
START:	
		MOV AX,DATA
		MOV DS,AX
		PUSH DS
		MOV AX, 0000H
		MOV DS, AX
		MOV AX, OFFSET IRQ7			;取中断入口地址
		MOV SI, 003CH				;中断矢量地址
		MOV [SI], AX				;填IRQ7的偏移矢量
		MOV AX, CS					;段地址
		MOV SI, 003EH
		MOV [SI], AX				;填IRQ7的段地址矢量
		CLI
		POP DS
		;初始化主片8259
		MOV AL, 11H
		OUT 20H, AL				;ICW1
		MOV AL, 08H
		OUT 21H, AL				;ICW2
		MOV AL, 04H
		OUT 21H, AL				;ICW3
		MOV AL, 01H
		OUT 21H, AL				;ICW4
		MOV AL, 6FH				;OCW1
		OUT 21H, AL
		;8254
		MOV DX, CON8254
		MOV AL, 00110110B				;计数器0，方式3,二进制计数
		OUT DX, AL
		MOV DX, A8254
		MOV AL, 50H						;计数初值设为50000
		OUT DX, AL
		MOV AL, 0c3H
		OUT DX, AL
		
		MOV DI,OFFSET Mem
		MOV DX,MY8255_CON			;写8255控制字
		MOV AL,81H                  ;10000001
		OUT DX,AL
		STI
		
BEGIN:	CALL DIS					;调用显示子程序
		CALL CLEAR					;清屏
		CALL CCSCAN					;扫描
		JNZ INK1					;有健按下转到INK1
		JMP BEGIN					
		
INK1:	CALL DIS
		CALL DALLY
		CALL DALLY
		CALL CLEAR
		CALL CCSCAN
		JNZ INK2					;有键按下，转到INK2
		JMP BEGIN
;确定按下键的位置
INK2:	MOV CH,0FEH
		MOV CL,00H
COLUM:	MOV AL,CH
		MOV DX,MY8255_A 
		OUT DX,AL
		MOV DX,MY8255_C 
		IN AL,DX
L1:		TEST AL,01H         			;is L1?
		JNZ L2
		MOV AL,00H          			;L1
		JMP KCODE
L2:		TEST AL,02H         			;is L2?
		JNZ L3
		MOV AL,04H          			;L2
		JMP KCODE
L3:		TEST AL,04H         			;is L3?
		JNZ L4
		MOV AL,08H          			;L3
		JMP KCODE
L4:		TEST AL,08H         			;is L4?
		JNZ NEXT
		MOV AL,0CH          			;L4
KCODE:	ADD AL,CL
		CALL PUTBUF
		PUSH AX
KON: 	CALL DIS
		CALL CLEAR
		CALL CCSCAN
		JNZ KON
		CALL PausePlay
		CALL PushM
		POP AX
NEXT:	INC CL
		MOV AL,CH
		TEST AL,08H                     ;AL第4位是否为1，否跳到KERR
		JZ KERR
		ROL AL,1
		MOV CH,AL
		JMP COLUM
KERR:	JMP BEGIN


CCSCAN:	MOV AL,00H					;键盘扫描子程序
		MOV DX,MY8255_A  
		OUT DX,AL
		MOV DX,MY8255_C 
		IN  AL,DX
		NOT AL
		AND AL,0FH					;若有健按下，ZF为0
		RET
		
CLEAR:	MOV DX,MY8255_B 			;清屏子程序
		MOV AL,00H
		OUT DX,AL
		RET		
		
DIS:	PUSH AX  		;显示子程序
		PUSH SI
		MOV SI,OFFSET LED
		MOV DL,0DFH
		MOV AL,DL
AGAIN:	PUSH DX
		MOV DX,MY8255_A 
		OUT DX,AL
		MOV AL,[SI]
		MOV BX,OFFSET DTABLE
		AND AX,00FFH
		ADD BX,AX
		MOV AL,[BX]
		MOV DX,MY8255_B 
		OUT DX,AL
		CALL DALLY
		INC SI
		POP DX
		MOV AL,DL
		TEST AL,01H
		JZ  OUT1
		ROR AL,1
		MOV DL,AL
		JMP AGAIN
OUT1:	
	POP SI
	POP AX
		RET
		
DALLY:	PUSH CX						;延时子程序
		MOV CX,0006H
T1:		MOV AX,009FH
T2:		DEC AX
		JNZ T2
		LOOP T1
		POP CX
		RET
		
PUTBUF:	MOV  SI,OFFSET LED					
		MOV  DL,AL
		CMP  DL,00H					;不为零转到case01
		JNZ  case01
		;MOV  DL,Play
		;NOT  DL						;AL取反
		;MOV  Play,DL				;写回Play
		CALL PlayR
		jmp  BACK
case01:                      ;按下key2设置status的低2位
		MOV  DL,AL
		CMP  DL,01H
		JNZ  case02
		MOV  SI,OFFSET LED
		ADD  SI,03H
		MOV  DL,[SI]
		INC	 DL							
		AND  DL,03H
		CMP  DL,00H
		JNZ  WS				;DL不为零转到WS
		MOV  DL,01H
WS:		MOV  [SI],DL
		jmp  GOBACK
case02:                      ;按下key3-key9  
		MOV  DL,AL
		CMP  DL,08H			;大于8转到case03
		JA  case03
		SUB  DL,01H
		MOV  SI,OFFSET LED
		ADD  SI,05H
		MOV  [SI],DL
		jmp  GOBACK
case03:                      ;按下key10到key16
		MOV DL,AL
		SUB DL,01H
		MOV SI,OFFSET LED
		ADD SI,01H
		MOV [SI],DL	
GOBACK:	
		MOV SI,OFFSET LED  
		MOV AH,00H
		
		MOV AL,[SI+3]		;取音区
		SUB AL,01H
		MOV BL,07H
		MUL BL
		MOV DX,AX
		
		MOV BL,[SI+1]      ;取音调
		SUB BL,08H
		ADD DL,BL
		
		MOV AL,DL
		MOV BL,07H
		MUL BL
		
		MOV BL,[SI+5]
		SUB BL,01H
		ADD AL,BL
		MOV SI,OFFSET FREQ_LIST
		ADD AX,AX
		ADD SI,AX
		MOV BX,[SI]
		CALL PlayMusic
		
BACK:	
		RET

PlayMusic:  		;频率存在bx中
		PUSH AX 
		PUSH DX

		MOV DX,CON8254
		MOV AL,01110110B	;通道1，方式3，二进制计数
		OUT DX,AL
		MOV DX,000FH					
		MOV AX,4240H		;1MHz
		DIV BX 
		MOV DX,B8254
		OUT DX,AL
		MOV AL,AH
		OUT DX,AL
	
		POP DX
		POP AX
		RET
PlayR:	
		MOV SI,OFFSET Mem
playnext:		
		CMP SI,DI
		JZ  PlayEnd
		MOV BX,[SI]
		PUSH SI
		MOV SI,OFFSET FREQ_LIST
		ADD SI,BX
		MOV BX,[SI]
		CALL PlayMusic
		POP SI
		ADD SI,02H
		MOV DX,[SI]
		CALL DALLY2
		ADD SI,02H
		JMP playnext
PlayEnd:
		RET

DALLY2:						;延时子程序
D0:		MOV CX,0060H
D1:		MOV AX,00faH
D2:		DEC AX
		JNZ D2
		LOOP D1
		DEC DL
		JNZ D0
		RET
		
IRQ7:	
		PUSHF
		PUSH AX		
		MOV  AX,Time
		INC  AX
		MOV  Time,AX
		
		MOV AL, 20H				;中断结束命令
		OUT 20H, AL	
		
		POP  AX
		POPF
		IRET
		
PushM:
		MOV SI,OFFSET LED  
		MOV AH,00H
		
		MOV AL,[SI+3]		;取音区
		SUB AL,01H
		MOV BL,07H
		MUL BL
		MOV DX,AX
		
		MOV BL,[SI+1]      ;取音调
		SUB BL,08H
		ADD DL,BL
		
		MOV AL,DL
		MOV BL,07H
		MUL BL
		
		MOV BL,[SI+5]		;取音符
		SUB BL,01H
		ADD AL,BL
		ADD AX,AX
		
		MOV SI,DI
		MOV [SI],AX
		
		MOV AX,Time
		MOV [SI+2],AX
		
		ADD DI,04H
		MOV BX,OFFSET Mem
		ADD BX,200
		CMP DI,BX
		JNZ PEnd
		MOV DI,OFFSET Mem
PEnd:	
		MOV AX,0000H
		MOV Time,AX
		RET

PausePlay:	
		MOV DX,CON8254 ;初始化 8254 工作方式
		MOV AL,01110110B ;定时器 1、方式 3
		OUT DX,AL
		RET

CODE	ENDS
		END  START
