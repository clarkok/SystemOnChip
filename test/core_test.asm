init:
    addi    $1,     $zero,  10
    addiu   $2,     $1,     10
    slti    $3,     $1,     11
    sltiu   $4,     $1,     -9
    andi    $5,     $1,     0xFFFF
    ori     $6,     $5,     0xF0F0
    xori    $7,     $5,     0x0F0F
    j       init
