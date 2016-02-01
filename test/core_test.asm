init:
    mfc0    $t0,    1
    nop
    addi    $t0,    $t0,    1
    mtc0    $t0,    1
    j       init
