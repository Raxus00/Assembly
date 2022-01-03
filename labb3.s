.data
    ; -------- VARIABLES FOR LIBRARY --------
    in: .space 1024
    in_size: .quad 1024 ; How large our buffer is
    in_p: .quad 0 ; Pointer for our in buffer
    in_c: .quad 0 ; Does the buffer contain anything? 0 = no, 1 = yes
    in_dir: .quad 0 ; Is the func called directly? 0 = yes, 1 = no

    out: .space 1024 ; Double the length as we need more character to process
    out_p: .quad 0 ; Pointer for our out buffer
    out_char_string: .asciz "%c"
    out_int_string: .asciz "%d"
    out_size: .quad 1024 ; How large our buffer is
    out_newline: .asciz "\n"

    type: .space 1024 ; Contains if a byte is a char or an int
    type_p: .quad 0 ; Pointer to the value above

    getInt_char: .quad 0 ; Has a char been found? 0 = no, 1 = yes
    ; -------- VARIABLES FOR LIBRARY --------


    headMsg: .asciz	"Start av testprogram. Skriv in 5 tal!"
	endMsg:	.asciz	"Slut pa testprogram"
	buf:	.space	1024
	sum:	.quad	0
	count:	.quad	0
	temp:	.quad	0


.text
.global inImage
.global getInt
.global getText
.global getChar
.global getInPos
.global setInPos

.global outImage
.global putInt
.global putText
.global putChar
.global getOutPos
.global setOutPos

; ================= INPUT =================
inImage: ; Takes a user input, and reset the pointer
    pushq %r8
    pushq %rdi
    pushq %rsi

    movq $in, %rdi ; Move the address
    movq (in_size), %rsi ; (in_length) characters aswell as the terminator
    movq stdin, %rdx ; Indicate that we want an input from the user

    pushq %rdi
    pushq %rsi
    pushq %rdx
    call inImageDecider
    popq %rdx
    popq %rsi
    popq %rdi

    movq $0, (in_p) ; Reset
    movq $1, (in_c) ; The buffer now contains a value
    movq $0, (in_dir) ; Reset

    popq %rsi
    popq %rdi
    popq %r8

    ret

inImageDecider:
    cmpq $1, (in_dir) ; Subroutine
    je inImage_indirect

    jmp inImage_direct ; Direct call

inImage_direct:
    call fgets
    ret

inImage_indirect:
    pushq %r8 ; Must pushq so that it doesnt crash
    call fgets
    popq %r8

    ret

in_contains: ; Makes sure that the buffer contains a value
    movq $1, (in_dir) ; If we call on inImage, then its through this function

    cmpq $0, (in_c) ; The buffer doesnt contain anything
    je inImage

    movq (in_p), %r8
    cmpq %r8, (in_size) ; Out-of-bounds
    jl inImage

    ret ; Success

getInt: ; Returns the first possible int from the in buffer, starting point is where the pointer currently is
    call in_contains ; Makes sure that the buffer should contain something
    movq $0, %r8 ; This will act as a buffer for the integer
    movq $in, %r10
    movq $0, %r12 ; This will be used to know if it's a negative number

    loop_getInt:
        movq (in_p), %r9 ; Current address
        movzbq 0(%r10, %r9, 1), %r11 ; Value at the current address

        subq $48, %r11 ; "Convert" to decimal

        cmpq $-38, %r11 ; "Line feed"
        je getInt_toReturn_or_notToReturn ; Jump if equal

        cmpq $-16, %r11 ; Space
        je getInt_toReturn_or_notToReturn

        cmpq $-5, %r11 ; Positive
        je getInt_ignore

        cmpq $-3, %r11 ; Negative
        je getInt_mark_negative

        cmpq $9, %r11 ; Check if (%r11) > 9
        jg getInt_end_loop_char ; Most likely a char

        cmpq $0, %r11 ; Check if (%r11) < 0
        jl getInt_end_loop_char ; Most likely a char

        imulq $10, %r8 ; Essentially r8 = 10 * loop_count
        call getInt_save ; We want this value!
        
        incq (in_p) ; Increment +1
        
        jmp loop_getInt ; We have passed the filter

    getInt_end_loop_char:
        movq $1, (getInt_char)
        movq $0, %rax
        movq $0, %r8
        ret

    getInt_toReturn_or_notToReturn:
        cmpq $0, (getInt_char)
        je getInt_end_loop

        movq $0, %rax
        movq $0, %r8
        ret

    getInt_end_loop: ; Leave loop
        movq %r8, %rax ; Put the final value in the correct register
        incq (in_p) ; Increment +1

        cmpq $1, %r12
        je getInt_end_loop_negate

        ret

    getInt_end_loop_negate: ; The value is negative
        neg %rax ; Makes the value negative
        ret

getInt_save: ; Remember the value!
    addq %r11, %r8 ; Save the value!    
    ret

getInt_mark_negative: ; Turns the value negative
    movq $1, %r12 ; Marks the value negative
    incq (in_p) ; Increment +1
    jmp loop_getInt

getInt_ignore: ; Ignore the value if we don't want it, even if it is valid
    incq (in_p) ; Increment +1. So that we jump one step extra
    jmp loop_getInt

getText: ; Copies %rsi amount of characters to %rdi from the in buffer
    pushq %rdi
    pushq %rsi
    call in_contains ; Makes sure that the buffer should contain something
    popq %rsi
    popq %rdi

    loop_getText:
        movq (in_p), %r10 
        cmpq %r10, (in_size) ; Check if we are out-of-bounds?
        jle loop_getText_end

        decq %rsi ; Decrement 1 from %rsi
        call getChar ; Will grab a value from the inbuffer and put it in %rax

        movq %rax, (%rdi) ; This will move the value that getChar returned to the buffer

        addq $1, %rdi ; Jump to the next address

        cmpq $0, %rsi ; Check if we are done
        jg loop_getText 
    
    loop_getText_end: ; Ends the session
        movq $0, (in_p) ; Reset
        movq %rsi, %rax ; %rax will now contain how many characters we successfully copied
        ret

getChar: ; Returns the character at the current location
    call in_contains ; Makes sure that the buffer should contain something
    movq $in, %r8
    movq (in_p), %r9
    movzbq 0(%r8, %r9, 1), %rax
    incq (in_p) ; Increment +1
    ret

getInPos: ; Returns the current pos in the in buffer, the return value is put into the %rax register
    movq (in_p), %rax
    ret

setInPos: ; Sets the current pos in the in_buffer, input is in the register %rdi
    cmpq (in_size), %rdi ; Check if %rdi > (in_size)
    jg overflow_jump_in

    cmpq $0, %rdi ; Check if %rdi < 0
    jl underflow_jump_in

    movq %rdi, (in_p) ; in_pointer is the pointer for our buffer that handles the input from the user
    ret

overflow_jump_in: ; The value in %rdi is larger than (in_size)
    movq (in_size), %r9
    movq %r9, (in_p)
    ret

underflow_jump_in: ; The value in %rdi is smaller than 0
    movq $0, (in_p)
    ret
; =================  =================

; ================= OUTPUT =================
outImage: ; Writes out the contents of out_buffer
    movq $out, %r8
    movq $type, %r9
    movq $0, %r12 ; Counter
    
    loop_out:
        movq (%r9), %r10 ; Grab if it is an int or a char
        movq (%r8), %rsi ; Grab the value
        
        addq $8, %r9
        addq $8, %r8
        addq $8, %r12

        call loadRDI ; This will load %rdi 
        
        pushq %r8
        pushq %r9
        pushq %rsi
        call printf
        popq %rsi
        popq %r9
        popq %r8

        cmpq %r12, (out_size) ; Checks if we have printed the entire buffer
        jg loop_out
                
        loop_out_end:
            pushq %rsi
            movq $out_newline, %rdi ; To make the output prettier
            call printf
            popq %rsi
            movq $0, (out_p) ; Reset
            movq $0, (type_p) ; Reset
            call outClean ; Clean the buffer
            ret

loadRDI:
    cmpq $0, %r10
    je outImageString

    cmpq $1, %r10
    je outImageInt

outImageString:
    cmpq $'0', %rsi ; We are trying to print a 0 as a char, indicating that it's the end
    je loop_out_end

    movq $out_char_string, %rdi
    ret

outImageInt:
    movq $out_int_string, %rdi
    ret

outClean: ; Cleans the buffer
    movq $out, %r8
    movq $type, %r9
    movq $0, %r10 ; Counter

    loop_clean:
        cmpq (out_size), %r10 ; Have we overwritten the entire buffer?
        jge clean_done
        
        movq $0, (%r8) ; Reset the value
        movq $0, (%r9) ; Reset the value

        addq $8, %r8
        addq $8, %r9
        addq $8, %r10

        jmp loop_clean

    clean_done:
        ret

outImageCallCheck: ; Checks if outImage has been called, as this indicate that the buffer will contain something    
    movq (out_size), %r8
    cmpq (out_p), %r8 ; We have gone further than what the buffer permits
    jl outImage

    ; If we have reached this point, then the buffer already contains something
    ret

putInt: ; Input from %rdi
    movq (out_p), %r8
    movq $out, %r9 ; Address of %r9
    addq %r8, %r9 ; %r9 is the base address of out_buffer, and %r8 is the current position
    movq %rdi, (%r9) ; Insert the actual value
    addq $8, (out_p)

    movq (type_p), %r8
    movq $type, %r9
    addq %r8, %r9
    movq $1, (%r9) ; Insert that it's an integer
    addq $8, (type_p)

    ; ----- Did we go above what we where allowed to do? -----
    movq (out_size), %r9
    cmpq %r9, (out_p) ; Check if (out_p) > (out_size)
    jg outImage
    ; ----- -----
    ret

putText: ; %rdi will contain the source address
    movq $0, %r8 ; %r8 will act as the pointer for %rdi in this case
    movq %rdi, %r9 ; So that we work with %r9 instead of %rdi

    loop_putText:
        movzbq 0(%r9, %r8, 1), %rdi ; This will grab the character from %rdi in its ascii value
        addq $1, %r8 ; Advance to the next address

        pushq %r8
        call outImageCallCheck ; Checks if the buffer is full
        popq %r8

        pushq %r8
        pushq %r9
        call putChar ; Inserts whatever %rdi contains
        popq %r9
        popq %r8

        cmpq $0, %rdi ; zero indicates the end of the string
        jne loop_putText
    ret

putChar: ; Input from %rdi
    movq (out_p), %r8
    movq $out, %r9 ; Address of %r9
    addq %r8, %r9 ; %r9 is the base address of out_buffer, and %r8 is the current pos
    movq %rdi, (%r9) ; Insert the actual value
    addq $8, (out_p)

    movq (type_p), %r8
    movq $type, %r9
    addq %r8, %r9
    movq $0, (%r9) ; Insert that it's an integer
    addq $8, (type_p)

    ; ----- Did we go above what we where allowed to do? -----
    movq (out_size), %r9
    cmpq %r9, (out_p) ; Check if (out_p) > (out_size)
    jg outImage
    ; ----- -----
    ret

getOutPos: ; Returns the current pos in the out buffer
    movq (out_p), %rax
    ret

setOutPos: ; %rdi will contain the position we want for the out buffer
    movq (out_p), %r8
    subq %rdi, %r8 ; Get the difference

    cmpq $8, %r8 ; The new position might be "invalid"
    jl correct_pos_fixer

    setOutPosFinder:
        movq (out_size), %r8
        cmpq %r8, %rdi ; is %rdi > (out_size)
        jg overflow_jump_out

        cmpq $0, %rdi ; is %rdi < 0
        jl underflow_jump_out

        movq %rdi, (out_p)
        movq %rdi, (type_p)

    ret

correct_pos_fixer:
    cmpq $0, %r8 ; the new value is a lot further back than normally
    jl correct_pos_fixer_high

    jmp correct_pos_fixer_low ; Assumes that the value is between 0 and 7

correct_pos_fixer_high: ; This fixes so that the indexes ge correct
    movq (out_p), %rdi
    addq $8, %rdi

    jmp setOutPosFinder

correct_pos_fixer_low: ; This fixes so that the indexes ge correct
    movq (out_p), %rdi
    subq $8, %rdi

    jmp setOutPosFinder


overflow_jump_out: ; The value in %rdi is larger than (out_size)
    movq (out_size), %r9
    movq %r9, (out_p)
    movq %r9, (type_p)
    ret

underflow_jump_out: ; The value in %rdi is smaller than 0
    movq $0, (out_p)
    movq $0, (type_p)
    ret
; =================  =================
