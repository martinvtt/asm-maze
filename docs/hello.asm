; Lesson 1: write a message, then exit. Linux x86-64, NASM Intel syntax.
bits 64
default rel

section .data
    message db "Welcome to the maze!", 10
    message_length equ $ - message

section .text
global _start

_start:
    ; Linux write(fd, buffer, count): rax=1, rdi=fd, rsi=buffer, rdx=count.
    mov rax, 1                  ; System call number for write.
    mov rdi, 1                  ; File descriptor 1 is standard output.
    lea rsi, [rel message]      ; Address of the first byte of the message.
    mov rdx, message_length     ; Number of bytes, including the newline.
    syscall

    ; Linux exit(status): rax=60, rdi=status.
    mov rax, 60
    xor rdi, rdi               ; Set the exit status to zero (success).
    syscall
