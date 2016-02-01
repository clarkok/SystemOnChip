j   init
j   except_handler
init:
    syscall
    break
    j       init

except_handler:
    addi    $v0,    $v0,    1
    eret
