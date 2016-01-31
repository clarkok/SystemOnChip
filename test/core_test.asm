init:
    beq     $zero,  $zero,  beq_token
    addi    $t1,    $zero,  1
beq_token:
    addi    $t2,    $zero,  1
    bne     $t1,    $t2,    bne_token
    addi    $v0,    $v0,    1
bne_token:
    bltz    $t1,    bltz_not_token
    addi    $v1,    $v1,    1
bltz_not_token:
    bgez    $t1,    bgez_token
    addi    $v0,    $v0,    1
bgez_token:
    j       init
