catch {package require otc}
# -----------------------------------------------------------------------------
# Database validation
# -----------------------------------------------------------------------------
# USAGE:
# mtclsh dbvalid.tcl <schema-path>
# -----------------------------------------------------------------------------
# DESCRIPTION:
# Validate a database schema by:
#  * recompiling all triggers, procedures and functions and flagging any which
#    fail compilation
#  * checking for 'alien' FK constraints on our tables
# -----------------------------------------------------------------------------

set start_secs 0
set start_usec 0
set intvl_secs 0
set intvl_usec 0
global dbx

# Check the existence of common_utilities.tcl, source if available.
if {[catch {getInfo _common_utilities_loaded}]} {
    if [catch {glob common_utilities.tcl} err] {
        puts "The file common_utilities.tcl is not in the current directory."
        puts "This script cannot run without it."
        puts "Please obtain this file and copy it into this directory."

        return 2
    } else {
        puts "Sourcing common_utilities.tcl..."
        source common_utilities.tcl
    }
}


# ##########
# @proc         dbvalid.version
# @description  Returns current version of this script
# ##########
proc dbvalid.version {} {return 1}
proc dbvalid.revision {} {return 1}

# ##########
# @proc         usage
# @description  Prints usage information to the screen.
# ##########
proc usage {} {
    puts "[dbvalid.getDescription]"
    puts "Usage:"
    puts "    dbvalid.tcl \[username\]/\[password\]@\[hostname\] \[OPTION(s)\]"
    puts ""
    puts "Options:"
    puts "    SILENT            - Silences prompts for user input."
    puts "    (STATS|NOSTATS)   - Update, or do not update, schema statistics."
    puts "                        Note: Gathering statistics may take an hour or more"
    puts "                              in a production database."
    puts ""
    puts "Example Usage:"
    puts "    tclsh dbvalid.tcl dbname/dbpass@servername"
    puts "    tclsh dbvalid.tcl myUser/myPass@my-db-host SILENT"
    puts "    tclsh dbvalid.tcl myUser/myPass@my-db-host STATS"
    puts "    tclsh dbvalid.tcl myUser/myPass@my-db-host NOSTATS"
    puts "    tclsh dbvalid.tcl myUser/myPass@my-db-host SILENT NOSTATS"
    puts ""
    puts "Information:"
}
proc dbvalid.getDescription {} {
    return "Dbvalid.tcl evaluates the suitability of an Oracle installation and schema
for conversion to CareRadius.  The script will identify problem areas and,
where appropriate, suggest remedial action."
}

# ##########
# @proc         Date
# @description  convert a clock value in seconds to a suitable date/time string
# ##########
proc Date { secs } {
    return [ clock format $secs -format "%Y.%m.%d %H:%M:%S" ]
}

# ##########
# @proc         StartClock
# @description  Start timer.
# ##########
proc StartClock { } {
    global start_secs start_usec intvl_secs intvl_usec time_stamp

    set start_secs [ clock seconds ]
    set start_usec [ clock clicks -milliseconds ]
    set intvl_secs $start_secs
    set intvl_usec $start_usec
    set time_stamp [clock format $start_secs -format "%m.%d.%y_%H.%M.%S"]
}


# ##########
# @proc         ZeroInterval
# @description  reset interval time (for new test)
# ##########
proc ZeroInterval { } {
    global intvl_secs intvl_usec

    set nows [ clock seconds ]
    set nowu [ clock clicks -milliseconds ]

    set intvl_secs $nows
    set intvl_usec $nowu
}


# ##########
# @proc         ClockInterval
# @description  display timer interval (aka run time)
# ##########
proc ClockInterval { } {
    global start_secs start_usec intvl_secs intvl_usec

    set nows [ clock seconds ]
    set nowu [ clock clicks -milliseconds ]
    set ints [ expr $nows - $intvl_secs ]
    set intu [ expr $nowu - $intvl_usec ]

    logit "===> $ints secs, $intu usec"

    ZeroInterval
}


# ##########
# @proc
# @description  display timer grand total
# ##########
proc FinalClock { } {
    global start_secs start_usec intvl_secs intvl_usec

    set nows [ clock seconds ]
    set nowu [ clock clicks -milliseconds ]

    set tots [ expr $nows - $start_secs ]
    set totu [ expr $nows - $start_usec ]

    logit "===> $tots secs, $totu usec"
}


# ##########
# @proc         Warn
# @description  Prints a warning footer.
# ##########
proc Warn { } {
    return "Problems with the schema were detected which could hamper the
conversion process. Please address these issues and tne re-run this script."
}


# ##########
# @proc         Oracle_Check_Scheduled_Jobs
# @description  check scheduled jobs
# ##########
proc Oracle_Check_Scheduled_Jobs { dbx } {
    global dbvalid_fix_script
    putt "\n--- Checking Scheduled Jobs ---"

    if { [ catch { execsql use $dbx "SELECT ENABLED, OWNER, JOB_NAME,
                                    SCHEDULE_NAME, SCHEDULE_TYPE, COMMENTS, LAST_START_DATE,
                                    NEXT_RUN_DATE
                                    INTO :l_en, :l_own, :l_jn, :l_sn, :l_st, :l_com, :l_lsd, :l_nrd
                                    FROM USER_SCHEDULER_JOBS
                                    WHERE OWNER NOT IN ('EXPSYS')
                                    AND JOB_NAME NOT LIKE '%$%'
                                    AND SCHEDULE_TYPE NOT IN ('ONCE')
                                    ORDER BY NEXT_RUN_DATE" } ] != 0 } {
        set err [ getinfo all ]
        putt "\nERROR: SQL error\n$err\n"

        return -1
    }

    if { [ info exists l_own ] == 0 } {
        putt "PASS: No jobs found"
        return 0
    }

    append dbvalid_fix_script "-- DISABLE SCHEDULED JOBS --\n"
    set i 0

    foreach en $l_en {
        set own [ lindex $l_own $i ]
        set jn  [ lindex $l_jn $i  ]
        set sn  [ lindex $l_sn $i  ]
        set st  [ lindex $l_st $i  ]
        set com [ lindex $l_com $i ]
        set lsd [ lindex $l_lsd $i ]
        set nrd [ lindex $l_nrd $i ]
        append dbvalid_fix_script "exec dbms_scheduler.disable('$jn');\n"
        logit "$en $own $jn $sn $st $com $lsd $nrd"
    }

    append dbvalid_fix_script "-- END DISABLE SCHEDULED JOBS SECTION --\n\n"

    return 1;
}


# ##########
# @proc         Oracle_Check_Sessions
# @description  Check for open sessions
# ##########
proc Oracle_Check_Sessions {dbx dname } {
    putt "\n--- Checking for open sessions ---"

    set SQL "SELECT * INTO :l_ino,:l_ina,:l_hn,:l_vn,:l_st,:l_ss,:l_p,:l_th,
            :l_ar,:l_lsw,:l_log,:l_sp,:l_ds,:l_ir,:l_as,:l_b FROM V\$SESSION
            WHERE SCHEMANAME = '$dname' AND STATUS = 'ACTIVE'"

    if { [ catch { execsql $SQL } ] != 0 } {
        set err [ getinfo all ]
        putt "\nERROR: SQL error; $SQL\n$err\n"

        return -1
    }

    if { [ info exists l_ino ] == 0 } {
        putt "PASS: No sessions found"

        return 0
    }

    set i 0

    foreach ino $l_ino {
        set ina [ lindex $l_ina $i ]
        set hn  [ lindex $l_hn  $i ]
        set vn  [ lindex $l_vn  $i ]
        set st  [ lindex $l_st  $i ]
        set ss  [ lindex $l_ss  $i ]
        set p   [ lindex $l_p   $i ]
        set th  [ lindex $l_th  $i ]
        set ar  [ lindex $l_ar  $i ]
        set lsw [ lindex $l_lsw $i ]
        set log [ lindex $l_log $i ]
        set sp  [ lindex $l_sp  $i ]
        set ds  [ lindex $l_ds  $i ]
        set ir  [ lindex $l_ir  $i ]
        set as  [ lindex $l_as  $i ]
        set b   [ lindex $l_b   $i ]
        logit "    $ina $hn $vn $st $ss $p $th $ar $lsw $log $sp $ds $ir $as $b"

        incr i
    }

    if { $i < 2 } {
        puts "PASS: One session found (likely this script)"

        return 0
    }

    puts "FAIL: Active Sessions were found on this schema."
    puts "      Please ensure there are no open sessions and try again."

    return $i
}


# ##########
# @proc         GetParameter
# @description  Query and return the value of an Oracle parameter
# ##########
proc GetParameter {dbx  name { divisor 0 } } {
    if { $divisor > 1 } {
        set SQL "SELECT VALUE / $divisor INTO :val FROM V\$PARAMETER WHERE NAME = '$name'"
    } else {
        set SQL "SELECT VALUE INTO :val FROM V\$PARAMETER WHERE NAME = '$name'"
    }

    if { [ catch { execsql $SQL } ] != 0 } {
        set err [ getinfo all ]
        putt "\nERROR: SQL error; $SQL\n$err\n"

        return -1
    }

    if { [ info exists val ] == 0 } {
        putt "ERROR: Oracle parameter $name not found in V\$PARAMETER"
        putt "  Access to the view V_\$PARAMETER is required for this step"

        return "wibble"
    }

    return $val
}


# ##########
# @proc         Oracle_Check_Archive_Log
# @description  Check that Archive Log mode is disabled
# ##########
proc Oracle_Check_Archive_Log {dbx  } {
    putt "\n--- Checking Archive Log Mode ---"

    set v [ GetParameter $dbx "log_archive_start" ]
    if { $v == "wibble" } { return 1 }

    if { $v == "FALSE" } {
        putt "PASS: Archive log mode is disabled"

        return 0
    }

    putt "FAIL: Archive log mode is ENABLED - this should be corrected"
    return 1
}


# ##########
# @proc         Oracle_Check_Undo_Retention
# @description  Check the undo retention time setting
# ##########
proc Oracle_Check_Undo_Retention {dbx uret} {
    putt "\n--- Checking UNDO retention ---"

    set v [ GetParameter $dbx "undo_retention" ]
    if { $v == "wibble" } { return 1 }

    if { $v >= $uret } {
        putt "PASS: UNDO retention of $v seconds is suitable"

        return 0
    }

    putt "FAIL: UNDO retention is $v seconds; this must be extended to $uret"

    return 1
}


# ##########
# @proc         Oracle_Check_SGA_Size
# @description  Check the SGA size
# ##########
proc Oracle_Check_SGA_Size {dbx sgamin} {
    putt "\n--- Checking SGA size ---"

    set v [ GetParameter $dbx "sga_max_size" 1048576 ]
    logit "$sgamin MB are required"
    if { $v == "wibble" } { return 1 }
    if { $v >= $sgamin } {
        putt "PASS: SGA size of $v MB is suitable"
        return 0
    }

    putt "FAIL: SGA size of $v MB is insufficient; minimum required is $sgamin MB"

    return 1
}


# ##########
# @proc         Oracle_Check_DB_Writers
# @description  Check DB Writers
# ##########
proc Oracle_Check_DB_Writers {dbx  } {
    putt "\n--- Checking DB Writer Processes ---"

    set v [ GetParameter $dbx "db_writer_processes" ]
    if { $v == "wibble" } { return 1 }

    putt     "CHECK: Currently $v DB Writer processes are configured"
    logit "       This number should, ideally, be the number of CPU cores"
    logit "       divided by 4. NB: on hyperthreaded systems the number of"
    logit "       physical cores may not match the number of cores reported"
    logit "       by the extant operating system. If in doubt please consult"
    logit "       your hardware vendor for verification."

    return 0
}


# ##########
# @proc         Oracle_Check_Undo_Tablespace
# @description  Check undo tablespace
# ##########
proc Oracle_Check_Undo_Tablespace {dbx  dname} {
    putt "\n--- Checking UNDO tablespace ---"

    # ---------------------------------------------------------------------------
    # first, confirm that we have access to the required views/tables
    # ---------------------------------------------------------------------------
    set SQL "SELECT COUNT(*) INTO :f
            FROM ALL_VIEWS WHERE VIEW_NAME IN ('DBA_DATA_FILES', 'DBA_SEGMENTS')"

    if { [ catch { execsql $SQL } ] != 0 } {
        set err [ getinfo all ]
        putt "\nERROR: SQL error; $SQL\n$err\n"

        return -1
    }

    if { $f < 2 } {
        putt "ERROR: this check requires access to the following views:"
        putt "  DBA_DATA_FILES DBA_SEGMENTS"
        putt " Please grant the schema select rights to these views and retry"

        return 1
    }

    # ---------------------------------------------------------------------------
    # calculate the required UTS
    # ---------------------------------------------------------------------------
    set SQL "SELECT 1.5 * (SUM(BYTES) / 1048576) INTO :ruts
            FROM DBA_SEGMENTS WHERE SEGMENT_TYPE = 'TABLE'
            AND OWNER = '$dname'
            AND SEGMENT_NAME IN
            (SELECT TOR_TABLE_NAME FROM TOR_TABLE_ORDER)"

    if { [ catch { execsql $SQL } ] != 0 } {
        set err [ getinfo all ]
        putt "\nERROR: SQL error; $SQL\n$err\n"

        return -1
    }

    # ---------------------------------------------------------------------------
    # calculate current available UTS
    # ---------------------------------------------------------------------------
    set SQL "SELECT (BYTES / 1048576), (MAXBYTES / 1048576) INTO :cuts, :muts
            FROM DBA_DATA_FILES WHERE TABLESPACE_NAME LIKE '%UNDO%'"

    if { [ catch { execsql $SQL } ] != 0 } {
        set err [ getinfo all ]
        putt "\nERROR: SQL error; $SQL\n$err\n"

        return -1
    }

    # ---------------------------------------------------------------------------
    # now sum them; (algorithm DRP)
    # ---------------------------------------------------------------------------
    set i 0
    set sum 0
    foreach cu $cuts {
        set mu [ lindex $muts $i ]
        if { $mu == 0 } {
            set sum [ expr $sum + $cu ]
        } else {
            set sum [ expr $sum + $mu ]
        }

        incr i
    }

    # ---------------------------------------------------------------------------
    # and check
    # ---------------------------------------------------------------------------
    regsub  {\..*} $ruts "" ruts    ; #hack off mantissa
    regsub  {\..*} $sum  "" sum     ; #hack off mantissa

    logit "    Required: $ruts MB"
    logit "    Current:  $sum MB"

    if { $sum >= $ruts } {
        putt "PASS: Undo tablespace is adequate"

        return 0;
    }

    putt "FAIL: Undo tablespace is insufficient; < $ruts MB"

    return 1
}


# ##########
# @proc         OracleConfigChecks
# @description  Perform various Oracle configuration checks
# ##########
proc OracleConfigChecks {dbx dname uret sgamin} {
    putt [getInfo hr]\n
    putt "--- Performing Oracle Configuration Prerequisite checks ---"

    set orb 0

    if { [ Oracle_Check_Scheduled_Jobs $dbx ] != 0 } { incr orb }
    ClockInterval

    if { [ Oracle_Check_Sessions $dbx  $dname] != 0 } { incr orb }
    ClockInterval

    if { [ Oracle_Check_Archive_Log $dbx ] != 0 } { incr orb }
    ClockInterval

    if { [ Oracle_Check_Undo_Retention $dbx $uret] != 0 } { incr orb }
    ClockInterval

    if { [ Oracle_Check_Undo_Tablespace $dbx $dname] != 0 } { incr orb }
    ClockInterval

    if { [ Oracle_Check_SGA_Size $dbx $sgamin] != 0 } { incr orb }
    ClockInterval

    if { [ Oracle_Check_DB_Writers $dbx ] != 0 } { incr orb }
    ClockInterval

    return $orb
}


# ##########
# @proc         CheckFKPrecision
# @description  check for column-size mismatches between FK constraints.  fetch
#               all FK constraints and for each column in each constraint, match
#               the type and precision of that column with its constrained counterpart.
#               for (each FK-type constraint) compare constrained column size &
#               precision with constraint reference
# ##########
proc CheckFKPrecision { dbx } {
    global dbvalid_fix_script

    putt "\n--- Checking for related column-precision mismatches ---"

    execsql "SELECT COUNT(*) INTO :nocs FROM USER_CONSTRAINTS"

    # query all FK constraint names
    execsql use $dbx "SELECT
        CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, POSITION,
        (SELECT DATA_TYPE
            FROM ALL_TAB_COLUMNS ATC
            WHERE UCC.TABLE_NAME = ATC.TABLE_NAME
            AND UCC.COLUMN_NAME = ATC.COLUMN_NAME),
        (SELECT DATA_LENGTH
            FROM ALL_TAB_COLUMNS ATC
            WHERE UCC.TABLE_NAME = ATC.TABLE_NAME
            AND UCC.COLUMN_NAME = ATC.COLUMN_NAME),
        (SELECT DATA_PRECISION
            FROM ALL_TAB_COLUMNS ATC
            WHERE UCC.TABLE_NAME = ATC.TABLE_NAME
            AND UCC.COLUMN_NAME = ATC.COLUMN_NAME),
        (SELECT DATA_SCALE
            FROM ALL_TAB_COLUMNS ATC
            WHERE UCC.TABLE_NAME = ATC.TABLE_NAME
            AND UCC.COLUMN_NAME = ATC.COLUMN_NAME),
        (SELECT R_CONSTRAINT_NAME
            FROM USER_CONSTRAINTS UC
            WHERE UC.CONSTRAINT_NAME = UCC.CONSTRAINT_NAME),
        (SELECT INDEX_NAME
            FROM USER_CONSTRAINTS UC
            WHERE UC.CONSTRAINT_NAME = UCC.CONSTRAINT_NAME)
        INTO :l_con, :l_tn, :l_cn, :l_pos, :l_dt,
            :l_dl, :l_dp, :l_ds, :l_rs, :l_in
        FROM USER_CONS_COLUMNS UCC"

    set i 0
    foreach con $l_con {
        set tn  [ lindex $l_tn $i ]
        set cn  [ lindex $l_cn $i ]
        set pos [ lindex $l_pos $i ]
        set dt  [ lindex $l_dt $i ]
        set dl  [ lindex $l_dl $i ]
        set dp  [ lindex $l_dp $i ]
        set ds  [ lindex $l_ds $i ]
        set rs  [ lindex $l_rs $i ]
        set in  [ lindex $l_in $i ]
        append fix ""
        logit "$con $tn.$cn $pos $dt\($dl\) $rs $in"

        incr i
    }

    return 0
}


# ##########
# @proc         CheckObjectsCompile
# @description  recompile all objects in the user_procedures view (procedures, packages,
#               functions and triggers) and flag any that fail recompilation.
# ##########
proc CheckObjectsCompile { dbx } {
    global  dbvalid_fix_script

    putt "\n--- Checking for invalid object statuses ---"

    execsql "SELECT COUNT(*) INTO :nobs FROM USER_OBJECTS"
    execsql use $dbx   "SELECT OBJECT_NAME, OBJECT_TYPE
                        INTO :l_on, :l_ot
                        FROM USER_OBJECTS
                        WHERE STATUS = 'INVALID'
                        AND OBJECT_NAME NOT LIKE '____TGRB_I___'
                        AND OBJECT_NAME NOT LIKE '____TGRB_D___'
                        AND OBJECT_NAME NOT LIKE '____TGRB_U___'
                        ORDER BY OBJECT_TYPE, OBJECT_NAME"

    set bad 0
    set fix ""
    foreach name $l_on {
        set type [ lindex $l_ot $bad ]
        putt "    INVALID STATUS: $type $name"
        incr bad

        append fix "BEGIN\n"

        if {$type == "PACKAGE"} {
            #NOTE: Packages must compile body as well.
            append fix "    EXECUTE IMMEDIATE 'ALTER $type $name COMPILE';\n"
            append fix "    EXECUTE IMMEDIATE 'ALTER $type $name COMPILE BODY';\n"
        } else {
            append fix "    EXECUTE IMMEDIATE 'ALTER $type $name COMPILE';\n"
        }

        #If there was a problem, simply drop the object - usually due to missing item
        append fix "EXCEPTION\n"
        append fix "    WHEN OTHERS THEN\n"
        append fix "        EXECUTE IMMEDIATE 'DROP $type $name';\n"
        append fix "END;\n"
        append fix "/\n"
    }

    if { $bad == 0 } {
        putt "PASS: no objects found with an invalid status"
    } else {
        putt "FAIL: $bad/$nobs objects with an invalid status"
        append dbvalid_fix_script "-- RECOMPILE INVALID OBJECTS --\n\n"
        append dbvalid_fix_script $fix
        append dbvalid_fix_script "-- END RECOMPILE INVALID OBJECTS SECTION -- \n\n"
    }

    return $bad
}


# ##########
# @proc         CheckConstraints
# @description  flag questionable constraints.  list any constraint applied to a
#               table not listed in TOR that is predicated on a table that _is_
#               listed in TOR
# ##########
proc CheckConstraints { dbx dname} {
    global dbvalid_fix_script

    putt "\n--- Checking for questionable constraints ---"
    execsql "SELECT COUNT(*) INTO :noc FROM USER_CONSTRAINTS"
    execsql use $dbx   "SELECT
                        OWNER AS OWN,
                        CONSTRAINT_NAME AS CON,
                        TABLE_NAME AS TBL,
                        R_OWNER AS ROWN,
                        (SELECT TABLE_NAME||'.'||CONSTRAINT_NAME
                            FROM ALL_CONSTRAINTS B
                            WHERE A.R_CONSTRAINT_NAME = B.CONSTRAINT_NAME
                            AND B.TABLE_NAME IN (SELECT TOR_TABLE_NAME FROM TOR_TABLE_ORDER)
                        ) AS REFS,
                        INDEX_NAME AS IDX
                        INTO :l_own, :l_con, :l_tbl, :l_rown, :l_refs, :l_idx
                        FROM ALL_CONSTRAINTS A
                        WHERE R_CONSTRAINT_NAME IS NOT NULL
                        AND OWNER = '$dname'
                        AND SUBSTR(TABLE_NAME, 1, 3) NOT IN (SELECT SUBSTR(TOR_TABLE_NAME, 1, 3) FROM TOR_TABLE_ORDER)
                        AND SUBSTR(TABLE_NAME, 1, 3) NOT IN ('ATI', 'ATB', 'ENI', 'ENT', 'ERP' )
                        and STATUS = 'ENABLED'"

    set i 0
    set bad 0
    set fix "-- DROP QUESTIONABLE CONSTRAINTS --\n\n"

    foreach own $l_own {
        set con  [ lindex $l_con $i  ]
        set tbl  [ lindex $l_tbl $i  ]
        set rown [ lindex $l_rown $i ]
        set refs [ lindex $l_refs $i ]
        set idx  [ lindex $l_idx $i  ]

        if {$refs != ""} {
            append fix "Alter table $tbl drop constraint $con;\n"
            logit "   $own.$tbl ($con) -> $rown.$refs $idx"
            incr bad
        }

        incr i
    }

    if { $bad == 0 } {
        putt "PASS: No questionable constraints detected"
    } else {
        putt "FAIL: $bad/$noc questionable constraints found"
        append dbvalid_fix_script $fix
        append dbvalid_fix_script "-- END DISABLE QUESTIONABLE CONSTRAINTS SECTION --\n\n"
    }

    return $bad
}


# ##########
# @proc         CheckIndexColumnCounts
# @description  check for indexes with too many columns whose prefix does not match any
#               table prefix in TOR
# ##########
proc CheckIndexColumnCounts {dbx maxic } {
    global  dbvalid_fix_script

    putt "\n--- Checking for indexes with excessive column counts ---"
    execsql "SELECT COUNT(*) INTO :noi FROM USER_INDEXES"

    set l_idx ""

    execsql "SELECT INDEX_NAME INTO :l_idx FROM USER_INDEXES UI
            WHERE (SELECT COUNT(*) FROM USER_IND_COLUMNS UIC
            WHERE UI.INDEX_NAME = UIC.INDEX_NAME) >= $maxic"

    set bad 0
    set fix "-- DROP EXCESSIVE COLUMN COUNT INDEXES --\n\n"

    foreach idx $l_idx {
        execsql "SELECT COUNT(*) INTO :nuc FROM USER_IND_COLUMNS
                WHERE INDEX_NAME = '$idx'"
        if { $nuc >= $maxic } {
            logit "   $nuc columns in index $idx"
            incr bad
            append fix "Drop index $idx;\n"
        } else {
            logit "ERROR: counted columns *changed* on $idx"
        }
    }

    if { $bad == 0 } {
        putt "PASS: No oversized indexes found"
    } else {
        putt "FAIL: $bad/$noi oversized indexes"
        append  dbvalid_fix_script $fix
        append dbvalid_fix_script "-- END DROP EXCESSIVE COLUMN COUNT INDEXES SECTION--\n\n"
    }

    return $bad
}


# ##########
# @proc         checkFunctionalIndexes
# @description  check for function-based indexes on Lcor tables
# ##########
proc checkFunctionalIndexes {dbx } {
    global  dbvalid_fix_script
    putt "\n--- Checking for function-based indexes on schema tables ---"
    set idxnames ""
    set idxtables ""
    set sql "Select index_name, table_name
            into :idxnames, :idxtables
            from USER_INDEXES
            where TABLE_NAME in (
            Select tor_table_name from TOR_TABLE_ORDER)
            and funcidx_status is not null
            order by INDEX_NAME"
    catch {execsql use $dbx $sql} err

    if {$err < 0} {
        set bad 1
    } else {
        set bad 0
    }

    set fix "-- DROP FUNCTIONAL INDICES --\n\n"

    foreach index $idxnames table $idxtables {
        incr bad
        logit "Functional index $table.$index found."
        append fix "DROP INDEX $index;\n"
    }

    if { $bad == 0 } {
        putt "PASS: No function-based indexes found"
        return 0
    }

    putt "FAIL: $bad function-based indexes found"
    append dbvalid_fix_script $fix
    append dbvalid_fix_script "-- END DROP FUNCTIONAL INDICES SECTION --\n\n"

    return $bad
}


# ##########
# @proc         CheckTriggers
# @description  check for unexpected trigger functions
# ##########
proc CheckTriggers { dbx } {
    global dbvalid_fix_script

    putt "\n--- Checking for unexpected trigger functions ---"
    execsql use $dbx   "SELECT TRIGGER_NAME
                        INTO :l_tn
                        FROM USER_TRIGGERS TRIG,
                        TOR_TABLE_ORDER TOR
                        WHERE TRIG.TRIGGER_NAME NOT LIKE SUBSTR(TOR.TOR_TABLE_NAME,1,   3)||'_TGRB___01'
                        AND TRIG.TRIGGER_NAME NOT LIKE 'AUDIT_'||SUBSTR(TOR.TOR_TABLE_NAME,1,3)||'%'
                        AND TRIG.TRIGGER_NAME != 'TJN_UPDATE_TRIGGER'
                        AND TRIG.TABLE_NAME = TOR.TOR_TABLE_NAME"

    set bad 0
    set fix "-- DROP UNEXPECTED_TRIGGERS --\n\n"

    foreach tn $l_tn {
        if {![regexp {[A-Z]{3}_TGRB_[UID]_\d\d} $tn ]} {
            logit "Unexpected trigger: $tn"
            append fix "DROP TRIGGER $tn;\n"
            incr bad
        }
    }

    if { $bad == 0 } {
        putt "PASS: No unexpected triggers found"

        return 0
    }

    putt "FAIL: $bad unexpected triggers found"
    append dbvalid_fix_script $fix
    append dbvalid_fix_script "-- END DROP UNEXPECTED_TRIGGERS SECTION --\n\n"

    return $bad
}

# ##########
# @proc         RecreateObjects
# @description  Retrive the schema objects.
# ##########

proc RecreateObjects { dbx } {
    global  dbvalid_fix_script_new
    global  dbvalid_fix_script_new_package


    putt "\n--- Generating sql code for objects that failed during compilation  ---"

    execsql "SELECT COUNT(*) INTO :nobs FROM USER_OBJECTS"

    execsql use $dbx   "SELECT OBJECT_NAME, OBJECT_TYPE
                        INTO :l_on, :l_ot
                        FROM USER_OBJECTS
                        WHERE STATUS = 'INVALID'
                        AND OBJECT_NAME NOT LIKE '____TGRB_I___'
                        AND OBJECT_NAME NOT LIKE '____TGRB_D___'
                        AND OBJECT_NAME NOT LIKE '____TGRB_U___'
                        ORDER BY OBJECT_TYPE, OBJECT_NAME"
    set bad 0
    set fix ""
    set fix_pkg ""
    foreach name $l_on {
        set type [ lindex $l_ot $bad ]
        logit "    INVALID STATUS: $type $name"
        incr bad
        execsql use $dbx  "select TEXT from user_source
                           into :temp
                           where type = '$type' and NAME = '$name'"
        set body $temp;

        if {$type == "PACKAGE BODY"} {
        append fix_pkg "CREATE OR REPLACE  "
        append fix_pkg "$body \n"
        append fix_pkg "/\n"
        append fix_pkg "-- End of $type $name --\n\n"
        } else {
        append fix "CREATE OR REPLACE  "
        append fix "$body \n"
        append fix "/\n"
        append fix "-- End of $type $name --\n\n"
        }
    }

    if { $bad == 0 } {
        putt "PASS: no objects found with an invalid status"
    } else {
         putt "FAIL: $bad/$nobs objects with an invalid status"
         append dbvalid_fix_script_new $fix
         append dbvalid_fix_script_new_package $fix_pkg
     }

    return $bad

}

# ##########
# @proc         GatherStatistics
# @description  Gathers schema statistics.
# ##########
proc GatherStatistics {dbx dname {STATS ""}} {
    global silent

    if {$STATS == "true"} {
        set done 1
    } elseif {$STATS == "false"} {
        set done 2
    } else {
        set done 0
    }

    if {![info exists silent]} {set silent 0}

    execsql use $dbx   "SELECT COUNT(*)
                        INTO :tn
                        FROM (SELECT NUM_ROWS FROM USER_TABLES WHERE TABLE_NAME IN (SELECT TOR_TABLE_NAME FROM TOR_TABLE_ORDER) AND NUM_ROWS IS NULL)"

    # if statistics are up to date
    if { $tn != 0 } {
        putt "\nWARNING: Schema statistics appear to be out of date"
        putt "\nIt is highly recommended that schema statistics are updated prior"
        putt "to beginning the database conversion or the conversion speed could be"
        putt "adversely affected.  Gathering statistics may take an hour or more in"
        putt "a production database."

        if {!$silent || $STATS == "true"} {
            while { $done == 0 } {
                putt "\nIf you wish to gather statistics please type 'yes' at this prompt: "

                set len [ gets stdin reply ]
                if { $len > 0 } {
                    if { $reply == "yes" } {
                        set done 1
                    } else {
                        set done 2
                    }
                } else {
                    putt "Please respond with 'yes' or 'no'"
                }
            }

            if { $done == 1 } {
                ZeroInterval            ; # RESET INTERVAL TIMER

                putt "\n--- Generating database statistics ---"

                if { [ catch { execsql "CALL DBMS_STATS.GATHER_SCHEMA_STATS('$dname', 100)" } ] } {
                    putt "ERROR: Failed to gather statistics."
                    putt "\nPlease contact EXL Healthcare Support for help in resolving this issue."
                    exit 1
                }

                ClockInterval           ; # READ OFF THE CURRENT INTERVAL

            } else {
                putt "\nUser elected to skip generation of database statistics."
            }
        }
    }

    return 0
}


# ##########
# @proc         dbvalid
# @description  Main logic for this script.
# ##########
proc dbvalid {dbpath {dbx ""} {STATS ""}} {
    set maxic   9       ;# threshhold index column count
    set uret    28800   ;# undo retention time
    set sgamin  4096    ;# sga min

    global  dbvalid_fix_script_new_package time_stamp
    global  dbvalid_fix_script_new time_stamp
    global  dbvalid_fix_script time_stamp
    set dname   [ string toupper [ lindex [ split $dbpath "/" ] 0 ] ]
    set dbvalid_fix_script ""
    set dbvalid_fix_script_new ""
    set dbvalid_fix_script_new_package ""
    set toolName dbvalid

    StartClock              ; # START THE MAIN TIMING CLOCK
    setStartTime "$toolName"
    set suffix      [clock format [getStartTime $toolName] -format  "%m%d%H%M"]
    set reportfile $toolName\_$suffix.log
    set rpt [getReportFile $toolName [getInfo outDir] $reportfile]
    updateInfo $toolName.REPORT_HANDLE $rpt
    updateInfo default_channel $rpt
    puts [getInfo HR]
    printInitialHeader $toolName [$toolName.getDescription] [$toolName.version].[$toolName.revision]

    putt "========= DATABASE SCHEMA PRE-CONVERSION VALIDATION CHECK ========="

    # --- connect to target schema ---
    if {$dbx == ""} {
        if { [ catch { set dbx [ getLogonHandle $dbpath ] } ] } {
            putt "Cannot connect to $dbpath"

            exit 1
        }

        putt "Connected to $dbpath"
    }

    ClockInterval           ; # READ OFF THE CURRENT INTERVAL

    set sql    "select sum(bytes)/1024/1024 into :dbsize from user_segments
                where segment_type = 'TABLE' or segment_type = 'INDEX'"
    execsql $sql

    set uret [expr int($dbsize / 2.7) ]
    # puts $uret

    set sgamin [expr int($dbsize / 18)]
    # puts $sgamin

    # ---------------------------- do something -----------------------------------
    set orv 0
    if { [ CheckObjectsCompile $dbx] != 0 } { incr orv }
    ClockInterval           ; # READ OFF THE CURRENT INTERVAL

    if { [ CheckConstraints $dbx $dname ] != 0 } { incr orv }
    ClockInterval           ; # READ OFF THE CURRENT INTERVAL

    if { [ CheckIndexColumnCounts $dbx $maxic] != 0 } { incr orv }
    ClockInterval           ; # READ OFF THE CURRENT INTERVAL

    if { [ checkFunctionalIndexes $dbx] != 0 } { incr orv }
    ClockInterval           ; # READ OFF THE CURRENT INTERVAL

    if { [ CheckTriggers $dbx ] != 0 } { incr orv }
    ClockInterval           ; # READ OFF THE CURRENT INTERVAL

    if { [ RecreateObjects $dbx ] != 0 } { incr orv }
    ClockInterval           ; # PRINTS SQL OBJECTS TO FILE

    if { [ GatherStatistics $dbx $dname $STATS] != 0 } { incr orv }

    if { [ OracleConfigChecks $dbx $dname $uret $sgamin] != 0 } { incr orv }

    if { $orv != 0 } { Warn }


   if {$dbvalid_fix_script != ""} {
        set dbv_fix [open dbvalid_schema_fixes_$time_stamp.sql w]
        puts $dbv_fix $dbvalid_fix_script
        puts $dbv_fix "Commit;\nexit"

        close $dbv_fix
    }

    if {$dbvalid_fix_script_new != ""} {
        set dbv_fix [open dbvalid_schema_fixes_new_$time_stamp.sql w]
        puts $dbv_fix [string map {\{ "" \} ""}  $dbvalid_fix_script_new]

        close $dbv_fix
    }

    if {$dbvalid_fix_script_new_package != ""} {
        set dbv_fix [open dbvalid_schema_fixes_new_package_$time_stamp.sql w]
        puts $dbv_fix [string map {\{ "" \} ""}  $dbvalid_fix_script_new_package]

        close $dbv_fix

        putt "A script to fix certain aspects of the schema validiation has been created"
        putt "This script is ./dbvalid_schema_fixes_new_package_$time_stamp.sql"
    }

    # -----------------------------------------------------------------------------
    # tadaaa!
    # -----------------------------------------------------------------------------
    putt "========= DATABASE SCHEMA PRE-CONVERSION VALIDATION CHECK COMPLETE ========="
    putt [getInfo HR]
    set duration [getDuration [getStartTime $toolName]]
    if {$orv == 0} {
        set status PASS
        set message "successfully."
    } else {
        set status FAIL
        set message "with issues:\n[Warn]"
    }
    putt "$toolName.tcl [$toolName.version], revision [$toolName.revision] has completed $message"
    putt "Run Time was [prettyTime [hms $duration]]."
    puts "Please carefully review the $reportfile report."
    putt      "END: [clock format [clock seconds] -format "[getInfo dateFormat] [getInfo timeFormat]"]"
    putt      [getInfo HR]
    putt   "RESULTS: $orv"
    putt   "STATUS: $status"
    setlog OFF $rpt
    if {[getInfo AutoScript.REPORT_HANDLE] != ""} {
        puts [getInfo AutoScript.REPORT_HANDLE] "$toolName.tcl version [$toolName.version], revision [$toolName.revision] has completed $message."
        puts [getInfo AutoScript.REPORT_HANDLE] "Output file is $reportfile."
    }
    unsetInfo $toolName*

    return $orv
}

# ============================= ENTRY POINT ====================================
if {[info exists argv0] && [string tolower $argv0] == "dbvalid.tcl"} {
    # Usage
    if {$argc == 0} {
        usage
        exit 0
    }

    set dbvalid_fix_script ""
    set dbpath [ lindex $argv 0 ]
    set silent 0

    # Check STATS parameter
    if {[lsearch [string toupper $argv] "STATS"] >= 0} {
        puts "INFO: Collecting statistics."
        set STATS "true"
    } elseif {[lsearch [string toupper $argv] "NOSTATS"] >= 0} {
        puts "INFO: Skipping statistics collection."
        set STATS "false"
    } else {
        set STATS ""
    }

    # Check SILENT parameter
    if {[lsearch [string toupper $argv] "SILENT"] >= 0} {
        puts "INFO: Running in \"SILENT\" mode... No user prompts."

        set silent 1
    }

    # Check connection
    if { [ catch { set dbx [ getLogonHandle $dbpath ] } err] } {
        puts "ERROR: $err"
        puts "INFO: Dbvalid.tcl experienced an error and could not connect to $dbpath"
        puts "INFO: Verify that your connection information is correct, and that you are using mtclsh, and try again."

        exit 1
    }

    set orv [dbvalid $dbpath $dbx $STATS]
}
