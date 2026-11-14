# P63 Hardware stack - dossier

## U1 Digital logic
My stack keeps a count of how many items it holds (0 to 4) in three flip-flops C2 C1 C0.
Two flags come from the count:

| Count | C2 | C1 | C0 | empty | full |
|:-----:|:--:|:--:|:--:|:-----:|:----:|
|   0   | 0  | 0  | 0  |   1   |  0   |
|   1   | 0  | 0  | 1  |   0   |  0   |
|   2   | 0  | 1  | 0  |   0   |  0   |
|   3   | 0  | 1  | 1  |   0   |  0   |
|   4   | 1  | 0  | 0  |   0   |  1   |

The count never goes above 4, so C2 = 1 only when the stack is full. That makes
the expressions short:
- full = C2
- empty = NOR(C0 + C1, C2) = /C0 . /C1 . /C2

When the clock ticks, the count changes like this:
- push_ok = push . /pop . /full (a push is only allowed when not full; push and pop at the same time do nothing)
- pop_ok = pop . /push . /empty
- C0 next = C0 xor (push_ok + pop_ok)
- C1 next = C1 xor (push_ok . C0 + pop_ok . /C0)
- C2 next = C2 xor (push_ok . C1 . C0 + pop_ok . /C1 . /C0)
- every next value is ANDed with /rst, so reset clears the count

I used NOT, AND, OR, XOR and NOR gates, three 1-bit D flip-flops for the count
and four 4-bit D flip-flops for the stored values.

Note: the Digital circuit stores 4 entries to keep it small. The Verilog module
stores 8 entries (count 0 to 8). Push, pop, top, empty, full and reset behave the
same way; only the depth is different.

## U2 Digital components
- **Registers:** four 4-bit D flip-flops hold the four entries. Three 1-bit D flip-flops hold the count. All of them use the same clock.
- **Write select:** AND gates decode C1 C0 (00, 01, 10, 11) and AND that with push_ok. This gives one write signal per entry, so a push goes into the entry numbered by the current count.
- **Multiplexers:** in front of each entry there is a 4-bit 2-to-1 multiplexer. If the write signal is 1 it passes the new data d, otherwise it passes the old value back (so the entry holds its value).
- **Top output:** two multiplexers pick between pairs of entries using C0, a third picks between those two using C1, and a last one outputs 0 when the stack is empty. The entry on top is the one with number count - 1.
- **Splitter:** it joins the three count bits into the 3-bit count output.

## U3 Data representation
1. **Push 7 on an empty stack.** Input d = 0111 (hex 7, decimal 7). Result: top = 0111, count = 001, empty = 0, full = 0. The value is 7 both as signed and unsigned.
2. **Push 15.** Input d = 1111 (hex F). As unsigned it is 15, as 4-bit signed two's complement it is -1. After the push, top = 1111 and count = 010 (2). If this 4-bit value were copied into a 32-bit register, zero extension gives 0x0000000F and sign extension gives 0xFFFFFFFF, so the choice matters. My circuit just passes the bits and does not extend them.
3. **Push 9 when the stack is full.** The count is 100 (4) and d = 1001 (hex 9). Nothing is stored. top stays the old value (12 in the test), count stays 100 and full = 1. Here overflow could go wrong: if the push were not blocked it would overwrite an entry, and a count with only 2 bits would wrap around to 0. That is why my count has 3 bits. In the Verilog module the same push also sets a sticky overflow bit in the status register.

## U4 Computer organisation
My block works in the **memory step**. During fetch, decode and execute the CPU only
works out the address of the stack's registers (slot 21, base 0x00020540). In the
memory step the address decoder selects my block and it reads or writes.

The instructions that use it are:
- `sw` (store word): writes to offset 0 to push a value, or to offset 16 to clear the overflow and underflow flags.
- `lw` (load word): reads offset 4 to pop, offset 8 to look at the top, offset 12 for the count, offset 16 for the status.

For a `lw`, the write-back step then copies the value that was read into the register rd.

## U5 Processors
- **RISC-V (this project):** it is load/store and has no push or pop instruction. It uses normal `lw` and `sw` to talk to my block, which is a memory-mapped peripheral.
- **Stack machine (JVM, Forth):** it has no general registers. An instruction like ADD takes the two top items from the stack, adds them and pushes the result.
- **CISC (x86, Mano's computer):** it has PUSH and POP as single instructions that also update a stack pointer and use memory.
- **GPU:** it runs thousands of threads, so a hardware stack for each thread would take too much area. It keeps stacks in memory and uses only small ones for branches.

## U6 Memory and I/O
My stack is an I/O peripheral reached by memory-mapped I/O.
1. The CPU does a `lw` or `sw`. The address decoder checks the address and, if it is in slot 21 (0x00020540), it selects my block.
2. The low address bits choose the register (offset 0 push, 4 pop, 8 top, 12 count, 16 status).
3. For a store, `we` is 1 and my block takes `wdata` and pushes it.
4. For a load, my block puts the data on `rdata`. The read multiplexers send it back to the register file.

## E1 Instruction trace: SLLI
I traced `slli a0, a1, 2` which is machine code `0x00259513`
(imm = 2, rs1 = x11, funct3 = 001, rd = x10, opcode = 0010011). Say x11 = 7.
1. **Program counter / PC adder:** pc = 0x00000000 goes to the instruction memory, and pc + 4 = 0x00000004 is prepared.
2. **Instruction memory:** returns 0x00259513.
3. **Field splitter / decoder:** rd = 10 (a0), rs1 = 11 (a1), immediate = 2, opcode = OP-IMM.
4. **Control unit:** regwrite = 1, ALU second input = immediate, no memory read or write.
5. **Immediate generator:** gives 0x00000002.
6. **Register file read:** x11 = 0x00000007.
7. **ALU input select:** A = 7, B = 2.
8. **Shifter / ALU:** 7 << 2 = 28 = 0x0000001C.
9. **Memory step:** not used.
10. **Write-back:** the shift result 0x0000001C is written into x10.
11. **Next PC:** pc becomes 0x00000004.

## E2 Neighbour review
- P62 (Interrupt latency meter): TODO - link to my review comment
- P64 (Code converter (Gray, excess-3)): TODO - link to my review comment

## E3 Where my block sits
My block is in the **I/O layer**, peripheral slot 21 at 0x00020540. The address decoder
selects it, the bus control gives it the read and write signals, and the store unit
gives it the data to push. Its output `rdata` goes through the read multiplexers
back to the register file.

## E4 Syllabus map
- [x] Logic gates, Boolean algebra, K-maps
- [x] Combinational circuits (adders, decoders, encoders, multiplexers)
- [x] Flip-flops, registers, counters
- [x] Memory (RAM, ROM)
- [x] Number systems, complements, signed arithmetic
- [x] Bus organisation, instruction codes and formats
- [x] Instruction cycle, hardwired vs microprogrammed control
- [ ] Interrupts and the interrupt cycle
- [ ] Pipelining
- [x] Register organisation, stack, addressing modes
- [x] RISC vs CISC, multicore, GPU
- [ ] Memory hierarchy, cache
- [x] I/O interface, programmed / interrupt-driven I/O, DMA
