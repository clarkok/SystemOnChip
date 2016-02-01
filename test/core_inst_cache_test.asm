    .text
    .ent init
init:
    lui     $t0,    %hi(exception_handler)
    addiu   $t0,    $t0,    %lo(exception_handler)
    mtc0    $t0,    4
    lui     $t0,    0x8000
    addiu   $t0,    $t0,    0x0002
    mtc0    $t0,    2
forever:
    lui     $a0,    %hi(SHARED)
    ll      $a1,    %lo(SHARED)($a0)
    nop
    addi    $a1,    $a1,    1
    sc      $a1,    %lo(SHARED)($a0)
    j       forever

    .ent add_loop
add_loop:
    lui     $a2,    %hi(SHARED)
    ll      $a3,    %lo(SHARED)($a2)
    nop
    addiu   $a3,    $a3,    -1
    sc      $a3,    %lo(SHARED)($a2)
    j       add_loop

    .ent exception_handler
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
    addiu   $s0,    $s0,    -4
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
SHARED:
    .4byte  (0)
