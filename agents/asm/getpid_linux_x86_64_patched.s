
.equ SYS_write, 1
.equ SYS_getpid, 39
.equ SYS_exit, 60
.equ SYS_gethostname, 170

.global _start


.section .data
    json1:      .ascii "{\"hostname\":\""
    len1:       .int . - json1

    json2:      .ascii "\", \"platform\":\"linux\",\"event\":\"asm_probe\",\"pid\":"
    len2:       .int . - json2

    json3:      .ascii "}\n"
    len3:       .int . - json3

    hostbuf:    .space 64
    hostlen:    .space 8

    pidbuf:     .space 20  # suficiente para un pid de 64 bits
    pidlen:     .int 0

.section .text
_start:
    # gethostname
    mov $SYS_gethostname, %rax
    lea hostbuf(%rip), %rdi
    mov $64, %rsi
    syscall

    # strlen del hostname
    lea hostbuf(%rip), %rdi
    call strlen

    mov %rax, hostlen(%rip)

    # write json1
    mov $SYS_write, %rax
    mov $1, %rdi
    lea json1(%rip), %rsi
    mov len1(%rip), %edx
    syscall

    # write hostname
    mov $SYS_write, %rax
    mov $1, %rdi
    lea hostbuf(%rip), %rsi
    mov hostlen(%rip), %rdx
    syscall

    # write json2
    mov $SYS_write, %rax
    mov $1, %rdi
    lea json2(%rip), %rsi
    mov len2(%rip), %edx
    syscall

    # getpid
    mov $SYS_getpid, %rax
    syscall

    # itoa(rax) -> pidbuf
    lea pidbuf(%rip), %rdi
    call itoa
    mov %rax, pidlen(%rip)

    # write pid
    mov $SYS_write, %rax
    mov $1, %rdi
    lea pidbuf(%rip), %rsi
    mov pidlen(%rip), %rdx
    syscall

    # write json3
    mov $SYS_write, %rax
    mov $1, %rdi
    lea json3(%rip), %rsi
    mov len3(%rip), %edx
    syscall

    # exit
    mov $SYS_exit, %rax
    xor %rdi, %rdi
    syscall

# -----------------
# Funciones auxiliares
# -----------------

# strlen:
#   Entrada:
#     - rdi: puntero a la cadena
#   Salida:
#     - rax: longitud de la cadena
strlen:
    xor %rax, %rax
    jmp strlen_loop
strlen_loop:
    cmpb $0, (%rdi, %rax, 1)
    je strlen_end
    inc %rax
    jmp strlen_loop
strlen_end:
    ret

# itoa:
#   Entrada:
#     - rax: número a convertir
#     - rdi: puntero al buffer de salida
#   Salida:
#     - rax: longitud de la cadena
itoa:
    mov $10, %rcx
    xor %rdx, %rdx
    mov $0, %rbx
    jmp itoa_loop
itoa_loop:
    div %rcx
    push %rdx
    inc %rbx
    test %rax, %rax
    jnz itoa_loop

    mov %rbx, %rax
    mov %rdi, %rdi
    jmp itoa_unloop
itoa_unloop:
    pop %rdx
    add $'0', %dl
    mov %dl, (%rdi)
    inc %rdi
    dec %rbx
    jnz itoa_unloop
    ret
