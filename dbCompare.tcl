# db_compare.tcl

if {[catch {getInfo _common_utilities_loaded}] || [getInfo _common_utilities_loaded] == ""} {
    if [catch {glob common_utilities.tcl} err] {
        puts "The file common_utilities.tcl is not in the current directory."
        puts "This script cannot run without it."
        puts "Please obtain this file and copy it into this directory."
        return 2
    } else {
        source common_utilities.tcl
    }
}

proc dbCompare.version {} {
    return "6"
}
proc dbCompare.revision {} {
    return "0"
}

#=================== PROCEDURE =========================#
# Procedure : p_CorrectUsage
# Purpose   : putting correct usage info to screen
#=======================================================#
proc dbCompareCorrectUsage {argv0} {
    set tool [file tail $argv0]
    puts ""
    puts  [dbCompare.getDescription]
    puts ""
    puts "USAGE:   mtclsh $tool  <Model Files directory> <Target database connect string> <Report filename> <SILENT>"
    puts ""
    puts "EXAMPLE: mtclsh $tool Mod600/ siteuser/sitepass@siteserver cert600.txt"
    puts ""
    puts "You can alternately put the above inputs into a file."
    puts "The default input file name is input_params.txt"
    puts "if dbCompare is run without parameters."
    puts "You may specify another file name on the command line:"
    puts "EXAMPLE: mtclsh dbCompare.tcl inputfile=myFile.txt"
    puts ""
    puts "input_params.txt can be found in the DB_Scripts/Tools directory"
    puts "and has all the parameters needed for all tcl tools."
    puts "For dbCompare.tcl the required paramters are:"
    puts "CARERADIUS_SCHEMA_NAME=<schemaname>"
    puts "CARERADIUS_SCHEMA_PASSWORD=<password>"
    puts "DB_HOST_INFO=<tnsname or identifier>"
    puts "optional parameters"
    puts "MODEL_DIR=<Model Files directory>"
    puts "OUTPUT_FILE=<Report filename>"
    puts "SILENT=<Y/N>"
    puts ""
    puts "ERROR: time [clock format [clock seconds]]"
    puts ""
}

proc dbcIntro {date_stamp displayDB model_version separator} {
    set intro "EXL Database Comparison Report
This command file lists all differences between the current state of the
target database and the model version. In order to bring the target
database into version, all differences need to be resolved unless it is
determined that the items are appropriate.
Special attention is required for all columns or tables being removed.
If these objects contain data, the data must be mapped to new or existing
columns during the target version's correction process or the data will be
permanently lost.

Contact the EXL Healthcare Support Department for assistance:
Phone   : (800) 669-4629
Website : https://support.exlhealthcare.com
[getInfo HR]
"
    return $intro
}

proc compareTriggers {modelDef targetDef} {
    upvar $modelDef model
    upvar $targetDef target
    # validate  trigger(s)
    # set addTriggerLst ""
    # set badTriggerLst ""
    # set dropTriggerLst ""
    set i 0
    set modelTableIndex 0
    set tests [getMinType USER_TRIGGERS model target]
    foreach modelTable $model(USER_TRIGGERS.header)  {
        # see if there is any index on target for this table
        set targetTableIndex [p_getArrayIndexFor target USER_TRIGGERS $modelTable]
        if {$targetTableIndex >= 0} {
            # target has an entry for this table
            set modelkeyIndex 0
            set targetKeys [lindex $target(USER_TRIGGERS.key) $targetTableIndex]
            foreach modelTriggerName [lindex $model(USER_TRIGGERS.key) $modelTableIndex] {
                set targetTriggerIndex [lsearch $targetKeys $modelTriggerName]
                set modeldef [p_getArrayDatumAt model USER_TRIGGERS $modelTableIndex $modelkeyIndex]
                # see if there is a target index of this name
                if {$targetTriggerIndex >= 0} {
                    set targetdef [p_getArrayDatumAt target USER_TRIGGERS $targetTableIndex $targetTriggerIndex]
                    if {$modeldef != $targetdef} {
                        #first remove any "SCHEMANAME". from the definition (name)
                        regsub  {".*?"\.} $modeldef "" modeldef
                        regsub {".*?"\.} $targetdef "" targetdef
                        foreach test $tests {
                            #there may be only non-whitespace differences - regsub out all whitespace and quotes
                            regsub -all {[\s\n"]} [lindex $modeldef $model(DEF.USER_TRIGGERS.data.index.$test)] "" mtest
                            regsub -all {[\s\n"]} [lindex $targetdef $target(DEF.USER_TRIGGERS.data.index.$test)] "" ttest
                            if {$mtest != $ttest} {
                                addResult RECREATE.TRIGGERS [list $modelTable $modelTriggerName $modeldef] 0
                                break
                            }
                        }
                    }
                } else {
                    # trigger needs to be added to target table
                     addResult ADD.TRIGGERS [list $modelTable $modelTriggerName $modeldef] 1
                }
                incr modelkeyIndex
            }
        } else {
            #table has no entries so add all
            set iterator 0
            foreach modelTriggerName [lindex $model(USER_TRIGGERS.key) $modelTableIndex] {
                addResult ADD.TRIGGERS [list $modelTable $modelTriggerName [p_getArrayDatumAt model USER_TRIGGERS $modelTableIndex $iterator]] 1
                incr iterator
            }
        }
        incr modelTableIndex
    }
    # check for extra triggers. - ENHANCEMENT: allow custom triggers?
    set targetTableIndex 0
    foreach targetTable $target(USER_TRIGGERS.header) {
        set modelTableIndex [lsearch $model(USER_TRIGGERS.header) $targetTable]
        if {$modelTableIndex >= 0} {
            foreach targetName [lindex $target(USER_TRIGGERS.key) $targetTableIndex] {
                set i [lsearch [lindex $model(USER_TRIGGERS.key) $modelTableIndex] $targetName]
                if {$i < 0} {
                    if {[string range $targetName 0 [string first "_" $targetName]] == [string range $targetTable 0 [string first "_" $targetTable]]} {
                        addResult DROP.TRIGGERS [list $targetTable $targetName] 1
                    } else {
                        addWarning DROP.TRIGGERS [list $targetTable $targetName] 1
                    }
                }
            }
        } else {
            foreach targetName [lindex $target(USER_TRIGGERS.key) $targetTableIndex] {
                if {[string range $targetName 0 [string first "_" $targetName]] == [string range $targetTable 0 [string first "_" $targetTable]]} {
                    addResult DROP.TRIGGERS [list $targetTable $targetName] 1
                } else {
                    addWarning DROP.TRIGGERS [list $targetTable $targetName] 1
                }
            }
        }
        incr targetTableIndex
    }

    # set diffs [expr [llength $addTriggerLst] + [llength $badTriggerLst] + [llength $dropTriggerLst] ]
    # return [list ADD.TRIGGERS $addTriggerLst RECREATE.TRIGGERS $badTriggerLst DROP.TRIGGERS $dropTriggerLst diffs $diffs]
}
# TODO move query to sqlA
proc p_getSchemaProcedureData {connectString arrayName {TABLES ""}} {
    upvar $arrayName temp
    set head ""
    set all_names ""
    set all_data ""
    set dataend [expr 2 + [llength [join $temp(DEF.USER_PROCEDURES.data)]]]
    if {$temp(DEF.USER_PROCEDURES.data) == {}} {
        logit "Cannot retrieve Text Index data from schema - no metadata exists"
        return
    }
    if {$TABLES != "" && [lsearch $TABLES UDT*] < 0} {
        return ""
    }
    set type_params ""
    set SQL "SELECT '{{'||USER_PROCEDURES.OBJECT_NAME||'} {'||USER_PROCEDURES.AUTHID||'} {'||
    (select listagg(USER_SOURCE.TEXT,chr(10)) within group (order by USER_SOURCE.LINE)
        from USER_SOURCE
        where USER_SOURCE.TYPE = 'PROCEDURE' AND USER_SOURCE.NAME = USER_PROCEDURES.OBJECT_NAME) || '}}'
    from USER_PROCEDURES USER_PROCEDURES
    where USER_PROCEDURES.OBJECT_NAME like 'UDT%'
    AND USER_PROCEDURES.OBJECT_TYPE = 'PROCEDURE'
    order by USER_PROCEDURES.OBJECT_NAME;"
    # catch {runSQLA $connectString USER_PROCEDURES $sqlcols $SQL results ""} err
    set schema [srange to "/" $connectString]
    set outfile $schema.USER_PROCEDURES.lst
    set sqlFile $schema.USER_PROCEDURES.sql
    set fid [open $sqlFile w]
    puts $fid "set echo off"
    puts $fid "set pagesize 0"
    puts $fid "set heading off"
    puts $fid "set feedback off"
    puts $fid "set linesize 4000"
    puts $fid "$SQL"
    puts $fid "exit"
    close $fid
    if [catch {exec [getSQLPLUS] -L -S $connectString @$sqlFile} results] {
      putt "SQL error : $output\n see $sqlFile"
      putt "connectString = $connectString"
      putt "columnList = $columnList"
      putt "from_where = $from_where"
      putt "isolateColumnList = $isolateColumnList"
      exit
    }
    set output ""
    set all_data ""
    set all_names ""
    foreach row $results {
        if {[string trim $row] == ""} {continue}
        set header [lindex $row $temp(DEF.USER_PROCEDURES.index.header)]
        if {$header != $head} {
            if {[lsearch -sorted $temp(USER_PROCEDURES.header) $header] < 0} {
                lappend temp(USER_PROCEDURES.header) $header
                set t ""
            }
            if {$head != ""} {
                lappend temp(USER_PROCEDURES.key) $all_names
                if {$dataend > 2} {
                    lappend temp(USER_PROCEDURES.data) $all_data
                }
                set all_names ""
                set all_data ""
            }
            set head $header
        }
        lappend all_names [lindex $row $temp(DEF.USER_PROCEDURES.index.key)]
        lappend all_data [lindex $row end]
        regsub -all {(\r\f)|([\r])|([\f])|([\n])} $all_data "\\\\n" all_data
        regsub -all {\t} $all_data "    " all_data
    }
    if {$all_names != ""} {
        lappend temp(USER_PROCEDURES.key) $all_names
        if {$dataend > 2} {
            lappend temp(USER_PROCEDURES.data) $all_data ;#[join $all_data]
        }
    }
    catch {file delete -force $outfile}
    catch {file delete -force $sqlFile}
    return
}
proc compareProcedures {modelDef targetDef} {
    upvar $modelDef model
    upvar $targetDef target

    # set addProcedureList ""
    # set badProcedureList ""
    # set dropProcedureList ""
    set i 0
    set modelProcedureIndex 0
    foreach modelProcedure $model(USER_PROCEDURES.header)  {
        set modelAuth [lindex $model(USER_PROCEDURES.key) $modelProcedureIndex]
        set targetProcedureIndex [lsearch [string toupper $target(USER_PROCEDURES.header)] [string toupper $modelProcedure]]
        if {$targetProcedureIndex >= 0} {
            set mdef [lindex $model(USER_PROCEDURES.data) $modelProcedureIndex]
            set tdef [lindex $target(USER_PROCEDURES.data) $targetProcedureIndex]
            regsub -all {[\s]|(\\n)} $mdef "" m
            regsub -all {[\s]|(\\n)} $tdef "" t
            if {[string toupper [join $t]] != [string toupper [join $m]]} {
                addResult RECREATE.PROCEDURES [list [lindex $target(USER_PROCEDURES.header) $targetProcedureIndex]] 0
            }
        } else {
               addResult ADD.PROCEDURES [list $modelProcedure $modelAuth [lindex $model(USER_PROCEDURES.data) $modelProcedureIndex]]
        }
        incr modelProcedureIndex
    }
    set targetProcedureIndex 0
    foreach targetProcedure $target(USER_PROCEDURES.header) {
        set modelProcedureIndex [lsearch [string toupper $model(USER_PROCEDURES.header)] [string toupper $targetProcedure]]
        if {$modelProcedureIndex < 0} {
            addResult DROP.PROCEDURES $targetProcedure
        }
        incr targetProcedureIndex
    }
    # set diffs [expr [llength $addProcedureList] + [llength $badProcedureList] + [llength $dropProcedureList] ]
    # return [list ADD.PROCEDURES $addProcedureList RECREATE.PROCEDURES $badProcedureList DROP.PROCEDURES $dropProcedureList diffs $diffs]
}

proc getSchemaTextIndexData {def dbh type {tableName ""}} {
    upvar $def temp
    set head ""
    set all_names ""
    set all_data ""
    set dataend [expr 2 + [llength [join $temp(DEF.TEXT_INDEXES.data)]]]
    set selectData ""
    if {$temp(DEF.$type.data) == {}} {
        logit "Cannot retrieve Text Index data from schema.  No metadata exists"
        return
    }
    set type_params ""
    set sqlcols {USER_INDEXES.TABLE_NAME USER_INDEXES.INDEX_NAME "(select LISTAGG(USER_IND_COLUMNS.COLUMN_NAME, ',') within group (order by USER_IND_COLUMNS.COLUMN_POSITION) from USER_IND_COLUMNS A where A.INDEX_NAME = USER_INDEXES.INDEX_NAME)" USER_INDEXES.INDEX_TYPE USER_INDEXES.ITYP_OWNER||'.'||USER_INDEXES.ITYP_NAME}
    set SQL " from USER_INDEXES USER_INDEXES, USER_IND_COLUMNS USER_IND_COLUMNS "
    if {[regexp "TABLE_NAME" $temp(DEF.$type.header)]} {
        if {($tableName == "" || $tableName == "*")} {
           append SQL ", TOR_TABLE_ORDER TTO where $temp(DEF.$type.WHERE) and USER_INDEXES.$temp(DEF.$type.header) = TTO.TOR_TABLE_NAME "
        } else {
            append SQL " where $temp(DEF.$type.WHERE) and USER_INDEXES.$temp(DEF.$type.header) in ('[join $tableName "','"]')"
        }
    }
    set results ""
    if {[info exists temp(DEF.$type.ORDER_BY)] && $temp(DEF.$type.ORDER_BY) != ""} {
        append SQL " order by $temp(DEF.$type.ORDER_BY)"
    }
    catch {set outfile [runSQL $dbh $type "$sqlcols" "$SQL" results " USER_INDEXES.parameters"]} err

    foreach row $results {
        set header [lindex $row $temp(DEF.$type.index.header)]
        if {$header != $head} {
            if {[lsearch -sorted $temp(TEXT_INDEXES.header) $header] < 0} {
                lappend temp(TEXT_INDEXES.header) $header
            }
            if {$head != ""} {
                lappend temp(TEXT_INDEXES.key) $all_names
                if {$dataend > 2} {
                    lappend temp(TEXT_INDEXES.data) $all_data
                }
                set all_names ""
                set all_data ""
            }
            set head $header
        }
        set t ""
        for {set j $temp(DEF.$type.index.data)} {$j < $dataend} {incr j} {
            lappend t [lindex $row $j]
        }
        lappend all_names [lindex $row $temp(DEF.$type.index.key)]
        lappend all_data $t
    }
    if {$all_names != ""} {
        lappend temp(TEXT_INDEXES.key) $all_names
        if {$dataend > 2} {
            lappend temp(TEXT_INDEXES.data) $all_data
        }
    }
    return
}
proc compareTextIndices {modelDef targetDef} {
    upvar $modelDef model
    upvar $targetDef target
    set addTextIndexLst ""
    set collideIndNameLst ""
    set badtextIndexLst ""
    set i 0
    set modelTableIndex 0
    set tests [getMinType TEXT_INDEXES model target]
    foreach modelTable $model(TEXT_INDEXES.header)  {
        # see if there is any index on target for this table
        set targetTableIndex [p_getArrayIndexFor target TEXT_INDEXES $modelTable]
        if {$targetTableIndex >= 0} {
            # target has an entry for this table
            set modelkeyIndex 0
            set adds ""
            set targetKeys [lindex $target(TEXT_INDEXES.key) $targetTableIndex]
            foreach modelIndexName [lindex $model(TEXT_INDEXES.key) $modelTableIndex] {
                set targeKeyIndex [lsearch [string toupper $targetKeys] [string toupper $modelIndexName]]
                set modeldef [p_getArrayDatumAt model TEXT_INDEXES $modelTableIndex $modelkeyIndex]
                set textIndexData ""
                foreach test $tests {
                    lappend textIndexData [lindex $modeldef $model(DEF.TEXT_INDEXES.data.index.$test)]
                }
                # see if there is a target index of this name
                if {$targeKeyIndex >= 0} {
                    # there is, so test the index to see if match
                    set targetdef [p_getArrayDatumAt target TEXT_INDEXES $targetTableIndex $targeKeyIndex]
                    if {$targetdef != $modeldef} {
                        # check - removing any whitespace, to see if there are non-whitespace differences
                        set t 0
                        foreach test $tests {
                            regsub -all {[\s\n]} [lindex $modeldef $model(DEF.TEXT_INDEXES.data.index.$test)] "" mdef
                            regsub -all {[\s\n]} [lindex $targetdef $target(DEF.TEXT_INDEXES.data.index.$test)] "" tdef
                            # ENHANCEMENT: this could be improved, to remove any commenting or other non critical items
                            # determine what has the diff.
                            # ENHANCEMENT: should add some notation of what was different DEF.TEXT_INDEXES.data.index.
                            set mdef [string toupper $mdef]
                            set tdef [string toupper $tdef]
                            if {$mdef != $tdef} {
                                # Index should be dropped first before creating
                                addResult RECREATE.TEXT_INDEXS [list $modelTable $modelIndexName $textIndexData] 1
                                break
                            }
                        }
                    }
                } else {
                    # check first for definition collisions before add text index items
                    if {[set collideIndex [lsearch [string toupper $target(TEXT_INDEXES.data)] [string toupper $modeldef]]] >= 0} {
                        addResult DROP.TEXT_INDEXS [list [lindex $target(TEXT_INDEXES.header) $targetTableIndex] [lindex $target(TEXT_INDEXES.key) $collideIndex] $modelTable $modelName $textIndexData] 1
                    } else {
                        addResult ADD.TEXT_INDEXS [list $modelTable $modelIndexName $textIndexData] 1
                    }

                }
                incr modelkeyIndex
            }
        } else {
            #table has no entries so add all
            set iterator 0
            foreach modelIndexName [lindex $model(TEXT_INDEXES.key) $modelTableIndex] {
                set textIndexData ""
                set modeldef [p_getArrayDatumAt model TEXT_INDEXES $modelTableIndex $iterator]
                foreach test $tests {
                    lappend textIndexData [lindex $modeldef $model(DEF.TEXT_INDEXES.data.index.$test)]
                }
                addResult ADD.TEXT_INDEXS [list $modelTable $modelIndexName $textIndexData] 1
                incr iterator
            }
        }
        incr modelTableIndex
    }
    # check for extra textIndexes. - ENHANCEMENT: allow custom textindexes?
    set targetTableIndex 0
    foreach targetTable $target(TEXT_INDEXES.header) {
        set modelTableIndex [lsearch [string toupper $model(TEXT_INDEXES.header)] [string toupper $targetTable]]
        if {$modelTableIndex >= 0} {
            foreach targetName [lindex $target(TEXT_INDEXES.key) $targetTableIndex] {
                set i [lsearch [string toupper [lindex $model(TEXT_INDEXES.key) $modelTableIndex]] [string toupper $targetName]]
                if {$i < 0} {
                    addResult DROP.TEXT_INDEXS [list $targetTable $targetName] 1
                }
            }
        } else {
            foreach targetName [lindex $target(TEXT_INDEXES.key) $targetTableIndex] {
                addResult DROP.TEXT_INDEXS [list $targetTable $targetName] 1
            }
        }
        incr targetTableIndex
    }
}

# sequences have gotten somewhat messy, lots of hard coded stuff here....
proc p_getSchemaSequenceData {dbh arrayName {tableName ""}} {
    upvar $arrayName temp
    set tab_prefix [string range $tableName 0 2]
    set SEQ [getSchemaSequences $dbh temp $tab_prefix]
    set seq_tables [lindex $SEQ 0]
    set seq_sequences [lindex $SEQ 1]
    set seq_data [lindex $SEQ 2]
    set SQL " from USER_SEQUENCES "
    if {$tab_prefix == "" || $tab_prefix == "*"} {
        append SQL " where substr(SEQUENCE_NAME,1,3) in (select substr(TOR_TABLE_NAME,1,3) from TOR_TABLE_ORDER where TOR_TABLE_NAME not like 'UDT%') and substr(SEQUENCE_NAME, -8, 8) = 'SEQUENCE' "
    } else {
        append SQL " where sequence_name like '$tab_prefix%' and substr(SEQUENCE_NAME, -8, 8) = 'SEQUENCE' "
    }
    append SQL " order by SEQUENCE_NAME"
    set results ""
    #TODO this is hardcoded MAX_VALUE!INCREMENT_BY!MIN_VALUE!CACHE_SIZE!CYCLE_FLAG
                #MAX_VALUE!INCREMENT_BY!MIN_VALUE!CACHE_SIZE!CYCLE_FLAG
    set outfile [runSQL $dbh SEQUENCE [list SEQUENCE_NAME nvl(MAX_VALUE,999999999) INCREMENT_BY nvl(MIN_VALUE,LAST_NUMBER+1) "decode(CACHE_SIZE,'0', 'NOCACHE',CACHE_SIZE)" "decode(CYCLE_FLAG,'N','NOCYCLE','Y','CYCLE',CYCLE_FLAG)"] $SQL results]
    set tab ""
    set sequences ""
    set data ""
    foreach row $results {
        #merge the info from SEQ
        # if the SEQ sequence exists, add this new data
        # if not, if the table entry doesn't exist add the table, sequence, nulls, and new data
        set sequence [lindex $row 0]
        set dat [lrange $row 1 end]
        if {[set sequenceIndex [lsearch $seq_sequences $sequence]] >= 0} {
            set table [lindex $seq_tables $sequenceIndex]
        } else {
            #assuming USER_TABLES has been populated....
            # TODO use guery model or schema procedure
            set i [lsearch $temp(USER_TABLES.header) [string range $sequence 0 2]*]
            if {$i < 0} {
                logit "Could not find a table for sequence $sequence"
                set table UNKNOWN
            } else {
                set table [lindex $temp(USER_TABLES.header) $i]
            }
        }
        if {$table != $tab} {
            if {$tab != ""} {
                lappend temp(USER_SEQUENCES.header) $tab
                lappend temp(USER_SEQUENCES.key) $sequences
                lappend temp(USER_SEQUENCES.data) $data
            }
            set sequences ""
            set data ""
        }
        if {$sequenceIndex >= 0} {
            set dat [concat [lindex $seq_data $sequenceIndex] $dat]
        } else {
            # if not in seq table, set site begin as 1
            set dat [concat [list $table 1] $dat]
        }
        lappend sequences $sequence
        lappend data $dat
        set tab $table
    }
    if {$tab != "" || $sequences != ""} {
        if {$tab != ""} {
            lappend temp(USER_SEQUENCES.header) $tab
        }
        lappend temp(USER_SEQUENCES.key) $sequences
        lappend temp(USER_SEQUENCES.data) $data
    }
    return
}
proc getSchemaSequences {dbh arrayName {tab_prefix ""}} {
    upvar $arrayName temp
    if {[string length $tab_prefix] > 3} {return ""}
        set SQL  "FROM SEQ_SEQUENCE"
    if {$tab_prefix == "" || $tab_prefix == "*"} {
        append SQL ",TOR_TABLE_ORDER TOR_TABLE_ORDER where substr(SEQ_NAME,1,3) =  substr(TOR_TABLE_NAME,1,3) "
    } else {
        append SQL ",TOR_TABLE_ORDER TOR_TABLE_ORDER WHERE SEQ_NAME LIKE '$tab_prefix%' and substr(SEQ_NAME,1,3) =  substr(TOR_TABLE_NAME,1,3)"
    }
    # Columns = TARGET_COLUMN!SITE_VALUE_BEGIN!
    append SQL " order by SEQ_NAME"
    set results ""
    set outfile [runSQL $dbh SEQ "TOR_TABLE_ORDER.TOR_TABLE_NAME SEQ_NAME SEQ_TARGET_COLUMN SEQ_SITE_VALUE_BEGIN" $SQL results]
    set tables ""
    set sequences ""
    set data ""
    foreach row $results {
        lappend tables [lindex $row $temp(DEF.USER_SEQUENCES.index.header)]
        lappend sequences [lindex $row $temp(DEF.USER_SEQUENCES.index.key)]
        lappend data [lrange $row $temp(DEF.USER_SEQUENCES.index.data) end]
    }
    return [list $tables $sequences $data]
}

# note: UDT_ sequences should not be flagged for drops as they apply to UDW tables.
proc checkDropSequences {modelDef targetDef} {
    upvar $modelDef model
    upvar $targetDef target
    # set drop_seq_lst ""
    for {set tableIndex 0} {$tableIndex < [llength $target(USER_SEQUENCES.header)]} {incr tableIndex} {
        set tableName [lindex $target(USER_SEQUENCES.header) $tableIndex]
        set sequenceNames [lindex $target(USER_SEQUENCES.key) $tableIndex]
        set modelTableIndex [lsearch $model(USER_SEQUENCES.header) $tableName]
        # user_sequences tablenames - if no seq entry, it won't be here.
        if {$modelTableIndex < 0} {
            foreach seq $sequenceNames {
                addResult DROP.SEQUENCES $seq 1
            }
        } else {
            set sequenceIndex 0
            foreach seq $sequenceNames {
                if {[lsearch [lindex $model(USER_SEQUENCES.key) $modelTableIndex] $seq] < 0 } {
                    addResult DROP.SEQUENCES $seq 1
                }
            }
        }
    }
    # return [list DROP.SEQUENCES $drop_seq_lst diffs [llength $drop_seq_lst]]
}


proc checkAddSequences {modelDef targetDef} {
    upvar $modelDef model
    upvar $targetDef target
    set add_sequence_lst ""
    set add_seq_table_lst ""
    #TODO : need a drop/recreate sequence list.
    # todo: utilize defined values instead of hardcoding index numbers.
    # foreach model index, see if there is a matching target index
    # this is complicated by the fact that the seq table data may be missing
    for {set tableIndex 0} {$tableIndex < [llength $model(USER_SEQUENCES.header)]} {incr tableIndex} {
        set tableName [lindex $model(USER_SEQUENCES.header) $tableIndex]
        set sequenceNames [lindex $model(USER_SEQUENCES.key) $tableIndex]
        set sequenceDatas [lindex $model(USER_SEQUENCES.data) $tableIndex]
        set targetTableIndex [lsearch $target(USER_SEQUENCES.header) $tableName]
        # user_sequences tablenames - if no seq entry, it won't be here.
        if {$targetTableIndex >= 0} {
            # This loop goes through all sequences in the model table, and checks for sequences of that name
            set sequenceIndex 0
            foreach seq [lindex $model(USER_SEQUENCES.key) $tableIndex] {
                if {[lsearch [lindex $target(USER_SEQUENCES.key) $targetTableIndex] $seq] < 0 } {
                    set details [lindex $sequenceDatas $sequenceIndex]
                    addResult ADD.SEQUENCES [list $tableName $seq $details] 1
                    addResult INSERT.SEQS [list $tableName $seq $details] 0
                } else {
                    # compare the sequences here
                    #TODO Code goes here
                    # note :seq fix should fix any discrepancy other than seq target column
                }
                incr sequenceIndex
            }
        } else {
            #sequence doesn't have an association with a table
            set sequenceIndex 0
            foreach seq $sequenceNames {
                set targetCol [findSequenceTarget model $seq]
                # may return null, but it is already null
                set data [lreplace [lindex $sequenceDatas $sequenceIndex] 0 0 $targetCol]
                if {[set tindex [findListItem target(USER_SEQUENCES.key) $seq]] < 0} {
                    addResult INSERT.SEQS [list $tableName $seq $data] 1
                    addResult ADD.SEQUENCES [list $tableName $seq $data] 0
                } else {
                    addResult INSERT.SEQS [list $tableName $seq $data]  1
                }
                incr sequenceIndex
            }
        }
    }
    # return [list ADD.SEQUENCES $add_sequence_lst INSERT.SEQS $add_seq_table_lst diffs [llength $add_sequence_lst]]
}

# if we need to find the target column of the sequence:
# if the sequence is XXX_SEQENCE, then it should be XXX_UID
# if it is something like XXX_ABC_SEQUENCE, then it should be some other column
# and we will need to make some assumptions.

proc findSequenceTarget {arrayName seqName} {
    upvar $arrayName A
    regsub {_SEQUENCE} $seqName "" seq_prefix
    set seq [string range $seqName 0 2]
    if {$seq == $seq_prefix} {
        set column $seq\_UID
    } else {
        set column $seq_prefix*
    }
    # TODO : use query function if this info doesn't already exist
    if {[info exists A(USER_TAB_COLUMNS.header)] && [set tabIndex [lsearch -glob $A(USER_TAB_COLUMNS.header) $seq*]] >= 0} {
        set table [lindex $A(USER_TAB_COLUMNS.header) $tabIndex]
        set keyIndexes [lsearch -glob -all [lindex $A(USER_TAB_COLUMNS.key) $tabIndex] $column]
        if  {[llength $keyIndexes] == 1} {
            return [lindex [lindex $A(USER_TAB_COLUMNS.key) $tabIndex] [lindex $keyIndexes 0]]
        }
    }
    return ""
}

proc get_Rtargets {arrayName RconstraintName} {
    upvar $arrayName A
    # note this shortcut is because our tables and constraints etc all start with 3 letter prefix
    # however, if it isn't found, it will fail the if
    set tabPrefix [string range $RconstraintName 0 2]
    if {[info exists A(USER_CONS_COLUMNS.header)] && [set tabIndex [lsearch -glob $A(USER_CONS_COLUMNS.header) $tabPrefix*]] >= 0} {
        set table [lindex $A(USER_CONS_COLUMNS.header) $tabIndex]
        set keyIndexes [lsearch -all [lindex $A(USER_CONS_COLUMNS.key) $tabIndex] $RconstraintName]
        set key ""
        set data ""
        #TODO move this out of the select from file and below the if section (once for all if clauses)
        foreach keyI $keyIndexes {
            lappend key [lindex [lindex $A(USER_CONS_COLUMNS.key) $tabIndex] $keyI]
            lappend data [lindex [lindex $A(USER_CONS_COLUMNS.data) $tabIndex] $keyI]
        }
        set rval [list $table $key $data]
    } elseif {$A(source) == "MODELFILES"} {
        set rval [selectFromFile A USER_CONS_COLUMNS "$tabPrefix" $RconstraintName]
    } else {
        set rval [selectFromSchema A USER_CONS_COLUMNS "" $RconstraintName]
    }
    return $rval
}
proc p_compareConstraints { DefA DefB {compare 1}} {
    upvar $DefA A
    upvar $DefB B
    # iterate over each tables constraint definition
    # set missingConstraintList ""
    # set recreateConstraintList ""
    set missingConstraintNames ""
    set recreateConstraintNames ""
    # set validateConstraints ""
    # set enableConstraints ""
    set Rtargets ""
    set i 0
    set Bconstraints ""
    set ATableIndex 0
    foreach Atable $A(USER_CONS_COLUMNS.header) {
        set BtableIndex [lsearch -sorted $B(USER_CONS_COLUMNS.header) $Atable]
        if {$BtableIndex >= 0} {
            set Bconstraints [lindex $B(USER_CONS_COLUMNS.key) $BtableIndex]
            set Bdefs [lindex $B(USER_CONS_COLUMNS.data) $BtableIndex]
        }
        set Aconstraints [lindex $A(USER_CONS_COLUMNS.key) $ATableIndex]
        set Adefs [lindex $A(USER_CONS_COLUMNS.data) $ATableIndex]
        set A_CONSTRAINTS [lindex $A(USER_CONSTRAINTS.key) $ATableIndex]
        # for each table entry, validate the constraints from A to B
        set Aconstrainti 0
        foreach Aconstraint $A_CONSTRAINTS {
            set AcolList ""
            set BcolList ""
            set AcolListOrder ""
            set BcolListOrder ""
            set diff ""
            set AconstraintDATA [lindex [lindex $A(USER_CONSTRAINTS.data) $ATableIndex] $Aconstrainti]
            if {[lindex $AconstraintDATA $A(DEF.USER_CONSTRAINTS.data.index.CONSTRAINT_TYPE)] == "R" && [info exists A(DEF.USER_CONSTRAINTS.data.index.R_CONSTRAINT_NAME)]} {
                set Rtargets [get_Rtargets A [lindex $AconstraintDATA $A(DEF.USER_CONSTRAINTS.data.index.R_CONSTRAINT_NAME)]]
                set A(USER_CONSTRAINTS.RDATA.$Aconstraint) [list [lindex $Rtargets 0] [lindex $Rtargets 2]]
            }
            set Bconstrainti [lsearch -sorted [lindex $B(USER_CONSTRAINTS.key) $BtableIndex] $Aconstraint]
            if {$Bconstrainti < 0} {
                if {[lsearch $missingConstraintNames $Aconstraint] < 0} {
                    #generate the constraint column definition here.
                    set AcolIndexes [lsearch -sorted -all $Aconstraints $Aconstraint]
                    foreach Acolindex $AcolIndexes {
                        lappend AcolList [lindex [lindex $Adefs $Acolindex] $A(DEF.USER_CONS_COLUMNS.data.index.COLUMN_NAME)]
                    }
                    if {[lindex $AconstraintDATA $A(DEF.USER_CONSTRAINTS.data.index.CONSTRAINT_TYPE)] == "R"} {
                        if {$compare} {
                            addResult ADD.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA $Rtargets] 1
                        } else {
                            addResult DROP.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA $Rtargets] 1
                        }
                        # lappend missingConstraintList [list $Atable $Aconstraint $AcolList $AconstraintDATA $Rtargets]
                    } else {
                        if {$compare} {
                            addResult ADD.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA] 1
                        } else {
                            addResult DROP.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA] 1
                        }
                    }
                    lappend missingConstraintNames $Aconstraint
                }
            } elseif {$compare}  {
                set AcolIndexes [lsearch -sorted -all $Aconstraints $Aconstraint]
                set BcolIndexes [lsearch -sorted -all $Bconstraints $Aconstraint] ;# because the constraint names are the same...
                set BconstraintDATA [lindex [lindex $B(USER_CONSTRAINTS.data) $BtableIndex] $Bconstrainti]
                foreach Acolindex $AcolIndexes {
                    lappend AcolList [lindex [lindex $Adefs $Acolindex] $A(DEF.USER_CONS_COLUMNS.data.index.COLUMN_NAME)]
                    lappend AcolListOrder [lindex $Adefs $Acolindex]
                }
                foreach Bcolindex $BcolIndexes {
                    lappend BcolList [lindex [lindex $Bdefs $Bcolindex] $B(DEF.USER_CONS_COLUMNS.data.index.COLUMN_NAME)]
                    lappend BcolListOrder [lindex $Bdefs $Bcolindex]
                }
                set adiffs ""
                set bdiffs ""
                set compList [compareLists $AcolListOrder $BcolListOrder]
                if {[llength [lindex $compList 0]] > 0 || [llength [lindex $compList 1]] > 0} {
                    append diff " -- column mismatch: is: $AcolList should be: $BcolList"
                    if [info exists A(USER_CONSTRAINTS.RDATA.$Aconstraint)] {
                      addWarning RECREATE.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA $Rtargets "Was:$BcolList Should be $AcolList"] 1
                    } else {
                        addWarning RECREATE.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA "Was:$BcolList Should be $AcolList"] 1
                    }
                }
                if {$AconstraintDATA != $BconstraintDATA} {
                    set constraintState ""
                    foreach type $A(DEF.USER_CONSTRAINTS.data) {
                        if {[info exists B(DEF.USER_CONSTRAINTS.data.index.$type)]} {
                            set a [lindex $AconstraintDATA $A(DEF.USER_CONSTRAINTS.data.index.$type)]
                            set b [lindex $BconstraintDATA $B(DEF.USER_CONSTRAINTS.data.index.$type)]
                            if {$a != $b} {
                                if {$type == "VALIDATED"} {
                                    lappend constraintState VALIDATE
                                } elseif {$type == "STATUS"} {
                                    lappend constraintState ENABLE
                                } elseif {$type == "INDEX_NAME"} {
                                    # no action, as add_index should be called.
                                } elseif {$type == "DELETE_RULE"} {
                                    # note: this is added as warning because there is historic data that is incorrect.
                                    if [info exists A(USER_CONSTRAINTS.RDATA.$Aconstraint)] {
                                        addWarning RECREATE.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA $Rtargets "Was:$b Should be $a"] 1
                                    } else {
                                        addWarning RECREATE.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA "Was:$b Should be $a"] 1
                                    }
                                } else {
                                    lappend adiffs $type:$a
                                    lappend bdiffs $type:$b
                                }
                            }
                        }
                    }
                    if {$constraintState != ""} {
                        addWarning ENABLE/VALIDATE.CONSTRAINTS [list $Atable $Aconstraint [join $constraintState]] 1
                    }
                }
                if {!($adiffs == "" && $bdiffs == "")} {
                        append diff " -- definition mismatch: is: [join $bdiffs] should be: [join $adiffs]"
                    if {[lsearch -glob $recreateConstraintNames $Aconstraint] < 0} {
                        if {[lindex $AconstraintDATA $A(DEF.USER_CONSTRAINTS.data.index.CONSTRAINT_TYPE)] == "R"} {
                        #get the column
                            addResult RECREATE.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA $Rtargets $diff] 1
                        } else {
                            addResult RECREATE.CONSTRAINTS [list $Atable $Aconstraint $AcolList $AconstraintDATA $diff] 1
                        }
                        lappend recreateConstraintNames $Aconstraint
                    }
                }
            }
            incr Aconstrainti
        }
        incr ATableIndex
    }
    # return [list $missingConstraintList $recreateConstraintList $enableConstraints $validateConstraints]
}
proc compareConstraints {model target} {
    upvar $model modelDef
    upvar $target targetDef
    set ADD_RECREATE [p_compareConstraints modelDef targetDef 1]
    # since if the constraint has the same name, we have already compared it, so
    # this time we only want to determine if we need to add it
    set DROP [lindex [p_compareConstraints targetDef modelDef 0] 0]
}
# todo: this isn't working
proc handleRenamedItems {addItems dropItems renameArray objectType} {
   upvar $renameArray temp
   set renameItems ""
    if {[info exists temp(RENAMED_OBJECTS.key)] && [info exists temp(RENAMED_OBJECTS.data)]} {
       set ojbectTypes $temp(RENAMED_OBJECTS.key)
       set rdefi 0
        foreach rno $ojbectTypes {
            if {$rno == "$objectType"} {
                set def [lindex $temp(RENAMED_OBJECTS.data) $rdefi]
                if {[set i [lsearch $dropItems [lindex $def $temp(DEF.RENAMED_OBJECTS.data.index.WAS)]]] >= 0 &&  [set j [lsearch $addItems [lindex $def $temp(DEF.RENAMED_OBJECTS.data.index.IS)]]] >= 0} {
                    set dropItems [lreplace $dropItems $i $i]
                    set addItems [lreplace $addItems $j $j]
                    lappend renameItems "$rno [lindex $def $temp(DEF.RENAMED_OBJECTS.data.index.WAS)] [lindex $def $temp(DEF.RENAMED_OBJECTS.data.index.IS)]"
                }
            }
            incr rdefi
        }
    }
    return [list ADD.$objectType\S $addItems DROP.$objectType\S $dropItems RENAME.$objectType\S $renameItems]
}
proc p_compareTables {A_Tables B_Tables} {
    upvar $A_Tables TABLE_A
    upvar $B_Tables TABLE_B
    set notInTables      ""
    # check for TABLE_B tables not in the TABLE_A list
    for {set i 0} {$i < [llength $TABLE_B(USER_TABLES.header)]} {incr i} {
        if {[lsearch $TABLE_A(USER_TABLES.header) [lindex $TABLE_B(USER_TABLES.header) $i]] < 0} {
            lappend notInTables [list [lindex $TABLE_B(USER_TABLES.header) $i] [lindex $TABLE_B(USER_TABLES.key) $i]]
        }
    }
    return $notInTables
}
proc compareTables {targetTables modelTables} {
    upvar $targetTables target
    upvar $modelTables model
    foreach ADD [p_compareTables target model] {
        addResult ADD.TABLES $ADD 1
    }
    foreach DROP [p_compareTables model target] {
        addResult DROP.TABLES $DROP 1
    }
    # return [list ADD.TABLES $ADDS DROP.TABLES $DROPS]
}
#TODO: pull out comparison piece into separate proc.
proc compareColBits {mtypes targetTypes modelCol targetCol} {
    # NOTE: if the modelTableDefs differ from the targetTableDefs we need to find out first
    # if this is due to converting a long raw to blob.  Comparing blob in the schema to
    # long raw in the model should be treated as successful since we are moving to blobs.
    # However, the reverse should be a failure.
    set mi 0
    set modify ""
    if {[regexp {[CB]LOB} [lindex $modelCol [lsearch $mtypes "DATA_TYPE"]]] && [regexp {[CB]LOB} [lindex $targetCol [lsearch $targetTypes "DATA_TYPE"]]]} {
         return ""
    }
    foreach type $mtypes {
        set ti [lsearch $targetTypes $type]
        if {[set modelBit [lindex $modelCol $mi]] != [set targetBit [lindex $targetCol $ti]]} {
            if {$type == "DATA_TYPE"} {
                if {[regexp "BLOB" $targetBit] && [regexp "LONG RAW" $modelBit]} {
                # no need to compare further, whole definition needs changing
                # TODO: this should probably be flagged as a drop/recreate column
                    set modify "$modelCol"
                    break
                }
            } elseif {$type == "DATA_PRECISION" || $type == "DATA_SCALE"} {
                if {!(($targetBit == "" && $modelBit == 0) || ($targetBit == 0 && $modelBit == ""))} {
                    # here we should add "precision is being decreased" if so
                    lappend modify  "$modelCol"
                }
            } elseif {$type == "DATA_DEFAULT"} {
                if {!(($targetBit == "NULL" && $modelBit == "") || ($targetBit == "" && $modelBit == "NULL"))} {
                    # some defaults are wrapped in parens - which parses out the same so we need to compare without it.
                    regsub -all {['\(\)]} $targetBit "" test
                    regsub -all {['\(\)]} $modelBit "" modelBit
                        if {$test != $modelBit} {
                            if {$modelBit == "NULL" || $modelBit == ""} {
                                # Using SETNULL to tell processModifyColumns to reset a default back to null
                                set modelCol [lreplace $modelCol $mi $mi "SETNULL"]
                            }
                            lappend modify "$modelCol"
                    }
                }
            } elseif {$type == "COLUMN_ID"} {
                # not comparing column Id ; do nothing
                # TODO: utilize compareColumns list in DEF
            } else {
                lappend modify  "$modelCol"
            }
        }
        incr mi
    }
    return "[join $modify]"
}
proc getMinType {type array1 array2} {
    upvar $array1 m
    upvar $array2 t
    set typedef ""
    set targetTypes $t(DEF.$type.data)
    foreach type $m(DEF.$type.data) {
        if {[set ti [lsearch $targetTypes $type]] >= 0} {
            lappend typedef $type
        }
    }
    return $typedef
}
proc getMinTypeList {type} {
    global modelDef targetDef
    set columndef ""
    set targetTypes $targetDef(DEF.$type.data)
    foreach type $modelDef(DEF.$type.data) {
        if {[set ti [lsearch $targetTypes $type]] >= 0} {
            lappend columndef $type
        }
    }
    return $columndef
}
proc compareTableColumns {modelTableDefs targetTableDefs} {
    global INDICES
    upvar $modelTableDefs model
    upvar $targetTableDefs target
    set add_column_lst      ""
    set MODCHANGE      ""
    set columndef   [getMinTypeList USER_TAB_COLUMNS]
    for {set modi 0}  {$modi < [llength $model(USER_TAB_COLUMNS.header)]} {incr modi} {
        set ADD_TABLE 0
        set mtable [lindex $model(USER_TAB_COLUMNS.header) $modi]
        if {[lsearch $target(USER_TAB_COLUMNS.header) $mtable] < 0} {
            set ADD_TABLE 1
        }
        set tarj [lsearch -sorted $target(USER_TAB_COLUMNS.header) $mtable]
        set tcols [lindex $target(USER_TAB_COLUMNS.key) $tarj]
        set tdefs [lindex $target(USER_TAB_COLUMNS.data) $tarj]
        set mcols [lindex $model(USER_TAB_COLUMNS.key) $modi]
        set mdefs [lindex $model(USER_TAB_COLUMNS.data) $modi]
        # foreach column, check : if tcol exists, then compare definition
        foreach mcol $mcols mdef $mdefs {
            set tarcolj [lsearch $tcols $mcol]
            if {$tarcolj < 0} {
                if {$ADD_TABLE} {
                    addResult ADD.TAB_COLS [list $mtable $mcol $mdef ] 0
                } else {
                    addResult ADD.COLUMNS [list $mtable $mcol $mdef ] 1
                }
            } elseif {$mdef == [lindex $tdefs $tarcolj]} {
                continue
            } else {
                #compare column def
                set diff [compareColBits $columndef $target(DEF.USER_TAB_COLUMNS.data) $mdef [lindex $tdefs $tarcolj]]
                if {$diff != ""} {
                    # this is a hack because some historic data where the default is wrong.
                    set d ""
                    set i 0
                    foreach m $diff t [lindex $tdefs $tarcolj] type $columndef {
                        if {$m != $t} {
                            if {$type == "COLUMN_ID"} {continue}
                            incr i
                            if {$type == "DATA_DEFAULT"} {set d DD}
                        }
                    }
                    if {$i == 1 && $d == "DD"} {
                        addWarning MODIFY.COLUMNS [list $mtable $mcol $diff [lindex $tdefs $tarcolj]] 1
                    } else {
                        addResult MODIFY.COLUMNS [list $mtable $mcol $diff [lindex $tdefs $tarcolj]] 1
                    }
                }
            }
        }
    }
}

proc getDroppedColumns {modelDef targetDef} {
    upvar $modelDef model
    upvar $targetDef target
    set drop_col_lst ""
    set i -1
    foreach mtable $model(USER_TAB_COLUMNS.header) {
      incr i
        set j [lsearch $target(USER_TAB_COLUMNS.header) $mtable]
        # missing tables already handled elsewhere.
        if {$j >= 0} {
            # search model column def
           foreach t_column [lindex $target(USER_TAB_COLUMNS.key) $j] {
               if { [lsearch  [lindex $model(USER_TAB_COLUMNS.key) $i] $t_column] < 0 } {
                   addResult DROP.COLUMNS [list $mtable $t_column] 1
               }
           }
        }
    }
    # return [list DROP.COLUMNS $drop_col_lst diffs [llength $drop_col_lst]]
}

proc p_compareIndexes { DefA DefB {compare 1}} {
    global INDICES
    upvar $DefA A
    upvar $DefB B
    # iterate over each tables index definition
    if {![info exists A(USER_INDEXES.header)]} {
        return [list "" ""]
    }
    set missingIndexList ""
    set recreateIndexList ""
    set indexColumnList ""
    set i 0
    set Bindexes ""
    set ATableIndex 0
    foreach Atable $A(USER_IND_COLUMNS.header) {
        set BtableIndex [lsearch -sorted $B(USER_IND_COLUMNS.header) $Atable]
        if {$BtableIndex >= 0} {
            set Bindexes [lindex $B(USER_IND_COLUMNS.key) $BtableIndex]
            set Bdefs [lindex $B(USER_IND_COLUMNS.data) $BtableIndex]
        }
        set Aindexes [lindex $A(USER_IND_COLUMNS.key) $ATableIndex]
        set Adefs [lindex $A(USER_IND_COLUMNS.data) $ATableIndex]
        set A_INDEXES [lindex $A(USER_INDEXES.key) $ATableIndex]
        set AIndexi 0
        # go through each index to compare
        foreach Aindex $A_INDEXES {
            set AcolList ""
            set AuicIndexes [lsearch -sorted -all $Aindexes $Aindex]
            # get column order of the index
            array unset tempColumnArray
            array set tempColumnArray ""
            set tempCounter 1
            foreach Acolindex $AuicIndexes {
                if {[lindex [lindex $Adefs $Acolindex] 1] != ""} {
                    set tempColumnArray([lindex [lindex $Adefs $Acolindex] 1]) [lindex [lindex $Adefs $Acolindex] 0]
                } else {
                    set tempColumnArray($tempCounter) [lindex [lindex $Adefs $Acolindex] 0]
                }
                incr tempCounter
            }
            for {set i 1} {$i < $tempCounter} {incr i} {
                lappend AcolList $tempColumnArray($i)
            }
            
            set BIndexj [lsearch -sorted [lindex $B(USER_INDEXES.key) $BtableIndex] $Aindex]
            if {$BIndexj < 0} {
                # eg it is missing
                if {$compare == 1} {
                    # index name does not exist in the target schema - this is all a check to 
                    # see if it is misnamed.
                    set extrasB ""
                    foreach b $Bindexes {
                        if {[lsearch $Aindexes $b] < 0} {
                            if {[lsearch $extrasB $b] < 0} {
                                lappend extrasB $b
                            }
                        }
                    }
                    set matchFound 0 ;# for renaming the index
                    if {$extrasB != ""} {
                        #generate the Model index definition here.
                        # generate each unknown name index definition to see if columns match
                        foreach bxtra $extrasB {
                            set BuicIndexes [lsearch -sorted -all $Bindexes $bxtra]
                            set BcolList ""
                            set tempCounter 1
                            array unset tempColumnArray
                            array set tempColumnArray {}
                            foreach indexNumber $BuicIndexes {
                                if {[lindex [lindex $Bdefs $indexNumber] 1] != ""} {
                                    set tempColumnArray([lindex [lindex $Bdefs $indexNumber] 1]) [lindex [lindex $Bdefs $indexNumber] 0]
                                } else {
                                    set tempColumnArray($tempCounter) [lindex [lindex $Bdefs $indexNumber] 0]
                                }
                                incr tempCounter
                            }
                            for {set i 1} {$i < $tempCounter} {incr i} {
                                lappend BcolList $tempColumnArray($i)
                            }
                            if {[join $BcolList ","] == [join $AcolList ","]} {
                                set matchFound 1
                                break
                            }
                        }
                    }
                    if {$matchFound} {
                        # rename index, ensure it isn't getting dropped. 
                        if {[regexp "$Atable.*$bxtra" [getResults DROP.INDEXS]] == 1} {
                            removeResult [list $Atable $bxtra $Aindex]
                        }
                        addResult RENAME.INDEXS [list $Atable $bxtra $Aindex] 1
                    } else {
                        if {[regexp {_TEXT_} $Aindex] && ![info exists A(TEXT_INDEXES)]} {
                            addResult ADD.TEXT_INDEXS [list $Atable $Aindex $AcolList] 1
                        } else {
                            if {[regexp "$Atable.*$Aindex" [getResults RENAME.INDEXS]] == 0} {
                                addResult ADD.INDEXS [list $Atable $Aindex $AcolList [lindex [lindex [lindex $A(USER_INDEXES.data) $ATableIndex] $AIndexi] $A(DEF.USER_INDEXES.data.index.TABLESPACE_NAME)]] 1
                            }
                        }
                    }
                } else {
                    # drop the index only if it isn't targeted to be renamed. 
                    if {[regexp "$Atable.*$Aindex" [getResults RENAME.INDEXS]] == 0} {
                        addWarning REVIEW.CUSTOM_INDEXS [list $Atable $Aindex $AcolList [lindex [lindex [lindex $A(USER_INDEXES.data) $ATableIndex] $AIndexi] $A(DEF.USER_INDEXES.data.index.TABLESPACE_NAME)]] 1
                    }
                }
            } elseif {$compare}  {
                if {[regexp "TEXT" $Aindex] && [getInfo dbCompare.modelDef.metaSource] == "oldproc"} {
                    #nothing to compare for old model
                } else {
                    set BuicIndexes [lsearch -sorted -all $Bindexes $Aindex] ;# because the index names are the same...
                    set BcolList ""
                    set tempCounter 1
                    array unset tempColumnArray
                    array set tempColumnArray {}
                    foreach indexNumber $BuicIndexes {
                        if {[lindex [lindex $Bdefs $indexNumber] 1] != ""} {
                            set tempColumnArray([lindex [lindex $Bdefs $indexNumber] 1]) [lindex [lindex $Bdefs $indexNumber] 0]
                        } else {
                            set tempColumnArray($tempCounter) [lindex [lindex $Bdefs $indexNumber] 0]
                        }
                        incr tempCounter
                    }
                    for {set i 1} {$i < $tempCounter} {incr i} {
                        lappend BcolList $tempColumnArray($i)
                    }
                    if {$AcolList != $BcolList} {
                        if {[lsearch $recreateIndexList $Aindex] < 0} {
                            lappend recreateIndexList $Aindex
                            addResult RECREATE.INDEXS [list $Atable $Aindex $AcolList [lindex [lindex [lindex $A(USER_INDEXES.data) $ATableIndex] $AIndexi] $A(DEF.USER_INDEXES.data.index.TABLESPACE_NAME)] [list $BcolList [lindex [lindex [lindex $B(USER_INDEXES.data) $BtableIndex] $BIndexj] $B(DEF.USER_INDEXES.data.index.TABLESPACE_NAME)] ]] 1
                        }
                    }
                }
            } ;# not other options?
        }
        incr ATableIndex
    }
}

proc p_compareIndexTablespaces {DefA DefB} {
    upvar $DefA A
    upvar $DefB B

    # set oracle and our default tablespace names
    if {$B(defaultTblspc) == -1} {
        set tablespaces [list MAX2_EHA_TS MAX2_ELA_TS MAX2_SHA_TS MAX2_SLA_TS MAX2_INDEX_S_TS MAX2_INDEX_E_TS]
    } else {
        set tablespaces [list $B(defaultTblspc) MAX2_EHA_TS MAX2_ELA_TS MAX2_SHA_TS MAX2_SLA_TS MAX2_INDEX_S_TS MAX2_INDEX_E_TS]
    }

    # get list of model indexes and data
    set modIndLst ""
    set modIndDataLst ""
    foreach modTabIndLst $A(USER_INDEXES.key) {
        set modIndLst [concat $modIndLst $modTabIndLst]
    }
    foreach modTabIndDataLst $A(USER_INDEXES.data) {
        set modIndDataLst [concat $modIndDataLst $modTabIndDataLst]
    }
    # get list of target indexes and data
    set targetIndLst ""
    set targetIndDataLst ""
    foreach targetTabIndLst $B(USER_INDEXES.key) {
        set targetIndLst [concat $targetIndLst $targetTabIndLst]
    }
    foreach targetTabIndDataLst $B(USER_INDEXES.data) {
        set targetIndDataLst [concat $targetIndDataLst $targetTabIndDataLst]
    }

    # foreach model index find the corresponding target index
    set moveIndLst ""
    foreach modInd $modIndLst modIndData $modIndDataLst {
        if {![regexp {^..._TEXT_INDEX_\d\d$} $modInd]} {
            set ti [lsearch $targetIndLst $modInd]
            set tTblspc [lindex [lindex $targetIndDataLst $ti] 0]
        set mTblspc [lindex $modIndData 0]
            if {$ti >= 0 && [lsearch $tablespaces $tTblspc] >= 0 && $mTblspc != $tTblspc} {
                addWarning MOVE.INDEXS [list $modInd [lindex $modIndData 0] [lindex [lindex $targetIndDataLst $ti] 0] ] 1
            }
        }
    }
    # if the target index is on a table tablespace or the oracle default tablespace add to rebuild list
}

proc compareIndexes {model target} {
    upvar $model modelDef
    upvar $target targetDef

    set ADD_RECREATE [p_compareIndexes modelDef targetDef 1]
    set MOVE_INDEXES [p_compareIndexTablespaces modelDef targetDef]
    # set diffs [llength [lindex $ADD_RECREATE 0]]
    # incr diffs [llength [lindex $ADD_RECREATE 1]]
    set DROP [lindex [p_compareIndexes targetDef modelDef 0] 0]
    # incr diffs [llength $DROP]
    # return [list ADD.INDEXS [lindex $ADD_RECREATE 0] RECREATE.INDEXS [lindex $ADD_RECREATE 1] DROP.INDEXS $DROP diffs $diffs]
}
proc selectFromFile {arrayName objectName headerName keyName} {
    upvar $arrayName A
    array set temp [array get A DEF.*]
    queryModel temp [filejoinx $A(ModDir) $objectName]  $headerName $keyName
    set keyIndex [dbc_getArrayIndexFor temp $objectName "" $keyName]
    set header [lindex $temp($objectName.header) [lindex $keyIndex 0]]
    set key ""
    set data ""
    foreach ki [lindex $keyIndex 1] {
        lappend key [lindex [lindex $temp($objectName.key) [lindex $keyIndex 0] ] $ki]
        lappend data [p_getArrayDatumAt temp $objectName [lindex $keyIndex 0] $ki]
    }
    return [list $header $key $data]
}
proc selectFromSchema {arrayName objectName headerName keyName} {
    upvar $arrayName A
    if {![info exists A(DEF.$objectName)]} {
        array set temp [getMetaData $A(ModDir) $objectName $A(metaSource)]
    } else {
        array set temp [array get A DEF.$objectName*]
        set temp($objectName.header) ""
        set temp($objectName.key) ""
        set temp($objectName.data) ""
    }
    set h $headerName
    if {$headerName == ""} {
        set h "KEYS"
    }
    getObjectData1 $A(connectionString) temp $objectName $h $keyName
    set keyIndex [dbc_getArrayIndexFor temp $objectName $headerName $keyName]
    set header [lindex $temp($objectName.header) [lindex $keyIndex 0]]
    set key ""
    set data ""
    foreach ki [lindex $keyIndex 1] {
        lappend key [lindex [lindex $temp($objectName.key) [lindex $keyIndex 0] ] $ki]
        lappend data [p_getArrayDatumAt temp $objectName [lindex $keyIndex 0] $ki]
    }
    array unset temp
    return [list $header $key $data]
}

proc getOldModels {arrayName utcfile {TABLES ""}} {
    upvar  $arrayName def
    set type [file tail $utcfile]
    if [catch {
        set fid [open $utcfile r]
        } err
    ]  {
        error $err
    }
    set lines [split [string trim [read $fid]] \n]
    close $fid
    if {$type != "USER_OBJECTS"} {
        set keysep $def(DEF.$type.keysep)
        set datasep $def(DEF.$type.datasep)
        set itemList $def(DEF.$type.data)
        set markerstop [string length $def(DEF.$type.heading_marker)]
        set markerlen [expr $markerstop - 1]
    }
    set tab ""
    set TABLEDEFS ""
    set keys ""
    set getData 1
    set header ""
    set keys ""
    set data ""
    set excludedTables [getExcludedTables]

            # special handling for some types that don't have all the items
    if {[lsearch "TOR_TABLE_ORDER DROPPED_TABLES" $type] >= 0} {
        foreach line [split $lines] {
            if {$TABLES == "" || [lsearch $TABLES $line] >= 0} {
               lappend def($type.header) $line
            }
        }
    } elseif {[lsearch "RENAMED_OBJECTS" $type] >= 0} {
        foreach line [split $lines]  {
            set l [split $line $keysep]
            set data [lrange $l 1 end]
            lappend def($type.header) [lindex $l 0]
            lappend def($type.key) [split $data $datasep]
        }
    } elseif {$type == "USER_TABLES"} {
        set tables [lindex $lines 0]
        set tblspaces [lindex $lines 1]
        foreach t $tables b $tblspaces {
            if {[lsearch $excludedTables $t] < 0} {
                lappend def($type.header) $t
                lappend def($type.key) $b
            }
        }
    } elseif {[lsearch "USER_COL_COMMENTS USER_CONS_COLUMNS" $type] >= 0}  {
        set tabPrefix  [string range [lindex $lines 0] 0 2]
        set header ""
        regsub -all \" $lines "" lines ;#"
        foreach line $lines {
            if {[string trim $line] == ""} {continue}
            if {[string range $line 0 0] == "#"} {continue}
            set tabPrefix [string range $line 0 2]
            if {[lsearch $excludedTables $tabPrefix*] >= 0} {
                continue
            }
            if {$tab != $tabPrefix} {
                if {$header != ""} {
                    lappend def($type.header) $header
                    lappend def($type.key) $keys
                    lappend def($type.data) $data
                    set keys ""
                    set data ""
                }
                set hi [lsearch $def(USER_TABLES.header) $tabPrefix*]
                set header [lindex $def(USER_TABLES.header) $hi]
                set tab $tabPrefix
            }
            #TODO: what if key is multi part?
            set keysplit [string first $keysep $line]
            set key [string range $line 0 [incr keysplit -1]]
            set dat [string range $line [incr keysplit 2] end]
            regsub -all {\|} $dat  "\} \{" dat
            set dat \{$dat\}
            if [catch {set dat [join $dat]} err] {
                error "$datasep $dat $err"
            }
            # here we add the column position in the constraint (null for not nulls)
            if {[regexp {NOT_NULL} $key]} {
                lappend keys $key
                lappend data [list $dat ""]
            } else {
                set i 1
                foreach d $dat {
                    lappend keys $key
                    lappend data [list $d $i]
                    incr i
                }
            }

        } ; # end of foreach line
        # add the last definition gathered
        if {$getData && $header != ""} {
            lappend def($type.header) $header
            lappend def($type.key) $keys
            lappend def($type.data) $data
        }
    } elseif {[lsearch "USER_OBJECTS" $type] >= 0} {
        set header ""
        set lastType ""
        foreach line $lines {
            if {[string range $line 0 1] == "->"} {
                set type [string trim [string range $line 2 end]]
                if {$type == "TRIGGERS"} {
                    set type "USER_TRIGGERS"
                }
                if {$lastType != "" } {
                    lappend def($lastType.header) $header
                    lappend def($lastType.key) $keys
                    lappend def($lastType.data) $data ;#[lappend data $dat]
                    set keys ""
                    set data ""
                }
                set keysep $def(DEF.$type.keysep)
                set datasep $def(DEF.$type.datasep)
                set itemList $def(DEF.$type.data)
                set tab ""
                set header ""
                continue
            }
            if {[lsearch $excludedTables $tab] >= 0} {
                continue
            }
            if {$tab != $header } {
                if {$header != ""} {
                    lappend def($type.header) $header
                    lappend def($type.key) $keys
                    lappend def($type.data) $data
                    set keys ""
                    set data ""
                }
            }
            set tab $header
            regsub -all {!!!} $line "\} \{" line
            set line \{$line\}
            if {$type == "USER_TRIGGERS"} {
                set lastType "USER_TRIGGERS"
                set tabp [string range [lindex $line 0] 0 2]
                set hi [lsearch $def(USER_TABLES.header) $tabp*]
                set header [lindex $def(USER_TABLES.header) $hi]
                set key [lindex $line 0]
                set dat [lrange $line 1 end]
            } elseif {$type == "TEXT_INDEXES"} {
                set lastType "TEXT_INDEXES"
                set header [lindex $line 1]
                set key [lindex $line 0]
                set dat [lrange $line 2 end]
            }
            lappend keys $key
            lappend data $dat
        } ; # end of foreach line
        # add the last definition gathered
        if {$header != ""} {
            lappend def($type.header) $header
            lappend def($type.key) $keys
            lappend def($type.data) $data
        }
    } elseif {$type == "USER_CONSTRAINTS"} {
        foreach line $lines {
            if {[string trim $line] == ""} {continue}
            if {[string range $line 0 0] == "#"} {continue}
            set hsplit [string first $keysep $line]
            set header [string range $line 0 [incr hsplit -1]]
            if {[lsearch $excludedTables $header] >= 0} {
                continue
            }
            set line [string range $line [incr hsplit 2] end]
            set keysplit [string first $keysep $line]
            set keys [string range $line 0 [incr keysplit -1]]
            set data [string range $line [incr keysplit 2] end]
            lappend def($type.header) $header
            lappend def($type.key) $keys
            lappend def($type.data) $data
        } ; # end of foreach line
        # add the last definition gathered
            lappend def($type.header) $header
            lappend def($type.key) $keys
            lappend def($type.data) $data
    } elseif {[lsearch "USER_IND_COLUMNS" $type] >= 0} {
        set indexes [lindex $lines 0]
        set tables [lindex $lines 1]
        set columns [lindex $lines 2]
        set lastTable ""
        set lastIndex ""
        set indexColumnList ""
        set indexNameList ""
        foreach index $indexes table $tables column $columns {
            # if next table, then append lists to def
            if {$lastIndex != $index } {
                #if next index, sum up column info
                # sum up index
                set counter 1
                foreach col $indexColumnList ind $indexNameList {
                    lappend data [list $col $counter]
                    lappend keys $ind
                    incr counter
                }
                set indexColumnList ""
                set indexNameList ""
                set lastIndex $index
            }
            lappend indexColumnList $column
            lappend indexNameList $index
            if {[lsearch $excludedTables $table] >= 0} {
                continue
            }
            if {$lastTable != $table } {
                if {$lastTable != ""} {
                #sum up table
                # add the last iteration
                    lappend def($type.header) $lastTable
                    lappend def($type.key) $keys
                    lappend def($type.data) $data
                    set keys ""
                    set data ""
                }
                set lastTable $table
                # set lastIndex $index
            }
        }
        set counter 1
        foreach col $indexColumnList ind $indexNameList {
            lappend data [list $col $counter]
            lappend keys $ind
            incr counter
        }
        lappend def($type.header) $lastTable
        lappend def($type.key) $keys
        lappend def($type.data) $data
    } elseif {$type == "USER_INDEXES"} {
        set indexes [lindex $lines 0]
        set tablespaces [lindex $lines 1]
        set header ""
        foreach i $indexes t $tablespaces {
            set tabPrefix [string range $i 0 2]
            if {[lsearch $excludedTables $tabPrefix*] >= 0} {
                continue
            }
            if {$tab != $tabPrefix} {
                if {$header != ""} {
                    lappend def($type.header) $header
                    lappend def($type.key) $keys
                    lappend def($type.data) $data
                }
                set hi [lsearch $def(USER_TABLES.header) $tabPrefix*]
                set header [lindex $def(USER_TABLES.header) $hi]
                set tab $tabPrefix
                set keys ""
                set data ""
            }
            lappend keys $i
            lappend data $t
        }
        lappend def($type.header) $header
        lappend def($type.key) $keys
        lappend def($type.data) $data
    } elseif {[lsearch "USER_SEQUENCES" $type] >= 0} {
        set sequences [lindex $lines 0]
        set values [lindex $lines 1]
        set columns [lindex $lines 2]
        set tab ""
        set index ""
        set keys ""
        set data ""
        foreach s $sequences v $values c $columns {
            set t [string range $s 0 2]
            set hi [lsearch $def(USER_TABLES.header) $t*]
            set header [lindex $def(USER_TABLES.header) $hi]
            if {[lsearch $excludedTables $header] >= 0} {
                continue
            }
            if {$header != $tab} {
                if {$tab != ""} {
                    #sum up table
                    lappend def($type.header) $tab
                    lappend def($type.key) $keys
                    lappend def($type.data) $data
                }
                set keys ""
                set data ""
                set tab $header
            }
            set tab $header
            lappend keys $s
            lappend data [list $c $v]
        }
        lappend def($type.header) $tab
        lappend def($type.key) $keys
        lappend def($type.data) $data
    } elseif {[lsearch "USER_TAB_COLUMNS" $type] >= 0} {
        for {set i 0} {$i < [llength $lines]} {incr i} {
            set tab [lindex $lines $i]
            incr i
            set cols [lindex $lines $i]
            incr i
            set vals [lindex $lines $i]
            foreach c $cols v $vals {
                lappend keys $c
                lappend data [split $v $datasep]
            }
            if {[lsearch $excludedTables $tab] < 0} {
                lappend def($type.header) $tab
                set sortedCols ""
                set sortedData ""
                foreach col [lsort $keys] {
                    set cc [lsearch $keys $col]
                    lappend sortedCols [lindex $keys $cc]
                    lappend sortedData [lindex $data $cc]
                }
                lappend def($type.key) $sortedCols
                lappend def($type.data) $sortedData
            }
            set keys ""
            set data ""
        }
    }
}
proc getModel {arrayName utcfile {TABLES ""}} {
    upvar  $arrayName def
    set type [file tail $utcfile]
    if [catch {
        set fid [open $utcfile r]
        } err
    ]  {
        error $err
    }
    set lines [split [read $fid] \n]
    close $fid
    set headerLine [lindex $lines 0]
    if {[regexp {^#[\s]*header} $headerLine]} {
        set lines [string trim [lrange $lines 1 end]]
    }
    set keysep $def(DEF.$type.keysep)
    set datasep $def(DEF.$type.datasep)
    set itemList $def(DEF.$type.data)
    set markerstop [string length $def(DEF.$type.heading_marker)]
    set markerlen [expr $markerstop - 1]
    set tab ""
    set TABLEDEFS ""
    set keys ""
    set DATA ""
    set getData 1
    set header ""
        # special handling for some types
    if {[lsearch "TOR_TABLE_ORDER DROPPED_TABLES" $type] >= 0} {
        foreach line $lines {
            set line [string trim $line]
            if {$line == ""} {continue}
            if {[string range $line 0 0] == "#"} {continue}
            if {$TABLES == "" || [lsearch $TABLES $line] >= 0} {
                if {[lsearch [getExcludedTables] [string trim $line]] < 0} {
                    lappend def($type.header) $line
                }
            }
        }
    } elseif {[lsearch "RENAMED_OBJECTS" $type] >= 0} {
        foreach line $lines {
            set l [split $line $keysep]
            set data [lrange $l 1 end]
            lappend def($type.header) [lindex $l 0]
            lappend def($type.key) [split $data $datasep]
        }
    } else {
        set i 0
        foreach line $lines {
            incr i
            if {[string trim $line] == ""} {continue}
            if {[string range $line 0 0] == "#"} {continue}
            if {[string range $line 0 $markerlen] == "$def(DEF.$type.heading_marker)"} {
                set header [string range [string trim $line] $markerstop end]
                if {[llength $header] > 1 } {
                    error "Model File for type $type is corrupted: getModel.table.notFound: line $i row $line length [llength $header]\n$header"
                }
                # now excluding the conversion logging tables
                if {$tab != "" && $getData && [lsearch [getExcludedTables] $tab] < 0} {
                    lappend def($type.header) $tab
                    lappend def($type.key) $keys
                    lappend def($type.data) $DATA
                }
                if { ($TABLES == "" || [lsearch $TABLES $header] >= 0)} {
                    set keys ""
                    set DATA ""
                    set getData 1
                }  else {
                    set getData 0
                }
                set tab $header
                continue
            }
            if {$getData} {
            #TODO: what if key is multi part?
                # set items [split [string trimleft $line] $keysep]
                # set key [lindex $items 0]
                # set data [lindex $items 1]
                set ki [string first $keysep $line]
                set key [string range $line 0 [expr $ki - 1]]
                set data [string range $line [expr $ki + 1] end]
                lappend keys $key
                if {$datasep != ""} {
                    lappend DATA [split $data $datasep]
                } else {
                    lappend DATA $data
                }
            }
        } ; # end of foreach line
        # add the last definition gathered
        if {$getData && $header != ""} {
            lappend def($type.header) $header
            lappend def($type.key) $keys
            lappend def($type.data) $DATA
        }
    }
}
proc queryModel {arrayName utcfile headerVal keyVal} {
    upvar  $arrayName def
    set type [file tail $utcfile]
    set baseDir [file dirname $utcfile]
    set tabFile [glob $baseDir/USER_TABLES]
    set fid [open $tabFile r]
    set lines [split [read $fid] \n]
    close $fid
    set header [lindex $lines 0]
    if {[regexp {^#[\s]*header} $header]} {
        set lines [lrange $lines 1 end]
    }
    set header ""
    set markerstop [string length $def(DEF.$type.heading_marker)]
    set markerlen [expr $markerstop - 1]
    foreach line $lines {
        set line [string trim $line]
        if {$line == ""} {continue}
        if {[string range $line 0 0] == "#"} {continue}
        if {[string range $line 0 $markerlen] == "$def(DEF.$type.heading_marker)"} {
            set header [string range [string trim $line] $markerstop end]
            if {[llength $header] > 1 } {
                error "Model File for type $type is corrupted: getModel.table.notFound: line $i row $line length [llength $header]\n$header"
            }
            if {[regexp ^$headerVal.* $header ]} {break}
            set header ""
        }
    }
    if {$header != ""} {
        getModel def $utcfile $header
    } else {
        error "Model table prefix $headerVal cannot be found. Model must be invalid."
    }
}


proc getObjectData1 {dbh arrayName type {tableName ""} {keys ""} } {
   upvar $arrayName temp

   if {$type == "TEXT_INDEXES"} {
        getSchemaTextIndexData temp $dbh TEXT_INDEXES $tableName
        return
   } elseif {$type == "USER_SEQUENCES"} {
        p_getSchemaSequenceData $dbh temp $tableName
        return
   } elseif {$type == "USER_PROCEDURES"} {
        p_getSchemaProcedureData $dbh temp $tableName
        return
   }
    set selectData ""
    if {$temp(DEF.$type.data) != {}} {
       set selectData $temp(DEF.$type.data)
    }
    set isolate ""
    set isolateCols ""
    if {[info exists temp(DEF.$type.isolateColumns)] && $temp(DEF.$type.isolateColumns) != ""} {
        foreach c $temp(DEF.$type.isolateColumns) {
            regsub $c $selectData "" selectData
            lappend isolateCols $c
        }
        set isolate [makeSQLcols $type $isolateCols]
    }
    set type_params ""
    set sqlcols [makeSQLcols $type "$temp(DEF.$type.header) $temp(DEF.$type.key) $selectData"]
    set SQL " from $type $type "
    if {[info exists temp(DEF.$type.FROM)]} {
        append SQL ", $temp(DEF.$type.FROM) $temp(DEF.$type.FROM) "
    }
    if {[regexp "TABLE_NAME" $temp(DEF.$type.header)]} {
        if {($tableName == "" || $tableName == "*")} {
           append SQL ", TOR_TABLE_ORDER TTO where $type.$temp(DEF.$type.header) = TTO.TOR_TABLE_NAME "
        } elseif {$tableName == "KEYS"} {
            append SQL " where $type.$temp(DEF.$type.key) in ('[join $keys "','"]')"
        } else {
            append SQL " where $type.$temp(DEF.$type.header) in ('[join $tableName "','"]')"
        }
    }
    set results ""
    if {[info exists temp(DEF.$type.WHERE)] && $temp(DEF.$type.WHERE) != ""} {
        append SQL " and $temp(DEF.$type.WHERE)"
    }
    if {[info exists temp(DEF.$type.ORDER_BY)] && $temp(DEF.$type.ORDER_BY) != ""} {
        append SQL " order by $temp(DEF.$type.ORDER_BY)"
    }
    catch {set filename [runSQL $dbh $type "$sqlcols" "$SQL" results $isolate]} err
    # adds values to the temp array from results
    parseSchemaValues temp results $type [concat $selectData $isolateCols]
    if {$type == "USER_COL_COMMENTS"} {
        populateNullComments temp
    }
}
proc parseSchemaValues {arrayName result type type_data} {
    upvar $arrayName temp
    upvar $result  results

    set head ""
    set all_names ""
    set all_data ""
    set dataend [expr [llength $type_data] + $temp(DEF.$type.index.data)]
    # temp(DEF.$type.header) eg DEF.USER_TABLES.header -> TABLE_NAME
    # this generates a list that allows each type to iterate through the header values,
    # and have a complete list of the objects of that type eg all table names
    if {[lsearch "USER_TRIGGERS USER_COL_COMMENTS USER_PROCEDURES TEXT_INDEXES" $type] < 0} {
        regsub -all {'} $results "" results
    }
    foreach row $results {
        if {[string trim $row] == ""} {continue}
        set header [lindex $row $temp(DEF.$type.index.header)]
        if {$header != $head} {
            if {[lsearch -sorted $temp($type.header) $header] < 0} {
                lappend temp($type.header)  $header
            }
            if {$head != ""} {
                lappend temp($type.key) $all_names
                if {$dataend > $temp(DEF.$type.index.data)} {
                    lappend temp($type.data) $all_data
                }
                set all_names ""
                set all_data ""
            }
            set head $header
        }
        lappend all_names [lindex $row $temp(DEF.$type.index.key)]
        set t ""
        for {set j $temp(DEF.$type.index.data)} {$j < $dataend} {incr j} {
            lappend t [lindex $row $j]
        }
        lappend all_data $t
    }
    lappend temp($type.key) $all_names
    if {$dataend > $temp(DEF.$type.index.data)} {
        lappend temp($type.data) $all_data
    }
}
proc escape_comments {comment} {
    foreach c [split $comment "|"] {
        if {[regexp \# $c]} {
            set c \"$c\"
        }
        lappend newcomment $c
    }
}
proc populateNullComments {arrayName} {
    upvar $arrayName temp
    set tempdata ""
    foreach clist $temp(USER_COL_COMMENTS.data) {
        set templist ""
        foreach ci $clist {
            if {$ci == "{}"} {set ci "||||||"}
            lappend templist [join $ci]
        }
        lappend tempdata $templist
    }
    set temp(USER_COL_COMMENTS.data) $tempdata
}
# TODO move to format proc
proc getdbcSeparator {} {
    return "#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#"
}
proc getHeader {fileName} {
    set headers ""
    if [catch {open $fileName r} fid] {
        return -1
    }
    set conts [split [read $fid] \n]
    close $fid
    foreach line [lrange $conts 0 3] { ; #allow for deviations in header structure, eg blank line or comments
        if {[lindex $line 0] == "#header"} {
            set header [string trimleft $line "#"]
            set typeIndex [lsearch $header "OBJECT_TYPE"]
            if {$typeIndex < 0} {
                set type [file tail $fileName]
                lappend header "OBJECT_TYPE"
                lappend header "$type"
            } else {
                # as list is in name/value format value should be next item
                incr typeIndex
                set type [lindex $header $typeIndex]
            }
            lappend headers [list "DEF.$type" "$header"]
            break ; # only one header definition allowed per file
        }
    }
    return $headers
}
proc getNonDatabaseTypes {} {
    return "DROPPED_TABLES RENAMED_OBJECTS"
}
proc getModelTypes {modFileDir} {
    set types ""
    foreach type [getObjectTypes *] {
        if {[file exists [file join $modFileDir $type]]} {
            lappend types $type
        }
    }
    return $types
}
proc getObjectTypes {type} {
    set allTypes [getInfo dbCompare.OBJECT_TYPES]
    if {$allTypes == ""} {
        set allTypes "USER_TABLES USER_TAB_COLUMNS USER_CONSTRAINTS USER_CONS_COLUMNS USER_INDEXES USER_IND_COLUMNS TEXT_INDEXES USER_TRIGGERS USER_SEQUENCES USER_PROCEDURES"
    }
    set addedtypes [getInfo dbCompare.ADD_TYPES]
    foreach t $addedtypes {
        if {[lsearch $allTypes $t] < 0} {
            lappend allTypes $t
        }
    }
    foreach t [getInfo dbCompare.IGNORE_LIST] {
        if {[set i [lsearch $allTypes $t]] >= 0} {
            set allTypes [lreplace $allTypes $i $i ]
        }
    }
    updateInfo dbCompare.OBJECT_TYPES $allTypes
   set types ""
    if {$type == "all" || $type == "" || $type == "*"} {
      set types $allTypes
    } else {
        foreach t [string toupper $type] {
            if {[lsearch $allTypes $t] >= 0} {
                lappend types $t
            } else {
                error "\nDDL type $t is invalid.\nShould be one of: \n\n[join $allTypes "\n"] \n"
            }
        }
    }
   return $types
}
proc setResultsMetadata {arrayName object action} {
    upvar $arrayName results
    set results (DEF.ADD.COLUMNS)
    set results (DEF.ADD)
    set results (DEF.ADD)
    set results (DEF.ADD)
    set results (DEF.ADD)
    set results (DEF.ADD)
    set results (DEF.RECREATE)
    set results (DEF.DROP)
    set results (DEF.RENAME)
    set results (DEF.MODIFY)
    set results (DEF.COLLIDE)
}
# NOTE: this should only be used if no model files are available (like doing a database to database comparison.
proc setTypes {{type "all"}} {
    set headers ""
    if {$type == "all" || $type == "DROPPED_TABLES" || $type == ""} {
        lappend headers [list "DEF.DROPPED_TABLES" [list header DROPPED_TABLES heading_marker {} key TABLE_NAME keysep {} datasep {} data {}  type $type] ]
    }
    if {$type == "all" || $type == "RENAMED_OBJECTS" || $type == ""} {
        lappend headers [list "DEF.RENAMED_OBJECTS" [list header RENAMED_OBJECTS heading_marker {} key OBJECT_TYPE keysep # datasep > data WAS>IS  type $type] ]
    }
    if {$type == "all" || $type == "USER_COL_COMMENTS" || $type == ""} {
        lappend headers [list "DEF.USER_COL_COMMENTS" [list header "TABLE_NAME" heading_marker "->" key COLUMN_NAME keysep # datasep "" data COMMENTS  ORDER_BY USER_COL_COMMENTS.TABLE_NAME,USER_COL_COMMENTS.COLUMN_NAME type $type]]
    }
    if {$type == "all" || $type == "USER_CONS_COLUMNS" || $type == ""} {
        lappend headers [list "DEF.USER_CONS_COLUMNS" [list header TABLE_NAME heading_marker -> key CONSTRAINT_NAME keysep # datasep ! data COLUMN_NAME!POSITION ORDER_BY USER_CONS_COLUMNS.TABLE_NAME,USER_CONS_COLUMNS.CONSTRAINT_NAME,USER_CONS_COLUMNS.POSITION type $type]]
    }
    if {$type == "all" || $type == "USER_CONSTRAINTS" || $type == ""} {
        lappend headers [list "DEF.USER_CONSTRAINTS" [list header TABLE_NAME heading_marker -> key CONSTRAINT_NAME keysep # datasep ! data CONSTRAINT_TYPE!DELETE_RULE!INDEX_NAME!R_CONSTRAINT_NAME!VALIDATED!STATUS ORDER_BY USER_CONSTRAINTS.TABLE_NAME,USER_CONSTRAINTS.CONSTRAINT_NAME type $type]]
    }
    if {$type == "all" || $type == "USER_IND_COLUMNS" || $type == ""} {
        lappend headers [list "DEF.USER_IND_COLUMNS" [list header TABLE_NAME heading_marker -> key INDEX_NAME keysep # datasep ! data COLUMN_NAME!COLUMN_POSITION FROM "USER_INDEXES" WHERE "USER_INDEXES.INDEX_TYPE LIKE ('%NORMAL%') and USER_INDEXES.INDEX_NAME = USER_IND_COLUMNS.INDEX_NAME" ORDER_BY USER_IND_COLUMNS.TABLE_NAME,USER_IND_COLUMNS.INDEX_NAME,USER_IND_COLUMNS.COLUMN_POSITION type $type]]
    }
    if {$type == "all" || $type == "USER_INDEXES" || $type == ""} {
       lappend headers [list "DEF.USER_INDEXES" [list header TABLE_NAME heading_marker -> key INDEX_NAME keysep # datasep ! data TABLESPACE_NAME!INDEX_TYPE!UNIQUENESS!ITYP_NAME!VISIBILITY WHERE "INDEX_TYPE LIKE ('%NORMAL%')" COMPARE INDEX_TYPE!UNIQUENESS!ITYP_NAME!VISIBILITY ORDER_BY USER_INDEXES.TABLE_NAME,USER_INDEXES.INDEX_NAME type $type]]
    }
    if {$type == "all" || $type == "USER_OBJECTS" || $type == "TEXT_INDEXES" || $type == "USER_OBJECTS.TEXT_INDEXES" || $type == ""} {
        lappend headers [list "DEF.TEXT_INDEXES" [list header TABLE_NAME heading_marker -> key INDEX_NAME keysep # datasep ! data COLUMN_NAME!INDEX_TYPE!ITYP_NAME!PARAMETERS WHERE {USER_INDEXES.ITYP_OWNER='CTXSYS' AND USER_INDEXES.INDEX_NAME=USER_IND_COLUMNS.INDEX_NAME} ORDER_BY USER_INDEXES.TABLE_NAME,USER_INDEXES.INDEX_NAME,USER_IND_COLUMNS.COLUMN_POSITION type $type]]
    }
    if {$type == "all" || $type == "USER_SEQUENCES" || $type == ""} {
        lappend headers [list "DEF.USER_SEQUENCES" [list header TABLE_NAME heading_marker -> key SEQUENCE_NAME keysep # datasep ! data TARGET_COLUMN!SITE_VALUE_BEGIN!MAX_VALUE!INCREMENT_BY!MIN_VALUE!CACHE_SIZE!CYCLE_FLAG ORDER_BY USER_SEQUENCES.SEQUENCE_NAME WHERE "substr(SEQUENCE_NAME,1,3) in (select substr(TOR_TABLE_NAME,1,3) from TOR_TABLE_ORDER) and substr(SEQUENCE_NAME, -8, 8) = 'SEQUENCE'" type $type]]
    }
    if {$type == "all" || $type == "USER_TAB_COLUMNS" || $type == ""} {
        lappend headers [list "DEF.USER_TAB_COLUMNS" [list header TABLE_NAME heading_marker -> key COLUMN_NAME keysep # datasep ! data DATA_TYPE!DATA_LENGTH!DATA_PRECISION!DATA_SCALE!COLUMN_ID!DATA_DEFAULT isolateColumns DATA_DEFAULT ORDER_BY USER_TAB_COLUMNS.TABLE_NAME,USER_TAB_COLUMNS.COLUMN_NAME map TABLE_NAME=USER_TABLES.TABLE_NAME COMPARE DATA_TYPE!DATA_LENGTH!DATA_PRECISION!DATA_SCALE!DATA_DEFAULT WHERE {COLUMN_NAME not like 'DROP%'} type $type]]
    }
    if {$type == "all" || $type == "USER_TABLES" || $type == ""} {
        lappend headers [list "DEF.USER_TABLES" [list header TABLE_NAME heading_marker -> key TABLESPACE_NAME keysep # datasep # data {} ORDER_BY USER_TABLES.TABLE_NAME map TABLE_NAME=USER_TAB_COLUMNS.TABLE_NAME type $type]]
    }
    if {$type == "all" || $type == "USER_OBJECTS" || $type == "USER_TRIGGERS" || $type == "USER_OBJECTS.TRIGGERS" || $type == ""} {
        lappend headers [list "DEF.USER_TRIGGERS" [list header TABLE_NAME heading_marker -> key TRIGGER_NAME keysep # datasep ! data TRIGGER_TYPE!TRIGGERING_EVENT!WHEN_CLAUSE!DESCRIPTION!TRIGGER_BODY isolateColumns TRIGGER_BODY ORDER_BY USER_TRIGGERS.TABLE_NAME,USER_TRIGGERS.TRIGGER_NAME WHERE "TRIGGER_NAME not like 'AUDIT%' AND TRIGGER_NAME != 'TJN_UPDATE_TRIGGER'" type $type]]
    }
    if {$type == "all" || $type == "USER_OBJECTS" || $type == "USER_PROCEDURES" || $type == "USER_OBJECTS.PROCEDURES" || $type == ""} {
        lappend headers [list "DEF.USER_PROCEDURES" [list header OBJECT_NAME heading_marker -> key AUTHID keysep # datasep {} data USER_SOURCE.TEXT isolateColumns USER_SOURCE.TEXT  type $type]]
    }
    return $headers
}
# OLD TYPE are for pre 3.0 versions without any header in the model files.
proc setOldTypes {{type "all"}} {
    set headers ""
    if {$type == "all" || $type == "USER_COL_COMMENTS" || $type == ""} {
        lappend headers [list "DEF.USER_COL_COMMENTS" [list header "TABLE_NAME" heading_marker "" key COLUMN_NAME keysep | datasep "|" data COMMENTS  ORDER_BY USER_COL_COMMENTS.TABLE_NAME,USER_COL_COMMENTS.COLUMN_NAME type $type]]
    }
    if {$type == "all" || $type == "USER_CONS_COLUMNS" || $type == ""} {
        lappend headers [list "DEF.USER_CONS_COLUMNS" [list header TABLE_NAME heading_marker "" key CONSTRAINT_NAME keysep # datasep "" data "COLUMN_NAME POSITION" ORDER_BY USER_CONS_COLUMNS.TABLE_NAME,USER_CONS_COLUMNS.CONSTRAINT_NAME,USER_CONS_COLUMNS.POSITION type $type]]
    }
    if {$type == "all" || $type == "USER_CONSTRAINTS" || $type == ""} {
        lappend headers [list "DEF.USER_CONSTRAINTS" [list header TABLE_NAME heading_marker "" key CONSTRAINT_NAME keysep # datasep # data CONSTRAINT_TYPE ORDER_BY USER_CONSTRAINTS.TABLE_NAME,USER_CONSTRAINTS.CONSTRAINT_NAME type $type]]
    }
    if {$type == "all" || $type == "USER_IND_COLUMNS" || $type == ""} {
        lappend headers [list "DEF.USER_IND_COLUMNS" [list header TABLE_NAME heading_marker "" key INDEX_NAME keysep "" datasep "" data COLUMN_NAME FROM "USER_INDEXES" WHERE "INDEX_TYPE != 'LOB' and USER_INDEXES.INDEX_NAME = USER_IND_COLUMNS.INDEX_NAME" ORDER_BY USER_IND_COLUMNS.TABLE_NAME,USER_IND_COLUMNS.INDEX_NAME,USER_IND_COLUMNS.COLUMN_POSITION type $type]]
    }
    if {$type == "all" || $type == "USER_INDEXES" || $type == ""} {
       lappend headers [list "DEF.USER_INDEXES" [list header TABLE_NAME heading_marker "" key INDEX_NAME keysep "" datasep "" data TABLESPACE_NAME WHERE "INDEX_TYPE != 'LOB'" ORDER_BY USER_INDEXES.TABLE_NAME,USER_INDEXES.INDEX_NAME type $type]]
    }
    if {$type == "all" || $type == "USER_SEQUENCES" || $type == ""} {
        lappend headers [list "DEF.USER_SEQUENCES" [list header TABLE_NAME heading_marker "" key SEQUENCE_NAME keysep "" datasep "" data TARGET_COLUMN!SITE_VALUE_BEGIN ORDER_BY USER_SEQUENCES.SEQUENCE_NAME WHERE "substr(SEQUENCE_NAME,1,3) in (select substr(TOR_TABLE_NAME,1,3) from TOR_TABLE_ORDER) and substr(SEQUENCE_NAME, -8, 8) = 'SEQUENCE'" type $type]]
    }
    if {$type == "all" || $type == "USER_TAB_COLUMNS" || $type == ""} {
        lappend headers [list "DEF.USER_TAB_COLUMNS" [list header TABLE_NAME heading_marker "" key COLUMN_NAME keysep "" datasep ! data DATA_TYPE!DATA_LENGTH!DATA_PRECISION!DATA_SCALE isolateColumns DATA_DEFAULT ORDER_BY USER_TAB_COLUMNS.TABLE_NAME,USER_TAB_COLUMNS.COLUMN_NAME map TABLE_NAME=USER_TABLES.TABLE_NAME WHERE {COLUMN_NAME not like 'DROP%'} type $type]]
    }
    if {$type == "all" || $type == "USER_TABLES" || $type == ""} {
        lappend headers [list "DEF.USER_TABLES" [list header TABLE_NAME heading_marker "" key TABLESPACE_NAME keysep "" datasep "" data {} ORDER_BY USER_TABLES.TABLE_NAME map TABLE_NAME=USER_TAB_COLUMNS.TABLE_NAME type $type]]
    }
    # if {$type == "all" || $type == "USER_OBJECTS" || $type == "USER_TRIGGERS" || $type == "USER_OBJECTS.TRIGGERS" || $type == ""} {
        # lappend headers [list "DEF.USER_TRIGGERS" [list header TABLE_NAME heading_marker -> key TRIGGER_NAME keysep # datasep ! data TRIGGER_TYPE!TRIGGERING_EVENT!WHEN_CLAUSE!DESCRIPTION!TRIGGER_BODY isolateColumns TRIGGER_BODY ORDER_BY USER_TRIGGERS.TABLE_NAME,USER_TRIGGERS.TRIGGER_NAME type USER_TRIGGERS]]
    # }
    # if {$type == "all" || $type == "USER_OBJECTS" || $type == "TEXT_INDEXES" || $type == "USER_OBJECTS.TEXT_INDEXES" || $type == ""} {
        # lappend headers [list "DEF.TEXT_INDEXES" [list header TABLE_NAME heading_marker -> key INDEX_NAME keysep # datasep ! data COLUMN_NAME!INDEX_TYPE!PARAMETERS WHERE {USER_INDEXES.ITYP_OWNER='CTXSYS' AND USER_INDEXES.INDEX_NAME=USER_IND_COLUMNS.INDEX_NAME} ORDER_BY USER_INDEXES.TABLE_NAME,USER_INDEXES.INDEX_NAME,USER_IND_COLUMNS.COLUMN_POSITION type TEXT_INDEXES]]
    # }
    return $headers
}


proc getConnectionSetup {arrayName connectionString modelDirectory} {
    upvar $arrayName temp
    set temp(defaultTblspc) -1
    if {$connectionString == {}} {
        set temp(source)    ""
        set temp(connectDisplay)    ""
        set target_info      ""
        set temp(modDirName)        ""
        set temp(schemaVersion)    ""
        set temp(prd)  CR ;#    "" ; # todo - once we have product, then we can get prefix
        set temp(product)   "" ; # todo - how to get it from information we have in mod files?
        set temp(ModDir) ""
    } elseif {![file exists $connectionString] && [regexp {.+/.+@.+} $connectionString]} {
        set temp(source)    "DATABASE"
        set temp(connectDisplay)    [getDisplayConnection $connectionString]
        if [catch {array set temp [checkLogon.Oracle $connectionString]} err] {
            error [p_runtimeError "Connection error using $temp(connectDisplay) \n$err"]
        }
        set temp(schemaVersion)    [getSchemaVersionsPLSQL $temp(connectionString)]
        set temp(product)   [getSchemaProductPLSQL $temp(connectionString)]
        set temp(prd)   [getProductPrefix $temp(product)]
        set temp(product) [getProductName $temp(prd) ]
        set temp(modDirName) [getVersionModDirName $temp(schemaVersion) [getInfo WORKING_DIRECTORY] ]
        set temp(defaultTblspc) [GetOracleDefaultTablespace $temp(connectionString)]
        if {$temp(modDirName) != ""} {
            set temp(ModDir) [file join $modelDirectory $temp(modDirName)]
        } else {
            error [p_runtimeError "Schema target version $temp(schemaVersion) does not exist in the AutoConversion.txt file."]
        }
    } else {
        set temp(source)    "MODELFILES"
        set temp(connectDisplay)    $connectionString
        set temp(modDirName)        $connectionString
        set temp(schemaVersion)    [getFirstDriverRowInfo "$temp(modDirName)" schemaVersion]
        set temp(prd) [getFirstDriverRowInfo "$temp(modDirName)" prd]
        set temp(product) [getProductName $temp(prd) ]
        set temp(ModDir)  [file join $modelDirectory $temp(modDirName)]
        if {![file exists $temp(ModDir)]} {
            error [p_runtimeError "Model file directory $temp(modDirName) does not exist in $modelDirectory"]
        }
        if [catch {getModFileVer "$temp(ModDir)"} temp(schemaVersion) ] {
            error [p_runtimeError "Model file directory $temp(modDirName) in $modelDirectory is invalid.\n$temp(schemaVersion)"]
        }
    }
    set temp(ARRAY_NAME) $arrayName
    updateInfo dbCompare.$temp(ARRAY_NAME).connectDisplay $temp(connectDisplay)
    updateInfo dbCompare.$temp(ARRAY_NAME).source $temp(source)
    updateInfo dbCompare.$temp(ARRAY_NAME).schemaVersion $temp(schemaVersion)
    updateInfo dbCompare.$temp(ARRAY_NAME).product $temp(product)
    if {[validateTor temp] == -1} {
        error [p_runtimeError "Cannot validate TOR table for version $targetDef(schemaVersion)."]
    }
    return
}
#header should include DEF.$type as the first value, the header array definition as the second.
proc parseHeader {header type} {
    array set temp $header
    set typeIndex [lsearch $header "OBJECT_TYPE"]
    if {$typeIndex >= 0} {
        # as list is in name/value format value should be next item
        incr typeIndex
        set type [lindex $header $typeIndex]
        set def(DEF.OBJECT_TYPE) $type
    }
    set temp(DEF.TYPES) $type
    set temp(DEF.$type) [lindex $header 1]
    foreach {n v} $temp(DEF.$type) {
        set temp(DEF.$type.$n) $v
        if {$n == "header" || $n == "key" || $n == "data"} {
            # initialize array value to null some may not be used, but avoids null pointers
            set temp($type.$n) ""
        }
    }
    # TODO this is hardcoded for now... move into meta data description would be better.
    # to do : is this needed?  where is it used?
    set temp(DEF.$type.index.header) 0
    set temp(DEF.$type.index.key) 1
    set temp(DEF.$type.index.data) 2
    set i 0
    # separtate data item list,  get the index for each data column
    if {$temp(DEF.$type.datasep) != {}} {
        set temp(DEF.$type.data) [split $temp(DEF.$type.data) $temp(DEF.$type.datasep)]
    }
    foreach d  $temp(DEF.$type.data) {
        set temp(DEF.$type.data.index.$d) $i
        incr i
    }
    return [array get temp]
}
proc setInitialNulls {arrayName} {
    upvar $arrayName temp
    foreach type $temp(DEF.TYPES) {
        set temp($type.header) ""
        set temp($type.key) ""
        set temp($type.data) ""
    }
}

proc getMetaDataSource {modelArray targetArray} {
    upvar $modelArray model
    upvar $targetArray target
    set modelTypes ""
    set targetTypes ""
    if {$model(source) == "MODELFILES" } {
        # if model header exists, use that
        set modelTypes [getModelTypes $model(ModDir)]
        if {$modelTypes == ""} {error "no modelfiles found in $model(ModDir)"}
        if {[set h [getHeader [file join $model(ModDir) USER_TABLES]]] == "" } {
            updateInfo dbCompare.$modelArray.metaSource oldproc
            updateInfo dbCompare.$modelArray.metaSourceLocation $model(ModDir)
        } else {
            updateInfo dbCompare.$modelArray.metaSource MODELFILES
            updateInfo dbCompare.$modelArray.metaSourceLocation $model(ModDir)
        }
        if {$target(source) == "MODELFILES"} {
            set targetTypes [getModelTypes $target(ModDir)]
            if {$targetTypes == ""} {error "no modelfiles found in $target(ModDir)"}
            if {[set t [getHeader [file join $target(ModDir) USER_TABLES]]] == "" } {
                updateInfo dbCompare.$targetArray.metaSource oldproc
                updateInfo dbCompare.$targetArray.metaSourceLocation ""
            } else {
                updateInfo dbCompare.$targetArray.metaSource MODELFILES
                updateInfo dbCompare.$targetArray.metaSourceLocation $target(ModDir)
            }
        } elseif {$target(source) == "DATABASE"} {
            updateInfo dbCompare.$targetArray.metaSource [getInfo dbCompare.$modelArray.metaSource]
            updateInfo dbCompare.$targetArray.metaSourceLocation [getInfo dbCompare.$modelArray.metaSourceLocation]
        } else {
            updateInfo dbCompare.$targetArray.metaSource [getInfo dbCompare.$modelArray.metaSource]
            updateInfo dbCompare.$targetArray.metaSourceLocation [getInfo dbCompare.$modelArray.metaSourceLocation]
        }
    } elseif {$model(source) == "DATABASE"} {
        if {$target(source) == "MODELFILES"} {
            set targetTypes [getModelTypes $target(ModDir)]
            if {$targetTypes == ""} {error "no modelfiles found in $target(ModDir)"}
            if {[set t [getHeader [file join $target(ModDir) USER_TABLES]]] == "" } {
                updateInfo dbCompare.$targetArray.metaSource oldproc
            } else {
                updateInfo dbCompare.$targetArray.metaSource MODELFILES
                updateInfo dbCompare.$targetArray.metaSourceLocation $target(ModDir)
            }
            updateInfo dbCompare.$modelArray.metaSource [getInfo dbCompare.$targetArray.metaSource]
            updateInfo dbCompare.$modelArray.metaSourceLocation [getInfo dbCompare.$targetArray.metaSourceLocation]
        } elseif {$target(source) == "DATABASE"} {
            if {[file exists [file join [getInfo dbCompare.MODEL_FILES_DIRECTORY] $model(prd).$model(schemaVersion)]]} {
                set model(ModDir) [file join [getInfo dbCompare.MODEL_FILES_DIRECTORY] $model(prd).$model(schemaVersion)]
                set modelTypes [getModelTypes $model(ModDir)]
                if {$modelTypes == ""} {
                    updateInfo dbCompare.$modelArray.metaSource typeproc
                    updateInfo dbCompare.$modelArray.metaSourceLocation "typeproc"
                } else {
                    if {[set h [getHeader [file join $model(ModDir) USER_TABLES]]] == "" } {
                        updateInfo dbCompare.$modelArray.metaSource typeproc
                    } else {
                        updateInfo dbCompare.$modelArray.metaSource MODELFILES
                        updateInfo dbCompare.$modelArray.metaSourceLocation $model(ModDir)
                    }
                }
                updateInfo dbCompare.$targetArray.metaSource [getInfo $modelArray.metaSource]
                updateInfo dbCompare.$targetArray.metaSourceLocation [getInfo dbCompare.$modelArray.metaSourceLocation]
            } elseif {[file exists [file join [getInfo dbCompare.MODEL_FILES_DIRECTORY] $target(prd).$target(schemaVersion)]]} {
                set target(ModDir) [file join [getInfo dbCompare.MODEL_FILES_DIRECTORY] $target(prd).$target(schemaVersion)]
                set targetTypes [getModelTypes $target(ModDir)]
                if {$targetTypes == ""} {
                    updateInfo dbCompare.$modelArray.metaSource typeproc
                    updateInfo dbCompare.$modelArray.metaSourceLocation "typeproc"
                } else {
                    if {[set t [getHeader [file join $target(ModDir) USER_TABLES]]] == "" } {
                        updateInfo dbCompare.$modelArray.metaSource typeproc
                    } else {
                        updateInfo dbCompare.$modelArray.metaSource MODELFILES
                        updateInfo dbCompare.$modelArray.metaSourceLocation $target(ModDir)
                    }
                }
                updateInfo dbCompare.$targetArray.metaSource [getInfo $modelArray.metaSource]
                updateInfo dbCompare.$targetArray.metaSourceLocation [getInfo dbCompare.$modelArray.metaSourceLocation]
            } else {
                updateInfo dbCompare.$modelArray.metaSource typeproc
                updateInfo dbCompare.$modelArray.metaSourceLocation "typeproc"
                updateInfo dbCompare.$targetArray.metaSource typeproc
                updateInfo dbCompare.$targetArray.metaSourceLocation "typeproc"
            }
        } else {
            # no target specified,
            if {[file exists [file join [getInfo dbCompare.MODEL_FILES_DIRECTORY] $model(prd).$model(schemaVersion)]]} {
                set model(ModDir) [file join [getInfo dbCompare.MODEL_FILES_DIRECTORY] $model(prd).$model(schemaVersion)]
                set modelTypes [getModelTypes $model(ModDir)]
                if {$modelTypes == ""} {
                    updateInfo dbCompare.$modelArray.metaSource typeproc
                    updateInfo dbCompare.$modelArray.metaSourceLocation "typeproc"
                } else {
                    if {[set h [getHeader [file join $model(ModDir) USER_TABLES]]] == "" } {
                        updateInfo dbCompare.$modelArray.metaSource typeproc
                    } else {
                        updateInfo dbCompare.$modelArray.metaSource MODELFILES
                        updateInfo dbCompare.$modelArray.metaSourceLocation $model(ModDir)
                    }
                }
                updateInfo dbCompare.$targetArray.metaSource [getInfo $modelArray.metaSource]
                updateInfo dbCompare.$targetArray.metaSourceLocation [getInfo dbCompare.$modelArray.metaSourceLocation]
            } else {
                updateInfo dbCompare.$modelArray.metaSource typeproc
                updateInfo dbCompare.$modelArray.metaSourceLocation "typeproc"
                updateInfo dbCompare.$targetArray.metaSource typeproc
                updateInfo dbCompare.$targetArray.metaSourceLocation "typeproc"
            }
        }
    } else {
        if {$target(source) == "MODELFILES"} {
            set targetTypes [getModelTypes $target(ModDir)]
            if {$targetTypes == ""} {error "no modelfiles found in $target(ModDir)"}
            if {[set t [getHeader [file join $target(ModDir) USER_TABLES]]] == "" } {
                updateInfo dbCompare.$targetArray.metaSource oldproc
                updateInfo dbCompare.$targetArray.metaSourceLocation ""
            } else {
                updateInfo dbCompare.$targetArray.metaSource MODELFILES
                updateInfo dbCompare.$targetArray.metaSourceLocation $target(ModDir)
            }
            updateInfo dbCompare.$modelArray.metaSource [getInfo dbCompare.$targetArray.metaSource]
            updateInfo dbCompare.$modelArray.metaSourceLocation [getInfo dbCompare.$targetArray.metaSourceLocation]
        } elseif {$target(source) == "DATABASE"} {
            if {[file exists [file join [getInfo dbCompare.MODEL_FILES_DIRECTORY] $target(prd).$target(schemaVersion)]]} {
                set target(ModDir) [file join [getInfo dbCompare.MODEL_FILES_DIRECTORY] $target(prd).$target(schemaVersion)]
                set targetTypes [getModelTypes $target(ModDir)]
                if {$targetTypes == ""} {
                    updateInfo dbCompare.$modelArray.metaSource typeproc
                    updateInfo dbCompare.$modelArray.metaSourceLocation "typeproc"
                } else {
                    if {[set h [getHeader [file join $target(ModDir) USER_TABLES]]] == "" } {
                        updateInfo dbCompare.$modelArray.metaSource typeproc
                        updateInfo dbCompare.$modelArray.metaSourceLocation ""
                    } else {
                        updateInfo dbCompare.$modelArray.metaSource MODELFILES
                        updateInfo dbCompare.$modelArray.metaSourceLocation $target(ModDir)
                    }
                }
                updateInfo dbCompare.$targetArray.metaSource [getInfo dbCompare.$modelArray.metaSource]
                updateInfo dbCompare.$targetArray.metaSourceLocation [getInfo dbCompare.$modelArray.metaSourceLocation]
            } else {
                updateInfo dbCompare.$modelArray.metaSource typeproc
                updateInfo dbCompare.$modelArray.metaSourceLocation ""
                updateInfo dbCompare.$targetArray.metaSource [getInfo dbCompare.$modelArray.metaSource]
                updateInfo dbCompare.$targetArray.metaSourceLocation [getInfo dbCompare.$modelArray.metaSourceLocation]
            }
        }
    }
    set types ""
    if {$modelTypes == ""} {set types $targetTypes}
    if {$targetTypes == ""} {set types $modelTypes}
    if {$types == ""} {
        set tt ""
        foreach t $modelTypes {
            if {[lsearch $targetTypes $t] >= 0} {
                lappend tt $t
            }
        }
        foreach t $targetTypes {
            if {[lsearch $tt $t] >= 0} {
                lappend types $t
            }
        }
    }
    updateInfo dbCompare.OBJECT_TYPES $types
    set model(metaSource) [getInfo dbCompare.$modelArray.metaSource]
    set target(metaSource) [getInfo dbCompare.$targetArray.metaSource]
}
proc setMetaDataSource {arrayName type} {
    updateInfo dbCompare.$arrayName.metaType $type
}
proc getMetaData {modDir {types "all"} sourceType} {
    if {$types == "all"} {
    set allTypes [getInfo dbCompare.OBJECT_TYPES] ;# gets list like "USER_TABLES...."
    } else {
        set allTypes $types
    }
    # We want to use the definition in the modelFile if it exists; else use the procedure to set the values.
    set dbTypes ""
    foreach type $allTypes {
        if {$sourceType == "MODELFILES"} {
            if {[catch {getHeader [file join $modDir $type]} headers]} {
                error "Could not get metadata from [file join $modDir $type] : $headers"
            }
        } elseif {$sourceType == "typeproc"} {
            set headers [setTypes $type] ; # this gets defition from hard coded proc.
        } elseif {$sourceType == "oldproc"} { ; # this gets defition from hard coded proc for older modelfiles.
            set headers [setOldTypes $type]
        }
        foreach header $headers {
            array set temp [parseHeader $header $type]
            lappend dbTypes $temp(DEF.TYPES)
        }
    }
    set temp(DEF.TYPES) $dbTypes
    return [array get temp]
}

proc makeTabModel {arrayName type dir {TABLES ""}} {
upvar $arrayName temp
    if {$TABLES == ""} {
        set fid [open $dir/$type w]
    } else {
        if {[llength $TABLES] == 1} {
            set fid [open $dir/$type.$TABLES w]
        } else {
            set fid [open $dir/$type.multi w]
        }
    }
    # put the array definition as the header
    puts $fid "#$temp(DEF.$type)"
    array set def $temp(DEF.$type)
    if {$def(datasep) != ""} {
        set data_lst [split $def(data) "$def(datasep)"]
    } else {
        set data_lst $def(data)
    }
    set keysep $def(keysep)
    set key $def(key)
    set datasep $def(datasep)
    set keyvals ""
    set datavals ""
    set i 0
    set tab ""
    for {set tableIndex 0} {$tableIndex < [llength $temp($type.header)]} {incr tableIndex} {
    if {[lindex $temp($type.header) $tableIndex] == ""} {continue}
        set table [lindex $temp($type.header) $tableIndex]
        set keyvals [lindex $temp($type.key) $tableIndex]
        set datavals [lindex $temp($type.data)  $tableIndex]
        regsub -all {\n} $datavals "\\\\n" datavals
        if {$TABLES == "" || [lsearch $TABLES $table] >= 0} {
            if {$table != $tab} {
                puts $fid "$def(heading_marker)$table"
            }
            foreach keyval $keyvals d $datavals {
                if {$keyval == ""} {continue}
                if {$def(datasep) == ""} {
                    puts $fid [join $keyval $def(keysep)]$def(keysep)$d
                } else {
                    puts $fid "[join $keyval $def(keysep)]$def(keysep)[join $d $def(datasep)]"
                }
            }
        }
        set tab $table
    }
    close $fid
    return
}

proc getSchemaVersionsPLSQL {connect {types "CREATE EB UPDATE"}} {
    set versions ""
    set types [string toupper $types]
    set SQL "from SHS_SCHEMA_HISTORY
    WHERE SHS_UID = (
    SELECT MAX(SHS_UID) from SHS_SCHEMA_HISTORY
    where SHS_TYPE in ([sqlList $types])
    and SHS_VERSION_NEW is not null
    and SHS_VERSION_NEW not like '-%'
    and upper(SHS_RESULTS) != 'STARTED'
    and lower(SHS_SQL_SCRIPT_NAME) like '%.sql')"
    set version ""
    set outfile [runSQL $connect VERSION "SHS_VERSION_NEW" $SQL version]
    set version [join [p_pad_version [lindex $version 0] ] "."]
    return $version
}
proc getSchemaProductPLSQL {connect} {
    set sysname ""
    set sql "from sys_system_configuration
    where nvl(sys_last_update_date, sys_create_date) =
    (select max(nvl(sys_last_update_date, sys_create_date)) from sys_system_configuration)"
    set outfile [runSQL $connect SYS_NAME SYS_APPLICATION_NAME $sql sysname]
    return [lindex $sysname 0]
}
proc formatResults {resultsArray type} {
    set line "[break_lines [getdbcSeparator] $type]"
    foreach listName [array names results($type)] {

    }
}
proc dbCompare.getDescription {} {
    return "Schema validation script
dbCompare.tcl generates a report listing all schema differences between
the model and the target schema descriptions."
}

proc getDefinitions {arrayName TABLES} {
    upvar $arrayName temp
    set IGNORELIST "DROPPED_TABLES RENAMED_OBJECTS"
     set types $temp(DEF.TYPES)

    if {$temp(source) == "DATABASE"} {
        foreach type $types {
            if {[lsearch $IGNORELIST $type] >= 0 } {
                continue
            }
            putt "Obtaining Schema Definitions from $type."
            getObjectData1 $temp(connectionString) temp $type $TABLES
        }
    } elseif {$temp(source) == "MODELFILES"} {
        putt "Obtaining Model Definitions from [file tail $temp(ModDir)]"
        foreach type $types {
            if {$temp(metaSource) == "oldproc"} {
                getOldModels temp [file join $temp(ModDir) $type]  $TABLES
            } else {
                getModel temp [file join $temp(ModDir) $type]  $TABLES
            }
        }
    }
}
proc getDefaultResults {} {
    return [list number_of_changes 0 diffs 0 chg_precision_lst 0]
}
proc getListNames {} {
    return [list Results Warnings]
}
proc processDrop1 {listName type} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName] DROP.$type\S] {
            lappend out "exec LANDA_CONVERSION.DROP_$type ('[lindex $item 1]');\n -- from Table [lindex $item 0]"
        }
    }
    return $out
}
proc reviewCustomIndex {listName name} {
    set out ""
    lappend out "--CUSTOM INDEXES to REVIEW"
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  $name] {
            if {[lindex $item 0] != ""} {
            lappend out "--exec LANDA_CONVERSION.DROP_INDEX ('[lindex $item 0]','[lindex $item 1]');\n -- from Table [lindex $item 0]"
            }
        }
    }
    return $out
}
proc processDrop2 {listName type} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  DROP.$type\S] {
            lappend out "exec LANDA_CONVERSION.DROP_$type ('[lindex $item 0]','[lindex $item 1]');\n -- from Table [lindex $item 0]"
        }
    }
    return $out
}
proc processDropColumn {listName} {
    set out ""
        set saveData "Y"
        if {[getInfo AUTO_DROP] == "Y"} {
            set saveData "N"
        }
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  DROP.COLUMNS] {
            lappend out "exec LANDA_CONVERSION.DROP_COLUMN ('[lindex $item 0]','[lindex $item 1]','$saveData'); \n-- from Table [lindex $item 0]"
        }
    }
    return $out
}
proc processDrop0 {listName type} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  DROP.$type\S] {
            lappend out "exec LANDA_CONVERSION.DROP_$type ('[lindex $item 0]'); "
        }
    }
    return $out
}
proc processRename {listName type} {
    set out ""
    foreach listName [getListNames] {
        if {[lsearch {INDEX TABLE TEXT_INDEX TRIGGER} $type] >= 0} {
            foreach item [[subst get$listName]  RENAME.$type\S] {
                lappend out "exec LANDA_CONVERSION.RENAME_$type ('[lindex $item 1]','[lindex $item 2]'); \n-- from Table [lindex $item 0]"
            }
        } else {
            foreach item [[subst get$listName]  RENAME.$type\S] {
                lappend out "exec LANDA_CONVERSION.RENAME_$type ('[lindex $item 0]','[lindex $item 1]','[lindex $item 2]');"
            }
        }
    }
    return $out
}
proc processAddColumn {listName} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  ADD.COLUMNS] {
            array set coldef [parseColumn [lindex $item 2]]
            set default $coldef(DEFAULT)
            if {$default != ""} {
                set default ",'$default'"
            }
            lappend out "exec LANDA_CONVERSION.ADD_COLUMN ('[lindex $item 0]','[lindex $item 1]','$coldef(DATA_TYPE)','$coldef(LENGTH)'$default);"
        }
    }
    return $out
}
proc parseColumn {coldef} {
    array set DEF [getDefaultMeta]
    set datatype [lindex $coldef $DEF(DEF.USER_TAB_COLUMNS.data.index.DATA_TYPE)]
    set length [lindex $coldef $DEF(DEF.USER_TAB_COLUMNS.data.index.DATA_LENGTH)]
    if {[lsearch "NUMBER DECIMAL FLOAT DOUBLE_PRECISION" $datatype] >= 0} {
        set precision [lindex $coldef $DEF(DEF.USER_TAB_COLUMNS.data.index.DATA_PRECISION)]
        lappend precision [lindex $coldef $DEF(DEF.USER_TAB_COLUMNS.data.index.DATA_SCALE)]
        set length [join $precision ","]
    }
    if {[regexp {(TIMESTAMP)(\(\d+\))} $datatype foo dat num]} {
        set datatype TIMESTAMP
        regsub -all {[\(\)]} $num "" length
    }
    if {[lsearch "DATE CLOB BLOB BINARY_DOUBLE" $datatype] >= 0} {
        set length ""
    }
    if {$length != ""} {
        set length "($length)"
    }
    if {[info exists DEF(DEF.USER_TAB_COLUMNS.data.index.DATA_DEFAULT)]} {
        set default [string trim [lindex $coldef $DEF(DEF.USER_TAB_COLUMNS.data.index.DATA_DEFAULT)] ']
    } else {set default ""}
    if {$default == "NULL"} {set default ""}
    # This allows reset of a default value that is not null back to null - see compareColBits.
    if {$default == "SETNULL"} {set default "NULL"}
    set column_id ""
    if {[info exists DEF(DEF.USER_TAB_COLUMNS.data.index.COLUMN_ID)]} {
        set column_id [lindex $coldef $DEF(DEF.USER_TAB_COLUMNS.data.index.COLUMN_ID)]
    }
    return [list DATA_TYPE $datatype LENGTH $length DEFAULT $default COLUMN_ID $column_id]
}
proc processModifyColumn {listName} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  MODIFY.COLUMNS] {
            array set coldef [parseColumn [lindex $item 2]]
            array set olddef [parseColumn [lindex $item 3]]
            set default $coldef(DEFAULT)
            if {$default != ""} {
                set default ",'$default'"
            }
            lappend out "exec LANDA_CONVERSION.MODIFY_COLUMN ('[lindex $item 0]','[lindex $item 1]','$coldef(DATA_TYPE)','$coldef(LENGTH)'$default);\n -- WAS '$olddef(DATA_TYPE)','$olddef(LENGTH)','$olddef(DEFAULT)'"
        }
    }
    return $out
}
proc processAddTI {listName prefix type} {
    set out ""
    array set DEF [getDefaultMeta]
    set tableName ""
    set indexName ""
    set columnName ""
    set itypName ""
    set params ""
    foreach listName [getListNames] {
    # column table column datatype leng default constraintclause
        foreach item [[subst get$listName]  $prefix.$type\S] {
            set tableName [lindex $item 0]
            set indexName [lindex $item 1]
            if {[info exists DEF(DEF.TEXT_INDEXES.data.index.COLUMN_NAME)]} {
                set columnName [lindex [lindex $item 2] $DEF(DEF.TEXT_INDEXES.data.index.COLUMN_NAME)]
                set itypName [lindex [lindex $item 2] $DEF(DEF.TEXT_INDEXES.data.index.ITYP_NAME)]
                set params [lindex [lindex $item 2] $DEF(DEF.TEXT_INDEXES.data.index.PARAMETERS)]
            }
            if {$columnName == ""} {
                lappend out "-- exec LANDA_CONVERSION.CREATE_$type ('$indexName','$tableName','$columnName','$itypName','$params');"
            } else {
                lappend out "exec LANDA_CONVERSION.CREATE_$type ('$indexName','$tableName','$columnName','$itypName','$params');"
            }
        }
    }
    return $out
}
proc processAddProcedure {listName {prefix "ADD"}} {
    array set def [getDefaultMeta]
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  $prefix.PROCEDURES] {
            set code [join [lindex $item 2]]
            lappend out "CREATE OR REPLACE [join $code]\n/"
        }
    }
    return $out
}
proc processAddTrigger {listName {prefix "ADD"}} {
    array set def [getDefaultMeta]
    set out ""
    foreach listName [getListNames] {
    # column table column datatype leng default constraintclause
        foreach item [[subst get$listName]  $prefix.TRIGGERS] {
            set items [lindex $item 2]
            set whenclause [lindex $items $def(DEF.USER_TRIGGERS.data.index.WHEN_CLAUSE)]
            if {[regexp -nocase {TGRB_U} [lindex $items 3]]} {
                lappend out "exec LANDA_CONVERSION.CREATE_RECORD_VERSION_TRIGGER('[lindex $item 0]');"
            } else {
            if {$whenclause != ""} {set whenclause "WHEN ($whenclause)"}
            lappend out "exec LANDA_CONVERSION.CREATE_TRIGGER ('[lindex $items $def(DEF.USER_TRIGGERS.data.index.DESCRIPTION)]','$whenclause','[lindex $items $def(DEF.USER_TRIGGERS.data.index.TRIGGER_BODY)]');"
                }
        }
    }
    return $out
}
proc orderColumns {columns defs} {
    set cols ""
    set i 1
    foreach c $columns d $defs {
        array set coldef [parseColumn $d]
        if {$coldef(COLUMN_ID) == ""} {
            set id $i
        } else {
            set id $coldef(COLUMN_ID)
        }
        lappend ids $id
        lappend deflist [array get coldef]
        incr i
    }
    set ordered [lsort -integer $ids]
    set newID 1
    foreach o $ordered {
        set i [lsearch $ids $o]
        set col [lindex $columns $i]
        lappend cols [list COLUMN.$newID [lindex $columns $i] DEF.$newID [lindex $deflist $i]]
        set ids [lreplace $ids $i $i XXXX] ;# preserves the list length and ordering
        incr newID
    }
    return [join $cols]
}
# todo: refactoring has required using results as a global:

proc processAddTable {listName} {
    global modelDef RESULTS
    set out ""
    foreach listName [getListNames] {
    foreach item [[subst get$listName]  ADD.TABLES] {
        set TABLENAME [lindex $item 0]
        set TABLESPACE [lindex $item 1]
        set addcols [lsearch -all $RESULTS(ADD.TAB_COLS) $TABLENAME*]

        set columns ""
        set coldefs ""
        foreach index $addcols {
            lappend columns [lindex [lindex $RESULTS(ADD.TAB_COLS) $index] 1] ;# results(index.addcolumns.column_name)
            lappend coldefs [lindex [lindex $RESULTS(ADD.TAB_COLS) $index] 2]
        }
        array unset colItems
        array set colItems [orderColumns $columns $coldefs]
        set column $colItems(COLUMN.1)

        array set coldef $colItems(DEF.1)
        set default $coldef(DEFAULT)
        if {$default != ""} {
            set default ",'$default'"
        }
        lappend out "exec LANDA_CONVERSION.CREATE_TABLE ('$TABLENAME','$TABLESPACE','$column','$coldef(DATA_TYPE)','$coldef(LENGTH)'$default);"
        set tempColId 1
        for {set i 2} {$i <= [llength $columns]} {incr i} {
            incr tempColId
            if {[catch {
            set column $colItems(COLUMN.$tempColId)
            array set coldef $colItems(DEF.$tempColId)
            set default $coldef(DEFAULT)
            } err] } {continue}
            if {$default != ""} {
                set default ",'$default'"
            }
            lappend out "exec LANDA_CONVERSION.ADD_COLUMN ('$TABLENAME','$column','$coldef(DATA_TYPE)','$coldef(LENGTH)'$default);"
        }
    }
    }
    return $out
}
proc processAddIndex {listName name} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  $name] {
            if {[lindex $item 0] != ""} {
                lappend out "exec LANDA_CONVERSION.ADD_INDEX ('[lindex $item 1]','[lindex $item 0]','[join [lindex $item 2] ","]','[lindex $item 3]');"
            }
        }
    }
    return $out
}
proc processMoveIndTablespace {listName name} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  $name] {
            if {[lindex $item 0] != ""} {
                lappend out "exec LANDA_CONVERSION.MOVE_IND_TBLSPC ('[lindex $item 0]','[lindex $item 1]');"
            }    
        }
    }
    return $out
}
proc processRECREATE_INDEX_DROP {listName} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  RECREATE.INDEXS] {
            if {[lindex $item 0] != ""} {
                lappend out " -- from Table [lindex $item 0] \n --        column mismatch: is [lindex [lindex $item 4] 0] should be: [lindex $item 2]\nexec LANDA_CONVERSION.DROP_INDEX ('[lindex $item 1]');"
            }
        }
    }
    return $out
}
proc processAddConstraint {listName name} {
    set outc ""
    set outp ""
    set outu ""
    set outr ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  $name] {
            set constraintType [lindex [lindex $item 3] 0]
            switch $constraintType {
                "C" {
                    lappend outc "exec LANDA_CONVERSION.ADD_NOT_NULL ('[lindex $item 0]','[lindex [lindex $item 2] 0]','[lindex $item 1]');"
                }
                "P" {
                    lappend outp "exec LANDA_CONVERSION.ADD_PRIMARY_KEY ('[lindex $item 0]','[lindex $item 1]','[join [lindex $item 2] ","]');"
                }
                "U" {
                    lappend outu "exec LANDA_CONVERSION.ADD_UNIQUE ('[lindex $item 0]','[lindex $item 1]','[join [lindex $item 2] ","]');"
                }
                "R" {
                    set rTable [lindex $item 9]
                    if {$rTable != {}} {
                        set rColumns  [join [lindex [split [lindex $item 11]] 0] ","]
                        set onDelete [lindex $item 4]
                    } else {
                        set rtabprefix [lindex $item 1]
                        set j [string first "_" $rtabprefix]
                        set rtabprefix [string range $rtabprefix [incr j] end]
                        set j [string first "_" $rtabprefix]
                        set rtabprefix [string range $rtabprefix 0 [incr j -1]]
                        set rtabi [lsearch $::modelDef(USER_TABLES.header) $rtabprefix*]
                        set rTable [lindex $::modelDef(USER_TABLES.header) $rtabi]
                        set tconi [lsearch $::modelDef(USER_CONSTRAINTS.header) $rTable]
                        set tconj [lsearch [lindex $::modelDef(USER_CONSTRAINTS.key) $tconi] *PRIMARY_KEY]
                        set rkey [lindex [lindex $::modelDef(USER_CONSTRAINTS.key) $tconi] $tconj]
                        set rColumns [join [lindex [lindex [lindex $::modelDef(USER_CONS_COLUMNS.data) $tconi] $tconj] $::modelDef(DEF.USER_CONS_COLUMNS.data.index.COLUMN_NAME)] ","]
                        set onDelete [lindex [lindex $item 3] 1]
                    }
                    if {$onDelete == "NO ACTION" || $onDelete == ""} {
                        set onDelete ""
                    } else {
                        set onDelete "ON DELETE $onDelete"
                    }
                    lappend outr "exec LANDA_CONVERSION.ADD_FOREIGN_KEY ('[lindex $item 0]','[lindex $item 1]','[join [lindex $item 2] ","]','$rTable','$rColumns','$onDelete');"
                }
                default {
                    lappend outr "exec LANDA_CONVERSION.ADD_CONSTRAINT ('[lindex $item 0]','[lindex $item 1]','[join [lindex $item 2] ","]','[lindex $item 3]');"
                }
            }
        }
    }
    return [concat $outc $outp $outu $outr]
}
proc processRECREATE_CONSTRAINT_DROP {listName} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  RECREATE.CONSTRAINTS] {
            if {[lindex $item 0] != ""} {
                lappend out "  -- [lindex $item end]\nexec LANDA_CONVERSION.DROP_CONSTRAINT ('[lindex $item 0]','[lindex $item 1]');"
            }
        }
    }
    return $out
}
proc processRECREATE_CONSTRAINT_ADD {listName} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  RECREATE.CONSTRAINTS] {
            lappend out "-- [lindex $item end]\nexec LANDA_CONVERSION.DROP_CONSTRAINT ('[lindex $item 0]','[lindex $item 1]'); "
        }
    }
    return $out
}
proc processEnableConstraint {listName} {
    set out ""
    foreach listName [getListNames] {
        foreach constraint [[subst get$listName]  ENABLE/VALIDATE.CONSTRAINTS] {
            if {[lindex $constraint 0] != ""} {
                lappend out "exec LANDA_CONVERSION.ENABLE_CONSTRAINT('[lindex $constraint 0]', '[lindex $constraint 1]');"
            }
        }
    }
    return $out
}
proc processValidateConstraint {listName} {
    set out ""
    # foreach listName [getListNames] {
        # foreach constraint [[subst get$listName]  ENABLE/VALIDATE.CONSTRAINTS] {
            # if {[lindex $constraint 0] != ""} {
                # # We should have VALIDATE.CONSTRAINTS procudure in LANDA_CONVERSION package
                # # to handle this situation
                # # Commenting out the next statement. RE-1417
                # # lappend out "exec LANDA_CONVERSION.ENABLE_CONSTRAINT('[lindex $constraint 0]', '[lindex $constraint 1]');"
            # }
        # }
    # }
    return $out
}
proc processAddSequence {listName} {
    set out ""
    # TARGET_COLUMN!SITE_VALUE_BEGIN!MAX_VALUE!INCREMENT_BY!MIN_VALUE!CACHE_SIZE!CYCLE_FLAG
    # 0TARGET_COLUMN!1SITE_VALUE_BEGIN!2MAX_VALUE!3INCREMENT_BY!4MIN_VALUE!5CACHE_SIZE!6CYCLE_FLAG
    array set def [getDefaultMeta]
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  ADD.SEQUENCES] {
            set data [lindex $item 2]
            set params ""
            if {[info exists def(DEF.USER_SEQUENCES.data.index.SITE_VALUE_BEGIN)] && [lindex $data $def(DEF.USER_SEQUENCES.data.index.SITE_VALUE_BEGIN)] != ""} {
                lappend params [lindex $data $def(DEF.USER_SEQUENCES.data.index.SITE_VALUE_BEGIN)]
            } else {
                lappend params 1
            }
            if {[info exists def(DEF.USER_SEQUENCES.data.index.INCREMENT_BY)] && [lindex $data $def(DEF.USER_SEQUENCES.data.index.INCREMENT_BY)] != ""} {
                lappend params [lindex $data $def(DEF.USER_SEQUENCES.data.index.INCREMENT_BY)]
            } else {
                lappend params 1
            }
            if {[info exists def(DEF.USER_SEQUENCES.data.index.MAX_VALUE)] && [lindex $data $def(DEF.USER_SEQUENCES.data.index.MAX_VALUE)] != ""} {
                lappend params [lindex $data $def(DEF.USER_SEQUENCES.data.index.MAX_VALUE)]
            } else {
                lappend params 9999999999
            }
            if {[info exists def(DEF.USER_SEQUENCES.data.index.CYCLE_FLAG)] && [lindex $data $def(DEF.USER_SEQUENCES.data.index.CYCLE_FLAG)] != ""} {
                lappend params [lindex $data $def(DEF.USER_SEQUENCES.data.index.CYCLE_FLAG)]
            }
            if {[info exists def(DEF.USER_SEQUENCES.data.index.CACHE_SIZE)] && [lindex $data $def(DEF.USER_SEQUENCES.data.index.CACHE_SIZE)] != ""} {
                lappend params [lindex $data $def(DEF.USER_SEQUENCES.data.index.CACHE_SIZE)]
            }
            if {[lindex $item 1] != ""} {
            lappend out "exec LANDA_CONVERSION.CREATE_SEQUENCE ('[lindex $item 1]','[join $params "','"]');"
            }
        }
    }
    return $out
}
proc processAddSeqEntry {listName} {
    set out ""
    foreach listName [getListNames] {
    # 0TARGET_COLUMN!1SITE_VALUE_BEGIN!2MAX_VALUE!3INCREMENT_BY!4MIN_VALUE!5CACHE_SIZE!6CYCLE_FLAG
        foreach item [[subst get$listName]  INSERT.SEQS] {
            set data [lindex $item 2]
            set commentout ""
            if {[lindex $data 0] == ""} {
                set commentout "-- unknown target column! "
            }
            lappend out "exec LANDA_CONVERSION.LANDA_INSERT ('INSERT INTO SEQ_SEQUENCE (SEQ_NAME,SEQ_TARGET_COLUMN,SEQ_SITE_VALUE_BEGIN,SEQ_RECORD_VERSION,SEQ_USR_UID_CREATED_BY,SEQ_CREATE_DATE) values (''[lindex $item 1]'',''[lindex $data 0]'',''[lindex $data 1]'',0,-4,sysdate)');"
        }
    }
    return $out
}
proc getSqlListPRE {} {
    return [list DROP.CONSTRAINT.RECREATE DROP.CONSTRAINT DROP.INDEX \
DROP.INDEX.RECREATE REVIEW.CUSTOM_INDEX DROP.TRIGGER DROP.TRIGGER.RECREATE DROP.TEXT_INDEX DROP.RECREATE.TEXT_INDEX DROP.PROCEDURE DROP.PROCEDURE.RECREATE RENAME.COLUMN RENAME.INDEX RENAME.CONSTRAINT \
RENAME.TABLE MODIFY.COLUMN ADD.TABLE ADD.COLUMN ADD.INDEX ADD.RECREATE.INDEX MOVE.INDEX ADD.SEQUENCE]
}
proc getSqlListPOST {} {
    return [list ADD.CONSTRAINT ADD.CONSTRAINT.RECREATE ADD.TRIGGER ADD.TRIGGER.RECREATE ADD.TEXT_INDEX ADD.RECREATE.TEXT_INDEX ADD.PROCEDURE ADD.PROCEDURE.RECREATE DROP.SEQUENCE ENABLE.CONSTRAINT VALIDATE.CONSTRAINT]
}
proc getSqlListMID {} {
    return [list DROP.CONSTRAINT DROP.INDEX]
}
proc getSqlListDROP {} {
    return [list DROP.COLUMN DROP.TABLE]
}
proc getSqlListMAP {} {return "MAPPING"}
proc getPLSQL {resultArray when} {
    upvar $resultArray results
    set sql_statements ""
    foreach item [getSqlList$when] {
        if {[info exists results($item)]} {
            foreach sql $results($item) {
                lappend sql_statements $sql
            }
        }            
    }
    return $sql_statements
}
proc addResult {type values {increment 0}} {
    global RESULTS
    if {![info exists RESULTS($type)]} {
        set RESULTS($type) ""
    }
    lappend RESULTS($type) $values
    incr RESULTS(number_of_changes) $increment
}
proc addWarning {type values {increment 1}} {
    global WARNINGS
    if {![info exists WARNINGS($type)]} {
        set WARNINGS($type) ""
    }
    lappend WARNINGS($type) $values
    incr WARNINGS(number_of_changes) $increment
}
proc removeResult {type key} {
    global RESULTS
    set i [lsearch $RESULTS($type) $key]
    if {$i >= 0} {
        set RESULTS($type) [lreplace $RESULTS($type) $i $i ]
        return 1
    }
    return -1
}
proc getResults {type} {
    global RESULTS
    if {$type == "all" || $type == "*"} {
        return [array get RESULTS]
    } elseif {[info exists RESULTS($type)]} {
        return "$RESULTS($type)"
    }
    error "type - $type"
    return ""
}
proc getResultsCount {} {
    global RESULTS
    return [array size RESULTS]
}
proc getWarningsCount {} {
    global WARNINGS
    return [array size WARNINGS]
}
proc getWarnings {type} {
    global WARNINGS
    if {$type == "all" || $type == "*"} {
        return [array get WARNINGS]
    } elseif {[info exists WARNINGS($type)]} {
        return "$WARNINGS($type)"
    }
     error "type - $type"
    return ""
}
proc getDeltaHeadings {type} {
    set rval ""
    switch $type {
        "ADD.SEQUENCES"  {
            set rval "TARGET TABLE\tSEQUENCE NAME\tTARGET COLUMN"
        }
        "DROP.SEQUENCES" {
            set rval "SEQUENCE NAME"
        }
        "ADD.COLUMNS" {
           set rval "TABLE NAME\tCOLUMN NAME\tData type/size/default"
        }
        "MODIFY.COLUMNS"  {
            set rval "TABLE NAME\tCOLUMN NAME\tData type/size/default\tPrior Value"
        }
        "DROP.COLUMNS" {
            set rval "TABLE NAME\tCOLUMN NAME"
        }
        "ADD.CONSTRAINTS" {
            set rval "TABLE NAME\tCONSTRAINT NAME\tCOLUMN NAME"
        }
        "RECREATE.CONSTRAINTS"  {
            set rval "TABLE NAME\tCONSTRAINT NAME\tCOLUMN NAME\tPrior Value"
        }
        "ENABLE/VALIDATE.CONSTRAINTS" {
            set rval "TABLE NAME\tCONSTRAINT NAME\tACTION"
        }
        "DROP.CONSTRAINTS" {
            set rval "TABLE NAME\tCONSTRAINT NAME"
        }
        "ADD.TEXT_INDEXS" -
        "ADD.INDEXS" {
            set rval "TABLE NAME\tINDEX NAME\tCOLUMN NAME"
        }
        "RENAME.INDEXS" {
            set rval "TABLE NAME\tOLD INDEX NAME\tNEW INDEX NAME"
        }
        "MOVE.INDEXS" {
            set rval "TABLE NAME\tINDEX NAME\tCOLUMN NAME\tPrior Definition"
        }
        "RECREATE.INDEXS" -
        "RECREATE.TEXT_INDEXS" {
            set rval "TABLE NAME\tINDEX NAME\tCOLUMN NAME\tTABLESPACE NAME\tPrior Definition"
        }
        "DROP.TEXT_INDEXS" -
        "DROP.INDEXS" {
            set rval "TABLE NAME\tINDEX NAME"
        }
        "REVIEW.CUSTOM_INDEXS" {
            set rval "TABLE NAME\tINDEX NAME\tCOLUMN NAME"
        }
        "ADD.TABLES" {
            set rval "TABLE NAME\tTABLESPACE NAME"
        }
        "DROP.TABLES" {
            set rval "TABLE NAME"
        }
        "DROP.TRIGGERS" -
        "RECREATE.TRIGGERS" -
        "ADD.TRIGGERS" {
            set rval "TABLE NAME\tTRIGGER NAME"
        }
        "ADD.PROCEDURES" -
        "RECREATE.PROCEDURES" -
        "DROP.PROCEDURES" {
            set rval "TABLE NAME\tPROCEDURE NAME"
        }
    }
    return $rval
}
proc outputDelta {outputFid} {
    logit $outputFid "DIFFERENCE REPORT"
    set skipList "number_of_changes chg_precision_lst"
    
    foreach type [getResultNames] {
        foreach statustype {WARNING ERROR} procname {getWarnings getResults} {
            if {[lsearch $skipList $type] >= 0} {continue}
            set results [$procname $type]
            if {$results != ""} {
                set count [llength $results]
                set n [split $type "."]
                set action [lindex $n 0]
                set object [lindex $n 1]
                regsub -nocase {S$} $object "" object
                logit $outputFid [getInfo HR]
                putt $outputFid "$statustype: $count [lindex $n 1] to [lindex $n 0]"
                logit $outputFid "[getDeltaHeadings $type]"
                foreach item $results {
                    set rval ""
                    switch $type {
                        "ADD.SEQUENCES"  {
                            set rval "[lindex $item 0]\t[lindex $item 1]\t[lindex [lindex $item 2]]"
                        }
                        "MODIFY.COLUMNS"  {
                            array set coldef [parseColumn [lindex $item 2]]
                            # set rval "$action\t$object\t[lindex $item 0]\t[lindex $item 1]\t$coldef(DATA_TYPE) $coldef(LENGTH) $coldef(DEFAULT)"
                            if {$coldef(DEFAULT) != ""} {set default "default $coldef(DEFAULT)"} else {set default ""}
                            set rval "[lindex $item 0]\t[lindex $item 1]\t$coldef(DATA_TYPE)\t$coldef(LENGTH)\t$default"
                            array unset coldef
                            array set coldef [parseColumn [lindex $item 3]]
                            if {$coldef(DEFAULT) != ""} {set default "default $coldef(DEFAULT)"} else {set default ""}
                            append rval "\t(was $coldef(DATA_TYPE)$coldef(LENGTH) $default)"
                            array unset coldef
                        }
                        "ADD.COLUMNS" {
                            array set coldef [parseColumn [lindex $item 2]]
                            if {$coldef(DEFAULT) != ""} {set default "default $coldef(DEFAULT)"} else {set default ""}
                            set rval "[lindex $item 0]\t[lindex $item 1]\t$coldef(DATA_TYPE)\t$coldef(LENGTH)\t$default "
                            array unset coldef
                        }
                        "MOVE.INDEXS" {
                            set rval "[lindex $item 0]\t[lindex $item 2]\t[lindex $item 1]"
                        }
                        "INSERT.SEQS" {
                            continue
                        }
                        "ADD.INDEXS" -
                        "RENAME.INDEXS" {
                            set rval "[lindex $item 0]\t[lindex $item 1]\t[join [lindex $item 2] ","]\t[join [lindex $item 3] \t]"
                        }
                        "ADD.TEXT_INDEXS"
                        {
                            set rval "[lindex $item 0]\t[lindex $item 1]\t[lindex $item 2]"
                        }
                        "ADD.CONSTRAINTS" {
                            set rval "[lindex $item 0]\t[lindex $item 1]\t[join [lindex $item 2] ","]\t[join [lindex $item 3] \t]\t[join [lindex $item 4] \t]"
                        }
                        "REVIEW.CUSTOM_INDEXS" {
                            set rval "[lindex $item 0]\t[lindex $item 1]\t[join [lindex $item 2] ","]"
                        }
                        "RECREATE.CONSTRAINTS" -
                        "RECREATE.TEXT_INDEXS" {
                            set rval "[lindex $item 0]\t[lindex $item 1]\t[lindex $item 2]\t(was [lrange $item 3 end])"
                        }
                        "RECREATE.INDEXS" {
                            set rval "[lindex $item 0]\t[lindex $item 1]\t[lindex $item 2]\t[lindex $item 3]\t(was [join [lindex $item 4] " "])"
                        }
                        "DROP.INDEXS" -
                        "DROP.CONSTRAINTS" -
                        "DROP.COLUMNS" -
                        "DROP.TEXT_INDEXS" -
                        "ADD.TRIGGERS" -
                        "DROP.TRIGGERS" -
                        "ADD.PROCEDURES" -
                        "DROP.PROCEDURES" -
                        "RECREATE.TRIGGERS" -
                        "RECREATE.PROCEDURES" 
                        {
                            set rval "[lindex $item 0]\t[lindex $item 1]"
                        }
                        "ENABLE/VALIDATE.CONSTRAINTS" {
                            set rval "[lindex $item 0]\t[lindex $item 1]\t[lindex $item 2]"
                        }
                        "DROP.SEQUENCES" -
                        "DROP.TABLES" {
                            set rval "[lindex $item 0]"
                        }
                        "ADD.TABLES" {
                            set tableName [lindex $item 0]
                            set tablespaceName [lindex $item 1]
                            set rval ""
                            set newcols ""
                            set allcols [$procname "ADD.TAB_COLS"]
                            # logit [join $allcols \n]
                            array unset cindex
                            array set cindex ""
                            set test [lindex [lindex [lindex $allcols 0] 2] 4]
                            if {$test == ""} {
                                # old style remove when column position is in all models
                                set test 1
                                foreach ac $allcols {
                                    if {[lindex $ac 0] == $tableName} {
                                        set coldesc [lindex $ac 2]
                                        set cindex($test) $ac
                                        incr test
                                    }
                                }
                            } else {
                                foreach ac $allcols {
                                    if {[lindex $ac 0] == $tableName} {
                                        set coldesc [lindex $ac 2]
                                        set cindex([lindex $coldesc 4]) $ac
                                    }
                                }
                            }
                            set colorder [lsort -integer [array names cindex]]
                            foreach i $colorder {
                                set ac $cindex($i)
                                array unset coldef
                                array set coldef [parseColumn [lindex $ac 2]]
                                if {$coldef(DEFAULT) != ""} {set default "default $coldef(DEFAULT)"} else {set default ""}
                                if {$rval == ""} {
                                    set rval "$tableName\t$tablespaceName\t[lindex $ac 1]\t$coldef(DATA_TYPE)\t$coldef(LENGTH)\t$default"
                                } else {
                                    append rval "\n[lindex $ac 0]\t[lindex $ac 1]\t$coldef(DATA_TYPE)\t$coldef(LENGTH)\t$default"
                                }
                            }
                            array unset coldef
                        }
                        default {}
                    }
                    logit $outputFid "$rval"
                }
            }
        }
    }
}
proc setNullResults {} {
global RESULTS WARNINGS
    if {![array exists RESULTS]} {
        array set RESULTS ""
    }
    foreach rname [getResultNames] {
        set RESULTS($rname) ""
    }
    if {![array exists WARNINGS]} {
        array set WARNINGS ""
    }
    foreach rname [getResultNames] {
        set WARNINGS($rname) ""
    }
    set RESULTS(number_of_changes) 0
    set RESULTS(chg_precision_lst) 0
    set WARNINGS(number_of_changes) 0
    set WARNINGS(chg_precision_lst) 0
}
proc getResultNames {} {
    return "ADD.TABLES
RENAME.TABLES
ADD.COLUMNS
RENAME.COLUMNS
MODIFY.COLUMNS
DROP.CONSTRAINTS
DROP.INDEXS
ADD.INDEXS
RENAME.INDEXS
RECREATE.INDEXS
MOVE.INDEXS
REVIEW.CUSTOM_INDEXS
ADD.SEQUENCES
RENAME.CONSTRAINTS
DROP.SEQUENCES
RECREATE.CONSTRAINTS
ADD.CONSTRAINTS
ENABLE/VALIDATE.CONSTRAINTS
ADD.TRIGGERS
ADD.RECREATE
DROP.TRIGGERS
RECREATE.TRIGGERS
ADD.PROCEDURES
DROP.PROCEDURES
RECREATE.PROCEDURES
ADD.TEXT_INDEXS
DROP.TEXT_INDEXS
RECREATE.TEXT_INDEXS
DROP.TABLES
DROP.COLUMNS
number_of_changes
chg_precision_lst"
}
proc processDROP {listName action type position {comment "-1"}} {
    set out ""
    foreach listName [getListNames] {
    foreach item [[subst get\$listName] $action.$type\S] {
        set params ""
        foreach p $position {
            lappend params "'[lindex $item $p]'"
        }
        if {[set note [lindex $item $comment] ] == ""} {
            set note ""
        } else {
            set note "-- from $note"
        }

        lappend out "LANDA_CONVERSION.DROP_$type ($params); $note"
    }
    }
    return $out
}

proc processRECREATE_TEXT_INDEX_DROP {listName} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  RECREATE.TEXT_INDEXS] {
            if {[lindex $item 0] != ""} {
                lappend out "LANDA_CONVERSION.DROP_INDEX ('[lindex $item 1]'); -- from Table [lindex $item 0]"
            }
        }
    }
    return $out
}

proc process_TEXT_INDEX_DROP {listName} {
    set out ""
    foreach listName [getListNames] {
        foreach item [[subst get$listName]  DROP.TEXT_INDEXS] {
            if {[lindex $item 0] != ""} {
                lappend out "LANDA_CONVERSION.DROP_INDEX ('[lindex $item 1]'); -- from Table [lindex $item 0]"
            }
        }
    }
    return $out
}

proc processDifferences2 {} {
    array set sql ""
# process drop indexs, constraints, triggers, textindexes
    set sqlVal [processRECREATE_CONSTRAINT_DROP Results]
    if {$sqlVal != ""} {
    catch {set sql(DROP.CONSTRAINT.RECREATE) $sqlVal} err
    }
    set sqlVal [reviewCustomIndex Warnings REVIEW.CUSTOM_INDEXS]
    if {$sqlVal != ""} {
    catch {set sql(REVIEW.CUSTOM_INDEX) $sqlVal} err
    }
    catch {set sql(DROP.CONSTRAINT) [processDrop2 Results CONSTRAINT]} err
    catch {set sql(DROP.INDEX) [processDrop1 Results INDEX]} err
    set sqlVal  [processRECREATE_INDEX_DROP Results]
    if {$sqlVal != ""} {
    catch {set sql(DROP.INDEX.RECREATE) $sqlVal} err
    }
    set sqlVal  [process_TEXT_INDEX_DROP Results]
    if {$sqlVal != ""} {
    catch {set sql(DROP.TEXT_INDEX) $sqlVal} err
    }
    set sqlVal  [processRECREATE_TEXT_INDEX_DROP Results]
    if {$sqlVal != ""} {
    catch {set sql(DROP.RECREATE.TEXT_INDEX) $sqlVal} err
    }
    #todo :need to add droprecreate trigger; then remove as a drop
    catch {set sql(DROP.TRIGGER) [processDrop1 Results TRIGGER]} err
    catch {set sql(DROP.TRIGGER.RECREATE) [processDROP Results RECREATE TRIGGER {1} 0]} err
    catch {set sql(DROP.PROCEDURE) [processDROP Results DROP PROCEDURE {0} ]} err
    catch {set sql(DROP.PROCEDURE.RECREATE) [processDROP Results RECREATE PROCEDURE {0} ]} err
    #Drop before Recreating Text Index
    catch {set sql(DROP.SEQUENCE) [processDrop0 Results SEQUENCE]} err
# process renamed items
    catch {set sql(RENAME.COLUMN) [processRename Results COLUMN]} err
    catch {set sql(RENAME.INDEX) [processRename Results INDEX]} err
    catch {set sql(RENAME.CONSTRAINT) [processRename Results CONSTRAINT]} err
    catch {set sql(RENAME.TABLE) [processRename Results TABLE]} err
    # process modify column, add table, add column
    catch {set sql(MODIFY.COLUMN) [processModifyColumn Results]} err
    catch {set sql(ADD.TABLE) [processAddTable Results]} err
    catch {set sql(ADD.COLUMN) [processAddColumn Results]} err
    # process add indexes
    set sqlVal  [processAddIndex Results ADD.INDEXS]
    if {$sqlVal != ""} {
    catch {set sql(ADD.INDEX) $sqlVal} err
    }
    set sqlVal  [processAddIndex Results RECREATE.INDEXS]
    if {$sqlVal != ""} {
    catch {set sql(ADD.RECREATE.INDEX) $sqlVal} err
    }
    # process move indexes
    set sqlVal  [processMoveIndTablespace Warnings MOVE.INDEXS]
    if {$sqlVal != ""} {
    catch {set sql(MOVE.INDEX) $sqlVal} err
    }
    # sequences:
    set sqlVal  [processAddSequence Results]
    if {$sqlVal != ""} {
    catch {set sql(ADD.SEQUENCE) $sqlVal} err
    }
    # ANY MAPPING WILL GO HERE
    catch {set sql(MAPPING)  [processAddSeqEntry Results]} err

    #process add constraints
    catch {set sql(ADD.CONSTRAINT) [processAddConstraint Results ADD.CONSTRAINTS]} err
    catch {set sql(ADD.CONSTRAINT.RECREATE) [processAddConstraint Results RECREATE.CONSTRAINTS]} err
    # process add trigges and text indexes
    catch {set sql(ADD.TRIGGER) [processAddTrigger Results]} err
    catch {set sql(ADD.TRIGGER.RECREATE) [processAddTrigger Results RECREATE]} err
    catch {set sql(ADD.PROCEDURE) [processAddProcedure Results]} err
    catch {set sql(ADD.PROCEDURE.RECREATE) [processAddProcedure Results RECREATE]} err
    catch {set sql(ADD.TEXT_INDEX) [processAddTI Results ADD TEXT_INDEX]} err
    catch {set sql(ADD.RECREATE.TEXT_INDEX) [processAddTI Results RECREATE TEXT_INDEX]} err
    
    set sqlVal  [processEnableConstraint Warnings]
    if {$sqlVal != ""} {
    catch {set sql(ENABLE.CONSTRAINT) $sqlVal} err
    }
    
    set sqlVal  [processValidateConstraint Warnings]
    if {$sqlVal != ""} {
    catch {set sql(VALIDATE.CONSTRAINT) $sqlVal} err
    }
    
    #process drop tables, columns
    catch {set sql(DROP.COLUMN) [processDropColumn Results]} err
    catch {set sql(DROP.TABLE) [processDrop0 Results TABLE]} err
    return [array get sql]
}

# TODO: improve this to include all result types
# TODO move all outputting to format procs.
proc leaveNow {} {
    upvar toolName toolName
    set terr [getResults number_of_changes]
    if {$terr > 0 } {
        putt  "[getInfo HR]"
        putt " *** WARNING: There are $terr schema differences listed in this report"
        putt "              which must be resolved prior to the conversion."
        putt "              Contact the EXL Healthcare Support Department for assistance:"
        putt "              (800) 669-4629 or EXLHealthcareSupport@exlservice.com"
        set STATUS FAIL
    } elseif {[llength [getWarnings ENABLE/VALIDATE.CONSTRAINTS]]} {
        set STATUS WARN
    } else {
        set STATUS PASS
    }
    
    #todo This is not being handled yet.
    # if {[llength [getResults chg_precision_lst]] > 0 } ...
    putt  "[getInfo HR]"
    putt      "[getResults number_of_changes] system schema differences"
    putt      "[llength [getWarnings ENABLE/VALIDATE.CONSTRAINTS]] non validated or disabled constraints"
    putt      ""
    #fix me: dbcReport null
    puts      "Please refer to [getInfo dbCompare.REPORT_FILE]"
    if {[getInfo AutoScript.REPORT_HANDLE] != ""} {
        puts [getInfo AutoScript.REPORT_HANDLE] "dbCompare.tcl version [$toolName.version], revision [$toolName.revision] completed."
        puts [getInfo AutoScript.REPORT_HANDLE] "Refer to output file [getInfo dbCompare.REPORT_FILE]"
    }

    # setEndTime dbCompare
    putt  "dbCompare.tcl version [dbCompare.version], revision [dbCompare.revision] completed with $terr issues.\n"
    set duration [getDuration [getStartTime dbCompare]]
    putt      "Run Time was [prettyTime [hms $duration]]."
    putt      "END: [clock format [clock seconds] -format "[getInfo dateFormat] [getInfo timeFormat]"]"
    putt      [getInfo HR]
    putt    "RESULTS: $terr"
    putt   "STATUS: $STATUS"
    if {!([info exists ::argv0] && [string tolower [file tail $::argv0]] == "dbcompare.tcl")} {
        setlog off [getInfo dbCompare.REPORT_HANDLE]
    }
    return [getResults number_of_changes]
}


proc correctArgs {argc argv} {
    set silent [lindex $argv end]
    if {[regexp -nocase "silent" $silent]} {
        set silent 1
        incr argc -1
        putt "Running in silent mode, user input will be suppressed."
    } else {
        set silent 0
    }
    if {$argc < 1} {
        error "Not enough arguments"
    } elseif {$argc == 1} {
        if {[regexp {^.+/.+@.+$} [lindex $argv 0]]} {
            set targetConnection [lindex $argv 0]
            set modelInfo ""
            set reportFile ""
        } else {
            if { [catch {set fid [open [lindex $argv 0] r]} ] } {
                putt null "*** ERROR - The [lindex $argv 0] command file cannot be found."
                putt null puts "Please enter a valid filename, including the complete path"
                putt null puts "to the file if necessary."
                error "Cannot open driver file"
            }
            set directions [split [string trim [read $fid] ] \n]
            close $fid
            foreach nv $directions {
                set [lindexe $directions 0] [lindexe $directions 1]
            }
        }
    } elseif {$argc == 2} {
        set arg0 [lindex $argv 0]
        set arg1 [lindex $argv 1]
        set modelInfo ""
        set targetConnection ""
        set reportFile ""
        # try to determine what the arguments are and set as appropriate
        # If we are given only two arguments, one of them has to be the connection string.
        # DbCompare is smart enough to extrapolate the model file version number based on the version of the schema
        # and generate the correct model folder name.
        if {[file isdirectory ./Models/$arg0]} {
            # set modelInfo to arg0 if the directory exists
            set modelInfo [lindex $argv 0]
            # if arg1 is in the form of a connection string, set targetConnection to arg1
            if {[regexp {^.+/.+@.+$} $arg1]} {
                set targetConnection $arg1
            } else {
                set reportFile $arg1
            }
        } elseif {[regexp {^.+/.+@.+$} $arg0]} {
            # if arg0 is in the form of a connection string, set targetConnection to arg0
            set targetConnection $arg0
            # set modelInfo to arg0 if the directory exists
            if {[file isdirectory ./Models/$arg1]} {
                set modelInfo $arg1
            } else {
                # set reportFile to arg1 since arg1 isnt a directory nor is it a connect string
                set reportFile $arg1
            }
        } else {
            # set reportFile to arg0 since arg1 isnt a directory nor is it a connect string
            set reportFile $arg0
            # if arg1 is a directory set modelInfo to arg1 otherwise if it's a connection string set targetConnection to arg1
            if {[file isdirectory ./Models/$arg1]} {
                set modelInfo $arg1
            } elseif {[regexp {^.+/.+@.+$} $arg1]} {
                set targetConnection $arg1
            }
        }
    } elseif {$argc == 3} {
        set modelInfo [lindex $argv 0]
        set targetConnection [lindex $argv 1]
        set reportFile [lindex $argv 2]
    } else {
        error "Wrong argument count"
    }
    regsub -all {\\} $modelInfo {\\\\} modelInfo
    if {[regexp {^.+/.+@.+$} $reportFile]} {
        puts "Output file cannot be in the form of a connection string."
        error
    }
    if {$targetConnection == ""} {
        puts "Connection information could not be determined."
        error
    }
    return [list $modelInfo $targetConnection $reportFile]
}
# TODO:
# add table filter to other get object procs (from schema)
# finish reporting piece
# make TABLES a little more robust on input perhaps -tables="table list"
# using tables may require a bit more planning, as the R relationship cannot be determined
#       without it.  it may require the reporting section be able to "getModel" in order to determine
#       table/column relationship for parent
# add to INDICES the column/data relationship, eg data = COLUMN_NAME,Column_position, then INDICES.USER_CONS_COLUMNS.data = data
proc getCorrectionParts {} {return "PRE ADDITIONS MAP MAPPING POST CONSTRAINTS DROP DROPS"}
proc getDefaultCorrectionScriptName {} {
    return "CORRECTION_DDL"
}
proc p_makeCorrectionDDL {rSQL {dir "."}} {
    upvar $rSQL resultSQL
    set rcount [getInfo dbCompare.countOfDDL]
    # TODO: would be better to keep tables together rather than every 100 itesm?
    if {$rcount == ""} {set rcount 100}
    set fid [open [getInfo dbCompare.CORRECTION_SCRIPT_NAME].sql w]
    puts $fid "-- Correction script to bring schema [getInfo dbCompare.targetDef.connectDisplay] to validate at version [getInfo modelDef.schemaVersion]"
    puts $fid "whenever sqlerror exit 1"
    puts $fid "set echo on"
    puts $fid "set serveroutput on"
    puts $fid "spool [getInfo dbCompare.CORRECTION_SCRIPT_NAME].lst"
    foreach {part name} [getCorrectionParts] {
        puts $fid "\n------$name-------\n"
        puts $fid [join [makePartDDL resultSQL $part $rcount] \n]
    }
    puts $fid "spool off"
    puts $fid "exit"
    close $fid
    return
}
proc p_makePackageCorrectionDDL {rSQL part fileName parent revision {rcount 100}} {
    upvar $rSQL resultSQL
    if {![regexp {^[\d]+$} $rcount]} {set rcount 100}
    set ifClause "'$fileName'"
    if {$parent != ""} {append ifClause ",'$parent'"}
    if {$revision != ""} {append ifClause ",'$revision'"}
    set fid [open [file join $dir $fileName.sql] w]
    puts $fid "whenever sqlerror exit 1"
    puts $fid "set echo on"
    puts $fid "set serveroutput on"
    puts $fid "\n------$fileName-------\n"
    puts $fid "BEGIN"
    puts $fid "    IF LANDA_CONVERSION.START_ITEM($ifClause) THEN"
    puts $fid "        [join [makePartDDL resultSQL $part $rcount] "        \n"]"
    puts $fid "        LANDA_CONVERSION.STOP_ITEM();"
    puts $fid "    END IF;"
    puts $fid "END;"
    puts $fid "/"
    close $fid
    return
}
proc makePartDDL {rSQL part {count 100}} {
    upvar $rSQL resultSQL
    set rval ""
    lappend rval "-- $part"
    foreach type [getSqlList$part] {
        if {[info exists resultSQL($type)] && $resultSQL($type) != ""} {
     #       lappend resultSQL(OUTPUT) "$type : [llength $resultSQL($type)] difference(s)"
            lappend rval [join [makeTypeDDL resultSQL $type $count] \n]
        }
    }
    return $rval
}
proc makeTypeDDL {rSQL type {count 100}} {
    upvar $rSQL resultSQL
    set rval ""

    set i 1
    foreach line $resultSQL($type) {
        lappend rval "$line"

        incr i
    }

    return $rval
}
proc p_makeModelFiles {arrayName} {
    upvar $arrayName model
    if {![info exists model(ModDir)] || $model(ModDir) == ""} {
        set newModelDir "[getInfo MODEL_FILES_DIRECTORY]/$model(prd).$model(schemaVersion)"
    } else {
        set newModelDir $model(ModDir)
    }
    if {![file exists $newModelDir]} {
        file mkdir $newModelDir
    }
    set fid [open $newModelDir/MODEL_VERSION w]
    puts $fid $model(schemaVersion)
    close $fid
    foreach type $model(DEF.TYPES) {
         catch {makeTabModel model $type $newModelDir [getInfo TABLES]} err
    }
}
proc setInitialArrays {} {
    global INDICES RESULTS
    global targetDef modelDef
    array unset INDICES
    array set INDICES "header 0 key 1 data 2"
    array unset modelDef
    array set modelDef ""
    array unset targetDef
    array set targetDef ""
    array unset RESULTS
    array set RESULTS ""
}


proc setDefaultMetaByList {metaList} {
    global defaultMetaArray
    updateInfo dbCompare.defaultMetaArray $metaList
}

proc setDefaultMeta {arrayName} {
    upvar $arrayName temp
    updateInfo dbCompare.defaultMetaArray [array get temp DEF.*]
}
proc getDefaultMeta {} {
    return [getInfo dbCompare.defaultMetaArray]
}
proc setDefaultMetaArray {} {
    global METADATA
    array unset METADATA
    array set METADATA [getInfo dbCompare.defaultMetaArray]
}
proc getDefaultMetaValue {name} {
    global METADATA
    return $METADATA($name)
}
proc doComparison {model target} {
    upvar $model modelDef
    upvar $target targetDef
    set objectTypes [getInfo dbCompare.OBJECT_TYPES]
    if {[lsearch $objectTypes "USER_TABLES"] >= 0} {
        putt " * * Comparing Table Information * * "
        set result [compareTables targetDef modelDef]
    }
    if {[lsearch $objectTypes "USER_TAB_COLUMNS"] >= 0} {
        putt " * * Comparing Table Column Definitions * * "
        set result [compareTableColumns modelDef targetDef]
        set result [getDroppedColumns modelDef targetDef]
    }
    if {[lsearch $objectTypes "USER_CONSTRAINTS"] >= 0} {
        putt " * * Comparing Table Constraints * * "
        set result [compareConstraints modelDef targetDef]
    }
    if {[lsearch $objectTypes "USER_INDEXES"] >= 0} {
        putt " * * Comparing Index Information * *"
        set result [compareIndexes modelDef targetDef]
    }
    if {[lsearch $objectTypes "USER_SEQUENCES"] >= 0} {
        putt " * * Comparing Sequence Information * *"
        set result    [checkAddSequences modelDef targetDef]
        set result [checkDropSequences modelDef targetDef]
    }
    if {[lsearch $objectTypes "TEXT_INDEXES"] >= 0} {
        putt " * * Comparing Text Index Information * *"
        set result [compareTextIndices modelDef targetDef]
    }
    if {[lsearch $objectTypes "USER_TRIGGERS"] >= 0} {
        putt " * * Comparing Trigger Information * *"
        set result [compareTriggers modelDef targetDef]
    }
    if {[lsearch $objectTypes "USER_PROCEDURES"] >= 0 && [lsearch [getInfo IGNORE_LIST] "USER_PROCEDURES"] < 0} {
        putt " * * Comparing Procedure Information * * "
        set result [compareProcedures modelDef targetDef]
    }
    putt [getInfo HR]\n
    return [getResults number_of_changes]
}
proc dbCompare.unsetAll {} {
global targetDef modelDef RESULTS
    catch {array unset targetDef}
    catch {array unset modelDef}
    catch {array unset RESULTS}
    unsetInfo dbCompare.*
}
global targetDef modelDef INDICES RESULTS METADATA

# ############################################################
# ==============================================================================
#   Main Proc
# ==============================================================================
proc dbCompare {model tdbh reportfile {TABLES ""} } {
    global targetDef modelDef
    set toolName dbCompare
    if {[info exists modelDef(connectDisplay)] == 0} {
        setInitialArrays
        getConnectionSetup modelDef $model [getInfo MODEL_FILES_DIRECTORY]
        getConnectionSetup targetDef $tdbh [getInfo MODEL_FILES_DIRECTORY]
    }
    setNullResults
    if {[getInfo dbCompare.CORRECTION_SCRIPT_NAME] == ""} {
        updateInfo dbCompare.CORRECTION_SCRIPT_NAME [getDefaultCorrectionScriptName]
    }
    setStartTime "$toolName"
    puts "\n[getInfo HR]"
    # todo cluge
    if {[getInfo AutoScript.OUTDIR] != ""} {setInfo $toolName.OUTDIR [getInfo AutoScript.OUTDIR]}
    set rpt [getReportFile $toolName [getInfo $toolName.OUTDIR] $reportfile]
    updateInfo $toolName.REPORT_HANDLE $rpt
    updateInfo default_channel $rpt
    printInitialHeader $toolName [$toolName.getDescription] [$toolName.version].[$toolName.revision]
    if {$targetDef(schemaVersion) != $modelDef(schemaVersion)} {
        putt [getInfo HR]
        putt " *** WARNING: Target schema version $targetDef(schemaVersion) does not match"
        putt "              model file version $modelDef(schemaVersion)!!!"
        putt "              Making changes based on incorrect model files can result"
        putt "              in loss of data and render your schema unusable!!!"
        putt [getInfo HR]\n
    }
    putt  "Model Files     : $modelDef(connectDisplay)"
    putt  "Model Version   : $modelDef(schemaVersion)"
    putt "Target Database : $targetDef(connectDisplay)"
    putt "Schema Version  : $targetDef(schemaVersion)"
    putt [getInfo HR]\n

    # validating SHS rows only if the target is database
    if {$targetDef(source) == "DATABASE"} {
        if { [catch {getLogonHandle $tdbh} sdgdbh ] }  {
            puts [p_runtimeError "Cannot log onto $database"]
            exit -1
        }
        set validSHS [validateSHS $sdgdbh ]
        if {$validSHS != ""} {
            puts "The following script did not complete: $validSHS"
            putt "Contact the EXL Healthcare Support Department for assistance: "
            putt [getInfo SupportContact]
            exit 1
        }
    }

    # Print cert file header
    logit "[dbcIntro [getInfo date_stamp] $targetDef(connectDisplay) $modelDef(schemaVersion) [getdbcSeparator]]"
    getMetaDataSource modelDef targetDef

    array set modelDef [getMetaData [getInfo dbCompare.modelDef.metaSourceLocation] all [getInfo dbCompare.modelDef.metaSource]]
    setInitialNulls modelDef
    setDefaultMeta modelDef
    unsetInfo DEF.TYPES
    updateInfo DEF.TYPES $modelDef(DEF.TYPES)
    array set targetDef [getMetaData [getInfo dbCompare.targetDef.metaSourceLocation] all [getInfo dbCompare.targetDef.metaSource]]
    setInitialNulls targetDef

    getDefinitions modelDef $TABLES
    putt [getInfo hr]\n
    getDefinitions targetDef $TABLES
    putt [getInfo hr]\n
    set results 0
    if {([getInfo DO_COMPARE] == "" || [getInfo DO_COMPARE] == "true") || [getInfo MAKE_DDL] == "true"} {
        set results [doComparison modelDef targetDef]
    }
    outputDelta [getInfo dbCompare.REPORT_HANDLE]
    leaveNow
    return $results
}

#==============================================================================#
#   Main Execution
#==============================================================================#
if {[info exists argv0] && [string tolower [file tail $argv0]] == "dbcompare.tcl"} {
    if [catch {set argv [p_getParams $argv [file rootname [file tail $argv0]]]} arg] {
        puts "$arg"
        dbCompareCorrectUsage $argv0
        exit 1
    }
    if {[catch {set argv [correctArgs [llength $argv] $arg]}]} {
        puts "Incorrect input:\n\t $arg"
        dbCompareCorrectUsage $argv0
        exit 1
    }
    setInitialArrays
    set model       [join [lindex $argv 0]]
    set tdbh        [join [lindex $argv 1]]
    if [catch {
        getConnectionSetup targetDef $tdbh [getInfo MODEL_FILES_DIRECTORY]
        if {$targetDef(schemaVersion) != "" && $model == ""} {
            set model [getVersionModDirName $targetDef(schemaVersion) [getInfo WORKING_DIRECTORY] ]
        }
        getConnectionSetup modelDef $model [getInfo MODEL_FILES_DIRECTORY]
    } err] {
        puts $err
        exit 1
    }
    set report      [lindex $argv 2]
    # if no report name has been supplied, generate default name based on model file number -> cert<modnumber>.lst
    if {$report == ""} {
        regsub -nocase {mod} $model.lst {cert} report
        puts "Output file was not supplied.\nSetting to $report"
    }
    set dir         [file dir $report]
    set report      [file tail $report]
    setInfo silent  [lindex $argv 3]
    set TABLES       [getInfo TABLES]
    setInfo dbCompare.REPORT $report
    setInfo connectString       $tdbh
    setInfo dbCompare.OUTDIR "$dir"
# TODO move to another proc
    if [catch {dbCompare $model $tdbh $report $TABLES} results] {
        puts "ERROR: $results $::errorInfo"
        catch {logoff $tdbh}
        catch {logoff $model}
        set fid [open dbcCore.txt w]
        puts $fid [showArray targetDef]
        puts $fid "**************"
        puts $fid [showArray modelDef]
        close $fid
        exit 1
    }
    if {[getResultsCount] != 0 || [getWarningsCount] != 0} {
        if {[getInfo MAKE_DDL] == "true"} {
            if {$modelDef(schemaVersion) == $targetDef(schemaVersion) || [getInfo REOVERRIDE] == "true"} {
                array unset resultSQL
                array set resultSQL [processDifferences2]
                if {[getInfo dbCompare.CORRECTION_SCRIPT_NAME] == ""} {
                    setInfo dbCompare.CORRECTION_SCRIPT_NAME [getDefaultCorrectionScriptName]
                }
                set resultSQL(OUTPUT) ""
                p_makeCorrectionDDL resultSQL [getInfo dbCompare.OUTDIR]
                # TODO evaluate where this is going;
                # puts [getInfo dbCompare.REPORT_HANDLE] [join $resultSQL(OUTPUT) \n]
            } else {
                puts "Schema versions are not the same, cannot generate DDL. Contact RE."
            }
        }
    }

    if {[getInfo makeModel] != ""} {
         p_makeModelFiles [getInfo makeModel]
    }
    if {[getInfo makeMatrix] != ""} {
        source schreq_verify_utilities.tcl
        putMatrix [p_makeMatrixA dummy [getInfo makeMatrix] dummy ] SchemaMatrix.txt
    }
    dbCompare.unsetAll
}
# to do items
# if default value is set but should be null, how to handle.  cannot be '', must be NULL in the correction.