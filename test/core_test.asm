init:
    addi    $1,     $0,     0x8765
    sll     $2,     $1,     1
    srl     $3,     $2,     1
    sra     $4,     $2,     1
    addi    $5,     $0,     2
    sllv    $6,     $1,     $5
    srlv    $7,     $2,     $5
    srav    $8,     $2,     $5
    j       init
