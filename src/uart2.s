        PUBLIC  __iar_program_start
        EXTERN  __vector_table

        SECTION .text:CODE:REORDER(2)
        
        ;; Keep vector table even if it's not referenced
        REQUIRE __vector_table
        
        THUMB

; System Control definitions
SYSCTL_BASE             EQU     0x400FE000
SYSCTL_RCGCGPIO         EQU     0x0608
SYSCTL_PRGPIO		EQU     0x0A08
SYSCTL_RCGCUART         EQU     0x0618
SYSCTL_PRUART           EQU     0x0A18
; System Control bit definitions
PORTA_BIT               EQU     000000000000001b ; bit  0 = Port A
PORTF_BIT               EQU     000000000100000b ; bit  5 = Port F
PORTJ_BIT               EQU     000000100000000b ; bit  8 = Port J
PORTN_BIT               EQU     001000000000000b ; bit 12 = Port N
UART0_BIT               EQU     00000001b        ; bit  0 = UART 0

; NVIC definitions
NVIC_BASE               EQU     0xE000E000
NVIC_EN1                EQU     0x0104
VIC_DIS1                EQU     0x0184
NVIC_PEND1              EQU     0x0204
NVIC_UNPEND1            EQU     0x0284
NVIC_ACTIVE1            EQU     0x0304
NVIC_PRI12              EQU     0x0430

; GPIO Port definitions
GPIO_PORTA_BASE         EQU     0x40058000
GPIO_PORTF_BASE    	EQU     0x4005D000
GPIO_PORTJ_BASE    	EQU     0x40060000
GPIO_PORTN_BASE    	EQU     0x40064000
GPIO_DIR                EQU     0x0400
GPIO_IS                 EQU     0x0404
GPIO_IBE                EQU     0x0408
GPIO_IEV                EQU     0x040C
GPIO_IM                 EQU     0x0410
GPIO_RIS                EQU     0x0414
GPIO_MIS                EQU     0x0418
GPIO_ICR                EQU     0x041C
GPIO_AFSEL              EQU     0x0420
GPIO_PUR                EQU     0x0510
GPIO_DEN                EQU     0x051C
GPIO_PCTL               EQU     0x052C

; UART definitions
UART_PORT0_BASE         EQU     0x4000C000
UART_FR                 EQU     0x0018
UART_IBRD               EQU     0x0024
UART_FBRD               EQU     0x0028
UART_LCRH               EQU     0x002C
UART_CTL                EQU     0x0030
UART_CC                 EQU     0x0FC8
;UART bit definitions
TXFE_BIT                EQU     10000000b ; TX FIFO full
RXFF_BIT                EQU     01000000b ; RX FIFO empty
BUSY_BIT                EQU     00001000b ; Busy


; PROGRAMA PRINCIPAL

__iar_program_start
        
main:   MOV R2, #(UART0_BIT)
	BL UART_enable ; habilita clock ao port 0 de UART

        MOV R2, #(PORTA_BIT)
	BL GPIO_enable ; habilita clock ao port A de GPIO
        
	LDR R0, =GPIO_PORTA_BASE
        MOV R1, #00000011b ; bits 0 e 1 como especiais
        BL GPIO_special

	MOV R1, #0xFF ; máscara das funções especiais no port A (bits 1 e 0)
        MOV R2, #0x11  ; funções especiais RX e TX no port A (UART)
        BL GPIO_select

	LDR R0, =UART_PORT0_BASE
        BL UART_config ; configura periférico UART0
        
        ; recepção e envio de dados pela UART utilizando sondagem (polling)
        ; resulta em um "eco": dados recebidos são retransmitidos pela UART
;<=============================================================================
;O seguinte algoritmo implementa o funcionamento de uma calculadora de com as
;operacoes: adicao inteira, subtracao interia, multipliacao inteira e divisao
;inteira.

;O laco principal reinicia os registradores a serem utilizados para as operacoes
loop:
	mov		r1,#0
	mov		r2,#0
	mov		r3,#0
	mov 	        r4,#0
	mov		r5,#0
	mov		r6,#0
	mov		r7,#0
	mov		r8,#0
        mov		r9,#0
	mov		r10,#0
;<=============================================================================
;As funcoes de leitura e retransmissao recebem os dados da UART e caso sejam
;validos eles sao retransmitidos ao usuario. A verificacao de validade ocorre
;atraves das funcoes "verificacao"   
leitura:
	ldr 	        r2,[r0,#UART_FR]
	tst 	        r2,#RXFF_BIT
	beq 	        leitura
	ldr		r1,[r0]
	
	add		r4,#1
	bl		verifica0
	push	        {r5}
	add		r7,#1
;A funcao de retransmissao tambem fui reutilizada pelas funcoes "erro", para
;imprimir a mensagem de "ERRO" quando os dados de entrada nao sao validos e pela
;funcao "transmissao" que transmite o resultado final.
retransmissao:
	ldr		r2,[r0,#UART_FR]
	tst		r2,#TXFE_BIT  
	beq		retransmissao
	str		r1,[r0]
        
        teq             r8,#1
        it              eq
        bxeq            lr
	
	teq		r1,#0x3D
	beq		calculo
	b		leitura
;<=============================================================================
erro:
        mov     r8,#1
	mov	r1,#'E'
	bl      retransmissao
        mov	r1,#'R'
	bl      retransmissao
        mov	r1,#'R'
	bl      retransmissao
        mov	r1,#'O'
	bl      retransmissao
        mov	r1,#'\r'
	bl      retransmissao
	mov	r1,#'\n'
	bl	retransmissao

        mov	lr,#0xffffffff
	
limpapilha:	
	teq     r7,#0
	beq	loop
	
	pop	{r1}
	sub	r7,#1
	b	limpapilha
;<=============================================================================
;A funcao "verifica1" ocorre quando o usuario digita o primeiro digito dos        
;numeros da operacao. A funcao "verifica2" ocorre quando o usuario digita
;nao o primeiro digito dos numeros da operacao, ou quando o usuario digita o
;o sinal de operacao ('+','-','*','/')
verifica0:
	teq		r4,#1
	beq		verifica1
	
	b		verifica2
;<=============================================================================
verifica1:
	mov		r2,#'0'
	mov		r3,#0
test:
	teq		r1,r2
	itt		eq
	moveq	        r5,r3
	bxeq	        lr
	add		r2,#1
	add		r3,#1
	teq		r3,#10
	beq		erro
	b		test
;<=============================================================================
verifica2:

        teq		r4,#5
	beq		test3
        
	;verifica se eh um número
	mov		r2,#'0'
	mov		r3,#0
test2:
	teq		r1,r2
	itt		eq
	moveq	        r5,r3
	beq		ajuste
	
	add		r2,#1
	add		r3,#1
	teq		r3,#10
	beq		test3
	b		test2
ajuste:
	pop		{r2}
        mov             r10,#10
	mul		r2,r2,r10
	add		r5,r5,r2
	bx		lr
	
test3:	
	;verifica se eh uma operacao

        teq		r6,#1
	beq		verifica3
        
	mov		r2,#0x2B
	teq		r1,r2
	itttt	        eq
	moveq	        r6,#1
	moveq	        r4,#0
	moveq	        r5,r1
	bxeq	        lr
	
	mov		r2,#0x2D
	teq		r1,r2
	itttt	        eq
	moveq	        r6,#1
	moveq	        r4,#0
	moveq	        r5,r1
	bxeq	        lr
	
	mov		r2,#0x2A
	teq		r1,r2
	itttt	        eq
	moveq	        r6,#1
	moveq	        r4,#0
	moveq	        r5,r1
	bxeq	        lr
	
	mov		r2,#0x2F
	teq		r1,r2
	itttt	        eq
	moveq	        r6,#1
	moveq	        r4,#0
	moveq	        r5,r1
	bxeq	        lr
	
	;caso nao for nem numero, nem operacao, vai a funcao erro
	
	b		erro
;<=============================================================================
;A funcao "verifica3" previne o usuário de digitar um numero com mais de 4 digitos
verifica3:
	mov		r2,#0x3D
	teq		r1,r2
	itt		eq
	moveq	        r5,r1
	bxeq	        lr
	
	b		erro
;<=============================================================================
calculo:	
	pop		{r1,r2,r3,r4}

        mov		r5,#0x2B
	
	teq		r3,#0x2B
	it		eq
	addeq   	r6,r2,r4
	
	teq		r3,#0x2D
	it		eq
	bleq    	subtracao
	
	teq		r3,#0x2A
	it		eq
	muleq   	r6,r2,r4

	teq		r3,#0x2F
	it		eq
	udiveq    	r6,r4,r2
	
	mov		r1,r6
	mov		r2,r5
	bl		decompoe
;<=============================================================================
;A funcao subtracao ajusta o sinal a ser mostrado na frente do numero e realiza
;as operacoes de subtracao
subtracao:
	subs		r9,r2,r4
	itte    	hi
	subhi   	r6,r2,r4
	movhi   	r5,#0x2D
	subls           r6,r4,r2
	bx		lr
;<=============================================================================
;A funcao "decompoe" transforma o resultado na sequencia de codigos ASCII de
;seus numeros, conforme as operacoes discutidas em aula
decompoe:
	mov		r3,#10
        mov      	r4,#0
analise:
	udiv    	r5,r1,r3
	mul		r6,r5,r3
	sub             r7,r1,r6
	
	push    	{r7}
	mov		r1,r5
	
	add		r4,#1
	teq		r5,#0
        beq             transmissao
	b		analise

transmissao:
        mov             r8,#1
        
	mov		r1,r2
	bl		retransmissao
loop2:
	teq		r4,#0
	beq		final
	
	pop		{r1}
	add		r1,#0x30
	bl		retransmissao
	sub		r4,#1
	b		loop2
;<=============================================================================
final:
        
	mov		r1,#'\r'
	bl		retransmissao
        
	mov		r1,#'\n'
	bl		retransmissao
	b 		loop	
;<=============================================================================
; SUB-ROTINAS

;----------
; UART_enable: habilita clock para as UARTs selecionadas em R2
; R2 = padrão de bits de habilitação das UARTs
; Destrói: R0 e R1
UART_enable:
        LDR R0, =SYSCTL_BASE
	LDR R1, [R0, #SYSCTL_RCGCUART]
	ORR R1, R2 ; habilita UARTs selecionados
	STR R1, [R0, #SYSCTL_RCGCUART]

waitu	LDR R1, [R0, #SYSCTL_PRUART]
	TEQ R1, R2 ; clock das UARTs habilitados?
	BNE waitu

        BX LR
        
; UART_config: configura a UART desejada
; R0 = endereço base da UART desejada
; Destrói: R1
UART_config:
        LDR R1, [R0, #UART_CTL]
        BIC R1, #0x01 ; desabilita UART (bit UARTEN = 0)
        STR R1, [R0, #UART_CTL]

        ; clock = 16MHz, baud rate = 14400bps
      
        mov r1, #69
        STR R1, [R0, #UART_IBRD]
      
        mov r1, #28
        STR R1, [R0, #UART_FBRD]
        
        ; 7 bits de dados, paridade par e 1 bit de parada
      
        mov r1, #0x46
        STR R1, [R0, #UART_LCRH]
        
        ; clock source = system clock
        MOV R1, #0x00
        STR R1, [R0, #UART_CC]
        
        LDR R1, [R0, #UART_CTL]
        ORR R1, #0x01 ; habilita UART (bit UARTEN = 1)
        STR R1, [R0, #UART_CTL]

        BX LR


; GPIO_special: habilita funcões especiais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como funções especiais
; Destrói: R2
GPIO_special:
	LDR R2, [R0, #GPIO_AFSEL]
	ORR R2, R1 ; configura bits especiais
	STR R2, [R0, #GPIO_AFSEL]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_select: seleciona funcões especiais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem alterados
; R2 = padrão de bits (1) a serem selecionados como funções especiais
; Destrói: R3
GPIO_select:
	LDR R3, [R0, #GPIO_PCTL]
        BIC R3, R1
	ORR R3, R2 ; seleciona bits especiais
	STR R3, [R0, #GPIO_PCTL]

        BX LR
;----------

; GPIO_enable: habilita clock para os ports de GPIO selecionados em R2
; R2 = padrão de bits de habilitação dos ports
; Destrói: R0 e R1
GPIO_enable:
        LDR R0, =SYSCTL_BASE
	LDR R1, [R0, #SYSCTL_RCGCGPIO]
	ORR R1, R2 ; habilita ports selecionados
	STR R1, [R0, #SYSCTL_RCGCGPIO]

waitg	LDR R1, [R0, #SYSCTL_PRGPIO]
	TEQ R1, R2 ; clock dos ports habilitados?
	BNE waitg

        BX LR

; GPIO_digital_output: habilita saídas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como saídas digitais
; Destrói: R2
GPIO_digital_output:
	LDR R2, [R0, #GPIO_DIR]
	ORR R2, R1 ; configura bits de saída
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_write: escreve nas saídas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits a serem escritos
GPIO_write:
        STR R2, [R0, R1, LSL #2] ; escreve bits com máscara de acesso
        BX LR

; GPIO_digital_input: habilita entradas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como entradas digitais
; Destrói: R2
GPIO_digital_input:
	LDR R2, [R0, #GPIO_DIR]
	BIC R2, R1 ; configura bits de entrada
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

	LDR R2, [R0, #GPIO_PUR]
	ORR R2, R1 ; habilita resitor de pull-up
	STR R2, [R0, #GPIO_PUR]

        BX LR

; GPIO_read: lê as entradas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits lidos
GPIO_read:
        LDR R2, [R0, R1, LSL #2] ; lê bits com máscara de acesso
        BX LR

; SW_delay: atraso de tempo por software
; R0 = valor do atraso
; Destrói: R0
SW_delay:
        CBZ R0, out_delay
        SUB R0, R0, #1
        B SW_delay        
out_delay:
        BX LR

; LED_write: escreve um valor binário nos LEDs D1 a D4 do kit
; R0 = valor a ser escrito nos LEDs (bit 3 a bit 0)
; Destrói: R1, R2, R3 e R4
LED_write:
        AND R3, R0, #0010b
        LSR R3, R3, #1
        AND R4, R0, #0001b
        ORR R3, R3, R4, LSL #1 ; LEDs D1 e D2
        LDR R1, =GPIO_PORTN_BASE
        MOV R2, #000000011b ; máscara PN1|PN0
        STR R3, [R1, R2, LSL #2]

        AND R3, R0, #1000b
        LSR R3, R3, #3
        AND R4, R0, #0100b
        ORR R3, R3, R4, LSL #2 ; LEDs D3 e D4
        LDR R1, =GPIO_PORTF_BASE
        MOV R2, #00010001b ; máscara PF4|PF0
        STR R3, [R1, R2, LSL #2]
        
        BX LR

; Button_read: lê o estado dos botões SW1 e SW2 do kit
; R0 = valor lido dos botões (bit 1 e bit 0)
; Destrói: R1, R2, R3 e R4
Button_read:
        LDR R1, =GPIO_PORTJ_BASE
        MOV R2, #00000011b ; máscara PJ1|PJ0
        LDR R0, [R1, R2, LSL #2]
        
dbc:    MOV R3, #50 ; constante de debounce
again:  CBZ R3, last
        LDR R4, [R1, R2, LSL #2]
        CMP R0, R4
        MOV R0, R4
        ITE EQ
          SUBEQ R3, R3, #1
          BNE dbc
        B again
last:
        BX LR

; Button_int_conf: configura interrupções do botão SW1 do kit
; Destrói: R0, R1 e R2
Button_int_conf:
        MOV R2, #00000001b ; bit do PJ0
        LDR R1, =GPIO_PORTJ_BASE
        
        LDR R0, [R1, #GPIO_IM]
        BIC R0, R0, R2 ; desabilita interrupções
        STR R0, [R1, #GPIO_IM]
        
        LDR R0, [R1, #GPIO_IS]
        BIC R0, R0, R2 ; interrupção por transição
        STR R0, [R1, #GPIO_IS]
        
        LDR R0, [R1, #GPIO_IBE]
        BIC R0, R0, R2 ; uma transição apenas
        STR R0, [R1, #GPIO_IBE]
        
        LDR R0, [R1, #GPIO_IEV]
        BIC R0, R0, R2 ; transição de descida
        STR R0, [R1, #GPIO_IEV]
        
        LDR R0, [R1, #GPIO_ICR]
        ORR R0, R0, R2 ; limpeza de pendências
        STR R0, [R1, #GPIO_ICR]
        
        LDR R0, [R1, #GPIO_IM]
        ORR R0, R0, R2 ; habilita interrupções no port GPIO J
        STR R0, [R1, #GPIO_IM]

        MOV R2, #0xE0000000 ; prioridade mais baixa para a IRQ51
        LDR R1, =NVIC_BASE
        
        LDR R0, [R1, #NVIC_PRI12]
        ORR R0, R0, R2 ; define prioridade da IRQ51 no NVIC
        STR R0, [R1, #NVIC_PRI12]

        MOV R2, #10000000000000000000b ; bit 19 = IRQ51
        MOV R0, R2 ; limpa pendências da IRQ51 no NVIC
        STR R0, [R1, #NVIC_UNPEND1]

        LDR R0, [R1, #NVIC_EN1]
        ORR R0, R0, R2 ; habilita IRQ51 no NVIC
        STR R0, [R1, #NVIC_EN1]
        
        BX LR

; Button1_int_enable: habilita interrupções do botão SW1 do kit
; Destrói: R0, R1 e R2
Button1_int_enable:
        MOV R2, #00000001b ; bit do PJ0
        LDR R1, =GPIO_PORTJ_BASE
        
        LDR R0, [R1, #GPIO_IM]
        ORR R0, R0, R2 ; habilita interrupções
        STR R0, [R1, #GPIO_IM]

        BX LR

; Button1_int_disable: desabilita interrupções do botão SW1 do kit
; Destrói: R0, R1 e R2
Button1_int_disable:
        MOV R2, #00000001b ; bit do PJ0
        LDR R1, =GPIO_PORTJ_BASE
        
        LDR R0, [R1, #GPIO_IM]
        BIC R0, R0, R2 ; desabilita interrupções
        STR R0, [R1, #GPIO_IM]

        BX LR

; Button1_int_clear: limpa pendência de interrupções do botão SW1 do kit
; Destrói: R0 e R1
Button1_int_clear:
        MOV R0, #00000001b ; limpa o bit 0
        LDR R1, =GPIO_PORTJ_BASE
        STR R0, [R1, #GPIO_ICR]

        BX LR

        END
