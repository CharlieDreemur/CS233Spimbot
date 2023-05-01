# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

OTHER_X                 = 0xffff00a0
OTHER_Y                 = 0xffff00a4

TIMER                   = 0xffff001c
GET_MAP                 = 0xffff2008

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00d4  ## Puzzle

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

FALLING_INT_MASK        = 0x200
FALLING_ACK             = 0xffff00f4

STOP_FALLING_INT_MASK   = 0x400
STOP_FALLING_ACK        = 0xffff00f8

POWERWASH_ON            = 0xffff2000
POWERWASH_OFF           = 0xffff2004

GET_WATER_LEVEL         = 0xffff201c

MMIO_STATUS             = 0xffff204c

.data
### Puzzle
puzzlewrapper:     .byte 0:400
#### Puzzle

has_puzzle: .word 0

has_bonked: .byte 0

test_falling_string: .asciiz "Falling interrupt detected!\n"

#test
# -- string literals --
.text
get_water_level:
    lw  $t0, GET_WATER_LEVEL
    li  $t1, 200            #water_level < 200, solve_puzzle
    ble $t0, $t1, end
    li  $a0, 80            #temporarily solve for 80 cycles
    jal loop_solve_puzzle
    end:
        jr $ra

get_time_left:
    lw $t0, TIMER
    li  $t1, 10000000        #total cycles
    sub $t0, $t0, $t1        #cycles left
    li  $t1, 10000
    blt $t0, $t1, last_step    #when cycles_left <  10000, execute last step
    jr  $ra

find_bot:
    

quickMoveTo: #a0 loop cycle, a1 velocity, a2 x, a3 y
    addi $sp, $sp, -16
    sw   $ra, 0($sp)
    sw   $a1, 4($sp)
    sw   $a2, 8($sp)
    sw   $a3, 12($sp)
    #a0 is the loop cycle
    jal  loop_solve_puzzle
    li   $t0, 0x00040000
    sw   $t0, POWERWASH_ON
    lw   $a1, 4($sp)
    lw   $a2, 8($sp)
    lw   $a3, 12($sp)
    jal  moveTo
    sw $zero, POWERWASH_OFF

    lw   $ra, 0($sp)
    addi $sp, $sp, 16
    jr   $ra

moveTo: #a1 velocity, a2 x, a3 y
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp) #temp
    sw $s3, 16($sp) #0 move x or 1 move y
    sw $s4, 20($sp) #0 move left or 1 move right
    #initial
    sw $a1, VELOCITY
    lw $s0, BOT_X
    lw $s1, BOT_Y
    li $s2, -1
    beq $a2, $s2, setyMoveTo  #if x=-1, move y
    beq $a3, $s3, setxMoveTo  #if y=-1, move x
    #j endloopMoveTo #if x=-1, y=-1, end direclty
    setxMoveTo:
        li $s3, 0
        bge $a2, $s0, setRightMoveTo
        j setLeftMoveTo
    setyMoveTo:
        li $s3, 1
        bge $a3, $s1, setRightMoveTo
        j setLeftMoveTo
    setLeftMoveTo:
        li $s4, 0
        j loopMoveTo
    setRightMoveTo:
        li $s4, 1
        j loopMoveTo
    loopMoveTo:
        lw $s0, BOT_X
        lw $s1, BOT_Y
        beq $s3, $zero, xMoveTo
        j yMoveTo
    xMoveTo:
        beq $s4, $zero, xMoveToBle
        j xMoveToBge
    xMoveToBge:
        #move right
        li $t0, 0
        sw $t0, ANGLE
        li $s2, 1
        sw $s2, ANGLE_CONTROL

        bge $s0, $a2, endloopMoveTo
        j loopMoveTo
    xMoveToBle:
        #move left
        li $t0, 180
        sw $t0, ANGLE
        li $s2, 1
        sw $s2, ANGLE_CONTROL

        ble $s0, $a2, endloopMoveTo
        j loopMoveTo
    yMoveTo:
        beq $s4, $zero, yMoveToBle
        j yMoveToBge
    yMoveToBge:
        #move down
        li $t0, 90
        sw $t0, ANGLE
        li $s2, 1
        sw $s2, ANGLE_CONTROL

        bge $s1, $a3, endloopMoveTo
        j loopMoveTo
    yMoveToBle:  
        #move up
        li $t0, 270
        sw $t0, ANGLE
        li $s2, 1
        sw $s2, ANGLE_CONTROL

        ble $s1, $a3, endloopMoveTo
        j loopMoveTo

    endloopMoveTo:
        sw $zero, VELOCITY #velocity = 0

        lw $ra, 0($sp)
        lw $s0, 4($sp)
        lw $s1, 8($sp)
        lw $s2, 12($sp)
        lw $s3, 16($sp)
        lw $s4, 20($sp)
        addi $sp, $sp, 24
        jr $ra

puzzle_solve:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    li      $t1, 2
    #turn off powerwash
    sw $zero, POWERWASH_OFF
    solve_puzzle:
        ble     $t1, $zero, end_solve_puzzle
        la      $t7, puzzlewrapper
        sw      $t7, REQUEST_PUZZLE
        loop_puzzle:
            la      $t5, has_puzzle
            lb      $t6, 0($t5)
            bne     $t6, $zero, end_loop_puzzle
            j       loop_puzzle
        end_loop_puzzle:
            sb      $zero, 0($t5) # reset puzzle interrupt flag
            la      $t7, puzzlewrapper
            #Get the puzzle, start to get the parameter first
            lw      $a0, 4($t7)
            lw      $s0, 4($t7)
            #int n MAXDIM=8
            lw      $a1, 0($t7)
            #li      $s1, 8
            #list node t *given queens
            lw      $a2, 8($t7)
            #int queens to place
            lw      $a3, 12($t7)
            jal      solve_queens
            la      $t7, puzzlewrapper
            sw      $t7, SUBMIT_SOLUTION #submit solution
            addi    $t1, $t1, -1
            j       solve_puzzle
        end_solve_puzzle:
            lw      $ra, 0($sp)
            addi    $sp, $sp, 8
            jr      $ra
loop_solve_puzzle:
	sub $sp, $sp, 12
	sw  $ra, 0($sp)
	move $t1, $a0
	li   $t2, 0
	inner_loop:
		sw $t1, 4($sp)
		sw $t2, 8($sp)
		jal puzzle_solve
		lw  $t1, 4($sp)
		lw  $t2, 8($sp)
		add $t2, $t2, 1
		blt $t2, $t1, inner_loop
	end_inner:
	
	lw  $ra, 0($sp)
	add $sp, $sp, 12
	jr  $ra
main: #p4 stop-falling interrupt flag, p5 puzzle interrupt flag, p6 timer interrupt flag
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    # Construct interrupt mask
    li      $t4, 0
    or      $t4, $t4, TIMER_INT_MASK            # enable timer interrupt
    or      $t4, $t4, BONK_INT_MASK             # enable bonk interrupt
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK   # enable puzzle interrupt
    or      $t4, $t4, 1 # global enable
    mtc0    $t4, $12
    
    li      $t1, 0
    sw      $t1, ANGLE
    li      $t1, 1
    sw      $t1, ANGLE_CONTROL
    li      $t2, 0
    sw      $t2, VELOCITY
        
    # YOUR CODE GOES HERE!!!!!!
    
    
    #find bot position
    lw $t0, BOT_X
    bgt $t0, 200, bot1_option
    j   bot0_option
    
    
bot0_option:    
    #directly move to for strategy
    li $a0, 52
    li $a1, 5
    li $a2, 128
    li $a3, -1
    jal quickMoveTo

    li $a0, 40
    li $a1, 5
    li $a2, -1
    li $a3, 216
    jal quickMoveTo

    li $a0, 35
    li $a1, 5
    li $a2, 56
    li $a3, -1
    jal quickMoveTo

    li $a0, 35
    li $a1, 5
    li $a2, -1
    li $a3, 128
    jal quickMoveTo

    li $a0, 30
    li $a1, 5
    li $a2, -1
    li $a3, 64
    jal quickMoveTo
    loop_timer_bot0:
        li $a0, 5
        jal loop_solve_puzzle
        #timer 
        lw $t0, TIMER
        li  $t1, 10000000        #total cycles
        sub $t0, $t1, $t0        #cycles left
        li  $t1, 600000
        blt $t0, $t1, bot_0_last
        j loop_timer_bot0

    bot_0_last:
    #go right
    li $t0, 0
    sw $t0, ANGLE
    li $t0, 1
    sw $t0, ANGLE_CONTROL
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON
    li $t0, 5
    sw $t0, VELOCITY
    j  bot0_loop
    
    
bot1_option:
    #directly move to for strategy
    li $a0, 52
    li $a1, 5
    li $a2, 184
    li $a3, -1
    jal quickMoveTo

    li $a0, 40
    li $a1, 5
    li $a2, -1
    li $a3, 216
    jal quickMoveTo

    li $a0, 35
    li $a1, 5
    li $a2, 256
    li $a3, -1
    jal quickMoveTo

    li $a0, 35
    li $a1, 5
    li $a2, -1
    li $a3, 128
    jal quickMoveTo

    li $a0, 30
    li $a1, 5
    li $a2, -1
    li $a3, 64
    jal quickMoveTo

    loop_timer_bot1:
        li $a0, 5
        jal loop_solve_puzzle
        #timer 
        lw $t0, TIMER
        li  $t1, 10000000        #total cycles
        sub $t0, $t1, $t0        #cycles left
        li  $t1, 600000
        blt $t0, $t1, bot_1_last
        j loop_timer_bot1

    bot_1_last:
    #go left
    li $t0, 180
    sw $t0, ANGLE
    li $t0, 1
    sw $t0, ANGLE_CONTROL
    li $t0, 0x00040000
    sw $t0, POWERWASH_ON
    li $t0, 5
    sw $t0, VELOCITY   
    j  bot1_loop 
loop: # Once done, enter an infinite loop so that your bot can be graded by QtSpimbot once 10,000,000 cycles have elapsed
bot0_loop:
    lw $t0, VELOCITY
    beq $t0, $zero, set_velocity_bot0
    j bot0_loop
    set_velocity_bot0:
        li $t0, 0
        sw $t0, ANGLE
        li $t0, 1
        sw $t0, ANGLE_CONTROL
        li $t0, 5
        sw $t0, VELOCITY
	j   bot0_loop
        
bot1_loop:
    lw $t0, VELOCITY
    beq $t0, $zero, set_velocity_bot1
    j bot1_loop
    set_velocity_bot1:
        li $t0, 180
        sw $t0, ANGLE
        li $t0, 1
        sw $t0, ANGLE_CONTROL
        li $t0, 5
        sw $t0, VELOCITY
        j  bot1_loop
j loop
    

.kdata
chunkIH:    .space 40
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)        # Get some free registers
    sw      $v0, 4($k0)        # by storing them to a global variable
    sw      $t0, 8($k0)
    sw      $t1, 12($k0)
    sw      $t2, 16($k0)
    sw      $t3, 20($k0)
    sw      $t4, 24($k0)
    sw      $t5, 28($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 32($k0)
    mflo    $t0
    sw      $t0, 36($k0)

    mfc0    $k0, $13                # Get Cause register
    srl     $a0, $k0, 2
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt


interrupt_dispatch:                 # Interrupt:
    mfc0    $k0, $13                # Get Cause register, again
    beq     $k0, 0, done            # handled all outstanding interrupts

    and     $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt

    and     $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne     $a0, 0, timer_interrupt

    and     $a0, $k0, REQUEST_PUZZLE_INT_MASK
    bne     $a0, 0, request_puzzle_interrupt

    and     $a0, $k0, FALLING_INT_MASK
    bne     $a0, 0, falling_interrupt

    and     $a0, $k0, STOP_FALLING_INT_MASK
    bne     $a0, 0, stop_falling_interrupt

    li      $v0, PRINT_STRING       # Unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    j       done

bonk_interrupt:
    sw      $0, BONK_ACK
    la      $t0, has_bonked

    #Fill in your bonk handler code here
    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK
    #Fill your timer interrupt code here
    li      $t0, 1
    sb      $t0, 0($t6) #set timer interrupt flag
    j        interrupt_dispatch     # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
    #Fill in your puzzle interrupt code here
    li      $t0, 1
    sb      $t0, 0($t5) #set puzzle interrupt flag
    
    j       interrupt_dispatch

falling_interrupt:
    sw      $0, FALLING_ACK
    #Fill in your respawn handler code here

    j       interrupt_dispatch

stop_falling_interrupt:

    sw      $0, STOP_FALLING_ACK
    #Fill in your respawn handler code here
    li      $t0, 1
    sb      $t0, 0($t4) #set stop falling interrupt flag
    j       interrupt_dispatch

non_intrpt:                         # was some non-interrupt
    li      $v0, PRINT_STRING
    la      $a0, non_intrpt_str
    syscall                         # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    # Restore coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    lw      $t0, 32($k0)
    mthi    $t0
    lw      $t0, 36($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $t4, 24($k0)
    lw      $t5, 28($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret


# Below are the provided puzzle functionality.
.text
.globl is_attacked
is_attacked:
    li $t0,0 #counter i=0
    li $t1,0 #counter j=0
    
    move $t2,$a1 #counter N
    j forloopvertical
    
forloopvertical:
    bge $t0,$t2,forloophorizontal  # if i >= n move on to next for loop
    bne $t0,$a2,verticalcheck  #checking i != row, if i != row move onto next check
    add $t0,$t0,1  # incrementing i = i+1
    j forloopvertical # jump back to for
    
verticalcheck:
    mul $t3, $t0, 4     # convert index to offset address for row
    add $t4, $a0, $t3   # add offset to base address of board
    lw  $t5, 0($t4)     # load address of board[row(i)] in $t5, $t5 is pointing to the beginning of the char*
    add $t6, $t5, $a3   # add offset to base address of board[row(i)]
    lb  $t7, 0($t6)     # load board[row(i)][col] in $t7
    beq $t7,1,return1   # if board[i][col] == 1 return 1
    add $t0,$t0,1       # increment i = i+1
    j forloopvertical   # jump to for loop

forloophorizontal:
    bge $t1,$t2,resetiandjleft  # if j >= n move on to next for loop
    bne $t1,$a3,horizontalcheck  #checking j != col, if j != col move onto next check
    add $t1,$t1,1  # incrementing j = j+1
    j forloophorizontal # jump back to for
    
horizontalcheck:
    mul $t3, $a2, 4     # convert index to offset address for row
    add $t4, $a0, $t3   # add offset to base address of board
    lw  $t5, 0($t4)     # load address of board[row] in $t5, $t5 is pointing to the beginning of the char*
    add $t6, $t5, $t1   # add offset to base address of board[row]
    lb  $t7, 0($t6)     # load board[row][col(j)] in $t7
    beq $t7,1,return1   # if board[row][j] == 1 return 1
    add $t1,$t1,1       # increment j = j+1
    j forloophorizontal   # jump to for loop

resetiandjleft:
    li $t0,0    # i = 0
    li $t1,0    # j = 0
    j forleftdiagonal

forleftdiagonal:
    bge $t0,$t2,resetiandjright #for int i = 0; i <n; i++
    beq $t0,$a2,incrementileft # (i != row)
    
    sub $t3,$t0,$a2
    add $t1,$t3,$a3 #int j = (i-row) + col
    
    blt $t1,0,incrementileft # j>=0
    bge $t1,$t2,incrementileft # j < n
    
    mul $t3, $t0, 4     # convert index to offset address for row
    add $t4, $a0, $t3   # add offset to base address of board
    lw  $t5, 0($t4)     # load address of board[row] in $t5, $t5 is pointing to the beginning of the char*
    add $t6, $t5, $t1   # add offset to base address of board[row]
    lb  $t7, 0($t6)     # load board[row][col(j)] in $t7
    beq $t7,1,return1   # if board[row][j] == 1 return 1
    
    add $t0,$t0,1
    j forleftdiagonal

incrementileft:
    add $t0,$t0,1
    j forleftdiagonal
    

resetiandjright:
    li $t0,0
    li $t1,0
    j forrightdiagonal

forrightdiagonal:
    bge $t0,$t2,return0 #for int i = 0; i <n; i++
    beq $t0,$a2,incrementiright # (i != row)
    
    sub $t3,$a2,$t0
    add $t1,$t3,$a3 #int j = (row-i) + col
    
    blt $t1,0,incrementiright # j>=0
    bge $t1,$t2,incrementiright # j < n
    
    mul $t3, $t0, 4     # convert index to offset address for row
    add $t4, $a0, $t3   # add offset to base address of board
    lw  $t5, 0($t4)     # load address of board[row] in $t5, $t5 is pointing to the beginning of the char*
    add $t6, $t5, $t1   # add offset to base address of board[row]
    lb  $t7, 0($t6)     # load board[row][col(j)] in $t7
    beq $t7,1,return1   # if board[row][j] == 1 return 1
    
    add $t0,$t0,1
    j forrightdiagonal

incrementiright:
    add $t0,$t0,1
    j forrightdiagonal
    
return1:
    li $v0,1            # output 1
    jr $ra              # return

return0:
    li $v0,0            # output 0
    jr $ra              # return

.globl place_queen_step
place_queen_step:
    
    
    
    
    base:
        bne  $a3, 0, recursive
        li   $v0, 1
        jr   $ra
    
    recursive:
    
    sub $sp,  $sp, 32
    sw  $ra,  0($sp)
    sw  $s0,  4($sp)
    sw  $s1,  8($sp)
    sw  $s2,  12($sp)
    sw  $s3,  16($sp)
    sw  $s4,  20($sp)
    sw  $s5,  24($sp)
    sw  $s6,  28($sp)
    
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3
    mul  $s4, $s1, $s1
    move $s6, $s2  
    
    for:
        bge  $s6, $s4, end_for
        div  $a2, $s6, $s1
        mul  $a3, $a2, $s1
        sub  $a3, $s6, $a3
        if:
            sll  $s5, $a2, 2
            add  $s5, $s5, $s0
            lw   $s5, 0($s5)
            add  $s5, $s5, $a3
            lb   $t0, 0($s5)
            bne  $t0, 0, end_if
            
            move $a0, $s0
            move $a1, $s1
            jal  is_attacked
            bne  $v0, 0, end_if
            
            li   $t0, 1
            sb   $t0, 0($s5)
            inner_if:
                move  $a0, $s0
                move  $a1, $s1
                addi  $a2, $s2, 1
                sub   $a3, $s3, 1
                jal   place_queen_step
                bne   $v0, 1, end_inner_if
                li    $v0, 1
                
                lw  $ra,  0($sp)
                lw  $s0,  4($sp)
                lw  $s1,  8($sp)
                lw  $s2,  12($sp)
                lw  $s3,  16($sp)
                lw  $s4,  20($sp)
                lw  $s5,  24($sp)
                lw  $s6,  28($sp)
                add $sp, $sp, 32
                jr  $ra
            end_inner_if:
                li  $t0, 0
                sb  $t0, 0($s5)
        end_if:
        add  $s6, $s6, 1
        j    for
    end_for:
    
    li  $v0, 0
    lw  $ra,  0($sp)
    lw  $s0,  4($sp)
    lw  $s1,  8($sp)
    lw  $s2,  12($sp)
    lw  $s3,  16($sp)
    lw  $s4,  20($sp)
    lw  $s5,  24($sp)
    lw  $s6,  28($sp)
    add $sp, $sp, 32
    jr  $ra

.globl solve_queens
solve_queens:
sq_prologue:
    sub     $sp, $sp, 20
    sw      $s0, 0($sp)
    sw      $s1, 4($sp)
    sw      $s2, 8($sp)
    sw      $s3, 12($sp)
    sw      $ra, 16($sp)

    move    $s0, $a0
    move    $s1, $a1
    move    $s2, $a2
    move    $s3, $a3



sq_ll_setup:
    move    $t5, $a2        # $t5 is curr

sq_ll_for:
    beq     $t5, $0, sq_ll_end
    
    lw      $t6, 0($t5)         # $t6 = curr->pos
    div     $t0, $t6, $s1       # $t0 = row = pos / n
    rem     $t1, $t6, $s1       # $t1 = col = pos % n
    
    sll     $t3, $t0, 2             # $t3 = row * 4
    add     $t3, $t3, $s0           # $t3 = &board[row] = board + row * 4
    lw      $t3, 0($t3)             # $t3 = board[row]

    add     $t3, $t3, $t1           # $t3 = &board[row][col] = board[row] + col
    li      $t7, 1
    sb      $t7, 0($t3)             # board[row][col] = 1

    lw      $t5, 4($t5)             # curr = curr->next

    j       sq_ll_for

sq_ll_end:
    move    $a2, $0
    jal     place_queen_step        # call place_queen_step(sol_board, n, 0, queens_to_place)

sq_epilogue:
    lw      $s0, 0($sp)
    lw      $s1, 4($sp)
    lw      $s2, 8($sp)
    lw      $s3, 12($sp)
    lw      $ra, 16($sp)

    add     $sp, $sp, 20
    jr      $ra