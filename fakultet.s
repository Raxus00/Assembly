.data
    n:
    .word 1, 2, 3, 4,5, 6, 7, 8, 9, 10, 0
.text
.global main
facult:
    stmdb sp!, {lr, r4}
    CMP r0, #1
    BEQ finish
    MOV r4, r0
    SUB r0, r0, #1
    BL facult
    MUL r6, r0, r4
    MOV r0, r6

finish:
    ldmia sp!, {pc, r4}
main:
    stmdb sp!, {lr}
    LDR r2 ,=n    
    BAL loop

loop:
    LDR r0, [r2]
    CMP r0, #0
    BEQ Done
    BL facult
    MOV r1,r0
    MOV r0, #1
    SWI 0x6b
    ADD r2, r2, #4
    BAl loop

Done:
    ldmia sp!, {pc}

