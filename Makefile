NASM ?= nasm
LD ?= ld
GDB ?= gdb

.PHONY: all run debug test clean

all: build/maze

build:
	mkdir -p build

build/main.o: src/main.asm | build
	$(NASM) -f elf64 -g -F dwarf -o $@ $<

build/maze: build/main.o
	$(LD) -m elf_x86_64 -z noexecstack -o $@ $<

run: build/maze
	./build/maze

debug: build/maze
	$(GDB) -q -ex "set disassembly-flavor intel" -ex starti ./build/maze

test: build/maze
	python3 -m unittest discover -s tests -v

clean:
	rm -rf build
