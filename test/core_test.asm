init:
    lb      $1,     1($0)
    lh      $5,     3($4)
    lw      $9,     5($8)
    dd      0xC14B0006          #    ll      $11,    6($10)
    sb      $13,    7($12)
    sh      $15,    8($14)
    sw      $17,    9($16)
    dd      0xE253000A          #    sc      $19,    10($18)
    beq     $zero, $zero, fault
    j       init
fault:
    lb      $1,     5($0)
forever:
    j       forever
