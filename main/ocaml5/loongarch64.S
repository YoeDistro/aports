/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                    yala <zhaojunchao@loongson.cn>                      */
/*                                                                        */
/*                   Copyright © 2008-2023 LOONGSON                       */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   $special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Asm part of the runtime system, LoongArch processor, 64-bit mode */
/* Must be preprocessed by cpp */

#include "caml/m.h"

#define DOMAIN_STATE_PTR $s8
#define TRAP_PTR $s1
#define ALLOC_PTR $s7
#define ADDITIONAL_ARG $t2
#define STACK_ARG_BEGIN $s3
#define STACK_ARG_END $s4
#define TMP $t0
#define TMP2 $t1

#define C_ARG_1 $a0
#define C_ARG_2 $a1
#define C_ARG_3 $a2
#define C_ARG_4 $a3

        .set    domain_curr_field, 0
        .set    domain_curr_cnt, 0
#define DOMAIN_STATE(c_type, name) \
        .equ    domain_field_caml_##name, domain_curr_field ; \
        .set    domain_curr_cnt, domain_curr_cnt + 1;    \
        .set    domain_curr_field, domain_curr_cnt*8
#include "../runtime/caml/domain_state.tbl"
#undef DOMAIN_STATE

#define Caml_state(var) DOMAIN_STATE_PTR, domain_field_caml_##var

/* Globals and labels */
#define L(lbl) .L##lbl

#define FUNCTION(name) \
        .align 2; \
        .globl name; \
        .type  name, @function; \
name:; \
        CFI_STARTPROC

#define END_FUNCTION(name) \
        CFI_ENDPROC; \
        .size name, .-name

#if defined(__PIC__)
#define PLT(r) %plt(r)
#else
#define PLT(r) r
#endif

#define OBJECT(name) \
        .data; \
        .align  3; \
        .globl  name; \
        .type   name, @object; \
name:
#define END_OBJECT(name) \
        .size   name, .-name

#undef ASM_CFI_SUPPORTED
#define CFI_STARTPROC
#define CFI_ENDPROC
#define CFI_ADJUST(n)
#define CFI_REGISTER(r1,r2)
#define CFI_OFFSET(r,n)
#define CFI_DEF_CFA_REGISTER(r)
#define CFI_REMEMBER_STATE
#define CFI_RESTORE_STATE

/* Stack switching operations */

/* struct stack_info */
#define Stack_sp(reg)           reg, 0
#define Stack_exception(reg)    reg, 8
#define Stack_handler(reg)      reg, 16
#define Stack_handler_from_cont(reg) reg, 15

/* struct c_stack_link */
#define Cstack_stack(reg)       reg, 0
#define Cstack_sp(reg)          reg, 8
#define Cstack_prev(reg)        reg, 16

/* struct stack_handler */
#define Handler_value(reg)      reg, 0
#define Handler_exception(reg)  reg, 8
#define Handler_effect(reg)     reg, 16
#define Handler_parent(reg)     reg, 24

/* Switch from OCaml to C stack. */
.macro SWITCH_OCAML_TO_C
    /* Fill in Caml_state->current_stack->$sp */
        ld.d      TMP, Caml_state(current_stack)
        st.d      $sp, Stack_sp(TMP)
    /* Fill in Caml_state->c_stack */
        ld.d      TMP2, Caml_state(c_stack)
        st.d      TMP, Cstack_stack(TMP2)
        st.d      $sp, Cstack_sp(TMP2)
    /* Switch to C stack */
        move      $sp, TMP2
        CFI_REMEMBER_STATE
.endm

/* Switch from C to OCaml stack. */
.macro SWITCH_C_TO_OCAML
        ld.d      $sp, Cstack_sp($sp)
        CFI_RESTORE_STATE
.endm

/* Save all of the registers that may be in use to a free gc_regs bucket
   and store ALLOC_PTR and TRAP_PTR back to Caml_state
   At the end the saved registers are placed in Caml_state(gc_regs)
 */
.macro SAVE_ALL_REGS
    /* First, save the young_ptr & exn_handler */
        st.d      ALLOC_PTR, Caml_state(young_ptr)
        st.d      TRAP_PTR, Caml_state(exn_handler)
    /* Now, use TMP to point to the gc_regs bucket */
        ld.d      TMP, Caml_state(gc_regs_buckets)
        ld.d      TMP2, TMP, 0  /* next ptr */
        st.d      TMP2, Caml_state(gc_regs_buckets)
    /* Save allocatable integer registers Must be in
    the same order as proc.ml int_reg_name*/
        st.d      $a0, TMP, 2*8
        st.d      $a1, TMP, 3*8
        st.d      $a2, TMP, 4*8
        st.d      $a3, TMP, 5*8
        st.d      $a4, TMP, 6*8
        st.d      $a5, TMP, 7*8
        st.d      $a6, TMP, 8*8
        st.d      $a7, TMP, 9*8
        st.d      $s2, TMP, 10*8
        st.d      $s3, TMP, 11*8
        st.d      $s4, TMP, 12*8
        st.d      $s5, TMP, 13*8
        st.d      $s6, TMP, 14*8
        st.d      $t2, TMP, 15*8
        st.d      $t3, TMP, 16*8
        st.d      $t4, TMP, 17*8
        st.d      $t5, TMP, 18*8
        st.d      $t6, TMP, 19*8
        st.d      $t7, TMP, 20*8
        st.d      $t8, TMP, 21*8
        st.d      $s0, TMP, 22*8
    /* Save caller-save floating-point registers
       (callee-saves are preserved by C functions) */
        fst.d     $ft0, TMP, 23*8
        fst.d     $ft1, TMP, 24*8
        fst.d     $ft2, TMP, 25*8
        fst.d     $ft3, TMP, 26*8
        fst.d     $ft4, TMP, 27*8
        fst.d     $ft5, TMP, 28*8
        fst.d     $ft6, TMP, 29*8
        fst.d     $ft7, TMP, 30*8
        fst.d     $fa0, TMP, 31*8
        fst.d     $fa1, TMP, 32*8
        fst.d     $fa2, TMP, 33*8
        fst.d     $fa3, TMP, 34*8
        fst.d     $fa4, TMP, 35*8
        fst.d     $fa5, TMP, 36*8
        fst.d     $fa6, TMP, 37*8
        fst.d     $fa7, TMP, 38*8
        fst.d     $ft8, TMP, 39*8
        fst.d     $ft9, TMP, 40*8
        fst.d     $ft10, TMP, 41*8
        fst.d     $ft11, TMP, 42*8
        fst.d     $ft12, TMP, 43*8
        fst.d     $ft13, TMP, 44*8
        fst.d     $ft14, TMP, 45*8
        fst.d     $ft15, TMP, 46*8
        addi.d    TMP, TMP, 16
        st.d      TMP, Caml_state(gc_regs)
.endm

/* Undo SAVE_ALL_REGS by loading the registers saved in Caml_state(gc_regs)
   and refreshing ALLOC_PTR & TRAP_PTR from Caml_state */
.macro RESTORE_ALL_REGS
    /* Restore $a0, $a1, freeing up the next ptr slot */
        ld.d      TMP, Caml_state(gc_regs)
        addi.d    TMP, TMP, -16
    /* Restore registers */
        ld.d      $a0, TMP, 2*8
        ld.d      $a1, TMP, 3*8
        ld.d      $a2, TMP, 4*8
        ld.d      $a3, TMP, 5*8
        ld.d      $a4, TMP, 6*8
        ld.d      $a5, TMP, 7*8
        ld.d      $a6, TMP, 8*8
        ld.d      $a7, TMP, 9*8
        ld.d      $s2, TMP, 10*8
        ld.d      $s3, TMP, 11*8
        ld.d      $s4, TMP, 12*8
        ld.d      $s5, TMP, 13*8
        ld.d      $s6, TMP, 14*8
        ld.d      $t2, TMP, 15*8
        ld.d      $t3, TMP, 16*8
        ld.d      $t4, TMP, 17*8
        ld.d      $t5, TMP, 18*8
        ld.d      $t6, TMP, 19*8
        ld.d      $t7, TMP, 20*8
        ld.d      $t8, TMP, 21*8
        ld.d      $s0, TMP, 22*8
        fld.d     $ft0, TMP, 23*8
        fld.d     $ft1, TMP, 24*8
        fld.d     $ft2, TMP, 25*8
        fld.d     $ft3, TMP, 26*8
        fld.d     $ft4, TMP, 27*8
        fld.d     $ft5, TMP, 28*8
        fld.d     $ft6, TMP, 29*8
        fld.d     $ft7, TMP, 30*8
        fld.d     $fa0, TMP, 31*8
        fld.d     $fa1, TMP, 32*8
        fld.d     $fa2, TMP, 33*8
        fld.d     $fa3, TMP, 34*8
        fld.d     $fa4, TMP, 35*8
        fld.d     $fa5, TMP, 36*8
        fld.d     $fa6, TMP, 37*8
        fld.d     $fa7, TMP, 38*8
        fld.d     $ft8, TMP, 39*8
        fld.d     $ft9, TMP, 40*8
        fld.d     $ft10, TMP, 41*8
        fld.d     $ft11, TMP, 42*8
        fld.d     $ft12, TMP, 43*8
        fld.d     $ft13, TMP, 44*8
        fld.d     $ft14, TMP, 45*8
        fld.d     $ft15, TMP, 46*8
    /* Put gc_regs struct back in bucket linked list */
        ld.d      TMP2, Caml_state(gc_regs_buckets)
        st.d      TMP2, TMP, 0  /* next ptr */
        st.d      TMP, Caml_state(gc_regs_buckets)
    /* Reload new allocation pointer & exn handler */
        ld.d      ALLOC_PTR, Caml_state(young_ptr)
        ld.d      TRAP_PTR, Caml_state(exn_handler)
.endm

        .section        .text
/* Invoke the garbage collector. */

        .globl  caml_system__code_begin
caml_system__code_begin:

FUNCTION(caml_call_realloc_stack)
    /* Save return address */
        CFI_OFFSET($ra, -8)
        addi.d    $sp, $sp, -16
        st.d      $ra, $sp, 8
        //CFI_ADJUST(16)
    /* Save all registers (including ALLOC_PTR & TRAP_PTR) */
        SAVE_ALL_REGS
        ld.d      C_ARG_1, $sp, 16  /* argument */
        SWITCH_OCAML_TO_C
        bl    PLT(caml_try_realloc_stack)
        SWITCH_C_TO_OCAML
        beqz    $a0, 1f
        RESTORE_ALL_REGS
    /* Free stack $space and return to caller */
        ld.d      $ra, $sp, 8
        addi.d    $sp, $sp, 16
        jr    $ra
1:      RESTORE_ALL_REGS
    /* Raise the Stack_overflow exception */
        ld.d      $ra, $sp, 8
        addi.d    $sp, $sp, 16
        addi.d    $sp, $sp, 16 /* pop argument */
        la.global      $a0, caml_exn_Stack_overflow
        b       caml_raise_exn
END_FUNCTION(caml_call_realloc_stack)

FUNCTION(caml_call_gc)
L(caml_call_gc):
    /* Save return address */
        CFI_OFFSET($ra, -8)
        addi.d    $sp, $sp, -16
        st.d      $ra, $sp, 8
        CFI_ADJUST(16)
    /* Store all registers (including ALLOC_PTR & TRAP_PTR) */
        SAVE_ALL_REGS
        SWITCH_OCAML_TO_C
    /* Call the garbage collector */
        bl    PLT(caml_garbage_collection)
        SWITCH_C_TO_OCAML
        RESTORE_ALL_REGS
    /* Free stack $space and return to caller */
        ld.d      $ra, $sp, 8
        addi.d    $sp, $sp, 16
        jr    $ra
END_FUNCTION(caml_call_gc)

FUNCTION(caml_alloc1)
        ld.d      TMP, Caml_state(young_limit)
        addi.d    ALLOC_PTR, ALLOC_PTR, -16
        bltu    ALLOC_PTR, TMP, L(caml_call_gc)
        jr    $ra
END_FUNCTION(caml_alloc1)

FUNCTION(caml_alloc2)
        ld.d      TMP, Caml_state(young_limit)
        addi.d    ALLOC_PTR, ALLOC_PTR, -24
        bltu    ALLOC_PTR, TMP, L(caml_call_gc)
        jr    $ra
END_FUNCTION(caml_alloc2)

FUNCTION(caml_alloc3)
        ld.d      TMP, Caml_state(young_limit)
        addi.d    ALLOC_PTR, ALLOC_PTR, -32
        bltu    ALLOC_PTR, TMP, L(caml_call_gc)
        jr    $ra
END_FUNCTION(caml_alloc3)

FUNCTION(caml_allocN)
        ld.d      TMP, Caml_state(young_limit)
        sub.d     ALLOC_PTR, ALLOC_PTR, ADDITIONAL_ARG
        bltu    ALLOC_PTR, TMP, L(caml_call_gc)
        jr    $ra
END_FUNCTION(caml_allocN)

/* Call a C function from OCaml */
/* Function to call is in ADDITIONAL_ARG */

.macro RET_FROM_C_CALL
        ld.d      TMP, Caml_state(action_pending)
        bnez    TMP, 1f
        jr	$ra
1:      li.d      TMP, -1
        st.d      TMP, Caml_state(young_limit)
        jr	$ra
.endm

FUNCTION(caml_c_call)
        CFI_OFFSET($ra, -8)
        addi.d    $sp, $sp, -16
        st.d      $ra, $sp, 8
        CFI_ADJUST(16)
    /* Switch form OCaml to C */
        SWITCH_OCAML_TO_C
    /* Make the exception handler alloc ptr available to the C code */
        st.d      ALLOC_PTR, Caml_state(young_ptr)
        st.d      TRAP_PTR, Caml_state(exn_handler)
    /* Call the function */
        jirl    $ra, ADDITIONAL_ARG, 0
    /* Reload alloc ptr */
        ld.d      ALLOC_PTR, Caml_state(young_ptr)
	ld.d     TRAP_PTR, Caml_state(exn_handler)
    /* Load ocaml stack */
        SWITCH_C_TO_OCAML
    /* Return */
        ld.d      $ra, $sp, 8
        addi.d    $sp, $sp, 16
        RET_FROM_C_CALL
END_FUNCTION(caml_c_call)

FUNCTION(caml_c_call_stack_args)
    /* Arguments:
        C arguments  : $a0 to a7, fa0 to fa7
        C function   : ADDITIONAL_ARG
        C stack args : begin=STACK_ARG_BEGIN
                       end=STACK_ARG_END */
        CFI_OFFSET($ra, -8)
        addi.d    $sp, $sp, -16
        st.d      $ra, $sp, 8
        CFI_ADJUST(16)
    /* Switch from OCaml to C */
        SWITCH_OCAML_TO_C
    /* Make the exception handler alloc ptr available to the C code */
        st.d      ALLOC_PTR, Caml_state(young_ptr)
        st.d      TRAP_PTR, Caml_state(exn_handler)
    /* Store $sp to restore after call */
        move      $s2, $sp
    /* Copy arguments from OCaml to C stack
       NB: STACK_ARG_END - STACK_ARG_BEGIN is a multiple of 16 */
1:      addi.d    STACK_ARG_END, STACK_ARG_END, -16
        bltu    STACK_ARG_END, STACK_ARG_BEGIN, 2f
        ld.d      TMP, STACK_ARG_END, 0
        ld.d      TMP2, STACK_ARG_END, 8
        addi.d    $sp, $sp, -16
        st.d      TMP, $sp, 0
        st.d      TMP2, $sp, 8
        b       1b
2:  /* Call the function */
        jirl    $ra, ADDITIONAL_ARG, 0
    /* Restore stack */
        move      $sp, $s2
    /* Reload alloc ptr */
        ld.d      ALLOC_PTR, Caml_state(young_ptr)
	ld.d     TRAP_PTR, Caml_state(exn_handler)
    /* Switch from C to OCaml */
        SWITCH_C_TO_OCAML
    /* Return */
        ld.d      $ra, $sp, 8
        addi.d    $sp, $sp, 16
        RET_FROM_C_CALL
END_FUNCTION(caml_c_call_stack_args)

/* Start the OCaml program */

FUNCTION(caml_start_program)
    /* domain state is passed as arg from C */
        move      TMP, C_ARG_1
        la.global      TMP2, caml_program

/* Code shared with caml_callback* */
/* Address of domain state is in TMP */
/* Address of OCaml code to call is in TMP2 */
/* Arguments to the OCaml code are in $a0...a7 */

L(jump_to_caml):
    /* Set up stack frame and save callee-save registers */
        CFI_OFFSET($ra, -200)
        addi.d    $sp, $sp, -208
        st.d      $ra, $sp, 8
        CFI_ADJUST(208)
        st.d      $s0, $sp, 2*8
        st.d      $s1, $sp, 3*8
        st.d      $s2, $sp, 4*8
        st.d      $s3, $sp, 5*8
        st.d      $s4, $sp, 6*8
        st.d      $s5, $sp, 7*8
        st.d      $s6, $sp, 8*8
        st.d      $s7, $sp, 9*8
        st.d      $s8, $sp, 10*8
        st.d      $fp, $sp, 11*8
        fst.d     $fs0, $sp, 14*8
        fst.d     $fs1, $sp, 15*8
        fst.d     $fs2, $sp, 16*8
        fst.d     $fs3, $sp, 17*8
        fst.d     $fs4, $sp, 18*8
        fst.d     $fs5, $sp, 19*8
        fst.d     $fs6, $sp, 20*8
        fst.d     $fs7, $sp, 21*8
    /* Load domain state pointer from argument */
        move      DOMAIN_STATE_PTR, TMP
    /* Reload allocation pointer */
        ld.d      ALLOC_PTR, Caml_state(young_ptr)
    /* Build (16-byte aligned) struct c_stack_link on the C stack */
        ld.d      $t2, Caml_state(c_stack)
        addi.d    $sp, $sp, -32
        st.d      $t2, Cstack_prev($sp)
        st.d      $zero, Cstack_stack($sp)
        st.d      $zero, Cstack_sp($sp)
        CFI_ADJUST(32)
        st.d      $sp, Caml_state(c_stack)
    /* Load the OCaml stack */
        ld.d      $t2, Caml_state(current_stack)
        ld.d      $t2, Stack_sp($t2)
    /* Store the gc_regs for callbacks during a GC */
        ld.d      $t3, Caml_state(gc_regs)
        addi.d    $t2, $t2, -8
        st.d      $t3, $t2, 0
    /* Store the stack pointer to allow DWARF unwind */
        addi.d    $t2, $t2, -8
        st.d      $sp, $t2, 0  /* C_stack_sp */
    /* Setup a trap frame to catch exceptions escaping the OCaml code */
        ld.d      $t3, Caml_state(exn_handler)
        la.local      $t4, L(trap_handler)
        addi.d    $t2, $t2, -16
        st.d      $t3, $t2, 0
        st.d      $t4, $t2, 8
        move      TRAP_PTR, $t2
    /* Switch stacks and call the OCaml code */
        move      $sp, $t2
        CFI_REMEMBER_STATE
    /* Call the OCaml code */
        jirl    $ra, TMP2, 0
L(caml_retaddr):
    /* Pop the trap frame, restoring Caml_state->exn_handler */
        ld.d      $t2, $sp, 0
        addi.d    $sp, $sp, 16
        CFI_ADJUST(-16)
        st.d      $t2, Caml_state(exn_handler)
L(return_result):
    /* Restore GC regs */
        ld.d      $t2, $sp, 0
        ld.d      $t3, $sp, 8
        addi.d    $sp, $sp, 16
        CFI_ADJUST(-16)
        st.d      $t3, Caml_state(gc_regs)
    /* Update allocation pointer */
        st.d      ALLOC_PTR, Caml_state(young_ptr)
    /* Return to C stack */
        ld.d      $t2, Caml_state(current_stack)
        st.d      $sp, Stack_sp($t2)
        ld.d      $t3, Caml_state(c_stack)
        move      $sp, $t3
        CFI_RESTORE_STATE
    /* Pop the struct c_stack_link */
        ld.d      $t2, Cstack_prev($sp)
        addi.d    $sp, $sp, 32
        CFI_ADJUST(-32)
        st.d      $t2, Caml_state(c_stack)
    /* Reload callee-save register and return address */
        ld.d      $s0, $sp, 2*8
        ld.d      $s1, $sp, 3*8
        ld.d      $s2, $sp, 4*8
        ld.d      $s3, $sp, 5*8
        ld.d      $s4, $sp, 6*8
        ld.d      $s5, $sp, 7*8
        ld.d      $s6, $sp, 8*8
        ld.d      $s7, $sp, 9*8
        ld.d      $s8, $sp, 10*8
        ld.d      $fp, $sp, 11*8
        fld.d     $fs0, $sp, 14*8
        fld.d     $fs1, $sp, 15*8
        fld.d     $fs2, $sp, 16*8
        fld.d     $fs3, $sp, 17*8
        fld.d     $fs4, $sp, 18*8
        fld.d     $fs5, $sp, 19*8
        fld.d     $fs6, $sp, 20*8
        fld.d     $fs7, $sp, 21*8
        ld.d      $ra, $sp, 8
        addi.d    $sp, $sp, 208
        CFI_ADJUST(-208)
    /* Return to C caller */
        jr    $ra
END_FUNCTION(caml_start_program)

/* The trap handler */

        .align  2
L(trap_handler):
        CFI_STARTPROC
    /* Save exception pointer */
        st.d      TRAP_PTR, Caml_state(exn_handler)
    /* Encode exception pointer */
        ori     $a0, $a0, 2
    /* Return it */
        b       L(return_result)
        CFI_ENDPROC

/* Exceptions */

.macro JUMP_TO_TRAP_PTR
    /* Cut stack at current trap handler */
        move      $sp, TRAP_PTR
    /* Pop previous handler and jump to it */
        ld.d      TMP, $sp, 8
        ld.d      TRAP_PTR, $sp, 0
        addi.d    $sp, $sp, 16
        jr      TMP
.endm

/* Raise an exception from OCaml */
FUNCTION(caml_raise_exn)
    /* Test if backtrace is active */
        ld.d      TMP, Caml_state(backtrace_active)
        bnez    TMP, 2f
1:
        JUMP_TO_TRAP_PTR
2:  /* Zero backtrace_pos */
        st.d      $zero, Caml_state(backtrace_pos)
L(caml_reraise_exn_stash):
    /* Preserve exception bucket in callee-save register $s2 */
        move      $s2, $a0
    /* Stash the backtrace */
                                  /* arg1: exn bucket, already in $a0 */
        move      $a1, $ra            /* arg2: pc of $raise */
        move      $a2, $sp            /* arg3: $sp of $raise */
        move      $a3, TRAP_PTR      /* arg4: $sp of handler */
    /* Switch to C stack */
        ld.d      TMP, Caml_state(c_stack)
        move      $sp, TMP
        bl    PLT(caml_stash_backtrace)
    /* Restore exception bucket and $raise */
        move      $a0, $s2
        b       1b
END_FUNCTION(caml_raise_exn)

FUNCTION(caml_reraise_exn)
        ld.d      TMP, Caml_state(backtrace_active)
        bnez    TMP, L(caml_reraise_exn_stash)
        JUMP_TO_TRAP_PTR
END_FUNCTION(caml_reraise_exn)

/* Raise an exception from C */

FUNCTION(caml_raise_exception)
    /* Load the domain state ptr */
        move      DOMAIN_STATE_PTR, C_ARG_1
    /* Load the exception bucket */
        move      $a0, C_ARG_2
    /* Reload trap ptr and alloc ptr */
        ld.d      TRAP_PTR, Caml_state(exn_handler)
        ld.d      ALLOC_PTR, Caml_state(young_ptr)
    /* Discard the C stack pointer and reset to ocaml stack */
        ld.d      TMP, Caml_state(current_stack)
        ld.d      TMP, Stack_sp(TMP)
        move      $sp, TMP
    /* Restore frame and link on return to OCaml */
        ld.d      $ra, $sp, 8
        addi.d    $sp, $sp, 16
        b       caml_raise_exn
END_FUNCTION(caml_raise_exception)

/* Callback from C to OCaml */

FUNCTION(caml_callback_asm)
    /* Initial shuffling of arguments */
    /* ($a0 = Caml_state, $a1 = closure, 0(a2) = first arg) */
        move      TMP, $a0
        ld.d      $a0, $a2, 0            /* $a0 = first arg */
                                    /* $a1 = closure environment */
        ld.d      TMP2, $a1, 0           /* code pointer */
        b       L(jump_to_caml)
END_FUNCTION(caml_callback_asm)

FUNCTION(caml_callback2_asm)
    /* Initial shuffling of arguments */
    /* ($a0 = Caml_state, $a1 = closure, 0(a2) = arg1, 8(a2) = arg2) */
        move      TMP, $a0
        move      TMP2, $a1
        ld.d      $a0, $a2, 0  /* $a0 = first arg */
        ld.d      $a1, $a2, 8  /* $a1 = second arg */
        move      $a2, TMP2   /* a2 = closure environment */
        la.global      TMP2, caml_apply2
        b       L(jump_to_caml)
END_FUNCTION(caml_callback2_asm)

FUNCTION(caml_callback3_asm)
    /* Initial shuffling of arguments */
    /* ($a0 = Caml_state, $a1 = closure, 0(a2) = arg1, 8(a2) = arg2,
        16(a2) = arg3) */
        move      TMP, $a0
        move      $a3, $a1       /* a3 = closure environment */
        ld.d      $a0, $a2, 0     /* $a0 = first arg */
        ld.d      $a1, $a2, 8     /* $a1 = second arg */
        ld.d      $a2, $a2, 16    /* a2 = third arg */
        la.global      TMP2, caml_apply3
        b       L(jump_to_caml)
END_FUNCTION(caml_callback3_asm)

/* Fibers */

/* Switch between OCaml stacks. Clobbers TMP and switches TRAP_PTR
   Preserves old_stack and new_stack registers */
.macro SWITCH_OCAML_STACKS old_stack, new_stack
    /* Save frame pointer and return address for old_stack */
        addi.d    $sp, $sp, -16
        st.d      $ra, $sp, 8
        CFI_ADJUST(16)
    /* Save OCaml SP and exn_handler in the stack info */
        st.d      $sp, Stack_sp(\old_stack)
        st.d      TRAP_PTR, Stack_exception(\old_stack)
    /* switch stacks */
        st.d      \new_stack, Caml_state(current_stack)
        ld.d      TMP, Stack_sp(\new_stack)
        move      $sp, TMP
    /* restore exn_handler for new stack */
        ld.d      TRAP_PTR, Stack_exception(\new_stack)
    /* Restore frame pointer and return address for new_stack */
        ld.d      $ra, $sp, 8
        addi.d    $sp, $sp, 16
.endm

/*
 * A continuation is a one word object that points to a fiber. A fiber [f] will
 * point to its parent at Handler_parent(Stack_handler(f)). In the following,
 * the [last_fiber] refers to the last fiber in the linked-list formed by the
 * parent pointer.
 */

FUNCTION(caml_perform)
    /*  $a0: effect to perform
        $a1: freshly allocated continuation */
        ld.d      $a2, Caml_state(current_stack) /* a2 := old stack */
        addi.d    $a3, $a2, 1 /* a3 := Val_ptr(old stack) */
        st.d      $a3, $a1, 0  /* Iniitalize continuation */
L(do_perform):
    /*  $a0: effect to perform
        $a1: continuation
        a2: old_stack
        a3: last_fiber */

	st.d	  $a3, $a1, 8		   /* Set the last fiber field in the continuation */
        ld.d      $t3, Stack_handler($a2)  /* $t3 := old stack -> handler */
        ld.d      $t4, Handler_parent($t3) /* t4 := parent stack */
        beqz    $t4, 1f
        SWITCH_OCAML_STACKS $a2, $t4
    /*  we have to null the Handler_parent after the switch because
        the Handler_parent is needed to unwind the stack for backtraces */
        st.d      $zero, Handler_parent($t3) /* Set parent of performer to NULL */
        ld.d      TMP, Handler_effect($t3)
        move      $a2, $a3                 /* a2 := last_fiber */
        move      $a3, TMP                /* a3 := effect handler */
        b    PLT(caml_apply3)
1:
    /*  switch back to original performer before $raising Effect.Unhandled
        (no-op unless this is a reperform) */
        ld.d      $t4, $a1, 0  /* load performer stack from continuation */
        addi.d    $t4, $t4, -1 /* t4 := Ptr_val(t4) */
        ld.d      $t3, Caml_state(current_stack)
        SWITCH_OCAML_STACKS $t3, $t4
    /*  No parent stack. Raise Effect.Unhandled. */
        la.global      ADDITIONAL_ARG, caml_raise_unhandled_effect
        b       caml_c_call
END_FUNCTION(caml_perform)

FUNCTION(caml_reperform)
    /*  $a0: effect to perform
        $a1: continuation
        a2: last_fiber */
        ld.d      TMP, Stack_handler_from_cont($a2)
        ld.d      $a2, Caml_state(current_stack) /* a2 := old stack */
        st.d      $a2, Handler_parent(TMP) /* Append to last_fiber */
        addi.d    $a3, $a2, 1 /* a3 (last_fiber) := Val_ptr(old stack) */
        b       L(do_perform)
END_FUNCTION(caml_reperform)

FUNCTION(caml_resume)
    /*  $a0: new fiber
        $a1: fun
        $a2: arg
	$a3: last_fiber */
        addi.d    $a0, $a0, -1 /* $a0 = Ptr_val($a0) */
        ld.d      $a4, $a1, 0   /* code pointer */
    /* Check if stack null, then already used */
	beqz	  $a0, 1f
    /* Add current stack to the end */
	addi.d	  $a3, $a3, -1 /* a3 = Ptr_val(a3) */
	ld.d	  $t2, Stack_handler($a3)
        ld.d      $t3, Caml_state(current_stack)
        st.d      $t3, Handler_parent($t2)
        SWITCH_OCAML_STACKS $t3, $a0
        move      $a0, $a2
        jr      $a4
1:      la.global      ADDITIONAL_ARG, caml_raise_continuation_already_resumed
        b       caml_c_call
END_FUNCTION(caml_resume)

/* Run a function on a new stack, then either
   return the value or invoke exception handler */
FUNCTION(caml_runstack)
    /*  $a0: fiber
        $a1: fun
        a2: arg */
        CFI_OFFSET($ra, -8)
        addi.d    $sp, $sp, -16
        st.d      $ra, $sp, 8
        CFI_ADJUST(16)
        addi.d    $a0, $a0, -1  /* $a0 := Ptr_val($a0) */
        ld.d      $a3, $a1, 0    /* code pointer */
    /*  save old stack pointer and exception handler */
        ld.d      $t2, Caml_state(current_stack) /* $t2 := old stack */
        st.d      $sp, Stack_sp($t2)
        st.d      TRAP_PTR, Stack_exception($t2)
    /* Load new stack pointer and set parent */
        ld.d      TMP, Stack_handler($a0)
        st.d      $t2, Handler_parent(TMP)
        st.d      $a0, Caml_state(current_stack)
        ld.d      $t3, Stack_sp($a0) /* $t3 := $sp of new stack */
    /* Create an exception handler on the target stack
       after 16byte DWARF & gc_regs block (which is unused here) */
        addi.d    $t3, $t3, -32
        la.local      TMP, L(fiber_exn_handler)
        st.d      TMP, $t3, 8
    /* link the previous exn_handler so that copying stacks works */
        ld.d      TMP, Stack_exception($a0)
        st.d      TMP, $t3, 0
        move      TRAP_PTR, $t3
    /* Switch to the new stack */
        move      $sp, $t3
        CFI_REMEMBER_STATE
    /* Call the function on the new stack */
        move      $a0, $a2
        jirl    $ra, $a3, 0
L(frame_runstack):
        addi.d    $t2, $sp, 32 /* $t2 := stack_handler */
        ld.d      $s2, Handler_value($t2) /* saved across C call */
1:
        move      $s3, $a0     /* save return across C call */
        ld.d      $a0, Caml_state(current_stack) /* arg to caml_free_stack */
    /* restore parent stack and exn_handler into Caml_state */
        ld.d      TMP, Handler_parent($t2)
        st.d      TMP, Caml_state(current_stack)
        ld.d      TRAP_PTR, Stack_exception(TMP)
        st.d      TRAP_PTR, Caml_state(exn_handler)
    /* free old stack by switching directly to c_stack;
       is a no-alloc call */
        ld.d      $s4, Stack_sp(TMP) /* saved across C call */
        CFI_RESTORE_STATE
        CFI_REMEMBER_STATE
        ld.d      TMP, Caml_state(c_stack)
        move      $sp, TMP
        bl    PLT(caml_free_stack)
    /* switch directly to parent stack with correct return */
        move      $a0, $s3
        move      $a1, $s2
        move      $sp, $s4
        CFI_RESTORE_STATE
        ld.d      TMP, $s2, 0   /* code pointer */
    /* Invoke handle_value (or handle_exn) */
        ld.d      $ra, $sp, 8
        addi.d    $sp, $sp, 16
        CFI_ADJUST(-16)
        jr      TMP
L(fiber_exn_handler):
        addi.d    $t2, $sp, 16  /* $t2 := stack_handler */
        ld.d      $s2, Handler_exception($t2)
        b       1b
END_FUNCTION(caml_runstack)

FUNCTION(caml_ml_array_bound_error)
    /* Load address of [caml_array_bound_error_asm] in ADDITIONAL_ARG */
        la.global      ADDITIONAL_ARG, caml_array_bound_error_asm
    /* Call that function */
        b       caml_c_call
END_FUNCTION(caml_ml_array_bound_error)

        .globl  caml_system__code_end
caml_system__code_end:

/* GC roots for callback */

OBJECT(caml_system.frametable)
        .quad   2                 /* two descriptors */
        .quad   L(caml_retaddr)   /* return address into callback */
        .short  -1                /* negative frame size => use callback link */
        .short  0                 /* no roots */
        .align  3
        .quad   L(frame_runstack) /* return address into fiber handler */
        .short  -1                /* negative frame size => use callback link */
        .short  0                 /* no roots */
        .align  3
END_OBJECT(caml_system.frametable)
.end
