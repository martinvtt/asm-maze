# Assembly Maze

A playable terminal maze written entirely in x86-64 assembly, using NASM Intel
syntax and Linux system calls. No C library, game engine or runtime dependencies.

## Run

On Ubuntu / WSL running on an x86-64 computer:

```bash
sudo apt install nasm binutils make gdb
cd ~/other/asm-maze
make run
```

Reach `S` with the player `@`. Walls are marked `#`.

| Command | Action |
| --- | --- |
| Z | Up |
| Q | Left |
| S | Down |
| D | Right |
| R | Restart, including after winning |
| X | Quit |

**Type one command and press Enter.** Lowercase and uppercase both work. The game
uses normal terminal input rather than raw mode, so it does not change terminal
settings. Ctrl+D on an empty input line also quits. Ctrl+C interrupts normally.
Each successful move increments the counter; walls and invalid commands do not.
After victory, use R to replay or X to leave.

## Features

- One fixed, solvable 21-by-11 maze.
- Bounds and wall checks, player rendering and victory detection.
- Decimal move counter, restart and replay.
- Bounded input storage; multi-character lines are rejected as a whole.
- EOF handling, interrupted syscall retries and partial-write handling.
- Debug symbols and a non-executable stack.

The board is printed again after each move. No ANSI screen clearing is used, so
the game also works with redirected input/output. This is a Linux ELF executable;
run it in Ubuntu/WSL, not directly in Windows Explorer.

## Development

```bash
make           # Assemble and link into build/maze.
make debug     # Start GDB at the first instruction, with Intel disassembly.
make test      # Requires Python 3, only for the tests.
make clean     # Remove generated files.
```

Tests run the real executable: movement, collisions, invalid/long input, EOF,
restart, input errors, and two complete games. A breadth-first search derives
a winning route from the rendered maze and checks the final move count.

`src/main.asm` contains the full game. Labels separate input, rendering, movement,
number formatting and syscall handling. `docs/hello.asm` preserves the original
starter program; `docs/01-first-program.md` is its introductory lesson, not the
current game implementation. Code, comments and documentation are in English.

No API key, network access or AI subscription is needed to run the game.
