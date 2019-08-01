#===============================================================================
# Start point
#===============================================================================

proc clean {path} {
    
    set home $path
    # set list [glob -nocomplain -directory "$home" *]
    set list [glob -nocomplain -directory "$home" -type d *]
    puts "$list"

    foreach val $list {
     set val_list [file tail $val]
     #puts $val_list
     if {$val_list == "log"} {
        puts "found log directoy"     
     }     else {
        set error [catch {file delete -force $val_list}]
        puts "\n removing directory $val_list ...\n"
     }
    }
    return 1;
}

set home [file dirname [file normalize [info script]]]
clean $home