proc test_getConnectionSetup {arrayname dataSource modelFileDirectory} {
    upvar $arrayname def
    getConnectionSetup $arrayname $dataSource $modelFileDirectory
    return [array get $arrayname]
}
proc dropAll {category} {
    unsetInfo all
}
proc diffArray2 {names a b} {
    array set A $a
    array set B $b
    set AnotB ""
    set BnotA ""
    set DIFF ""
    foreach n $names {
        if [catch {set v $A($n)}] {
            set v NULL
            lappend BnotA "$n $v"
        }
        if {![info exists B($n)] } {
            lappend AnotB "$n NULL"
            set B($n) "NULL"
        }
        if {$B($n) != $v} {
            catch {regexp $B($n) $v} d
            if {$d != 1} {
                lappend DIFF "$n $v $B($n)"
            }
        }
    }
    return [list $AnotB $BnotA $DIFF]
}
proc diffArray {a b} {
    array set A $a
    array set B $b
    set AnotB ""
    set BnotA ""
    set DIFF ""
    foreach {n v} [array get A] {
        if {! [info exists B($n)] } {
            lappend AnotB "$n $v"
        } elseif {$B($n) != $v} {
            catch {regexp $B($n) $v} d
            puts "d = $d"
            if {$d != 1} {
                lappend DIFF "$n $v $B($n)"
                #error $d
            }
        }
    }
    foreach {n v} [array get B] {
        if {![info exists A($n)] } {
            lappend BnotA "$n $v"
        }
    }
    return [list $AnotB $BnotA $DIFF]
}

# Array Compare Function return difference in list
proc cmpArray { ary1 ary2 } {
    upvar $ary1 a1
    upvar $ary2 a2

    set ilist1 [array names a1]
    set ilist2 [array names a2]

    foreach idx $ilist1 {
        # Make sure ary2 HAS this element!
        if {![info exists a2($idx)]} {
            # We don't have this element so...
            continue
        }

        if {$a1($idx) != $a2($idx)} {
            # They are not the same!
            lappend retn_list $idx
        }
    }
    if {![info exists retn_list]} {
        # There ARE no differences so return an empty list
        set retn_list ""
        #set retn_list [list {}]
    }
    return $retn_list
}

# Proc to return temp array of dbCompare.tcl
proc tempArray {} {
    source dbCompare.tcl
    set argv "Mod3000 TEST24_P/TEST24_P@cic-svr-db09-site cert200.txt"
    set argv0 "dbcompare.tcl"
    if {[info exists argv0] && [string tolower [file tail $argv0]] == "dbcompare.tcl"} {
        set DBCstartTime [clock seconds]
        setInfo DBCstartTime $DBCstartTime
        if [catch {set argv [p_getParams  $argv]}  arg] {
            puts "Incorrect input:\n\t $arg"
            dbCompareCorrectUsage $argv0

            exit 1
        }

        if {[catch {set argv [correctArgs [llength $argv] $arg]}]} {
          puts "Incorrect input:\n\t $arg"
            dbCompareCorrectUsage $argv0

            exit 1
        }
        setInitialArrays
        set tdbh        [lindex $argv 1]
        set report      [lindex $argv 2]
        set dir         [file dir $report]
        set report      [file tail $report]
        set model       [lindex $argv 0]
        setInfo silent  [lindex $argv 3]
        set TABLES       [getInfo TABLES]
        setInfo REPORT $report
        setInfo connectString       $tdbh
        setInfo outDir "$dir"
        getConnectionSetup modelDef $model [getInfo MODEL_FILES_DIRECTORY]
        getConnectionSetup targetDef $tdbh [getInfo MODEL_FILES_DIRECTORY]
    # TODO move to another proc
        if [catch {dbCompare $model $tdbh $report $TABLES} results] {
            puts "ERROR: $results $::errorInfo"
            catch {logoff $tdbh}
            set fid [open dbcCore.txt w]
            puts $fid [showArray targetDef]
            puts $fid "**************"
            puts $fid [showArray modelDef]
            close $fid
            exit 1
        }
        if {$results != 0} {
            array set RESULTS [getInfo RESULTS]
        } else {
        array set RESULTS [setNullResults]
        updateInfo RESULTS [array get RESULTS]
        }
    }
    return [array get RESULTS]
}

proc setDefaultArray {model target modelconnection tdbh {type all}} {
    # modelDef and targetDef will not be in scope of this proc unless upvared
    upvar $model modelDef
    upvar $target targetDef
    setInitialArrays
    getConnectionSetup modelDef $modelconnection [getInfo MODEL_FILES_DIRECTORY]
    getConnectionSetup targetDef $tdbh [getInfo MODEL_FILES_DIRECTORY]
    getMetaDataSource modelDef targetDef
    array set modelDef [getMetaData [getInfo dbCompare.modelDef.metaSourceLocation] $type [getInfo dbCompare.modelDef.metaSource]]
    setInitialNulls modelDef
    setDefaultMeta modelDef
    setInfo DEF.TYPES $modelDef(DEF.TYPES)
    array set targetDef [getMetaData [getInfo dbCompare.targetDef.metaSourceLocation] $type [getInfo dbCompare.targetDef.metaSource]]
    setInitialNulls targetDef

}

# ##########
# @proc compare2Files
# @ returns the result of comparison of content of 2 files
# ##########
# @author Mohit Uniyal
# @param file1 :the first file
# @param file2 :the second file
# @exception none
# @see none
# @return -1 if either or both the files do not exist, 0 if no difference is found, 1 if some difference exists
# ##########
proc compare2Files {file1 file2} {
    if {[file exists $file1] && [file exists $file2]} {
        set fptr1 [open $file1 r]
        set fptr2 [open $file2 r]
        set fLines1 [split [string trim [read $fptr1]] "\n"]
        set fLines2 [split [string trim [read $fptr2]] "\n"]
        close $fptr1
        close $fptr2
        foreach line1 $fLines1 line2 $fLines2 {
            if {$line1 != $line2} {return 1}
        }
        return 0
    } else {
        return -1
    }
}

# @proc getSchemaName
# If schema not present in the schema List get it from schema pool
# @author Tarun Arya
# @param schemaVersion :schema version e.g. 03010100
# @param server :full server name e.g. cic-svr-db09-site
# @return schema string e.g. test/test@cic-svr-db09-site

proc getSchemaName {filename schemaVersion server} {
    if {![file exists $filename]} {
        set fid [open $filename w]
        close $fid
    }
    array set schemaList ""
    source $filename
    # if schema not present in the schema List get it from schema pool
    if {![info exists schemaList($schemaVersion)]} {
        set schemaName [getSchema $schemaVersion $server]
        if {$schemaName != -1} {
            # set targetInputParam "$schemaName/$schemaName@$server"
            # write schema name in file for future use
            set fp [open "$filename" a]
            puts $fp "set schemaList($schemaVersion) $schemaName"
            close $fp
            return "$schemaName/$schemaName@$server"
        } else {return $schemaName}
    } else {
        return "$schemaList($schemaVersion)/$schemaList($schemaVersion)@$server"
    }
}
proc getPKNames {names} {
    set nameList [split $names]
    return [split [lindex $nameList 1] "!"]
}
proc getColNames {names} {
    set nameList [split $names]
    return [split [lindex $nameList 2] "!"]
}
proc getPKVals {values} {
    regexp {^[^#]+} $values valueList 
    regsub  -all {!!!} $valueList ` valueList
    return [split $valueList "`"]
}
proc getColVals {values} {
    regexp {###.*} $values valueList 
    set valueList [string trimright [string range $valueList 3 end]]
    regsub  -all {!!!} $valueList ` valueList
    return [split $valueList "`"]
}