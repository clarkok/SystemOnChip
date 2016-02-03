init:
    addiu   $1,     $zero,  10
    addiu   $2,     $zero,  20
    mult    $1,     $2
    nop
    mflo    $1
    mflo    $2
    j       init
