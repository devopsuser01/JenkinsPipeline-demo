package require xml
package require dom::tcl
source "C:\\svn_local\\releng\\trunk\\package\\scripts\\XMLprocs.tcl"
source launch_build.tcl
# proc GetTableInfo {tabPrefix svn_local svn_remote svn_base} {
    # if [file exists [file join $svn_local $svn_base]] {
        # exec svn update [file join $svn_local $svn_base Data]
    # } else {
        # exec svn co $svn_remote$svn_base/Data@HEAD [file join $svn_local $svn_base Data]
    # }
    # file copy [file join $svn_local $svn_base Data Source txt $tabPrefix.txt] working/123456/Data/Source/txt ;# pass in as param
    # array set foo [parseSQLfile [catl [file join $svn_local $svn_base Data Source sql $tabPrefix.sql]]]
    # if {1 == 1} {
        # puts "<br>columnList: $columnList"
        # return [array get foo]
    # } else {
        # todo - add functionality to handle new tables
               # add page for user to enter table columns
               # for system data.
        # return [list -1 "Information for table $tabPrefix does not exist yet or this is an invalid table.  If request is valid, Inform RE to create $tabPrefix.sql file."]
    # }
# }
proc getSysDataSources {arrayName baseURL svn_local svnBranch workingDir modFileName tabPrefix} { 
    upvar $arrayName temp
    set localBase $svn_local/$svnBranch
    if [file exists [file join $svn_local $svnBranch]] {
        catch {exec svn revert -R [file join $localBase Data] }
        catch {exec svn revert -R [file join $localBase DDL/ModelFiles] }
        catch {exec svn revert -R [file join $localBase Tools] }
        exec svn update [file join $localBase Data]
        exec svn update [file join $localBase DDL/ModelFiles]
        exec svn update [file join $localBase Tools] 
    } else {
        exec svn co $baseURL/$svnBranch@HEAD $localBase
    }
    set temp(REPO_MODELFILE_DIR) [file join $localBase Data/ModelFiles]
    set temp(REPO_SQL_DIR) $localBase/Data/Source/sql
    file delete -force $workingDir/Data/Source
    file delete -force $workingDir/Models
    file mkdir $workingDir/Data/Source/sql
    file mkdir $workingDir/Data/Source/txt
    file mkdir $workingDir/Models/$modFileName
    set temp(WORKING_TXT_DIR) $workingDir/Data/Source/txt
    set temp(WORKING_SQL_DIR) $workingDir/Data/Source/sql
    set temp(WORKING_MOD_DIR) $workingDir/Models/$modFileName
    # file mkdir Tools
    set tabPrefix [string tolower $tabPrefix]
    file copy -force $localBase/Tools/sysDataGen.tcl $workingDir/sysDataGen.tcl
    set temp(WORKING_SDG) $workingDir/sysDataGen.tcl
    file copy -force $localBase/Tools/common_utilities.tcl $workingDir/common_utilities.tcl
    file copy -force $localBase/DDL/ModelFiles/MODEL_VERSION $workingDir/Models/$modFileName/MODEL_VERSION
    set temp(WORKING_VERSION_FILE) $workingDir/Models/$modFileName/MODEL_VERSION
    set temp(REPO_TOR_TABLE) $localBase/DDL/ModelFiles/TOR_TABLE_ORDER
    set fn $tabPrefix.sql
    file copy -force $localBase/Data/Source/sql/$fn $workingDir/Data/Source/sql/$fn
    set temp(WORKING_SQL_FILE) $workingDir/Data/Source/sql/$fn
    set dfn $tabPrefix.txt
    file copy -force $localBase/Data/Source/txt/$dfn $workingDir/Data/Source/txt/$dfn
    set temp(REPO_TXT_FILE) $localBase/Data/Source/txt/$dfn
    set temp(REPO_TXT_DIR) $localBase/Data/Source/txt
    set temp(WORKING_TXT_FILE) $workingDir/Data/Source/txt/$dfn
}
package require RE
proc generateSelectFromTrunk {arrayName tableName columnNames} {
    upvar $arrayName A
    set A(SELECT_QUERY) $columnNames 
    set A(INSERT_QUERY) $columnNames
    switch $tableName {
        "SRU_SECURITY_RESOURCE" {
            set i [lsearch $columnNames SRU_SRU_UID_PARENT]
            set A(SELECT_QUERY) [lreplace $A(SELECT_QUERY) $i $i "(SELECT SRU_ID || ',' || SRU_RESOURCE_TYPE from SRU_SECURITY_RESOURCE WHERE SRU_UID = $A(tabPrefix).SRU_SRU_UID_PARENT)"] 
            set A(INSERT_QUERY) [lreplace $A(INSERT_QUERY) $i $i  "SELECT SRU_UID from SRU_SECURITY_RESOURCE where SRU_ID || ''',''' || SRU_RESOURCE_TYPE"]
        }
        "SPV_SECURITY_PRIVILEGE" {
            set i [lsearch $columnNames SPV_SRU_UID]
            set A(SELECT_QUERY) [lreplace $A(SELECT_QUERY) $i $i "(SELECT SRU_ID || ',' || SRU_RESOURCE_TYPE from SRU_SECURITY_RESOURCE WHERE SRU_UID = SPV.SPV_SRU_UID)"]
            set A(INSERT_QUERY) [lreplace $A(INSERT_QUERY) $i $i  "SELECT SRU_UID from SRU_SECURITY_RESOURCE where SRU_ID || ',' || SRU_RESOURCE_TYPE"]
            set i [lsearch $columnNames SPV_SPF_UID]
            set A(SELECT_QUERY) [lreplace $A(SELECT_QUERY) $i $i "(SELECT SPF_ID from SPF_SECURITY_PROFILE WHERE SPF_UID = SPV.SPV_SPF_UID)"]
            set A(INSERT_QUERY) [lreplace $A(INSERT_QUERY) $i $i  "SELECT SPF_UID from SPF_SECURITY_PROFILE WHERE SPF_ID"]
        }
        "UPL_USER_PROFILE_LINK" {
            set i [lsearch $columnNames UPL_SPF_UID]
            set A(SELECT_QUERY) [lreplace $A(SELECT_QUERY) $i $i  "(SELECT SPF_ID from SPF_SECURITY_PROFILE where SPF_UID = UPL.UPL_SPF_UID)"]
            set A(INSERT_QUERY) [lreplace $A(INSERT_QUERY) $i $i  "SELECT SPF_UID from SPF_SECURITY_PROFILE where spf_uid"]
            set i [lsearch $columnNames UPL_USR_UID]
            set A(SELECT_QUERY) [lreplace $A(SELECT_QUERY) $i $i  "(SELECT USR_ID from USR_USER where USR_UID = UPL.UPL_USR_UID)"]
            set A(INSERT_QUERY) [lreplace $A(INSERT_QUERY) $i $i  "SELECT USR_UID from USR_USER where USR_ID"]
        }
    }
}

proc getSpecialColumnValues {columnName} {
    set rval "99"
    switch -glob [string toupper $columnName] {
        "*RECORD_VERSION" {set rval 0}
        "*USR_UID_UPDATED_BY" {set rval "''"}
        "*LAST_UPDATE_DATE"    {set rval "''"}
        "*USR_UID_CREATED_BY" {set rval -4}
        "*CREATE_DATE"          {set rval sysdate} 
        "*SYSTEM_YN"        {set rval 'Y'}
        "*RECORD_STATUS_DATE" {set rval sysdate}
    }
    # puts "returning $rval for $columnName"
    return $rval
}

proc setTableName {arrayName} {
    upvar $arrayName A
    set proto [logon $A(PROTO)]
    set tab_name ""
    set sql_statement "select table_name into :tab_name from user_tables where table_name like '$A(tabPrefix)%'"
    execsql use $proto $sql_statement
    if {$tab_name == ""} {
        set A(TABLE_NAME) $A(tabPrefix)
    } else {
        set A(TABLE_NAME) $tab_name
    }
    logoff $A(PROTO)
}

proc populateInfoArray {arrayName inputStr} {
    upvar $arrayName A
    # puts $A(logFile) "In pop Arr: $inputStr"
    set splitchar \u0080
    set inputStr [string trimleft $inputStr "\\"]
    set inputStr [string trimleft $inputStr "\("]
    set inputStr [string trimright $inputStr "\)"]
    set inputStr [string trimright $inputStr "\\"]
    set substring "\\\}\\\{"
    # puts $A(logFile) "Input str: $inputStr"
    set inputList [split [string map [list $substring $splitchar] $inputStr] $splitchar]
    # puts $A(logFile) "Post-processing input list: $inputList"
    foreach inputVal $inputList {
        if {$inputVal != ""} {
            regsub {(.*)::::(.*)} $inputVal {\1} name
            regsub {(.*)::::(.*)} $inputVal {\2} value
            set name [string trim $name]
            set value [string trim $value]
            if {$name != "logFile"} {
                # puts $A(logFile) "Decoded Name -> $name\nDecoded value -> $value"
                set A($name) $value
            }
        }
    }
}

proc generateInsert2 {arrayName dev proto} {
    upvar $arrayName A
    set base $A(SVN_LOCAL)/$A(branch)
    set A(tabPrefix) [string toupper $A(tabPrefix)]
    set sql "select TABLE_NAME, COLUMN_NAME into :tableName, :columnNames from USER_TAB_COLUMNS where table_name = '$A(TABLE_NAME)'"
    # puts $sql
    execsql use $proto $sql
    # puts "columns = $columnNames"
    # array set A [parseSQLfile [catl $base/Data/Source/sql/[string tolower $A(tabPrefix)].sql]]
    # set tableName [lindex $tableName 0]
    # set A(columnNames) $columnNames
    set valPointers [string tolower $columnNames]
    #generate the select statement
    generateSelectFromTrunk A $A(TABLE_NAME) $columnNames
    set sql "select [join $A(SELECT_QUERY) ","] into :[join $valPointers ",:"] from $A(TABLE_NAME) $A(tabPrefix) where [join $A(KEY_COLUMNS) "||','||"] in ('[join $A(INSERT_DATA) ',']')"
    # puts "<br>SQL- $sql<br>"
    catch {execsql use $dev $sql} output
    set baseSQL "INSERT INTO $A(TABLE_NAME) $A(tabPrefix) ([join $columnNames ","]) values ("
    # get the number of rows and loop through each
    set A(insertSQL) ""
    set i 0
    set end [llength [set [lindex $valPointers 0]]]
    while {$i < $end} {
        set dataSQL ""
        foreach valName $valPointers Q $A(INSERT_QUERY) {
            if {[string toupper $valName] == $Q} {
                # cols we want to control values like _USR_UID_UPDATED_BY  some will be "" none will be 99
                if {[set val [getSpecialColumnValues $valName]] != "99"} {
                    lappend dataSQL $val
                } else {
                    regsub -all {'} [lindex [set $valName] $i] "''" val
                        lappend dataSQL "'$val'"
                }
            } else {
                regsub -all {'} [lindex [set $valName] $i] "''" val
                lappend dataSQL [join "($Q = '$val')"]
            }
            # puts "valName = $valName val = $val"
        }
        lappend A(insertSQL) "$baseSQL [join $dataSQL ","])"
        incr i
     }
     #todo return value to force redraw of entryForm (at return to makeform
     if {$A(insertSQL) == ""} {
        puts "<br>! no data found !<br>"
     } else {
        set uniqueKey [lindex $A(UNIQUE) 0]
        set ukeySQL "select $uniqueKey into :uniqueData from $A(TABLE_NAME) where $A(KEY_COLUMNS) in ('[join $A(INSERT_DATA) ',']')"
        execsql use $dev $ukeySQL
        set A(revertInsertSQL) "delete from $A(TABLE_NAME) where $uniqueKey in ('[join $uniqueData ',']')"
     }
} 
proc insertData {proto SQL} {
    foreach sql $SQL {
        if {[catch {execsql use $proto $sql} err] || $err < 0} {
            execsql use $proto "rollback"
            puts "<br><h2>An sql error occured: please check your data.</h2><br>[getinfo all]<br>SQL: $sql<br>"
            #return -1
            return $err
        }
        # puts "<br>sql= $sql <br>err was $err"
    }
    execsql use $proto "commit"
    return 0
}
proc generateRollbackInsert {arrayName proto column data} {
    upvar $arrayName A
    set A(tabPrefix) [string toupper $A(tabPrefix)]
    set sql "select TABLE_NAME, COLUMN_NAME into :tableName, :columnNames from USER_TAB_COLUMNS where table_name = '$A(TABLE_NAME)'"
    execsql use $proto $sql
    set valPointers [string tolower $columnNames]
    #generate the select statement
    generateSelectFromTrunk A $A(TABLE_NAME) $columnNames
    set sql "select [join $A(SELECT_QUERY) ","] into :[join $valPointers ",:"] from $A(TABLE_NAME) $A(tabPrefix) where $column = '$data'"
    catch {execsql use $proto $sql} output
    set baseSQL "INSERT INTO $A(TABLE_NAME) $A(tabPrefix) ([join $columnNames ","]) values ("
    # get the number of rows and loop through each
    set i 0
    set A(insertSQL) ""
        set dataSQL ""
        foreach valName $valPointers Q $A(INSERT_QUERY) {
            if {[string toupper $valName] == $Q} {
                # cols we want to control values like _USR_UID_UPDATED_BY  some will be "" none will be 99
                if {[set val [getSpecialColumnValues $valName]] != "99"} {
                    lappend dataSQL $val
                } else {
                    regsub -all {'} [lindex [set $valName] $i] "''" val
                        lappend dataSQL "'$val'"
                }
            } else {
                regsub -all {'} [lindex [set $valName] $i] "''" val
                lappend dataSQL [join "($Q = '$val')"]
            }
        }
    lappend A(revertDeleteSQL) "$baseSQL [join $dataSQL ","])"
}
proc validateCurrentData {dbh sdgFile txtDir sqlDir torFile outDir prd_id versionDots} {
    makeDataModel $txtDir $sqlDir $outDir $torFile $prd_id $versionDots
    source $sdgFile
    puts "<BR> Executing SysDataGen It may take few seconds ... "
    puts "<BR>"
    catch {sysDataGen $dbh "" [file tail $outDir] "./" "no" "no" 0} rval
    return $rval
}
proc processGetSystemData {arrayName dbh expectedDeltaCount localBase tabPrefix modFileName prd_id versionDots} {
    #get items
    upvar $arrayName delta
    # file mkdir Tools
    set tabPrefix [string tolower $tabPrefix]
    getData $dbh $delta(WORKING_SQL_FILE) $delta(WORKING_TXT_DIR)
    # puts "repo = $delta(REPO_TXT_FILE) working = $delta(WORKING_TXT_FILE)"
    array set delta [compareCodesAddDropUpdate $delta(WORKING_TXT_FILE)  $delta(REPO_TXT_FILE)]
    puts "inserts = $delta(INSERTS) dropt = $delta(DELETES) upd = $delta(UPDATES)<br>" 
    set delta($tabPrefix.SQL) [generateSQL $delta(TABLE_NAME) $delta(KEY_COLUMNS) $delta(UNIQUE) $delta(COLUMNS) $delta(INSERTS)] 
    puts "<BR>"
    puts "<br>Sql Query is $delta($tabPrefix.SQL)"
    if {$delta(CHANGE_COUNT) != $expectedDeltaCount} {
        puts "<h2>There are changes to table $tabPrefix that you didn't ask for: <br> </h2>[join $delta(INSERTS) "<br>"] expected $expectedDeltaCount got [llength $delta($tabPrefix.SQL)] <br>"
        markAsFailed "There are changes to table $tabPrefix that you didn't ask for: [join $delta(INSERTS)]. expected $expectedDeltaCount got [llength $delta($tabPrefix.SQL)]"
        #return "-1"
    }
    file copy -force $delta(workingDir)/Data/Source/txt/$tabPrefix.txt $localBase/Data/Source/txt/$tabPrefix.txt
    return 0
}
 
proc runsysDataGenTest {dbconnection workingDir svnSource modFileName} {
    set here [pwd]
    cd $workingDir
        file delete -force Models/
        file mkdir Models/$modFileName
        file copy $svnSource/Data/ModelFiles/NAMES.txt Models/$modFileName/NAMES.txt
    file copy $svnSource/Data/ModelFiles/VALUES.txt Models/$modFileName/VALUES.txt
    file copy $svnSource/Data/ModelFiles/WHERE.txt Models/$modFileName/WHERE.txt  
file copy $svnSource/DDL/ModelFiles/MODEL_VERSION Models/$modFileName/MODEL_VERSION    
        file copy -force $svnSource/Tools/sysDataGen.tcl ./sysDataGen.tcl
        file copy -force $svnSource/Tools/common_utilities.tcl .
        source sysDataGen.tcl
        set dbh [logon $dbconnection]
        puts "<BR> Executing SysDataGen It may take few seconds ... "
        puts "<BR>"
        set rval [sysDataGen $dbh "" $modFileName "./" "no" "no" 0]
        logoff $dbh
    cd $here
    return 0
}
# array set delta [compareCodesAddDropUpdate  {C:\svn_local\releng\trunk\PBS\Epic1\Data\Source\txt\sru.txt} {C:\opt\Tomcat\Tomcat7\webapps\ROOT\site\sdr\working\SRU123456\Data\Source\txt\sru.txt}]
proc generateSQL {table key_name_lst conscols column_name_lst insertData} {
    array set foo ""
    set i 0
    foreach c $key_name_lst {
        set foo($c) $i
        incr i
    }
    # puts "$key_name_lst"
    # puts $conscols
    # puts $insertData
    set columns ""
    foreach c $column_name_lst {
        set foo($c) $i
        if {[lsearch $conscols $c ] < 0} {
            lappend columns $c
        } 
        incr i
    }
    set pkcols "[join $key_name_lst ","]"
    set ucols [join $conscols ","]
    set ccols [join $columns ","]
    set insertSQL_lst ""
    foreach rowData $insertData {
    set rowitems ""
        set insert_sql "LANDA_CONVERSION.INSERT_DATA_UNIQUE('$table',"
        foreach c $pkcols {
            lappend rowitems [lindex $rowData $foo($c)]
        }
        append insert_sql "'$pkcols','[join  $rowitems "'',''"]',"
        set rowitems ""
        foreach c $conscols {
            lappend rowitems [lindex $rowData $foo($c)]
        }
        append insert_sql "'$ucols','[join  $rowitems "'',''"]',"
        set rowitems ""
        foreach c $columns {
            lappend rowitems [lindex $rowData $foo($c)]
        }
        append insert_sql "'$ccols','[join $rowitems "'',''"]');"
        lappend insertSQL_lst $insert_sql
    }
    return $insertSQL_lst
}
# @author       Tarun Arya (P20)
# @description  This proc will generate Delete Query in Landa format
# @since        10/10/2016
# @see          N/A
# @param        infoArray proto (DBH for proto schema)
# @return       It will set Delete query in global Array
# @exception    On exception on SQL Query do rollback

proc generateDelete {infoArray proto} {
    upvar $infoArray info
    set deleteData ""
    set deleteSql ""
    set columnsData [split $info(DELETE_DATA) ","]
    set len [llength $columnsData]
    set counter 0
    set sql "DELETE FROM $info(TABLE_NAME) WHERE "
    foreach columns $columnsData {
        set counter [expr $counter + 1]
        set data [split $columns "="]
        set columnName [string trim [lindex $data 0]]
        if {[lsearch $info(UNIQUE) $columnName] < 0} {
            puts "Column Name $columnName you entered is not a Unique Column. Please enter correct column name"
            return -1
        }
        regsub -all {\s+} [string trim [lindex $data 1]] ',' deleteData
        generateRollbackInsert info $proto $columnName $deleteData
        set sql1 "$columnName IN ('$deleteData')"
        if {$counter < $len} {
            append sql "$sql1 and "
        } else {
            append sql $sql1
        }
    }
	set info(deleteSQL) $sql
    if {[catch {execsql use $proto $sql} err] || $err < 0} {
        execsql use $proto "rollback"
        puts "An sql error occured while deleting data: please check your data.[getinfo all] SQL: $sql"
        return -1
    }
    set deleteSql "LANDA_CONVERSION.RUN_DML ('$sql');"
    set info($info(tabPrefix).Delete.SQL) $deleteSql
    return $deleteSql
}

proc splitModelLine {line } {
    set line [splat $line "###"]
    set vals [concat [splat [lindex $line 0] "!!!"] [splat [lindex $line 1] "!!!"] ]
    return $vals
}
proc compareCodesAddDropUpdate {newlist current} {
    set adds ""
    set drops ""
    set updates ""
    set a [catl $newlist]
    set b [catl $current]
    set d ""
    set akeys ""
    set avals ""
    set changecount 0

    foreach line $a {
        set line [splitModelLine $line]
        lappend akeys [lindex $line 0]
        lappend avals [lrange $line 1 end]
    }
    # puts "a=[llength $akeys]"
    set bkeys ""
    set bvals ""
    foreach line $b {
        set line [splitModelLine $line]
        lappend bkeys [lindex $line 0]
        lappend bvals [lrange $line 1 end]
    }
    # puts "b=[llength $bkeys]"
    set i 0
    while {$i < [llength $akeys]} {
        set ka [lindex $akeys $i]
        if {[set bi [lsearch $bkeys $ka]] < 0} {
            lappend adds [concat [lindex $akeys $i] [lindex $avals $i]]
            incr changecount
        } else {
            if {[lindex $avals $i] != [lindex $bvals $bi] } {
                lappend updates  [concat [lindex $akeys $i] [lindex $avals $i]]
                incr changecount
            }
        }
        incr i
    }
    set i 0
    while {$i < [llength $bkeys]} {
        set kb [lindex $bkeys $i]
        if {[set bi [lsearch $akeys $kb]] < 0} {
            lappend drops  [concat [lindex $bkeys $i] [lindex $bvals $i]]
            incr changecount
        } 
        incr i
    }
    # puts "vals= $updates $adds $drops"
    return [list UPDATES $updates INSERTS $adds DELETES $drops CHANGE_COUNT $changecount]
}
proc GetInClause {dataList} {
    # take the dataList provided and return a sql "in" clause
    # need to find out if we received a list or a single item
    if {[llength $dataList] > 0} {
        foreach dataItem $dataList {
            regsub -all {[,']} $dataItem "" newDataItem
            lappend info(dataList) '$newDataItem'
        }
        set retVal ([join $info(dataList) ", "])
    } else {
        set retVal 0
    }
    return $retVal
}

proc GetInserts {infoArray tableName columnList primaryKey dataList} {
    upvar $infoArray info
    # use the columnsList tableName and dataList to generate insert statements
    set createdBy [string range $tableName 0 2]_USR_UID_CREATED_BY
    set createDate [string range $tableName 0 2]_CREATE_DATE
    set index 0
    for {set colInd 0} {$colInd < [llength [lindex $dataList 0]]} {incr colInd} {
        set tempDataRow ""
        foreach dataColumn $dataList {
            if {[lindex $dataColumn $colInd] == "null"} {
                set tempDataRow [concat $tempDataRow [lindex $dataColumn $colInd]]
            } else {
                set tempDataRow [concat $tempDataRow \"'[lindex $dataColumn $colInd]'\"]
            }
        }
        lappend sqlInserts "insert into $tableName ($primaryKey, [join $columnList ", "], $createdBy, $createDate) values ([join $tempDataRow ", "], -4, SYSDATE)"
    }
    return $sqlInserts
}

proc GetUpdates {infoArray tableName columnList primaryKey dataList} {
    upvar $infoArray info
    # use the columnsList tableName and dataList to generate insert statements
    set updatedBy [string range $tableName 0 2]_USR_UID_UPDATED_BY
    set updateDate [string range $tableName 0 2]_LAST_UPDATE_DATE
    set newColumnList [concat $primaryKey $columnList]
    set index 0
    set updateRow ""
    foreach column $newColumnList data $dataList {
        if {$data == "null"} {
            append updateRow "$column = '', "
        } else {
            append updateRow "$column = '$data', "
        }
    }
    set sqlUpdates "update $tableName set $updateRow $updatedBy = -4, $updateDate = SYSDATE where $primaryKey = '[lindex $dataList 0]'"
    return $sqlUpdates 
}

proc WrapRunDml {sqlStatement} {
    # take input as a single sql statement and wrap it in the RUN_DML sql
    set front "LANDA_CONVERSION.RUN_DML('"
    set back "');"
    regsub -all ' [string trim [string trim $sqlStatement \;]] '' quoteSqlStatement
    return $front$quoteSqlStatement$back
}

proc GetDataFromSchema {infoArray login tableName columnList primaryKey whereClause} {
    upvar $infoArray info

    # set database connection info
    set dbh [logon $login]
    if {![regexp {oratcl.+} $dbh]} {
        set info(errorMessage) "Cannot log into $login."
        MakeForm info dva
        exit
    }
    
    # setup sql formatting for selecting the columns into variable
    # We are using -123456 because of an issue with the OTC package that
    # sets an INTO variable to 0 when the numeric column is null.
    # this way we can regsub null where the value is -123456.
    # I can't think of a reason, other than testing, where we would see that value.
    set columns "nvl([join $columnList ", -123456)||'!!!'||nvl("], -123456)"
    set joinedPK "nvl([join $primaryKey ", -123456)||'!!!'||nvl("], -123456)"
    set intos ":pkData, :columnData"
    
    # execute sql using the whereClause supplied
    set info(SQL_Statement) "select $joinedPK, $columns into $intos from $tableName where $whereClause"
    puts $info(logFile) "[Now] INFO: GetDataFromSchema: $info(SQL_Statement)"
    execsql use $dbh $info(SQL_Statement) SQLError
    set retVal ""
    foreach pk $pkData cData $columnData {
        regsub -all -- -123456 $cData null newColData
        regsub -all -- -123456 $pk null newPK
        lappend retVal [list $newPK $newColData]
    }
    logoff $dbh
    return $retVal
}

proc DataExist {infoArray svn_local svn_remote svn_base tableName data {pkYN Y}} {
    upvar $infoArray info
    # Find out if a column's data or PK data already exists
    exec svn co $svn_remote$svn_base/Data@HEAD [file join $svn_local $svn_base Data]
    set vfile [glob [file join $svn_local $svn_base Data ModelFiles]/*VALUES.txt]
    set vfid [open $vfile r]
    set tempVlines [split [read $vfid] \n]
    close $vfid
    set thisTable false
    foreach line $tempVlines {
        if {[regexp -nocase "^->$tableName" $line]} {
            set thisTable true
            continue
        } elseif {[regexp -nocase "^->" $line] && ![regexp -nocase "^->$tableName" $line]} {
            set thisTable false
        }
        set vline0 ""
        set vline1 ""
        if {$thisTable == true} {
            set vline0 [split [string map {\### |} $line] |]
            set vline1 [split [string map {!!! |} [lindex $vline0 1]] |]
            lappend vlines [concat [lindex $vline0 0] $vline1]
        }
    }
    # set testData to the primary key value or the first column definition value
    # basically we have this so as not to use the PK for SRU, SPV, and FDD
    puts $info(logFile) "[Now] INFO: DataExist data: $data"
    regsub -all "null" $data "" newData
    if {$newData != ""} {
        puts $info(logFile) "[Now] INFO: DataExist newData: $newData"
    } else {
        set newData $data
    }
    set dataCount 0
    if {$pkYN == "Y"} {
        set dataCount [lsearch -index 0 $vlines [lindex $newData 0]]
    } else {
        set sourceTestData [lindex [split [string map {!!! |} [lindex $newData 1]] |] 0]
        set dataCount [lsearch -index 1 $vlines $sourceTestData]
    }
    return $dataCount
}

proc Now {} {
    return [clock format [clock seconds] -format "%Y.%m.%d-%H:%M:%S"]
}

proc GetInsertionPoint {infoArray data index start end} {
    # get the next value between the start and end UID values
    # from the data list supplied at index supplied.  If
    # the start value does not exists, that's what we want 
    # to use, and we need to find the next or previous value
    # so that we can derive an index value.
    upvar $infoArray info
    set done false
    set searchInd ""
    set prevInd ""
    set useOrig false
    set origStart $start
    if {[lsearch -index $index $data $start] == -1} {
        set useOrig true
    }
    while {!$done} {
        set searchInd [lsearch -index $index $data $start]
        if {$searchInd > -1 && $start <= $end} {
            set prevInd $searchInd
            incr start
            #puts $info(logFile) "[Now] INFO: incr start to $start"
            if {$start > $end} {
                set done true
                #puts $info(logFile) "[Now] INFO: start: $start, useOrig: $useOrig, searchInd: $searchInd -2"
                set retVal -2
            }
        } elseif {$searchInd == -1 && $prevInd != "" && $prevInd > -1} {
            set done true
            # puts $info(logFile) "[Now] INFO: $searchInd == -1 && $prevInd != \"\" && $prevInd > -1"
            if {$useOrig} {
                # if the original start value did not exist then that is what we want to use for the UID.
                # We will return the index where we want to perform the insert but with the original UID value.
                puts $info(logFile) "[Now] INFO: Since $origStart did not exist, setting $start back to $origStart."
                set start $origStart
            }
            set retVal [list [expr $prevInd + 1] $start]
        } elseif {$searchInd == -1 && ($prevInd == "" || $prevInd == -1)} {
            incr start -1
            # puts $info(logFile) "[Now] INFO: $searchInd == -1 && ($prevInd == \"\" || $prevInd == -1)"
            # puts $info(logFile) "[Now] INFO: setting start -1 to $start"
        } else {
            set done true
            set retVal -1
            puts $info(logFile) "[Now] INFO: $searchInd == -1 && $prevInd != \"\" && $prevInd > -1"
            puts $info(logFile) "[Now] INFO: $searchInd == -1 && ($prevInd == \"\" || $prevInd == -1)"
            puts $info(logFile) "[Now] INFO: start: $start, useOrig: $useOrig, searchInd: $searchInd not -2"
        }
    }
    return $retVal
}
proc drawTextbox { value id { requiredYN "N" } {size "25"} {max "25"} {extraHTML ""} {accessKey ""} {popupText ""} } {
    puts [getTextbox $value $id $requiredYN $size $max $extraHTML $accessKey $popupText]
}
proc getTextbox { value id { requiredYN "N" } {size "25"} {max "25"} {extraHTML ""} {accessKey ""} {popupText ""} } {
    set html  "<input id=\"$id\" name=\"$id\" type=\"text\" size=\"$size\" $extraHTML accessKey=\"$accessKey\" "
    if {$requiredYN == "N"} {
        append html " class='inputTextbox' "
    } else {
        append html " class='inputTextboxRequired' "
    }
    if {$popupText != ""} {
        if {$accessKey != ""} {
            append html " title=\"$popupText\n\nPress ALT-$accessKey to access this field directly\" "
        } else {
            append html " title=\"$popupText\" "
        }
    } else {
        if {$accessKey != ""} {
            append html " title=\"Press ALT-$accessKey to access this field directly\" "
        }
    }
    append html  " value=\"$value\" maxlength=\"$max\"  />" 
    return $html
}
proc drawTextArea {value id {requiredYN "N"} {showbackimageYN "Y"} {rows 6} {cols 80} {maxchars 1500} {extraHTML ""}  {accessKey ""} {popupText ""} {charCounterYN N} {charCounterField ""} {charCounterLabelPrefix ""} {charCounterLabelSuffix ""}} {
    puts "[getTextArea  $value $id $requiredYN $showbackimageYN $rows $cols $maxchars $extraHTML $accessKey $popupText $charCounterYN  $charCounterField $charCounterLabelPrefix  $charCounterLabelSuffix]"
}
proc getTextArea { value id {requiredYN "N"} {showbackimageYN "Y"} {rows 6} {cols 80} {maxchars 1500} {extraHTML ""}  {accessKey ""} {popupText ""} {charCounterYN N} {charCounterField ""} {charCounterLabelPrefix ""} {charCounterLabelSuffix ""} } {
    set htmlOutput ""
    append htmlOutput "<textarea id=\"$id\" name=\"$id\" rows=\"$rows\" cols=\"$cols\" $extraHTML accesskey=\"$accessKey\" class=\"inputTextArea" 
    if {$requiredYN == "Y"} { append htmlOutput "Required" }
    if {$showbackimageYN == "N"} { append htmlOutput "NoBack" }
    append htmlOutput "\""

    if {$popupText != ""} {
        if {$accessKey != ""} {
            append htmlOutput " title=\"$popupText\n\nPress ALT-$accessKey to access this field directly\" "
        } else {
            append htmlOutput " title=\"$popupText\" "
        }
    } else {
        if {$accessKey != ""} {
            append htmlOutput " title=\"Press ALT-$accessKey to access this field directly\" "
        }
    }

    if {[string toupper $charCounterYN]=="Y"} {
        append htmlOutput " onKeyDown=\"textCounter(this,$maxchars);document.getElementById('$charCounterField').innerHTML = '$charCounterLabelPrefix' + (GetCharsLeft(this, $maxchars)) + '$charCounterLabelSuffix';\" onKeyUp=\"textCounter(this,$maxchars);document.getElementById('$charCounterField').innerHTML = '$charCounterLabelPrefix' + (GetCharsLeft(this, $maxchars)) + '$charCounterLabelSuffix';\" onBlur=\"textCounter(this,$maxchars);document.getElementById('$charCounterField').innerHTML = '$charCounterLabelPrefix' + (GetCharsLeft(this, $maxchars)) + '$charCounterLabelSuffix';\" onChange=\"textCounter(this,$maxchars);document.getElementById('$charCounterField').innerHTML = '$charCounterLabelPrefix' + (GetCharsLeft(this, $maxchars)) + '$charCounterLabelSuffix';\" "
    } else {
        append htmlOutput " onKeyDown=\"textCounter(this,$maxchars);\" onKeyUp=\"textCounter(this,$maxchars);\" onBlur=\"textCounter(this,$maxchars);\" onChange=\"textCounter(this,$maxchars);\" "
    }
    append htmlOutput " >$value</textarea>"
    return $htmlOutput
}
proc writeJavaScriptSDR {} {
        cgi_script {
            cgi_puts {
                function getFreshPage() {
                    if (document.contains(document.getElementById("dataTypeSelect"))) {
                        showDataTypeNote(getSysDataType());
                        showTableInput(getSysDataType());
                        showDeleteBox(getSysDataType());
                    }
                }
            }
        
            cgi_puts {
                function setSysData(value) {
                    document.getElementById("dataTypeSelect").value = value;
                }
            }

            cgi_puts {
                function getSysDataType() {
                    var obj = document.getElementById("dataTypeSelect");
                    var dataType = obj.options[obj.selectedIndex].text;
                    return dataType;
                }
            }

            cgi_puts {
                function getSysDataTypeNote(value) {
                    switch(value) {
                        case "System Data":
                            return "<font color=red size=2 face=arial>NOTE: System data consists of records that are to be validated pre and post conversion.  Values will be reset on each conversion.  See RE if you have any questions.";
                            break;
                        case "Non-System Data":
                            return "<font color=red size=2 face=arial>NOTE:  Non-System data consists of records that are to be added to the schema but are not required to persist or be validated by the conversion process.  Values will not be reset during conversion.  See RE if you have any questions.";
                            break;
                        case "Load Once Data":
                            return "<font color=red size=2 face=arial>NOTE: Load Once Data consists of records that are required to be loaded on creation of the schema but do not need to be validated pre and/or post conversion.  Values will not be reset during conversion.  See RE if you have any questions.";
                            break;
                        default:
                            return "";
                        
                    }
                }
            }
        
            cgi_puts {
                function showTableInput(data) {
                    var tableInputVal = '<font size=2 face=arial>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Table: <input type="text" name="tabPrefix" size=25>&nbsp;&nbsp;*<br>';
                    if (data == "System Data") {
                        document.getElementById("tableInput").innerHTML = tableInputVal;
                    } else {
                        document.getElementById("tableInput").innerHTML = '';
                    }
                }
            }        
            
            cgi_puts {
                function showDeleteBox(data) {
                    var delCheckBox = '<font size=2 face=arial>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Delete: <input type="checkbox" name="deleteDataYN" value="Y" disabled><br>';
                    if (data == "System Data") {
                        document.getElementById("deleteBox").innerHTML = delCheckBox;
                    } else {
                        document.getElementById("deleteBox").innerHTML = '';
                    }
                }
            }

            cgi_puts {
                function showDataTypeNote(dataType) {
                    document.getElementById("dataTypeNote").innerHTML = getSysDataTypeNote(dataType);
                }
            }
        }
}

# @author       Tarun Arya (P20)
# @description  This proc will update System Data Change Document placed in working directory
# @since        10/12/2016
# @see          makeForm.tcl
# @param        infoArray (Global Array)
# @return       N/A
# @exception    N/A

proc updateSystemDataChange {infoArray} {
upvar $infoArray info
set childDvt $info(childDvt)
set PARENT_DVT $info(parentDvt)
set TABLE $info(TABLE_NAME)
set tabPrefix [string tolower $info(tabPrefix)]

# Update systemDataChanges file for insert
if {$info($tabPrefix.SQL) != ""} {
    set unique_Column $info(KEY_COLUMNS)
    set other_Column $info(COLUMNS)
    
    # Combining all the columns
    set COLUMNS "$unique_Column $other_Column"
    set VALUES [lindex $info(INSERTS) 0]
    
    
    # Doing some parsing to find out action type (INSERT/DELETE)
    
    set sql [split $info($tabPrefix.SQL) "."]
    set ACTION [lindex [split [lindex $sql 1] "_"] 0]
    
    foreach VALUES $info(INSERTS) {
        set vals ""
            foreach val $VALUES col $COLUMNS {
                set vals [append vals "$col = '$val'" " "]
            }
        
        set fp [open "systemDataChanges.txt" a]
        puts $fp "$childDvt \t$PARENT_DVT \t$ACTION \t$TABLE \t\t$vals"
        close $fp
    }
}

if {[info exists info(deleteSQL)]} {
    if {$info(deleteSQL) != ""} {
        set ACTION "DELETE"
        set deleteQuery ""
        puts "<BR> Delete SQL is : $info(deleteSql) <BR>"
        foreach deleteQuery $info(tabPrefix).Delete.SQL {
            set vals [lindex [split [regsub -all "WHERE" $deleteQuery "*"] "*"] 1]
            regsub -all "'\\);" $vals "" vals
            # puts "<BR> vals is $vals"
            set fp [open "systemDataChanges.txt" a]
            puts $fp "$childDvt \t$PARENT_DVT \t$ACTION \t$TABLE \t\t$vals"
            close $fp
        }
    }
}
}

# @author       Tarun Arya (P20)
# @description  This proc will finds out if dependent Dvt exists in fileOrder or not 
# @since        1/17/2017
# @see          N/A
# @param        infoArray (FileOrder path and  Array)
# @return       dependent DVT 
# @exception    N/A

proc getDependencyScript {inFile dvt} { 
    set fid [open $inFile r]
    set conts [read $fid]
    close $fid
    set dvtList [regexp -all -inline "$dvt.\[\\d\]+" $conts]
    set dvtList [lsort $dvtList]
    return [lindex $dvtList end]
}

# @author       Tarun Arya (P20)
# @description  This proc will generate item.2.sql file
# @since        10/11/2016
# @see          N/A
# @param        infoArray (Global Array)
# @return       "item.2.sql" name and It will create "item.2.sql" sql file
# @exception    N/A

proc genDvtSql {infoArray} {
    upvar $infoArray info
    set parentDVT $info(parentDvt)
    # if developer says another dvt should be executed first, then grab the greatest script name with that dvt number
    set dependency ""
    if {[string trim $info(DEPENDENT_DVT)] != ""} {
        set dependency [getDependencyScript $info(tBranch)/Scripts/Items/fileOrder.txt [string trim $info(DEPENDENT_DVT)]]
        if {$dependency == ""} {
            lappend info(error_message) "The DVT you entered, $info(DEPENDENT_DVT), does not exist in this version."
        }
    }
    set childDvt $info(childDvt)
    set tabPrefix [string tolower $info(tabPrefix)]
    # set landaInsertSql [lindex $info($tabPrefix.SQL) 0]
    set landaInsertSql $info($tabPrefix.SQL)
    if {[info exists info($info(tabPrefix).Delete.SQL)]} {
        set landaDeleteSql $info($info(tabPrefix).Delete.SQL)
    } else {
        set landaDeleteSql ""
    }
    set insertsql ""
    set fileInsert [open "$childDvt.2.sql" w]
    puts $fileInsert "/************************************\n DVT $childDvt PART 2 REVISION 0\n************************************/"
    puts $fileInsert "/***************************\n  DVT $childDvt \n  Parent DVT: $parentDVT \n***************************/"
    lappend insertsql "BEGIN"
    
    if {$dependency != ""} {
        set allDvts ""
        regsub -all {\s+} $dependency "','" allDvts
        set dependentDvts "$allDvts','$childDvt.2"
    } else {
        set dependentDvts "$childDvt.2"
    }
    lappend insertsql "\tIF LANDA_CONVERSION.START_ITEM('$dependentDvts') THEN"
    #lappend insertsql "\t\tLANDA_CONVERSION.INSERT_DATA_UNIQUE ('$tableName', '$pk_Column', '$pk_value', '$uk_Column', '$uk_Value', '$other_Column', '$other_value')"
    if {$landaInsertSql != ""} {
        foreach insertQuery $landaInsertSql {
            lappend insertsql "\t\t$insertQuery\n"
        }
    }
    if {$landaDeleteSql != ""} {
        foreach deleteQuery $landaDeleteSql {
            lappend insertsql "\t\t$deleteQuery\n"
        }
    }
    #lappend insertsql "\t\t\t'[string trimright $sql]'"
    #lappend insertsql "\t\t\t'$sql'"
    lappend insertsql "\t\t);"
    lappend insertsql "\t\tLANDA_CONVERSION.STOP_ITEM();"
    lappend insertsql "\tEND IF;"
    lappend insertsql "END;"
    lappend insertsql "/"
    puts $fileInsert [join $insertsql \n]
    close $fileInsert
    return "$childDvt.2.sql"
}

# @author       Tarun Arya (P20)
# @description  This proc will generate child DVT
# @since        10/10/2016 (Reused this proc from some other script)
# @version      1.0
# @see          N/A
# @param        dbh productID version dvt_desc notes marketID source_emp re_emp parent_dvt_ID {dva ""} {pvr ""} {build ""} {releaseCandidate rc01}
# @return       DVT ID
# @exception    On exception on SQL Query do rollback

proc p_makeDVT {dbh productID version dvt_desc notes marketID source_emp re_emp parent_dvt_ID {dva ""} {pvr ""} {build ""} {releaseCandidate rc01}} {
        set ver_lst [p_pad_version $version]
        set verbuild [join $ver_lst ""]
        if { [llength $ver_lst] < 4 && $build != ""} {
            append verbuild $build
            lappend ver_lst $build
            
        } else {
					set build 00
					lappend ver_lst $build
				}
        puts "Creating DVT for new build $verbuild"
                
        if [catch {execsql use $dbh "select 1 from dual"} ] {
					if [catch {logon support@cs_ops} dbh] {
						return -1
					}
				}
        #puts "Setting SQL Statement"
        set SQL_Statement "select DVT_ID, DHS_TST_CODE into :oldid :oldcode from DVT_DEVELOPMENT_TASK, DHS_DVT_HISTORY  where DVT_PRD_ID = '$productID' and DVT_ID = DHS_DVT_ID and DVT_DESC like '$dvt_desc'"
        execsql use $dbh $SQL_Statement 
        # puts "oldid is $oldid"
        # set oldid ""
        if {[llength $oldid] != 0 } { 
            #if a dvt matches that description, then don't create a duplicate
            puts "<h4>Build $build Handoff DVT already exists.<br> DVT [lindex $oldid 0] has history $oldcode. <p>Please check on the status of that DVT, or on the build number called for.</H4>"
            #puts "Build ID: $::env(BUILD_ID)"
            #markAsFailed "Build $build Handoff DVT already exists. DVT [lindex $oldid 0] has history $oldcode. Please check on the status of that DVT, or on the build number called for."
            return -1  
            #################################### Reopen this HO DVT? if so, write new RC number into dvt_user_notes
        } else {
          set DVT_ID "-2"
          set systime "0000"
            #create a Handoff DVT, attaching it to the DVA for the build
            set SQL_Statement "select to_char(sysdate, 'DD-MM-YYYY') into :sysdate_val from Dual"
           execsql use $dbh $SQL_Statement
           # execsql $SQL_Statement
            set SQL_Statement "select to_char(sysdate, 'HHMI') into :systime from Dual"
           execsql use $dbh $SQL_Statement
           # execsql $SQL_Statement
            set SQL_Statement "SELECT DVT_SEQUENCE.NEXTVAL into :DVT_ID FROM DUAL"
           execsql use $dbh $SQL_Statement
           #this code now always attaches dvt to the dva
                set dvtdvaidassignment $dva
           # puts "$DVT_ID, $dvt_desc, $re_emp, $sysdate_val, $info(marketID), $info(productID), $notes, $info(dva), $verbuild"
            set SQL_Statement "INSERT INTO DVT_DEVELOPMENT_TASK (dvt_id, dvt_desc,dvt_source,dvt_emp_id_entered_by,dvt_date_entered,dvt_mkt_id,dvt_prd_id,dvt_mdl_id, dvt_cmp_id,dvt_functional_notes,dvt_type,dvt_dhs_tst_code,dvt_usr_uid_created_by,dvt_create_date,dvt_emp_id_assignment,dvt_emp_id_source, dvt_date_evaluated,dvt_emp_id_evaluated) 
            VALUES ('$DVT_ID', '$dvt_desc', 'I', '$source_emp',trunc(sysdate), 'INT', '$productID', 'RELPREP', 'RELPREP', '$notes', 'X', 'SCH',1000376,trunc(sysdate),'$source_emp', '$source_emp', trunc(sysdate), '$source_emp')"
                                
  # set SQL_Statement "INSERT INTO DVT_DEVELOPMENT_TASK ( DVT_ID, DVT_DVT_ID_PARENT, DVT_DESC, DVT_TYPE,
            # DVT_SOURCE, DVT_EMP_ID_SOURCE, DVT_EMP_ID_ENTERED_BY, DVT_DATE_ENTERED,
            # DVT_MKT_ID, DVT_PRD_ID, DVT_MDL_ID, DVT_CMP_ID, DVT_FUNCTIONAL_NOTES, DVT_USER_NOTES,
            # DVT_BENEFIT_NOTES, DVT_PRIORITY_REQUESTED, DVT_ASSIGNMENT_TYPE,
            # DVT_EMP_ID_ASSIGNMENT, DVT_DAYS_ACTUAL, DVT_CREATE_DATE,
            # DVT_USR_UID_CREATED_BY, DVT_DOCS_NOT_AFFECTED_YN, DVT_DHS_TST_CODE, DVT_DVA_ID_ASSIGNMENT, DVT_PRODUCT_VERSION) 
            # VALUES ('$DVT_ID', $parent_dvt_ID, '$dvt_desc', 'M', 'I', '$source_emp', '$source_emp', 
            # trunc(sysdate), '$marketID', '$productID', 'RELPREP', 'RELPREP', '$notes', 'Current Release Candidate: $releaseCandidate', '--', 'M', 'N', '$re_emp', 0, 
            # trunc(sysdate), 1000026, 'Y', 'SCH', '$dvtdvaidassignment', '$verbuild')"
            # puts $SQL_Statement
            #puts "<br>"
            if {[catch {execsql use $dbh $SQL_Statement} err]} {
                puts "Could not create DVT error code = $err"
                exit
            } else {
              #puts "SQL_Statement: $SQL_Statement"
            }
            execsql use $dbh "COMMIT"
            set SQL_Statement "INSERT INTO DHS_DVT_HISTORY ( DHS_DVT_ID, DHS_DATE, DHS_TIME,
            DHS_EMP_ID_ENTERED_BY, DHS_CREATE_DATE, DHS_USR_UID_CREATED_BY, DHS_TST_CODE )
            VALUES ('$DVT_ID', trunc(sysdate), 0000, '$source_emp', trunc(sysdate), 1000026, 'OPN' )"
            execsql use $dbh $SQL_Statement
            execsql use $dbh "COMMIT"
            # puts $SQL_Statement
            #puts "<br>"
            set SQL_Statement "INSERT INTO DHS_DVT_HISTORY ( DHS_DVT_ID, DHS_DATE, DHS_TIME,
            DHS_EMP_ID_ENTERED_BY, DHS_CREATE_DATE, DHS_USR_UID_CREATED_BY, DHS_TST_CODE )
            VALUES ( '$DVT_ID', trunc(sysdate), $systime, '$source_emp', trunc(sysdate), 1000026, 'SCH' )"
            execsql use $dbh $SQL_Statement
             execsql use $dbh "COMMIT"
            # puts $SQL_Statement
            #puts "<br>"
            if { $dvtdvaidassignment != "" } {
                set SQL_Statement "INSERT INTO DVL_DVA_DVT_LINK ( DVL_DVA_ID, DVL_DVT_ID, DVL_CREATE_DATE, DVL_USR_UID_CREATED_BY) 
                VALUES ('$dva', '$DVT_ID', trunc(sysdate), 1000026)"
            execsql use $dbh $SQL_Statement                       
                 execsql use $dbh "COMMIT"
                # puts $SQL_Statement
            }
            
        }
#ENTER INFO INTO RELENG DATABASE
# execsql use $dbh "select emp_uid into :empuid from emp_employee where emp_id = '$source_emp'"
   # catch { 
 # set releng [logon releng@cic-svr-db08-orcl]
       # execsql use $releng "select count(*) into :ru from rel_release where REL_PVR_UID=$pvr"
       # if {$ru != 0} {
    # puts "<br>Releng entry already exists for this pvr"
    
 # } else {
        # set sql "insert into REL_RELEASE (REL_UID,REL_PVR_UID,REL_PRD_ID,REL_DVA_UID,
  # REL_VERSION_STRING,REL_GENERAL_VERSION,REL_MAINTENANCE_VERSION,
  # REL_EB_VERSION,REL_DEVBUILD_VERSION,REL_CALL_DATE,REL_EMP_UID_IN_CHARGE,
  # REL_CREATE_DATE,REL_EMP_UID_CREATED_BY,REL_DVT_HO_ID
  # ) values (
  # REL_UID_SEQUENCE.nextval, $pvr, '$productID', $dva,
  # '$verbuild', [lindex $ver_lst 0],[lindex $ver_lst 1],[lindex $ver_lst 2],
  # [lindex $ver_lst 3], SYSDATE, $empuid, sysdate, $empuid, $DVT_ID)"
  # puts $sql
  # catch {execsql use $releng $sql} e1
  # execsql use $releng "COMMIT"
# }
      # logoff $releng 
			# } err
            # puts "<br> Error is $err"
  if {$err != 0} {puts "<br>releng error<br>";return -4}
	return $DVT_ID
}

# Description :: This procedure is used to check in required files which has been changed during the 
#                sysDataReq process
# @author     Anurag
# @since      09/11/2016
# @param      args  infoArray : tempArray, sourceLocation : location of the changed file, targetLocation : Location where file
#             needs to check-in, file : Name of the file, dvt : Child DVT number
# @return     This procedure returns nothing (just updated the key in the tempArray which will be used later in the processing)

proc fileCheckIn {infoArray sourceLocation targetLocation file dvt} {
    upvar $infoArray info
    set sourceLocation "$info(workingDir)/$sourceLocation"
    exec svn up $targetLocation
    catch {exec svn info "[filejoinx $targetLocation $file]"} svnResults
    regexp {Revision: (.*?)\n} $svnResults matched previousRevision
    if {[info exists previousRevision]} {
        file copy -force "[filejoinx $sourceLocation $file]" "[filejoinx $targetLocation $file]"
        # catch { exec svn upgrade "$::env(WORKSPACE)"} upgradeError
        catch {exec svn ci -m "File added through sysDataReq application" "[filejoinx $targetLocation $file]"} results
        if {[regexp {svn: E\d+} $results]} {
          puts "Files in conflict. Aborting"
          markAsFailed $results
        } elseif {$results == ""} {
            set revisionNumber 1
            return [list $previousRevision $revisionNumber]
        }
        regexp {Committed revision (.*)\.} $results matched revisionNumber
        return [list $previousRevision $revisionNumber]
    } else {
        set previousRevision 1
        file copy -force "[filejoinx $sourceLocation $file]" "[filejoinx $targetLocation $file]"
        catch {exec svn add "[filejoinx $targetLocation $file]"} err1
        puts $err1
        catch {exec svn ci -m "File added through sysDataReq application" "[filejoinx $targetLocation $file]"} results
        # catch { exec svn upgrade "$::env(WORKSPACE)"} upgradeError
        puts $results
        regexp {Committed revision (.*)\.} $results matched revisionNumber
        return [list $previousRevision $revisionNumber]
    }
}

# Description :: This procedure is used to rollback the changes which has been made during the system data change process 
# @author     Anurag
# @since      09/11/2016
# @param      args  infoArray : tempArray, proto : Handle of the proto database
# @return     This procedure returns nothing (just updated the key in the tempArray which will be used later in the processing)

proc rollback {infoArray} {
    upvar $infoArray info
	set maxtrax [logon $info(maxtrax)]
	set proto [logon $info(PROTO)]
    if {[info exists info(checkedInFiles)] == 1} {
        set filesToRevert $info(checkedInFiles)
        catch { exec svn upgrade "$::env(WORKSPACE)"} upgradeError
        foreach file $filesToRevert {
            if {[lindex $info($file) 0] == 1} {
                set revision [lindex $info($file) 0]
                set targetLocation $info($file-targetLocation)
                exec svn rm "[filejoinx $targetLocation $file]" 
                catch {exec svn ci -m "Deleting $file due to sysDataReq failure" "[filejoinx $targetLocation $file]"} results
                continue
            }
            if {[lindex $info($file) 1] != 1} {
                set revision [lindex $info($file) 0]
                set targetLocation $info($file-targetLocation)
                exec svn merge -r HEAD:$revision "[filejoinx $targetLocation $file]" 
                catch {exec svn ci -m "Reverting changes to revision $revision" "[filejoinx $targetLocation $file]"} results
            } 
        }
    }
    if {[info exists info(revertInsertSQL)] == 1} {
        if {[catch { execsql use $proto $info(revertInsertSQL) } err] || $err < 0} {
            return "Failed to revert database entries"
        }   
    }
    if {[info exists info(revertDeleteSQL)] == 1} {
        foreach sql $info(revertDeleteSQL) {
            if {[catch { execsql use $proto $sql } err] || $err < 0} {
                return "Failed to revert database entries"
            }
        }
    }
    execsql use $proto "commit"
    # Deleting child dvts
    if {[info exists info(childDvt)] == 1} {
        set deleteChildDvt "delete from DVT_DEVELOPMENT_TASK where DVT_ID = $info(childDvt)"
        set deleteChildDvtHistory "delete from DHS_DVT_HISTORY where DHS_DVT_ID = $info(childDvt)"
        if {[catch { execsql use $maxtrax $deleteChildDvt } err] || $err < 0} {
            return "Failed to child dvt"
        } 
        if {[catch { execsql use $maxtrax $deleteChildDvtHistory } err] || $err < 0} {
            return "Failed to child dvt's history"
        } 
    }
    execsql use $maxtrax "commit"
   
    
    return 1
}

# @author       Tarun Arya (P20)
# @description  This proc will return branch path as pet inputs
# @since        10/07/2016
# @see          N/A
# @param        infoArray verList (Version list) branch (T or main)
# @return       Branch Path
# @exception    N/A

proc branchesPath {infoArray verList branch} {
    upvar $infoArray info
    return "$info(SVN_LOCAL)/branches/CareRadius/V[lindex $verList 0]/[lindex $verList 1]/[lindex $verList 2]/[lindex $verList 3]$branch"
    # return "$info(SVN_LOCAL)/branches/CareRadius/V[lindex $verList 0]/[lindex $verList 1]/[lindex $verList 2]/TTT"
}

# @author       Tarun Arya (P20)
# @description  This proc will update filOrder.txt file
# @since        10/07/2016
# @see          sysdatareq.cgi
# @param        item (child DVT #) parent (Parent DVT#) revision version
# @return       N/A
# @exception    N/A

proc updateFileOrder {item parent revision version} {
    set fp [open "fileOrder.txt" a]
    puts $fp "$item \t$parent \t$revision \t$version"
    close $fp
}

proc updateSvn {sourceLocation fileName} {
    exec svn update "$sourceLocation/$fileName"
}

proc updateExportSvn {sourceLocation targetLocation fileName} {
    exec svn update "$sourceLocation/$fileName"
    file copy -force "$sourceLocation/$fileName" $targetLocation
}

proc hasFailed {} {
    if {$::env(SDR_STATUS) != "PASSED"} {
        return 1
    }
    return 0
}

proc markAsFailed {err} {
    set ::env(SDR_STATUS) "FAILED"
    lappend ::env(SDR_FAIL_MESSAGE) $err
    puts "Job Status: $::env(SDR_STATUS) \nFail Message: $::env(SDR_FAIL_MESSAGE)"
    error $err
}

proc Findmodfile {prd ver drvrFile} {
    set sample "$prd$ver"
    set sample1 [string range $sample 0 9].sql
    set file $drvrFile
    set fid [open $file r]
    if {[catch {set lines [getLines $file]} err]} {
        error $err
    }
    close $fid
    set match ""
    set counter 0

    foreach line $lines {
        set found [regexp $sample1 $line match]
        if {$found == 1} {
            set curentVerindex $counter
            set curVermod [lindex $line 4]
            set prvsVerindex [expr $curentVerindex-1]
            set prvsVermod [ lindex [lindex $lines $prvsVerindex] 4]
            return "$curVermod $prvsVermod"
        } else {
            set found1 [regexp $sample1 $line match]
        }
        incr counter 
    }
}
# @author       Parminder Singh (P18)
# @description  This proc will export the latest NAMES,VALUES,WHERE files.
# @since        10/07/2016
# @see          N/A
# @param        home targetLocation itemloc modeldir itemsdir
# @return       N/A
# @exception    N/A
proc CopysvnExport {home targetLocation itemloc modeldir itemsdir} {
    #PWD is H:\CareRadius
    set svnExport "$home\\export"
    file mkdir $svnExport
    cd $svnExport
    exec svn export $modeldir
    exec svn export $itemsdir
    file copy -force ModelFiles\\NAMES.txt $targetLocation
    file copy -force ModelFiles\\VALUES.txt $targetLocation
    file copy -force ModelFiles\\WHERE.txt $targetLocation
    # Deleting items directory from package
    cd $itemloc
    foreach f [glob *] {file delete -force $f}
    cd ..
    #PWD is H:\CareRadius\V03\02\CR0302000004_rc08\DB_Scripts\Tools\Scripts
    file delete -force Items
    file copy -force $svnExport\\Items .
}

# @author       Parminder Singh (P18)
# @description  This proc will execute runconversion and check logFile
# @since        10/07/2016
# @see          N/A
# @param        prd ver {rc "optional"} {schmask "optional"} infoArray
# @return       Pass/Fail
# @exception    N/A
proc runconversion {prd ver {rc "01"} {schmask "03000000"} infoArray} {
	upvar $infoArray tempArray
    set url "http://cic-re-sauron:8080/job/RE/job/dash/job/runconversion-test-job/lastBuild/api/json"
    set username    reservice
    set password  6ab31e98924cf5086d36f0e8652bee32
    set workingDirectory [pwd]
    set prover [string range $ver 0 1]
    set packver [string range $ver 2 3]
    set home "\\\\cic-svr-fs03.corp.exlservice.com\\HOME\\CareRadius"
    set packageDir "\\\\cic-svr-fs07.corp.exlservice.com\\Packaging\\CareRadius\\V$prover\\$packver\\$prd$ver\_rc$rc"
    set path "V$prover\\$packver\\$prd$ver\_rc$rc"
    set svnCoModelfiles "https://cic-svr-svn01:18080/svn/releng/branches/CareRadius/V[string range $ver 0 1]/[string range $ver 2 3]/[string range $ver 4 5]/00TT/Data/ModelFiles/"
    set svnCoItem "https://cic-svr-svn01:18080/svn/releng/branches/CareRadius/V[string range $ver 0 1]/[string range $ver 2 3]/[string range $ver 4 5]/00TT/Scripts/Items/"
    cd $home
    # Delete existing items, if any. Then create new dirs and populate
    catch {
        set file_list [glob -nocomplain "*"]
        if {[llength $file_list] != 0} {
            foreach f [glob *] {file delete -force $f}
        } else {
            #puts "$dir is empty"
        }
        
          
    } err
    if {$err != ""} {
        puts "Error in deleting files from $home :$err"
        return "Error: $err"
    }
    file mkdir $path
    file copy -force "$packageDir\\DB_Scripts" $path
    set Driverfile "$home\\$path\\DB_Scripts\\Tools\\AutoConversion.txt"
    # Home Drive Custom path for logs
    set logs "\\\\cic-svr-fs03.corp.exlservice.com\\HOME\\TEST_RESULTS\\CareRadius_custom\\$prd$ver\_rc$rc"
    
    # Finding Mod files of Previous and Current Version.
    set modList [Findmodfile $prd $ver $Driverfile]
    set currentMod [lindex $modList 0]
    set previousMod [lindex $modList 1]
    set Targetloc "$home\\$path\\DB_Scripts\\Tools\\Models\\$currentMod"
    set itemloc "$home\\$path\\DB_Scripts\\Tools\\Scripts\\Items"
    
    # Copy files from 00TT branch to HOME drive
    catch {CopysvnExport "$home" "$Targetloc" "$itemloc" "$svnCoModelfiles" "$svnCoItem"} err
    if {$err != ""} {
        puts $err
        cd $workingDirectory
        markAsFailed "SVN Export FAILED: $err"
    }
    cd $workingDirectory
    
    puts "\n####### EXECUTING 'runconversion-test-job' JENKINS JOB #######\n"
    
    # launch_build.tcl  will execute the Jenkins job on Cic-re-sauron 
    #Eg: tclsh launch_build.tcl job/RE/job/dash/job/testJenkinsJob "product CA" "version 039838838"

    if [catch {exec tclsh launch_build.tcl job/RE/job/dash/job/runconversion-test-job "product $prd" "version $ver" "rc $rc" "schemaMask $schmask"} output] {
        puts "ERROR: CAUGHT error... $output"
    } 
    
    # check Status for runconversion Jenkins job
    set counter 0
    puts "Waiting for RunConversion Jenkins job to start"
    after 60000
    while {[set buildStatus [fetchBuildStatus $url $username $password]] == "null" && $counter <12000} {
        incr counter
        puts "Waiting for RunConversion Jenkins job to Finish (Time elapsed waiting: [expr $counter * 60] seconds)"
        after 60000
    }
    
    # CHECK THE RUNCONVERSION LOGS 
    
    if {$buildStatus == "SUCCESS"} {
        cd $logs 
        set ret [ind]
        cd $workingDirectory
        #puts "IND RETURN VALUE: $ret"
        if {$ret == "PASSED"} {
            puts "Runconversion completed Succesfully \n"
        } elseif {$ret == "ABORTED"} {
            puts "Temporary - Runconversion completed Succesfully \n"
        } else {
            puts "Runconversion job failed with status : $ret. Please check logs - $logs \n"
			puts "Calling Rollback..."
			# rollback tempArray
            markAsFailed $err
        }
        return $ret
    }
    return $buildStatus
}
# @author       Parminder Singh (P18)
# @description  This proc check for test.out files that will be generated by runconversion test cases.
# @since        10/07/2016
# @see          N/A
# @param        N/A
# @return       N/A
# @exception    N/A
proc ind {} {
  set here [pwd]
  cd $here
  for {set i 1} {$i<=2} {incr i} {
	set dir$i [glob -type d *]
	set d dir$i
	cd [expr $$d]
	puts [pwd]
  }
  set dir [glob -type d results]
  cd $dir
  set ret [checkRunconvlogs "test.out"]
  return $ret   
  
}
# @author       Parminder Singh (P18)
# @description  This proc check the content of logfiles of runconversion test cases and return status.
# @since        10/07/2016
# @see          N/A
# @param        logfile
# @return       Pas/Fail
# @exception    N/A
proc checkRunconvlogs {logfile} {
    set fid [open $logfile r]
    #puts "REading file: $logfile"
    set data [split [read $fid] \n]
    puts "Reading file: $logfile\nData: $data"
    close $fid
   
    foreach line $data { 
        #puts "Reading line: $line \n"
        if [regexp "FAILED" $line] {
            return "FAILED"
        }
    }
    return "PASSED"
}
# @author       Parminder Singh (P18)
# @description  Current Status of Runconversion Jenkins job.
# @since        10/07/2016
# @see          N/A
# @param        url username password
# @return       Pass/Fail
# @exception    N/A
proc fetchBuildStatus {url username password} {
    set auth "Basic [base64::encode $username:$password]"
    set headerl [list Authorization $auth]
    set tok [http::geturl $url -headers $headerl]
    set res [http::data $tok]
    http::cleanup $tok
    set bodyNew [split $res ","]
    set result [string trim [lindex [split [lindex $bodyNew [lsearch -regexp $bodyNew "result"]] ":"] 1] "\""]
    puts "Current Status of runConversion Jenkins job is: $result"
    return $result
}
# @author       Parminder Singh (P18)
# @description  Pick the Package Name from 'P' drive chosen for runconversion testing
# @since        10/07/2016
# @see          N/A
# @param        infoArray
# @return       N/A
# @exception    N/A
proc fetchBuildnumber {infoArray} {
    set here [pwd]
    set verList $infoArray
    set packageDir "\\\\cic-svr-fs07.corp.exlservice.com\\Packaging\\CareRadius\\V[lindex $verList 0]\\[lindex $verList 1]\\"
    cd $packageDir
    set verListApp ""
    foreach val $verList {append verListApp $val}
    set globRes [glob -nocomplain CR$verListApp*]
    set dirList ""
    foreach f $globRes {
        if {[file isdirectory $f]} {
            lappend dirList $f
        }
    }
    set dirList [lsort $dirList]
    puts "Package Name chosen for runconversion testing: [lindex $dirList 0], Build number [string range $dirList 10 11]"
    cd $here
    return [string range $dirList 10 11]
}
# @author       Parminder Singh (P18)
# @description  Package Name chosen for runconversion testing
# @since        10/07/2016
# @see          N/A
# @param        infoArray
# @return       Pass/Fail
# @exception    N/A
proc schemaVersion {versionFile} {
    set pdversion [lindex [split [file tail $versionFile] .] 0]
    puts "Using Xmlfile for runconversion $versionFile"
    set version_doc [p_setDocument "$versionFile"]
    set schemasNode [p_getFirstNodeWithName $version_doc version "$pdversion"]
    set schemaNode [p_getNodes $schemasNode "schemas/schema"]

    set node [lindex $schemaNode 1]
    set schemaList [getAttributeValue $node "name"]
    if {$schemaList != ""} {
        lappend schemaVer [lindex $schemaList 1]
        return [lindex $schemaVer 0]
    }

    

}