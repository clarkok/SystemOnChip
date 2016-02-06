init:
    lui     $t1,    0xC000
loop:
    sw      $t1,    0($t1)
    addiu   $t1,    $t1,    4
    j       loop
