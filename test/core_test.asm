init:
    addi    $a0,    $zero,  0
    jal     func0
    addi    $a0,    $zero,  1
    jal     func0
    j       init

func0:
    sll     $t0,    $a0,    2
    lui     $t1,    %hi(JUMP_TABLE)
    lw      $t2,    %lo(JUMP_TABLE)($t0)
    move    $k0,    $ra
    jalr    $ra,    $t2
    jr      $k0

func1:
    addi    $v0,    $zero,  1
    jr      $ra

func2:
    addi    $v0,    $zero,  2
    jr      $ra

    .section .rodata
JUMP_TABLE:
    .4byte  (func1)
    .4byte  (func2)
