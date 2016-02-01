    .text
init:
    lui     $t0,    %hi(exception_handler)
    addiu   $t0,    $t0,    %lo(exception_handler)
    mtc0    $t0,    4
    lui     $t0,    0x8000
    addiu   $t0,    $t0,    0x0002
    mtc0    $t0,    2
forever:
    j       forever

add_loop:
    addi    $v0,    $v0,    1
    j       add_loop

exception_handler:
    addi    $t0,    $zero,  100
    lui     $t1,    0xFFFF
    sw      $t0,    0($t1)
    mfc0    $s0,    0
    lui     $k0,    %hi(CURRENT)
    lw      $k0,    %lo(CURRENT)($k0)
    lui     $k1,    %hi(PC_TABLE)
    sll     $k0,    $k0,    2
    add     $k1,    $k1,    $k0
    sw      $s0,    %lo(PC_TABLE)($k1)
    xori    $k1,    $k1,    4
    lw      $s0,    %lo(PC_TABLE)($k1)
    xori    $k0,    $k0,    4
    srl     $k0,    $k0,    2
    mtc0    $s0,    0
    lui     $k1,    %hi(CURRENT)
    sw      $k0,    %lo(CURRENT)($k1)
    eret

    .data
PC_TABLE:
LOOP_EPC:
    .4byte  (0)
ADD_EPC:
    .4byte  (add_loop)
CURRENT:
    .4byte  (0)
