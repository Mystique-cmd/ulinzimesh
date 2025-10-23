.global _start
.section .data
json1:  .ascii "{\"hostname\":\""
json2:  .ascii "\", \"platform\":\"linux\",\"event\":\"asm_probe\",\"pid\":"
pidbuf: .space 16
json3:  .ascii "}\n"

hostbuf: .space 64

.section .text
_start:
    #gethostname
    mov $170, %rax
    mov $hostbuf, %rdi
    mov $64, %rsi
    syscall

    #write part 1
    mov $1, %rax         #sys_write
    mov $1, %rdi        #fd 1 = stdout
    mov $json1, %rsi
    mov $14, %rdx       #length of json1
    syscall

    #write hostname (null terminated)
    mov $1, %rax
    mov $1, %rdi
    mov $hostbuf, %rsi
    mov $64, %rdx
    syscall

    #write part 2
    mov $1, %rax
    mov $1, %rdi

    lea json2(%rip), %rsi
    lea pidbuf(%rip), %rax
    sub %rsi, %rax
    mov %rax, %rdx      #the length can be fixed at runtime
    syscall

    #getpid
    mov $39, %rax
    syscall

    #convert PID to ascii
    mov %rax, %rbx
    mov $pidbuf+15, %rdi
    mov $0, %rcx
pidloop:
    mov $0, %rdx
    mov $10, %rax
    div %rbx
    add $'0', %dl
    dec %rdi
    mov %dl, (%rdi)
    test %rax, %rax
    jnz pidloop

    #write pid
    mov $1, %rax
    mov $1, %rdi
    mov %rdi, %rsi
    mov $(pidbuf+16 - pidbuf), %rdx
    syscall

    #write part 3
    mov $1, %rax
    mov $1, %rdi
    mov $json3, %rsi
    mov $3, %rdx
    syscall

    #exit 
    mov $60, %rax
    xor %rdi, %rdi
    syscall
