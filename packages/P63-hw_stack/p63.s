# P63 program: RPN calculator on the hardware stack
# Rules: start at the label p63_main and finish with ret; every label you
# create starts with p63_ ; save ra (and any s registers you use) on the stack.
# You may call the library routines in sw/lib/rcv_lib.s (rcv_puts, rcv_getc, ...).

        .text
        .globl  p63_main
p63_main:
        addi    sp, sp, -16
        sw      ra, 12(sp)
        sw      s0, 8(sp)
        sw      s1, 4(sp)
        sw      s2, 0(sp)

        li      s0, HWSTACK_BASE

        # Step 1: Empty the hardware stack (POP while HWSTACK_COUNT > 0)
p63_clear_loop:
        lw      t0, 12(s0)              # HWSTACK_COUNT
        beqz    t0, p63_clear_done
        lw      t1, 4(s0)               # HWSTACK_POP
        j       p63_clear_loop
p63_clear_done:
        sw      zero, 16(s0)            # write HWSTACK_STATUS to clear overflow/underflow

        # Step 2: Read one line character by character with rcv_getc
p63_char_loop:
        call    rcv_getc
        li      t0, 10                  # '\n'
        beq     a0, t0, p63_end_expr
        li      t0, 13                  # '\r'
        beq     a0, t0, p63_end_expr
        beqz    a0, p63_end_expr        # EOF / null

        li      t0, 32                  # ' '
        beq     a0, t0, p63_char_loop
        li      t0, 9                   # '\t'
        beq     a0, t0, p63_char_loop

        # Digit 0..9
        li      t0, 48                  # '0'
        blt     a0, t0, p63_check_op
        li      t1, 57                  # '9'
        bgt     a0, t1, p63_check_op

        sub     t2, a0, t0              # digit value
        sw      t2, 0(s0)               # HWSTACK_PUSH
        j       p63_char_loop

p63_check_op:
        li      t0, 43                  # '+'
        beq     a0, t0, p63_do_add
        li      t0, 45                  # '-'
        beq     a0, t0, p63_do_sub
        li      t0, 42                  # '*'
        beq     a0, t0, p63_do_mul

        # Unrecognized character
        j       p63_error

p63_do_add:
        lw      t1, 4(s0)               # right operand
        lw      t2, 4(s0)               # left operand
        add     t3, t2, t1
        sw      t3, 0(s0)               # push result
        j       p63_char_loop

p63_do_sub:
        lw      t1, 4(s0)               # right operand
        lw      t2, 4(s0)               # left operand
        sub     t3, t2, t1
        sw      t3, 0(s0)               # push result
        j       p63_char_loop

p63_do_mul:
        lw      s1, 4(s0)               # right operand
        lw      s2, 4(s0)               # left operand
        mv      a0, s2
        mv      a1, s1
        call    rcv_umul                # a0 = left * right
        sw      a0, 0(s0)               # push result
        j       p63_char_loop

p63_end_expr:
        # Check STATUS: bit 2 overflow, bit 3 underflow
        lw      t0, 16(s0)              # HWSTACK_STATUS
        andi    t1, t0, 12              # bits 2 & 3
        bnez    t1, p63_error

        # Check COUNT == 1
        lw      t0, 12(s0)              # HWSTACK_COUNT
        li      t1, 1
        bne     t0, t1, p63_error

        # Success: pop result and print
        lw      s1, 4(s0)               # HWSTACK_POP
        la      a0, p63_str_result
        call    rcv_puts
        mv      a0, s1
        call    rcv_print_dec
        call    rcv_newline
        j       p63_exit

p63_error:
        la      a0, p63_str_error
        call    rcv_puts

p63_exit:
        lw      s2, 0(sp)
        lw      s1, 4(sp)
        lw      s0, 8(sp)
        lw      ra, 12(sp)
        addi    sp, sp, 16
        ret

        .rodata
p63_str_result:
        .asciz  "result = "
p63_str_error:
        .asciz  "stack error\n"
        .align  2
