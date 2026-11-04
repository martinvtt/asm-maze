# Lesson 1: understand every instruction

Historical starter lesson: the game now lives in `src/main.asm`. To try this
original example separately, run:

```bash
mkdir -p build
nasm -f elf64 -g -F dwarf docs/hello.asm -o build/hello.o
ld -z noexecstack build/hello.o -o build/hello
./build/hello
gdb -q -ex "set disassembly-flavor intel" -ex starti ./build/hello
```

The `make` commands below refer to the original starter workflow. For this
archived example, use the commands above instead.

The goal is to explain the program and make three small changes yourself before
adding the maze. Read `docs/hello.asm` next to this guide.

## Data and addresses

`section .data` holds initialized data. `db` defines bytes. The number `10` is the
newline byte. There is no zero terminator: Linux `write` uses a byte count.

`message` is a label identifying an address. `message_length equ $ - message`
computes the number of bytes at assembly time: `$` is the current position, after
the message. No CPU instruction is executed for `equ`.

`lea rsi, [rel message]` puts the message's address into `rsi`. It does not load
the text itself into the register. Relative addressing uses the instruction
pointer as a reference; we will return to addressing modes in later lessons.

## Ask Linux to write

`section .text` contains instructions. `_start` is where this executable begins;
it is not a C `main` function. `global _start` makes the symbol visible to the
linker. `mov destination, source` copies a value into its destination.

For the Linux x86-64 `write` system call:

| Register | Value here | Meaning |
| --- | --- | --- |
| `rax` | `1` | System call number: write |
| `rdi` | `1` | Output file descriptor: standard output |
| `rsi` | Address of `message` | Where the bytes begin |
| `rdx` | `message_length` | How many bytes to request |

`syscall` enters the operating system. On return, `rax` holds the result: normally
the number of bytes written, or a negative error code. It also clobbers `rcx` and
`r11`. This first program assumes a successful short terminal write; handling
errors and partial writes is a later improvement.

The register mapping above is a Linux **system call** convention. It is not the
same as the convention for calling ordinary functions, which we will learn later.

## Exit

For Linux x86-64, `rax = 60` selects `exit` and `rdi` contains the status.
`xor rdi, rdi` sets `rdi` to zero because a value XOR itself is zero. Zero normally
means success. The final `syscall` does not return.

## Inspect with GDB

```bash
make debug
```

GDB stops before the first instruction. Enter these commands one at a time:

```text
x/8i $rip
si
info registers rax rdi rsi rdx rip
```

`si` executes one machine instruction. Repeat it through the first four `mov` /
`lea` instructions. Once `rsi` contains the message address, inspect exactly the
21 bytes in the original message (including the newline):

```text
x/21cb $rsi
```

Execute the first `syscall` with `si`, then inspect `rax` again: did Linux write
the requested number of bytes? Use `continue` to finish, then `quit`.
If you changed the message, adjust the count in `x/21cb` accordingly. Do not use
`x/s` here: our message has no zero terminator.

NASM may encode a small constant assignment to `rax` as `mov eax, ...` (similarly
for `edi` and `edx`). Writing a 32-bit register clears the upper 32 bits of its
64-bit register, so these positive constants still give the intended result.
This explains why GDB's disassembly can look slightly different from the source.

## Your three exercises

1. Replace the greeting with your own message. Rebuild. Why does its length stay
   correct without editing a number manually?
2. Add a second line inside the same `message` byte sequence. Include newline
   bytes and keep the single `write` call.
3. Replace `xor rdi, rdi` with an instruction that sets the exit status to `7`.
   Run `./build/maze`, then immediately `echo $?`. Restore status zero afterward.

Before the next lesson, explain the difference between the address in `rsi`,
the count in `rdx`, and the syscall number in `rax`. Next we will replace the
greeting with a fixed maze and locate the player in its byte array.
