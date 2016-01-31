init:
    addi    $t0,    $zero,  15
    addi    $t1,    $zero,  -15
    mult    $t0,    $t1
    addi    $t2,    $zero,  15
    addi    $t3,    $zero,  -15
    mfhi    $t4
    mflo    $t5
    multu   $t2,    $t3
    nop
    nop
    mfhi    $t6
    mflo    $t7
    mthi    $zero
    mtlo    $zero
    j       init
