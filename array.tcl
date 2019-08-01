#how to et an array om TCL


# proc stash {key array_name value} {
    # upvar $array_name a
    # set a($key) $value
    
    # #Printing the value of Array
    
    # parray a
# }

# stash one pvr 1
# stash two pvr 2
# array names pvr

#******************************************************************************************************************#

#To initialize an array, use "array set". If you want to just create the internal array object without giving it any values you can give it an empty list as an argument. 
#For example:

# array set foo {}

# array set foo {
    # one {this is element 1}
    # two {this is element 2}
# }

# parray foo



#********************************************************************************************************************#

#If you're looking to index things by number (which your code implies), use a list. It is analogous to an array in C.

# set mylist {}

# lappend mylist a
# lappend mylist b
# lappend mylist c
# lappend mylist d

# foreach elem $mylist {
    # puts "$elem"
# }
# #// or if you really want to use for
# for {set i 0} {$i < [llength $mylist]} {incr i} {
    # puts "${i}=[lindex $mylist $i]"
# }

#If you want to index things by string (or have a sparse list), you can use an array, which is a hashmap of key->value.

set myarr(chicken) animal
set myarr(cows) animal
set myarr(rock) mineral
set myarr(pea) vegetable

foreach key [array names myarr] {
    puts "${key}=$myarr($key)"
}