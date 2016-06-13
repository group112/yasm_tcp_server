    section        .bss
    extern         sigintFlg

    section        .text
    global         _start
    extern         error
    extern         fillAddr
    extern         noSigPipe
    extern         noSigInt
    extern         readAll
    extern         writeAll

; ---- _start -----------------------------------------------------------------
;
    section        .data
us                 db                  "Usage: ", 0
ar                 db                  " <ip> <port>", 10, 0

    section        .text
_start:
    cmp            qword[rsp],         3
    jne            .usg

    mov            rsi,                [rsp + 24]
    mov            rdi,                [rsp + 16]
    call           startSrv

    mov            rdi,                rax
    mov            rax,                60
    syscall

.usg:
    mov            rdi,                us
    call           error

    mov            rdi,                [rsp + 8]
    call           error

    mov            rdi,                ar
    call           error

    mov            rdi,                -1
    mov            rax,                60
    syscall

; ---- int startSrv(const char *ip, const char *port) -------------------------
;
    section        .data
fa                 db                  "Can't fill address",           10, 0
nsp                db                  "Can't setup SIGPIPE ignoring", 10, 0
nsi                db                  "Can't setup SIGINT ignoring",  10, 0
so                 db                  "Can't create socket",          10, 0
ra                 db                  "Can't perform setsockopt",     10, 0
bi                 db                  "Can't bind socket to address", 10, 0
li                 db                  "Can't start listen",           10, 0
ce                 db                  "Can't close properly",         10, 0

    section        .text
startSrv:
    push           rbp
    mov            rbp,                rsp

    ; Local variables.
    sa             equ                 16
    fd             equ                 32
    on             equ                 48
    sub            rsp,                48

    ; Fill address.
    mov            rdx,                rsi
    mov            rsi,                rdi
    lea            rdi,                [rbp - sa]
    call           fillAddr

    cmp            rax,                0
    je             .fa
    mov            rdi,                fa
    jmp            .err
.fa:

    ; Setup SIGPIPE ignoring.
    call           noSigPipe

    cmp            rax,                0
    je             .nsp
    mov            rdi,                nsp
    jmp            .err
.nsp:

    ; Setup SIGINT ignoring.
    call           noSigInt

    cmp            rax,                0
    je             .nsi
    mov            rdi,                nsi
    jmp            .err
.nsi:

    ; Create socket.
    mov            rdx,                0          ; 0
    mov            rsi,                1          ; SOCK_STREAM
    mov            rdi,                2          ; AF_INET
    mov            rax,                41         ; sys_socket
    syscall

    mov            [rbp - fd],         rax        ; fd

    cmp            rax,                -1
    jne            .so
    mov            rdi,                so
    jmp            .err
.so:

    ; Setup REUSEADDR server socket property.
    mov            qword[rbp - on],    1          ; on = 1

    mov            r8,                 4          ; sizeof on
    lea            r10,                [rbp - on] ; &on
    mov            rdx,                2          ; SO_REUSEADDR
    mov            rsi,                1          ; SOL_SOCKET
    mov            rdi,                [rbp - fd] ; fd
    mov            rax,                54         ; sys_setsockopt
    syscall

    cmp            rax,                -1
    jne            .ra
    mov            rdi,                ra
    jmp            .err
.ra:

    ; Bind.
    mov            rdx,                16         ; addrelen
    lea            rsi,                [rbp - sa] ; sa
    mov            rdi,                [rbp - fd] ; fd
    mov            rax,                49         ; sys_bind
    syscall

    cmp            rax,                -1
    jne            .bi
    mov            rdi,                bi
    jmp            .err
.bi:

    ; Listen.
    mov            rsi,                5
    mov            rdi,                [rbp - fd] ; fd
    mov            rax,                50         ; sys_listen
    syscall

    cmp            rax,                -1
    jne            .li
    mov            rdi,                li
    jmp            .err
.li:

    ; Start loop.
    mov            rdi,                [rbp - fd] ; fd
    call           startLoop

    ; Close.
    mov            rdi,                [rbp - fd] ; fd
    mov            rax,                3          ; sys_close
    syscall

    cmp            rax,                0
    je             .cl
    mov            rdi,                ce
    jmp            .err
.cl:

    mov            rax,                0
    jmp            .end

.err:
    call           error
    mov            rax,                -1

.end:
    leave
    ret

; ---- void startLoop(int ld) -------------------------------------------------
;
    section        .data
ac                 db                  "Can't accept connection", 10, 0

    section        .text
startLoop:
    push           rbp
    mov            rbp,                rsp

    ; Local variables.
    ld             equ                 16
    cd             equ                 32
    sa_clt         equ                 48
    sa_len         equ                 64
    sub            rsp,                64

    mov            [rbp - ld],         rdi

    ; Accept connections loop.
.loop:
    ; if(sigintFlg != 0) break
    cmp            byte[sigintFlg],     0
    jne            .end

    ; Accept new connection.
    mov            qword[rbp - sa_len], 16

    lea            rdx,                 [rbp - sa_len] ; &sa_len
    lea            rsi,                 [rbp - sa_clt] ; &sa_clt
    mov            rdi,                 [rbp - ld]     ; ld
    mov            rax,                 43             ; sys_accept
    syscall

    mov            [rbp - cd],          rax            ; cd

    cmp            rax,                 0
    jge            .ac
    mov            rdi,                 ac
    call           error
    jmp .loop

.ac:
    ; Treat connection.
    mov            rdi,                 [rbp - cd]     ; cd
    call           treatConn

    ; Close connection.
    mov            rdi,                 [rbp - cd]     ; cd
    mov            rax,                 3              ; sys_close
    syscall

    cmp            rax,                 0
    je             .cl
    mov            rdi,                 ce
    call           error
.cl:

    jmp .loop

.end:
    leave
    ret

; ---- void treatConn(int cd) -------------------------------------------------
;
    section        .data
wl                 db                  "Can't write length",  10, 0 
wm                 db                  "Can't write message", 10, 0 
rl                 db                  "Can't read length",   10, 0 
rm                 db                  "Can't read message",  10, 0

    section        .bss
buflen             equ                 1024
buf                resb                buflen

    section        .text
treatConn:
    push           rbp
    mov            rbp,                rsp

    ; Local variables.
    con            equ                 8
    len            equ                 16
    sub            rsp,                16

    mov            [rbp - con],        rdi

    ; Read incoming message length.
    mov            rdx,                8
    lea            rsi,                [rbp - len]
    mov            rdi,                [rbp - con]
    call           readAll

    cmp            rax,                0
    jz             .rl
    mov            rdi,                rl
    jmp            .err
.rl:

    ; Read incoming message.
    mov            rdx,                [rbp - len]
    mov            rsi,                buf
    mov            rdi,                [rbp - con]
    call           readAll

    cmp            rax,                0
    jz             .rm
    mov            rdi,                rm
    jmp            .err
.rm:

    ; Print incoming message.
    mov            rdx,                [rbp - len]
    mov            rsi,                buf
    mov            rdi,                1
    mov            rax,                1
    syscall

    ; Write outcoming message length.
    mov            rdx,                8
    lea            rsi,                [rbp - len]
    mov            rdi,                [rbp - con]
    call           writeAll

    cmp            rax,                0
    jz             .wl
    mov            rdi,                wl
    jmp            .err
.wl:

    ; Write outcoming message.
    mov            rdx,                [rbp - len]
    mov            rsi,                buf
    mov            rdi,                [rbp - con]
    call           writeAll

    cmp            rax,                0
    jz             .wm
    mov            rdi,                wm
    jmp            .err
.wm:

    jmp            .end

.err:
    call           error

.end:
    leave
    ret

