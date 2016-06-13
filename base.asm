    section        .text
    global         slength
    global         error
    global         toInt
    global         strToIP
    global         fillAddr
    global         writeAll
    global         readAll

; ---- Get string length ------------------------------------------------------
;
slength:
    push           rbp
    mov            rbp,                rsp
  
    mov            rax,                0
    mov            rcx,                rdi
.loop:
    cmp            byte[rcx],          0
    jz             .end
    inc            rax
    inc            rcx
    jmp            .loop

.end:
    leave
    ret

; ---- Printt string to stderr ------------------------------------------------
;
error:
    push           rbp
    mov            rbp,                rsp
 
    call           slength

    mov            rdx,                rax
    mov            rsi,                rdi
    mov            rdi,                2  
    mov            rax,                1
    syscall

    leave
    ret

; ---- int toInt(const char *str, int *res) ----------------------------------- 
;
toInt:
    push           r12
    push           rdx
    push           rcx
    push           rbx

    push           rbp
    mov            rbp,                rsp

    mov            rdx,                0
    mov            rcx,                rdi

    cmp            byte[rcx],          0
    je             .err  

.loop:
    cmp            byte[rcx],          0
    je             .suc

    cmp            byte[rcx],          48
    jl             .err

    cmp            byte[rcx],          57
    jg             .err

    mov            bl,                 byte[rcx] 
    sub            rbx,                48

    imul           rdx,                10  
    add            rdx,                rbx    

    inc            rcx
    jmp            .loop 

.suc:
    mov            [rsi],              rdx 
    mov            rax,                0
    jmp            .end

.err:
    mov            rax,                -1

.end:
    leave

    pop            rbx
    pop            rcx
    pop            rdx 
    pop            r12 

    ret

; ---- int toIntBy(const char *str, char e, int *res, char **nstr) ------------ 
;
toIntBy:
    push           r14
    push           r13
    push           r12
    push           rbx

    push           rbp
    mov            rbp,                rsp

    mov            r12,                0
    mov            r13,                rdi

    cmp            byte[r13],          0
    je             .err
    cmp            byte[r13],          sil
    je             .err

.loop:
    cmp            byte[r13],          0
    je             .end
    cmp            byte[r13],          sil
    je             .nxt
    cmp            byte[r13],          48
    jl             .err
    cmp            byte[r13],          57
    jg             .err

    xor            rbx,                rbx
    mov            bl,                 byte[r13] 
    sub            bl,                 48

    imul           r12,                10  
    add            r12,                rbx    

    inc            r13

    jmp            .loop

.nxt:
    mov            rax,                1
    inc            r13
    mov            [rdx],              r12
    mov            [rcx],              r13
    jmp            .ret

.end:
    mov            rax,                0
    mov            [rdx],              r12
    jmp            .ret

.err:
    mov            rax,               -1

.ret:
    leave

    pop            rbx
    pop            r12
    pop            r13 
    pop            r14 

    ret

; ---- int strToIP(const char *str, int *res) ---------------------------------
;
strToIP:
    push           rcx
    push           rbx

    push           rbp
    mov            rbp,                rsp

    ; Local variables.
    b1             equ                 32
    b2             equ                 24
    b3             equ                 16
    b4             equ                 8 
    str1           equ                 48
    str2           equ                 40
    resp           equ                 64
    sub            rsp,                64

    mov            [rbp - str1],       rdi
    mov            [rbp - resp],       rsi

    lea            rcx,                [rbp - str2]
    lea            rdx,                [rbp - b1]
    mov            rsi,                46
    mov            rdi,                [rbp - str1]
    call           toIntBy   

    cmp            rax,                1
    jne            .err

    lea            rcx,                [rbp - str1]
    lea            rdx,                [rbp - b2]
    mov            rsi,                46
    mov            rdi,                [rbp - str2]
    call           toIntBy   

    cmp            rax,                1
    jne            .err

    lea            rcx,                [rbp - str2]
    lea            rdx,                [rbp - b3]
    mov            rsi,                46
    mov            rdi,                [rbp - str1]
    call           toIntBy
 
    cmp            rax,                1
    jne            .err

    lea            rcx,                [rbp - str1]
    lea            rdx,                [rbp - b4]
    mov            rsi,                46
    mov            rdi,                [rbp - str2]
    call           toIntBy   

    cmp            rax,                0
    jne            .err

    mov            rdi,                [rbp - str1]
    mov            rsi,                [rbp - resp]

    mov            bl,                 [rbp - b1] 
    mov            bh,                 [rbp - b2] 
    mov            cl,                 [rbp - b3] 
    mov            ch,                 [rbp - b4] 

    mov            [rsi],              bl
    mov            [rsi + 1],          bh
    mov            [rsi + 2],          cl
    mov            [rsi + 3],          ch

.suc:
    mov            rax,                0
    jmp            .end

.err:
    mov            rax,                -1

.end:
    leave

    pop            rbx
    pop            rcx

    ret

; ---- int fillAddr(sockaddr_in *sa, const char *ip, const char *port) --------
;
fillAddr:
    push           rcx
    push           rbx

    push           rbp
    mov            rbp,                     rsp

    ; Local variables.
    sa             equ                      16
    ip             equ                      24 
    port           equ                      32
    p              equ                      40
    sub            rsp,                     48 

    mov            [rbp - sa],              rdi
    mov            [rbp - ip],              rsi
    mov            [rbp - port],            rdx

    ; struct sockaddr_in {
    ;     short           sin_family;
    ;     unsigned short  sin_port;
    ;     struct in_addr  sin_addr;
    ;     char            sin_zero[8];
    ; };

    ; Fill sin_family.
    mov            rcx,                     [rbp - sa] 
    mov            word[rcx],               2

    ; Fill sin_port.
    lea            rsi,                     [rbp - p]
    mov            rdi,                     [rbp - port]
    call           toInt

    cmp            rax,                     0
    jnz            .err

    mov            cx,                      [rbp - p]
    mov            bl,                      ch
    mov            bh,                      cl
    
    mov            rcx,                     [rbp - sa]
    mov            [rcx + 2],               bx
 
    ; Fill sin_addr.
    mov            rcx,                     [rbp - sa] 

    lea            rsi,                     [rcx + 4]
    mov            rdi,                     [rbp - ip]
    call           strToIP

    cmp            rax,                     0
    jnz            .err

    ; Fill sin_zero.
    xor            rbx,                     rbx
    mov            rcx,                     [rbp - sa] 
    mov            [rcx + 8],               rbx

    mov            rax,                     0
    jmp            .end

.err:
    mov            rax,                     -1

.end:
    leave

    pop            rbx
    pop            rcx

    ret

; ---- int writeAll(int fd, const void *a, size_t l) --------------------------
;
writeAll:
    push           rbp
    mov            rbp,                     rsp

    push           r14
    push           r13
    push           r12
    push           rcx

    mov            rcx,                     rsi ; a 
    mov            r12,                     rdx ; l
    mov            r13,                     rdi ; fd  

.loop:
    cmp            r12,                     0
    jz             .suc

    mov            rdx,                     r12 ; l
    mov            rsi,                     rcx ; a 
    mov            rdi,                     r13 ; fd
    mov            rax,                     1   ; sys_write
    syscall

    cmp            rax,                     0
    jle            .err

    add            rcx,                     rax
    sub            r12,                     rax 

    jmp            .loop

.suc:
    mov            rax,                     0  
    jmp            .end

.err:
    mov            rax,                     -1  

.end:
    pop            rcx
    pop            r12 
    pop            r13 
    pop            r14 

    leave
    ret

; ---- int readAll(int fd, void *a, size_t l) ---------------------------------
;
readAll:
    push           rbp
    mov            rbp,                     rsp

    push           r14
    push           r13
    push           r12
    push           rcx

    mov            rcx,                     rsi ; a 
    mov            r12,                     rdx ; l
    mov            r13,                     rdi ; fd  

.loop:
    cmp            r12,                     0
    jz             .suc

    mov            rdx,                     r12 ; l
    mov            rsi,                     rcx ; a 
    mov            rdi,                     r13 ; fd
    mov            rax,                     0   ; sys_read
    syscall

    cmp            rax,                     0
    jle            .err

    add            rcx,                     rax
    sub            r12,                     rax 

    jmp            .loop

.suc:
    mov            rax,                     0  
    jmp            .end

.err:
    mov            rax,                     -1  

.end:
    pop            rcx
    pop            r12 
    pop            r13 
    pop            r14 

    leave
    ret

