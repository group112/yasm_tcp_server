    section        .data
us                 db                  "Usage: ", 0
ar                 db                  " <ip> <port> <msg>", 10, 0

    section        .text
    global         _start
    extern         error
    extern         fillAddr
    extern         slength
    extern         writeAll
    extern         readAll
    extern         noSigPipe

_start:
    cmp            qword[rsp],         4
    jne            .usg

    mov            rdx,                [rsp + 32] ; msg
    mov            rsi,                [rsp + 24] ; port
    mov            rdi,                [rsp + 16] ; ip
    call           startClt

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

; -- int startClt(const char *ip, const char *port, const char *msg) ----------
;
    section        .data
fa                 db                  "Can't fill address",           10, 0
so                 db                  "Can't create socket",          10, 0
co                 db                  "Can't connect",                10, 0
ce                 db                  "Can't close properly",         10, 0
nsp                db                  "Can't setup SIGPIPE ignoring", 10, 0
sh                 db                  "Can't shutdown properly",      10, 0

    section        .text
startClt:
    push           rbp
    mov            rbp,                rsp

    ; Local variables.
    fd             equ                 8
    msg            equ                 16
    sa             equ                 32 
    sub            rsp,                32

    mov            [rbp - msg],        rdx

    ; Fill address.
    mov            rdx,                rsi        ;  port
    mov            rsi,                rdi        ;  ip
    lea            rdi,                [rbp - sa] ; &sa
    call fillAddr

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

    ; Connect.
    mov            rdx,                16         ; addrlen 
    lea            rsi,                [rbp - sa] ; sa
    mov            rdi,                [rbp - fd] ; fd
    mov            rax,                42         ; sys_connect
    syscall

    cmp            rax,                0
    je             .co
    mov            rdi,                co
    jmp            .err
.co:

    ; Perform request.
    mov            rsi,                [rbp - msg]; msg
    mov            rdi,                [rbp - fd] ; fd
    call           performReq

    ; Shutdown.
    mov            rsi,                2          ; how (both directions)
    mov            rdi,                [rbp - fd] ; fd
    mov            rax,                48         ; sys_shutdown
    syscall

    cmp            rax,                0
    je             .sh
    mov            rdi,                sh
    jmp            .err
.sh:

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

; -- void performReq(int fd, const char *msg) ---------------------------------
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
performReq:
    push           rbp
    mov            rbp,                rsp

    ; Local variables.
    len            equ                 24
    sub            rsp,                32

    mov            [rbp - fd],         rdi
    mov            [rbp - msg],        rsi

    ; Get message length.
    mov            rdi,                [rbp - msg]
    call           slength 

    mov            [rbp - len],        rax

    cmp            rax,                0
    jle            .end

    ; Write outcoming message length.
    mov            rdx,                8
    lea            rsi,                [rbp - len]
    mov            rdi,                [rbp - fd]
    call           writeAll

    cmp            rax,                0
    jz             .wl
    mov            rdi,                wl
    jmp            .err
.wl:

    ; Write outcoming message.
    mov            rdx,                [rbp - len]
    mov            rsi,                [rbp - msg]
    mov            rdi,                [rbp - fd]
    call           writeAll

    cmp            rax,                0
    jz             .wm
    mov            rdi,                wm
    jmp            .err
.wm:

    ; Read incoming message length.
    mov            rdx,                8
    lea            rsi,                [rbp - len]
    mov            rdi,                [rbp - fd]
    call           readAll

    cmp            rax,                0
    jz             .rl
    mov            rdi,                rl
    jmp            .err
.rl:

    ; Read incoming message.
    mov            rdx,                [rbp - len]
    mov            rsi,                buf
    mov            rdi,                [rbp - fd]
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
  
    jmp            .end

.err:
    call           error

.end:
    leave
    ret

