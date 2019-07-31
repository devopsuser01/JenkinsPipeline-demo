#===============================================================================
#
# SCRIPT NAME  : AutoScript.tcl
#
# WRITTEN BY   : Anna Devore
#
# DATE         : July 26, 2002
#
# PLATFORM     : Unix or NT.
#
# INSTRUCTIONS : Include logon information, Driver file , optionally e-mail address.
#
# PURPOSE      : Automatically process all scripts and certification involved in a upgrade.
#===============================================================================

# Needed source files/ packages
if {[catch {getInfo _common_utilities_loaded}]} {
    if [catch {glob common_utilities.tcl} err] {
        puts "The file common_utilities.tcl is not in the current directory."
        puts "This script cannot run without it."
        puts "Please obtain this file and copy it into this directory."
        return -2
    } else {
        source common_utilities.tcl
    }
}

# ##########
# @proc AutoScript.version/revision
# @current version of tool - update as needed.
# ##########
# @author
# @param
# @exception
# @see
# @return version
# ##########
proc AutoScript.version {} {return "6"}
proc AutoScript.revision {} {return "0"}
proc asc_tool {} {return "AutoScript"}
set toolName AutoScript
#============================================================
# procedures
# ##########
# @getArgsAutoScript
# @parse inputs
# ##########
# @author LAQ
# @param argv the input arguments
# @param argc the input count
# @exception none
# @see
# @return argv
# ##########
proc getArgsAutoScript {argv argc} {
    # parse inputs - database, driverfile autodrop silent email
    set silentindex [lsearch  [split [string tolower [join $argv]]] "silent"]

    if {$silentindex > 0} {
        set silent 1

        puts "Running in silent mode, warnings will be suppressed.\n"

        #if no email notification, need to remove this, or it will be parsed as email address
        set argv [lreplace $argv $silentindex $silentindex]
        set argc [llength $argv]
    } else {
        set silent 0
    }

    if {$argc < 3} {
        puts "\n***ERROR  - Not enough arguments"
        puts "*****************************************\n"

        return -1
    }

    set database [lindex $argv 0]

    if {![regexp {.*/.*@} $database]} {
        #TODO error message
        putt "Invalid database connection string"

        return -1
    }

    if [catch {glob [lindex $argv 1]} driverFile] {
        puts "\n***ERROR  - Unable to find driver file [lindex $argv 1]"
        puts "Please check your typing and that the file exists."
        puts "*****************************************\n"

        return -1
    }

    set driverFileName [file tail $driverFile]
    set auto_drop [string range [string toupper [lindex $argv 2]] 0 0]

    if { $auto_drop != "Y" && $auto_drop != "N" } {
        puts "***ERROR  - Invalid Auto Drop Unused flag.  "

        return -1
    }

    # if client wants email notification, check that it works.
    set e_mail nomail

    if { $argc == 4 } {
        set e_mail [lindex $argv 3]

        if [regexp {@.*\.} $e_mail] {
            #set continue [getResponse "$e_mail "]
        } else {
            puts "***ERROR  - Invalid email address"

            return -1
        }
    }

    return "$database $driverFile $auto_drop $e_mail $silent"
}

# pauseOnIndexScript
# allows user to review and modify if necessary a script before it runs.
# User may exit, review, restart autoscript
# or user may review and type go
# params: scriptname - script client should review
# returns : none
proc pauseOnIndexScript {scriptname} {
    puts "Please review the file $scriptname as outlined in the conversion guide."
    puts "When you are finished, enter 'go' to finish the conversion,"
    puts "or any other key to exit autoscript.  You may then restart autoscript"
    puts "when you are ready to continue."
    puts -nonewline "\nTo run $scriptname and finish the conversion enter 'go' now: > "

    flush stdout

    gets stdin response

    if {[string trim [string tolower $response] "'"] != "go"} {
        puts "Exiting autoscript.tcl"
        puts "When you have finished reviewing $scriptname, you may resume"
        puts "running autoscript."

        exit
    }
}

# ##########
# @getToolsList
# @returns the tools needed by product
# ##########
# @author
# @param product,  export file name (version specific.)
# @exception
# @see
# @return tool list
# ##########
proc getToolsList {product e_file} {
    switch $product {
        "CR"  { set tcl_tools "dbvalid dbCompare SysDataGen SysDeleteEval sy_load seqfix" }
        "MC" -
        "M2" {set tcl_tools "dbCompare SysDataGen SysDeleteEval sy_load seqfix TaskImport $e_file"}
        "CF" {set tcl_tools "dbCompare SysDataGen SysDeleteEval TblspAnalysis seqfix"}
    }

    return $tcl_tools
}

# ##########
# @checkResources
# @ensures that necessary conversion tools and resources exist.
# ##########
# @author
# @param tools list, driver file name.
# @exception
# @see
# @return missing item list or ""
# ##########
proc checkResources {tcl_tools driverfile } {
    set missing {}
    # TaskImport not for CR

    foreach tool $tcl_tools {
        if { [file exists $tool.tcl] == 0 } {
            lappend missing "$tool.tcl is missing."
        }
    }

    set scriptlist [getLines $driverfile]

    foreach test_lst $scriptlist {
        set test [lindex $test_lst 1]

        if { [string first sql $test] > 0 } {
            if { [file exists $test] == 0 } {
                set i_test2 [string first g_new_tblsp $test]

                if { $i_test2 < 0 } {
                    lappend missing "$test is missing."
                } else {
                    set test2 [string range $test 0 $i_test2].sql

                    if { [file exists $test2] == 0 } {
                        lappend missing "$test2 is missing."
                    }
                }
            }
        }
    }

    return $missing
}

# ##########
# @restartYN
# @determines from existing .bat file where to restart theconversion
# ##########
# @author LAQ
# @param scriptLogonString logon to use in scripts (usually the same as database)
# @exception
# @see
# @return current product, current versison, -1
# ##########
proc restartYN {DBH scriptLogonString batty silent} {
    upvar driverFile driverFile
    set status 0

    putt "Found $batty, indicating autoscript is restarting from prior run."

    set conts [getLines $batty]
    set script_name [lindex $conts 1]
    set script_name [lindex [split $script_name "@"] 2]
    set script_dir  [file dirname [string trim [string trim $script_name] \"]]
    set script_name [file tail [string trim $script_name \"] ]
    set results ""
    set current_product ""
    putt "Found script $script_name mentioned in $batty."
    catch {execsql use $DBH "select shs_results, shs_version_new into :results, :new_version from shs_schema_history where shs_sql_script_name = '$script_name'"} err
    # if no results, try handling a script that ran but exited before making an shs entry by checking
    # whether or not the prior script ran successfully
    if {$results == ""} {
        putt "WARNING: $script_name was not listed in SHS row.\nAssuming it did not run."
        set line ""
        set results ""
        set prev_script_name ""
        set line [getPrevDriverRow $driverFile $script_name]
        if {$line != -1 && $line != ""} {
            set prev_script_name [lindex $line 1]
            putt "Script that should have run prior: $prev_script_name"
            execsql use $DBH "select shs_results, shs_version_old, shs_version_new into :results, :old_version, :new_version from shs_schema_history where shs_sql_script_name = '$prev_script_name'"
            if {$results == "Successful"} {
                set script_name $prev_script_name
            } elseif {$results == "Started"} {
                set script_name $prev_script_name
            } else {
                putt "ERROR: unknown or missing status: $results"
                set results "UNKNOWN"
                set status -1
            }
        } else {
            putt "ERROR: Could not find evidence of $prev_script_name in SHS either."
            set results "UNKNOWN"
            set status -1
        }
    }
    if {$results == "Successful"} {
        # note - it could be the previous script - see above.  handles both cases
        #last one succeed, this one did not yet write an shs,
        #older scripts create exception table first, so remove it, as script hasn't run yet
        set sql "Drop table exceptions"
        execsql use $DBH $sql
        # could be an old bat file left around?
        # todo - check if some other script has started (and failed), but no bat file for it??
        # not a likely scenario, but possible
        putt "$script_name already completed successfully. \nContinuing conversion, but will recertify schema."
        puts "Deleting old bat file $batty"
        catch {file delete $batty}
        set results "CHECK"
        set status "0 0"
    }

    if {$results == "Started"} {
        # this case handles where script really did fail and can be restarted.
        set status -1
        putt "CAUTION: Script $script_name did not complete successfully.\nYou should have a revised script from EXL Healthcare before proceeding."
        #add if silent clause here.
        if {$silent} {
            putt "Running in silent mode, continuing despite warning."
        } else {
            set response [getUserResponse "Restart conversion with script $script_name? (Y N) >" $silent N]

            if { ![regexp -nocase {^y$} $response] } {
                putt "User responded '$response' to query to continue."

                return -2
            }
        }

        #TODO add a check that script has been modified - like a comment "EXL Healthcare MODIFIED date"
        putt "Restarting execution of $script_name."

        catch {run_SQL_Script $scriptLogonString $script_name $batty "$script_dir" [getInfo sign]}
        if {$err != 0} {
            putt "ERROR: Conversion failure running scripts.\n$err"
            return -1
        } else {
            if [catch {findSpoolFile $script_name [getInfo WORKING_DIRECTORY]} spoolfile] {
                putt "ERROR:"
                putt "$script_name did not complete successfully:\n$spoolfile"
            }
            if {[catch {QuestionCompleteness $DBH $script_name $spoolfile} status] || $status != 0} {
                putt "ERROR:"
                putt "$script_name did not complete successfully:\n$status"
                putt "Contact EXL Healthcare support before proceeding."
                putt "Failure at [clock format [clock seconds]]"
                set status -1
                return -1
            } else {
                file delete -force $batty
                catch {execsql use $DBH "select shs_results, shs_version_new into :results, :new_version from shs_schema_history where shs_sql_script_name = '$script_name'"} err
                set current_version [lindex $new_version 0]
                set productName [getSchemaProduct $DBH]
                set current_product [getProductPrefix $productName]
                putt "Restarting conversion processing after $script_name."
                set status "$current_product $current_version"
            }
        }
    }
    return $status
}

# ##########
# @proc usage_Autoscript
# @outputs correct usage , for help or in case input was invalid
# ##########
# @author
# @param argv, arcg
# @exception
# @see
# @return -1
# ##########
#todo implement usage (bundled script) db_util convert connect=a/b@c silent=Y dropUnused=Y
proc usage_Autoscript  {} {
    puts "AutoScript.tcl version [AutoScript.version], revision [AutoScript.revision]\nat [clock format [clock seconds]].\n"

    set t_flag no

    puts ""
    puts "AutoScript.tcl automatically converts schema and data in "
    puts "a target database to the target version. "
    puts ""
    puts "DIRECTORY STRUCTURE: In order for AutoScript.tcl to run, all "
    puts "files must be in the same directory structure as delivered in the "
    puts "DB_Scripts directory on the CD. "
    puts ""
    puts "CONVERSION STATUS: If at any point AutoScript.tcl fails, the "
    puts "conversion process will stop. You should contact the EXL Healthcare "
    puts "Support Department to assist in safely resolving the issue "
    puts "(800) 669-4629."
    puts ""
    puts "OUTPUT FILES:"
    puts "AutoScript.tcl generates several output files--for example, "
    puts "SQL spool files (.lst) and processing log files (.log). All "
    puts "output files are automatically placed in an output directory. "
    puts "In order to prevent these files from being overwritten in the "
    puts "event a utility is run multiple times, the date and time is "
    puts "included in the filename. The date-time format is "
    puts "month-day-hour-minute. For example, the following file was"
    puts "created on September 20, at 11:58 AM"
    puts ""
    puts "   sysDataUpdate09201158.sql"
    puts "                ^ ^ ^ ^"
    puts "                | | | |"
    puts "            Month | | |"
    puts "                Day | |"
    puts "                 Hour |"
    puts "                 Minute"
    puts ""
    puts ""
    puts "AUTO DROP UNUSED FLAG:"
    puts "EXL Healthcare Schema Upgrade scripts flag unused columns for later deletion."
    puts "If AutoScript is launched after-hours, it may be advantageous to drop them"
    puts "immediately upon successful completion of a script, in which case this"
    puts "flag should be set to 'Y'."
    puts ""
    puts "SILENT:"
    puts "If you are running autoscript as a background process, enter SILENT as"
    puts "the last parameter to avoid requests for user input.  The result of this"
    puts "is that warnings will be ignored and the script will continue."
    puts "This should only be used if you know what the warning(s) will be, and"
    puts "know that your response should be to continue."
    puts "It is advised that you contact EXL Healthcare Support before using this option."
    puts ""
    puts "EMAIL:"
    puts "If the server on which you are running AutoScript.tcl has email capabilities"
    puts "and you include a notification email address when using AutoScript.tcl, "
    puts "you will be notified of the error and the conversion failure in an email "
    puts "message. Similarly, if the conversion completes successfully, you will also"
    puts "be notified in an email message."
    puts ""
    puts "USAGE:   mtclsh AutoScript.tcl <Target database connect string> "
    puts "         <AutoConversion .txt file> <Auto Drop Unused flag (Y/N)>"
    puts "         \[Notification email address\]"
    puts "         \[SILENT\]"
    puts "EXAMPLE: mtclsh AutoScript.tcl proddb/mypass@servername  "
    puts "         M2050000_M2060000_AutoConversion.txt N maxadmin@site.com"
    puts ""
    puts "You can alternately put the above inputs into a file."
    puts "The default input file name is input_params.txt and is the default"
    puts "if autoScript is run without parameters."
    puts "You may specify another file name on the command line:"
    puts "EXAMPLE: mtclsh AutoScript.tcl inputfile=myFile.txt"
    puts "input_params.txt can be found in the DB_Scripts/Tools directory"
    puts "and has all the parameters needed for all tcl tools."
    puts "For autoScript.tcl the required paramters are:"
    puts "CARERADIUS_SCHEMA_NAME=<schemaname>"
    puts "CARERADIUS_SCHEMA_PASSWORD=<password>"
    puts "DB_HOST_INFO=<tnsname or identifier>"
    puts "AUTOCONVERSION_FILE=AutoConversion.txt"
    puts "AUTO_DROP_COLUMNS=<Y/N>"
    puts "optional parameters"
    puts "SILENT=<Y/N>"
    puts "EMAIL=<abc@xyz.com>"
    puts ""
    puts "For more details, see DB_Scripts/Docs/Tools_Docs/using-autoscript.html"
    puts "ERROR: time [clock format [clock seconds]]"
    puts ""

    return -1
}

# ##########
# @proc runConversionScripts
# @Given the scripts to run, runs, then checks success of script run
# ##########
# @author LAQ
# @param DBH -database connection handle
# @param scriptLogonString - connection script
# @param scripts autodrop - flag to drop unused columns yor no
# @param cript dir (optional) path to add to file names
# @param question = depricated, should always be true?
# @exception script failure exception
# @see common_utilites::run_SQL_Script
# @see common_utilites::QuestionCompleteness
# @return status
# ##########
proc runConversionScripts {DBH scriptLogonString scripts auto_drop outDir {scriptDir ""} {question "true"}} {
    foreach line $scripts {
        if {[llength $line] == 0} {
            continue
        } elseif {[llength $line] != 3 && [llength $line] != 5} {
            puts "Error: Invalid or corrupted driver file - only [llength $line] entries in the line"
            error "Invalid or corrupted driver file"
        }

        # zero pad script index if only 1 character in length.  Ensures lsort later can sort asc[index].bat files correctly.
        if {[string length [lindex $line 0]] == 1} {
            set script_index "0[lindex $line 0]"
        } else {
            set script_index [lindex $line 0]
        }
        set script [lindex $line 1]

        putt "Running script $script in $scriptDir"

        set batty [file join $scriptDir asc$script_index.bat]

        catch {run_SQL_Script $scriptLogonString "$script" "$batty" $scriptDir [getInfo sign]} status
        if {$status != 0} {
            putt "Unexpected error condition occurred: \n$status"
            if [catch {findSpoolFile $script [getInfo WORKING_DIRECTORY]} spoolfile] {
                putt "It appears no spool file was generated: expected [file rootname $script].lst"
            } else {
                putt "Please review $spoolfile"
            }
            return -1
        }
        putt "Testing status of script execution..."
        if [catch {findSpoolFile $script [getInfo WORKING_DIRECTORY]} spoolfile] {
            putt "ERROR:"
            putt "$script did not complete successfully:\n$spoolfile"
        }
        set status [QuestionCompleteness $DBH  $script $spoolfile]
        if {$status != 0} {
            putt "Execution error while running $script"
            error "$script $status"
        } else {
            putt "Status OK."
        }
        regsub {\.sql} $script "*.lst" spoolfile
        set spoolfiles [glob -nocomplain $spoolfile]

        foreach spoolfile $spoolfiles {
            if {![file exists $spoolfile]} {
                if {[file exists [file join $scriptDir $spoolfile]]} {
                    set spoolfile [file join $scriptDir $spoolfile]
                } else {
                    putt "Could not locate $spoolfile"
                }
            }
            if [catch {file rename -force $spoolfile [file join [getInfo AutoScript.OUTDIR] $spoolfile]} err] {
                putt "spool file $spoolfile could not be moved to [getInfo AutoScript.OUTDIR]"
                putt $err
            }
        }
        file delete -force $batty
        if { [file exists $batty] } {
            puts "WARNING: unable to delete file $batty"
        }
    }
    return 0
}

# ##########
# @proc runDropColumns
# @drops unused columns that are commented out at bottom of conversion script.
# ##########
# @author LAQ
# @param DBH database handle
# @param scripts listing of sql scripts to check
# @param scriptDir directory scripts are located in.
# @exception none
# @see common_utilites::dropColumns
# @return none
# ##########
proc runDropColumns {DBH scripts {scriptDir ""}} {
    foreach line $scripts {
        set script [lindex $line 1]
        set sc [file join $scriptDir $script]
        set status [dropColumns $DBH $sc]
        if {[lindex $status 0] != 0} {
            puts "#---------------------------------#"
            putt "Could not drop [lindex $status 0] unused column(s):"
            if {[lindex $status 1] != ""} {
                putt [join [lindex $status 1 ] ";\n"]\;
            } 
            if {[lindex $status 2] != ""} {
                putt [join [lindex $status 2 ] ";\n"]\;
                putt "You will need to manually run these statements after conversion is completed."
            }
            puts "#---------------------------------#\n"
        }

    }
}

# ##########
# @proc codeFailureMessage
# @products text to output if code check fails, gets user input to ignore or quit
# ##########
# @author
# @param conflict_codes -list of items that will conflict
# @exception
# @see
# @return user response
# ##########
proc codeFailureMessage {conflict_codes {silent 0}} {
    append out_text "\n============================================================================"
    append out_text "\nERROR: During the conversion, codes will be added to tables which have\nexisting codes created outside of the standard schema upgrade process.\n"
    append out_text  "\n   [format "%-26s %-26s %-26s" "TABLE_NAME" "COLUMN_NAME" "COLUMN_VALUE"]"

    foreach line $conflict_codes {
        append out_text  "\n   [format "%-26s %-26s %-26s" [lindex $line 0] [lindex $line 1] [lindex $line 2]]"
    }

    append out_text "\n"
    append out_text "\nCode Check Failure"
    append out_text "\n============================================================================"
    append out_text "\nThere has been a Code Check failure.  Please contact EXL Healthcare Technical"
    append out_text "\nSupport at 1-800-669-4629 to validate if the code(s) listed above will cause"
    append out_text "\na conversion failure.  Continuing the conversion at this point may result in"
    append out_text "\na conversion failure."
    append out_text "\nWould you like to continue with the conversion? (Y/N):"

    putt $out_text

    set $out_text ""
    flush stdout

    if {$silent} {
        putt "Running in silent mode."
        putt "Failing script due to Code Check Failure."

        set response N
    } else {
        gets stdin response
    }

    set response [string trim [string toupper $response]]

    # #TODO this message is getting repeated twice.
    if { ![regexp -nocase {^y} $response] } {
        set message "Code Check Failure."
        SendMess $message
    } else {
        append out_text "\n============================================================================"
        append out_text "\nContinuing conversion with Code Check failure."
        append out_text "\n============================================================================"

        putt $out_text
    }

    return $response
}

# ##########
# @proc systemDataFailure
# @Outputs error that sysdatagen found errors in system data.
# If diff is only non sysdata in system area, allows user to ignore
# ##########
# @author
# @param datastatus - list of discrepancies.
# @exception
# @see
# @return user response
# ##########
proc systemDataFailure {datastatus silent} {
    set message "ERROR: \nConversion error. "

    putt ""
    putt "ERROR: Could not certify system data:"
    putt ""
    putt "[lindex $datastatus 0] System data values missing"
    putt "[lindex $datastatus 1] System data values need updating"
    putt "[lindex $datastatus 2] Non system data records in system data areas"
    putt ""
    putt "Please contact the EXL Healthcare Support Department for assistance:"
    putt "[getInfo SupportContact]"

    if {[lindex $datastatus 2] != 0 } {
        putt "WARNING: [lindex $datastatus 2] Non system data records in system data areas."
        putt "This may cause conversion failure if system data being added conflicts \nwith these records."

        if {$silent} {
            putt "Running in silent mode, continuing despite this warning."
            return 0
        } else {
            puts "You should contact EXL Healthcare support before proceeding with conversion."
            puts "If you have already determined that these records will not cause conflicts, \nyou may continue with the conversion."
            puts "Continue with conversion (Y/N)?"

            gets stdin resp

            if { [string tolower [string trim $resp]] != "y" } {
                set message "User entered $resp : execution cancelled"

                SendMess $message

                return -1
            } else {
                return 0
            }
        }
    }

    return -1
}


proc checkConversionUtilities {dbh} {
    set scriptCount 1
    set sql "select count(*) into :scriptCount from shs_schema_history where
    (select count(*) from SHS_schema_history where shs_sql_script_name like 'MC%.sql'
    and shs_version_new like '-%') > 0 and (
    select count(*) from shs_schema_history where shs_sql_script_name like 'MC%CR%CONVERSION_UTILITIES.tcl') = 0"
    execsql use $dbh $sql
    return $scriptCount
}


# ##########
# @proc conversionFailure
# @explains that conversion was unsuccessful, and to contact Lcorp
# ##########
# @author
# @param displayDB what database/server (w/o password)
# @param startVersion where schema started.
# @param currentVersion where schema is
# @param outDir the output directory
# @exception
# @see common_utilities::getInfo
# @return
# ##########
proc conversionFailure {displayDB startVersion targetVersion outDir} {
    putt ""
    putt "[getInfo HR]"
    putt "  !!! CONVERSION FAILURE !!!"
    putt ""
    putt "The conversion was NOT completed.  AutoScript.tcl experienced an error during"
    putt "the $startVersion to $targetVersion conversion on $displayDB."
    putt ""
    putt "Reports listing the discrepancies are available in the output directory:"
    putt "  [getInfo AutoScript.OUTDIR]"
    putt ""
    putt "Please contact the EXL Healthcare Support Department for assistance: "
    putt "[getInfo SupportContact]"
    putt ""
    putt "please include all files in [getInfo AutoScript.OUTDIR] when you contact EXL support"
    putt "[getInfo HR]"
}
# ##########
# @proc preConversionFailure
# @explains that pre conversion validation was unsuccessful, and to contact Lcorp
# ##########
# @author
# @param displayDB what database/server (w/o password)
# @param startVersion where schema started.
# @param currentVersion where schema is
# @param outDir the output directory
# @exception
# @see common_utilities::getInfo
# @return
# ##########
proc preConversionFailure {displayDB startVersion targetVersion outDir} {
    putt ""
    putt "[getInfo HR]"
    putt "  !!! PRE CONVERSION CHECK FAILURE !!!"
    putt ""
    putt "The Conversion cannot continue."
    putt "The schema is in an unknow or invalid state.  AutoScript.tcl experienced an error during"
    putt "the $startVersion to $targetVersion conversion on $displayDB."
    putt ""
    putt "Reports listing the discrepancies are available in the output directory:"
    putt "  [getInfo AutoScript.OUTDIR]"
    putt ""
    putt "Please contact the EXL Healthcare Support Department for assistance: "
    putt "[getInfo SupportContact]"
    putt ""
    putt "please include all files in [getInfo AutoScript.OUTDIR] when you contact EXL support"
    putt "[getInfo HR]"
}
proc AutoScript.getDescription {} {
        return "Script to upgrade schema and data in
a database to the targeted version. "
}
############################################################################
#
#   The main logic starts here.
#   First the user is prompted to include the database logon string,
#     target version and
#   (optionally) the e-mail address
#
########################################################################
proc autoscript {database driverFile auto_drop e_mail silent} {
    set here [pwd]
    set toolName AutoScript
    setInfo here $here
    # Note: if scripts get separate directory, update scriptDir to point to it.
    set scriptDir   "[getInfo SCRIPT_FILES_DIRECTORY]"
    set workingDir  "[getInfo WORKING_DIRECTORY]"
    set time_start  [clock seconds]
    set curr_dir [pwd]
    set batty $curr_dir
    set message z
    set restart 0
    set ebScripts_todo ""
    set outdatesuff [clock format $time_start -format "%m.%d.%H%M"]
    set fullOutDateSuff [clock format $time_start -format "%Y.%m.%d-%H.%M.%S"]
    setInfo currentTool Autoscript
    set driverFileName [file tail $driverFile]
    set displayConnection [getInfo displayConnection]
    set logfile "[file rootname [asc_tool]]-$outdatesuff.log"
    #  NOTE: this is a temporary log file till we find out where to put it.
    setStartTime "$toolName"
    puts "\n[getInfo HR]"
    set log [getReportFile $toolName [pwd] $logfile]
    updateInfo $toolName.REPORT_HANDLE $log
    updateInfo default_channel $log
    printInitialHeader $toolName [$toolName.getDescription] [$toolName.version].[$toolName.revision]

    set ctxTS ""
    set lobTS ""
# Test for special characters in logon string Test for special handling of @ symbol
    if [catch {addInfo [checkLogon.Oracle $database]} err] {
        error [p_runtimeError "Connection error using [getInfo connectDisplay] \n$err"]
    }
    if {[catch {getLogonHandle [getInfo connectionString]} DBH] || $DBH < 0} {
        putt "Could not log onto $displayConnection."
        putt "Check your typing or connection file."
        putt "Error was : $DBH"

        return -1
    }
    setInfo DATABASE_HANDLE $DBH
    putt "Conversion processing on $displayConnection"


    # need current_product, current_version, current model file
    # need target_product, targetVersion, target model file
    # need to make sure can start from this location
    # or if need to restart.
    # if batty exists, see if client needs to restart the conversion
    # This should be modified to read from the conversion progress table
    # select columnContainingConversionFromVersionToVersionInfo from conversion progress where latest entry
    if {![catch {glob -directory "[getInfo SCRIPT_FILES_DIRECTORY]" asc*} batty]} {
        set batty [lindex [lsort -decreasing [glob -nocomplain -directory "[getInfo SCRIPT_FILES_DIRECTORY]" asc*]] 0]
        #todo: return the current product as well
        set cpv [restartYN $DBH [getInfo scriptLogonString] $batty $silent]

        if {[llength $cpv] < 2 && $cpv < 0} {
            puts "Exiting conversion"
            return -1
        } elseif {[lindex $cpv 0] == 0} {
            # this is returned if prior script succeeded and the script mentioned
            # in batty never started.  - result = start where schema says, but check
            # to make sure all is good.
            set productName [getSchemaProduct $DBH]
            set currentProduct [getProductPrefix $productName]
            set currentVersion [getSchemaVersion $DBH]
        } else {
            set restart 1
            set currentProduct [getProductPrefix [lindex $cpv 0]]
            set currentVersion [lindex $cpv 1]
        }
    } else {
        set productName [getSchemaProduct $DBH]
        set currentProduct [getProductPrefix $productName]
        set currentVersion [getSchemaVersion $DBH]
        # if there is a failed version in the shs table that's greater than the current version
        # we probably had a script that didn't complete.  If the asc file was deleted we will want
        # to treat as a restart so validation doesn't fail.  Try re-running the script that failed.
        set failedScripts [getFailedScripts $DBH]
        if {[llength [lindex $failedScripts 0]] != 0} {
            if {[llength [lindex $failedScripts 0]] == 1 } {
                putt "Found failed script [lindex $failedScripts 0]."
                putt "Attempting conversion restart..."
                if {[lindex $failedScripts 1] > $currentVersion} {
                    set currentVersion [lindex $failedScripts 1]
                    set restart 1
                } 
            } else {
                set errormessage "ERROR: More than 1 failed script has been found.  It is not safe to continue.\nFailed scripts:\n[join [lindex $failedScripts 0] \n]"
                puts $log $errormessage
                error $errormessage
            }
        }
    }

# GET version information
    if [catch {getCurrentDriverRows $driverFile $currentVersion $currentProduct} currentInfo] {
        putt "ERROR: $currentInfo"
        putt "Cannot continue with conversion."
        putt "You may be using the wrong driver file \n '$driverFile' \nfor your start version."
        putt "Or you may need to run an EB script \nto bring your schema to a valid start version.\nCheck the ug_patch directory."
        putt "For assistance, please contact EXL Healthcare support.\n[getInfo SupportContact]"

        return -1
    }
    set currentMod [lindex [lindex $currentInfo end] 4]
    regexp {[0-9]+$} $currentMod short_current
    set targetProduct [getFinalProduct $driverFile]
    set targetInfo [getTargetDriverRow $driverFile]
    set targetVersion [lindex $targetInfo 2]
    set targetMod [lindex $targetInfo 4]
    regexp {[0-9]+} $targetMod short_target

    set shortdotcurrent [join [p_unpad_version $currentVersion] "."]
    set shortdottarget [join [p_unpad_version $targetVersion] "."]
    #should have all versioning info now...
    putt  "Current version is $currentVersion"
    putt  "Target version is $targetVersion"
    putt "Initial certification against model definition in $currentMod"
    putt "Final certification against model definition in   $targetMod."
    #check that conversion utilities has been run if necessary
    setInfo startVersion $currentVersion
    if {$currentProduct == "CR" && ($currentVersion >= "01.06.06.00" || $targetVersion >= "02.00.00.00")} {
        if [checkConversionUtilities $DBH] {
            putt "\nYou cannot run this script until you have run conversionUtilities.tcl.
    To do so would cause loss of data.
    Please review the conversion instructions.
    If you have any issues, please contact EXL Healthcare support.\n[getInfo SupportContact]\n"
        return 1
        }
    }
    # if the conversion is to version 02.01.00.00 or greater, validate the existence of the max2_ctx_ts and max2_lob_ts tablespaces
    if {$targetVersion >= "02.01.00.00"} {
        set ctxTS [validateCTXTableSpace $DBH]
        set lobTS [validateLOBTableSpace $DBH]
        if {$ctxTS == 0} {
            putt "\nYou cannot run this script until you have run CTXCreateTablespace.sql.\nIf you have any issues, please contact EXL Healthcare support.\n[getInfo SupportContact]\n"
        }
        if {$lobTS == 0} {
            putt "\nYou cannot run this script until you have run LDSCreateTablespace.sql.\nIf you have any issues, please contact EXL Healthcare support.\n[getInfo SupportContact]\n"
        }
        if {$ctxTS == 0 || $lobTS == 0} {
            return 1
        }
    }
    set conversionInfo [getConversionInfo $driverFile $currentProduct $currentVersion]
    # check for all needed resources.
    # ufg is not for CR
    if { $targetProduct == "MC" || $targetProduct == "M2" } {
        set e_file export$short_target.ufg
    } else {
        set e_file ""
    }

    set missing_flag  [checkResources  [getToolsList $currentProduct $e_file] $driverFile ]

    if { $missing_flag == "yes" } {
        puts "\nThe above named file(s) must be in the current directory.\nCopy them from the CD and restart AutoScript.\nCall EXL Healthcare Support at 1-800-669-4629 if you are unable to locate them."
        puts $log "\nThe above named file(s) must be in the current directory.\nCopy them from the CD and restart AutoScript.\nCall EXL Healthcare Support at 1-800-669-4629 if you are unable to locate them."
        puts $log "Exit [clock format [clock seconds]]"

        close $log

        return -1
    }

    set missing_flag [checkModelFileResources $conversionInfo]
    #check that all necessary scripts exist.

    if { $missing_flag == "yes" } {
        puts "\nThe above named file(s) must be in the current directory.\nCopy them from the CD and restart AutoScript.\nCall EXL Healthcare Support at 1-800-669-4629 if you are unable to locate them."
        puts $log "\nThe above named file(s) must be in the current directory.\nCopy them from the CD and restart AutoScript.\nCall EXL Healthcare Support at 1-800-669-4629 if you are unable to locate them."
        puts $log "Exit [clock format [clock seconds]]"

        close $log

        return -1
   }
    # make output directory, move log restart logging
    set outDir  [file join $workingDir $fullOutDateSuff-$currentProduct$shortdotcurrent\_$targetProduct$shortdottarget]

    updateInfo AutoScript.OUTDIR $outDir
    if [catch {makeDir $outDir } outDir] {
        puts "All files will be generated in the current directory [pwd]"
        set outDir $workingDir
    } else {
        setlog off $log
        if [catch {file rename -force $logfile $outDir/$logfile} err] {
            puts "Cannot move log file to output directory.  Logfile is $logfile"
            set log [setlog "append" "$logfile"]
        } else {
            set log [setlog "append" "$outDir/$logfile"]
        }
        updateInfo default_channel $log
        updateInfo AutoScript.REPORT_HANDLE $log
    }
    putt "All output files will be in directory $outDir"
    putt "Autoscript log file is $logfile"
    putt "Using driver file $driverFile"
    putt "Silent flag = $silent"
    if {[string toupper [getInfo LOADPACKAGE]] == "TRUE"} {
        putt "Force update of conversion package"
    }
    putt "[getInfo HR]\n"
    setInfo outDir $outDir

    # if user is present, check if email confirmation is required.
    if {$silent == 0} {
        checkEmail $e_mail
    }

    # if target version is 02.02.XX.XX or greater then load the LANDA_CONVERSION package
    if {$targetVersion >= "02.02.00.00" && (!($restart) || [string toupper [getInfo LOADPACKAGE]] == "TRUE")} {
        set rval [loadLandaPackage $DBH $workingDir $outDir $log]
        if {$rval != 0} {
            return $rval
        }
        set rval [loadTextStorage $workingDir $outDir $log]
        if {$rval != 0} {
            return $rval
        }
    }

    set curVerScripts ""
    set shsLst ""
    set curVerScriptsToRun ""

    #find out if any scripts for the current version haven't been run (like a data script)
    if {! $restart} {
        putt $log "Checking for scripts that need to be run for version $currentVersion."
        set curVerScripts [getCurrentDriverRows $driverFile $currentVersion $currentProduct]
        set shsLst [getSHSscripts $DBH]
        set scripts [scriptsToRun $conversionInfo $shsLst]
        set curVerScriptsToRun [scriptsToRun $curVerScripts $shsLst]
        if {[llength $curVerScriptsToRun] > 0} {
            set message "Before beginning conversion you must run the following script"
            if {[llength $curVerScriptsToRun] > 1} {
                append message "s"
            }
            putt $log $message
            puts [join $curVerScriptsToRun "\n"]
            set response [getUserResponse "Would you like to run the scripts now?" $silent]
            if [regexp -nocase {^Y$} [string trim $response]] {
                catch {runConversionScripts $DBH [getInfo scriptLogonString] $curVerScriptsToRun $auto_drop $outDir $scriptDir "true"} err
                if {$err != 0} {
                    putt $log "Failure on running scripts"
                    putt $log $err
                    return -1
                }
            } else {
                putt $log "User entered $response"
                putt $log "Exiting autoscript.tcl"
                return -1
            }
        } else {
            putt $log  "There are no scripts that need to be run."
        }
        putt "[getInfo hr]\n"
    }

    # get EB scripts if they exist
    if {! $restart} {
        putt $log  "Checking for eb scripts for version $currentVersion"
        set ebScripts_todo [getEBScripts $DBH "ug_patch" $currentVersion $currentProduct $short_current]
        if {[llength $ebScripts_todo] > 0} {
            set message "Before beginning conversion you must run the following script"

            if {[llength $ebScripts_todo] > 1} {
                append message "s"
            }

            putt $log $message
            puts [join $ebScripts_todo "\n"]

            set response [getUserResponse "Would you like to run the scripts now?" $silent]

            if [regexp -nocase {^Y$} [string trim $response]] {
                catch {runConversionScripts $DBH [getInfo scriptLogonString] $ebScripts_todo $auto_drop $outDir [file join $workingDir "ug_patch"] "true"} err

                if {$err != 0} {
                    putt $log "Failure on running EB scripts"
                    putt $log $err

                    return -1
                }
            } else {
                putt $log "User entered $response"
                putt $log "Exiting autoscript.tcl"

                return -1
            }
        } else {
            putt $log  "There are no EB scripts that need to be run."
        }
        putt "[getInfo hr]\n"
        # validate currentVersion against old/ new versioning
        # prior to CR 1.6, used MR version, with no EBs.
    }

    

    if {$conversionInfo == "" && $currentVersion != $targetVersion} {
        if {$ebScripts_todo != ""} {
            set errormessage "You must run the following scripts before your SHS table and schema can be validated."

            putt $log $errormessage
            putt $log \t[join $ebScripts_todo "\n\t"]
        } else {
            set errormessage "Unable to determine conversion path for $productName version $currentVersion.\n"

            append errormessage "Or you may need to run an EB script \nto bring your schema to a valid start version.\nCheck the ug_patch directory."

            putt $log $errormessage
        }
        putt "[getInfo HR]\n"
        error $errormessage
    }

    if {!$restart} {
        if {$currentProduct == $targetProduct && $currentVersion == $targetVersion} {
            putt $log "Schema is already at target version. No scripts need to be run."

            set response [getUserResponse "Continue anyway?" $silent N "No conversion scripts need to be run.\nRunning this again will merely certify the conversion."]

            if [regexp -nocase "Y" $response] {
                putt $log "\nContinuing - will certify conversion."
            } else {
                putt $log "Exiting - user entered $response"

                return 0
            }
        } else {
            putt $log  "Start version OK"
        }

        putt $log  "Checking SHS_SCHEMA_HISTORY table for errors or failed script entries"

        set validSHS [validateSHS $DBH ]

        if {$validSHS != ""} {
            putt $log  "The following did not complete: $validSHS"
            # TODO - what to do
            # check if EB scripts need to be run....
            if {$ebScripts_todo != ""} {
                putt $log "You must run the following scripts before your SHS table can be validated."
                putt $log \t[join $ebScripts_todo "\n\t"]
            }

            putt $log "Exiting."

            return -1
        } else {
            putt "SHS_SCHEMA_HISTORY table check OK"
        }
    }

    ##################################################
    # Set the version for user output format (e.g., 05.00.00)
    # This is based off of the AutoConversion.txt name
    ##################################################
    # there are several forms of the version numbering that are being used
    # 05.00.00 - for shs version values, outputting
    # 050000 - for
    # 500 - for modelfiles


    if {! $restart} {
        # begin checking for prerequisites
        putt $log "Checking if database has sufficient privileges."
        # Ensure user has correct privileges: call procedure GrantCheck
    if {$currentProduct != "CF"} {
        putt "Checking user select permissions."
        set err [GrantCheck $log $DBH]
        if {$err != 0} {
            putt $log "User does not have sufficient privileges."
            #todo: fix this
            set continue [getUserResponse "You do not have sufficient privileges to run the tablespace check.\n Continue anyway? (YN)" $silent]
            if {[string toupper $continue] == "Y"} {
                set checkTableSpace 0
            } else {
                putt $log "Run the above sql as user that has rights to grant the specified permissions."
                putt $log "Exiting on user's response $continue"
                return 0
            }
        } else {
            putt "The target database has sufficient select privileges."
        }
        if {![regexp {^01} $targetVersion]} {
            putt "Checking user execute and create permissions."
            set err [FunctionalGrantCheck $log $DBH]
            if {$err < 0} {
                set out "============================================================================\n"
                append out "You are missing privileges required to run this conversion.\n"
                append out "Run the above sql as user that has rights to grant the specified permissions.\n"
                append out "============================================================================\n"
                putt $log $out
                return -1
            }
        } else {
            putt "The target database has sufficient execute and create privileges."
        }
        putt "[getInfo hr]\n"
    }
}


    set message ""

    source dbCompare.tcl
    source sy_load.tcl
    source seqfix.tcl
    source SysDataGen.tcl

    #################################################
    ## Certify at starting version.
    #################################################
    # #restart should skip certification as we may have eb's to run
    # #if versions are same, no point in certifying at this point.
    # # ie, this is only for real conversions

    if {! ($restart) && "$currentVersion" != "$targetVersion"} {
        logit "Beginning initial version schema certification."

        set schemaValid [dbCompare $currentMod $database "cert$short_current.lst" ]
        updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
        if {$schemaValid != 0} {
            putt  "Schema cannot be certified at starting version."
            putt  "$schemaValid items are out of compliance"
            putt  "You must repair the schema before converting it."
            putt  "Contact EXL Healthcare support for assistance."
            putt "please review cert$short_current.lst in [getInfo AutoScript.OUTDIR]"
            return -1

        }
        #clear out all old information from dbcompare data structures.
        dbCompare.unsetAll

        putt "Schema certified at starting version"
        logit "STATUS: DBCOMPARE: PASS"

        lappend delete_it_lst [MoveOutput "cert$short_current.lst" [getInfo AutoScript.OUTDIR]]

        if {$currentProduct == "MC" && $targetProduct == "CR"} {
            set orv 0

            putt $log "Checking database readiness for conversion."
            putt $log "Running dbvalid.tcl"

            source dbvalid.tcl

            set orv [dbvalid $database $DBH]
            updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
            lappend delete_it_lst [MoveOutput "dbvalid" [getInfo AutoScript.OUTDIR]]

            if { $orv != 0 } {
                putt "\nERROR: dbvalid.tcl failed to pass database validation."
                putt "Please review [file join [getInfo AutoScript.OUTDIR] dbvalid.log] for details."
                putt "For assistance, contact EXL Healthcare support \n[getInfo SupportContact]"

                return $orv
            }
            putt "Database configuration ready for conversion."
            logit "STATUS: DBVALID: PASS"

        }
        #TODO make the file name outputs similar.
        putt "Updating SYD and SYT table definitions"

        set sy_fi [sy_load $DBH $displayConnection "yes" $silent [getInfo AutoScript.OUTDIR] ]
        updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
        logit "output file is $sy_fi"
        logit "STATUS: SY_LOAD: PASS"
        lappend delete_it_lst [MoveOutput "sy_load_info*.txt" [getInfo AutoScript.OUTDIR]]

        putt "Checking schema sequences."
        seqfix $DBH $displayConnection
        updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
        MoveOutput "seqfix_*.log" [getInfo AutoScript.OUTDIR]
        logit "Beginning initial version data certification."
        logit "Comparing schema to model definition in $currentMod."
        set datastatus [sysDataGen $DBH $displayConnection $currentMod [getInfo AutoScript.OUTDIR] "no" "$silent"]
        updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
        lappend delete_it_lst [MoveOutput "sysdataDiff*.txt sysDataUpdate*.sql nonSysRows*.sql" [getInfo AutoScript.OUTDIR]]
        if {!([lindex $datastatus 0] == 0 && [lindex $datastatus 1] == 0) } {
            set response [systemDataFailure $datastatus $silent]
            if {$response != 0} {
                preConversionFailure $displayConnection $currentVersion $targetVersion [getInfo AutoScript.OUTDIR]
                return $response
            }
        } else {
            putt "System Data certified at starting version"
            logit "STATUS: SYSDATAGEN: PASS"
        }
        putt "[getInfo hr]\n"
    }
    putt "Disabling RECORD_VERSION triggers."
    set rval [runSQLB [getInfo scriptLogonString] "exec Landa_conversion.DISABLE_RECORD_VERSION_TRIGS();" runval]
    if {$rval != 0} {
        set response [ getUserResponse "\nFailed to disable record version triggers.\nThis will not affect the ability of the conversion to complete successfully.\nWould you like to continue? > " $silent N]
        if {$response != "Y"} {
            return -2
        }
    } else {
        putt "Disabled RECORD_VERSION triggers successfully"
    }
    # Check for enabled invalid triggers
    putt "Checking for enabled invalid triggers."
    set triggers [getInvalidTriggers $DBH "nonAuditTrigger"]
    if {$triggers != 0 && $triggers != 1} {
        putt "Disabling enabled invalid triggers."
        if {[disableTriggers $triggers $DBH] > 0} {
            putt "Failed to disable triggers"
            putt "This could cause issues during the conversion."
            return 1
        }
    } elseif {$triggers == 1} {
        putt "Failed to retrieve list of triggers"
        putt "This could cause issues during the conversion."
        return 1
    } else {
        putt "None found."
    }
    putt "[getInfo hr]\n"

    # Auditing/Journaling
    catch {stopJournaling $DBH} code
    if {$code < 0} {
        putt "Failed to turn off journaling"
        putt "This could cause issues during the conversion."
        return $code
    } elseif {$code >= 0} {
        putt "Turned off $code journaling tables."
    }
    ##################################################
    #### Run the Conversion.
    ##################################################
    set shsLst [getSHSscripts $DBH]
    set scripts [scriptsToRun $conversionInfo $shsLst]
    putt "Begin conversion"
    putt "The following scripts will be run: \n"
    putt "[join $scripts \n]"
    putt "[getInfo HR]\n"
    set status [runConversionScripts $DBH [getInfo scriptLogonString] $scripts $auto_drop [getInfo AutoScript.OUTDIR] $scriptDir "true"]
    if {$status != 0} {
        putt $log "Conversion FAILED. "
        return -1
    }
    putt "[getInfo HR]\n"
    if {$auto_drop == "Y"} {
        set status [runDropColumns $DBH $scripts $scriptDir]
    }
    set finalStatus ""
    # re-enable or recreate record version triggers
    updateTor [getInfo scriptLogonString] [file join [getInfo MODEL_FILES_DIRECTORY] $targetMod]
    set runval ""
    putt "Enabling RECORD_VERSION triggers"
    set rval [runSQLB [getInfo scriptLogonString] "set serveroutput on\nexec Landa_conversion.ENABLE_RECORD_VERSION_TRIGGERS();" runval enableTriggers.lst]
    if {$rval != 0} {
         putt "Failed to disable RECORD_VERSION triggers. dbCompare will notify you which ones need to be recreated."
    } else {
        putt "Enabled RECORD_VERSION triggers successfully"
    }

    ##################################################
    #### Certify at target version.
    ##################################################
    putt "Certifying schema against target model"
    set schemaValid [dbCompare $targetMod $database "cert$short_target.lst"]
    updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
    lappend delete_it_lst [MoveOutput "cert$short_target.lst" [getInfo AutoScript.OUTDIR]]

    if {$schemaValid != 0} {
        putt $log "$schemaValid differences must be resolved before this schema can be certified."
        putt $log "Please contact EXL Healthcare support."
        putt $log "Validation FAILED"
        lappend finalStatus "dbCompare failed with $schemaValid errors."
    }
    putt "[getInfo hr]\n"
    dbCompare.unsetAll

    ##################################################
    #### Certify data at target version.
    ##################################################
    #clear out any nonsys files-
    deleteNonSysSpool [getInfo AutoScript.OUTDIR]

    putt "Validating system data against target model"

    set datastatus [sysDataGen $DBH $displayConnection $targetMod [getInfo AutoScript.OUTDIR] "yes" "$silent"]
    updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
    # check result
    if {[lindex $datastatus 0] != 0 || [lindex $datastatus 1] != 0 || [lindex $datastatus 2] != 0} {
        #discrepancy exists - try running script to update schema
        set statFile [lindex $datastatus 3]
        if {![file exists $statFile]} {
            putt $log "Warning: System data may not be certified.
            An unexpected failure occurred while attempting to certify data."
            lappend finalStatus "An unexpected failure occurred while attempting to certify data."
        }
        set correctionScripts [DataCertify $statFile]

        if {[llength $correctionScripts] > 0} {
            putt $log "Found system data discrepancies."

            set dirname [file dirname $statFile]
            set i 1

            foreach script $correctionScripts {
                putt $log "Running $script to correct system data discrepancies."

                set batty certifyData$i.bat
                catch {run_SQL_Script [getInfo scriptLogonString] $script $batty $dirname [getInfo sign]} status
                if {$status != 0} {
                    putt $log "Failed to certify data- script failure: \n $status"
                    return -1
                }
                if { [string first nonSysRows $script] == 0 } {
                    source SysDeleteEval.tcl
                    set spools [glob -directory $dirname -nocomplain $targetProduct*_Deletes_*.lst]
                    sysDeleteEval $DBH $spools {AutoScript no}
                }

                catch {file delete -force $batty}
            }

            # now run sysdatagen one more time to see that everything was corrected.
            putt $log "Checking that system data was corrected."

            set datastatus [sysDataGen $DBH $displayConnection $targetMod [getInfo AutoScript.OUTDIR] "yes" "$silent"]
            updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
            if { [lindex $datastatus 2] != 0} {
                putt "There are non-system data items in the schema that could not be deleted."
            }
            if {[lindex $datastatus 0] != 0 || [lindex $datastatus 1] != 0} {
                set statFile [lindex $datastatus 3]
                if {![file exists $statFile]} {
                    putt $log "Warning: System data may not be certified.
                    An unexpected failure occurred while attempting to certify data."
                    lappend finalStatus "An unexpected failure occurred while attempting to certify data."
                }
                set correctionScripts [DataCertify $statFile]

                if {[llength $correctionScripts] > 0} {
                    putt $log "Failed to certify data"
                    lappend finalStatus "SysDataGen Failed with [expr [lindex $datastatus 0] + [lindex $datastatus 1]] errors"
                }
            } else {
               set datastatus 0
            }
        } else {
            putt $log "Warning: System data may not be certified.
            An unexpected failure occurred while attempting to certify data."
            lappend finalStatus "An unexpected failure occurred while attempting to certify data."
        }
    } else {
        set datastatus 0
    }
    putt "[getInfo hr]\n"
    lappend delete_it_lst [MoveOutput "sysdataDiff*.txt sysDataUpdate*.sql nonSysRows*.sql" [getInfo AutoScript.OUTDIR]]

    MoveOutput *Updates_*lst [getInfo AutoScript.OUTDIR]
    MoveOutput *Deletes_*lst [getInfo AutoScript.OUTDIR]

    updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
    lappend delete_it_lst [MoveOutput "seqfix_*.log" [getInfo AutoScript.OUTDIR]]

    # currently, TaskImport will not work with changed Task structure of CareRadius
    if { $targetProduct == "MC" || $targetProduct == "M2" } {
        source TaskImport.tcl
        set log_stamp [clock format [clock seconds] -format "%m/%d/%y at %I:%M %p"]
        puts $log "TaskImport completed $log_stamp."
        MoveOutput task_import_*log [getInfo AutoScript.OUTDIR]
    }
    putt "Updating SYD and SYT table definitions"
    set sy_fi [sy_load $DBH $displayConnection "yes" $silent [getInfo AutoScript.OUTDIR] ]
    updateInfo default_channel [getInfo AutoScript.REPORT_HANDLE]
    putt "[getInfo HR]\n"
    lappend delete_it_lst [MoveOutput "sy_load_info*.txt" [getInfo AutoScript.OUTDIR]]
    lappend delete_it_lst [MoveOutput "sy_load_*.lst" [getInfo AutoScript.OUTDIR]]
    foreach delete_it $delete_it_lst {
        if {$delete_it != ""} {
            logit "deleting $delete_it"
            catch {file delete -force $delete_it}
        }
    }

    #to do : review this code.
    set del_append ""
    set report_lst [lsort -decreasing [glob -nocomplain *_Deletes_*.txt]]

    if { [llength $report_lst] != 0 } {
        set del_append "The data in this database is not fully EXL Healthcare compliant.\nPlease refer to [lindex $report_lst 0] for guidance in addressing this issue."
    } else {
        if {$auto_drop == "Y"} {
            dropDroppedColumns [getInfo scriptLogonString]  ""
        }
    }

# check for any warnings in the scd table:
    set sql "select scd_sch_id, scd_object, scd_action, scd_NAME, scd_sequence, scd_status
    into :items, :objects, :actions, :names, :sequences, :stati
    from scd_sch_details SCD, SCH_CHANGE_HISTORY SCH where scd_sch_id = SCH.SCH_ID and scd_uid = (select max(scd_uid) from
    scd_sch_details where scd_sch_id = SCD.SCD_sch_id and scd_sequence = scd.scd_sequence) and sch_status != 'C' and scd_status != 'C'
    order by SCD_SCH_ID, SCD_SEQUENCE"
    execsql use $DBH $sql
    if {$items != ""} {
        putt [getInfo hr]
        set em "WARNING: [llength $items] script items exited with warnings or exceptions. \n"
        if {[llength $finalStatus] == 0} {
            # don't scare client
append em "
This does NOT necessarily mean that there was a problem with the conversion.

Since the schema was certified at $targetVersion, these items should
not affect the successful outcome of the conversion and are most likely
the result of adding a data value that already exists.
However, they should be reviewed by EXL Healthcare,
and once evaluated can be updated to reflect their successful completion."
        } else {
            append em "
These items require attention, and may require corrective action.

Please contact EXL Healthcare and provide all output files so that
the status of your conversion may be assessed."
        }
        append em "
Please review $logfile for details."
        putt $em
        set errorcount 0
        foreach item $items sequence $sequences action $actions object $objects name $names status $stati {
            if {$status == "ERROR" || $status == "FAIL"} {incr errorcount}
            set sql "select scl_text
            into :errtext
            from scl_conversion_log SCL where  scl_uid = (select max(scl_uid) from scl_conversion_log where scl_status in ('WARN', 'ERROR', 'FAIL') and scl_sch_id = SCL.scl_sch_id and scl_sequence = scl.scl_sequence)
            and scl_sch_id = '$item' and scl_sequence = '$sequence'"
            execsql use $DBH $sql
            regsub -all {\n| +} $name " " name
            logit "-> $item.$sequence: $status $action $object $name"
            logit "\tResult was: [join $errtext]"
        }
        if {$datastatus == 0 && $schemaValid == 0 && $errorcount == 0} {
            # output "marking conversion process successful in SCH table...
            set sql "update sch_change_history set sch_status = 'C' where sch_status = 'W'"
            execsql use $DBH $sql
            execsql use $DBH commit
        }
        putt [getInfo hr]
    }
# done with all processing.
   if {[llength $finalStatus] == 0} {
    set success_message     "
  *** CONVERSION SUCCESSFUL ***

All SQL conversion scripts were successfully executed and both the schema and
system data have been certified at $targetVersion.

Please send EXL Healthcare Support a notification email that the conversion has
completed successfully.  In your email attach a zipped (.zip) archive of all
output files generated during the conversion.

Any questions or concerns about the conversion should be directed to a
Client Support Technician.  The EXL Healthcare Support Department may be reached at:
[getInfo SupportContact]
"
} else {
    set success_message "*** CONVERSION COMPLETED with ERRORS ***
All SQL conversion scripts were successfully executed,
but there were validation errors:
[join $finalStatus \n]"
}
    if { [string length $del_append] != 0 } {
        append success_message  "\n$del_append\n\n"
    }

    putt        $success_message
    putt "[getInfo HR]\n"
    if {$e_mail != "nomail" && $e_mail != "" } {
        if { [string first / [pwd]] == 0 } {
            exec echo $success_message$del_append | mailx -s "AutoScript complete" $e_mail
        } else {
            LOGMess AutoScript $success_message$del_append
        }
    }
    ##############################################
    # Delete the files that couldn't be moved but were
    # copied instead.
    ##############################################
    catch {file delete -force $batty}
    catch {file delete -force asc*.bat}
    catch {file delete -force AutoStat.txt}
    # close any open channels from other scripts if any
    closeOpenChannels [getInfo AutoScript.REPORT_HANDLE]
    return [llength $finalStatus]
}
# END proc autoscript

#==============================================================================#
#   Main Execution
#==============================================================================#
if {[info exists argv0] && [file tail [string tolower $argv0]] == "autoscript.tcl"} {
    if [catch {set argv [p_getParams $argv [file rootname [file tail $argv0]]]} arg] {
        puts "$arg"
        usage_Autoscript
        exit 1
    }
    set args [getArgsAutoScript $argv [llength $argv]]
    if {$args == -1} {
        usage_Autoscript
        exit 1
    }
    set database [lindex $args 0]
    set driverFile [lindex $args 1]
    set auto_drop [lindex $args 2]
    setInfo AUTO_DROP $auto_drop
    set e_mail [lindex $args 3]
    set silent [lindex $args 4]
    set displayConnection [getDisplayConnection $database]
    setInfo CONNECTION_STRING $database
    setInfo displayConnection $displayConnection
    setInfo driverFile $driverFile
    setInfo silent $silent

    catch {autoscript $database $driverFile $auto_drop $e_mail $silent} RESULT
    set duration [getDuration [getStartTime $toolName]]
    if {$RESULT != 0} {
        putt  "$toolName.tcl version [$toolName.version], revision [$toolName.revision] completed with errors.\n"
        putt "There was an error in processing: autoscript failed with error: $RESULT\n"
        putt "Error info was: $errorInfo"
        conversionFailure $database [getInfo startVersion] [lindex [getTargetDriverRow $driverFile] 2] [getInfo AutoScript.OUTDIR]
        set STATUS "FAIL"
        set exitval 1
    } else {
          putt  "$toolName.tcl version [$toolName.version], revision [$toolName.revision] successfully completed.\n"
          set STATUS "PASS"
          set exitval 0
    }
    putt      "Run Time was [prettyTime [hms $duration]]."
    putt      "END: [clock format [clock seconds] -format "[getInfo dateFormat] [getInfo timeFormat]"]"
    putt      [getInfo HR]
    putt    "RESULTS: $RESULT"
    putt   "STATUS: $STATUS"
    exit $exitval
} else {
    #puts "Sourced: Autoscript.tcl"
}
