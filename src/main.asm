; Terminal maze for Linux x86-64. NASM Intel syntax, Linux syscalls only.
; No libc, heap allocation, terminal-mode changes or external game engine.
bits 64
default rel

%define SYS_READ 0
%define SYS_WRITE 1
%define SYS_EXIT 60
%define WIDTH 21
%define HEIGHT 11
%define STRIDE (WIDTH + 1)
%define START (STRIDE + 1)

section .rodata
    title db 10, '=== ASSEMBLY MAZE ===', 10
          db 'Reach S.  @ = you, # = wall.', 10
          db 'Z: up | Q: left | S: down | D: right | R: restart | X: quit', 10
          db 'Type one command, then press Enter. Uppercase also works.', 10
    title_len equ $ - title
    maze db '#####################', 10
         db '#     #       #    S#', 10
         db '# ### # ##### # ### #', 10
         db '#   #   #   #   #   #', 10
         db '### ##### # ##### # #', 10
         db '#   #     #       # #', 10
         db '# ### ########### # #', 10
         db '#     #       #   # #', 10
         db '# ##### ##### # ### #', 10
         db '#       #           #', 10
         db '#####################', 10
    maze_len equ $ - maze
    moves_label db 'Moves: '
    moves_label_len equ $ - moves_label
    prompt db '> '
    prompt_len equ $ - prompt
    wall_message db 'Blocked by a wall. No move counted.', 10
    wall_message_len equ $ - wall_message
    invalid_message db 'Use one of Z, Q, S, D, R or X, then Enter.', 10
    invalid_message_len equ $ - invalid_message
    restart_message db 'New game.', 10
    restart_message_len equ $ - restart_message
    win_message db 'You escaped! Final moves: '
    win_message_len equ $ - win_message
    win_prompt db 'R: play again | X: quit', 10
    win_prompt_len equ $ - win_prompt
    goodbye db 'Thanks for playing!', 10
    goodbye_len equ $ - goodbye
    newline db 10

section .bss
    board resb maze_len
    player resq 1
    moves resq 1
    won resb 1
    input_byte resb 1
    number_buffer resb 20       ; Enough for any unsigned 64-bit decimal integer.

section .text
global _start

; Print a constant without relying on null terminators.
%macro PRINT 1
    lea rsi, [rel %1]
    mov edx, %1_len
    call write_stdout
%endmacro

_start:
    PRINT title
    call reset_game

game_loop:
    call render
command_loop:
    PRINT prompt
    call read_command
    cmp eax, -1                ; Clean EOF behaves like quitting.
    je quit
    cmp al, 'x'
    je quit
    cmp al, 'r'
    je restart
    cmp byte [won], 0
    jne finished_command

    mov rax, [player]
    cmp r8b, 'z'
    je move_up
    cmp r8b, 's'
    je move_down
    cmp r8b, 'q'
    je move_left
    cmp r8b, 'd'
    je move_right
    PRINT invalid_message
    jmp command_loop

move_up:
    sub rax, STRIDE
    jmp try_move
move_down:
    add rax, STRIDE
    jmp try_move
move_left:
    dec rax
    jmp try_move
move_right:
    inc rax

try_move:
    ; Unsigned comparison also rejects negative offsets after subtraction.
    cmp rax, maze_len
    jae blocked
    lea rdx, [rel maze]
    movzx ecx, byte [rdx + rax]
    cmp cl, '#'
    je blocked
    cmp cl, 10                 ; Never walk into a row separator.
    je blocked
    mov [player], rax
    inc qword [moves]
    cmp cl, 'S'
    jne game_loop
    mov byte [won], 1
    jmp game_loop

blocked:
    PRINT wall_message
    jmp command_loop

finished_command:
    PRINT win_prompt
    jmp command_loop

restart:
    call reset_game
    PRINT restart_message
    jmp game_loop

quit:
    PRINT goodbye
    xor edi, edi
    jmp exit_process

; Game state lives in explicit variables so helpers do not depend on registers.
reset_game:
    mov qword [player], START
    mov qword [moves], 0
    mov byte [won], 0
    ret

render:
    cld
    lea rsi, [rel maze]
    lea rdi, [rel board]
    mov ecx, maze_len
    rep movsb
    lea rsi, [rel board]
    mov rax, [player]
    mov byte [rsi + rax], '@'
    mov edx, maze_len
    call write_stdout
    PRINT moves_label
    mov rax, [moves]
    call print_unsigned
    cmp byte [won], 0
    je .done
    PRINT win_message
    mov rax, [moves]
    call print_unsigned
    PRINT win_prompt
.done:
    ret

; rax -> decimal output plus newline. Division produces digits in reverse order.
print_unsigned:
    lea rsi, [rel number_buffer + 20]
    xor ecx, ecx
    mov r9d, 10
.digit:
    xor edx, edx
    div r9
    add dl, '0'
    dec rsi
    mov [rsi], dl
    inc ecx
    test rax, rax
    jnz .digit
    mov edx, ecx
    call write_stdout
    lea rsi, [rel newline]
    mov edx, 1
    jmp write_stdout

; Read a whole line without a growing buffer. Return eax/r8d = command, 0 if
; invalid, or -1 at EOF. CR is accepted for CRLF input. Long lines are drained
; and rejected, never executed as a series of hidden commands.
read_command:
    xor r8d, r8d
    xor r9d, r9d               ; Saturating length: 0, 1, or 2 (invalid).
.read:
    xor eax, eax
    xor edi, edi
    lea rsi, [rel input_byte]
    mov edx, 1
    syscall
    cmp rax, -4                ; EINTR: retry an interrupted read.
    je .read
    test rax, rax
    js io_error
    jz .eof
    movzx eax, byte [input_byte]
    cmp al, 10
    je .line
    cmp al, 13
    je .read
    test r9d, r9d
    jnz .extra
    mov r8d, eax
    mov r9d, 1
    jmp .read
.extra:
    mov r9d, 2
    jmp .read
.eof:
    test r9d, r9d
    jnz .line
    mov eax, -1
    ret
.line:
    cmp r9d, 1
    jne .invalid
    cmp r8b, 'A'
    jb .ready
    cmp r8b, 'Z'
    ja .ready
    add r8b, 'a' - 'A'
.ready:
    mov eax, r8d
    ret
.invalid:
    xor r8d, r8d
    xor eax, eax
    ret

; Write all rdx bytes at rsi, handling partial writes and EINTR. Caller-saved
; registers may change. Linux syscall always clobbers rcx and r11.
write_stdout:
    test rdx, rdx
    jz .done
.write:
    mov eax, SYS_WRITE
    mov edi, 1
    syscall
    cmp rax, -4
    je .write
    test rax, rax
    jle io_error
    add rsi, rax
    sub rdx, rax
    jnz .write
.done:
    ret

io_error:
    mov edi, 1
exit_process:
    mov eax, SYS_EXIT
    syscall
