init:
    addi    $1,     $0,     0x1234
    add     $2,     $1,     $0
    addu    $3,     $1,     $2
    sub     $4,     $1,     $3
    subu    $5,     $4,     $2
    slt     $6,     $4,     $1
    sltu    $7,     $4,     $1
    and     $8,     $4,     $1
    or      $9,     $4,     $1
    xor     $10,    $4,     $1
    nor     $11,    $4,     $1
    j       init
