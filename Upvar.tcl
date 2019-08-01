set x 10

proc proc1 {} {
    upvar 2 20 y
    puts "1. before:$y"
    # set y 20
    puts "1. after:$y"
    # set y 10
}

proc proc2 {} {
    upvar x z
    puts "2. before:$z"
    set z 30
    puts "2. after:$z"
    set z 10
}

proc proc3 {} {
    set x 50
    proc proc4 {} {
        # set a 100
        upvar #1 x a
        puts "3.1. before:$a"
        set a 30
        puts "3.2. after:$a"
    }
    proc4
}

# puts "1. x:$x"
# proc1
# puts "2. x:$x"
# proc2
# puts "3. x:$x"
proc3