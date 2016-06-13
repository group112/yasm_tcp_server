    section        .bss
    global         sigintFlg

    section        .text
    global         noSigInt
    global         noSigPipe

SA_RESTORER        equ                 0x04000000
SIGINT             equ                 2
SIGPIPE            equ                 13
sys_rt_sigaction   equ                 13
sys_rt_sigreturn   equ                 15

; ---- void noSigInt(void) ----------------------------------------------------
;
noSigInt:
    push           rbp
    mov            rbp,                rsp

    mov            rdi,                SIGINT 
    call           noSig

    leave
    ret

; ---- void noSigPipe(void) ---------------------------------------------------
;
noSigPipe:
    push           rbp
    mov            rbp,                rsp

    mov            rdi,                SIGPIPE 
    call           noSig

    leave
    ret

; ---- void noSig(int sn) -----------------------------------------------------
;
    section        .bss
                   align               16
nac                resb                160
oac                resb                160

    section        .text
noSig:
    push           rbp
    mov            rbp,                rsp

    ; Local variables.
    sub            rsp,                16
    sn             equ                 16

    mov            [rbp - sn],         rdi

    mov            qword[nac],         handler
    mov            qword[nac +  8],    SA_RESTORER
    mov            qword[nac + 16],    restorer

    mov            r10,                8
    mov            rdx,                oac
    mov            rsi,                nac
    mov            rdi,                [rbp - sn]    
    mov            rax,                sys_rt_sigaction
    syscall

    leave
    ret

; ---- void handler(int sn) ---------------------------------------------------
;
    section        .bss
sigintFlg          resb                1

    section        .text
handler:
    push           rbp
    mov            rbp,                rsp

    cmp            rdi,                SIGINT
    jne            .end
    mov            byte[sigintFlg],    1

.end:
    leave
    ret

; ---- void restorer(void) ----------------------------------------------------
;
restorer:
    mov            rax,                sys_rt_sigreturn
    syscall
